// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// GMA (Global Mountain Activity) — an award with a HUNTING side:
// a QSO carries the summits the other station was on, and the logging panel
// gains a per-QSO control for them.
//
// It is also the home of the cqgma.org spot endpoint that half a dozen other
// awards post through, which lives in `extensions/shared/gmaSpots.ts` because
// none of them owns it.
//
// app-polo gives GMA no scoring at all — no threshold, no duplicate rules — so
// this registers no `scoring` hook. Summits are recorded and exported, not
// counted.

import {
  activityExportHook,
  defineExtension,
  huntingExportHook,
  referenceActivity,
} from "@ham2k/extension-sdk"
import type {
  DataFileDefinition,
  HookContext,
  PostOtherSpotRequest,
  PostResult,
  PostSelfSpotRequest,
  Ref,
  SpotEligibility,
} from "@ham2k/extension-sdk"
import { locationToGrid6 } from "@ham2k/lib-geo-tools"

import { postOtherSpotToGMA, postSelfSpotToGMA } from "../../../shared/gmaSpots.ts"
import { tFor } from "./i18n.ts"

import manifest from "../manifest.json" with { type: "json" }

const HUNTING_TYPE = 'gma'
const ACTIVATION_TYPE = 'gmaActivation'

/// `XX/YY-123` for the ordinary references, plus the `UNM-nnn` / `UNM-SHnnn`
/// series, which follow no prefix rule at all.
const REFERENCE_REGEX = /^(?:[A-Z0-9]+\/[A-Z]{2,}-[0-9]{3,}|UNM-(?:SH)?[0-9]{3})$/i

const { refHandler, activityHook, adifFieldsHook, adifImportHook } = referenceActivity({
  key: 'gma',
  label: 'GMA',
  activationType: ACTIVATION_TYPE,
  huntingType: HUNTING_TYPE,
  referenceRegex: REFERENCE_REGEX,
  icon: manifest.icon,
  color: manifest.accentColor,
  placeholder: 'DL/AL-001',
  tFor,
  // The GMA site carries the reference lists for the castle, lighthouse and
  // mill programs as well as its own summits — one page per reference,
  // whatever program issued it.
  linkUrl: (reference: string) => `https://www.gma.rocks/zinfo.php?ref=${encodeURIComponent(reference)}`,
  // app-polo writes a single SIG_INFO for GMA rather than one record per
  // summit — it registers no `adifFieldCombinationsForOneQSO` at all.
  splitRecordsPerHuntedRef: false,
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
    if (refs.length === 0) return { ok: false, message: 'No GMA activation on this operation' }
    return postSelfSpotToGMA({ operation, refs, freq, mode, comment })
  },

  async postOtherSpot({ qso, comment, spotterCall }: PostOtherSpotRequest, _ctx: HookContext): Promise<PostResult> {
    const refs = refsOfType(qso, HUNTING_TYPE)
    if (refs.length === 0) return { ok: false, message: 'No GMA reference on this QSO' }
    return postOtherSpotToGMA({ qso, refs, comment, spotterCall })
  },
}

const gmaDataFile: DataFileDefinition = {
  key: 'gma-all-summits',
  name: (_args: Record<string, never>, ctx: HookContext) => tFor(ctx)('dataFileName'),
  description: (_args: Record<string, never>, ctx: HookContext) => tFor(ctx)('dataFileDescription'),
  url: 'https://www.cqgma.org/download/summits.csv',
  maxAgeInDays: 30,
  fetchType: 'csv',
  category: 'gma',
  csvOptions: { hasHeaders: true, delimiter: ',' },
  csvToLookupEntry: (row: Record<string, string> | string[]) => {
    const r = row as Record<string, string>
    // The list keeps retired summits and marks them; app-polo skips them
    // outright rather than storing them as inactive.
    if ((r.deleted ?? '').trim() !== '0') return null

    const ref = (r.Reference ?? '').trim().toUpperCase()
    if (!ref) return null

    const parsedLat = Number.parseFloat(r.Latitude)
    const parsedLon = Number.parseFloat(r.Longitude)
    const lat = Number.isNaN(parsedLat) ? undefined : parsedLat
    const lon = Number.isNaN(parsedLon) ? undefined : parsedLon

    // The published locator is upper-cased throughout; the last pair is
    // conventionally lower-case, and the rest of HaLo compares grids as
    // strings. Fall back to deriving one when the list has none.
    const published = (r['Maidenhead Locator'] ?? '').trim()
    const grid = published
      ? published.replace(/[A-Z]{2}$/, (x) => x.toLowerCase())
      : lat != null && lon != null
        ? locationToGrid6(lat, lon)
        : undefined

    const altitude = Number.parseInt(r['Height (m)'], 10)

    return {
      // The association prefix (`DL` of `DL/AL-001`), which is how an operator
      // narrows a search to their own country.
      subCategory: ref.split('/')[0],
      key: ref,
      name: r.Name,
      lat,
      lon,
      flags: 1,
      data: {
        ref,
        name: r.Name,
        grid,
        altitude: Number.isNaN(altitude) ? undefined : altitude,
        lat,
        lon,
      },
    }
  },
}

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook(`ref:${HUNTING_TYPE}`, { hook: refHandler, key: 'gma' })
    registerHook(`ref:${ACTIVATION_TYPE}`, { hook: refHandler, key: 'gma' })
    registerHook('activity', { hook: activityHook, key: 'gma' })
    registerHook('adifFields', { hook: adifFieldsHook, key: 'gma' })
    registerHook('adifImport', { hook: adifImportHook, key: 'gma' })
    registerHook('spots', { hook: SpotsHook, key: 'gma' })
    registerHook('dataFile', { hook: gmaDataFile, key: 'gma-all-summits' })
    // No `scoring`: app-polo's GMA counts nothing.
    registerHook('export', {
      hook: activityExportHook({ key: 'gma', label: 'GMA', activationType: ACTIVATION_TYPE, icon: manifest.icon }),
      key: 'gma',
    })
    // The chaser side: every reference hunted, across the whole log — a
    // different key so it doesn't collide with the activator registration
    // above.
    registerHook('export', {
      hook: huntingExportHook({ key: 'gma', label: 'GMA', huntingType: HUNTING_TYPE, activationType: ACTIVATION_TYPE, icon: manifest.icon, color: manifest.accentColor }),
      key: 'gma-hunter',
    })
  },
})
