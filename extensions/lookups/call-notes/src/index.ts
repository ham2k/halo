// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Callsign Notes ("Hams of Note", ham2k/app-halo-dist#17). Four hooks:
//
//  - `dataFile`: fetches https://ham2k.com/data/hams-of-note.txt daily and
//    keeps the parsed index in module memory. `fetchType: 'raw'` means the
//    Dart side caches the PARSED index as JSON and replays it through
//    `onLoadRawData` at startup, so notes work offline.
//  - `lookup`: surfaces a call's combined note + emoji marker during the
//    lookup fan-out (extra fields on CallInfoLookup, same widening pattern
//    as annotate.ts's `flag`).
//  - `command`: `//KEY` expands a notes entry into the call field — only
//    when that entry reads as a plain comma list of calls (see
//    expansionValueFor). Leading "//" never parses as call stacking (a
//    stack's first segment would be empty), so the two syntaxes coexist.
//  - `callNotes`: in-runtime directory of the noted calls, for other
//    extensions (see DirectoryHook below).

import { defineExtension } from "@ham2k/halo-extension-sdk"
import type {
  AnnotatedCallInfo,
  CallInfoLookup,
  CommandCatalogEntry, CommandInterpretation,
  DataFileDefinition,
  HookContext,
  JSONValue,
  LookupResult,
} from "@ham2k/halo-extension-sdk"

import { combineNotes, expansionValueFor, parseCallNotes } from "./callNotes"
import type { CallNotesIndex } from "./callNotes"
import { tFor } from "./i18n.ts"

import manifest from "../manifest.json" with { type: "json" }

// `note`/`emoji` ride along as extra fields CallInfoLookup's fixed shape
// doesn't declare — same rationale as annotate.ts's CallInfoLookupWithFlag.
type CallInfoLookupWithNote = CallInfoLookup & { note?: string; emoji?: string }

let notesByCall: CallNotesIndex = {}

const notesDataFile: DataFileDefinition = {
  key: 'call-notes',
  // The name is a Ham2K product title — kept verbatim in every locale.
  name: "Ham2K's Hams of Note",
  description: (_args: Record<string, never>, ctx: HookContext) => tFor(ctx)('dataFileDescription'),
  url: 'https://ham2k.com/data/hams-of-note.txt',
  maxAgeInDays: 1,
  fetchType: 'raw',
  category: 'call-notes',
  rawToJSONData: async ({ body }) => parseCallNotes(body),
  onLoadRawData: (data) => {
    notesByCall = (data as CallNotesIndex | null) ?? {}
  },
  onRemoveRawData: async () => {
    notesByCall = {}
  },
}

function entriesFor(call: string, baseCall?: string) {
  return notesByCall[call] ?? (baseCall ? notesByCall[baseCall.toUpperCase()] : undefined)
}

async function lookupCall(
  { callInfo }: { callInfo: AnnotatedCallInfo; qso: Record<string, JSONValue>; operation: Record<string, JSONValue> },
  _ctx: HookContext,
): Promise<LookupResult> {
  const call = (callInfo.call || '').trim().toUpperCase()
  const entries = entriesFor(call, callInfo.baseCall)
  const combined = combineNotes(entries)
  if (!combined) return []

  const result: CallInfoLookupWithNote = {
    call,
    source: 'call-notes',
    scope: 'general',
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
    return Object.keys(notesByCall)
  },
}

const EXPAND_MATCH = /^\/\/(\S+)$/

const ExpandCommand = {
  async interpret({ input }: { input: string }, ctx: HookContext): Promise<CommandInterpretation | null> {
    const match = EXPAND_MATCH.exec(input.trim())
    if (!match) return null

    const value = expansionValueFor(notesByCall[match[1].toUpperCase()])
    if (!value) return null

    return {
      describe: tFor(ctx)('expandTo', { value }),
      commands: [{ setCallField: { text: value } }],
    }
  },

  async catalog(ctx: HookContext): Promise<CommandCatalogEntry[]> {
    const t = tFor(ctx)
    // The "//" prefix itself, not every key the user has defined — those are
    // their own data, and listing them all would swamp the palette.
    return [{
      command: '//',
      params: t('catalogExpandParams'),
      describe: t('catalogExpand'),
      category: t('catalogCategory'),
      expectsParams: true,
    }]
  },
}

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook('dataFile', { hook: notesDataFile, key: 'call-notes' })
    registerHook('lookup', { hook: { lookupCall }, key: 'call-notes', priority: 100 })
    registerHook('command', { hook: ExpandCommand, key: 'call-notes', priority: 100 })
    registerHook('callNotes', { hook: DirectoryHook, key: 'call-notes' })
  },
})
