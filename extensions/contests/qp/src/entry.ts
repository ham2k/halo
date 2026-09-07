// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What the operator declares once per operation — read off the party's ref, in
// one place, so the setup form, the scorer, the ADIF and the Cabrillo cannot
// disagree about what was claimed.
//
// The ref is the segment-effective one wherever a segment may have restated it:
// `location` and `mobile` are what a rover changes when they drive into the
// next county, so the scorer reads them per QSO rather than once per log.

import {
  MODE_CLASSES,
  type ModeClass,
  OPERATOR_CLASSES,
  type OperatorClass,
  OVERLAY_CLASSES,
  type OverlayClass,
  type PowerClass,
  POWER_CLASSES,
  type QsoParty,
  ROVING_STATION_CLASSES,
  STATION_CLASSES,
  type StationClass,
} from "./parties.ts"

/// The ref type this extension owns, and the value in a `{type: 'qp'}` ref.
export const TYPE = 'qp'

export function str(value: unknown): string {
  return typeof value === 'string' ? value : ''
}

/// This extension's ref on an operation (or on a QSO), if it has one.
export function refOfType(
  record: Record<string, unknown> | undefined,
  type: string = TYPE,
): Record<string, unknown> | undefined {
  const refs = (record?.refs as Record<string, unknown>[] | undefined) ?? []
  return refs.find((ref) => ref?.type === type)
}

/// Where we are operating from, as typed — one county, or a county line's two
/// separated by a slash. Not resolved here: `location.ts` owns what the text
/// means, and this is only where it lives.
export function ourLocationText(
  operation: Record<string, unknown> | undefined,
  ref?: Record<string, unknown>,
): string {
  return str((ref ?? refOfType(operation))?.location).trim()
}

/// One declared class, or undefined for a question the operator has not
/// answered — and `undefined` is the answer that means "no claim", not a
/// missing value to be defaulted (`stateparks/entry.ts` makes the same point
/// about power). A value the party does not publish is refused, so a class left
/// on a ref by a previously-chosen party cannot be submitted under this one.
function declared<T extends string>(
  ref: Record<string, unknown> | undefined,
  field: string,
  known: readonly T[],
  offered: readonly T[],
): T | undefined {
  const value = str(ref?.[field]).toUpperCase()
  const code = known.find((candidate) => candidate === value)
  return code && offered.includes(code) ? code : undefined
}

/// The entry class we are competing in, for each axis the party publishes.
export function ourOperatorClass(
  party: QsoParty,
  operation: Record<string, unknown> | undefined,
  ref?: Record<string, unknown>,
): OperatorClass | undefined {
  return declared(ref ?? refOfType(operation), 'operator', OPERATOR_CLASSES, party.entryClasses.operator)
}

export function ourStationClass(
  party: QsoParty,
  operation: Record<string, unknown> | undefined,
  ref?: Record<string, unknown>,
): StationClass | undefined {
  return declared(ref ?? refOfType(operation), 'station', STATION_CLASSES, party.entryClasses.station)
}

export function ourModeClass(
  party: QsoParty,
  operation: Record<string, unknown> | undefined,
  ref?: Record<string, unknown>,
): ModeClass | undefined {
  return declared(ref ?? refOfType(operation), 'mode', MODE_CLASSES, party.entryClasses.mode)
}

export function ourOverlayClass(
  party: QsoParty,
  operation: Record<string, unknown> | undefined,
  ref?: Record<string, unknown>,
): OverlayClass | undefined {
  return declared(ref ?? refOfType(operation), 'overlay', OVERLAY_CLASSES, party.entryClasses.overlay)
}

/// [party] is optional only because the power class is read in places that have
/// no party to hand; give it one wherever the answer reaches a submitted file,
/// so a class left behind by a previously-chosen party is refused here as it is
/// on every other axis.
export function ourPowerClass(
  operation: Record<string, unknown> | undefined,
  ref?: Record<string, unknown>,
  party?: QsoParty,
): PowerClass | undefined {
  const offered = party ? party.entryClasses.power : POWER_CLASSES
  return declared(ref ?? refOfType(operation), 'power', POWER_CLASSES, offered)
}

/// What the declared power class multiplies the score by, or 1.
///
/// Four parties publish a power table and polo reads none of them (its own
/// NOTES lists `powerMultiplier` as unimplemented), so a QRP entrant's score
/// there is a third of what DE awards. Honoured here — one of the gaps this
/// port closes — and 1 whenever no class is declared or the party publishes no
/// table, which is every party but six.
export function powerMultiplier(
  party: QsoParty,
  operation: Record<string, unknown> | undefined,
  ref?: Record<string, unknown>,
): number {
  const power = ourPowerClass(operation, ref, party)
  if (!power) return 1
  return party.powerMultipliers[power] ?? 1
}

/// Whether we are entering as a mobile or rover station. Several parties pay
/// the per-county bonus to rovers only, and one (TN) lets a rover count its own
/// county as a multiplier.
/// Now a reading of the STATION class, which is the same question asked
/// properly: "Mobile or Rover" was a checkbox because there was nowhere else to
/// put it. The old boolean is still honoured — it is on every operation logged
/// before the classes existed, and on anything synced from polo.
export function isMobile(
  operation: Record<string, unknown> | undefined,
  ref?: Record<string, unknown>,
  party?: QsoParty,
): boolean {
  const own = ref ?? refOfType(operation)
  if (own?.mobile === true) return true
  const station = str(own?.station).toUpperCase() as StationClass
  return ROVING_STATION_CLASSES.includes(station)
    && (!party || party.entryClasses.station.includes(station))
}

/// The address a Cabrillo's `EMAIL:` line carries, for the sponsors that ask
/// for one.
export function ourEmail(
  operation: Record<string, unknown> | undefined,
  ref?: Record<string, unknown>,
): string {
  return str((ref ?? refOfType(operation))?.email).trim()
}

/// The name we send, for the one party whose exchange includes it (MN).
export function ourName(
  operation: Record<string, unknown> | undefined,
  ref?: Record<string, unknown>,
): string {
  return str((ref ?? refOfType(operation))?.ourName).trim().toUpperCase()
}
