// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// SAMPLE — a chasing program: what each contact counts toward.
//
// An award is a checklist, and a chasing program says which lines of it a
// contact fills. The app keeps the best claim for each line, ranks spots by
// what working the station would add, and alerts on what is new. The program
// never reads the log: `claimsForQsos` is a pure function of each contact,
// because the app also asks it about spots and about the call being typed.
//
// One contact makes several claims, one per kind of line the award keeps —
// here DXCC's three: Mixed (any band, any mode), its band, and its mode. A
// missing Mixed line is a new entity, a missing band or mode line a new band
// or mode, and `notices` says how each reads ("DXCC in 80m").
//
// The rules here are DXCC's, simplified: the catalog's `ham2k-dxcc` adds
// deleted entities, maritime mobile, satellites and the DXCC Challenge. See
// `docs/hooks.md` §`chasing`.

import { defineExtension, entityForCall } from "@ham2k/extension-sdk"
import type { ChasingHook, JSONValue, QsoClaim } from "@ham2k/extension-sdk"
import { parseCallsign } from "@ham2k/lib-callsigns"
import { ADIF_MODES_AND_SUBMODES, superModeForMode } from "@ham2k/lib-operation-data"

import manifest from "../manifest.json" with { type: "json" }

/// DXCC's three mode awards. `superModeForMode` calls anything it does not
/// know `DATA`, so a mode is checked against ADIF's list first.
const KNOWN_MODES = new Set(ADIF_MODES_AND_SUBMODES.map((mode) => mode.toUpperCase()))
const AWARD_MODES: Record<string, string> = { CW: "CW", PHONE: "PHONE", DATA: "DIGITAL" }

function obj(value: JSONValue | undefined): Record<string, JSONValue> {
  return value && typeof value === "object" && !Array.isArray(value) ? value : {}
}

/// Who the claim belongs to: an opaque string the program builds. DXCC goes
/// to a call, for contacts made from one entity — KI2D and KI2D/P share a
/// checklist, KI2D/VE2 keeps its own.
function holderFor(station: Record<string, JSONValue>): string | undefined {
  if (typeof station.call !== "string" || !station.call) return undefined
  const call = station.call.trim().toUpperCase()
  const base = parseCallsign(call).baseCall || call
  const entity = typeof station.dxccCode === "number" ? station.dxccCode : entityForCall(call).dxccCode
  return entity == null ? base : `${base}@${entity}`
}

/// `worked` from the contact itself, `confirmed` by a QSL the award takes.
function levelOf(qso: Record<string, JSONValue>): Pick<QsoClaim, "level" | "by"> {
  const qsl = obj(qso.qsl)
  if (obj(qsl.lotw).received === true) return { level: "confirmed", by: "lotw" }
  if (obj(qsl.qsl).received === true) return { level: "confirmed", by: "qsl" }
  return { level: "worked" }
}

function claimsFor(qso: Record<string, JSONValue>): QsoClaim[] {
  // An event marker's calls are placeholders, not stations.
  if (qso.band === "event") return []
  const their = obj(qso.their)
  const holder = holderFor(obj(qso.our))
  if (typeof their.call !== "string" || !holder) return []
  const { dxccCode, entityName } = entityForCall(their.call)
  if (dxccCode == null) return []

  const base = { holder, ref: String(dxccCode), ...(entityName ? { label: entityName } : {}), ...levelOf(qso) }
  const claims: QsoClaim[] = [{ ...base, band: null, mode: null }]
  if (typeof qso.band === "string" && qso.band) claims.push({ ...base, band: qso.band, mode: null })
  const mode = typeof qso.mode === "string" && KNOWN_MODES.has(qso.mode.toUpperCase()) ? AWARD_MODES[superModeForMode(qso.mode.toUpperCase())] : undefined
  if (mode) claims.push({ ...base, band: null, mode })
  return claims
}

const program: ChasingHook = {
  // Plain data, read without calling anything. Raise `version` whenever the
  // same contacts would claim something different.
  program: {
    label: "DXCC*",
    icon: "earth",
    version: 1,
    editions: "lifetime",
    notices: { newRef: "New DXCC* entity", newBand: "DXCC* on {{band}}", newMode: "DXCC* in {{mode}}" },
    modeLabels: { PHONE: "Phone", DIGITAL: "Digital" },
  },
  // Keyed by each contact's uuid; one without a uuid has no key to answer under.
  claimsForQsos: ({ qsos }) =>
    Object.fromEntries(qsos.filter((qso) => typeof qso.uuid === "string" && qso.uuid).map((qso) => [qso.uuid as string, claimsFor(qso)])),
  holdersFor: ({ station }) => {
    const holder = holderFor(station)
    return holder ? [holder] : []
  },
  // One tally per thing worth counting: entities, from their Mixed lines.
  summarizeClaims: ({ slots }) => {
    const entities = slots.filter((slot) => slot.band === null && slot.mode === null)
    const confirmed = entities.filter((slot) => slot.level !== "worked").length
    return { entities: { key: "entities", icon: "earth", label: `${entities.length} entities`, summary: `${confirmed} confirmed`, total: entities.length } }
  },
}

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook("chasing", { hook: program, key: manifest.key })
  },
})
