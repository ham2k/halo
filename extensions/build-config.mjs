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

import { readFile } from "node:fs/promises"
import { dirname, join, resolve } from "node:path"
import { fileURLToPath } from "node:url"

import { buildOptionsFor as extensionBuildOptions } from "./tools/h2kext-build.mjs"
import { validateAdifFieldsScope, validateRelevance } from "./tools/h2kext.mjs"

export const root = dirname(fileURLToPath(import.meta.url))
export const outDir = resolve(root, "../app/assets/extensions")
// Where `kind: 'fixture'` bundles go. NOT under [outDir]: the app's pubspec
// ships that directory wholesale, so anything written there is in every
// release build whether or not index.json names it.
export const fixturesDir = resolve(root, "build/fixtures")

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
    const pkgJson = JSON.parse(await readFile(join(root, "node_modules", pkg, "package.json"), "utf-8"))
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
export const builtInSharedDependencies = Object.fromEntries(sharedPackages.map((pkg) => [pkg, "*"]))

// `domains` is each extension's declared network capability (DESIGN.md §3's
// manifest allowlist, in embryo): the Dart host refuses host.fetch calls to
// any host not listed. Entries are exact hostnames; '*.example.com' matches
// subdomains; a lone '*' means any https host (only ham2k-lofi, whose sync
// server is user-configurable). No entry (or []) means no network at all.
// `webSockets` is the same shape for host.webSocket, and a separate grant: a
// live connection is not the request `domains` consents to. `wss://` to a
// listed host; plain `ws://` only to one that is also a local-network address.
// The entry "local" admits every local-network address, for gear whose
// address only the operator knows.
// `allowUserAgentOverride: true` is another network capability: the host
// stamps HaLo's canonical User-Agent on every host.fetch and normally
// overrides any the extension set, but a whitelisted extension keeps its own
// (see docs/design/network.md). Omit it (the default) unless a third-party
// service demands a specific UA — consistency is the goal.
// `requiresLocation: true` is a third capability, unrelated to networking:
// it allows the bundle to call host.getLocation() (the device's raw GPS
// fix, APP-34). Omit it (the default) — the host refuses the call for any
// extension key that doesn't declare it.
// `requiresRadioRead: true` and `requiresRadioWrite: true` likewise allow
// host.listRadios()/readRadio() (and a scene's spectrum control) and
// host.setRadio()/setRadioConnection()/setRadioSpectrum() and the keying calls.
// Write implies read: a command answers with the radio's state.
// `requiresClusterRead`, `requiresClusterSpot` and `requiresClusterCommand`
// allow the DX cluster calls, each including the ones before it:
// host.clusterStatus()/clusterLines()/clusterSubscribe(), then
// host.clusterPostSpot(), then host.clusterSend() (docs/design/cluster.md).
// Each extension's USER-FACING metadata (name, category, icon, keywords,
// translations, fetch-domain allowlist, …) lives in the package's own
// manifest.json — the single source both this build and the bundle itself
// (defineExtension spreads the imported manifest) read, so the two can't
// drift. index.json carries the manifest fields because the Extensions
// settings panel must list DISABLED extensions, whose bundles are never
// evaluated — the metadata has to be readable without running any JS.
// `version` is copied too, for the same reason: an extension that is
// installed but disabled has no running bundle for the kernel's
// listExtensions to report, and an update check needs its version anyway.
// `relevance` (where, when and for whom the extension matters) likewise, so
// the panel and the catalog can rank a disabled entry. Manifests without a `category` are
// core: always enabled, never listed in the panel.
export const bundles = [
  { key: "kernel", entry: "sdk/src/kernel.ts", kind: "kernel" },
  { key: "adif", entry: "core/adif/src/index.ts", kind: "extension" },
  { key: "scoring", entry: "core/scoring/src/index.ts", kind: "extension" },
  { key: "dxcc", entry: "core/dxcc/src/index.ts", kind: "extension" },
  { key: "lookups", entry: "core/lookups/src/index.ts", kind: "extension" },
  { key: "radio-commands", entry: "core/radio-commands/src/index.ts", kind: "extension" },
  { key: "dev-commands", entry: "core/dev-commands/src/index.ts", kind: "extension" },
  { key: "annotation-commands", entry: "core/annotation-commands/src/index.ts", kind: "extension" },
  { key: "spot-commands", entry: "core/spot-commands/src/index.ts", kind: "extension" },
  { key: "settings-commands", entry: "core/settings-commands/src/index.ts", kind: "extension" },
  { key: "test-ops-commands", entry: "core/test-ops-commands/src/index.ts", kind: "extension" },
  { key: "operation-commands", entry: "core/operation-commands/src/index.ts", kind: "extension" },
  { key: "time-commands", entry: "core/time-commands/src/index.ts", kind: "extension" },
  { key: "templates", entry: "core/templates/src/index.ts", kind: "extension" },
  // Built for the host's bridge tests, into [fixturesDir]; never shipped.
  { key: "k2hrc-panel-scenes", entry: "samples/k2hrc-panel-scenes/src/index.ts", kind: "fixture" },
  { key: "k2hrc-cqww", entry: "samples/k2hrc-cqww/src/index.ts", kind: "fixture" },
  { key: "ham2k-lofi", entry: "sync/ham2k-lofi/src/index.ts", kind: "extension" },
]

/// The experiment KEYS the app's catalog defines (aliases don't count: the
/// host gates on `experimentEnabled(key)`, which matches keys only). Extracted
/// by regex rather than a yaml dependency — the catalog is a flat hand-edited
/// list.
export async function loadKnownExperiments() {
  const experimentsCatalog = await readFile(resolve(root, "../app/experiments.yaml"), "utf-8")
  const knownExperiments = new Set([...experimentsCatalog.matchAll(/^\s*-\s*key:\s*(\S+)/gm)].map((m) => m[1]))
  // The extraction has to prove itself: no shipped manifest declares
  // `experiments` today, so the validation below iterates zero times and a
  // regex that silently stopped matching the catalog would go unnoticed until
  // somebody added a gate — and then fail in whichever direction it broke.
  // An over-matching regex is the dangerous one, because it validates a typo'd
  // key, which hides the extension from every user with no runtime signal.
  // `keyer` stands in for the catalog here: it is an entry the catalog is
  // expected to keep, and when it ships ungated this names another.
  if (!knownExperiments.has("keyer")) {
    throw new Error(
      `app/experiments.yaml parsed to ${knownExperiments.size} key(s), none of them 'keyer' — ` +
        "either the extraction regex no longer matches the catalog, or the 'keyer' entry was renamed or removed",
    )
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
  const manifestPath = join(root, dirname(bundle.entry), "../manifest.json")
  const manifest = JSON.parse(await readFile(manifestPath, "utf8"))
  validateManifest(manifest, bundle.key, knownExperiments, manifestPath)
  return manifest
}

export function validateManifest(manifest, bundleKey, knownExperiments, manifestPath) {
  if (manifest.key !== bundleKey) {
    throw new Error(`manifest key '${manifest.key}' does not match bundle key '${bundleKey}' (${manifestPath})`)
  }
  for (const field of ["name", "version", "description"]) {
    if (typeof manifest[field] !== "string" || manifest[field].trim() === "") {
      throw new Error(`manifest for '${bundleKey}' is missing required field '${field}' (${manifestPath})`)
    }
  }
  // `experiments` gates availability in the host: a malformed list — or a key
  // the catalog doesn't define (a typo, an alias, a retired entry) — would
  // silently hide the extension for everyone, so it fails the build instead.
  if ("experiments" in manifest && (!Array.isArray(manifest.experiments) || manifest.experiments.some((e) => typeof e !== "string" || e.trim() === ""))) {
    throw new Error(`manifest for '${bundleKey}' has an invalid 'experiments' list (${manifestPath})`)
  }
  for (const experiment of manifest.experiments ?? []) {
    if (!knownExperiments.has(experiment)) {
      throw new Error(`manifest for '${bundleKey}' lists experiment '${experiment}', which is not a key in app/experiments.yaml (${manifestPath})`)
    }
  }
  // The name `relevance` replaced. `indexEntryFor` copies `relevance` and
  // nothing else, so a manifest left on the old name builds green and ships
  // worldwide, with the author's audience dropped on the floor.
  if ("geo" in manifest) {
    throw new Error(`manifest for '${bundleKey}' still uses 'geo', which is now 'relevance' (${manifestPath})`)
  }
  // `relevance` is copied into index.json as-is and read there by the host's
  // matcher, which treats a key it cannot parse as "does not gate" — so a
  // malformed one would ship as worldwide. The rules are the format's
  // (tools/h2kext.mjs), imported rather than restated.
  const relevanceProblems = validateRelevance(manifest.relevance)
  if (relevanceProblems.length) {
    throw new Error(`manifest for '${bundleKey}' has an invalid 'relevance': ${relevanceProblems.join("; ")} (${manifestPath})`)
  }
  // Same rule the packer applies, imported for the same reason: an extension
  // whose fields the full ADIF export would never ask for builds green here
  // otherwise, and ships a hook that does nothing.
  const adifFieldsProblems = validateAdifFieldsScope(manifest)
  if (adifFieldsProblems.length) {
    throw new Error(`manifest for '${bundleKey}': ${adifFieldsProblems.join("; ")} (${manifestPath})`)
  }
}

/// Loads and validates every extension's manifest, attaching it to the bundle
/// entry as `.manifest`. Runs up front so a typo'd key, a missing file, or a
/// missing required field fails before any bundling work.
export async function loadManifests(forBundles = bundles) {
  const knownExperiments = await loadKnownExperiments()
  for (const bundle of forBundles) {
    if (bundle.kind !== "extension") continue
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
  const isKernel = bundle.kind === "kernel"

  return extensionBuildOptions({
    entry: join(root, bundle.entry),
    outfile,
    dir: root,
    manifest: isKernel ? {} : { sharedDependencies: builtInSharedDependencies },
    inline: isKernel ? sharedPackages : [],
    timers: isKernel ? false : join(root, "sdk/src/timers.ts"),
    alias: {
      "@ham2k/extension-sdk": join(root, "sdk/src/index.ts"),
      // camelcase@8 (pulled in by @ham2k/lib-qson-cabrillo) is a unicode-aware
      // package doing an ASCII job: Cabrillo tags are ASCII by specification.
      // shims/camelcase.ts covers that job without the dependency.
      camelcase: join(root, "shims/camelcase.ts"),
    },
    ...(isKernel ? { define: { __SHARED_VERSIONS__: JSON.stringify(hostSharedVersions) } } : {}),
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
    version: m.version,
    // A built-in declares none and is at the app's own level; a dev-served
    // catalog extension declares the level it was built for.
    ...(m.api ? { api: m.api } : {}),
    domains: m.domains ?? [],
    ...(m.webSockets?.length ? { webSockets: m.webSockets } : {}),
    ...(m.allowUserAgentOverride ? { allowUserAgentOverride: true } : {}),
    ...(m.requiresLocation ? { requiresLocation: true } : {}),
    ...(m.requiresRadioRead ? { requiresRadioRead: true } : {}),
    ...(m.requiresRadioWrite ? { requiresRadioWrite: true } : {}),
    ...(m.requiresClusterRead ? { requiresClusterRead: true } : {}),
    ...(m.requiresClusterSpot ? { requiresClusterSpot: true } : {}),
    ...(m.requiresClusterCommand ? { requiresClusterCommand: true } : {}),
    ...(m.experiments?.length ? { experiments: m.experiments } : {}),
    ...(m.relevance ? { relevance: m.relevance } : {}),
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
