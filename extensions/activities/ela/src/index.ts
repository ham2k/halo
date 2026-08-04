// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// ELA (English Lighthouse Awards). Same publisher and same cached-JSON shape as
// `eca` — rows inside a positional envelope, `[meta, meta, {data: [...]}]`.
//
// Note the reference format: `ENG 001`, with a SPACE.

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

const ACTIVATION_TYPE = 'elaActivation'
const REFERENCE_REGEX = /^ENG [0-9]{3}$/i

const { refHandler, activityHook, adifFieldsHook } = referenceActivity({
  key: 'ela',
  label: 'ELA',
  activationType: ACTIVATION_TYPE,
  referenceRegex: REFERENCE_REGEX,
  icon: manifest.icon,
  color: manifest.accentColor,
  placeholder: 'ENG 001',
  tFor,
  // One operation can activate several lighthouses at once.
  allowsMultiple: true,
})

/// 50 contacts activate a lighthouse, with band+mode uniqueness and no day
/// axis — the same hand-written rules app-polo gives ECA.
const ELA_SCORING = {
  label: 'ELA',
  icon: manifest.icon,
  activationType: ACTIVATION_TYPE,
  qsosToActivate: 50,
  uniquePer: ['band', 'mode'] as const,
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
    if (refs.length === 0) return { ok: false, message: 'No ELA activation on this operation' }
    return postSelfSpotToGMA({ operation, refs, freq, mode, comment })
  },
}

const elaDataFile: DataFileDefinition = {
  key: 'ela-all-lighthouses',
  name: (_args: Record<string, never>, ctx: HookContext) => tFor(ctx)('dataFileName'),
  description: (_args: Record<string, never>, ctx: HookContext) => tFor(ctx)('dataFileDescription'),
  url: 'https://ham2k.com/data/cached/ela/ELA_References.json',
  maxAgeInDays: 100,
  fetchType: 'json',
  category: 'ela',
  jsonOptions: { rootPath: '2.data' },
  jsonToLookupEntry: (entry: Record<string, any>) => {
    // The pattern check is app-polo's own here. Trimmed first — ECA, published
    // by the same site, carries trailing spaces on some references.
    const ref = String(entry?.ELA ?? '').trim().toUpperCase()
    if (!ref || !REFERENCE_REGEX.test(ref)) return null

    const parsedLat = Number.parseFloat(entry?.LATITUDE)
    const parsedLon = Number.parseFloat(entry?.LONGITUDE)
    const lat = Number.isNaN(parsedLat) ? undefined : parsedLat
    const lon = Number.isNaN(parsedLon) ? undefined : parsedLon
    const name = String(entry?.NAME_OF_LIGHTHOUSE ?? '').trim()
    const location = entry?.LOCATION

    return {
      subCategory: location,
      key: ref,
      name,
      lat,
      lon,
      flags: 1,
      data: {
        ref,
        name,
        location,
        lat,
        lon,
        grid: lat != null && lon != null ? locationToGrid6(lat, lon) : undefined,
      },
    }
  },
}

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook(`ref:${ACTIVATION_TYPE}`, { hook: refHandler, key: 'ela' })
    registerHook('activity', { hook: activityHook, key: 'ela' })
    registerHook('adifFields', { hook: adifFieldsHook, key: 'ela' })
    registerHook('spots', { hook: SpotsHook, key: 'ela' })
    registerHook('dataFile', { hook: elaDataFile, key: 'ela-all-lighthouses' })
    registerHook('scoring', {
      hook: contestScorer(activityScorer(ELA_SCORING), { scope: { refTypes: [ACTIVATION_TYPE] } }),
      key: 'ela',
    })
    registerHook('export', {
      hook: activityExportHook({ key: 'ela', label: 'ELA', activationType: ACTIVATION_TYPE, icon: manifest.icon }),
      key: 'ela',
    })
  },
})
