// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// The Control Board panel: each placement's board, from its own settings, drawn as a scene.

import { renderTemplate, templateContext, triggersForTemplate, type PanelContent, type PanelHook, type PanelRenderArgs } from "@ham2k/extension-sdk"
import { actionsFor, runActions, varsOf, type BoardHost } from "./actions.ts"
import { BoardError, parseBoard, type Board } from "./board.ts"
import { compileBoard, stampOf, varValues } from "./compile.ts"

const panelKey = "board"

/** At most this many placements' vars are kept; the oldest goes first. */
const maxPlacements = 64

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
  const text = (args: PanelRenderArgs) => {
    const context = templateContext({ operation: args.operation, qsoCount: args.qsoCount, ...(args.qso ? { qso: args.qso } : {}), config: args.config })
    return (template: string) => (template.includes("{{") || template.includes("{%") ? renderTemplate(template, context) : template)
  }
  const textOf = (args: PanelRenderArgs) => (typeof args.config?.board === "string" ? args.config.board : "")

  return {
    async getPanels() {
      return [
        {
          key: panelKey,
          title: "Control Board",
          description: "Buttons, meters and controls for the station, laid out on a grid you write",
          icon: "view-dashboard-variant",
          multiple: true,
          form: [
            {
              type: "field",
              fieldType: "multiline",
              key: "board",
              label: "Board (YAML)",
              placeholder:
                "ham2k-board: 1\nsources:\n  rig: { radio: null }\nitems:\n  - { type: needle, value: rig.signalDbm, min: -130, max: -10, label: S }",
            },
          ],
        },
      ]
    },

    async render(args): Promise<PanelContent> {
      const source = textOf(args)
      const stamp = stampOf(source)
      let board: Board
      try {
        board = boardOf(source)
        const vars = args.instanceId ? varsOf_(args.instanceId, stamp) : {}
        const { scene, templates } = compileBoard(board, args.environment, vars, text(args), stamp)
        const triggers = [...new Set(templates.flatMap(triggersForTemplate))]
        return { kind: "scene", scene, ...(board.name ? { title: board.name } : {}), ...(triggers.length ? { triggers } : {}) }
      } catch (e) {
        if (!(e instanceof BoardError)) throw e
        return { kind: "markdown", content: `**This board cannot be drawn.**\n\n${e.message}` }
      }
    },

    async onEvent(args) {
      const source = textOf(args)
      const stamp = stampOf(source)
      if (!args.instanceId) throw new Error("A board's event names no placement")
      const mine = varsOf_(args.instanceId, stamp)
      const { event } = args
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
        const words = text(args)
        await runActions(host, actions, {
          board,
          vars: next,
          value,
          text: (template) => {
            try {
              return words(template)
            } catch (e) {
              throw new BoardError(`The Liquid in an action cannot be rendered: ${(e as Error).message}`)
            }
          },
        })
        // Only what this event changed is written back: another event's change made meanwhile stays.
        const touched = Object.keys(next).filter((name) => next[name] !== started[name])
        for (const name of touched) mine[name] = next[name]
        // Only the vars this event changed: an answer naming the others would put back any a
        // control is still holding.
        return varValues(board, mine, new Set([...changed, ...touched]))
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
