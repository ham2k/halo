// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Bundles the kernel and every extension into single-file IIFE bundles for the
// QuickJS runtime, and writes an index.json the Dart host uses to know what
// to load. Output goes into the Flutter app's assets.

import { build } from 'esbuild'
import { mkdir, writeFile, readFile, readdir, unlink } from 'node:fs/promises'
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
  "liquidjs",
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
      build.onResolve({ filter: /^(@ham2k\/lib-|i18next$|liquidjs$)/ }, (args) => {
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
// `allowUserAgentOverride: true` is a second network capability: the host
// stamps HaLo's canonical User-Agent on every host.fetch and normally
// overrides any the extension set, but a whitelisted extension keeps its own
// (see docs/design/network.md). Omit it (the default) unless a third-party
// service demands a specific UA — consistency is the goal.
// `requiresLocation: true` is a third capability, unrelated to networking:
// it allows the bundle to call host.getLocation() (the device's raw GPS
// fix, APP-34). Omit it (the default) — the host refuses the call for any
// extension key that doesn't declare it.
// Each extension's USER-FACING metadata (name, category, icon, keywords,
// translations, fetch-domain allowlist, …) lives in the package's own
// manifest.json — the single source both this build and the bundle itself
// (defineExtension spreads the imported manifest) read, so the two can't
// drift. index.json carries the manifest fields because the Extensions
// settings panel must list DISABLED extensions, whose bundles are never
// evaluated — the metadata has to be readable without running any JS.
// Versions are NOT copied into index.json (they stay runtime-only, via the
// kernel's listExtensions). Manifests without a `category` are core:
// always enabled, never listed in the panel.
const bundles = [
  { key: 'kernel', entry: 'sdk/src/kernel.ts', kind: 'kernel' },
  { key: 'adif', entry: 'core/adif/src/index.ts', kind: 'extension' },
  { key: 'scoring', entry: 'core/scoring/src/index.ts', kind: 'extension' },
  { key: 'lookups', entry: 'core/lookups/src/index.ts', kind: 'extension' },
  { key: 'radio-commands', entry: 'core/radio-commands/src/index.ts', kind: 'extension' },
  { key: 'dev-commands', entry: 'core/dev-commands/src/index.ts', kind: 'extension' },
  { key: 'annotation-commands', entry: 'core/annotation-commands/src/index.ts', kind: 'extension' },
  { key: 'spot-commands', entry: 'core/spot-commands/src/index.ts', kind: 'extension' },
  { key: 'settings-commands', entry: 'core/settings-commands/src/index.ts', kind: 'extension' },
  { key: 'qrz', entry: 'lookups/qrz/src/index.ts', kind: 'extension' },
  { key: 'ham2k-lookup', entry: 'lookups/ham2k-lookup/src/index.ts', kind: 'extension' },
  { key: 'call-notes', entry: 'lookups/call-notes/src/index.ts', kind: 'extension' },
  { key: 'spot-history', entry: 'lookups/spot-history/src/index.ts', kind: 'extension' },
  { key: 'pota', entry: 'activities/pota/src/index.ts', kind: 'extension' },
  { key: 'sota', entry: 'activities/sota/src/index.ts', kind: 'extension' },
  { key: 'wca', entry: 'activities/wca/src/index.ts', kind: 'extension' },
  { key: 'gma', entry: 'activities/gma/src/index.ts', kind: 'extension' },
  { key: 'mota', entry: 'activities/mota/src/index.ts', kind: 'extension' },
  { key: 'siota', entry: 'activities/siota/src/index.ts', kind: 'extension' },
  { key: 'wwbota', entry: 'activities/wwbota/src/index.ts', kind: 'extension' },
  { key: 'zlota', entry: 'activities/zlota/src/index.ts', kind: 'extension' },
  { key: 'wwff', entry: 'activities/wwff/src/index.ts', kind: 'extension' },
  { key: 'llota', entry: 'activities/llota/src/index.ts', kind: 'extension' },
  { key: 'tota', entry: 'activities/tota/src/index.ts', kind: 'extension' },
  { key: 'bca', entry: 'activities/bca/src/index.ts', kind: 'extension' },
  { key: 'blha', entry: 'activities/blha/src/index.ts', kind: 'extension' },
  { key: 'eca', entry: 'activities/eca/src/index.ts', kind: 'extension' },
  { key: 'ela', entry: 'activities/ela/src/index.ts', kind: 'extension' },
  { key: 'pga', entry: 'activities/pga/src/index.ts', kind: 'extension' },
  { key: 'custom', entry: 'activities/custom/src/index.ts', kind: 'extension' },
  { key: 'satellites', entry: 'activities/satellites/src/index.ts', kind: 'extension' },
  { key: 'simple-contest', entry: 'contests/simple-contest/src/index.ts', kind: 'extension' },
  { key: 'cqww', entry: 'contests/cqww/src/index.ts', kind: 'extension' },
  { key: 'arrl-dx', entry: 'contests/arrl-dx/src/index.ts', kind: 'extension' },
  { key: 'cqwpx', entry: 'contests/cqwpx/src/index.ts', kind: 'extension' },
  { key: 'iaru-hf', entry: 'contests/iaru-hf/src/index.ts', kind: 'extension' },
  { key: 'naqp', entry: 'contests/naqp/src/index.ts', kind: 'extension' },
  { key: 'stateparks', entry: 'contests/stateparks/src/index.ts', kind: 'extension' },
  { key: 'fd', entry: 'contests/fd/src/index.ts', kind: 'extension' },
  { key: 'wfd', entry: 'contests/wfd/src/index.ts', kind: 'extension' },
  { key: 'arrl-vhf-tests', entry: 'contests/arrl-vhf-tests/src/index.ts', kind: 'extension' },
  { key: 'r1-vhf-tests', entry: 'contests/r1-vhf-tests/src/index.ts', kind: 'extension' },
  { key: 'rsgb-vhf-tests', entry: 'contests/rsgb-vhf-tests/src/index.ts', kind: 'extension' },
  { key: 'parksnpeaks', entry: 'spots/parksnpeaks/src/index.ts', kind: 'extension' },
  { key: 'custom-text', entry: 'dashboard/custom-text/src/index.ts', kind: 'extension' },
  { key: 'solar-panel', entry: 'dashboard/solar/src/index.ts', kind: 'extension' },
  { key: 'ham2k-lofi', entry: 'sync/ham2k-lofi/src/index.ts', kind: 'extension' },
]

// The experiment KEYS the app's catalog defines (aliases don't count: the
// host gates on `experimentEnabled(key)`, which matches keys only). Used to
// validate manifests' `experiments` lists below. Extracted by regex rather
// than a yaml dependency — the catalog is a flat hand-edited list.
const experimentsCatalog = await readFile(resolve(root, '../app/experiments.yaml'), 'utf-8')
const knownExperiments = new Set([...experimentsCatalog.matchAll(/^\s*-\s*key:\s*(\S+)/gm)].map((m) => m[1]))

// Load and sanity-check every extension's manifest up front, so a typo'd
// key, a missing file, or a missing required field fails the build before
// any bundling work.
for (const bundle of bundles) {
  if (bundle.kind !== 'extension') continue
  const manifestPath = join(root, dirname(bundle.entry), '../manifest.json')
  const manifest = JSON.parse(await readFile(manifestPath, 'utf8'))
  if (manifest.key !== bundle.key) {
    throw new Error(`manifest key '${manifest.key}' does not match bundle key '${bundle.key}' (${manifestPath})`)
  }
  for (const field of ['name', 'version', 'description']) {
    if (typeof manifest[field] !== 'string' || manifest[field].trim() === '') {
      throw new Error(`manifest for '${bundle.key}' is missing required field '${field}' (${manifestPath})`)
    }
  }
  // `experiments` gates availability in the host: a malformed list — or a
  // key the catalog doesn't define (a typo, an alias, a retired entry) —
  // would silently hide the extension for everyone, so it fails the build
  // instead.
  if ('experiments' in manifest &&
      (!Array.isArray(manifest.experiments) ||
        manifest.experiments.some((e) => typeof e !== 'string' || e.trim() === ''))) {
    throw new Error(`manifest for '${bundle.key}' has an invalid 'experiments' list (${manifestPath})`)
  }
  for (const experiment of manifest.experiments ?? []) {
    if (!knownExperiments.has(experiment)) {
      throw new Error(
        `manifest for '${bundle.key}' gates on experiment '${experiment}', which is not a key in app/experiments.yaml (${manifestPath})`)
    }
  }
  bundle.manifest = manifest
}

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
    alias: {
      '@ham2k/halo-extension-sdk': join(root, 'sdk/src/index.ts'),
      // camelcase@8 (pulled in by @ham2k/lib-qson-cabrillo) is a unicode-aware
      // package doing an ASCII job: Cabrillo tags are ASCII by specification.
      // shims/camelcase.ts covers that job without the dependency.
      'camelcase': join(root, 'shims/camelcase.ts'),
      // liquidjs's `main`/`module` are its NODE builds, which import node:fs
      // and node:path for `{% include %}`'s filesystem loader. Its browser
      // build is reachable only through the `browser` field, and
      // `platform: 'neutral'` ignores that field — so without this alias the
      // kernel fails to bundle. Nothing is lost: filesystem partials have no
      // meaning in a runtime with no filesystem, so `{% include %}` throws
      // either way (docs/extensions/templates.md).
      'liquidjs': join(root, 'node_modules/liquidjs/dist/liquid.browser.mjs'),
    },
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
        .map(({ key, manifest: m }) => ({
          key,
          file: `${key}.js`,
          domains: m.domains ?? [],
          ...(m.allowUserAgentOverride ? { allowUserAgentOverride: true } : {}),
          ...(m.requiresLocation ? { requiresLocation: true } : {}),
          ...(m.experiments?.length ? { experiments: m.experiments } : {}),
          core: !m.category,
          ...(m.category
            ? {
                name: m.name ?? key,
                ...(m.shortName ? { shortName: m.shortName } : {}),
                category: m.category,
                enabledByDefault: m.enabledByDefault ?? true,
                ...(m.icon ? { icon: m.icon } : {}),
                ...(m.description ? { description: m.description } : {}),
                ...(m.accentColor ? { accentColor: m.accentColor } : {}),
                ...(m.keywords ? { keywords: m.keywords } : {}),
                ...(m.hooks ? { hooks: m.hooks } : {}),
                ...(m.translations ? { translations: m.translations } : {}),
              }
            : {}),
        })),
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
const expected = new Set([...bundles.map((b) => `${b.key}.js`), 'index.json'])
for (const name of await readdir(outDir)) {
  if (expected.has(name)) continue
  await unlink(join(outDir, name))
  console.log(`removed orphan — ${name}`)
}

console.log(`index.json — ${bundles.length - 1} extensions`)
