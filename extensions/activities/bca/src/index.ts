// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// BCA (Belgium Castles & Fortresses). Belgian castles are also WCA references,
// so `wca` registers for `bcaActivation` too — either extension can resolve one
// and whichever is enabled answers.
//
// The list is published as GeoJSON from a Google Drive link (see app-polo's
// BCADataFile); every reference is Belgian, hence the constant subCategory.

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

const ACTIVATION_TYPE = 'bcaActivation'
const REFERENCE_REGEX = /^ON-[0-9]{5}$/i

const { refHandler, activityHook, adifFieldsHook } = referenceActivity({
  key: 'bca',
  label: 'BCA',
  activationType: ACTIVATION_TYPE,
  referenceRegex: REFERENCE_REGEX,
  icon: manifest.icon,
  color: manifest.accentColor,
  placeholder: 'ON-00558',
  tFor,
  // One operation can activate several castles at once.
  allowsMultiple: true,
})

/// 50 contacts activate a castle; a repeat counts again on a new band, mode or
/// day, and the count accrues across the whole operation.
const BCA_SCORING = {
  label: 'BCA',
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
    if (refs.length === 0) return { ok: false, message: 'No BCA activation on this operation' }
    return postSelfSpotToGMA({ operation, refs, freq, mode, comment })
  },
}

/// GeoJSON: each feature's coordinates are [lon, lat], NOT [lat, lon].
const bcaDataFile: DataFileDefinition = {
  key: 'bca-all-castles',
  name: (_args: Record<string, never>, ctx: HookContext) => tFor(ctx)('dataFileName'),
  description: (_args: Record<string, never>, ctx: HookContext) => tFor(ctx)('dataFileDescription'),
  url: 'https://drive.google.com/uc?id=1p4uCYG4R48FdD5gihbEcdSQuOa6ko216&export=download',
  maxAgeInDays: 100,
  fetchType: 'json',
  category: 'bca',
  jsonOptions: { rootPath: 'features' },
  jsonToLookupEntry: (entry: Record<string, any>) => {
    // Trimmed, but NOT filtered by the reference pattern: app-polo stores what
    // the list publishes, and a pattern check here turns a stray space or an
    // unforeseen prefix into a castle that silently does not exist.
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
    registerHook(`ref:${ACTIVATION_TYPE}`, { hook: refHandler, key: 'bca' })
    registerHook('activity', { hook: activityHook, key: 'bca' })
    registerHook('adifFields', { hook: adifFieldsHook, key: 'bca' })
    registerHook('spots', { hook: SpotsHook, key: 'bca' })
    registerHook('dataFile', { hook: bcaDataFile, key: 'bca-all-castles' })
    registerHook('scoring', {
      hook: contestScorer(activityScorer(BCA_SCORING), { scope: { refTypes: [ACTIVATION_TYPE] } }),
      key: 'bca',
    })
    registerHook('export', {
      hook: activityExportHook({ key: 'bca', label: 'BCA', activationType: ACTIVATION_TYPE, icon: manifest.icon }),
      key: 'bca',
    })
  },
})
