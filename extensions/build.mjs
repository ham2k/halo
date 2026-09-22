// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Bundles the kernel and every extension into single-file IIFE bundles for the
// QuickJS runtime, and writes an index.json the Dart host uses to know what
// to load. Output goes into the Flutter app's assets.
//
// WHAT is built and HOW lives in build-config.mjs, shared with dev-server.mjs
// so the bundles an author iterates on are built exactly like the ones that
// ship. This file is only the writing of them.

import { build } from "esbuild"
import { mkdir, writeFile, readdir, unlink } from "node:fs/promises"
import { join } from "node:path"

import { bundles, buildOptionsFor, fixturesDir, indexEntryFor, loadHostSharedVersions, loadManifests, outDir } from "./build-config.mjs"
import { checkHooksAgainstManifests } from "./hook-check.mjs"

const hostSharedVersions = await loadHostSharedVersions()
await loadManifests()

await mkdir(outDir, { recursive: true })
await mkdir(fixturesDir, { recursive: true })

const dirFor = (bundle) => (bundle.kind === "fixture" ? fixturesDir : outDir)

for (const bundle of bundles) {
  const result = await build(
    buildOptionsFor(bundle, {
      hostSharedVersions,
      outfile: join(dirFor(bundle), `${bundle.key}.js`),
    }),
  )
  const bytes = Object.values(result.metafile.outputs)[0].bytes
  console.log(`${bundle.key}.js — ${(bytes / 1024).toFixed(1)} KB`)
}

await writeFile(
  join(outDir, "index.json"),
  JSON.stringify(
    {
      kernel: "kernel.js",
      // What this build's kernel carries, for extensions that declare
      // `sharedDependencies` rather than inlining their own copies. The host
      // checks a declared range against these before loading an installed
      // bundle (HALO-422) — which is only possible if the versions travel
      // where Dart can read them without booting the runtime.
      sharedModules: hostSharedVersions,
      extensions: bundles.filter((b) => b.kind === "extension").map(indexEntryFor),
    },
    null,
    2,
  ),
)
// Delete bundles for extensions that no longer exist. The output directory is
// gitignored and never cleaned, so removing an extension otherwise leaves its
// .js behind forever — and an ORPHAN is worse than a stale bundle, because the
// staleness check compares timestamps and an orphan has no source to be newer
// than it. A test or host that reads such a bundle by key keeps working locally
// off a file that no longer has any right to exist, while CI — which builds into
// a clean tree — fails. That is how the sandbox clock test came to pass here and
// fail there.
//
// A fixture in [outDir] is an orphan like any other — and the one that matters
// most, since everything in that directory ships.
for (const dir of [outDir, fixturesDir]) {
  const expected = new Set(bundles.filter((b) => dirFor(b) === dir).map((b) => `${b.key}.js`))
  if (dir === outDir) expected.add("index.json")
  for (const name of await readdir(dir)) {
    if (expected.has(name)) continue
    await unlink(join(dir, name))
    console.log(`removed orphan — ${name}`)
  }
}

console.log(`index.json — ${bundles.filter((b) => b.kind === "extension").length} extensions`)

// Last, because it evaluates what was just written: every manifest's `hooks`
// must be what its code registers (hook-check.mjs).
await checkHooksAgainstManifests({ bundles, outDir })
console.log("hooks — every manifest matches what its bundle registers")
