// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Core radio commands: band, frequency, mode, power and keyer-speed shortcuts typed into the
// call field and triggered on space, ported from app-polo's RadioCommands
// extension (src/extensions/commands/RadioCommands.js) — this is the
// reference implementation of the `command` hook category (DESIGN.md §4,
// docs/extensions/hooks.md). Power has no app-polo equivalent — CAT power
// control is new to this app.
//
// Frequency parsing delegates to @ham2k/lib-format-tools' parseFreq (the
// same published parser app-polo uses), which reads the app's notation —
// "14.285", "14.200.5", "1.296.000" — by the same band tie-break as the
// app's own Freq field.

import { parseFreq, fmtFreq } from "@ham2k/lib-format-tools"
import { bandForFrequency } from "@ham2k/lib-operation-data"

import { defineExtension } from "@ham2k/extension-sdk"
import type { CommandCatalogEntry, CommandInterpretation, HookContext } from "@ham2k/extension-sdk"
import { tFor } from "./i18n.ts"
import { parsePowerCommand } from "./parsePowerCommand.ts"
import { parseWpmCommand } from "./parseWpmCommand.ts"
import { parseKeyerCommand } from "./parseKeyerCommand.ts"
import { parseEnterSendsCommand } from "./parseEnterSendsCommand.ts"
import { parseGigBandCommand } from "./parseGigBandCommand.ts"
import { parseBandCommand } from "./parseBandCommand.ts"

import manifest from "../manifest.json" with { type: "json" }

// CW keying sits behind its own experiment (app/experiments.yaml), checked
// per-call via ctx.enabledExperiments rather than manifest.experiments, which
// would gate the whole file.
const KEYER_EXPERIMENT = "keyer"
const keyerEnabled = (ctx: HookContext) => !!ctx.enabledExperiments?.includes(KEYER_EXPERIMENT)

// Enter Sends Messages, on top of keying (app/experiments.yaml).
const ESM_EXPERIMENT = "esm"
const esmEnabled = (ctx: HookContext) => keyerEnabled(ctx) && !!ctx.enabledExperiments?.includes(ESM_EXPERIMENT)

const MODE_MATCH = /^(CW|SSB|USB|LSB|FM|AM|FT8|FT4|FT2|RTTY)$/i
const FREQUENCY_MATCH = /^[\d.,]+$/

// Every band the app supports, by name — see parseBandCommand.ts.
const BandCommand = {
  async interpret({ input }: { input: string }, ctx: HookContext): Promise<CommandInterpretation | null> {
    const band = parseBandCommand(input)
    if (!band) return null
    const t = tFor(ctx)
    return {
      describe: t("bandDescribe", { band }),
      confirm: t("bandConfirm", { band }),
      commands: [{ setVfo: { band } }],
    }
  },

  // One BAND entry, not one per band — the palette lists the command, and
  // `interpret` above is what recognizes each actual band.
  async catalog(ctx: HookContext): Promise<CommandCatalogEntry[]> {
    const t = tFor(ctx)
    return [
      {
        command: "20M",
        keywords: ["BAND", "METERS"],
        params: "(80M, 20M, 70CM, 2MM…)",
        describe: t("catalogBand"),
        category: t("catalogCategory"),
        expectsParams: true,
        suggest: true,
      },
    ]
  },
}

// The GHz designations microwave operators actually say — see parseGigBandCommand.ts.
// Above the frequency command in priority, though nothing it matches holds a 'G'.
const GigBandCommand = {
  async interpret({ input }: { input: string }, ctx: HookContext): Promise<CommandInterpretation | null> {
    const parsed = parseGigBandCommand(input)
    if (!parsed) return null
    // The operator typed a designation, so the confirmation says it back, next to
    // the band name they see everywhere else in the app.
    const band = `${parsed.designation} (${parsed.band})`
    const t = tFor(ctx)
    return {
      describe: t("bandDescribe", { band }),
      confirm: t("bandConfirm", { band }),
      commands: [{ setVfo: { band: parsed.band } }],
    }
  },

  async catalog(ctx: HookContext): Promise<CommandCatalogEntry[]> {
    const t = tFor(ctx)
    return [
      {
        command: "10G",
        keywords: ["BAND", "GHZ", "MICROWAVE"],
        params: "(1.2G, 24G, 47G…)",
        describe: t("catalogGigBand"),
        category: t("catalogCategory"),
        expectsParams: true,
        suggest: true,
      },
    ]
  },
}

const FrequencyCommand = {
  async interpret({ input, qso }: { input: string; qso?: Record<string, any> }, ctx: HookContext): Promise<CommandInterpretation | null> {
    const trimmed = input.trim()
    // Require at least 3 characters so short band-only numbers ("20") don't
    // get treated as frequencies before the (higher-priority) band command
    // has a chance to match them.
    if (trimmed.length < 3) return null

    let freq: number | null = null
    const qsoFreq = typeof qso?.freq === "number" ? qso.freq : null

    if (trimmed.startsWith("..") && qsoFreq) {
      freq = parseFreq(`${Math.round(qsoFreq / 1000)}${trimmed.substring(1)}`)
    } else if ((trimmed.startsWith(".") || trimmed.startsWith(",")) && qsoFreq) {
      freq = parseFreq(`${Math.floor(qsoFreq / 1000)}${trimmed}`)
    } else if (FREQUENCY_MATCH.test(trimmed)) {
      freq = parseFreq(trimmed)
    }

    if (!freq) return null

    // bandForFrequency falls back to the literal string 'other' for
    // unrecognized frequencies rather than a falsy value.
    const band = freq ? bandForFrequency(freq) : undefined
    if (!band || band === "other") return null

    const formattedFreq = fmtFreq(freq)
    const t = tFor(ctx)
    return {
      describe: t("freqDescribe", { freq: formattedFreq }),
      confirm: t("freqConfirm", { freq: formattedFreq }),
      commands: [{ setVfo: { freq } }],
    }
  },

  async catalog(ctx: HookContext): Promise<CommandCatalogEntry[]> {
    const t = tFor(ctx)
    return [
      {
        command: "14.285",
        keywords: ["FREQUENCY", "FREQ", "QRG", "VFO", "KHZ", "MHZ"],
        params: "(14285, 14.285…)",
        describe: t("catalogFreq"),
        category: t("catalogCategory"),
        expectsParams: true,
        suggest: true,
      },
    ]
  },
}

const ModeCommand = {
  async interpret({ input }: { input: string }, ctx: HookContext): Promise<CommandInterpretation | null> {
    const match = MODE_MATCH.exec(input.trim())
    if (!match) return null
    const mode = match[1].toUpperCase()
    const t = tFor(ctx)
    return {
      describe: t("modeDescribe", { mode }),
      confirm: t("modeConfirm", { mode }),
      commands: [{ setVfo: { mode } }],
    }
  },

  async catalog(ctx: HookContext): Promise<CommandCatalogEntry[]> {
    const t = tFor(ctx)
    return [
      {
        command: "CW",
        keywords: ["MODE", "SSB", "USB", "LSB", "FM", "AM", "FT8", "FT4", "FT2", "RTTY"],
        params: "(CW, SSB, FT8…)",
        describe: t("catalogMode"),
        category: t("catalogCategory"),
        expectsParams: true,
        suggest: true,
      },
    ]
  },
}

const PowerCommand = {
  async interpret({ input }: { input: string }, ctx: HookContext): Promise<CommandInterpretation | null> {
    const watts = parsePowerCommand(input)
    if (watts == null) return null
    const t = tFor(ctx)
    return {
      describe: t("powerDescribe", { watts }),
      confirm: t("powerConfirm", { watts }),
      commands: [{ setPower: { watts } }],
    }
  },

  async catalog(ctx: HookContext): Promise<CommandCatalogEntry[]> {
    const t = tFor(ctx)
    return [
      {
        command: "5W",
        keywords: ["POWER", "WATTS", "PWR"],
        params: "(1W, 5W, 50W…)",
        describe: t("catalogPower"),
        category: t("catalogCategory"),
        expectsParams: true,
        suggest: true,
      },
    ]
  },
}

// Behind the keyer experiment (and CAT): the app reports "no CW-capable
// radio connected" on dispatch rather than this hook guessing at the
// radio's state.
const WpmCommand = {
  async interpret({ input }: { input: string }, ctx: HookContext): Promise<CommandInterpretation | null> {
    if (!keyerEnabled(ctx)) return null
    const wpm = parseWpmCommand(input)
    if (wpm == null) return null
    const t = tFor(ctx)
    return {
      describe: t("wpmDescribe", { wpm }),
      confirm: t("wpmConfirm", { wpm }),
      commands: [{ setKeyerSpeed: { wpm } }],
    }
  },

  async catalog(ctx: HookContext): Promise<CommandCatalogEntry[]> {
    if (!keyerEnabled(ctx)) return []
    const t = tFor(ctx)
    return [
      {
        command: "20WPM",
        keywords: ["SPEED", "WPM", "KEYER"],
        params: "(18WPM, 25WPM…)",
        describe: t("catalogWpm"),
        category: t("catalogCategory"),
        expectsParams: true,
        suggest: true,
      },
    ]
  },
}

// KEYER / MACROS: brings up the keyer area with its message buttons. Same
// gate as WPM; the app says when nothing connected can key.
const KeyerCommand = {
  async interpret({ input }: { input: string }, ctx: HookContext): Promise<CommandInterpretation | null> {
    if (!keyerEnabled(ctx)) return null
    if (!parseKeyerCommand(input)) return null
    const t = tFor(ctx)
    return {
      describe: t("keyerDescribe"),
      confirm: t("keyerConfirm"),
      commands: [{ showKeyer: {} }],
    }
  },

  async catalog(ctx: HookContext): Promise<CommandCatalogEntry[]> {
    if (!keyerEnabled(ctx)) return []
    const t = tFor(ctx)
    return [
      {
        command: "KEYER",
        keywords: ["MACROS", "MESSAGES", "CW"],
        params: "(MACROS)",
        describe: t("catalogKeyer"),
        category: t("catalogCategory"),
        suggest: true,
      },
    ]
  },
}

// ESM / ESM OFF / RUN / SP: Enter Sends Messages and which side of the
// exchange it plays. Gated on its own experiment on top of KEYER's; the app
// says when nothing can key.
const EnterSendsCommand = {
  async interpret({ input }: { input: string }, ctx: HookContext): Promise<CommandInterpretation | null> {
    if (!esmEnabled(ctx)) return null
    const ask = parseEnterSendsCommand(input)
    if (!ask) return null
    const t = tFor(ctx)
    const which = !ask.on ? "esmOff" : ask.running === true ? "esmRun" : ask.running === false ? "esmSp" : "esmOn"
    return {
      describe: t(`${which}Describe`),
      confirm: t(`${which}Confirm`),
      commands: [{ setEnterSends: ask }],
    }
  },

  async catalog(ctx: HookContext): Promise<CommandCatalogEntry[]> {
    if (!esmEnabled(ctx)) return []
    const t = tFor(ctx)
    return [
      { command: "ESM", keywords: ["ENTER SENDS", "ENTER"], params: "(OFF)", describe: t("catalogEsm"), category: t("catalogCategory"), suggest: true },
      { command: "RUN", keywords: ["RUNNING", "CQ", "ENTER SENDS"], describe: t("catalogRun"), category: t("catalogCategory"), suggest: true },
      {
        command: "SP",
        keywords: ["S&P", "SEARCH AND POUNCE", "POUNCE", "ENTER SENDS"],
        params: "(S&P)",
        describe: t("catalogSp"),
        category: t("catalogCategory"),
        suggest: true,
      },
    ]
  },
}

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook("command", { key: "radio-commands-band", hook: BandCommand, priority: 100 })
    registerHook("command", { key: "radio-commands-mode", hook: ModeCommand, priority: 100 })
    registerHook("command", { key: "radio-commands-gig-band", hook: GigBandCommand, priority: 100 })
    registerHook("command", { key: "radio-commands-frequency", hook: FrequencyCommand, priority: 99 })
    registerHook("command", { key: "radio-commands-power", hook: PowerCommand, priority: 100 })
    registerHook("command", { key: "radio-commands-wpm", hook: WpmCommand, priority: 100 })
    registerHook("command", { key: "radio-commands-keyer", hook: KeyerCommand, priority: 100 })
    registerHook("command", { key: "radio-commands-enter-sends", hook: EnterSendsCommand, priority: 100 })
  },
})
