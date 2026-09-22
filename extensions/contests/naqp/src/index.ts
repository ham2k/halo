// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// North American QSO Party. Ported from app-polo's NAQPExtension.
//
// What it exercises that
// the other contests don't: TWO primary fields writing to one ref — NAQP sends
// a name
// and a location, and both are typed on every QSO.
//
// Its location set is inline (`locations.ts`), per docs/design/contests.md
// §5.3's dataset table.

import { exportTypeDefinition } from "@ham2k/extension-sdk"
import { qsonToCabrillo } from "@ham2k/lib-qson-cabrillo"
import { adifForExport, contestScorer, defineExtension, exportFilename, startMillisOf } from "@ham2k/extension-sdk"
import type {
  ExportOption,
  ExportOptionsRequest,
  ExportRequest,
  ExportResult,
  HookContext,
  JSONValue,
  LoggingControlDescriptor,
  Ref,
  RefLink,
} from "@ham2k/extension-sdk"
import { annotateCallAgainstCountryFile } from "../../../sdk/src/dxcc.ts"

import { tFor } from "./i18n.ts"
import { firstName, guessedLocation, guessedName, normalizeLocation, ourExchange } from "./exchange.ts"
import { LOCATION_PATTERN, VALID_LOCATIONS } from "./locations.ts"
import { NAQPScorer } from "./scorer.ts"

import manifest from "../manifest.json" with { type: "json" }

const TYPE = "naqp"

function refOfType(container: Record<string, JSONValue>, type: string): Record<string, JSONValue> | undefined {
  return ((container.refs as Record<string, JSONValue>[] | undefined) ?? []).find((r) => r?.type === type)
}

function str(value: JSONValue | undefined): string {
  return typeof value === "string" ? value : ""
}

const ActivityHook = {
  async operationControls(_args: { operation: Record<string, JSONValue> }, ctx: HookContext): Promise<LoggingControlDescriptor[]> {
    const t = tFor(ctx)
    return [
      {
        key: "naqp/setup",
        label: t("activityLabel"),
        icon: manifest.icon,
        color: manifest.accentColor,
        order: 10,
        input: {
          kind: "form",
          refType: TYPE,
          form: {
            title: t("setupLabel"),
            elements: [
              {
                type: "field",
                fieldType: "radio",
                key: "mode",
                label: t("modeLabel"),
                // NAQP runs these as separate contests on separate weekends.
                options: [
                  { value: "CW", label: "CW" },
                  { value: "SSB", label: "SSB" },
                  { value: "RTTY", label: "RTTY" },
                ],
              },
              // `ourName`/`ourLocation`, not `name`/`location`: a form field
              // key IS a key on the ref, and `name` is the slot `decorateRef`
              // writes the activity row's subtitle into. Naming them plainly
              // would have this setup overwrite itself on save.
              {
                type: "field",
                fieldType: "text",
                key: "ourName",
                label: t("ourNameLabel"),
                placeholder: t("ourNamePlaceholder"),
                uppercase: true,
              },
              {
                type: "field",
                fieldType: "text",
                key: "ourLocation",
                label: t("ourLocationLabel"),
                placeholder: t("ourLocationPlaceholder"),
                uppercase: true,
              },
              { type: "markdown", text: t("rulesLink") },
            ],
          },
        },
      },
    ]
  },

  /// TWO fields per QSO — the first contest here to need that. Both write to
  /// the same ref, which the core folds together.
  ///
  /// Both are UPPERCASE. §5.3 cites this name field as its worked example of
  /// where `uppercase: false` belongs, and that is wrong for an on-air
  /// exchange: an operator not reaching for shift logs "bob", and a Cabrillo
  /// full of mixed-case names reads as sloppy. polo forces uppercase here too.
  async loggingControls(
    args: { operation: Record<string, JSONValue>; qso?: Record<string, JSONValue> },
    ctx: HookContext,
  ): Promise<LoggingControlDescriptor[]> {
    // Off-contest, contribute nothing — an optimization, not the rule. The core
    // already refuses a primary field to an activity the operation isn't
    // running; what this saves is a country-file annotation per refresh.
    if (!refOfType(args.operation, TYPE)) return []

    const t = tFor(ctx)
    const their = (args.qso?.their as Record<string, JSONValue>) ?? {}
    const name = guessedName(their)
    const location = guessedLocation(their)

    return [
      {
        key: "naqp/name",
        label: t("nameLabel"),
        icon: manifest.icon,
        color: manifest.accentColor,
        order: 10,
        input: {
          kind: "text",
          refType: TYPE,
          field: "name",
          maxLength: 12,
          uppercase: true,
          placeholder: name || undefined,
          suggestedValue: name || undefined,
        },
      },
      {
        key: "naqp/location",
        label: t("locationLabel"),
        icon: manifest.icon,
        color: manifest.accentColor,
        order: 20,
        input: {
          kind: "text",
          refType: TYPE,
          field: "location",
          maxLength: 4,
          uppercase: true,
          pattern: LOCATION_PATTERN,
          placeholder: location || undefined,
          suggestedValue: location || undefined,
        },
      },
    ]
  },

  /// Records what was received, and mirrors it where the rest of the app can
  /// see it (docs/design/contests.md §8).
  ///
  /// Both halves of the exchange are guessable — the name from the callsign
  /// lookup, the location from the country file — so both are written onto the
  /// ref as data of record rather than left for the export to re-derive. The
  /// typed value always wins.
  async processQsoBeforeSave(
    args: { qso: Record<string, JSONValue>; operation: Record<string, JSONValue> },
    _ctx: HookContext,
  ): Promise<Record<string, JSONValue> | null> {
    if (!refOfType(args.operation, TYPE)) return null

    const their = (args.qso.their as Record<string, JSONValue>) ?? {}
    const qsoRef = refOfType(args.qso, TYPE)

    // PRESENCE of each field, not its truthiness. The core writes `field: ''`
    // when the operator empties one on purpose, and drops the key entirely when
    // it was never filled in — so a present key, blank or not, is a decision,
    // and guessing over it would put back what they just removed. The two
    // halves decide independently: clearing a name doesn't re-guess a location.
    const nameDecided = qsoRef !== undefined && "name" in qsoRef
    const locationDecided = qsoRef !== undefined && "location" in qsoRef
    const name = nameDecided ? firstName(qsoRef.name) : guessedName(their)
    const location = locationDecided ? normalizeLocation(qsoRef.location) : guessedLocation(their)

    if (!name && !location) {
      // A deliberate blank still projects, so clearing an exchange on an edit
      // clears the QSO row's column too instead of leaving the old value there.
      return nameDecided || locationDecided ? { their: { exchange: "" } } : null
    }

    // Only the halves that actually carry something, or that the operator
    // already decided. An object literal would put BOTH keys on the ref every
    // time — stamping `location: ''` onto a QSO whose location simply couldn't
    // be guessed yet, which the presence rule above then reads back forever as
    // "the operator emptied this". The half would never be guessed again, and
    // the state multiplier would be lost for good.
    const refPatch: Record<string, JSONValue> = { type: TYPE }
    if (name || nameDecided) refPatch.name = name
    if (location || locationDecided) refPatch.location = location

    return {
      // Field-wise into our own ref; the core allows this extension no other.
      refs: [refPatch],
      their: { exchange: [name, location].filter((x) => x).join(" ") },
    }
  },
}

const RefHandler = {
  async validateRef({ ref }: { ref: Ref }, _ctx: HookContext) {
    return { valid: true, normalized: (ref.ref ?? "").trim() }
  },

  async decorateRef({ ref }: { ref: Ref }, ctx: HookContext): Promise<Ref> {
    const mode = str((ref as Record<string, JSONValue>).mode)
    const label = mode ? `NAQP ${mode}` : tFor(ctx)("unconfigured")
    const { name, location } = ourExchange(ref as Record<string, JSONValue>)
    return {
      ...ref,
      program: "Contest",
      label,
      shortLabel: label,
      name: [name, location].filter((x) => x).join(" ") || tFor(ctx)("notConfigured"),
    }
  },

  /// "KI2D for NAQP CW" with "SEB in NY" beneath it: the sent exchange is the
  /// one thing an operator re-reads constantly during a contest.
  async suggestOperationTitle({ ref }: { ref: Ref; operation: Record<string, JSONValue> }, ctx: HookContext) {
    const mode = str((ref as Record<string, JSONValue>).mode)
    const { name, location } = ourExchange(ref as Record<string, JSONValue>)
    return {
      for: ["NAQP", mode].filter((x) => x).join(" "),
      subtitle: name && location ? tFor(ctx)("ourExchangeSubtitle", { name, location }) : undefined,
    }
  },

  /// The contest's published rules — a reference here names an event, not a
  /// place, so what there is to read about it is the rules it is run under.
  async linkForRef(_args: { ref: Ref }, _ctx: HookContext): Promise<RefLink | null> {
    return { url: "https://ncjweb.com/naqp/", label: "NAQP" }
  },
}

const AdifFieldsHook = {
  async fieldsForOneQSO(
    { qso, operation }: { qso: Record<string, JSONValue>; operation: Record<string, JSONValue> },
    _ctx: HookContext,
  ): Promise<{ name: string; value: string }[]> {
    const opRef = refOfType(operation, TYPE)
    if (!opRef) return []
    const mode = str(opRef.mode)

    const fields: { name: string; value: string }[] = [{ name: "CONTEST_ID", value: mode ? `NAQP-${mode}` : "NAQP" }]
    const ours = ourExchange(opRef)
    const qsoRef = refOfType(qso, TYPE)
    const sent = [ours.name, ours.location].filter((x) => x).join(" ")
    const received = [firstName(qsoRef?.name), normalizeLocation(qsoRef?.location)].filter((x) => x).join(" ")
    if (sent) fields.push({ name: "STX_STRING", value: sent })
    if (received) fields.push({ name: "SRX_STRING", value: received })
    return fields
  },
}

function reportFor(qso: Record<string, JSONValue>, side: "our" | "their"): string {
  const sideData = (qso[side] as Record<string, JSONValue>) ?? {}
  const sent = str(sideData.sent)
  if (sent) return sent
  return str(qso.mode) === "CW" || str(qso.mode) === "RTTY" ? "599" : "59"
}

/// The contest's own name for this operation's file — the mode is part of the
/// identity here, since NAQP CW and NAQP SSB are separate contests with
/// separate submissions. Same string the Cabrillo and ADIF headers carry.
function contestTag(operation: Record<string, JSONValue>): string {
  const mode = str(refOfType(operation, TYPE)?.mode)
  return mode ? `NAQP-${mode}` : "NAQP"
}

function filenameFor(operation: Record<string, JSONValue>, qsos: Record<string, JSONValue>[], extension: string, compact?: boolean): string {
  return exportFilename({
    stationCall: operation.stationCall,
    activity: contestTag(operation),
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
        templateData: { activity: contestTag(args.operation) },
        format: "adif",
        label: t("adifExport", { contest: manifest.shortName }),
        filename: named("adi"),
        selectedByDefault: true,
        refType: TYPE,
      },
      {
        exportType: `${TYPE}-cabrillo`,
        templateData: { activity: contestTag(args.operation) },
        format: "cabrillo",
        label: t("cabrilloExport", { contest: manifest.shortName }),
        filename: named("log"),
        selectedByDefault: true,
        refType: TYPE,
      },
    ]
  },

  async generateExport(args: ExportRequest, ctx: HookContext): Promise<ExportResult> {
    // Only the two exportTypes offered above. Belt and braces alongside the
    // keyed delegation in `adifForExport`: a hook answering for an exportType it never
    // offered makes the ADIF delegation recurse into itself.
    if (args.exportType !== `${TYPE}-cabrillo` && args.exportType !== `${TYPE}-adif`) {
      return { filename: "", mimeType: "", content: "" }
    }

    const operation = args.operation
    const opRef = refOfType(operation, TYPE)
    const mode = str(opRef?.mode)
    const ourCall = str(operation.stationCall)
    const ours = ourExchange(opRef)

    if (args.exportType === `${TYPE}-cabrillo`) {
      const content = qsonToCabrillo(args.qsos, {
        headers: [
          ["CONTEST", mode ? `NAQP-${mode}` : "NAQP"],
          ["CALLSIGN", ourCall],
          ["NAME", ours.name],
          ["LOCATION", ours.location],
          ["OPERATORS", str((operation.local as Record<string, JSONValue>)?.operatorCall)],
          ["GRID-LOCATOR", str(operation.grid)],
        ],
        qsoParts: (qso) => {
          const qsoRef = refOfType(qso, TYPE)
          return [
            ourCall || "-",
            ours.name || "-",
            ours.location || "-",
            str(((qso.their as Record<string, JSONValue>) ?? {}).call) || "-",
            firstName(qsoRef?.name) || "-",
            normalizeLocation(qsoRef?.location) || "-",
          ]
        },
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
      // extension's `adifFields` hook and no other's — app-polo's main
      // handler (see `ExportRequest.mainHandler`).
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
      hook: contestScorer(NAQPScorer, { scope: { refTypes: [TYPE] } }),
      key: TYPE,
    })
  },
})

// `VALID_LOCATIONS` is re-exported for the tests, which check the dataset
// itself rather than reaching through the scorer for it.
export { VALID_LOCATIONS }
