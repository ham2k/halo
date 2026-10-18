// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Flutter-rendered pieces for the OSM map backend: the circle and pill
// markers and the tap callout card (callsign • distance / report • mode •
// band • time, with the band in its band color — same layout as
// app-polo's map callout). The webview backend re-creates the same look in
// HTML/CSS instead (see mapbox_webview_map_view.dart).

import 'package:flutter/material.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'map_marker_data.dart';
import 'map_marker_icon.dart';

/// A QSO or QTH as a plain circle — band-colored with an outline for QSOs
/// (sized by signal strength, light/dark-mode aware — see
/// map_panel.dart's [MapMarkerData.strokeColor]), black with a white
/// outline for the QTH.
class MapCircleMarker extends StatelessWidget {
  final MapMarkerData marker;

  /// Its size against the full one, as the map's zoom sets it — see
  /// [mapMarkerScaleAt].
  final double scale;

  const MapCircleMarker({super.key, required this.marker, this.scale = 1});

  @override
  Widget build(BuildContext context) {
    final isQth = marker.kind == MapMarkerKind.qth;
    // A glyph marker takes its geometry from map_marker_icon.dart, the same
    // constants the rasterized copy the other backends draw is built from.
    final glyph = marker.glyph;
    final diameter =
        scale *
        (glyph != null
            ? glyph.diameter
            : isQth
            ? 12.0
            : 14.0 * marker.sizeFactor);
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: marker.color,
        border: Border.all(
          color: marker.strokeColor,
          width:
              scale *
              (marker.strokeWidth ??
                  (glyph != null
                      ? markerIconStrokeWidth
                      : isQth
                      ? 2
                      : 1.5)),
        ),
        boxShadow: switch (glyph?.glow) {
          final glow? => [BoxShadow(color: glow, blurRadius: markerIconGlowExtent * scale)],
          null => null,
        },
      ),
      child: glyph == null
          ? null
          : Center(
              child: Icon(glyph.icon, size: markerGlyphSizeFor(glyph.diameter) * scale, color: glyph.color),
            ),
    );
  }
}

/// A marker with a [MapMarkerData.labelColor]: its label on a pill of its
/// colour — the same geometry as the pill the GL script draws
/// (map_gl_pill_script.dart's `ensurePillImage`), so the two read alike.
class MapPillMarker extends StatelessWidget {
  final MapMarkerData marker;

  /// Its size against the full one, as the map's zoom sets it — see
  /// [mapPillScaleAt].
  final double scale;

  const MapPillMarker({super.key, required this.marker, this.scale = 1});

  // The GL script's PILL_TEXT_SIZE, PILL_PAD_X, PILL_PAD_Y and PILL_RING.
  static const _textSize = 12.0;
  static const _padX = 6.0;
  static const _padY = 2.0;
  static const _ring = 1.5;

  @override
  Widget build(BuildContext context) => Container(
    // Less the ring, which a ShapeDecoration adds to the padding: the GL
    // pill's ring sits inside its padding.
    padding: EdgeInsets.symmetric(horizontal: (_padX - _ring) * scale, vertical: (_padY - _ring) * scale),
    decoration: ShapeDecoration(
      color: marker.color,
      shape: StadiumBorder(
        side: BorderSide(color: marker.strokeColor, width: _ring * scale),
      ),
    ),
    child: Text(
      marker.label,
      maxLines: 1,
      softWrap: false,
      style: TextStyle(fontSize: _textSize * scale, height: 1.2, fontWeight: FontWeight.w700, color: marker.labelColor),
    ),
  );
}

/// The callout shown when a circle is tapped.
class MapPopupCard extends StatelessWidget {
  static const double maxWidth = 240;

  final MapMarkerData marker;

  const MapPopupCard({super.key, required this.marker});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    final hasDetail = marker.popupDetailPrefix.isNotEmpty || marker.popupBand.isNotEmpty || marker.popupDetailSuffix.isNotEmpty;

    return Container(
      constraints: const BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: kElevationToShadow[2],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            marker.popupTitle.isEmpty ? marker.label : marker.popupTitle,
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: textColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (hasDetail)
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: marker.popupDetailPrefix),
                  TextSpan(
                    text: marker.popupBand,
                    style: TextStyle(fontWeight: FontWeight.w700, color: marker.color),
                  ),
                  TextSpan(text: marker.popupDetailSuffix),
                ],
              ),
              style: theme.textTheme.bodySmall?.copyWith(color: textColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}
