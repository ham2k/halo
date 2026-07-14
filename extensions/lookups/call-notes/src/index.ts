// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Callsign Notes ("Hams of Note", ham2k/app-halo-dist#17). Three hooks:
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

import { defineExtension } from "@ham2k/halo-extension-sdk"
import type {
  AnnotatedCallInfo,
  CallInfoLookup,
  CommandInterpretation,
  DataFileDefinition,
  HookContext,
  JSONValue,
  LookupResult,
} from "@ham2k/halo-extension-sdk"

import { combineNotes, expansionValueFor, parseCallNotes } from "./callNotes"
import type { CallNotesIndex } from "./callNotes"

// `note`/`emoji` ride along as extra fields CallInfoLookup's fixed shape
// doesn't declare — same rationale as annotate.ts's CallInfoLookupWithFlag.
type CallInfoLookupWithNote = CallInfoLookup & { note?: string; emoji?: string }

let notesByCall: CallNotesIndex = {}

const notesDataFile: DataFileDefinition = {
  key: 'call-notes',
  name: "Ham2K's Hams of Note",
  description: "A veritable sample of who's who and who isn't in the world of radio",
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
  const combined = combineNotes(entriesFor(call, callInfo.baseCall))
  if (!combined) return []

  const result: CallInfoLookupWithNote = {
    call,
    source: 'call-notes',
    scope: 'general',
    note: combined.note,
    emoji: combined.emoji,
  }
  return [result]
}

const EXPAND_MATCH = /^\/\/(\S+)$/

const ExpandCommand = {
  async interpret({ input }: { input: string }, _ctx: HookContext): Promise<CommandInterpretation | null> {
    const match = EXPAND_MATCH.exec(input.trim())
    if (!match) return null

    const value = expansionValueFor(notesByCall[match[1].toUpperCase()])
    if (!value) return null

    return {
      describe: `Expand to ${value}?`,
      commands: [{ setCallField: { text: value } }],
    }
  },
}

defineExtension({
  key: 'call-notes',
  name: 'Callsign Notes',
  version: '0.0.1',
  description: 'Notes about specific callsigns, from Ham2K\'s "Hams of Note"',
  onActivation({ registerHook }) {
    registerHook('dataFile', { hook: notesDataFile, key: 'call-notes' })
    registerHook('lookup', { hook: { lookupCall }, key: 'call-notes', priority: 100 })
    registerHook('command', { hook: ExpandCommand, key: 'call-notes', priority: 100 })
  },
})
