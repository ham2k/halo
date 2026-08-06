// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Current conditions in a pane, from Open-Meteo and the same weather-code
// table the WEATHER command writes into the log
// (extensions/shared/spaceWeather.ts).
//
// Location comes from the OPERATION's grid, so the panel works the moment
// it is placed, with a settings override for a grid square or lat/lon —
// handy for checking a summit before driving to it. Deliberately not the
// device's GPS: that is a permission prompt and a capability declaration
// for a panel that only wants a rough position, and the operation already
// knows one.
//
// The caching shape is solar-panel's, and for the same reason: `render` has
// a five-second budget host-side, so it answers from cache and refreshes
// behind itself. See that file for the reasoning.

import { defineExtension, host } from "@ham2k/halo-extension-sdk"
import type { HookContext, PanelContent, PanelDescriptor, PanelHook, PanelRenderArgs } from "@ham2k/halo-extension-sdk"
import { WEATHER_CODES } from "../../../shared/spaceWeather.ts"
import { readingAge } from "../../../shared/freshness.ts"
import { parseLocation } from "./location.ts"
import manifest from "../manifest.json"

const PREVIEW = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
  <circle cx="9" cy="9" r="4" fill="#f5a623"/>
  <path d="M17.5 19h-9a4 4 0 010-8 5.5 5.5 0 0110.4 1.6A3.2 3.2 0 0117.5 19z" fill="#00b4e6"/>
</svg>`

const MAX_AGE_MS = 15 * 60 * 1000
const FETCH_TIMEOUT_MS = 4000

type Reading = { at: number; key: string; data: WeatherResponse }

interface WeatherResponse {
  current: {
    temperature_2m: number
    relative_humidity_2m: number
    wind_speed_10m: number
    wind_gusts_10m: number
    wind_direction_10m: number
    precipitation: number
    weather_code: number
    is_day: number
  }
  current_units: Record<string, string>
  // Seconds since the epoch, because the request asks for
  // `timeformat=unixtime` — the default is an ISO string.
  daily?: { sunrise?: number[]; sunset?: number[] }
}

let cached: Reading | null = null

/// Keyed by WHAT it is fetching, not merely "a fetch is running". A pane
/// asking for a location while an older request for a different one is in
/// flight would otherwise be handed that request's promise, find the cache
/// still holding the wrong place when it resolves, and tell the operator the
/// service is unreachable — right after they typed a valid location on a
/// working network. The SOLAR/WEATHER commands key theirs for the same
/// reason.
let inFlight: { key: string; promise: Promise<void> } | null = null

/// Why the last fetch failed, for the operator. Kept apart from `cached` so
/// a failure never erases a good reading — and so the panel can say whether
/// the service answered badly or never answered at all, which are different
/// problems with different remedies.
let lastFailure: { at: number; transport: boolean; message: string } | null = null

function refresh(latitude: number, longitude: number, fahrenheit: boolean, key: string): Promise<void> {
  if (inFlight?.key === key) return inFlight.promise
  const promise = (async () => {
    try {
      const params: Record<string, string> = {
        latitude: String(latitude),
        longitude: String(longitude),
        temperature_unit: fahrenheit ? "fahrenheit" : "celsius",
        // Kept in step with the temperature rather than left at the API's
        // defaults: °F beside km/h and mm is nobody's convention, and the
        // labels come from the response so it reads as deliberate.
        wind_speed_unit: fahrenheit ? "mph" : "kmh",
        precipitation_unit: fahrenheit ? "inch" : "mm",
        current:
          "temperature_2m,relative_humidity_2m,wind_speed_10m,precipitation,weather_code,wind_direction_10m,wind_gusts_10m,is_day",
        daily: "sunrise,sunset",
        forecast_days: "1",
        timeformat: "unixtime",
      }
      const query = Object.entries(params)
        .map(([k, v]) => `${k}=${encodeURIComponent(v)}`)
        .join("&")
      const response = await host.fetch(`https://api.open-meteo.com/v1/forecast?${query}`, { timeout: FETCH_TIMEOUT_MS })
      if (response.status !== 200) throw new Error(`status ${response.status}`)
      const data = JSON.parse(response.body) as WeatherResponse
      if (!data?.current) throw new Error("no current conditions in response")
      cached = { at: Date.now(), key, data }
      lastFailure = null
    } catch (e) {
      const message = String((e as Error)?.message ?? e)
      // Whether the service ANSWERED is the distinction worth keeping: an
      // operator told "no network" goes looking for signal, which is wasted
      // effort when the truth is a 503, a reshaped feed, or a `domains` typo
      // in our own manifest that would fail forever with nothing said.
      lastFailure = { at: Date.now(), transport: !/^status |^no current/.test(message), message }
      // For the author, never the operator — the same shape every other
      // extension that swallows a network failure uses (qrz, hamdb, pota,
      // sota). Without it a manifest typo is undebuggable.
      host.log(`weather panel refresh failed: ${message}`)
    } finally {
      // Only if it is still OURS. A location edit landing mid-flight starts
      // a second request and takes the slot; clearing unconditionally would
      // let this older one erase it, and the next render would open a third
      // for a place two requests have already been sent for.
      if (inFlight?.key === key) inFlight = null
    }
  })()
  inFlight = { key, promise }
  return promise
}

function pad(n: number): string {
  return n < 10 ? `0${n}` : String(n)
}

/// Open-Meteo's `unixtime` values are seconds at the LOCATION's local time
/// offset, which it returns separately — but this runtime has no zone
/// support at all (see the clock panel), so sunrise and sunset are shown in
/// UTC and labelled as such rather than in a local time nothing here can
/// compute.
function utcTime(unixSeconds: number | undefined): string | null {
  if (typeof unixSeconds !== "number") return null
  const d = new Date(unixSeconds * 1000)
  return `${pad(d.getUTCHours())}:${pad(d.getUTCMinutes())}`
}

/// What to tell the operator about a failed fetch. Two sentences, not one:
/// "no network" sends them looking for signal, which is wasted effort when
/// the service answered and said no.
function failureSentence(service: string): string {
  if (!lastFailure) return `Couldn't reach ${service}. Will try again shortly.`
  return lastFailure.transport
    ? `Couldn't reach ${service} — no network? Will try again shortly.`
    : `${service} answered, but not with anything readable. Will try again shortly.`
}

const COMPASS = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]

function compass(degrees: number): string {
  return COMPASS[Math.round(degrees / 22.5) % 16]
}

export const WeatherPanel: PanelHook = {
  async getPanels(_args: Record<string, never>, _ctx: HookContext): Promise<PanelDescriptor[]> {
    return [
      {
        key: "weather",
        title: "Weather",
        description: "Conditions where you're operating",
        icon: "weather-partly-cloudy",
        preview: PREVIEW,
        // `operation` because moving the operation's grid moves the weather;
        // the tick keeps a pane from going stale while somebody watches it.
        on: ["operation", "tick:900"],
        form: [
          {
            type: "field",
            key: "location",
            fieldType: "text",
            label: "Location",
            description: "A grid square (FN31pr) or lat,lon. Leave empty to follow the operation's own location.",
          },
        ],
      },
    ]
  },

  async render(args: PanelRenderArgs, ctx: HookContext): Promise<PanelContent> {
    const override = typeof args.config?.location === "string" ? args.config.location : ""
    const fromConfig = parseLocation(override)
    if (override.trim() && !fromConfig) {
      return {
        kind: "markdown",
        content: `**Weather**\n\nCouldn't read the location \`${override.trim()}\`. Use a grid square like \`FN31pr\`, or \`42.36,-71.06\`.`,
      }
    }

    const grid = typeof args.operation?.grid === "string" ? args.operation.grid : ""
    const place = fromConfig ?? (grid ? parseLocation(grid) : null)
    if (!place) {
      return {
        kind: "markdown",
        content:
          "**Weather**\n\nThis operation has no location yet. Set one on the operation, or give this panel a location in its settings.",
      }
    }

    // The operator's distance preference stands in for a unit SYSTEM, which
    // is what the WEATHER command already does — the app has no separate
    // temperature setting to read. Imperfect: a UK operator keeps miles and
    // expects Celsius. Worth a real units preference rather than a better
    // guess here.
    const fahrenheit = ctx.distanceUnits === "miles"
    // Keyed by place and units, so changing either is a fresh reading rather
    // than the old one relabelled.
    const key = `${place.latitude.toFixed(2)},${place.longitude.toFixed(2)}/${fahrenheit ? "F" : "C"}`
    const stale = !cached || cached.key !== key || Date.now() - cached.at > MAX_AGE_MS
    if (stale) {
      // Awaited directly, with the cap enforced by the host inside
      // `host.fetch`. Nothing here can race a timer: this runtime has none.
      const wait = refresh(place.latitude, place.longitude, fahrenheit, key)
      if (!cached || cached.key !== key) await wait
      else void wait
    }

    if (!cached || cached.key !== key) {
      return { kind: "markdown", content: `**Weather**\n\n${failureSentence("Open-Meteo")}` }
    }

    const c = cached.data.current
    const units = cached.data.current_units ?? {}
    const code = WEATHER_CODES[c.weather_code]
    // Flat fields with night VARIANTS, not nested day/night objects — the
    // same accessors `weatherMessage` uses, and a night entry falls back to
    // the day one rather than to nothing.
    const emoji = (c.is_day ? code?.emoji : (code?.nightEmoji ?? code?.emoji)) ?? "🌡️"
    const description = (c.is_day ? code?.description : (code?.nightDescription ?? code?.description)) ?? "Unknown"
    const sunrise = utcTime(cached.data.daily?.sunrise?.[0])
    const sunset = utcTime(cached.data.daily?.sunset?.[0])

    return {
      kind: "markdown",
      content: [
        `## ${emoji} ${c.temperature_2m}${units.temperature_2m ?? "°"}`,
        "",
        description,
        "",
        "| | |",
        "|---|---|",
        `| 💨 Wind | ${c.wind_speed_10m}${units.wind_speed_10m ?? ""} ${compass(c.wind_direction_10m)}` +
          `${c.wind_gusts_10m > c.wind_speed_10m ? ` (gusts ${c.wind_gusts_10m})` : ""} |`,
        `| 💧 Humidity | ${c.relative_humidity_2m}${units.relative_humidity_2m ?? "%"} |`,
        ...(c.precipitation > 0 ? [`| 🌧️ Precipitation | ${c.precipitation}${units.precipitation ?? ""} |`] : []),
        ...(sunrise ? [`| 🌅 Sunrise | ${sunrise} UTC |`] : []),
        ...(sunset ? [`| 🌇 Sunset | ${sunset} UTC |`] : []),
        "",
        // The age is not decoration. Weather is the one reading here an
        // operator acts on physically — packing up ahead of a storm — and a
        // failing fetch leaves this reading on screen indefinitely.
        `_${grid && !fromConfig ? grid : `${place.latitude.toFixed(2)}, ${place.longitude.toFixed(2)}`}_ · ` +
          `${readingAge(cached.at)} · [Open-Meteo](https://open-meteo.com)`,
        ...(lastFailure && lastFailure.at > cached.at ? ["", `⚠️ ${failureSentence("Open-Meteo")}`] : []),
      ].join("\n"),
    }
  },
}

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook("panel", { key: "weather-panel", hook: WeatherPanel })
  },
})
