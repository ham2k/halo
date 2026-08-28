// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A radio that is only ever as far away as this object: it holds frequency,
// mode and power, accepts every set, and reports each one straight back.
// Paired with fake_transport.dart, which explains why the pair exists.
//
// It speaks no protocol and puts nothing on the wire, so it proves nothing
// about any real driver — what it exercises is everything ABOVE a driver,
// which on a web build is otherwise unreachable for want of a socket. A
// protocol emulator (a driver's own bytes parsed and answered) would be a
// different thing living at the transport, and is not this.
//
// It PUSHES: [expectedUpdateInterval] is null, which is a claim Smart VFO
// Snap acts on (docs/design/cat.md § Smart VFO Snap) — silence means the
// radio is not moving, rather than nobody having asked.

import 'dart:async';
import 'dart:typed_data';

import '../../../i18n/strings.g.dart';
import '../driver.dart';
import '../equipment.dart';
import '../transports/config_field_helpers.dart';

/// Where a new fake rig comes up, so it lands somewhere plausible rather
/// than reporting nothing at all — 40m phone, at a typical barefoot output.
const fakeRadioDefaultFreqKHz = 7200.0;
const fakeRadioDefaultMode = 'LSB';
const fakeRadioDefaultWatts = 75;

/// Null for a value no parse accepts, rather than the default: the caller
/// that READS applies the default, the caller that VALIDATES rejects the
/// null. One parse for both, so a frequency that passes the editor is the
/// frequency the session comes up on.
double? freqFromConfig(Map<String, dynamic> config) {
  final raw = config['fakeFreq'];
  if (raw is num) return raw.toDouble();
  return double.tryParse('$raw'.trim());
}

/// Tolerant of a non-String, like every other read in this layer: a stored
/// node's config has been round-tripped through JSON, and an `as String`
/// here would throw out of `createSession` — which `CatService` does not
/// guard, so the throw would escape with the connection already open and
/// its drop timer still running.
String modeFromConfig(Map<String, dynamic> config) {
  final raw = '${config['fakeMode'] ?? ''}'.trim().toUpperCase();
  return raw.isEmpty ? fakeRadioDefaultMode : raw;
}

/// A mode token this driver will hand upward. Deliberately a shape rather
/// than the app's mode list: the point of a fake rig is trying modes,
/// including ones no catalogue radio supports. But a reading goes through
/// `RadioService` onto logged QSOs and out to ADIF, so a fat-fingered
/// `US B` must not get that far.
final _modeToken = RegExp(r'^[A-Z0-9][A-Z0-9/-]*$');

class FakeRadioDriver extends EquipmentDriver {
  const FakeRadioDriver();

  @override
  String get key => 'fake-radio';

  /// First word is what an equipment report prefills as the manufacturer,
  /// so it stays a plain word with no protocol or parenthesis in it — see
  /// equipment_report_test.dart.
  @override
  String get name => 'Fake Radio';

  /// True, not because a radio was ever on the bench but because there is
  /// none to be: the picker's caveat is about a driver that might not work
  /// against real hardware, and this one has no hardware to disappoint.
  @override
  bool get hardwareVerified => true;

  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) =>
      FakeRadioSession(sink, config);

  @override
  List<Map<String, dynamic>> configElements({
    Map<String, dynamic> overrides = const {},
    Map<String, dynamic> restrictions = const {},
  }) =>
      [
        if (!overrides.containsKey('fakeFreq'))
          {
            'type': 'field',
            'fieldType': 'number',
            'key': 'fakeFreq',
            'label': t.settings.station.fakeFreq,
            'description': t.settings.station.fakeFreqDescription,
          },
        if (!overrides.containsKey('fakeMode'))
          {
            'type': 'field',
            'fieldType': 'text',
            'key': 'fakeMode',
            'label': t.settings.station.fakeMode,
            'description': t.settings.station.fakeModeDescription,
          },
        if (!overrides.containsKey('fakePower'))
          {
            'type': 'field',
            'fieldType': 'number',
            'key': 'fakePower',
            'label': t.settings.station.fakePower,
          },
        if (!overrides.containsKey('fakeReplyDelay'))
          {
            'type': 'field',
            'fieldType': 'number',
            'key': 'fakeReplyDelay',
            'label': t.settings.station.fakeReplyDelay,
            'description': t.settings.station.fakeReplyDelayDescription,
          },
      ];

  /// Blank is rejected on every numeric field, and prefilled by
  /// [EquipmentVariant.defaultConfig] so it never comes up unasked — see
  /// FakeTransport.validateField for why null cannot be waved through.
  @override
  String? validateField(String key, dynamic value, Map<String, dynamic> config) {
    switch (key) {
      case 'fakeFreq':
        final freq = freqFromConfig({...config, key: value});
        return (freq == null || freq <= 0) ? t.settings.station.fakeFreqInvalid : null;
      case 'fakePower':
      case 'fakeReplyDelay':
        return numberFromConfig({...config, key: value}, key, -1) < 0
            ? t.settings.station.fakeWholeNumberInvalid
            : null;
      case 'fakeMode':
        // Blank IS allowed here, and means the default: a `text` field hands
        // over the string the operator typed, so an empty box is empty and
        // nothing else — none of the number field's ambiguity.
        final mode = '${value ?? ''}'.trim().toUpperCase();
        return (mode.isEmpty || _modeToken.hasMatch(mode)) ? null : t.settings.station.fakeModeInvalid;
      default:
        return null;
    }
  }
}

class FakeRadioSession implements TransceiverSession {
  final EquipmentSink _sink;

  /// How long a set takes to come back as a reading. Zero reports
  /// synchronously — a `Timer` of `Duration.zero` still defers a turn, and
  /// a test asserting on the reading would then have to pump for a rig that
  /// is meant to be instant.
  final Duration _replyDelay;

  double _freqKHz;
  String _mode;
  num _watts;

  /// Pending reports, so [teardown] can drop them: a timer that survives
  /// the session reports a reading for a connection that is gone.
  final _pending = <Timer>[];

  /// Restates the current reading often enough that `CatService`'s silence
  /// watch never fires (`_staleAfter`, 30s). Without it a fake rig left
  /// alone turns stale in half a minute and the panel says the radio has
  /// stopped answering — which is exactly the state an operator leaves it
  /// sitting in while checking something else. A restated frequency is a
  /// no-op everywhere it lands: `_applyReading` skips an unchanged VFO and
  /// `VfoSnapper.report` refuses to extend a burst on one.
  Timer? _heartbeat;

  static const _heartbeatInterval = Duration(seconds: 10);

  FakeRadioSession(this._sink, Map<String, dynamic> config)
      : _replyDelay = Duration(milliseconds: numberFromConfig(config, 'fakeReplyDelay', 0)),
        _freqKHz = freqFromConfig(config) ?? fakeRadioDefaultFreqKHz,
        _mode = modeFromConfig(config),
        _watts = numberFromConfig(config, 'fakePower', fakeRadioDefaultWatts);

  void _afterDelay(void Function() report) {
    if (_replyDelay == Duration.zero) {
      report();
      return;
    }
    late final Timer timer;
    timer = Timer(_replyDelay, () {
      _pending.remove(timer);
      report();
    });
    _pending.add(timer);
  }

  void _reportVfo() => _afterDelay(() => _sink.report(VfoReading(freqKHz: _freqKHz, mode: _mode)));

  /// Nothing ever arrives: the fake transport's connection never emits.
  @override
  void handleData(Uint8List chunk) {}

  @override
  void startUpdates() {
    // One word, in the equipment row's developer-mode slot between the
    // frequency and the status pill: a green row moving through frequencies
    // is exactly what a real rig looks like, and this is the only thing on
    // screen that says none is attached. A sentence would crowd out the
    // reading it sits beside.
    _sink.reportDiagnostic(t.settings.station.fakeDiagnostic);
    _reportVfo();
    _afterDelay(() => _sink.reportPower(_watts));
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(_heartbeatInterval, (_) => _reportVfo());
  }

  /// Drops the pending replies along with the heartbeat: after this the
  /// session is not reporting, and a set whose delay had not yet elapsed
  /// would otherwise land afterwards as if it were still live.
  @override
  void stopUpdates() {
    _heartbeat?.cancel();
    _heartbeat = null;
    for (final timer in _pending) {
      timer.cancel();
    }
    _pending.clear();
  }

  @override
  void setFrequency(double freqKHz) {
    _freqKHz = freqKHz;
    _reportVfo();
  }

  @override
  void setMode(String mode) {
    _mode = mode;
    _reportVfo();
  }

  @override
  void setPower(num watts) {
    _watts = watts;
    _afterDelay(() => _sink.reportPower(_watts));
  }

  /// Null, not a short interval: this session reports a change as it
  /// happens, so a quiet VFO is a settled one.
  @override
  Duration? get expectedUpdateInterval => null;

  @override
  void teardown() => stopUpdates();
}
