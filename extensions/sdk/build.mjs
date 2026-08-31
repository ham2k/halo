// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Builds the publishable `@ham2k/extension-sdk` from `src/`.
//
// Nothing else in this repo needs this: every extension here reaches the SDK
// through a tsconfig path alias straight at `src/index.ts`, and esbuild
// compiles the TypeScript on the way past. This exists only so that someone
// with none of this repo can install the same thing from npm.

import { build } from 'esbuild'
import { execFile } from 'node:child_process'
import { cp, mkdir, readFile, readdir, rm, writeFile } from 'node:fs/promises'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { promisify } from 'node:util'

import { sharedPackages } from '../build-config.mjs'

const run = promisify(execFile)
const here = dirname(fileURLToPath(import.meta.url))
const src = join(here, 'src')
const dist = join(here, 'dist')
const entry = join(src, 'index.ts')

await rm(dist, { recursive: true, force: true })
await mkdir(dist, { recursive: true })

/// Every module the package ships: the SDK's own sources, minus its tests and
/// minus the kernel.
///
/// `kernel.ts` sits in this directory and must never leave it. It IS the host —
/// it defines `globalThis.__polo` and holds the one instance of every shared
/// library that extensions look up. Nothing in the barrel imports it, so a
/// bundled build would drop it silently; naming the entry points explicitly is
/// what keeps that true when someone adds an import.
async function shippedModules() {
  const names = await readdir(src)
  return names
    .filter((name) => name.endsWith('.ts') && !name.endsWith('.test.ts') && name !== 'kernel.ts')
    .map((name) => join(src, name))
}

// Transpiled module BY MODULE, not bundled into one file, and this is the
// whole reason the build is shaped this way. Rolled into a single file, the
// author's bundler can no longer tell which parts their extension reaches:
// Hello World came out 5x larger, carrying the ADIF importer and the export
// machinery it cannot call. Shipping the module graph intact lets their
// tree-shaking work exactly as it does for the extensions built in this repo.
//
// The shared libraries stay as BARE SPECIFIERS for the same family of reason.
// An author's build rewrites each one their manifest declares into a lookup on
// the host's single instance — but `sharedModulesPlugin` can only rewrite an
// import it can SEE. Resolved here, they would be gone before it ran, and
// every extension would go back to carrying private copies (HALO-442).
await build({
  entryPoints: await shippedModules(),
  outdir: dist,
  bundle: false,
  format: 'esm',
  platform: 'neutral',
  target: 'es2020',
  logLevel: 'warning',
})

// esbuild leaves import specifiers alone when it is not bundling, and these
// sources import each other by explicit `.ts` path — which is why the repo's
// tsconfig carries `allowImportingTsExtensions`. Left as they are, every
// import in the published package would point at a file that isn't there.
for (const name of await readdir(dist)) {
  if (!name.endsWith('.js')) continue
  const file = join(dist, name)
  const code = await readFile(file, 'utf8')
  await writeFile(file, code.replace(/(from\s*["']\.[^"']*)\.ts(["'])/g, '$1.js$2'))
}

// Imported with `with { type: "json" }` and left as imports by the transpile
// above, so the files themselves have to travel.
await cp(join(src, 'i18n'), join(dist, 'i18n'), { recursive: true })

// The two properties that make this package worth installing, asserted rather
// than trusted, because breaking either produces a package that WORKS and is
// silently wrong — no error anywhere, just every extension built against it
// paying for it.
const emitted = (await readdir(dist)).filter((name) => name.endsWith('.js'))
const modules = Object.fromEntries(
  await Promise.all(emitted.map(async (name) => [name, await readFile(join(dist, name), 'utf8')])))

// Bundling this into one file would cost the author roughly five times the
// bundle size: their tree-shaking can no longer tell which parts their
// extension reaches, so Hello World ships the ADIF importer it cannot call.
//
// It also guards the shared libraries by proxy. Only a BUNDLING build can
// resolve them away from `sharedModulesPlugin`, and every bundling shape
// either collapses to one file — caught here — or esbuild refuses outright.
if (emitted.length < 2) {
  throw new Error(
    `dist/ holds ${emitted.length} module(s) — the SDK was bundled into one file, ` +
    "which defeats the author's tree-shaking")
}

// The kernel IS the host. Published, it would hand every extension author the
// code that defines `globalThis.__polo` and holds the single instance of every
// shared library.
const kernelMarkers = Object.entries(modules).filter(([, code]) => code.includes('__polo ='))
if (kernelMarkers.length) {
  throw new Error(`dist/${kernelMarkers[0][0]} defines the kernel — that belongs to the host, not the SDK`)
}

// `tsc` cannot emit the JS above either: TypeScript allows
// `allowImportingTsExtensions` only alongside `noEmit` or
// `emitDeclarationOnly`. Types are all that is wanted from it here.
//
// Rolled into ONE declaration with the types borrowed from
// `@ham2k/lib-qson-tools` and friends inlined, so installing the SDK installs
// everything needed to typecheck against it. Those packages are optional peers
// precisely so that nothing has to fetch ten of them to get `CallInfo`.
const dts = join(dist, 'index.d.ts')
await run('npx', [
  'dts-bundle-generator',
  '--out-file', dts,
  '--no-banner',
  // Every shared library is a candidate for inlining rather than importing.
  // Only the ones the SDK's surface actually names reach the output, so listing
  // all twelve costs nothing and means a new type reference cannot quietly
  // start leaking an import the guard below would then reject.
  '--external-inlines', ...sharedPackages,
  '--project', join(here, '../tsconfig.json'),
  '--',
  entry,
], { cwd: here })

const declared = await readFile(dts, 'utf8')
// A declaration still pointing at a package the author was told they need not
// install types out to `any` in their editor, silently — the one outcome
// bundling the types exists to prevent.
const leaked = sharedPackages.filter((pkg) => declared.includes(`from '${pkg}'`) || declared.includes(`from "${pkg}"`))
if (leaked.length) {
  throw new Error(
    `dist/index.d.ts still imports from ${leaked.join(', ')} — those types did not get inlined, ` +
    'so an author who installs only the SDK loses them')
}

const { version } = JSON.parse(await readFile(join(here, 'package.json'), 'utf8'))
await writeFile(dts, `// @ham2k/extension-sdk ${version}\n${declared}`)

const shipped = (await readdir(dist)).filter((n) => n.endsWith('.js')).length
console.log(`built @ham2k/extension-sdk ${version} — ${shipped} modules + rolled-up types`)
