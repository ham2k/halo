// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// What the coach does to the app itself, once per operation and only when
// the operator turned it on in the coach's settings: keep the screen awake
// (`host.updateSetting`, under `requiresSettingsWrite`), and draw a layout of
// its own (`host.layouts`, under `requiresLayoutControl`). The app names
// each change on the status bar, with the coach as the one that made it.

import { host } from "@ham2k/extension-sdk"
import type { JSONValue, LayoutDocument } from "@ham2k/extension-sdk"

/// The coach's layout of the Operation view: the log, and beside it a UTC
/// clock over the spots.
export const RATE_LAYOUT: LayoutDocument = {
  "ham2k-layout": 1,
  name: "Rate Coach",
  description: "The log, with a UTC clock over the spots",
  wide: {
    root: {
      split: "horizontal",
      weights: [2, 1],
      children: [
        { tabs: [{ panel: "logging" }] },
        {
          split: "vertical",
          weights: [1, 3],
          children: [{ tabs: [{ panel: "clock", instance: true, settings: { zone: "UTC" } }] }, { tabs: [{ panel: "spots" }] }],
        },
      ],
    },
  },
}

/// The operations set up already. One the operator switched away from stays
/// where they put it.
const done = new Set<string>()

/// Sets up the operation [uuid] as [config] asks, the first time it is
/// called about it. Until the Operation view is open, which can be a moment
/// after the operation is, the next call tries again.
export async function setUpOperation(uuid: string, config: Record<string, JSONValue>): Promise<void> {
  if (done.has(uuid)) return
  // Says nothing when the screen already stays awake.
  if (config.keepAwake === true) await host.updateSetting({ key: "keepDeviceAwake", value: true })
  if (config.ownLayout === true) {
    const view = (await host.layouts.list()).find((each) => each.view === "operation")
    if (!view?.open) return
    // Made once and kept. A layout the operator has since edited is theirs,
    // and a new one is made in its place.
    let id = view.layouts.find((layout) => layout.mine)?.id
    if (id === undefined) {
      const made = await host.layouts.apply({ view: "operation", document: RATE_LAYOUT })
      // `editing` while the operator edits a layout: the next call tries again.
      if (!made.accepted) return
      id = made.id
    }
    if (id !== undefined && view.active !== id) await host.layouts.switch({ view: "operation", id })
  }
  done.add(uuid)
}
