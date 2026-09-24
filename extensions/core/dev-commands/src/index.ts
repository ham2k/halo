// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Developer-only call-field shortcuts: DEVMODE toggles developer mode
// (a dev tool, not a radio one, so it lives here and not radio-commands), and
// DEVNOTICE/DEVSTATUS/DEVPROGRESS post sample items to the status bar so
// the footer/notice UI can be exercised without a real extension driving
// it, and DEVHAMMER reproduces a data-file sync's CHURN — items appearing,
// ticking and clearing — which is what provokes the web engine into blurring
// a focused text field. DEVSPLASH re-shows the startup release-notes overlay on
// demand, bypassing its normal "once per version" gate. DEVSENTRY pushes a
// synthetic error through the error-reporting pipeline to verify the
// Sentry wiring. DEVLOGCAT records radio traffic for a field report. DEVPOPUP reopens the app in a standalone, phone-sized popup
// window (web only). RELOAD forces a data-file re-sync (bypassing the normal 30-day
// staleness check), for both developers iterating on `csvToLookupEntry`
// mapping logic and anyone troubleshooting stale/missing lookup data.
// DEVTT moves the app clock, for testing anything that turns on the date or on
// elapsed time (see timetravel.ts and docs/design/time.md).
// SEED fills the current log with generated QSOs for exercising list/
// scoring/map UI against realistic data (ported from app-polo's
// DebuggingCommands). EXP toggles experimental features from
// app/experiments.yaml. All are just `command` hooks like radio-commands' —
// see docs/extensions/hooks.md.

import { defineExtension, hooks } from "@ham2k/extension-sdk"
import type { CommandAction, CommandCatalogEntry, CommandInterpretation, HookContext, JSONValue } from "@ham2k/extension-sdk"

import { FALLBACK_CALLS, existingStatsFromQsos, mutateCall, parseSeedCommand, randomRST, seedPlan, seedableCallsFrom } from "./seed.ts"
import type { ExistingQsoStats } from "./seed.ts"

import { describeTimeTravel, parseTimeTravelCommand } from "./timetravel.ts"

import manifest from "../manifest.json" with { type: "json" }

/// Builds a `catalog` for one dev command. These stay OUT of the command
/// dialog unless developer mode is on (`always` opts a genuinely user-facing
/// one back in, e.g. RELOAD) — the palette is a discovery surface, and a
/// normal operator has no business finding SEED there. Every command still
/// runs when typed in full, developer mode or not; this only governs what the
/// palette lists.
///
/// `suggest` is honored only alongside `always`: a developer-mode entry can
/// never be volunteered by the empty-field samples, no matter what its
/// options say — only a genuinely user-facing command may opt in.
///
/// Strings here are plain English, like the rest of this extension's
/// describe/confirm lines — dev-commands carries no i18n catalog.
function devCatalog(
  command: string,
  describe: string,
  opts: { always?: boolean; params?: string; needsOperation?: boolean; expectsParams?: boolean; suggest?: boolean } = {},
) {
  return async (ctx: HookContext): Promise<CommandCatalogEntry[]> => {
    if (!opts.always && !ctx.developerMode) return []
    return [
      {
        command,
        describe,
        category: opts.always ? "Data files" : "Developer",
        ...(opts.params ? { params: opts.params } : {}),
        ...(opts.needsOperation ? { needsOperation: true } : {}),
        ...(opts.expectsParams ? { expectsParams: true } : {}),
        ...(opts.always && opts.suggest ? { suggest: true } : {}),
      },
    ]
  }
}

const DevModeCommand = {
  async interpret({ input }: { input: string }, ctx: HookContext): Promise<CommandInterpretation | null> {
    const trimmed = input.trim().toUpperCase()
    if (trimmed !== "DEVMODE" && trimmed !== "KONAMI") return null

    const devMode = !!ctx.developerMode
    const nextDevMode = !devMode
    return {
      describe: nextDevMode ? "Activate developer mode?" : "Deactivate developer mode?",
      confirm: nextDevMode ? "Developer mode activated" : "Developer mode deactivated",
      commands: [{ updateSettings: { developerMode: nextDevMode } }],
    }
  },

  catalog: devCatalog("DEVMODE", "Toggle developer mode"),
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
  { icon: "party-popper", title: "Random notice", text: "This is a **random** dev notice, generated to test the status bar." },
  { icon: "bug", title: "Heads up", text: "Here's another sample notice with *different* text, to check variety." },
  { icon: "flask", title: "Experiment running", text: "A third possible dev notice — multi-line bodies work too.\n\nLike this second line." },
]
const lastNoticeIndex = { value: -1 }

const DevNoticeCommand = {
  async interpret({ input }: { input: string }, _ctx: HookContext): Promise<CommandInterpretation | null> {
    if (input.trim().toUpperCase() !== "DEVNOTICE") return null
    const notice = pickNext(DEV_NOTICES, lastNoticeIndex)
    const key = `devNotice-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`
    return {
      describe: "Show a random dev notice?",
      confirm: "Added a random notice",
      commands: [{ devNotice: { key, ...notice } }],
    }
  },

  catalog: devCatalog("DEVNOTICE", "Post a sample notice to the status bar"),
}

const DEV_STATUSES = [
  { icon: "radio-tower", text: "Scanning band…" },
  { icon: "satellite-uplink", text: "Waiting for spots…" },
  { icon: "weather-lightning", text: "Checking propagation…" },
]
const lastStatusIndex = { value: -1 }

const DevStatusCommand = {
  async interpret({ input }: { input: string }, _ctx: HookContext): Promise<CommandInterpretation | null> {
    if (input.trim().toUpperCase() !== "DEVSTATUS") return null
    const status = pickNext(DEV_STATUSES, lastStatusIndex)
    // A fresh key per call — rather than always overwriting one fixed
    // "devStatus" slot — so repeated DEVSTATUS calls actually stack up as
    // separate items, demonstrating the footer's multi-item/"+N" behavior.
    const key = `devStatus-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`
    return {
      describe: "Show a random dev status message?",
      confirm: "Added a random status message",
      commands: [{ devStatus: { key, ...status } }],
    }
  },

  catalog: devCatalog("DEVSTATUS", "Post a sample status message"),
}

// "DEVPROGRESS" alone -> indeterminate; "DEVPROGRESS 10" -> 10%.
const DEV_PROGRESS_MATCH = /^DEVPROGRESS(?:\s+(\d+(?:\.\d+)?))?$/i

const DevProgressCommand = {
  async interpret({ input }: { input: string }, _ctx: HookContext): Promise<CommandInterpretation | null> {
    const match = DEV_PROGRESS_MATCH.exec(input.trim())
    if (!match) return null
    const percent = match[1] ? Math.min(100, Math.max(0, parseFloat(match[1]))) : undefined
    return {
      describe: percent === undefined ? "Show an indeterminate dev progress bar?" : `Show a dev progress bar at ${percent}%?`,
      confirm: percent === undefined ? "Added an indeterminate progress bar" : `Added a progress bar at ${percent}%`,
      commands: [{ devProgress: { icon: "progress-clock", title: "Dev progress", percent } }],
    }
  },

  catalog: devCatalog("DEVPROGRESS", "Post a sample progress bar", { params: "[percent]" }),
}

// "DEVHAMMER" alone -> the default run; "DEVHAMMER 20" -> 20 seconds of it.
const DEV_HAMMER_MATCH = /^DEVHAMMER(?:\s+(\d+))?$/i

const DevHammerCommand = {
  async interpret({ input }: { input: string }, _ctx: HookContext): Promise<CommandInterpretation | null> {
    const match = DEV_HAMMER_MATCH.exec(input.trim())
    if (!match) return null
    const seconds = match[1] ? Math.min(120, Math.max(1, parseInt(match[1], 10))) : undefined
    const howLong = seconds === undefined ? "" : ` for ${seconds}s`
    return {
      describe: `Churn the status bar${howLong}, like a data-file sync does?`,
      confirm: `Hammering the status bar${howLong} — focus a field and type`,
      commands: [{ devHammer: { seconds } }],
    }
  },

  catalog: devCatalog("DEVHAMMER", "Churn the status bar like a data-file sync", { params: "[seconds]" }),
}

const DevSplashCommand = {
  async interpret({ input }: { input: string }, _ctx: HookContext): Promise<CommandInterpretation | null> {
    if (input.trim().toUpperCase() !== "DEVSPLASH") return null
    return {
      describe: "Show the startup release-notes overlay?",
      confirm: "Showing the release-notes overlay",
      commands: [{ devSplash: {} }],
    }
  },

  catalog: devCatalog("DEVSPLASH", "Re-show the release-notes overlay"),
}

// DEVSPLASH's sibling for the first-run onboarding overlay:
// re-shows it on demand, bypassing its "default profile callsign undefined"
// gate — for iterating on the flow. The overlay is live: completing it
// (Done) applies its choices; Skip leaves existing settings untouched.
const DevOnboardCommand = {
  async interpret({ input }: { input: string }, _ctx: HookContext): Promise<CommandInterpretation | null> {
    if (input.trim().toUpperCase() !== "DEVONBOARD") return null
    return {
      describe: "Show the onboarding overlay?",
      confirm: "Showing the onboarding overlay — completing it applies its choices",
      commands: [{ devOnboard: {} }],
    }
  },

  catalog: devCatalog("DEVONBOARD", "Re-show the onboarding overlay"),
}

// DEVSPLASH's sibling for the tester overlay (the per-build "what's new for
// testers" with the caution tape): re-shows it on demand, bypassing its
// edition and last-seen-build gates.
const DevTesterCommand = {
  async interpret({ input }: { input: string }, _ctx: HookContext): Promise<CommandInterpretation | null> {
    if (input.trim().toUpperCase() !== "DEVTESTER") return null
    return {
      describe: "Show the tester-notes overlay?",
      confirm: "Showing the tester-notes overlay",
      commands: [{ devTester: {} }],
    }
  },

  catalog: devCatalog("DEVTESTER", "Re-show the tester-notes overlay"),
}

// Reopens the app in a standalone, chrome-less popup window sized like a
// phone screen — for checking phone-scale layout without a device. Web only;
// the app reports the "not on web" outcome itself, the EXP/DEVTT pattern.
const DevPopupCommand = {
  async interpret({ input }: { input: string }, _ctx: HookContext): Promise<CommandInterpretation | null> {
    if (input.trim().toUpperCase() !== "DEVPOPUP") return null
    return {
      describe: "Open the app in a standalone popup window?",
      commands: [{ devPopup: {} }],
    }
  },

  catalog: devCatalog("DEVPOPUP", "Open the app in a standalone, phone-sized popup window"),
}

// "DEVSENTRY" / "DEVSENTRY custom message" -> push a synthetic error through
// the app's error-reporting pipeline to verify the Sentry wiring end
// to end; the app reports back whether it uploaded or only logged locally
// (no DSN in this build). `mixedCase` keeps Space literal so bare DEVSENTRY
// stays executable while still extendable with a free-text message (the
// SEED pattern). No `confirm` — the app's outcome message is the feedback.
const DEVSENTRY_MATCH = /^DEVSENTRY(?:\s+(.+))?$/i

const DevSentryCommand = {
  async interpret({ input }: { input: string }, _ctx: HookContext): Promise<CommandInterpretation | null> {
    const match = DEVSENTRY_MATCH.exec(input.trim())
    if (!match) return null
    const message = match[1]?.trim()
    return {
      mixedCase: true,
      describe: message ? `Send a test error report ("${message}")?` : "Send a test error report?",
      commands: [{ devSentry: message ? { message } : {} }],
    }
  },

  catalog: devCatalog("DEVSENTRY", "Send a test error report", { params: "[message]" }),
}

// DEVBENCH [n]: log a synthetic CQ WW contest into a throwaway Test Operation
// and report what each phase cost as the log grew (HALO-119). The count is
// optional and defaults app-side.
//
// Developer mode only, and like DEVTT that gate is checked HERE as well as in
// the app — the sandbox can see `ctx.developerMode`, and returning null keeps
// the command from existing at all for an ordinary operator. The app checks
// again because this one writes several thousand contacts, and a gate that
// matters is not left to the caller.
//
// It DOES carry a `catalog`, unlike DEVTT: a benchmark that cleans up after
// itself is safe to discover, where a silently-travelled clock is not.
const DEVBENCH_MATCH = /^DEVBENCH(?:\s+(\d+))?$/i

const DevBenchCommand = {
  async interpret({ input }: { input: string }, ctx: HookContext): Promise<CommandInterpretation | null> {
    if (!ctx.developerMode) return null
    const match = DEVBENCH_MATCH.exec(input.trim())
    if (!match) return null
    const count = match[1] ? Number(match[1]) : null
    if (count !== null && count < 1) return { mixedCase: true, error: "DEVBENCH needs a positive number of QSOs" }
    // Refused here rather than clamped silently by the app: the confirmation
    // below quotes the number back, and quoting one the run will not use tells
    // the operator something untrue at the one moment they can still say no.
    if (count !== null && count > 20000) {
      return { mixedCase: true, error: "DEVBENCH tops out at 20000 QSOs" }
    }
    return {
      mixedCase: true,
      // Says "written and synced" because they are: the workload logs into a
      // real Test Operation, which syncs like any other and can surface on the
      // operator's other devices before the purge tombstones it back out.
      describe: count
        ? `Benchmark logging ${count} QSOs? They are written and synced, then removed.`
        : "Benchmark logging? Contacts are written and synced, then removed.",
      commands: [{ devBench: count === null ? {} : { qsoCount: count } }],
    }
  },

  catalog: devCatalog("DEVBENCH", "Benchmark logging a contest", { params: "[qsos]" }),
}

// DEVLOGCAT: records every byte to and from the equipment, or stops and sends
// the recording. One command both ways because only the app knows whether a
// recording is running, so the describe line names both and the app's own
// outcome message says which happened. Not gated on developer mode — it is
// run by operators whose rigs misbehave, and it changes nothing that is sent.
const DevLogCatCommand = {
  async interpret({ input }: { input: string }, _ctx: HookContext): Promise<CommandInterpretation | null> {
    if (input.trim().toUpperCase() !== "DEVLOGCAT") return null
    return {
      describe: "Record radio traffic, or stop and send the recording?",
      commands: [{ devLogCat: {} }],
    }
  },

  catalog: devCatalog("DEVLOGCAT", "Record radio traffic, or stop and send it"),
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

    const target = allShorthand || targetWord?.toUpperCase() === "ALL" ? "ALL" : targetWord?.toUpperCase()

    return {
      describe: target === "ALL" ? "Reload all data files?" : `Reload ${target} data files?`,
      confirm: target === "ALL" ? "Reloading all data files…" : `Reloading ${target} data files…`,
      commands: [{ reloadDataFiles: { target } }],
    }
  },

  catalog: devCatalog("RELOAD", "Re-sync data files", { always: true, params: "<POTA|SOTA|ALL>", expectsParams: true, suggest: true }),
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
    {
      input,
      operation,
      qso,
      execute,
    }: {
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
    if (!operation) return { error: "SEED needs an open operation" }
    if (!parsed.complete) return { expectsParams: true, mixedCase: true }

    const { count, spreadMillis, spreadLabel } = parsed
    const roughWhere = spreadLabel ? ` over ${spreadLabel}` : ""

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
    if (typeof operation.uuid === "string" && ctx.getQsos) {
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

    const mode = typeof qso?.mode === "string" ? qso.mode : "SSB"
    const band = typeof qso?.band === "string" ? qso.band : "20m"
    const freq = typeof qso?.freq === "number" ? qso.freq : undefined
    const stationCall = typeof operation.stationCall === "string" && operation.stationCall ? operation.stationCall : "N0CALL"

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

    const where = spreadLabel ? (plan.beforeExisting ? ` over ${spreadLabel}, before your earliest QSO` : ` over the last ${spreadLabel}`) : ""
    return {
      mixedCase: true,
      describe: `Seed the log with ${count} random QSOs${where}?`,
      confirm: `Seeding ${count} QSOs${where}…`,
      commands,
      // Seeded QSOs only ever carry the offline guess from lookupGuessFor
      // above — never real online lookup data, and SEED is for fabricating
      // test data quickly, not for accurate lookups, so there's no reason to
      // burn network lookups on made-up calls once they're on screen.
      skipOnlineLookup: true,
    }
  },

  catalog: devCatalog("SEED", "Fill the log with generated QSOs", { params: "[count] [hours]", needsOperation: true }),
}

/// Every key in the Callsign Notes index, via call-notes' `callNotes` hook —
/// in-runtime composition (like the lookup fan-out), no bridge round-trip.
/// Empty when call-notes isn't loaded or has no data yet.
async function allNotedCalls(): Promise<string[]> {
  const calls: string[] = []
  try {
    for (const entry of await hooks.invokeAll("callNotes", "allCalls", {})) {
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
      "lookupService",
      "lookupCallInfo",
      { callInfo: { call }, qso: qsoData, operation },
      false, // offline: seeding must stay fast (it re-runs while typing) and never hit QRZ/HamDB
    )
    const entry = entries.find((e) => e.ok && e.value)
    return (entry?.value as { guess?: JSONValue; lookups?: JSONValue } | undefined) ?? null
  } catch (e) {
    return null
  }
}

// EXP <key-or-alias> toggles an experimental feature. The catalog
// (app/experiments.yaml) and the stored state both live app-side; the app
// resolves the token again when it flips the state and reports the outcome
// (enabled/disabled/unknown) itself — hence no `confirm` here. The catalog
// in ctx serves only the preview, so the describe can say which way the
// toggle will go instead of a bare "toggle".
const EXP_MATCH = /^EXP(?:\s+(.+))?$/i

const ExpCommand = {
  async interpret({ input }: { input: string }, ctx: HookContext): Promise<CommandInterpretation | null> {
    const match = EXP_MATCH.exec(input.trim())
    if (!match) return null
    const token = match[1]?.trim()
    if (!token) return { expectsParams: true } // bare "EXP" — recognized, not complete yet
    // Still a recognized command with extra words — error out rather than
    // silently demoting "EXP LAYOUTS ON" back to callsign text (the field
    // invited free text via expectsParams, so Enter must not log it).
    if (/\s/.test(token)) return { error: "EXP takes a single experiment name" }

    // Case-insensitive like the app's own resolution: the call field
    // uppercases everything typed into it.
    const lower = token.toLowerCase()
    const experiment = ctx.experiments?.find((e) => e.key.toLowerCase() === lower || e.aliases.some((a) => a.toLowerCase() === lower))
    const commands = [{ toggleExperiment: { token } }]
    if (!experiment) return { describe: `Toggle experiment ${token.toUpperCase()}?`, commands }
    const enabled = ctx.enabledExperiments?.includes(experiment.key) ?? false
    return {
      describe: `${enabled ? "Disable" : "Enable"} experiment ${experiment.name.toUpperCase()}?`,
      commands,
    }
  },

  catalog: devCatalog("EXP", "Toggle an experimental feature", { params: "<name>", expectsParams: true }),
}

// DEVTT / DEVTIMETRAVEL move the app clock (docs/design/time.md): "DEVTT +3h",
// "DEVTT -1d", "DEVTT 2x", "DEVTT +1d 10x", and bare "DEVTT" back to real time.
// Offsets are cumulative, so the command steps.
//
// DELIBERATELY has no `catalog` — not even a developer-mode one. Every other
// command here can be found in the palette once developer mode is on; this one
// can only be typed, because the palette and the empty-field samples are
// discovery surfaces and a clock that silently disagrees with the operator's
// wristwatch is not something to discover by accident. `interpret` returning
// null outside developer mode makes it not exist there at all, and turning
// developer mode off puts the clock back (see the app's `devTimeTravel`
// action), so this can't be a trap door out of the gate.
//
// No `confirm`: only the app knows what time it ends up at, and it reports
// that itself — the EXP pattern. Same reason the sync-account and
// developer-mode gates live app-side: neither is visible from here.
const DevTimeTravelCommand = {
  async interpret({ input }: { input: string }, ctx: HookContext): Promise<CommandInterpretation | null> {
    if (!ctx.developerMode) return null
    const request = parseTimeTravelCommand(input)
    if (!request) return null

    // mixedCase for the SEED reason: it keeps Space a literal character, so a
    // complete "DEVTT" can still be extended to "DEVTT +3h".
    if (request.kind === "error") return { mixedCase: true, error: request.error }

    return {
      mixedCase: true,
      describe: describeTimeTravel(request),
      commands: [
        {
          devTimeTravel:
            request.kind === "reset" ? { reset: true } : { deltaMillis: request.deltaMillis, ...(request.speed === null ? {} : { speed: request.speed }) },
        },
      ],
    }
  },
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
  ...manifest,
  onActivation({ registerHook }) {
    registerHook("command", { key: "dev-commands-devmode", hook: DevModeCommand, priority: 100 })
    registerHook("command", { key: "dev-commands-devnotice", hook: DevNoticeCommand, priority: 100 })
    registerHook("command", { key: "dev-commands-devstatus", hook: DevStatusCommand, priority: 100 })
    registerHook("command", { key: "dev-commands-devprogress", hook: DevProgressCommand, priority: 100 })
    registerHook("command", { key: "dev-commands-devhammer", hook: DevHammerCommand, priority: 100 })
    registerHook("command", { key: "dev-commands-devsplash", hook: DevSplashCommand, priority: 100 })
    registerHook("command", { key: "dev-commands-devonboard", hook: DevOnboardCommand, priority: 100 })
    registerHook("command", { key: "dev-commands-devtester", hook: DevTesterCommand, priority: 100 })
    registerHook("command", { key: "dev-commands-devpopup", hook: DevPopupCommand, priority: 100 })
    registerHook("command", { key: "dev-commands-devsentry", hook: DevSentryCommand, priority: 100 })
    registerHook("command", { key: "dev-commands-reload", hook: ReloadCommand, priority: 100 })
    registerHook("command", { key: "dev-commands-seed", hook: SeedCommand, priority: 100 })
    registerHook("command", { key: "dev-commands-exp", hook: ExpCommand, priority: 100 })
    registerHook("command", { key: "dev-commands-devtimetravel", hook: DevTimeTravelCommand, priority: 100 })
    registerHook("command", { key: "dev-commands-devbench", hook: DevBenchCommand, priority: 100 })
    registerHook("command", { key: "dev-commands-devlogcat", hook: DevLogCatCommand, priority: 100 })
  },
})
