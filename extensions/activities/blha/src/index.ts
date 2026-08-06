// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// BLHA (Belgian Lighthouses and Lightships). Same GeoJSON-from-Google-Drive
// source as `bca`, published by the same group.
//
// Note the reference format: `BEL 001`, with a SPACE, unlike every other award
// here.

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

const ACTIVATION_TYPE = 'blhaActivation'
const REFERENCE_REGEX = /^BEL [0-9]{3}$/i

const { refHandler, activityHook, adifFieldsHook, adifImportHook } = referenceActivity({
  key: 'blha',
  label: 'BLHA',
  activationType: ACTIVATION_TYPE,
  referenceRegex: REFERENCE_REGEX,
  icon: manifest.icon,
  color: manifest.accentColor,
  placeholder: 'BEL 001',
  tFor,
  // One operation can activate several lighthouses at once.
  allowsMultiple: true,
})

/// app-polo's BLHA Info declares no scoring block at all, so the shared
/// scorer's defaults apply: ten contacts, and any repeat contact with the same
/// station is a duplicate — no band, mode or day relaxation.
const BLHA_SCORING = {
  label: 'BLHA',
  icon: manifest.icon,
  activationType: ACTIVATION_TYPE,
  qsosToActivate: 10,
  uniquePer: [] as const,
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
    if (refs.length === 0) return { ok: false, message: 'No BLHA activation on this operation' }
    return postSelfSpotToGMA({ operation, refs, freq, mode, comment })
  },
}

/// GeoJSON: each feature's coordinates are [lon, lat], NOT [lat, lon].
const blhaDataFile: DataFileDefinition = {
  key: 'blha-all-lighthouses',
  name: (_args: Record<string, never>, ctx: HookContext) => tFor(ctx)('dataFileName'),
  description: (_args: Record<string, never>, ctx: HookContext) => tFor(ctx)('dataFileDescription'),
  url: 'https://drive.google.com/uc?id=1I0u81-8Ha_pQIR1Q4iPRDd6yilH_t4hq&export=download',
  maxAgeInDays: 100,
  fetchType: 'json',
  category: 'blha',
  jsonOptions: { rootPath: 'features' },
  jsonToLookupEntry: (entry: Record<string, any>) => {
    // Trimmed, but NOT filtered by the reference pattern — see bca for why.
    // Note the pattern includes a space (`BEL 001`), so trimming the ENDS is
    // safe but any normalisation of inner whitespace would not be.
    const ref = String(entry?.properties?.reference ?? '').trim().toUpperCase()
    if (!ref) return null
    const [lon, lat] = (entry?.geometry?.coordinates ?? []) as number[]
    const name = String(entry?.properties?.name ?? '').trim()

    return {
      subCategory: 'ON',
      key: ref,
      name,
      lat,
      lon,
      flags: 1,
      data: {
        ref,
        name,
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
    registerHook(`ref:${ACTIVATION_TYPE}`, { hook: refHandler, key: 'blha' })
    registerHook('activity', { hook: activityHook, key: 'blha' })
    registerHook('adifFields', { hook: adifFieldsHook, key: 'blha' })
    registerHook('adifImport', { hook: adifImportHook, key: 'blha' })
    registerHook('spots', { hook: SpotsHook, key: 'blha' })
    registerHook('dataFile', { hook: blhaDataFile, key: 'blha-all-lighthouses' })
    registerHook('scoring', {
      hook: contestScorer(activityScorer(BLHA_SCORING), { scope: { refTypes: [ACTIVATION_TYPE] } }),
      key: 'blha',
    })
    registerHook('export', {
      hook: activityExportHook({ key: 'blha', label: 'BLHA', activationType: ACTIVATION_TYPE, icon: manifest.icon }),
      key: 'blha',
    })
  },
})
