// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Labels on a map's circles and lines, set contour style: straight text
// along the edge where it sits, turned to read upright, the edge cut under
// it (docs/design/panel-scenes.md § Map, "A label sits where the view shows
// its edge").

import 'dart:math' as math;
import 'dart:ui' show ClipOp;

import 'package:flutter/painting.dart';

/// Where a label [width] long sits along [runs], points on the screen:
/// the place on them nearest [prefer] at which the whole label lies along
/// them inside [within], and the way they run there, in radians, turned to
/// read upright. With [pinned], the place on them nearest [prefer], while
/// it is inside [within], or none: a label the scene placed is hidden
/// rather than moved, and at a line's end it runs on past it.
({Offset at, double angle})? placeMapLabel(List<List<Offset>> runs, Rect within, double width, Offset prefer, {bool pinned = false}) {
  if (within.isEmpty) return null;
  final half = width / 2;
  ({double distance, List<Offset> run, List<double> along, double at, bool shown})? nearest;
  ({double distance, List<Offset> run, List<double> along, double at})? best;
  for (var run in runs) {
    if (run.length < 2) continue;
    // A ring starts somewhere, a circle's at its north: begun there, a label
    // could not sit across where it closes. Begun as far from the anchor as
    // it goes, it can sit anywhere near it.
    if (run.length > 2 && (run.first - run.last).distance < 1e-6) {
      var far = 0;
      for (var i = 1; i < run.length; i++) {
        if ((run[i] - prefer).distanceSquared > (run[far] - prefer).distanceSquared) far = i;
      }
      run = [...run.sublist(far), ...run.sublist(1, far + 1)];
    }
    final along = List<double>.filled(run.length, 0);
    for (var i = 1; i < run.length; i++) {
      along[i] = along[i - 1] + (run[i] - run[i - 1]).distance;
    }
    // The stretches of the run inside [within], by how far along it they start and end.
    final shown = <(double, double)>[];
    for (var i = 0; i + 1 < run.length; i++) {
      final cut = _clip(run[i], run[i + 1], within);
      if (cut == null) continue;
      final length = along[i + 1] - along[i];
      final (start, end) = (along[i] + cut.$1 * length, along[i] + cut.$2 * length);
      if (shown.isNotEmpty && (shown.last.$2 - start).abs() < 1e-6) {
        shown.last = (shown.last.$1, end);
      } else {
        shown.add((start, end));
      }
    }
    // The stretches in order along the run: those wholly before a step are before every later one too.
    var first = 0;
    for (var i = 0; i + 1 < run.length; i++) {
      final (a, b) = (run[i], run[i + 1]);
      final length = along[i + 1] - along[i];
      final t = length == 0 ? 0.0 : (((prefer - a).dx * (b - a).dx + (prefer - a).dy * (b - a).dy) / (length * length)).clamp(0.0, 1.0);
      final s = along[i] + t * length;
      final off = (a + (b - a) * t - prefer).distance;
      if (nearest == null || off < nearest.distance) {
        nearest = (distance: off, run: run, along: along, at: s, shown: shown.any((r) => r.$1 <= s && s <= r.$2));
      }
      if (pinned) continue;
      while (first < shown.length && shown[first].$2 < along[i]) {
        first++;
      }
      for (var j = first; j < shown.length && shown[j].$1 <= along[i + 1]; j++) {
        final (start, end) = shown[j];
        final low = math.max(start + half, along[i]), high = math.min(end - half, along[i + 1]);
        if (low > high) continue;
        final at = s.clamp(low, high);
        // On this step: found from its start, not by walking the run again for every candidate.
        final away = ((length == 0 ? a : a + (b - a) * ((at - along[i]) / length)) - prefer).distance;
        if (best == null || away < best.distance) best = (distance: away, run: run, along: along, at: at);
      }
    }
  }
  if (pinned) {
    if (nearest == null || !nearest.shown) return null;
    best = (distance: nearest.distance, run: nearest.run, along: nearest.along, at: nearest.at);
  }
  if (best == null) return null;
  final from = _pointAt(best.run, best.along, best.at - half), to = _pointAt(best.run, best.along, best.at + half);
  var angle = math.atan2(to.dy - from.dy, to.dx - from.dx);
  if (angle > math.pi / 2) angle -= math.pi;
  if (angle < -math.pi / 2) angle += math.pi;
  return (at: _pointAt(best.run, best.along, best.at), angle: angle);
}

Offset _pointAt(List<Offset> run, List<double> along, double at) {
  var i = 1;
  while (i < run.length - 1 && along[i] < at) {
    i++;
  }
  final span = along[i] - along[i - 1];
  final t = span == 0 ? 0.0 : ((at - along[i - 1]) / span).clamp(0.0, 1.0);
  return run[i - 1] + (run[i] - run[i - 1]) * t;
}

/// The share of the way from [a] to [b] at which it enters [box] and the
/// share at which it leaves (Liang and Barsky's), or null where it misses.
(double, double)? _clip(Offset a, Offset b, Rect box) {
  var (t0, t1) = (0.0, 1.0);
  final d = b - a;
  for (final (p, q) in [(-d.dx, a.dx - box.left), (d.dx, box.right - a.dx), (-d.dy, a.dy - box.top), (d.dy, box.bottom - a.dy)]) {
    if (p == 0) {
      if (q < 0) return null;
      continue;
    }
    final r = q / p;
    if (p < 0) {
      if (r > t1) return null;
      t0 = math.max(t0, r);
    } else {
      if (r < t0) return null;
      t1 = math.min(t1, r);
    }
  }
  return t0 <= t1 ? (t0, t1) : null;
}

/// A label's text laid out, and its halo in its look's casing.
class MapLabelText {
  final TextPainter text;
  final TextPainter? halo;

  MapLabelText(String words, TextStyle style, {Color? halo})
    : text = TextPainter(
        text: TextSpan(text: words, style: style),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(),
      halo = halo == null
          ? null
          : (TextPainter(
              text: TextSpan(
                text: words,
                style: style.copyWith(
                  color: null,
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 3
                    ..strokeJoin = StrokeJoin.round
                    ..color = halo,
                ),
              ),
              textDirection: TextDirection.ltr,
              maxLines: 1,
            )..layout());

  Size get size => text.size;

  /// Its room on the edge: a few pixels clear of the words at either end.
  double get room => size.width + 6;

  /// Cuts its box, at [at] turned [angle], out of what [canvas] draws next.
  /// A clip outlives the save it was made in, so the turn is undone by hand
  /// rather than by a restore. Not Path.combine's difference of the boxes
  /// from the pane: on the web (CanvasKit) that clip lands away from them.
  void cutOut(Canvas canvas, Offset at, double angle) {
    canvas
      ..translate(at.dx, at.dy)
      ..rotate(angle)
      ..clipRect(
        Rect.fromCenter(center: Offset.zero, width: room, height: size.height),
        clipOp: ClipOp.difference,
      )
      ..rotate(-angle)
      ..translate(-at.dx, -at.dy);
  }

  void dispose() {
    text.dispose();
    halo?.dispose();
  }

  void paintAt(Canvas canvas, Offset at, double angle) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(angle);
    final corner = Offset(-size.width / 2, -size.height / 2);
    halo?.paint(canvas, corner);
    text.paint(canvas, corner);
    canvas.restore();
  }
}
