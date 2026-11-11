// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// The Control Board panel: each placement's board, from its own settings, drawn as a scene. Its
// params are the placement's own form, and its menu edits, imports and exports the board.

import {
  renderTemplate,
  templateContext,
  triggersForTemplate,
  type JSONValue,
  type PanelContent,
  type PanelDescriptor,
  type PanelHook,
  type PanelMenuEntry,
  type PanelRenderArgs,
  type PanelSceneEventResult,
} from "@ham2k/extension-sdk"
import { actionsFor, runActions, varsOf, type BoardHost } from "./actions.ts"
import { BoardError, parseBoard, type Board } from "./board.ts"
import { compileBoard, stampOf, varValues } from "./compile.ts"
import { paramsForm, paramsKey, paramValues, resolveSources } from "./params.ts"
import { sampleBoard } from "./sample.ts"

/** At most this many placements' vars are kept; the oldest goes first. */
const maxPlacements = 64

/** What every board placement keeps, and how its board moves in and out of a file. */
const placement: Pick<PanelDescriptor, "multiple" | "form" | "config" | "file"> = {
  multiple: true,
  form: [{ type: "field", fieldType: "multiline", key: "board", label: "Board (YAML)" }],
  config: [paramsKey],
  file: { key: "board", extension: "h2kboard" },
}

/** The pane's menu: the board's YAML, until the editor takes its place. */
const menu: PanelMenuEntry[] = [{ label: "Edit Board…", settings: true }]

export function createBoardPanel(host: BoardHost): PanelHook {
  // Each placement's vars, for the board text they were set under: an edited board starts over,
  // and a new board in a slot another one left does not take on its knob positions.
  const placements = new Map<string, { stamp: string; vars: Record<string, number | string> }>()
  // The last boards read, by their text itself: a knob's step renders the board again, its text
  // the same, and a hash of it could, however rarely, name another board.
  const parsed = new Map<string, Board>()
  const boardOf = (text: string) => {
    let board = parsed.get(text)
    if (!board) {
      board = parseBoard(text)
      if (parsed.size >= maxPlacements) parsed.delete(parsed.keys().next().value!)
      parsed.set(text, board)
    }
    return board
  }
  const varsOf_ = (id: string, stamp: string) => {
    let mine = placements.get(id)
    if (!mine || mine.stamp !== stamp) {
      placements.delete(id)
      if (placements.size >= maxPlacements) placements.delete(placements.keys().next().value!)
      mine = { stamp, vars: {} }
    }
    // Moved to the end on every use, so the one evicted is the one used longest ago.
    placements.delete(id)
    placements.set(id, mine)
    return mine.vars
  }
  /** Liquid, with the placement's params beside the template context's own values. */
  const text = (args: PanelRenderArgs, params: Record<string, JSONValue>) => {
    const context = {
      ...templateContext({ operation: args.operation, qsoCount: args.qsoCount, ...(args.qso ? { qso: args.qso } : {}), config: args.config }),
      params,
    }
    return (template: string) => (template.includes("{{") || template.includes("{%") ? renderTemplate(template, context) : template)
  }
  const textOf = (args: PanelRenderArgs) => (typeof args.config?.board === "string" ? args.config.board : "")

  /** A file's board, kept with its params cleared: another station's radio ids mean nothing here. */
  async function imported(file: string | undefined): Promise<PanelSceneEventResult> {
    // Read as an empty board, a missing text would replace the pane's board with nothing.
    if (typeof file !== "string") throw new Error("A file event carries the file's text")
    try {
      parseBoard(file)
      return { values: {}, config: { board: file, [paramsKey]: {} } }
    } catch (e) {
      if (!(e instanceof BoardError)) throw e
      await host.showMessage({ presentation: "status", text: `That file is not a board this app can read: ${e.message}` })
      return { values: {} }
    }
  }

  return {
    async getPanels() {
      return [
        {
          key: "board",
          title: "Control Board",
          description: "An empty board of buttons, meters and controls for the station, laid out on a grid you write",
          icon: "view-dashboard-variant",
          ...placement,
        },
        {
          key: "sample",
          title: "Sample Control Board",
          description: "A station board to start from: the dial, meters, power and a rotator",
          icon: "view-dashboard-variant",
          ...placement,
          initialConfig: { board: sampleBoard },
        },
      ]
    },

    async render(args): Promise<PanelContent> {
      const source = textOf(args)
      const stamp = stampOf(source)
      try {
        const board = boardOf(source)
        const params = paramValues(board.params, args.config?.[paramsKey])
        const vars = args.instanceId ? varsOf_(args.instanceId, stamp) : {}
        const { scene, templates } = compileBoard(board, args.environment, vars, text(args, params), stamp)
        const triggers = [...new Set(templates.flatMap(triggersForTemplate))]
        const form = paramsForm(board.params)
        return {
          kind: "scene",
          scene,
          ...(board.name ? { title: board.name } : {}),
          ...(triggers.length ? { triggers } : {}),
          ...(form ? { form } : {}),
          menu,
        }
      } catch (e) {
        if (!(e instanceof BoardError)) throw e
        return { kind: "markdown", content: `**This board cannot be drawn.**\n\n${e.message}`, menu }
      }
    },

    async onEvent(args) {
      const { event } = args
      if (event.controlId === "file" && event.action === "file") return imported(event.text)
      const source = textOf(args)
      const stamp = stampOf(source)
      if (!args.instanceId) throw new Error("A board's event names no placement")
      const mine = varsOf_(args.instanceId, stamp)
      let board: Board | undefined
      // Until the event names its item, every var: put back all, since a control still held is
      // the app's to keep, and an answer cannot name which.
      let changed: string[] = []
      try {
        board = boardOf(source)
        changed = Object.keys(board.vars)
        const { item, actions, value, sets } = actionsFor(board, stamp, event.action, event.value ?? event.text)
        changed = varsOf(item)
        const started = { ...mine }
        const next = { ...mine, ...sets }
        const params = paramValues(board.params, args.config?.[paramsKey])
        const nextParams = { ...params }
        // On the params as the actions change them: an action after a `setParam` commands the
        // equipment it just picked, and says its words with the new value.
        const words = text(args, nextParams)
        const render = (template: string) => {
          try {
            return words(template)
          } catch (e) {
            throw new BoardError(`The Liquid in an action cannot be rendered: ${(e as Error).message}`)
          }
        }
        const drawn = board
        await runActions(host, actions, {
          board: drawn,
          get sources() {
            return resolveSources(drawn, render)
          },
          vars: next,
          params: nextParams,
          value,
          text: render,
        })
        // Only what this event changed is written back: another event's change made meanwhile stays.
        const touched = Object.keys(next).filter((name) => next[name] !== started[name])
        for (const name of touched) mine[name] = next[name]
        // Only the vars this event changed: an answer naming the others would put back any a
        // control is still holding.
        const answer: PanelSceneEventResult = varValues(board, mine, new Set([...changed, ...touched]))
        const paramsChanged = Object.keys(nextParams).some((name) => nextParams[name] !== params[name])
        return paramsChanged ? { ...answer, config: { [paramsKey]: nextParams } } : answer
      } catch (e) {
        if (!(e instanceof BoardError)) throw e
        // A refusal is the operator's to read, not a failure to report: said where they look, with
        // the control put back where the board still has it.
        await host.showMessage({ presentation: "status", text: e.message })
        return board ? varValues(board, mine, changed) : { values: {}, strings: {} }
      }
    },
  }
}
