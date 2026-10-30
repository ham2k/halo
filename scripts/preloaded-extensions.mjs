#!/usr/bin/env node
// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The catalog bundles the app ships pre-loaded, held to what the catalog
// serves (docs/design/extension-install.md, "What the app builds in, and what it pre-loads").
//
//   node scripts/preloaded-extensions.mjs check
//   node scripts/preloaded-extensions.mjs update [key…]
//
// `check` exits 1 unless every bundle in app/assets/preloaded-extensions/ is
// byte for byte the catalog's current stable release, as the app itself would
// be offered it. `update` makes them so, and pre-loads any [key] named that is
// not shipped yet.
//
// A pre-load behind the catalog is not harmless: a new install starts on it,
// and every install is then offered the update on its first catalog check —
// an update the release could have carried.

import { createHash } from "node:crypto"
import { readFile, writeFile, unlink } from "node:fs/promises"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"

const root = join(dirname(fileURLToPath(import.meta.url)), "..")
const assetDir = join(root, "app/assets/preloaded-extensions")
const indexPath = join(assetDir, "index.json")
const catalogUrl = process.env.H2K_CATALOG_URL ?? "https://catalog.ham2k.net"

const sha256 = (bytes) => createHash("sha256").update(bytes).digest("hex")

/// A catalog that never answers must not hold a release cut hostage.
const fetchTimeoutMs = 60_000
const fetchWithTimeout = (url) => fetch(url, { signal: AbortSignal.timeout(fetchTimeoutMs) })

/// The extension API level this build speaks, read from the app rather than
/// restated here: the catalog filters its listing by it, and a copy would
/// drift the day the app moves.
async function appApiVersion() {
  const source = await readFile(join(root, "app/lib/services/extensions/installed_extensions.dart"), "utf8")
  const match = source.match(/^const kExtensionApiVersion = (\d+);/m)
  if (!match) throw new Error("kExtensionApiVersion not found in installed_extensions.dart")
  return Number(match[1])
}

/// What the app would be offered: the stable channel, at its API level.
async function listing() {
  const api = await appApiVersion()
  const response = await fetchWithTimeout(`${catalogUrl}/api/v1/catalog?channel=stable&api=${api}`)
  if (!response.ok) throw new Error(`catalog listing: HTTP ${response.status}`)
  const { extensions } = await response.json()
  return new Map(extensions.map((entry) => [entry.key, entry]))
}

async function readIndex() {
  return JSON.parse(await readFile(indexPath, "utf8"))
}

async function check() {
  const { preloaded } = await readIndex()
  const offered = await listing()
  const problems = []
  for (const bundle of preloaded) {
    const bytes = await readFile(join(assetDir, bundle.file)).catch(() => null)
    const latest = offered.get(bundle.key)
    if (!bytes) problems.push(`${bundle.key}: ${bundle.file} is missing`)
    else if (sha256(bytes) !== bundle.sha256) problems.push(`${bundle.key}: ${bundle.file} does not match the sha256 index.json records`)
    else if (!latest) problems.push(`${bundle.key}: the catalog's stable channel does not list it`)
    else if (latest.sha256 !== bundle.sha256) problems.push(`${bundle.key}: ships ${bundle.version}, the catalog serves ${latest.version}`)
  }
  for (const problem of problems) console.log(`✗ ${problem}`)
  if (problems.length) {
    console.log(`\n${problems.length} of ${preloaded.length} pre-loaded extensions are not ${catalogUrl}'s current release.`)
    console.log("Run `node scripts/preloaded-extensions.mjs update` and commit the result.")
    process.exit(1)
  }
  console.log(`✓ all ${preloaded.length} pre-loaded extensions are ${catalogUrl}'s current release`)
}

async function update(added) {
  const index = await readIndex()
  const offered = await listing()
  const keys = [...new Set([...index.preloaded.map((bundle) => bundle.key), ...added])].sort()
  const previous = new Map(index.preloaded.map((bundle) => [bundle.key, bundle]))
  // Everything is fetched and verified before anything is written: a failure
  // part way — a key the catalog does not list, a download that breaks off —
  // would otherwise leave files no index entry names, or entries naming files
  // already deleted.
  const changes = []
  const preloaded = []
  for (const key of keys) {
    const latest = offered.get(key)
    if (!latest) throw new Error(`${key}: the catalog's stable channel does not list it`)
    const file = `${key}-${latest.version}.h2kext`
    const old = previous.get(key)
    if (old?.sha256 !== latest.sha256) {
      const response = await fetchWithTimeout(latest.bundleUrl)
      if (!response.ok) throw new Error(`${key} ${latest.version}: HTTP ${response.status}`)
      const bytes = Buffer.from(await response.arrayBuffer())
      // The catalog freezes a version's bytes on approval, so a mismatch is a
      // bad download, never a newer build of the same version.
      if (sha256(bytes) !== latest.sha256) throw new Error(`${key} ${latest.version}: downloaded bytes do not match the catalog's sha256`)
      changes.push({ key, old, version: latest.version, file, bytes })
    }
    preloaded.push({ key, version: latest.version, file, sha256: latest.sha256 })
  }
  for (const { file, bytes } of changes) await writeFile(join(assetDir, file), bytes)
  await writeFile(indexPath, `${JSON.stringify({ ...index, preloaded }, null, 2)}\n`)
  for (const { key, old, version, file } of changes) {
    if (old && old.file !== file) await unlink(join(assetDir, old.file))
    console.log(old ? `${key} ${old.version} → ${version}` : `${key} ${version} (new)`)
  }
}

const [command, ...args] = process.argv.slice(2)
if (command === "check") await check()
else if (command === "update") await update(args)
else {
  console.error("usage: node scripts/preloaded-extensions.mjs check | update [key…]")
  process.exit(2)
}
