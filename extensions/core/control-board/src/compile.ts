// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// A board, compiled to a scene: each widget a cell at its own size, each group a grid, the board's
// sources the scene's, and its vars scene values. What a control sends names the board it came
// from by a stamp of its text and the widget by its path, so an event finds its actions in the same
// board again, and one sent from a board since edited is refused rather than run on another item.

import type { PanelEnvironment, PanelScene, PanelSceneControl, PanelSceneLayer, PanelSceneLayoutNode } from "@ham2k/extension-sdk"
import { BoardError, placeName, type Board, type BoardGrid } from "./board.ts"
import { resolveSources } from "./params.ts"
import { buildWidget, type Theme } from "./widgets.ts"

/** Liquid, for a widget's words: rendered against the panel's template context. */
export type RenderText = (template: string) => string

export interface CompiledBoard {
  scene: PanelScene
  /** Every template the board renders, for the triggers that keep it current. */
  templates: string[]
}

const defaultUnit: [number, number] = [48, 48]
const defaultGap = 4

/** The most a cell may measure either way, as the app takes one. */
const maxCell = 8192

/** The smallest a widget's cell may be, in pixels across and down: below it, its parts overlap. */
const minimumCell: Record<string, [number, number]> = {
  label: [16, 16],
  readout: [40, 24],
  frequency: [96, 24],
  button: [24, 24],
  toggle: [40, 24],
  bar: [40, 20],
  ledBar: [40, 16],
  needle: [64, 48],
  knob: [32, 32],
  slider: [40, 20],
  menuButton: [40, 24],
  segmented: [48, 24],
}

export const defaultSpans: Record<string, [number, number]> = {
  label: [3, 1],
  readout: [2, 1],
  frequency: [4, 1],
  button: [2, 1],
  toggle: [2, 1],
  bar: [4, 1],
  ledBar: [4, 1],
  needle: [3, 2],
  knob: [2, 2],
  slider: [4, 1],
  menuButton: [2, 1],
  segmented: [4, 1],
}

/**
 * A stamp of a board's text, which its events carry so a board edited since is told apart: two
 * 32-bit hashes, so two texts sharing one stamp is not a thing to plan for.
 */
export function stampOf(text: string): string {
  let a = 0x811c9dc5
  let b = 5381
  for (let i = 0; i < text.length; i++) {
    const c = text.charCodeAt(i)
    a = Math.imul(a ^ c, 0x01000193)
    b = (Math.imul(b, 33) + c) | 0
  }
  return (a >>> 0).toString(36) + (b >>> 0).toString(36)
}

/** Values a board's vars hold, as the scene holds them: `var.<name>`, a number or a word; [only] those named. */
export function varValues(board: Board, state: Record<string, number | string>, only?: Iterable<string>) {
  const values: Record<string, number> = {}
  const strings: Record<string, string> = {}
  for (const name of only ? [...only] : Object.keys(board.vars)) {
    const start = board.vars[name]
    const now = state[name] ?? start
    if (typeof start === "number") values[`var.${name}`] = typeof now === "number" ? now : start
    else strings[`var.${name}`] = typeof now === "string" ? now : start
  }
  return { values, strings }
}

export function compileBoard(
  board: Board,
  environment: PanelEnvironment | undefined,
  state: Record<string, number | string>,
  text: RenderText,
  stamp: string,
): CompiledBoard {
  const theme = themeOf(environment)
  const templates: string[] = []
  const wordsAt =
    (where: string): RenderText =>
    (template) => {
      templates.push(template)
      try {
        return text(template)
      } catch (e) {
        throw new BoardError(`The Liquid in ${where} cannot be rendered: ${(e as Error).message}`)
      }
    }
  const { values, strings } = varValues(board, state)
  const cells: { id: string; width: number; height: number }[] = []
  const layers: PanelSceneLayer[] = []
  const controls: PanelSceneControl[] = []

  function grid(
    spec: BoardGrid,
    path: string,
    parent: { unit: [number, number]; gap: [number, number]; columns?: number } | null,
    outermost: boolean,
  ): PanelSceneLayoutNode {
    const where = path ? placeName(path.slice(0, -1)) : "the board"
    const unit = spec.unit ?? parent?.unit ?? defaultUnit
    const gap: [number, number] =
      spec.gap === undefined ? (parent?.gap ?? [defaultGap, defaultGap]) : typeof spec.gap === "number" ? [spec.gap, spec.gap] : spec.gap
    // A wrapping group takes a whole row of its parent, so its widest child must fit there.
    if (parent?.columns && spec.columns === undefined) {
      const needs = slotsAcross(spec, unit, gap, parent.unit, parent.gap)
      if (needs > parent.columns) throw new BoardError(`${where} needs ${needs} columns of the grid it is in, which has ${parent.columns}`)
    }
    const children: PanelSceneLayoutNode[] = spec.items.map((item, i) => {
      const at = `${path}${i}`
      if (item.type === "group") return grid(item as unknown as BoardGrid, `${at}.`, { unit, gap, columns: spec.columns }, false)
      const span = item.span ?? defaultSpans[item.type] ?? [1, 1]
      if (spec.columns !== undefined && span[0] > spec.columns) throw new BoardError(`${placeName(at)} spans ${span[0]} columns of a grid with ${spec.columns}`)
      const width = span[0] * unit[0] + (span[0] - 1) * gap[0]
      const height = span[1] * unit[1] + (span[1] - 1) * gap[1]
      const [minWidth, minHeight] = minimumCell[item.type] ?? [16, 16]
      if (width < minWidth || height < minHeight)
        throw new BoardError(`${placeName(at)} is ${width} by ${height} pixels; a ${item.type} needs at least ${minWidth} by ${minHeight}`)
      if (width > maxCell || height > maxCell) throw new BoardError(`${placeName(at)} is ${width} by ${height} pixels; a cell is at most ${maxCell} either way`)
      const cell = `w${at}`
      let built
      try {
        built = buildWidget(item, { cell, width, height, theme, text: wordsAt(placeName(at)), path: at, stamp })
      } catch (e) {
        if (e instanceof BoardError && !e.message.includes(placeName(at))) throw new BoardError(`${placeName(at)}: ${e.message}`)
        throw e
      }
      // A part under a pixel is refused by the app, scene and all: said here, by the item.
      for (const part of [...built.layers, ...built.controls] as { id: string; width?: number; height?: number }[]) {
        if (part.width !== undefined && !(part.width >= 1 && part.height! >= 1)) {
          throw new BoardError(`${placeName(at)} is too small for its parts at ${width} by ${height} pixels; give it a larger \`span\``)
        }
      }
      cells.push({ id: cell, width, height })
      const when = item.when
      for (const layer of built.layers) layers.push({ ...layer, cell, ...(when ? { when } : {}) } as PanelSceneLayer)
      for (const control of built.controls) controls.push({ ...control, cell, ...(when ? { when } : {}) } as PanelSceneControl)
      return { cell, span }
    })
    const title = spec.title === undefined ? undefined : wordsAt(`the title of ${where}`)(spec.title)
    if (title !== undefined && title.length > 256) throw new BoardError(`The title of ${where} comes out ${title.length} characters long, at most 256`)
    const style =
      title !== undefined || spec.background || spec.border
        ? {
            ...(title ? { title } : {}),
            ...(spec.background ? { background: spec.background } : {}),
            ...(spec.border ? { border: { color: spec.border } } : {}),
            ...(spec.radius !== undefined ? { radius: spec.radius } : {}),
          }
        : undefined
    return {
      grid: children,
      ...(outermost || spec.unit ? { unit } : {}),
      ...(outermost || spec.gap !== undefined ? { gap } : {}),
      ...(spec.columns !== undefined ? { columns: spec.columns } : {}),
      ...(spec.padding !== undefined ? { padding: spec.padding } : outermost ? { padding: 8 } : {}),
      ...(style ? { style } : {}),
    } as PanelSceneLayoutNode
  }

  const layout = grid(board, "", null, true)
  if (!board.items.length) {
    // An empty board says what it is for, rather than drawing a blank pane.
    const hint = "Edit this board in the pane's settings"
    cells.push({ id: "hint", width: 320, height: 48 })
    layers.push({ id: "hint", cell: "hint", x: 0, y: 12, width: 320, height: 24, text: { literal: hint, size: theme.body.size, color: theme.dim } })
    ;(layout as { grid: PanelSceneLayoutNode[] }).grid.push({ cell: "hint" } as PanelSceneLayoutNode)
  }
  // The scene's own budgets, said by the board rather than left to the app's "could not be displayed".
  let nodes = 0
  let depth = 0
  const count = (node: PanelSceneLayoutNode, level: number) => {
    nodes++
    depth = Math.max(depth, level)
    for (const child of (node as { grid?: PanelSceneLayoutNode[] }).grid ?? []) count(child, level + 1)
  }
  count(layout, 1)
  for (const [what, n, max] of [
    ["layers", layers.length, 512],
    ["controls", controls.length, 256],
    ["cells", cells.length, 256],
    ["grids and widgets", nodes, 512],
    ["levels of groups", depth, 12],
  ] as const) {
    if (n > max) throw new BoardError(`The board draws ${n} ${what}, and a panel holds at most ${max}`)
  }
  return {
    scene: {
      version: 1,
      width: 1,
      height: 1,
      values,
      strings,
      ...(Object.keys(board.sources).length
        ? {
            sources: resolveSources(board, (template) => {
              templates.push(template)
              return text(template)
            }),
          }
        : {}),
      cells,
      layers,
      controls,
      layout,
    } as PanelScene,
    templates,
  }
}

/**
 * The slots of a parent grid a wrapping group takes at its narrowest, as the scene counts them: its
 * widest child, a wrapping group within it at its own narrowest, plus its padding.
 */
function slotsAcross(spec: BoardGrid, unit: [number, number], gap: [number, number], parentUnit: [number, number], parentGap: [number, number]): number {
  let widest = 1
  for (const item of spec.items) {
    let cols: number
    if (item.type === "group") {
      const g = item as unknown as BoardGrid
      const inner: [number, number] = typeof g.gap === "number" ? [g.gap, g.gap] : (g.gap ?? gap)
      cols = g.columns !== undefined ? 1 : slotsAcross(g, g.unit ?? unit, inner, unit, gap)
    } else {
      cols = (item.span ?? defaultSpans[item.type] ?? [1, 1])[0]
    }
    widest = Math.max(widest, cols)
  }
  const width = widest * unit[0] + (widest - 1) * gap[0] + 2 * (spec.padding ?? 0)
  return Math.max(1, Math.ceil((width + parentGap[0]) / (parentUnit[0] + parentGap[0]) - 1e-6))
}

const fallbackColors: PanelEnvironment["colors"] = {
  surface: "#121417",
  surfaceContainer: "#1d2126",
  onSurface: "#e2e2e6",
  onSurfaceVariant: "#c3c6cf",
  accent: "#7ad1c6",
  primary: "#7ab8ff",
  onPrimary: "#00315c",
  secondary: "#bbc7db",
  outline: "#8d9199",
  outlineVariant: "#43474e",
  error: "#ffb4ab",
  onError: "#690005",
}

/** The colors and type sizes the widgets draw with, from the pane's render environment. */
export function themeOf(environment: PanelEnvironment | undefined): Theme {
  const colors = { ...fallbackColors, ...(environment?.colors ?? {}) }
  const size = (role: "body" | "label" | "title" | "display" | "mono", fallback: number) => ({
    size: environment?.typography?.[role]?.fontSize ?? fallback,
    family: environment?.typography?.[role]?.fontFamily ?? undefined,
  })
  return {
    colors,
    face: colors.surfaceContainer,
    ink: colors.onSurface,
    dim: colors.onSurfaceVariant,
    track: colors.outlineVariant,
    lit: colors.accent,
    active: colors.primary,
    onActive: colors.onPrimary,
    warn: colors.error,
    body: size("body", 14),
    label: size("label", 11),
    title: size("title", 16),
    display: size("display", 36),
    mono: size("mono", 14),
  }
}
