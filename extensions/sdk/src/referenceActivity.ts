// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The plain reference-award activity: a program that is a list of places with
// codes, activated by working people from one, with no API of its own beyond a
// downloadable list. Castles, lighthouses, mills, silos, towers — app-polo has
// a dozen and they differ only in the regex, the list, and how many contacts
// activate a reference. Their extensions are otherwise the same file copied.
//
// So this builds the hooks from a config, and each extension supplies the
// config plus its own `dataFile` (the one genuinely per-program part: every
// list has its own shape). POTA and SOTA deliberately do NOT use this — they
// have live APIs, spot feeds, accounts and n-fers, and hand-written is the
// honest way to say so.
//
// Scoring and exports are separate factories the extension composes itself
// (`activityScorer`, `activityExportHook`), because not every program has
// either: PGA scores nothing at all in app-polo.
//
// Types and helpers come in by relative path, not the
// `@ham2k/halo-extension-sdk` alias, so this module's tests can run under plain
// `node --test` — the constraint dxcc.ts and scoring.ts document.

import { distanceOnEarth } from "@ham2k/lib-geo-tools"

import type {
  ActivitySuggestion,
  HookContext,
  JSONValue,
  LookupRow,
  Ref,
  SuggestArgs,
  TitleSuggestion,
} from "./types.ts"

/// The SDK barrel re-exports this module, so a static import of `host` from it
/// would be circular. Imported once on first use, then cached by the module
/// system — the same dance activityExports.ts does for `hooks`.
async function hostApi() {
  const { host } = await import("@ham2k/halo-extension-sdk")
  return host
}

/// Nearby suggestions use a bounding box, not a radius — `dbLookupSelectByLocation`
/// is a rectangular query. Results get a real distance afterwards and are
/// ranked by it, the same trade-off POTA's own suggestions make.
const NEARBY_DELTA = 1.5
const MAX_SUGGESTIONS = 30

export interface ReferenceActivityConfig {
  /// The extension key. Namespaces the control key (`wca/activation`), which
  /// is what makes `wca:` scoping work in the activity search.
  key: string
  /// Short program name, shown on the control and written to ADIF's MY_SIG —
  /// 'WCA', 'BLHA'.
  label: string
  /// The ref type an operation carries while activating ('wcaActivation').
  activationType: string
  /// What a reference looks like. Anchored and matched case-insensitively.
  referenceRegex: RegExp
  icon?: string
  color?: string
  /// Placeholder for the reference field — 'ON-00558'.
  placeholder?: string
  /// The `lookups` category this program's data file writes into. Defaults to
  /// the extension key.
  category?: string
  /// The extension's own translator (its `tFor`). The factory looks up a fixed
  /// vocabulary, so every program using it must define the same keys:
  /// `invalidReference`, `unknownReference`, `activationControl`.
  tFor: (ctx: { locale?: string }) => (key: string) => string
  /// The program name written to ADIF's MY_SIG. Defaults to `label` — set it
  /// where the award and the ADIF program differ.
  adifProgram?: string
  /// Whether the program recognises several references activated at once.
  /// Defaults to false; none of the simple awards allow it.
  allowsMultiple?: boolean
}

function normalize(ref: string | undefined): string {
  return (ref ?? '').toUpperCase().trim()
}

function refsOfType(container: Record<string, unknown>, type: string): Ref[] {
  return (((container.refs as Ref[] | undefined) ?? [])).filter((r) => r.type === type && r.ref)
}

/// How well a row answers the search, so the core can rank across programs.
/// Same ladder POTA uses.
function relevanceForMatch(row: LookupRow, searchTerm?: string): number {
  if (!searchTerm) return 1
  const term = searchTerm.toUpperCase()
  const key = row.key.toUpperCase()
  const name = (row.name ?? '').toUpperCase()
  if (key === term) return 1
  if (name.startsWith(term)) return 0.9
  if (key.includes(term)) return 0.85
  if (name.includes(term)) return 0.7
  return 0.6
}

export interface ReferenceActivityHooks {
  refHandler: Record<string, unknown>
  activityHook: Record<string, unknown>
  adifFieldsHook: Record<string, unknown>
}

export function referenceActivity(config: ReferenceActivityConfig): ReferenceActivityHooks {
  const category = config.category ?? config.key
  const program = config.adifProgram ?? config.label
  const allowsMultiple = config.allowsMultiple ?? false

  /// A reference as the local list knows it. Everything here is offline: unlike
  /// POTA these programs have no per-reference API, so an unknown code stays
  /// unknown until the list is refreshed.
  async function lookupReference(ref: string): Promise<LookupRow | null> {
    const host = await hostApi()
    try {
      return await host.dbLookupSelectOne(category, ref)
    } catch (e) {
      host.log(`${config.key}: database lookup failed for ${ref}: ${e}`)
      return null
    }
  }

  function decorate(ref: Ref, reference: string, row: LookupRow | null, unknown: string): Ref {
    if (!row?.name) return { ...ref, ref: reference, name: unknown, program }
    const data = (row.data ?? {}) as Record<string, any>
    return {
      ...ref,
      ref: reference,
      name: row.name,
      grid: data.grid,
      location: data.location,
      program,
      label: `${config.label} ${reference}: ${row.name}`,
      shortLabel: `${config.label} ${reference}`,
    }
  }

  const refHandler = {
    async validateRef({ ref }: { ref: Ref }, _ctx: HookContext) {
      const normalized = normalize(ref.ref)
      return { valid: config.referenceRegex.test(normalized), normalized }
    },

    async decorateRef({ ref }: { ref: Ref }, ctx: HookContext): Promise<Ref> {
      const t = config.tFor(ctx)
      const reference = normalize(ref.ref)
      if (!config.referenceRegex.test(reference)) {
        return { ...ref, ref: reference, name: t('invalidReference') }
      }
      return decorate(ref, reference, await lookupReference(reference), t('unknownReference'))
    },

    /// Titles ANY reference type this handler was registered for, rather than
    /// only `config.activationType`. These programs have no hunting side, so
    /// every type they register is an activation and every one of them means
    /// "the operation is happening here".
    ///
    /// Checking the type would be actively wrong: `wca` also registers for
    /// `ecaActivation` and `bcaActivation` (English and Belgian castles ARE WCA
    /// references), title dispatch resolves to a SINGLE hook, and WCA wins it by
    /// registration order — so a type check silently costs those two activities
    /// their "at ON-00558" whenever WCA is enabled alongside them. `decorateRef`
    /// above never checked the type either; this makes the pair consistent.
    async suggestOperationTitle({ ref }: { ref: Ref }, _ctx: HookContext): Promise<TitleSuggestion | null> {
      if (!ref.ref) return null
      return { at: ref.ref, subtitle: ref.name }
    },
  }

  const activityHook = {
    async operationControls(
      _args: { operation: Record<string, JSONValue>; qso?: Record<string, JSONValue> },
      ctx: HookContext,
    ) {
      return [
        {
          key: `${config.key}/activation`,
          label: config.tFor(ctx)('activationControl'),
          icon: config.icon,
          color: config.color,
          order: 10,
          optionType: 'optional',
          allowsMultiple,
          input: {
            kind: 'refList',
            refType: config.activationType,
            placeholder: config.placeholder,
            pattern: config.referenceRegex.source,
          },
        },
      ]
    },

    // No `loggingControls`: these programs have no hunting side, so there is
    // nothing to record per QSO.

    async suggest({ location, searchTerm }: SuggestArgs, _ctx: HookContext): Promise<ActivitySuggestion[]> {
      const host = await hostApi()
      const rows: LookupRow[] = searchTerm
        ? await host.dbLookupSelectAll(category, searchTerm)
        : location
          ? await host.dbLookupSelectByLocation(category, location.lat, location.lon, NEARBY_DELTA)
          : []

      const withDistance = rows.map((row) => ({
        row,
        distance:
          location && row.lat != null && row.lon != null
            ? (distanceOnEarth(location, { lat: row.lat, lon: row.lon }) ?? undefined)
            : undefined,
      }))
      // Nearby results must be ranked by real distance BEFORE truncating: the
      // bounding-box query's row order is not a proxy for it, so slicing first
      // can drop a closer reference for a farther one that came back earlier.
      if (!searchTerm) {
        withDistance.sort((a, b) => (a.distance ?? Infinity) - (b.distance ?? Infinity))
      }

      return withDistance.slice(0, MAX_SUGGESTIONS).map(({ row, distance }) => {
        const data = (row.data ?? {}) as Record<string, any>
        return {
          type: config.activationType,
          ref: row.key,
          name: row.name,
          grid: data.grid,
          location: data.location,
          program,
          label: `${config.label} ${row.key}: ${row.name ?? ''}`,
          shortLabel: `${config.label} ${row.key}`,
          distance,
          relevance: relevanceForMatch(row, searchTerm),
          allowsMultiple,
        }
      })
    },
  }

  const adifFieldsHook = {
    async fieldsForOneQSO(
      { operation }: { qso: Record<string, unknown>; operation: Record<string, unknown> },
      _ctx: HookContext,
    ): Promise<{ name: string; value: string }[]> {
      const activationRefs = refsOfType(operation, config.activationType)
      if (activationRefs.length === 0) return []
      // MY_SIG_INFO takes the primary reference only, matching app-polo. These
      // programs have no hunting side, so nothing writes SIG/SIG_INFO.
      return [
        { name: 'MY_SIG', value: program },
        { name: 'MY_SIG_INFO', value: activationRefs[0].ref! },
      ]
    },
  }

  return { refHandler, activityHook, adifFieldsHook }
}
