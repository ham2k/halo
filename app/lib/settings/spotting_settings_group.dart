// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/foundation.dart';
import 'package:halo_i18n/halo_i18n.dart';

import 'package:halo_widgets/halo_widgets.dart' show SpottingControlModel;

import '../services/settings_service.dart';
import '../services/spotting_settings.dart';
import 'settings_registry.dart';

/// The Spotting section: auto-respotting's interval, whether it starts
/// without offering, and whether the chip pulses before each one. Its fields are also what the Spotting control's tune
/// button opens (`target: 'spotting'`).
class SpottingSettingsGroup extends SettingsGroup {
  final SettingsService settings;
  SpottingSettingsGroup(this.settings);

  @override
  String get key => SpottingSettings.group;
  @override
  String get title => t.settings.spotting.title;
  @override
  int get order => 12;
  @override
  Listenable get listenable => settings;

  @override
  Future<List<Map<String, dynamic>>> buildElements() async {
    final labels = t.settings.spotting;
    final (:respotInterval, :autoRespotByDefault, :pulseBeforeRespot) = SpottingSettings.read(settings);
    final minutes = '${respotInterval.inMinutes}';
    return [
      {
        'type': 'field',
        'fieldType': 'select',
        'key': SpottingSettings.respotIntervalKey,
        'label': labels.respotInterval,
        'icon': 'timer-refresh-outline',
        'description': labels.minutes(minutes: minutes),
        'value': minutes,
        'options': [
          for (final option in SpottingSettings.respotIntervalOptions) {'label': labels.minutes(minutes: '$option'), 'value': '$option'},
        ],
        'target': 'spotting',
      },
      {
        'type': 'field',
        'fieldType': 'checkbox',
        'key': SpottingSettings.autoRespotByDefaultKey,
        'label': labels.autoRespotByDefault,
        'icon': 'repeat',
        'description': autoRespotByDefault ? labels.autoRespotByDefaultOn : labels.autoRespotByDefaultOff,
        'value': autoRespotByDefault,
        'target': 'spotting',
      },
      {
        'type': 'field',
        'fieldType': 'checkbox',
        'key': SpottingSettings.pulseBeforeRespotKey,
        'label': labels.pulseBeforeRespot,
        'icon': 'pulse',
        'description': pulseBeforeRespot ? labels.pulseBeforeRespotOn(seconds: SpottingControlModel.respotSoonLead.inSeconds) : labels.pulseBeforeRespotOff,
        'value': pulseBeforeRespot,
        'target': 'spotting',
      },
    ];
  }

  @override
  Future<void> commit(String fieldKey, dynamic value) async {
    // The interval is one of its own option strings, each toggle a bool;
    // anything else — another key, another kind — is a build mismatch,
    // dropped rather than stored: a string under a toggle's key would make
    // its getter throw where the logging panel reads it.
    final fits = switch (fieldKey) {
      SpottingSettings.respotIntervalKey => value is String,
      SpottingSettings.autoRespotByDefaultKey || SpottingSettings.pulseBeforeRespotKey => value is bool,
      _ => false,
    };
    if (!fits) return;
    await settings.setSettingValue(SpottingSettings.group, fieldKey, value);
  }
}
