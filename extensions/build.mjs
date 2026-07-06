// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Bundles the kernel and every extension into single-file IIFE bundles for the
// QuickJS runtime, and writes an index.json the Dart host uses to know what
// to load. Output goes into the Flutter app's assets.

import { build } from 'esbuild'
import { mkdir, writeFile } from 'node:fs/promises'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = dirname(fileURLToPath(import.meta.url))
const outDir = resolve(root, '../app/assets/extensions')

const bundles = [
  { key: 'kernel', entry: 'sdk/src/kernel.ts', kind: 'kernel' },
  { key: 'adif', entry: 'core/adif/src/index.ts', kind: 'extension' },
  { key: 'radio-commands', entry: 'core/radio-commands/src/index.ts', kind: 'extension' },
  { key: 'hamdb', entry: 'lookups/hamdb/src/index.ts', kind: 'extension' },
  { key: 'qrz', entry: 'lookups/qrz/src/index.ts', kind: 'extension' },
  { key: 'pota', entry: 'activities/pota/src/index.ts', kind: 'extension' },
]

await mkdir(outDir, { recursive: true })

for (const bundle of bundles) {
  const result = await build({
    entryPoints: [join(root, bundle.entry)],
    bundle: true,
    format: 'iife',
    platform: 'neutral',
    mainFields: ['module', 'main'],
    target: 'es2020',
    outfile: join(outDir, `${bundle.key}.js`),
    alias: { '@ham2k/polo-sdk': join(root, 'sdk/src/index.ts') },
    logLevel: 'warning',
    metafile: true,
  })
  const bytes = Object.values(result.metafile.outputs)[0].bytes
  console.log(`${bundle.key}.js — ${(bytes / 1024).toFixed(1)} KB`)
}

await writeFile(
  join(outDir, 'index.json'),
  JSON.stringify(
    {
      kernel: 'kernel.js',
      extensions: bundles.filter((b) => b.kind === 'extension').map((b) => ({ key: b.key, file: `${b.key}.js` })),
    },
    null,
    2,
  ),
)
console.log(`index.json — ${bundles.length - 1} extensions`)
