// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Add a Panel sheet, shown from the header's plus button while the layout
// is being edited (docs/design/layouts.md) — the right-aligned counterpart of
// the operation setup sheet.
//
// It answers ONE question: what else could go in this view. Where a pane sits
// is a tab drag, and taking one out is a drag onto the delete target — a
// second list of what is already in the view would be a second place to do
// that, and the two would disagree the moment one of them was wrong.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:halo_core/halo_core.dart' show matchesWordStart;
import 'package:halo_widgets/halo_widgets.dart';

import 'package:halo_i18n/halo_i18n.dart';

import '../../services/extensions/catalog_service.dart';
import '../../services/extensions/extension_info.dart';
import '../extensions_panel.dart' show extensionCategoryIcon;
import 'activities_catalog_tier.dart' show InstallExtensionRow;

/// One row of the sheet: a panel that could be added to the view.
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

  /// The name of the extension that contributes this panel, null for one of
  /// the app's own. Searched like the title: an operator who just enabled
  /// an extension from this sheet finds its panels by the name they enabled.
  final String? extensionName;

  const LayoutPanelEntry({required this.id, required this.title, this.description, this.preview, this.extensionName});
}

/// A panel's preview image. SVG is drawn directly; a `data:` URI is
/// decoded as an image. Anything else — notably a remote URL — draws
/// nothing at all rather than reaching for the network.
class _PanelPreview extends StatelessWidget {
  final String preview;

  /// The row's thumbnail is deliberately small — these rows match the
  /// operation setup sheet's, and growing them to fit a legible preview
  /// would make the two read as unrelated surfaces. The thumbnail is a
  /// control instead: tapping it opens the same image at [_paneSize].
  final double size;

  /// Shown in place of the image when it does not draw — an SVG that fails
  /// to parse, a `data:` payload that is not the image it claims to be.
  /// Null at thumbnail size, where the row simply shows nothing: a broken
  /// preview is an extension-author defect, and the operator reading a
  /// panel list is not the one who can act on it. At pane size it is the
  /// difference between "this panel looks like nothing" and "this preview
  /// is broken".
  final Widget? unavailable;

  const _PanelPreview({required this.preview, this.size = _thumbnailSize, this.unavailable});

  static const _thumbnailSize = 40.0;

  /// Roughly the shape of a real pane, so what the operator is choosing
  /// between looks like what they will get.
  static const _paneSize = 320.0;

  @override
  Widget build(BuildContext context) {
    final trimmed = preview.trimLeft();
    Widget? image;
    if (trimmed.startsWith('<svg') || trimmed.startsWith('<?xml')) {
      image = SvgPicture.string(preview, fit: BoxFit.contain, errorBuilder: (error, _, _) => _dropped('SVG preview did not parse: $error'));
    } else if (trimmed.startsWith('data:image/svg+xml')) {
      final decoded = _decodeSvgDataUri(trimmed);
      if (decoded != null) {
        image = SvgPicture.string(decoded, fit: BoxFit.contain, errorBuilder: (error, _, _) => _dropped('SVG preview did not parse: $error'));
      }
    } else if (trimmed.startsWith('data:image/')) {
      final decoded = _decodeDataUri(trimmed);
      if (decoded != null) {
        image = Image.memory(decoded, fit: BoxFit.contain, errorBuilder: (_, error, _) => _dropped('preview image did not decode: $error'));
      }
    }
    // Inside the box either way. The row wraps this in a tap target and
    // announces it to a screen reader, so a bare `SizedBox.shrink()` here
    // would leave a control with no hit area and nothing to say — and at
    // pane size, the `unavailable` message would never be reachable, since
    // only the two errorBuilders below get there.
    return SizedBox(width: size, height: size, child: image ?? _dropped('preview payload did not decode'));
  }

  /// Whether [preview] is in a form this widget will even attempt — an SVG
  /// document or a `data:` image. A remote URL is not, and never will be.
  ///
  /// Deliberately NOT a promise that the image draws: whether an SVG parses
  /// or a PNG decodes is only knowable by trying, inside build. The row asks
  /// this before offering the tap so that a preview nothing could ever draw
  /// offers no control at all; a preview that is well-formed enough to try
  /// and then fails is the pane's problem, and [_unavailable] is what it
  /// shows instead of an empty box.
  static bool isDrawableForm(String preview) {
    final trimmed = preview.trimLeft();
    return trimmed.startsWith('<svg') || trimmed.startsWith('<?xml') || trimmed.startsWith('data:image/');
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

  /// One bad preview costs its own image, never the row or the sheet. The
  /// line goes to the console because it is an extension author's to fix;
  /// what the operator gets is [unavailable], which is nothing at all in a
  /// row and a plain sentence at pane size.
  Widget _dropped(String why) {
    debugPrint('[panels] $why');
    return unavailable ?? const SizedBox.shrink();
  }
}

class LayoutSheet extends StatefulWidget {
  /// Named so a test can tell "the section isn't rendered" from "it rendered
  /// with nothing in it" — the two look identical from the outside and only
  /// one of them is correct.
  static const availableSectionKey = Key('layoutSection-available');

  static const previewPlaceholderKey = Key('layoutSheet-previewPlaceholder');

  /// Panels this view knows how to show. A panel already in the layout is
  /// listed only if it can be placed more than once, in which case this row
  /// IS the "add another" control.
  final List<LayoutPanelEntry> available;

  final void Function(String id)? onAdd;

  /// Installed extensions that contribute panels but are switched off, and
  /// catalog extensions that contribute panels and are not installed —
  /// offered as "Enable X" / "Install X" rows when the search matches them,
  /// the same tiers the operation sheet's activity search offers. Unfiltered:
  /// the sheet owns the search text, so it does the matching.
  final List<ExtensionInfo> enableable;
  final List<CatalogEntry> installable;

  /// Called on every non-empty search, so the host can fetch the catalog
  /// lazily — a sheet opened only to add a Clock asks the catalog nothing.
  final VoidCallback? onSearch;

  /// Gain the extension, answering whether it is now running with its panels
  /// listed. On true the search is replaced by the extension's name, which
  /// is what lists its panels.
  final Future<bool> Function(ExtensionInfo info)? onEnableExtension;
  final Future<bool> Function(CatalogEntry entry)? onInstallExtension;

  /// Opens the extensions screen, filtered to the ones that contribute
  /// panels. The list here is only what is INSTALLED; an operator who cannot
  /// find the panel they want needs the other screen, and sending them to
  /// hunt for it is worse than a button.
  final VoidCallback? onManageExtensions;

  const LayoutSheet({
    super.key,
    this.available = const [],
    this.onAdd,
    this.onManageExtensions,
    this.enableable = const [],
    this.installable = const [],
    this.onSearch,
    this.onEnableExtension,
    this.onInstallExtension,
  });

  @override
  State<LayoutSheet> createState() => _LayoutSheetState();
}

class _LayoutSheetState extends State<LayoutSheet> {
  final _searchController = TextEditingController();

  /// Held from the tap on an Enable/Install row until the extension is
  /// running: both end in a runtime restart, and a second tap would queue
  /// another on top of the first.
  bool _gaining = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Matches a panel's NAME and its description both — a panel is often
  /// easier to describe than to name ("weather" finds Weather; so does
  /// "conditions", which is what its own author wrote).
  bool _matches(LayoutPanelEntry panel, String query) {
    if (query.isEmpty) return true;
    return matchesWordStart(panel.title, query) || matchesWordStart(panel.description ?? '', query) || matchesWordStart(panel.extensionName ?? '', query);
  }

  Future<void> _gain(Future<bool> Function() gain, String name) async {
    if (_gaining) return;
    setState(() => _gaining = true);
    try {
      final gained = await gain();
      if (!mounted || !gained) return;
      _searchController.text = name;
    } finally {
      if (mounted) setState(() => _gaining = false);
    }
  }

  Widget _enableRow(BuildContext context, ExtensionInfo info, String locale) {
    final theme = Theme.of(context);
    final name = info.nameFor(locale);
    return ListTile(
      tileColor: theme.colorScheme.secondaryContainer,
      leading: ExtensionIconTile(icon: info.icon, accentColor: info.accentColor, fallbackIcon: extensionCategoryIcon(info.category)),
      title: Text(
        context.t.activitiesView.enableExtension(name: name),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(context.t.activitiesView.enableExtensionHint),
      trailing: const Icon(MdiIcons.plus),
      onTap: _gaining ? null : () => unawaited(_gain(() => widget.onEnableExtension!(info), name)),
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
          style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _panelRow(BuildContext context, LayoutPanelEntry panel) {
    final t = context.t.operation.layout;
    final preview = panel.preview;
    final onAdd = widget.onAdd;
    return ListTile(
      // Opaque, like the operation sheet's rows: the sheet's own background
      // shows straight through a row that doesn't paint one.
      tileColor: haloSheetRowColor(context),
      // A placeholder where there is no preview, so every title starts at the
      // same inset — and a plain box, not a control: there is nothing to open.
      leading: preview == null || !_PanelPreview.isDrawableForm(preview)
          ? SizedBox.square(
              key: LayoutSheet.previewPlaceholderKey,
              dimension: _PanelPreview._thumbnailSize,
              child: Icon(MdiIcons.viewDashboardOutline, color: Theme.of(context).colorScheme.onSurfaceVariant),
            )
          : Semantics(
              button: true,
              label: t.showPreview(panel: panel.title),
              child: InkWell(
                // Inside the tile, so it takes the tap before the row does —
                // and a Builder is unnecessary here because the pane opens
                // against the sheet's own route either way.
                onTap: () => _showPreview(context, panel, preview),
                child: _PanelPreview(preview: preview),
              ),
            ),
      title: Text(panel.title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: panel.description == null ? null : Text(panel.description!),
      // The whole row adds; the plus only says so. It is not a second
      // control — two focus stops doing one thing is one too many.
      trailing: onAdd == null ? null : Icon(MdiIcons.plus, semanticLabel: t.addPanel(panel: panel.title)),
      onTap: onAdd == null ? null : () => onAdd(panel.id),
    );
  }

  /// The preview at pane scale. A 40pt thumbnail says a panel HAS a preview;
  /// it does not say what the panel looks like, which is the whole question
  /// when picking one out of Available Panels.
  void _showPreview(BuildContext context, LayoutPanelEntry panel, String preview) {
    showModalPane<void>(
      context,
      title: panel.title,
      closeLabel: context.t.common.close,
      builder: (paneContext) => Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: _PanelPreview(
                preview: preview,
                size: _PanelPreview._paneSize,
                unavailable: Text(
                  context.t.operation.layout.previewUnavailable,
                  style: Theme.of(paneContext).textTheme.bodyMedium?.copyWith(color: Theme.of(paneContext).colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            if (panel.description case final description?) ...[
              const SizedBox(height: Space.lg),
              Text(description, style: Theme.of(paneContext).textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.operation.layout;
    final query = _searchController.text.trim();
    final available = [
      for (final panel in widget.available)
        if (_matches(panel, query)) panel,
    ];
    final locale = LocaleSettings.currentLocale.languageCode;
    final enable = widget.onEnableExtension == null
        ? const <ExtensionInfo>[]
        : [
            for (final info in widget.enableable)
              if (info.matchesSearch(query, locale: locale)) info,
          ];
    final install = widget.onInstallExtension == null
        ? const <CatalogEntry>[]
        : [
            for (final entry in widget.installable)
              if (entry.matchesSearch(query, locale: locale)) entry,
          ];
    return Material(
      color: haloSheetListBackground(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Builder(
            builder: (context) {
              final searchBorder = OutlineInputBorder(borderRadius: BorderRadius.circular(8));
              return Padding(
                padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, Space.md),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        selectAllOnFocus: false,
                        controller: _searchController,
                        onChanged: (text) {
                          setState(() {});
                          if (text.trim().isNotEmpty) widget.onSearch?.call();
                        },
                        decoration: InputDecoration(
                          isDense: true,
                          prefixIcon: const Icon(MdiIcons.magnify, size: 18),
                          suffixIcon: query.isEmpty
                              ? null
                              : IconButton(
                                  icon: Icon(MdiIcons.close, size: 18, semanticLabel: context.t.common.clear),
                                  onPressed: () => setState(_searchController.clear),
                                ),
                          hintText: t.searchHint,
                          border: searchBorder,
                          // The theme deliberately leaves `focusedBorder` unset
                          // (see haloFocusedBorder), so a decoration that builds
                          // its own border has to pass it through — Material's
                          // own primary indicator is 2.67:1 on the dark surface.
                          focusedBorder: haloFocusedBorder(searchBorder, context),
                        ),
                      ),
                    ),
                    if (widget.onManageExtensions != null) ...[
                      const SizedBox(width: Space.md),
                      IconButton(
                        icon: Icon(MdiIcons.puzzle, semanticLabel: context.t.activitiesView.manageExtensions),
                        onPressed: widget.onManageExtensions,
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          // A restart, and for an install a download, lie between the tap and
          // the panels arriving; rows that merely stop answering read as stuck.
          if (_gaining) const LinearProgressIndicator(),
          _sectionHeader(context, t.availableSection, key: LayoutSheet.availableSectionKey),
          // A sheet that renders nothing at all reads as one that failed to
          // load. There IS a way to get here with nothing to add — every
          // panel placed, none of them instanceable.
          // Not beside an Enable/Install row: "no panel matches" above an
          // offer of one would contradict it.
          if (available.isEmpty && enable.isEmpty && install.isEmpty)
            Padding(
              padding: const EdgeInsets.all(Space.xl),
              child: Text(
                // Two different nothings: a search that found none of the
                // panels there ARE, and a view that already holds all of them.
                query.isEmpty ? t.nothingToAdd : t.noPanelsMatch,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          for (final panel in available) _panelRow(context, panel),
          // Below what is already here: a panel the operator has is the
          // answer, and one that has to be enabled or downloaded first is
          // the fallback.
          for (final info in enable) _enableRow(context, info, locale),
          for (final entry in install)
            InstallExtensionRow(entry: entry, onTap: _gaining ? null : () => unawaited(_gain(() => widget.onInstallExtension!(entry), entry.nameFor(locale)))),
        ],
      ),
    );
  }
}
