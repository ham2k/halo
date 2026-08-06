// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Shaping solar and weather readings into something readable — shared
// because two extensions render the same numbers: the SOLAR/WEATHER
// commands, which write an annotation into the log, and the dashboard
// panels, which show them in a pane. One place decides what an SFI of 180
// looks like, so a command and a panel can never disagree about it.
//
// Pure, so it unit-tests without the kernel. Message formats, emoji
// thresholds, and the Open-Meteo weather-code table are ported verbatim
// from app-polo's AnnotationCommands.js so both apps annotate logs
// identically.

/// Extracts every flat `<tag>text</tag>` pair from hamqsl.com's solar XML
/// (https://www.hamqsl.com/solarxml.php) into a map, trimmed. Nested
/// elements (`calculatedconditions`'s per-band entries) are skipped — the
/// message and stored data only need the scalar readings (solarflux,
/// aindex, kindex, sunspots…), so a full XML parser would be a bundled
/// dependency for nothing.
export function parseSolarXml(body: string): Record<string, string> {
  const data: Record<string, string> = {}
  const tagPattern = /<(\w+)>([^<>]*)<\/\1>/g
  let match
  while ((match = tagPattern.exec(body)) !== null) {
    data[match[1]] = match[2].trim()
  }
  return data
}

export function emojiForSFI(sfi: number): string {
  if (sfi < 100) return '🔴'
  else if (sfi < 150) return '🟡'
  else if (sfi < 200) return '🔵'
  else return '🟢'
}

export function emojiForAIndex(aindex: number): string {
  if (aindex < 20) return '🟢'
  else if (aindex < 30) return '🟡'
  else if (aindex < 50) return '🔴'
  else if (aindex < 100) return '🟤'
  else return '🟣'
}

export function emojiForKIndex(kindex: number): string {
  if (kindex <= 3) return '🟢'
  else if (kindex < 5) return '🟡'
  else if (kindex < 7) return '🔴'
  else return '🟣'
}

/// "🟡SFI 117 • 🟢A 14 • 🟢K 1 • 😎SN 60" — same format as app-polo
/// (including its constant 😎 for the sunspot number).
export function solarMessage(solarData: Record<string, string>): string {
  return `${emojiForSFI(Number(solarData.solarflux))}SFI ${solarData.solarflux} ` +
    `• ${emojiForAIndex(Number(solarData.aindex))}A ${solarData.aindex} ` +
    `• ${emojiForKIndex(Number(solarData.kindex))}K ${solarData.kindex} ` +
    `• 😎SN ${solarData.sunspots}`
}

interface WeatherCode {
  description: string
  emoji: string
  nightDescription?: string
  nightEmoji?: string
}

/// Open-Meteo `weather_code` → description/emoji, with day/night variants —
/// ported from app-polo's WEATHER_CODES.
export const WEATHER_CODES: Record<number, WeatherCode> = {
  0: { description: 'Sunny', emoji: '☀️', nightDescription: 'Clear', nightEmoji: '🌙' },
  1: { description: 'Mainly Sunny', emoji: '☀️', nightDescription: 'Mainly Clear', nightEmoji: '🌙' },
  2: { description: 'Partly Cloudy', emoji: '🌤️' },
  3: { description: 'Cloudy', emoji: '🌥️' },
  45: { description: 'Foggy', emoji: '🌫️' },
  48: { description: 'Rime Fog', emoji: '🌫️' },
  51: { description: 'Light Drizzle', emoji: '🌧️' },
  53: { description: 'Drizzle', emoji: '🌧️' },
  55: { description: 'Heavy Drizzle', emoji: '🌧️' },
  56: { description: 'Light Freezing Drizzle', emoji: '🌧️' },
  57: { description: 'Freezing Drizzle', emoji: '🌧️' },
  61: { description: 'Light Rain', emoji: '🌧️' },
  63: { description: 'Rain', emoji: '🌧️' },
  65: { description: 'Heavy Rain', emoji: '🌧️' },
  66: { description: 'Light Freezing Rain', emoji: '🌧️' },
  67: { description: 'Freezing Rain', emoji: '🌧️' },
  71: { description: 'Light Snow', emoji: '🌨️' },
  73: { description: 'Snow', emoji: '🌨️' },
  75: { description: 'Heavy Snow', emoji: '🌨️' },
  77: { description: 'Snow Grains', emoji: '🌨️' },
  80: { description: 'Light Showers', emoji: '🌧️' },
  81: { description: 'Showers', emoji: '🌧️' },
  82: { description: 'Heavy Showers', emoji: '🌧️' },
  85: { description: 'Light Snow Showers', emoji: '🌨️' },
  86: { description: 'Snow Showers', emoji: '🌨️' },
  95: { description: 'Thunderstorm', emoji: '⛈️' },
  96: { description: 'Light Thunderstorms With Hail', emoji: '⛈️' },
  99: { description: 'Thunderstorm With Hail', emoji: '⛈️' },
}

/// Loosely typed on purpose: this is the raw Open-Meteo response, stored
/// whole in the event's `data` — only the fields used here are named.
export interface WeatherData {
  current: {
    temperature_2m: number
    relative_humidity_2m: number
    wind_speed_10m: number
    weather_code: number
    is_day: number
  }
  current_units: {
    temperature_2m: string
    wind_speed_10m: string
  }
}

/// "🌥️ 41.8°F Cloudy 💧 50%, 💨 14.3km/h" — same format as app-polo.
/// An unknown `weather_code` falls back to a generic emoji and simply
/// omits the description — never the literal text "undefined", which
/// would be stored permanently in the log.
export function weatherMessage(weatherData: WeatherData): string {
  const current = WEATHER_CODES[weatherData.current.weather_code]
  const currentEmoji = (weatherData.current.is_day
    ? current?.emoji
    : (current?.nightEmoji ?? current?.emoji)) || '🌤️'
  const currentDescription = weatherData.current.is_day
    ? current?.description
    : (current?.nightDescription ?? current?.description)

  return [
    currentEmoji,
    `${weatherData.current.temperature_2m}${weatherData.current_units.temperature_2m}`,
    currentDescription,
    `💧 ${weatherData.current.relative_humidity_2m}%,`,
    `💨 ${weatherData.current.wind_speed_10m}${weatherData.current_units.wind_speed_10m}`,
  ].filter(Boolean).join(' ')
}
