// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// What the operator does, for agent apps to wait on (docs/design/agent-link.md
// § Events). MCP lets the app answer only what the agent asks, so the agent
// asks `wait_for_events` and is answered when something happens. The events
// come from this extension's own assistant, which watches as any assistant
// does, and wait in one queue every connection reads with its own cursor.

import type { AssistantHook, HookContext, JSONValue, ObserveArgs } from "@ham2k/extension-sdk"
import { tFor } from "./i18n.ts"

type EventType = "operationOpened" | "operationChanged" | "qsoLogged" | "radio" | "equipment" | "spots"

interface EventFields {
  [key: string]: JSONValue | undefined
}

export interface NewEvent extends EventFields {
  /// The app clock's time it happened.
  atMillis: number
  type: EventType
  operationUuid?: string
}

export interface AgentEvent extends NewEvent {
  seq: number
}

/// How many events the queue keeps; an agent that falls further behind is
/// told it `missed` some.
export const MAX_EVENTS = 200

/// The longest the app holds a wait for an agent.
export const MAX_WAIT_SECONDS = 45

/// The board refreshes every few seconds; an agent needs to know it moved,
/// not each time.
const SPOTS_EVERY_MS = 60_000

export interface ReadResult {
  events: AgentEvent[]
  /// What to pass as `after` next time.
  cursor: number
  /// Events past `after` that the queue no longer holds, or a cursor from
  /// before the extension last started, whose events are gone.
  missed: boolean
}

/// The events waiting for agents. It never waits itself: a hook call held
/// open keeps the extension engine pumping its jobs every few milliseconds,
/// so a wait is held by the app instead (`Hold` in mcp.ts), which asks
/// again after this extension's assistant has observed something.
export class EventQueue {
  private events: AgentEvent[] = []
  private seq: number
  private lastStation = new Map<string, string>()
  private lastSpotsAt = -Infinity

  /// [start] is where this queue's cursors begin. Each runtime picks its own,
  /// far from any other's, so an agent holding a cursor from before the
  /// extension restarted lands outside this queue's events, past its end or
  /// before its first, and is told it missed some. Counting from zero, a
  /// queue that had passed the old cursor would skip its own first events.
  constructor(start = Math.floor(Math.random() * 1e9) * 1000) {
    this.seq = start
  }

  /// Where an agent that asks for events "from now on" starts.
  get cursor(): number {
    return this.seq
  }

  push(event: NewEvent): void {
    this.events.push({ ...event, seq: ++this.seq })
    if (this.events.length > MAX_EVENTS) this.events.splice(0, this.events.length - MAX_EVENTS)
  }

  /// Station-wide events arrive once per open operation; this keeps one per
  /// change of [summary].
  pushStation(type: "radio" | "equipment", summary: string, event: EventFields & { atMillis: number }): void {
    if (this.lastStation.get(type) === summary) return
    this.lastStation.set(type, summary)
    this.push({ ...event, type })
  }

  /// At most one a minute of real time, [realNowMillis]: paced by the app
  /// clock, time travel back would silence it.
  pushSpots(event: { atMillis: number }, realNowMillis: number): void {
    if (realNowMillis - this.lastSpotsAt < SPOTS_EVERY_MS) return
    this.lastSpotsAt = realNowMillis
    this.push({ ...event, type: "spots" })
  }

  /// The events after [after].
  read(after: number): ReadResult {
    // A cursor past the queue's own is one a runtime before this one gave:
    // read as "nothing new", it would hold the agent until this queue caught
    // up with a count it never had.
    if (after > this.seq) return { events: [...this.events], cursor: this.seq, missed: true }
    const events = this.events.filter((e) => e.seq > after)
    const oldest = this.events[0]?.seq ?? this.seq + 1
    return { events, cursor: this.seq, missed: after < this.seq && oldest > after + 1 }
  }
}

/// The assistant that fills [queue]. Its switch is under Settings ›
/// Assistants; while it is off, agents wait in vain.
export function eventsAssistant(queue: EventQueue, station: { readRadio(): Promise<unknown>; listEquipment(): Promise<unknown> }): AssistantHook {
  /// Per operation, the contacts it held at the last look, by uuid: a
  /// contact logged with an earlier time sorts into the middle of the log,
  /// so the newest are not always the last.
  const known = new Map<string, Set<string>>()
  const details = new Map<string, string>()
  return {
    async getAssistants(_args, ctx) {
      const t = tFor(ctx)
      return [
        {
          key: "events",
          title: t("assistantTitle"),
          description: t("assistantDescription"),
          icon: "robot-outline",
          on: ["operation", "qsoLogged", "radio", "equipment", "spots"],
        },
      ]
    },
    async observe(args: ObserveArgs, ctx: HookContext) {
      const { operation, reasons, clock } = args
      const uuid = operation.uuid as string
      const atMillis = clock.nowMillis
      const now = detailsOf(operation)
      // `open` comes again for an operation already open whenever the
      // assistants are read again, folded with whatever else fired: an
      // operation seen before keeps its contacts to compare against, or a
      // contact logged in the same moment would be taken for one it had.
      if (reasons.includes("open") || !details.has(uuid)) {
        details.set(uuid, now)
        queue.push({ type: "operationOpened", atMillis, ...describe(operation) })
      } else if (reasons.includes("operation") && details.get(uuid) !== now) {
        details.set(uuid, now)
        queue.push({ type: "operationChanged", atMillis, ...describe(operation) })
      }
      if (reasons.includes("qsoLogged") || reasons.includes("open")) await qsosLogged(queue, ctx, uuid, known, atMillis)
      // Spots first, needing no read; then the station's reads side by side,
      // so one that fails costs only its own event, and is still reported.
      if (reasons.includes("spots")) queue.pushSpots({ atMillis }, clock.realNowMillis)
      const reads = await Promise.allSettled([
        reasons.includes("radio")
          ? station.readRadio().then((radio) => queue.pushStation("radio", summaryOf(radio), { atMillis, radio: (radio ?? null) as JSONValue }))
          : null,
        reasons.includes("equipment")
          ? station
              .listEquipment()
              .then((equipment) => queue.pushStation("equipment", JSON.stringify(equipment), { atMillis, equipment: equipment as JSONValue }))
          : null,
      ])
      const failed = reads.find((read) => read.status === "rejected")
      if (failed) throw failed.reason
    },
  }
}

/// How many contacts one `qsoLogged` event carries: an import logs
/// thousands at once, and every waiting agent would get all of them.
export const MAX_EVENT_QSOS = 50

async function qsosLogged(queue: EventQueue, ctx: HookContext, uuid: string, known: Map<string, Set<string>>, atMillis: number) {
  const qsos = await ctx.getQsos?.(uuid)
  // An unreadable log says nothing about what was logged; taken as empty, the
  // next good read would report the whole log as new.
  if (!qsos) return
  const before = known.get(uuid)
  known.set(uuid, keysOf(qsos))
  if (!before) return
  const added = qsos.filter((q) => q.band !== "event" && !before.has(keyOf(q)))
  if (added.length === 0) return
  queue.push({
    type: "qsoLogged",
    atMillis,
    operationUuid: uuid,
    count: added.length,
    ...(added.length > MAX_EVENT_QSOS ? { truncated: true } : {}),
    qsos: added.slice(0, MAX_EVENT_QSOS) as JSONValue,
  })
}

function keyOf(qso: Record<string, JSONValue>): string {
  return typeof qso.uuid === "string" ? qso.uuid : JSON.stringify(qso)
}

function keysOf(qsos: Record<string, JSONValue>[]): Set<string> {
  return new Set(qsos.map(keyOf))
}

/// What changing the radio means to an agent: where it is and what it sends,
/// not every meter reading.
function summaryOf(radio: unknown): string {
  if (!radio || typeof radio !== "object") return "none"
  const r = radio as Record<string, unknown>
  // To the kHz: a dial being turned is one change when it stops, near enough.
  const khz = typeof r.frequencyHz === "number" ? Math.round(r.frequencyHz / 1000) : null
  return JSON.stringify([r.id, khz, r.mode, r.status, r.transmitting])
}

/// What logging a contact moves on an operation, by itself: its counters,
/// its contacts' times, and its status, which the first contact makes
/// active.
const MOVED_BY_LOGGING = new Set(["uuid", "qsoCount", "startAtMillisMin", "startAtMillisMax", "status", "statusAtMillis", "updatedAtMillis", "updatedOnMillis"])

/// Everything else on an operation, as one string to compare.
function detailsOf(operation: Record<string, JSONValue>): string {
  return JSON.stringify(
    Object.keys(operation)
      .sort()
      .flatMap((key) => (MOVED_BY_LOGGING.has(key) ? [] : [[key, operation[key]]])),
  )
}

function describe(operation: Record<string, JSONValue>): EventFields {
  const own = operation.userTitle
  const title = typeof own === "string" && own ? own : typeof operation.title === "string" ? operation.title : ""
  return { operationUuid: operation.uuid as string, title, stationCall: (operation.stationCall as string) ?? "" }
}
