// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import assert from "node:assert/strict"
import { describe, it } from "node:test"

import { buildStashMultipart, STASH_SOURCE, stashBoundary } from "./stash.ts"

const FILE = { filename: "K1ABC@US-0001-20260930.adi", content: "<CALL:4>W1AW <EOR>\n", mimeType: "text/plain", format: "adif" }
const GROUP = { uuid: "0b6f5c1e-0000-4000-8000-000000000001", title: "K1ABC for POTA at US-0001" }

/// The parts of [body] as {headers, value}, split the way a server splits
/// them — so a test fails when the body stops parsing, not when its bytes
/// merely change.
function parse(body: string, boundary: string): { headers: string; value: string }[] {
  const chunks = body.split(`--${boundary}`)
  assert.equal(chunks[0], "", "nothing precedes the first boundary")
  assert.equal(chunks[chunks.length - 1], "--\r\n", "the body ends with the closing boundary")
  return chunks.slice(1, -1).map((chunk) => {
    assert.ok(chunk.startsWith("\r\n") && chunk.endsWith("\r\n"), "every part sits on its own lines")
    const inner = chunk.slice(2, -2)
    const split = inner.indexOf("\r\n\r\n")
    return { headers: inner.slice(0, split), value: inner.slice(split + 4) }
  })
}

function field(parts: { headers: string; value: string }[], name: string): string | undefined {
  return parts.find((p) => p.headers.includes(`name="${name}"`))?.value
}

describe("buildStashMultipart", () => {
  // Rails reads `stash_file[...]` into the nested params the controller
  // `expect`s; a renamed field is dropped there without an error, and the
  // missing `file` then fails validation as though the upload were empty.
  it("sends every field under the names the server expects", () => {
    const { contentType, body } = buildStashMultipart(FILE, GROUP, "B")
    assert.equal(contentType, "multipart/form-data; boundary=B")
    const parts = parse(body, "B")
    assert.equal(field(parts, "stash_file[filename]"), FILE.filename)
    assert.equal(field(parts, "stash_file[format]"), "adif")
    assert.equal(field(parts, "stash_file[source]"), STASH_SOURCE)
    assert.equal(field(parts, "stash_file[group_uuid]"), GROUP.uuid)
    assert.equal(field(parts, "stash_file[group_title]"), GROUP.title)
    assert.equal(field(parts, "stash_file[file]"), FILE.content)
  })

  // Without `filename=` the part is a plain string param, not an upload,
  // and ActiveStorage refuses to attach it.
  it("marks the file part as an upload with its own name and type", () => {
    const parts = parse(buildStashMultipart(FILE, GROUP, "B").body, "B")
    const filePart = parts.find((p) => p.headers.includes('name="stash_file[file]"'))!
    assert.match(filePart.headers, /; filename="K1ABC@US-0001-20260930\.adi"\r\n/)
    assert.match(filePart.headers, /\r\nContent-Type: text\/plain$/)
  })

  it("leaves optional fields out rather than sending them empty", () => {
    const parts = parse(buildStashMultipart({ filename: "a.txt", content: "x" }, { uuid: "u" }, "B").body, "B")
    assert.equal(field(parts, "stash_file[format]"), undefined)
    assert.equal(field(parts, "stash_file[group_title]"), undefined)
  })

  // A quote ends the header's value early and a newline ends the header, so
  // an unescaped one lets a filename rewrite the part.
  it("keeps a hostile filename inside its quotes", () => {
    const parts = parse(buildStashMultipart({ filename: 'a"b\r\nc.txt', content: "x" }, { uuid: "u" }, "B").body, "B")
    const filePart = parts.find((p) => p.headers.includes('name="stash_file[file]"'))!
    assert.match(filePart.headers, /filename="a%22b%0D%0Ac\.txt"/)
  })
})

describe("stashBoundary", () => {
  // A boundary that occurs in the log splits the file at that line — the
  // server stores a truncated log and says nothing.
  it("never returns a boundary that occurs in the content", () => {
    const values = [0.5, 0.5, 0.25, 0.25]
    const random = () => values.shift()!
    const first = `----HaLoStash${Math.floor(0.5 * 2 ** 48).toString(16)}${Math.floor(0.5 * 2 ** 48).toString(16)}`
    const boundary = stashBoundary({ filename: "a.adi", content: `before\n${first}\nafter` }, { uuid: "u" }, random)
    assert.notEqual(boundary, first)
    assert.ok(!`before\n${first}\nafter`.includes(boundary))
  })
})
