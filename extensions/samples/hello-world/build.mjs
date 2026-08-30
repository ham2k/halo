// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Builds this sample the way a third party builds an extension: esbuild to one
// IIFE, dependencies INLINED, and no shared-libs plugin — the host promises
// nothing about which libraries it carries unless the manifest declares them.
//
//   node build.mjs && node ../../tools/h2kext-pack.mjs build
//
// Everything the packer then checks is documented in
// docs/extensions/distribution.md.

import { build } from 'esbuild'
import { copyFile, mkdir } from 'node:fs/promises'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const here = dirname(fileURLToPath(import.meta.url))
const out = join(here, 'build')
await mkdir(out, { recursive: true })

await build({
  entryPoints: [join(here, 'src/index.ts')],
  bundle: true,
  format: 'iife',
  platform: 'neutral',
  mainFields: ['module', 'main'],
  target: 'es2020',
  outfile: join(out, 'index.js'),
  alias: {
    // The SDK is a workspace path here. Outside this repo it is an npm
    // dependency, and this alias goes away.
    '@ham2k/halo-extension-sdk': join(here, '../../sdk/src/index.ts'),
    // This one does NOT go away, and every extension author hits it: the SDK
    // reaches liquidjs for its templating, and liquidjs's `main`/`module` are
    // its NODE builds, which import fs/path/stream. `platform: 'neutral'`
    // ignores the `browser` field that would have picked the right one, so
    // without this the build fails on five unresolvable node built-ins before
    // tree-shaking ever gets a chance to drop the unused half.
    liquidjs: join(here, '../../node_modules/liquidjs/dist/liquid.browser.mjs'),
  },
  logLevel: 'warning',
})

await copyFile(join(here, 'manifest.json'), join(out, 'manifest.json'))
console.log('built', join(out, 'index.js'))
