// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Language setting's contract: every language Crowdin delivers can be
// found by its own name, "system" never lands on a joke locale, and a locale
// intl does not know never reaches intl.

import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

void main() {
  // The app has Material load intl's date data; here every locale's is loaded.
  setUpAll(initializeDateFormatting);
  tearDown(() => applyLocaleSetting('en'));

  test('every locale has a name of its own', () {
    // A language added on Crowdin and pulled without a name here would be
    // listed by its bare code.
    for (final locale in AppLocale.values) {
      expect(localeNames[locale], isNotNull, reason: '$locale has no entry in localeNames');
    }
  });

  test('the Language setting lists every real language and no hidden one', () {
    expect(selectableLocales.toSet(), AppLocale.values.toSet().difference(hiddenLocales));
    expect(selectableLocales, containsAll([AppLocale.en, AppLocale.es]));
  });

  group('resolveLocaleSetting', () {
    AppLocale system(List<Locale> device) => resolveLocaleSetting(systemLocaleSetting, deviceLocales: device);

    test('follows the first device language the app has', () {
      expect(system(const [Locale('xx'), Locale('de', 'AT'), Locale('fr')]), AppLocale.de);
    });

    test('tells the two Portugueses apart', () {
      expect(system(const [Locale('pt', 'BR')]), AppLocale.ptBr);
      expect(system(const [Locale('pt', 'PT')]), AppLocale.pt);
    });

    test('reads Norwegian reported as the macrolanguage as Bokmål', () {
      expect(system(const [Locale('no')]), AppLocale.nb);
    });

    test('falls back to English when the device has no language the app has', () {
      expect(system(const [Locale('xx')]), AppLocale.en);
    });

    test('never picks a hidden locale for a device', () {
      // `cw` is no ISO 639 code, but nothing stops a platform reporting one.
      expect(system(const [Locale('cw'), Locale('qro')]), AppLocale.en);
    });

    test('takes an explicit choice as a language tag, hidden ones included', () {
      expect(resolveLocaleSetting('pt-BR'), AppLocale.ptBr);
      expect(resolveLocaleSetting('cw'), AppLocale.cw);
    });

    test('follows the device for a language this build has no strings for', () {
      // A stored "pl" from a newer build, or a language since dropped: the
      // picker labels it "Follow system settings", so that is what it does.
      expect(resolveLocaleSetting('pl', deviceLocales: const [Locale('de')]), AppLocale.de);
      // slang would match "xx-BR" to Brazilian Portuguese by country alone.
      expect(resolveLocaleSetting('xx-BR', deviceLocales: const [Locale('de')]), AppLocale.de);
    });
  });

  test('a hidden locale formats as English', () async {
    // DateFormat throws on a locale intl has no data for, so `cw` reaching
    // Intl.defaultLocale would break every date the app shows.
    await applyLocaleSetting('cw');
    expect(LocaleSettings.currentLocale, AppLocale.cw);
    expect(Intl.defaultLocale, 'en');
    expect(DateFormat.yMMMd().format(DateTime.utc(2026, 10, 12)), 'Oct 12, 2026');
  });

  test('plurals follow the language rules slang has no table for', () async {
    // Turkish is absent from slang's own plural table, so without the intl
    // resolver it logs an error and guesses on every plural it formats.
    await applyLocaleSetting('tr');
    String resolve(num n) => LocaleSettings.instance.currentTranslations.$meta.cardinalResolver!(n, one: 'one', other: 'other');
    expect(resolve(1), 'one');
    expect(resolve(3), 'other');

    // Czech has a `few` category the English source does not: it reads `other`.
    await applyLocaleSetting('cs');
    expect(LocaleSettings.instance.currentTranslations.$meta.cardinalResolver!(3, one: 'one', other: 'other'), 'other');

    // Crowdin's `pt` is European Portuguese, where 0 is plural; intl's bare
    // `pt` is Brazilian, where it is singular ("0 extensão").
    await applyLocaleSetting('pt');
    expect(LocaleSettings.instance.currentTranslations.$meta.cardinalResolver!(0, one: 'one', other: 'other'), 'other');
    await applyLocaleSetting('pt-BR');
    expect(LocaleSettings.instance.currentTranslations.$meta.cardinalResolver!(0, one: 'one', other: 'other'), 'one');
  });

  test('switches land in the order they were asked for', () async {
    // On web a language loads on first use; one picked first and still loading
    // must not land after one picked second.
    final first = applyLocaleSetting('ja');
    final second = applyLocaleSetting('en');
    await Future.wait([first, second]);
    expect(LocaleSettings.currentLocale, AppLocale.en);
    expect(Intl.defaultLocale, 'en');
  });

  test('every plural Crowdin delivers has an `other`', () {
    // Crowdin exports `one` and `other` as separate strings, so a pull with
    // only `one` translated leaves a plural no count above 1 can render.
    const forms = {'zero', 'one', 'two', 'few', 'many', 'other'};
    void check(String file, String path, Object? node) {
      if (node is! Map<String, dynamic>) return;
      if (node.isNotEmpty && node.keys.every(forms.contains)) {
        expect(node.keys, contains('other'), reason: '$file: $path');
        return;
      }
      for (final MapEntry(:key, :value) in node.entries) {
        check(file, '$path.$key', value);
      }
    }

    for (final file in Directory('lib/i18n/crowdin').listSync().whereType<File>()) {
      check(file.path, '', jsonDecode(file.readAsStringSync()));
    }
  });
}
