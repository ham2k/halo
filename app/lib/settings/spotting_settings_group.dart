// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/widgets.dart';
import 'package:halo_i18n/halo_i18n.dart';

import 'package:halo_widgets/halo_widgets.dart' show FormRenderer, SpottingControlModel;

import '../services/settings_service.dart';
import '../services/spotting_settings.dart';
import 'settings_registry.dart';

/// The Spotting section: auto-respotting's interval, whether it starts
/// without offering, and whether the chip pulses before each one. Its fields are also what the Spotting control's tune
/// button opens (`target: 'spotting'`). Below them, [cluster]'s rows as a
/// DX Cluster section of their own.
class SpottingSettingsGroup extends SettingsGroup {
  final SettingsService settings;
  SpottingSettingsGroup(this.settings);

  /// The DX cluster's settings, set by the cluster's wiring before anything
  /// reads [listenable]. Never registered on its own: a cluster is how spots
  /// travel, so its node sits with the rest of spotting.
  SettingsGroup? cluster;

  @override
  String get key => SpottingSettings.group;
  @override
  String get title => t.settings.spotting.title;
  @override
  int get order => 12;

  /// Merged once, so a form subscribes and unsubscribes the same object.
  @override
  late final Listenable listenable = Listenable.merge([settings, ?cluster?.listenable]);

  @override
  Future<void> openAction(BuildContext context, String actionKey) async => cluster?.openAction(context, actionKey);

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
      if (await cluster?.buildElements() case final clusterElements? when clusterElements.isNotEmpty)
        ...FormRenderer.closingSections([
          {'type': 'header', 'style': 'section', 'key': 'cluster', 'title': cluster!.title},
          ...clusterElements,
        ]),
    ];
  }

  @override
  Future<void> commit(String fieldKey, dynamic value) async {
    // The interval is one of its own option strings, each toggle a bool;
    // another kind is a build mismatch, dropped rather than stored: a string
    // under a toggle's key would make its getter throw where the logging
    // panel reads it. Any other key is the cluster's, which drops what it
    // does not know.
    final fits = switch (fieldKey) {
      SpottingSettings.respotIntervalKey => value is String,
      SpottingSettings.autoRespotByDefaultKey || SpottingSettings.pulseBeforeRespotKey => value is bool,
      _ => null,
    };
    if (fits == null) return cluster?.commit(fieldKey, value);
    if (!fits) return;
    await settings.setSettingValue(SpottingSettings.group, fieldKey, value);
  }
}
