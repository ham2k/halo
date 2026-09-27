// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Callsign Notes ("Hams of Note"). Five hooks:
//
//  - `dataFile`: one registration per note SOURCE — every entry in
//    BUILT_IN_NOTES, plus one per user-added custom file (HALO-53) — each
//    fetched/cached independently and folded into `notesByFile` by its own
//    `identifier` (never a shared single index; see that map's own comment).
//    `fetchType: 'raw'` means the Dart side caches the PARSED index as JSON
//    and replays it through `onLoadRawData` at startup, so notes work
//    offline.
//  - `lookup`: surfaces a call's combined note + emoji marker during the
//    lookup fan-out (extra fields on CallInfoLookup, same widening pattern
//    as annotate.ts's `flag`).
//  - `command`: `//KEY` expands a notes entry into the call field — only
//    when that entry, once a leading heading/emoji marker is stripped, reads
//    as a plain comma list of calls (see expansionValueFor) — a note authored
//    as `1GM ## VK1GM,VK2ETI` for readability in the note display still
//    expands. The call field explicitly excludes a field
//    STARTING with "//" from call stacking (logging_controls.dart's
//    _pickStackedCall) — without that, a note key that's itself a valid
//    callsign (the common case) would also read as a stacked call, racing
//    the expand command with a real lookup/score for the key.
//    A key stacked ALONGSIDE other calls ("KI2D//1AB") never reaches this
//    hook as a whole-field command; the call field asks again with just the
//    segment under the cursor ("//1AB") and splices the answer back into
//    that segment (logging_controls.dart's _expandStackedNote), so nothing
//    here needs to know about stacks.
//  - `callNotes`: in-runtime directory of the noted calls, for other
//    extensions (see DirectoryHook below).
//  - `settingsPanel` (HALO-53): lets the operator disable a builtin source
//    and add/remove custom ones. Tier 2 (`kind: 'dynamic'`) because a
//    builtin's enable state and the whole custom-file list both need to
//    survive a restart, and the ONLY durable per-extension storage is
//    `host.getSettings()`/`setSettings` — Tier 1 has no persistence an
//    extension can read back at all (see docs/extensions/settings.md).

import { defineExtension, host } from "@ham2k/extension-sdk"
import type {
  AnnotatedCallInfo,
  CallInfoLookup,
  CommandCatalogEntry,
  CommandInterpretation,
  DataFileDefinition,
  DynamicSettingsPanel,
  FormDefinition,
  HookContext,
  JSONValue,
  LookupResult,
  SettingsPanelDescriptor,
} from "@ham2k/extension-sdk"

import { combineNotes, customIdentifier, expansionValueFor, parseCallNotes } from "./callNotes.ts"
import type { CallNotesIndex } from "./callNotes.ts"
import { tFor } from "./i18n.ts"

import manifest from "../manifest.json" with { type: "json" }

// `note`/`emoji` ride along as extra fields CallInfoLookup's fixed shape
// doesn't declare — same rationale as annotate.ts's CallInfoLookupWithFlag.
type CallInfoLookupWithNote = CallInfoLookup & { note?: string; emoji?: string }

interface BuiltinNote {
  identifier: string
  name: string
  url: string
}

// Exactly one today — the settings panel below still lists/disables it
// generically (map over this array, not a hardcoded single row), so adding
// a second builtin source later is a one-line change here, not a UI change.
const BUILT_IN_NOTES: BuiltinNote[] = [{ identifier: "hams-of-note", name: "Ham2K's Hams of Note", url: "https://ham2k.com/data/hams-of-note.txt" }]

// The settings panel lists builtins first, then custom files; precedence is
// the reverse of that list, so the file listed last wins. app-polo's
// call-notes puts custom files first in list order, so there the FIRST custom
// file wins — HaLo deliberately differs, as its settings help text states.
function precedenceOrder(customIdentifiers: string[]): string[] {
  return [...BUILT_IN_NOTES.map((note) => note.identifier), ...customIdentifiers].reverse()
}

interface CustomFile {
  name: string
  location: string
}

interface CallNotesSettings {
  // Builtin identifier → enabled; absent/anything but `false` means
  // enabled, matching app-polo's own `!== false` convention (a builtin
  // added after a user's settings were last saved defaults to on).
  enabledNotes: Record<string, boolean>
  customFiles: CustomFile[]
}

async function loadSettings(): Promise<CallNotesSettings> {
  const all = await host.getSettings()
  const extensions = all.extensions as Record<string, JSONValue> | undefined
  const mine = extensions?.["extension_call-notes"] as Record<string, JSONValue> | undefined
  return {
    enabledNotes: (mine?.enabledNotes as Record<string, boolean> | undefined) ?? {},
    customFiles: (mine?.customFiles as CustomFile[] | undefined) ?? [],
  }
}

// Every loaded source's parsed index, keyed by its own `identifier` — never
// one shared index the way the pre-HALO-53 single-builtin version had.
// Sources fetch/cache independently and complete in whatever order the
// network/cache gives them, so this can't just be `Object.entries()`'d for
// lookup precedence — see `fileOrder`.
let notesByFile: Record<string, CallNotesIndex> = {}

// Builtin-only; a custom file has no toggle (see CustomFile above). Seeded
// from settings at activation, updated in place (no restart needed) when a
// builtin's checkbox commits — `entriesFor` reads this directly, not
// settings, so the very next lookup reflects the change.
let enabledByIdentifier: Record<string, boolean> = {}

// Fixed at activation, in precedence order (see precedenceOrder). Within one
// file, entries keep file order. Sources populate `notesByFile`
// asynchronously as each one's fetch/cache-load finishes, which can finish
// in ANY order; iterating this fixed list (not `Object.keys(notesByFile)`,
// whose insertion order would just be "whichever source happened to load
// first") is what keeps that precedence deterministic regardless.
let fileOrder: string[] = []

// Every file's exact-call entries come before any file's baseCall fallback:
// otherwise a higher-precedence file's note for KI2D would headline a lookup
// of KI2D/P over another file's note written for KI2D/P itself. A note text
// already collected (the same line in two files, or one file added twice) is
// shown once.
function entriesFor(call: string, baseCall?: string) {
  const base = baseCall?.toUpperCase()
  const exact = []
  const fallback = []
  for (const identifier of fileOrder) {
    if (enabledByIdentifier[identifier] === false) continue
    const index = notesByFile[identifier]
    if (!index) continue
    if (index[call]) exact.push(...index[call])
    else if (base && index[base]) fallback.push(...index[base])
  }
  const seen = new Set<string>()
  const results = [...exact, ...fallback].filter((entry) => !seen.has(entry.note) && seen.add(entry.note))
  return results.length ? results : undefined
}

function makeDataFileDef(identifier: string, name: string, url: string): DataFileDefinition {
  return {
    key: identifier,
    name,
    description: (_args: Record<string, never>, ctx: HookContext) => tFor(ctx)("dataFileDescription"),
    url,
    maxAgeInDays: 1,
    fetchType: "raw",
    category: "call-notes",
    rawToJSONData: async ({ body }) => parseCallNotes(body),
    onLoadRawData: (data) => {
      notesByFile[identifier] = (data as CallNotesIndex | null) ?? {}
    },
    onRemoveRawData: async () => {
      delete notesByFile[identifier]
    },
  }
}

async function lookupCall(
  { callInfo }: { callInfo: AnnotatedCallInfo; qso: Record<string, JSONValue>; operation: Record<string, JSONValue> },
  _ctx: HookContext,
): Promise<LookupResult> {
  const call = (callInfo.call || "").trim().toUpperCase()
  const entries = entriesFor(call, callInfo.baseCall)
  const combined = combineNotes(entries)
  if (!combined) return []

  const result: CallInfoLookupWithNote = {
    call,
    source: "call-notes",
    scope: "general",
    note: combined.note, // combined single-line note for the compact call-info line
    emoji: combined.emoji,
    notes: (entries ?? []).map((entry) => entry.note), // every note, for the call-info detail
  }
  return [result]
}

// Lets other extensions enumerate the noted calls (dev-commands' SEED draws
// its callsign pool from here) via in-runtime composition
// (`hooks.invokeAll('callNotes', 'allCalls', {})`) — the index lives in this
// module's memory, unreachable from other bundles. Keys come back raw,
// including expansion keywords; callers filter for callsign-shaped entries.
const DirectoryHook = {
  async allCalls(_args: Record<string, never>, _ctx: HookContext): Promise<string[]> {
    const seen = new Set<string>()
    for (const identifier of fileOrder) {
      // Same enabled-state check as entriesFor — a
      // disabled source's calls shouldn't surface here either, or a
      // consumer (dev-commands' SEED) would see calls whose notes are
      // hidden everywhere else in the app.
      if (enabledByIdentifier[identifier] === false) continue
      for (const call of Object.keys(notesByFile[identifier] ?? {})) seen.add(call)
    }
    return [...seen]
  },
}

const EXPAND_MATCH = /^\/\/(\S+)$/

const ExpandCommand = {
  async interpret({ input }: { input: string }, ctx: HookContext): Promise<CommandInterpretation | null> {
    const match = EXPAND_MATCH.exec(input.trim())
    if (!match) return null

    const value = expansionValueFor(entriesFor(match[1].toUpperCase()))
    if (!value) return null

    return {
      describe: tFor(ctx)("expandTo", { value }),
      commands: [{ setCallField: { text: value } }],
    }
  },

  async catalog(ctx: HookContext): Promise<CommandCatalogEntry[]> {
    const t = tFor(ctx)
    // The "//" prefix itself, not every key the user has defined — those are
    // their own data, and listing them all would swamp the palette.
    return [
      {
        command: "//",
        params: t("catalogExpandParams"),
        describe: t("catalogExpand"),
        category: t("catalogCategory"),
        expectsParams: true,
      },
    ]
  },
}

const SettingsPanel: DynamicSettingsPanel = {
  kind: "dynamic",

  // Declares the title upfront (and keeps this panel out of the app's
  // top-level settings nav — it's reached from the Data Files screen
  // instead) without waiting on getDefinition, which the host would
  // otherwise have to fetch just to know what to call the panel/row.
  async getPanels(_args: Record<string, never>, ctx: HookContext): Promise<SettingsPanelDescriptor[]> {
    return [{ key: "call-notes", title: tFor(ctx)("settingsTitle"), sidebar: false, dataFilesSection: true }]
  },

  async getDefinition(_args: { panelKey: string }, ctx: HookContext): Promise<FormDefinition> {
    const t = tFor(ctx)
    const settings = await loadSettings()
    return {
      // No title here — the panel's own title (getPanels above) already
      // labels the modal/dialog that hosts this form; repeating it in the
      // body would double it.
      elements: [
        { type: "header" as const, title: t("builtinNotesTitle"), style: "section" as const },
        ...BUILT_IN_NOTES.map((note) => ({
          type: "field" as const,
          fieldType: "checkbox" as const,
          key: `enabled.${note.identifier}`,
          label: note.name,
          value: settings.enabledNotes[note.identifier] !== false,
        })),
        { type: "header" as const, title: t("customFilesLabel"), style: "section" as const },
        {
          type: "field" as const,
          fieldType: "list" as const,
          key: "customFiles",
          label: t("customFilesLabel"),
          itemLabel: t("customFileItemLabel"),
          // Reorder handle, delete button, and Add row shown directly here
          // (under the header above) instead of behind a summary row that
          // opens a separate list-editor dialog.
          inline: true,
          itemTitle: "${name}",
          orderable: true,
          // See docs/extensions/settings.md's "Restarting the runtime after
          // a Tier 2 field commits" — onActivation is the only place a new
          // custom file becomes a registered dataFile hook.
          restartOnChange: true,
          itemFields: [
            { type: "field" as const, fieldType: "text" as const, key: "name", label: t("customFileName") },
            { type: "field" as const, fieldType: "text" as const, key: "location", label: t("customFileLocation") },
          ],
          value: settings.customFiles,
        },
        {
          type: "markdown" as const,
          collapsible: true,
          title: t("helpTitle"),
          text: t("helpText"),
        },
      ],
    }
  },

  async onChangeField({ fieldKey, value }, _ctx: HookContext) {
    if (fieldKey.startsWith("enabled.")) {
      const identifier = fieldKey.slice("enabled.".length)
      const enabled = value as boolean
      const settings = await loadSettings()
      enabledByIdentifier[identifier] = enabled
      await host.setSettings({ enabledNotes: { ...settings.enabledNotes, [identifier]: enabled } })
      return
    }
    if (fieldKey === "customFiles") {
      await host.setSettings({ customFiles: value as JSONValue })
    }
  },
}

defineExtension({
  ...manifest,
  // ASYNC onActivation is new territory — no other shipped extension awaits
  // anything before its registerHook calls (kernel.ts's activation loop
  // never awaits onActivation itself, so nothing here delays boot). Only
  // a user-added custom file's dataFile registration below actually needs
  // that await (its identifier/URL comes from settings) — everything else,
  // including the builtin(s), registers synchronously first, specifically
  // so it's never subject to what follows.
  //
  // A registerHook call made AFTER an await lands whenever that promise
  // happens to resolve, not before boot "finishes" — nothing in the kernel
  // awaits onActivation itself. That's only safe in practice because the
  // app's own boot path always makes an unrelated host round trip of its
  // own (ExtensionService._start()'s _refreshAccountSynchronizable) before
  // returning control to any caller, which reliably gives a pending
  // getSettings() continuation enough time to land first on a real
  // (many-extension) runtime — not a hard guarantee, an incidental one. A
  // minimal, few-extension host with no such trailing round trip
  // (packages/halo_extension_host/test/extension_host_test.dart's bare
  // ExtensionHost.start(), not app-level ExtensionService) can observe
  // this registerHook call landing LATE relative to one made immediately
  // after boot — that test works around it with an explicit settle delay;
  // see its own comment for what that means and doesn't mean.
  async onActivation({ registerHook }) {
    notesByFile = {}
    // Everything that DOESN'T need settings registers synchronously, before
    // the `await` below — including the builtin(s), the common case that's
    // always present — so none of it is subject to this file's own header
    // comment about registerHook calls made after an await landing late.
    // Only a user-added custom file's OWN dataFile registration genuinely
    // needs settings first (its identifier/URL comes from there).
    fileOrder = precedenceOrder([])
    for (const note of BUILT_IN_NOTES) {
      registerHook("dataFile", { hook: makeDataFileDef(note.identifier, note.name, note.url), key: note.identifier })
    }
    registerHook("lookup", { hook: { lookupCall }, key: "call-notes", priority: 100 })
    registerHook("command", { hook: ExpandCommand, key: "call-notes", priority: 100 })
    registerHook("callNotes", { hook: DirectoryHook, key: "call-notes" })
    registerHook("settingsPanel", { hook: SettingsPanel, key: "call-notes" })

    const settings = await loadSettings()
    enabledByIdentifier = { ...settings.enabledNotes }
    // Extended now that custom files are known — see `fileOrder`'s own
    // comment on why this has to be a fixed list, not object insertion
    // order.
    fileOrder = precedenceOrder(settings.customFiles.map((file) => customIdentifier(file.location)))
    for (const file of settings.customFiles) {
      const identifier = customIdentifier(file.location)
      registerHook("dataFile", { hook: makeDataFileDef(identifier, file.name, file.location), key: identifier })
    }
  },
})
