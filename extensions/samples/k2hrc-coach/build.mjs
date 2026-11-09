// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// Builds this sample the way a third party builds an extension: through the
// SDK's build preset, which carries the esbuild settings the runtime requires
// and rewrites the libraries `manifest.json` declares into lookups on the
// host's single copy.
//
//   node build.mjs && node ../../tools/h2kext-pack.mjs build
//
// Everything the packer then checks is documented in
// docs/extensions/packaging.md.

import { build } from "esbuild"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"

import { buildExtension } from "../../tools/h2kext-build.mjs"

const here = dirname(fileURLToPath(import.meta.url))

await buildExtension(build, {
  dir: here,
  alias: {
    // The SDK is a workspace path here. Outside this repo it is an npm
    // dependency and this alias goes away — as does the relative import
    // above, which becomes '@ham2k/extension-tools'.
    "@ham2k/extension-sdk": join(here, "../../sdk/src/index.ts"),
  },
})

console.log("built", join(here, "build/index.js"))
