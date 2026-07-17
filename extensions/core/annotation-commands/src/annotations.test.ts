// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The SOLAR/WEATHER data shaping is what turns raw feeds into the log's
// annotation text, and its emoji thresholds and formats must match
// app-polo's exactly (both apps annotate the same synced logs) — so they
// are pinned here, against a real hamqsl.com response shape.

import assert from 'node:assert/strict'
import { describe, it } from 'node:test'

import {
  emojiForAIndex,
  emojiForKIndex,
  emojiForSFI,
  parseSolarXml,
  solarMessage,
  weatherMessage,
} from './annotations.ts'
import type { WeatherData } from './annotations.ts'

// Abridged from a real https://www.hamqsl.com/solarxml.php response —
// scalar readings plus the nested per-band conditions the parser must skip.
const SOLAR_XML = `<?xml version="1.0"?>
<solar>
  <solardata>
    <source url="http://www.hamqsl.com/solar.html">N0NBH</source>
    <updated>16 Jul 2026 1800 GMT</updated>
    <solarflux>117</solarflux>
    <aindex>14</aindex>
    <kindex>1</kindex>
    <kindexnt>No Report</kindexnt>
    <xray>B4.5</xray>
    <sunspots>60</sunspots>
    <heliumline>142.2</heliumline>
    <protonflux>158</protonflux>
    <electonflux>630</electonflux>
    <aurora>1</aurora>
    <normalization>1.99</normalization>
    <latdegree>67.5</latdegree>
    <solarwind>354.4</solarwind>
    <magneticfield>2.0</magneticfield>
    <calculatedconditions>
      <band name="80m-40m" time="day">Fair</band>
      <band name="30m-20m" time="day">Good</band>
    </calculatedconditions>
    <geomagfield>VR QUIET</geomagfield>
    <signalnoise>S0-S1</signalnoise>
    <fof2>5.85</fof2>
  </solardata>
</solar>`

describe('parseSolarXml', () => {
  it('extracts the scalar readings', () => {
    const data = parseSolarXml(SOLAR_XML)
    assert.equal(data.solarflux, '117')
    assert.equal(data.aindex, '14')
    assert.equal(data.kindex, '1')
    assert.equal(data.sunspots, '60')
    assert.equal(data.updated, '16 Jul 2026 1800 GMT')
    assert.equal(data.geomagfield, 'VR QUIET')
  })

  it('skips nested elements like the per-band conditions', () => {
    const data = parseSolarXml(SOLAR_XML)
    assert.equal(data.calculatedconditions, undefined)
    assert.equal(data.band, undefined)
  })

  it('returns an empty map for a non-XML error body', () => {
    assert.deepEqual(parseSolarXml('Service temporarily unavailable'), {})
  })
})

describe('solar emoji thresholds (must match app-polo)', () => {
  it('SFI: red < 100 ≤ yellow < 150 ≤ blue < 200 ≤ green', () => {
    assert.equal(emojiForSFI(99), '🔴')
    assert.equal(emojiForSFI(100), '🟡')
    assert.equal(emojiForSFI(149), '🟡')
    assert.equal(emojiForSFI(150), '🔵')
    assert.equal(emojiForSFI(199), '🔵')
    assert.equal(emojiForSFI(200), '🟢')
  })

  it('A index: green < 20 ≤ yellow < 30 ≤ red < 50 ≤ brown < 100 ≤ purple', () => {
    assert.equal(emojiForAIndex(19), '🟢')
    assert.equal(emojiForAIndex(20), '🟡')
    assert.equal(emojiForAIndex(30), '🔴')
    assert.equal(emojiForAIndex(50), '🟤')
    assert.equal(emojiForAIndex(100), '🟣')
  })

  it('K index: green ≤ 3 < yellow < 5 ≤ red < 7 ≤ purple', () => {
    assert.equal(emojiForKIndex(3), '🟢')
    assert.equal(emojiForKIndex(4), '🟡')
    assert.equal(emojiForKIndex(5), '🔴')
    assert.equal(emojiForKIndex(7), '🟣')
  })
})

describe('solarMessage', () => {
  it('formats the SFI/A/K/SN line exactly like app-polo', () => {
    const message = solarMessage(parseSolarXml(SOLAR_XML))
    assert.equal(message, '🟡SFI 117 • 🟢A 14 • 🟢K 1 • 😎SN 60')
  })
})

function weatherData(overrides: Partial<WeatherData['current']> = {}): WeatherData {
  return {
    current: {
      temperature_2m: 41.8,
      relative_humidity_2m: 50,
      wind_speed_10m: 14.3,
      weather_code: 3,
      is_day: 1,
      ...overrides,
    },
    current_units: {
      temperature_2m: '°F',
      wind_speed_10m: 'km/h',
    },
  }
}

describe('weatherMessage', () => {
  it('formats the conditions line exactly like app-polo', () => {
    assert.equal(weatherMessage(weatherData()), '🌥️ 41.8°F Cloudy 💧 50%, 💨 14.3km/h')
  })

  it('uses the night variant when is_day is 0', () => {
    const message = weatherMessage(weatherData({ weather_code: 0, is_day: 0 }))
    assert.equal(message, '🌙 41.8°F Clear 💧 50%, 💨 14.3km/h')
  })

  it('falls back to a generic emoji for an unknown weather code, omitting the description', () => {
    const message = weatherMessage(weatherData({ weather_code: 42 }))
    // Never the literal "undefined" — this string is stored in the log.
    assert.equal(message, '🌤️ 41.8°F 💧 50%, 💨 14.3km/h')
  })
})
