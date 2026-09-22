#!/usr/bin/env node
// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// Scaffolds an extension project (HALO-452, docs/extensions/distribution.md).
//
//   npx h2kext-init <yourcallsign>-<name>
//
// Writes the smallest whole extension — a panel that says hello — plus the
// `AGENTS.md` that points whatever is writing the code at the reference inside
// `@ham2k/extension-sdk`. That one line is the whole reason this command
// exists: an agent reads a project's AGENTS.md unprompted, and otherwise never
// learns the docs are sitting in node_modules and guesses the manifest instead.
//
// It takes the key rather than defaulting one. A placeholder like
// `n0call-my-extension` VALIDATES — N0CALL is a well-formed callsign — so it
// would ship, which is the one outcome the naming convention exists to stop.

import { readFileSync } from "node:fs"
import { access, mkdir, readFile, writeFile } from "node:fs/promises"
import { dirname, join, relative, resolve } from "node:path"
import { fileURLToPath } from "node:url"

import { EXAMPLE_BUILD_SCRIPT } from "./h2kext-build.mjs"
import { H2KEXT_API_VERSION, SCAFFOLD_SHARED_DEPENDENCIES, keyProblem } from "./h2kext.mjs"

const args = process.argv.slice(2)

if (args.length === 0 || args.includes("--help") || args.includes("-h")) {
  console.log(`Scaffold a Ham2K Logger extension.

  h2kext-init <key> [--dir <path>] [--name "<display name>"]

The key is '<yourcallsign>-<name>' — e.g. ki2d-my-clock. The callsign is a
namespace you already have, globally unique, so two authors who never met
cannot collide. It also namespaces your extension's storage.

Writes manifest.json, src/index.ts, build.mjs, tsconfig.json, AGENTS.md and
.gitignore into <path> (default: the working directory), refusing rather than
overwrite anything already there. An existing package.json is added to — the
scripts and dependencies this needs, nothing of yours replaced.`)
  process.exit(args.length === 0 ? 1 : 0)
}

let key
let dir = process.cwd()
let displayName
for (let i = 0; i < args.length; i++) {
  // `resolve('')` is the working directory, so a bare `--dir` would scaffold
  // wherever the author happened to be standing.
  if (args[i] === "--dir") dir = args[++i] ? resolve(args[i]) : undefined
  else if (args[i] === "--name") displayName = args[++i]
  else if (!args[i].startsWith("-") && key === undefined) key = args[i]
}

const problem = keyProblem(key)
if (problem) {
  console.error(`h2kext-init: ${problem}`)
  process.exit(1)
}

if (dir === undefined) {
  console.error("h2kext-init: --dir needs the directory to scaffold into")
  process.exit(1)
}

const shortKey = key.slice(key.indexOf("-") + 1)
const name =
  displayName ??
  shortKey
    .split("-")
    .filter(Boolean)
    .map((w) => w[0].toUpperCase() + w.slice(1))
    .join(" ")

const here = dirname(fileURLToPath(import.meta.url))
const { version: toolsVersion } = JSON.parse(await readFile(join(here, "package.json"), "utf8"))

/// The SDK is a SEPARATE package on its own version line, so this cannot be
/// answered with the version of the tools that happen to be running: a
/// tools-only patch would scaffold `^0.1.1` of an SDK that has no such
/// release, and `npm install` — the very next line this command prints —
/// fails with ETARGET. The other direction is worse, because it is quiet: an
/// SDK a minor ahead, and the author installs the old one while reading the
/// new one's docs.
///
/// Resolved from what is actually installed where the project is being made,
/// which is right whenever the documented `npm i -D @ham2k/extension-tools`
/// route pulled the SDK in too. With nothing installed there is nothing to
/// read, and `latest` is the honest answer — the author's `npm install` then
/// fetches whatever the current SDK is, which is what a new project wants.
function sdkRange(projectDir) {
  // READ the file; do not `require` it. A package's own package.json is not a
  // subpath its `exports` map declares, and Node refuses an undeclared subpath
  // — `createRequire(...)('@ham2k/extension-sdk/package.json')` throws
  // ERR_PACKAGE_PATH_NOT_EXPORTED for a package sitting right there in
  // node_modules, so every scaffold would silently fall through to `latest`.
  for (const start of [projectDir, here]) {
    for (let dir = start; ; dir = dirname(dir)) {
      try {
        const path = join(dir, "node_modules/@ham2k/extension-sdk/package.json")
        const { version } = JSON.parse(readFileSync(path, "utf8"))
        if (version) return `^${version}`
      } catch {
        // Not here; walk up to the next node_modules.
      }
      if (dirname(dir) === dir) break
    }
  }
  return "latest"
}

/// What the project's package.json has to say for the build, the packer and
/// the typecheck to run.
const projectPackage = {
  name: key,
  version: "0.1.0",
  private: true,
  type: "module",
  scripts: {
    build: "node build.mjs",
    pack: "h2kext-pack build",
    typecheck: "tsc --noEmit",
  },
  dependencies: {
    "@ham2k/extension-sdk": sdkRange(dir),
  },
  devDependencies: {
    "@ham2k/extension-tools": `^${toolsVersion}`,
    esbuild: "^0.25.0",
    typescript: "^5.6.0",
  },
}

const files = {
  "manifest.json": `${JSON.stringify(
    {
      key,
      name,
      version: "0.1.0",
      description: `${name}, an extension for the Ham2K Logger`,
      category: "dashboard",
      api: H2KEXT_API_VERSION,
      icon: "hand-wave-outline",
      // The Extensions list reads this without evaluating any bundle, and the
      // Add-Panel route shows only what declares `panel`. Undeclared, a panel
      // extension installs and then cannot be found or switched on.
      hooks: ["panel"],
      sharedDependencies: SCAFFOLD_SHARED_DEPENDENCIES,
    },
    null,
    2,
  )}\n`,

  "build.mjs": EXAMPLE_BUILD_SCRIPT,

  "src/index.ts": `// ${name} — a panel that says hello.
//
// Everything here is the minimum: one hook, one descriptor, one render. See
// node_modules/@ham2k/extension-sdk/AGENTS.md for what to read next.

import { defineExtension } from '@ham2k/extension-sdk'
import type { HookContext, PanelContent, PanelDescriptor, PanelHook, PanelRenderArgs } from '@ham2k/extension-sdk'

import manifest from '../manifest.json'

const HelloPanel: PanelHook = {
  /// What the operator sees when choosing a panel to place.
  async getPanels(_args: Record<string, never>, _ctx: HookContext): Promise<PanelDescriptor[]> {
    return [{ key: 'hello', title: ${JSON.stringify(name)}, description: 'A panel that says hello', icon: 'hand-wave-outline' }]
  },

  /// What the pane shows. A panel returns CONTENT, never widgets — which is
  /// what keeps extensions out of the app's UI toolkit.
  ///
  /// The method is \`render\`, not \`renderPanel\`: the host routes to the hook by
  /// its registered key and then calls this by name, so a near-miss is a panel
  /// that installs, activates, and then renders nothing.
  async render(_args: PanelRenderArgs, _ctx: HookContext): Promise<PanelContent> {
    return { kind: 'markdown', content: '# Hello, World!' }
  },
}

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook('panel', { key: '${key}', hook: HelloPanel })
  },
})
`,

  "tsconfig.json": `${JSON.stringify(
    {
      compilerOptions: {
        target: "ES2020",
        module: "ESNext",
        moduleResolution: "bundler",
        lib: ["ES2020"],
        strict: true,
        noEmit: true,
        skipLibCheck: true,
        resolveJsonModule: true,
      },
      include: ["src/**/*.ts"],
    },
    null,
    2,
  )}\n`,

  // The whole point of the file. Claude Code and its siblings read a project's
  // AGENTS.md before they touch anything, so this is what carries the hook
  // reference, the sandbox's limits and the manifest's shape into the session
  // — none of which anyone would think to go looking for in node_modules.
  "AGENTS.md": `# ${name}

An extension for the Ham2K Logger. How to write one, what the hooks are, and
what the sandbox will and will not let you do:

@node_modules/@ham2k/extension-sdk/AGENTS.md
`,

  ".gitignore": "node_modules/\nbuild/\n*.h2kext\n",
}

// Reported together rather than one per run: a scaffold that stops at the
// first collision has already written half a project, and the second attempt
// then collides with its own output.
const packagePath = join(dir, "package.json")
const currentPackage = await readFile(packagePath, "utf8").then(
  (text) => {
    try {
      return JSON.parse(text)
    } catch (e) {
      // Read BEFORE anything is written: parsed after the write loop, this
      // threw a raw SyntaxError over six files already on disk, and the retry
      // then collided with them.
      console.error(`h2kext-init: ${packagePath} is not readable JSON (${e.message}) — nothing written`)
      process.exit(1)
    }
  },
  () => ({}),
)

// `null`, `[]` and `"text"` all parse, and none of them is something to merge
// into — reached at the end, each is a raw TypeError over six written files.
if (currentPackage === null || typeof currentPackage !== "object" || Array.isArray(currentPackage)) {
  console.error(`h2kext-init: ${packagePath} is not a package description — nothing written`)
  process.exit(1)
}

// `access`, not a read: a directory where a file should go, or one this
// process cannot read, is something in the way — treated as absent, it becomes
// a write loop that fails half-way through.
const existing = []
for (const path of Object.keys(files)) {
  if (
    await access(join(dir, path)).then(
      () => true,
      () => false,
    )
  )
    existing.push(path)
}
if (existing.length) {
  const where = relative(process.cwd(), dir)
  console.error(
    `h2kext-init: ${where.startsWith("..") ? dir : where || "."} already holds ${existing.join(", ")} — ` +
      "nothing written. Scaffold into an empty directory with --dir.",
  )
  process.exit(1)
}

for (const [path, content] of Object.entries(files)) {
  await mkdir(dirname(join(dir, path)), { recursive: true })
  await writeFile(join(dir, path), content)
}

// `package.json` is the one file that gets merged rather than refused, because
// the obvious way to reach this command already made one:
// `npm i -D @ham2k/extension-tools && npx h2kext-init …`. Refusing there would
// turn the documented path into the broken one.
//
// Filled in key by key, never overwritten: what the author already declared —
// their own name for the project, a version of esbuild they chose — is theirs.
for (const [field, value] of Object.entries(projectPackage)) {
  if (typeof value !== "object") currentPackage[field] ??= value
  else for (const [name, entry] of Object.entries(value)) (currentPackage[field] ??= {})[name] ??= entry
}
await writeFile(packagePath, `${JSON.stringify(currentPackage, null, 2)}\n`)

console.log(`${key} — ${name}

  ${[...Object.keys(files), "package.json"].join("\n  ")}

Next:
  npm install
  npm run build && npm run pack`)
