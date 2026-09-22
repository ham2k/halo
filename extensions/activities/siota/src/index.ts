// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// SiOTA (Silos on the Air) — Australian grain silos. The only award in this
// batch with no spotting at all: app-polo registers neither a feed nor a post,
// so neither does this.
//
// Its duplicate rules are the source of the `freshRefRescuesActivation` flag.
// app-polo's comment on the branch says it plainly: a silo the station hasn't
// given before "Doesn't count towards activation, but towards Silo 2 Silo
// award."

import { activityExportHook, activityScorer, contestScorer, defineExtension, huntingExportHook, referenceActivity } from "@ham2k/extension-sdk"
import type { DataFileDefinition, HookContext, RefTransform } from "@ham2k/extension-sdk"

import { tFor } from "./i18n.ts"

import manifest from "../manifest.json" with { type: "json" }

const HUNTING_TYPE = "siota"
const ACTIVATION_TYPE = "siotaActivation"
const REFERENCE_REGEX = /^VK-[A-Z]{3}[0-9]+$/i

/// Live-typing reformatting, app-polo's SiOTAInput chain: "VKABC" gets its
/// dash ("VK-ABC"), and a silo typed without the country ("ABC1") gets both
/// ("VK-ABC1") — once a digit follows, so the three letters of a silo code
/// being typed are not mistaken for one before it is complete.
export const TRANSFORMS: RefTransform[] = [
  { pattern: "(^|,\\s*)VK([A-Z]+)", replacement: "${1}VK-${2}", flags: "gi" },
  { pattern: "(^|,\\s*)(?!VK-)([A-Z]{3}\\d)", replacement: "${1}VK-${2}", flags: "gi" },
  { pattern: "[^A-Z0-9\\-, ]", replacement: "", flags: "gi" },
]

/// A repeat contact is a duplicate on the same band, mode AND day. A silo the
/// station hasn't given before is called out and earns the Silo-to-Silo
/// credit, but does not advance the activation.
const SIOTA_SCORING = {
  label: "SiOTA",
  icon: manifest.icon,
  activationType: ACTIVATION_TYPE,
  huntingType: HUNTING_TYPE,
  allowsMultipleReferences: true,
  qsosToActivate: 10,
  uniquePer: ["band", "mode", "day", "ref"] as const,
  activates: "once" as const,
  freshRefRescuesActivation: false,
  refNoun: (ctx: HookContext) => tFor(ctx)("silo"),
  refNounPlural: (ctx: HookContext) => tFor(ctx)("silosPlural"),
  p2pLabel: (ctx: HookContext) => tFor(ctx)("s2s"),
}

const { refHandler, activityHook, adifFieldsHook, adifImportHook } = referenceActivity({
  key: "siota",
  label: "SiOTA",
  activationType: ACTIVATION_TYPE,
  huntingType: HUNTING_TYPE,
  referenceRegex: REFERENCE_REGEX,
  icon: manifest.icon,
  color: manifest.accentColor,
  placeholder: "VK-ABC123",
  transforms: TRANSFORMS,
  tFor,
  linkUrl: (reference: string) => `https://www.silosontheair.com/silo/${encodeURIComponent(reference)}`,
  // app-polo names every hunted silo in a single record's SIG_INFO.
  splitRecordsPerHuntedRef: false,
  // The ADIF program name is upper-case even though the award styles itself
  // SiOTA.
  adifProgram: "SIOTA",
  // Derived from the scorer's own rule, not a separate flag — the UI control
  // and the scorer can't disagree about whether this award allows n-fers.
  allowsMultiple: SIOTA_SCORING.allowsMultipleReferences,
})

const siotaDataFile: DataFileDefinition = {
  key: "siota-all-silos",
  name: (_args: Record<string, never>, ctx: HookContext) => tFor(ctx)("dataFileName"),
  description: (_args: Record<string, never>, ctx: HookContext) => tFor(ctx)("dataFileDescription"),
  url: "https://www.silosontheair.com/data/silos.csv",
  maxAgeInDays: 30,
  fetchType: "csv",
  category: "siota",
  csvOptions: { hasHeaders: true, delimiter: "," },
  csvToLookupEntry: (row: Record<string, string> | string[]) => {
    const r = row as Record<string, string>
    const ref = (r.SILO_CODE ?? "").trim().toUpperCase()
    if (!ref) return null

    const parsedLat = Number.parseFloat(r.LAT)
    const parsedLon = Number.parseFloat(r.LNG)
    const lat = Number.isNaN(parsedLat) ? undefined : parsedLat
    const lon = Number.isNaN(parsedLon) ? undefined : parsedLon

    return {
      // The Australian state, which is how a VK operator narrows a search.
      subCategory: r.STATE,
      key: ref,
      name: r.NAME,
      lat,
      lon,
      flags: 1,
      data: {
        ref,
        name: r.NAME,
        location: r.LOCALITY,
        state: r.STATE,
        // The list publishes its own locator.
        grid: r.LOCATOR,
        lat,
        lon,
      },
    }
  },
}

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook(`ref:${HUNTING_TYPE}`, { hook: refHandler, key: "siota" })
    registerHook(`ref:${ACTIVATION_TYPE}`, { hook: refHandler, key: "siota" })
    registerHook("activity", { hook: activityHook, key: "siota" })
    registerHook("adifFields", { hook: adifFieldsHook, key: "siota" })
    registerHook("adifImport", { hook: adifImportHook, key: "siota" })
    registerHook("dataFile", { hook: siotaDataFile, key: "siota-all-silos" })
    // No `spots`: SiOTA has neither a feed nor a spot endpoint in app-polo.
    registerHook("scoring", {
      hook: contestScorer(activityScorer(SIOTA_SCORING), {
        scope: { refTypes: [ACTIVATION_TYPE, HUNTING_TYPE], huntingRefTypes: [HUNTING_TYPE] },
      }),
      key: "siota",
    })
    registerHook("export", {
      hook: activityExportHook({ key: "siota", label: "SiOTA", activationType: ACTIVATION_TYPE, icon: manifest.icon }),
      key: "siota",
    })
    // The chaser side: every reference hunted, across the whole log — a
    // different key so it doesn't collide with the activator registration
    // above.
    registerHook("export", {
      hook: huntingExportHook({
        key: "siota",
        label: "SiOTA",
        huntingType: HUNTING_TYPE,
        activationType: ACTIVATION_TYPE,
        icon: manifest.icon,
        color: manifest.accentColor,
      }),
      key: "siota-hunter",
    })
  },
})
