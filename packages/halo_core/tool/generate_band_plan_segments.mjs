// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Regenerates lib/src/ham/band_plan_segments.dart from @ham2k/lib-operation-data
// (HALO-32). Run from the repo root, after `npm install` in extensions/ picks
// up a new version:
//
//   node packages/halo_core/tool/generate_band_plan_segments.mjs
//
// The band-plan segment table isn't part of the package's public API (only
// modeForFrequency() is), so — same situation and same fix as
// generate_entity_locations.mjs's entityRegionLocations — it's parsed out of
// the bundled source (`var bandPlans_default = {...}`) via
// extensions/node_modules, where the package is already installed. The
// bundle isn't strict JSON (unquoted keys, `false` in place of some `mode`s,
// `2e3`-style numbers), so it's evaluated as JS rather than JSON.parse'd.
//
// The npm package's data is treated as authoritative: this script does not
// hand-correct known-bad entries (see the warning below) — it only reports
// them, so a re-run always reflects exactly what the package ships.

import { createRequire } from 'node:module'
import { readFileSync, writeFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const here = dirname(fileURLToPath(import.meta.url))
const repoRoot = join(here, '..', '..', '..')
const require = createRequire(join(repoRoot, 'extensions', 'package.json'))

// package.json subpaths aren't in these packages' `exports` maps, so read
// the version stamp straight off the node_modules directory instead — same
// as generate_entity_locations.mjs's pkgVersion.
const pkgVersion = JSON.parse(
  readFileSync(join(repoRoot, 'extensions', 'node_modules', '@ham2k', 'lib-operation-data', 'package.json'), 'utf8'),
).version
const bundlePath = require.resolve('@ham2k/lib-operation-data')
const bundleSource = readFileSync(bundlePath, 'utf8')

const match = bundleSource.match(/var bandPlans_default = (\{[\s\S]*?\n\});/)
if (!match) throw new Error('bandPlans_default not found in lib-operation-data bundle')
// The inlined object is valid JS (unquoted keys, `2e3` numbers, `false`
// standing in for some `mode`s) but not valid JSON — evaluate it as JS.
const bandPlans = new Function(`return (${match[1]})`)()

const fmt = (n) => {
  if (!Number.isFinite(n)) throw new Error(`non-finite frequency: ${n}`)
  return `${n}`
}

const lines = []
let total = 0
let warned = 0
for (const [band, info] of Object.entries(bandPlans.bands)) {
  lines.push(`  // ${band}`)
  for (const segment of info.segments ?? []) {
    const mhz = segment.mhz
    if (!Array.isArray(mhz) || mhz.length < 2) continue
    const [lo, hi] = mhz
    if (hi < lo) {
      console.warn(`⚠ ${band} "${segment.name}": mhz [${lo}, ${hi}] has hi < lo — dead, never matches a frequency`)
      warned++
    }
    if (segment.entities) {
      // Silently carrying this through as unscoped (regions/countries both
      // empty) would be a real correctness regression, not just missing
      // data: modeForFrequency would treat the segment as applying to every
      // operator, including ones it doesn't restrict to. Fail loudly instead
      // of shipping that — the source data has never used `entities` so far
      // (checked at HALO-52 time), so this is a real "come update the
      // generator" signal, not busywork.
      throw new Error(
        `${band} "${segment.name}": scoped by "entities" (${JSON.stringify(segment.entities)}), which this generator does not carry through. ` +
          'Silently treating it as unscoped would misapply the segment to every operator — extend the generator (and radio.dart\'s ' +
          '_BandPlanSegment/modeForFrequency) to carry an `entities` list through before regenerating.',
      )
    }
    const mode = typeof segment.mode === 'string' ? `'${segment.mode}'` : 'null'
    const priority = segment.priority ?? 0
    const regions = (segment.regions ?? []).join(', ')
    const countries = (segment.countries ?? []).map((c) => `'${c}'`).join(', ')
    lines.push(
      `  (loKHz: ${fmt(lo)}, hiKHz: ${fmt(hi)}, mode: ${mode}, priority: ${priority}, regions: [${regions}], countries: [${countries}]),`,
    )
    total++
  }
}

const out = `// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// GENERATED FILE — do not edit by hand.
// Regenerate with: node packages/halo_core/tool/generate_band_plan_segments.mjs
// Source: @ham2k/lib-operation-data ${pkgVersion} (bandPlans data, not part of
// the package's public API — parsed out of its bundle, see the generator).
//
// One entry per band-plan segment, read by modeForFrequency (radio.dart).
// \`regions\`/\`countries\` carry the source's own restriction lists through
// as-is (HALO-52) — empty on both means the segment applies everywhere. The
// source's \`entities\` restriction (DXCC-entity-code scoped, distinct from
// \`countries\`' ISO codes) isn't carried through — the generator refuses to
// run (rather than silently treating it as unscoped) if a future data update
// ever adds one; see its \`segment.entities\` check.
//
// The source data is treated as authoritative and carried through as-is,
// including known issues — e.g. 12m's FT4 segment ships as mhz: [24919,
// 23922] (hi < lo, so it never matches any frequency). Re-run the generator
// above to see the current list of these.

const List<({double loKHz, double hiKHz, String? mode, int priority, List<int> regions, List<String> countries})>
    bandPlanModeSegments = [
${lines.join('\n')}
];
`

const outPath = join(repoRoot, 'packages', 'halo_core', 'lib', 'src', 'ham', 'band_plan_segments.dart')
writeFileSync(outPath, out)
console.log(`Wrote ${outPath}: ${total} segments${warned ? ` (${warned} dead: hi < lo — see warnings above)` : ''}`)
