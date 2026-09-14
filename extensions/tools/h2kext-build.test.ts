// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// The extension build preset (HALO-442).
//
// What matters here is which libraries end up INSIDE the bundle and which are
// left to the host, because both wrong answers are quiet: an undeclared shared
// import ships a second copy of a library the kernel already holds — thirty
// times the size, and its own module state — while a lookup the manifest never
// declared loads happily and dies at the first call, in someone else's app.

import { test } from "node:test"
import assert from "node:assert/strict"
import { build } from "esbuild"
import { mkdtemp, writeFile, readFile, mkdir, symlink } from "node:fs/promises"
import { tmpdir } from "node:os"
import { join, isAbsolute, relative as relativePath } from "node:path"

// @ts-ignore — deliberately plain JS, like the packer it sits beside: both are
// meant to be lifted into a published package unchanged.
import { buildExtension, sharedModulesPlugin } from "./h2kext-build.mjs"
// @ts-ignore
import { findSharedModuleReferences, H2KEXT_API_VERSION } from "./h2kext.mjs"

/// Bundles [source] with the plugin, returning the built text — or throwing
/// whatever esbuild threw.
async function bundleWith(source: string, pluginOptions: Record<string, unknown> = {}) {
  const dir = await mkdtemp(join(tmpdir(), "h2kext-build-test-"))
  await writeFile(join(dir, "entry.js"), source)
  // A stand-in for the real package, so a build that DOESN'T externalise has
  // something to inline and the two outcomes are distinguishable.
  await mkdir(join(dir, "node_modules/i18next"), { recursive: true })
  await writeFile(
    join(dir, "node_modules/i18next/package.json"),
    JSON.stringify({ name: "i18next", version: "23.0.0", main: "index.js" }))
  await writeFile(join(dir, "node_modules/i18next/index.js"), "module.exports = { INLINED_COPY: true }")

  const result = await build({
    entryPoints: [join(dir, "entry.js")],
    bundle: true,
    format: "iife",
    platform: "neutral",
    write: false,
    logLevel: "silent",
    plugins: [sharedModulesPlugin(pluginOptions)],
  })
  return result.outputFiles[0].text
}

test("a declared library is taken from the host rather than bundled", async () => {
  const out = await bundleWith(
    'import i18next from "i18next"; globalThis.x = i18next',
    { sharedDependencies: { i18next: "^23.0.0" } })

  assert.deepEqual(findSharedModuleReferences(out), ["i18next"])
  // The mutation this guards: a plugin that resolves the name but forgets to
  // replace the CONTENTS externalises nothing and silently ships the copy.
  assert.ok(!out.includes("INLINED_COPY"), "the local copy was bundled anyway")
})

test("using a library the host carries without declaring it fails the build", async () => {
  // Not a style rule. Undeclared, the app cannot check at install that the
  // version it holds is one this bundle works with — so it loads, and then
  // dies at the first call into a different major.
  await assert.rejects(
    () => bundleWith('import i18next from "i18next"; globalThis.x = i18next'),
    (e: Error) => {
      assert.match(e.message, /does not declare it/)
      assert.match(e.message, /sharedDependencies/)
      return true
    })
})

test("inline says the second copy is deliberate, and produces one", async () => {
  // The escape hatch has to actually work, or its own error message is a lie:
  // shipping your own copy is how you use a version the host does not carry.
  const out = await bundleWith(
    'import i18next from "i18next"; globalThis.x = i18next',
    { inline: ["i18next"] })

  assert.ok(out.includes("INLINED_COPY"), "inline did not bundle the local copy")
  assert.deepEqual(findSharedModuleReferences(out), [])
})

test("a package the host does not carry is left alone", async () => {
  // The filter is built from package names carrying `/`, `-` and `@`. Treated
  // as a regex rather than escaped, `@ham2k/lib-callsigns` would also claim
  // names it merely resembles — and claiming one the host has no instance of
  // yields `sharedModules[...]` === undefined at runtime, not a build error.
  const out = await bundleWith(
    'import x from "i18next-extra"; globalThis.x = x',
    {
      sharedDependencies: { i18next: "^23.0.0" },
      // Everything else the API offers is undeclared, so a leaky filter would
      // fail this build rather than merely mis-resolve it.
      inline: [],
    })
    .then((text) => text, (e: Error) => e)

  // i18next-extra does not exist, so esbuild fails to RESOLVE it — the point
  // is that it fails as an unresolved import, not as one of ours.
  assert.ok(out instanceof Error)
  assert.match(out.message, /Could not resolve/)
  assert.doesNotMatch(out.message, /does not declare it/)
})

test("buildExtension leaves the manifest beside the bundle it was built from", async () => {
  const dir = await mkdtemp(join(tmpdir(), "h2kext-build-ext-"))
  await mkdir(join(dir, "src"), { recursive: true })
  await writeFile(join(dir, "src/index.ts"), "globalThis.hello = 'world'")
  const manifest = { key: "w7abc-notes", api: H2KEXT_API_VERSION, sharedDependencies: {} }
  await writeFile(join(dir, "manifest.json"), JSON.stringify(manifest))

  const { outDir } = await buildExtension(build, { dir })

  // The packer reads both out of one directory. A manifest left behind is a
  // declared dependency list that no longer describes the code beside it.
  assert.ok((await readFile(join(outDir, "index.js"), "utf8")).includes("hello"))
  assert.deepEqual(JSON.parse(await readFile(join(outDir, "manifest.json"), "utf8")), manifest)
})

test("liquidjs resolves to its browser build, so an extension that inlines it can compile", async () => {
  // HALO-443: liquidjs's `main`/`module` are its NODE builds, and
  // `platform: 'neutral'` ignores the `browser` field that would pick the
  // other one — so without the preset's alias this fails to resolve fs, path,
  // stream, module and crypto before compiling anything. It fails at RESOLVE
  // time, which is why tree-shaking cannot save an extension that never
  // renders a template.
  const dir = await mkdtemp(join(tmpdir(), "h2kext-build-liquid-"))
  await mkdir(join(dir, "src"), { recursive: true })
  await writeFile(join(dir, "src/index.ts"), 'import { Liquid } from "liquidjs"; globalThis.x = new Liquid()')
  await writeFile(join(dir, "manifest.json"), JSON.stringify({ key: "w7abc-t", api: H2KEXT_API_VERSION }))

  // The alias is resolved from the EXTENSION's directory, not this repo's,
  // because the author's copy is the one that has to be found. So the author's
  // situation is what the test has to build: liquidjs in their own
  // node_modules, linked here to the only copy a test can rely on existing.
  await mkdir(join(dir, "node_modules"), { recursive: true })
  await symlink(join(import.meta.dirname, "../node_modules/liquidjs"), join(dir, "node_modules/liquidjs"))

  const { outDir } = await buildExtension(build, { dir, inline: ["liquidjs"] })

  const out = await readFile(join(outDir, "index.js"), "utf8")
  // Compiling at all IS the assertion — the bug is a RESOLVE failure, so
  // without the alias buildExtension throws and never reaches this line. The
  // rest guards the other direction: an alias pointing back at the node build
  // would compile here and die in a runtime with no `fs`.
  assert.ok(out.includes("Liquid"), "liquidjs was not bundled")
  assert.doesNotMatch(out, /require\(["']fs["']\)|from ?["']node:fs["']/)
})

test("declaring a library the host does not carry is refused, not externalised", async () => {
  // Externalising it would emit `sharedModules["lodash"]` — `undefined` at the
  // first call. The build succeeds and the bundle cannot work, which is the
  // one outcome worse than a build error.
  assert.throws(
    () => sharedModulesPlugin({ sharedDependencies: { lodash: "^4.0.0" } }),
    /does not carry \(lodash\)/)
})

test("declaring a library and also inlining it is refused", async () => {
  // The two statements contradict, and the resolvers are registered in an
  // order that silently settles it — declared wins, so an author who added
  // `inline` precisely because the host's version was wrong for them would
  // get the host's copy anyway.
  assert.throws(
    () => sharedModulesPlugin({ sharedDependencies: { i18next: "^23.0.0" }, inline: ["i18next"] }),
    /both sharedDependencies and inline/)
})

test("a relative dir still finds liquidjs, rather than silently dropping the alias", async () => {
  // createRequire rejects a relative path outright. Caught and treated as
  // "liquidjs isn't installed", that loses the alias and reproduces HALO-443
  // in full — five unresolvable node built-ins, and nothing naming the cause.
  const dir = await mkdtemp(join(tmpdir(), "h2kext-build-rel-"))
  await mkdir(join(dir, "src"), { recursive: true })
  await mkdir(join(dir, "node_modules"), { recursive: true })
  await symlink(join(import.meta.dirname, "../node_modules/liquidjs"), join(dir, "node_modules/liquidjs"))
  await writeFile(join(dir, "src/index.ts"), 'import { Liquid } from "liquidjs"; globalThis.x = new Liquid()')
  await writeFile(join(dir, "manifest.json"), JSON.stringify({ key: "w7abc-t", api: H2KEXT_API_VERSION }))

  const relative = relativePath(process.cwd(), dir)
  assert.ok(!isAbsolute(relative), "the test needs a relative path to be testing anything")

  const { outDir } = await buildExtension(build, { dir: relative, inline: ["liquidjs"] })
  assert.ok((await readFile(join(outDir, "index.js"), "utf8")).includes("Liquid"))
})

test("a liquidjs that cannot be resolved fails loudly instead of losing the alias", async () => {
  // `require.resolve('liquidjs/package.json')` is how the package root is
  // found, and it stops working the day liquidjs publishes an `exports` map
  // that does not list ./package.json — which is a normal thing for a package
  // to do. Treated as "not installed", that silently drops the alias and hands
  // the author HALO-443's five unresolvable node built-ins, with nothing
  // naming liquidjs as the cause. Loud and wrong beats quiet and wrong.
  const dir = await mkdtemp(join(tmpdir(), "h2kext-build-exports-"))
  await mkdir(join(dir, "src"), { recursive: true })
  await mkdir(join(dir, "node_modules/liquidjs"), { recursive: true })
  await writeFile(
    join(dir, "node_modules/liquidjs/package.json"),
    JSON.stringify({ name: "liquidjs", version: "10.0.0", exports: { ".": "./main.js" } }))
  await writeFile(join(dir, "node_modules/liquidjs/main.js"), "module.exports = {}")
  await writeFile(join(dir, "src/index.ts"), "globalThis.x = 1")
  await writeFile(join(dir, "manifest.json"), JSON.stringify({ key: "w7abc-t", api: H2KEXT_API_VERSION }))

  await assert.rejects(
    () => buildExtension(build, { dir, inline: ["liquidjs"] }),
    /ERR_PACKAGE_PATH_NOT_EXPORTED|is not defined by "exports"/)
})
