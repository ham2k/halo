// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The part of map_gl_script.dart's `create` that moves overlapping markers
// apart — spliced into it verbatim, so it runs in the same closure and reads
// the same `map`, markers and sources.

/// See map_gl_script.dart's `mapGlScript`, which includes this text whole.
const mapGlSpreadScript = '''
    // Markers that would overlap, moved apart (setSpread): below
    // SPREAD_FROM_ZOOM each sits on its own point, overlapping or not; from
    // there those that collide ease out to places in a ring around their
    // group's centre, reached at SPREAD_FULL_ZOOM. Closer in, each marker
    // draws back toward its point as far as it can without a collision, so
    // one whose point has drawn far enough from the rest ends up on it. A
    // place — the kind 'qth', "you are here" — is never moved.
    //
    // The rings are laid out once per set of markers, at SPREAD_FULL_ZOOM,
    // and every zoom moves a marker only along the line that layout gave it:
    // laid out afresh at each zoom, groups merge and split and their centres
    // shift, and a marker swings from one side of its point to the other.
    // Where each marker is drawn is still recomputed as the view changes,
    // since a fixed offset in pixels is a different distance on the ground at
    // every zoom — and the leader lines are ground geometry. Each marker
    // eases toward its place over a few frames rather than jumping.
    const SPREAD_FROM_ZOOM = 10;
    const SPREAD_FULL_ZOOM = 13;
    // Pixels kept clear between spread markers, and between a marker and any
    // leader's dot.
    const SPREAD_GAP = 3;
    // Pixels of leader line left showing between a spread marker's edge and
    // the centre of its group: without it a pair on one point sits edge to
    // edge right over the dot that says where that point is.
    const SPREAD_LEADER = 12;
    // A leader's dot, as drawn by leaderLayers: radius and stroke.
    const SPREAD_DOT = 4.5;
    // The share of the way to its place a marker covers each frame.
    const SPREAD_EASE = 0.3;
    let spreadOn = false;
    // One entry per marker that may be moved: its geometry (shared with the
    // feature drawn), its own point, and the offset in pixels it is drawn at.
    let spreadable = [];
    // The groups of two or more the layout made, each moved as one.
    let spreadGroups = [];
    // The offsets last drawn, by marker id, so a new set of markers picks up
    // where the old one left off instead of snapping.
    let spreadOffsets = new Map();
    let spreadFrame = 0;
    // No group to spread and every marker back on its own point: a zoom
    // moves nothing, and resending every marker for it would re-tile them all
    // on each frame of a pinch.
    let spreadIdle = false;
    let lastMarkerFeatures = [];
    let lastIconFeatures = [];

    // Web Mercator, as the unit square, and back.
    function toUnit(lon, lat) {
      const sin = Math.sin(lat * Math.PI / 180);
      return [(lon + 180) / 360, 0.5 - Math.log((1 + sin) / (1 - sin)) / (4 * Math.PI)];
    }
    function fromUnit(x, y) {
      return [x * 360 - 180, 360 / Math.PI * Math.atan(Math.exp((0.5 - y) * 2 * Math.PI)) - 90];
    }

    // Each entry's offset, in pixels, to its place at [zoom]: zero for one
    // that collides with nothing there, otherwise its place in a ring around
    // its group's centre big enough to hold the group's markers apart and
    // clear of every one of the group's dots.
    //
    // A ring can land on a marker outside its group, or on another group's
    // dot, so the groups are formed again from where the rings put their
    // markers — whatever such a marker touches joins its group — until no
    // marker is left on another or on a dot.
    function spreadTargets(zoom) {
      const scale = 512 * Math.pow(2, zoom);
      spreadable.forEach(function (e) {
        e.px = e.ux * scale;
        e.py = e.uy * scale;
        e.tx = 0;
        e.ty = 0;
      });
      const parent = spreadable.map(function (_, i) { return i; });
      function root(i) { while (parent[i] !== i) { parent[i] = parent[parent[i]]; i = parent[i]; } return i; }
      function join(i, j) {
        const ri = root(i), rj = root(j);
        if (ri === rj) return false;
        parent[rj] = ri;
        return true;
      }
      // Neighbours by cell rather than every pair against every other: a
      // cell wider than any marker means touching ones are a cell apart at most.
      const cell = 64;
      function near(xOf, yOf) {
        const cells = new Map();
        spreadable.forEach(function (e, i) {
          const key = Math.floor(xOf(e) / cell) + ',' + Math.floor(yOf(e) / cell);
          if (!cells.has(key)) cells.set(key, []);
          cells.get(key).push(i);
        });
        return function (x, y, visit) {
          const cx = Math.floor(x / cell), cy = Math.floor(y / cell);
          for (let dx = -1; dx <= 1; dx++) {
            for (let dy = -1; dy <= 1; dy++) (cells.get((cx + dx) + ',' + (cy + dy)) || []).forEach(visit);
          }
        };
      }
      const touching = function (a, b, ax, ay, bx, by) { return Math.hypot(ax - bx, ay - by) < (a.size + b.size) / 2 + SPREAD_GAP; };
      const atOwn = near(function (e) { return e.px; }, function (e) { return e.py; });
      spreadable.forEach(function (a, i) {
        atOwn(a.px, a.py, function (j) {
          if (j > i && touching(a, spreadable[j], a.px, a.py, spreadable[j].px, spreadable[j].py)) join(i, j);
        });
      });
      for (let pass = 0; pass < 8; pass++) {
        layoutRings(root);
        const drawnX = function (e) { return e.px + e.tx; };
        const drawnY = function (e) { return e.py + e.ty; };
        const atDrawn = near(drawnX, drawnY);
        let joined = false;
        spreadable.forEach(function (a, i) {
          atDrawn(drawnX(a), drawnY(a), function (j) {
            const b = spreadable[j];
            if (j > i && root(i) !== root(j) && touching(a, b, drawnX(a), drawnY(a), drawnX(b), drawnY(b))) joined = join(i, j) || joined;
          });
          // A moved marker leaves a dot on its own point.
          if (a.tx === 0 && a.ty === 0) return;
          atDrawn(a.px, a.py, function (j) {
            const b = spreadable[j];
            if (root(i) !== root(j) && Math.hypot(drawnX(b) - a.px, drawnY(b) - a.py) < b.size / 2 + SPREAD_DOT + SPREAD_GAP) joined = join(i, j) || joined;
          });
        });
        if (!joined) break;
      }
      const groups = new Map();
      spreadable.forEach(function (e, i) {
        e.fx = e.tx;
        e.fy = e.ty;
        const r = root(i);
        if (!groups.has(r)) groups.set(r, []);
        groups.get(r).push(e);
      });
      spreadGroups = Array.from(groups.values()).filter(function (group) { return group.length > 1; });
    }

    // Sets the offsets of every group [root] makes: a ring for each of two
    // or more, nothing for a marker alone.
    function layoutRings(root) {
      const groups = new Map();
      spreadable.forEach(function (e, i) {
        e.tx = 0;
        e.ty = 0;
        const r = root(i);
        if (!groups.has(r)) groups.set(r, []);
        groups.get(r).push(e);
      });
      groups.forEach(function (members) {
        const n = members.length;
        if (n < 2) return;
        const cx = members.reduce(function (sum, e) { return sum + e.px; }, 0) / n;
        const cy = members.reduce(function (sum, e) { return sum + e.py; }, 0) / n;
        const size = Math.max.apply(null, members.map(function (e) { return e.size; })) + SPREAD_GAP;
        // Around the centre in the order they already sit, so no two lines
        // cross; points on top of one another — the same place listed by
        // two programs — keep their listed order, starting on the left.
        const angleOf = function (e) { return Math.hypot(e.px - cx, e.py - cy) < 0.5 ? null : Math.atan2(e.py - cy, e.px - cx); };
        const ordered = members.slice().sort(function (a, b) {
          const aa = angleOf(a), ab = angleOf(b);
          return aa === null || ab === null ? 0 : aa - ab;
        });
        const first = angleOf(ordered[0]);
        const start = first === null ? Math.PI : first;
        const angles = ordered.map(function (_, k) { return start + 2 * Math.PI * k / n; });
        // The smallest ring that holds the markers apart and off the centre,
        // grown until no marker sits on any of the group's dots.
        let radius = Math.max(n === 2 ? size / 2 : size / (2 * Math.sin(Math.PI / n)), size / 2 + SPREAD_LEADER);
        const clear = size / 2 + SPREAD_DOT;
        for (let tries = 0; tries < 40; tries++) {
          const covers = angles.some(function (angle) {
            const x = cx + radius * Math.cos(angle), y = cy + radius * Math.sin(angle);
            return members.some(function (dot) { return Math.hypot(x - dot.px, y - dot.py) < clear; });
          });
          if (!covers) break;
          radius += 2;
        }
        ordered.forEach(function (e, k) {
          e.tx = cx + radius * Math.cos(angles[k]) - e.px;
          e.ty = cy + radius * Math.sin(angles[k]) - e.py;
        });
      });
    }

    // Sets each of [group]'s markers' share of its full offset at [scale]:
    // as little as it can be drawn at, along its own line, with no marker on
    // another and none on a dot — its own dot kept a leader's length off.
    // Each from where the layout put it, so a marker whose point has drawn
    // clear of the rest goes back to it while those still crowded stay out.
    function sharesAt(group, scale) {
      group.forEach(function (e) {
        e.zx = e.ux * scale;
        e.zy = e.uy * scale;
        e.share = 1;
      });
      const clearFor = function (a, share) {
        const ax = a.zx + a.fx * share, ay = a.zy + a.fy * share;
        return group.every(function (b) {
          if (b === a) return share === 0 || Math.hypot(a.fx * share, a.fy * share) >= a.size / 2 + SPREAD_LEADER;
          const bx = b.zx + b.fx * b.share, by = b.zy + b.fy * b.share;
          if (Math.hypot(ax - bx, ay - by) < (a.size + b.size) / 2 + SPREAD_GAP) return false;
          if (b.share > 0 && Math.hypot(ax - b.zx, ay - b.zy) < a.size / 2 + SPREAD_DOT + SPREAD_GAP) return false;
          return share === 0 || Math.hypot(bx - a.zx, by - a.zy) >= b.size / 2 + SPREAD_DOT + SPREAD_GAP;
        });
      };
      for (let pass = 0; pass < 2; pass++) {
        group.forEach(function (a) {
          for (let step = 0; step < 20; step++) {
            if (step / 20 >= a.share) return;
            if (clearFor(a, step / 20)) {
              a.share = step / 20;
              return;
            }
          }
        });
      }
    }

    // Moves each marker a step toward its place, and its leader with it.
    // Answers whether any is still on its way, and so needs another frame.
    function positionSpread() {
      const zoom = map.getZoom();
      const factor = Math.min(Math.max((zoom - SPREAD_FROM_ZOOM) / (SPREAD_FULL_ZOOM - SPREAD_FROM_ZOOM), 0), 1);
      const scale = 512 * Math.pow(2, zoom);
      spreadGroups.forEach(function (group) {
        if (zoom > SPREAD_FULL_ZOOM) {
          sharesAt(group, scale);
        } else {
          group.forEach(function (e) { e.share = factor; });
        }
        group.forEach(function (e) {
          e.tx = e.fx * e.share;
          e.ty = e.fy * e.share;
        });
      });
      const leaders = [];
      let moving = false;
      spreadable.forEach(function (e) {
        const tx = e.tx, ty = e.ty;
        e.ox += (tx - e.ox) * SPREAD_EASE;
        e.oy += (ty - e.oy) * SPREAD_EASE;
        if (Math.hypot(tx - e.ox, ty - e.oy) < 0.5) {
          e.ox = tx;
          e.oy = ty;
        } else {
          moving = true;
        }
        spreadOffsets.set(e.id, [e.ox, e.oy]);
        if (e.ox === 0 && e.oy === 0) {
          e.geometry.coordinates = [e.lon, e.lat];
          return;
        }
        const at = fromUnit(e.ux + e.ox / scale, e.uy + e.oy / scale);
        e.geometry.coordinates = at;
        const properties = { color: e.color, strokeColor: e.strokeColor };
        leaders.push({ type: 'Feature', properties: properties, geometry: { type: 'LineString', coordinates: [[e.lon, e.lat], at] } });
        leaders.push({ type: 'Feature', properties: properties, geometry: { type: 'Point', coordinates: [e.lon, e.lat] } });
      });
      const source = map.getSource('polo-leaders');
      if (source) source.setData({ type: 'FeatureCollection', features: leaders });
      spreadIdle = !moving && spreadGroups.length === 0;
      return moving;
    }

    // Once a frame at most, for as long as the view is changing or a marker
    // is still on its way.
    function spreadSoon() {
      if (!spreadable.length || spreadFrame || spreadIdle) return;
      spreadFrame = requestAnimationFrame(function () {
        spreadFrame = 0;
        try {
          const moving = positionSpread();
          const markers = map.getSource('polo-markers');
          const icons = map.getSource('polo-marker-icons');
          if (markers) markers.setData({ type: 'FeatureCollection', features: lastMarkerFeatures });
          if (icons) icons.setData({ type: 'FeatureCollection', features: lastIconFeatures });
          if (moving) spreadSoon();
        } catch (err) {
          report('deferred-update', 'spreading the markers failed: ' + ((err && err.message) || err));
        }
      });
    }
    map.on('zoom', spreadSoon);

    function setSpread(on) {
      if (spreadOn === on) return;
      spreadOn = on;
      if (!on) {
        spreadOffsets = new Map();
        const source = map.getSource('polo-leaders');
        if (source) source.setData(EMPTY);
      }
      if (lastMarkersData) setMarkers(lastMarkersData);
    }
''';
