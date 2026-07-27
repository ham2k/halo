// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What we declared about our own station: the power class we are running, and —
// where the sponsor publishes them — the entry category we are entering.
//
// Both are read back THROUGH THE EVENT, the same way `configuredOurPark` is and
// for the same reason: a setup-form field that has been hidden still submits, so
// switching an operation from Ohio to Texas leaves `ourCategory: 'SL'` sitting
// on the ref, where it must not reach a Texas anything. Ohio publishes no QRP
// class either, so a `QRP` left behind by Texas must not become a Cabrillo
// header for a sponsor whose own rules offer two classes.

import type { JSONValue } from "@ham2k/halo-extension-sdk"

import type { EntryCategory, StateParkEvent } from "./events.ts"
import { refOfType } from "./parks.ts"

const TYPE = 'stateparks'

/// Anything carrying `refs` — an operation, or a ref on its own.
type Container = Record<string, JSONValue> | undefined

function str(value: JSONValue | undefined): string {
  return typeof value === 'string' ? value : ''
}

/// The power class set up for this operation, if it is one THIS event publishes.
///
/// [ownRef] wins when given, as in `configuredOurPark`: a scorer is handed the
/// ref that selected it, and `decorateRef` has no operation around it at all.
export function configuredOurPower(event: StateParkEvent, operation: Container, ownRef?: Record<string, JSONValue>): string {
  const value = str((ownRef ?? refOfType(operation, TYPE))?.ourPower).toUpperCase()
  return event.powerClasses.some((power) => power.value === value) ? value : ''
}

/// The entry category set up for this operation, if it is one this event has.
export function configuredCategory(event: StateParkEvent, operation: Container, ownRef?: Record<string, JSONValue>): EntryCategory | undefined {
  const value = str((ownRef ?? refOfType(operation, TYPE))?.ourCategory).toUpperCase()
  return event.categories.find((category) => category.value === value)
}

/// What our power class ADDS to the multiplier sum — Texas's `powerMultipliers`,
/// and 0 for every event that publishes none and for a class never chosen.
///
/// Zero rather than one deliberately: an unanswered question must not claim a
/// multiplier the sponsor would not award (see events.ts, §6.5.1).
export function powerMultiplier(event: StateParkEvent, operation: Container, ownRef?: Record<string, JSONValue>): number {
  return event.powerMultipliers[configuredOurPower(event, operation, ownRef)] ?? 0
}

/// `CATEGORY-POWER` for a Cabrillo: the entry category's own power where the
/// category names one — six of Ohio's nine codes do — else the class we
/// declared.
///
/// Ohio is the only sponsor whose log carries this header, and it publishes two
/// classes, LP and HP. A QRP left on the ref by another event is therefore not
/// an Ohio class at all: `configuredOurPower` refuses it and this answers '',
/// which the writer drops. The HP/LOW mapping below is what makes LP read as the
/// sponsor's own word, and would carry a QRP class as LOW if Ohio ever added one.
export function cabrilloPower(event: StateParkEvent, operation: Container, ownRef?: Record<string, JSONValue>): string {
  const category = configuredCategory(event, operation, ownRef)
  if (category?.power) return category.power
  const power = configuredOurPower(event, operation, ownRef)
  if (!power) return ''
  return power === 'HP' ? 'HIGH' : 'LOW'
}
