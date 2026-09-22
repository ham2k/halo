// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Flutter-rendered pieces for the OSM map backend: the circle marker
// glyph and the tap callout card (callsign • distance / report • mode •
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

  const MapCircleMarker({super.key, required this.marker});

  @override
  Widget build(BuildContext context) {
    final isQth = marker.kind == MapMarkerKind.qth;
    // A glyph marker takes its geometry from map_marker_icon.dart, the same
    // constants the rasterized copy the other backends draw is built from.
    final glyph = marker.glyph;
    final diameter = glyph != null
        ? markerIconDiameter
        : isQth
        ? 12.0
        : 14.0 * marker.sizeFactor;
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: marker.color,
        border: Border.all(
          color: marker.strokeColor,
          width: glyph != null
              ? markerIconStrokeWidth
              : isQth
              ? 2
              : 1.5,
        ),
      ),
      child: glyph == null
          ? null
          : Center(
              child: Icon(glyph.icon, size: markerIconGlyphSize, color: glyph.color),
            ),
    );
  }
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
