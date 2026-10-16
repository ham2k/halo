// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:halo_widgets/halo_widgets.dart' show SpottingHooks;

import 'settings_service.dart';

/// Where the Spotting section's settings live, in their own group: how often
/// auto-respotting repeats a self-spot, whether it starts without offering,
/// and whether the chip pulses before each one.
abstract final class SpottingSettings {
  static const group = 'spotting';
  static const respotIntervalKey = 'respotIntervalMinutes';
  static const autoRespotByDefaultKey = 'autoRespotByDefault';
  static const pulseBeforeRespotKey = 'pulseBeforeRespot';

  /// The intervals offered, in minutes. RESPOT with a number of its own may
  /// go as long as an hour; this is the everyday range.
  static const respotIntervalOptions = [5, 10, 15, 20, 30];

  /// Every value at once, from one read of the group: the logging panel
  /// re-reads them on each settings change, and those come often.
  static ({Duration respotInterval, bool autoRespotByDefault, bool pulseBeforeRespot}) read(SettingsService settings) {
    final stored = settings.settingsGroup(group);
    return (
      respotInterval: _snapInterval(stored[respotIntervalKey]),
      autoRespotByDefault: stored[autoRespotByDefaultKey] as bool? ?? false,
      pulseBeforeRespot: stored[pulseBeforeRespotKey] as bool? ?? true,
    );
  }

  /// How often auto-respotting repeats a self-spot: the button's offer and a
  /// bare RESPOT both use it. A stored value the picker does not offer — an
  /// older build's list, a hand-edited store — snaps to the nearest one it
  /// does, so the picker never shows one interval while respotting runs on
  /// another.
  static Duration respotInterval(SettingsService settings) => read(settings).respotInterval;

  static bool autoRespotByDefault(SettingsService settings) => read(settings).autoRespotByDefault;

  /// Whether the Spotting chip pulses in the seconds before each auto-respot.
  static bool pulseBeforeRespot(SettingsService settings) => read(settings).pulseBeforeRespot;

  /// The default is the Spotting control's own, so a host without these
  /// settings re-spots at the same pace.
  static Duration _snapInterval(Object? raw) {
    final stored = raw is num ? raw : num.tryParse('${raw ?? ''}');
    final target = stored != null && stored.isFinite ? stored : SpottingHooks.defaultRespotInterval.inMinutes;
    final minutes = respotIntervalOptions.reduce((a, b) => (a - target).abs() <= (b - target).abs() ? a : b);
    return Duration(minutes: minutes);
  }
}
