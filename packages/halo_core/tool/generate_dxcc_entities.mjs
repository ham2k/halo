// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Regenerates lib/src/ham/dxcc_entities.dart from @ham2k/lib-dxcc-data, the
// same table the lookup pipeline's callsign annotation reads its `flag` from
// (extensions/sdk/src/dxcc.ts). Run from the repo root:
//
//   node packages/halo_core/tool/generate_dxcc_entities.mjs
//
// Resolved via extensions/node_modules, where the package is already
// installed — same arrangement as generate_entity_locations.mjs.

import { createRequire } from 'node:module'
import { readFileSync, writeFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const here = dirname(fileURLToPath(import.meta.url))
const repoRoot = join(here, '..', '..', '..')
const require = createRequire(join(repoRoot, 'extensions', 'package.json'))

const dxccVersion = JSON.parse(readFileSync(join(repoRoot, 'extensions', 'node_modules', '@ham2k', 'lib-dxcc-data', 'package.json'), 'utf8')).version

const { DXCC_BY_PREFIX, DXCC_BY_CODE } = require('@ham2k/lib-dxcc-data')

const quote = (s) => `'${s.replace(/\\/g, '\\\\').replace(/'/g, "\\'")}'`

const byCode = Object.entries(DXCC_BY_CODE)
  .map(([code, e]) => [Number(code), e])
  .sort(([a], [b]) => a - b)
for (const [code, e] of byCode) {
  if (!Number.isInteger(code)) throw new Error(`non-integer DXCC code key: ${code}`)
  if (typeof e.entityPrefix !== 'string' || e.entityPrefix === '') throw new Error(`DXCC ${code} has no entityPrefix`)
}

const codeByPrefix = Object.entries(DXCC_BY_PREFIX)
  .sort(([a], [b]) => (a < b ? -1 : 1))
  .map(([prefix, e]) => {
    if (!Number.isInteger(e.dxccCode)) throw new Error(`prefix ${prefix} has no integer dxccCode`)
    return `  ${quote(prefix)}: ${e.dxccCode},`
  })
const prefixByCode = byCode.map(([code, e]) => `  ${code}: ${quote(e.entityPrefix)},`)
const flagByCode = byCode.filter(([, e]) => typeof e.flag === 'string' && e.flag !== '').map(([code, e]) => `  ${code}: ${quote(e.flag)},`)

// A renamed export throws above on its own; a renamed `flag` FIELD would pass
// the filter with zero rows and write an empty table that compiles.
if (codeByPrefix.length === 0 || prefixByCode.length === 0 || flagByCode.length === 0) {
  throw new Error(`lib-dxcc-data read empty (${codeByPrefix.length} prefixes, ${prefixByCode.length} codes, ${flagByCode.length} flags)`)
}

const out = `// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// GENERATED FILE — do not edit by hand.
// Regenerate with: node packages/halo_core/tool/generate_dxcc_entities.mjs
// Source: @ham2k/lib-dxcc-data ${dxccVersion}.
//
// The DXCC entity table, as far as a stored contact needs it: which entity a
// stored \`entityPrefix\` or \`dxccCode\` names, and that entity's flag. HaLo's
// lookup pipeline stores the entity prefix and the flag on every guess it
// writes (extensions/core/lookups/src/annotate.ts), but a record written
// elsewhere does not: app-polo derives the flag at render time from the entity
// prefix and never stores it, and an ADIF record carries its DXCC code. Read by
// \`Qso.theirEntityPrefix\`/\`Qso.theirFlag\` and the ADIF importer.
//
// Entities lib-dxcc-data has no flag for (most deleted entities, and a few
// live ones such as Märket) are absent from the flag table only.

/// Numeric DXCC code by entity prefix (e.g. 'K' → 291). Every key is an entity
/// prefix, so membership here is what tells one from a WPX prefix ("W1").
const Map<String, int> dxccCodeByEntityPrefix = {
${codeByPrefix.join('\n')}
};

/// Entity prefix by numeric DXCC code (e.g. 291 → 'K').
const Map<int, String> entityPrefixByDxccCode = {
${prefixByCode.join('\n')}
};

/// Flag emoji by numeric DXCC code (e.g. 291 → 🇺🇸).
const Map<int, String> entityFlagByDxccCode = {
${flagByCode.join('\n')}
};
`

const outPath = join(repoRoot, 'packages', 'halo_core', 'lib', 'src', 'ham', 'dxcc_entities.dart')
writeFileSync(outPath, out)
console.log(`Wrote ${outPath}: ${codeByPrefix.length} prefixes, ${prefixByCode.length} codes, ${flagByCode.length} flags`)
