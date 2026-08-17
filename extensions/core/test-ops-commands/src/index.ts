// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// PURGETESTS: bulk-deletes every Test Operation on this device (a station
// call ending `/T` or `/TEST`, docs: Test Operations). This extension only
// recognizes the word and hands off a bare `purgeTests` action — listing
// the candidates and confirming is app-side (`main.dart`'s `runCommandAction`,
// via `confirmPurgeTestOperations`), since it needs a `BuildContext` to show
// a dialog, which no hook context here can provide. Purging itself goes
// through `HaLoServices.purgeOperation`, the same path a single Test
// Operation's own delete confirmation uses.

import { defineExtension } from "@ham2k/halo-extension-sdk"
import type { CommandCatalogEntry, CommandInterpretation, HookContext } from "@ham2k/halo-extension-sdk"

import manifest from "../manifest.json" with { type: "json" }

const PurgeTestsCommand = {
  async interpret({ input }: { input: string }, _ctx: HookContext): Promise<CommandInterpretation | null> {
    if (input.trim().toUpperCase() !== "PURGETESTS") return null
    return {
      describe: "Purge every Test Operation on this device?",
      commands: [{ purgeTests: {} }],
    }
  },

  async catalog(_ctx: HookContext): Promise<CommandCatalogEntry[]> {
    return [
      {
        command: "PURGETESTS",
        describe: "Delete every Test Operation on this device",
        category: "Data",
      },
    ]
  },
}

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook("command", { key: "test-ops-commands-purge", hook: PurgeTestsCommand })
  },
})
