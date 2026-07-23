// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Annotation commands (ham2k/app-halo-dist#64), ported from app-polo's
// AnnotationCommands: NOTE/TODO capture free text, SOLAR/WEATHER capture
// current conditions, and all four add a non-QSO row to the log — an event
// pseudo-QSO (`band: 'event'`, see `Qso.isEvent`) via the `addQso` action,
// rendered as a yellow annotation row by the QSO list. This supersedes the
// original note-command extension, whose NOTE wrote to the in-progress
// QSO's notes field instead of the log timeline (the Notes logging control
// still covers that).
//
// SOLAR/WEATHER fetch in the background even on a describe-preview call
// (issue #189) — the fetch itself doesn't block interpret()'s own Promise,
// which still returns immediately with a placeholder describe; once the
// fetch resolves, host.updateInterpretation pushes the real reading so it
// shows in the UI before the user ever presses Enter. The one in-flight
// fetch is cached and reused by the execute call that actually logs the
// event, so pressing Enter doesn't trigger a second fetch.

import { defineExtension, host } from "@ham2k/halo-extension-sdk"
import type { CommandInterpretation, HookContext, JSONValue } from "@ham2k/halo-extension-sdk"
import { gridToLocation } from "@ham2k/lib-geo-tools"

import { parseSolarXml, solarMessage, weatherMessage } from "./annotations.ts"
import type { WeatherData } from "./annotations.ts"
import { tFor } from "./i18n.ts"

import manifest from "../manifest.json" with { type: "json" }

type Translator = ReturnType<typeof tFor>

type Operation = Record<string, JSONValue>

/// The event pseudo-QSO all four commands add — same sentinel shape as
/// app-polo's `newEventQSO` (our/their calls, `freq: 0`, `mode` mirroring
/// the event kind) so annotations sync between the two apps cleanly.
/// `startAtMillis` is deliberately omitted: `QsosRepository.add` stamps
/// "now" itself.
function eventQso(kind: string, event: Record<string, JSONValue>): Record<string, JSONValue> {
  return {
    band: 'event',
    freq: 0,
    mode: kind,
    our: { call: 'EVENT' },
    their: { call: kind.toUpperCase() },
    event: { event: kind, ...event },
  }
}

/// NOTE/TODO share everything but their words and icons: free-prose
/// parameter (mixedCase), operation-scoped, and an event row via addQso.
function noteLikeCommand({ pattern, kind, name, icon, describe, confirm, extra }: {
  pattern: RegExp
  kind: string
  name: string
  icon: string
  describe: (t: Translator, text: string) => string
  confirm: (t: Translator) => string
  extra?: Record<string, JSONValue>
}) {
  return {
    async interpret(
      { input, operation }: { input: string; operation?: Operation },
      ctx: HookContext,
    ): Promise<CommandInterpretation | null> {
      const match = pattern.exec(input.trim())
      if (!match) return null

      const t = tFor(ctx)
      if (!operation) return { error: t('needsOperation', { name }) }

      // `mixedCase` on both results: the text is free prose, so the call
      // field must not force it to uppercase — and it stays typed-as-is
      // even once the input is a complete command (see CommandInterpretation).
      const text = match[1]?.trim()
      if (!text) return { expectsParams: true, mixedCase: true }

      return {
        mixedCase: true,
        describe: describe(t, text),
        confirm: confirm(t),
        commands: [{
          addQso: eventQso(kind, { command: `${name} ${text}`, icon, note: text, ...extra }),
        }],
      }
    },
  }
}

const NoteCommand = noteLikeCommand({
  pattern: /^NOTES?(?:\s+(.*))?$/i,
  kind: 'note',
  name: 'NOTE',
  icon: 'sticker-text-outline',
  describe: (t, text) => t('addNote', { text }),
  confirm: (t) => t('noteAdded'),
})

const TodoCommand = noteLikeCommand({
  pattern: /^TODO(?:\s+(.*))?$/i,
  kind: 'todo',
  name: 'TODO',
  icon: 'sticker-outline',
  describe: (t, text) => t('addTodo', { text }),
  confirm: (t) => t('todoAdded'),
  extra: { data: { done: false } },
})

type SolarResult = { solarData: Record<string, string>; message: string } | null

async function fetchSolarData(): Promise<SolarResult> {
  try {
    const response = await host.fetch('https://www.hamqsl.com/solarxml.php')
    if (response.status !== 200) throw new Error(`status ${response.status}`)
    const solarData = parseSolarXml(response.body)
    // All four readings the message renders must be present — a partial or
    // reshaped response would otherwise store "undefined" text (and
    // NaN-driven alarm emoji) permanently in the log.
    if (!solarData.solarflux || !solarData.aindex || !solarData.kindex || !solarData.sunspots) {
      throw new Error('incomplete solar data in response')
    }
    return { solarData, message: solarMessage(solarData) }
  } catch {
    return null
  }
}

// The one in-flight/last-started fetch, shared by every interpret() call
// for "SOLAR" until an execute call consumes and clears it — see the file
// header comment.
let solarFetch: Promise<SolarResult> | null = null

const SolarCommand = {
  async interpret(
    { input, operation, execute }: { input: string; operation?: Operation; execute?: boolean },
    ctx: HookContext,
  ): Promise<CommandInterpretation | null> {
    if (input.trim().toUpperCase() !== 'SOLAR') return null

    const t = tFor(ctx)
    if (!operation) return { error: t('needsOperation', { name: 'SOLAR' }) }

    if (!solarFetch) {
      solarFetch = fetchSolarData()
      solarFetch.then((result) => {
        host.updateInterpretation(
          input,
          result ? { describe: result.message } : { describe: t('solarError') },
        )
      })
    }

    if (!execute) return { describe: t('fetchingSolar') }

    const promise = solarFetch
    solarFetch = null // next SOLAR (a later QSO) starts its own fresh fetch
    const result = await promise
    if (!result) return { error: t('solarError') }

    return {
      describe: result.message,
      confirm: result.message,
      commands: [{
        addQso: eventQso('solar', {
          command: 'SOLAR',
          icon: 'sun-wireless',
          description: result.message,
          data: result.solarData,
        }),
      }],
    }
  },
}

type WeatherResult = { weatherData: Record<string, JSONValue>; message: string } | null

async function fetchWeatherData(grid: string, distanceUnits: string | undefined): Promise<WeatherResult> {
  // Parsed loosely — the raw response is stored whole in the event's `data`;
  // WeatherData just gives weatherMessage a typed view of the fields it reads.
  try {
    const [latitude, longitude] = gridToLocation(grid)
    // Fahrenheit for miles users, Celsius otherwise — the same units
    // preference the map's distances follow, via HookContext.
    const params: Record<string, string> = {
      latitude: String(latitude),
      longitude: String(longitude),
      temperature_unit: distanceUnits === 'miles' ? 'fahrenheit' : 'celsius',
      current: 'temperature_2m,relative_humidity_2m,wind_speed_10m,precipitation,weather_code,wind_direction_10m,wind_gusts_10m,is_day',
      daily: 'sunrise,sunset',
    }
    const query = Object.entries(params)
      .map(([key, value]) => `${key}=${encodeURIComponent(value)}`)
      .join('&')
    const response = await host.fetch(`https://api.open-meteo.com/v1/forecast?${query}`)
    if (response.status !== 200) throw new Error(`status ${response.status}`)
    const weatherData = JSON.parse(response.body) as Record<string, JSONValue>
    if (!weatherData?.current) throw new Error('no weather data in response')
    return { weatherData, message: weatherMessage(weatherData as unknown as WeatherData) }
  } catch {
    return null
  }
}

// Same one-fetch-shared-until-executed cache as SOLAR's.
let weatherFetch: Promise<WeatherResult> | null = null

const WeatherCommand = {
  async interpret(
    { input, operation, execute }: { input: string; operation?: Operation; execute?: boolean },
    ctx: HookContext,
  ): Promise<CommandInterpretation | null> {
    if (input.trim().toUpperCase() !== 'WEATHER') return null

    const t = tFor(ctx)
    if (!operation) return { error: t('needsOperation', { name: 'WEATHER' }) }
    // app-polo falls back to device geolocation here; the extension runtime
    // has no location host call (yet), so the operation's own grid is the
    // one source of position.
    const grid = operation.grid
    if (typeof grid !== 'string' || !grid) {
      return { error: t('weatherNeedsLocation') }
    }

    if (!weatherFetch) {
      weatherFetch = fetchWeatherData(grid, ctx.distanceUnits)
      weatherFetch.then((result) => {
        host.updateInterpretation(input, result ? { describe: result.message } : { describe: t('weatherError') })
      })
    }

    if (!execute) return { describe: t('fetchingWeather') }

    const promise = weatherFetch
    weatherFetch = null // next WEATHER (a later QSO) starts its own fresh fetch
    const result = await promise
    if (!result) return { error: t('weatherError') }

    return {
      describe: result.message,
      confirm: result.message,
      commands: [{
        addQso: eventQso('weather', {
          command: 'WEATHER',
          icon: 'weather-sunny',
          description: result.message,
          data: result.weatherData,
        }),
      }],
    }
  },
}

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook('command', { key: 'annotation-commands-note', hook: NoteCommand, priority: 100 })
    registerHook('command', { key: 'annotation-commands-todo', hook: TodoCommand, priority: 100 })
    registerHook('command', { key: 'annotation-commands-solar', hook: SolarCommand, priority: 100 })
    registerHook('command', { key: 'annotation-commands-weather', hook: WeatherCommand, priority: 100 })
  },
})
