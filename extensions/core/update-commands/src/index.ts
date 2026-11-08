// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// UPDATE (or UPD) — fetches what changed, on the operator's word rather than
// on the app's schedule:
//
//   UPDATE DATA         → every data file
//   UPDATE POTA         → the data files answering to POTA (NOTES, HISTORY…)
//   UPDATE APP          → About's Check for Updates
//   UPDATE EXT          → asks the catalog now, then offers every update
//
// The hook only parses. Which data files a word names, and every check, is
// the app's (`updateDataFiles`, `updateApp` and `updateExtensions` in
// command_actions.dart).

import { defineExtension } from "@ham2k/extension-sdk"
import type { CommandCatalogEntry, CommandInterpretation, HookContext } from "@ham2k/extension-sdk"

import { parseUpdateCommand } from "./updateCommandParsing.ts"
import { tFor } from "./i18n.ts"

import manifest from "../manifest.json" with { type: "json" }

const UpdateCommand = {
  async interpret({ input }: { input: string }, ctx: HookContext): Promise<CommandInterpretation | null> {
    const target = parseUpdateCommand(input)
    if (!target) return null
    const t = tFor(ctx)
    switch (target.kind) {
      case "incomplete":
        return { expectsParams: true, describe: t("choose") }
      case "app":
        return { describe: t("app"), confirm: t("appChecking"), commands: [{ updateApp: {} }] }
      case "extensions":
        return { describe: t("extensions"), confirm: t("extensionsChecking"), commands: [{ updateExtensions: {} }] }
      case "data":
        // No `confirm`: the app answers at once, naming the files it found.
        return target.matching
          ? { describe: t("dataMatching", { words: target.matching.join(" ") }), commands: [{ updateDataFiles: { matching: target.matching } }] }
          : { describe: t("data"), commands: [{ updateDataFiles: {} }] }
    }
  },

  async catalog(ctx: HookContext): Promise<CommandCatalogEntry[]> {
    const t = tFor(ctx)
    const category = t("catalogCategory")
    return [
      { command: "UPDATE DATA", describe: t("data"), keywords: ["UPD", "DATA FILES", "REFRESH", "DOWNLOAD"], category, suggest: true },
      { command: "UPDATE APP", describe: t("app"), keywords: ["UPD", "VERSION", "UPGRADE"], category },
      { command: "UPDATE EXT", describe: t("extensions"), keywords: ["UPD", "EXTENSIONS"], category },
      { command: "UPDATE", params: t("dataFileParam"), describe: t("dataMatching", { words: "…" }), keywords: ["UPD"], category, expectsParams: true },
    ]
  },
}

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook("command", { key: "update-commands-update", hook: UpdateCommand, priority: 100 })
  },
})
