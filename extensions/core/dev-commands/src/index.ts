// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Developer-only call-field shortcuts: DEVMODE toggles developer mode
// (moved here from radio-commands — it's a dev tool, not a radio one), and
// DEVNOTICE/DEVSTATUS/DEVPROGRESS post sample items to the status bar so
// the footer/notice UI can be exercised without a real extension driving
// it. DEVSPLASH re-shows the startup release-notes overlay (Issue #42) on
// demand, bypassing its normal "once per version" gate. RELOAD forces a
// data-file re-sync (bypassing the normal 30-day
// staleness check), for both developers iterating on `csvToLookupEntry`
// mapping logic and anyone troubleshooting stale/missing lookup data.
// SEED fills the current log with generated QSOs for exercising list/
// scoring/map UI against realistic data (ported from app-polo's
// DebuggingCommands). All are just `command` hooks like radio-commands' —
// see docs/extensions/hooks.md.

import { defineExtension, hooks } from "@ham2k/halo-extension-sdk"
import type { CommandAction, CommandInterpretation, HookContext, JSONValue } from "@ham2k/halo-extension-sdk"

import {
  FALLBACK_CALLS,
  existingStatsFromQsos,
  mutateCall,
  parseSeedCommand,
  randomRST,
  seedPlan,
  seedableCallsFrom,
} from "./seed.ts"
import type { ExistingQsoStats } from "./seed.ts"

const DevModeCommand = {
  async interpret({ input }: { input: string }, ctx: HookContext): Promise<CommandInterpretation | null> {
    const trimmed = input.trim().toUpperCase()
    if (trimmed !== 'DEVMODE' && trimmed !== 'KONAMI') return null

    const devMode = !!ctx.developerMode
    const nextDevMode = !devMode
    return {
      describe: nextDevMode ? 'Activate developer mode?' : 'Deactivate developer mode?',
      confirm: nextDevMode ? 'Developer mode activated' : 'Developer mode deactivated',
      commands: [{ updateSettings: { developerMode: nextDevMode } }],
    }
  },
}

// Excludes whatever index was picked last time (tracked per-list, at module
// scope — the kernel stays loaded for the whole session, so this state
// persists across calls) so two DEVNOTICE/DEVSTATUS in a row never repeat
// the same entry, instead of leaving it to plain Math.random() chance.
function pickNext<T>(list: T[], lastIndex: { value: number }): T {
  if (list.length === 1) return list[0]
  let index = Math.floor(Math.random() * (list.length - 1))
  if (lastIndex.value >= 0 && index >= lastIndex.value) index += 1
  lastIndex.value = index
  return list[index]
}

const DEV_NOTICES = [
  { icon: 'party-popper', title: 'Random notice', text: 'This is a **random** dev notice, generated to test the status bar.' },
  { icon: 'bug-outline', title: 'Heads up', text: "Here's another sample notice with *different* text, to check variety." },
  { icon: 'flask-outline', title: 'Experiment running', text: 'A third possible dev notice — multi-line bodies work too.\n\nLike this second line.' },
]
const lastNoticeIndex = { value: -1 }

const DevNoticeCommand = {
  async interpret({ input }: { input: string }, _ctx: HookContext): Promise<CommandInterpretation | null> {
    if (input.trim().toUpperCase() !== 'DEVNOTICE') return null
    const notice = pickNext(DEV_NOTICES, lastNoticeIndex)
    return {
      describe: 'Show a random dev notice?',
      confirm: 'Added a random notice',
      commands: [{ devNotice: notice }],
    }
  },
}

const DEV_STATUSES = [
  { icon: 'radio-tower', text: 'Scanning band…' },
  { icon: 'satellite-uplink-outline', text: 'Waiting for spots…' },
  { icon: 'weather-lightning', text: 'Checking propagation…' },
]
const lastStatusIndex = { value: -1 }

const DevStatusCommand = {
  async interpret({ input }: { input: string }, _ctx: HookContext): Promise<CommandInterpretation | null> {
    if (input.trim().toUpperCase() !== 'DEVSTATUS') return null
    const status = pickNext(DEV_STATUSES, lastStatusIndex)
    // A fresh key per call — rather than always overwriting one fixed
    // "devStatus" slot — so repeated DEVSTATUS calls actually stack up as
    // separate items, demonstrating the footer's multi-item/"+N" behavior.
    const key = `devStatus-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`
    return {
      describe: 'Show a random dev status message?',
      confirm: 'Added a random status message',
      commands: [{ devStatus: { key, ...status } }],
    }
  },
}

// "DEVPROGRESS" alone -> indeterminate; "DEVPROGRESS 10" -> 10%.
const DEV_PROGRESS_MATCH = /^DEVPROGRESS(?:\s+(\d+(?:\.\d+)?))?$/i

const DevProgressCommand = {
  async interpret({ input }: { input: string }, _ctx: HookContext): Promise<CommandInterpretation | null> {
    const match = DEV_PROGRESS_MATCH.exec(input.trim())
    if (!match) return null
    const percent = match[1] ? Math.min(100, Math.max(0, parseFloat(match[1]))) : undefined
    return {
      describe: percent === undefined ? 'Show an indeterminate dev progress bar?' : `Show a dev progress bar at ${percent}%?`,
      confirm: percent === undefined ? 'Added an indeterminate progress bar' : `Added a progress bar at ${percent}%`,
      commands: [{ devProgress: { icon: 'progress-clock', title: 'Dev progress', percent } }],
    }
  },
}

const DevSplashCommand = {
  async interpret({ input }: { input: string }, _ctx: HookContext): Promise<CommandInterpretation | null> {
    if (input.trim().toUpperCase() !== 'DEVSPLASH') return null
    return {
      describe: 'Show the startup release-notes overlay?',
      confirm: 'Showing the release-notes overlay',
      commands: [{ devSplash: {} }],
    }
  },
}

// "RELOAD POTA" / "RELOAD SOTA" -> reload data files whose category matches
// that word; "RELOAD ALL", "RELOADALL", or bare "RELOAD!" -> reload every
// data file. Bare "RELOAD" (no target, no ALL/!) isn't executable by itself,
// but it is a recognized prefix — expectsParams lets the call field switch
// into free-text mode so the target word can be typed with a real space.
const RELOAD_MATCH = /^RELOAD(ALL|!)?(?:\s+(\S+))?$/i

const ReloadCommand = {
  async interpret({ input }: { input: string }, _ctx: HookContext): Promise<CommandInterpretation | null> {
    const match = RELOAD_MATCH.exec(input.trim())
    if (!match) return null
    const [, allShorthand, targetWord] = match
    if (allShorthand && targetWord) return null // "RELOADALL POTA" / "RELOAD! POTA" is ambiguous — don't guess
    if (!allShorthand && !targetWord) return { expectsParams: true } // bare "RELOAD" — recognized, not complete yet

    const target = allShorthand || targetWord?.toUpperCase() === 'ALL' ? 'ALL' : targetWord?.toUpperCase()

    return {
      describe: target === 'ALL' ? 'Reload all data files?' : `Reload ${target} data files?`,
      confirm: target === 'ALL' ? 'Reloading all data files…' : `Reloading ${target} data files…`,
      commands: [{ reloadDataFiles: { target } }],
    }
  },
}

// "SEED" -> 10 QSOs; "SEED 20" -> 20; "SEED 15 3H" -> 15 spread over 3
// hours (see seed.ts for parsing and time placement). Calls come from the
// Callsign Notes data (via call-notes' in-runtime `callNotes`/`allCalls`
// hook), mutated 80% of the time so the log isn't all famous calls; each
// generated QSO runs through the lookup service's offline pass so seeded
// rows carry the same `their.guess`/`their.lookups` a typed call would.
// Every result says `mixedCase` — not because the parameters are prose,
// but because that's what keeps Space a literal character once the command
// is already complete ("SEED 15" is executable AND extendable to
// "SEED 15 3H"; `expectsParams` alone can't express that).
const SeedCommand = {
  async interpret(
    { input, operation, qso, execute }: {
      input: string
      operation?: Record<string, JSONValue>
      qso?: Record<string, JSONValue>
      execute?: boolean
    },
    ctx: HookContext,
  ): Promise<CommandInterpretation | null> {
    const parsed = parseSeedCommand(input)
    if (!parsed) return null
    // Recognized, but there's no log to seed here (e.g. the home screen's
    // quick search) — an error the UI presents, not a silent non-match.
    if (!operation) return { error: 'SEED needs an open operation' }
    if (!parsed.complete) return { expectsParams: true, mixedCase: true }

    const { count, spreadMillis, spreadLabel } = parsed
    const roughWhere = spreadLabel ? ` over ${spreadLabel}` : ''

    // This same `interpret()` also runs on the call field's 150ms typing
    // debounce, for the live describe preview — re-triggered on every
    // keystroke pause, not just once on submit. The log read below and the
    // per-QSO lookups further down are too expensive for that path (see
    // CommandHook.interpret's `execute` doc), so skip straight to a cheap
    // description until the host is actually about to run this command.
    if (!execute) {
      return {
        mixedCase: true,
        describe: `Seed the log with ${count} random QSOs${roughWhere}?`,
      }
    }

    // The existing log's time range, read through ctx (the logging panel
    // folds `uuid` into the operation map it passes to interpret). Absent
    // uuid or host support, seed as if the log were empty.
    let existing: ExistingQsoStats = {}
    if (typeof operation.uuid === 'string' && ctx.getQsos) {
      try {
        // Null (unknown operation / host without log access) seeds as if
        // the log were empty, anchored to now.
        existing = existingStatsFromQsos((await ctx.getQsos(operation.uuid)) ?? [])
      } catch (e) {
        // host without log-data host calls — keep seeding, anchored to now
      }
    }
    const plan = seedPlan({ count, spreadMillis, nowMillis: Date.now(), existing })

    let pool = seedableCallsFrom(await allNotedCalls())
    if (pool.length === 0) pool = [...FALLBACK_CALLS]

    const mode = typeof qso?.mode === 'string' ? qso.mode : 'SSB'
    const band = typeof qso?.band === 'string' ? qso.band : '20m'
    const freq = typeof qso?.freq === 'number' ? qso.freq : undefined
    const stationCall = typeof operation.stationCall === 'string' && operation.stationCall ? operation.stationCall : 'N0CALL'

    const commands: CommandAction[] = []
    let bag: string[] = []
    for (const startAtMillis of plan.startTimes) {
      if (bag.length === 0) bag = shuffled(pool)
      let call = bag.pop()!
      if (Math.random() < 0.8) call = mutateCall(call)

      const their: Record<string, JSONValue> = { call, sent: randomRST(mode) }
      const qsoData: Record<string, JSONValue> = {
        band,
        mode,
        ...(freq !== undefined ? { freq } : {}),
        startAtMillis,
        our: { call: stationCall, sent: randomRST(mode) },
        their,
      }
      const annotation = await lookupGuessFor(call, qsoData, operation)
      if (annotation?.guess) their.guess = annotation.guess
      if (annotation?.lookups) their.lookups = annotation.lookups
      commands.push({ addQso: qsoData })
    }

    const where = spreadLabel
      ? plan.beforeExisting
        ? ` over ${spreadLabel}, before your earliest QSO`
        : ` over the last ${spreadLabel}`
      : ''
    return {
      mixedCase: true,
      describe: `Seed the log with ${count} random QSOs${where}?`,
      confirm: `Seeding ${count} QSOs${where}…`,
      commands,
    }
  },
}

/// Every key in the Callsign Notes index, via call-notes' `callNotes` hook —
/// in-runtime composition (like the lookup fan-out), no bridge round-trip.
/// Empty when call-notes isn't loaded or has no data yet.
async function allNotedCalls(): Promise<string[]> {
  const calls: string[] = []
  try {
    for (const entry of await hooks.invokeAll('callNotes', 'allCalls', {})) {
      if (entry.ok && Array.isArray(entry.value)) calls.push(...(entry.value as string[]))
    }
  } catch (e) {
    // no callNotes hook in this runtime — fall through to FALLBACK_CALLS
  }
  return calls
}

/// One offline pass through the lookup service (the same `lookupService`/
/// `core` orchestrator the logging panel uses) so a seeded QSO carries
/// `their.guess`/`their.lookups`. Returns null if the service isn't loaded
/// or fails — seeding still works, just without the decoration.
async function lookupGuessFor(
  call: string,
  qsoData: Record<string, JSONValue>,
  operation: Record<string, JSONValue>,
): Promise<{ guess?: JSONValue; lookups?: JSONValue } | null> {
  try {
    const entries = await hooks.invokeAll(
      'lookupService',
      'lookupCallInfo',
      { callInfo: { call }, qso: qsoData, operation },
      false, // offline: seeding must stay fast (it re-runs while typing) and never hit QRZ/HamDB
    )
    const entry = entries.find((e) => e.ok && e.value)
    return (entry?.value as { guess?: JSONValue; lookups?: JSONValue } | undefined) ?? null
  } catch (e) {
    return null
  }
}

function shuffled(list: string[]): string[] {
  const copy = [...list]
  for (let i = copy.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1))
    ;[copy[i], copy[j]] = [copy[j], copy[i]]
  }
  return copy
}

defineExtension({
  key: 'dev-commands',
  name: 'Developer Commands',
  version: '0.0.1',
  description:
    'Call-field shortcuts for developer tools: DEVMODE, DEVNOTICE, DEVSTATUS, DEVPROGRESS, DEVSPLASH, RELOAD, SEED',
  onActivation({ registerHook }) {
    registerHook('command', { key: 'dev-commands-devmode', hook: DevModeCommand, priority: 100 })
    registerHook('command', { key: 'dev-commands-devnotice', hook: DevNoticeCommand, priority: 100 })
    registerHook('command', { key: 'dev-commands-devstatus', hook: DevStatusCommand, priority: 100 })
    registerHook('command', { key: 'dev-commands-devprogress', hook: DevProgressCommand, priority: 100 })
    registerHook('command', { key: 'dev-commands-devsplash', hook: DevSplashCommand, priority: 100 })
    registerHook('command', { key: 'dev-commands-reload', hook: ReloadCommand, priority: 100 })
    registerHook('command', { key: 'dev-commands-seed', hook: SeedCommand, priority: 100 })
  },
})
