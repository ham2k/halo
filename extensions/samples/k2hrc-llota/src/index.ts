// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// SAMPLE — an award program: references, an offline list, and activation
// scoring.
//
// This is the shape of POTA, SOTA, WWFF and a dozen others, and almost none of
// it is written by hand. `referenceActivity()` builds the reference handler,
// the logging controls and the ADIF fields from one description; the manifest
// says which `ref:` types they answer for. What is left for you is what the
// program actually is: its reference format, where the list comes from, and
// what it takes to activate.
//
// Modelled on LLOTA (Lakes and Lagoons on the Air) and using its public list.
// The reference TYPES are namespaced to this sample (`k2hrcLlota`), so
// installing it cannot collide with the real LLOTA extension's records.
//
// What this sample leaves out: the spot feed and spot posting, which need an
// API key the program issues, and the export hooks that submit a log. See
// `docs/hooks.md` §`spots` and §`export`.

import { activityScorer, contestScorer, defineExtension, referenceActivity } from "@ham2k/extension-sdk"
import type { DataFileDefinition, HookContext } from "@ham2k/extension-sdk"
import { locationToGrid6 } from "@ham2k/lib-geo-tools"

import manifest from "../manifest.json" with { type: "json" }

/// The type a QSO carries for a lake the OTHER station was at, and the type an
/// operation carries while activating one. Two types, because they are two
/// different claims about the same reference.
const HUNTING_TYPE = "k2hrcLlota"
const ACTIVATION_TYPE = "k2hrcLlotaActivation"

const REFERENCE_REGEX = /^LL[A-Z0-9]+-(?:[0-9]{4,5}|TEST)$/i

/// Every user-visible string reaches the SDK through a translator, so that one
/// written against several locales needs no different wiring. A real extension
/// builds this with `createCachedTranslator` over its own JSON files — see
/// `activities/*/src/i18n.ts` in the app's repository. This is the smallest
/// thing with the right shape.
///
/// `invalidReference` and `unknownReference` are the vocabulary
/// `referenceActivity` looks up; `activationControl` and `huntingControl` name
/// the two logging controls it builds.
const STRINGS: Record<string, string> = {
  invalidReference: "Not a lake reference",
  unknownReference: "Unknown lake",
  activationControl: "Lake",
  huntingControl: "Lake",
}
const tFor = (_ctx: { locale?: string }) => (key: string) => STRINGS[key] ?? key

/// What it takes to activate: ten contacts in a UTC day.
///
/// `uniquePer` is the rule that decides when a repeat contact counts AGAIN —
/// here, a station already worked is worth another contact on a new band, a
/// new mode, a new day, or at a different lake. Get this wrong and the score
/// is wrong in a way no test of yours will notice, because it only shows up on
/// the second QSO with the same station.
const SCORING = {
  label: "LLOTA",
  icon: manifest.icon,
  activationType: ACTIVATION_TYPE,
  huntingType: HUNTING_TYPE,
  qsosToActivate: 10,
  // Several lakes activated at once, and one contact crediting several hunted
  // ones. Programs genuinely differ here; most of the simpler awards do not
  // allow it, and the default is false.
  allowsMultipleReferences: true,
  uniquePer: ["band", "mode", "day", "ref"] as const,
  activates: "daily" as const,
}

const { refHandler, activityHook, adifFieldsHook, adifImportHook } = referenceActivity({
  key: "k2hrc-llota",
  label: "LLOTA",
  activationType: ACTIVATION_TYPE,
  huntingType: HUNTING_TYPE,
  referenceRegex: REFERENCE_REGEX,
  icon: manifest.icon,
  color: manifest.accentColor,
  placeholder: "LLUS-0001",
  tFor,
  // Where the `lookups` rows below are written and read. It must match the
  // data file's `category`, or the handler will look up references nothing
  // ever stored.
  category: "k2hrc-llota",
  linkUrl: (reference: string) => `https://llota.app/list/ref/${encodeURIComponent(reference)}`,
  // One ADIF record per hunted lake rather than one naming them all. The
  // programs disagree, and it decides how many contacts the award sees.
  splitRecordsPerHuntedRef: true,
  adifRefField: "LLOTA",
  // Read off the scoring rule rather than restated, so the control and the
  // scorer cannot disagree about whether this award allows n-fers.
  allowsMultiple: SCORING.allowsMultipleReferences,
})

/// The reference list, downloaded and kept offline.
///
/// This is what makes a reference resolve to a lake's name in the field, with
/// no signal and no per-reference API. The host does the fetching, the
/// scheduling and the storage; the extension's whole job is turning one
/// entry of somebody else's JSON into one row.
const referenceList: DataFileDefinition = {
  key: "k2hrc-llota-references",
  name: (_args: Record<string, never>, _ctx: HookContext) => "LLOTA Lakes",
  description: (_args: Record<string, never>, _ctx: HookContext) => "Every lake reference, for offline lookup",
  url: "https://llota.app/api/public/references?version=lite",
  maxAgeInDays: 30,
  fetchType: "json",
  category: "k2hrc-llota",

  jsonToLookupEntry: (entry: Record<string, any>) => {
    const ref = String(entry?.reference_code ?? "")
      .trim()
      .toUpperCase()
    // Returning null drops the entry. A list of this size will contain a few
    // rows that are not references, and throwing would abandon the rest.
    if (!ref) return null

    const lat = typeof entry?.latitude === "number" ? entry.latitude : undefined
    const lon = typeof entry?.longitude === "number" ? entry.longitude : undefined

    return {
      // The country part of the code (`LLUS` of `LLUS-0001`), which is how an
      // operator narrows a search to their own country.
      subCategory: ref.split("-")[0],
      key: ref,
      name: entry?.name,
      lat,
      lon,
      flags: 1,
      data: {
        ref,
        name: entry?.name,
        location: ref.split("-")[0],
        // The grid is DERIVED from the coordinate, never stored instead of it:
        // where both are present the pair outranks the grid, and a grid with
        // no coordinate behind it would quietly lose precision the list had.
        grid: lat != null && lon != null ? locationToGrid6(lat, lon) : undefined,
        lat,
        lon,
      },
    }
  },
}

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    // One handler, both types: an activation and a hunted reference are the
    // same lake, validated and decorated the same way.
    registerHook(`ref:${HUNTING_TYPE}`, { hook: refHandler, key: manifest.key })
    registerHook(`ref:${ACTIVATION_TYPE}`, { hook: refHandler, key: manifest.key })
    registerHook("activity", { hook: activityHook, key: manifest.key })
    registerHook("adifFields", { hook: adifFieldsHook, key: manifest.key })
    registerHook("adifImport", { hook: adifImportHook, key: manifest.key })
    registerHook("dataFile", { hook: referenceList, key: "k2hrc-llota-references" })
    // `contestScorer` wraps the activity rules in the scoring hook's own
    // interface, and `scope` is what keeps this scorer out of operations that
    // have nothing to do with the program.
    registerHook("scoring", {
      hook: contestScorer(activityScorer(SCORING), {
        scope: { refTypes: [ACTIVATION_TYPE, HUNTING_TYPE], huntingRefTypes: [HUNTING_TYPE] },
      }),
      key: manifest.key,
    })
  },
})
