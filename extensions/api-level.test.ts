// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import { test } from "node:test"
import assert from "node:assert/strict"
import { copyFileSync, mkdirSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"
import { FILES, LEVELS_FILE, close, open, problems, status, tableRows } from "./api-level.mjs"

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..")
const TABLE = "docs/extensions/packaging.md"

/// A scratch copy of the files the level lives in, so opening and closing
/// run for real without touching the tree.
function scratch(): string {
  const root = mkdtempSync(join(tmpdir(), "api-level-"))
  for (const file of FILES) {
    mkdirSync(dirname(join(root, file)), { recursive: true })
    copyFileSync(join(ROOT, file), join(root, file))
  }
  return root
}

const readIn = (root: string, file: string) => readFileSync(join(root, file), "utf8")
const snapshot = (root: string) => FILES.map((file) => readIn(root, file))

function editRow(root: string, level: number, text: string) {
  const table = readIn(root, TABLE)
  writeFileSync(join(root, TABLE), table.replace(new RegExp(`^\\| ${level} \\|.*\\|$`, "m"), `| ${level} | ${text} |`))
}

/// Leaves the scratch copy with no open level, as right after a Next cut.
function released(root: string): number {
  const { open: level } = status(root)
  if (level !== null) assert.equal(close(root), level)
  return status(root).released
}

test("every place that states the level agrees, and no released level has gained surface", () => {
  assert.deepEqual(problems(ROOT), [])
})

test("surface added to a level after its release fails the check, naming the level and the way out", () => {
  const root = scratch()
  const level = released(root)
  editRow(root, level, `${tableRows(readIn(root, TABLE)).get(level)}; \`host.somethingNew\``)
  const found = problems(root)
  assert.equal(found.length, 1)
  assert.match(found[0], new RegExp(`API ${level} is released`))
  assert.match(found[0], /mise run api:open/)
})

test("opening a level moves every place that states it, chains the shared modules, and adds its row", () => {
  const root = scratch()
  const level = released(root)
  const next = level + 1
  assert.match(open(root), new RegExp(`API ${next} is open`))
  assert.equal(status(root).open, next)
  assert.match(readIn(root, "app/lib/services/extensions/installed_extensions.dart"), new RegExp(`^const kExtensionApiVersion = ${next};$`, "m"))
  assert.equal(JSON.parse(readIn(root, "extensions/sdk/package.json")).version, `1.${next}.0`)
  assert.equal(JSON.parse(readIn(root, "extensions/tools/package.json")).version, `1.${next}.0`)
  assert.match(readIn(root, "docs/extensions/README.md"), new RegExp(`SDK 1\\.${next} describes API ${next}`))
  assert.match(readIn(root, "extensions/tools/h2kext.mjs"), new RegExp(`^SHARED_MODULES_BY_API\\[${next}\\] = SHARED_MODULES_BY_API\\[${level}\\]$`, "m"))
  // The new row starts empty, and the check holds the level open-but-undescribed
  // until whoever opened it says what it adds.
  assert.deepEqual(problems(root), [`API ${next} is open, but its row in ${TABLE} is empty — say what it adds`])
  editRow(root, next, "`host.somethingNew`")
  assert.deepEqual(problems(root), [])
})

test("opening while a level is open changes nothing, so sessions that each open one converge on the same level", () => {
  const root = scratch()
  released(root)
  open(root)
  const level = status(root).open
  editRow(root, level!, "`host.somethingNew`")
  const before = snapshot(root)
  assert.match(open(root), new RegExp(`API ${level} is open: add new surface to its row`))
  assert.deepEqual(snapshot(root), before)
})

test("closing freezes the open level's row word for word, and a cut with nothing open writes nothing", () => {
  const root = scratch()
  released(root)
  open(root)
  const level = status(root).open!
  editRow(root, level, "`host.somethingNew`")
  assert.equal(close(root), level)
  assert.equal(JSON.parse(readIn(root, LEVELS_FILE)).closed[level], "`host.somethingNew`")
  assert.equal(status(root).open, null)
  const before = snapshot(root)
  assert.equal(close(root), null)
  assert.deepEqual(snapshot(root), before)
})

test("a level bumped by hand in one place is named, so opening never runs over a half-done bump", () => {
  const root = scratch()
  const { level } = status(root)
  const file = "extensions/sdk/src/index.ts"
  writeFileSync(join(root, file), readIn(root, file).replace(`export const API_VERSION = ${level}`, `export const API_VERSION = ${level + 1}`))
  assert.match(problems(root).join("\n"), new RegExp(`${file} says API ${level + 1}, but the packer speaks ${level}`))
  assert.throws(() => open(root), /not opening a level/)
})

test("a levels file that lists no closed level is an error, never a level read as open or closed", () => {
  // Read loosely, `{}` makes every level open and a stray key closes none.
  for (const closed of [{}, { latest: "x" }, null]) {
    const root = scratch()
    writeFileSync(join(root, LEVELS_FILE), JSON.stringify({ closed }))
    assert.throws(() => status(root), /must hold "closed"/)
  }
})
