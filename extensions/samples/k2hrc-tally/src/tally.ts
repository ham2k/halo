// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// The integration itself: what it offers in the Integrations dialog, and what
// it does when the app tells it what changed in an operation.

import { host } from "@ham2k/extension-sdk"
import type { HookContext, IntegrationDescriptor, IntegrationHook, IntegrationObserveArgs } from "@ham2k/extension-sdk"

export interface Tally {
  logged: number
  updated: number
  deleted: number
}

/// One tally per operation it is on in. Held in memory, so a restart of the
/// app, which calls with `open` again, starts every one from zero.
const tallies = new Map<string, Tally>()

/// The line the tally reads as, or null while there is nothing to say.
export function tallyText(tally: Tally, countEdits: boolean): string | null {
  if (tally.logged === 0 && (!countEdits || (tally.updated === 0 && tally.deleted === 0))) return null
  const logged = `${tally.logged} logged`
  return countEdits ? `This session: ${logged}, ${tally.updated} edited, ${tally.deleted} deleted` : `This session: ${logged}`
}

export const SessionTally: IntegrationHook = {
  async getIntegrations(_args: Record<string, never>, _ctx: HookContext): Promise<IntegrationDescriptor[]> {
    return [
      {
        key: "tally",
        title: "Session Tally",
        description: "Counts the contacts logged since you switched it on",
        icon: "counter",
        // Every change to the log. The app says which contacts changed, so
        // there is no need to read the whole log on each call.
        on: ["qsoLogged"],
        form: [{ type: "field", fieldType: "checkbox", key: "countEdits", label: "Count edits and deletions too", value: false }],
      },
    ]
  },

  async observe({ operation, reasons, changes, config }: IntegrationObserveArgs, _ctx: HookContext): Promise<void> {
    const uuid = String(operation.uuid)
    if (reasons.includes("open")) tallies.set(uuid, { logged: 0, updated: 0, deleted: 0 })
    const tally = tallies.get(uuid) ?? { logged: 0, updated: 0, deleted: 0 }
    tally.logged += changes.logged.length
    tally.updated += changes.updated.length
    tally.deleted += changes.deleted.length
    tallies.set(uuid, tally)

    // The key is the same for every operation: with two open, the line
    // carries the one the last call was about.
    const text = tallyText(tally, config.countEdits === true)
    if (text === null) return await host.fyi.clear("tally")
    await host.fyi.post({ key: "tally", category: "info", icon: "counter", text })
  },
}
