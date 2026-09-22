// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// The samples (HALO-452). They ship inside `@ham2k/extension-sdk` as the
// worked examples an author — or the agent writing for one — copies, so the
// bar is that each one BUILDS and would PACK.
//
// Nothing else here covers them: they are not in `build-config.mjs`'s bundle
// list, so `npm run build` never touches them, and a typecheck cannot see an
// undeclared shared dependency or a manifest the packer would refuse. Left to
// that, a sample rots into something that reads fine and fails on the first
// command its reader runs.

import { test } from "node:test"
import assert from "node:assert/strict"
import { build } from "esbuild"
import { cp, mkdtemp, readFile, readdir } from "node:fs/promises"
import { tmpdir } from "node:os"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"

// @ts-ignore — deliberately plain JS, meant to travel to a published package.
import { buildExtension } from "../tools/h2kext-build.mjs"
import { validateManifest } from "../tools/h2kext.mjs"

const samplesDir = dirname(fileURLToPath(import.meta.url))
const sdkEntry = join(samplesDir, "../sdk/src/index.ts")

async function sampleDirs(): Promise<string[]> {
  const entries = await readdir(samplesDir, { withFileTypes: true })
  return entries
    .filter((e) => e.isDirectory())
    .map((e) => e.name)
    .sort()
}

test("every sample builds and passes the packer's manifest checks", async (t) => {
  const dirs = await sampleDirs()
  // The list is discovered, not restated: a sample added and never wired into
  // this test would be one nobody builds — which is the state this test exists
  // to end.
  assert.ok(dirs.length >= 5, `expected the samples to still be here, found ${dirs.join(", ") || "none"}`)

  for (const name of dirs) {
    await t.test(name, async () => {
      const dir = join(samplesDir, name)
      const manifest = JSON.parse(await readFile(join(dir, "manifest.json"), "utf8"))

      assert.deepEqual(validateManifest(manifest), [], `${name}'s manifest would not pack`)

      // Built from a COPY, in a temp directory. `buildExtension` writes
      // `build/` inside the directory it is given — it is an author's own
      // project directory, so there is nowhere else for it to go — and a test
      // that let it write here would leave output in the tree for the next
      // `h2kext-pack` to package.
      const workDir = join(await mkdtemp(join(tmpdir(), `h2kext-sample-${name}-`)), name)
      await cp(dir, workDir, { recursive: true })

      const { outDir } = await buildExtension(build, {
        dir: workDir,
        // The one difference from an author's build, and the reason the shipped
        // copy of these samples carries a different `build.mjs`: here the SDK is
        // a workspace path, there it is an npm dependency.
        alias: { "@ham2k/extension-sdk": sdkEntry },
        logLevel: "silent",
      })

      const bundle = await readFile(join(outDir, "index.js"), "utf8")
      // The sandbox evaluates a script and has no module loader, so a bundle
      // that kept an `import` is one that loads and then does nothing. The
      // preset is what prevents it; this is the assertion that the sample
      // actually went through the preset.
      assert.doesNotMatch(bundle, /^import\s/m, `${name} built with imports left in it`)
    })
  }
})
