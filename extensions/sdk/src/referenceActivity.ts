// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
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
// `@ham2k/extension-sdk` alias, so this module's tests can run under plain
// `node --test` — the constraint dxcc.ts and scoring.ts document.

import { nearbyLookupRows } from "./nearby.ts"
import { distanceOnEarth } from "@ham2k/lib-geo-tools"

import { activityAdifImport } from "./activityAdifImport.ts"
import type { ActivitySuggestion, AdifImportHook, HookContext, JSONValue, LookupRow, Ref, RefLink, SuggestArgs, TitleSuggestion } from "./types.ts"
import type { RefTransform } from "./refTransforms.ts"

/// The SDK barrel re-exports this module, so a static import of `host` from it
/// would be circular. Imported once on first use, then cached by the module
/// system — the same dance activityExports.ts does for `hooks`.
async function hostApi() {
  const { host } = await import("@ham2k/extension-sdk")
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
  /// The ref type a QSO carries for a reference the other station was at
  /// ('gma'). Omit it for an award that only recognises activations — several
  /// of the castle and lighthouse programs do, and app-polo says so by leaving
  /// `huntingType` off its Info. With it, the logging panel gains a per-QSO
  /// control and exports carry SIG/SIG_INFO.
  huntingType?: string
  /// Whether a contact that hunts several references is submitted as one
  /// record PER reference, or as a single record naming them all.
  ///
  /// The programs genuinely disagree and it is not cosmetic — it decides how
  /// many contacts the award sees. POTA and MOTA split; SiOTA, WWBOTA and
  /// ZLOTA join with commas. Ignored without a `huntingType`.
  splitRecordsPerHuntedRef?: boolean
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
  /// Emit `<NAME>_REF` / `MY_<NAME>_REF` alongside SIG_INFO / MY_SIG_INFO.
  ///
  /// The bigger programs have a field of their own that logging software and
  /// the awards' own uploaders read in preference to SIG_INFO — `POTA_REF`,
  /// `WWFF_REF`, `LLOTA_REF`. Omit it for a program that has none; writing an
  /// invented field would be worse than writing none.
  adifRefField?: string
  /// Whether the program recognises several references activated at once.
  /// Defaults to false; none of the simple awards allow it.
  allowsMultiple?: boolean
  /// The program's own web page for one reference, built from the normalized
  /// code. Omit it for a program whose list is a download with no page per
  /// reference — several of these have none, and a link into a search form
  /// would be worse than no link at all.
  linkUrl?: (reference: string) => string
  /// Live-typing reformatting for the reference field, applied by the core's
  /// input on every keystroke (`RefListInputDescriptor.transforms`) — what
  /// turns a typed "0001" into "X00001" or "VK-ABC1". Without it the field
  /// takes what is typed as-is. For a program whose rules bake in a prefix
  /// that depends on the station, see `refInput`.
  transforms?: RefTransform[]
  /// The field's placeholder and transforms resolved per controls build, for
  /// a program whose default prefix follows a station's DXCC entity (WWFF's
  /// "KFF"/"GFF", LLOTA's "LLUS"/"LLGB"). `side` says which control is being
  /// built: the hunting control follows the OTHER station's entity (that of
  /// the QSO's callsign) and the activation control our own — app-polo's
  /// hunter/activator rule. What it answers wins over `placeholder` and
  /// `transforms`; what it leaves out falls back to them.
  refInput?: (args: RefInputArgs, ctx: HookContext) => Promise<RefInputExtras> | RefInputExtras
}

export interface RefInputArgs {
  operation: Record<string, JSONValue>
  qso?: Record<string, JSONValue>
  side: "activation" | "hunting"
}

export interface RefInputExtras {
  placeholder?: string
  transforms?: RefTransform[]
}

/// The reference prefix a program uses for one DXCC entity, learned from the
/// program's own loaded list rather than derived — WWFF's and WWBOTA's
/// prefixes only mostly follow the entity prefix (Russia is "RFF", the
/// Canaries are "EAFF", Canada is "B/CA"), and app-polo builds the same map
/// while it loads the file. Asked of the lookups table by `subCategory`, which
/// these programs' data-file mappers set to the entity prefix, and cached
/// per entity for the session: one query per entity, not one per keystroke.
///
/// `fallback` answers when the list has nothing for that entity — not yet
/// synced, or a country the program has no references in — so the field
/// still autoformats to SOMETHING the operator can correct.
const learnedPrefixes = new Map<string, string>()
export async function learnedReferencePrefix(category: string, entityPrefix: string, fallback: string): Promise<string> {
  const cacheKey = `${category}:${entityPrefix}`
  const cached = learnedPrefixes.get(cacheKey)
  if (cached) return cached
  const host = await hostApi()
  let rows: LookupRow[] = []
  try {
    rows = await host.dbLookupSelectAll(category, "", entityPrefix)
  } catch (e) {
    host.log(`${category}: prefix lookup failed for ${entityPrefix}: ${e}`)
  }
  // The most common prefix among the rows, not the first: a list can carry a
  // stray reference filed under the wrong entity.
  const counts = new Map<string, number>()
  for (const row of rows) {
    const prefix = row.key.split("-")[0]
    if (prefix) counts.set(prefix, (counts.get(prefix) ?? 0) + 1)
  }
  let best: string | undefined
  for (const [prefix, count] of counts) {
    if (best === undefined || count > (counts.get(best) ?? 0)) best = prefix
  }
  if (best === undefined) return fallback
  learnedPrefixes.set(cacheKey, best)
  return best
}

function normalize(ref: string | undefined): string {
  return (ref ?? "").toUpperCase().trim()
}

/// Whether [text] is worth offering as a reference of a program whose codes
/// look like [referenceRegex] — either it already is one, or it is shaped like
/// a code rather than like a name.
///
/// The scoped search offers the operator's own text when nothing else matched,
/// so that a reference the program's list has not caught up with — or whose
/// format this app has wrong — is still reachable. The cost of getting this
/// wrong is a junk row at the head of every search: a single word is the
/// commonest way to look for a park or a summit BY NAME, and answering
/// `beersel` with an invented BEERSEL reference buries the real match.
///
/// Anything the program itself accepts is a reference by definition, whatever
/// it looks like — that is what lets BLHA's `BEL 123` through, space and all,
/// and it is why the space test below costs no program its own format.
///
/// Past that, a name is rejected on either count: more than one word, or no
/// digit and no separator anywhere. Both are needed. Names carry numbers
/// (`route 66`, `camp 4`, `castle 3`), so a digit alone does not make text a
/// code; and a code can be a single bare word, so one word alone does not make
/// it one either.
///
/// Exported so the hand-written programs (POTA, SOTA) apply the same rule as
/// the fourteen built on this factory.
export function looksLikeReference(text: string, referenceRegex: RegExp): boolean {
  if (referenceRegex.test(text)) return true
  if (/\s/.test(text)) return false
  return /[0-9]/.test(text) || /[-/]/.test(text)
}

function refsOfType(container: Record<string, unknown>, type: string): Ref[] {
  return ((container.refs as Ref[] | undefined) ?? []).filter((r) => r.type === type && r.ref)
}

/// How well a row answers the search, so the core can rank across programs.
/// Same ladder POTA uses.
function relevanceForMatch(row: LookupRow, searchTerm?: string): number {
  if (!searchTerm) return 1
  const term = searchTerm.toUpperCase()
  const key = row.key.toUpperCase()
  const name = (row.name ?? "").toUpperCase()
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
  adifImportHook: AdifImportHook
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

  /// A reference that resolved to nothing keeps NONE of the previous one's
  /// decoration. `label`/`shortLabel` are what an activity row renders in
  /// preference to the code itself, so a spread-through pair would show the old
  /// reference's name over the new code; and `lat`/`lon` outrank a grid wherever
  /// a location is read (docs/design/locations.md), so they would keep the
  /// operation at a reference it no longer carries.
  function undecorated(ref: Ref, reference: string, name: string): Ref {
    return {
      ...ref,
      ref: reference,
      name,
      program,
      label: undefined,
      shortLabel: undefined,
      grid: undefined,
      lat: undefined,
      lon: undefined,
      location: undefined,
    }
  }

  function decorate(ref: Ref, reference: string, row: LookupRow | null, unknown: string): Ref {
    if (!row?.name) return undecorated(ref, reference, unknown)
    const data = (row.data ?? {}) as Record<string, any>
    return {
      ...ref,
      ref: reference,
      name: row.name,
      grid: data.grid,
      lat: row.lat,
      lon: row.lon,
      location: data.location,
      program,
      label: `${config.label} ${reference}: ${row.name}`,
      shortLabel: `${config.label} ${reference}`,
    }
  }

  /// The `input` of one control: the static placeholder/transforms, with
  /// whatever `refInput` answers laid over them.
  async function refListInput(refType: string, args: RefInputArgs, ctx: HookContext) {
    const extras = config.refInput ? await config.refInput(args, ctx) : {}
    return {
      kind: "refList" as const,
      refType,
      placeholder: extras.placeholder ?? config.placeholder,
      pattern: config.referenceRegex.source,
      transforms: extras.transforms ?? config.transforms,
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
        return undecorated(ref, reference, t("invalidReference"))
      }
      return decorate(ref, reference, await lookupReference(reference), t("unknownReference"))
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

    /// Only for a reference this program would accept: a code the operator is
    /// still typing, or one another program's handler would answer for, would
    /// otherwise send them to a page that cannot exist.
    ///
    /// No `label`: the core names the row instead, and the row's name is the
    /// honest one here. This handler answers for ref types belonging to OTHER
    /// programs (WCA takes `ecaActivation` and `bcaActivation` — see
    /// `suggestOperationTitle` above), so a label built from `config.label`
    /// would read "WCA G-00001" aloud on an ECA reference.
    async linkForRef({ ref }: { ref: Ref }, _ctx: HookContext): Promise<RefLink | null> {
      if (!config.linkUrl) return null
      const reference = normalize(ref.ref)
      if (!config.referenceRegex.test(reference)) return null
      return { url: config.linkUrl(reference) }
    },
  }

  const activityHook = {
    async operationControls({ operation }: { operation: Record<string, JSONValue>; qso?: Record<string, JSONValue> }, ctx: HookContext) {
      return [
        {
          key: `${config.key}/activation`,
          label: config.tFor(ctx)("activationControl"),
          icon: config.icon,
          color: config.color,
          order: 10,
          optionType: "optional",
          allowsMultiple,
          input: await refListInput(config.activationType, { operation, side: "activation" }, ctx),
        },
      ]
    },

    // Only offered when the program HAS a hunting side; an activation-only
    // award has nothing to record per QSO. One control either way, unlike
    // app-polo which swaps between an activator and a hunter control depending
    // on whether the operation is activating — both write the same hunting
    // refs, and POTA's HaLo port already settled on the single control.
    ...(config.huntingType
      ? {
          async loggingControls({ operation, qso }: { operation: Record<string, JSONValue>; qso?: Record<string, JSONValue> }, ctx: HookContext) {
            return [
              {
                key: `${config.key}/hunter`,
                label: config.tFor(ctx)("huntingControl"),
                icon: config.icon,
                color: config.color,
                order: 10,
                optionType: "optional",
                allowsMultiple: true,
                input: await refListInput(config.huntingType!, { operation, qso, side: "hunting" }, ctx),
              },
            ]
          },
        }
      : {}),

    async suggest({ location, bounds, searchTerm, scoped }: SuggestArgs, ctx: HookContext): Promise<ActivitySuggestion[]> {
      const host = await hostApi()
      const { rows, inViewport }: { rows: LookupRow[]; inViewport: boolean } = searchTerm
        ? { rows: await host.dbLookupSelectAll(category, searchTerm), inViewport: false }
        : await nearbyLookupRows(host, category, { location, bounds }, { delta: NEARBY_DELTA })

      const withDistance = rows.map((row) => ({
        row,
        distance: location && row.lat != null && row.lon != null ? (distanceOnEarth(location, { lat: row.lat, lon: row.lon }) ?? undefined) : undefined,
      }))
      // Nearby results must be ranked by real distance BEFORE truncating: the
      // bounding-box query's row order is not a proxy for it, so slicing first
      // can drop a closer reference for a farther one that came back earlier.
      if (!searchTerm) {
        withDistance.sort((a, b) => (a.distance ?? Infinity) - (b.distance ?? Infinity))
      }

      const suggestions = withDistance.slice(0, inViewport ? withDistance.length : MAX_SUGGESTIONS).map(({ row, distance }) => {
        const data = (row.data ?? {}) as Record<string, any>
        return {
          type: config.activationType,
          ref: row.key,
          name: row.name,
          grid: data.grid,
          lat: row.lat,
          lon: row.lon,
          location: data.location,
          program,
          label: `${config.label} ${row.key}: ${row.name ?? ""}`,
          shortLabel: `${config.label} ${row.key}`,
          distance,
          relevance: relevanceForMatch(row, searchTerm),
          allowsMultiple,
        }
      })

      // The reference the operator typed, offered as itself when the data file
      // has no row for it — a reference added since the last sync, or one
      // `referenceRegex` rejects. Only when this program alone was asked
      // (`wca: <code>`, or its row in Activity Types): the operator named the
      // program, so the one thing left in doubt is whether HaLo's idea of its
      // reference format is right, and a code the app refuses is an activation
      // that cannot be logged at all. Never on an unscoped search, where every
      // enabled program would answer any text with a reference of its own.
      //
      // What separates a code from a name is that a code carries a digit or a
      // separator. `wca: beersel` is someone looking for a castle by name and
      // must not also be offered a reference called BEERSEL — one word, so a
      // whitespace test would not catch it. A code the pattern already accepts
      // skips the heuristic entirely, which is what lets BLHA through: its
      // references are `BEL 123`, space and all.
      const typed = scoped ? normalize(searchTerm) : ""
      if (typed && looksLikeReference(typed, config.referenceRegex) && !suggestions.some((s) => s.ref === typed)) {
        const t = config.tFor(ctx)
        const valid = config.referenceRegex.test(typed)
        const row = valid ? await lookupReference(typed) : null
        const data = (row?.data ?? {}) as Record<string, any>
        const name = row?.name || (valid ? t("unknownReference") : t("invalidReference"))
        if (suggestions.length >= MAX_SUGGESTIONS) suggestions.pop()
        suggestions.unshift({
          type: config.activationType,
          ref: typed,
          name,
          grid: data.grid,
          lat: row?.lat,
          lon: row?.lon,
          location: data.location,
          program,
          label: `${config.label} ${typed}: ${name}`,
          shortLabel: `${config.label} ${typed}`,
          distance: undefined,
          relevance: 1,
          allowsMultiple,
        })
      }

      return suggestions
    },
  }

  type AdifField = { name: string; value: string }

  /// MY_SIG/MY_SIG_INFO for the operation's activation. MY_SIG_INFO takes the
  /// primary reference only, matching app-polo.
  function activationFields(operation: Record<string, unknown>): AdifField[] {
    const refs = refsOfType(operation, config.activationType)
    if (refs.length === 0) return []
    return [
      { name: "MY_SIG", value: program },
      { name: "MY_SIG_INFO", value: refs[0].ref! },
      ...(config.adifRefField ? [{ name: `MY_${config.adifRefField}_REF`, value: refs.map((r) => r.ref).join(",") }] : []),
    ]
  }

  function huntedRefsOn(qso: Record<string, unknown>): Ref[] {
    return config.huntingType ? refsOfType(qso, config.huntingType) : []
  }

  const adifFieldsHook: Record<string, unknown> = {
    async fieldsForOneQSO({ qso, operation }: { qso: Record<string, unknown>; operation: Record<string, unknown> }, _ctx: HookContext): Promise<AdifField[]> {
      const hunted = huntedRefsOn(qso)
      const huntedJoined = hunted.map((r) => r.ref).join(",")
      return [
        ...(hunted.length > 0
          ? [
              { name: "SIG", value: program },
              { name: "SIG_INFO", value: huntedJoined },
              ...(config.adifRefField ? [{ name: `${config.adifRefField}_REF`, value: huntedJoined }] : []),
            ]
          : []),
        ...activationFields(operation),
      ]
    },
  }

  // Only a splitting program needs combinations: joining is what
  // `fieldsForOneQSO` already does, and declaring both would just make the
  // exporter ask twice for the same answer.
  if (config.huntingType && config.splitRecordsPerHuntedRef) {
    /// One ADIF record per hunted reference — the contact is submitted to each
    /// program reference separately, which is also why it counts once per
    /// reference toward an activation (docs/design/activities.md §4).
    adifFieldsHook.fieldCombinationsForOneQSO = async (
      { qso, operation }: { qso: Record<string, unknown>; operation: Record<string, unknown> },
      _ctx: HookContext,
    ): Promise<AdifField[][]> => {
      const activation = activationFields(operation)
      const hunted = huntedRefsOn(qso)
      if (hunted.length === 0) return [activation]
      return hunted.map((ref) => [
        ...activation,
        { name: "SIG", value: program },
        { name: "SIG_INFO", value: ref.ref! },
        // One record names ONE reference, so the program field names it too.
        ...(config.adifRefField ? [{ name: `${config.adifRefField}_REF`, value: ref.ref! }] : []),
      ])
    }
  }

  /// The inverse of `adifFieldsHook`, from the same config — every program
  /// built on this factory writes SIG/SIG_INFO the same way, so it can read
  /// them back the same way. Registering it is one line in the extension;
  /// nothing happens until it does.
  ///
  /// `referenceRegex` is deliberately NOT the import filter. By the time a
  /// reference reaches here the file has already said whose it is — the
  /// `*_REF` list field is program-specific, and the `SIG_INFO` path is gated
  /// on `SIG`. So a reference that fails the pattern is MALFORMED, not
  /// foreign, and dropping it would lose data the operator can still fix.
  ///
  /// It imports as written instead. `decorateRef` labels anything the pattern
  /// rejects as an invalid reference, which puts it in front of the operator
  /// rather than in a silent discard — and the raw text is the only thing a
  /// later correction, by hand or by a smarter normalizer, could work from.
  const adifImportHook = activityAdifImport({
    sig: program,
    huntingType: config.huntingType,
    activationType: config.activationType,
    refField: config.adifRefField ? `${config.adifRefField.toLowerCase()}_ref` : undefined,
    normalize,
  })

  return { refHandler, activityHook, adifFieldsHook, adifImportHook }
}
