// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// GO <place> — goes to a part of the app: Home's operations list, maps, logs
// and chasing, or a Settings panel (see `PLACES` for every word). The hook
// only parses; the app decides how to get there and whether this build has
// the place turned on (`runCommandAction`'s `navigate`, command_actions.dart).

import { defineExtension } from "@ham2k/extension-sdk"
import type { CommandCatalogEntry, CommandInterpretation, HookContext } from "@ham2k/extension-sdk"
import { availablePlaces, keywordsOf, parseGoCommand } from "./navigationCommandParsing.ts"
import { tFor } from "./i18n.ts"

import manifest from "../manifest.json" with { type: "json" }

const placesFor = (ctx: HookContext) => availablePlaces(ctx.enabledExperiments ?? [], ctx.developerMode ?? false)

const GoCommand = {
  async interpret({ input }: { input: string }, ctx: HookContext): Promise<CommandInterpretation | null> {
    const places = placesFor(ctx)
    const parsed = parseGoCommand(input, places)
    if (!parsed) return null
    const t = tFor(ctx)
    switch (parsed.kind) {
      case "incomplete":
        // Recognized but not runnable yet: without this, Enter on a bare GO
        // in the call field logs "GO" as a contact.
        return { expectsParams: true, describe: t("choose", { places: parsed.candidates.join(", ") }) }
      case "unknown":
        return {
          error: t("unknown", {
            text: parsed.text,
            places: places
              .filter((p) => !p.alias)
              .map((p) => p.word)
              .join(", "),
          }),
        }
      case "place":
        // No `confirm`: the place itself is the answer, and a palette held
        // open to say "Going to Maps" would only sit over it.
        return {
          describe: t("goTo", { place: t(`place.${parsed.word}`) }),
          commands: [{ navigate: { to: parsed.to } }],
        }
    }
  },

  async catalog(ctx: HookContext): Promise<CommandCatalogEntry[]> {
    const t = tFor(ctx)
    const category = t("catalogCategory")
    const places = placesFor(ctx)
    return places
      .filter((p) => !p.alias)
      .map((p) => ({
        command: `GO ${p.word}`,
        keywords: keywordsOf(p, places),
        describe: t("goTo", { place: t(`place.${p.word}`) }),
        category,
      }))
  },
}

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook("command", { key: "navigation-commands-go", hook: GoCommand, priority: 100 })
  },
})
