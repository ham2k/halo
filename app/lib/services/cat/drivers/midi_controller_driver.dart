// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A MIDI controller node's place in the catalogue. CAT never connects it —
// its transport is `none` — and its config (device, mapping) is edited in its
// own pane (midi_controller_pane.dart) rather than the equipment form: Learn
// writes the mapping while the pane is open, which a form that saves the
// config it opened with would undo.

import '../../midi/midi_mapping.dart';
import '../driver.dart';

class MidiControllerDriver extends EquipmentDriver {
  const MidiControllerDriver();

  @override
  String get key => 'midiController';

  @override
  String get name => 'MIDI Controller';

  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) =>
      throw UnsupportedError('$key has no session to create — MidiService binds its device');

  /// The device's name, as the whole subtitle — see TypeOnlyEquipmentDriver's.
  @override
  String? describeSuffix(Map<String, dynamic> config, {Map<String, dynamic> overrides = const {}}) => MidiMapping.fromConfig(config).device;
}
