// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What the Operation Postcard draws over its map: the operation's title and
// numbers in a band across the top, the app's name at the foot, the bands'
// legend in the corner beside it, the map's attribution, and the Map tab's
// open popup where it showed one.

import 'package:flutter/material.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../map/map_marker_data.dart' show MapMarkerData;
import '../map/map_popup.dart' show MapPopupCard;
import 'operation_postcard.dart' show PostcardBand, PostcardShape, PostcardText, postcardCalloutGap;

const _footerBottom = 24.0;
const _footerPadding = Space.sm;

/// The footer pill's height: its padding and its line, the brand's 20 at 1.25.
const _footerHeight = 2 * _footerPadding + 20 * 1.25;

/// The foot of a postcard that its footer takes, and a gap above it.
const postcardFooterRoom = _footerBottom + _footerHeight + Space.xl;

/// Everything the postcard draws over the map, at its logical size. Its
/// colours are the picture's own, not the app theme's: the band follows the
/// basemap's tone, and the image looks the same whichever theme made it.
class PostcardOverlay extends StatelessWidget {
  final PostcardShape shape;
  final PostcardText text;
  final String attribution;
  final bool isDark;

  /// On the header band, for the pane to measure it by.
  final Key? headerKey;

  /// Whether [text]'s band legend is drawn: the map page's alone, since a
  /// summary page's text runs into the corner it takes.
  final bool legend;

  /// The Map tab's open popup, drawn with its tip on [calloutAt] — or laid out
  /// unseen, for [calloutKey] to be measured by, until the pane knows where.
  final MapMarkerData? callout;
  final Offset? calloutAt;
  final Key? calloutKey;

  const PostcardOverlay({
    super.key,
    required this.shape,
    required this.text,
    required this.attribution,
    required this.isDark,
    this.headerKey,
    this.legend = false,
    this.callout,
    this.calloutAt,
    this.calloutKey,
  });

  static const _lightBand = Color(0xB3F2F8FA);
  static const _lightInk = Color(0xFF222222);
  static const _darkBand = Color(0xB3121A20);
  static const _darkInk = Color(0xFFEEEEEE);

  static Color bandColor(bool isDark) => isDark ? _darkBand : _lightBand;
  static Color inkColor(bool isDark) => isDark ? _darkInk : _lightInk;

  @override
  Widget build(BuildContext context) {
    final band = bandColor(isDark);
    final ink = inkColor(isDark);
    final heading = TextStyle(fontFamily: 'RobotoSlab', fontWeight: FontWeight.w900, fontSize: 24, height: 1.2, color: ink);
    final body = TextStyle(fontFamily: 'Roboto', fontSize: 18, height: 1.25, color: ink);

    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text.title, style: heading, maxLines: 2, overflow: TextOverflow.ellipsis),
        if (text.subtitle.isNotEmpty) Text(text.subtitle, style: body, maxLines: 2, overflow: TextOverflow.ellipsis),
      ],
    );
    final right = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text.stats, style: heading, textAlign: TextAlign.right, maxLines: 1),
        if (text.date.isNotEmpty) Text(text.date, style: body, textAlign: TextAlign.right, maxLines: 1),
      ],
    );

    // Pinned to a plain text theme: the overlay is a picture, and the app's
    // text scaling or a platform's default font must not change it.
    return MediaQuery.withNoTextScaling(
      child: DefaultTextStyle(
        style: body,
        child: Stack(
          children: [
            if (callout case final marker?)
              switch (calloutAt) {
                null => Positioned(
                  left: 0,
                  top: 0,
                  child: Opacity(
                    opacity: 0,
                    child: _PostcardCallout(key: calloutKey, marker: marker),
                  ),
                ),
                final at => Positioned(
                  left: at.dx,
                  top: at.dy - postcardCalloutGap,
                  child: FractionalTranslation(
                    translation: const Offset(-0.5, -1),
                    child: _PostcardCallout(key: calloutKey, marker: marker),
                  ),
                ),
              },
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: ColoredBox(
                key: headerKey,
                color: band,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.xxl, vertical: Space.xl),
                  child: shape == PostcardShape.landscape
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: left),
                            const SizedBox(width: Space.xxl),
                            right,
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            left,
                            const SizedBox(height: Space.md),
                            Align(alignment: Alignment.centerRight, child: right),
                          ],
                        ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: _footerBottom,
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(color: band, borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.xl, vertical: _footerPadding),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          // The brand, which is never translated.
                          TextSpan(text: 'Ham2K ', style: body.copyWith(fontSize: 20)),
                          TextSpan(text: ham2kProductName, style: heading.copyWith(fontSize: 20)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (legend && text.bands.isNotEmpty)
              Positioned(
                left: Space.xl,
                // A portrait's corner is too narrow to hold the legend beside
                // the footer, so it stands on top of it there.
                bottom: shape == PostcardShape.portrait ? _footerBottom + _footerHeight + Space.md : _footerBottom,
                child: _PostcardLegend(bands: text.bands, band: band, style: body.copyWith(fontSize: 16)),
              ),
            Positioned(
              right: 6,
              bottom: 4,
              child: Text(attribution, style: body.copyWith(fontSize: 9, color: ink.withValues(alpha: 0.8))),
            ),
          ],
        ),
      ),
    );
  }
}

/// Each band, a dot in its markers' colour and its count, in three columns:
/// the names and the counts flush right. The names are in the overlay's ink,
/// which every band colour from navy to yellow would not read against.
class _PostcardLegend extends StatelessWidget {
  final List<PostcardBand> bands;
  final Color band;
  final TextStyle style;

  const _PostcardLegend({required this.bands, required this.band, required this.style});

  static const _dot = 12.0;

  @override
  Widget build(BuildContext context) {
    final figures = style.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    return DecoratedBox(
      decoration: BoxDecoration(color: band, borderRadius: BorderRadius.circular(Space.lg)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.sm),
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            for (final row in bands)
              TableRow(
                children: [
                  Text(
                    row.band,
                    style: figures.copyWith(fontWeight: FontWeight.w900),
                    textAlign: TextAlign.right,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.sm),
                    // Ringed in the ink, as a contact's marker is ringed against its basemap.
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: row.color,
                        border: Border.all(color: figures.color!, width: 1.5),
                      ),
                      child: const SizedBox.square(dimension: _dot),
                    ),
                  ),
                  Text(row.count, style: figures, textAlign: TextAlign.right),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// The Map tab's popup as the GL map draws it — a light card with a tip
/// pointing down at its marker — whatever the app's theme or the basemap's
/// tone.
class _PostcardCallout extends StatelessWidget {
  final MapMarkerData marker;

  const _PostcardCallout({super.key, required this.marker});

  static const _tip = Size(20, 10);

  @override
  Widget build(BuildContext context) {
    final light = buildHaLoTheme(Brightness.light);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Theme(
          data: light,
          child: MapPopupCard(marker: marker),
        ),
        CustomPaint(size: _tip, painter: _TipPainter(light.colorScheme.surface)),
      ],
    );
  }
}

class _TipPainter extends CustomPainter {
  final Color color;

  _TipPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_TipPainter oldDelegate) => oldDelegate.color != color;
}
