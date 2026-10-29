// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What a scene's `radio.` dial values read, from CAT. They keep `readRadio`'s
// rules, so a scene and the render beside it never disagree: the frequency and
// mode are the last the radio gave, connected or not, and the rest is only
// what a live radio says now.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/operation/panel_scene/cat_spectrum_source.dart';

class _Transceiver extends Fake implements EquipmentType {
  @override
  String get category => kCategoryTransceiver;
}

class _Cat extends Fake implements CatService {
  EquipmentState state = const EquipmentState(
    status: EquipmentStatus.connected,
    vfo: VfoReading(freqKHz: 14074.5, mode: 'USB'),
    passband: Passband(100, 2800),
    power: 50,
    tuner: TunerStatus.inline,
  );
  bool ptt = false;
  bool logging = true;

  @override
  EquipmentState stateFor(String uuid) => state;
  @override
  EquipmentNode? nodeFor(String uuid) => nodes.first;
  @override
  ({double? swrAverage, int endedAtMillis})? lastTransmissionFor(String uuid) => null;
  @override
  double? swrAverageFor(String uuid) => null;
  @override
  bool pttHeldOn(String? uuid) => ptt;
  @override
  bool isRadio1(String uuid) => logging;
  @override
  bool isRadio2(String uuid) => false;
  @override
  List<EquipmentNode> get nodes => const [EquipmentNode(uuid: 'a', typeKey: 'test')];
  @override
  EquipmentType? typeFor(EquipmentNode node) => _Transceiver();
}

class _Settings extends Fake implements SettingsService {
  final bool keyer;
  _Settings({this.keyer = true});
  @override
  bool experimentEnabled(String key) => key == 'keyer' && keyer;
}

void main() {
  test('a live radio gives its whole dial', () {
    final source = CatSpectrumSource(_Cat()..ptt = true, settings: _Settings());
    expect(source.readings('a'), {
      'secondsSinceTransmit': 1e9,
      'frequencyHz': 14074500,
      'passbandLowHz': 100,
      'passbandHighHz': 2800,
      'passbandWidthHz': 2700,
      'powerWatts': 50,
      'ptt': 1,
      'connected': 1,
    });
    expect(source.readingStrings('a'), {'mode': 'USB', 'tuner': 'inline', 'status': 'connected'});
  });

  test('PTT is given only where `readRadio` gives keying', () {
    // A scene that showed `radio.ptt` where the render beside it reads no `keying` would tell the
    // operator about a latch the app does not offer them: on a host without keying, or on a radio
    // it does not key with.
    expect(CatSpectrumSource(_Cat()..ptt = true, settings: _Settings(keyer: false)).readings('a'), isNot(contains('ptt')));
    expect(CatSpectrumSource(_Cat()..ptt = true).readings('a'), isNot(contains('ptt')), reason: 'no settings reads as off');
    expect(
      CatSpectrumSource(
        _Cat()
          ..ptt = true
          ..logging = false,
        settings: _Settings(),
      ).readings('a'),
      isNot(contains('ptt')),
    );
    expect(CatSpectrumSource(_Cat()..ptt = true, settings: _Settings()).readings('a')['ptt'], 1);
  });

  test('a radio that drops keeps its frequency and mode, and nothing it would have to be asked now', () {
    // A readout that blanked on a disconnect would lose the frequency the operator was on — the
    // built-in Radio panel keeps it — while a passband or a tuner state is only true of a live radio.
    final cat = _Cat();
    cat.state = EquipmentState(status: EquipmentStatus.disconnected, vfo: cat.state.vfo, passband: cat.state.passband, power: 50, tuner: TunerStatus.inline);
    final source = CatSpectrumSource(cat);
    expect(source.readings('a'), {'secondsSinceTransmit': 1e9, 'frequencyHz': 14074500, 'connected': 0});
    expect(source.readingStrings('a'), {'mode': 'USB', 'status': 'disconnected'});
  });

  test('the dial a `radio` trigger compares moves with the VFO and the mode, never with a meter', () {
    final cat = _Cat();
    final source = CatSpectrumSource(cat);
    final before = source.dialState();
    cat.state = EquipmentState(
      status: EquipmentStatus.connected,
      vfo: cat.state.vfo,
      passband: cat.state.passband,
      power: cat.state.power,
      tuner: cat.state.tuner,
      telemetry: const RadioTelemetry(transmitting: false),
    );
    expect(source.dialState(), isNot(before), reason: 'transmit state is part of the dial');
    // A meter moves several times a second: in the dial, every S-meter flicker would render the panel.
    final at = nowMillis();
    cat.state = EquipmentState(
      status: EquipmentStatus.connected,
      vfo: cat.state.vfo,
      passband: cat.state.passband,
      power: cat.state.power,
      tuner: cat.state.tuner,
      telemetry: RadioTelemetry(transmitting: false, meters: {RadioMeter.signalDbm: MeterReading(-73, at), RadioMeter.powerOut: MeterReading(0, at)}),
    );
    final metered = source.dialState();
    expect(source.readings('a')['signalDbm'], -73, reason: 'the meter is live, so its absence from the dial is a choice');
    cat.state = EquipmentState(
      status: EquipmentStatus.connected,
      vfo: cat.state.vfo,
      passband: cat.state.passband,
      power: cat.state.power,
      tuner: cat.state.tuner,
      telemetry: RadioTelemetry(transmitting: false, meters: {RadioMeter.signalDbm: MeterReading(-91, at), RadioMeter.powerOut: MeterReading(0, at)}),
    );
    expect(source.dialState(), metered);
    final settled = source.dialState();
    // A power setting is not the dial: the band map has nothing to redraw for it.
    cat.state = EquipmentState(
      status: EquipmentStatus.connected,
      vfo: cat.state.vfo,
      passband: cat.state.passband,
      power: 5,
      tuner: cat.state.tuner,
      telemetry: cat.state.telemetry,
    );
    expect(source.dialState(), settled);
    cat.state = EquipmentState(
      status: EquipmentStatus.connected,
      vfo: const VfoReading(freqKHz: 7030, mode: 'CW'),
      passband: cat.state.passband,
      telemetry: cat.state.telemetry,
    );
    expect(source.dialState(), isNot(settled));
  });
}
