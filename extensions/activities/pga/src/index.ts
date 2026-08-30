// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// PGA (Polish Gmina Award). The odd one out of the six: app-polo gives it no
// scoring at all and no spotting, so this registers neither — a gmina is
// recorded and exported, not counted toward a threshold.
//
// A gmina reference is a bare four characters (`AB12`), which is loose enough
// that it will match plenty of things that are not gminas; the list is what
// actually tells you.

import {
  activityExportHook,
  defineExtension,
  referenceActivity,
} from "@ham2k/extension-sdk"
import type { DataFileDefinition, HookContext } from "@ham2k/extension-sdk"

import { tFor } from "./i18n.ts"

import manifest from "../manifest.json" with { type: "json" }

const ACTIVATION_TYPE = 'pgaActivation'
const REFERENCE_REGEX = /^[A-Z]{2}[0-9]{2}$/i

const { refHandler, activityHook, adifFieldsHook, adifImportHook } = referenceActivity({
  key: 'pga',
  label: 'PGA',
  activationType: ACTIVATION_TYPE,
  referenceRegex: REFERENCE_REGEX,
  icon: manifest.icon,
  color: manifest.accentColor,
  placeholder: 'AB12',
  tFor,
})

/// The list carries a grid per gmina rather than only coordinates, so that is
/// what gets stored — gmina boundaries are areas and the published grid is the
/// award's own answer for them.
const pgaDataFile: DataFileDefinition = {
  key: 'pga-gminas',
  name: (_args: Record<string, never>, ctx: HookContext) => tFor(ctx)('dataFileName'),
  description: (_args: Record<string, never>, ctx: HookContext) => tFor(ctx)('dataFileDescription'),
  url: 'https://www.sq7acp.pl/files/PGA_LIST.csv',
  maxAgeInDays: 100,
  fetchType: 'csv',
  category: 'pga',
  csvOptions: { hasHeaders: true, delimiter: ',' },
  csvToLookupEntry: (row: Record<string, string> | string[]) => {
    const r = row as Record<string, string>
    // The list carries retired gminas too; app-polo skips them outright rather
    // than storing them as inactive. Trimmed because the failure mode if this
    // ever mismatches is EVERY gmina disappearing, not one.
    if ((r.ACTIVE ?? '').trim().toUpperCase() !== 'YES') return null

    // Trimmed, but NOT filtered by the reference pattern — see bca for why.
    const ref = (r['PGA REF.'] ?? '').trim().toUpperCase()
    if (!ref) return null

    const parsedLat = Number.parseFloat(r.LAT)
    const parsedLon = Number.parseFloat(r.LONG)
    const lat = Number.isNaN(parsedLat) ? undefined : parsedLat
    const lon = Number.isNaN(parsedLon) ? undefined : parsedLon
    const name = r.GMINA

    return {
      // The powiat (county), which is how Polish operators narrow a search.
      subCategory: r.POWIAT,
      key: ref,
      name,
      lat,
      lon,
      flags: 1,
      data: {
        ref,
        name,
        grid: r['GRID LOCATOR'],
        location: r.POWIAT,
        county: r.POWIAT,
        province: r.VOIVODESHIP,
        lat,
        lon,
      },
    }
  },
}

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook(`ref:${ACTIVATION_TYPE}`, { hook: refHandler, key: 'pga' })
    registerHook('activity', { hook: activityHook, key: 'pga' })
    registerHook('adifFields', { hook: adifFieldsHook, key: 'pga' })
    registerHook('adifImport', { hook: adifImportHook, key: 'pga' })
    registerHook('dataFile', { hook: pgaDataFile, key: 'pga-gminas' })
    // No `scoring` and no `spots`: app-polo's PGA has neither.
    registerHook('export', {
      hook: activityExportHook({ key: 'pga', label: 'PGA', activationType: ACTIVATION_TYPE, icon: manifest.icon }),
      key: 'pga',
    })
  },
})
