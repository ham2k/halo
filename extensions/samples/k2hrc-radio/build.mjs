// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Builds this sample IN THIS REPO, where the SDK and the tools are workspace
// paths. The copy that ships inside `@ham2k/extension-sdk` carries the plain
// four-line version instead (`EXAMPLE_BUILD_SCRIPT`), which is what an author
// outside this repo writes — and what `h2kext-init` scaffolds.

import { build } from 'esbuild'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

import { buildExtension } from '../../tools/h2kext-build.mjs'

const here = dirname(fileURLToPath(import.meta.url))

await buildExtension(build, {
  dir: here,
  alias: { '@ham2k/extension-sdk': join(here, '../../sdk/src/index.ts') },
})

console.log('built', join(here, 'build/index.js'))
