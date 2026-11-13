// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// What an agent app can ask of the station (docs/design/agent-link.md
// § Tools). Each tool is one of the host's own calls, under the same grants
// an assistant has. Reading, and talking to the operator on the FYI line or
// in a notice, is watching; the rest is making changes. Nothing here
// transmits, posts to the cluster or logs a contact: the agent fills in the
// contact, and the operator logs it.

import type { GetSpotsOptions, HookContext, host, JSONValue } from "@ham2k/extension-sdk"
import { MAX_WAIT_SECONDS, type EventQueue } from "./events.ts"
import { Hold, type Tool } from "./mcp.ts"

type Host = Pick<
  typeof host,
  | "readRadio"
  | "listRadios"
  | "listEquipment"
  | "setRadio"
  | "setAntenna"
  | "setRotator"
  | "stopRotator"
  | "updateDraft"
  | "searchSettings"
  | "updateSetting"
  | "fyi"
  | "statusBar"
  | "spots"
  | "bandAnnotations"
  | "layouts"
>
type Args = Record<string, JSONValue>
type Schema = Record<string, JSONValue>

function tool(name: string, title: string, access: Tool["access"], description: string, properties: Schema, run: Tool["run"], required: string[] = []): Tool {
  return {
    name,
    title,
    description,
    access,
    inputSchema: { type: "object", properties, ...(required.length ? { required } : {}), additionalProperties: false },
    run,
  }
}

const str = (description: string): Schema => ({ type: "string", description })
const num = (description: string): Schema => ({ type: "number", description })
const bool = (description: string): Schema => ({ type: "boolean", description })
const obj = (description: string): Schema => ({ type: "object", description })
const strings = (description: string): Schema => ({ type: "array", items: { type: "string" }, description })

const operationArg = str("An operation's uuid, from list_operations. The one in front when left out.")

function text(args: Args, key: string): string | undefined {
  const value = args[key]
  return typeof value === "string" && value ? value : undefined
}

function count(args: Args, key: string, fallback: number, max: number): number {
  const value = args[key]
  return typeof value === "number" && value > 0 ? Math.min(Math.floor(value), max) : fallback
}

/// The operation [args] name, or the one in front.
async function operationOf(args: Args, ctx: HookContext): Promise<string> {
  const named = text(args, "operationUuid")
  if (named) return named
  const front = await frontOperation(ctx)
  if (!front) throw new Error("No operation is open; name one with operationUuid")
  return front
}

/// A change's answer, as the agent reads it: a refusal throws, so the agent
/// is told it failed, and why, rather than reading `accepted: false` as
/// something to report as done.
async function acted(name: string, answer: Promise<unknown>): Promise<JSONValue> {
  const result = (await answer) as Record<string, JSONValue> | null
  if (result && typeof result === "object" && result.accepted === false) {
    const why = [result.reason, result.message].filter((part) => typeof part === "string" && part).join(": ")
    throw new Error(`${name} was refused${why ? `: ${why}` : ""}`)
  }
  return result as JSONValue
}

/// The operation in front, or none: for a read that is still worth making
/// without one.
async function frontOperation(ctx: HookContext): Promise<string | undefined> {
  const [front] = (await ctx.listOperations?.({ open: true, limit: 1 })) ?? []
  return front?.front ? front.uuid : undefined
}

/// A key on the FYI line or for a notice: the agent's own words, kept to
/// what the host takes.
function messageKey(args: Args): string {
  return (text(args, "key") ?? "agent").replace(/[^A-Za-z0-9_.-]/g, "-").slice(0, 64)
}

export function readTools(station: Host, queue: EventQueue): Tool[] {
  return [
    tool(
      "wait_for_events",
      "Wait for events",
      "watch",
      "Waits for what the operator does: an operation opened or changed, contacts logged (with the contacts), the radio or equipment changing, the spots board moving. " +
        "Answers at once when events past `after` are waiting, otherwise when one comes or `timeoutSeconds` pass. Pass the `cursor` it answers as `after` next time; " +
        "without `after` it waits for events from now on. `missed` means events were dropped while you were away. " +
        "Events come only while an operation is open (`operationsOpen` says how many) and the operator has the Agent apps assistant on.",
      { after: num("The cursor the last call answered."), timeoutSeconds: num(`How long to wait, 0 to ${MAX_WAIT_SECONDS}. Default 30.`) },
      async (args, ctx) => {
        const seconds = typeof args.timeoutSeconds === "number" ? Math.min(Math.max(0, args.timeoutSeconds), MAX_WAIT_SECONDS) : 30
        const result = queue.read(typeof args.after === "number" ? args.after : queue.cursor)
        const open = (await ctx.listOperations?.({ open: true })) ?? []
        const answer = { ...result, operationsOpen: open.length } as unknown as JSONValue
        // Nothing yet: the app holds the request, and asks again from this
        // cursor, so what comes meanwhile is not taken for "from now on".
        if (result.events.length === 0 && !result.missed && seconds > 0) return new Hold(answer, seconds, { after: result.cursor, timeoutSeconds: seconds })
        return answer
      },
    ),
    tool(
      "list_operations",
      "Operations",
      "watch",
      "The operator's operations, the most recent first: title, station call, references, grid, contact count, first and last contact times, and whether each is open now and in front.",
      { limit: num("At most this many. Default 50, at most 500.") },
      async (args, ctx) => {
        if (!ctx.listOperations) throw new Error("This app cannot list operations")
        return { operations: (await ctx.listOperations({ limit: count(args, "limit", 50, 500) })) as unknown as JSONValue }
      },
    ),
    tool("get_operation", "Operation", "watch", "One operation's details, as the app stores them.", { operationUuid: operationArg }, async (args, ctx) => {
      const operation = await ctx.getOperation?.(await operationOf(args, ctx))
      if (!operation) throw new Error("No such operation")
      return operation
    }),
    tool(
      "get_qsos",
      "Contacts",
      "watch",
      "The contacts logged in an operation, oldest first: the latest `limit` of them, or those since `sinceMillis`. Event markers have `band: 'event'`.",
      {
        operationUuid: operationArg,
        limit: num("At most this many, the latest. Default 50, at most 1000."),
        sinceMillis: num("Only contacts that started at or after this time."),
      },
      async (args, ctx) => {
        const uuid = await operationOf(args, ctx)
        const qsos = await ctx.getQsos?.(uuid)
        if (!qsos) throw new Error("No such operation")
        const since = typeof args.sinceMillis === "number" ? args.sinceMillis : undefined
        const picked = since === undefined ? qsos : qsos.filter((q) => Number(q.startAtMillis ?? 0) >= since)
        // `matched` beside the page: past `limit`, the earliest matches are
        // left out, and an agent catching up by time must see that it was.
        return { operationUuid: uuid, total: qsos.length, matched: picked.length, qsos: picked.slice(-count(args, "limit", 50, 1000)) }
      },
    ),
    tool(
      "get_call_history",
      "Call history",
      "watch",
      "The latest contacts with a callsign across every operation, newest first.",
      { call: str("The callsign."), limit: num("At most this many. Default 5, at most 50.") },
      async (args, ctx) => ({ qsos: (await ctx.getHistoryForCall?.(String(args.call), { limit: count(args, "limit", 5, 50) })) ?? [] }),
      ["call"],
    ),
    tool(
      "find_calls",
      "Find calls",
      "watch",
      "The callsigns in the log that a partial one could be: exact, containing it, or one edit away. `?` stands for any one character.",
      { call: str("The partial callsign."), limit: num("At most this many. Default 20, at most 100.") },
      async (args, ctx) => ({ calls: ((await ctx.findCalls?.(String(args.call), { limit: count(args, "limit", 20, 100) })) ?? []) as unknown as JSONValue }),
      ["call"],
    ),
    tool(
      "get_radio",
      "Radio",
      "watch",
      "A radio's state as the app last read it: frequency (Hz), mode, power, whether it is transmitting, meters. The logging radio when `id` is left out; null when none is connected.",
      { id: str("A radio's id, from list_radios.") },
      async (args) => ((await station.readRadio(text(args, "id"))) ?? null) as unknown as JSONValue,
    ),
    tool("list_radios", "Radios", "watch", "Every radio the app knows, with its state.", {}, async () => ({
      radios: (await station.listRadios()) as unknown as JSONValue,
    })),
    tool("list_equipment", "Equipment", "watch", "The antenna switches and rotators: each port's antenna, a rotator's heading.", {}, async () => ({
      equipment: (await station.listEquipment()) as unknown as JSONValue,
    })),
    tool(
      "get_spots",
      "Spots",
      "watch",
      "Spots the app holds, as the operator's Spots panel filters them: call, frequency, mode, source, and, judged against an operation, whether each is worked or a new multiplier. " +
        "Each has the `id` mark_spots takes. `judged` is false when there was no operation to judge them against.",
      {
        band: str("A band, as the app writes it: '20m'."),
        mode: str("A mode ('FT8') or a family ('CW', 'Phone', 'Digital')."),
        maxAgeMinutes: num("Only spots this recent."),
        limit: num("At most this many, newest first. Default 50, at most 500."),
        operationUuid: str("The operation to judge them against. The one in front when left out."),
      },
      async (args, ctx) => {
        if (!ctx.getSpots) throw new Error("This app cannot list spots")
        const options: GetSpotsOptions = {}
        if (text(args, "band")) options.band = text(args, "band")
        if (text(args, "mode")) options.mode = text(args, "mode")
        if (typeof args.maxAgeMinutes === "number") options.maxAgeMinutes = args.maxAgeMinutes
        // The hook the agent's call runs in was handed no operation, so none
        // is judged against unless named: the verdicts would be missing, and
        // read as "not worked".
        const operationUuid = text(args, "operationUuid") ?? (await frontOperation(ctx))
        if (operationUuid) options.operationUuid = operationUuid
        const spots = await ctx.getSpots(options)
        return { judged: operationUuid !== undefined, spots: spots.slice(0, count(args, "limit", 50, 500)) as unknown as JSONValue }
      },
    ),
    tool(
      "get_band_annotations",
      "Band annotations",
      "watch",
      "What is said about a band: the operator's band tags, and what extensions marked on it.",
      { band: str("A band, as the app writes it: '20m'.") },
      async (args, ctx) => ({ annotations: ((await ctx.getBandAnnotations?.({ band: String(args.band) })) ?? []) as unknown as JSONValue }),
      ["band"],
    ),
    tool(
      "search_settings",
      "Find a setting",
      "watch",
      "Finds a setting by the words the operator would type after SET, and the value those words would give it: its `key` is what update_setting takes.",
      { query: str("A setting's name, then optionally a value: 'theme dark'.") },
      async (args) => (await station.searchSettings({ args: String(args.query ?? "") })) as unknown as JSONValue,
      ["query"],
    ),
    tool("list_layouts", "Layouts", "watch", "Each view's layouts, the one drawn, and the panels an open view holds.", {}, async () => ({
      views: (await station.layouts.list()) as unknown as JSONValue,
    })),
    tool(
      "post_fyi",
      "Say on the FYI line",
      "watch",
      "Puts one line under the call info, replacing your line under the same `key`. Keep it short: the operator reads it while operating. You hold at most four.",
      {
        text: str("One line, inline markdown, at most 256 characters."),
        key: str("Your name for the line, to replace or clear it. Default 'agent'."),
        category: { type: "string", enum: ["alert", "warning", "operational", "info"], description: "How it reads. Default 'info'." },
        icon: str("A Material Design Icons name. Default 'robot-outline'."),
        expiresInSeconds: num("Takes it down on its own after this long."),
      },
      async (args) => {
        const category = (text(args, "category") ?? "info") as "alert" | "warning" | "operational" | "info"
        const expires = typeof args.expiresInSeconds === "number" ? { expiresInSeconds: args.expiresInSeconds } : {}
        await station.fyi.post({ key: messageKey(args), category, text: String(args.text ?? ""), icon: text(args, "icon") ?? "robot-outline", ...expires })
        return { posted: true }
      },
      ["text"],
    ),
    tool("clear_fyi", "Clear the FYI line", "watch", "Takes down your line under `key`.", { key: str("Default 'agent'.") }, async (args) => {
      await station.fyi.clear(messageKey(args))
      return { cleared: true }
    }),
    tool(
      "show_notice",
      "Show a notice",
      "watch",
      "A notice over the footer that stays until the operator dismisses it: for what needs their attention, not a running commentary. At most ten a minute.",
      { text: str("Markdown."), title: str("A title."), key: str("Your name for it; a notice under the same key replaces it. Default 'agent'.") },
      async (args) => {
        const title = text(args, "title")
        await station.statusBar.showNotice({ key: messageKey(args), text: String(args.text ?? ""), icon: "robot-outline", ...(title ? { title } : {}) })
        return { shown: true }
      },
      ["text"],
    ),
  ]
}

export function changeTools(station: Host): Tool[] {
  return [
    tool(
      "update_draft",
      "Fill in the contact",
      "change",
      "Changes the contact the operator is composing, as typing in its fields would; the operator logs it. A patch merges key by key ({ their: { sent: '599' } } keeps the call); null clears a field. " +
        "With `replace` it starts a new contact instead, and needs their.call. Setting freq, band or mode moves the radio too. Refused when the operation is not open in front.",
      {
        patch: obj("QSON fields: their.call, their.sent, our.sent, freq, band, mode, refs, notes…"),
        replace: bool("Start a new contact."),
        operationUuid: operationArg,
      },
      async (args) => {
        const operationUuid = text(args, "operationUuid")
        return await acted(
          "update_draft",
          station.updateDraft(args.patch as never, {
            replace: args.replace === true,
            ...(operationUuid ? { operationUuid } : {}),
          }),
        )
      },
      ["patch"],
    ),
    tool(
      "set_radio",
      "Set the radio",
      "change",
      "Tunes or sets a radio: frequency, mode, power, keyer speed, filter, antenna. Never transmits.",
      {
        id: str("A radio's id, from list_radios. The logging radio when left out."),
        frequencyHz: num("The frequency, in Hz."),
        mode: str("One of the radio's modes."),
        powerWatts: num("Power, in watts."),
        keyerSpeedWpm: num("The keyer's speed."),
        passband: obj("The receive filter: { lowHz, highHz }."),
        antenna: obj("Ports: { rx?, tx? }."),
      },
      async (args) => {
        const id = text(args, "id") ?? (await station.readRadio())?.id
        if (!id) throw new Error("No radio is connected")
        const set: Args = { id }
        for (const key of ["frequencyHz", "mode", "powerWatts", "keyerSpeedWpm", "passband", "antenna"]) if (args[key] !== undefined) set[key] = args[key]
        return await acted("set_radio", station.setRadio(set as never))
      },
    ),
    tool(
      "set_antenna",
      "Pick an antenna",
      "change",
      "Puts an antenna switch's port on an antenna.",
      { id: str("The switch, from list_equipment."), port: str("Its port."), antenna: str("The antenna.") },
      async (args) => await acted("set_antenna", station.setAntenna({ id: String(args.id), port: String(args.port), antenna: String(args.antenna) })),
      ["id", "port", "antenna"],
    ),
    tool(
      "set_rotator",
      "Turn a rotator",
      "change",
      "Turns a rotator to a heading.",
      { id: str("The rotator, from list_equipment."), azimuth: num("Degrees from north."), elevation: num("Degrees, where it turns in elevation.") },
      async (args) => {
        const elevation = typeof args.elevation === "number" ? { elevation: args.elevation } : {}
        return await acted("set_rotator", station.setRotator({ id: String(args.id), azimuth: Number(args.azimuth), ...elevation }))
      },
      ["id", "azimuth"],
    ),
    tool(
      "stop_rotator",
      "Stop a rotator",
      "change",
      "Stops a rotator where it is.",
      { id: str("The rotator.") },
      async (args) => {
        return await acted("stop_rotator", station.stopRotator({ id: String(args.id) }))
      },
      ["id"],
    ),
    tool(
      "mark_spots",
      "Mark spots",
      "change",
      "Puts your word on spots, by the `id` get_spots gives them: an icon, a color, a note, a boost up the list, or hiding them. Replaces what you said before about those ids.",
      { ids: strings("Spot ids."), mark: obj("{ icon?, color? ('#RRGGBB'), note?, boost?, hidden? }") },
      async (args) => {
        await station.spots.mark(args.ids as string[], (args.mark ?? {}) as never)
        return { marked: true }
      },
      ["ids", "mark"],
    ),
    tool(
      "unmark_spots",
      "Unmark spots",
      "change",
      "Takes your marks off those spots, or off every spot.",
      { ids: strings("Spot ids; every one you marked when left out.") },
      async (args) => {
        await station.spots.unmark(args.ids === undefined ? undefined : (args.ids as string[]))
        return { unmarked: true }
      },
    ),
    tool(
      "annotate_band",
      "Annotate a band",
      "change",
      "Marks stretches of bands, for every panel that draws them, replacing yours under the same key.",
      {
        annotations: {
          type: "array",
          items: { type: "object" },
          description: "Band annotations: { key, band, lowHz?, highHz?, label, importance?, expiresAtMillis? }.",
        },
      },
      async (args) => {
        await station.bandAnnotations.put(args.annotations as never)
        return { put: true }
      },
      ["annotations"],
    ),
    tool(
      "clear_band_annotations",
      "Clear band annotations",
      "change",
      "Takes away your band annotations under those keys, or all of them.",
      { keys: strings("Keys; all of yours when left out.") },
      async (args) => {
        await station.bandAnnotations.remove(args.keys === undefined ? undefined : (args.keys as string[]))
        return { removed: true }
      },
    ),
    tool(
      "update_setting",
      "Change a setting",
      "change",
      "Changes a setting, by the `key` search_settings answers with. The operator is told on the status bar.",
      { key: str("The setting's key."), value: { description: "true or false, an option's value, a number, or text." } },
      async (args) => await acted("update_setting", station.updateSetting({ key: String(args.key), value: args.value ?? null })),
      ["key", "value"],
    ),
    tool(
      "switch_layout",
      "Switch the layout",
      "change",
      "Draws another of a view's layouts, by the ids list_layouts gives.",
      { view: str("operation, logs, chase or home."), id: str("The layout's id.") },
      async (args) => await acted("switch_layout", station.layouts.switch({ view: String(args.view), id: String(args.id) } as never)),
      ["view", "id"],
    ),
    tool(
      "focus_panel",
      "Bring a panel to the front",
      "change",
      "Brings a panel's tab to the front in an open view.",
      { panel: str("The panel's id, from list_layouts."), view: str("Default operation.") },
      async (args) => {
        const view = text(args, "view")
        return await acted("focus_panel", station.layouts.focus({ panel: String(args.panel), ...(view ? { view } : {}) } as never))
      },
      ["panel"],
    ),
  ]
}
