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
// SOLAR/WEATHER fetch on `execute` only (the describe preview must stay
// cheap — see CommandHook.interpret), so the fetched readings land in both
// the stored event and the `confirm` message.

import { defineExtension, host } from "@ham2k/halo-extension-sdk"
import type { CommandInterpretation, HookContext, JSONValue } from "@ham2k/halo-extension-sdk"
import { gridToLocation } from "@ham2k/lib-geo-tools"

import { parseSolarXml, solarMessage, weatherMessage } from "./annotations.ts"
import type { WeatherData } from "./annotations.ts"

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
  describe: (text: string) => string
  confirm: string
  extra?: Record<string, JSONValue>
}) {
  return {
    async interpret(
      { input, operation }: { input: string; operation?: Operation },
      _ctx: HookContext,
    ): Promise<CommandInterpretation | null> {
      const match = pattern.exec(input.trim())
      if (!match) return null

      if (!operation) return { error: `${name} needs an open operation` }

      // `mixedCase` on both results: the text is free prose, so the call
      // field must not force it to uppercase — and it stays typed-as-is
      // even once the input is a complete command (see CommandInterpretation).
      const text = match[1]?.trim()
      if (!text) return { expectsParams: true, mixedCase: true }

      return {
        mixedCase: true,
        describe: describe(text),
        confirm,
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
  describe: (text) => `Add note “${text}”?`,
  confirm: 'Note added',
})

const TodoCommand = noteLikeCommand({
  pattern: /^TODO(?:\s+(.*))?$/i,
  kind: 'todo',
  name: 'TODO',
  icon: 'sticker-outline',
  describe: (text) => `Add to-do “${text}”?`,
  confirm: 'To-do added',
  extra: { data: { done: false } },
})

const SolarCommand = {
  async interpret(
    { input, operation, execute }: { input: string; operation?: Operation; execute?: boolean },
    _ctx: HookContext,
  ): Promise<CommandInterpretation | null> {
    if (input.trim().toUpperCase() !== 'SOLAR') return null

    if (!operation) return { error: 'SOLAR needs an open operation' }

    // The describe preview reruns on every keystroke pause — never fetch
    // there (see CommandHook.interpret's `execute` doc).
    if (!execute) return { describe: 'Add current solar conditions to the log?' }

    let solarData: Record<string, string>
    try {
      const response = await host.fetch('https://www.hamqsl.com/solarxml.php')
      if (response.status !== 200) throw new Error(`status ${response.status}`)
      solarData = parseSolarXml(response.body)
      // All four readings the message renders must be present — a partial
      // or reshaped response would otherwise store "undefined" text (and
      // NaN-driven alarm emoji) permanently in the log.
      if (!solarData.solarflux || !solarData.aindex || !solarData.kindex || !solarData.sunspots) {
        throw new Error('incomplete solar data in response')
      }
    } catch {
      return { error: 'Error fetching solar conditions' }
    }

    const message = solarMessage(solarData)
    return {
      describe: 'Add current solar conditions to the log?',
      confirm: message,
      commands: [{
        addQso: eventQso('solar', {
          command: 'SOLAR',
          icon: 'sun-wireless',
          description: message,
          data: solarData,
        }),
      }],
    }
  },
}

const WeatherCommand = {
  async interpret(
    { input, operation, execute }: { input: string; operation?: Operation; execute?: boolean },
    _ctx: HookContext,
  ): Promise<CommandInterpretation | null> {
    if (input.trim().toUpperCase() !== 'WEATHER') return null

    if (!operation) return { error: 'WEATHER needs an open operation' }
    // app-polo falls back to device geolocation here; the extension runtime
    // has no location host call (yet), so the operation's own grid is the
    // one source of position.
    const grid = operation.grid
    if (typeof grid !== 'string' || !grid) {
      return { error: 'WEATHER needs a location — set the operation’s grid square' }
    }

    if (!execute) return { describe: 'Add current weather to the log?' }

    // Parsed loosely — the raw response is stored whole in the event's
    // `data`; WeatherData just gives weatherMessage a typed view of the
    // fields it reads.
    let weatherData: Record<string, JSONValue>
    try {
      const [latitude, longitude] = gridToLocation(grid)
      const { distanceUnits } = await host.getCoreSettings()
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
      weatherData = JSON.parse(response.body) as Record<string, JSONValue>
      if (!weatherData?.current) throw new Error('no weather data in response')
    } catch {
      return { error: 'Error fetching weather' }
    }

    const message = weatherMessage(weatherData as unknown as WeatherData)
    return {
      describe: 'Add current weather to the log?',
      confirm: message,
      commands: [{
        addQso: eventQso('weather', {
          command: 'WEATHER',
          icon: 'weather-sunny',
          description: message,
          data: weatherData,
        }),
      }],
    }
  },
}

defineExtension({
  key: 'annotation-commands',
  name: 'Annotation Commands',
  version: '0.0.1',
  description: 'NOTE, TODO, SOLAR and WEATHER call-field commands that add annotation rows to the log',
  onActivation({ registerHook }) {
    registerHook('command', { key: 'annotation-commands-note', hook: NoteCommand, priority: 100 })
    registerHook('command', { key: 'annotation-commands-todo', hook: TodoCommand, priority: 100 })
    registerHook('command', { key: 'annotation-commands-solar', hook: SolarCommand, priority: 100 })
    registerHook('command', { key: 'annotation-commands-weather', hook: WeatherCommand, priority: 100 })
  },
})
