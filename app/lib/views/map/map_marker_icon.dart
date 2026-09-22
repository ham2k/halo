// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Rasterizes a glyph-bearing marker for the backends that can only take
// pixels (map_marker_data.dart's MapMarkerImage). The pure-Flutter backend
// draws the same marker from the widget tree instead — both read their
// geometry from the constants here, so the two can't drift into two
// different-looking "you are here" dots.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'map_marker_data.dart';

/// Outer diameter, in logical pixels, including [markerIconStrokeWidth].
const markerIconDiameter = 28.0;
const markerIconStrokeWidth = 2.0;

/// The glyph's box inside the circle. Short of the inner diameter so the
/// pin's own bounding box has room to breathe rather than touching the ring.
const markerIconGlyphSize = 18.0;

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
}) async {
  final scale = devicePixelRatio.clamp(1.0, 4.0);
  final size = (markerIconDiameter * scale).ceil();

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(scale);

  const center = Offset(markerIconDiameter / 2, markerIconDiameter / 2);
  // Inset by half the stroke: a stroked circle straddles its radius, so a
  // full-radius one would have half its ring clipped off by the image's own
  // edge.
  const radius = markerIconDiameter / 2 - markerIconStrokeWidth / 2;
  canvas.drawCircle(center, radius, Paint()..color = background);
  canvas.drawCircle(
    center,
    radius,
    Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = markerIconStrokeWidth,
  );

  final painter = TextPainter(
    textDirection: TextDirection.ltr,
    text: TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: markerIconGlyphSize,
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
            '-$size',
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
