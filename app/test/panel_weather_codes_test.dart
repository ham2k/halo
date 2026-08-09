// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The weather-code table, and the i18n bundle behind it.
//
// The coverage test is the point of this file. A description key with no
// string behind it renders as a raw identifier — but only in the sky that
// produces it, so a developer whose own weather is fine never sees it, and
// neither does any test that pumps one fixed forecast.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/views/operation/weather/weather_codes.dart';
import 'package:halo_widgets/halo_widgets.dart';

void main() {
  group('day and night are different skies', () {
    test('a clear sky is named and drawn differently after dark', () {
      expect(weatherConditionFor(0, isDay: true), (icon: MdiIcons.weatherSunny, key: 'sunny'));
      expect(weatherConditionFor(0, isDay: false), (icon: MdiIcons.weatherNight, key: 'clear'));
    });

    test('a code with no night NAME still gets a night GLYPH', () {
      // app-polo names only 0 and 1 differently after dark, so 2 keeps
      // "Partly Cloudy" — but a sun glyph beside a 22:00 clock reads as a
      // bug, which is why the icon and the description fall back separately.
      final night = weatherConditionFor(2, isDay: false);
      expect(night.key, 'partlyCloudy');
      expect(night.icon, MdiIcons.weatherNightPartlyCloudy);
    });

    test('a code with neither variant falls back to the day entry, not to nothing', () {
      expect(weatherConditionFor(45, isDay: false), weatherConditionFor(45, isDay: true));
    });
  });

  group('an unknown sky says so', () {
    test('rather than resolving to a plausible wrong one', () {
      // An operator deciding whether to strike a mast is owed the difference
      // between "cloudy" and "we don't know". A fallback to code 3 here would
      // be indistinguishable on screen from a real reading.
      for (final code in [null, 4, 42, 100, -1]) {
        final condition = weatherConditionFor(code, isDay: true);
        expect(condition.key, 'unknown', reason: 'code $code');
        expect(condition.icon, MdiIcons.weatherCloudyAlert, reason: 'code $code');
      }
    });
  });

  group('every key the table can produce has a string in every locale', () {
    for (final locale in AppLocale.values) {
      // `build`, not `buildSync`: every locale but the base one is a deferred
      // library, and buildSync throws on it rather than loading it — so a
      // sync sweep silently covers English only, which is the one locale a
      // missing key would never be missing from.
      test(locale.languageTag, () async {
        final t = await locale.build();
        for (final key in weatherConditionKeys) {
          final text = t['operation.layout.panels.weatherConditions.$key'];
          expect(text, isA<String>(), reason: '$key is missing from ${locale.languageTag}');
          expect(text, isNotEmpty, reason: '$key is empty in ${locale.languageTag}');
        }
      });
    }
  });
}
