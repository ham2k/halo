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
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../i18n/strings.g.dart';
import '../services/extension_service.dart';
import '../services/settings_service.dart';
import '../tools/sync_account_identity.dart';
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
  List<String>? aliases,
  required String value,
  required List<({String label, String value})> options,
  bool common = false,
  String? environment,
  String? target,
  bool devMode = false,
}) => {
  'type': 'field',
  'fieldType': 'select',
  'key': key,
  'label': label,
  'icon': icon,
  if (description != null) 'description': description,
  if (aliases != null) 'aliases': aliases,
  'value': value,
  'options': [
    for (final o in options) {'label': o.label, 'value': o.value},
  ],
  if (common) 'common': true,
  if (environment != null) 'environment': environment,
  if (target != null) 'target': target,
  if (devMode) 'devMode': true,
};

Map<String, dynamic> _text({
  required String key,
  required String label,
  required String icon,
  String? description,
  List<String>? aliases,
  required String value,
  String? placeholder,
  String? target,
}) => {
  'type': 'field',
  'fieldType': 'text',
  'key': key,
  'label': label,
  'icon': icon,
  if (description != null) 'description': description,
  if (aliases != null) 'aliases': aliases,
  'value': value,
  if (placeholder != null) 'placeholder': placeholder,
  if (target != null) 'target': target,
};

Map<String, dynamic> _toggle({
  required String key,
  required String label,
  required String icon,
  String? description,
  List<String>? aliases,
  required bool value,
  bool common = false,
  String? environment,
  String? target,
}) => {
  'type': 'field',
  'fieldType': 'checkbox',
  'key': key,
  'label': label,
  'icon': icon,
  if (description != null) 'description': description,
  if (aliases != null) 'aliases': aliases,
  'value': value,
  if (common) 'common': true,
  if (environment != null) 'environment': environment,
  if (target != null) 'target': target,
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
        aliases: const ['theme'],
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
        aliases: const ['language', 'lang'],
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
      _layoutDensitySelect(),
      _select(
        key: 'distanceUnits',
        aliases: const ['units'],
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
      _select(
        key: 'numberFormat',
        aliases: const ['decimals', 'decimalSeparator'],
        label: t.settings.numberFormat,
        icon: 'numeric',
        // Just the current choice's name, matching distanceUnits above.
        description: t['settings.numberFormatOpts.${settings.numberFormatStyle.name}'] as String,
        value: settings.numberFormatStyle.name,
        options: [
          for (final style in NumberFormatStyle.values)
            (label: t['settings.numberFormatOpts.${style.name}'] as String, value: style.name),
        ],
      ),
      _toggle(
        key: 'layoutCustomization',
        // NOT 'panels': this setting decides whether a view can be
        // REARRANGED, not what there is to arrange. An operator told to
        // "turn panels on" would get a rearrangeable view and still no
        // Custom Text, which is an extension they enable separately.
        aliases: const ['layout', 'dock'],
        label: t.settings.layoutCustomization.title,
        icon: 'view-dashboard',
        description: settings.layoutCustomization
            ? t.settings.layoutCustomization.descriptionOn
            : t.settings.layoutCustomization.descriptionOff,
        value: settings.layoutCustomization,
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
      aliases: const ['fontSize'],
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

  /// The Layout Density picker.
  ///
  /// Unlike Font Scale every level is listed, including [DensityPreference.auto],
  /// which is the default and where most operators should stay.
  ///
  /// The description names the stored PREFERENCE, not the density in force.
  /// Those differ on Auto, and on a window too short for the pick, where
  /// `DensityPreference.resolve`'s ceiling overrides it — but a settings
  /// group builds its elements without a `BuildContext`, so the window height
  /// the effective density needs is not reachable from here. The ⌘⇧-/⌘⇧=
  /// shortcuts name both (`_announceDensity` in main.dart), which is where an
  /// operator finds out that a pick was stored but clamped.
  Map<String, dynamic> _layoutDensitySelect() {
    final current = settings.densityPreference;

    return _select(
      key: 'layoutDensity',
      label: t.settings.layoutDensity,
      icon: 'arrow-collapse-vertical',
      description: t['settings.layoutDensityOpts.${current.name}'] as String,
      value: current.name,
      options: [
        for (final preference in DensityPreference.selectableValues)
          (label: t['settings.layoutDensityOpts.${preference.name}'] as String, value: preference.name),
      ],
      common: true,
    );
  }

  @override
  Future<void> commit(String fieldKey, dynamic value) async {
    if (fieldKey == 'layoutCustomization') {
      if (value is bool) await settings.setLayoutCustomization(value);
      return;
    }
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
      case 'layoutDensity':
        final density = _enumByNameOrNull(DensityPreference.values, value);
        if (density != null) await settings.setDensityPreference(density);
      case 'distanceUnits':
        final units = _enumByNameOrNull(DistanceUnits.values, value);
        if (units != null) await settings.setDistanceUnits(units);
      case 'numberFormat':
        final style = _enumByNameOrNull(NumberFormatStyle.values, value);
        if (style != null) await settings.setNumberFormatStyle(style);
    }
    // Locale and theme feed extension HookContexts — invalidate so hooks
    // re-fetch fresh state (labels, theme-dependent assets).
    extensions.invalidateHookContext();
  }
}

/// Logging behavior and layout. The five show* toggles are `target:
/// 'logging'` — the base set the logging panel's tune-icon dialog
/// (settings_target_dialog.dart) always shows. Everything else here is
/// `target: 'logging-extended'` — reachable from the same dialog, behind
/// its "show more settings" disclosure, since these are newer and more
/// niche than the five toggles operators already know.
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
        aliases: const ['leftie'],
        label: s.leftieMode.title,
        icon: 'hand-front-left',
        description: settings.leftieMode ? s.leftieMode.descriptionOn : s.leftieMode.descriptionOff,
        value: settings.leftieMode,
        target: 'logging-extended',
      ),
      _toggle(
        key: 'fieldsOnTop',
        label: s.fieldsOnTop.title,
        icon: 'page-layout-header',
        description: settings.fieldsOnTop ? s.fieldsOnTop.descriptionOn : s.fieldsOnTop.descriptionOff,
        value: settings.fieldsOnTop,
        target: 'logging-extended',
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
        target: 'logging-extended',
      ),
      _toggle(
        key: 'showBearing',
        label: s.showBearing.title,
        icon: 'compass',
        description: settings.showBearing ? s.showBearing.descriptionOn : s.showBearing.descriptionOff,
        value: settings.showBearing,
        target: 'logging-extended',
      ),
      if (settings.showBearing)
        _toggle(
          key: 'showReverseBearing',
          label: s.showReverseBearing.title,
          icon: 'compass-outline',
          description: settings.showReverseBearing ? s.showReverseBearing.descriptionOn : s.showReverseBearing.descriptionOff,
          value: settings.showReverseBearing,
          target: 'logging-extended',
        ),
      _toggle(
        key: 'switchSentRcvd',
        label: s.switchSentRcvd.title,
        icon: 'arrow-left-right',
        description: settings.switchSentRcvd ? s.switchSentRcvd.rcvdFirst : s.switchSentRcvd.sentFirst,
        value: settings.switchSentRcvd,
        target: 'logging-extended',
      ),
      _toggle(
        key: 'jumpAfterRST',
        label: s.jumpAfterRST.title,
        icon: 'redo',
        description: settings.jumpAfterRST ? s.jumpAfterRST.descriptionOn : s.jumpAfterRST.descriptionOff,
        value: settings.jumpAfterRST,
        target: 'logging-extended',
      ),
      // The report an empty Sent/Rcvd stands for, one field per mode band.
      // Shown with the standard report as the PLACEHOLDER rather than the
      // value, the same rule the logging fields themselves follow: an empty
      // setting means "the standard one", so clearing it restores the
      // default instead of storing a blank report.
      _text(
        key: 'defaultReport',
        aliases: const ['report', 'rst'],
        label: s.defaultReport.title,
        icon: 'signal',
        description: s.defaultReport.description,
        value: settings.defaultReport,
        placeholder: defaultRSTFor('SSB'),
        target: 'logging-extended',
      ),
      _text(
        key: 'defaultReportCW',
        aliases: const ['reportCW', 'rstCW'],
        label: s.defaultReportCW.title,
        icon: 'signal',
        description: s.defaultReportCW.description,
        value: settings.defaultReportCW,
        placeholder: defaultRSTFor('CW'),
        target: 'logging-extended',
      ),
      _text(
        key: 'defaultReportFT8',
        aliases: const ['reportFT8', 'reportFT4'],
        label: s.defaultReportFT8.title,
        icon: 'signal',
        description: s.defaultReportFT8.description,
        value: settings.defaultReportFT8,
        placeholder: defaultRSTFor('FT8'),
        target: 'logging-extended',
      ),
      // The mobile numbers row — irrelevant without an
      // on-screen keyboard, hence `environment: 'ios,android'`, filtered out
      // everywhere (not just Common Preferences) on desktop/web. Flagged
      // `common: true` so it's reachable from Common Preferences too, not
      // just All Settings. Its two sub-options only make sense while the
      // row is on, so they appear only then — buildElements re-runs on
      // every settings change (listenable: settings), so they show/hide as
      // the master toggle flips.
      _toggle(
        key: 'showNumbersRow',
        aliases: const ['numbersRow'],
        label: s.numbersRow.title,
        icon: 'dialpad',
        description: s.numbersRow.description,
        value: settings.showNumbersRow,
        common: true,
        environment: 'ios,android',
        target: 'logging-extended',
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
          target: 'logging-extended',
        ),
        _toggle(
          key: 'vibrateNumbersRow',
          label: s.numbersRowVibrate.title,
          icon: 'vibrate',
          description: s.numbersRowVibrate.description,
          value: settings.vibrateNumbersRow,
          common: true,
          environment: 'ios,android',
          target: 'logging-extended',
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
        'target': 'logging-extended',
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
        'target': 'logging-extended',
      },
      _toggle(
        key: 'showRSTFields',
        label: t.operation.menu.showRstFields,
        icon: 'signal',
        value: settings.showRSTFields,
        target: 'logging',
      ),
      _toggle(
        key: 'showStateField',
        label: t.operation.menu.showStateField,
        icon: 'map',
        value: settings.showStateField,
        target: 'logging',
      ),
      _toggle(
        key: 'showGridField',
        label: t.operation.menu.showGridField,
        icon: 'grid',
        value: settings.showGridField,
        target: 'logging',
      ),
      _toggle(
        key: 'showDeletedQSOs',
        aliases: const ['deletedQSOs'],
        label: t.operation.menu.showDeletedQsos,
        icon: 'delete',
        value: settings.showDeletedQSOs,
        target: 'logging',
      ),
      _toggle(
        key: 'showQsoNumbers',
        label: t.operation.menu.showQsoNumbers,
        icon: 'counter',
        target: 'logging',
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
      case 'defaultReport' || 'defaultReportCW' || 'defaultReportFT8':
        // Uppercased so a CW operator's "5nn" matches the rest of the
        // logging fields, which are uppercase throughout; stored trimmed so a
        // field holding only spaces reads as cleared and falls back to the
        // standard report.
        if (value is String) {
          await settings.setSettingValue(SettingsService.loggingGroup, fieldKey, value.trim().toUpperCase());
        }
      default:
        if (value is bool) await settings.setSettingValue(SettingsService.loggingGroup, fieldKey, value);
    }
  }
}

/// How the app behaves towards the radio it is driving — the settings the
/// Station panel's tune icon collects under `target: 'current-radio'`.
/// About the VFO the app follows, not about any one piece of equipment,
/// which is why these are here and not in an equipment node's own config.
class RadioSettingsGroup extends SettingsGroup {
  final SettingsService settings;

  RadioSettingsGroup(this.settings);

  @override
  String get key => 'radio';

  @override
  String get title => t.settings.radio.title;

  @override
  int get order => 15;

  @override
  Listenable? get listenable => settings;

  @override
  Future<List<Map<String, dynamic>>> buildElements() async {
    // Nothing here means anything without CAT, which is still behind the
    // Station Configuration experiment — an empty group renders nothing at
    // all (see settings_view.dart's _SettingsGroupForm), rather than a
    // section header over nothing.
    if (!settings.experimentEnabled('gato') /* stored key, see experiments.yaml */) return [];
    final s = t.settings.radio;
    return [
      _toggle(
        key: 'smartVfoSnap',
        label: s.smartVfoSnap.title,
        icon: 'magnet',
        description: settings.smartVfoSnap ? s.smartVfoSnap.descriptionOn : s.smartVfoSnap.descriptionOff,
        value: settings.smartVfoSnap,
        target: 'current-radio',
      ),
      // The feel, in the `-extended` bucket behind the dialog's "show more
      // settings" — four numbers nobody should have to meet to use the
      // feature, and which only mean anything once it's on.
      //
      // Emitted only in developer mode rather than merely flagged
      // `devMode: true`: the flag hides an element inside FormRenderer, but
      // the target dialog decides whether to offer "show more settings" from
      // whether the bucket is EMPTY, so flagging alone would leave everyone
      // else a disclosure that expands to nothing. The flag is set as well,
      // for the dev-mode accent and for All Settings.
      if (settings.smartVfoSnap && settings.developerMode) ...[
        _tuningSelect(
          key: 'smartVfoSnapDebounceMs',
          label: s.snapDebounce.title,
          description: s.snapDebounce.description,
          icon: 'timer-outline',
          value: settings.smartVfoSnapDebounce.inMilliseconds.toString(),
          options: SettingsService.smartVfoSnapDebounceOptions,
          unit: s.units.ms,
        ),
        _tuningSelect(
          key: 'smartVfoSnapLongMoveKHz',
          label: s.snapLongMove.title,
          description: s.snapLongMove.description,
          icon: 'arrow-expand-horizontal',
          value: _numText(settings.smartVfoSnapLongMoveKHz),
          options: SettingsService.smartVfoSnapLongMoveOptions,
          unit: s.units.kHz,
        ),
        _tuningSelect(
          key: 'smartVfoSnapMinMoveKHz',
          label: s.snapMinMove.title,
          description: s.snapMinMove.description,
          icon: 'arrow-collapse-horizontal',
          value: _numText(settings.smartVfoSnapMinMoveKHz),
          options: SettingsService.smartVfoSnapMinMoveOptions,
          unit: s.units.kHz,
        ),
        _tuningSelect(
          key: 'smartVfoSnapMinSpeed',
          label: s.snapMinSpeed.title,
          description: s.snapMinSpeed.description,
          icon: 'speedometer-slow',
          value: _numText(settings.smartVfoSnapMinSpeed),
          options: SettingsService.smartVfoSnapMinSpeedOptions,
          unit: s.units.kHzPerSecond,
        ),
      ],
      _toggle(
        key: 'avoidZeroBeat',
        aliases: const ['zeroBeat'],
        label: s.avoidZeroBeat.title,
        icon: 'tune-vertical',
        description: settings.avoidZeroBeat ? s.avoidZeroBeat.descriptionOn : s.avoidZeroBeat.descriptionOff,
        value: settings.avoidZeroBeat,
        target: 'current-radio',
      ),
      // Emitted with the feature, not with developer mode: whoever switched
      // it on is who would want to tune the spread. Still gated rather than
      // merely flagged, so it doesn't offer "show more settings" to someone
      // who has the feature off and would find nothing there.
      if (settings.avoidZeroBeat)
        _tuningSelect(
          key: 'zeroBeatRangeHz',
          devMode: false,
          label: s.zeroBeatRange.title,
          description: s.zeroBeatRange.description,
          icon: 'arrow-left-right',
          value: _numText(settings.zeroBeatRangeHz),
          options: SettingsService.zeroBeatRangeOptions,
          unit: s.units.hz,
        ),
      // The CW messages, under a target of their own: the Station dialog's
      // keyer row opens `cw-messages` as its own dialog (station_panel.dart),
      // and eight text fields among the radio's behaviour toggles would bury
      // both. Declared here rather than in a widget so SET/SHOW find them
      // and All Settings lists them like any other setting.
      {'type': 'markdown', 'text': s.cwMessages.description, 'target': 'cw-messages'},
      for (var n = 1; n <= SettingsService.cwMessageCount; n++) ...[
        _text(
          key: SettingsService.cwMessageKey(n),
          label: s.cwMessages.key(n: n),
          icon: 'numeric-$n-circle',
          value: settings.cwMessage(n),
          target: 'cw-messages',
        ),
        _text(
          key: SettingsService.cwMessageLabelKey(n),
          label: s.cwMessages.labelKey(n: n),
          icon: 'numeric-$n-circle-outline',
          value: settings.cwMessageLabel(n),
          target: 'cw-messages',
        ),
      ],
    ];
  }

  /// A radio tuning knob: a `select` over preset values rather than a `number`
  /// field, so trying one is a single tap and no half-typed value is ever
  /// committed and acted on.
  ///
  /// [devMode] is what separates Smart VFO Snap's four knobs — which nobody
  /// should have to meet, since that feature works without them — from the
  /// zero-beat range, which only exists once an operator has deliberately
  /// switched that feature on and is exactly who might want to tune it. Both
  /// stay in the `-extended` bucket, behind "show more settings".
  Map<String, dynamic> _tuningSelect({
    required String key,
    required String label,
    required String description,
    required String icon,
    required String value,
    required List<String> options,
    required String unit,
    bool devMode = true,
  }) {
    String labelFor(String option) => '$option $unit';
    // No fallback here: [value] comes from a getter that already resolved
    // the stored value against this same list (SettingsService's option
    // lists), so it always names an item. Falling back at THIS layer instead
    // would show one value while the snapper ran on another.
    assert(options.contains(value), 'a select whose value has no item throws when the dialog opens');

    return _select(
      key: key,
      label: label,
      icon: icon,
      // Current value first, then what it does. Every other select here puts
      // the value alone in this slot (theme, font scale) — but a knob nobody
      // can guess the meaning of from its name needs the sentence too, and a
      // row that shows only prose leaves the setting's actual value invisible
      // until it's opened.
      description: '${labelFor(value)} — $description',
      value: value,
      options: [for (final option in options) (label: labelFor(option), value: option)],
      target: 'current-radio-extended',
      devMode: devMode,
    );
  }

  @override
  Future<void> commit(String fieldKey, dynamic value) async {
    // The toggle is a bool; every tuning knob is one of its own option
    // strings. Anything else is a build mismatch and is dropped rather than
    // stored for a later parse to fall back from.
    if (value is! bool && value is! String) return;
    await settings.setSettingValue(SettingsService.radioGroup, fieldKey, value);
  }
}

/// A tuning value as its option string — `2.0` is offered as `'2'`, `0.25`
/// as `'0.25'`, so a stored value matches the dropdown's own items.
String _numText(double value) =>
    value == value.roundToDouble() ? value.toInt().toString() : '$value';

/// The Map tab's basemap picker (see map_panel.dart / map_gl_script.dart's
/// `mapLibreStyleUrl`) — the OSM backend has no equivalent choice to offer,
/// but that only matters on Linux, where this group still shows the field
/// (it just goes unused there). `target: 'map'` is what the tab's own
/// settings button (operation_view.dart) opens; the field is also reachable
/// from All Settings, same as every other target-scoped field.
class MapSettingsGroup extends SettingsGroup {
  final SettingsService settings;

  MapSettingsGroup(this.settings);

  @override
  String get key => 'map';

  @override
  String get title => t.settings.map.title;

  @override
  int get order => 17;

  @override
  Listenable? get listenable => settings;

  @override
  Future<List<Map<String, dynamic>>> buildElements() async {
    final s = t.settings.map;
    return [
      _select(
        key: 'mapStyle',
        label: s.style.title,
        icon: 'map-outline',
        value: settings.mapStyle.name,
        options: [
          for (final style in MapStyle.values)
            (label: t['settings.map.styleOpts.${style.name}'] as String, value: style.name),
        ],
        target: 'map',
      ),
    ];
  }

  @override
  Future<void> commit(String fieldKey, dynamic value) async {
    if (fieldKey != 'mapStyle' || value is! String) return;
    final style = MapStyle.values.firstWhere((e) => e.name == value, orElse: () => MapStyle.automatic);
    await settings.setMapStyle(style);
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
  // Also the clock: this group renders whether time travel is holding sync off,
  // and ending travel writes no setting — so a group listening only to settings
  // would keep saying "unavailable" over a control that works again.
  Listenable? get listenable => Listenable.merge([settings, ClockTravel.instance]);

  @override
  Future<List<Map<String, dynamic>>> buildElements() async {
    String account = '';
    if (settings.syncEnabled) {
      account = syncAccountLabel(settings.syncState['accountData']);
    }
    // Sync RUNS while the clock is travelled — what a travelled session may
    // write is bounded instead (docs/design/time.md §4) — so this row no
    // longer claims otherwise. It still names the offset, because a developer
    // reading "sync is on" while the clock sits days out deserves to see both
    // facts in one place. Developer-only and in English, like the DEVTT
    // command it names.
    final travelLabel = AppClock.instance.travelLabel;
    return [
      _toggle(
        key: 'enabled',
        label: t.settings.sync.enable,
        icon: 'cloud-sync',
        description: travelLabel != null
            ? 'Time travelling ($travelLabel) — only test data is written'
            : (account.isEmpty ? null : account),
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
