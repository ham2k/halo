// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// ECA (English Castles Awards). English castles are also WCA references, so
// `wca` registers for `ecaActivation` too.
//
// The award's own site publishes an HTML-ish endpoint, so ham2k re-publishes a
// cached JSON — whose rows sit inside a positional envelope, `[meta, meta,
// {data: [...]}]`, hence the `2.data` root path.

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

const ACTIVATION_TYPE = 'ecaActivation'
const REFERENCE_REGEX = /^G-[0-9]{5}$/i

const { refHandler, activityHook, adifFieldsHook } = referenceActivity({
  key: 'eca',
  label: 'ECA',
  activationType: ACTIVATION_TYPE,
  referenceRegex: REFERENCE_REGEX,
  icon: manifest.icon,
  color: manifest.accentColor,
  placeholder: 'G-00001',
  tFor,
  // One operation can activate several castles at once.
  allowsMultiple: true,
})

/// 50 contacts activate a castle. app-polo hand-writes this scorer rather than
/// using its shared one, and the rules it writes are band+mode uniqueness with
/// no day axis — a repeat contact on the same band and mode is a duplicate
/// however many days later.
const ECA_SCORING = {
  label: 'ECA',
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
    if (refs.length === 0) return { ok: false, message: 'No ECA activation on this operation' }
    return postSelfSpotToGMA({ operation, refs, freq, mode, comment })
  },
}

/// The reference lives under `WCA`, not `ECA` — English castles are catalogued
/// by their WCA code.
const ecaDataFile: DataFileDefinition = {
  key: 'eca-all-castles',
  name: (_args: Record<string, never>, ctx: HookContext) => tFor(ctx)('dataFileName'),
  description: (_args: Record<string, never>, ctx: HookContext) => tFor(ctx)('dataFileDescription'),
  url: 'https://ham2k.com/data/cached/eca/ECA_References.json',
  maxAgeInDays: 100,
  fetchType: 'json',
  category: 'eca',
  jsonOptions: { rootPath: '2.data' },
  jsonToLookupEntry: (entry: Record<string, any>) => {
    // TRIM before anything else: three of the published references carry a
    // trailing space ('G-01516 '), and testing them unturned drops real
    // castles. Nothing else here filters by the reference pattern — app-polo
    // doesn't either, and a reference the list publishes is a reference
    // somebody can activate, whatever we think of its shape.
    const ref = String(entry?.WCA ?? '').trim().toUpperCase()
    if (!ref) return null

    const parsedLat = Number.parseFloat(entry?.LATITUDE)
    const parsedLon = Number.parseFloat(entry?.LONGITUDE)
    const lat = Number.isNaN(parsedLat) ? undefined : parsedLat
    const lon = Number.isNaN(parsedLon) ? undefined : parsedLon
    const name = String(entry?.NAME_OF_CASTLE ?? '').trim()
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
    registerHook(`ref:${ACTIVATION_TYPE}`, { hook: refHandler, key: 'eca' })
    registerHook('activity', { hook: activityHook, key: 'eca' })
    registerHook('adifFields', { hook: adifFieldsHook, key: 'eca' })
    registerHook('spots', { hook: SpotsHook, key: 'eca' })
    registerHook('dataFile', { hook: ecaDataFile, key: 'eca-all-castles' })
    registerHook('scoring', {
      hook: contestScorer(activityScorer(ECA_SCORING), { scope: { refTypes: [ACTIVATION_TYPE] } }),
      key: 'eca',
    })
    registerHook('export', {
      hook: activityExportHook({ key: 'eca', label: 'ECA', activationType: ACTIVATION_TYPE, icon: manifest.icon }),
      key: 'eca',
    })
  },
})
