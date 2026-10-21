// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// An extension's screenshots from the catalog (catalog SPEC §4.8): a row of
// thumbnails wherever the app shows an extension it could install or has
// installed, and the pictures themselves full size on a tap.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../services/extensions/catalog_service.dart' show CatalogScreenshot;

/// One row of thumbnails, as many as fit; when they do not all fit, the last
/// one says how many more there are. Never a scroller: a sideways list in a
/// row of a vertical one moves with neither a mouse wheel nor a mouse drag,
/// and the viewer pages through every one of them anyway.
///
/// Nothing at all for an extension without screenshots, so a caller can
/// place it unconditionally.
class ExtensionScreenshotStrip extends StatelessWidget {
  final List<CatalogScreenshot> screenshots;

  /// What the viewer's header says: the extension's name.
  final String title;

  final double height;

  const ExtensionScreenshotStrip({super.key, required this.screenshots, required this.title, this.height = 64});

  /// How wide a thumbnail of [shot] is drawn at [height]. Clamped, so one
  /// panorama or one phone-portrait capture cannot take the whole row or
  /// shrink to a sliver; the thumbnail is cropped to the box instead.
  static double thumbnailWidth(CatalogScreenshot shot, double height) => (height * shot.aspectRatio).clamp(height * 0.5, height * 2.2);

  /// How many of [widths] fit in [available], a [gap] apart.
  @visibleForTesting
  static int fitting(List<double> widths, double available, double gap) {
    var used = 0.0;
    for (var i = 0; i < widths.length; i++) {
      used += widths[i] + (i == 0 ? 0 : gap);
      if (used > available) return i;
    }
    return widths.length;
  }

  @override
  Widget build(BuildContext context) {
    if (screenshots.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final widths = [for (final shot in screenshots) thumbnailWidth(shot, height)];
        // At least one, even in a box too narrow for it: a strip that showed
        // nothing would hide that there is anything to open.
        final shown = constraints.maxWidth.isFinite ? fitting(widths, constraints.maxWidth, Space.sm).clamp(1, screenshots.length) : screenshots.length;
        return SizedBox(
          height: height,
          child: Row(
            children: [
              for (var i = 0; i < shown; i++) ...[
                if (i > 0) const SizedBox(width: Space.sm),
                _Thumbnail(
                  shot: screenshots[i],
                  width: widths[i],
                  height: height,
                  label: screenshots[i].caption ?? context.t.extensionsPanel.screenshotLabel(n: i + 1, count: screenshots.length),
                  more: i == shown - 1 ? screenshots.length - shown : 0,
                  onTap: () => showScreenshotViewer(context, screenshots: screenshots, title: title, initial: i),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final CatalogScreenshot shot;
  final double width;
  final double height;
  final String label;

  /// How many screenshots are left out of the strip after this one, said
  /// over it; zero says nothing.
  final int more;
  final VoidCallback onTap;

  const _Thumbnail({required this.shot, required this.width, required this.height, required this.label, required this.more, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pixels = MediaQuery.devicePixelRatioOf(context);
    // `cover` scales by whichever side the box is tighter on, and the
    // decode has to match that side: decoding a clamped portrait shot by its
    // height would draw it scaled up past what was decoded.
    final byWidth = shot.aspectRatio < width / height;
    // The tap is the Semantics node's own: `excludeSemantics` drops the
    // InkWell's, and a button a screen reader cannot press is worse than none.
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          width: width,
          height: height,
          child: Material(
            color: theme.colorScheme.surfaceContainerHighest,
            child: InkWell(
              onTap: onTap,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    shot.thumbUrl.toString(),
                    fit: BoxFit.cover,
                    // Decoded at the size it is drawn, not the size it was
                    // uploaded: a page of search results holds dozens.
                    cacheWidth: byWidth ? (width * pixels).round() : null,
                    cacheHeight: byWidth ? null : (height * pixels).round(),
                    errorBuilder: (context, error, stack) => Icon(MdiIcons.imageOffOutline, size: 20, color: theme.colorScheme.onSurfaceVariant),
                  ),
                  if (more > 0)
                    ColoredBox(
                      color: Colors.black54,
                      child: Center(
                        child: Text(
                          context.t.extensionsPanel.moreScreenshots(count: more),
                          style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Every screenshot full size, starting at [initial], paged with the arrows
/// on screen or on the keyboard. A Modal Pane, like the call-info photo:
/// full screen on narrow, a centered card on wide.
Future<void> showScreenshotViewer(BuildContext context, {required List<CatalogScreenshot> screenshots, required String title, int initial = 0}) =>
    showModalPane<void>(
      context,
      title: title,
      closeLabel: context.t.common.close,
      // The body sizes the image itself; a pane's own scroll view would hand
      // it unbounded height.
      scrollable: false,
      fillHeight: true,
      builder: (context) => _ScreenshotViewer(screenshots: screenshots, initial: initial),
    );

class _ScreenshotViewer extends StatefulWidget {
  final List<CatalogScreenshot> screenshots;
  final int initial;

  const _ScreenshotViewer({required this.screenshots, required this.initial});

  @override
  State<_ScreenshotViewer> createState() => _ScreenshotViewerState();
}

class _ScreenshotViewerState extends State<_ScreenshotViewer> {
  late final PageController _pages = PageController(initialPage: widget.initial);
  late int _index = widget.initial;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int index) {
    if (index < 0 || index >= widget.screenshots.length) return;
    _pages.animateToPage(index, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.t.extensionsPanel;
    final count = widget.screenshots.length;
    final shot = widget.screenshots[_index];
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _go(_index - 1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _go(_index + 1),
      },
      child: Focus(
        autofocus: true,
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: count,
                onPageChanged: (index) => setState(() => _index = index),
                itemBuilder: (context, i) {
                  final page = widget.screenshots[i];
                  // No InteractiveViewer: its pan takes the horizontal drag the
                  // PageView pages on, and a phone could no longer swipe.
                  return Center(
                    child: AspectRatio(
                      aspectRatio: page.aspectRatio,
                      child: Image.network(
                        page.url.toString(),
                        fit: BoxFit.contain,
                        semanticLabel: page.caption ?? t.screenshotLabel(n: i + 1, count: count),
                        // The thumbnail stands in until the full image
                        // arrives.
                        loadingBuilder: (context, child, progress) => progress == null
                            ? child
                            : Image.network(page.thumbUrl.toString(), fit: BoxFit.contain, errorBuilder: (_, _, _) => const SizedBox.shrink()),
                        errorBuilder: (context, error, stack) => Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(MdiIcons.imageOffOutline, size: 28, color: theme.colorScheme.onSurfaceVariant),
                              const SizedBox(height: Space.xs),
                              Text(t.screenshotUnavailable, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: Space.md),
            Row(
              children: [
                IconButton(
                  icon: Icon(MdiIcons.chevronLeft, semanticLabel: t.previousScreenshot),
                  onPressed: _index > 0 ? () => _go(_index - 1) : null,
                ),
                Expanded(
                  child: Text(
                    shot.caption ?? t.screenshotLabel(n: _index + 1, count: count),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                IconButton(
                  icon: Icon(MdiIcons.chevronRight, semanticLabel: t.nextScreenshot),
                  onPressed: _index < count - 1 ? () => _go(_index + 1) : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
