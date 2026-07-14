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

import { parseFreq, fmtFreq } from "@ham2k/lib-format-tools"
import { bandForFrequency } from "@ham2k/lib-operation-data"

import { defineExtension } from "@ham2k/halo-extension-sdk"
import type { CommandInterpretation, HookContext } from "@ham2k/halo-extension-sdk"

const BAND_MATCH = /^(2200|630|160|80|60|40|30|20|17|15|12|10|6|4|2)M?$/i
const MODE_MATCH = /^(CW|SSB|USB|LSB|FM|AM|FT8|FT4|FT2|RTTY)$/i
const FREQUENCY_MATCH = /^[\d.,]+$/

const BandCommand = {
  async interpret({ input }: { input: string }, _ctx: HookContext): Promise<CommandInterpretation | null> {
    const match = BAND_MATCH.exec(input.trim())
    if (!match) return null
    const band = `${match[1].toLowerCase()}m`
    return {
      describe: `Change band to **${band}**?`,
      confirm: `Band set to **${band}**`,
      commands: [{ setVfo: { band } }],
    }
  },
}

const FrequencyCommand = {
  async interpret(
    { input, qso }: { input: string; qso?: Record<string, any> },
    _ctx: HookContext,
  ): Promise<CommandInterpretation | null> {
    const trimmed = input.trim()
    // Require at least 3 characters so short band-only numbers ("20") don't
    // get treated as frequencies before the (higher-priority) band command
    // has a chance to match them.
    if (trimmed.length < 3) return null

    let freq: number | null = null
    const qsoFreq = typeof qso?.freq === 'number' ? qso.freq : null

    if (trimmed.startsWith('..') && qsoFreq) {
      freq = parseFreq(`${Math.round(qsoFreq / 1000)}${trimmed.substring(1)}`)
    } else if ((trimmed.startsWith('.') || trimmed.startsWith(',')) && qsoFreq) {
      freq = parseFreq(`${Math.floor(qsoFreq / 1000)}${trimmed}`)
    } else if (FREQUENCY_MATCH.test(trimmed)) {
      freq = parseFreq(trimmed)
    }

    if (!freq) return null

    // bandForFrequency falls back to the literal string 'other' for
    // unrecognized frequencies rather than a falsy value.
    const band = freq ? bandForFrequency(freq) : undefined
    if (!band || band === 'other') return null

    const formattedFreq = fmtFreq(freq)
    return {
      describe: `Change frequency to **${formattedFreq} MHz**?`,
      confirm: `Frequency set to **${formattedFreq} MHz**`,
      commands: [{ setVfo: { freq } }],
    }
  },
}

const ModeCommand = {
  async interpret({ input }: { input: string }, _ctx: HookContext): Promise<CommandInterpretation | null> {
    const match = MODE_MATCH.exec(input.trim())
    if (!match) return null
    const mode = match[1].toUpperCase()
    return {
      describe: `Change mode to **${mode}**?`,
      confirm: `Mode set to **${mode}**`,
      commands: [{ setVfo: { mode } }],
    }
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
