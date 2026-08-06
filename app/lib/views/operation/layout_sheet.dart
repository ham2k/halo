// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The layout setup sheet, shown from the header's dashboard button via
// showTopModalPane (docs/design/layouts.md) — the right-aligned counterpart
// of the operation setup sheet, and the only place a pane can be taken OUT
// of a customizable view. Where a pane SITS stays a tab drag; this sheet
// answers which panes are in the view at all, and how to reach each one's
// own settings.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../../i18n/strings.g.dart';

/// One row of the sheet: a pane in the view, with its own settings control
/// where it has any.
class LayoutPanelEntry {
  final String id;
  final String title;

  /// One line under the title. Worth showing where the operator is choosing
  /// a panel they may never have seen — an extension's panel is exactly
  /// that, and its own author wrote this line.
  final String? description;

  /// An SVG document or a `data:` URI, shown as a thumbnail. Never a URL:
  /// this sheet renders offline, and a remote preview would turn opening
  /// the panel list into a fetch.
  final String? preview;

  /// Opens this panel's settings, or null when the panel declares none —
  /// which is most of them today. A row without settings shows no control
  /// rather than an inert one.
  final void Function(BuildContext context)? openSettings;

  const LayoutPanelEntry({
    required this.id,
    required this.title,
    this.description,
    this.preview,
    this.openSettings,
  });
}

/// A panel's preview thumbnail. SVG is drawn directly; a `data:` URI is
/// decoded as an image. Anything else — notably a remote URL — draws
/// nothing at all rather than reaching for the network.
class _PanelPreview extends StatelessWidget {
  final String preview;

  const _PanelPreview({required this.preview});

  static const _size = 40.0;

  @override
  Widget build(BuildContext context) {
    final trimmed = preview.trimLeft();
    Widget? image;
    if (trimmed.startsWith('<svg') || trimmed.startsWith('<?xml')) {
      image = SvgPicture.string(
        preview,
        fit: BoxFit.contain,
        errorBuilder: (error, _, _) => _dropped('SVG preview did not parse: $error'),
      );
    } else if (trimmed.startsWith('data:image/svg+xml')) {
      final decoded = _decodeSvgDataUri(trimmed);
      if (decoded != null) {
        image = SvgPicture.string(
          decoded,
          fit: BoxFit.contain,
          errorBuilder: (error, _, _) => _dropped('SVG preview did not parse: $error'),
        );
      }
    } else if (trimmed.startsWith('data:image/')) {
      final decoded = _decodeDataUri(trimmed);
      if (decoded != null) {
        image = Image.memory(
          decoded,
          fit: BoxFit.contain,
          errorBuilder: (_, error, _) => _dropped('preview image did not decode: $error'),
        );
      }
    }
    if (image == null) return const SizedBox.shrink();
    return SizedBox(width: _size, height: _size, child: image);
  }

  static Uint8List? _decodeDataUri(String uri) {
    try {
      return UriData.fromUri(Uri.parse(uri)).contentAsBytes();
    } on Exception catch (e) {
      // A malformed preview costs its own thumbnail, never the row — but an
      // extension author whose preview never appears needs to be able to
      // tell "my data URI is wrong" from "the host ignores previews".
      // `on Exception`, not a bare catch: an Error here (an OOM from a
      // hostile multi-megabyte blob) is not this widget's to absorb.
      debugPrint('[panels] preview data URI did not decode: $e');
      return null;
    }
  }

  /// The SVG text of a `data:image/svg+xml` URI. Decoding is inside the
  /// guard: an author who base64s the wrong bytes would otherwise throw a
  /// FormatException out of build() — one bad thumbnail taking the whole
  /// sheet down, and every other failure on this path is already just a
  /// missing thumbnail.
  static String? _decodeSvgDataUri(String uri) {
    final bytes = _decodeDataUri(uri);
    if (bytes == null) return null;
    try {
      return utf8.decode(bytes);
    } on FormatException catch (e) {
      debugPrint('[panels] preview SVG is not valid UTF-8: $e');
      return null;
    }
  }

  static Widget _dropped(String why) {
    debugPrint('[panels] $why');
    return const SizedBox.shrink();
  }
}

class LayoutSheet extends StatelessWidget {
  /// Named so a test can tell "the Available section isn't rendered" from
  /// "it rendered with nothing in it" — the two look identical from the
  /// outside and only one of them is correct.
  static const panelsSectionKey = Key('layoutSection-panels');
  static const availableSectionKey = Key('layoutSection-available');

  /// The panels the view is currently holding, in the layout's own order.
  final List<LayoutPanelEntry> panels;

  /// Panels this view knows how to show but that aren't in the layout right
  /// now — every removal has to have a way back that isn't Reset Layout.
  final List<LayoutPanelEntry> available;

  /// Removes a panel from the view. Null for the row that must not be
  /// removed — the view's last remaining panel, which would leave the dock
  /// with no tab to drag anything back with.
  final void Function(String id)? onRemove;

  final void Function(String id)? onAdd;

  const LayoutSheet({
    super.key,
    required this.panels,
    this.available = const [],
    this.onRemove,
    this.onAdd,
  });

  /// The sheet's Options menu, opened from the top row's Options button and
  /// held by the view (which owns the default arrangement this restores).
  static Future<void> showOptions(BuildContext context, {required VoidCallback onReset}) {
    final t = context.t.operation.layout;
    return showHaloDialog<void>(
      context: context,
      builder: (dialogContext) => HaloDialog(
        title: Text(t.optionsTitle),
        // Same as the operation sheet's own options menu: the rows are the
        // whole content, so their ListTiles supply the horizontal inset.
        contentPadding: const EdgeInsets.symmetric(vertical: Space.md),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(MdiIcons.backupRestore),
              title: Text(t.resetLayout),
              // The menu closes first: the layout underneath rearranges as
              // this fires, and a dialog left standing over it would be
              // covering the very thing the user asked to see.
              onTap: () {
                Navigator.of(dialogContext).pop();
                onReset();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// A section band, in the operation setup sheet's own idiom: the pane's
  /// banding color, and the section's name in the same weight — the two
  /// sheets sit behind the same header and would read as unrelated surfaces
  /// otherwise. No chevron: these sections hold a handful of rows and have
  /// nothing worth collapsing.
  Widget _sectionHeader(BuildContext context, String title, {required Key key}) {
    final theme = Theme.of(context);
    return Material(
      key: key,
      color: haloDialogBandColorAt(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.md),
        child: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _panelRow(BuildContext context, LayoutPanelEntry panel, {required Widget? trailing}) => ListTile(
    // Opaque, like the operation sheet's rows: the sheet's own background
    // shows straight through a row that doesn't paint one.
    tileColor: haloSheetRowColor(context),
    leading: panel.preview == null ? null : _PanelPreview(preview: panel.preview!),
    title: Text(panel.title, style: const TextStyle(fontWeight: FontWeight.bold)),
    subtitle: panel.description == null ? null : Text(panel.description!),
    trailing: trailing,
  );

  @override
  Widget build(BuildContext context) {
    final t = context.t.operation.layout;
    // Removal is refused for a lone panel (see [onRemove]) — the row still
    // renders, without the control, rather than vanishing.
    final removable = panels.length > 1;
    return Material(
      color: haloSheetListBackground(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _sectionHeader(context, t.panelsSection, key: panelsSectionKey),
          for (final panel in panels)
            _panelRow(
              context,
              panel,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (panel.openSettings case final open?)
                    Builder(
                      // A context inside the row, not the sheet's: the
                      // settings dialog this opens positions itself against
                      // the control that asked for it.
                      builder: (rowContext) => IconButton(
                        icon: Icon(MdiIcons.tune, semanticLabel: t.panelSettings(panel: panel.title)),
                        onPressed: () => open(rowContext),
                      ),
                    ),
                  if (removable && onRemove != null)
                    IconButton(
                      icon: Icon(MdiIcons.close, semanticLabel: t.removePanel(panel: panel.title)),
                      onPressed: () => onRemove!(panel.id),
                    ),
                ],
              ),
            ),
          // Only once something has actually been taken out — an empty
          // "Available" heading reads as a feature that failed to load.
          if (available.isNotEmpty) ...[
            _sectionHeader(context, t.availableSection, key: availableSectionKey),
            for (final panel in available)
              _panelRow(
                context,
                panel,
                trailing: onAdd == null
                    ? null
                    : IconButton(
                        icon: Icon(MdiIcons.plus, semanticLabel: t.addPanel(panel: panel.title)),
                        onPressed: () => onAdd!(panel.id),
                      ),
              ),
          ],
        ],
      ),
    );
  }
}
