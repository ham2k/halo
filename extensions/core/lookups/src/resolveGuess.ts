// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The definitive account of the other station: every lookup source's answer,
// the contact's own references, and what the operator entered, settled once,
// here, so that every reader can take `their.guess` as it stands rather than
// re-deciding which of its fields to trust (docs/design/locations.md, "The
// invariant").
//
// Pure, and run over results already fetched — the live lookup ends with it,
// and so does `resolveCallInfo`, which replays a saved contact's stored
// `lookups[]` without going to the network.

import { locationToGrid6 } from "@ham2k/lib-geo-tools"
import type { CallInfo, CallInfoLookup } from "@ham2k/extension-sdk"

import { gridCell, isPlaceholderLocation } from "../../adif/src/grid.ts"
import { annotateCallsign } from "./annotate.ts"
import { LOCATION_FIELDS, preferStationValues, runLookupPipeline } from "./mergeLookup.ts"

type Fields = Record<string, unknown>

/// The source name the annotation pre-step files its own entry under.
export const ANNOTATION_SOURCE = "callsign-annotation"

/// The source name a stored guess is filed under when a contact has no
/// `lookups[]` to replay — one app-polo logged, or an import.
export const STORED_GUESS_SOURCE = "stored-guess"

/// [lookups] (as fetched, in fold order, the annotation entry included or
/// not) settled into one guess for the contact [qso] describes.
///
/// A source that answers about the CALLSIGN (`scope` other than `qso`: QRZ,
/// the Ham2K lookup, the log's own history) describes where the license is
/// registered, which is where the station is only when nothing says it is
/// elsewhere. Its location is dropped, its name and the rest kept, when:
///
///  - the call says the station is away — `/P`, `/M`, `/AM`, `/MM`, or a
///    call-area digit (`locationScope: 'portable'` from the annotation);
///  - the call is prefixed (`EA3/KI2D`) and the source answered for the base
///    call: a profile filed under the full prefixed call is about that
///    operation, the base call's is about home (app-polo's rule);
///  - one of the contact's references has a location — a park, a summit,
///    or just the state one lies in — whether the QSO ref carries it
///    (`decorateRef`) or a `qso`-scope source answered with it for a ref the
///    contact still has (a source named for the ref's type).
///
/// A LARGE-AREA reference (a long trail, a park across several states) says
/// the station is away all the same, but where on it is anyone's guess: its
/// point is only representative, and it lies in no one state. So it places
/// nothing — neither its own point nor its program's answer for it (a source
/// named for the ref's type, or an answer marked `largeArea`) — as on the
/// operation side (location_from_refs.dart).
///
/// What the operator entered goes on last ([applyEntered]).
export function resolveGuess(call: string, lookups: CallInfoLookup[], qso: Fields): CallInfo {
  const annotation = annotateCallsign(call)
  const refs = qsoRefs(qso)
  const refTypes = new Set(refs.map((ref) => text(ref.type)))
  const largeAreaTypes = new Set(refs.filter((ref) => ref.largeArea === true).map((ref) => text(ref.type)))
  // An answer about the contact is about one of its references; one stored
  // for a reference since removed describes nowhere this contact went, and
  // takes no part — not even its scope, which would still clear the rest.
  const answers = lookups.filter((lookup) => lookup.source !== ANNOTATION_SOURCE && (lookup.scope !== "qso" || refTypes.has(text(lookup.source))))
  const fromRefs = refs
    .filter((ref) => ref.largeArea !== true)
    .map((ref) => refAnswer(call, ref))
    .filter((answer): answer is CallInfoLookup => answer !== undefined)

  const placesNothing = (answer: CallInfoLookup): boolean => (answer as Fields).largeArea === true || largeAreaTypes.has(text(answer.source))
  const placedByRef =
    refs.some((ref) => ref.largeArea === true || refHasLocation(ref)) ||
    answers.some((answer) => answer.scope === "qso" && ((answer as Fields).largeArea === true || carriesLocation(answer)))
  const keepsLocation = (answer: CallInfoLookup): boolean => {
    if (answer.scope === "qso") return !placesNothing(answer)
    if (answer.source === STORED_GUESS_SOURCE) return true
    if (placedByRef || annotation.locationScope === "portable") return false
    if (annotation.locationScope === "prefixed") return sameCall(answer.call, call)
    return true
  }

  // A stored guess merges at the call's own scope — settled already, its
  // location is no home address for a portable call's scope to turn away.
  const asFolded = (answer: CallInfoLookup): CallInfoLookup =>
    answer.source === STORED_GUESS_SOURCE ? { ...answer, locationScope: answer.locationScope ?? annotation.locationScope } : answer
  const folded = [annotation, ...answers.map((answer) => (keepsLocation(answer) ? asFolded(answer) : withoutLocation(answer))), ...fromRefs]
  const merged = runLookupPipeline({ call }, folded).guess
  return applyEntered(preferStationValues(merged, annotation, answers), asFields(qso.their))
}

/// [guess] with the operator's own entries on the other station's location
/// laid over it, as one group — a field-by-field merge would put the
/// lookup's square under the operator's corrected state.
///
///  - An entered coordinate is the location; its grid is the entered one, or
///    derived from it.
///  - An entered grid replaces the lookup's square and drops its coordinate,
///    which would otherwise outrank the square everywhere it is read.
///  - An entered state that DISAGREES with the lookup's says the lookup's
///    address is wrong, so its whole location goes and the state stands
///    alone (the country stays: the call establishes that). One that matches
///    confirms the lookup, and one beside a lookup that named no state has
///    nothing to contradict — the lookup's precision stays in both cases.
export function applyEntered(guess: CallInfo, their: Fields): CallInfo {
  const next = { ...guess } as Fields
  const state = text(their.state)
  const lookupState = text(next.state)
  if (state !== undefined) {
    if (lookupState !== undefined && lookupState.toUpperCase() !== state.toUpperCase()) {
      for (const field of LOCATION_FIELDS) if (field !== "country") delete next[field]
    }
    next.state = state
  }

  const pair = coordinate(their)
  const grid = gridCell(their.grid) ? text(their.grid) : undefined
  if (pair !== undefined || grid !== undefined) {
    delete next.lat
    delete next.lon
    delete next.locSource
    next.grid = grid ?? locationToGrid6(pair!.lat, pair!.lon)
    if (pair !== undefined) {
      next.lat = pair.lat
      next.lon = pair.lon
    }
  }
  return next as CallInfo
}

/// The lookup entry a contact's stored [guess] stands as when it has no
/// `lookups[]` of its own. Already settled where it was written — app-polo
/// sets a portable call's home address aside and places a hunted park or
/// summit the same way — so only what the operator entered goes over it: the
/// away rules would strip a summit's square from a `/P` chase whose ref
/// carries no location of its own.
export function storedGuessLookup(guess: Fields): CallInfoLookup {
  return { ...guess, source: STORED_GUESS_SOURCE, scope: "general" } as unknown as CallInfoLookup
}

/// The contact's references — the entries that name one (`ref`). A
/// contest's exchange rides `refs` too, as `{type, <field>: value}` with no
/// `ref`; a VHF contest's `grid` there is the exchange the lookup itself
/// prefilled, and must not overrule the lookup it came from.
function qsoRefs(qso: Fields): Fields[] {
  if (!Array.isArray(qso.refs)) return []
  return qso.refs.filter((ref): ref is Fields => typeof ref === "object" && ref !== null && !Array.isArray(ref) && text((ref as Fields).ref) !== undefined)
}

function refHasLocation(ref: Fields): boolean {
  return coordinate(ref) !== undefined || gridCell(ref.grid) !== undefined || text(ref.state) !== undefined
}

/// What a located reference says about where the station is, as a `qso`-scope
/// answer — its point, and the state it lies in where it names one (app-polo
/// reads `ref.state` the same way). Folded after every source, so a source
/// answering for the same reference (POTA's park database, SOTA's summit
/// list) keeps the place it already gave.
function refAnswer(call: string, ref: Fields): CallInfoLookup | undefined {
  const pair = coordinate(ref)
  const grid = gridCell(ref.grid) ? text(ref.grid) : undefined
  const state = text(ref.state)
  if (pair === undefined && grid === undefined && state === undefined) return undefined
  return {
    call,
    source: `ref:${text(ref.type) ?? ""}`,
    scope: "qso",
    locationScope: "portable",
    ...(pair !== undefined || grid !== undefined ? { grid: grid ?? locationToGrid6(pair!.lat, pair!.lon) } : {}),
    ...(pair !== undefined ? { lat: pair.lat, lon: pair.lon } : {}),
    ...(state !== undefined ? { state } : {}),
  } as CallInfoLookup
}

function carriesLocation(answer: CallInfoLookup): boolean {
  const fields = answer as Fields
  return LOCATION_FIELDS.some((field) => field !== "country" && text(fields[field]) !== undefined) || coordinate(fields) !== undefined
}

function withoutLocation(answer: CallInfoLookup): CallInfoLookup {
  const next = { ...answer } as Fields
  for (const field of LOCATION_FIELDS) if (field !== "country") delete next[field]
  delete next.locAccuracy
  delete next.largeArea
  return next as CallInfoLookup
}

/// A usable coordinate on [fields]: both halves numbers, not a placeholder,
/// and not a country-file centroid (`locSource: 'prefix'`, which app-polo
/// spreads onto `their` itself — see halo_core's `locationFromGuess`).
function coordinate(fields: Fields): { lat: number; lon: number } | undefined {
  const { lat, lon } = fields
  if (fields.locSource === "prefix") return undefined
  if (typeof lat !== "number" || typeof lon !== "number" || !Number.isFinite(lat) || !Number.isFinite(lon)) return undefined
  if (Math.abs(lat) > 90 || Math.abs(lon) > 180 || isPlaceholderLocation(lat, lon)) return undefined
  return { lat, lon }
}

function sameCall(a: unknown, b: string): boolean {
  return typeof a === "string" && a.trim().toUpperCase() === b.trim().toUpperCase()
}

function text(value: unknown): string | undefined {
  if (typeof value !== "string") return undefined
  const trimmed = value.trim()
  return trimmed === "" ? undefined : trimmed
}

function asFields(value: unknown): Fields {
  return typeof value === "object" && value !== null && !Array.isArray(value) ? (value as Fields) : {}
}
