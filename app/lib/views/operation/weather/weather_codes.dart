// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Open-Meteo's `weather_code` → the glyph the panel draws and the key its
// description is looked up under.
//
// This is a SECOND table. `extensions/shared/spaceWeather.ts` holds the same
// codes for the SOLAR/WEATHER commands, which annotate the log from inside
// the extension runtime and cannot reach Dart. Both are ports of app-polo's
// WEATHER_CODES, so a code Open-Meteo adds has to be added in both places or
// a command and a panel describe the same sky differently.
//
// The GLYPHS deliberately diverge from that table's emoji: the app's icon
// language is MDI (docs/design/user-interface.md), and emoji do not render at
// all on Windows.

import 'package:flutter/widgets.dart';
import 'package:halo_widgets/halo_widgets.dart';

/// One sky, as this panel draws it. [key] indexes
/// `operation.layout.panels.weatherConditions` in the i18n bundle rather than
/// carrying the text, so the table stays const and free of a BuildContext.
typedef WeatherCondition = ({IconData icon, String key});

class _Sky {
  final IconData icon;
  final String key;

  /// Night variants, null where the sky looks and reads the same after dark —
  /// fog is fog. A null here falls back to the day entry rather than to a
  /// generic glyph, which is what keeps a night reading from being worse than
  /// a day one.
  final IconData? nightIcon;
  final String? nightKey;

  const _Sky(this.icon, this.key, {this.nightIcon, this.nightKey});
}

/// Night ICONS run one code further than the night DESCRIPTIONS: app-polo
/// names only 0 and 1 differently after dark ("Clear", "Mainly Clear"), but a
/// partly cloudy night is still drawn with a moon, because a sun glyph on a
/// panel next to a 22:00 clock reads as a bug.
const _skies = <int, _Sky>{
  0: _Sky(MdiIcons.weatherSunny, 'sunny', nightIcon: MdiIcons.weatherNight, nightKey: 'clear'),
  1: _Sky(MdiIcons.weatherSunny, 'mainlySunny', nightIcon: MdiIcons.weatherNight, nightKey: 'mainlyClear'),
  2: _Sky(MdiIcons.weatherPartlyCloudy, 'partlyCloudy', nightIcon: MdiIcons.weatherNightPartlyCloudy),
  3: _Sky(MdiIcons.weatherCloudy, 'cloudy'),
  45: _Sky(MdiIcons.weatherFog, 'foggy'),
  48: _Sky(MdiIcons.weatherFog, 'rimeFog'),
  51: _Sky(MdiIcons.weatherRainy, 'lightDrizzle'),
  53: _Sky(MdiIcons.weatherRainy, 'drizzle'),
  55: _Sky(MdiIcons.weatherRainy, 'heavyDrizzle'),
  56: _Sky(MdiIcons.weatherSnowyRainy, 'lightFreezingDrizzle'),
  57: _Sky(MdiIcons.weatherSnowyRainy, 'freezingDrizzle'),
  61: _Sky(MdiIcons.weatherRainy, 'lightRain'),
  63: _Sky(MdiIcons.weatherPouring, 'rain'),
  65: _Sky(MdiIcons.weatherPouring, 'heavyRain'),
  66: _Sky(MdiIcons.weatherSnowyRainy, 'lightFreezingRain'),
  67: _Sky(MdiIcons.weatherSnowyRainy, 'freezingRain'),
  71: _Sky(MdiIcons.weatherSnowy, 'lightSnow'),
  73: _Sky(MdiIcons.weatherSnowy, 'snow'),
  75: _Sky(MdiIcons.weatherSnowyHeavy, 'heavySnow'),
  77: _Sky(MdiIcons.weatherSnowy, 'snowGrains'),
  80: _Sky(MdiIcons.weatherPartlyRainy, 'lightShowers'),
  81: _Sky(MdiIcons.weatherRainy, 'showers'),
  82: _Sky(MdiIcons.weatherPouring, 'heavyShowers'),
  85: _Sky(MdiIcons.weatherPartlySnowy, 'lightSnowShowers'),
  86: _Sky(MdiIcons.weatherSnowy, 'snowShowers'),
  95: _Sky(MdiIcons.weatherLightningRainy, 'thunderstorm'),
  96: _Sky(MdiIcons.weatherHail, 'lightThunderstormsWithHail'),
  99: _Sky(MdiIcons.weatherHail, 'thunderstormWithHail'),
};

/// The sky [code] names, drawn for day or night.
///
/// A code this table does not know — Open-Meteo adding one, or a reshaped
/// feed — resolves to `unknown` with an alert glyph rather than to a plausible
/// wrong sky. An operator deciding whether to strike a mast is owed the
/// difference between "cloudy" and "we don't know".
WeatherCondition weatherConditionFor(int? code, {required bool isDay}) {
  final sky = _skies[code];
  if (sky == null) return (icon: MdiIcons.weatherCloudyAlert, key: 'unknown');
  if (isDay) return (icon: sky.icon, key: sky.key);
  return (icon: sky.nightIcon ?? sky.icon, key: sky.nightKey ?? sky.key);
}

/// Every description key this table can produce, for the test that holds the
/// i18n bundle to it. A key with no string behind it renders as a raw
/// identifier on the panel, and only in the sky that produces it — which is
/// not a thing a developer trips over on their own screen.
Set<String> get weatherConditionKeys => {
  'unknown',
  for (final sky in _skies.values) ...[sky.key, if (sky.nightKey != null) sky.nightKey!],
};
