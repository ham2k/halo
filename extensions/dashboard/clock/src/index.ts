// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// UTC and station time in a pane, plus any other clocks the operator adds.
//
// **This panel does not know about time zones, and cannot.** The extension
// runtime is QuickJS-NG, which ships no ECMA-402: `Intl` is undefined, and
// — the part that actually bites — `toLocaleString(…, {timeZone: 'X'})`
// does NOT throw. It silently ignores the zone and returns host-local time,
// so a machine that happens to sit in the requested zone makes the bug
// invisible. The web build runs on the browser's engine, which does have
// `Intl`, so the same code would work there and be quietly wrong
// everywhere else.
//
// So extra clocks are fixed UTC offsets with a label the operator writes.
// No DST, and deliberately no zone names: a clock that is confidently wrong
// twice a year is worse than one that never claimed to know.
//
// Seconds are out of reach too, and for a different reason: `tick` is
// floored at five seconds and every tick crosses the JS bridge. A panel
// wanting to be live to the second wants to be a native pane, which
// docs/extensions/hooks.md says outright. This shows HH:MM and ticks at 15s,
// so it is at most a quarter of a minute late on the rollover.

import { defineExtension } from "@ham2k/halo-extension-sdk"
import type { HookContext, PanelContent, PanelDescriptor, PanelHook, PanelRenderArgs } from "@ham2k/halo-extension-sdk"

import { clockAt, offsetLabel, pad, parseClocks } from "./offsets.ts"
import manifest from "../manifest.json"

const PREVIEW = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
  <circle cx="12" cy="12" r="9.5" fill="none" stroke="#00b4e6" stroke-width="2"/>
  <path d="M12 6.5V12l3.5 2.5" fill="none" stroke="#006783" stroke-width="2" stroke-linecap="round"/>
</svg>`

export const ClockPanel: PanelHook = {
  async getPanels(_args: Record<string, never>, _ctx: HookContext): Promise<PanelDescriptor[]> {
    return [
      {
        key: "clock",
        title: "Clock",
        description: "UTC, station time, and clocks you add",
        icon: "clock-outline",
        preview: PREVIEW,
        // 15s: the floor is 5, and every tick is a bridge call. Showing
        // HH:MM, this is at most a quarter-minute late on the rollover.
        on: ["tick:15"],
        form: [
          {
            type: "field",
            key: "clocks",
            fieldType: "multiline",
            label: "Extra clocks",
            description: "One per line, as Label = offset — e.g. Tokyo = +9, or Mumbai = +5:30. Offsets from UTC; no daylight saving.",
          },
          {
            type: "field",
            key: "hideStation",
            fieldType: "checkbox",
            label: "Hide station time",
            description: "UTC is always shown",
          },
        ],
      },
    ]
  },

  async render(args: PanelRenderArgs, _ctx: HookContext): Promise<PanelContent> {
    const now = new Date()
    // The host's own offset, which is the ONE local zone this runtime can
    // speak for — it comes from the engine, not from a zone database.
    const stationOffset = -now.getTimezoneOffset()
    const raw = typeof args.config?.clocks === "string" ? args.config.clocks : ""
    const { clocks, bad } = parseClocks(raw)

    const rows = [
      `| 🌐 **UTC** | **${clockAt(now, 0)}** |`,
      ...(args.config?.hideStation === true
        ? []
        : [`| 🏠 Station | ${clockAt(now, stationOffset)} · ${offsetLabel(stationOffset)} |`]),
      ...clocks.map((c) => `| 🕒 ${c.label} | ${clockAt(now, c.offset)} · ${offsetLabel(c.offset)} |`),
    ]

    return {
      kind: "markdown",
      content: [
        "| | |",
        "|---|---|",
        ...rows,
        "",
        ...(bad.length ? [`⚠️ Couldn't read: ${bad.map((b) => `\`${b}\``).join(", ")}`, ""] : []),
        `_${now.getUTCFullYear()}-${pad(now.getUTCMonth() + 1)}-${pad(now.getUTCDate())} UTC_`,
      ].join("\n"),
    }
  },
}

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook("panel", { key: "clock-panel", hook: ClockPanel })
  },
})
