// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Regenerates lib/src/ham/entity_bounds.dart: a bounding box and continent
// per DXCC entity, for a map framed to fit the operator's own country or
// continent. Run from the repo root with Natural Earth's 1:10m Admin 0
// countries (public domain), downloaded from
// https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_10m_admin_0_countries.geojson
//
//   node packages/halo_core/tool/generate_entity_bounds.mjs <path to that file>
//
// A country's land goes to the DXCC entities that share its ISO code
// (@ham2k/lib-dxcc-data's countryCode). A piece of it near an outlying
// entity's centroid is that entity's — Hawaii, the Canaries, Corsica — and
// the rest is the country's main entity's, or divided by [SPLITS] where DXCC
// divides one landmass: Alaska from the lower 48, European from Asiatic
// Russia, England from Scotland, Wales and Northern Ireland. Nearest
// centroid alone gets those wrong: the lower 48's is closer to the Florida
// Keys than Guantanamo's is to nothing, Asiatic Russia's sits in Yakutia.
// An entity Natural Earth draws no land for (a reef, a rock) gets no box.

import { createRequire } from 'node:module'
import { readFileSync, writeFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const here = dirname(fileURLToPath(import.meta.url))
const repoRoot = join(here, '..', '..', '..')
const require = createRequire(join(repoRoot, 'extensions', 'package.json'))

const source = process.argv[2]
if (!source) throw new Error('usage: generate_entity_bounds.mjs <ne_10m_admin_0_countries.geojson>')

const pkgVersion = (name) =>
  JSON.parse(readFileSync(join(repoRoot, 'extensions', 'node_modules', '@ham2k', name, 'package.json'), 'utf8')).version
const { DXCC_BY_PREFIX } = require('@ham2k/lib-dxcc-data')
const dxccVersion = pkgVersion('lib-dxcc-data')

const entities = Object.values(DXCC_BY_PREFIX).filter((e) => !e.deleted)
const byPrefix = new Map(entities.map((e) => [e.entityPrefix, e]))

// Centroids the DXCC data has wrong, where they would claim another
// entity's land.
const CENTROIDS = { CY9: { lat: 47.2, lon: -60.15 }, GM: { lat: 57.0, lon: -4.2 } }
const centroid = (entity) => CENTROIDS[entity.entityPrefix] ?? entity

// How far from an outlying entity's centroid its land may lie.
const OUTLYING_KM = 600

// A rock off a mainland reaches no further than itself.
const OUTLYING_KM_FOR = { CY9: 30, CY0: 50 }

// How far from a country's main entity's centroid its smaller land may lie.
const MAIN_KM = 3000

// The entities that divide one country's main landmass, and which of them a
// point of it belongs to.
const SPLITS = {
  US: { entities: ['K', 'KL'], owner: (lat, lon) => (lat > 50 && (lon < -129 || lon > 170) ? 'KL' : 'K') },
  RU: { entities: ['UA', 'UA9'], owner: (lat, lon) => (lon >= 19 && lon < 60 ? 'UA' : 'UA9') },
  GB: {
    entities: ['G', 'GM', 'GW', 'GI'],
    owner: (lat, lon) => {
      // Rockall is no part of Scotland's frame.
      if (lon < -8.2) return null
      if (lon < -5.4 && lat > 54 && lat < 55.4) return 'GI'
      // North of the line from the Solway Firth to the Tweed.
      if (lat > 54.98 + ((lon + 3.2) * 0.83) / 1.17) return 'GM'
      if (lon < -2.65 && lat >= 51.35 && lat <= 53.45) return 'GW'
      return 'G'
    },
  },
}

const byCode = new Map()
for (const entity of entities) {
  if (!entity.countryCode) continue
  const code = entity.countryCode.toUpperCase()
  if (!byCode.has(code)) byCode.set(code, [])
  byCode.get(code).push(entity)
}
// Entities whose land Natural Earth draws inside another country's:
// Northern Ireland's code is not an ISO one, the US's Pacific islands are
// its Minor Outlying Islands, and France, Norway, the
// Netherlands, Australia and New Zealand carry their overseas parts.
const ALIASES = { GB: ['GI'], UM: ['KH3', 'KH4', 'KH5', 'KH7K', 'KH9', 'KP1'], FR: ['FG', 'FM', 'FY', 'FH'], NO: ['JW', 'JX'], NL: ['PJ4', 'PJ5'], AU: ['VK9C', 'VK9X'], NZ: ['ZK3'] }
for (const [code, prefixes] of Object.entries(ALIASES)) {
  for (const prefix of prefixes) byCode.get(code).push(byPrefix.get(prefix))
}

const rad = Math.PI / 180
function km(lat1, lon1, lat2, lon2) {
  const a = Math.sin(((lat2 - lat1) * rad) / 2) ** 2 + Math.cos(lat1 * rad) * Math.cos(lat2 * rad) * Math.sin(((lon2 - lon1) * rad) / 2) ** 2
  return 6371 * 2 * Math.asin(Math.min(1, Math.sqrt(a)))
}

const points = new Map() // entityPrefix → [[lon, lat]]
const add = (prefix, point) => {
  if (!points.has(prefix)) points.set(prefix, [])
  points.get(prefix).push(point)
}

const geo = JSON.parse(readFileSync(source, 'utf8'))
for (const feature of geo.features) {
  const code = feature.properties.ISO_A2_EH
  const candidates = byCode.get(code)
  if (!candidates) continue
  const split = SPLITS[code]
  const polygons = feature.geometry.type === 'Polygon' ? [feature.geometry.coordinates] : feature.geometry.coordinates
  const rings = polygons.map((polygon) => polygon[0])
  // The main entity: the one nearest the country's largest piece of land.
  const largest = rings.reduce((a, b) => (b.length > a.length ? b : a))
  const middle = (ring) => [ring.reduce((sum, [, la]) => sum + la, 0) / ring.length, ring.reduce((sum, [lo]) => sum + lo, 0) / ring.length]
  const nearestTo = (lat, lon, list) => {
    let best
    let bestKm = Infinity
    for (const entity of list) {
      const c = centroid(entity)
      const d = km(lat, lon, c.lat, c.lon)
      if (d < bestKm) {
        best = entity
        bestKm = d
      }
    }
    return [best, bestKm]
  }
  const main = nearestTo(...middle(largest), candidates)[0]
  const outlying = candidates.filter((entity) => entity !== main && !split?.entities.includes(entity.entityPrefix))
  for (const ring of rings) {
    const [lat, lon] = middle(ring)
    const [near, nearKm] = nearestTo(lat, lon, [main, ...outlying])
    if (near !== main && nearKm < (OUTLYING_KM_FOR[near.entityPrefix] ?? OUTLYING_KM)) {
      for (const point of ring) add(near.entityPrefix, point)
      continue
    }
    // Far-flung islands no entity of this code claims — Tokelau in New
    // Zealand's land, French Guiana in France's — are no part of the main
    // entity's box. Its largest piece always is, however wide.
    if (ring !== largest && km(lat, lon, centroid(main).lat, centroid(main).lon) > MAIN_KM && !split) continue
    if (split) {
      for (const point of ring) {
        const owner = split.owner(point[1], point[0])
        if (!owner) continue
        const c = centroid(byPrefix.get(owner))
        if (ring === largest || km(lat, lon, c.lat, c.lon) <= MAIN_KM) add(owner, point)
      }
    } else {
      for (const point of ring) add(main.entityPrefix, point)
    }
  }
}

// The narrowest longitude span holding every point: across the antimeridian
// when that is shorter, its east edge then past 180.
function bounds(list) {
  let south = 90
  let north = -90
  for (const [, lat] of list) {
    south = Math.min(south, lat)
    north = Math.max(north, lat)
  }
  const lons = [...new Set(list.map(([lon]) => lon))].sort((a, b) => a - b)
  let gap = lons[0] + 360 - lons[lons.length - 1]
  let west = lons[0]
  let east = lons[lons.length - 1]
  for (let i = 1; i < lons.length; i++) {
    const g = lons[i] - lons[i - 1]
    if (g > gap) {
      gap = g
      west = lons[i]
      east = lons[i - 1] + 360
    }
  }
  // All the way round, as Antarctica is.
  if (east - west > 300) return { south, west: -180, north, east: 180 }
  return { south, west, north, east }
}

const round = (n) => Math.round(n * 100) / 100
const sorted = [...entities].sort((a, b) => a.entityPrefix.localeCompare(b.entityPrefix))
const boxes = []
const continents = []
for (const entity of sorted) {
  const continent = entity.continents?.[0]
  if (continent) continents.push(`  '${entity.entityPrefix}': '${continent}',`)
  const list = points.get(entity.entityPrefix)
  if (!list) continue
  const b = bounds(list)
  boxes.push(`  '${entity.entityPrefix}': (south: ${round(b.south)}, west: ${round(b.west)}, north: ${round(b.north)}, east: ${round(b.east)}),`)
}

const out = `// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// GENERATED FILE — do not edit by hand.
// Regenerate with: node packages/halo_core/tool/generate_entity_bounds.mjs <ne_10m_admin_0_countries.geojson>
// Sources: @ham2k/lib-dxcc-data ${dxccVersion} (entities, centroids, continents),
//          Natural Earth 1:10m Admin 0 countries (land).

/// A DXCC entity's land as a box. [east] runs past 180 for an entity across
/// the antimeridian.
typedef EntityBounds = ({double south, double west, double north, double east});

/// By entity prefix, every entity Natural Earth draws land for.
const Map<String, EntityBounds> entityBounds = {
${boxes.join('\n')}
};

/// Each entity's first continent (\`NA\`, \`EU\`…), by entity prefix — for every
/// entity, land or none.
const Map<String, String> entityContinents = {
${continents.join('\n')}
};
`
writeFileSync(join(repoRoot, 'packages', 'halo_core', 'lib', 'src', 'ham', 'entity_bounds.dart'), out)
console.log(`wrote ${boxes.length} boxes and ${continents.length} continents of ${entities.length} entities`)
