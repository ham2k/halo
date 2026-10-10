// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Rasterizes a glyph-bearing marker for the backends that can only take
// pixels (map_marker_data.dart's MapMarkerImage). The pure-Flutter backend
// draws the same marker from the widget tree instead — both read their
// geometry from the constants here, so the two can't drift into two
// different-looking "you are here" dots.

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'map_marker_data.dart';

/// Outer diameter, in logical pixels, including [markerIconStrokeWidth].
const markerIconDiameter = 28.0;
const markerIconStrokeWidth = 2.0;

/// The glyph's box inside the circle. Short of the inner diameter so the
/// pin's own bounding box has room to breathe rather than touching the ring.
const markerIconGlyphSize = 18.0;

/// The glyph's box for a marker of [diameter]: [markerIconGlyphSize] at the
/// standard size, scaled with it, so a smaller marker keeps its proportions.
double markerGlyphSizeFor(double diameter) => markerIconGlyphSize * diameter / markerIconDiameter;

/// How far a marker's glow reaches past its ring, in logical pixels. The
/// rasterized image grows by this on every side so the blur is not clipped
/// by its own edge; the circle itself keeps its diameter.
const markerIconGlowExtent = 4.0;

/// A filled circle with [icon] centered in it, ringed in [strokeColor] —
/// [background] and [foreground] come from whatever the marker is mirroring,
/// so the map's dot and its on-screen counterpart carry the same colors.
///
/// [devicePixelRatio] only buys resolution: the marker still measures
/// [markerIconDiameter] logical pixels on the map, because the ratio travels
/// with the pixels as [MapMarkerImage.pixelRatio]. The id is derived from
/// every input that changes a pixel — the icon's FONT included, since two of
/// them are in play (halo_widgets' resolveIconName) and a code point alone
/// names a different glyph in each — so a backend that has already
/// registered these bytes can recognize them and skip the work.
Future<MapMarkerImage> renderMarkerIconImage({
  required IconData icon,
  required Color background,
  required Color foreground,
  required Color strokeColor,
  required double devicePixelRatio,
  double strokeWidth = markerIconStrokeWidth,
  Color? glow,
  double diameter = markerIconDiameter,
}) async {
  final scale = devicePixelRatio.clamp(1.0, 4.0);
  final extent = glow == null ? 0.0 : markerIconGlowExtent;
  final box = diameter + extent * 2;
  final size = (box * scale).ceil();

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(scale);

  final center = Offset(box / 2, box / 2);
  // Inset by half the stroke: a stroked circle straddles its radius, so a
  // full-radius one would have half its ring clipped off by the image's own
  // edge.
  final radius = diameter / 2 - strokeWidth / 2;
  if (glow != null) {
    canvas.drawCircle(
      center,
      diameter / 2,
      Paint()
        ..color = glow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, markerIconGlowExtent / 2),
    );
  }
  canvas.drawCircle(center, radius, Paint()..color = background);
  canvas.drawCircle(
    center,
    radius,
    Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth,
  );

  final painter = TextPainter(
    textDirection: TextDirection.ltr,
    text: TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: markerGlyphSizeFor(diameter),
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: foreground,
        // The glyph box is the marker's own size, not a line of text — the
        // default line height would push it off-centre inside the circle.
        height: 1,
      ),
    ),
  )..layout();
  painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));

  final picture = recorder.endRecording();
  try {
    final image = await picture.toImage(size, size);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      // toByteData is documented to complete with null when the image cannot
      // be encoded. Named here rather than left as a bare null check: the
      // caller's report of it is all anyone reading a crash later gets.
      if (data == null) {
        throw StateError('could not rasterize marker glyph U+${icon.codePoint.toRadixString(16)} in ${icon.fontFamily}');
      }
      return MapMarkerImage(
        id:
            'glyph-${icon.fontPackage}/${icon.fontFamily}/${icon.codePoint}'
            '-${background.toARGB32()}-${foreground.toARGB32()}-${strokeColor.toARGB32()}'
            '-$strokeWidth-${glow?.toARGB32()}-$diameter-$size',
        // Offset and length, not the whole buffer: a view into a larger one
        // would hand the GL backends more bytes than width * height * 4, and
        // addImage rejects the size mismatch rather than the byte count.
        rgba: data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        width: size,
        height: size,
        pixelRatio: scale.toDouble(),
      );
    } finally {
      image.dispose();
    }
  } finally {
    // Its own scope, outside the image's: a toImage that throws never
    // produces one, and a picture disposed only on the success path leaks
    // native memory once per retry — and this IS retried, once per rebuild.
    picture.dispose();
  }
}

/// One map's rasterized glyph markers, keyed by every input that changes a
/// pixel. Rasterizing goes through the engine and so is asynchronous: a marker
/// draws as a plain dot for the frame or two before its pixels land rather
/// than the map waiting for them. [onLanded] is the map's cue to rebuild — it
/// must check `mounted` itself, since pixels can land after the map is gone.
///
/// The cache grows with the icons on screen times the themes and displays
/// visited before its map closes, which is small enough to leave unswept.
class MarkerGlyphCache {
  MarkerGlyphCache({required this.onLanded});

  final VoidCallback onLanded;
  final Map<String, MapMarkerGlyph> _glyphs = {};
  final Set<String> _inFlight = {};

  /// The glyph for these inputs if it has been drawn, otherwise null with a
  /// rasterization started — call it from `build`, and [onLanded] brings the
  /// marker in.
  MapMarkerGlyph? glyphFor({
    required IconData icon,
    required Color background,
    required Color foreground,
    required Color strokeColor,
    required double devicePixelRatio,
    double strokeWidth = markerIconStrokeWidth,
    Color? glow,
    double diameter = markerIconDiameter,
  }) {
    // The font is part of the icon's identity, not decoration: extensions
    // name icons across two of them (halo_widgets' resolveIconName), so two
    // different glyphs can share a code point.
    final key =
        '${icon.fontFamily}/${icon.fontPackage}/${icon.codePoint}'
        '/${background.toARGB32()}/${foreground.toARGB32()}'
        '/${strokeColor.toARGB32()}/$strokeWidth/${glow?.toARGB32()}/$diameter/$devicePixelRatio';
    final ready = _glyphs[key];
    if (ready != null) return ready;
    if (!_inFlight.add(key)) return null;
    unawaited(() async {
      try {
        final image = await renderMarkerIconImage(
          icon: icon,
          background: background,
          foreground: foreground,
          strokeColor: strokeColor,
          devicePixelRatio: devicePixelRatio,
          strokeWidth: strokeWidth,
          glow: glow,
          diameter: diameter,
        );
        _glyphs[key] = MapMarkerGlyph(icon: icon, color: foreground, image: image, glow: glow, diameter: diameter);
        onLanded();
      } finally {
        // In a finally, not after the await: a rasterization that throws
        // would otherwise leave its key claimed forever, and that marker
        // would be a plain dot for the rest of the session with nothing
        // saying why. Freeing it lets the next build try again, and the
        // throw itself goes on to ErrorPolicy rather than being swallowed
        // here.
        _inFlight.remove(key);
      }
    }());
    return null;
  }
}
