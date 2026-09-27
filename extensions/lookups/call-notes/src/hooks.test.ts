// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Source precedence through the HOOKS: the help text promises that the file
// listed last wins, so a custom file overrides the built-in notes. Building
// the precedence list in panel order (builtin first) makes the first two
// tests fail.

import { test } from "node:test"
import assert from "node:assert/strict"

import { loadExtension } from "../../../sdk/src/testing.ts"
import { customIdentifier, parseCallNotes } from "./callNotes.ts"

const FIRST = "https://example.com/first.txt"
const SECOND = "https://example.com/second.txt"

const callNotes = await loadExtension(() => import("./index.ts"), {
  hostCalls: {
    getSettings: () => ({
      extensions: {
        "extension_call-notes": {
          customFiles: [
            { name: "First", location: FIRST },
            { name: "Second", location: SECOND },
          ],
        },
      },
    }),
  },
})

const load = (key: string, body: string) => callNotes.runHook("dataFile", "onLoadRawData", parseCallNotes(body), { key })

await load("hams-of-note", "K1ABC 📻 Builtin note\nDAN K1BLT\nKI2D/P Portable note\nW1AW Memorial Station")
await load(customIdentifier(FIRST), "K1ABC First file note\nDAN K1FST\nW1AW Memorial Station")
await load(customIdentifier(SECOND), "K1ABC 🎉 Second file, line one\nK1ABC Second file, line two\nDAN K1SND\nKI2D Base note")

const lookup = async (callInfo: Record<string, string>) => ((await callNotes.runHook("lookup", "lookupCall", { callInfo, qso: {}, operation: {} })) as any[])[0]

test("the file listed last comes first, keeps its own lines in file order, and supplies the marker", async () => {
  const result = await lookup({ call: "K1ABC" })
  assert.deepEqual(result.notes, ["🎉 Second file, line one", "Second file, line two", "First file note", "📻 Builtin note"])
  assert.equal(result.emoji, "🎉")
})

test("a custom file's expansion overrides the built-in one for the same key", async () => {
  const answer = (await callNotes.runHook("command", "interpret", { input: "//DAN" })) as any
  assert.deepEqual(answer.commands, [{ setCallField: { text: "K1SND" } }])
})

test("any file's note for the exact call outranks a higher file's note for the base call", async () => {
  const result = await lookup({ call: "KI2D/P", baseCall: "KI2D" })
  assert.deepEqual(result.notes, ["Portable note", "Base note"])
})

test("the same note in two files shows once", async () => {
  assert.deepEqual((await lookup({ call: "W1AW" })).notes, ["Memorial Station"])
})
