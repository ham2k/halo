// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Which language the app speaks, given the Language setting: what each
// language is called, which ones the setting lists, and what the locale
// means for formatting dates and numbers.

import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:intl/intl.dart';

import 'i18n/strings.g.dart';

/// The Language setting's value for "follow the device's language".
const systemLocaleSetting = 'system';

/// The joke locales (generated from English by
/// tool/generate_hidden_locales.dart): reached only by typing `LANG <code>`,
/// never listed in the Language setting or picked for a device.
const hiddenLocales = {AppLocale.cw, AppLocale.qrp, AppLocale.qro};

/// Each language's name in that language — the label it gets in the Language
/// setting whatever language the app is in, so a person who cannot read the
/// current one still finds their own. Every [AppLocale] needs an entry; a new
/// Crowdin language without one fails the halo_i18n tests.
const localeNames = <AppLocale, String>{
  AppLocale.en: 'English',
  AppLocale.ca: 'Català',
  AppLocale.cs: 'Čeština',
  AppLocale.cw: 'CW',
  AppLocale.de: 'Deutsch',
  AppLocale.es: 'Español',
  AppLocale.fr: 'Français',
  AppLocale.it: 'Italiano',
  AppLocale.ja: '日本語',
  AppLocale.ko: '한국어',
  AppLocale.nb: 'Norsk bokmål',
  AppLocale.nl: 'Nederlands',
  AppLocale.pt: 'Português',
  AppLocale.ptBr: 'Português (Brasil)',
  AppLocale.qrp: 'qrp',
  AppLocale.qro: 'QRO',
  AppLocale.ro: 'Română',
  AppLocale.sk: 'Slovenčina',
  AppLocale.tr: 'Türkçe',
  AppLocale.zh: '中文',
};

/// The languages the Language setting lists. In language-code order, which is
/// close to alphabetical by their own names; sorting the names themselves puts
/// "Čeština" after "Türkçe".
List<AppLocale> get selectableLocales {
  final locales = AppLocale.values.where((locale) => !hiddenLocales.contains(locale)).toList();
  return locales..sort((a, b) => a.languageTag.compareTo(b.languageTag));
}

/// Every [AppLocale.formattingLocale], for `MaterialApp.supportedLocales`:
/// Material matches its locale against this list, and would read `pt-PT` as
/// a bare (Brazilian) `pt` without it.
List<Locale> get formattingLocales => {for (final locale in AppLocale.values) locale.formattingLocale}.toList();

extension AppLocaleNames on AppLocale {
  /// This language's name in itself (see [localeNames]).
  String get nativeName => localeNames[this] ?? languageTag;

  /// How the Language setting stores this locale: `en`, `pt-BR`.
  String get languageTag => flutterLocale.toLanguageTag();

  /// The locale that dates, numbers, plurals and Flutter's own widgets use.
  /// Not always [flutterLocale]: intl and Material know no `cw`, `qrp` or
  /// `qro`, and `DateFormat` throws on a locale it does not know, so those read
  /// as English. And `pt` is Crowdin's European Portuguese, which intl and
  /// Material would read as Brazilian (counting 0 as singular).
  Locale get formattingLocale => switch (this) {
    AppLocale.pt => const Locale('pt', 'PT'),
    _ when hiddenLocales.contains(this) => AppLocale.en.flutterLocale,
    _ => flutterLocale,
  };
}

/// The locale a Language setting value stands for: a language tag the app has
/// strings for is that language; anything else — [systemLocaleSetting], or a
/// language this build no longer has — follows the device's preferred
/// languages, never landing on a hidden locale.
AppLocale resolveLocaleSetting(String setting, {List<Locale>? deviceLocales}) {
  for (final locale in AppLocale.values) {
    if (locale.languageTag == setting) return locale;
  }
  for (final device in deviceLocales ?? PlatformDispatcher.instance.locales) {
    // Some devices report Norwegian Bokmål under the macrolanguage, `no`.
    final languageCode = device.languageCode == 'no' ? 'nb' : device.languageCode;
    final locale = AppLocaleUtils.parseLocaleParts(languageCode: languageCode, scriptCode: device.scriptCode, countryCode: device.countryCode);
    if (locale.languageCode == languageCode && !hiddenLocales.contains(locale)) return locale;
  }
  return AppLocale.en;
}

/// Switches the strings and intl's default locale to what [setting] stands
/// for (see [resolveLocaleSetting]), and returns that locale.
///
/// Switches run one at a time, in the order asked for. On web a language's
/// strings load on first use, so without the queue a slow language picked
/// first lands after a quicker one picked second, leaving the app in the
/// language the person moved away from.
///
/// The plural rules come from intl, which has CLDR's for every language;
/// slang's own table covers only some of them and logs an error on every
/// plural it formats in the rest.
Future<AppLocale> applyLocaleSetting(String setting) {
  final locale = resolveLocaleSetting(setting);
  final applied = _applying.then((_) => _apply(locale));
  // The queue only orders the switches; a failure reaches the caller through
  // `applied`, and must not stop the next switch from running.
  _applying = applied.then((_) {}, onError: (_) {});
  return applied;
}

var _applying = Future<void>.value();

Future<AppLocale> _apply(AppLocale locale) async {
  final formatting = locale.formattingLocale.toString();
  Intl.defaultLocale = formatting;
  await LocaleSettings.setPluralResolver(
    locale: locale,
    // `other!`: every plural has an `other`, and a translation missing one
    // should fail loudly rather than render as nothing.
    cardinalResolver: (n, {zero, one, two, few, many, other}) =>
        Intl.pluralLogic(n, zero: zero, one: one, two: two, few: few, many: many, other: other!, locale: formatting),
  );
  await LocaleSettings.setLocale(locale);
  return locale;
}
