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
import '../driver.dart';
import '../equipment.dart';

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

  /// Exercised against a real IC-705 behind `rigctld -m 3085` over USB
  /// serial, not just the dummy backend (`-m 1`) — a real backend proves
  /// the daemon's answers track an actual radio. Which rigs rigctld
  /// itself handles well is Hamlib's contract, not this driver's.
  @override
  bool get hardwareVerified => true;

  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) => RigctldSession(sink);
}

/// Hamlib's `RFPOWER` level (unlike `RFPOWER_METER_WATTS`, see [setPower])
/// is genuinely settable, but expressed as a 0.0-1.0 fraction of the rig's
/// own maximum — a fact rigctld has no command to state. 100W stands in
/// for that maximum the same way the other four drivers' relative-scale
/// conversions do; wrong for a QRP or a high-power station.
const _assumedMaxWatts = 100;

class RigctldSession implements EquipmentSession {
  final EquipmentSink _sink;

  RigctldSession(this._sink);

  late final AdaptivePoller _poller = AdaptivePoller(onPoll: _requestFrequencyAndMode);

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

  @override
  void handleData(Uint8List chunk) {
    // Anything at all defers the next poll — the daemon just answered, so
    // asking again now would repeat a question we hold the answer to.
    _poller.noteData();
    for (final byte in chunk) {
      if (byte == _lineFeed) {
        _handleLine(ascii.decode(_residual, allowInvalid: true));
        _residual.clear();
      } else if (byte != _carriageReturn) {
        _residual.add(byte);
      }
    }
  }

  void _handleLine(String line) {
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
      if (watts != null) _sink.reportPower(watts);
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
  }

  @override
  void stopUpdates() => _poller.stop();


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
  }
}
