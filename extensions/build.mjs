// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Bundles the kernel and every extension into single-file IIFE bundles for the
// QuickJS runtime, and writes an index.json the Dart host uses to know what
// to load. Output goes into the Flutter app's assets.

import { build } from 'esbuild'
import { mkdir, writeFile, readFile } from 'node:fs/promises'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import semver from 'semver'

const root = dirname(fileURLToPath(import.meta.url))
const outDir = resolve(root, '../app/assets/extensions')

const sharedPackages = [
  "@ham2k/lib-callsigns",
  "@ham2k/lib-country-files",
  "@ham2k/lib-cqmag-data",
  "@ham2k/lib-dxcc-data",
  "@ham2k/lib-format-tools",
  "@ham2k/lib-geo-tools",
  "@ham2k/lib-operation-data",
  "@ham2k/lib-qson-adif",
  "@ham2k/lib-qson-cabrillo",
  "@ham2k/lib-qson-tools",
  "i18next",
]

// Resolve the versions of all shared libraries installed in local node_modules
const hostSharedVersions = {}
for (const pkg of sharedPackages) {
  const pkgJsonPath = join(root, 'node_modules', pkg, 'package.json')
  const pkgJson = JSON.parse(await readFile(pkgJsonPath, 'utf-8'))
  hostSharedVersions[pkg] = pkgJson.version
}

// Read the main package.json dependencies to get versions required by extensions
const rootPackageJson = JSON.parse(await readFile(join(root, 'package.json'), 'utf-8'))
const rootDeps = rootPackageJson.dependencies || {}

function sharedLibsPlugin(extensionDependencies = {}) {
  return {
    name: 'shared-libs',
    setup(build) {
      build.onResolve({ filter: /^(@ham2k\/lib-|i18next$)/ }, (args) => {
        const packageName = args.path
        // NOTE: today every extension shares the workspace-root package.json
        // (there are no per-extension manifests), so `extensionDependencies`
        // is always the root deps and this range check is effectively "the
        // host has it" — it can't currently catch a version mismatch because
        // there's only one declared version. The machinery stays for when
        // per-extension dependency ranges are introduced (the OTA-extension
        // story in DESIGN.md §3), at which point pass that extension's own
        // `dependencies` here instead of the root's.
        const requestedRange = extensionDependencies[packageName] || '*'
        const hostVersion = hostSharedVersions[packageName]

        // Externalize only if host has it and it satisfies the requested range
        if (hostVersion && semver.satisfies(hostVersion, requestedRange)) {
          return { path: packageName, namespace: 'shared-libs-external' }
        }

        // Version mismatch: let esbuild bundle it inline
        return null
      })

      build.onLoad({ filter: /.*/, namespace: 'shared-libs-external' }, (args) => {
        return {
          contents: `module.exports = globalThis.__polo.sharedModules["${args.path}"];`,
          loader: 'js',
        }
      })
    }
  }
}

// `domains` is each extension's declared network capability (DESIGN.md §3's
// manifest allowlist, in embryo): the Dart host refuses host.fetch calls to
// any host not listed. Entries are exact hostnames; '*.example.com' matches
// subdomains; a lone '*' means any https host (only ham2k-lofi, whose sync
// server is user-configurable). No entry (or []) means no network at all.
const bundles = [
  { key: 'kernel', entry: 'sdk/src/kernel.ts', kind: 'kernel' },
  { key: 'settings', entry: 'core/settings/src/index.ts', kind: 'extension' },
  { key: 'adif', entry: 'core/adif/src/index.ts', kind: 'extension' },
  { key: 'scoring', entry: 'core/scoring/src/index.ts', kind: 'extension' },
  { key: 'lookups', entry: 'core/lookups/src/index.ts', kind: 'extension' },
  { key: 'radio-commands', entry: 'core/radio-commands/src/index.ts', kind: 'extension' },
  { key: 'dev-commands', entry: 'core/dev-commands/src/index.ts', kind: 'extension' },
  { key: 'note-command', entry: 'core/note-command/src/index.ts', kind: 'extension' },
  { key: 'hamdb', entry: 'lookups/hamdb/src/index.ts', kind: 'extension', domains: ['api.hamdb.org'] },
  { key: 'qrz', entry: 'lookups/qrz/src/index.ts', kind: 'extension', domains: ['xmldata.qrz.com', 'logbook.qrz.com'] },
  { key: 'pota', entry: 'activities/pota/src/index.ts', kind: 'extension', domains: ['api.pota.app', 'pota.app'] },
  { key: 'sota', entry: 'activities/sota/src/index.ts', kind: 'extension', domains: ['api2.sota.org.uk'] },
  { key: 'ham2k-lofi', entry: 'sync/ham2k-lofi/src/index.ts', kind: 'extension', domains: ['*'] },
]

await mkdir(outDir, { recursive: true })

for (const bundle of bundles) {
  const isKernel = bundle.kind === 'kernel'
  const buildOptions = {
    entryPoints: [join(root, bundle.entry)],
    bundle: true,
    format: 'iife',
    platform: 'neutral',
    mainFields: ['module', 'main'],
    target: 'es2020',
    outfile: join(outDir, `${bundle.key}.js`),
    alias: { '@ham2k/polo-sdk': join(root, 'sdk/src/index.ts') },
    logLevel: 'warning',
    metafile: true,
  }

  if (isKernel) {
    buildOptions.define = {
      '__SHARED_VERSIONS__': JSON.stringify(hostSharedVersions)
    }
  } else {
    buildOptions.plugins = [sharedLibsPlugin(rootDeps)]
  }

  const result = await build(buildOptions)
  const bytes = Object.values(result.metafile.outputs)[0].bytes
  console.log(`${bundle.key}.js — ${(bytes / 1024).toFixed(1)} KB`)
}

await writeFile(
  join(outDir, 'index.json'),
  JSON.stringify(
    {
      kernel: 'kernel.js',
      extensions: bundles
        .filter((b) => b.kind === 'extension')
        .map((b) => ({ key: b.key, file: `${b.key}.js`, domains: b.domains ?? [] })),
    },
    null,
    2,
  ),
)
console.log(`index.json — ${bundles.length - 1} extensions`)
