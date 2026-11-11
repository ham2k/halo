// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// An antenna switch that is only ever as far away as this object: as many
// antennas and radio ports as its settings say, every selection taken at
// once. Paired with placeholder_transport.dart, for
// placeholder_radio_driver.dart's reason: it exercises everything above a
// switch driver — the Station panel's ports, antenna links and selections —
// on a build with no switch, the web included. It proves nothing about any
// real switch, and refuses nothing a real one would: it has no RF to guard.

import 'dart:async';
import 'dart:typed_data';

import 'package:halo_i18n/halo_i18n.dart';
import '../driver.dart';
import '../equipment.dart';

const simulatedSwitchAntennasConfigKey = 'simulatedAntennas';
const simulatedSwitchRadiosConfigKey = 'simulatedRadios';

/// An Antenna Genius' eight by two, the shape most worth exercising: more
/// than one radio, so two ports can contend for one antenna.
const simulatedSwitchDefaultAntennas = 8, simulatedSwitchDefaultRadios = 2;

/// As many of each as the Station panel lays out sensibly; the radio ports
/// are lettered, so no more than the alphabet's first few.
const simulatedSwitchMaxAntennas = 16, simulatedSwitchMaxRadios = 8;

/// How often it restates its state: well inside `catStaleAfter`, which would
/// otherwise call a switch nobody is touching one that stopped answering.
const _restateEvery = Duration(seconds: 10);

int _countFrom(Map<String, dynamic> config, String key, int fallback) {
  final raw = config[key];
  return (raw is num ? raw.toInt() : int.tryParse('${raw ?? ''}'.trim())) ?? fallback;
}

class SimulatedSwitchDriver extends EquipmentDriver {
  const SimulatedSwitchDriver();

  @override
  String get key => 'simulated-switch';

  @override
  String get name => 'Simulated Antenna Switch';

  /// The defaults: what the editor offers to link antennas to before the
  /// switch has connected and said how many it has.
  @override
  int get antennaPortCount => simulatedSwitchDefaultAntennas;

  @override
  int get devicePortCount => simulatedSwitchDefaultRadios;

  @override
  List<Map<String, dynamic>> configElements({Map<String, dynamic> overrides = const {}, Map<String, dynamic> restrictions = const {}}) {
    final st = t.settings.station;
    return [
      if (!overrides.containsKey(simulatedSwitchAntennasConfigKey))
        {'type': 'field', 'fieldType': 'number', 'key': simulatedSwitchAntennasConfigKey, 'label': st.simulatedSwitchAntennas},
      if (!overrides.containsKey(simulatedSwitchRadiosConfigKey))
        {'type': 'field', 'fieldType': 'number', 'key': simulatedSwitchRadiosConfigKey, 'label': st.simulatedSwitchRadios},
    ];
  }

  @override
  String? validateField(String key, dynamic value, Map<String, dynamic> config) {
    final max = switch (key) {
      simulatedSwitchAntennasConfigKey => simulatedSwitchMaxAntennas,
      simulatedSwitchRadiosConfigKey => simulatedSwitchMaxRadios,
      _ => null,
    };
    if (max == null) return null;
    final count = _countFrom({key: value}, key, 0);
    return count < 1 || count > max ? t.settings.station.simulatedSwitchCountInvalid(min: 1, max: max) : null;
  }

  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) => SimulatedSwitchSession(
    sink,
    antennas: _countFrom(config, simulatedSwitchAntennasConfigKey, simulatedSwitchDefaultAntennas).clamp(1, simulatedSwitchMaxAntennas),
    radios: _countFrom(config, simulatedSwitchRadiosConfigKey, simulatedSwitchDefaultRadios).clamp(1, simulatedSwitchMaxRadios),
  );
}

class SimulatedSwitchSession implements AntennaSwitchSession {
  final EquipmentSink _sink;
  final int antennas, radios;

  /// Each radio port's antenna, by port key: radio port n starts on antenna
  /// n, so every port shows a selection from the first reading.
  final Map<String, String?> _selected;

  SimulatedSwitchSession(this._sink, {required this.antennas, required this.radios})
    : _selected = {for (var port = 1; port <= radios; port++) '$port': port <= antennas ? '$port' : null};

  Timer? _restate;

  /// Antennas and ports numbered from 1, as a real switch's are; the radio
  /// ports lettered on the front, as an Antenna Genius' are. Antennas carry
  /// no name of their own, so the Station panel words them by number.
  void _publish() => _sink.reportSwitchState(
    [for (var antenna = 1; antenna <= antennas; antenna++) SwitchAntenna(key: '$antenna', name: '')],
    [
      for (final MapEntry(key: port, value: antenna) in _selected.entries)
        SwitchPort(key: port, label: String.fromCharCode(0x40 + int.parse(port)), selectedAntennaKey: antenna),
    ],
  );

  @override
  void handleData(Uint8List chunk) {}

  @override
  void startUpdates() {
    _publish();
    _restate?.cancel();
    _restate = Timer.periodic(_restateEvery, (_) => _publish());
  }

  @override
  void stopUpdates() {
    _restate?.cancel();
    _restate = null;
  }

  @override
  void teardown() => stopUpdates();

  @override
  Duration? get expectedUpdateInterval => null;

  @override
  void selectAntenna(String portKey, String antennaKey) {
    final antenna = int.tryParse(antennaKey);
    if (!_selected.containsKey(portKey) || antenna == null || antenna < 1 || antenna > antennas) return;
    _selected[portKey] = antennaKey;
    _publish();
  }

  @override
  String toString() => 'SimulatedSwitchSession($antennas×$radios, $_selected)';
}
