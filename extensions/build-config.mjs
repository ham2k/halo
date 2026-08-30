// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What every extension bundle is built FROM: the bundle list, the shared-module
// externalization, the esbuild options, and the manifest checks.
//
// Shared by build.mjs (which writes the shipped bundles into the app's assets)
// and dev-server.mjs (which builds the same sources in memory and serves them
// to a running app). They must build IDENTICALLY — a dev bundle that resolves
// its dependencies differently from the shipped one sends an author chasing
// behaviour that exists only in their loop, which is the one bug a dev loop
// must never invent. One module, imported by both, is what makes that
// structural rather than a promise.

import { readFile } from 'node:fs/promises'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

import { buildOptionsFor as extensionBuildOptions } from './tools/h2kext-build.mjs'

export const root = dirname(fileURLToPath(import.meta.url))
export const outDir = resolve(root, '../app/assets/extensions')

export const sharedPackages = [
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

/// The versions of the shared libraries actually installed here — what the
/// kernel will hold at runtime, and therefore what an extension's declared
/// range is checked against.
export async function loadHostSharedVersions() {
  const versions = {}
  for (const pkg of sharedPackages) {
    const pkgJson = JSON.parse(await readFile(join(root, 'node_modules', pkg, 'package.json'), 'utf-8'))
    versions[pkg] = pkgJson.version
  }
  return versions
}

/// What a built-in bundle declares it takes from the host: the host's whole
/// list, because for a built-in the two lists are the same thing. It ships
/// inside the app beside the kernel that holds the instances, so there is no
/// subset it could name that would mean anything — and naming one would make
/// adding an import to an extension a build failure in a second file.
///
/// Which of them a given bundle actually resolves is decided by its imports,
/// not by this: every extension imports the SDK barrel, whose modules reach 8
/// of the 12, and the rest appear only where something imports them directly.
///
/// Declared HERE rather than in 49 manifests. A third party's declaration is
/// read twice: by their build, and by the app at install, which refuses a
/// bundle whose ranges this build cannot satisfy. A built-in's would be read
/// only by this build — built-ins are assets, and never take the install path
/// — so 49 identical copies would be a field nothing reads, drifting the
/// moment one was missed.
///
/// The range is `*` and means it: a built-in ships inside the app, so whatever
/// version the host holds is by construction the version it was built against.
export const builtInSharedDependencies = Object.fromEntries(sharedPackages.map((pkg) => [pkg, '*']))

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
export const bundles = [
  { key: 'kernel', entry: 'sdk/src/kernel.ts', kind: 'kernel' },
  { key: 'adif', entry: 'core/adif/src/index.ts', kind: 'extension' },
  { key: 'scoring', entry: 'core/scoring/src/index.ts', kind: 'extension' },
  { key: 'lookups', entry: 'core/lookups/src/index.ts', kind: 'extension' },
  { key: 'radio-commands', entry: 'core/radio-commands/src/index.ts', kind: 'extension' },
  { key: 'dev-commands', entry: 'core/dev-commands/src/index.ts', kind: 'extension' },
  { key: 'annotation-commands', entry: 'core/annotation-commands/src/index.ts', kind: 'extension' },
  { key: 'spot-commands', entry: 'core/spot-commands/src/index.ts', kind: 'extension' },
  { key: 'settings-commands', entry: 'core/settings-commands/src/index.ts', kind: 'extension' },
  { key: 'test-ops-commands', entry: 'core/test-ops-commands/src/index.ts', kind: 'extension' },
  { key: 'operation-commands', entry: 'core/operation-commands/src/index.ts', kind: 'extension' },
  { key: 'qrz', entry: 'lookups/qrz/src/index.ts', kind: 'extension' },
  { key: 'ham2k-lookup', entry: 'lookups/ham2k-lookup/src/index.ts', kind: 'extension' },
  { key: 'call-notes', entry: 'lookups/call-notes/src/index.ts', kind: 'extension' },
  { key: 'spot-history', entry: 'lookups/spot-history/src/index.ts', kind: 'extension' },
  { key: 'call-history', entry: 'lookups/call-history/src/index.ts', kind: 'extension' },
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
  { key: 'cwt', entry: 'contests/cwt/src/index.ts', kind: 'extension' },
  { key: 'parksnpeaks', entry: 'spots/parksnpeaks/src/index.ts', kind: 'extension' },
  { key: 'custom-text', entry: 'dashboard/custom-text/src/index.ts', kind: 'extension' },
  { key: 'ham2k-lofi', entry: 'sync/ham2k-lofi/src/index.ts', kind: 'extension' },
]

/// The experiment KEYS the app's catalog defines (aliases don't count: the
/// host gates on `experimentEnabled(key)`, which matches keys only). Extracted
/// by regex rather than a yaml dependency — the catalog is a flat hand-edited
/// list.
export async function loadKnownExperiments() {
  const experimentsCatalog = await readFile(resolve(root, '../app/experiments.yaml'), 'utf-8')
  const knownExperiments = new Set([...experimentsCatalog.matchAll(/^\s*-\s*key:\s*(\S+)/gm)].map((m) => m[1]))
  // The extraction has to prove itself: no shipped manifest declares
  // `experiments` today, so the validation below iterates zero times and a
  // regex that silently stopped matching the catalog would go unnoticed until
  // somebody added a gate — and then fail in whichever direction it broke.
  // An over-matching regex is the dangerous one, because it validates a typo'd
  // key, which hides the extension from every user with no runtime signal.
  // `experiments` is the meta-experiment gating the Experiments list, the one
  // key the catalog cannot lose.
  if (!knownExperiments.has('experiments')) {
    throw new Error(
      `app/experiments.yaml parsed to ${knownExperiments.size} key(s), none of them 'experiments' — ` +
        'the extraction regex no longer matches the catalog')
  }
  return knownExperiments
}

/// Reads and validates ONE extension's manifest, returning it.
///
/// Every caller must go through this, the dev server's per-rebuild re-read
/// included: a manifest edited mid-session can change `key`, drop a required
/// field, or name an experiment the catalog doesn't define, and a dev loop that
/// accepted what `npm run build` would reject is the exact drift this module
/// exists to prevent.
export async function readManifest(bundle, knownExperiments) {
  const manifestPath = join(root, dirname(bundle.entry), '../manifest.json')
  const manifest = JSON.parse(await readFile(manifestPath, 'utf8'))
  validateManifest(manifest, bundle.key, knownExperiments, manifestPath)
  return manifest
}

export function validateManifest(manifest, bundleKey, knownExperiments, manifestPath) {
  if (manifest.key !== bundleKey) {
    throw new Error(`manifest key '${manifest.key}' does not match bundle key '${bundleKey}' (${manifestPath})`)
  }
  for (const field of ['name', 'version', 'description']) {
    if (typeof manifest[field] !== 'string' || manifest[field].trim() === '') {
      throw new Error(`manifest for '${bundleKey}' is missing required field '${field}' (${manifestPath})`)
    }
  }
  // `experiments` gates availability in the host: a malformed list — or a key
  // the catalog doesn't define (a typo, an alias, a retired entry) — would
  // silently hide the extension for everyone, so it fails the build instead.
  if ('experiments' in manifest &&
      (!Array.isArray(manifest.experiments) ||
        manifest.experiments.some((e) => typeof e !== 'string' || e.trim() === ''))) {
    throw new Error(`manifest for '${bundleKey}' has an invalid 'experiments' list (${manifestPath})`)
  }
  for (const experiment of manifest.experiments ?? []) {
    if (!knownExperiments.has(experiment)) {
      throw new Error(
        `manifest for '${bundleKey}' gates on experiment '${experiment}', which is not a key in app/experiments.yaml (${manifestPath})`)
    }
  }
}

/// Loads and validates every extension's manifest, attaching it to the bundle
/// entry as `.manifest`. Runs up front so a typo'd key, a missing file, or a
/// missing required field fails before any bundling work.
export async function loadManifests(forBundles = bundles) {
  const knownExperiments = await loadKnownExperiments()
  for (const bundle of forBundles) {
    if (bundle.kind !== 'extension') continue
    bundle.manifest = await readManifest(bundle, knownExperiments)
  }
  return forBundles
}

/// The esbuild options for one bundle. [outfile] is omitted by the dev server,
/// which builds in memory (`write: false`) rather than into the app's assets —
/// serving a bundle must never overwrite the one the app ships, or a dev
/// session would quietly leave the working tree carrying its output.
export function buildOptionsFor(bundle, { hostSharedVersions, outfile }) {
  // The kernel is the one bundle that must NOT reach for `sharedModules`: it
  // IS what holds them, so it inlines every shared library and publishes the
  // instances the others then look up.
  const isKernel = bundle.kind === 'kernel'

  return extensionBuildOptions({
    entry: join(root, bundle.entry),
    outfile,
    dir: root,
    manifest: isKernel ? {} : { sharedDependencies: builtInSharedDependencies },
    inline: isKernel ? sharedPackages : [],
    alias: {
      '@ham2k/extension-sdk': join(root, 'sdk/src/index.ts'),
      // camelcase@8 (pulled in by @ham2k/lib-qson-cabrillo) is a unicode-aware
      // package doing an ASCII job: Cabrillo tags are ASCII by specification.
      // shims/camelcase.ts covers that job without the dependency.
      'camelcase': join(root, 'shims/camelcase.ts'),
    },
    ...(isKernel ? { define: { '__SHARED_VERSIONS__': JSON.stringify(hostSharedVersions) } } : {}),
    metafile: true,
  })
}

/// One extension's entry in index.json — the metadata the Dart host reads
/// without evaluating any JS. The dev server serves the same shape for the
/// extensions it offers, so the app's loader needs no second format.
export function indexEntryFor({ key, manifest: m }) {
  return {
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
  }
}
