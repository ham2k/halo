// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// A control board's definition: what the operator writes (YAML) and what the compiler reads,
// checked here in full so a board the app would refuse is refused first, in words that say where.
// See docs/design/control-boards.md §8.

import type { PanelColorRole, PanelSceneRadioString, PanelSceneRadioValue, PanelSceneRotatorValue, PanelSceneSource } from "@ham2k/extension-sdk"
import { CORE_SCHEMA, load } from "js-yaml"

/** A value a widget shows: a source's reading (`rig.signalDbm`) or one of the board's vars (`var.drive`). */
export type ValueRef = string

export interface BoardCondition {
  value: ValueRef
  is?: number | string
  in?: (number | string)[]
  min?: number
  max?: number
  not?: boolean
}

/** What a press, a pick or a turn does. `$value` is the control's value; text is Liquid. */
export type BoardAction =
  | {
      setRadio: {
        source?: string
        mode?: string
        frequencyHz?: number | string
        powerWatts?: number | string
        tunerInline?: boolean
        startTune?: true
        keyerSpeedWpm?: number | string
      }
    }
  | { turnRotator: { source: string; azimuth: number | string; elevation?: number | string } }
  | { stopRotator: { source: string } }
  | { selectAntenna: { source: string; port: string; antenna: string } }
  | { setVar: { name: string; value: number | string } }
  | { toggleVar: { name: string } }

export interface BoardItem {
  type: string
  span?: [number, number]
  when?: BoardCondition
  [prop: string]: unknown
}

export interface BoardGrid {
  unit?: [number, number]
  gap?: number | [number, number]
  padding?: number
  columns?: number
  title?: string
  background?: string
  border?: string
  radius?: number
  items: BoardItem[]
}

export type BoardSource = PanelSceneSource

export interface Board extends BoardGrid {
  name?: string
  sources: Record<string, BoardSource>
  vars: Record<string, number | string>
}

/** What a board refuses to be, said in words for the operator, with where in it it went wrong. */
export class BoardError extends Error {}

/** Past this, a board's text is refused before it is parsed. */
export const maxBoardChars = 262144
/** Past this many items, counted each time an alias repeats one, a board is refused. */
export const maxBoardItems = 1024
/** Past this many values of any kind, counted the same way, the parsed text is refused. */
export const maxBoardNodes = 20000

/** An item's place as the operator counts it: `item 3`, `item 7.2`, from a 0-based path. */
export function placeName(path: string): string {
  return `item ${path
    .split(".")
    .map((i) => Number(i) + 1)
    .join(".")}`
}

type Unprefixed<T extends string> = T extends `radio.${infer R}` ? R : never

/** Every one of the SDK's names [T], checked when typed: one it adds that a list here misses fails the typecheck. */
const all =
  <T extends string>() =>
  <const L extends readonly T[]>(list: L & ([Exclude<T, L[number]>] extends [never] ? unknown : { missing: Exclude<T, L[number]> })): readonly string[] =>
    list

/** The color roles a theme names, as the render environment does. */
export const colorRoles = all<PanelColorRole>()([
  "surface",
  "surfaceContainer",
  "onSurface",
  "onSurfaceVariant",
  "accent",
  "primary",
  "onPrimary",
  "secondary",
  "outline",
  "outlineVariant",
  "error",
  "onError",
])

// What each kind of source gives, as numbers and as words: the scene's own lists (scenes.md).
const radioNumbers = all<Unprefixed<PanelSceneRadioValue>>()([
  "signalDbm",
  "powerOut",
  "swr",
  "alc",
  "supplyVolts",
  "compression",
  "transmitting",
  "swrAverage",
  "secondsSinceTransmit",
  "frequencyHz",
  "reportedFrequencyHz",
  "passbandLowHz",
  "passbandHighHz",
  "passbandWidthHz",
  "powerWatts",
  "ptt",
  "connected",
])
const radioWords = all<Unprefixed<PanelSceneRadioString>>()(["mode", "tuner", "status"])
const rotatorNumbers = all<PanelSceneRotatorValue>()(["azimuth", "elevation", "targetAzimuth", "moving", "connected"])

type Kind = "number" | "word"

/** Reads a board's YAML: the core schema only (no merge keys, no `!!omap`), its size and its values capped. */
export function parseBoard(text: string): Board {
  if (text.length > maxBoardChars) throw new BoardError(`The board is ${text.length} characters long, at most ${maxBoardChars}`)
  if (!text.trim()) return { sources: {}, vars: {}, items: [] }
  let raw: unknown
  try {
    raw = load(text, { schema: CORE_SCHEMA })
  } catch (e) {
    throw new BoardError(`The board is not valid YAML: ${(e as Error).message.split("\n")[0]}`)
  }
  // An alias is read once and referenced where it repeats: walked as written, a few lines of
  // nested aliases are millions of values, whatever key they sit under.
  // An alias may even name a map it is inside of. Walked without a stack of calls, every visit
  // counted, either is a refusal rather than a hang or an overflow.
  let nodes = 0
  const pending: unknown[] = [raw]
  while (pending.length) {
    if (++nodes > maxBoardNodes) throw new BoardError(`The board holds more than ${maxBoardNodes} values, counting what its aliases repeat`)
    const value = pending.pop()
    // One at a time: spread, a list of a hundred thousand would be that many arguments.
    if (Array.isArray(value)) for (const v of value) pending.push(v)
    else if (isObject(value)) for (const v of Object.values(value)) pending.push(v)
  }
  if (!isObject(raw)) throw new BoardError("A board is a map of settings with its `items`")
  const version = raw["ham2k-board"]
  // `"1"` too: a quoted version is the same version.
  if (version !== undefined && version !== 1 && version !== "1")
    throw new BoardError(`This board is written for a newer version (ham2k-board: ${String(version)})`)
  allowed(raw, ["ham2k-board", "name", "sources", "vars", ...gridKeys], "the board")
  const board: Board = { sources: parseSources(raw.sources), vars: parseVars(raw.vars), items: [] }
  if (raw.name !== undefined) board.name = text_(raw.name, "`name` of the board")
  const reader = new Reader(board)
  Object.assign(board, reader.grid(raw, "", "the board"))
  return board
}

const gridKeys = ["unit", "gap", "padding", "columns", "title", "background", "border", "radius", "items"]

function parseSources(raw: unknown): Record<string, BoardSource> {
  if (raw === undefined || raw === null) return {}
  if (!isObject(raw)) throw new BoardError("`sources` is a map of names to a radio, rotator or antennaSwitch")
  if (Object.keys(raw).length > 16) throw new BoardError("A board has at most 16 sources")
  const out: Record<string, BoardSource> = {}
  for (const [name, source] of Object.entries(raw)) {
    if (!/^[A-Za-z][A-Za-z0-9_]{0,31}$/.test(name) || name === "radio" || name === "var") throw new BoardError(`\`${name}\` cannot name a source`)
    if (!isObject(source)) throw new BoardError(`Source \`${name}\` is one of radio, rotator or antennaSwitch`)
    const kinds = ["radio", "rotator", "antennaSwitch"].filter((k) => own(source, k))
    if (kinds.length !== 1 || Object.keys(source).length !== 1) throw new BoardError(`Source \`${name}\` is one of radio, rotator or antennaSwitch`)
    const id = source[kinds[0]]
    // `null` (or nothing) is the designated radio; an empty id is a mistake, never a default.
    if (kinds[0] === "radio" && id === null) out[name] = { radio: null }
    else if (typeof id === "string" && id.trim()) out[name] = { [kinds[0]]: id } as BoardSource
    else throw new BoardError(`Source \`${name}\` names no ${kinds[0]}`)
  }
  return out
}

function parseVars(raw: unknown): Record<string, number | string> {
  if (raw === undefined || raw === null) return {}
  if (!isObject(raw)) throw new BoardError("`vars` is a map of names to their starting values")
  const out: Record<string, number | string> = {}
  for (const [name, value] of Object.entries(raw)) {
    if (!/^[A-Za-z][A-Za-z0-9_]{0,31}$/.test(name)) throw new BoardError(`\`${name}\` cannot name a var`)
    if (typeof value === "boolean") out[name] = value ? 1 : 0
    else if (typeof value === "number" && Number.isFinite(value)) out[name] = value
    else if (typeof value === "string") out[name] = value
    else throw new BoardError(`Var \`${name}\` starts as a number, a word or true/false`)
  }
  return out
}

/** Which triggers carry a value for `$value`, and which an operator presses (a tune is only those). */
const valuedTriggers = new Set(["onChange", "segmented.onSelect"])
const pressTriggers = new Set(["onPress", "menu.onSelect", "segmented.onSelect"])

class Reader {
  private items = 0
  private board: Board
  constructor(board: Board) {
    this.board = board
  }

  grid(raw: Record<string, unknown>, path: string, where: string): BoardGrid {
    const grid: BoardGrid = { items: [] }
    if (raw.unit !== undefined) grid.unit = pair(raw.unit, `\`unit\` of ${where}`, 8, 512)
    if (raw.gap !== undefined)
      grid.gap = typeof raw.gap === "number" ? number_(raw.gap, `\`gap\` of ${where}`, 0, 64) : pair(raw.gap, `\`gap\` of ${where}`, 0, 64)
    if (raw.padding !== undefined) grid.padding = number_(raw.padding, `\`padding\` of ${where}`, 0, 256)
    if (raw.columns !== undefined) grid.columns = whole(raw.columns, `\`columns\` of ${where}`, 1, 64)
    if (raw.radius !== undefined) grid.radius = number_(raw.radius, `\`radius\` of ${where}`, 0, 64)
    if (raw.title !== undefined) grid.title = text_(raw.title, `\`title\` of ${where}`)
    if (raw.background !== undefined) grid.background = color(raw.background, `\`background\` of ${where}`)
    if (raw.border !== undefined) grid.border = color(raw.border, `\`border\` of ${where}`)
    const items = raw.items ?? []
    if (!Array.isArray(items)) throw new BoardError(`\`items\` of ${where} is a list`)
    items.forEach((item, i) => {
      if (++this.items > maxBoardItems) throw new BoardError(`The board has more than ${maxBoardItems} items`)
      grid.items.push(this.item(item, `${path}${i}`))
    })
    return grid
  }

  item(raw: unknown, path: string): BoardItem {
    const where = placeName(path)
    if (!isObject(raw)) throw new BoardError(`${where} is a map with a \`type\``)
    const shape = typeof raw.type === "string" && own(widgets, raw.type) ? widgets[raw.type] : undefined
    if (!shape) throw new BoardError(`${where} has an unknown type \`${String(raw.type)}\`; a board knows ${Object.keys(widgets).join(", ")}`)
    const type = raw.type as string
    const props = shape.props
    allowed(raw, ["type", ...(type === "group" ? [] : ["span", "when"]), ...Object.keys(props)], `${where} (a ${type})`)
    const item: BoardItem = { type }
    if (type === "group") {
      Object.assign(item, this.grid(raw, `${path}.`, where))
      return item
    }
    if (raw.span !== undefined) {
      const span = pair(raw.span, `\`span\` of ${where}`, 1, 64)
      if (!span.every(Number.isInteger)) throw new BoardError(`\`span\` of ${where} is two whole numbers`)
      item.span = span
    }
    if (raw.when !== undefined) {
      // A widget that lights by a condition of its own cannot take another: a scene tests one.
      if (shape.lights(raw)) throw new BoardError(`${where} lights by a condition of its own, so it cannot also take a \`when\``)
      item.when = this.condition(raw.when, `\`when\` of ${where}`)
    }
    for (const [key, kind] of Object.entries(props)) {
      if (raw[key] === undefined) continue
      item[key] = this.prop(kind, raw[key], `\`${key}\` of ${where}`, key, type)
    }
    for (const key of shape.needs ?? []) if (item[key] === undefined) throw new BoardError(`${where} needs a \`${key}\``)
    shape.check?.(item, where, this)
    return item
  }

  prop(kind: string, raw: unknown, where: string, key: string, type: string): unknown {
    switch (kind) {
      case "text":
        return text_(raw, where)
      case "number":
        return number_(raw, where)
      case "decimals":
        return whole(raw, where, 0, 6)
      case "positive":
        return number_(raw, where, 1e-9)
      case "segments":
        return whole(raw, where, 2, 64)
      case "hold":
        return number_(raw, where, 0, 60000)
      case "bool":
        if (typeof raw !== "boolean") throw new BoardError(`${where} is true or false`)
        return raw
      case "color":
        return color(raw, where)
      case "style":
        return oneOf(raw, where, ["body", "label", "title", "display", "mono"])
      case "align":
        return oneOf(raw, where, ["start", "center", "end"])
      case "number-ref":
        return this.ref(raw, where, "number")
      case "ref":
        return this.ref(raw, where)
      case "number-var":
        return this.varName(raw, where, "number")
      case "condition":
        return this.condition(raw, where)
      case "actions":
        return this.actions(raw, where, type === "segmented" ? `segmented.${key}` : key)
      case "zones":
        return zones(raw, where)
      case "options":
        return this.options(raw, where)
      case "menu":
        return this.menu(raw, where)
    }
    throw new BoardError(`${where} has a kind the board does not know`)
  }

  /** A ref to a reading a source gives, or a declared var, and which kind of value it holds. */
  ref(raw: unknown, where: string, want?: Kind): string {
    if (typeof raw !== "string") throw new BoardError(`${where} names a reading (\`rig.signalDbm\`) or a var (\`var.drive\`)`)
    const kind = this.kindOf(raw, where)
    if (want && kind !== want) throw new BoardError(`${where} needs a number, and \`${raw}\` is a word`)
    return raw
  }

  kindOf(ref: string, where: string): Kind {
    const dot = ref.indexOf(".")
    const head = dot > 0 ? ref.slice(0, dot) : ""
    const rest = ref.slice(dot + 1)
    if (head === "var") {
      if (!own(this.board.vars, rest)) throw new BoardError(`${where} names a var the board does not have: \`${ref}\``)
      return typeof this.board.vars[rest] === "number" ? "number" : "word"
    }
    const source = own(this.board.sources, head) ? this.board.sources[head] : undefined
    if (!source) throw new BoardError(`${where} names \`${ref}\`, which is neither a source's reading nor a var`)
    if ("radio" in source) {
      if (radioNumbers.includes(rest)) return "number"
      if (radioWords.includes(rest)) return "word"
      throw new BoardError(`${where}: a radio gives no \`${rest}\`; it gives ${[...radioNumbers, ...radioWords].join(", ")}`)
    }
    if ("rotator" in source) {
      if (rotatorNumbers.includes(rest)) return "number"
      throw new BoardError(`${where}: a rotator gives no \`${rest}\`; it gives ${rotatorNumbers.join(", ")}`)
    }
    // A switch's ports go by its own keys: any port, as `<port>.auto`, `.antenna` or `.antennaName`.
    if (rest === "connected" || /^.+\.auto$/.test(rest)) return "number"
    if (/^.+\.(antenna|antennaName)$/.test(rest)) return "word"
    throw new BoardError(`${where}: an antenna switch gives \`connected\` and each port's \`<port>.auto\`, \`.antenna\` and \`.antennaName\``)
  }

  varName(raw: unknown, where: string, want: Kind): string {
    if (typeof raw !== "string") throw new BoardError(`${where} names one of the board's vars`)
    this.ref(`var.${raw}`, where, want)
    return raw
  }

  /** A scene condition: exactly one test, suiting the kind of value it reads. */
  condition(raw: unknown, where: string): BoardCondition {
    if (!isObject(raw)) throw new BoardError(`${where} is a condition: \`{ value, is }\`, \`{ value, in }\` or \`{ value, min, max }\``)
    allowed(raw, ["value", "is", "in", "min", "max", "not"], where)
    const kind = this.kindOf(this.ref(raw.value, where), where)
    const tests = [raw.is !== undefined, raw.in !== undefined, raw.min !== undefined || raw.max !== undefined].filter(Boolean).length
    if (tests !== 1) throw new BoardError(`${where} has exactly one test: \`is\`, \`in\`, or \`min\`/\`max\``)
    // A number is 1 or 0 where it is on or off (`transmitting`, a toggle's var): `is: true` means 1.
    const asKind = (v: unknown) => (kind === "number" && typeof v === "boolean" ? Number(v) : v)
    const fits = (v: unknown) => (kind === "number" ? typeof v === "number" && Number.isFinite(v) : typeof v === "string")
    const condition: BoardCondition = { value: raw.value as string }
    if (raw.is !== undefined) {
      const is = asKind(raw.is)
      if (!fits(is)) throw new BoardError(`${where} tests a ${kind} with \`is: ${String(raw.is)}\``)
      condition.is = is as number | string
    }
    if (raw.in !== undefined) {
      const list = Array.isArray(raw.in) ? raw.in.map(asKind) : []
      if (!list.length || !list.every(fits)) throw new BoardError(`${where}'s \`in\` is a list of ${kind}s`)
      condition.in = list as (number | string)[]
    }
    if (raw.min !== undefined || raw.max !== undefined) {
      if (kind !== "number") throw new BoardError(`${where} cannot test a word by a range`)
      if (raw.min !== undefined) condition.min = number_(raw.min, `\`min\` of ${where}`)
      if (raw.max !== undefined) condition.max = number_(raw.max, `\`max\` of ${where}`)
      if (condition.min !== undefined && condition.max !== undefined && condition.min > condition.max)
        throw new BoardError(`${where}'s \`min\` is above its \`max\``)
    }
    if (raw.not !== undefined) {
      if (typeof raw.not !== "boolean") throw new BoardError(`\`not\` of ${where} is true or false`)
      if (raw.not) condition.not = true
    }
    return condition
  }

  /** One action or a list, each with only the fields it takes, in the kinds it takes them. */
  actions(raw: unknown, where: string, trigger: string): BoardAction[] {
    const list = Array.isArray(raw) ? raw : [raw]
    if (!list.length) throw new BoardError(`${where} is an action, or a list of them`)
    const valued = valuedTriggers.has(trigger)
    const amount = (v: unknown, field: string) => {
      if (typeof v === "number" && Number.isFinite(v)) return v
      if (typeof v === "string" && v.trim()) {
        if (v.includes("$value") && !valued) throw new BoardError(`${field} reads \`$value\`, and ${where} has no value to give it`)
        return v
      }
      throw new BoardError(`${field} is a number, \`$value\` or Liquid text`)
    }
    const word = (v: unknown, field: string) => {
      if (typeof v === "number") return String(v)
      if (typeof v !== "string" || !v.trim()) throw new BoardError(`${field} is text`)
      if (v.includes("$value") && !valued) throw new BoardError(`${field} reads \`$value\`, and ${where} has no value to give it`)
      return v
    }
    const sourceOf = (params: Record<string, unknown>, kind: "radio" | "rotator" | "antennaSwitch", field: string, optional = false) => {
      if (params.source === undefined && optional) return undefined
      const name = params.source
      const declared = typeof name === "string" && own(this.board.sources, name) ? this.board.sources[name] : undefined
      if (!declared || !(kind in declared)) throw new BoardError(`${field} needs a ${kind} source, and \`${String(name)}\` is not one`)
      return name as string
    }
    return list.map((action, i) => {
      const at = list.length > 1 ? `action ${i + 1} of ${where}` : where
      if (!isObject(action) || Object.keys(action).length !== 1)
        throw new BoardError(`${at} is one action: setRadio, turnRotator, stopRotator, selectAntenna, setVar or toggleVar`)
      const [kind, params] = Object.entries(action)[0]
      if (!isObject(params)) throw new BoardError(`${kind} in ${at} needs its settings`)
      const field = (f: string) => `\`${f}\` of ${kind} in ${at}`
      switch (kind) {
        case "setRadio": {
          allowed(params, ["source", "mode", "frequencyHz", "powerWatts", "tunerInline", "startTune", "keyerSpeedWpm"], `${kind} in ${at}`)
          const out: Record<string, unknown> = {}
          const source = sourceOf(params, "radio", field("source"), true)
          if (source) out.source = source
          if (params.mode !== undefined) out.mode = word(params.mode, field("mode"))
          for (const f of ["frequencyHz", "powerWatts", "keyerSpeedWpm"]) if (params[f] !== undefined) out[f] = amount(params[f], field(f))
          // A carrier on the air: only for an operator's press, never a knob a wheel passes over.
          for (const f of ["tunerInline", "startTune"]) {
            if (params[f] === undefined) continue
            if (typeof params[f] !== "boolean") throw new BoardError(`${field(f)} is true or false`)
            if (params[f] && !pressTriggers.has(trigger)) throw new BoardError(`${field(f)} keys the radio, so it goes on a press, not on ${where}`)
            out[f] = params[f]
          }
          if (out.startTune === false) delete out.startTune
          // A tune goes alone: with anything else in the same call the host refuses it every time.
          if (out.startTune && Object.keys(out).some((k) => k !== "startTune" && k !== "source"))
            throw new BoardError(`\`startTune\` in ${at} goes alone, with nothing else set beside it`)
          // A frequency a knob or slider turns is a dial turning: the app settles it as the radio's own.
          if (out.frequencyHz !== undefined && valued) out.dial = true
          if (Object.keys(out).length === (source ? 1 : 0)) throw new BoardError(`setRadio in ${at} sets nothing`)
          return { setRadio: out } as BoardAction
        }
        case "turnRotator": {
          allowed(params, ["source", "azimuth", "elevation"], `${kind} in ${at}`)
          if (params.azimuth === undefined) throw new BoardError(`${field("azimuth")} is missing`)
          return {
            turnRotator: {
              source: sourceOf(params, "rotator", field("source"))!,
              azimuth: amount(params.azimuth, field("azimuth")),
              ...(params.elevation !== undefined ? { elevation: amount(params.elevation, field("elevation")) } : {}),
            },
          }
        }
        case "stopRotator":
          allowed(params, ["source"], `${kind} in ${at}`)
          return { stopRotator: { source: sourceOf(params, "rotator", field("source"))! } }
        case "selectAntenna":
          allowed(params, ["source", "port", "antenna"], `${kind} in ${at}`)
          return {
            selectAntenna: {
              source: sourceOf(params, "antennaSwitch", field("source"))!,
              port: word(params.port, field("port")),
              antenna: word(params.antenna, field("antenna")),
            },
          }
        case "setVar": {
          allowed(params, ["name", "value"], `${kind} in ${at}`)
          const name = params.name
          if (typeof name !== "string" || !own(this.board.vars, name))
            throw new BoardError(`${field("name")} names a var the board does not have: \`${String(name)}\``)
          const value = typeof this.board.vars[name] === "number" ? amount(params.value, field("value")) : word(params.value, field("value"))
          return { setVar: { name, value } }
        }
        case "toggleVar": {
          allowed(params, ["name"], `${kind} in ${at}`)
          return { toggleVar: { name: this.varName(params.name, field("name"), "number") } }
        }
      }
      throw new BoardError(`${at} has an unknown action \`${kind}\``)
    })
  }

  /** A segmented choice's options, each `{ value, label? }`, or a value alone. */
  options(raw: unknown, where: string): { value: number | string; label?: string }[] {
    if (!Array.isArray(raw) || raw.length < 2 || raw.length > 16) throw new BoardError(`${where} is a list of 2 to 16 options`)
    return raw.map((option, i) => {
      const entry: Record<string, unknown> = isObject(option) ? option : { value: option }
      allowed(entry, ["value", "label"], `option ${i + 1} of ${where}`)
      if (!(typeof entry.value === "number" && Number.isFinite(entry.value)) && !(typeof entry.value === "string" && entry.value)) {
        throw new BoardError(`option ${i + 1} of ${where} needs a \`value\``)
      }
      return {
        value: entry.value as number | string,
        ...(entry.label !== undefined ? { label: text_(entry.label, `\`label\` of option ${i + 1} of ${where}`) } : {}),
      }
    })
  }

  menu(raw: unknown, where: string): { label: string; onSelect: BoardAction[] }[] {
    if (!Array.isArray(raw) || !raw.length || raw.length > 32) throw new BoardError(`${where} is a list of 1 to 32 entries`)
    return raw.map((entry, i) => {
      const at = `entry ${i + 1} of ${where}`
      if (!isObject(entry)) throw new BoardError(`${at} is \`{ label, onSelect }\``)
      allowed(entry, ["label", "onSelect"], at)
      if (entry.onSelect === undefined) throw new BoardError(`${at} needs an \`onSelect\``)
      return { label: text_(entry.label, `\`label\` of ${at}`), onSelect: this.actions(entry.onSelect, at, "menu.onSelect") }
    })
  }
}

interface Shape {
  props: Record<string, string>
  /** Whether the widget lights by a condition of its own, which a `when` would overwrite. */
  lights(raw: Record<string, unknown>): boolean
  /** What it cannot be drawn without; checked before [check], which may read them. */
  needs?: string[]
  check?(item: BoardItem, where: string, reader: Reader): void
}

const meter = { value: "number-ref", min: "number", max: "number", label: "text", hold: "hold" }
const dial = { var: "number-var", min: "number", max: "number", step: "positive", label: "text", onChange: "actions" }
const never = () => false
const range = (item: BoardItem, where: string) => {
  const min = (item.min as number | undefined) ?? 0
  const max = (item.max as number | undefined) ?? 100
  if (!(max > min)) throw new BoardError(`${where}'s \`max\` (${max}) is not above its \`min\` (${min})`)
}

const widgets: Record<string, Shape> = {
  label: { props: { text: "text", style: "style", align: "align", color: "color" }, lights: never },
  readout: {
    props: { value: "ref", label: "text", decimals: "decimals", scale: "number", prefix: "text", suffix: "text" },
    needs: ["value"],
    lights: never,
  },
  frequency: { props: { value: "number-ref", label: "text" }, needs: ["value"], lights: never },
  button: {
    props: { label: "text", onPress: "actions", active: "condition" },
    lights: (raw) => raw.active !== undefined,
    check(item, where) {
      if (!item.onPress) throw new BoardError(`${where} needs an \`onPress\``)
    },
  },
  toggle: {
    props: { label: "text", var: "number-var", on: "condition", onPress: "actions" },
    lights: () => true,
    check(item, where) {
      // A lamp by its own var, flipped by the press; or by a reading, set by its own action.
      if (item.var !== undefined && (item.on !== undefined || item.onPress !== undefined))
        throw new BoardError(`${where} has a \`var\` it flips, or an \`on\` condition with an \`onPress\`, not both`)
      if (item.var === undefined && (item.on === undefined || item.onPress === undefined))
        throw new BoardError(`${where} needs a \`var\`, or an \`on\` condition and an \`onPress\``)
    },
  },
  bar: {
    props: { ...meter, color: "color", adjustable: "bool", step: "positive", invertScroll: "bool" },
    needs: ["value"],
    lights: never,
    check(item, where) {
      range(item, where)
      if (item.adjustable && !(item.value as string).startsWith("var.")) throw new BoardError(`${where} is adjustable, so it shows one of the board's vars`)
      if (!item.adjustable && (item.step !== undefined || item.invertScroll !== undefined))
        throw new BoardError(`${where} takes a \`step\` or \`invertScroll\` only when it is adjustable`)
    },
  },
  ledBar: { props: { ...meter, segments: "segments", zones: "zones" }, needs: ["value"], lights: never, check: range },
  needle: { props: { ...meter, minLabel: "text", maxLabel: "text" }, needs: ["value"], lights: never, check: range },
  knob: { props: dial, needs: ["var"], lights: never, check: range },
  slider: { props: dial, needs: ["var"], lights: never, check: range },
  menuButton: {
    props: { label: "text", items: "menu" },
    lights: never,
    check(item, where) {
      if (!item.items) throw new BoardError(`${where} needs its \`items\``)
    },
  },
  segmented: {
    props: { value: "ref", options: "options", onSelect: "actions" },
    lights: () => true,
    check(item, where, reader) {
      if (!item.options || item.value === undefined) throw new BoardError(`${where} needs a \`value\` and its \`options\``)
      const kind = reader.kindOf(item.value as string, where)
      for (const option of item.options as { value: number | string }[]) {
        if ((typeof option.value === "number") !== (kind === "number"))
          throw new BoardError(`${where}'s options are ${kind}s, as \`${String(item.value)}\` is; \`${String(option.value)}\` is not`)
      }
      if (!(item.value as string).startsWith("var.") && !item.onSelect)
        throw new BoardError(`${where} shows a reading, so it needs an \`onSelect\` to change it`)
      // A word option's `$value` where a number goes would be refused at every pick: said here.
      if (kind === "word") {
        for (const action of (item.onSelect as BoardAction[] | undefined) ?? []) {
          const numbers: [string, unknown][] =
            "setRadio" in action
              ? Object.entries(action.setRadio).filter(([k]) => k !== "mode" && k !== "source")
              : "turnRotator" in action
                ? Object.entries(action.turnRotator).filter(([k]) => k !== "source")
                : "setVar" in action && reader.kindOf(`var.${action.setVar.name}`, where) === "number"
                  ? [[action.setVar.name, action.setVar.value]]
                  : []
          const field = numbers.find(([, v]) => v === "$value")
          if (field) throw new BoardError(`${where}'s options are words, and its \`onSelect\` sets the number \`${field[0]}\` to one`)
        }
      }
    },
  },
  group: { props: Object.fromEntries(gridKeys.map((k) => [k, "grid"])), lights: never },
}

/** Zones color an LED bar from a level up: `[[level, color], …]`, in rising order. */
function zones(raw: unknown, where: string): [number, string][] {
  if (!Array.isArray(raw)) throw new BoardError(`${where} is a list of \`[level, color]\``)
  const out = raw.map((zone, i) => {
    if (!Array.isArray(zone) || zone.length !== 2) throw new BoardError(`zone ${i + 1} of ${where} is \`[level, color]\``)
    return [number_(zone[0], `the level of zone ${i + 1} of ${where}`), color(zone[1], `the color of zone ${i + 1} of ${where}`)] as [number, string]
  })
  if (out.some((zone, i) => i > 0 && zone[0] <= out[i - 1][0])) throw new BoardError(`${where} rise in order, each from a higher level`)
  return out
}

function allowed(raw: Record<string, unknown>, keys: string[], where: string) {
  const strays = Object.keys(raw).filter((k) => !keys.includes(k))
  if (strays.length) throw new BoardError(`${where} has no ${strays.map((k) => `\`${k}\``).join(", ")}; it takes ${keys.map((k) => `\`${k}\``).join(", ")}`)
}

function color(raw: unknown, where: string): string {
  // Six digits only: text takes no others, and eight read #AARRGGBB in a grid but #RRGGBBAA in artwork.
  if (typeof raw === "string" && (colorRoles.includes(raw) || /^#[0-9a-fA-F]{6}$/.test(raw))) return raw
  throw new BoardError(`${where} is a theme color (${colorRoles.join(", ")}) or \`#RRGGBB\``)
}

function oneOf(raw: unknown, where: string, values: string[]): string {
  if (typeof raw !== "string" || !values.includes(raw)) throw new BoardError(`${where} is one of ${values.join(", ")}`)
  return raw
}

function text_(raw: unknown, where: string): string {
  if (typeof raw === "number") return String(raw)
  if (typeof raw !== "string") throw new BoardError(`${where} is text`)
  return raw
}

function number_(raw: unknown, where: string, min = -1e12, max = 1e12): number {
  if (typeof raw !== "number" || !Number.isFinite(raw) || raw < min || raw > max)
    throw new BoardError(`${where} is a number${min > -1e12 || max < 1e12 ? ` from ${min} to ${max}` : ""}`)
  return raw
}

function whole(raw: unknown, where: string, min: number, max: number): number {
  const n = number_(raw, where, min, max)
  if (!Number.isInteger(n)) throw new BoardError(`${where} is a whole number`)
  return n
}

function pair(raw: unknown, where: string, min: number, max: number): [number, number] {
  if (!Array.isArray(raw) || raw.length !== 2) throw new BoardError(`${where} is two numbers`)
  return [number_(raw[0], where, min, max), number_(raw[1], where, min, max)]
}

/** Whether [key] is [object]'s own, not one inherited: `constructor` names no var. */
function own(object: object, key: string): boolean {
  return Object.prototype.hasOwnProperty.call(object, key)
}

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value)
}
