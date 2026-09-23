// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// IARU Region 1 Field Day — the exchange, the setup, and the two exports.
// Not a polo port: polo never carried this contest, so the rules come straight
// from the DARC reference rules (see `scorer.ts`), not from a translation.
//
// One extension, two runnings a year — CW in June, SSB in September — sharing
// one ref type, `r1-vhf-tests`' shape: the running lives in the ref's own
// `ref` field as `${mode}-${year}` ("SSB-2026"), so the two runnings of one
// year stay distinct events with distinct logs.

import { exportTypeDefinition } from "@ham2k/extension-sdk"
import { qsonToCabrillo } from "@ham2k/lib-qson-cabrillo"
import { adifForExport, contestScorer, defineExtension, exportFilename, startMillisOf } from "@ham2k/extension-sdk"
import type {
  ActivitySuggestion,
  ExportOption,
  ExportOptionsRequest,
  ExportRequest,
  ExportResult,
  FormElement,
  HookContext,
  JSONValue,
  LoggingControlDescriptor,
  Ref,
  RefLink,
  SuggestArgs,
  TitleSuggestion,
} from "@ham2k/extension-sdk"

import { tFor } from "./i18n.ts"
import { MODES, nextRunningYear, relevanceFor } from "./schedule.ts"
import { R1FDScorer, TYPE, modeOfRef, refOfType, yearOfRef } from "./scorer.ts"
import type { R1FdMode } from "./schedule.ts"

import manifest from "../manifest.json" with { type: "json" }

const RULES_URL = "https://www.darc.de/der-club/referate/conteste/iaru-region-1-fieldday/rules/"

/// What a search has to contain to offer these events. Matched as "does the
/// alias contain what was typed", so "fd" finds every field day and the date
/// ranking decides which comes first.
const ALIASES = ["R1FD", "R1 FD", "REGION 1 FIELD DAY", "IARU FIELD DAY", "FIELD DAY", "FIELDDAY", "FD", "DARC", "IARU"]

function str(value: JSONValue | undefined): string {
  return typeof value === "string" ? value.trim() : ""
}

/// A serial as it should appear in an export: whatever is on the ref, as
/// digits — a typed `their` number arrives as a string but an allocated `our`
/// one may already be a number.
function serial(qso: Record<string, JSONValue>, field: string): string {
  const value = refOfType(qso, TYPE)?.[field]
  if (typeof value === "number") return String(value)
  const digits = str(value)
  return /^\d+$/.test(digits) ? String(parseInt(digits, 10)) : ""
}

/// The next running of [mode] as a ref key, "SSB-2026".
function nextRunningKey(nowMillis: number, mode: R1FdMode): string {
  return `${mode}-${nextRunningYear(nowMillis, mode)}`
}

/// The running nearest on the calendar, for defaults — in July that is
/// September's SSB, in May June's CW.
function nearestMode(nowMillis: number): R1FdMode {
  return relevanceFor(nowMillis, "CW") >= relevanceFor(nowMillis, "SSB") ? "CW" : "SSB"
}

function runningLabel(t: (key: string, args?: Record<string, string>) => string, refKey: string): string {
  const mode = modeOfRef(refKey)
  const year = yearOfRef(refKey)
  if (!mode) return t("unconfigured")
  return [t(mode === "CW" ? "cwRunning" : "ssbRunning"), year].filter((part) => part).join(" ")
}

const ActivityHook = {
  /// Offered in the activity search by NAME and by NEARNESS — both runnings,
  /// each ranked by its own date, so in August the SSB event leads and typing
  /// "field day" in May leads with CW.
  async suggest({ searchTerm }: SuggestArgs, ctx: HookContext): Promise<ActivitySuggestion[]> {
    const t = tFor(ctx)
    const term = (searchTerm ?? "").trim().toUpperCase()
    if (term && !ALIASES.some((alias) => alias.includes(term))) return []

    const now = Date.now()
    return MODES.map((mode) => {
      const key = nextRunningKey(now, mode)
      return {
        type: TYPE,
        // The picker's duplicate guard compares type+ref, and the setup form
        // writes the same key, so both add-paths produce a ref the core
        // recognises as the same activity.
        ref: key,
        // A suggestion is persisted VERBATIM and never runs through
        // `decorateRef`, so everything the operation row reads has to be here.
        program: "Contest",
        name: t("activityDescription"),
        label: `${t("activityLabel")} ${runningLabel(t, key)}`,
        shortLabel: `R1FD ${mode}`,
        relevance: relevanceFor(now, mode),
      }
    })
  },

  async operationControls({ operation }: { operation: Record<string, JSONValue> }, ctx: HookContext): Promise<LoggingControlDescriptor[]> {
    const t = tFor(ctx)
    const now = Date.now()
    const currentKey = str(refOfType(operation, TYPE)?.ref)
    const options = MODES.map((mode) => {
      const key = nextRunningKey(now, mode)
      return { value: key, label: runningLabel(t, key) }
    })
    // A past running stays selectable — an operator editing June's log in
    // September must not have the form silently rewrite which event it was.
    if (currentKey && !options.some((option) => option.value === currentKey)) {
      options.unshift({ value: currentKey, label: runningLabel(t, currentKey) })
    }

    const elements: FormElement[] = [
      {
        type: "field",
        fieldType: "select",
        key: "ref",
        label: t("runningLabel"),
        value: currentKey || nextRunningKey(now, nearestMode(now)),
        options,
      },
      // The two-axis entry category. Station type feeds the scorer —
      // fixed-to-fixed is worth zero, so it changes every verdict — while the
      // rest only describe the entry to the Cabrillo CATEGORY headers.
      {
        type: "field",
        fieldType: "select",
        key: "ourStationType",
        label: t("stationTypeLabel"),
        value: "PORTABLE",
        options: [
          { value: "PORTABLE", label: t("stationPortable") },
          { value: "FIXED", label: t("stationFixed") },
        ],
      },
      {
        type: "field",
        fieldType: "select",
        key: "ourOperators",
        label: t("operatorsLabel"),
        options: [
          { value: "SINGLE-OP", label: t("operatorsSingle") },
          { value: "MULTI-OP", label: t("operatorsMulti") },
        ],
      },
      {
        type: "field",
        fieldType: "select",
        key: "ourPower",
        label: t("powerLabel"),
        options: [
          { value: "QRP", label: t("powerQrp") },
          { value: "LOW", label: t("powerLow") },
          { value: "HIGH", label: t("powerHigh") },
        ],
      },
      {
        type: "field",
        fieldType: "checkbox",
        key: "ourAssisted",
        label: t("assistedLabel"),
      },
      { type: "markdown", text: t("rulesLink", { url: RULES_URL }) },
    ]

    return [
      {
        key: "r1-fd/setup",
        label: t("activityLabel"),
        icon: manifest.icon,
        color: manifest.accentColor,
        order: 10,
        input: { kind: "form", refType: TYPE, form: { title: t("setupLabel"), elements } },
      },
    ]
  },

  /// Two fields per QSO: the number we send and the number they send.
  ///
  /// Ours is a `serial` input — the extension names the sequence and the core
  /// fills the field, so nothing here tracks a counter. One series for the
  /// whole entry: the exchange is "RS(T) + serial number starting from 001",
  /// with no per-band reset.
  async loggingControls(
    args: { operation: Record<string, JSONValue>; qso?: Record<string, JSONValue> },
    ctx: HookContext,
  ): Promise<LoggingControlDescriptor[]> {
    // Off-contest, contribute nothing — saves the work below on every
    // keystroke-triggered refresh; the core refuses the primary field anyway.
    if (!refOfType(args.operation, TYPE)) return []

    const t = tFor(ctx)
    return [
      {
        key: "r1-fd/ourSerial",
        label: t("ourSerialLabel"),
        icon: manifest.icon,
        color: manifest.accentColor,
        order: 10,
        // Sent, not copied: Space and Tab pass over it, the arrows reach it.
        skipFocus: true,
        input: {
          kind: "serial",
          refType: TYPE,
          field: "ourSerial",
          sequence: { key: "serial" },
        },
      },
      {
        key: "r1-fd/theirSerial",
        label: t("theirSerialLabel"),
        icon: manifest.icon,
        color: manifest.accentColor,
        order: 20,
        input: {
          kind: "text",
          refType: TYPE,
          field: "theirSerial",
          numeric: true,
          maxLength: 5,
          // No placeholder: there is nothing to guess about the number another
          // station is about to send.
        },
      },
    ]
  },

  /// Mirrors the exchange this contest keeps on its own ref into the generic
  /// `their.exchange` — nothing outside this extension knows to look inside a
  /// contest ref, so without this the QSO row's exchange column and a plain
  /// ADIF export both come up empty. Only ever a projection: the ref stays the
  /// source of truth.
  async processQsoBeforeSave(
    args: { qso: Record<string, JSONValue>; operation: Record<string, JSONValue> },
    _ctx: HookContext,
  ): Promise<Record<string, JSONValue> | null> {
    if (!refOfType(args.operation, TYPE)) return null
    const qsoRef = refOfType(args.qso, TYPE)
    const exchange = serial(args.qso, "theirSerial")
    // A field the operator EMPTIED is present-but-blank rather than absent.
    // Returning null there would leave the previous save's `their.exchange`
    // showing, so a cleared exchange has to project the blank.
    if (!exchange) return qsoRef && "theirSerial" in qsoRef ? { their: { exchange: "" } } : null
    return { their: { exchange } }
  },
}

const RefHandler = {
  async validateRef({ ref }: { ref: Ref }, _ctx: HookContext) {
    return { valid: true, normalized: (ref.ref ?? "").trim().toUpperCase() }
  },

  async decorateRef({ ref }: { ref: Ref }, ctx: HookContext): Promise<Ref> {
    const t = tFor(ctx)
    const key = str(ref.ref as JSONValue)
    const mode = modeOfRef(key)
    return {
      ...ref,
      program: "Contest",
      name: t("activityDescription"),
      label: [t("activityLabel"), runningLabel(t, key)].filter((part) => part).join(" "),
      shortLabel: mode ? `R1FD ${mode}` : "R1FD",
    }
  },

  async suggestOperationTitle({ ref }: { ref: Ref }, ctx: HookContext): Promise<TitleSuggestion | null> {
    const mode = modeOfRef(str(ref.ref as JSONValue))
    return {
      for: mode ? `R1FD ${mode}` : "R1FD",
      subtitle: tFor(ctx)("serialSubtitle"),
    }
  },

  /// The contest's published rules — a reference here names an event, not a
  /// place, so what there is to read about it is the rules it is run under.
  async linkForRef(_args: { ref: Ref }, _ctx: HookContext): Promise<RefLink | null> {
    return { url: RULES_URL, label: "IARU Region 1 Field Day" }
  },
}

/// The DARC's registered Cabrillo name for a running, also used as the ADIF
/// CONTEST_ID — the R1 field days have no entry in the ADIF contest
/// enumeration, so the submission's own name is the least surprising value.
function contestIdFor(operation: Record<string, JSONValue>): string {
  const mode = modeOfRef(str(refOfType(operation, TYPE)?.ref))
  return mode ? `IARU-FD-R1-DARC-${mode}` : "IARU-FD-R1-DARC"
}

const AdifFieldsHook = {
  async fieldsForOneQSO(
    { qso, operation }: { qso: Record<string, JSONValue>; operation: Record<string, JSONValue> },
    _ctx: HookContext,
  ): Promise<{ name: string; value: string }[]> {
    if (!refOfType(operation, TYPE)) return []

    const fields: { name: string; value: string }[] = [{ name: "CONTEST_ID", value: contestIdFor(operation) }]
    const sent = serial(qso, "ourSerial")
    const received = serial(qso, "theirSerial")
    if (sent) fields.push({ name: "STX", value: sent })
    if (received) fields.push({ name: "SRX", value: received })
    return fields
  },
}

function reportFor(qso: Record<string, JSONValue>, side: "our" | "their"): string {
  const sideData = (qso[side] as Record<string, JSONValue>) ?? {}
  const sent = str(sideData.sent)
  if (sent) return sent
  return str(qso.mode) === "CW" ? "599" : "59"
}

function filenameFor(operation: Record<string, JSONValue>, qsos: Record<string, JSONValue>[], extension: string, compact?: boolean): string {
  const mode = modeOfRef(str(refOfType(operation, TYPE)?.ref))
  return exportFilename({
    stationCall: operation.stationCall,
    activity: mode ? `R1-FD-${mode}` : "R1-FD",
    startAtMillis: startMillisOf(operation, qsos),
    extension,
    compact,
  })
}

const ExportHook = {
  async getExportTypes() {
    return [exportTypeDefinition(TYPE, "adif", manifest.shortName), exportTypeDefinition(TYPE, "cabrillo", manifest.shortName)]
  },
  async suggestExportOptions(args: ExportOptionsRequest, ctx: HookContext): Promise<ExportOption[]> {
    if (!refOfType(args.operation, TYPE)) return []
    const t = tFor(ctx)
    const named = (extension: string) => filenameFor(args.operation, args.qsos ?? [], extension, args.compactFilenames)
    return [
      {
        exportType: `${TYPE}-adif`,
        templateData: {
          activity: modeOfRef(str(refOfType(args.operation, TYPE)?.ref)) ? `R1-FD-${modeOfRef(str(refOfType(args.operation, TYPE)?.ref))}` : "R1-FD",
        },
        format: "adif",
        label: t("adifExport", { contest: manifest.shortName }),
        filename: named("adi"),
        selectedByDefault: true,
        refType: TYPE,
      },
      {
        exportType: `${TYPE}-cabrillo`,
        templateData: {
          activity: modeOfRef(str(refOfType(args.operation, TYPE)?.ref)) ? `R1-FD-${modeOfRef(str(refOfType(args.operation, TYPE)?.ref))}` : "R1-FD",
        },
        format: "cabrillo",
        label: t("cabrilloExport", { contest: manifest.shortName }),
        filename: named("log"),
        selectedByDefault: true,
        refType: TYPE,
      },
    ]
  },

  async generateExport(args: ExportRequest, _ctx: HookContext): Promise<ExportResult> {
    // Only the two exportTypes offered above — a hook that answers for an
    // exportType it never offered makes the ADIF delegation recurse into
    // itself.
    if (args.exportType !== `${TYPE}-cabrillo` && args.exportType !== `${TYPE}-adif`) {
      return { filename: "", mimeType: "", content: "" }
    }

    const operation = args.operation
    const opRef = refOfType(operation, TYPE)
    const ourCall = str(operation.stationCall)

    if (args.exportType === `${TYPE}-cabrillo`) {
      // The CATEGORY block the DARC's sample logs show; the checker reads the
      // entry class from these lines, not from a claimed-category name.
      const mode = modeOfRef(str(opRef?.ref))
      const content = qsonToCabrillo(args.qsos, {
        headers: [
          ["CONTEST", contestIdFor(operation)],
          ["CALLSIGN", ourCall],
          ["CATEGORY-STATION", str(opRef?.ourStationType)],
          ["CATEGORY-OPERATOR", str(opRef?.ourOperators)],
          ["CATEGORY-POWER", str(opRef?.ourPower)],
          ["CATEGORY-ASSISTED", opRef?.ourAssisted === true ? "ASSISTED" : "NON-ASSISTED"],
          ["CATEGORY-MODE", mode],
          ["OPERATORS", str((operation.local as Record<string, JSONValue>)?.operatorCall)],
          ["GRID-LOCATOR", str(operation.grid)],
        ],
        qsoParts: (qso) => [
          ourCall || "-",
          reportFor(qso, "our"),
          serial(qso, "ourSerial") || "0",
          str(((qso.their as Record<string, JSONValue>) ?? {}).call) || "-",
          reportFor(qso, "their"),
          serial(qso, "theirSerial") || "0",
        ],
      })
      return {
        filename: filenameFor(operation, args.qsos, "log", args.compactFilenames),
        mimeType: "text/plain",
        content,
      }
    }

    const content = await adifForExport({
      operation: args.operation,
      qsos: args.qsos,
      segments: args.segments,
      includePrivateData: args.includePrivateData,
      includeLookupData: args.includeLookupData,
      exportSettings: args.exportSettings,
      exportData: args.exportData,
      exportTitle: args.exportTitle,
      // This file is the CONTEST's log, so the core exporter asks this
      // extension's `adifFields` hook and no other's.
      mainHandler: TYPE,
    })
    return {
      filename: filenameFor(operation, args.qsos, "adi", args.compactFilenames),
      mimeType: "text/plain",
      content,
    }
  },
}

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook("activity", { hook: ActivityHook, key: TYPE })
    registerHook(`ref:${TYPE}`, { hook: RefHandler, key: TYPE })
    registerHook("adifFields", { hook: AdifFieldsHook, key: TYPE })
    registerHook("export", { hook: ExportHook, key: TYPE })
    registerHook("scoring", {
      hook: contestScorer(R1FDScorer, { scope: { refTypes: [TYPE] } }),
      key: TYPE,
    })
  },
})
