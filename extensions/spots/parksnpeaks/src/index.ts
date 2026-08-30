// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// ParksnPeaks — a VK/ZL spotting service that carries other awards' spots
// rather than awards of its own. It is the only source for WWFF and SiOTA
// activity in that part of the world, so this extension owns no references,
// no scoring and no ADIF: it reads that feed and posts to it.
//
// Inbound is deliberately narrowed to WWFF and SiOTA. The API answers with
// every class it knows (POTA and SOTA among them), and HaLo already has each
// of those from its own source — mapping PnP's copies too would show one
// activator twice, in two sources, with no way for the operator to tell they
// are the same person.

import { defineExtension, host } from "@ham2k/extension-sdk"
import type {
  HookContext,
  JSONValue,
  PostOtherSpotRequest,
  PostResult,
  PostSelfSpotRequest,
  Ref,
  Spot,
  SpotEligibility,
} from "@ham2k/extension-sdk"
import { bandForFrequency, modeForFrequency } from "@ham2k/lib-operation-data"

import { tFor } from "./i18n.ts"

import manifest from "../manifest.json" with { type: "json" }

const API_BASE = 'https://www.parksnpeaks.org/api'

/// The ACTIVATION ref types — what an operation carries — mapped to the
/// `actClass` this service files a spot under.
const ACTIVATION_SPOT_CLASSES: Record<string, string> = {
  siotaActivation: 'SiOTA',
  wwffActivation: 'WWFF',
}

/// The HUNTING ref types, which is what a QSO carries. Spotting someone else
/// reads these, never the activation types above: a logged contact with a
/// park has `wwff`, and matching `wwffActivation` there silently disables the
/// whole other-spot path.
const HUNTING_SPOT_CLASSES: Record<string, string> = {
  siota: 'SiOTA',
  wwff: 'WWFF',
}

/// The classes read back off the feed, mapped to the hunting ref type each
/// becomes. Anything absent here is dropped — see the header.
const INBOUND_REF_TYPES: Record<string, string> = {
  SiOTA: 'siota',
  WWFF: 'wwff',
}

/// The published record. `actSpoter` is the API's own spelling of "spotter";
/// matching the typo is what makes the field arrive.
interface PnPApiSpot {
  actTime?: string
  actSiteID?: string
  actCallsign?: string
  actMode?: string
  actFreq?: string
  actClass?: string
  actLocation?: string
  actComments?: string
  actSpoter?: string
}

/// The references of [container] this service will take a spot for, each
/// already carrying the `actClass` to file it under — so no caller has to
/// remember which of the two class maps applies to what it holds.
interface SpottableRef {
  ref: string
  actClass: string
}

function spottableRefs(container: Record<string, unknown>, classes: Record<string, string>): SpottableRef[] {
  return (((container.refs as Ref[] | undefined) ?? [])).flatMap((r) => {
    const actClass = classes[r.type]
    return actClass && r.ref ? [{ ref: r.ref, actClass }] : []
  })
}

async function credentials(ctx: HookContext): Promise<{ userId?: string; apiKey?: string }> {
  return {
    userId: ctx.account?.credentials?.userId,
    apiKey: ctx.account?.credentials?.apiKey,
  }
}

const SpotsHook = {
  sourceName: 'ParksnPeaks',

  async fetchSpots(_args: Record<string, never>, ctx: HookContext): Promise<Spot[]> {
    if (!ctx.online) return []

    // Reading the feed needs no account — only posting does. An operator with
    // no ParksnPeaks login still gets the VK/ZL spots, which is most of the
    // value here.
    const response = await host.fetch(`${API_BASE}/ALL`, {
      headers: {
        Accept: 'application/json',
        // The service answers `Content-Type: text/html` for what is JSON, and
        // app-polo asks for no caching on every call; a spot list served from
        // a cache is a spot list that has already expired.
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        Pragma: 'no-cache',
      },
    })
    if (response.status !== 200) throw new Error(`ParksnPeaks API returned HTTP ${response.status}`)
    const apiSpots = JSON.parse(response.body) as PnPApiSpot[]

    const spots: Spot[] = []
    for (const spot of apiSpots) {
      const refType = INBOUND_REF_TYPES[spot.actClass ?? '']
      if (!refType) continue

      // Published as MHz in a string ('7.160'); everything downstream is kHz.
      const parsed = Number.parseFloat(spot.actFreq ?? '')
      const freq = Number.isNaN(parsed) ? undefined : parsed * 1000

      // No 'Z' and no offset in `actTime` ('2026-08-05 00:07:27'), but the
      // service publishes UTC. Parsed as local time every spot would jump by
      // the operator's offset — a VK activator would appear to have been
      // spotted ten hours from now.
      //
      // An unreadable time becomes 0, never NaN: NaN fails every comparison,
      // so it would make the dedupe below depend on the order the service
      // happened to return rows in — a malformed row arriving first would
      // hold the slot and discard every good row after it.
      const parsedTime = Date.parse(`${(spot.actTime ?? '').replace(' ', 'T')}Z`)
      const timeInMillis = Number.isNaN(parsedTime) ? 0 : parsedTime

      const sourceInfo: Record<string, JSONValue> = {}
      if (spot.actComments) sourceInfo.comments = spot.actComments
      if (spot.actSpoter) sourceInfo.spotter = spot.actSpoter.toUpperCase().trim()

      spots.push({
        their: { call: (spot.actCallsign ?? '').toUpperCase().trim() },
        freq,
        band: freq ? bandForFrequency(freq) : undefined,
        // A spot with no mode is invisible under the panel's DEFAULT mode
        // filter, so an empty `actMode` — which app-polo wrote this same
        // fallback for, against this same feed — would silently hide it. The
        // band plan is read for VK: this service covers VK and ZL, both ITU
        // region 3.
        mode: spot.actMode?.toUpperCase() ||
          (freq ? modeForFrequency(freq, { ituRegion: 3, countryCode: 'AU', entityPrefix: 'VK' }) || undefined : undefined),
        refs: spot.actSiteID ? [{ ref: spot.actSiteID, type: refType }] : [],
        spot: {
          timeInMillis,
          source: manifest.key,
          label: [spot.actSiteID, spot.actLocation].filter((x) => x).join(': '),
          sourceInfo,
        },
      })
    }

    // One row per station PER AWARD. app-polo keeps a single row per station,
    // whichever the API returned first; that both hides an operator running a
    // WWFF park and a SiOTA silo at once (a common VK pairing, published as
    // two rows) and shows a station that moved band where it no longer is.
    // Keyed per award and keeping the NEWEST fixes both — and the panel's own
    // `mergeSpotsByCallAndFreq` then combines the two into one row carrying
    // both references, which it cannot do for rows discarded here.
    const newest = new Map<string, Spot>()
    for (const spot of spots) {
      const call = spot.their.call
      if (!call) continue
      const key = `${call}|${spot.refs?.[0]?.type ?? ''}`
      const held = newest.get(key)
      // `>=` so that among rows of equal time the later one in the feed wins.
      // Total, because an unreadable time was already turned into 0 above.
      if (!held || spot.spot.timeInMillis >= held.spot.timeInMillis) {
        newest.set(key, spot)
      }
    }
    return [...newest.values()]
  },

  async isSelfSpotEnabled({ operation }: { operation: Record<string, any> }, ctx: HookContext): Promise<SpotEligibility> {
    // Both halves of the login, not just the key: posting sends each, so
    // offering the source with only one stored invites a post that can only
    // come back rejected.
    const { userId, apiKey } = await credentials(ctx)
    return userId && apiKey && spottableRefs(operation, ACTIVATION_SPOT_CLASSES).length > 0
      ? { enabled: true, icon: manifest.icon }
      : { enabled: false }
  },

  async isOtherSpotEnabled({ qso }: { qso: Record<string, any> }, ctx: HookContext): Promise<SpotEligibility> {
    const { userId, apiKey } = await credentials(ctx)
    return userId && apiKey && spottableRefs(qso, HUNTING_SPOT_CLASSES).length > 0
      ? { enabled: true, icon: manifest.icon }
      : { enabled: false }
  },

  async postSelfSpot({ operation, freq, mode, comment }: PostSelfSpotRequest, ctx: HookContext): Promise<PostResult> {
    const refs = spottableRefs(operation, ACTIVATION_SPOT_CLASSES)
    if (refs.length === 0) return { ok: false, message: 'No WWFF or SiOTA activation on this operation' }
    const call = String(operation.stationCall ?? '').trim()
    if (!call) return { ok: false, message: 'This operation has no station callsign to spot' }
    return postSpotsToPnP(call, refs, freq, mode, comment, ctx)
  },

  async postOtherSpot({ qso, comment }: PostOtherSpotRequest, ctx: HookContext): Promise<PostResult> {
    const refs = spottableRefs(qso, HUNTING_SPOT_CLASSES)
    if (refs.length === 0) return { ok: false, message: 'No WWFF or SiOTA reference on this QSO' }
    const freq = Number(qso.freq)
    if (!freq) return { ok: false, message: 'This QSO has no frequency to spot' }
    const their = (qso.their ?? {}) as Record<string, unknown>
    // Guarded like the frequency: a spot naming no station reaches everybody
    // watching, which is worse than no spot.
    const call = String(their.call ?? '').trim()
    if (!call) return { ok: false, message: 'This QSO has no callsign to spot' }
    return postSpotsToPnP(call, refs, freq, qso.mode ? String(qso.mode) : undefined, comment, ctx)
  },
}

/// The service answers 200 with 'Failure' in the body for a rejected spot, so
/// the status alone never proves one landed.
const FAILURE_BODY = /Failure/i

/// kHz to the MHz string the API publishes and expects ('7.160').
///
/// NOT `fmtFreq(freq, {mode: 'compact'})`, which app-polo uses: that groups
/// thousands and strips the last group only when it is exactly '000', so
/// 7160.5 kHz — any radio not parked on a whole kHz — goes out as '7.160.',
/// and 630m/2200m lose the grouping entirely ('475', which reads as MHz).
/// Three decimals is the resolution the service itself publishes.
function mhzForSpot(freqKHz: number): string {
  return (freqKHz / 1000).toFixed(3)
}

async function postSpotsToPnP(
  call: string,
  refs: SpottableRef[],
  freq: number,
  mode: string | undefined,
  comment: string | undefined,
  ctx: HookContext,
): Promise<PostResult> {
  const { userId, apiKey } = await credentials(ctx)
  const t = tFor(ctx)
  if (!userId || !apiKey) return { ok: false, message: t('missingCredentials') }

  // EVERY reference is attempted, even after one fails: stopping at the first
  // leaves a reference the operator IS activating unspotted, with nothing
  // saying which. Failures are collected and named instead.
  const failures: string[] = []

  for (const ref of refs) {
    try {
      const response = await host.fetch(`${API_BASE}/spot`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          actCallsign: call,
          actClass: ref.actClass,
          actSite: ref.ref,
          freq: mhzForSpot(freq),
          mode: mode ?? null,
          comments: comment ?? '',
          userID: userId,
          APIKey: apiKey,
        }),
      })
      if (response.status !== 200 || FAILURE_BODY.test(response.body ?? '')) {
        failures.push(ref.ref)
      }
    } catch (_error) {
      failures.push(ref.ref)
    }
  }

  if (failures.length > 0) {
    return { ok: false, message: t('postFailed', { refs: failures.join(', ') }) }
  }
  return { ok: true }
}

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook('spots', { hook: SpotsHook, key: manifest.key })
    registerHook('account', {
      hook: {
        label: 'ParksnPeaks',
        description: (_args: Record<string, never>, ctx: HookContext) => tFor(ctx)('accountDescription'),
        kvKey: manifest.key,
        // One ParksnPeaks login belongs to the operator, not to a device, so
        // it syncs across their Apple devices the way the QRZ login does.
        synchronizable: true,
        fields: (_args: Record<string, never>, ctx: HookContext) => {
          const t = tFor(ctx)
          return [
            {
              key: 'userId',
              label: t('userIdLabel'),
              type: 'text',
              postface: t('userIdPostface'),
            },
            {
              key: 'apiKey',
              label: t('apiKeyLabel'),
              type: 'secret',
              postface: t('apiKeyPostface'),
            },
          ]
        },
        async testCredentials(creds: Record<string, string>, ctx: HookContext): Promise<string> {
          const t = tFor(ctx)
          if (!creds.userId?.trim() || !creds.apiKey?.trim()) return t('missingCredentials')
          // Presence is all this can honestly check. ParksnPeaks publishes no
          // endpoint that validates a login, and the only authenticated call
          // it has is posting a spot — which would put a real station on a
          // real spot list to test a password. Said plainly rather than
          // returning a bare ✅, which would claim the credentials work.
          // An empty string is not an option: the dialog renders the result
          // verbatim, so it would leave a blank box that reads as a failure.
          return t('credentialsUnverified', { userId: creds.userId.trim() })
        },
      },
    })
  },
})
