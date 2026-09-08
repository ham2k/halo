// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Building an extension: the esbuild settings a Ham2K bundle needs, and the
// plugin that takes the host up on the libraries it carries (HALO-442,
// docs/extensions/development.md).
//
// Standalone in the same way h2kext.mjs is, and for the same reason — that
// module is its only import, because its whole purpose is to work for someone
// with none of this repo. esbuild it does NOT import: the caller passes their
// own `build` in, so an author's toolchain and this preset cannot end up
// running two copies of it.
//
// Ships beside the packer, in `@ham2k/extension-tools`, because both read the
// FORMAT — the API version, the manifest's entry names, the list of libraries
// the host carries. Neither depends on the SDK an extension imports, so the
// runtime package stays free of any build-time surface.
//
// The repo's own build uses it too, on the same terms, which is what keeps the
// path a third party takes from being the untested one.

import { readFileSync } from 'node:fs'
import { copyFile, mkdir, readFile } from 'node:fs/promises'
import { createRequire } from 'node:module'
import { dirname, join, resolve } from 'node:path'

import { H2KEXT_API_VERSION, MANIFEST_ENTRY, sharedModulesFor } from './h2kext.mjs'

/// What an extension's own `build.mjs` says, for everything that has to write
/// one: `h2kext-init`'s scaffold, and the samples the SDK ships.
///
/// Here rather than in either of them because two copies of a file whose whole
/// job is to be correct on someone else's machine would drift, and neither
/// copy is exercised by this repo's own build — the extensions here are built
/// through `build-config.mjs`, which takes a different path into the same
/// preset.
export const EXAMPLE_BUILD_SCRIPT = `import { build } from 'esbuild'
import { buildExtension } from '@ham2k/extension-tools'

await buildExtension(build, { dir: import.meta.dirname })

console.log('built build/index.js')
`

export class BuildError extends Error {}

/// Rewrites imports of the libraries the host carries into lookups on the
/// kernel's single instance, so a bundle need not ship its own copy.
///
/// Only what the manifest DECLARES is rewritten. Declaring is what lets the
/// host check, before it loads anything, that the version it holds is one the
/// bundle can work with — an undeclared lookup is a bundle that loads happily
/// and then dies at the first call into a library that turned out to be a
/// different major, in someone else's app, far from the cause.
///
/// So using an offered library without declaring it FAILS the build rather
/// than quietly inlining a private copy. Inlining is a legitimate choice — it
/// is how you use a version the host does not carry — and [inline] is how to
/// make it, but it is a choice worth stating, because the silent version costs
/// roughly thirty times the bundle size and nothing anywhere says so.
/// The version of a shared package as installed beside the extension being
/// built, for the range the "you must declare this" error suggests.
///
/// Suggesting a floor is not cosmetic. The host admits a bundle by comparing
/// its declared range against the package version the host holds — it cannot
/// see which SYMBOLS that version has. A package that grew an export (the
/// Cabrillo writer arrived in `@ham2k/lib-qson-cabrillo` 1.2.0) therefore
/// satisfies a `^1.0.0` declaration on a host too old to have the function,
/// and the extension installs, loads, and throws the first time an operator
/// asks for that feature. Suggesting the version the author is actually
/// building against makes the honest declaration the easy one.
///
/// Null when the package is not resolvable from there, which leaves the
/// caller its own fallback — a missing suggestion is worth far less than a
/// failed build.
function installedVersionOf(pkg, fromDir) {
  try {
    const require = createRequire(resolve(fromDir, 'noop.js'))
    // Walked up from the entry point rather than resolved directly: a package
    // with an `exports` map that does not list `./package.json` — which is
    // most of them, `@ham2k/lib-qson-cabrillo` included — refuses that path
    // outright, and asking for it is how this silently answers 1.0.0 for
    // every package.
    let dir = dirname(require.resolve(pkg))
    for (let up = 0; up < 6; up += 1) {
      try {
        const manifest = JSON.parse(readFileSync(join(dir, 'package.json'), 'utf8'))
        if (manifest.name === pkg) return manifest.version ?? null
      } catch {
        // Not this directory's package.json, or not readable — keep climbing.
      }
      const parent = dirname(dir)
      if (parent === dir) break
      dir = parent
    }
    return null
  } catch {
    return null
  }
}

export function sharedModulesPlugin({ sharedDependencies = {}, api = H2KEXT_API_VERSION, inline = [] } = {}) {
  const offered = sharedModulesFor(api)
  const declared = Object.keys(sharedDependencies)

  // Refused rather than ignored. Externalizing a name the host has no instance
  // of emits `sharedModules["lodash"]`, which is `undefined` at the first call
  // — a build that succeeded and a bundle that cannot work.
  const notOffered = declared.filter((pkg) => !offered.includes(pkg))
  if (notOffered.length) {
    throw new BuildError(
      `${MANIFEST_ENTRY} declares sharedDependencies the host does not carry (${notOffered.join(', ')}). ` +
      'Bundle those into your build instead — only what the host offers can be shared.')
  }

  // The two say opposite things about the same package, so neither can be
  // honoured silently: whichever won, the other statement would be a lie.
  const both = declared.filter((pkg) => inline.includes(pkg))
  if (both.length) {
    throw new BuildError(
      `${both.join(', ')} appears in both sharedDependencies and inline. ` +
      "Declare it to use the host's copy, or inline it to ship your own — not both.")
  }

  const undeclared = offered.filter((pkg) => !declared.includes(pkg) && !inline.includes(pkg))

  return {
    name: 'ham2k-shared-modules',
    setup(build) {
      if (declared.length) {
        build.onResolve({ filter: matcherFor(declared) }, (args) => ({
          path: args.path,
          namespace: 'ham2k-shared-module',
        }))
      }

      // A separate resolver rather than one branch inside the first: esbuild
      // consults filters in order, and a plugin that resolved a package only
      // to return null would hand it back to the very resolution this exists
      // to intercept.
      if (undeclared.length) {
        build.onResolve({ filter: matcherFor(undeclared) }, (args) => ({
          // The fix goes in `text`, not in a `notes` entry: a note reaches
          // esbuild's pretty printer and nothing else, so a build script that
          // catches the error — or runs at logLevel 'silent' — shows the
          // author the complaint with the answer stripped off.
          errors: [{
            text: `'${args.path}' is carried by the Ham2K extension host, but this bundle does not declare it. ` +
              `Add it to "sharedDependencies" in ${MANIFEST_ENTRY} with the version range you work with ` +
              `(e.g. {${JSON.stringify(args.path)}: "^${installedVersionOf(args.path, args.resolveDir) ?? '1.0.0'}"}), ` +
              `or pass inline: [${JSON.stringify(args.path)}] ` +
              'to ship your own copy — which is how you use a version the host does not carry.',
          }],
        }))
      }

      build.onLoad({ filter: /.*/, namespace: 'ham2k-shared-module' }, (args) => ({
        contents: `module.exports = globalThis.__polo.sharedModules[${JSON.stringify(args.path)}];`,
        loader: 'js',
      }))
    },
  }
}

/// An esbuild filter matching exactly [packages] and nothing else. Package
/// names carry regex metacharacters (`@ham2k/lib-qson-adif` has a slash, and a
/// dot would be a wildcard), so every one is escaped.
function matcherFor(packages) {
  const alternatives = packages.map((pkg) => pkg.replace(/[.*+?^${}()|[\]\\/]/g, '\\$&')).join('|')
  return new RegExp(`^(${alternatives})$`)
}

/// Where liquidjs's BROWSER build lives, or null if liquidjs is not installed.
///
/// Every author who inlines liquidjs hits this: its `main`/`module` are the
/// NODE builds, which import fs, path and stream, and `platform: 'neutral'`
/// ignores the `browser` field that would have picked the right one. Without
/// the alias the build fails on unresolvable node built-ins before tree-shaking
/// gets a chance to drop the half that wanted them (HALO-443).
///
/// Resolved from the CALLER's directory, not this file's — the point is to find
/// the author's copy.
function liquidBrowserBuild(fromDir) {
  try {
    // `resolve` because createRequire rejects a relative path outright, and
    // `dir` is the caller's to pass — a relative one lands in the catch below
    // and loses the alias, which is precisely the failure this function exists
    // to prevent, arriving with nothing to point at the cause.
    const require = createRequire(resolve(fromDir, 'noop.js'))
    return join(dirname(require.resolve('liquidjs/package.json')), 'dist/liquid.browser.mjs')
  } catch (e) {
    // Not installed is the normal case for an extension that neither inlines
    // liquidjs nor uses it, and there is nothing to alias. Anything else is a
    // real fault, and swallowing it would hand the author five unresolvable
    // node built-ins instead.
    if (e.code === 'MODULE_NOT_FOUND') return null
    throw e
  }
}

/// The esbuild options a Ham2K extension bundle is built with.
///
/// Everything here is a requirement of the runtime rather than a preference:
/// one IIFE because the sandbox evaluates a script and has no module loader;
/// `platform: 'neutral'` because there is no node and no DOM; es2020 because
/// that is what QuickJS-NG speaks.
export function buildOptionsFor({ entry, outfile, manifest = {}, dir = process.cwd(), alias = {}, inline = [], ...rest } = {}) {
  const liquid = liquidBrowserBuild(dir)
  return {
    entryPoints: [entry],
    ...(outfile ? { outfile } : { write: false }),
    bundle: true,
    format: 'iife',
    platform: 'neutral',
    mainFields: ['module', 'main'],
    target: 'es2020',
    logLevel: 'warning',
    ...rest,
    alias: {
      ...(liquid ? { liquidjs: liquid } : {}),
      ...alias,
    },
    plugins: [
      sharedModulesPlugin({ sharedDependencies: manifest.sharedDependencies, api: manifest.api, inline }),
      ...(rest.plugins ?? []),
    ],
  }
}

/// Builds one extension directory into something `h2kext-pack` can package:
/// a `manifest.json` and an `index.js`, side by side.
///
///   import { build } from 'esbuild'
///   import { buildExtension } from '@ham2k/extension-tools'
///   await buildExtension(build, { dir: import.meta.dirname })
///
/// [esbuild] is the caller's `build` function, passed in rather than imported
/// so this module needs no copy of its own.
export async function buildExtension(esbuild, { dir, entry = 'src/index.ts', outDir = 'build', ...rest } = {}) {
  if (!dir) throw new BuildError('buildExtension needs `dir`: the extension directory holding manifest.json')

  let manifest
  try {
    manifest = JSON.parse(await readFile(join(dir, MANIFEST_ENTRY), 'utf8'))
  } catch (e) {
    throw new BuildError(`could not read ${join(dir, MANIFEST_ENTRY)}: ${e.message}`)
  }

  const out = join(dir, outDir)
  await mkdir(out, { recursive: true })

  await esbuild(buildOptionsFor({
    entry: join(dir, entry),
    outfile: join(out, 'index.js'),
    manifest,
    dir,
    ...rest,
  }))

  // The packer reads both from one directory, so the manifest the bundle was
  // built against is the manifest that ships with it. Copied rather than left
  // for the author to remember: a stale manifest beside a fresh bundle is a
  // declared dependency list that no longer describes the code.
  await copyFile(join(dir, MANIFEST_ENTRY), join(out, MANIFEST_ENTRY))

  return { outDir: out, manifest }
}
