// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Speaks the Hamlib `rigctld` network protocol: line-oriented ASCII over a
// TCP stream to a daemon the operator already runs, which in turn drives
// any of the hundreds of radios Hamlib has a backend for — one codec, the
// whole catalogue (docs/design/cat.md, roadmap).
//
// rigctld pushes nothing: it only ever answers questions, so this driver is
// poll-driven end to end, on the same AdaptivePoller cadence as the FT-891.
//
// Reads use the extended-response protocol (the `+` prefix): a plain `f`
// answers with a bare number and a plain `m` with a bare word, and with two
// questions outstanding on one stream the answers can only be told apart by
// keeping a queue of what was asked — which one dropped response desyncs
// for the life of the connection. `+f` answers with a self-labeling
// `Frequency: 14250000` line, so every line parses on its own.
//
// Writes are plain commands (`F`, `M`); their `RPRT n` acknowledgements are
// deliberately ignored. A rejected set needs no handling of its own — the
// next poll reports the unchanged state, which is the truth on the dial.
//
// Commands address whatever VFO the rig currently has selected. What that
// takes depends on how the daemon was started: plainly, commands carry no
// VFO argument — and a stray token is read as a further command — while in
// `--vfo` mode every command must name one, or the parser consumes the
// next command as the name (a `+f\n+m\n` burst loses the `+m`). The two
// forms are mutually unintelligible, so startUpdates asks `\chk_vfo`
// first and the session adapts — the same negotiation rigctl's own NET
// backend performs.

import 'dart:convert';
import 'dart:typed_data';

import '../adaptive_poller.dart';
import '../telemetry_poller.dart';
import '../driver.dart';
import '../equipment.dart';
import 'telemetry_config.dart';

const _lineFeed = 0x0a;
const _carriageReturn = 0x0d;

/// App mode names → Hamlib mode tokens, where the spellings differ. The
/// app's names follow the Yaesu-flavored table the rest of the codebase
/// uses (`CW-R`, `DATA-USB`); Hamlib writes them as one token (`CWR`,
/// `PKTUSB`) and calls both RTTY sidebands `RTTY`/`RTTYR`.
const hamlibModesByAppMode = <String, String>{
  'CW-R': 'CWR',
  'FM-N': 'FMN',
  'AM-N': 'AMN',
  'DATA-USB': 'PKTUSB',
  'DATA-LSB': 'PKTLSB',
  'DATA-FM': 'PKTFM',
  'RTTY-LSB': 'RTTY',
  'RTTY-USB': 'RTTYR',
};

const appModesByHamlibMode = <String, String>{
  'CWR': 'CW-R',
  'FMN': 'FM-N',
  'AMN': 'AM-N',
  'PKTUSB': 'DATA-USB',
  'PKTLSB': 'DATA-LSB',
  'PKTFM': 'DATA-FM',
  // Without these, a set round-trips as raw 'RTTYR' — a spelling no other
  // surface of the app uses. Plain RTTY is the conventional (LSB) side.
  'RTTY': 'RTTY-LSB',
  'RTTYR': 'RTTY-USB',
};

final _hamlibModeToken = RegExp(r'^[A-Z0-9]+$');

/// The Hamlib token to send for an app mode, or null for a mode that can't
/// be expressed as one — the caller sends nothing rather than a command
/// with a malformed argument. Pass-through is deliberate: Hamlib's mode
/// list is far longer than any table here, and an unknown-to-us token costs
/// only an `RPRT` error from a daemon that doesn't know it either.
String? hamlibModeForAppMode(String? mode) {
  if (mode == null) return null;
  final upper = mode.toUpperCase();
  final mapped = hamlibModesByAppMode[upper] ?? upper;
  return _hamlibModeToken.hasMatch(mapped) ? mapped : null;
}

/// The app's name for a Hamlib mode token. Tokens without an app spelling
/// (WFM, PSK, …) pass through unchanged, the way the FlexRadio driver
/// reports whatever the radio said.
String appModeForHamlibMode(String token) {
  final upper = token.toUpperCase();
  return appModesByHamlibMode[upper] ?? upper;
}

class RigctldDriver extends EquipmentDriver {
  const RigctldDriver();

  /// rigctld's own default (`-t` changes it).
  static const defaultPort = 4532;

  @override
  String get key => 'rigctld';

  @override
  String get name => 'Hamlib rigctld';


  /// The levels Hamlib defines for these, all of them read-only meters. No
  /// ALC-free or SWR-free backend is excluded by declaring them: a level a
  /// backend does not implement answers `RPRT -11`, which this driver
  /// ignores like every other error, and the slot simply stays empty.
  @override
  Set<RadioMeter> get telemetryMeters =>
      const {RadioMeter.powerOut, RadioMeter.swr, RadioMeter.alc, RadioMeter.supplyVolts};

  /// The meter cadence, and nothing else: where the daemon is listening is
  /// the TCP transport's question.
  @override
  List<Map<String, dynamic>> configElements({
    Map<String, dynamic> overrides = const {},
    Map<String, dynamic> restrictions = const {},
  }) =>
      [telemetryConfigElement()];

  @override
  String? validateField(String key, dynamic value, Map<String, dynamic> config) =>
      key == telemetryIntervalConfigKey ? validateTelemetryInterval(value) : null;

  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) => RigctldSession(sink, config);
}

/// Hamlib's `RFPOWER` level (unlike `RFPOWER_METER_WATTS`, see [setPower])
/// is genuinely settable, but expressed as a 0.0-1.0 fraction of the rig's
/// own maximum — a fact rigctld has no command to state. 100W stands in
/// for that maximum the same way the other four drivers' relative-scale
/// conversions do; wrong for a QRP or a high-power station.
const _assumedMaxWatts = 100;

class RigctldSession implements TransceiverSession {
  final EquipmentSink _sink;

  RigctldSession(this._sink, [this._config = const {}]);

  final Map<String, dynamic> _config;

  late final AdaptivePoller _poller = AdaptivePoller(onPoll: _requestFrequencyAndMode);

  /// Watches for the operator to key the rig, and reads its meters while
  /// they hold it — telemetry_poller.dart, and the opposite rule to
  /// [_poller]'s.
  ///
  /// Both cadences take the flat default: rigctld is reached over TCP, and
  /// the serial link on the far side of the daemon is one this app never
  /// sees and cannot budget for.
  late final TelemetryPoller _telemetry = TelemetryPoller(
    onPoll: _pollTelemetry,
    idleInterval: telemetryIntervalFor(_config, cycleBytes: 0),
    txInterval: telemetryIntervalFor(_config, cycleBytes: 0),
  );

  /// What was last reported upward, so a repeat can be told from a move —
  /// the poller's fast/slow choice rides on this, same as the FT-891's.
  VfoReading? _lastReported;

  /// Bytes received since the last complete line.
  final _residual = <int>[];

  /// Whether the daemon parses a VFO name on every command (`--vfo` mode),
  /// per its `\chk_vfo` answer. Until that answer lands, commands go out
  /// plain: a `--vfo` daemon still answers a plain `+f` (it loses the `+m`
  /// riding behind it, recovered on the next poll), whereas `currVFO` sent
  /// to a plain daemon is read as further commands and executes garbage.
  bool _vfoMode = false;

  /// The cadence the poller has settled on — for tests, which otherwise
  /// could only infer it from timing.
  Duration get pollInterval => _poller.interval;

  void _send(String command) => _sink.send(ascii.encode('$command\n'));

  /// The VFO argument this daemon's parser requires, `currVFO` meaning
  /// "whatever the rig has selected" — the same addressing plain mode gets
  /// by leaving it off.
  String get _vfo => _vfoMode ? ' currVFO' : '';

  void _requestFrequencyAndMode() {
    _send('+f$_vfo');
    _send('+m$_vfo');
    // Absolute watts, not Hamlib's older 0.0-1.0 RFPOWER fraction of an
    // unknown maximum — this level exists precisely so a front-end can deal
    // in watts without knowing the radio's ceiling. Silently unanswered on
    // a daemon/backend that predates it, same as any other RPRT error this
    // driver ignores; the field just never receives a reading.
    _send('+l$_vfo RFPOWER_METER_WATTS');
  }

  /// One turn of the telemetry cadence. No backlog guard, unlike flrig's:
  /// rigctld labels every extended answer, so a question asked twice is
  /// answered twice and read correctly both times — there is no positional
  /// correlation to fall out of step.
  void _pollTelemetry(bool transmitting) {
    _send('+t$_vfo');
    if (!transmitting) return;
    // RFPOWER_METER_WATTS is already on the state poll (see
    // [_requestFrequencyAndMode]) — it is asked again here because that
    // poll runs at seconds and a transmission is measured in them.
    _send('+l$_vfo RFPOWER_METER_WATTS');
    _send('+l$_vfo SWR');
    _send('+l$_vfo ALC');
    _send('+l$_vfo VD_METER');
  }

  @override
  void handleData(Uint8List chunk) {
    for (final byte in chunk) {
      if (byte == _lineFeed) {
        _handleLine(ascii.decode(_residual, allowInvalid: true));
        _residual.clear();
      } else if (byte != _carriageReturn) {
        _residual.add(byte);
      }
    }
  }

  /// The lines that are the daemon ANSWERING OUR TELEMETRY, rather than
  /// telling us where the radio is. They must not defer the state poll: the
  /// TX watch asks several times a second, and treating its answers as "the
  /// daemon just told us something" re-arms the poll timer before it can
  /// ever fire — leaving the frequency to arrive only on AdaptivePoller's
  /// 9-second staleness ceiling.
  ///
  /// `RFPOWER_METER_WATTS` belongs here even though the STATE poll asks for
  /// it too: the telemetry cycle asks again several times a second while the
  /// radio is keyed, so leaving it out re-armed the poll timer through every
  /// transmission — the same starvation the other three labels are here to
  /// prevent, just harder to see, because it only bit while transmitting.
  /// The state poll's own frequency and mode answers are what defer it, and
  /// they arrive in the same round.
  static const _telemetryLabels = ['PTT: ', 'SWR: ', 'ALC: ', 'VD_METER: ', 'RFPOWER_METER_WATTS: '];

  void _handleLine(String line) {
    // Anything else defers the next poll — the daemon just answered, so
    // asking again now would repeat a question we hold the answer to.
    if (!_telemetryLabels.any(line.startsWith)) _poller.noteData();

    // Extended responses label every value; anything else on the stream —
    // `get_freq:` headers, `Passband:`, `RPRT n` acknowledgements — asks
    // nothing of us.
    // Both spellings of the probe answer: `ChkVFO: 1` is 4.7's extended
    // form, `CHKVFO 1` the older daemons' — netrigctl accepts both, so
    // must we, or an old `--vfo` daemon reads as plain and loses its mode.
    if (line.startsWith('ChkVFO: ')) {
      _vfoMode = line.substring('ChkVFO: '.length).trim() == '1';
    } else if (line.startsWith('CHKVFO ')) {
      _vfoMode = line.substring('CHKVFO '.length).trim() == '1';
    } else if (line.startsWith('Frequency: ')) {
      final hz = double.tryParse(line.substring('Frequency: '.length).trim());
      // The daemon reports Hz; everything above here speaks kHz.
      if (hz != null && hz > 0) {
        _report(VfoReading(freqKHz: double.parse((hz / 1000).toStringAsFixed(3))));
      }
    } else if (line.startsWith('Mode: ')) {
      final token = line.substring('Mode: '.length).trim();
      if (token.isNotEmpty) _report(VfoReading(mode: appModeForHamlibMode(token)));
    } else if (line.startsWith('RFPOWER_METER_WATTS: ')) {
      final watts = double.tryParse(line.substring('RFPOWER_METER_WATTS: '.length).trim());
      if (watts != null) {
        // Both, from the one reading, and they are not the same claim: the
        // app's power is what the station is running at, and the meter is
        // what left the radio a moment ago. Hamlib happens to answer the
        // second everywhere else's protocol answers the first.
        _sink.reportPower(watts);
        // As a METER, only while the radio is actually keyed. This level is
        // also on the state poll, where it reads 0 — and a measured "0 W" on
        // the strip is a different statement from an empty slot: one says
        // the radio put out nothing, the other that there was nothing to
        // measure. The second is what is true between overs.
        if (_telemetry.transmitting) _sink.reportMeter(RadioMeter.powerOut, watts);
      }
    } else if (line.startsWith('PTT: ')) {
      final ptt = int.tryParse(line.substring('PTT: '.length).trim());
      // Anything else is a backend that does not implement it, and is left
      // as "nobody knows" rather than read as receiving.
      if (ptt != null && _telemetry.noteTransmitting(ptt != 0)) _sink.reportTransmitting(ptt != 0);
    } else if (line.startsWith('SWR: ')) {
      final swr = double.tryParse(line.substring('SWR: '.length).trim());
      // Below 1 is physically impossible, so it is a backend answering
      // zero for a meter it does not have — and a 0.0 on the strip reads as
      // a perfect match, the most reassuring way available to be wrong.
      if (swr != null && swr >= 1) _sink.reportMeter(RadioMeter.swr, swr);
    } else if (line.startsWith('ALC: ')) {
      final alc = double.tryParse(line.substring('ALC: '.length).trim());
      // Hamlib's ALC is already a fraction of the backend's own scale.
      if (alc != null) _sink.reportMeter(RadioMeter.alc, alc.clamp(0.0, 1.0));
    } else if (line.startsWith('VD_METER: ')) {
      final volts = double.tryParse(line.substring('VD_METER: '.length).trim());
      if (volts != null) _sink.reportMeter(RadioMeter.supplyVolts, volts);
    }
  }

  /// Reports upward, and tells the poller whether the radio is moving.
  void _report(VfoReading reading) {
    final merged = VfoReading(
      freqKHz: reading.freqKHz ?? _lastReported?.freqKHz,
      mode: reading.mode ?? _lastReported?.mode,
    );
    // The FIRST reading is the answer to the question startUpdates just
    // asked, not the radio moving — see Ft891Session._report.
    final first = _lastReported == null;
    if (merged != _lastReported) {
      _lastReported = merged;
      if (!first) _poller.noteChange();
    }
    _sink.report(reading);
  }

  @override
  void setFrequency(double freqKHz) => _send('F$_vfo ${(freqKHz * 1000).round()}');

  @override
  void setMode(String mode) {
    final token = hamlibModeForAppMode(mode);
    // `-1` leaves the passband unchanged (Hamlib ≥ 3.1), so retuning the
    // mode never clobbers a filter width the operator set at the radio.
    if (token != null) _send('M$_vfo $token -1');
  }

  /// NOT `RFPOWER_METER_WATTS` — Hamlib defines that level read-only (a
  /// measured-output meter), so a `set_level` against it is rejected by
  /// every correctly-implemented backend, not just an old one. `RFPOWER`
  /// is the genuinely settable level, at the cost of [_assumedMaxWatts]'s
  /// conversion — an ignored `RPRT` error here means the daemon/backend
  /// rejected the value outright, same as any other rejected set.
  @override
  void setPower(num watts) =>
      _send('L$_vfo RFPOWER ${(watts / _assumedMaxWatts).clamp(0, 1).toStringAsFixed(3)}');

  @override
  void startUpdates() {
    _residual.clear();
    // Re-learned per connection — a reconnect may reach a daemon restarted
    // the other way. The extended `+` form makes the answer self-labeling
    // (`ChkVFO: 0/1`) in both modes; a daemon too old to know the command
    // answers an unlabeled complaint, which reads as plain mode.
    _vfoMode = false;
    _send('+\\chk_vfo');
    _requestFrequencyAndMode();
    _poller.start();
    _telemetry.start();
  }

  @override
  void stopUpdates() {
    _poller.stop();
    _telemetry.stop();
  }


  /// The poller's CURRENT cadence, not its floor: it runs fast while the
  /// dial is moving and eases off when it isn't, and a caller asking "how
  /// long until I'd hear about a change" wants whichever is in force now.
  @override
  Duration? get expectedUpdateInterval => _poller.interval;

  @override
  void teardown() {
    // Nothing to say goodbye to: rigctld holds no per-client state, so
    // stopping the poll is the whole farewell.
    stopUpdates();
    _telemetry.dispose();
  }
}
