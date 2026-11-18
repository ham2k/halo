#!/usr/bin/env python3
"""Writes app/assets/geo/world-110m.json and world-50m.json, the outlines a
scene's maps draw: 1:110m for the whole world, 1:50m from zoom 3.

  curl -sSfLO https://cdn.jsdelivr.net/npm/world-atlas@2.0.2/land-110m.json
  curl -sSfLO https://cdn.jsdelivr.net/npm/world-atlas@2.0.2/countries-110m.json
  curl -sSfLO https://cdn.jsdelivr.net/gh/nvkelso/natural-earth-vector@v5.1.2/geojson/ne_110m_lakes.geojson
  python3 scripts/world-outlines.py land-110m.json countries-110m.json ne_110m_lakes.geojson > app/assets/geo/world-110m.json

and the same with 50m for world-50m.json.

world-atlas is Natural Earth's 1:110m and 1:50m sets (public domain) as
TopoJSON; the lakes are Natural Earth's own, at the same scale, as GeoJSON.
The output is plain JSON the app reads without a TopoJSON decoder:

  land     the land polygons' rings, for the fill, and the lakes' (with
           their islands), which the even-odd fill makes holes in it
  borders  every edge two countries share, for the lines between them

Each ring or line is one flat list, longitude then latitude, in hundredths
of a degree. Longitudes run on across the antimeridian rather than jumping
back (179, 181, not 179, -179), so every ring is a plain polygon on a flat
map, reaching past +180 (never -180) where it crosses — and Antarctica, which goes the
whole way round, is closed along the South Pole. A coastline is not listed
apart: it is the land rings, less that closure, whose ends are at a pole.
"""
import json
import sys


def decode_arcs(topology):
    sx, sy = topology['transform']['scale']
    tx, ty = topology['transform']['translate']
    arcs = []
    for arc in topology['arcs']:
        x = y = 0
        points = []
        for dx, dy in arc:
            x += dx
            y += dy
            points.append((x * sx + tx, y * sy + ty))
        arcs.append(points)
    return arcs


def line(arcs, indexes):
    points = []
    for i in indexes:
        arc = arcs[i] if i >= 0 else list(reversed(arcs[~i]))
        # Each arc starts where the last one ended.
        points.extend(arc if not points else arc[1:])
    return points


def unwrapped(points):
    out = []
    for lon, lat in points:
        if out:
            while lon - out[-1][0] > 180:
                lon -= 360
            while lon - out[-1][0] < -180:
                lon += 360
        out.append((lon, lat))
    return out


def closed_at_pole(ring):
    first_lon, first_lat = ring[0]
    last_lon = ring[-1][0]
    if abs(last_lon - first_lon) < 180:
        return ring
    pole = -90 if sum(lat for _, lat in ring) < 0 else 90
    return ring + [(last_lon, pole), (first_lon, pole), (first_lon, first_lat)]


def shifted_east(ring):
    """Moves a ring whole turns east until it starts no further west than
    -180, so it only ever spills past +180, never past both."""
    west = min(lon for lon, _ in ring)
    turns = 0
    while west + 360 * turns < -180:
        turns += 1
    return [(lon + 360 * turns, lat) for lon, lat in ring]


def flat(points):
    out = []
    for lon, lat in points:
        out += [round(lon * 100), round(lat * 100)]
    return out


def holds(rings, lon, lat):
    """Whether the even-odd fill of [rings] covers [lon], [lat]."""
    inside = False
    for ring in rings:
        points = list(zip(ring[0::2], ring[1::2]))
        for (x0, y0), (x1, y1) in zip(points, points[1:] + points[:1]):
            if (y0 > lat * 100) != (y1 > lat * 100) and lon * 100 < x0 + (lat * 100 - y0) * (x1 - x0) / (y1 - y0):
                inside = not inside
    return inside


def inner_point(ring):
    """A place inside [ring]: halfway between the first two edges a line
    across its middle latitude meets."""
    lats = [lat for _, lat in ring]
    lat = (min(lats) + max(lats)) / 2
    xs = sorted(x0 + (lat - y0) * (x1 - x0) / (y1 - y0)
                for (x0, y0), (x1, y1) in zip(ring, ring[1:] + ring[:1]) if (y0 > lat) != (y1 > lat))
    return (xs[0] + xs[1]) / 2, lat


def lake_rings(lakes, land_rings):
    """Each lake's ring and its islands', for a lake that lies on the land:
    one the land already leaves out would be filled back in."""
    rings = []
    for feature in lakes['features']:
        geometry = feature['geometry']
        polygons = geometry['coordinates'] if geometry['type'] == 'MultiPolygon' else [geometry['coordinates']]
        for polygon in polygons:
            lon, lat = inner_point([tuple(p) for p in polygon[0]])
            if holds(land_rings, lon, lat):
                rings += [flat(shifted_east([tuple(p) for p in ring])) for ring in polygon]
    return rings


def main(land_path, countries_path, lakes_path=None):
    with open(land_path) as f:
        land = json.load(f)
    with open(countries_path) as f:
        countries = json.load(f)

    land_arcs = decode_arcs(land)
    rings = []
    for geometry in land['objects']['land']['geometries']:
        polygons = geometry['arcs'] if geometry['type'] == 'MultiPolygon' else [geometry['arcs']]
        for polygon in polygons:
            for ring in polygon:
                rings.append(flat(shifted_east(closed_at_pole(unwrapped(line(land_arcs, ring))))))

    if lakes_path:
        with open(lakes_path) as f:
            rings += lake_rings(json.load(f), rings)

    country_arcs = decode_arcs(countries)
    used_by = {}
    for n, geometry in enumerate(countries['objects']['countries']['geometries']):
        polygons = geometry['arcs'] if geometry['type'] == 'MultiPolygon' else [geometry['arcs']] if geometry['type'] == 'Polygon' else []
        for polygon in polygons:
            for ring in polygon:
                for i in ring:
                    used_by.setdefault(i if i >= 0 else ~i, set()).add(n)
    borders = [flat(unwrapped(country_arcs[i])) for i, users in sorted(used_by.items()) if len(users) > 1]

    json.dump({'land': rings, 'borders': borders}, sys.stdout, separators=(',', ':'))
    sys.stdout.write('\n')


if __name__ == '__main__':
    main(*sys.argv[1:4])
