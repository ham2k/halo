// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Call-field commands that edit the OPEN operation:
//   OPER / OPERATOR <call>  — who is at the key ("OPER KI2D", "OPER/KI2D")
//   POSITION <n>            — this device's multi-station position, the `n`
//                             in the `/OP<n>` its self-spots go out under
//                             ("POSITION 2"); POSITION 0 clears it
//   START / BREAK / STOP    — segment markers on the log (END = STOP)
//   ROVERQTH                — a rover moving: a break, then the operation's
//                             Location screen, in one step
//   FIND [query]            — the log's Find bar, on a QSO number or a call
//                             (SEARCH, JUMP, GOTO are the same command)
// None of the hooks writes anything: they parse text into an
// `updateOperation`, `markSegment` or `findInLog` action, and the app
// resolves which operation is open and does the rest.

import { defineExtension } from "@ham2k/extension-sdk"
import type { CommandCatalogEntry, CommandInterpretation, HookContext, JSONValue } from "@ham2k/extension-sdk"
import { parseFindCommand, parseOperatorCommand, parsePositionCommand, parseSegmentCommand, positionValueFor } from "./operationCommandParsing.ts"
import { tFor } from "./i18n.ts"

import manifest from "../manifest.json" with { type: "json" }

const OperatorCommand = {
  async interpret({ input, operation }: { input: string; operation?: Record<string, JSONValue> }, ctx: HookContext): Promise<CommandInterpretation | null> {
    const parsed = parseOperatorCommand(input)
    if (!parsed) return null
    const t = tFor(ctx)
    if (!operation) return { error: t("needsOperation") }
    // Recognized but not complete: bare "OPER" puts the field into free-text
    // mode for the callsign, and Enter cannot run it meanwhile — without
    // this the word falls through and Enter logs "OPER" as a contact.
    if (!parsed.call) return { expectsParams: true }
    return {
      describe: t("setOperator", { call: parsed.call }),
      confirm: t("settingOperator", { call: parsed.call }),
      commands: [{ updateOperation: { operatorCall: parsed.call } }],
    }
  },

  async catalog(ctx: HookContext): Promise<CommandCatalogEntry[]> {
    const t = tFor(ctx)
    return [
      {
        command: "OPER",
        keywords: ["OPERATOR"],
        params: "<call>",
        describe: t("catalogOperator"),
        category: t("catalogCategory"),
        needsOperation: true,
        expectsParams: true,
      },
    ]
  },
}

const PositionCommand = {
  async interpret({ input, operation }: { input: string; operation?: Record<string, JSONValue> }, ctx: HookContext): Promise<CommandInterpretation | null> {
    const parsed = parsePositionCommand(input)
    if (!parsed) return null
    const t = tFor(ctx)
    if (!operation) return { error: t("needsOperation") }
    if (!parsed.position) return { expectsParams: true }
    // A non-number is a mistake worth naming rather than a prefix to keep
    // typing: whatever is typed here ends up in a callsign on the air.
    if (parsed.invalid) return { error: t("positionNeedsNumber") }
    const value = positionValueFor(parsed.position)
    return {
      describe: value ? t("setPosition", { position: value }) : t("clearPosition"),
      confirm: value ? t("settingPosition", { position: value }) : t("clearingPosition"),
      commands: [{ updateOperation: { multiIdentifier: value } }],
    }
  },

  async catalog(ctx: HookContext): Promise<CommandCatalogEntry[]> {
    const t = tFor(ctx)
    return [
      {
        command: "POSITION",
        keywords: ["MULTI-OP", "SEAT"],
        params: "<number>",
        describe: t("catalogPosition"),
        category: t("catalogCategory"),
        needsOperation: true,
        expectsParams: true,
      },
    ]
  },
}

const SegmentCommand = {
  async interpret({ input, operation }: { input: string; operation?: Record<string, JSONValue> }, ctx: HookContext): Promise<CommandInterpretation | null> {
    const parsed = parseSegmentCommand(input)
    if (!parsed) return null
    const t = tFor(ctx)
    if (!operation) return { error: t("needsOperation") }
    const key = parsed.setLocation ? "roverQth" : parsed.kind
    return {
      describe: t(`${key}`),
      confirm: t(`${key}Confirm`),
      commands: [{ markSegment: { kind: parsed.kind, ...(parsed.setLocation ? { setLocation: true } : {}) } }],
    }
  },

  async catalog(ctx: HookContext): Promise<CommandCatalogEntry[]> {
    const t = tFor(ctx)
    const category = t("catalogCategory")
    return [
      { command: "START", keywords: ["BEGIN", "SEGMENT"], describe: t("catalogStart"), category, needsOperation: true },
      { command: "BREAK", keywords: ["SEGMENT", "PAUSE"], describe: t("catalogBreak"), category, needsOperation: true },
      { command: "STOP", keywords: ["END", "FINISH", "SEGMENT"], describe: t("catalogStop"), category, needsOperation: true },
      { command: "ROVERQTH", keywords: ["ROVER", "MOVE", "LOCATION", "QTH", "GRID"], describe: t("catalogRoverQth"), category, needsOperation: true },
    ]
  },
}

const FindCommand = {
  async interpret({ input, operation }: { input: string; operation?: Record<string, JSONValue> }, ctx: HookContext): Promise<CommandInterpretation | null> {
    const parsed = parseFindCommand(input)
    if (!parsed) return null
    const t = tFor(ctx)
    // mixedCase, like SEED: bare FIND runs on Enter, yet Space must stay a
    // literal character so "FIND KN" can still be typed. The bar reads the
    // query uppercase whatever arrives.
    if (!operation) return { mixedCase: true, error: t("needsOperation") }
    return {
      mixedCase: true,
      describe: parsed.query ? t("find", { query: parsed.query }) : t("findOpen"),
      commands: [{ findInLog: parsed.query ? { query: parsed.query } : {} }],
    }
  },

  async catalog(ctx: HookContext): Promise<CommandCatalogEntry[]> {
    const t = tFor(ctx)
    return [
      {
        command: "FIND",
        keywords: ["SEARCH", "JUMP", "GOTO"],
        params: "[number or call]",
        describe: t("catalogFind"),
        category: t("catalogCategory"),
        needsOperation: true,
        suggest: true,
      },
    ]
  },
}

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook("command", { key: "operation-commands-operator", hook: OperatorCommand, priority: 100 })
    registerHook("command", { key: "operation-commands-position", hook: PositionCommand, priority: 100 })
    registerHook("command", { key: "operation-commands-segment", hook: SegmentCommand, priority: 100 })
    registerHook("command", { key: "operation-commands-find", hook: FindCommand, priority: 100 })
  },
})
