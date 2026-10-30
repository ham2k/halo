#!/usr/bin/env node
// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// Packages an extension into a `.h2kext` a user can install
// (HALO-422, docs/extensions/packaging.md).
//
//   node tools/h2kext-pack.mjs <directory> [-o out.h2kext]
//
// The directory holds a built `index.js`, a `manifest.json`, and optionally an
// `assets/` folder. Nothing here compiles anything — see h2kext.mjs.

import { pack, PackError, H2KEXT_API_VERSION, RESERVED_PREFIX, settingsReviewReasons } from "./h2kext.mjs"

const args = process.argv.slice(2)

if (args.length === 0 || args.includes("--help") || args.includes("-h")) {
  console.log(`Package an extension directory into a .h2kext bundle.

  h2kext-pack <directory> [-o <out.h2kext>] [--force-name]

The directory must contain:
  manifest.json   key, name, version, description, category, api (${H2KEXT_API_VERSION})
  index.js        your extension, built
  assets/         optional

The key is '<yourcallsign>-<name>' — e.g. ki2d-my-clock. The callsign is a
namespace you already have, globally unique, so two authors who never met
cannot collide.

  --force-name    waive the naming convention (Ham2K's own builds, which
                  ship bare keys and the reserved '${RESERVED_PREFIX}-' prefix)

Defaults to <key>-<version>.h2kext in the working directory.`)
  process.exit(args.length === 0 ? 1 : 0)
}

// Walked by index rather than matched by value: `args.indexOf(a)` finds the
// FIRST occurrence, so `-o foo foo` mistook the output path for the directory.
const forceName = args.includes("--force-name")
let dir
let outPath
for (let i = 0; i < args.length; i++) {
  if (args[i] === "-o") {
    outPath = args[++i]
  } else if (!args[i].startsWith("-") && dir === undefined) {
    dir = args[i]
  }
}

if (!dir) {
  console.error("h2kext-pack: name the directory to package")
  process.exit(1)
}

try {
  const result = await pack(dir, { outPath, forceName })
  const assets = result.files.length - 2
  console.log(`${result.outPath}`)
  console.log(`  ${result.manifest.key} ${result.manifest.version} — ${result.manifest.name}`)
  console.log(`  ${assets} asset${assets === 1 ? "" : "s"}`)
  if (result.manifest.domains?.length) {
    // Named on the way out, because this is the one part of the manifest the
    // person installing it will be asked to approve.
    console.log(`  may reach: ${result.manifest.domains.join(", ")}`)
  }
  if (result.manifest.webSockets?.length) {
    console.log(`  may hold connections to: ${result.manifest.webSockets.join(", ")}`)
  }
  // Not a refusal: placements beyond the usual are allowed, once an admin has
  // looked. Said now so a publish that waits in the queue is no surprise.
  for (const reason of settingsReviewReasons(result.manifest)) {
    console.log(`  held for review on the catalog: ${reason}`)
  }
} catch (e) {
  if (e instanceof PackError) {
    console.error(`h2kext-pack: ${dir} is not ready to package:\n${e.message}`)
    process.exit(1)
  }
  throw e
}
