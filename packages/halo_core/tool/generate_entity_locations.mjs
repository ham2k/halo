// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Regenerates lib/src/ham/entity_locations.dart from the same npm packages
// app-polo's map uses (see the header of the generated file for why the data
// is ported to Dart at all). Run from the repo root:
//
//   node packages/halo_core/tool/generate_entity_locations.mjs
//
// Reads @ham2k/lib-dxcc-data (entity centroids by prefix) and
// @ham2k/lib-geo-tools (the entityRegionLocations state/province centroid
// table — not exported from the package, so it's parsed out of the bundled
// source) via extensions/node_modules, where both are already installed.

import { createRequire } from 'node:module'
import { readFileSync, writeFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const here = dirname(fileURLToPath(import.meta.url))
const repoRoot = join(here, '..', '..', '..')
const require = createRequire(join(repoRoot, 'extensions', 'package.json'))

// package.json subpaths aren't in these packages' `exports` maps, so read
// the version stamps straight off the node_modules directories instead.
const pkgVersion = (name) =>
  JSON.parse(readFileSync(join(repoRoot, 'extensions', 'node_modules', '@ham2k', name, 'package.json'), 'utf8')).version

const { DXCC_BY_PREFIX } = require('@ham2k/lib-dxcc-data')
const dxccVersion = pkgVersion('lib-dxcc-data')
const geoToolsPath = require.resolve('@ham2k/lib-geo-tools')
const geoVersion = pkgVersion('lib-geo-tools')

// entityRegionLocations.json is inlined in lib-geo-tools' bundle as
// `var entityRegionLocations_default = {...};` — extract and parse it.
const geoSource = readFileSync(geoToolsPath, 'utf8')
const regionMatch = geoSource.match(/var entityRegionLocations_default = (\{[\s\S]*?\n\});/)
if (!regionMatch) throw new Error('entityRegionLocations_default not found in lib-geo-tools bundle')
// The inlined JSON object is valid JSON except for being a JS expression.
const regionTable = JSON.parse(regionMatch[1].replace(/,\s*\}$/m, '\n}'))

const fmt = (n) => {
  if (!Number.isFinite(n)) throw new Error(`non-finite coordinate: ${n}`)
  return Number.isInteger(n) ? `${n}` : `${n}`
}

const entityEntries = Object.entries(DXCC_BY_PREFIX)
  .filter(([, e]) => e.lat != null && e.lon != null)
  .sort(([a], [b]) => (a < b ? -1 : 1))
  .map(([prefix, e]) => `  '${prefix}': GridLocation(${fmt(e.lat)}, ${fmt(e.lon)}),`)

// Region table values are stored as [longitude, latitude] pairs (GeoJSON
// order) — swap into GridLocation(lat, lon). "IGNORE" sentinels ('K-IGNORE',
// 'VE-IGNORE') carry no coordinates and are dropped.
const regionEntries = Object.entries(regionTable)
  .filter(([key, pair]) => !key.endsWith('-IGNORE') && Array.isArray(pair) && pair.length >= 2)
  .sort(([a], [b]) => (a < b ? -1 : 1))
  .map(([key, [lon, lat]]) => `  '${key}': GridLocation(${fmt(lat)}, ${fmt(lon)}),`)

const out = `// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// GENERATED FILE — do not edit by hand.
// Regenerate with: node packages/halo_core/tool/generate_entity_locations.mjs
// Sources: @ham2k/lib-dxcc-data ${dxccVersion} (entity centroids),
//          @ham2k/lib-geo-tools ${geoVersion} (entityRegionLocations).
//
// Coarse fallback coordinates for QSOs that have no grid square: a DXCC
// entity centroid per entity prefix, refined to a state/province centroid
// where the region table has one (US, Canada, Australia). Ported to Dart as
// data because the Map tab resolves QSO locations in core UI code (same
// rationale as grid.dart) — the JS lookup pipeline deliberately does NOT
// annotate QSOs with these centroids (see extensions/core/lookups/src/
// annotate.ts), so the map has to fall back at render time, exactly like
// app-polo's locationForQSONInfo does.

import 'grid.dart';

/// DXCC entity centroid by entity prefix (e.g. 'K' → the continental US).
const Map<String, GridLocation> entityLocations = {
${entityEntries.join('\n')}
};

/// State/province centroid by \`<entityPrefix>-<region>\` key (e.g. 'K-CA').
const Map<String, GridLocation> entityRegionLocations = {
${regionEntries.join('\n')}
};
`

const outPath = join(repoRoot, 'packages', 'halo_core', 'lib', 'src', 'ham', 'entity_locations.dart')
writeFileSync(outPath, out)
console.log(`Wrote ${outPath}: ${entityEntries.length} entities, ${regionEntries.length} regions`)
