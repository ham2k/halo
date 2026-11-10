#!/usr/bin/env python3
"""Writes app/assets/geo/admin1-50m.json, the state and province lines the
rotator map draws when zoomed in.

  curl -sSfLO https://raw.githubusercontent.com/nvkelso/natural-earth-vector/v5.1.2/geojson/ne_50m_admin_1_states_provinces.geojson
  python3 scripts/admin1-outlines.py ne_50m_admin_1_states_provinces.geojson > app/assets/geo/admin1-50m.json

The source is Natural Earth's 1:50m admin-1 states and provinces (public
domain) as GeoJSON. At 1:50m it covers only a few large countries; of those,
the output keeps the ones in COUNTRIES. Mexico, Argentina and Kazakhstan
have no admin-1 polygons at that scale, so they are not in the list.

The output is plain JSON:

  admin1  every edge two divisions of the same country share

A coastline or an international border is not listed: world-110m.json
already draws those. Each line is one flat list, longitude then latitude,
in hundredths of a degree, as in world-110m.json. An edge counts as shared
when both divisions' rings hold it once their points are rounded to that
grid, and consecutive shared edges are chained back into lines. Longitudes
run on across the antimeridian rather than jumping back (179, 181, not
179, -179).
"""
import json
import sys

COUNTRIES = {'USA', 'CAN', 'BRA', 'RUS', 'CHN', 'IND', 'AUS'}


def rings(geometry):
    polygons = geometry['coordinates'] if geometry['type'] == 'MultiPolygon' else [geometry['coordinates']]
    for polygon in polygons:
        yield from polygon


def gridded(ring):
    out = []
    for lon, lat in ring:
        point = (round(lon * 100), round(lat * 100))
        if not out or out[-1] != point:
            out.append(point)
    return out


def shared_edges(features):
    """The edges, as point pairs in either order, that two divisions of one
    country both hold."""
    owners = {}
    for n, feature in enumerate(features):
        country = feature['properties']['adm0_a3']
        for ring in rings(feature['geometry']):
            points = gridded(ring)
            for a, b in zip(points, points[1:]):
                owners.setdefault(frozenset((a, b)), set()).add((country, n))
    shared = set()
    for edge, users in owners.items():
        countries = [country for country, _ in users]
        if any(countries.count(c) > 1 for c in countries):
            shared.add(edge)
    return shared


def chained(edges):
    """Joins edges into lines that break only where three or more edges
    meet or a line ends; a loop with no such point comes back as one closed
    line."""
    neighbours = {}
    for edge in edges:
        a, b = tuple(edge)
        neighbours.setdefault(a, []).append(b)
        neighbours.setdefault(b, []).append(a)
    unvisited = set(edges)

    def walk(start, step):
        line = [start, step]
        unvisited.discard(frozenset((start, step)))
        while len(neighbours[line[-1]]) == 2:
            nxt = next((p for p in neighbours[line[-1]] if frozenset((line[-1], p)) in unvisited), None)
            if nxt is None:
                break
            unvisited.discard(frozenset((line[-1], nxt)))
            line.append(nxt)
        return line

    lines = []
    for point in sorted(neighbours):
        if len(neighbours[point]) != 2:
            for step in neighbours[point]:
                if frozenset((point, step)) in unvisited:
                    lines.append(walk(point, step))
    while unvisited:
        a, b = sorted(min(unvisited, key=sorted))
        lines.append(walk(a, b))
    return lines


def unwrapped(points):
    out = []
    for lon, lat in points:
        if out:
            while lon - out[-1][0] > 18000:
                lon -= 36000
            while lon - out[-1][0] < -18000:
                lon += 36000
        out.append((lon, lat))
    return out


def flat(points):
    out = []
    for lon, lat in points:
        out += [lon, lat]
    return out


def main(path):
    with open(path) as f:
        source = json.load(f)
    features = [f for f in source['features'] if f['properties']['adm0_a3'] in COUNTRIES]
    lines = [flat(unwrapped(line)) for line in chained(shared_edges(features))]
    json.dump({'admin1': lines}, sys.stdout, separators=(',', ':'))
    sys.stdout.write('\n')


if __name__ == '__main__':
    main(sys.argv[1])
