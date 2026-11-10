// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Where a rotator map's view sits in its pane: how far it is zoomed, where
// the station has been panned to, and the rim's shape — the zoom, pan and
// edge of red-ham-toolkit's rotator widget (docs/design/panel-scenes.md §
// Rotator map).

import 'dart:math' as math;
import 'dart:ui';

/// Half the Earth's circumference, in kilometres: the distance from the
/// station to the map's antipodal rim at zoom 1.
const double earthHalfCircumferenceKm = 20015.087;

/// The geometry of one view: built per layout, zoom and pan, and asked where
/// things are by everything that draws or hit-tests the map.
class RotatorFrame {
  final Size size;

  /// The disc's radius at zoom 1, in pixels: the whole Earth fits in it.
  final double base;
  final double zoom;

  /// The station: the map's centre, wherever the pan has put it.
  final Offset station;

  /// The rim, as a closed polygon in pane pixels.
  final List<Offset> rim;
  final Path rimPath;

  /// The pan actually in force, in pixels from the pane's middle, after
  /// [RotatorFrame]'s limits clamped what was asked.
  final Offset pan;

  /// Everywhere the station may be panned to at this zoom, in pane pixels.
  final Rect reach;

  RotatorFrame._(this.size, this.base, this.zoom, this.station, this.rim, this.rimPath, this.pan, this.reach);

  /// How far the station may move from the pane's middle at [zoom], in
  /// units of [base]: only as far as keeps the far side of the Earth — the
  /// disc's edge — out of the view.
  static double zoomPanLimit(double zoom) => math.max(0.0, 0.95 * zoom - 1);

  /// [widest] is the zoom furthest out the view goes: there the rim is a
  /// circle, its corners tightening from it as the view closes in.
  ///
  /// [pan] is where the station was asked to go, in pixels from the pane's
  /// middle. It stays inside [panArea] — the `square` around the circle the
  /// widest view draws, or the whole `pane` — by [panMargin] of the pane's
  /// shorter side, and inside [zoomPanLimit].
  factory RotatorFrame(
    Size size, {
    required double zoom,
    double widest = 1,
    Offset pan = Offset.zero,
    String panArea = 'pane',
    double panMargin = 0.1,
    double margin = 2,
  }) {
    final w = size.width, h = size.height;
    final base = math.max(0.0, math.min(w, h) / 2 - margin);
    final c = size.center(Offset.zero);
    final keep = panMargin * math.min(w, h);
    final reach = zoomPanLimit(zoom) * base;

    // Per axis: the stretch the rim may take, and how far the station may go each way from the middle.
    ({double lo, double hi, double down, double up}) axis(double middle, double extent) {
      final (lo, hi) = panArea == 'square' ? (middle - base, middle + base) : (margin, extent - margin);
      return (lo: lo, hi: hi, down: math.max(0.0, math.min(reach, middle - lo - keep)), up: math.max(0.0, math.min(reach, hi - keep - middle)));
    }

    final ax = axis(c.dx, w), ay = axis(c.dy, h);
    final off = Offset(pan.dx.clamp(-ax.down, ax.up), pan.dy.clamp(-ay.down, ay.up));
    final station = c + off;

    // How far the station has gone toward each side's limit, -1 to 1.
    double share(double offset, ({double lo, double hi, double down, double up}) a) => offset > 0
        ? (a.up <= 0 ? 0.0 : offset / a.up)
        : offset < 0
        ? (a.down <= 0 ? 0.0 : offset / a.down)
        : 0.0;
    final tx = share(off.dx, ax), ty = share(off.dy, ay);

    // The box keeps the circle's far edges, and stretches toward the area's
    // edge on the side the station has moved to, as far as the pan goes.
    (double, double) bounds(double t, double middle, ({double lo, double hi, double down, double up}) a) {
      if (t > 0) return (middle - base, middle + base + t * math.max(0.0, a.hi - (middle + base)));
      if (t < 0) return (middle - base - (-t) * math.max(0.0, (middle - base) - a.lo), middle + base);
      return (middle - base, middle + base);
    }

    final (left, right) = bounds(tx, c.dx, ax);
    final (top, bottom) = bounds(ty, c.dy, ay);
    final halfW = (right - left) / 2, halfH = (bottom - top) / 2;
    final roundest = math.min(halfW, halfH);

    // A circle zoomed all the way out, the corners tightening as the view
    // closes in. A corner the station has moved toward tightens further, and
    // the one across from it opens well out toward a full round, so the rim
    // leans with the pan.
    final corner = base * (widest / zoom).clamp(0.15, 1.0);
    double radius(double sx, double sy) {
      final lean = (sx * tx + sy * ty).clamp(-1.0, 1.0);
      final r = lean >= 0 ? corner * (1 - 0.5 * lean) : corner + (roundest - corner) * 0.75 * -lean;
      return math.min(r, roundest);
    }

    final points = <Offset>[];
    void arc(double cx, double cy, double r, double from, double to) {
      final steps = math.max(2, ((to - from).abs() / 0.05).ceil());
      for (var i = 0; i <= steps; i++) {
        final a = from + (to - from) * i / steps;
        points.add(Offset(cx + r * math.cos(a), cy + r * math.sin(a)));
      }
    }

    final (tl, tr, br, bl) = (radius(-1, -1), radius(1, -1), radius(1, 1), radius(-1, 1));
    arc(left + tl, top + tl, tl, math.pi, math.pi * 1.5);
    arc(right - tr, top + tr, tr, math.pi * 1.5, math.pi * 2);
    arc(right - br, bottom - br, br, 0, math.pi * 0.5);
    arc(left + bl, bottom - bl, bl, math.pi * 0.5, math.pi);
    final path = Path()..addPolygon(points, true);
    final stations = Rect.fromLTRB(c.dx - ax.down, c.dy - ay.down, c.dx + ax.up, c.dy + ay.up);
    return RotatorFrame._(size, base, zoom, station, points, path, off, stations);
  }

  /// Pixels per unit of the projection's disc, whose radius 1 is the antipode.
  double get discPx => base * zoom;

  double get pxPerKm => discPx / earthHalfCircumferenceKm;

  Offset toScreen(double x, double y) => station + Offset(x, y) * discPx;

  /// Where on the projection's disc a point of the pane is.
  Offset toDisc(Offset screen) => (screen - station) / discPx;

  /// The bearing from the station to [screen], degrees from north.
  double bearingOf(Offset screen) {
    final d = screen - station;
    return (math.atan2(d.dx, -d.dy) * 180 / math.pi + 360) % 360;
  }

  /// The unit step along [bearing] on screen.
  static Offset direction(double bearing) {
    final a = (bearing - 90) * math.pi / 180;
    return Offset(math.cos(a), math.sin(a));
  }

  Offset along(double bearing, double distancePx) => station + direction(bearing) * distancePx;

  /// How far, in pixels, the rim is from the station along [bearing].
  double rimAt(double bearing) {
    final d = direction(bearing);
    double? best;
    for (var i = 0; i < rim.length; i++) {
      final a = rim[i], b = rim[(i + 1) % rim.length];
      final e = b - a;
      final den = d.dx * e.dy - d.dy * e.dx;
      if (den.abs() < 1e-9) continue;
      final t = ((a.dx - station.dx) * e.dy - (a.dy - station.dy) * e.dx) / den;
      final s = ((a.dx - station.dx) * d.dy - (a.dy - station.dy) * d.dx) / den;
      if (t >= 0 && s >= -1e-6 && s <= 1 + 1e-6 && (best == null || t < best)) best = t;
    }
    return best ?? base;
  }

  bool contains(Offset screen) => rimPath.contains(screen);

  /// The box the rim lies in.
  Rect get bounds => rimPath.getBounds();

  /// The stretch of the projection's disc the pane can show at this zoom,
  /// wherever the station is panned to: a picture of it moves with a pan
  /// rather than being drawn again.
  Rect get reachableDisc =>
      Rect.fromLTRB((0 - reach.right) / discPx, (0 - reach.bottom) / discPx, (size.width - reach.left) / discPx, (size.height - reach.top) / discPx);
}
