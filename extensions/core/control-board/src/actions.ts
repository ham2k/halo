// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// What a board's controls do: a declarative action, run through the host's own calls under their
// own rules, so a board commands a radio, a rotator or a switch exactly as any panel would.

import type { PanelRadioSet } from "@ham2k/extension-sdk"
import { BoardError, placeName, type Board, type BoardAction, type BoardGrid, type BoardItem } from "./board.ts"

/** The host calls a board makes: the SDK's `host`, or a test's stand-in. */
export type BoardHost = Pick<typeof import("@ham2k/extension-sdk").host, "readRadio" | "setRadio" | "setRotator" | "stopRotator" | "setAntenna" | "showMessage">

export interface ActionContext {
  board: Board
  /** The vars the actions read and change: a copy, kept only once every action is taken. */
  vars: Record<string, number | string>
  /** The control's own value, for `$value`: a knob's, a slider's, the option picked. */
  value?: number | string
  /** Liquid, for an action's words. */
  text(template: string): string
}

/** The widget at [path] (`0.3.1`: the first item, its fourth, its second). */
export function itemAt(board: BoardGrid, path: string): BoardItem {
  let grid: BoardGrid = board
  let item: BoardItem | undefined
  for (const step of path.split(".")) {
    // Only a group holds items: a path into a menu's entries, or through any other widget, names
    // nothing, and neither does a step that is not a whole number.
    const at = /^\d+$/.test(step) && (!item || item.type === "group") ? grid.items[Number(step)] : undefined
    if (!at) throw new BoardError(`The board has no ${placeName(path)}`)
    item = at
    grid = item as unknown as BoardGrid
  }
  return item!
}

/** The vars a control sets by being used, beside its actions: put back as they were if those fail. */
export function varsOf(item: BoardItem): string[] {
  if (typeof item.var === "string") return [item.var]
  if (typeof item.value === "string" && item.value.startsWith("var.")) return [item.value.slice(4)]
  return []
}

/**
 * What a control's event stands for: `a` a press, `c` a knob's or slider's new value, `m` a menu
 * entry picked, `s` a segmented option picked, each `<kind>:<stamp>:<path>[:<index>]`. An event
 * from a board since edited is refused: its path may name another item now. The var the control
 * sets comes back as `sets`, kept only once its actions are taken.
 */
export function actionsFor(board: Board, stamp: string, action: string, value: number | string | undefined) {
  const [kind, sent, path, index] = action.split(":")
  if (sent !== stamp) throw new BoardError("The board changed since that was drawn; use it again")
  const item = itemAt(board, path)
  const list = (key: string) => (item[key] as BoardAction[] | undefined) ?? []
  const sets: Record<string, number | string> = {}
  switch (kind) {
    case "a":
      if (item.type === "toggle" && typeof item.var === "string") return { item, actions: [{ toggleVar: { name: item.var } }] as BoardAction[], sets }
      return { item, actions: list("onPress"), sets }
    case "c":
      if (typeof value !== "number") throw new BoardError(`${placeName(path)} sent no value`)
      for (const name of varsOf(item)) sets[name] = value
      return { item, actions: list("onChange"), value, sets }
    case "m": {
      const entry = (item.items as { onSelect: BoardAction[] }[] | undefined)?.[Number(index)]
      if (!entry) throw new BoardError(`The menu at ${placeName(path)} has no entry ${Number(index) + 1}`)
      return { item, actions: entry.onSelect, sets }
    }
    case "s": {
      const option = (item.options as { value: number | string }[] | undefined)?.[Number(index)]
      if (!option) throw new BoardError(`The choice at ${placeName(path)} has no option ${Number(index) + 1}`)
      for (const name of varsOf(item)) sets[name] = option.value
      return { item, actions: list("onSelect"), value: option.value, sets }
    }
  }
  throw new BoardError(`Unknown board event ${action}`)
}

/** Runs [actions] in order; the first the host refuses stops the rest and says why. */
export async function runActions(host: BoardHost, actions: BoardAction[], ctx: ActionContext): Promise<void> {
  for (const action of actions) await runAction(host, action, ctx)
}

const decimal = /^-?\d+(\.\d+)?$/

async function runAction(host: BoardHost, action: BoardAction, ctx: ActionContext) {
  const word = (v: unknown, what: string) => {
    const text = resolve(v, ctx).trim()
    if (!text) throw new BoardError(`${what} came out empty`)
    return text
  }
  // Only a number as written: an empty field or a stray word is refused, never taken as 0, which
  // would turn a rotator north or a radio's power off.
  const number = (v: unknown, what: string) => {
    if (typeof v === "number") return v
    // The control's own number as it came, not as text: a knob stepped through zero sends 2e-16.
    if (v === "$value" && typeof ctx.value === "number") return ctx.value
    const text = word(v, what)
    if (!decimal.test(text)) throw new BoardError(`${what} is not a number: ${text}`)
    return Number(text)
  }
  const equipment = (source: string, kind: "rotator" | "antennaSwitch") => (ctx.board.sources[source] as Record<string, string>)[kind]
  if ("setRadio" in action) {
    const { source, ...change } = action.setRadio
    const selection = source === undefined ? null : ((ctx.board.sources[source] as { radio: string | null }).radio ?? null)
    const radio = await host.readRadio(selection ?? undefined)
    if (!radio?.id) throw new BoardError(source ? `\`${source}\` names a radio that is not set up` : "There is no radio to command")
    const patch: Record<string, unknown> = {}
    for (const [key, raw] of Object.entries(change)) {
      // The radio's modes are upper case: `usb` would be refused as no mode it has.
      patch[key] = key === "mode" ? word(raw, "mode").toUpperCase() : typeof raw === "boolean" ? raw : number(raw, key)
    }
    // The id just read, as the band scope sends it: the set path resolves a node's id, not every
    // name `readRadio` accepts for one.
    said(await host.setRadio({ ...patch, id: radio.id, ...(selection ? { selection: radio.id } : {}) } as PanelRadioSet), "The radio")
  } else if ("turnRotator" in action) {
    const { source, azimuth, elevation } = action.turnRotator
    said(
      await host.setRotator({
        id: equipment(source, "rotator"),
        azimuth: number(azimuth, "azimuth"),
        ...(elevation !== undefined ? { elevation: number(elevation, "elevation") } : {}),
      }),
      "The rotator",
    )
  } else if ("stopRotator" in action) {
    said(await host.stopRotator({ id: equipment(action.stopRotator.source, "rotator") }), "The rotator")
  } else if ("selectAntenna" in action) {
    const { source, port, antenna } = action.selectAntenna
    said(await host.setAntenna({ id: equipment(source, "antennaSwitch"), port: word(port, "port"), antenna: word(antenna, "antenna") }), "The antenna switch")
  } else if ("setVar" in action) {
    const { name, value } = action.setVar
    ctx.vars[name] = typeof ctx.board.vars[name] === "number" ? number(value, name) : word(value, name)
  } else if ("toggleVar" in action) {
    const name = action.toggleVar.name
    ctx.vars[name] = Number(ctx.vars[name] ?? ctx.board.vars[name]) ? 0 : 1
  }
}

/** A field's text: `$value` the control's own, then Liquid. */
function resolve(raw: unknown, ctx: ActionContext): string {
  const text = String(raw)
  if (text.includes("$value")) {
    if (ctx.value === undefined) throw new BoardError("`$value` has no value here")
    return ctx.text(text.split("$value").join(String(ctx.value)))
  }
  return ctx.text(text)
}

function said(result: { accepted: boolean; reason?: string }, what: string) {
  if (!result.accepted) throw new BoardError(`${what} did not take it${result.reason ? `: ${result.reason}` : ""}`)
}
