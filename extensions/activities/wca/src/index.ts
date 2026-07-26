// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// WCA (World Castles Awards) — the archetype for the plain reference awards.
// Everything but the data file comes from `referenceActivity`; what is left
// here is the program's own facts: what a reference looks like, where the list
// lives, and what activates one.
//
// WCA also answers for the ENGLISH and BELGIAN castle references
// (`ecaActivation`, `bcaActivation`), which are WCA references under their own
// national awards — app-polo's Info calls these `otherActivationTypes`. Those
// extensions decorate their own refs from their own lists; registering here too
// means a WCA reference typed while ECA is disabled still resolves.

import {
  activityExportHook,
  activityScorer,
  contestScorer,
  defineExtension,
  referenceActivity,
} from "@ham2k/halo-extension-sdk"
import type { DataFileDefinition, HookContext, PostResult, PostSelfSpotRequest, Ref, SpotEligibility } from "@ham2k/halo-extension-sdk"
import { locationToGrid6 } from "@ham2k/lib-geo-tools"

import { postSelfSpotToGMA } from "../../../shared/gmaSpots.ts"
import { tFor } from "./i18n.ts"

import manifest from "../manifest.json" with { type: "json" }

const ACTIVATION_TYPE = 'wcaActivation'
/// National castle awards whose references ARE WCA references.
const OTHER_ACTIVATION_TYPES = ['ecaActivation', 'bcaActivation']

const REFERENCE_REGEX = /^[A-Z0-9]+-[0-9]{5}$/i

const { refHandler, activityHook, adifFieldsHook } = referenceActivity({
  key: 'wca',
  label: 'WCA',
  activationType: ACTIVATION_TYPE,
  referenceRegex: REFERENCE_REGEX,
  icon: manifest.icon,
  color: manifest.accentColor,
  placeholder: 'ON-00558',
  tFor,
})

/// 50 contacts activate a castle, and a repeat contact counts again on a new
/// band, mode or day. The count accrues across the whole operation rather than
/// per day — app-polo says so by registering the OPERATION accumulator.
const WCA_SCORING = {
  label: 'WCA',
  icon: manifest.icon,
  activationType: ACTIVATION_TYPE,
  qsosToActivate: 50,
  uniquePer: ['band', 'mode', 'day'] as const,
  activates: 'once' as const,
}

function refsOfType(container: Record<string, unknown>, type: string): Ref[] {
  return (((container.refs as Ref[] | undefined) ?? [])).filter((r) => r.type === type && r.ref)
}

const SpotsHook = {
  sourceName: 'GMA',

  async isSelfSpotEnabled({ operation }: { operation: Record<string, any> }, _ctx: HookContext): Promise<SpotEligibility> {
    return refsOfType(operation, ACTIVATION_TYPE).length > 0
      ? { enabled: true, icon: manifest.icon }
      : { enabled: false }
  },

  async postSelfSpot({ operation, freq, mode, comment }: PostSelfSpotRequest, _ctx: HookContext): Promise<PostResult> {
    const refs = refsOfType(operation, ACTIVATION_TYPE)
    if (refs.length === 0) return { ok: false, message: 'No WCA activation on this operation' }
    return postSelfSpotToGMA({ operation, refs, freq, mode, comment })
  },
}

/// Maintained by ON4VT Danny as a spreadsheet and re-published as CSV, which is
/// why the URL is ham2k's rather than the award's — see app-polo's WCADataFile.
const wcaDataFile: DataFileDefinition = {
  key: 'wca-all-castles',
  name: (_args: Record<string, never>, ctx: HookContext) => tFor(ctx)('dataFileName'),
  description: (_args: Record<string, never>, ctx: HookContext) => tFor(ctx)('dataFileDescription'),
  url: 'https://polo.ham2k.com/data/activities/wca/all-castles.csv',
  maxAgeInDays: 100,
  fetchType: 'csv',
  category: 'wca',
  csvOptions: { hasHeaders: true, delimiter: ',' },
  csvToLookupEntry: (row: Record<string, string> | string[]) => {
    const r = row as Record<string, string>
    // The pattern check is app-polo's own here, and the 183 rows it drops out
    // of 70,000 are genuinely malformed (`LZ=00525`, four-digit `SV-0001`).
    // Trimmed first so a stray space isn't mistaken for one of them.
    const ref = (r.REF ?? '').trim().toUpperCase()
    if (!ref || !REFERENCE_REGEX.test(ref)) return null

    // A single `COORDINATES` column holding "lat,lon" — not two columns.
    let lat: number | undefined
    let lon: number | undefined
    if (r.COORDINATES?.includes(',')) {
      const [latStr, lonStr] = r.COORDINATES.split(',')
      lat = Number.parseFloat(latStr)
      lon = Number.parseFloat(lonStr)
      if (Number.isNaN(lat) || Number.isNaN(lon)) {
        lat = undefined
        lon = undefined
      }
    }
    const name = r['CLEAN NAME']

    return {
      subCategory: r.PREFIX,
      key: ref,
      name,
      lat,
      lon,
      flags: 1,
      data: {
        ref,
        prefix: r.PREFIX,
        name,
        location: r['CLEAN LOCATION'],
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
    registerHook(`ref:${ACTIVATION_TYPE}`, { hook: refHandler, key: 'wca' })
    for (const type of OTHER_ACTIVATION_TYPES) {
      registerHook(`ref:${type}`, { hook: refHandler, key: 'wca' })
    }
    registerHook('activity', { hook: activityHook, key: 'wca' })
    registerHook('adifFields', { hook: adifFieldsHook, key: 'wca' })
    registerHook('spots', { hook: SpotsHook, key: 'wca' })
    registerHook('dataFile', { hook: wcaDataFile, key: 'wca-all-castles' })
    registerHook('scoring', {
      hook: contestScorer(activityScorer(WCA_SCORING), { scope: { refTypes: [ACTIVATION_TYPE] } }),
      key: 'wca',
    })
    registerHook('export', {
      hook: activityExportHook({
        key: 'wca',
        label: 'WCA',
        activationType: ACTIVATION_TYPE,
        icon: manifest.icon,
      }),
      key: 'wca',
    })
  },
})
