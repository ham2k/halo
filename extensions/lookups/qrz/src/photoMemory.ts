// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What QRZ already told us it has no picture of.
//
// The photo is QRZ's alone — no other source carries one, and each lookup run
// seeds from the bare callsign — so a hook that skips the network whenever the
// name and location are already answered leaves the call-info panel with no
// photo for exactly the callsigns the operator knows best. Without something
// remembering an answer ACROSS runs, the only correct behaviour is to ask
// every time.
//
// This is that memory, and only the negative half of it: a call QRZ has no
// picture of is worth remembering, since nothing else about it will ever be
// worth a round-trip either. A call that HAS a photo is deliberately not
// cached — the URL is on the QSO and Call History carries it forward, and
// re-asking is what keeps a changed profile picture from being frozen.
//
// The store is the LOG, not a cache of its own: a past QSO with this station
// carries QRZ's own record of that lookup (`their.lookups`), and a record with
// no `image` in it IS the remembered answer. `host.kvSet` would have been the
// obvious home and is the wrong one — it is in-memory per extension namespace
// (halo_extension_host.dart), so a cache built on it forgets everything the
// app is relaunched, which is exactly the span this needs to survive.
//
// A session-scoped map rides on top of that, so working the same station twice
// in one sitting does not re-read the log either.
//
// Pure, and its own module, so the rules below are testable without the host
// bridge index.ts pulls in.

import type { JSONValue } from "@ham2k/halo-extension-sdk"

/// How long an answer stands, whether remembered in this session or read back
/// off a past QSO. A ham who adds a photo should be found again without
/// reinstalling the app, and a month is short against how often a profile
/// picture appears, long against how often the same call is worked.
export const PHOTO_MEMORY_TTL_MS = 30 * 24 * 60 * 60 * 1000

/// Entries kept in the session map before the oldest are dropped. A logbook
/// can hold tens of thousands of calls; this is a courtesy cache in front of
/// the log, not a mirror of it.
export const PHOTO_MEMORY_LIMIT = 500

/// Callsign → when QRZ last said it has no picture, in epoch millis.
export type PhotoMemory = Record<string, number>

/// Whether QRZ has already said it has no picture of [call], recently enough
/// to still believe.
///
/// A stamp in the FUTURE is treated as expired, not as freshest: developer
/// time travel writes one (the sandbox's `Date` is the app clock), and an
/// entry stamped a year out would otherwise suppress that call's photo until
/// real time caught up — with nothing on screen to say why.
export function hasNoPhoto(memory: PhotoMemory, call: string, nowMillis: number): boolean {
  const at = memory[call.toUpperCase()]
  if (at === undefined) return false
  const age = nowMillis - at
  return age >= 0 && age < PHOTO_MEMORY_TTL_MS
}

/// Records that QRZ has no picture of [call]. Returns a NEW map — callers
/// compare against the old one to decide whether a write is needed.
export function rememberNoPhoto(memory: PhotoMemory, call: string, nowMillis: number): PhotoMemory {
  const next: PhotoMemory = { ...memory, [call.toUpperCase()]: nowMillis }
  const calls = Object.keys(next)
  if (calls.length <= PHOTO_MEMORY_LIMIT) return next
  // Oldest first, dropping from the front: the entries most likely to have
  // expired anyway, and never the one just written.
  calls.sort((a, b) => next[a] - next[b])
  for (const call of calls.slice(0, calls.length - PHOTO_MEMORY_LIMIT)) delete next[call]
  return next
}

/// Forgets [call] — QRZ answered with a picture after all. Returns the same
/// map when there was nothing to forget, so a caller can skip the write.
export function forgetNoPhoto(memory: PhotoMemory, call: string): PhotoMemory {
  const key = call.toUpperCase()
  if (!(key in memory)) return memory
  const next = { ...memory }
  delete next[key]
  return next
}

/// QRZ's source key, as it writes it on every result and as the app persists
/// it under a QSO's `their.lookups`.
const QRZ_SOURCE = 'qrz.com'

/// Whether a past QSO with this station already records QRZ answering without
/// a picture — the durable half of the memory, read straight off the log.
///
/// [history] is `ctx.getHistoryForCall`'s answer: whole QSO records, newest
/// first. Only the newest one that carries a QRZ record at all is consulted;
/// an older answer says nothing a newer one hasn't already superseded.
///
/// Absence of a QRZ record means "never asked", NOT "no photo" — a QSO logged
/// offline, or before a QRZ account was configured, must not suppress the
/// lookup that would finally find the picture.
export function historySaysNoPhoto(history: Record<string, JSONValue>[], nowMillis: number): boolean {
  for (const qso of history) {
    const their = (qso.their as Record<string, JSONValue> | undefined) ?? {}
    const lookups = Array.isArray(their.lookups) ? (their.lookups as Record<string, JSONValue>[]) : []
    const qrz = lookups.find((l) => l && l.source === QRZ_SOURCE)
    if (!qrz) continue

    // Stamped by when the contact happened, the one time this record carries.
    // A lookup re-run later against an old QSO is stamped older than it really
    // is, which errs toward asking again — the safe direction.
    const at = typeof qso.startAtMillis === 'number' ? qso.startAtMillis : undefined
    if (at === undefined) return false
    const age = nowMillis - at
    if (age < 0 || age >= PHOTO_MEMORY_TTL_MS) return false

    const image = qrz.image
    return !(typeof image === 'string' && image.trim() !== '')
  }
  return false
}
