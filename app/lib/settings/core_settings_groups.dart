// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The core settings declarations (see settings_registry.dart): general
// (user interface), logging, privacy — all stored in SettingsService's
// per-group JSON maps — plus sync, whose enabled toggle routes through
// HaLoServices so the engine starts. The general group is the direct Dart
// port of the retired extensions/core/settings extension: same fields,
// icons, i18n keys, and value-dependent descriptions, minus the
// getCoreSettings/setCoreSetting host round-trips.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../i18n/strings.g.dart';
import '../services/extension_service.dart';
import '../services/settings_service.dart';
import 'settings_registry.dart';

// Where the Privacy panel's policy links point.
const privacyPolicyUrl = 'https://ham2k.com/legal/privacy/';
const termsOfServiceUrl = 'https://ham2k.com/legal/terms-of-service/';

// The theme field's own icon switches with its current value so the row
// reflects what's actually selected, not just that it's a theme setting.
const _themeIcons = {
  'system': 'theme-light-dark',
  'light': 'white-balance-sunny',
  'dark': 'weather-night',
};

Map<String, dynamic> _select({
  required String key,
  required String label,
  required String icon,
  String? description,
  required String value,
  required List<({String label, String value})> options,
}) => {
  'type': 'field',
  'fieldType': 'select',
  'key': key,
  'label': label,
  'icon': icon,
  if (description != null) 'description': description,
  'value': value,
  'options': [
    for (final o in options) {'label': o.label, 'value': o.value},
  ],
};

Map<String, dynamic> _toggle({
  required String key,
  required String label,
  required String icon,
  String? description,
  required bool value,
}) => {
  'type': 'field',
  'fieldType': 'checkbox',
  'key': key,
  'label': label,
  'icon': icon,
  if (description != null) 'description': description,
  'value': value,
};

/// Theme, language, font scale, and units — the "User Interface" section.
class GeneralSettingsGroup extends SettingsGroup {
  final SettingsService settings;
  final ExtensionService extensions;

  GeneralSettingsGroup(this.settings, this.extensions);

  @override
  String get key => 'general';

  @override
  String get title => t.settings.userInterface;

  @override
  int get order => 0;

  @override
  Listenable? get listenable => settings;

  @override
  Future<List<Map<String, dynamic>>> buildElements() async {
    final themeMode = settings.themeMode.name;
    return [
      _select(
        key: 'themeMode',
        label: t.settings.theme.title,
        icon: _themeIcons[themeMode] ?? _themeIcons['system']!,
        description: (t['settings.themeDescription.$themeMode'] as String?) ?? t.settings.themeDescription.system,
        value: themeMode,
        options: [
          (label: t.settings.theme.system, value: 'system'),
          (label: t.settings.theme.light, value: 'light'),
          (label: t.settings.theme.dark, value: 'dark'),
        ],
      ),
      _select(
        key: 'locale',
        label: t.settings.language,
        icon: 'translate',
        value: settings.locale,
        options: const [
          (label: 'English', value: 'en'),
          (label: 'Español', value: 'es'),
        ],
      ),
      _select(
        key: 'fontScale',
        label: t.settings.fontScale,
        icon: 'format-size',
        description: t.settings.fontScaleDescription,
        value: settings.fontScale.name,
        options: [
          for (final scale in FontScale.values) (label: t['settings.fontScaleOpts.${scale.name}'] as String, value: scale.name),
        ],
      ),
      _select(
        key: 'distanceUnits',
        label: t.settings.distanceUnits,
        icon: 'map-marker-distance',
        description: t.settings.distanceUnitsDescription,
        value: settings.distanceUnits.name,
        options: [
          for (final unit in DistanceUnits.values)
            (label: t['settings.distanceUnitsOpts.${unit.name}'] as String, value: unit.name),
        ],
      ),
    ];
  }

  @override
  Future<void> commit(String fieldKey, dynamic value) async {
    if (value is! String) return;
    switch (fieldKey) {
      case 'themeMode':
        final mode = _enumByNameOrNull(ThemeMode.values, value);
        if (mode != null) await settings.setThemeMode(mode);
      case 'locale':
        await settings.setLocale(value);
        LocaleSettings.setLocaleRaw(value);
      case 'fontScale':
        final scale = _enumByNameOrNull(FontScale.values, value);
        if (scale != null) await settings.setFontScale(scale);
      case 'distanceUnits':
        final units = _enumByNameOrNull(DistanceUnits.values, value);
        if (units != null) await settings.setDistanceUnits(units);
    }
    // Locale and theme feed extension HookContexts — invalidate so hooks
    // re-fetch fresh state (labels, theme-dependent assets).
    extensions.invalidateHookContext();
  }
}

/// Logging behavior and layout. The new fields (leftie mode, fields on
/// top, flags, bearing, report order, jump-after-RST, bands/modes) are
/// stored and declared but not yet consumed by the logging UI — each needs
/// its own wiring as follow-up. The five show* toggles are the same ones
/// the operation view's "..." menu flips.
class LoggingSettingsGroup extends SettingsGroup {
  final SettingsService settings;

  LoggingSettingsGroup(this.settings);

  @override
  String get key => 'logging';

  @override
  String get title => t.settings.logging.title;

  @override
  int get order => 10;

  @override
  Listenable? get listenable => settings;

  @override
  Future<List<Map<String, dynamic>>> buildElements() async {
    final s = t.settings.logging;
    return [
      _toggle(
        key: 'leftieMode',
        label: s.leftieMode.title,
        icon: 'hand-front-left-outline',
        description: settings.leftieMode ? s.leftieMode.descriptionOn : s.leftieMode.descriptionOff,
        value: settings.leftieMode,
      ),
      _toggle(
        key: 'fieldsOnTop',
        label: s.fieldsOnTop.title,
        icon: 'page-layout-header',
        description: settings.fieldsOnTop ? s.fieldsOnTop.descriptionOn : s.fieldsOnTop.descriptionOff,
        value: settings.fieldsOnTop,
      ),
      _select(
        key: 'dxFlags',
        label: s.countryFlags.title,
        icon: 'flag',
        description: t['settings.logging.countryFlags.${settings.dxFlags.name}'] as String,
        value: settings.dxFlags.name,
        options: [
          for (final option in DxFlags.values)
            (label: t['settings.logging.countryFlags.${option.name}'] as String, value: option.name),
        ],
      ),
      _toggle(
        key: 'showBearing',
        label: s.showBearing.title,
        icon: 'compass-outline',
        description: settings.showBearing ? s.showBearing.descriptionOn : s.showBearing.descriptionOff,
        value: settings.showBearing,
      ),
      _toggle(
        key: 'switchSentRcvd',
        label: s.switchSentRcvd.title,
        icon: 'arrow-left-right',
        description: settings.switchSentRcvd ? s.switchSentRcvd.rcvdFirst : s.switchSentRcvd.sentFirst,
        value: settings.switchSentRcvd,
      ),
      _toggle(
        key: 'jumpAfterRST',
        label: s.jumpAfterRST.title,
        icon: 'redo',
        description: settings.jumpAfterRST ? s.jumpAfterRST.descriptionOn : s.jumpAfterRST.descriptionOff,
        value: settings.jumpAfterRST,
      ),
      {
        'type': 'field',
        'fieldType': 'multiselect',
        'key': 'bands',
        'label': s.bands,
        'icon': 'radio',
        'value': settings.enabledBands,
        'defaultValue': SettingsService.defaultBands,
        'options': r'$core.bands',
      },
      {
        'type': 'field',
        'fieldType': 'multiselect',
        'key': 'modes',
        'label': s.modes,
        'icon': 'waveform',
        'value': settings.enabledModes,
        'defaultValue': SettingsService.defaultModes,
        'options': r'$core.modes',
      },
      _toggle(
        key: 'showRSTFields',
        label: t.operation.menu.showRstFields,
        icon: 'signal',
        value: settings.showRSTFields,
      ),
      _toggle(
        key: 'showStateField',
        label: t.operation.menu.showStateField,
        icon: 'map-outline',
        value: settings.showStateField,
      ),
      _toggle(
        key: 'showGridField',
        label: t.operation.menu.showGridField,
        icon: 'grid',
        value: settings.showGridField,
      ),
      _toggle(
        key: 'showDeletedQSOs',
        label: t.operation.menu.showDeletedQsos,
        icon: 'delete-outline',
        value: settings.showDeletedQSOs,
      ),
      _toggle(
        key: 'showQsoNumbers',
        label: t.operation.menu.showQsoNumbers,
        icon: 'counter',
        value: settings.showQsoNumbers,
      ),
    ];
  }

  @override
  Future<void> commit(String fieldKey, dynamic value) async {
    switch (fieldKey) {
      case 'dxFlags':
        if (value is String && _enumByNameOrNull(DxFlags.values, value) != null) {
          await settings.setSettingValue(SettingsService.loggingGroup, fieldKey, value);
        }
      case 'bands' || 'modes':
        // The multiselect editor only emits values from the $core.bands/
        // $core.modes vocabularies, already in canonical order.
        if (value is List) {
          await settings.setSettingValue(SettingsService.loggingGroup, fieldKey, value.whereType<String>().toList());
        }
      default:
        if (value is bool) await settings.setSettingValue(SettingsService.loggingGroup, fieldKey, value);
    }
  }
}

/// Data-sharing consents (both opt-in, app-polo keys and wording) and the
/// Ham2K policy links.
class PrivacySettingsGroup extends SettingsGroup {
  final SettingsService settings;

  PrivacySettingsGroup(this.settings);

  @override
  String get key => 'privacy';

  @override
  String get title => t.settings.privacy.title;

  @override
  int get order => 20;

  @override
  Listenable? get listenable => settings;

  @override
  Future<List<Map<String, dynamic>>> buildElements() async {
    final s = t.settings.privacy;
    return [
      _toggle(
        key: 'consentAppData',
        label: s.shareAppData.title,
        icon: 'cellphone-lock',
        description: settings.consentAppData ? s.shareAppData.descriptionOn : s.shareAppData.descriptionOff,
        value: settings.consentAppData,
      ),
      _toggle(
        key: 'consentOpData',
        label: s.shareOpData.title,
        icon: 'cellphone-lock',
        description: settings.consentOpData ? s.shareOpData.descriptionOn : s.shareOpData.descriptionOff,
        value: settings.consentOpData,
      ),
      {'type': 'link', 'key': 'privacyPolicy', 'label': s.privacyPolicy, 'icon': 'shield-account-outline', 'url': privacyPolicyUrl},
      {'type': 'link', 'key': 'termsOfService', 'label': s.termsOfService, 'icon': 'file-document-outline', 'url': termsOfServiceUrl},
    ];
  }

  @override
  Future<void> commit(String fieldKey, dynamic value) async {
    if (value is! bool) return;
    await settings.setSettingValue(SettingsService.privacyGroup, fieldKey, value);
  }
}

/// Sync's declarative representation for All Settings: the enabled toggle
/// (routed through HaLoServices so the engine starts) and a read-only
/// account line. The dedicated Sync panel remains the full management UI.
///
/// The account line reads the STATIC snapshot the last real fetch stored in
/// `syncState['accountData']` (see ExtensionService.syncAccountData) — no
/// network request here: buildElements re-runs on every settings change,
/// and only the Sync panel itself actively refreshes account data.
class SyncSettingsGroup extends SettingsGroup {
  final SettingsService settings;
  final Future<void> Function(bool enabled) onToggle;

  SyncSettingsGroup(this.settings, {required this.onToggle});

  @override
  String get key => 'sync';

  @override
  String get title => t.settings.sync.title;

  @override
  int get order => 30;

  @override
  Listenable? get listenable => settings;

  @override
  Future<List<Map<String, dynamic>>> buildElements() async {
    String account = '';
    if (settings.syncEnabled) {
      final data = settings.syncState['accountData'];
      final current = data is Map ? data['current_account'] : null;
      final call = current is Map ? current['call'] as String? : null;
      account = (call == null || call.isEmpty) ? 'Not linked yet' : 'Linked as $call';
    }
    return [
      _toggle(
        key: 'enabled',
        label: t.settings.sync.enable,
        icon: 'cloud-sync-outline',
        description: account.isEmpty ? null : account,
        value: settings.syncEnabled,
      ),
    ];
  }

  @override
  Future<void> commit(String fieldKey, dynamic value) async {
    if (fieldKey == 'enabled' && value is bool) await onToggle(value);
  }
}

T? _enumByNameOrNull<T extends Enum>(List<T> values, String name) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return null;
}
