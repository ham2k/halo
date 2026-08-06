// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Solar and geomagnetic conditions in a pane, from the same hamqsl.com feed
// and the same emoji thresholds the SOLAR command writes into the log
// (extensions/shared/spaceWeather.ts) — so the two can never disagree about
// what an SFI of 180 looks like.
//
// The shape here is the one every FETCHING panel needs, and the reason this
// file is worth reading before writing another: `render` has a five-second
// budget on the host side, so it must never simply await the network. It
// answers from cache and refreshes in the background, and a slow or failed
// fetch leaves the last good reading on screen rather than an error.

import { defineExtension, host } from "@ham2k/halo-extension-sdk"
import type { HookContext, PanelContent, PanelDescriptor, PanelHook, PanelRenderArgs } from "@ham2k/halo-extension-sdk"

import { emojiForAIndex, emojiForKIndex, emojiForSFI, parseSolarXml } from "../../../shared/spaceWeather.ts"
import { readingAge } from "../../../shared/freshness.ts"
import manifest from "../manifest.json"

const PREVIEW = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
  <circle cx="12" cy="12" r="5" fill="#f5a623"/>
  <g stroke="#f5a623" stroke-width="2" stroke-linecap="round">
    <path d="M12 1v3M12 20v3M1 12h3M20 12h3M4.2 4.2l2.1 2.1M17.7 17.7l2.1 2.1M19.8 4.2l-2.1 2.1M6.3 17.7l-2.1 2.1"/>
  </g>
</svg>`

/// How old a reading may be before a render kicks off a refresh. The feed
/// itself updates a few times an hour, so anything shorter is a request
/// nobody reads a new answer from.
const MAX_AGE_MS = 20 * 60 * 1000

/// Handed to `host.fetch`, which bounds the request HOST-side. It has to be
/// the host that enforces this: the JS runtime is QuickJS with no timer
/// functions at all — `setTimeout` is simply not defined — so a timeout
/// raced in JS is not merely awkward, it throws ReferenceError out of
/// render. Below the host's own five-second render budget, so a slow source
/// costs a message rather than a failed pane.
const FETCH_TIMEOUT_MS = 4000

let cached: { at: number; data: Record<string, string> } | null = null
let inFlight: Promise<void> | null = null

/// Why the last fetch failed, for the operator. Kept apart from `cached` so
/// a failure never erases a good reading, and so the panel can say whether
/// the service answered badly or never answered at all.
let lastFailure: { at: number; transport: boolean; message: string } | null = null

function refresh(): Promise<void> {
  // One fetch at a time: several panes of this panel, or a tick landing on a
  // manual refresh, would otherwise each open their own request for the same
  // document.
  if (inFlight) return inFlight
  inFlight = (async () => {
    try {
      const response = await host.fetch("https://www.hamqsl.com/solarxml.php", { timeout: FETCH_TIMEOUT_MS })
      if (response.status !== 200) throw new Error(`status ${response.status}`)
      const data = parseSolarXml(response.body)
      // A partial or reshaped response would render "undefined" with an
      // alarm emoji driven by NaN — keeping the previous reading is more
      // honest than showing that.
      if (!data.solarflux || !data.aindex || !data.kindex || !data.sunspots) {
        throw new Error("incomplete solar data")
      }
      cached = { at: Date.now(), data }
      lastFailure = null
    } catch (e) {
      const message = String((e as Error)?.message ?? e)
      // Whether the feed ANSWERED is the distinction worth keeping: told "no
      // network", an operator goes hunting for signal — wasted effort when
      // the truth is a 503, a reshaped feed, or a `domains` typo in our own
      // manifest, which would fail forever with nothing said anywhere.
      lastFailure = { at: Date.now(), transport: !/^status |^incomplete/.test(message), message }
      // For the author, never the operator — the shape every other extension
      // that swallows a network failure uses (qrz, hamdb, pota, sota).
      host.log(`solar panel refresh failed: ${message}`)
    } finally {
      inFlight = null
    }
  })()
  return inFlight
}

/// Two sentences, not one: "no network" sends an operator looking for signal,
/// which is wasted effort when the feed answered and said no.
function failureSentence(): string {
  if (!lastFailure) return "Couldn't reach hamqsl.com. Will try again shortly."
  return lastFailure.transport
    ? "Couldn't reach hamqsl.com — no network? Will try again shortly."
    : "hamqsl.com answered, but not with a reading we could use. Will try again shortly."
}

export const SolarPanel: PanelHook = {
  async getPanels(_args: Record<string, never>, _ctx: HookContext): Promise<PanelDescriptor[]> {
    return [
      {
        key: "solar",
        title: "Solar",
        description: "Flux, A and K indices, and sunspot number",
        icon: "white-balance-sunny",
        preview: PREVIEW,
        // The feed updates a few times an hour; this is the slowest tick
        // that still keeps a pane from going visibly stale while somebody
        // watches it. Nothing else changes what this panel shows, so it asks
        // for nothing else.
        on: ["tick:600"],
      },
    ]
  },

  async render(_args: PanelRenderArgs, _ctx: HookContext): Promise<PanelContent> {
    const stale = !cached || Date.now() - cached.at > MAX_AGE_MS
    // Only a render with nothing to show waits for the network. Once there
    // is a reading, a refresh happens behind it and lands on the next tick —
    // the pane never blocks on a fetch it could answer without.
    if (stale) {
      // Awaited directly, with the cap enforced by the host inside
      // `host.fetch`. Nothing here can race a timer: this runtime has none.
      if (!cached) await refresh()
      else void refresh()
    }

    if (!cached) {
      return {
        kind: "markdown",
        content: `**Solar conditions**\n\n${failureSentence()}`,
      }
    }

    const d = cached.data
    return {
      kind: "markdown",
      content: [
        `## ${emojiForSFI(Number(d.solarflux))} SFI ${d.solarflux}`,
        "",
        `| | |`,
        `|---|---|`,
        `| ${emojiForAIndex(Number(d.aindex))} A index | **${d.aindex}** |`,
        `| ${emojiForKIndex(Number(d.kindex))} K index | **${d.kindex}** |`,
        `| 😎 Sunspots | **${d.sunspots}** |`,
        ...(d.xray ? [`| ☢️ X-ray | **${d.xray}** |`] : []),
        ...(d.aurora ? [`| 🌌 Aurora | **${d.aurora}** |`] : []),
        "",
        `_${readingAge(cached.at)}_ · [hamqsl.com](https://www.hamqsl.com) by N0NBH`,
        ...(lastFailure && lastFailure.at > cached.at ? ["", `⚠️ ${failureSentence()}`] : []),
      ].join("\n"),
    }
  },
}

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook("panel", { key: "solar-panel", hook: SolarPanel })
  },
})
