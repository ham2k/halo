// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// Scene patches on the extension's side of the bridge (docs/design/panel-scenes.md
// § Patches): the same steps the app applies (scene_patch.dart). The kernel
// applies an event answer's patch, or `host.updateScene`'s, to the scene it
// last sent the placement, so the next render is compared with the scene the
// app shows.

import type { PanelScenePatchStep, PanelScenePath } from "./panelScene.ts"
import type { JSONValue } from "./types.ts"

type ScenePath = PanelScenePath
type ScenePatchStep = PanelScenePatchStep

/// The most steps one patch takes, as the app takes them.
export const SCENE_PATCH_MAX_STEPS = 8192

/// The deepest a path reaches, as the app reaches.
export const SCENE_PATCH_MAX_DEPTH = 16

type Json = unknown
type JsonObject = Record<string, Json>

const isObject = (v: Json): v is JsonObject => typeof v === "object" && v !== null && !Array.isArray(v)
/// A key the object has of its own: `in` would find `toString` on any of
/// them, which the app's maps do not have.
const has = (o: JsonObject, key: string) => Object.prototype.hasOwnProperty.call(o, key)
const idOf = (v: Json): string | undefined => (isObject(v) && typeof v.id === "string" ? v.id : undefined)
const shown = (path: ScenePath) => (path.length === 0 ? "the scene" : path.join(" › "))

/// [document] with [steps] applied, as the app applies them; the objects and
/// lists along each step's path are copied, once each, and the rest shared.
/// Throws naming the step at fault.
export function applyScenePatch(document: JsonObject, steps: unknown): JsonObject {
  if (!Array.isArray(steps)) throw new Error("A scene patch is a list of steps")
  if (steps.length > SCENE_PATCH_MAX_STEPS) throw new Error(`A scene patch takes at most ${SCENE_PATCH_MAX_STEPS} steps, not ${steps.length}`)
  const owned = new Set<object>()
  const indexes = new Map<Json[], Map<string, number>>()
  const own = <T extends object>(v: T): T => {
    if (owned.has(v)) return v
    const copy = (Array.isArray(v) ? v.slice() : { ...v }) as T
    owned.add(copy)
    if (Array.isArray(v) && indexes.has(v)) indexes.set(copy as unknown as Json[], indexes.get(v)!)
    return copy
  }
  const indexOf = (list: Json[], id: string) => {
    let index = indexes.get(list)
    if (!index) {
      index = new Map()
      for (let i = 0; i < list.length; i++) {
        const itemId = idOf(list[i])
        if (itemId !== undefined) index.set(itemId, i)
      }
      indexes.set(list, index)
    }
    return index.get(id) ?? -1
  }
  const within = (node: Json, path: ScenePath, from: number, change: (target: Json) => Json): Json => {
    if (from === path.length) return change(node)
    const segment = path[from]
    if (Array.isArray(node)) {
      const at = indexOf(node, segment)
      if (at < 0) throw new Error(`${shown(path.slice(0, from + 1))} is not there`)
      const copy = own(node)
      copy[at] = within(node[at], path, from + 1, change)
      return copy
    }
    if (isObject(node)) {
      if (!has(node, segment)) throw new Error(`${shown(path.slice(0, from + 1))} is not there`)
      const copy = own(node)
      copy[segment] = within(node[segment], path, from + 1, change)
      return copy
    }
    throw new Error(`${shown(path.slice(0, from))} holds neither keys nor items`)
  }
  const merged = (target: Json, value: Json, path: ScenePath): JsonObject => {
    if (!isObject(target)) throw new Error(`${shown(path)} is not an object to merge into`)
    if (!isObject(value)) throw new Error("a merge's value is an object")
    const copy: JsonObject = { ...target }
    for (const [key, field] of Object.entries(value)) {
      if (key === "__proto__") throw new Error("a merge names no __proto__")
      if (field === null) delete copy[key]
      else copy[key] = field
    }
    return copy
  }
  let out: JsonObject = document
  steps.forEach((step: unknown, i: number) => {
    try {
      if (!isObject(step)) throw new Error("a step is an object")
      const ops = (["set", "merge", "remove", "insert"] as const).filter((op) => op in step)
      if (ops.length !== 1) throw new Error("a step is one of set, merge, remove or insert")
      const op = ops[0]
      const path = step[op]
      if (!Array.isArray(path) || path.some((s) => typeof s !== "string")) throw new Error("a path is a list of keys and ids")
      if (path.length > SCENE_PATCH_MAX_DEPTH) throw new Error(`a path reaches at most ${SCENE_PATCH_MAX_DEPTH} deep`)
      // Set as a key, it would set the object's prototype instead, and the
      // scene held here would part from the app's.
      if (path.includes("__proto__")) throw new Error("a path names no __proto__")
      if (op === "insert") {
        out = within(out, path, 0, (list) => {
          if (!Array.isArray(list)) throw new Error(`${shown(path)} is not a list`)
          const id = idOf(step.value)
          if (id === undefined) throw new Error("an insert's value is an object with an id")
          if (step.before !== undefined && typeof step.before !== "string") throw new Error("an insert's before is an id")
          if (indexOf(list, id) >= 0) throw new Error(`${shown(path)} already has ${id}`)
          const at = step.before === undefined ? list.length : indexOf(list, step.before as string)
          if (at < 0) throw new Error(`${shown(path)} has no ${step.before} to insert before`)
          const copy = own(list)
          copy.splice(at, 0, step.value)
          indexes.delete(copy)
          return copy
        }) as JsonObject
        return
      }
      if (path.length === 0) throw new Error("a step names a place in the scene")
      const last = path[path.length - 1]
      out = within(out, path.slice(0, -1), 0, (container) => {
        if (Array.isArray(container)) {
          const at = indexOf(container, last)
          if (op === "set") {
            // An item keeps the id it is found by: one set under another
            // would leave two the list cannot tell apart.
            if (idOf(step.value) !== last) throw new Error(`${shown(path)} is set to an object with the id ${last}`)
            const copy = own(container)
            if (at >= 0) copy[at] = step.value
            else {
              copy.push(step.value)
              indexes.delete(copy)
            }
            return copy
          }
          if (at < 0) throw new Error(`${shown(path)} is not there`)
          const copy = own(container)
          if (op === "merge") {
            const item = merged(container[at], step.value, path)
            if (idOf(item) !== last) throw new Error(`${shown(path)} keeps its id`)
            copy[at] = item
          } else {
            copy.splice(at, 1)
            indexes.delete(copy)
          }
          return copy
        }
        if (isObject(container)) {
          const copy = own(container)
          if (op === "set") {
            if (!("value" in step)) throw new Error("a set has a value")
            copy[last] = step.value
          } else if (op === "merge") copy[last] = merged(container[last], step.value, path)
          else {
            if (!has(container, last)) throw new Error(`${shown(path)} is not there`)
            delete copy[last]
          }
          return copy
        }
        throw new Error(`${shown(path.slice(0, -1))} holds neither keys nor items`)
      }) as JsonObject
    } catch (e) {
      throw new Error(`Scene patch step ${i + 1}: ${e instanceof Error ? e.message : String(e)}`)
    }
  })
  return out
}
