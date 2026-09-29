// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// The `.h2kext` bundle format: what one contains, what makes one valid, and how
// to write it (HALO-422, docs/extensions/distribution.md).
//
// Deliberately standalone. It imports nothing from this repo — not the bundle
// list, not the esbuild options, not the SDK — because its whole purpose is to
// work for someone who has none of that. Its only dependency is a zip writer.
// Lifting this file and its CLI into a published npm package should be a
// packaging change, not a rewrite.
//
// It PACKAGES; it does not compile. The input is a directory that already
// holds a built `index.js` and a `manifest.json`. How that JS got built is the
// author's business — which is exactly why the checks below matter, since the
// one way it can be built WRONG is invisible until the extension is running
// inside somebody's app.

import { createWriteStream } from "node:fs"
import { readFile, readdir, stat } from "node:fs/promises"
import { join, posix, relative, sep } from "node:path"
import { parseCallsign } from "@ham2k/lib-callsigns"
import yazl from "yazl"

/// The extension API this format describes. A bundle declares the version it
/// was built against and the host refuses one it does not speak, so an old app
/// meeting a newer bundle says so instead of failing at a call site.
///
/// Raised when a bundle using something new could not work at all on an app
/// without it — not for every addition. 2 adds `host.webSocket` and the
/// manifest's `webSockets` grant; 3 adds timers and `onShow`/`onHide`; 4 lets
/// `host.fetch` reach an http-only host the app fronts with its https proxy
/// (the QSO Party Hub); 5 adds panel scenes' `scene` kind and what came with
/// it — native controls, `strings`, `layout`, `after` and control `opacity`.
export const H2KEXT_API_VERSION = 5

/// The first API with `host.webSocket`. A manifest declaring `webSockets`
/// under an older one is refused: an older app would install it and fail only
/// when it tried to connect.
export const WEB_SOCKETS_API_VERSION = 2

/// The first API with timers. The build points a bundle's bare `setTimeout`
/// and friends at the SDK's only from here on: an older app's kernel hands an
/// extension no timers, and a bundle declaring less says it runs there.
export const TIMERS_API_VERSION = 3

/// `<prefix>-<name>`, all lowercase. The shape is what the kernel's
/// `bundleMayDefine` prefix rule can reason about; the PREFIX is what keeps two
/// authors who never met from choosing the same key.
export const KEY_PATTERN = /^[a-z0-9]+-[a-z0-9-]*[a-z0-9]$/

/// The prefix reserved for Ham2K's own extensions. Refused to a distributed
/// bundle unless it is one of ours: there is no signing yet, so anyone could
/// claim it, and a key is what the app shows when it says where a hook came
/// from.
export const RESERVED_PREFIX = "ham2k"

/// Whether [prefix] is a real amateur callsign — the namespace every author of
/// this software already has, globally unique, and free.
export function isCallsignPrefix(prefix) {
  const parsed = parseCallsign(prefix.toUpperCase())
  return !!parsed.baseCall && parsed.baseCall === prefix.toUpperCase()
}

/// The shape a key must have whatever else is waived: lowercase, letters
/// digits and hyphens. Not a naming convention — the key namespaces KV
/// storage, scopes secrets, and identifies hooks, so anything outside this
/// breaks the runtime rather than merely looking wrong.
///
/// A leading DIGIT is legitimate and must stay allowed: plenty of callsigns
/// begin with one (2E0ABC, 9A1AA, 4X4XYZ), and the convention below builds a
/// key out of exactly that.
export const SAFE_KEY_PATTERN = /^[a-z0-9][a-z0-9-]*$/

/// Why [key] is not a usable extension key, or null if it is.
///
/// [forceName] waives the naming CONVENTION — the callsign prefix and the
/// reserved `ham2k-` — for Ham2K's own packaging, which builds the extensions
/// that ship inside the app under bare keys (`pota`, `sota`) and the reserved
/// prefix. It does not waive [SAFE_KEY_PATTERN], which is not a convention.
///
/// A guardrail, not a gate: a standalone tool cannot enforce who runs it. The
/// app is where the rule bites, refusing a reserved or colliding key at
/// install.
export function keyProblem(key, { forceName = false } = {}) {
  if (typeof key !== "string" || !SAFE_KEY_PATTERN.test(key)) {
    return `key '${key}' must be lowercase, and contain only letters, digits and hyphens`
  }
  if (forceName) return null
  if (!KEY_PATTERN.test(key)) {
    return `key '${key}' must be '<callsign>-<name>' (e.g. ki2d-my-clock)`
  }
  const prefix = key.slice(0, key.indexOf("-"))
  if (prefix === RESERVED_PREFIX) {
    return `key '${key}' uses the '${RESERVED_PREFIX}-' prefix, which is reserved for Ham2K's own extensions`
  }
  if (!isCallsignPrefix(prefix)) {
    return `key '${key}' must start with your callsign — '${prefix}' is not one (e.g. ki2d-my-clock)`
  }
  return null
}

/// The only entries a bundle may contain, beyond `assets/`.
export const MANIFEST_ENTRY = "manifest.json"
export const BUNDLE_ENTRY = "index.js"
export const ASSETS_PREFIX = "assets/"

/// The libraries the extension host carries, per API version, so a bundle does
/// not have to ship its own copy of each. The kernel holds one instance and
/// hands it to every extension through `__polo.sharedModules`.
///
/// NAMES only. The VERSION a given app carries is that build's business, which
/// is the whole reason a bundle declares a RANGE in `sharedDependencies` and
/// the host checks it at load: a list of names is stable across releases,
/// a list of versions would be a lie the moment either side shipped.
///
/// Deliberately duplicated from build-config.mjs's `sharedPackages` rather than
/// imported — this module has to work with none of this repo present. A test
/// in the repo asserts the two agree, which is the only place that check can
/// live once this file is published on its own.
export const SHARED_MODULES_BY_API = {
  1: [
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
  ],
}
SHARED_MODULES_BY_API[2] = SHARED_MODULES_BY_API[1]
SHARED_MODULES_BY_API[3] = SHARED_MODULES_BY_API[2]
SHARED_MODULES_BY_API[4] = SHARED_MODULES_BY_API[3]
SHARED_MODULES_BY_API[5] = SHARED_MODULES_BY_API[4]

/// What a scaffolded extension declares on day one: the eight modules the SDK
/// barrel itself reaches, so a project that has written no code yet still
/// builds. Importing anything from `@ham2k/extension-sdk` pulls them in —
/// `dxcc`, `i18n` and `templates` are on the barrel — which makes declaring
/// them a starting condition rather than a choice the author makes later.
///
/// Ranges at the MAJOR, which is the grain the check is really about and the
/// one the docs model. They are a starting point the author owns from the
/// moment it is written: narrowing one to the version actually tested against
/// is a normal thing to do before publishing.
///
/// Versions here and nowhere else in this file. `SHARED_MODULES_BY_API` is the
/// host's OFFER, which must stay version-free; this is one author's opening
/// DECLARATION, which the format requires to carry ranges. A test in the repo
/// asserts every range here is satisfied by the versions this build's host
/// actually holds, so a major bump there fails a build rather than shipping a
/// scaffold that cannot install.
export const SCAFFOLD_SHARED_DEPENDENCIES = {
  "@ham2k/lib-callsigns": "^1.0.0",
  "@ham2k/lib-country-files": "^1.0.0",
  "@ham2k/lib-dxcc-data": "^1.0.0",
  "@ham2k/lib-format-tools": "^1.0.0",
  "@ham2k/lib-geo-tools": "^1.0.0",
  "@ham2k/lib-operation-data": "^1.0.0",
  i18next: "^23.0.0",
  liquidjs: "^10.0.0",
}

/// What the host offers a bundle declaring [api].
export function sharedModulesFor(api) {
  return SHARED_MODULES_BY_API[api] ?? SHARED_MODULES_BY_API[H2KEXT_API_VERSION]
}

export class PackError extends Error {}

/// The vocabulary of the manifest's `relevance` — what the matcher compares
/// the operator's own values against, so a value outside it can never match
/// anyone. Continents are cty.dat's column-4 codes; the regions are the three
/// the ITU Radio Regulations define.
export const GEO_CONTINENTS = ["AF", "AS", "EU", "NA", "OC", "SA", "AN"]
export const GEO_ITU_REGIONS = [1, 2, 3]

/// What `relevance.interests` may name: a mode, a band group, or a style of
/// operating. Closed, and checked, because an interest nothing else spells
/// the same way matches nobody while looking like it works — `CW`, `cw` and
/// `morse` would be three interests, and only one of them the one the app
/// asks for.
///
/// Growing the list is how a new interest arrives. Guessing is not.
export const RELEVANCE_INTERESTS = ["cw", "phone", "digital", "hf", "vhf", "uhf", "microwave", "satellite", "portable", "qrp"]

const RELEVANCE_KEYS = ["entities", "countries", "continents", "ituRegions", "dates", "interests"]

/// Everything wrong with a manifest's `relevance`, as a list — empty for a
/// valid one, and for an absent one, which means worldwide and undated.
///
/// The shape rules are the ones that matter: the matcher reads a key it
/// cannot parse as "does not gate", so a misspelt key or a string where a
/// list should be would quietly make a Chilean extension relevant to the
/// whole world. The vocabulary rules catch the opposite mistake — a value that
/// can never match anyone, which is a bundle nobody is shown.
///
/// Shared with build-config.mjs's manifest checks, which import it: the
/// rules are the format's, not the repo's, and this module is the format.
export function validateRelevance(relevance) {
  if (relevance === undefined) return []
  if (typeof relevance !== "object" || relevance === null || Array.isArray(relevance)) {
    return [`'relevance' must be an object of ${RELEVANCE_KEYS.join(" / ")}`]
  }
  const problems = []
  for (const key of Object.keys(relevance)) {
    if (!RELEVANCE_KEYS.includes(key)) {
      problems.push(`'relevance' has an unknown key '${key}' — only ${RELEVANCE_KEYS.join(", ")} are read`)
    }
  }
  for (const key of RELEVANCE_KEYS) {
    const values = relevance[key]
    if (values === undefined) continue
    if (!Array.isArray(values)) {
      problems.push(`'relevance.${key}' must be a list`)
      continue
    }
    for (const value of values) {
      const problem = relevanceValueProblem(key, value)
      if (problem) problems.push(`'relevance.${key}' has ${JSON.stringify(value)}, which ${problem}`)
    }
  }
  return problems
}

function relevanceValueProblem(key, value) {
  if (key === "ituRegions") {
    return GEO_ITU_REGIONS.includes(value) ? null : `is not an ITU region (${GEO_ITU_REGIONS.join(", ")})`
  }
  if (typeof value !== "string" || value.trim() === "") return "is not a non-empty string"
  if (key === "entities") {
    return /^\*?[A-Z0-9/]+$/.test(value.toUpperCase()) ? null : "is not a DXCC entity prefix (letters, digits and '/', with an optional leading '*')"
  }
  if (key === "countries") {
    return /^[a-z]{2}$/.test(value.toLowerCase()) ? null : "is not a two-letter ISO country code"
  }
  if (key === "dates") return calendarDateProblem(value)
  if (key === "interests") {
    return RELEVANCE_INTERESTS.includes(value) ? null : `is not an interest (${RELEVANCE_INTERESTS.join(" ")})`
  }
  return GEO_CONTINENTS.includes(value.toUpperCase()) ? null : `is not a continent (${GEO_CONTINENTS.join(" ")})`
}

/// Why [value] is not a UTC calendar day, or null.
///
/// The round trip is the whole check: `Date.UTC` rolls 31 February over into
/// 3 March rather than refusing it, so a pattern match alone accepts a day
/// that does not exist and then silently means a different one.
///
/// A year under 1000 is refused before that round trip, and the Dart twin
/// refuses it too. `Date.UTC` reads a year under 100 as 19xx, so `0050-01-01`
/// would fail the round trip here and pass in Dart — a disagreement between
/// the two on an input neither should be accepting anyway.
function calendarDateProblem(value) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return "is not a YYYY-MM-DD date"
  const [year, month, day] = value.split("-").map(Number)
  if (year < 1000) return "is not a year an event could fall in"
  const at = new Date(Date.UTC(year, month - 1, day))
  return at.getUTCFullYear() === year && at.getUTCMonth() === month - 1 && at.getUTCDate() === day ? null : "is not a day that exists"
}

/// Everything wrong with how a manifest scopes its `adifFields` hook, as a
/// list — empty for one with no such hook.
///
/// The full ADIF export asks an extension for fields only about a contact
/// carrying a reference that extension answers for, unless the manifest says
/// `adifFieldsScope: "always"`. A bundle that adds fields and declares neither
/// a `ref:` type nor the opt-in writes nothing to that file, and nothing at
/// export time says so. The opt-in is a manifest field rather than something
/// on the hook so that this check can see it without running the bundle.
///
/// Shared with build-config.mjs's manifest checks, like [validateRelevance].
export function validateAdifFieldsScope(manifest) {
  const scope = manifest?.adifFieldsScope
  if (scope !== undefined && scope !== "always") {
    return [`'adifFieldsScope' must be "always", or left out to scope 'adifFields' to the references this extension handles`]
  }
  const hooks = Array.isArray(manifest?.hooks) ? manifest.hooks : []
  if (!hooks.includes("adifFields") || scope === "always") return []
  if (hooks.some((hook) => typeof hook === "string" && hook.startsWith("ref:"))) return []
  return [
    `'hooks' lists 'adifFields' but no 'ref:' type — the full ADIF export asks an extension only about contacts with a reference it handles, ` +
      `so these fields would never be written; declare the 'ref:' types, or set "adifFieldsScope": "always" (docs/extensions/hooks.md)`,
  ]
}

/// Everything wrong with a candidate bundle, as a list — an author fixing one
/// problem per run is an author running this five times.
export function validateManifest(manifest, { source = MANIFEST_ENTRY, forceName = false } = {}) {
  const problems = []
  const say = (m) => problems.push(`${source}: ${m}`)

  if (typeof manifest !== "object" || manifest === null || Array.isArray(manifest)) {
    return [`${source}: must be a JSON object`]
  }

  for (const field of ["key", "name", "version", "description"]) {
    if (typeof manifest[field] !== "string" || manifest[field].trim() === "") {
      say(`missing required field '${field}'`)
    }
  }

  if (manifest.key !== undefined) {
    const problem = keyProblem(manifest.key, { forceName })
    if (problem) say(problem)
  }

  if (manifest.api === undefined) {
    say(`missing 'api' — declare the extension API this was built against (currently ${H2KEXT_API_VERSION})`)
  } else if (!Number.isInteger(manifest.api)) {
    say(`'api' must be an integer, not ${JSON.stringify(manifest.api)}`)
  } else if (manifest.api > H2KEXT_API_VERSION) {
    say(`'api' is ${manifest.api}, but this packer only knows ${H2KEXT_API_VERSION}`)
  }

  if (manifest.webSockets !== undefined) {
    if (!Array.isArray(manifest.webSockets) || manifest.webSockets.some((host) => typeof host !== "string")) {
      say("'webSockets' must be a list of hosts")
    } else if (manifest.webSockets.length && Number.isInteger(manifest.api) && manifest.api < WEB_SOCKETS_API_VERSION) {
      say(`'webSockets' needs 'api' ${WEB_SOCKETS_API_VERSION} or later — an app older than that would install this and fail only when it connects`)
    }
  }

  // An extension with no category is CORE to the host: always enabled, and
  // never listed in the Extensions panel. That is a status the app grants its
  // own extensions, not one a distributed bundle may claim for itself — a user
  // could neither see it nor turn it off.
  if (typeof manifest.category !== "string" || manifest.category.trim() === "") {
    say("missing 'category' — a bundle with none is treated as core: always on, and invisible in the Extensions panel")
  }

  if (manifest.sharedDependencies !== undefined) {
    const declared = manifest.sharedDependencies
    if (typeof declared !== "object" || declared === null || Array.isArray(declared)) {
      say("'sharedDependencies' must be an object of package name to version range")
    } else {
      const offered = sharedModulesFor(manifest.api)
      for (const [pkg, range] of Object.entries(declared)) {
        if (!offered.includes(pkg)) {
          say(`'sharedDependencies' names '${pkg}', which the host does not provide — bundle it into your build instead`)
        } else if (typeof range !== "string" || range.trim() === "") {
          say(`'sharedDependencies' entry '${pkg}' needs a version range, e.g. "^1.0.0"`)
        }
      }
    }
  }

  // `experiments` gates availability against the APP's experiment catalog. A
  // key the host does not define hides the extension forever, with nothing in
  // the UI to explain it, so a distributed bundle must not carry one.
  if (manifest.experiments !== undefined) {
    say("'experiments' refers to the app's own experiment catalog and would hide this extension permanently — remove it")
  }

  // The name `relevance` replaced. Nothing reads `geo`, and nothing here
  // rejects unknown top-level keys, so a manifest still carrying it would
  // pack, publish and install as WORLDWIDE — the author's audience silently
  // discarded rather than refused. It is the one stale key certain to
  // arrive, because it is what every older manifest says.
  if (manifest.geo !== undefined) {
    say("'geo' is now 'relevance' — rename it (docs/extensions/distribution.md)")
  }

  // `enabledByDefault` is the shipping app's answer for its OWN extensions,
  // which arrive whether the operator wanted them or not. An installed
  // bundle is one the operator went and got, so the answer is always yes and
  // a manifest that says otherwise is describing a state it cannot reach.
  if (manifest.enabledByDefault !== undefined) {
    say("'enabledByDefault' applies to an app's built-in extensions — an installed one is on because the operator installed it")
  }

  // `relevance` ranks the bundle, in the catalog and the Extensions panel,
  // for the operators it was written for. The matcher reads a key it cannot
  // parse as "does not gate", so a malformed one would ship as worldwide.
  for (const problem of validateRelevance(manifest.relevance)) say(problem)

  for (const problem of validateAdifFieldsScope(manifest)) say(problem)

  return problems
}

/// Every library a bundle takes from the host rather than carrying its own
/// copy — the `globalThis.__polo.sharedModules[...]` lookups its build emitted.
///
/// Taking them is the supported path and worth roughly thirty times the bundle
/// size. What the caller checks is that each one was DECLARED: the host carries
/// whatever version its build shipped with and makes no promise, so an
/// undeclared lookup is a bundle the app cannot version-check before loading.
/// It loads happily and then dies at the first call into a library that turned
/// out to be absent or a different major — far from the cause, and in someone
/// else's app.
export function findSharedModuleReferences(source) {
  const hits = []
  const pattern = /__polo\s*\.\s*sharedModules\s*\[\s*["']([^"']+)["']\s*\]/g
  for (const match of source.matchAll(pattern)) hits.push(match[1])
  return [...new Set(hits)]
}

/// Reads a bundle directory and returns `{manifest, files}` ready to write, or
/// throws a [PackError] naming everything wrong with it.
export async function readBundleDirectory(dir, { forceName = false } = {}) {
  let manifestRaw
  try {
    manifestRaw = await readFile(join(dir, MANIFEST_ENTRY), "utf8")
  } catch {
    throw new PackError(`no ${MANIFEST_ENTRY} in ${dir}`)
  }

  let manifest
  try {
    manifest = JSON.parse(manifestRaw)
  } catch (e) {
    throw new PackError(`${MANIFEST_ENTRY} is not valid JSON: ${e.message}`)
  }

  const problems = validateManifest(manifest, { forceName })

  let bundleSource
  try {
    bundleSource = await readFile(join(dir, BUNDLE_ENTRY), "utf8")
  } catch {
    throw new PackError(`no ${BUNDLE_ENTRY} in ${dir} — build your extension first; this packages, it does not compile`)
  }
  if (bundleSource.trim() === "") problems.push(`${BUNDLE_ENTRY}: is empty`)

  // Using the host's shared libraries is allowed, and is much the better
  // option — inlining them costs about ten times the bundle size. What is NOT
  // allowed is using one silently: the host carries whatever version that
  // build shipped with, so a bundle has to say what it can work with, and the
  // host checks it before loading. Undeclared, it loads happily and then dies
  // at the first call into a library that turned out to be a different major.
  const declaredShared = manifest?.sharedDependencies ?? {}
  const undeclared = findSharedModuleReferences(bundleSource).filter((pkg) => !(pkg in declaredShared))
  if (undeclared.length) {
    problems.push(
      `${BUNDLE_ENTRY}: uses the host's shared modules without declaring them (${undeclared.join(", ")}). ` +
        `Add them to 'sharedDependencies' in ${MANIFEST_ENTRY} with the version range you work with, ` +
        'e.g. {"' +
        undeclared[0] +
        '": "^1.0.0"}, so the host can refuse to load this against a version you never tested.',
    )
  }

  if (problems.length) throw new PackError(problems.join("\n"))

  const files = [
    { entry: MANIFEST_ENTRY, path: join(dir, MANIFEST_ENTRY) },
    { entry: BUNDLE_ENTRY, path: join(dir, BUNDLE_ENTRY) },
    ...(await collectAssets(dir)),
  ]
  return { manifest, files }
}

/// Everything under `assets/`, as forward-slashed entry names. Zip entry names
/// are `/`-separated by specification, so a Windows author must not produce a
/// bundle whose paths only their own machine can read.
async function collectAssets(dir) {
  const root = join(dir, ASSETS_PREFIX.slice(0, -1))
  try {
    if (!(await stat(root)).isDirectory()) return []
  } catch (e) {
    // No assets/ is ordinary. Anything else — unreadable, an I/O error, a
    // broken symlink — is not, and swallowing it ships a bundle silently
    // missing files the author believes are in it.
    if (e.code === "ENOENT") return []
    throw new PackError(`could not read ${root}: ${e.message}`)
  }

  const found = []
  const walk = async (current) => {
    for (const item of await readdir(current, { withFileTypes: true })) {
      const full = join(current, item.name)
      if (item.isDirectory()) await walk(full)
      else if (item.isFile()) {
        found.push({ entry: ASSETS_PREFIX + relative(root, full).split(sep).join(posix.sep), path: full })
      }
    }
  }
  await walk(root)
  return found.sort((a, b) => a.entry.localeCompare(b.entry))
}

/// Writes the `.h2kext` at [outPath]. Resolves once the file is closed —
/// yazl's `end()` only starts the write, and a caller that reported success
/// before then would be describing a file that is still being produced.
export function writeBundle(files, outPath) {
  return new Promise((resolve, reject) => {
    const zip = new yazl.ZipFile()
    for (const file of files) zip.addFile(file.path, file.entry)
    const out = createWriteStream(outPath)
    zip.outputStream.pipe(out)
    out.on("close", () => resolve(outPath))
    out.on("error", reject)
    zip.outputStream.on("error", reject)
    zip.end()
  })
}

/// Validate a directory and write its `.h2kext`. Returns `{manifest, outPath}`.
export async function pack(dir, { outPath, forceName = false } = {}) {
  const { manifest, files } = await readBundleDirectory(dir, { forceName })
  const target = outPath ?? join(process.cwd(), `${manifest.key}-${manifest.version}.h2kext`)
  await writeBundle(files, target)
  return { manifest, outPath: target, files }
}
