// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Which parks a QSO is worth, resolved ONCE for everyone who asks.
//
// The scorer, the ADIF fields, the Cabrillo writer and the operation title all
// need the same two answers — which park we are working from, and which park the
// station we worked is in — and they must agree. They didn't: the scorer read
// the QSO's POTA reference first and the exports read the typed abbreviation
// first, so a QSO carrying both, disagreeing, scored as one park and was
// submitted as another. The app would show a multiplier the submitted log does
// not support. polo has the same split (`scoringForQSO` vs
// `qsoToCabrilloParts`); this is a fix, not a port.
//
// The typed value wins. What the operator keyed is what was sent on the air, so
// it is the data of record — the same reading §5.8 takes of a serial number,
// where the number DISPLAYED is written to the QSO because that is what went
// out. A POTA reference is the fallback, and for the three events with no
// exchange at all it is the only source.

import type { JSONValue } from "@ham2k/halo-extension-sdk"

import type { StateParkEvent } from "./events.ts"

export const POTA_HUNTING = 'pota'
export const POTA_ACTIVATION = 'potaActivation'

/// Anything carrying `refs` — an operation or a QSO, in either direction.
type Container = Record<string, JSONValue> | undefined

function str(value: JSONValue | undefined): string {
  return typeof value === 'string' ? value : ''
}

export function refsOfType(container: Container, type: string): Record<string, JSONValue>[] {
  return (((container?.refs as Record<string, JSONValue>[] | undefined) ?? [])).filter((r) => r?.type === type)
}

export function refOfType(container: Container, type: string): Record<string, JSONValue> | undefined {
  return refsOfType(container, type)[0]
}

/// The abbreviation the operator set up for this operation, if it is one of
/// THIS event's parks.
///
/// Checked against the event, because the setup form keeps a field it has hidden
/// (a `visibleWhen` field still submits) — so switching an operation from Ohio
/// to Texas leaves Ohio's `ourPark` sitting on the ref, where it must not be
/// read as a Texas park or shown in a Texas label.
///
/// [ownRef] wins when given: a scorer is handed the ref that SELECTED it, which
/// on a segmented log is the segment's own, and `decorateRef` is handed a ref
/// with no operation around it at all.
export function configuredOurPark(event: StateParkEvent, operation: Container, ownRef?: Record<string, JSONValue>): string {
  const configured = str((ownRef ?? refOfType(operation, 'stateparks'))?.ourPark).toUpperCase()
  return event.parkByAbbreviation[configured] ? configured : ''
}

/// The parks in [event] we are working FROM, as POTA references.
///
/// The POTA activation is authoritative when there is one: it is a reference,
/// checked and decorated, and the operator is logging it either way. The
/// abbreviation from setup is a FALLBACK for someone running the event without
/// POTA — not an addition to it. Adding it doubled every QSO's points and
/// invented a second activated park whenever the two disagreed.
export function ourParkRefs(event: StateParkEvent, operation: Container, ownRef?: Record<string, JSONValue>): string[] {
  const activated = refsOfType(operation, POTA_ACTIVATION)
    .map((r) => str(r.ref).toUpperCase())
    .filter((r) => event.parkByRef[r])
  if (activated.length > 0) return activated

  const fromSetup = event.parkByAbbreviation[configuredOurPark(event, operation, ownRef)]?.ref
  return fromSetup ? [fromSetup] : []
}

/// Our park's abbreviation for display and for the exchange we send — the park
/// we set up, else the one our POTA activation names.
export function ourParkAbbreviation(event: StateParkEvent, operation: Container, ownRef?: Record<string, JSONValue>): string {
  const configured = configuredOurPark(event, operation, ownRef)
  if (configured) return configured
  return event.parkByRef[ourParkRefs(event, operation, ownRef)[0] ?? '']?.abbreviation ?? ''
}

/// Whether the operator has DECIDED this QSO's exchange — the field is present
/// on our ref, blank or not.
///
/// Presence, never truthiness: the core writes `park: ''` when the operator
/// empties the field on purpose and drops the key when it was never filled in,
/// so a present-but-blank key is a decision every reader has to honour. Deriving
/// a park from a POTA reference over the top of it would put back what they just
/// removed — in the log they submit, if not on the screen (§5.4).
export function theirParkWasDecided(qso: Container): boolean {
  const ref = refOfType(qso, 'stateparks')
  return ref !== undefined && 'park' in ref
}

/// The abbreviation the station we worked sent, as typed if they typed one, else
/// the abbreviation of a park they are logged as being in.
export function theirParkAbbreviation(event: StateParkEvent, qso: Container): string {
  const ref = refOfType(qso, 'stateparks')
  if (ref !== undefined && 'park' in ref) return str(ref.park).toUpperCase()

  for (const hunted of refsOfType(qso, POTA_HUNTING)) {
    const park = event.parkByRef[str(hunted.ref).toUpperCase()]
    if (park?.abbreviation) return park.abbreviation
  }
  return ''
}

/// The parks in [event] the station we worked is in, as POTA references.
///
/// AN EVENT WITH AN EXCHANGE CLAIMS AT MOST ONE PARK PER QSO, and that is a fact
/// about the events rather than a limitation here: the exchange is one park
/// abbreviation, and the sponsor's park list is a subset of POTA that contains no
/// multi-reference location — so no station can be at two of Ohio's parks at
/// once. A QSO may perfectly well be a POTA two-fer AND a single OHSP contact;
/// the two programs' exchanges are independent, and a second POTA reference never
/// becomes a second state-park claim.
///
/// The events with NO exchange (Texas, Florida, Georgia) have no such list to be
/// a subset of, so there every park of theirs in the event counts — a park-to-park
/// pair is a contact for each.
///
/// Either way a POTA reference only INFORMS this: it is where the abbreviation
/// comes from when the operator hasn't keyed one.
export function theirParkRefs(event: StateParkEvent, qso: Container): string[] {
  const hunted = refsOfType(qso, POTA_HUNTING)
    .map((r) => str(r.ref).toUpperCase())
    .filter((r) => event.parkByRef[r])

  if (!event.usesParkAbbreviations) return hunted

  // An exchange the operator DECIDED settles it: what they keyed is what was
  // sent, so a reference that disagrees gets no claim of its own, and a
  // decided-but-unrecognized value claims nothing rather than falling through to
  // a park they just told us they weren't in.
  if (theirParkWasDecided(qso)) {
    const typed = event.parkByAbbreviation[theirParkAbbreviation(event, qso)]?.ref
    return typed ? [typed] : []
  }

  // Nothing keyed: the abbreviation would have come from the first of their
  // references, so that is the one park claimed — never two.
  return hunted.slice(0, 1)
}
