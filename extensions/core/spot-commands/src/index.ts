// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Call-field shortcuts for spotting (ham2k/app-halo-dist#10), ported from
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
import type { CommandInterpretation, HookContext } from "@ham2k/halo-extension-sdk"
import { parseSelfSpotCommand, isLastSpotCommand } from "./spotCommandParsing.ts"

const SelfSpotCommand = {
  async interpret({ input }: { input: string }, _ctx: HookContext): Promise<CommandInterpretation | null> {
    const parsed = parseSelfSpotCommand(input)
    if (!parsed) return null
    const { comment } = parsed
    return {
      describe: comment ? `Self-spot with comment "${comment}"?` : 'Self-spot?',
      confirm: comment ? `Self-spotting: ${comment}` : 'Self-spotting…',
      commands: [{ sendSpots: { comment: comment || undefined, target: 'self' } }],
    }
  },
}

const LastSpotCommand = {
  async interpret({ input }: { input: string }, _ctx: HookContext): Promise<CommandInterpretation | null> {
    if (!isLastSpotCommand(input)) return null
    return {
      describe: 'Spot the last logged QSO?',
      confirm: 'Spotting last QSO…',
      commands: [{ sendSpots: { target: 'last' } }],
    }
  },
}

defineExtension({
  key: 'spot-commands',
  name: 'Spotting Commands',
  version: '0.0.1',
  description: 'Call-field shortcuts for spotting: SPOT, SPOTME, SELFSPOT, QRV, QRT, QSY, QRX, SPOTLAST',
  onActivation({ registerHook }) {
    registerHook('command', { key: 'spot-commands-self', hook: SelfSpotCommand, priority: 100 })
    registerHook('command', { key: 'spot-commands-last', hook: LastSpotCommand, priority: 100 })
  },
})
