// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Call-field shortcuts for spotting, ported from
// app-polo's MiscCommands.js:
//   SPOT / SPOTME / SPME / SELFSPOT  — self-spot, optional free-text comment
//   QRV / QRT / QSY / QRX            — self-spot; the Q-code itself becomes
//                                       the start of the comment (e.g.
//                                       "QRT ADIOS" spots with comment
//                                       "QRT ADIOS")
//   SPOTLAST / SPOTEM / SPOTTHEM / SPTHEM [comment] — spot the most recently logged
//                                       QSO, no reference in app-polo (new
//                                       behavior for app-halo)
//   RESPOT [minutes|OFF]             — auto-respotting, HaLo's own: the
//                                       Spotting control's "Re-spot every
//                                       N min", at the operator's interval
//                                       or a chosen one
// Neither command resolves *who* gets spotted or *how* — that's Dart's job
// (it owns the QSO list and the extension-hook fan-out); this just parses
// text into a `sendSpots` or `autoRespot` CommandAction. Parsing itself lives in
// spotCommandParsing.ts so it's unit-testable without the extension-runtime
// globals `defineExtension` depends on.

import { defineExtension } from "@ham2k/extension-sdk"
import type { CommandCatalogEntry, CommandInterpretation, HookContext, JSONValue } from "@ham2k/extension-sdk"
import { parseSelfSpotCommand, parseLastSpotCommand, parseRespotCommand } from "./spotCommandParsing.ts"
import { tFor } from "./i18n.ts"

import manifest from "../manifest.json" with { type: "json" }

// Both hooks are operation-scoped: a self-spot advertises the operation and
// SPOTLAST spots its most recent QSO, so outside an operation's logging
// panel (e.g. the home screen's quick search) they answer with an `error`
// the UI presents rather than a silent non-match.
const SelfSpotCommand = {
  async interpret({ input, operation }: { input: string; operation?: Record<string, JSONValue> }, ctx: HookContext): Promise<CommandInterpretation | null> {
    const parsed = parseSelfSpotCommand(input)
    if (!parsed) return null
    const t = tFor(ctx)
    if (!operation) return { error: t("needsOperation") }
    const { comment } = parsed
    return {
      // The comment is free prose for other operators (same as the Spotting
      // control's own comment field), so the call field must not force it
      // to uppercase or treat space as advance-focus. mixedCase, not
      // expectsParams: a bare "SPOT" is already executable on Enter.
      mixedCase: true,
      describe: comment ? t("selfSpotWithComment", { comment }) : t("selfSpot"),
      confirm: comment ? t("selfSpottingComment", { comment }) : t("selfSpotting"),
      commands: [{ sendSpots: { comment: comment || undefined, target: "self" } }],
    }
  },

  async catalog(ctx: HookContext): Promise<CommandCatalogEntry[]> {
    const t = tFor(ctx)
    return [
      {
        command: "SPOT",
        params: "[comment]",
        describe: t("catalogSelfSpot"),
        category: t("catalogCategory"),
        needsOperation: true,
        // Types in rather than running: SPOT posts to the public cluster, and
        // it's offered as an empty-field sample to users who don't yet know
        // that — picking it must not publish in one click. Enter still runs
        // the bare form; the [comment] stays optional.
        expectsParams: true,
        suggest: true,
      },
    ]
  },
}

const LastSpotCommand = {
  async interpret({ input, operation }: { input: string; operation?: Record<string, JSONValue> }, ctx: HookContext): Promise<CommandInterpretation | null> {
    const parsed = parseLastSpotCommand(input)
    if (!parsed) return null
    const t = tFor(ctx)
    if (!operation) return { error: t("needsOperation") }
    const { comment } = parsed
    return {
      // Free prose for other operators, as SPOT's comment is: mixed case, and
      // space a character rather than advance-focus.
      mixedCase: true,
      describe: comment ? t("spotLastWithComment", { comment }) : t("spotLast"),
      confirm: comment ? t("spottingLastComment", { comment }) : t("spottingLast"),
      commands: [{ sendSpots: { comment: comment || undefined, target: "last" } }],
    }
  },

  async catalog(ctx: HookContext): Promise<CommandCatalogEntry[]> {
    const t = tFor(ctx)
    return [
      {
        command: "SPOTLAST",
        params: "[comment]",
        describe: t("catalogSpotLast"),
        category: t("catalogCategory"),
        needsOperation: true,
      },
    ]
  },
}

const RespotCommand = {
  async interpret({ input, operation }: { input: string; operation?: Record<string, JSONValue> }, ctx: HookContext): Promise<CommandInterpretation | null> {
    const parsed = parseRespotCommand(input)
    if (!parsed) return null
    const t = tFor(ctx)
    if (!operation) return { error: t("needsOperation") }
    // mixedCase, like SEED: bare RESPOT runs on Enter, yet Space must stay a
    // literal character so "RESPOT 5" can still be typed.
    if ("invalid" in parsed) return { mixedCase: true, error: t("respotUsage") }
    if ("off" in parsed) {
      return { mixedCase: true, describe: t("respotOff"), confirm: t("respotStopped"), commands: [{ autoRespot: { off: true } }] }
    }
    const { minutes } = parsed
    if (minutes === undefined) {
      return { mixedCase: true, describe: t("respotDefault"), confirm: t("respotting"), commands: [{ autoRespot: {} }] }
    }
    return {
      mixedCase: true,
      describe: t("respotEvery", { minutes }),
      confirm: t("respottingEvery", { minutes }),
      commands: [{ autoRespot: { minutes } }],
    }
  },

  async catalog(ctx: HookContext): Promise<CommandCatalogEntry[]> {
    const t = tFor(ctx)
    return [
      {
        command: "RESPOT",
        params: "[minutes|OFF]",
        describe: t("catalogRespot"),
        category: t("catalogCategory"),
        needsOperation: true,
        // Types in rather than running, for SPOT's reason: it can post to the
        // public cluster.
        expectsParams: true,
      },
    ]
  },
}

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook("command", { key: "spot-commands-self", hook: SelfSpotCommand, priority: 100 })
    registerHook("command", { key: "spot-commands-last", hook: LastSpotCommand, priority: 100 })
    registerHook("command", { key: "spot-commands-respot", hook: RespotCommand, priority: 100 })
  },
})
