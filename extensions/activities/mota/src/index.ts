// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// MOTA (Mills on the Air). Shares GMA's list infrastructure and its spot
// endpoint — the mills catalogue is published by cqgma.org alongside the
// summits.
//
// Two things set MOTA apart from the other hunt-and-activate awards:
// it SPLITS a multi-mill contact into one record per mill (like POTA), and it
// has duplicate rules but NO activation threshold — app-polo registers a
// scorer with no accumulator at all, so mills are never counted toward
// anything.

import {
  activityExportHook,
  activityScorer,
  contestScorer,
  defineExtension,
  referenceActivity,
} from "@ham2k/halo-extension-sdk"
import type {
  DataFileDefinition,
  HookContext,
  PostOtherSpotRequest,
  PostResult,
  PostSelfSpotRequest,
  Ref,
  SpotEligibility,
} from "@ham2k/halo-extension-sdk"
import { locationToGrid6 } from "@ham2k/lib-geo-tools"

import { postOtherSpotToGMA, postSelfSpotToGMA } from "../../../shared/gmaSpots.ts"
import { tFor } from "./i18n.ts"

import manifest from "../manifest.json" with { type: "json" }

const HUNTING_TYPE = 'mota'
const ACTIVATION_TYPE = 'motaActivation'
const REFERENCE_REGEX = /^X[0-9]{5}$/i

/// Duplicate rules only. A repeat contact on the same band and day is a
/// duplicate; a new band or day makes it fresh again. A mill the station hasn't
/// given before is called out — but it does NOT rescue the contact, and nothing
/// is counted toward a threshold, because app-polo's MOTA has no accumulator.
const MOTA_SCORING = {
  label: 'MOTA',
  icon: manifest.icon,
  activationType: ACTIVATION_TYPE,
  huntingType: HUNTING_TYPE,
  allowsMultipleReferences: true,
  uniquePer: ['band', 'day', 'ref'] as const,
  activates: 'once' as const,
  tracksActivation: false,
  freshRefRescuesActivation: false,
}

const { refHandler, activityHook, adifFieldsHook, adifImportHook } = referenceActivity({
  key: 'mota',
  label: 'MOTA',
  activationType: ACTIVATION_TYPE,
  huntingType: HUNTING_TYPE,
  referenceRegex: REFERENCE_REGEX,
  icon: manifest.icon,
  color: manifest.accentColor,
  placeholder: 'X00001',
  tFor,
  // app-polo writes one record per hunted mill.
  splitRecordsPerHuntedRef: true,
  // Derived from the scorer's own rule, not a separate flag — the UI control
  // and the scorer can't disagree about whether this award allows n-fers.
  allowsMultiple: MOTA_SCORING.allowsMultipleReferences,
})

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

  async isOtherSpotEnabled({ qso }: { qso: Record<string, any> }, _ctx: HookContext): Promise<SpotEligibility> {
    return refsOfType(qso, HUNTING_TYPE).length > 0
      ? { enabled: true, icon: manifest.icon }
      : { enabled: false }
  },

  async postSelfSpot({ operation, freq, mode, comment }: PostSelfSpotRequest, _ctx: HookContext): Promise<PostResult> {
    const refs = refsOfType(operation, ACTIVATION_TYPE)
    if (refs.length === 0) return { ok: false, message: 'No MOTA activation on this operation' }
    return postSelfSpotToGMA({ operation, refs, freq, mode, comment })
  },

  async postOtherSpot({ qso, comment, spotterCall }: PostOtherSpotRequest, _ctx: HookContext): Promise<PostResult> {
    const refs = refsOfType(qso, HUNTING_TYPE)
    if (refs.length === 0) return { ok: false, message: 'No MOTA reference on this QSO' }
    return postOtherSpotToGMA({ qso, refs, comment, spotterCall })
  },
}

const motaDataFile: DataFileDefinition = {
  key: 'mota-all-mills',
  name: (_args: Record<string, never>, ctx: HookContext) => tFor(ctx)('dataFileName'),
  description: (_args: Record<string, never>, ctx: HookContext) => tFor(ctx)('dataFileDescription'),
  url: 'https://www.cqgma.org/download/mills.csv',
  maxAgeInDays: 30,
  fetchType: 'csv',
  category: 'mota',
  csvOptions: { hasHeaders: true, delimiter: ',' },
  csvToLookupEntry: (row: Record<string, string> | string[]) => {
    const r = row as Record<string, string>
    // Every entry carries a validity window; `21991231` is the list's way of
    // saying "no end date". Anything else has been retired.
    if ((r['valid to'] ?? '').trim() !== '21991231') return null

    const ref = (r.Reference ?? '').trim().toUpperCase()
    if (!ref) return null

    const parsedLat = Number.parseFloat(r.Latitude)
    const parsedLon = Number.parseFloat(r.Longitude)
    const lat = Number.isNaN(parsedLat) ? undefined : parsedLat
    const lon = Number.isNaN(parsedLon) ? undefined : parsedLon

    // Same locator convention as GMA — published upper-case, tail lower.
    const published = (r['Maidenhead Locator'] ?? '').trim()
    const grid = published
      ? published.replace(/[A-Z]{2}$/, (x) => x.toLowerCase())
      : lat != null && lon != null
        ? locationToGrid6(lat, lon)
        : undefined

    return {
      subCategory: r.District,
      key: ref,
      name: r.Name,
      lat,
      lon,
      flags: 1,
      data: {
        ref,
        name: r.Name,
        district: r.District,
        // Windmill, watermill and so on.
        type: r.Function || undefined,
        location: r.District,
        grid,
        lat,
        lon,
      },
    }
  },
}

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook(`ref:${HUNTING_TYPE}`, { hook: refHandler, key: 'mota' })
    registerHook(`ref:${ACTIVATION_TYPE}`, { hook: refHandler, key: 'mota' })
    registerHook('activity', { hook: activityHook, key: 'mota' })
    registerHook('adifFields', { hook: adifFieldsHook, key: 'mota' })
    registerHook('adifImport', { hook: adifImportHook, key: 'mota' })
    registerHook('spots', { hook: SpotsHook, key: 'mota' })
    registerHook('dataFile', { hook: motaDataFile, key: 'mota-all-mills' })
    registerHook('scoring', {
      hook: contestScorer(activityScorer(MOTA_SCORING), {
        scope: { refTypes: [ACTIVATION_TYPE, HUNTING_TYPE], huntingRefTypes: [HUNTING_TYPE] },
      }),
      key: 'mota',
    })
    registerHook('export', {
      hook: activityExportHook({ key: 'mota', label: 'MOTA', activationType: ACTIVATION_TYPE, icon: manifest.icon }),
      key: 'mota',
    })
  },
})
