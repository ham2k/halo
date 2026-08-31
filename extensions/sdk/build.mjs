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
import { EXAMPLE_BUILD_SCRIPT } from '../tools/h2kext-build.mjs'

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

/// The reference an author — or the agent writing the extension for them —
/// reads, carried IN the tarball rather than linked to.
///
/// Installed, they are local, greppable, offline, and pinned to the version of
/// the SDK sitting beside them; a link to the repository is none of those, and
/// answers with whatever `main` says today about a package published months
/// ago. `AGENTS.md` is the map into them.
///
/// Curated, because this repo's own inner loop is not an author's. The dev
/// server and `halo-ext` need a checkout, `mise` and the app's built bundles —
/// documented, they would send a reader after tooling they cannot run.
const shippedDocs = ['hooks.md', 'forms.md', 'templates.md', 'settings.md', 'distribution.md']

const docsSrc = join(here, '../../docs/extensions')
const docsOut = join(here, 'docs')
const PUBLIC_BLOB = 'https://github.com/ham2k/halo/blob/main'

/// `](target)`, ignoring absolute URLs, anchors and mail links.
const RELATIVE_LINK = /\]\((?!https?:|#|mailto:)([^)\s]+)\)/g

await rm(docsOut, { recursive: true, force: true })
await mkdir(docsOut, { recursive: true })

for (const name of shippedDocs) {
  const text = await readFile(join(docsSrc, name), 'utf8')

  const rewritten = text.replace(RELATIVE_LINK, (whole, target) => {
    const [path, anchor] = target.split('#')
    if (shippedDocs.includes(path.replace(/^\.\//, ''))) return whole
    // Resolved against the docs directory it came from, so `../design/x.md`
    // and `../../extensions/sdk/src/types.ts` both land on a repo path.
    const repoPath = `docs/extensions/${path}`.split('/').reduce((parts, part) => {
      if (part === '..') parts.pop()
      else if (part !== '.' && part !== '') parts.push(part)
      return parts
    }, []).join('/')
    return `](${PUBLIC_BLOB}/${repoPath}${anchor ? `#${anchor}` : ''})`
  })

  // The link forms RELATIVE_LINK does NOT match, scanned in the SOURCE. Those
  // are the ones that ship broken: the rewriter never sees them, so they leave
  // here as relative paths pointing at files the package does not carry —
  // followed, a dead relative path reads as a local file, and the reader
  // concludes it exists and starts inventing what is in it.
  //
  // Checking the rewriter's OWN pattern against its output would prove
  // nothing: it returns either an absolute URL or a path in `shippedDocs`, so
  // that scan passes by construction.
  const UNHANDLED_LINKS = [
    // `](x.md "title")` — the space ends RELATIVE_LINK's target early.
    /\]\((?!https?:|#|mailto:)[^)\s]+\s+[^)]*\)/g,
    // `[x]: y.md` — a reference-style definition is not a `](…)` at all.
    /^\[[^\]]+\]:\s*(?!https?:|#|mailto:)\S+/gm,
  ]
  for (const pattern of UNHANDLED_LINKS) {
    const [found] = text.match(pattern) ?? []
    if (found) {
      throw new Error(
        `docs/${name} has a link the shipping rewrite cannot follow: ${found.trim()}`)
    }
  }

  await writeFile(join(docsOut, name), rewritten)
}

/// How to run one. Short on purpose: the samples themselves are the document,
/// and the only thing a reader cannot work out from them is that a project
/// needs a package.json and a tsconfig, which `h2kext-init` writes.
const SAMPLES_README = `# Samples

One extension per shape, each one real: it builds, it packs, and it does what
it says against the live service. Read the one whose shape matches what you are
building — the header comment in each \`src/index.ts\` says what it leaves out.

| | |
| --- | --- |
| \`k2hrc-hamqth\` | A callsign lookup, and the \`account\` hook that asks for a password |
| \`k2hrc-llota\` | An award program: references, an offline list, activation scoring |
| \`k2hrc-cqww\` | A contest: an exchange to type, and a score to keep |
| \`k2hrc-radio\` | An HTML panel, and why you should probably write markdown instead |

## Running one

\`\`\`sh
mkdir my-extension && cd my-extension
npx -p @ham2k/extension-tools h2kext-init <yourcallsign>-<name>
npm install
\`\`\`

Then copy a sample's \`manifest.json\` and \`src/\` over the scaffolded ones,
change the \`key\` back to yours, and:

\`\`\`sh
npm run build && npm run pack
\`\`\`

The key must stay \`<yourcallsign>-<name>\` — it namespaces your extension's
storage, and the packer refuses anything else. The \`k2hrc-\` keys here belong
to the samples, so leaving one in place would collide with them.

See \`../AGENTS.md\` for the map, and \`../docs/\` for the references.
`

/// The worked examples, carried in the tarball beside the reference.
///
/// One per shape an extension can take, because the question an author arrives
/// with is "what does a lookup/contest/panel actually look like", and the
/// answer is code rather than prose. They are real: each builds, each would
/// pack, and `samples/samples.test.ts` in this repo holds them to it.
///
/// `build.mjs` is REPLACED on the way out. In this repo a sample reaches the
/// SDK and the tools through workspace paths; an author's copy reaches them
/// through npm, and shipping the workspace form would hand every reader a
/// build script that cannot resolve its own imports.
const shippedSamples = ['k2hrc-hamqth', 'k2hrc-llota', 'k2hrc-cqww', 'k2hrc-radio']

const samplesOut = join(here, 'samples')
await rm(samplesOut, { recursive: true, force: true })

for (const name of shippedSamples) {
  const from = join(here, '../samples', name)
  const to = join(samplesOut, name)
  await cp(from, to, { recursive: true })
  await writeFile(join(to, 'build.mjs'), EXAMPLE_BUILD_SCRIPT)

  // A sample that names a shared library its manifest does not declare fails
  // an author's first build, on code they did not write and cannot fix from
  // the error. The repo's test builds these, so reaching here with one is not
  // expected — this is the check that the thing being COPIED is the thing that
  // was tested.
  const manifest = JSON.parse(await readFile(join(to, 'manifest.json'), 'utf8'))
  if (!manifest.sharedDependencies || !manifest.key?.startsWith('k2hrc-')) {
    throw new Error(`samples/${name} does not look like a packaged sample (key, sharedDependencies)`)
  }
}

await writeFile(join(samplesOut, 'README.md'), SAMPLES_README)

const shipped = (await readdir(dist)).filter((n) => n.endsWith('.js')).length
console.log(
  `built @ham2k/extension-sdk ${version} — ${shipped} modules + rolled-up types + ` +
  `${shippedDocs.length} docs + ${shippedSamples.length} samples`)
