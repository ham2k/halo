// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// DXCC as a chasing program (docs/design/claims.md): every contact with a
// resolvable entity claims it three ways — Mixed (any band, any mode), on its
// band, and in its mode — for the station call worked FROM that entity.
//
// Imported by relative path, not the `@ham2k/extension-sdk` alias, so the
// tests run under plain `node --test`; `index.ts` keeps the alias.

import { baseCallOf } from "../../../sdk/src/callsigns.ts"
import { entityForCall } from "../../../sdk/src/dxcc.ts"
import { createCachedTranslator } from "../../../sdk/src/i18n.ts"
import { DXCC_BY_CODE } from "@ham2k/lib-dxcc-data"
import { fmtInteger } from "@ham2k/lib-format-tools"
import { ADIF_MODES_AND_SUBMODES, superModeForMode } from "@ham2k/lib-operation-data"
import type { ChasingHook, ClaimSlot, ClaimsTally, HookContext, JSONValue, QsoClaim } from "@ham2k/extension-sdk"

import en from "./i18n/en.json" with { type: "json" }
import es from "./i18n/es.json" with { type: "json" }

const tFor = createCachedTranslator({ en: { translation: en }, es: { translation: es } })

/// The three DXCC mode awards. `superModeForMode` answers `DATA` for anything
/// it does not recognize — an empty mode, an imported `OTHER` — so a mode is
/// checked against ADIF's list before it is grouped at all.
const KNOWN_MODES = new Set(ADIF_MODES_AND_SUBMODES.map((mode) => mode.toUpperCase()))
const AWARD_MODES: Record<string, string> = { CW: "CW", PHONE: "PHONE", DATA: "DIGITAL" }

function awardModeOf(mode: unknown): string | undefined {
  if (typeof mode !== "string" || !KNOWN_MODES.has(mode.toUpperCase())) return undefined
  return AWARD_MODES[superModeForMode(mode.toUpperCase())]
}

/// An award goes to a call, for contacts made from one entity: KI2D and
/// KI2D/P share a checklist, KI2D/VE2 has its own. A call whose entity does
/// not resolve still claims, under the bare call.
function holderFor(call: string, dxccCode: number | undefined = entityForCall(call).dxccCode): string {
  const base = baseCallOf(call)
  return dxccCode == null ? base : `${base}@${dxccCode}`
}

function storedCode(side: Record<string, JSONValue>): number | undefined {
  return typeof side.dxccCode === "number" ? side.dxccCode : undefined
}

/// The entity a contact records outranks the one its callsign resolves to:
/// an ADIF import writes `dxccCode` on both sides, and a log made from Hawaii
/// under a mainland call says 110 where the callsign says 291 — the same rule
/// the ADIF export follows (core/adif). A lookup's guess comes next; the
/// callsign is the fallback, and it settles an entity outright, so a claim
/// resolved from it is not a guess. One resolved from a lookup is.
function theirEntity(their: Record<string, JSONValue>, call: string): { dxccCode?: number; entityName?: string; guess?: boolean } {
  const stored = storedCode(their)
  const code = stored ?? storedCode(obj(their.guess))
  if (code == null) return entityForCall(call)
  const name = typeof their.entityName === "string" && their.entityName ? their.entityName : DXCC_BY_CODE[code]?.name
  return { dxccCode: code, ...(name ? { entityName: name } : {}), ...(stored == null ? { guess: true } : {}) }
}

/// The ADIF award DXCC credits each kind of slot under: Mixed, a band, a mode.
type SlotKind = "DXCC" | "DXCC_BAND" | "DXCC_MODE"

/// DXCC credit is verified; a LoTW or paper confirmation is confirmed. eQSL,
/// QRZ and Club Log confirmations do not count for DXCC.
///
/// DXCC credits a contact for Mixed, for its band and for its mode
/// separately. A credit that lists its `awards` verifies only the slots it
/// names; one that lists none verifies all three.
function levelOf(qso: Record<string, JSONValue>, kind: SlotKind): Pick<QsoClaim, "level" | "by"> {
  const credit = obj(obj(qso.credits).dxcc)
  const awards = Array.isArray(credit.awards) ? credit.awards : undefined
  if (credit.level === "verified" && (awards == null || awards.includes(kind))) {
    return { level: "verified", ...(typeof credit.by === "string" ? { by: credit.by } : {}) }
  }
  const qsl = obj(qso.qsl)
  if (obj(qsl.lotw).received === true) return { level: "confirmed", by: "lotw" }
  if (obj(qsl.qsl).received === true) return { level: "confirmed", by: "qsl" }
  return { level: "worked" }
}

function obj(value: JSONValue | undefined): Record<string, JSONValue> {
  return value && typeof value === "object" && !Array.isArray(value) ? value : {}
}

/// [stationEntity] resolves the station call's entity; a batch shares a
/// cache of it, since its contacts are nearly always made from one call.
function claimsForQso(
  qso: Record<string, JSONValue>,
  stationEntity: (call: string) => number | undefined = (call) => entityForCall(call).dxccCode,
): QsoClaim[] {
  // An event marker carries placeholder calls (`EVENT`, `START`) that resolve
  // to real entities.
  if (qso.band === "event" || qso.deleted === true) return []
  const their = obj(qso.their)
  const our = obj(qso.our)
  if (typeof their.call !== "string" || !their.call || typeof our.call !== "string" || !our.call) return []
  const { dxccCode, entityName, guess } = theirEntity(their, their.call)
  if (dxccCode == null) return []

  const holder = holderFor(our.call, storedCode(our) ?? stationEntity(our.call))
  const base = { holder, ref: String(dxccCode), ...(entityName ? { label: entityName } : {}), ...(guess ? { guess } : {}) }
  const claims: QsoClaim[] = [{ ...base, band: null, mode: null, ...levelOf(qso, "DXCC") }]
  if (typeof qso.band === "string" && qso.band) claims.push({ ...base, band: qso.band, mode: null, ...levelOf(qso, "DXCC_BAND") })
  const mode = awardModeOf(qso.mode)
  if (mode) claims.push({ ...base, band: null, mode, ...levelOf(qso, "DXCC_MODE") })
  return claims
}

/// Contacts without a uuid have no key to answer under, and are left out.
function claimsForQsos({ qsos }: { qsos: Record<string, JSONValue>[] }): Record<string, QsoClaim[]> {
  const entities = new Map<string, number | undefined>()
  const stationEntity = (call: string) => {
    if (!entities.has(call)) entities.set(call, entityForCall(call).dxccCode)
    return entities.get(call)
  }
  return Object.fromEntries(qsos.filter((qso) => typeof qso.uuid === "string" && qso.uuid).map((qso) => [qso.uuid as string, claimsForQso(qso, stationEntity)]))
}

function summarizeClaims({ slots }: { holder: string; slots: ClaimSlot[] }, ctx: Pick<HookContext, "locale">): Record<string, ClaimsTally> {
  const t = tFor(ctx)
  const mixed = slots.filter((slot) => slot.band === null && slot.mode === null)
  const confirmed = mixed.filter((slot) => slot.level !== "worked").length
  const count = mixed.length
  return {
    entities: {
      key: "entities",
      icon: "earth",
      label: count === 1 ? t("oneEntity") : t("manyEntities", { formatted: fmtInteger(count) }),
      summary: t("confirmed", { formatted: fmtInteger(confirmed) }),
      total: count,
    },
  }
}

export const dxccProgram: ChasingHook = {
  program: { label: "DXCC", icon: "earth", version: 1, editions: "lifetime" },
  claimsForQsos,
  holdersFor: ({ station }) => (typeof station.call === "string" && station.call ? [holderFor(station.call, storedCode(station))] : []),
  summarizeClaims,
}
