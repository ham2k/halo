// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/widgets.dart';
import 'package:halo_i18n/halo_i18n.dart';

import 'package:halo_widgets/halo_widgets.dart' show ExtensionIconTile, FormRenderer, MdiIcons, SpotDestinationPolicy, SpottingControlModel, Tone;

import '../services/extensions/extension_service.dart' show SpotDestination;

import '../services/settings_service.dart';
import '../services/spotting_settings.dart';
import 'settings_registry.dart';

/// The Spotting section: auto-respotting's interval, whether it starts
/// without offering, and whether the chip pulses before each one, then a
/// Destinations section with which spots each spot destination is sent.
/// These are also what the Spotting control's tune button opens
/// (`target: 'spotting'`). Below them, [cluster]'s rows as a DX Cluster
/// section of their own.
class SpottingSettingsGroup extends SettingsGroup {
  final SettingsService settings;
  SpottingSettingsGroup(this.settings);

  /// The DX cluster's settings, set by the cluster's wiring before anything
  /// reads [listenable]. Never registered on its own: a cluster is how spots
  /// travel, so its node sits with the rest of spotting.
  SettingsGroup? cluster;

  /// Every spot source that posts spots, by `hookKey`, set by the
  /// extensions' wiring with [destinationChanges] before anything reads
  /// [listenable]. With none listed and none held back, the Destinations
  /// section is left out.
  Future<Map<String, SpotDestination>> Function()? destinations;

  /// Notifies when [destinations] may have changed.
  Listenable? destinationChanges;

  /// A destination's row key: the prefix and its spot source's `hookKey`.
  static const destinationKeyPrefix = 'destination-';

  @override
  String get key => SpottingSettings.group;
  @override
  String get title => t.settings.spotting.title;
  @override
  int get order => 12;

  /// Merged once, so a form subscribes and unsubscribes the same object.
  @override
  late final Listenable listenable = Listenable.merge([settings, ?destinationChanges, ?cluster?.listenable]);

  @override
  Future<void> openAction(BuildContext context, String actionKey) async => cluster?.openAction(context, actionKey);

  @override
  Future<List<Map<String, dynamic>>> buildElements() async {
    final labels = t.settings.spotting;
    final (:respotInterval, :autoRespotByDefault, :pulseBeforeRespot, destinations: policies) = SpottingSettings.read(settings);
    final minutes = '${respotInterval.inMinutes}';
    String policyLabel(SpotDestinationPolicy policy) => switch (policy) {
      SpotDestinationPolicy.all => labels.destinationAll,
      SpotDestinationPolicy.qrvQrt => labels.destinationQrvQrt,
      SpotDestinationPolicy.exceptAuto => labels.destinationExceptAuto,
      SpotDestinationPolicy.none => labels.destinationNone,
    };
    SpotDestinationPolicy policyOf(String hookKey) => policies[hookKey] ?? SpotDestinationPolicy.all;
    final listed = await destinations?.call() ?? const {};
    final named = {
      ...listed,
      // A destination held back keeps its row when the listing leaves it out
      // — its extension removed, or the runtime slow to answer: the setting
      // still holds it back, and a row is the only way to undo that.
      for (final hookKey in policies.keys)
        if (!listed.containsKey(hookKey)) hookKey: (name: hookKey, icon: null, accentColor: null, postsSelfSpots: true),
    }.entries.toList()..sort((a, b) => a.value.name.toLowerCase().compareTo(b.value.name.toLowerCase()));
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
      if (named.isNotEmpty)
        // The section's close carries the target too: the Spotting control's
        // dialog keeps only the elements that do.
        for (final element in FormRenderer.closingSections([
          {'type': 'header', 'style': 'section', 'key': 'destinations', 'title': labels.destinations},
          for (final MapEntry(key: hookKey, value: (:name, :icon, :accentColor, :postsSelfSpots)) in named)
            {
              'type': 'field',
              'fieldType': 'select',
              'key': '$destinationKeyPrefix$hookKey',
              'label': name,
              'icon': 'send-outline',
              // The tile the extension wears everywhere else, so a
              // destination reads as the program it is.
              'leading': ExtensionIconTile(icon: icon, accentColor: accentColor, fallbackIcon: MdiIcons.sendOutline),
              'description': policyLabel(policyOf(hookKey)),
              'tone': switch (policyOf(hookKey)) {
                SpotDestinationPolicy.all => Tone.good,
                SpotDestinationPolicy.qrvQrt || SpotDestinationPolicy.exceptAuto => Tone.partial,
                SpotDestinationPolicy.none => Tone.bad,
              }.name,
              'value': policyOf(hookKey).name,
              'options': [
                // Which self-spots go out means nothing to a destination
                // that takes none: it is sent every other spot, or none.
                for (final policy in SpotDestinationPolicy.values)
                  if (postsSelfSpots || policy == SpotDestinationPolicy.all || policy == SpotDestinationPolicy.none)
                    {'label': policyLabel(policy), 'value': policy.name},
              ],
            },
        ]))
          {...element, 'target': 'spotting'},
      if (await cluster?.buildElements() case final clusterElements? when clusterElements.isNotEmpty)
        ...FormRenderer.closingSections([
          {'type': 'header', 'style': 'section', 'key': 'cluster', 'title': cluster!.title},
          ...clusterElements,
        ]),
    ];
  }

  @override
  Future<void> commit(String fieldKey, dynamic value) async {
    // A destination's value is one of its option strings, the interval one
    // of its own, each toggle a bool; another kind is a build mismatch,
    // dropped rather than stored: a string under a toggle's key would make
    // its getter throw where the logging panel reads it. Any other key is
    // the cluster's, which drops what it does not know.
    if (fieldKey.startsWith(destinationKeyPrefix)) {
      final policy = SpotDestinationPolicy.values.asNameMap()[value];
      if (policy == null) return;
      return SpottingSettings.setDestination(settings, fieldKey.substring(destinationKeyPrefix.length), policy);
    }
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
