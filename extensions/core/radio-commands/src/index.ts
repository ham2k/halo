// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Core radio commands: band, frequency, and mode shortcuts typed into the
// call field and triggered on space. Ported from app-polo's RadioCommands
// extension (src/extensions/commands/RadioCommands.js) — this is the
// reference implementation of the `command` hook category (DESIGN.md §4,
// docs/extensions/hooks.md), replacing what used to be a hand-rolled regex
// in LoggingPanel.
//
// Delegating frequency parsing to @ham2k/lib-format-tools' parseFreq (the
// same published parser app-polo uses) instead of a Dart-side regex fixes
// a real bug: the old Dart regex required 3+ digits before any decimal
// point, so MHz-style input like "14.285" never matched even though
// parseFreq has always supported it.

import { parseFreq } from "@ham2k/lib-format-tools"
import { bandForFrequency } from "@ham2k/lib-operation-data"

import { defineExtension } from "@ham2k/polo-sdk"
import type { CommandResult, HookContext } from "@ham2k/polo-sdk"

const BAND_MATCH = /^(2200|630|160|80|60|40|30|20|17|15|12|10|6|4|2)M?$/i
const MODE_MATCH = /^(CW|SSB|USB|LSB|FM|AM|FT8|FT4|FT2|RTTY)$/i
const FREQUENCY_MATCH = /^[\d.,]+$/

const BandCommand = {
  async tryCommand({ input }: { input: string }, _ctx: HookContext): Promise<CommandResult | null> {
    const match = BAND_MATCH.exec(input.trim())
    if (!match) return null
    return { band: `${match[1].toLowerCase()}m` }
  },
}

const FrequencyCommand = {
  async tryCommand({ input }: { input: string }, _ctx: HookContext): Promise<CommandResult | null> {
    const trimmed = input.trim()
    // Require at least 3 characters so short band-only numbers ("20") don't
    // get treated as frequencies before the (higher-priority) band command
    // has a chance to match them.
    if (trimmed.length < 3 || !FREQUENCY_MATCH.test(trimmed)) return null

    const freq = parseFreq(trimmed)
    // bandForFrequency falls back to the literal string 'other' for
    // unrecognized frequencies rather than a falsy value, so checking
    // truthiness alone would accept any 3+ digit number as a "frequency."
    const band = freq ? bandForFrequency(freq) : undefined
    if (!freq || !band || band === 'other') return null
    return { freq }
  },
}

const ModeCommand = {
  async tryCommand({ input }: { input: string }, _ctx: HookContext): Promise<CommandResult | null> {
    const match = MODE_MATCH.exec(input.trim())
    if (!match) return null
    return { mode: match[1].toUpperCase() }
  },
}

defineExtension({
  key: 'radio-commands',
  name: 'Radio Commands',
  version: '0.0.1',
  description: 'Frequency, band, and mode shortcuts typed into the call field',
  onActivation({ registerHook }) {
    registerHook('command', { key: 'radio-commands-band', hook: BandCommand, priority: 100 })
    registerHook('command', { key: 'radio-commands-mode', hook: ModeCommand, priority: 100 })
    registerHook('command', { key: 'radio-commands-frequency', hook: FrequencyCommand, priority: 99 })
  },
})
