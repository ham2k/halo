// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// ZLOTA (ZL on the Air) — one award covering six kinds of New Zealand place:
// lighthouses, huts, islands, lakes, parks and volcanoes. The kind is encoded
// in the third character of the reference, and it decides how many contacts
// activate it: a hut takes one, a lighthouse four.
//
// SPOTTING IS NOT PORTED. app-polo posts through an account (a ZLOTA user id
// and API key) that HaLo has no equivalent for yet — it would need an `account`
// hook like SOTA's. The read-only spot FEED needs no credentials and is here.

import {
  activityExportHook,
  activityScorer,
  contestScorer,
  defineExtension,
  host,
  huntingExportHook,
  referenceActivity,
} from "@ham2k/extension-sdk"
import type { DataFileDefinition, HookContext, Spot } from "@ham2k/extension-sdk"
import { bandForFrequency } from "@ham2k/lib-operation-data"

import { tFor } from "./i18n.ts"

import manifest from "../manifest.json" with { type: "json" }

const HUNTING_TYPE = 'zlota'
const ACTIVATION_TYPE = 'zlotaActivation'

const REFERENCE_REGEX = /^ZL(?:B\/[0-9]{3}|[HI]\/[A-Z]{2}-[0-9]{3}|L\/[0-9]{4}|P\/[A-Z]{2}-[0-9]{4}|V\/[A-Z]{2,3}-[0-9]{3})$/i

/// The third character of a reference names the kind of place.
const ASSET_TYPE_BY_CODE: Record<string, string> = {
  B: 'lighthouse',
  H: 'hut',
  I: 'island',
  L: 'lake',
  P: 'park',
  V: 'volcano',
}

/// How many contacts each kind takes to activate.
const CONTACTS_TO_ACTIVATE: Record<string, number> = {
  lighthouse: 4,
  hut: 1,
  island: 1,
  lake: 2,
  park: 4,
  volcano: 4,
}

function assetTypeOf(ref: string): string | undefined {
  return ASSET_TYPE_BY_CODE[ref[2]?.toUpperCase()]
}

/// The bar is the kind of place, and activating several at once takes the
/// hardest of them — a hut alongside a lighthouse is not done at one contact.
function zlotaThreshold(refs: string[]): number {
  return Math.max(...refs.map((ref) => CONTACTS_TO_ACTIVATE[assetTypeOf(ref) ?? ''] ?? 1))
}

/// ZLOTA's only duplicate axis is the reference itself: working the same
/// station again counts as long as they are somewhere new. Band, mode and day
/// are irrelevant to it, unlike every other award in this batch.
const ZLOTA_SCORING = {
  label: 'ZLOTA',
  icon: manifest.icon,
  activationType: ACTIVATION_TYPE,
  huntingType: HUNTING_TYPE,
  allowsMultipleReferences: true,
  qsosToActivate: zlotaThreshold,
  uniquePer: ['ref'] as const,
  activates: 'once' as const,
  // No refNoun: ZLOTA covers islands, huts and more under one umbrella with
  // no single noun, so the generic "reference(s)" wording stays. p2pLabel
  // doesn't have that problem — one abbreviation covers every contact
  // between two ZLOTA activators regardless of site kind.
  p2pLabel: (ctx: HookContext) => tFor(ctx)('z2z'),
}

const { refHandler, activityHook, adifFieldsHook, adifImportHook } = referenceActivity({
  key: 'zlota',
  label: 'ZLOTA',
  activationType: ACTIVATION_TYPE,
  huntingType: HUNTING_TYPE,
  referenceRegex: REFERENCE_REGEX,
  icon: manifest.icon,
  color: manifest.accentColor,
  placeholder: 'ZLH/AA-001',
  tFor,
  // ontheair.nz names an asset page after its code with the slash written as
  // an underscore — `/assets/ZLB_001`, not `ZLB/001`, which is a different route.
  linkUrl: (reference: string) => `https://ontheair.nz/assets/${encodeURIComponent(reference.replace('/', '_'))}`,
  // app-polo names every hunted reference in a single record's SIG_INFO.
  splitRecordsPerHuntedRef: false,
  // Derived from the scorer's own rule, not a separate flag — the UI control
  // and the scorer can't disagree about whether this award allows n-fers.
  allowsMultiple: ZLOTA_SCORING.allowsMultipleReferences,
})

interface ZLOTAApiSpot {
  /// Shared by every row of a multi-reference spot.
  id: number
  activator: string
  reference: string
  frequency: string
  mode?: string
  referenced_time: string
  name?: string
}

const SpotsHook = {
  sourceName: 'ZLOTA',

  async fetchSpots(_args: Record<string, never>, ctx: HookContext): Promise<Spot[]> {
    if (!ctx.online) return []

    const response = await host.fetch('https://ontheair.nz/api/spots.js?zlota_only=true', {
      headers: { Accept: 'application/json' },
    })
    if (response.status !== 200) throw new Error(`ZLOTA API returned HTTP ${response.status}`)
    const apiSpots = JSON.parse(response.body) as ZLOTAApiSpot[]

    // The feed arrives oldest-first and emits ONE ROW PER REFERENCE, so a
    // station at two places is two rows sharing an `id`. Reversed for
    // newest-first, then folded back into one spot each.
    const byId = new Map<number, Spot>()
    for (const spot of [...apiSpots].reverse()) {
      const ref = { ref: spot.reference, type: HUNTING_TYPE }
      const existing = byId.get(spot.id)
      if (existing) {
        existing.refs!.push(ref)
        existing.spot!.label = existing.refs!.map((r) => r.ref).join(' ')
        continue
      }

      const freq = Number.parseFloat(spot.frequency)
      byId.set(spot.id, {
        their: { call: (spot.activator ?? '').toUpperCase().trim() },
        freq: Number.isNaN(freq) ? undefined : freq,
        band: Number.isNaN(freq) ? undefined : bandForFrequency(freq),
        mode: spot.mode?.toUpperCase(),
        refs: [ref],
        spot: {
          timeInMillis: Date.parse(spot.referenced_time),
          source: 'zlota',
          label: `${spot.reference}${spot.name ? `: ${spot.name}` : ''}`,
        },
      })
    }
    return [...byId.values()]
  },
}

const zlotaDataFile: DataFileDefinition = {
  key: 'zlota-all-references',
  name: (_args: Record<string, never>, ctx: HookContext) => tFor(ctx)('dataFileName'),
  description: (_args: Record<string, never>, ctx: HookContext) => tFor(ctx)('dataFileDescription'),
  url: 'https://ontheair.nz/assets/assets.json',
  maxAgeInDays: 30,
  fetchType: 'json',
  category: 'zlota',
  // A bare top-level array, so no root path.
  jsonToLookupEntry: (entry: Record<string, any>) => {
    const ref = String(entry?.code ?? '').trim().toUpperCase()
    if (!ref) return null

    // `x` is longitude and `y` latitude — the list is drawn from a map layer.
    const lat = typeof entry?.y === 'number' ? entry.y : undefined
    const lon = typeof entry?.x === 'number' ? entry.x : undefined

    return {
      // The kind of place, which is both how an operator narrows a search and
      // what sets the activation bar.
      subCategory: entry?.asset_type,
      key: ref,
      name: entry?.name,
      lat,
      lon,
      flags: 1,
      data: {
        ref,
        name: entry?.name,
        assetType: entry?.asset_type,
        location: entry?.asset_type,
        lat,
        lon,
      },
    }
  },
}

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook(`ref:${HUNTING_TYPE}`, { hook: refHandler, key: 'zlota' })
    registerHook(`ref:${ACTIVATION_TYPE}`, { hook: refHandler, key: 'zlota' })
    registerHook('activity', { hook: activityHook, key: 'zlota' })
    registerHook('adifFields', { hook: adifFieldsHook, key: 'zlota' })
    registerHook('adifImport', { hook: adifImportHook, key: 'zlota' })
    // Feed only — posting needs an account HaLo doesn't have yet.
    registerHook('spots', { hook: SpotsHook, key: 'zlota' })
    registerHook('dataFile', { hook: zlotaDataFile, key: 'zlota-all-references' })
    registerHook('scoring', {
      hook: contestScorer(activityScorer(ZLOTA_SCORING), {
        scope: { refTypes: [ACTIVATION_TYPE, HUNTING_TYPE], huntingRefTypes: [HUNTING_TYPE] },
      }),
      key: 'zlota',
    })
    registerHook('export', {
      hook: activityExportHook({ key: 'zlota', label: 'ZLOTA', activationType: ACTIVATION_TYPE, icon: manifest.icon }),
      key: 'zlota',
    })
    // The chaser side: every reference hunted, across the whole log — a
    // different key so it doesn't collide with the activator registration
    // above.
    registerHook('export', {
      hook: huntingExportHook({ key: 'zlota', label: 'ZLOTA', huntingType: HUNTING_TYPE, activationType: ACTIVATION_TYPE, icon: manifest.icon, color: manifest.accentColor }),
      key: 'zlota-hunter',
    })
  },
})
