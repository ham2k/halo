// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// A board's parameters: the settings an operator changes for one placement without editing the
// board (which radio is `radio1`), answered as that placement's own form, their values kept in its
// config under `params`. See docs/design/control-boards.md §8 and §9.

import type { JSONValue, PanelPlacementForm, PanelSceneSource } from "@ham2k/extension-sdk"
import { BoardError, type Board } from "./board.ts"

export const paramTypes = ["radio", "rotator", "antennaSwitch", "band", "mode", "choice", "text", "number", "toggle"] as const
export type ParamType = (typeof paramTypes)[number]

export interface BoardParam {
  type: ParamType
  label: string
  /** A `choice`'s options. */
  options?: { value: string | number; label?: string }[]
}

/** The config key a placement's parameter values are kept under, as one object. */
export const paramsKey = "params"

/** At most this many: a form, not a list to scroll. */
const maxParams = 32

const name = /^[A-Za-z][A-Za-z0-9_]{0,31}$/
const isObject = (v: unknown): v is Record<string, unknown> => typeof v === "object" && v !== null && !Array.isArray(v)

export function parseParams(raw: unknown): Record<string, BoardParam> {
  if (raw === undefined || raw === null) return {}
  if (!isObject(raw)) throw new BoardError("`params` is a map of names to `{ type, label }`")
  if (Object.keys(raw).length > maxParams) throw new BoardError(`A board has at most ${maxParams} params`)
  const out: Record<string, BoardParam> = {}
  for (const [key, spec] of Object.entries(raw)) {
    if (!name.test(key)) throw new BoardError(`\`${key}\` cannot name a param`)
    const where = `Param \`${key}\``
    if (!isObject(spec)) throw new BoardError(`${where} is \`{ type, label }\``)
    const extra = Object.keys(spec).filter((k) => !["type", "label", "options"].includes(k))
    if (extra.length) throw new BoardError(`${where} takes no \`${extra[0]}\`; it takes type, label and options`)
    if (!paramTypes.includes(spec.type as ParamType)) throw new BoardError(`${where}'s type is one of ${paramTypes.join(", ")}`)
    const type = spec.type as ParamType
    const label = spec.label === undefined ? key : spec.label
    if (typeof label !== "string" || !label.trim() || label.length > 64) throw new BoardError(`${where}'s label is text of up to 64 characters`)
    const param: BoardParam = { type, label }
    if (type === "choice") {
      if (!Array.isArray(spec.options) || spec.options.length < 2 || spec.options.length > 32) throw new BoardError(`${where} is a choice of 2 to 32 options`)
      param.options = spec.options.map((option, i) => {
        const entry: Record<string, unknown> = isObject(option) ? option : { value: option }
        const value = entry.value
        if (!((typeof value === "string" && value) || (typeof value === "number" && Number.isFinite(value)))) {
          throw new BoardError(`option ${i + 1} of ${where} needs a \`value\``)
        }
        if (entry.label !== undefined && typeof entry.label !== "string") throw new BoardError(`option ${i + 1} of ${where}'s label is text`)
        return { value: value as string | number, ...(entry.label !== undefined ? { label: entry.label as string } : {}) }
      })
    } else if (spec.options !== undefined) {
      throw new BoardError(`${where} takes \`options\` only as a choice`)
    }
    out[key] = param
  }
  return out
}

/** What leaving an equipment param unset means, said as its picker's first option. */
const unsetLabels: Partial<Record<ParamType, string>> = {
  radio: "Designated radio",
  rotator: "None",
  antennaSwitch: "None",
}

const systemLists: Partial<Record<ParamType, string>> = {
  radio: "$core.radios",
  rotator: "$core.rotators",
  antennaSwitch: "$core.antennaSwitches",
  band: "$core.bands",
  mode: "$core.modes",
}

/** The placement's form for [params], or nothing for a board with none. */
export function paramsForm(params: Record<string, BoardParam>): PanelPlacementForm | undefined {
  const entries = Object.entries(params)
  if (!entries.length) return undefined
  return {
    key: paramsKey,
    title: "Board Settings…",
    elements: entries.map(([key, param]) => {
      const list = systemLists[param.type]
      if (list) {
        const none = unsetLabels[param.type]
        return { type: "field", fieldType: "select", key, label: param.label, options: list, ...(none ? { none } : {}) }
      }
      if (param.type === "choice") {
        return {
          type: "field",
          fieldType: "select",
          key,
          label: param.label,
          options: param.options!.map((o) => ({ label: o.label ?? String(o.value), value: o.value })),
        }
      }
      const fieldType = param.type === "toggle" ? "checkbox" : param.type === "number" ? "number" : "text"
      return { type: "field", fieldType, key, label: param.label }
    }),
  }
}

/** The placement's values for [params], from its stored `config.params`: only those the board declares. */
export function paramValues(params: Record<string, BoardParam>, stored: unknown): Record<string, JSONValue> {
  const values: Record<string, JSONValue> = {}
  if (!isObject(stored)) return values
  for (const key of Object.keys(params)) {
    if (stored[key] !== undefined && stored[key] !== null) values[key] = stored[key] as JSONValue
  }
  return values
}

/**
 * An id no equipment has. A rotator or switch whose param is unset is this: the scene takes no
 * empty id, and its readings are missing, as an unknown id's are.
 */
export const unsetEquipment = "unset"

/** The board's sources with their Liquid ids rendered: `{ radio: "{{ params.radio1 }}" }`, the radio chosen. */
export function resolveSources(board: Board, text: (template: string) => string): Record<string, PanelSceneSource> {
  const out: Record<string, PanelSceneSource> = {}
  for (const [key, source] of Object.entries(board.sources)) {
    const [kind, id] = Object.entries(source)[0] as [keyof PanelSceneSource & string, string | null]
    if (id === null) {
      out[key] = { radio: null }
      continue
    }
    let rendered: string
    try {
      rendered = text(id).trim()
    } catch (e) {
      throw new BoardError(`The Liquid in source \`${key}\` cannot be rendered: ${(e as Error).message}`)
    }
    // An unset radio is the designated one, as `{ radio: null }` is.
    out[key] = (kind === "radio" ? { radio: rendered || null } : { [kind]: rendered || unsetEquipment }) as PanelSceneSource
  }
  return out
}
