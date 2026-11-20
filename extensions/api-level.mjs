#!/usr/bin/env node
// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The extension API level: which one is open, and the steps that open and
// close it.
//
//   node extensions/api-level.mjs status [--json]   # which level is open, which released
//   node extensions/api-level.mjs open              # open the next level, or name the open one
//   node extensions/api-level.mjs close             # freeze the open level (the Next cut runs it)
//   node extensions/api-level.mjs check [--committed]  # every place agrees; closed rows unchanged
//
// New SDK surface goes in ONE open level until a Next build ships it. The
// level the packer speaks (`H2KEXT_API_VERSION`) is open while it is above the
// highest level in api-levels.json; that file keeps each closed level's row
// from docs/extensions/packaging.md word for word, so surface added to a level
// that apps already run fails the check instead of shipping under a number
// that means something else on those apps.

import { execFileSync } from "node:child_process"
import { readFileSync, realpathSync, writeFileSync } from "node:fs"
import { dirname, join } from "node:path"
import { fileURLToPath, pathToFileURL } from "node:url"

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..")

export const LEVELS_FILE = "extensions/api-levels.json"
const PACKER = "extensions/tools/h2kext.mjs"
const TABLE = "docs/extensions/packaging.md"

/// Every place that states the level. Each pattern matches exactly once, and
/// its `level`/`level2` groups are the level; `patch` is a package's patch
/// version, which opening a level resets. The packer comes first: it is the
/// one the others are checked against.
const CARRIERS = [
  { file: PACKER, pattern: /^export const H2KEXT_API_VERSION = (?<level>\d+)$/dm },
  { file: "app/lib/services/extensions/installed_extensions.dart", pattern: /^const kExtensionApiVersion = (?<level>\d+);$/dm },
  { file: "extensions/sdk/src/index.ts", pattern: /^export const API_VERSION = (?<level>\d+)$/dm },
  { file: "extensions/sdk/package.json", pattern: /^ {2}"version": "1\.(?<level>\d+)\.(?<patch>\d+)",$/dm },
  { file: "extensions/tools/package.json", pattern: /^ {2}"version": "1\.(?<level>\d+)\.(?<patch>\d+)",$/dm },
  { file: "extensions/package-lock.json", pattern: /"name": "@ham2k\/extension-sdk",\n\s+"version": "1\.(?<level>\d+)\.(?<patch>\d+)"/d },
  { file: "extensions/sdk/README.md", pattern: /SDK 1\.(?<level>\d+) describes API (?<level2>\d+)/d },
  { file: "docs/extensions/README.md", pattern: /SDK 1\.(?<level>\d+) describes API (?<level2>\d+)/d },
]

/// Every file the level lives in.
export const FILES = [...new Set([...CARRIERS.map((c) => c.file), TABLE, LEVELS_FILE])]

const read = (root, file) => readFileSync(join(root, file), "utf8")

/// Where the API table starts in packaging.md.
function tableStart(markdown) {
  const start = markdown.indexOf("| Level | Adds |")
  if (start < 0) throw new Error(`${TABLE} has no "| Level | Adds |" table`)
  return start
}

/// The API table's rows in packaging.md, by level.
export function tableRows(markdown) {
  const rows = new Map()
  for (const line of markdown.slice(tableStart(markdown)).split("\n").slice(2)) {
    const match = /^\| (\d+) \|(.*)\|$/.exec(line)
    if (!match) break
    rows.set(Number(match[1]), match[2].trim())
  }
  return rows
}

/// What a carrier says, or why it can't say it.
function carrierLevel(text, { file, pattern }) {
  const matches = [...text.matchAll(new RegExp(pattern.source, pattern.flags + "g"))]
  if (matches.length !== 1) return { problem: `${file}: expected one match for ${pattern}, found ${matches.length}` }
  const { level, level2 } = matches[0].groups
  if (level2 !== undefined && level2 !== level) return { problem: `${file} says SDK 1.${level} describes API ${level2}` }
  return { level: Number(level), match: matches[0] }
}

/// The level the packer speaks, the highest closed one, and the open one
/// (null when the packer speaks a closed level).
export function status(root = ROOT) {
  const closed = JSON.parse(read(root, LEVELS_FILE)).closed
  const keys = Object.keys(closed ?? {})
  if (typeof closed !== "object" || Array.isArray(closed) || !keys.length || !keys.every((k) => /^[1-9]\d*$/.test(k))) {
    throw new Error(`${LEVELS_FILE} must hold "closed": an object of rows keyed by level, with at least one`)
  }
  const released = Math.max(...keys.map(Number))
  const { level, problem } = carrierLevel(read(root, PACKER), CARRIERS[0])
  if (problem) throw new Error(problem)
  return { level, released, open: level > released ? level : null, closed }
}

/// Everything that disagrees, as sentences. Empty when the tree is consistent.
export function problems(root = ROOT) {
  const out = []
  const { level, released, open, closed } = status(root)
  for (const carrier of CARRIERS.slice(1)) {
    const said = carrierLevel(read(root, carrier.file), carrier)
    if (said.problem) out.push(said.problem)
    else if (said.level !== level)
      out.push(`${carrier.file} says API ${said.level}, but the packer speaks ${level} — run \`mise run api:open\` rather than bumping by hand`)
  }
  if (level < released) out.push(`the packer speaks API ${level}, below API ${released}, which ${LEVELS_FILE} says is released`)
  if (level > released + 1) out.push(`the packer speaks API ${level}, but only API ${released} is released: one level is open at a time`)
  if (level > 1 && !new RegExp(`^SHARED_MODULES_BY_API\\[${level}\\] = `, "m").test(read(root, PACKER))) {
    out.push(`${PACKER} has no SHARED_MODULES_BY_API[${level}]: without it an api-${level} bundle builds with no shared modules`)
  }
  const rows = tableRows(read(root, TABLE))
  for (const [key, frozen] of Object.entries(closed)) {
    const row = rows.get(Number(key))
    if (row === frozen) continue
    out.push(
      `API ${key} is released, but its row in ${TABLE} changed.\n` +
        `    released: ${frozen}\n` +
        `    now:      ${row ?? "(no row)"}\n` +
        `  New surface goes in the open level (\`mise run api:open\` opens one). A rewording that adds nothing changes the copy in ${LEVELS_FILE} too.`,
    )
  }
  if (open !== null && !rows.get(open)) out.push(`API ${open} is open, but its row in ${TABLE} is empty — say what it adds`)
  return out
}

/// Text with each named group in [match] replaced by what [values] gives it.
function rewrite(text, match, values) {
  let result = text
  const spans = Object.entries(match.indices.groups)
    .filter(([name, span]) => span && name in values)
    .sort((a, b) => b[1][0] - a[1][0])
  for (const [name, [start, end]] of spans) result = result.slice(0, start) + values[name] + result.slice(end)
  return result
}

/// Opens the level after the released one, editing every carrier, the shared
/// module chain and the table. Returns what it did, in a sentence.
export function open(root = ROOT) {
  const before = problems(root)
  if (before.length) throw new Error(`not opening a level over these:\n${before.join("\n")}`)
  const { level, open } = status(root)
  if (open !== null) return `API ${open} is open: add new surface to its row in ${TABLE}.`
  const next = level + 1
  const writes = new Map()
  for (const carrier of CARRIERS) {
    const text = writes.get(carrier.file) ?? read(root, carrier.file)
    const { match } = carrierLevel(text, carrier)
    writes.set(carrier.file, rewrite(text, match, { level: String(next), level2: String(next), patch: "0" }))
  }
  const chain = `SHARED_MODULES_BY_API[${level}] = SHARED_MODULES_BY_API[${level - 1}]\n`
  const packer = writes.get(PACKER)
  if (!packer.includes(chain)) throw new Error(`${PACKER} has no "${chain.trim()}" line to chain API ${next} after`)
  writes.set(PACKER, packer.replace(chain, `${chain}SHARED_MODULES_BY_API[${next}] = SHARED_MODULES_BY_API[${level}]\n`))
  const table = read(root, TABLE)
  const start = tableStart(table)
  const last = new RegExp(`^\\| ${level} \\|.*\\|$`, "m").exec(table.slice(start))
  if (!last) throw new Error(`${TABLE} has no row for API ${level}`)
  const at = start + last.index + last[0].length
  writes.set(TABLE, `${table.slice(0, at)}\n| ${next} |  |${table.slice(at)}`)
  for (const [file, text] of writes) writeFileSync(join(root, file), text)
  return `API ${next} is open. Say what it adds in its row in ${TABLE}; the Next build that ships it closes it.`
}

/// Freezes the open level's row in api-levels.json. Returns the level closed,
/// or null when none was open.
export function close(root = ROOT) {
  const before = problems(root)
  if (before.length) throw new Error(`not closing a level over these:\n${before.join("\n")}`)
  const { open, closed } = status(root)
  if (open === null) return null
  const levels = { closed: { ...closed, [open]: tableRows(read(root, TABLE)).get(open) } }
  writeFileSync(join(root, LEVELS_FILE), JSON.stringify(levels, null, 2) + "\n")
  return open
}

/// `git status` for the files the level lives in; empty when they match HEAD.
function uncommitted() {
  return execFileSync("git", ["status", "--porcelain", "--", ...FILES], { cwd: ROOT, encoding: "utf8" }).trimEnd()
}

function main([command, ...args]) {
  switch (command) {
    case "status": {
      const { level, released, open } = status()
      if (args.includes("--json")) console.log(JSON.stringify({ level, released, open }))
      else console.log(open === null ? `API ${released} is released; no level is open.` : `API ${open} is open; API ${released} is released.`)
      return 0
    }
    case "open":
      console.log(open())
      return 0
    case "close": {
      // The release commit carries only the levels file, so the row frozen
      // here must be the one HEAD has, and so must everything checked first.
      const dirty = uncommitted()
      if (dirty) throw new Error(`not closing a level while these differ from HEAD, which the release commit would not carry:\n${dirty}`)
      const closed = close()
      console.log(closed === null ? "No level is open; nothing to close." : `API ${closed} is closed.`)
      return 0
    }
    case "check": {
      // --committed vouches for HEAD, which is what a release or code push
      // ships: an uncommitted fix would otherwise clear a tree that still has
      // the problem, and an uncommitted `open` refuse one that doesn't.
      const dirty = args.includes("--committed") ? uncommitted() : ""
      const found = dirty ? [`these differ from HEAD, so the check can't vouch for it — commit or restore them:\n${dirty}`] : problems()
      for (const problem of found) console.error(problem)
      return found.length ? 1 : 0
    }
    default:
      console.error("usage: node extensions/api-level.mjs status [--json] | open | close | check [--committed]")
      return 2
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(realpathSync(process.argv[1])).href) {
  try {
    process.exitCode = main(process.argv.slice(2))
  } catch (e) {
    console.error(e.message)
    process.exitCode = 1
  }
}
