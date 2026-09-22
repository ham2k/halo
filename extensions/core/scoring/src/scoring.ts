// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Core scoring: duplicate detection, DXCC entities worked, and bands/modes
// worked. Ported from web-lofi's day-sectioning/handler-accumulation
// model, expressed as a `ContestScorer` (docs/design/contests.md §5.2) so it
// runs as an ordinary peer scorer alongside any contest rather than being the
// one hardcoded scorer. The per-QSO loop, day sectioning and the live path all
// come from the shared harness, which still makes one coarse bridge call
// (DESIGN.md §4: "score 500 QSOs in one call, not 500 calls").
//
// Its four rules are deliberately PRIVATE to the scoresheet. Contests don't
// share a rule vocabulary, so what leaves this module is only a merged per-QSO
// verdict (notices/alerts/points) plus summary tallies whose keys are this
// scorer's own — `qsoCount`, `dxcc`, `bandsAndModes`, `statesAndProvinces`.
//
// Which rules NOTIFY and which only tally is a deliberate split: a notice has
// to tell the operator something they can act on. Operation-level band/mode
// newness told them the log was empty, so it tallies silently; a state or an
// entity they haven't worked is worth a pill.
//
// `entityPrefixForCall`, the translator and the scoring harness all come in by
// relative path, not the `@ham2k/extension-sdk` alias, so this module's
// tests can run under plain `node --test` (which can't resolve that
// tsc/esbuild-only bare specifier). `index.ts` keeps the alias for
// `defineExtension` and is the one module the tests don't import.

import { entityPrefixForCall } from "../../../sdk/src/dxcc.ts"
import { createCachedTranslator, createTranslator } from "../../../sdk/src/i18n.ts"
import { canonicalMode, modesMatchForDupe } from "../../../sdk/src/modes.ts"
import { contestScorer } from "../../../sdk/src/scoring.ts"
import { fmtInteger } from "@ham2k/lib-format-tools"
import { DXCC_BY_PREFIX } from "@ham2k/lib-dxcc-data"
// Frequency-ordered, and the same list the runtime itself uses — the breakdown
// reads top-down like a band plan rather than in whatever order QSOs arrived.
import { EXTENDED_BANDS } from "@ham2k/lib-operation-data"
import type { ContestScorer, JSONValue, QsoScoreVerdict, ScoreTally } from "@ham2k/extension-sdk"

// User-visible tally labels; the per-locale catalogs live in
// i18n/<locale>.json (flat key → string maps). Singular/plural is
// picked with explicit ternaries in the summarize functions (not i18next's
// `count` pluralization, which needs Intl.PluralRules — absent in QuickJS).
import en from "./i18n/en.json" with { type: "json" }
import es from "./i18n/es.json" with { type: "json" }

type Translator = ReturnType<typeof createTranslator>

/// Translator for this extension's strings, cached per locale — `ctx.locale`
/// only changes when the app's locale setting does.
const tFor = createCachedTranslator({ en: { translation: en }, es: { translation: es } })

/// Everything the three rules accumulate. A type alias (not an interface) so it
/// stays assignable to `Scoresheet`; every field is JSON so the core can
/// snapshot it as a checkpoint.
export type CoreScoresheet = {
  /// call → "band|mode" combinations already worked with it (dupe detection).
  workedByCall: Record<string, string[]>
  /// DXCC entity prefix → contacts, and band/mode → contacts.
  entities: Record<string, number>
  bands: Record<string, number>
  modes: Record<string, number>
  qsos: number
  points: number
  duplicates: number
  /// Contacts that brought a band or a mode the operation hadn't worked yet.
  /// Counted rather than derived from `bands`/`modes` above, because a QSO that
  /// is new on BOTH axes still credits once.
  bandModeQsos: number
  /// Whether the mode tallies are already keyed as [canonicalMode] spells
  /// them. Absent on every checkpoint written before the tally folded — which
  /// is exactly the sheet that needs migrating — and set from then on, so the
  /// check costs one comparison per QSO instead of a walk of every band.
  foldedTallyKeys?: boolean
  /// band → mode → contacts, the per-band breakdown's own data. Kept beside
  /// the flat `bands`/`modes` counts rather than replacing them: those two
  /// answer "how many bands" without walking a matrix, and a QSO with a band
  /// but no mode belongs to its band's total while having no mode column.
  bandModes: Record<string, Record<string, number>>
  /// US states and Canadian provinces worked → contacts. Only accumulated when
  /// our own station is North American (see [tracksStatesAndProvinces]).
  states: Record<string, number>
  provinces: Record<string, number>
  /// Our own DXCC entity prefix and the station call it came from, resolved
  /// once and kept here so the fold doesn't re-annotate it per QSO. The call is
  /// stored WITH it because a checkpoint outlives the operation setup it was
  /// built from: correcting a station call (or a segment overriding it) has to
  /// re-derive the entity, or the own-entity rules stay pointed at the old one.
  /// `''` means "resolved to nothing"; `undefined` means "not resolved yet",
  /// which is also what a checkpoint predating these fields reads as.
  ourEntity?: string
  ourCall?: string
  /// Reset on each new UTC day — `qsoCount` is a per-day tally, while the
  /// entity and band/mode tallies deliberately carry across the operation.
  dayQsos: number
  dayPoints: number
  dayDuplicates: number
}

/// US states and Canadian provinces, ported from web-lofi's
/// `USStatesScoringHandler` / `CanadianProvincesScoringHandler`. DC is included
/// here where web-lofi's scorer omits it (its summarizer reads a `DC` bucket
/// its scorer could never fill) — a contact in the District is a place worked,
/// and the operator is the one who decides what it counts toward.
const US_STATES = new Set([
  "AL",
  "AK",
  "AZ",
  "AR",
  "CA",
  "CO",
  "CT",
  "DC",
  "DE",
  "FL",
  "GA",
  "HI",
  "ID",
  "IL",
  "IN",
  "IA",
  "KS",
  "KY",
  "LA",
  "ME",
  "MD",
  "MA",
  "MI",
  "MN",
  "MS",
  "MO",
  "MT",
  "NE",
  "NV",
  "NH",
  "NJ",
  "NM",
  "NY",
  "NC",
  "ND",
  "OH",
  "OK",
  "OR",
  "PA",
  "RI",
  "SC",
  "SD",
  "TN",
  "TX",
  "UT",
  "VT",
  "VA",
  "WA",
  "WV",
  "WI",
  "WY",
])

const CANADIAN_PROVINCES = new Set(["AB", "BC", "MB", "NB", "NL", "NS", "NT", "NU", "ON", "PE", "QC", "SK", "YT"])

/// COUNTRY-FILE entity prefixes whose stations have a state or province, not
/// what a ham would write: Alaska is `KL`, not `KL7` (the same correction
/// `extensions/contests/naqp/src/exchange.ts` documents). Hawaii and Alaska are
/// their own DXCC entities, so a station there carries no `state` of its own —
/// the entity IS the answer, which is why they get defaults below.
const US_ENTITIES = new Set(["K", "KL", "KH6"])
const STATE_DEFAULT_BY_ENTITY: Record<string, string> = { KH6: "HI", KL: "AK" }

/// Whether states and provinces are worth tracking for THIS operator: a rule
/// about our own station, not the one being worked. Both lists then apply to
/// either — a US operator working VE3 is told it's a new province.
function tracksStatesAndProvinces(ourEntity: string | undefined): boolean {
  return ourEntity === "VE" || US_ENTITIES.has(ourEntity ?? "")
}

function str(value: JSONValue | undefined): string | undefined {
  return typeof value === "string" && value.length > 0 ? value : undefined
}

/// The mode half of a `band|mode` entry in `workedByCall`. Split on the FIRST
/// separator: a band name carries none, a mode string is not guaranteed to.
function modeOfCombo(combo: string): string {
  return combo.slice(combo.indexOf("|") + 1)
}

/// The state or province of the station being worked, or undefined when it has
/// none, isn't North American, or hasn't been resolved yet.
///
/// A station's own `state` wins over the lookup's `guess.state` (the operator
/// typed or received it), matching NAQP's `guessedLocation`. Anything not on
/// the two lists comes back EMPTY rather than as itself: a county, a Mexican
/// state or a country-file artifact must never open a bucket in a tally the
/// operator reads as "states worked".
function stateOrProvinceOf(their: Record<string, JSONValue>, entityPrefix: string | undefined): { kind: "state" | "province"; code: string } | undefined {
  if (!entityPrefix) return undefined
  const guess = (their.guess as Record<string, JSONValue>) ?? {}
  const code = (str(their.state) ?? str(guess.state) ?? STATE_DEFAULT_BY_ENTITY[entityPrefix] ?? "").toUpperCase()
  if (!code) return undefined
  if (US_ENTITIES.has(entityPrefix) && US_STATES.has(code)) return { kind: "state", code }
  if (entityPrefix === "VE" && CANADIAN_PROVINCES.has(code)) return { kind: "province", code }
  return undefined
}

export const CoreScorer: ContestScorer<CoreScoresheet> = {
  startScoresheet(): CoreScoresheet {
    return {
      workedByCall: {},
      entities: {},
      bands: {},
      modes: {},
      bandModes: {},
      states: {},
      provinces: {},
      qsos: 0,
      points: 0,
      duplicates: 0,
      bandModeQsos: 0,
      foldedTallyKeys: true,
      dayQsos: 0,
      dayPoints: 0,
      dayDuplicates: 0,
    }
  },

  // Mutates and returns the scoresheet it's given, which the contract
  // explicitly allows: spreading the worked-call map per QSO made a full pass
  // quadratic (289ms for 5,000 QSOs against 18ms for 1,000). The harness copies
  // any resume checkpoint at its boundary, so nothing cached is ever aliased.
  scoreQso({ scoresheet, qso, operation, isNewDay }) {
    const base = scoresheet
    if (isNewDay) {
      base.dayQsos = 0
      base.dayPoints = 0
      base.dayDuplicates = 0
    }

    // A cached checkpoint predating rule 4 carries neither our entity nor the
    // place maps. Filled in here rather than in `startScoresheet`, which a
    // resumed fold never calls: reading `base.states` unguarded throws, and
    // scoring runs on every keystroke.
    const stationCall = str(operation?.stationCall) ?? ""
    if (base.ourEntity === undefined || base.ourCall !== stationCall) {
      base.ourCall = stationCall
      base.ourEntity = entityPrefixForCall(stationCall) ?? ""
    }
    base.states ??= {}
    base.provinces ??= {}
    base.bandModes ??= {}
    base.bands ??= {}
    base.modes ??= {}
    if (base.foldedTallyKeys !== true) {
      foldTallyKeys(base)
      base.foldedTallyKeys = true
    }

    const their = (qso.their as Record<string, JSONValue>) ?? {}
    const call = str(their.call)
    if (!call) return { scoresheet: base, score: { value: 0 } }

    const band = str(qso.band) ?? ""
    const mode = str(qso.mode) ?? ""
    // What the band/mode TALLIES key on — one spelling per emission, so a log
    // holding both `USB` and `SSB` reports one mode worked rather than two.
    // Not what `workedByCall` stores: that keeps the mode as logged, and the
    // duplicate rule reads it through `modesMatchForDupe`, which folds further
    // than this does.
    const tallyMode = canonicalMode(mode)
    const bandMode = `${band}|${mode}`
    const prior = base.workedByCall[call] ?? []

    // --- Rule 1: duplicate contacts ---------------------------------------
    // Not a string comparison against `bandMode`: the two sides spell the mode
    // at whatever resolution they were logged or spotted at, and `SSB` and
    // `USB` are one emission — see [modesMatchForDupe].
    const sameMode = (combo: string) => modesMatchForDupe(modeOfCombo(combo), mode)
    const isDupe = prior.some((combo) => combo.startsWith(`${band}|`) && sameMode(combo))

    const notices = new Set<string>()
    const alerts = new Set<string>()
    if (isDupe) {
      alerts.add("duplicate")
    } else if (prior.length > 0) {
      // Worked before, but not on this combination — worth calling out.
      if (!prior.some(sameMode)) notices.add("newMode")
      if (!prior.some((combo) => combo.startsWith(`${band}|`))) notices.add("newBand")
    }

    // --- Rule 2: DXCC entities worked --------------------------------------
    // Our own entity still counts toward the tally — it is a worked entity like
    // any other — but never notifies: "new DXCC" for the country you are
    // sitting in is noise on the first local contact of every operation.
    const entityPrefix = entityPrefixForCall(call)
    const isNewEntity = Boolean(entityPrefix) && base.entities[entityPrefix!] === undefined
    if (isNewEntity && entityPrefix !== base.ourEntity) notices.add("newDXCC")

    // --- Rule 3: bands and modes worked ------------------------------------
    // A TALLY ONLY. Operation-level newness deliberately does not notify: the
    // first QSO of an operation is new on every axis, so it lit up "new band ·
    // new mode" for a station nobody had worked yet, which told the operator
    // nothing. `newBand`/`newMode` come from rule 1 alone — a station already
    // in this log, now on a band or mode we hadn't worked THEM on.
    // Read BEFORE recording below, or the QSO would mask itself.
    const isNewBand = Boolean(band) && base.bands[band] === undefined
    const isNewMode = Boolean(tallyMode) && base.modes[tallyMode] === undefined
    // Credits once for a QSO that is new on either axis — a first 15m contact
    // counts even when its mode was already worked. Never a duplicate, which
    // by rule 1 brought nothing: that rule folds modes FURTHER than the tally
    // does, so a station worked on `FT4` and duplicated on `MFSK` reaches here
    // with a key the tally has never seen and would otherwise be credited for
    // bringing it.
    const broughtBandOrMode = !isDupe && (isNewBand || isNewMode)

    // --- Rule 4: states and provinces worked -------------------------------
    // Scoped to North American operators (rule 3's tally-only treatment does
    // not apply here: a state IS the kind of newness worth a pill). Our own
    // state notifies like any other — it is a WAS credit, where our own DXCC
    // entity is never a DX one.
    const stateWorked = tracksStatesAndProvinces(base.ourEntity) ? stateOrProvinceOf(their, entityPrefix) : undefined
    if (stateWorked?.kind === "state" && base.states[stateWorked.code] === undefined) notices.add("newState")
    if (stateWorked?.kind === "province" && base.provinces[stateWorked.code] === undefined) notices.add("newProvince")

    // A dupe is by definition neither a new band, a new mode, nor a new
    // entity — it contributes nothing, so it carries only its alert.
    if (isDupe) notices.clear()

    const score: QsoScoreVerdict = { value: isDupe ? 0 : 1 }
    if (isDupe) score.dupe = true
    if (notices.size > 0) score.notices = [...notices]
    if (alerts.size > 0) score.alerts = [...alerts]

    const points = score.value
    if (!isDupe) {
      if (prior.length > 0) prior.push(bandMode)
      else base.workedByCall[call] = [bandMode]
    }
    if (entityPrefix) base.entities[entityPrefix] = (base.entities[entityPrefix] ?? 0) + 1
    if (band) base.bands[band] = (base.bands[band] ?? 0) + 1
    // Keyed on `tallyMode`, so guarded on it too: `str` does not trim, so a
    // mode of whitespace alone is truthy and canonicalizes to nothing, and a
    // nameless key is a phantom mode in the count and a blank entry in the
    // breakdown.
    if (tallyMode) base.modes[tallyMode] = (base.modes[tallyMode] ?? 0) + 1
    if (band && tallyMode) {
      const byMode = (base.bandModes[band] ??= {})
      byMode[tallyMode] = (byMode[tallyMode] ?? 0) + 1
    }
    if (stateWorked?.kind === "state") base.states[stateWorked.code] = (base.states[stateWorked.code] ?? 0) + 1
    if (stateWorked?.kind === "province") {
      base.provinces[stateWorked.code] = (base.provinces[stateWorked.code] ?? 0) + 1
    }
    base.qsos += 1
    base.points += points
    base.duplicates += isDupe ? 1 : 0
    base.bandModeQsos += broughtBandOrMode ? 1 : 0
    base.dayQsos += 1
    base.dayPoints += points
    base.dayDuplicates += isDupe ? 1 : 0

    return { scoresheet: base, score }
  },

  summarizeScore({ scoresheet, scope }, ctx): Record<string, ScoreTally> {
    const t = tFor(ctx)
    const isDay = scope === "day"
    const places = summarizeStatesAndProvinces(scoresheet, t)
    return {
      qsoCount: summarizeQsoCount(scoresheet, scope === "day", t),
      dxcc: summarizeDxcc(scoresheet, t),
      // Omitted entirely rather than shown empty: an operator outside North
      // America never tracks these, and a badge with no label is a puzzle.
      // Ordered before bandsAndModes: display reads DXCC, then states, then
      // bands (scoring_summaries.dart/information_panel.dart follow this
      // object's own key order).
      ...(places ? { statesAndProvinces: places } : {}),
      bandsAndModes: summarizeBandsAndModes(scoresheet, t, isDay),
    }
  },
}

/// Per-day, matching web-lofi: the QSO count restarts each calendar day while
/// the entity and band/mode tallies below carry across the whole operation.
function summarizeQsoCount(sheet: CoreScoresheet, isDay: boolean, t: Translator): ScoreTally {
  const total = isDay ? sheet.dayPoints : sheet.points
  return {
    key: "qsoCount",
    for: isDay ? "day" : "operation",
    icon: "radio",
    total,
    count: isDay ? sheet.dayQsos : sheet.qsos,
    duplicates: isDay ? sheet.dayDuplicates : sheet.duplicates,
    label: total === 1 ? t("oneQso") : t("manyQsos", { formatted: fmtInteger(total) }),
    summary: fmtInteger(total),
  }
}

function summarizeDxcc(sheet: CoreScoresheet, t: Translator): ScoreTally {
  const count = Object.keys(sheet.entities).length
  return {
    key: "dxcc",
    for: "operation",
    icon: "earth",
    total: count,
    entities: sheet.entities,
    label: count === 1 ? t("oneDxccEntity") : t("manyDxccEntities", { formatted: fmtInteger(count) }),
    // Below five entities the number is noise next to the QSO count.
    summary: count >= 5 ? fmtInteger(count) : "",
    ...(count > 0 ? { longSummary: dxccBreakdown(sheet.entities) } : {}),
  }
}

/// Flag, name and (when worked more than once) contact count for every entity
/// worked, busiest first. `\u00A0` inside an entry keeps its flag/name/count
/// together on wrap; the plain space between entries is where the markdown
/// renderer is free to break the line.
///
/// `entityPrefixForCall` resolves against the BIGCTY country file;
/// `DXCC_BY_PREFIX` is `@ham2k/lib-dxcc-data`'s own, separately-maintained
/// table. Nothing enforces the two agree, so a prefix the first produces and
/// the second has never heard of falls back to the bare prefix rather than
/// vanishing — the row count here must always match `dxcc`'s own `total`.
export function dxccBreakdown(entities: Record<string, number>): string {
  return Object.keys(entities)
    .sort((a, b) => entities[b] - entities[a])
    .map((prefix) => {
      const entity = DXCC_BY_PREFIX[prefix]
      const count = entities[prefix]
      const countTxt = count > 1 ? `\u00A0(${fmtInteger(count)})` : ""
      const label = entity ? `${entity.flag}\u00A0${entity.name.split(" ").join("\u00A0")}` : prefix
      return `${label}${countTxt}`
    })
    .join(" ")
}

/// A mode tally re-keyed through [canonicalMode], merging the counts that
/// land together. The scoresheet is already tallied that way, so this is for
/// the ones that are NOT: a checkpoint written by a build that keyed on the
/// raw mode persists in the operation's local data and is resumed from as-is,
/// and would otherwise keep reporting `USB` and `SSB` as two modes worked
/// until something forced a full rescore.
function foldedModeTally(modes: Record<string, number> | undefined): Record<string, number> {
  const folded: Record<string, number> = {}
  for (const [mode, count] of Object.entries(modes ?? {})) {
    const key = canonicalMode(mode)
    // A checkpoint can hold a nameless key — a mode of whitespace alone was
    // tallied as itself before the write guard keyed on the canonical value.
    // Dropped rather than carried: it counts as a mode worked and renders as
    // a blank entry in the breakdown.
    if (!key) continue
    folded[key] = (folded[key] ?? 0) + count
  }
  return folded
}

/// Re-keys a resumed checkpoint's mode tallies in place, so the accumulator
/// agrees with what [foldedModeTally] renders. A sheet cached by a build that
/// tallied the mode as logged carries `USB` and `SSB` as separate keys, and
/// `isNewMode` reading one of those finds no key for the next contact on the
/// other spelling — crediting it as having brought a mode the operation had
/// already worked, and leaving both keys in the checkpoint from then on.
///
/// Runs once, gated on [CoreScoresheet.foldedTallyKeys], because a resumed fold
/// never calls `startScoresheet` and this walks every band's modes — per QSO
/// that costs about a third of the whole pass, on a loop that runs in QuickJS
/// on every keystroke.
///
/// Migrates the KEYS, not the counters derived from them: `bandModeQsos` was
/// accumulated against the unfolded keys and may credit a contact for bringing
/// a mode that, folded, was already worked. Nothing here can tell which
/// contact that was — only a full rescore can, and the number is a running
/// total by design.
function foldTallyKeys(base: CoreScoresheet): void {
  if (Object.keys(base.modes).some((mode) => canonicalMode(mode) !== mode)) {
    base.modes = foldedModeTally(base.modes)
  }
  for (const band of Object.keys(base.bandModes)) {
    const byMode = base.bandModes[band]
    if (Object.keys(byMode).some((mode) => canonicalMode(mode) !== mode)) {
      base.bandModes[band] = foldedModeTally(byMode)
    }
  }
}

function summarizeBandsAndModes(sheet: CoreScoresheet, t: Translator, isDay: boolean): ScoreTally {
  const bandCount = Object.keys(sheet.bands).length
  const modes = foldedModeTally(sheet.modes)
  const modeCount = Object.keys(modes).length
  const parts: string[] = []
  if (bandCount > 0) parts.push(bandCount === 1 ? t("oneBand") : t("manyBands", { n: bandCount }))
  if (modeCount > 0) parts.push(modeCount === 1 ? t("oneMode") : t("manyModes", { n: modeCount }))
  return {
    key: "bandsAndModes",
    for: "operation",
    icon: "antenna",
    // Contacts that brought something new, not `bandCount + modeCount` — a QSO
    // new on both axes credits once.
    total: sheet.bandModeQsos,
    bands: sheet.bands,
    modes,
    label: parts.join(", "),
    // Operation scope only. `bands`/`bandModes` carry across the whole
    // operation (`for: 'operation'` says so), so a breakdown attached to a day
    // section would read as that day's while holding operation-to-date numbers.
    ...(isDay ? {} : { longSummary: bandBreakdown(sheet) }),
  }
}

/// One line per band WORKED, in band-plan order: the band's contacts, then how
/// they split across modes, busiest first. Deliberately no row for a band that
/// was never worked — this is a record of an operation, not a checklist.
///
/// A band's total is CONTACTS LOGGED on it — duplicates included, matching the
/// stats block's own QSO count rather than the score, which drops them. It also
/// counts any contact with no mode at all, which has no mode column to sit in,
/// so the mode numbers need not add up to the total. Rendered as markdown by
/// the information panel, which joins these single newlines with
/// `softLineBreak`.
function bandBreakdown(sheet: CoreScoresheet): string {
  const worked = Object.keys(sheet.bands ?? {})
  // A band the lib doesn't list still gets a row, after the ones it does —
  // dropping a worked band would silently under-report the operation.
  // The lib types its list as a union of the band names it knows, which a
  // log's free-form band string is not — compared as plain strings here.
  const bandPlanOrder: string[] = [...EXTENDED_BANDS]
  const ordered = [...bandPlanOrder.filter((band) => worked.includes(band)), ...worked.filter((band) => !bandPlanOrder.includes(band)).sort()]

  return ordered
    .map((band) => {
      const total = fmtInteger(sheet.bands[band] ?? 0)
      const byMode = Object.entries(foldedModeTally(sheet.bandModes?.[band]))
        // Count first, then mode name — so two modes tied at 3 don't swap
        // places between renders of the same log.
        .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
        .map(([mode, count]) => `${mode} ${fmtInteger(count)}`)
      return byMode.length > 0 ? `**${band}**: ${total} — ${byMode.join(", ")}` : `**${band}**: ${total}`
    })
    .join("\n")
}

/// Undefined until something has actually been worked, which for a DX operator
/// is never — [tracksStatesAndProvinces] gates the accumulation, so the empty
/// case and the not-applicable case are the same thing here.
function summarizeStatesAndProvinces(sheet: CoreScoresheet, t: Translator): ScoreTally | undefined {
  const stateCount = Object.keys(sheet.states ?? {}).length
  const provinceCount = Object.keys(sheet.provinces ?? {}).length
  if (stateCount === 0 && provinceCount === 0) return undefined

  const parts: string[] = []
  if (stateCount > 0) parts.push(stateCount === 1 ? t("oneState") : t("manyStates", { n: stateCount }))
  if (provinceCount > 0) {
    parts.push(provinceCount === 1 ? t("oneProvince") : t("manyProvinces", { n: provinceCount }))
  }

  const grids: string[] = []
  if (stateCount > 0) grids.push(placesGrid(US_STATES, sheet.states))
  if (provinceCount > 0) grids.push(placesGrid(CANADIAN_PROVINCES, sheet.provinces))

  return {
    key: "statesAndProvinces",
    for: "operation",
    icon: "star",
    // Places worked, not contacts: unlike `bandsAndModes` there is no
    // "credits once" subtlety, since a QSO has one state at most.
    total: stateCount + provinceCount,
    states: sheet.states,
    provinces: sheet.provinces,
    label: parts.join(", "),
    // A day header renders a tally only when it has BOTH an icon and a
    // non-empty summary, so the threshold is what decides whether this shows
    // there at all. Below five places the number is noise next to the QSO
    // count, same judgement `dxcc` makes.
    summary: stateCount + provinceCount >= 5 ? fmtInteger(stateCount + provinceCount) : "",
    longSummary: grids.join("\n\n"),
    grid: true,
  }
}

/// A checklist of every code in `all`, worked ones struck through and bold so
/// the whole grid reads at a glance as what is done versus what is still
/// open, not just a count.
function placesGrid(all: Set<string>, worked: Record<string, number>): string {
  return [...all].map((code) => (worked[code] ? `**~~${code}~~**` : code)).join("  ")
}

/// The registrable hook. `scope: 'always'` — core scoring applies to every
/// operation, contest or not, and keeps running alongside any contest scorer.
export const coreScoringHook = contestScorer(CoreScorer, { scope: "always" })

/// Named exports so tests (and any caller) can drive either path directly.
export const scoreQsos = coreScoringHook.scoreQsos
export const scoreQso = coreScoringHook.scoreQso!
