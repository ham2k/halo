// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// The one copy of an operation's log that every extension in this runtime
// reads through `ctx.getQsos`.
//
// Reading the log across the bridge costs the whole log every time — at 2000
// contacts about 47 ms, most of it the database read and the transfer into
// the engine, against a few for the work a panel then does with it. So the
// kernel keeps the log here and asks the host only what changed since the
// cursor it holds (`getQsoChanges`, `QsosRepository.changesSince`). The host
// answers with the whole log, `reset`, whenever it cannot tell — a cursor it
// never issued, one older than its ledger — so a copy is never wrong for
// long, and a fresh runtime simply starts from a reset.
//
// `getQsos` keeps its contract: every call asks the host first, so a list is
// never staler than the call, and every caller gets a fresh array. What it
// shares is the QSOs themselves — frozen, and handed only to an extension
// declaring the API level that promised they would be. An older one may
// mutate what it is handed, as it always could, so it gets copies.

type Qso = Record<string, unknown>

/// The first extension API level handed the shared QSOs frozen; an older one
/// may mutate what `getQsos` returns, and gets copies.
export const FROZEN_QSOS_API = 9

/// What the host answers `getQsoChanges` with; null where `getQsos` is null.
/// [count] is how many contacts the log holds after these changes.
export type LogChanges = { cursor: string; reset: boolean; qsos: Qso[]; removed: string[]; count?: number }

/// How a host older than `getQsoChanges` refuses it. Matched whole: a looser
/// test would read any "not implemented" from inside the host's own read as
/// the host lacking the call, and give up on the copy for the session.
const UNSUPPORTED = "Host call method getQsoChanges not implemented"

export type LogSource = {
  changes(operationUuid: string, cursor: string | undefined): Promise<LogChanges | null>
  /// The whole log, for a host that does not answer `getQsoChanges`.
  whole(operationUuid: string): Promise<Qso[] | null>
}

export type LogCopies = {
  /// The operation's log, oldest first, as `ctx.getQsos` answers. [frozen]
  /// shares the copy's QSOs; otherwise each call gets QSOs of its own.
  read(operationUuid: string, options: { frozen: boolean }): Promise<Qso[] | null>
  /// The contacts [uuids] name, in that order, from the same up-to-date copy
  /// — those of them it still holds. Picked from the copy's own index, and
  /// only those copied when not [frozen].
  pick(operationUuid: string, uuids: string[], options: { frozen: boolean }): Promise<Qso[] | null>
}

type Copy = {
  cursor?: string
  rows: Map<string, Qso>
  /// Oldest first, rebuilt when the rows change.
  list: Qso[]
  /// [list] serialized once per change, for the callers that get copies.
  json?: string
  /// Syncs run one at a time per log. Two at once could both send the same
  /// cursor and apply their answers in either order, leaving the cursor
  /// ahead of the rows.
  queue: Promise<unknown>
}

/// How many logs are kept. The open operation's is the one that matters; a
/// few more cover a panel reading another, without letting a session that
/// visits many operations hold all of them.
const KEEP = 3

const startOf = (qso: Qso) => (typeof qso.startAtMillis === "number" ? qso.startAtMillis : -Infinity)

export function deepFreeze<T>(value: T): T {
  if (value && typeof value === "object" && !Object.isFrozen(value)) {
    Object.freeze(value)
    for (const child of Object.values(value)) deepFreeze(child)
  }
  return value
}

export function createLogCopies(source: LogSource, keep = KEEP): LogCopies {
  const copies = new Map<string, Copy>()
  let unsupported = false

  function copyFor(operationUuid: string): Copy {
    let copy = copies.get(operationUuid)
    if (copy) copies.delete(operationUuid)
    else copy = { rows: new Map(), list: [], queue: Promise.resolve() }
    // Re-inserted, so the Map's order is least recently used first.
    copies.set(operationUuid, copy)
    for (const stale of copies.keys()) {
      if (copies.size <= keep) break
      copies.delete(stale)
    }
    return copy
  }

  /// Brings [copy] up to date; false when the host knows no such log.
  async function sync(operationUuid: string, copy: Copy): Promise<boolean> {
    let changes = await source.changes(operationUuid, copy.cursor)
    if (changes === null) return false
    // A copy that ends up holding another number of contacts than the log has
    // missed a write the host's ledger never saw. Rather than keep a copy
    // known to be wrong, ask for the whole log once.
    const held = apply(copy, changes)
    if (!changes.reset && typeof changes.count === "number" && held !== changes.count) {
      changes = await source.changes(operationUuid, undefined)
      if (changes === null) return false
      apply(copy, changes)
    }
    if (changes.reset || changes.qsos.length > 0 || changes.removed.length > 0) {
      // Stable, so contacts that start together keep the order the host gave them.
      copy.list = [...copy.rows.values()].sort((a, b) => startOf(a) - startOf(b))
      copy.json = undefined
    }
    copy.cursor = changes.cursor
    return true
  }

  /// Applies [changes] to [copy]'s rows, returning how many it then holds.
  function apply(copy: Copy, changes: LogChanges): number {
    if (changes.reset) copy.rows.clear()
    for (const qso of changes.qsos) copy.rows.set(String(qso.uuid), deepFreeze(qso))
    for (const uuid of changes.removed) copy.rows.delete(uuid)
    return copy.rows.size
  }

  /// [operationUuid]'s copy, brought up to date; null when the host knows no
  /// such log, [UNSUPPORTED] when the host is older than `getQsoChanges`.
  async function synced(operationUuid: string): Promise<Copy | null | typeof UNSUPPORTED> {
    if (unsupported) return UNSUPPORTED
    const copy = copyFor(operationUuid)
    const run = copy.queue.then(() => sync(operationUuid, copy))
    copy.queue = run.catch(() => undefined)
    let known: boolean
    try {
      known = await run
    } catch (error) {
      // A host older than `getQsoChanges` says so once; everything else is
      // a failure `getQsos` would have had too, and is the caller's to see.
      if (!String((error as Error)?.message ?? error).includes(UNSUPPORTED)) throw error
      unsupported = true
      copies.clear()
      return UNSUPPORTED
    }
    if (known) return copy
    copies.delete(operationUuid)
    return null
  }

  return {
    async read(operationUuid, { frozen }) {
      const copy = await synced(operationUuid)
      if (copy === null || copy === UNSUPPORTED) return copy === null ? null : source.whole(operationUuid)
      if (frozen) return copy.list.slice()
      copy.json ??= JSON.stringify(copy.list)
      return JSON.parse(copy.json) as Qso[]
    },

    async pick(operationUuid, uuids, { frozen }) {
      const copy = await synced(operationUuid)
      if (copy === null) return null
      const rows = copy === UNSUPPORTED ? new Map((await source.whole(operationUuid))?.map((qso) => [String(qso.uuid), qso]) ?? []) : copy.rows
      const picked = uuids.flatMap((uuid) => (rows.has(uuid) ? [rows.get(uuid)!] : []))
      return frozen || copy === UNSUPPORTED ? picked : (JSON.parse(JSON.stringify(picked)) as Qso[])
    },
  }
}
