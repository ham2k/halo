// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The waterfall's history: each row as drawn and the levels it keeps for a
// redraw in other colors, where each lies down and across the display, and
// the palettes its levels are colored by (docs/design/panel-scenes.md §
// Spectrum).

part of 'scene_spectrum.dart';

/// Where a row taken over [rowLowHz]–[rowHighHz] lies across a display
/// [width] wide that now shows [lowHz]–[highHz]: its left and right edges,
/// either of which may fall off the display.
@visibleForTesting
(double, double) waterfallRowExtent(int rowLowHz, int rowHighHz, int lowHz, int highHz, double width) {
  if (highHz <= lowHz) return (0, width);
  final span = (highHz - lowHz).toDouble();
  return ((rowLowHz - lowHz) / span * width, (rowHighHz - lowHz) / span * width);
}

/// One waterfall row: its picture, the levels and the sweep's floor and ceiling it was drawn from —
/// kept so the whole history can be drawn again in other colors — and the frequencies it was
/// taken over.
class _Row {
  ui.Image image;
  final Float32List levels;
  final double floorDb, ceilingDb;
  final int lowHz, highHz, atMillis;

  /// The window and palette [image] was drawn on (a [_SceneSpectrumViewState._rowsKey]).
  Object? drawnOn;

  _Row(this.image, this.levels, this.floorDb, this.ceilingDb, this.lowHz, this.highHz, this.atMillis, {this.drawnOn});
}

/// Where a row taken at [atMillis] lies down a waterfall moving
/// [pixelsPerSecond], the newest taken at [newestMillis]: from its age to the
/// age of the row before it, [olderMillis], so irregular sweeps leave no
/// gaps; the oldest, with none before it, a [rowHeight] deep.
@visibleForTesting
(double, double) waterfallRowSpan(int newestMillis, int atMillis, int? olderMillis, double pixelsPerSecond, double rowHeight) {
  final top = (newestMillis - atMillis) / 1000 * pixelsPerSecond;
  final bottom = olderMillis == null ? top + rowHeight : (newestMillis - olderMillis) / 1000 * pixelsPerSecond;
  return (top, math.max(bottom, top + 1));
}

class _WaterfallPainter extends CustomPainter {
  final _Way way;
  final List<_Row> rows;

  /// Rows a second as they arrive now, which spaces them by when they were
  /// taken; null, one row deep each.
  final double? Function() rowsPerSecond;

  /// For the frequency lines and the marks, which follow the latest sweep.
  final SpectrumFrame? Function() frame;
  final _Marks marks;
  final _Style style;

  _WaterfallPainter({
    required Listenable repaint,
    required this.way,
    required this.rows,
    required this.rowsPerSecond,
    required this.frame,
    required this.marks,
    required this.style,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size screen) => _inFlow(canvas, screen, way, (size) => _paint(canvas, size));

  void _paint(Canvas canvas, Size size) {
    if (size.height <= 0) return;
    final rowHeight = math.max(1.0, size.height / _waterfallRows);
    final paint = Paint()..filterQuality = FilterQuality.low;
    final current = frame();
    // Each row where its frequencies are NOW: a retune slides the history
    // sideways and a width change stretches it, rather than redrawing old
    // signals at frequencies they were never on. Off the window, clipped.
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final perSecond = rowsPerSecond();
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final (top, bottom) = perSecond == null || perSecond <= 0
          ? (i * rowHeight, (i + 1) * rowHeight)
          : waterfallRowSpan(rows.first.atMillis, row.atMillis, i + 1 < rows.length ? rows[i + 1].atMillis : null, perSecond * rowHeight, rowHeight);
      if (top >= size.height) break;
      final (left, right) = current == null ? (0.0, size.width) : waterfallRowExtent(row.lowHz, row.highHz, current.lowHz, current.highHz, size.width);
      if (right <= 0 || left >= size.width) continue;
      canvas.drawImageRect(row.image, Rect.fromLTWH(0, 0, row.image.width.toDouble(), 1), Rect.fromLTRB(left, top, right, bottom + .5), paint);
    }
    canvas.restore();
    if (style.waterfallGrid case final grid? when current != null) _paintFrequencyLines(canvas, size, current, grid, dashed: style.gridDashed);
    // Both passes over the rows: under them, nothing would show.
    _paintMarks(canvas, size, current, marks, style, pan: false, front: false);
    _paintMarks(canvas, size, current, marks, style, pan: false, front: true);
  }

  @override
  bool shouldRepaint(_WaterfallPainter old) => true;
}

/// 256 RGBA colors, packed for a little-endian `rgba8888` row.
List<int> _paletteFor(SceneSpectrumSpec spec) {
  final stops =
      spec.waterfallColors ??
      switch (spec.palette) {
        'gray' => const [Color(0xFF000000), Color(0xFFFFFFFF)],
        'heat' => const [Color(0xFF000000), Color(0xFF7F0000), Color(0xFFFF4000), Color(0xFFFFFF00), Color(0xFFFFFFFF)],
        _ => const [Color(0xFF000010), Color(0xFF0000A0), Color(0xFF00C0FF), Color(0xFFFFFF00), Color(0xFFFF0000)],
      };
  return [
    for (var i = 0; i < 256; i++)
      () {
        final t = i / 255 * (stops.length - 1);
        final index = t.floor().clamp(0, stops.length - 2);
        final c = Color.lerp(stops[index], stops[index + 1], t - index)!;
        int byte(double v) => (v * 255).round() & 0xFF;
        return byte(c.a) << 24 | byte(c.b) << 16 | byte(c.g) << 8 | byte(c.r);
      }(),
  ];
}
