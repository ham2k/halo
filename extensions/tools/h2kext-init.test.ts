// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// The scaffold (HALO-452). What it writes has to be a project that BUILDS —
// an author, or the agent working for one, starts from this and reads the
// error it produces as a fact about their own code.

import { test } from "node:test"
import assert from "node:assert/strict"
import { execFile } from "node:child_process"
import { mkdir, mkdtemp, readdir, readFile, writeFile } from "node:fs/promises"
import { build } from "esbuild"
import { tmpdir } from "node:os"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"
import { promisify } from "node:util"
import { format, getFileInfo, version as prettierVersion } from "prettier"

// @ts-ignore — deliberately plain JS, like the modules it tests.
import { loadHostSharedVersions } from "../build-config.mjs"
import { buildExtension } from "./h2kext-build.mjs"
import { SCAFFOLD_SHARED_DEPENDENCIES, sharedModulesFor, validateManifest } from "./h2kext.mjs"

const run = promisify(execFile)
const here = dirname(fileURLToPath(import.meta.url))
const init = join(here, "h2kext-init.mjs")
const sdkDir = join(here, "../sdk")

/// Driven as the command, not as a module: it IS a command, and its argument
/// parsing and its refusals are most of what it does.
async function init_(args: string[], dir: string) {
  return await run("node", [init, ...args, "--dir", dir])
}

async function emptyDir() {
  return await mkdtemp(join(tmpdir(), "h2kext-init-test-"))
}

async function readJson(dir: string, name: string) {
  return JSON.parse(await readFile(join(dir, name), "utf8"))
}

test("scaffolds a manifest the packer accepts", async () => {
  const dir = await emptyDir()
  await init_(["w7abc-notes"], dir)

  const manifest = await readJson(dir, "manifest.json")
  assert.equal(manifest.key, "w7abc-notes")
  // The same validation the packer runs, so a scaffold can never produce a
  // project whose very first `npm run pack` refuses it.
  assert.deepEqual(validateManifest(manifest), [])
})

test("the display name comes from the key, and --name overrides it", async () => {
  const dir = await emptyDir()
  await init_(["w7abc-my-notes"], dir)
  assert.equal((await readJson(dir, "manifest.json")).name, "My Notes")

  const named = await emptyDir()
  await init_(["w7abc-my-notes", "--name", "Station Notes"], named)
  assert.equal((await readJson(named, "manifest.json")).name, "Station Notes")
})

test("the extension key reaches the source, not just the manifest", async () => {
  const dir = await emptyDir()
  await init_(["w7abc-notes"], dir)
  const source = await readFile(join(dir, "src/index.ts"), "utf8")
  // A hook registered under a key the manifest doesn't carry is an extension
  // that loads and then never answers for anything.
  assert.match(source, /registerHook\("panel", \{ key: "w7abc-notes"/)
})

test("AGENTS.md points at the reference in the installed SDK", async () => {
  const dir = await emptyDir()
  await init_(["w7abc-notes"], dir)
  // The line an agent follows. Without it the docs sit unread in node_modules
  // and the manifest gets guessed, which is the whole failure this scaffold
  // exists to prevent.
  assert.match(await readFile(join(dir, "AGENTS.md"), "utf8"), /@node_modules\/@ham2k\/extension-sdk\/AGENTS\.md/)
})

test("refuses a key that is not '<callsign>-<name>', writing nothing", async () => {
  const dir = await emptyDir()
  await assert.rejects(init_(["notes"], dir), (e: any) => {
    assert.match(e.stderr, /must be '<callsign>-<name>'/)
    return true
  })
  await assert.rejects(readFile(join(dir, "manifest.json"), "utf8"))
})

test("refuses to overwrite, and names everything in the way at once", async () => {
  const dir = await emptyDir()
  await init_(["w7abc-notes"], dir)
  const before = await readFile(join(dir, "src/index.ts"), "utf8")

  await assert.rejects(init_(["w7abc-other"], dir), (e: any) => {
    // Every collision, not the first: a scaffold that stopped at one would
    // already have written half a project, and the retry then collides with
    // its own output.
    assert.match(e.stderr, /manifest\.json.*src\/index\.ts.*AGENTS\.md/)
    return true
  })
  assert.equal(await readFile(join(dir, "src/index.ts"), "utf8"), before)
})

test("adds to an existing package.json without replacing what is declared", async () => {
  const dir = await emptyDir()
  // `npm i -D @ham2k/extension-tools && npx h2kext-init …` is the documented
  // route here, and it has already written a package.json by this point.
  await writeFile(
    join(dir, "package.json"),
    JSON.stringify({
      name: "my-own-name",
      devDependencies: { esbuild: "^0.24.0" },
    }),
  )

  await init_(["w7abc-notes"], dir)

  const pkg = await readJson(dir, "package.json")
  assert.equal(pkg.name, "my-own-name")
  assert.equal(pkg.devDependencies.esbuild, "^0.24.0")
  assert.equal(pkg.scripts.build, "node build.mjs")
  assert.ok(pkg.dependencies["@ham2k/extension-sdk"])
})

/// Everything the scaffold wrote, as paths relative to the project, so a
/// template added later is covered without anyone remembering to list it.
async function scaffolded(dir: string, prefix = ""): Promise<string[]> {
  const found: string[] = []
  for (const entry of await readdir(join(dir, prefix), { withFileTypes: true })) {
    const path = prefix ? `${prefix}/${entry.name}` : entry.name
    if (entry.isDirectory()) found.push(...(await scaffolded(dir, path)))
    else found.push(path)
  }
  return found
}

test("what it scaffolds already satisfies the .prettierrc.json it scaffolds", async () => {
  // A long display name, because the scaffolded source carries it: on one
  // line the panel descriptor passes the width at around 54 characters of
  // name, and the short name every other test uses would never show it.
  const dir = await emptyDir()
  await init_(["w7abc-notes", "--name", "Station Notes And Logs For The Whole Weekend Contest Thing"], dir)

  // The author's first `npm run format:check` runs on files nobody has
  // touched. A template written in another style fails it there, and the
  // reflex fix is to delete the config — so the scaffold's own output is what
  // pins the style, not the config file alone.
  const options = JSON.parse(await readFile(join(dir, ".prettierrc.json"), "utf8"))
  const files = await scaffolded(dir)
  // Derived, never listed — but a derivation that silently found nothing
  // would assert nothing at all.
  assert.ok(files.includes("src/index.ts") && files.includes(".prettierrc.json"), files.join(", "))

  let checked = 0
  for (const name of files) {
    // .gitignore has no parser, and Prettier skips it rather than failing.
    const { inferredParser } = await getFileInfo(join(dir, name))
    if (!inferredParser) continue
    const source = await readFile(join(dir, name), "utf8")
    assert.equal(source, await format(source, { ...options, filepath: join(dir, name) }), `${name} is not in the style the scaffold asks for`)
    checked++
  }
  assert.ok(checked >= files.length - 1, `only ${checked} of ${files.length} scaffolded files had a parser`)
})

test("the Prettier it scaffolds is the one the templates are checked against", async () => {
  const dir = await emptyDir()
  await init_(["w7abc-notes"], dir)

  // The test above proves the templates against the Prettier installed HERE.
  // A scaffolded range that admits some other version moves the formatting
  // the author gets away from the formatting this suite checked, and the
  // failure lands on them, on untouched files.
  // A tilde range and nothing else, compared by its minor: the point is that
  // the author cannot be moved onto a Prettier this suite never formatted
  // with, and Prettier restyles code in a minor.
  const range: string = (await readJson(dir, "package.json")).devDependencies.prettier
  assert.match(range, /^~\d+\.\d+\.\d+$/, "a range wider than a patch line puts the author on an unchecked Prettier")
  const minor = (v: string) => v.replace(/^[~^]/, "").split(".").slice(0, 2).join(".")
  assert.equal(minor(range), minor(prettierVersion), `the suite formats with Prettier ${prettierVersion}, the scaffold asks for ${range}`)
})

test("an existing Prettier config is left in charge, and said so", async () => {
  const dir = await emptyDir()
  // Prettier reads the first config it finds and a package.json `prettier`
  // key outranks a .prettierrc.json beside it — so writing one would leave a
  // file nothing reads, and an author whose own style is silently ignored.
  await writeFile(join(dir, "package.json"), JSON.stringify({ name: "mine", prettier: { semi: true } }))

  const { stdout } = await init_(["w7abc-notes"], dir)

  await assert.rejects(readFile(join(dir, ".prettierrc.json"), "utf8"))
  assert.match(stdout, /No \.prettierrc\.json written/)
  assert.deepEqual((await readJson(dir, "package.json")).prettier, { semi: true })
})

test("the scaffolded sharedDependencies are ones this host carries, at versions it satisfies", async () => {
  const offered = sharedModulesFor(1)
  const carried = await loadHostSharedVersions()

  for (const [pkg, range] of Object.entries(SCAFFOLD_SHARED_DEPENDENCIES)) {
    assert.ok(offered.includes(pkg), `${pkg} is not a module the host offers`)
    // Only the caret major is checked, which is the grain the range is written
    // at. A minor bump in the app is routine; a MAJOR one leaves every
    // scaffolded project declaring a range the app refuses at install, and the
    // author reads that as a mistake in code they just generated.
    const [major] = (range as string).replace("^", "").split(".")
    assert.equal(carried[pkg].split(".")[0], major, `${pkg} ${range} vs the host's ${carried[pkg]}`)
  }
})

test("the scaffold declares exactly what the SDK barrel forces it to", async () => {
  const dir = await emptyDir()
  await init_(["w7abc-notes"], dir)

  // Asked of the BUNDLER, not restated from the scaffold. Importing anything
  // at all from the SDK resolves these before tree-shaking runs, so they are a
  // starting condition rather than a choice the author makes later — and the
  // day a barrel module gains a value import of a ninth, every scaffolded
  // project's first `npm run build` breaks on code its author never wrote.
  const manifest = await readJson(dir, "manifest.json")
  await writeFile(join(dir, "manifest.json"), JSON.stringify({ ...manifest, sharedDependencies: {} }))

  const forced = new Set<string>()
  try {
    await buildExtension(build, {
      dir,
      alias: { "@ham2k/extension-sdk": join(sdkDir, "src/index.ts") },
      // The eight refusals are the test's subject, not a failure to report:
      // printed, they read as a broken suite in the gate's log.
      logLevel: "silent",
    })
  } catch (e: any) {
    for (const error of e.errors ?? []) {
      const named = /'([^']+)' is provided by the Ham2K extension host/.exec(error.text)
      if (named) forced.add(named[1])
    }
  }

  assert.ok(forced.size > 0, "an undeclared build should have named the modules the barrel reaches")
  assert.deepEqual([...forced].sort(), Object.keys(SCAFFOLD_SHARED_DEPENDENCIES).sort())
})

test("pins the SDK by the SDK's own version, never the tools' one", async () => {
  const dir = await emptyDir()
  // Two separately versioned packages. Answered with the running tools'
  // version, a tools-only patch scaffolds `^0.1.1` of an SDK with no such
  // release and the very next `npm install` dies with ETARGET — and the
  // opposite pairing installs an old SDK behind new docs, silently.
  //
  // Installed as the REAL package.json with a version swapped in, never as a
  // hand-written `{name, version}`. A minimal stand-in has no `exports` map,
  // and `exports` is the whole difficulty here: it decides whether the file
  // can be reached at all. A fake without one passes against a reader that
  // cannot read the real thing.
  await mkdir(join(dir, "node_modules/@ham2k/extension-sdk"), { recursive: true })
  const real = JSON.parse(await readFile(join(sdkDir, "package.json"), "utf8"))
  await writeFile(join(dir, "node_modules/@ham2k/extension-sdk/package.json"), JSON.stringify({ ...real, version: "0.4.2" }))

  await init_(["w7abc-notes"], dir)
  assert.equal((await readJson(dir, "package.json")).dependencies["@ham2k/extension-sdk"], "^0.4.2")
})

test("reads the version out of an SDK whose exports map does not offer it", async () => {
  const dir = await emptyDir()
  // @ham2k/extension-sdk 0.1.0 is published with an `exports` map naming only
  // ".", and an undeclared subpath is REFUSED — `require`ing that package's own
  // package.json throws ERR_PACKAGE_PATH_NOT_EXPORTED for a package sitting
  // right there in node_modules. Every author who installed the SDK before the
  // map gained `./package.json` still has one, so a reader that resolves rather
  // than reads answers `latest` for all of them, silently.
  await mkdir(join(dir, "node_modules/@ham2k/extension-sdk"), { recursive: true })
  const real = JSON.parse(await readFile(join(sdkDir, "package.json"), "utf8"))
  await writeFile(
    join(dir, "node_modules/@ham2k/extension-sdk/package.json"),
    JSON.stringify({
      ...real,
      version: "0.1.0",
      exports: { ".": { types: "./dist/index.d.ts", default: "./dist/index.js" } },
    }),
  )

  await init_(["w7abc-notes"], dir)
  assert.equal((await readJson(dir, "package.json")).dependencies["@ham2k/extension-sdk"], "^0.1.0")
})

test("finds the SDK installed above the project, as a workspace puts it", async () => {
  // npm hoists, so a project inside a workspace has its dependencies one or
  // more directories up rather than beside it.
  const root = await emptyDir()
  await mkdir(join(root, "node_modules/@ham2k/extension-sdk"), { recursive: true })
  const real = JSON.parse(await readFile(join(sdkDir, "package.json"), "utf8"))
  await writeFile(join(root, "node_modules/@ham2k/extension-sdk/package.json"), JSON.stringify({ ...real, version: "0.3.1" }))

  const dir = join(root, "packages", "my-extension")
  await mkdir(dir, { recursive: true })
  await init_(["w7abc-notes"], dir)
  assert.equal((await readJson(dir, "package.json")).dependencies["@ham2k/extension-sdk"], "^0.3.1")
})

test("refuses a package.json that is not a package description, writing nothing", async () => {
  const dir = await emptyDir()
  // `null` parses. Merged into at the end of the run, it is a raw TypeError
  // over six files already written — the half-scaffolded state whose retry the
  // collision check then blocks.
  await writeFile(join(dir, "package.json"), "null")

  await assert.rejects(init_(["w7abc-notes"], dir), (e: any) => {
    assert.match(e.stderr, /is not a package description/)
    return true
  })
  await assert.rejects(readFile(join(dir, "manifest.json"), "utf8"))
})

test("counts something unreadable in the way as a collision", async () => {
  const dir = await emptyDir()
  // A directory named AGENTS.md is not an absent AGENTS.md. Read to decide
  // existence, it looks missing, and the write loop then fails part-way.
  await mkdir(join(dir, "AGENTS.md"))

  await assert.rejects(init_(["w7abc-notes"], dir), (e: any) => {
    assert.match(e.stderr, /already holds AGENTS\.md/)
    return true
  })
  await assert.rejects(readFile(join(dir, "manifest.json"), "utf8"))
})
