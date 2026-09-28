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

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'package:halo_i18n/halo_i18n.dart';
import '../services/cat_server/cat_server_service.dart';
import '../services/extensions/extension_service.dart';
import '../services/settings_service.dart';
import '../tools/sync_account_identity.dart';
import 'cat_server_dialog.dart';
import 'settings_registry.dart';

export 'export_settings_group.dart';

// Where the Privacy panel's policy links point.
const privacyPolicyUrl = 'https://ham2k.com/legal/privacy/';
const termsOfServiceUrl = 'https://ham2k.com/legal/terms-of-service/';

// The resolved decimal separator as a word, for the Number Formatting row.
// A locale whose separator is neither of the two the setting offers (Arabic
// writes ٫) shows the character itself rather than a wrong word.
String _decimalSeparatorName() {
  final separator = NumberFormatting.instance.decimalSeparator;
  return switch (separator) {
    ',' => t.settings.numberFormatSeparators.comma,
    '.' => t.settings.numberFormatSeparators.period,
    _ => separator,
  };
}

// The theme field's own icon switches with its current value so the row
// reflects what's actually selected, not just that it's a theme setting.
const _themeIcons = {'system': 'theme-light-dark', 'light': 'white-balance-sunny', 'dark': 'weather-night'};

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
  'description': ?description,
  'aliases': ?aliases,
  'value': value,
  'options': [
    for (final o in options) {'label': o.label, 'value': o.value},
  ],
  if (common) 'common': true,
  'environment': ?environment,
  'target': ?target,
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
  'description': ?description,
  'aliases': ?aliases,
  'value': value,
  'placeholder': ?placeholder,
  'target': ?target,
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
  'description': ?description,
  'aliases': ?aliases,
  'value': value,
  if (common) 'common': true,
  'environment': ?environment,
  'target': ?target,
};

/// Theme, language, font scale, units and the awake hold — the "User Interface" section.
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
        options: const [(label: 'English', value: 'en'), (label: 'Español', value: 'es')],
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
        options: [for (final unit in DistanceUnits.values) (label: t['settings.distanceUnitsOpts.${unit.name}'] as String, value: unit.name)],
        common: true,
      ),
      _select(
        key: 'numberFormat',
        aliases: const ['decimals', 'decimalSeparator'],
        label: t.settings.numberFormat,
        icon: 'numeric',
        // The explicit choices name themselves, matching distanceUnits above;
        // "follow system settings" does not say what the system settled on,
        // which is the only part an operator can't see from the row.
        description: switch (settings.numberFormatStyle) {
          NumberFormatStyle.locale => t.settings.numberFormatDescription.locale(separator: _decimalSeparatorName()),
          NumberFormatStyle.period => t.settings.numberFormatDescription.period,
          NumberFormatStyle.comma => t.settings.numberFormatDescription.comma,
        },
        value: settings.numberFormatStyle.name,
        options: [for (final style in NumberFormatStyle.values) (label: t['settings.numberFormatOpts.${style.name}'] as String, value: style.name)],
      ),
      _select(
        key: 'gridPrecision',
        aliases: const ['grid', 'gridDigits', 'locator'],
        label: t.settings.gridPrecision,
        icon: 'grid',
        // Just the digit count: its own key rather than the option label,
        // which carries an example grid the row has no room for.
        description: t['settings.gridPrecisionDescription.${settings.gridPrecision.name}'] as String,
        value: settings.gridPrecision.name,
        options: [for (final precision in GridPrecision.values) (label: t['settings.gridPrecisionOpts.${precision.name}'] as String, value: precision.name)],
      ),
      _toggle(
        key: 'keepDeviceAwake',
        aliases: const ['awake', 'sleep', 'screen'],
        label: t.settings.keepDeviceAwake.title,
        icon: settings.keepDeviceAwake ? 'lightbulb-on' : 'lightbulb-outline',
        description: settings.keepDeviceAwake ? t.settings.keepDeviceAwake.descriptionOn : t.settings.keepDeviceAwake.descriptionOff,
        value: settings.keepDeviceAwake,
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
    String labelFor(FontScale scale) => t['settings.fontScaleOpts.${scale == anchor ? current.name : scale.name}'] as String;

    return _select(
      key: 'fontScale',
      aliases: const ['fontSize'],
      label: t.settings.fontScale,
      icon: 'format-size',
      // Just the current scale's name (its option label).
      description: t['settings.fontScaleOpts.${current.name}'] as String,
      value: anchor.name,
      options: [for (final scale in FontScale.selectableValues) (label: labelFor(scale), value: scale.name)],
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
    );
  }

  @override
  Future<void> commit(String fieldKey, dynamic value) async {
    if (fieldKey == 'keepDeviceAwake') {
      if (value is bool) await settings.setKeepDeviceAwake(value);
      return;
    }
    if (value is! String) return;
    switch (fieldKey) {
      case 'themeMode':
        final mode = _enumByNameOrNull(ThemeMode.values, value);
        if (mode != null) await settings.setThemeMode(mode);
      case 'locale':
        await settings.setLocale(value);
        unawaited(LocaleSettings.setLocaleRaw(value));
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
      case 'gridPrecision':
        final precision = _enumByNameOrNull(GridPrecision.values, value);
        if (precision != null) await settings.setGridPrecision(precision);
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
        environment: 'ios,android',
        target: 'logging-extended',
      ),
      _select(
        key: 'dxFlags',
        label: s.countryFlags.title,
        icon: 'flag',
        // Its own key, not the option label: the row says what is happening
        // now, the dialog says what each choice would do.
        description: t['settings.logging.countryFlagsDescription.${settings.dxFlags.name}'] as String,
        value: settings.dxFlags.name,
        options: [for (final option in DxFlags.values) (label: t['settings.logging.countryFlags.${option.name}'] as String, value: option.name)],
        target: 'logging-extended',
      ),
      _toggle(
        key: 'suggestDefaultOperator',
        label: s.suggestDefaultOperator.title,
        icon: 'account-arrow-right',
        description: settings.suggestDefaultOperator ? s.suggestDefaultOperator.descriptionOn : s.suggestDefaultOperator.descriptionOff,
        value: settings.suggestDefaultOperator,
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
      // just Settings. Its two sub-options only make sense while the
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
        'common': true,
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
        'common': true,
        'target': 'logging-extended',
      },
      _toggle(key: 'showRSTFields', label: t.operation.menu.showRstFields, icon: 'signal', value: settings.showRSTFields, target: 'logging'),
      _toggle(key: 'showStateField', label: t.operation.menu.showStateField, icon: 'map', value: settings.showStateField, target: 'logging'),
      _toggle(key: 'showGridField', label: t.operation.menu.showGridField, icon: 'grid', value: settings.showGridField, target: 'logging'),
      _toggle(key: 'showQsoNumbers', label: t.operation.menu.showQsoNumbers, icon: 'counter', target: 'logging', value: settings.showQsoNumbers),
      _toggle(
        key: 'showDeletedQSOs',
        aliases: const ['deletedQSOs'],
        label: t.operation.menu.showDeletedQsos,
        icon: 'delete',
        value: settings.showDeletedQSOs,
        target: 'logging',
      ),
      _toggle(
        key: 'showDeletedOps',
        aliases: const ['deletedOps'],
        label: t.operation.menu.showDeletedOps,
        icon: 'delete',
        value: settings.showDeletedOps,
        target: 'logging-extended',
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

/// The Radio group's link to the Station panel, and the section heading over
/// it — both left out where the group is embedded IN that panel.
const moreStationSettingsKey = 'moreStationSettings';
const stationConfigurationSectionKey = 'stationConfigurationSection';

/// The Radio group's rows that open the two keyer dialogs.
const cwKeyerActionKey = 'cwKeyer';
const phoneKeyerActionKey = 'phoneKeyer';

/// How the app behaves towards the radio it is driving — the settings the
/// Station panel's tune icon collects under `target: 'current-radio'`.
/// About the VFO the app follows, not about any one piece of equipment,
/// which is why these are here and not in an equipment node's own config.
class RadioSettingsGroup extends SettingsGroup {
  final SettingsService settings;

  /// The CAT server, resolved only while its experiment is on and never on
  /// web. Null where there is none to offer — a test's settings alone.
  final CatServerService Function()? catServer;

  /// Open the dialogs behind [cwKeyerActionKey] and [phoneKeyerActionKey].
  /// Callbacks because the dialogs are views, which this layer does not
  /// import; HaLoServices supplies them where it registers the group.
  final Future<void> Function(BuildContext context)? openCwKeyer;
  final Future<void> Function(BuildContext context)? openPhoneKeyer;

  /// Whether the station has a transceiver of its own. The CAT features are
  /// left out without one — they have nothing to act on — and [inventory]
  /// says when the answer may have changed. Null answers yes: a test's
  /// settings alone.
  final bool Function()? hasTransceivers;
  final Listenable Function()? inventory;

  RadioSettingsGroup(this.settings, {this.catServer, this.openCwKeyer, this.openPhoneKeyer, this.hasTransceivers, this.inventory});

  CatServerService? get _catServer => kIsWeb || !catServerExperimentEnabled(settings) ? null : catServer?.call();

  @override
  String get key => 'radio';

  @override
  String get title => t.settings.radio.title;

  @override
  int get order => 15;

  /// The server as well as the settings: its row's status changes when a
  /// bind lands, a client connects or the radio comes and goes. One object
  /// for the section's life, whatever the experiment says — a form subscribes
  /// once and unsubscribes later, and must be handed the same thing both
  /// times.
  @override
  late final Listenable listenable = _RadioSectionChanges(settings, () => _catServer, inventory);

  @override
  Future<void> openAction(BuildContext context, String actionKey) async {
    switch (actionKey) {
      case _catServerAction:
        final server = _catServer;
        if (server == null) return;
        await showHaloDialog<void>(
          context: context,
          builder: (_) => CatServerDialog(service: server),
        );
      case cwKeyerActionKey:
        await openCwKeyer?.call(context);
      case phoneKeyerActionKey:
        await openPhoneKeyer?.call(context);
    }
  }

  static const _catServerAction = 'catServer';

  @override
  Future<List<Map<String, dynamic>>> buildElements() async {
    final s = t.settings.radio;
    final radios = hasTransceivers?.call() ?? true;
    return [
      // Declared either way, so SET and SHOW still reach them; unlisted with
      // no radio, so the settings screens leave out rows with nothing to act
      // on (the same `listed: false` the keyer's message fields use).
      for (final el in <Map<String, dynamic>>[
        {'type': 'header', 'style': 'section', 'title': s.tuningSection},
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
        // for the dev-mode accent and for Settings.
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
        // Each keyer is a dialog of its own (cw_messages_dialog.dart,
        // voice_messages_dialog.dart), reached from these two rows as from the
        // Station dialog's keyer row and the keyer area. The settings those
        // dialogs edit stay declared below, so SET/SHOW find them, but
        // `listed: false` keeps them off these rows: two dozen message fields
        // would bury the radio's own toggles. The rows' aliases are how the
        // Settings search still reaches them.
        // Behind the keyer experiment as well as CAT — the surfaces that key
        // them are.
        if (settings.experimentEnabled('keyer') /* stored key, see experiments.yaml */ ) ...[
          {'type': 'header', 'style': 'section', 'title': s.keyerSection},
          {
            'type': 'action',
            'style': 'row',
            'key': cwKeyerActionKey,
            'label': s.cwMessages.title,
            'icon': 'message-bulleted',
            'aliases': const ['cwMessages', 'cwMessageLabel', 'cwRepeatDelay', 'messages', 'macros', 'repeat', 'enterSendsMessages', 'esm'],
          },
          {
            'type': 'action',
            'style': 'row',
            'key': phoneKeyerActionKey,
            'label': s.voiceMessages.title,
            'icon': 'account-voice',
            'aliases': const ['voiceMessages', 'voiceMessageLabel', 'voiceRepeatDelay', 'voice memories', 'messages', 'repeat', 'enterSendsMessages', 'esm'],
          },
          for (final el in _keyerElements()) {...el, 'listed': false},
        ],
        if (_catServer case final server?) ...[
          {'type': 'header', 'style': 'section', 'title': s.servicesSection},
          {
            'type': 'action',
            'style': 'row',
            'key': _catServerAction,
            'label': t.settings.catServer.title,
            'description': catServerStatusText(server),
            'icon': 'lan-connect',
            // Also in the current radio's settings dialog, beside the other
            // things the Main VFO radio does.
            'target': 'current-radio',
          },
        ],
      ])
        radios ? el : {...el, 'listed': false},
      {'type': 'header', 'style': 'section', 'title': s.loggingAndCat},
      // What each QSO remembers about the station — shown with or without a
      // radio, since antenna and key are worth recording either way.
      _toggle(key: 'trackStationInfo', label: t.settings.station.trackStationInfo, icon: 'clipboard-text-outline', value: settings.trackStationInfo),
      if (settings.trackStationInfo)
        {
          'type': 'field',
          'fieldType': 'multiselect',
          'key': 'stationInfoTrackedFields',
          'label': t.settings.station.whatToTrack,
          'icon': 'format-list-checks',
          'value': [
            for (final opt in _stationInfoFieldOptions())
              if (settings.stationInfoTrackedFields.contains(opt['value'])) opt['value'],
          ],
          'defaultValue': SettingsService.defaultStationInfoTrackedFields,
          'options': _stationInfoFieldOptions(),
          'compact': true,
        },
      // Keyed, unlike the other headers, so a host that leaves the link out
      // (the Station panel, which IS where it goes) can leave its heading too.
      {'type': 'header', 'style': 'section', 'key': stationConfigurationSectionKey, 'title': s.stationConfigurationSection},
      {'type': 'link', 'key': moreStationSettingsKey, 'label': s.moreSettings, 'icon': 'cat', 'panel': 'station'},
    ];
  }

  static List<Map<String, String>> _stationInfoFieldOptions() {
    final st = t.settings.station;
    return [
      {'value': 'rig', 'label': st.trackFieldRig},
      {'value': 'power', 'label': st.trackFieldPower},
      {'value': 'antenna', 'label': st.trackFieldAntenna},
      {'value': 'key', 'label': st.trackFieldKey},
    ];
  }

  /// What the two keyer dialogs edit, as declared settings: the CW
  /// messages under `cw-messages`, the voice memory labels under
  /// `voice-messages`.
  List<Map<String, dynamic>> _keyerElements() {
    final s = t.settings.radio;
    return [
      // Message 1 only, which is what the circled 1 in the label says —
      // see SettingsService.cwRepeatDelay on why the others never repeat.
      _select(
        key: 'cwRepeatDelay',
        label: s.cwMessages.repeat,
        icon: 'repeat',
        value: '${settings.cwRepeatDelay.inSeconds}',
        options: [
          for (final option in SettingsService.cwRepeatDelayOptions)
            (label: option == '0' ? s.cwMessages.repeatOff : s.cwMessages.repeatAfter(n: option), value: option),
        ],
        target: 'cw-messages',
      ),
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
      // The voice memory labels, the same way, under `voice-messages`:
      // the audio is in the radio, so a label is all there is to edit.
      // The voice counterpart of the CW repeat, and the same rule: memory
      // 1 only, which is what the circled 1 in the label says.
      _select(
        key: 'voiceRepeatDelay',
        label: s.voiceMessages.repeat,
        icon: 'repeat',
        value: '${settings.voiceRepeatDelay.inSeconds}',
        options: [
          for (final option in SettingsService.cwRepeatDelayOptions)
            (label: option == '0' ? s.voiceMessages.repeatOff : s.voiceMessages.repeatAfter(n: option), value: option),
        ],
        target: 'voice-messages',
      ),
      for (var n = 1; n <= SettingsService.voiceMessageCount; n++)
        _text(
          key: SettingsService.voiceMessageLabelKey(n),
          label: s.voiceMessages.labelKey(n: n),
          icon: 'numeric-$n-circle-outline',
          value: settings.voiceMessageLabel(n),
          target: 'voice-messages',
        ),
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
    // The station-info pair lives in its own settings group, not this one.
    if (fieldKey == 'trackStationInfo' && value is bool) return settings.setTrackStationInfo(value);
    if (fieldKey == 'stationInfoTrackedFields' && value is List) return settings.setStationInfoTrackedFields(value.whereType<String>().toSet());
    // The toggle is a bool; every tuning knob is one of its own option
    // strings. Anything else is a build mismatch and is dropped rather than
    // stored for a later parse to fall back from.
    if (value is! bool && value is! String) return;
    // A message and its label live in the ACTIVE set, not under their own
    // key: writing the key directly would store a message nothing reads
    // (SettingsService.cwMessageKey).
    if (value is String) {
      for (var n = 1; n <= SettingsService.cwMessageCount; n++) {
        if (fieldKey == SettingsService.cwMessageKey(n)) return settings.setCwMessage(n, value);
        if (fieldKey == SettingsService.cwMessageLabelKey(n)) return settings.setCwMessageLabel(n, value);
      }
    }
    await settings.setSettingValue(SettingsService.radioGroup, fieldKey, value);
  }
}

/// The Radio section's changes: the settings always, and the CAT server's
/// whenever there is one to offer. Which server that is follows the settings
/// — the experiment can come on or go off while Settings is open — and it is
/// followed only while someone is listening, so an idle section keeps no
/// service alive.
class _RadioSectionChanges extends ChangeNotifier {
  final SettingsService settings;
  final CatServerService? Function() server;
  final Listenable Function()? inventory;

  _RadioSectionChanges(this.settings, this.server, this.inventory);

  Listenable? _inventory;

  var _listeners = 0;
  CatServerService? _followed;

  @override
  void addListener(VoidCallback listener) {
    if (_listeners++ == 0) {
      settings.addListener(_onSettings);
      _follow(server());
      _inventory = inventory?.call()?..addListener(notifyListeners);
    }
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (--_listeners == 0) {
      settings.removeListener(_onSettings);
      _follow(null);
      _inventory?.removeListener(notifyListeners);
      _inventory = null;
    }
  }

  void _onSettings() {
    _follow(server());
    notifyListeners();
  }

  void _follow(CatServerService? next) {
    if (identical(next, _followed)) return;
    _followed?.removeListener(notifyListeners);
    _followed = next;
    next?.addListener(notifyListeners);
  }
}

/// A tuning value as its option string — `2.0` is offered as `'2'`, `0.25`
/// as `'0.25'`, so a stored value matches the dropdown's own items.
String _numText(double value) => value == value.roundToDouble() ? value.toInt().toString() : '$value';

/// The Map tab's basemap picker (see map_panel.dart / map_gl_script.dart's
/// `mapLibreStyleUrl`) — the OSM backend has no equivalent choice to offer,
/// but that only matters on Linux, where this group still shows the field
/// (it just goes unused there). `target: 'map'` is what the tab's own
/// settings button (operation_view.dart) opens; the field is also reachable
/// from Settings, same as every other target-scoped field.
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
        options: [for (final style in MapStyle.values) (label: t['settings.map.styleOpts.${style.name}'] as String, value: style.name)],
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
  // Last of the core groups, and below the extension-contributed panels'
  // default order too (settings_view.dart) — consent and policy links are
  // what an operator looks up once, not what they come to Settings for. An
  // extension declaring a higher order of its own still sorts below this;
  // nothing clamps that, and nothing needs to.
  int get order => 200;

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
      {'type': 'link', 'key': 'privacyPolicy', 'label': s.privacyPolicy, 'icon': 'shield-account', 'url': privacyPolicyUrl},
      {'type': 'link', 'key': 'termsOfService', 'label': s.termsOfService, 'icon': 'file-document', 'url': termsOfServiceUrl},
    ];
  }

  @override
  Future<void> commit(String fieldKey, dynamic value) async {
    if (value is! bool) return;
    await settings.setSettingValue(SettingsService.privacyGroup, fieldKey, value);
  }
}

/// Sync's declarative representation for Settings: the enabled toggle
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
        description: travelLabel != null ? 'Time travelling ($travelLabel) — only test data is written' : (account.isEmpty ? null : account),
        value: settings.syncEnabled,
      ),
      {'type': 'link', 'key': 'moreSyncSettings', 'label': t.settings.sync.moreSettings, 'icon': 'cloud-cog', 'panel': 'sync'},
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
