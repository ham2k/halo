// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The `.h2kext` packer (HALO-422). What it accepts, and — mostly — what it
// refuses, because every check here exists to stop a bundle that would install
// cleanly and then misbehave inside somebody else's app, where the author
// cannot see it.

import { test } from "node:test"
import assert from "node:assert/strict"
import { mkdtemp, mkdir, writeFile, readFile } from "node:fs/promises"
import { tmpdir } from "node:os"
import { join } from "node:path"

// @ts-ignore — deliberately plain JS: this module is meant to be lifted into a
// published package unchanged, so it carries no TypeScript build of its own.
import { sharedPackages } from "../build-config.mjs"
import {
  H2KEXT_API_VERSION,
  sharedModulesFor,
  findSharedModuleReferences,
  keyProblem,
  pack,
  PackError,
  RESERVED_PREFIX,
  validateManifest,
} from "./h2kext.mjs"

const validManifest = {
  key: "w7abc-notes",
  name: "W7ABC Notes",
  version: "1.2.3",
  description: "Notes about the stations I work",
  category: "dashboard",
  api: H2KEXT_API_VERSION,
}

async function bundleDir(overrides: Record<string, unknown> = {}, source = "(() => {})()") {
  const dir = await mkdtemp(join(tmpdir(), "h2kext-test-"))
  const manifest = { ...validManifest, ...overrides }
  for (const [key, value] of Object.entries(overrides)) {
    if (value === undefined) delete (manifest as Record<string, unknown>)[key]
  }
  await writeFile(join(dir, "manifest.json"), JSON.stringify(manifest))
  await writeFile(join(dir, "index.js"), source)
  return dir
}

test("a complete bundle packages, and the file is a real zip", async () => {
  const dir = await bundleDir()
  await mkdir(join(dir, "assets"))
  await writeFile(join(dir, "assets", "note.txt"), "hello")

  const result = await pack(dir, { outPath: join(dir, "out.h2kext") })

  assert.equal(result.manifest.key, "w7abc-notes")
  // The local file header's signature. The app sniffs exactly this rather than
  // trusting the filename, because Android hands back a cache copy whose name
  // the platform rewrote from the MIME type.
  const head = await readFile(result.outPath)
  assert.deepEqual([...head.subarray(0, 4)], [0x50, 0x4b, 0x03, 0x04])
  assert.deepEqual(
    result.files.map((f: { entry: string }) => f.entry),
    ["manifest.json", "index.js", "assets/note.txt"],
  )
})

test("the default name carries the key and version, so two builds are distinguishable", async () => {
  const dir = await bundleDir()
  const result = await pack(dir, { outPath: join(dir, "w7abc-notes-1.2.3.h2kext") })
  assert.match(result.outPath, /w7abc-notes-1\.2\.3\.h2kext$/)
})

test("a bundle that externalises the host's shared modules is refused", async () => {
  // The subtle one, and the reason this check exists. A bundle built with this
  // build preset resolves @ham2k/lib-*, i18next and liquidjs
  // against whatever versions that checkout happened to have, at BUILD time.
  // A distributed bundle cannot: the host makes no promise about what it
  // carries. Left in, it loads happily and then dies at the first call into a
  // library that is absent or a different major — in someone else's app, far
  // from anything the author can see.
  const dir = await bundleDir({}, 'var x = globalThis.__polo.sharedModules["@ham2k/lib-callsigns"];')

  await assert.rejects(() => pack(dir, { outPath: join(dir, "out.h2kext") }), (e: Error) => {
    assert.ok(e instanceof PackError)
    assert.match(e.message, /shared modules/)
    assert.match(e.message, /@ham2k\/lib-callsigns/)
    return true
  })
})

test("findSharedModuleReferences names every library, once each", () => {
  const hits = findSharedModuleReferences(`
    a = globalThis.__polo.sharedModules["i18next"]
    b = __polo.sharedModules['liquidjs']
    c = __polo . sharedModules [ "i18next" ]
  `)
  assert.deepEqual(hits.sort(), ["i18next", "liquidjs"])
})

test("a bundle with no category is refused", () => {
  // No category means CORE to the host: always enabled, never listed in the
  // Extensions panel. That is a status the app grants its own extensions — a
  // distributed bundle claiming it would be one the user can neither see nor
  // turn off.
  const problems = validateManifest({ ...validManifest, category: undefined })
  assert.equal(problems.length, 1)
  assert.match(problems[0], /core: always on, and invisible/)
})

test("a bundle gating on an experiment is refused", () => {
  // `experiments` is checked against the APP's catalog. A key the host does
  // not define hides the extension permanently, with nothing in the UI to say
  // why — which is a bug we already have a card for on our own extensions.
  const problems = validateManifest({ ...validManifest, experiments: ["panels"] })
  assert.equal(problems.length, 1)
  assert.match(problems[0], /hide this extension permanently/)
})

test("a callsign starting with a digit is still a callsign", () => {
  // 2E0ABC, 9A1AA, 4X4XYZ. A safe-key pattern demanding a leading letter locks
  // out every UK Foundation licensee and a good deal of the rest of the world.
  assert.equal(keyProblem("2e0abc-thing"), null)
  assert.equal(keyProblem("9a1aa-logger"), null)
})

test("a key must be <callsign>-<name>", () => {
  // The callsign is a namespace every author of this software already holds,
  // globally unique and free — which is what stops two people who never met
  // from shipping the same key.
  for (const key of ["ki2d-my-clock", "w7abc-notes", "2e0abc-thing", "vk3xyz-a-longer-name"]) {
    assert.equal(keyProblem(key), null, `expected '${key}' to be accepted`)
  }
})

test("a key without a real callsign prefix is refused", () => {
  for (const key of ["my-clock", "notacall-x", "cool-extension"]) {
    assert.match(keyProblem(key)!, /must start with your callsign/, `expected '${key}' to be refused`)
  }
})

test("a bare key with no prefix at all is refused", () => {
  // The shape our own built-ins use ('pota', 'sota'). They are ours and they
  // are reserved; a distributed bundle claiming one would collide with the
  // app's own hooks, and with the key prefix that governs secret visibility.
  for (const key of ["pota", "notes"]) {
    assert.match(keyProblem(key)!, /must be '<callsign>-<name>'/, `expected '${key}' to be refused`)
  }
})

test(`the '${RESERVED_PREFIX}-' prefix is refused`, () => {
  // There is no signing yet, so anyone could claim it — and the key is what
  // the app shows when it says where a hook came from. Refusing it by default
  // is the only thing standing between a sideloaded bundle and looking
  // official.
  assert.match(keyProblem("ham2k-lofi")!, /reserved for Ham2K/)
})

test("--force-name waives the convention, for the builds that ship inside the app", () => {
  // Ham2K's own extensions carry exactly the two shapes the convention
  // refuses: bare keys, and the reserved prefix.
  for (const key of ["pota", "arrl-dx", "ham2k-lofi"]) {
    assert.equal(keyProblem(key, { forceName: true }), null, `expected '${key}' to pass with --force-name`)
  }
})

test("--force-name does NOT waive what the runtime needs", () => {
  // The key namespaces KV storage, scopes secrets, and identifies hooks.
  // Uppercase or a space there is not a convention being broken, it is a key
  // the runtime cannot carry — so no flag lets it through.
  for (const key of ["KI2D-x", "ki2d_x", "ki2d-My-Clock", "has space"]) {
    assert.ok(keyProblem(key, { forceName: true }) !== null, `expected '${key}' to be refused even forced`)
    assert.ok(keyProblem(key) !== null, `expected '${key}' to be refused`)
  }
})

test("validateManifest carries the waiver through", () => {
  assert.match(validateManifest({ ...validManifest, key: "ham2k-x" }).join(), /reserved for Ham2K/)
  assert.equal(validateManifest({ ...validManifest, key: "ham2k-x" }, { forceName: true }).length, 0)
})

test("a missing or future api version is refused", () => {
  assert.match(validateManifest({ ...validManifest, api: undefined }).join(), /missing 'api'/)
  assert.match(validateManifest({ ...validManifest, api: H2KEXT_API_VERSION + 1 }).join(), /only knows/)
  assert.match(validateManifest({ ...validManifest, api: "1" }).join(), /must be an integer/)
})

test("every problem is reported at once", async () => {
  // An author who fixes one problem per run is an author running this five
  // times to find out what is wrong with one file.
  const problems = validateManifest({ key: "Bad Key!", version: "1.0" })
  assert.ok(problems.length >= 4, `expected several problems, got ${problems.length}: ${problems.join(" | ")}`)
})

test("an unbuilt directory says so, rather than producing an empty bundle", async () => {
  const dir = await mkdtemp(join(tmpdir(), "h2kext-test-"))
  await writeFile(join(dir, "manifest.json"), JSON.stringify(validManifest))

  await assert.rejects(() => pack(dir, { outPath: join(dir, "out.h2kext") }), (e: Error) => {
    // The packer packages; it does not compile. Saying that here is what stops
    // an author waiting for a build that is never going to happen.
    assert.match(e.message, /this packages, it does not compile/)
    return true
  })
})

test("manifest.json that is not JSON says which file and why", async () => {
  const dir = await mkdtemp(join(tmpdir(), "h2kext-test-"))
  await writeFile(join(dir, "manifest.json"), "{ not json")
  await writeFile(join(dir, "index.js"), "(() => {})()")

  await assert.rejects(() => pack(dir, { outPath: join(dir, "out.h2kext") }), (e: Error) => {
    assert.match(e.message, /manifest\.json is not valid JSON/)
    return true
  })
})

test("the packer's shared-module list matches what the build actually externalises", () => {
  // h2kext.mjs duplicates this list rather than importing it, because it has to
  // work with none of this repo present — it is meant to be published on its
  // own. This is the only place that duplication can be checked, and without
  // it the two drift the first time a library is added: the packer refuses a
  // declaration the host would happily satisfy, or accepts one it cannot.
  assert.deepEqual([...sharedModulesFor(H2KEXT_API_VERSION)].sort(), [...sharedPackages].sort())
})

test("using a shared module without declaring it is refused", async () => {
  const dir = await bundleDir({}, 'var x = __polo.sharedModules["i18next"];')

  await assert.rejects(() => pack(dir, { outPath: join(dir, "out.h2kext") }), (e: Error) => {
    // Undeclared is the dangerous case: the host carries whatever version that
    // build shipped with, so an undeclared use loads happily and dies at the
    // first call into a library that turned out to be a different major.
    assert.match(e.message, /without declaring them \(i18next\)/)
    assert.match(e.message, /sharedDependencies/)
    return true
  })
})

test("declaring a shared module makes using it fine", async () => {
  const dir = await bundleDir(
    { sharedDependencies: { i18next: "^23.0.0" } },
    'var x = __polo.sharedModules["i18next"];',
  )

  // The point of the whole mechanism: a bundle that says what it needs may use
  // the host's copy, and skips carrying ~1.4MB of its own.
  const result = await pack(dir, { outPath: join(dir, "out.h2kext") })
  assert.equal(result.manifest.sharedDependencies.i18next, "^23.0.0")
})

test("declaring a package the host does not carry is refused", () => {
  const problems = validateManifest({ ...validManifest, sharedDependencies: { lodash: "^4.0.0" } })
  assert.match(problems.join(), /the host does not carry/)
})

test("a shared dependency needs a range, not just a name", () => {
  assert.match(validateManifest({ ...validManifest, sharedDependencies: { i18next: "" } }).join(), /needs a version range/)
  assert.match(validateManifest({ ...validManifest, sharedDependencies: ["i18next"] }).join(), /must be an object/)
})
