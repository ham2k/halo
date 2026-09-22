// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Satellite operations — the only activity
// that is not an award. Nothing is activated and nothing is scored: a satellite
// QSO is an ordinary contact that happens to name the bird it went through, so
// this registers no `scoring` and no `export`, exactly as app-polo does.
//
// The reference is a TRANSPONDER, not a satellite: `SO-50/145.85/fm` is name,
// uplink MHz and uplink mode joined by `/`, which is app-polo's own format —
// logs move between the two apps unchanged. It has to be the transponder rather
// than the bird because AO-7's two transponders answer on different bands (2m
// up → 10m down, 70cm up → 2m down), so the choice decides both what the radio
// is tuned to and what `BAND_RX` says.
//
// Two ways in, per the decision in docs/design/activities.md §3.5:
//   - a PICKER (`kind: 'options'` per QSO, `kind: 'form'` per operation), which
//     records the bird but cannot tune the radio — a control writes its value
//     and cannot ask for anything else to happen;
//   - a COMMAND (`SAT SO-50`), which can, because commands emit `setVfo`.
// Neither needed a core change. Letting controls emit command actions is the
// reusable fix and is written up as the alternative in §3.5.

import { defineExtension, host } from "@ham2k/extension-sdk"
import type { CommandCatalogEntry, CommandInterpretation, DataFileDefinition, HookContext, JSONValue, LookupRow, Ref } from "@ham2k/extension-sdk"
import { bandForFrequency } from "@ham2k/lib-operation-data"
import { capitalizeString } from "@ham2k/lib-format-tools"

import { tFor } from "./i18n.ts"

import manifest from "../manifest.json" with { type: "json" }

const REF_TYPE = "satellite"
const CATEGORY = "satellites"

interface Link {
  mode?: string
  lowerMHz?: number
  upperMHz?: number
}

interface Satellite {
  name?: string
  number?: number
  modulation?: string
  uplinks?: Link[]
  downlinks?: Link[]
}

/// Megahertz to three decimals.
///
/// NOT `fmtFreq`, which reads its argument as kHz and groups thousands — it
/// renders QO-100's 10489.5 MHz as "10.489.500", which app-polo's labels
/// inherit. Satellite data is published in MHz, so it is shown in MHz.
function fmtMHz(mhz: number | undefined): string {
  return typeof mhz === "number" ? mhz.toFixed(3) : ""
}

function textOf(value: unknown): string {
  return typeof value === "string" ? value.trim() : ""
}

function refsOfType(container: Record<string, unknown> | undefined, type: string): Ref[] {
  const refs = (container?.refs ?? []) as Ref[]
  return Array.isArray(refs) ? refs.filter((r) => r?.type === type) : []
}

/// One selectable transponder: what the log stores, what the operator reads,
/// and the two things the choice decides.
interface Transponder {
  /// `SO-50/145.85/fm` — app-polo's format, stored verbatim.
  code: string
  label: string
  satName: string
  /// The uplink, in kHz, which is what the radio is tuned to.
  uplinkKHz?: number
  /// FM is worth setting; a `linear` or `digital` transponder says nothing
  /// about which mode the operator will actually use on it.
  uplinkMode?: string
  /// From the matching DOWNLINK — this is `BAND_RX`.
  downlinkBand?: string
}

function transpondersOf(sat: Satellite): Transponder[] {
  const name = textOf(sat.name)
  if (!name) return []
  return (sat.uplinks ?? []).map((up, index) => {
    // Paired by index. The published data has matched the two arrays every time
    // so far, but it is fetched live — falling back to the first downlink keeps
    // a mismatched bird usable rather than dropping it, which is app-polo's
    // choice too.
    const down = sat.downlinks?.[index] ?? sat.downlinks?.[0]
    const arrow = [fmtMHz(up?.lowerMHz), fmtMHz(down?.upperMHz)].filter((x) => x).join(" → ")
    return {
      code: `${name}/${up?.lowerMHz}/${up?.mode}`,
      label: `${name} • ${capitalizeString(up?.mode ?? "")}${arrow ? `: ${arrow}` : ""}`,
      satName: name,
      uplinkKHz: typeof up?.lowerMHz === "number" ? up.lowerMHz * 1000 : undefined,
      uplinkMode: up?.mode === "fm" ? "FM" : undefined,
      downlinkBand: typeof down?.upperMHz === "number" ? bandForFrequency(down.upperMHz) : undefined,
    }
  })
}

/// The bird table, cached because the ADIF path asks per QSO and every ask is a
/// bridge crossing.
///
/// The controls refresh it — they run when the operator opens a picker, which
/// is rare and is also the moment a freshly downloaded list should show up. The
/// export path uses whatever they last loaded, so a bird added mid-session
/// reaches the log as soon as the picker has been opened once.
let cached: Transponder[] | null = null

async function transponders({ refresh = false } = {}): Promise<Transponder[]> {
  if (cached && !refresh) return cached
  // An empty query matches everything, capped at 100 rows — comfortable for the
  // ~40 active birds, and the reason this stores one row per BIRD rather than
  // one per transponder.
  const rows: LookupRow[] = await host.dbLookupSelectAll(CATEGORY, "")
  cached = rows.flatMap((row) => transpondersOf((row.data ?? {}) as Satellite))
  return cached
}

function transponderFor(code: string, all: Transponder[]): Transponder | undefined {
  return all.find((t) => t.code === code)
}

const refHandler = {
  async decorateRef({ ref }: { ref: Ref }, _ctx: HookContext): Promise<Ref> {
    const code = textOf(ref.ref)
    if (!code) return ref
    const [satName] = code.split("/")
    const match = transponderFor(code, cached ?? [])
    return {
      ...ref,
      ref: code,
      // The bird alone, because that is what an operator calls it. The
      // transponder is in the full label for the one case it matters.
      shortLabel: satName,
      label: match?.label ?? satName,
      name: match?.label ?? satName,
    }
  },
}

const activityHook = {
  /// The operation's bird, which every QSO then defaults to. A `form` rather
  /// than the `options` control below because `operationControls` renders only
  /// `refList` and `form` — and a `select` of forty labelled transponders reads
  /// better here than a code field anyway.
  async operationControls(_args: { operation: Record<string, JSONValue>; qso?: Record<string, JSONValue> }, ctx: HookContext) {
    const t = tFor(ctx)
    const options = (await transponders({ refresh: true })).map((tr) => ({ label: tr.label, value: tr.code }))
    return [
      {
        key: "satellites/satellite",
        label: t("operationControl"),
        icon: manifest.icon,
        color: manifest.accentColor,
        order: 10,
        optionType: "optional",
        input: {
          kind: "form",
          refType: REF_TYPE,
          form: {
            title: t("setupTitle"),
            // Empty until the data file has landed. The control still appears:
            // an empty picker says "the list is not here yet", where hiding the
            // activity entirely would look like it does not exist.
            elements: [{ type: "field", fieldType: "select", key: "ref", label: t("satelliteLabel"), options }],
          },
        },
      },
    ]
  },

  /// Per QSO. Mandatory once the operation names a bird — on a satellite pass
  /// every contact goes through one, and a QSO that forgot to say which is a
  /// QSO that cannot be uploaded as a satellite contact.
  async loggingControls({ operation }: { operation: Record<string, JSONValue>; qso?: Record<string, JSONValue> }, ctx: HookContext) {
    const t = tFor(ctx)
    const all = await transponders({ refresh: true })
    const operationSatellite = textOf(refsOfType(operation, REF_TYPE)[0]?.ref)
    return [
      {
        key: "satellites/qso",
        label: t("loggingControl"),
        icon: manifest.icon,
        color: manifest.accentColor,
        order: 10,
        optionType: operationSatellite ? "mandatory" : "optional",
        input: {
          kind: "options",
          refType: REF_TYPE,
          field: "ref",
          options: all.map((tr) => ({ code: tr.code, name: tr.label })),
          // The operation's bird, so a pass is one choice rather than one per
          // contact — app-polo's `operation.satellite` without a second place
          // to store it.
          suggestedValue: operationSatellite || undefined,
          // The stored code carries a lowercase mode (`SO-50/145.85/fm`).
          // Uppercasing it would break the match against app-polo's format for
          // no gain; the search ignores case on both sides regardless.
          uppercase: false,
          minCharsForSuggestions: 1,
        },
      },
    ]
  },
}

const adifFieldsHook = {
  async fieldsForOneQSO(
    { qso }: { qso: Record<string, unknown>; operation: Record<string, unknown> },
    _ctx: HookContext,
  ): Promise<{ name: string; value: string }[]> {
    const code = textOf(refsOfType(qso, REF_TYPE)[0]?.ref)
    if (!code) return []
    const [satName] = code.split("/")
    if (!satName) return []

    const fields = [
      { name: "PROP_MODE", value: "SAT" },
      { name: "SAT_NAME", value: satName },
    ]
    // BAND_RX is the DOWNLINK's band, which is why the transponder is part of
    // the reference: AO-7 answers on 10m from one and 2m from the other.
    const band = transponderFor(code, await transponders())?.downlinkBand
    if (band) fields.push({ name: "BAND_RX", value: band })
    return fields
  },
}

/// A satellite name with the punctuation taken out, so `SO50` and `SO-50` are
/// the same bird. The exporter above writes the table's own spelling, but other
/// software writes what the operator typed.
function satKey(name: string): string {
  return name.toUpperCase().replace(/[^A-Z0-9]/g, "")
}

/// The band a record says the station TRANSMITTED on. `FREQ` is the uplink by
/// ADIF's own definition — `FREQ_RX`/`BAND_RX` are the receive side — which is
/// what makes it usable for telling one transponder from another.
///
/// Undefined means "the record does not say", and `'other'` has to collapse to
/// that: `bandForFrequency` answers with the literal string for a frequency it
/// cannot place rather than anything falsy, so passing it through would turn
/// no information into a CONTRADICTION and eliminate every candidate — costing
/// a single-transponder bird the transponder its name alone had already
/// settled.
function uplinkBandOf(fields: Record<string, string>): string | undefined {
  const band = textOf(fields.band).toLowerCase()
  if (band) return band
  // MHz, as ADIF writes it. `bandForFrequency` reads either MHz or kHz.
  const freq = Number.parseFloat(fields.freq ?? "")
  if (Number.isNaN(freq)) return undefined
  const uplink = bandForFrequency(freq)
  return uplink === "other" ? undefined : uplink
}

/// The inverse of `adifFieldsHook`, and lossy in one direction: the log stores
/// a TRANSPONDER (`AO-7/145.95/linear`) while ADIF carries only the bird's name
/// and the downlink band, so the uplink half is reconstructed rather than read.
///
/// `SAT_NAME` alone is enough to import. The table is consulted to RECOVER the
/// transponder when it can — `BAND_RX` matches a downlink, `BAND`/`FREQ`
/// matches an uplink, and AO-7's two transponders differ on both axes (2m up →
/// 10m down, 70cm up → 2m down), which is why the reference names a transponder
/// at all. But nothing here validates: a bird the table has never heard of, a
/// `BAND_RX` that disagrees with it, and a record that names no band are all
/// imported as the bare satellite the file wrote.
///
/// The reference degrades cleanly, which is what makes that safe. `decorateRef`
/// splits on `/` and falls back to the whole string, so a bare name labels
/// itself; the exporter writes `SAT_NAME` from the same first segment and
/// simply omits `BAND_RX` when it cannot resolve one. What is lost is the
/// uplink the radio would tune to, not the fact that this was a satellite QSO.
function satelliteRefFor(fields: Record<string, string>, all: Transponder[]): string | undefined {
  const name = textOf(fields.sat_name)
  if (!name) return undefined

  const key = satKey(name)
  let candidates = all.filter((t) => satKey(t.satName) === key)

  const downlinkBand = textOf(fields.band_rx).toLowerCase()
  if (downlinkBand) candidates = candidates.filter((t) => t.downlinkBand === downlinkBand)

  const uplinkBand = uplinkBandOf(fields)
  if (uplinkBand) {
    candidates = candidates.filter((t) => t.uplinkKHz != null && bandForFrequency(t.uplinkKHz) === uplinkBand)
  }

  // Exactly one, or none of it — two survivors mean the record does not say
  // which transponder was used, and picking either would name a band the
  // operator never transmitted on.
  return candidates.length === 1 ? candidates[0].code : name
}

const adifImportHook = {
  async refsForRecords({ records }: { records: { fields: Record<string, string> }[] }, _ctx: HookContext): Promise<({ refs: Ref[] } | null)[]> {
    // Refreshed once for the whole batch rather than trusted from the cache: an
    // import can be the first thing a session does, and `transponders()` would
    // otherwise memoize the empty table it found before the data file landed.
    const all = await transponders({ refresh: true })
    return records.map((record) => {
      const ref = satelliteRefFor(record.fields ?? {}, all)
      // No `for: 'operation'` — unlike an award's activation, the bird belongs
      // to the CONTACT. The operation's own satellite ref is only the default
      // new QSOs pick up, and hoisting would take it off the QSOs that need it.
      return ref ? { refs: [{ type: REF_TYPE, ref }] } : null
    })
  },
}

/// `SAT SO-50` — the half a control cannot do.
///
/// A `loggingControls` selection writes its value and nothing else; a command
/// returns ACTIONS, so this is the only way to both name the bird and tune the
/// radio to its uplink in one move (§3.5, option C).
const SatCommand = {
  async interpret(
    { input, qso }: { input: string; operation?: Record<string, JSONValue>; qso?: Record<string, JSONValue> },
    ctx: HookContext,
  ): Promise<CommandInterpretation | null> {
    const match = /^SAT(?:\s+(.*))?$/i.exec(input.trim())
    if (!match) return null
    const t = tFor(ctx)

    const term = (match[1] ?? "").trim()
    if (!term) return { expectsParams: true, describe: t("commandExpects") }

    const all = await transponders()
    const upper = term.toUpperCase()
    // Exact transponder first, then the bird by name, then a name prefix — so
    // "SAT SO-50" works without knowing the frequency, and the one bird with
    // two transponders can still be named in full.
    const hit =
      all.find((tr) => tr.code.toUpperCase() === upper) ??
      all.find((tr) => tr.satName.toUpperCase() === upper) ??
      all.find((tr) => tr.satName.toUpperCase().startsWith(upper))

    if (!hit) return { error: t("commandUnknown", { name: term }) }

    // Merged, not replaced: `updateQso` writes whole fields, so returning a
    // bare refs list would drop the park or summit this QSO is also for.
    const others = ((qso?.refs ?? []) as Ref[]).filter((r) => r?.type !== REF_TYPE)
    const refs = [...others, { type: REF_TYPE, ref: hit.code }]

    const commands: Record<string, JSONValue>[] = [{ updateQso: { refs: refs as unknown as JSONValue } }]
    if (hit.uplinkKHz) {
      commands.unshift({
        setVfo: {
          freq: hit.uplinkKHz,
          // Only FM says anything about the mode; on a linear transponder the
          // operator picks, and overwriting their choice would be worse than
          // leaving it.
          ...(hit.uplinkMode ? { mode: hit.uplinkMode } : {}),
        } as unknown as JSONValue,
      })
    }

    return {
      describe: t("commandDescribe", { label: hit.label }),
      confirm: t("commandConfirm", { name: hit.satName }),
      commands: commands as unknown as CommandInterpretation["commands"],
    }
  },

  async catalog(ctx: HookContext): Promise<CommandCatalogEntry[]> {
    const t = tFor(ctx)
    return [
      {
        command: "SAT",
        params: t("catalogSatParams"),
        describe: t("catalogSat"),
        category: t("catalogCategory"),
        // Its commands are updateQso/setVfo, which only the logging panel's
        // dispatcher can apply — without an open operation they go nowhere.
        needsOperation: true,
        expectsParams: true,
        suggest: true,
      },
    ]
  },
}

/// AMSAT's active birds, republished by Ham2K in the shape app-polo reads: one
/// entry per satellite with parallel `uplinks`/`downlinks` arrays.
const satelliteDataFile: DataFileDefinition = {
  key: "satellite-data",
  name: (_args: Record<string, never>, ctx: HookContext) => tFor(ctx)("dataFileName"),
  description: (_args: Record<string, never>, ctx: HookContext) => tFor(ctx)("dataFileDescription"),
  url: "https://polo.ham2k.com/data/satellites.json",
  maxAgeInDays: 28,
  fetchType: "json",
  category: CATEGORY,
  jsonToLookupEntry: (entry: Record<string, any>) => {
    const name = textOf(entry?.name)
    if (!name) return null
    return {
      // One row per BIRD, with its transponders in `data` — a row per
      // transponder would sit closer to the 100-row query cap for no gain.
      key: name.toUpperCase(),
      name,
      subCategory: textOf(entry?.modulation) || undefined,
      flags: 1,
      data: entry,
    }
  },
}

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook(`ref:${REF_TYPE}`, { hook: refHandler, key: "satellites" })
    registerHook("activity", { hook: activityHook, key: "satellites" })
    registerHook("adifFields", { hook: adifFieldsHook, key: "satellites" })
    registerHook("adifImport", { hook: adifImportHook, key: "satellites" })
    registerHook("dataFile", { hook: satelliteDataFile, key: "satellite-data" })
    registerHook("command", { hook: SatCommand, key: "satellites-sat" })
    // No `scoring` and no `export`: nothing is activated and nothing is
    // counted, so there is no threshold to report and no per-reference file to
    // submit. app-polo registers neither either.
  },
})
