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
  bool common = false,
  String? environment,
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
  if (common) 'common': true,
  if (environment != null) 'environment': environment,
};

Map<String, dynamic> _toggle({
  required String key,
  required String label,
  required String icon,
  String? description,
  required bool value,
  bool common = false,
  String? environment,
}) => {
  'type': 'field',
  'fieldType': 'checkbox',
  'key': key,
  'label': label,
  'icon': icon,
  if (description != null) 'description': description,
  'value': value,
  if (common) 'common': true,
  if (environment != null) 'environment': environment,
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
        common: true,
      ),
      _select(
        key: 'locale',
        label: t.settings.language,
        icon: 'translate',
        // Just the current language's own name (its option label).
        description: settings.locale == 'es' ? 'Español' : 'English',
        value: settings.locale,
        options: const [
          (label: 'English', value: 'en'),
          (label: 'Español', value: 'es'),
        ],
        common: true,
      ),
      _fontScaleSelect(),
      _select(
        key: 'distanceUnits',
        label: t.settings.distanceUnits,
        icon: 'map-marker-distance',
        // Just the current unit's name (its option label).
        description: t['settings.distanceUnitsOpts.${settings.distanceUnits.name}'] as String,
        value: settings.distanceUnits.name,
        options: [
          for (final unit in DistanceUnits.values)
            (label: t['settings.distanceUnitsOpts.${unit.name}'] as String, value: unit.name),
        ],
        common: true,
      ),
    ];
  }

  /// The Font Scale picker.
  ///
  /// It lists only [FontScale.selectableValues] — the four extremes are
  /// reachable with the keyboard shortcuts only. When one of those IS in
  /// effect, the nearest listed entry carries its label instead ("Largest++"
  /// on the Largest row), so the setting still reports the size actually in
  /// use rather than silently showing "Largest" at 1.90.
  ///
  /// Selecting that annotated row commits the plain level it stands for
  /// (Largest, 1.40) — which is also the only way back to a standard size
  /// without the shortcuts.
  Map<String, dynamic> _fontScaleSelect() {
    final current = settings.fontScale;
    final anchor = current.nearestSelectable;
    String labelFor(FontScale scale) =>
        t['settings.fontScaleOpts.${scale == anchor ? current.name : scale.name}'] as String;

    return _select(
      key: 'fontScale',
      label: t.settings.fontScale,
      icon: 'format-size',
      // Just the current scale's name (its option label).
      description: t['settings.fontScaleOpts.${current.name}'] as String,
      value: anchor.name,
      options: [
        for (final scale in FontScale.selectableValues) (label: labelFor(scale), value: scale.name),
      ],
      common: true,
    );
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
        icon: 'hand-front-left',
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
        icon: 'compass',
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
      // The mobile numbers row (issue #27, APP-21) — irrelevant without an
      // on-screen keyboard, hence `environment: 'ios,android'`, filtered out
      // everywhere (not just Common Preferences) on desktop/web. Flagged
      // `common: true` so it's reachable from Common Preferences too, not
      // just All Settings. Its two sub-options only make sense while the
      // row is on, so they appear only then — buildElements re-runs on
      // every settings change (listenable: settings), so they show/hide as
      // the master toggle flips.
      _toggle(
        key: 'showNumbersRow',
        label: s.numbersRow.title,
        icon: 'dialpad',
        description: s.numbersRow.description,
        value: settings.showNumbersRow,
        common: true,
        environment: 'ios,android',
      ),
      if (settings.showNumbersRow) ...[
        _toggle(
          key: 'showExtraInNumbersRow',
          label: s.numbersRowExtra.title,
          icon: 'slash-forward',
          description: s.numbersRowExtra.description,
          value: settings.showExtraInNumbersRow,
          common: true,
          environment: 'ios,android',
        ),
        _toggle(
          key: 'vibrateNumbersRow',
          label: s.numbersRowVibrate.title,
          icon: 'vibrate',
          description: s.numbersRowVibrate.description,
          value: settings.vibrateNumbersRow,
          common: true,
          environment: 'ios,android',
        ),
      ],
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
        icon: 'map',
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
        icon: 'delete',
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
        common: true,
      ),
      _toggle(
        key: 'consentOpData',
        label: s.shareOpData.title,
        icon: 'cellphone-lock',
        description: settings.consentOpData ? s.shareOpData.descriptionOn : s.shareOpData.descriptionOff,
        value: settings.consentOpData,
        common: true,
      ),
      {
        'type': 'link',
        'key': 'privacyPolicy',
        'label': s.privacyPolicy,
        'icon': 'shield-account',
        'url': privacyPolicyUrl,
        'common': true,
      },
      {
        'type': 'link',
        'key': 'termsOfService',
        'label': s.termsOfService,
        'icon': 'file-document',
        'url': termsOfServiceUrl,
        'common': true,
      },
    ];
  }

  @override
  Future<void> commit(String fieldKey, dynamic value) async {
    if (value is! bool) return;
    await settings.setSettingValue(SettingsService.privacyGroup, fieldKey, value);
  }
}

/// Export settings — today just the filename form. Declared here as well as
/// being reachable from the Exports panel's own gear, because a setting that
/// exists only behind a button inside one panel can't be found by anyone who
/// doesn't already know where it lives (settings_registry.dart).
class ExportsSettingsGroup extends SettingsGroup {
  final SettingsService settings;

  ExportsSettingsGroup(this.settings);

  @override
  String get key => 'exports';

  @override
  String get title => t.operation.export.settingsTitle;

  @override
  int get order => 25;

  @override
  Listenable? get listenable => settings;

  @override
  Future<List<Map<String, dynamic>>> buildElements() async {
    final names = t.operation.export.compactFileNames;
    final private = t.operation.export.includePrivateData;
    return [
      _toggle(
        key: 'useCompactFileNames',
        label: names.title,
        icon: 'file-code-outline',
        description: settings.useCompactFileNames ? names.descriptionOn : names.descriptionOff,
        value: settings.useCompactFileNames,
      ),
      _toggle(
        key: 'includePrivateData',
        label: private.title,
        icon: 'account-lock',
        description: '${settings.includePrivateData ? private.descriptionOn : private.descriptionOff}'
            ' — ${private.note}',
        value: settings.includePrivateData,
      ),
    ];
  }

  @override
  Future<void> commit(String fieldKey, dynamic value) async {
    if (value is! bool) return;
    await settings.setSettingValue(SettingsService.exportsGroup, fieldKey, value);
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
      account = (call == null || call.isEmpty) ? t.settings.syncPanel.notLinked : t.settings.syncPanel.linkedAs(call: call);
    }
    return [
      _toggle(
        key: 'enabled',
        label: t.settings.sync.enable,
        icon: 'cloud-sync',
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
