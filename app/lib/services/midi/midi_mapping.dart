// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A MIDI controller node's config: which device, which control drives which
// target, and each target's options. Controls and options are kept apart so
// that clearing or re-learning a control keeps the row's step and coding.

import 'midi_codec.dart';
import 'midi_targets.dart';

/// The device's name, as the platform lists it. Bound by name, not id: an id
/// is the platform's own and does not survive a replug on every one.
const midiDeviceConfigKey = 'device';
const midiControlsConfigKey = 'controls';
const midiOptionsConfigKey = 'options';

/// Per-row option keys.
const midiOptStepPhone = 'stepPhone', midiOptStepCw = 'stepCw', midiOptCoding = 'coding', midiOptPtt = 'ptt';

/// [midiOptPtt]'s values: transmit while held, or each press flips.
const midiPttHold = 'hold', midiPttToggle = 'toggle';

class MidiMapping {
  final String? device;
  final Map<String, MidiControl> controls;
  final Map<String, Map<String, dynamic>> options;
  final Map<MidiControl, String> _byControl;

  MidiMapping({this.device, this.controls = const {}, this.options = const {}}) : _byControl = {for (final e in controls.entries) e.value: e.key};

  factory MidiMapping.fromConfig(Map<String, dynamic> config) {
    final controls = <String, MidiControl>{};
    if (config[midiControlsConfigKey] case final Map<dynamic, dynamic> stored) {
      for (final MapEntry(:key, :value) in stored.entries) {
        final target = key is String ? midiTargetById(key) : null;
        final control = MidiControl.fromJson(value);
        // A target that no longer exists, or a control its kind cannot take,
        // is dropped rather than left to act as something else.
        if (target != null && control != null && target.kind.accepts.contains(control.kind)) controls[target.id] = control;
      }
    }
    final options = <String, Map<String, dynamic>>{};
    if (config[midiOptionsConfigKey] case final Map<dynamic, dynamic> stored) {
      for (final MapEntry(:key, :value) in stored.entries) {
        if (key is String && value is Map) options[key] = Map<String, dynamic>.from(value);
      }
    }
    final device = config[midiDeviceConfigKey];
    return MidiMapping(device: device is String && device.isNotEmpty ? device : null, controls: controls, options: options);
  }

  /// The target [control] drives here, if any.
  String? targetFor(MidiControl control) => _byControl[control];

  /// [config] with [control] driving [targetId] — and no longer driving
  /// anything else, since one control drives one target. Null clears it.
  static Map<String, dynamic> assign(Map<String, dynamic> config, String targetId, MidiControl? control) {
    final current = MidiMapping.fromConfig(config).controls;
    final next = <String, dynamic>{
      for (final MapEntry(:key, :value) in current.entries)
        if (key != targetId && value != control) key: value.toJson(),
      if (control != null) targetId: control.toJson(),
    };
    return {...config, midiControlsConfigKey: next};
  }

  /// [config] with one option of one row set.
  static Map<String, dynamic> setOption(Map<String, dynamic> config, String targetId, String key, Object value) {
    final all = MidiMapping.fromConfig(config).options;
    return {
      ...config,
      midiOptionsConfigKey: {
        ...all,
        targetId: {...?all[targetId], key: value},
      },
    };
  }

  /// Hz per tick for [target] in a CW mode ([cw]) or any other.
  int stepFor(MidiTarget target, {required bool cw}) {
    final stored = options[target.id]?[cw ? midiOptStepCw : midiOptStepPhone];
    if (stored is int && stored > 0) return stored;
    return cw ? target.stepCw : target.stepPhone;
  }

  MidiEncoderCoding codingFor(String targetId) => MidiEncoderCoding.fromName(options[targetId]?[midiOptCoding]);

  bool pttToggles(String targetId) => options[targetId]?[midiOptPtt] == midiPttToggle;
}
