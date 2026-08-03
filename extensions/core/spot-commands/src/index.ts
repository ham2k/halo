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
//   SPOTLAST / SPOTEM / SPOTTHEM / SPTHEM — spot the most recently logged
//                                       QSO, no reference in app-polo (new
//                                       behavior for app-halo)
// Neither command resolves *who* gets spotted or *how* — that's Dart's job
// (it owns the QSO list and the extension-hook fan-out); this just parses
// text into a `sendSpots` CommandAction. Parsing itself lives in
// spotCommandParsing.ts so it's unit-testable without the extension-runtime
// globals `defineExtension` depends on.

import { defineExtension } from "@ham2k/halo-extension-sdk"
import type { CommandCatalogEntry, CommandInterpretation, HookContext, JSONValue } from "@ham2k/halo-extension-sdk"
import { parseSelfSpotCommand, isLastSpotCommand } from "./spotCommandParsing.ts"
import { tFor } from "./i18n.ts"

import manifest from "../manifest.json" with { type: "json" }

// Both hooks are operation-scoped: a self-spot advertises the operation and
// SPOTLAST spots its most recent QSO, so outside an operation's logging
// panel (e.g. the home screen's quick search) they answer with an `error`
// the UI presents rather than a silent non-match.
const SelfSpotCommand = {
  async interpret(
    { input, operation }: { input: string; operation?: Record<string, JSONValue> },
    ctx: HookContext,
  ): Promise<CommandInterpretation | null> {
    const parsed = parseSelfSpotCommand(input)
    if (!parsed) return null
    const t = tFor(ctx)
    if (!operation) return { error: t('needsOperation') }
    const { comment } = parsed
    return {
      // The comment is free prose for other operators (same as the Spotting
      // control's own comment field), so the call field must not force it
      // to uppercase or treat space as advance-focus. mixedCase, not
      // expectsParams: a bare "SPOT" is already executable on Enter.
      mixedCase: true,
      describe: comment ? t('selfSpotWithComment', { comment }) : t('selfSpot'),
      confirm: comment ? t('selfSpottingComment', { comment }) : t('selfSpotting'),
      commands: [{ sendSpots: { comment: comment || undefined, target: 'self' } }],
    }
  },

  async catalog(ctx: HookContext): Promise<CommandCatalogEntry[]> {
    const t = tFor(ctx)
    return [{
      command: 'SPOT',
      params: '[comment]',
      describe: t('catalogSelfSpot'),
      category: t('catalogCategory'),
      needsOperation: true,
    }]
  },
}

const LastSpotCommand = {
  async interpret(
    { input, operation }: { input: string; operation?: Record<string, JSONValue> },
    ctx: HookContext,
  ): Promise<CommandInterpretation | null> {
    if (!isLastSpotCommand(input)) return null
    const t = tFor(ctx)
    if (!operation) return { error: t('needsOperation') }
    return {
      describe: t('spotLast'),
      confirm: t('spottingLast'),
      commands: [{ sendSpots: { target: 'last' } }],
    }
  },

  async catalog(ctx: HookContext): Promise<CommandCatalogEntry[]> {
    const t = tFor(ctx)
    return [{
      command: 'SPOTLAST',
      describe: t('catalogSpotLast'),
      category: t('catalogCategory'),
      needsOperation: true,
    }]
  },
}

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook('command', { key: 'spot-commands-self', hook: SelfSpotCommand, priority: 100 })
    registerHook('command', { key: 'spot-commands-last', hook: LastSpotCommand, priority: 100 })
  },
})
