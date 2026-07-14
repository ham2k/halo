// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// NOTE <text> -> sets the in-progress QSO's notes field, via the same
// `updateQso` action _dispatchActions already uses for the Notes control
// (packages/halo_widgets/lib/src/logging_controls.dart). Proves out the
// `expectsParams` call-field mode (issue #22): bare "NOTE" is a recognized
// prefix that isn't a command yet, so the field switches to free-text
// (spaces, normal capitalization) until the rest is typed.

import { defineExtension } from "@ham2k/halo-extension-sdk"
import type { CommandInterpretation, HookContext } from "@ham2k/halo-extension-sdk"

const NOTE_MATCH = /^NOTE(?:\s+(.*))?$/i

const NoteCommand = {
  async interpret({ input }: { input: string }, _ctx: HookContext): Promise<CommandInterpretation | null> {
    const match = NOTE_MATCH.exec(input.trim())
    if (!match) return null

    const text = match[1]?.trim()
    if (!text) return { expectsParams: true } // "NOTE" alone — recognized, but nothing to save yet

    return {
      describe: `Add note "${text}"?`,
      confirm: 'Note added',
      commands: [{ updateQso: { notes: text } }],
    }
  },
}

defineExtension({
  key: 'note-command',
  name: 'Note Command',
  version: '0.0.1',
  description: 'NOTE <text> call-field shortcut that sets the QSO notes field',
  onActivation({ registerHook }) {
    registerHook('command', { key: 'note-command-note', hook: NoteCommand, priority: 100 })
  },
})
