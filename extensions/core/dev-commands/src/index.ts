// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Developer-only call-field shortcuts: DEVMODE toggles developer mode
// (moved here from radio-commands — it's a dev tool, not a radio one), and
// DEVNOTICE/DEVSTATUS/DEVPROGRESS post sample items to the status bar so
// the footer/notice UI can be exercised without a real extension driving
// it. RELOAD forces a data-file re-sync (bypassing the normal 30-day
// staleness check), for both developers iterating on `csvToLookupEntry`
// mapping logic and anyone troubleshooting stale/missing lookup data. All
// five are just `command` hooks like radio-commands' — see
// docs/extensions/hooks.md.

import { defineExtension } from "@ham2k/polo-sdk"
import type { CommandInterpretation, HookContext } from "@ham2k/polo-sdk"

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

defineExtension({
  key: 'dev-commands',
  name: 'Developer Commands',
  version: '0.0.1',
  description: 'Call-field shortcuts for developer tools: DEVMODE, DEVNOTICE, DEVSTATUS, DEVPROGRESS, RELOAD',
  onActivation({ registerHook }) {
    registerHook('command', { key: 'dev-commands-devmode', hook: DevModeCommand, priority: 100 })
    registerHook('command', { key: 'dev-commands-devnotice', hook: DevNoticeCommand, priority: 100 })
    registerHook('command', { key: 'dev-commands-devstatus', hook: DevStatusCommand, priority: 100 })
    registerHook('command', { key: 'dev-commands-devprogress', hook: DevProgressCommand, priority: 100 })
    registerHook('command', { key: 'dev-commands-reload', hook: ReloadCommand, priority: 100 })
  },
})
