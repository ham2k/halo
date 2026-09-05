// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Reads the radio's meters while it is transmitting, and not otherwise.
//
// A separate poller from [AdaptivePoller] rather than more knobs on it,
// because the two follow opposite rules. Frequency and mode are polled
// hardest when the radio is BUSY being tuned and eased off when it settles;
// meters are the reverse — worthless while receiving (SWR and ALC read zero,
// and power out is not a thing that exists at rest) and worth every
// millisecond of the wire while the radio is keyed.
//
// The other half of the difference is that this one has a hard stop. A tune
// can be missed and corrected at the next poll; a transmission is over when
// it is over, and there is nothing to catch up on afterwards.

import 'dart:async';

import 'package:flutter/foundation.dart';

/// The cadence an operator gets when nothing argues for another, and the
/// one they see prefilled: fast enough that an SWR spike during a call is
/// on screen while the call is still going out.
const kTelemetryInterval = Duration(milliseconds: 200);

/// The floor on a link with no stated speed — a network transport, flrig,
/// rigctld. Not a budget, just a guard against an operator typing something
/// that would spend the app's time on nothing useful.
const kTelemetryFloorFast = Duration(milliseconds: 50);

/// The share of the wire a meter cycle may take.
///
/// The same budget adaptive_poller.dart reasons in, and for the reason
/// stated there: on a slow serial link CPU scales with BYTES, and a cycle
/// that fills the line also queues in front of the app's own commands. A
/// quarter leaves room for the frequency poll, the radio's own pushed
/// frames, and a tune the operator makes mid-transmission.
const _dutyCycle = 0.25;

/// Bits on the wire per byte, framing included — 8N1's start and stop bits
/// are what make the arithmetic ten rather than eight.
const _bitsPerByte = 10;

/// The config key holding a node's meter cadence, in milliseconds.
///
/// Per node rather than per driver: two rigs on the same driver can sit on
/// links an order of magnitude apart, and the number that matters is the
/// one the SLOW one can afford.
const telemetryIntervalConfigKey = 'telemetryInterval';

/// The fastest meter cycle [baudRate] can carry inside [_dutyCycle], for a
/// cycle of [cycleBytes] bytes in both directions.
///
/// Null baud is a link that never stated a speed (TCP, a network rig, an
/// XML-RPC server): it is not "infinitely fast", it is unmeasured, so it
/// gets [kTelemetryFloorFast] rather than a computed number pretending to
/// know something.
///
/// An FT-891 at 4800 with a four-meter cycle (~52 bytes) lands near 430 ms;
/// the same radio at 38400 lands under the 200 ms default, which is then
/// what stands.
Duration telemetryFloor({required int cycleBytes, int? baudRate}) {
  if (baudRate == null || baudRate <= 0) return kTelemetryFloorFast;
  final wireMillis = cycleBytes * _bitsPerByte * 1000 / baudRate;
  final millis = (wireMillis / _dutyCycle).ceil();
  return millis < kTelemetryFloorFast.inMilliseconds
      ? kTelemetryFloorFast
      : Duration(milliseconds: millis);
}

/// What a node should be polled at: what the operator asked for, never
/// faster than the link can afford a cycle of [cycleBytes].
///
/// The clamp is one-directional on purpose. An operator who wants their
/// meters SLOWER than the budget is allowed it — a shared serial line, a
/// bridge, a radio they simply do not want chattered at — and only the fast
/// end is a wire fact they cannot overrule.
///
/// Called once per cadence, with that cadence's own cycle: the TX watch is a
/// single short exchange and the meter read is several, so on a slow link
/// the same stated interval is affordable for one and not the other.
Duration telemetryIntervalFor(
  Map<String, dynamic> config, {
  required int cycleBytes,
  int? baudRate,
}) {
  final floor = telemetryFloor(cycleBytes: cycleBytes, baudRate: baudRate);
  final asked = _millisFromConfig(config[telemetryIntervalConfigKey]);
  final wanted = asked == null
      ? (kTelemetryInterval > floor ? kTelemetryInterval : floor)
      : Duration(milliseconds: asked);
  return wanted < floor ? floor : wanted;
}

/// A number field stores a num; an override pins an int; a value typed into
/// a text-shaped form arrives as a String. Same three shapes
/// [voiceMemoriesFromConfig] handles, for the same reason.
int? _millisFromConfig(dynamic raw) {
  final value = raw is num ? raw.round() : (raw is String ? int.tryParse(raw.trim()) : null);
  return value != null && value > 0 ? value : null;
}

/// Watches for the radio to be keyed, and reads its meters while it is.
///
/// Two cadences from one setting, because the two questions cost different
/// amounts on the wire. Watching is a single short exchange — "are you
/// transmitting?" — and has to be quick or a whole over is missed. Reading
/// the meters is several exchanges, and on a slow link cannot be asked as
/// often. The operator states ONE number; each cadence is that number held
/// against its own floor.
///
/// The session owns one of these and tells it what the radio said; it owns
/// no protocol and asks the radio nothing itself.
class TelemetryPoller {
  /// How often to ask whether the radio is keyed.
  final Duration idleInterval;

  /// How often to read the meters once it is.
  final Duration txInterval;

  /// [transmitting] says which question to ask: the driver sends its TX
  /// query when false, and its meter cycle when true. One callback rather
  /// than two, because on every protocol here the answer comes back through
  /// the same parser either way.
  final void Function(bool transmitting) onPoll;

  Timer? _timer;

  /// Null until the radio has answered once. The first answer is NEWS even
  /// when it is "receiving": the app's other half of this
  /// ([RadioTelemetry.transmitting]) distinguishes a radio that says it is
  /// receiving from one that cannot say at all, and a driver that reported
  /// only changes would leave every rig in the second state until its
  /// operator first keyed it.
  bool? _known;

  bool _watching = false;

  TelemetryPoller({
    required this.onPoll,
    this.idleInterval = kTelemetryInterval,
    this.txInterval = kTelemetryInterval,
  });

  bool get isRunning => _timer != null;

  /// Whether the radio is keyed, as the session last heard it — false while
  /// it has not said, which is what the cadence needs. Callers that must
  /// tell silence from "receiving" read [known].
  bool get transmitting => _known ?? false;

  /// What the radio last said, or null if it never has.
  bool? get known => _known;

  /// The interval in force — for tests and diagnostics, as
  /// [AdaptivePoller.interval] is.
  Duration get interval => transmitting ? txInterval : idleInterval;

  /// Begin watching for the radio to key, on connect.
  ///
  /// Optional: a session that learns of transmission some other way — the
  /// Placeholder Radio, which keys itself, or a protocol that PUSHES its
  /// interlock state — never calls this and spends nothing watching. It
  /// still gets its meters read, because that starts from
  /// [noteTransmitting].
  void start() {
    _watching = true;
    _schedule();
  }

  /// The radio said it is keyed, or that it is not.
  ///
  /// A meter read fires IMMEDIATELY on the transition into transmit rather
  /// than after the first interval: a short call — an S&P "N0DEV" — can be
  /// over inside one poll period, and a strip that only ever lit up for long
  /// overs would miss precisely the SWR that matters, the one on a band the
  /// operator has just moved to.
  ///
  /// Repeated reports of the SAME state are not transitions, and must not
  /// restart the timer — the TX watch answers on every cycle, and a poller
  /// that took each answer as news would reset its own timer forever and
  /// never ask again.
  ///
  /// Answers whether this was news, so the caller reports to its sink
  /// exactly when the poller acts. Two places deciding that separately is
  /// how a driver ends up waking every listener five times a second.
  bool noteTransmitting(bool transmitting) {
    if (_known == transmitting) return false;
    _known = transmitting;
    if (transmitting) {
      _fire();
      _schedule();
    } else {
      // The readings stand where they are — see [meterLinger]. Clearing them
      // here would blank the panel at the exact moment the operator lets go
      // of the key and looks down at it.
      _schedule();
    }
    return true;
  }

  /// Stops polling without deciding anything about the radio.
  ///
  /// NOT [noteTransmitting] with false, which is the radio SAYING it
  /// unkeyed: this is the app standing down — a session tearing down, a
  /// connection going away. What was last heard is kept, so the radio saying
  /// "transmitting" again is a fresh transition and starts a fresh cycle
  /// rather than being deduped away as a restatement.
  void stop() {
    _watching = false;
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stop();
    _known = null;
  }

  /// Nothing is scheduled while the radio is receiving and nobody asked for
  /// the watch: a session that knows its own keying pays for no polls at
  /// all.
  void _schedule() {
    _timer?.cancel();
    if (!_watching && !transmitting) {
      _timer = null;
      return;
    }
    _timer = Timer(interval, () {
      _fire();
      _schedule();
    });
  }

  void _fire() {
    try {
      onPoll(transmitting);
    } catch (e) {
      // Caught for the same reason AdaptivePoller catches: a driver throwing
      // in here must not end telemetry for the life of the connection, and
      // must not escape into the zone.
      debugPrint('[cat] telemetry poll failed, continuing: $e');
    }
  }
}
