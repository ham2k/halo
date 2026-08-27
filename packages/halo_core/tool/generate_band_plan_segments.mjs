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
    // `mode: false` is the source's "amateurs are not allocated this here"
    // marker, distinct from its `mode: null` ("no single mode conventionally
    // used here") — folding the two together loses the whole out-of-band
    // warning, so it carries through as radio.dart's `outOfBandMode`
    // sentinel, spelled as a literal to keep this file import-free.
    //
    // A real mode named 'OOB' would be indistinguishable from that sentinel,
    // and would turn a legal frequency into an illegality warning; anything
    // outside the shapes below would collapse to `null`, silently dropping
    // either a mode guess or an out-of-band warning. Neither is a thing to
    // discover from a bug report.
    if (segment.mode === 'OOB') {
      throw new Error(
        `${band} "${segment.name}": mode 'OOB' collides with radio.dart's outOfBandMode sentinel. ` +
          'Rename the sentinel there (and here) before regenerating.',
      )
    }
    if (!(typeof segment.mode === 'string' || segment.mode === null || segment.mode === undefined || segment.mode === false)) {
      throw new Error(`${band} "${segment.name}": unhandled mode ${JSON.stringify(segment.mode)} — teach the generator what it means.`)
    }
    const mode = typeof segment.mode === 'string' ? `'${segment.mode}'` : segment.mode === false ? `'OOB'` : 'null'
    const priority = segment.priority ?? 0
    // Validated the same way as `countries` below, and for the same reason —
    // a nested `[[1], [2]]` here joins to `1, 2`, which is valid Dart that
    // silently WIDENS the segment to two regions rather than matching
    // nobody. Scope that reads as deliberate is the harder failure to spot.
    if ((segment.regions ?? []).some((r) => typeof r !== 'number' || !Number.isFinite(r))) {
      throw new Error(
        `${band} "${segment.name}": regions is not a flat list of numbers (${JSON.stringify(segment.regions)}). ` +
          'Fix the data upstream in @ham2k/lib-operation-data and reinstall before regenerating.',
      )
    }
    const regions = (segment.regions ?? []).join(', ')
    if ((segment.countries ?? []).some((c) => typeof c !== 'string')) {
      // Same class of failure as `entities` above, and refused the same
      // way: `${['a','b']}` stringifies a nested list into ONE bogus
      // comma-joined country code, which matches no operator — silently
      // disabling the segment for everyone instead of applying it to the
      // countries it names.
      throw new Error(
        `${band} "${segment.name}": countries is not a flat list of strings (${JSON.stringify(segment.countries)}). ` +
          'Flattening or coercing it here would hand-correct the source; carrying it through would emit a country code no operator can match. ' +
          'Fix the data upstream in @ham2k/lib-operation-data and reinstall before regenerating.',
      )
    }
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
// A \`mode\` of \`'OOB'\` is radio.dart's \`outOfBandMode\` sentinel, carrying
// through the source's \`mode: false\` ("amateurs are not allocated this
// here") apart from its \`mode: null\` ("no single mode used here").
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
