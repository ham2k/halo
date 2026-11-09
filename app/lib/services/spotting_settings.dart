// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/foundation.dart' show VoidCallback, mapEquals;
import 'package:halo_widgets/halo_widgets.dart' show SendSpot, SpotDestinationPolicy, SpottingHooks, SuggestSpotSources;

import 'settings_service.dart';

/// Where the Spotting section's settings live, in their own group: how often
/// auto-respotting repeats a self-spot, whether it starts without offering,
/// whether the chip pulses before each one, and which spots each destination
/// is sent.
abstract final class SpottingSettings {
  static const group = 'spotting';
  static const respotIntervalKey = 'respotIntervalMinutes';
  static const autoRespotByDefaultKey = 'autoRespotByDefault';
  static const pulseBeforeRespotKey = 'pulseBeforeRespot';
  static const localSpotsKey = 'localSpots';

  /// `{hookKey: SpotDestinationPolicy.name}`, one entry per destination the
  /// operator set; one with none is sent every spot.
  static const destinationsKey = 'destinations';

  /// The intervals offered, in minutes. RESPOT with a number of its own may
  /// go as long as an hour; this is the everyday range.
  static const respotIntervalOptions = [5, 10, 15, 20, 30];

  /// Every value at once, from one read of the group: the logging panel
  /// re-reads them on each settings change, and those come often.
  static SpottingValues read(SettingsService settings) {
    final stored = settings.settingsGroup(group);
    return (
      respotInterval: _snapInterval(stored[respotIntervalKey]),
      autoRespotByDefault: stored[autoRespotByDefaultKey] as bool? ?? false,
      pulseBeforeRespot: stored[pulseBeforeRespotKey] as bool? ?? true,
      destinations: _destinations(stored[destinationsKey]),
    );
  }

  /// The Spotting control's hooks, carrying [values]; the rest are the
  /// panel's. Built here rather than at the logging panel, which sits at its
  /// file-size budget: each setting passed there by hand is a line it lacks.
  static SpottingHooks hooks(SpottingValues values, {SuggestSpotSources? suggestSpotSources, SendSpot? sendSpot, VoidCallback? onOpenSettings}) =>
      SpottingHooks(
        suggestSpotSources: suggestSpotSources,
        sendSpot: sendSpot,
        respotInterval: values.respotInterval,
        autoRespotByDefault: values.autoRespotByDefault,
        pulseBeforeRespot: values.pulseBeforeRespot,
        destinations: values.destinations,
        onOpenSettings: onOpenSettings,
      );

  /// Whether [a] and [b] hold the same values: a record's own `==` compares
  /// [SpottingValues.destinations] by identity, and every [read] builds a new
  /// map.
  static bool same(SpottingValues a, SpottingValues b) =>
      a.respotInterval == b.respotInterval &&
      a.autoRespotByDefault == b.autoRespotByDefault &&
      a.pulseBeforeRespot == b.pulseBeforeRespot &&
      mapEquals(a.destinations, b.destinations);

  /// Stores [policy] for the destination under [hookKey]; [SpotDestinationPolicy.all]
  /// drops its entry, so the store holds only the destinations held back.
  static Future<void> setDestination(SettingsService settings, String hookKey, SpotDestinationPolicy policy) async {
    final stored = settings.settingsGroup(group)[destinationsKey];
    final next = {
      if (stored is Map)
        for (final entry in stored.entries)
          if (entry.key is String && entry.key != hookKey) entry.key as String: entry.value,
      if (policy != SpotDestinationPolicy.all) hookKey: policy.name,
    };
    await settings.setSettingValue(group, destinationsKey, next);
  }

  static Map<String, SpotDestinationPolicy> _destinations(Object? raw) => raw is Map
      ? {
          for (final entry in raw.entries)
            if (entry.key is String) entry.key as String: SpotDestinationPolicy.parse(entry.value),
        }
      : const {};

  /// How often auto-respotting repeats a self-spot: the button's offer and a
  /// bare RESPOT both use it. A stored value the picker does not offer — an
  /// older build's list, a hand-edited store — snaps to the nearest one it
  /// does, so the picker never shows one interval while respotting runs on
  /// another.
  static Duration respotInterval(SettingsService settings) => read(settings).respotInterval;

  static bool autoRespotByDefault(SettingsService settings) => read(settings).autoRespotByDefault;

  /// Whether the Spotting chip pulses in the seconds before each auto-respot.
  static bool pulseBeforeRespot(SettingsService settings) => read(settings).pulseBeforeRespot;

  /// Whether a call entered in the logging panel goes on the board as a local
  /// spot (docs/design/logging-fields.md § Local spots). Off until the
  /// operator turns it on. Not one of [SpottingValues]: it is the board's,
  /// not the Spotting control's.
  static bool localSpots(SettingsService settings) => settings.settingsGroup(group)[localSpotsKey] as bool? ?? false;

  /// The default is the Spotting control's own, so a host without these
  /// settings re-spots at the same pace.
  static Duration _snapInterval(Object? raw) {
    final stored = raw is num ? raw : num.tryParse('${raw ?? ''}');
    final target = stored != null && stored.isFinite ? stored : SpottingHooks.defaultRespotInterval.inMinutes;
    final minutes = respotIntervalOptions.reduce((a, b) => (a - target).abs() <= (b - target).abs() ? a : b);
    return Duration(minutes: minutes);
  }
}

typedef SpottingValues = ({Duration respotInterval, bool autoRespotByDefault, bool pulseBeforeRespot, Map<String, SpotDestinationPolicy> destinations});
