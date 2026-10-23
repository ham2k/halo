// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Add a Panel sheet, as the dock host opens it: this view's own panels and
// the ones extensions contribute (docs/design/layouts.md). A part of
// dock_host.dart, like named_layouts.dart, for the host's private per-class
// state.

part of '../dock_host.dart';

extension AddPanelSheet<T extends StatefulWidget> on DockHost<T> {
  Future<void> openAddPanelSheet() async {
    // The sheet's own header carries this very button (see [headerTrailing]),
    // so the obvious thing to press while it is up reopens it. A second route
    // would take over `_sheetRevision` — orphaning the first sheet's list —
    // and on closing would clear `layoutSheetOpen` under a sheet still on
    // screen, putting a dead copy of the controls in the header beneath it.
    if (layoutSheetOpen) return;
    final dock = dockKey.currentState;
    if (dock == null) {
      // NOT asserted-impossible: this button lives in the view's own header,
      // outside the dock's own tree, so a breakpoint crossing the two-pane
      // threshold can unmount the dock while the button stays up. A silent
      // no-op is correct here, not a bug — see `onAdd`'s matching guard for
      // the same condition reached through the sheet this button opens.
      debugPrint('[layout] add-panel-no-dock: add-panel button pressed with no dock mounted');
      return;
    }
    // An extension enabled since this view mounted has panels nobody has asked
    // for yet, and this is where the operator would go looking for them. The
    // answer lands after the sheet is already built, which is why the sheet
    // rebuilds on `revision` rather than reading the catalog once.
    unawaited(dockServices.panels.refreshExtensionPanels());
    final revision = _sheetRevision = ValueNotifier<int>(0);
    // Per sheet, so a sheet fetches the catalog at most once however much is
    // typed into it.
    final catalogTier = CatalogTier();
    final t = _t;
    _rebuild(() => layoutSheetOpen = true);
    try {
      await showTopModalPane<void>(
        context,
        rightInset: _addPanelButtonRightInset,
        // Narrower than a form pane: every row here is a panel name and a
        // control or two.
        maxWidth: idealPaneWidth * 0.8,
        // The sheet's rows and section bands run edge to edge, like the
        // operation sheet's — a list inset from the pane's walls reads as a
        // panel floating inside it rather than as the pane's own content.
        contentPadding: EdgeInsets.zero,
        closeLabel: context.t.common.close,
        // The header's layout controls, drawn by the route into the strip of
        // header it leaves uncovered — the view's own copies are suppressed
        // while this is up (see [layoutHeaderControls]). Rebuilt on the same
        // revision the sheet body is, since Save Layout is one of them and
        // changes which of them there are.
        headerTrailing: ValueListenableBuilder<int>(
          valueListenable: revision,
          // A context from inside the route, so the buttons resolve their
          // theme and their locale where they are actually drawn.
          builder: (headerContext, _, _) =>
              Row(mainAxisSize: MainAxisSize.min, children: [...layoutHeaderControls(headerContext, inSheet: true), windowsCaptionSpacer(context)]),
        ),
        // A mirror of the operation sheet's top row, because this sheet hangs
        // off the opposite end of the same header: the title against the edge
        // the sheet came from, and the accept button at that edge. Its own
        // trailing inset: HaloDialogHeader puts the title's Expanded and the
        // accept button flush against each other, and a right-aligned title
        // ends exactly where that button starts.
        title: Padding(
          padding: const EdgeInsets.only(right: Space.lg),
          child: Text(t.title, textAlign: TextAlign.right),
        ),
        // Nothing is held back to be saved here — a removed panel is gone the
        // moment it's tapped — so this only dismisses; it exists because a
        // sheet with an accept button and one without read as two different
        // kinds of surface.
        trailing: Builder(
          builder: (buttonContext) => IconButton(
            icon: Icon(MdiIcons.check, semanticLabel: t.done),
            style: IconButton.styleFrom(backgroundColor: fabAccentColor, foregroundColor: Theme.of(buttonContext).colorScheme.onPrimary),
            onPressed: () => Navigator.of(buttonContext).pop(),
          ),
        ),
        builder: (sheetContext) => ValueListenableBuilder<int>(
          valueListenable: revision,
          builder: (context, _, _) {
            final extensions = dockServices.extensions;
            final locale = LocaleSettings.currentLocale.languageCode;
            String? extensionName(String? key) =>
                key == null ? null : extensions.availableExtensions.where((info) => info.key == key).firstOrNull?.nameFor(locale);
            // Re-read per build: the dock can go out from under an open sheet
            // (a resize past a breakpoint), and the list is then about an
            // arrangement that is not on screen. Falling back to the draft
            // keeps it describing the same thing the header does.
            final inLayout = dockKey.currentState?.modules ?? dockSpec?.collectModules() ?? const <String>[];
            return LayoutSheet(
              // Catalog order, not the order things were taken out in, so a
              // panel returns to the same place in the list it left from.
              // Everything a row shows — name, description, preview — comes
              // from the panels service, so a panel an extension contributed
              // lists exactly like one of ours.
              available: [
                // This view's own panels and the extension panels, never
                // another view's: an Operation List pane has no meaning inside
                // an operation, and offering one is offering a broken pane.
                for (final panel in dockServices.panels.catalogFor(dockView))
                  // A panel that may be placed more than once stays offered
                  // however many are already in the layout — that row IS the
                  // "add another" control, and there is no other.
                  if (panel.multiple || !inLayout.contains(panel.id))
                    LayoutPanelEntry(
                      id: panel.id,
                      title: panel.title,
                      description: panel.description,
                      preview: panel.preview,
                      extensionName: panel.source == PanelSource.extension ? extensionName(panel.hookKey) : null,
                    ),
              ],
              // Not a core one (always on), not one an experiment gates (enabling
              // it could not load it) — the same rule [_hasPanelExtensions] uses.
              enableable: [
                for (final info in extensions.availableExtensions)
                  if (!info.core && info.hooks.contains(HookCategories.panel) && extensions.isExtensionAvailable(info) && !extensions.isExtensionEnabled(info))
                    info,
              ],
              installable: switch (catalogTier.entries) {
                final entries? => orderedCatalogEntries(
                  [
                    for (final entry in entries)
                      if (entry.hooks.contains(HookCategories.panel) && !extensions.availableExtensions.any((info) => info.key == entry.key)) entry,
                  ],
                  dockServices.flags.operatorGeo,
                  locale,
                ),
                null => const [],
              },
              onSearch: () => catalogTier.ensureFetched(dockServices, bumpSheet),
              onEnableExtension: (info) => _gainPanelExtension(() async {
                await extensions.setExtensionEnabled(info.key, true);
                return true;
              }),
              onInstallExtension: (entry) => _gainPanelExtension(() => installCatalogExtension(context, services: dockServices, entry: entry)),
              onAdd: (id) {
                // Adding an instanceable panel places a NEW one rather than
                // re-adding the descriptor: its id is what its config is stored
                // under, so two panes sharing one would share their contents
                // too.
                final dock = dockKey.currentState;
                // NOT asserted-impossible: the sheet is a route and outlives
                // the dock across a breakpoint that crosses the two-pane
                // threshold and unmounts it — a silent no-op here is what
                // stops that resize from throwing a setState-after-dispose
                // through a callback the sheet is still holding.
                if (dock == null) return;
                final panel = dockServices.panels[id];
                // Adding is what the operator came here for; the sheet has
                // nothing more to say once it is done.
                Navigator.of(sheetContext).pop();
                dock.addModule(
                  panel != null && panel.multiple
                      // Ids waiting to be forgotten are NOT free. Their config
                      // outlives the removal until the save commits it, so
                      // handing one to a new placement gives the operator a
                      // pane that arrives holding the last one's notes — and
                      // the save then spares it, seeing the id back in the
                      // arrangement.
                      ? PanelService.nextInstanceId(id, [...dock.modules, ..._allPendingForgets, ..._instanceIdsInEveryDock()])
                      : id,
                );
              },
              // Filtered to the extensions that contribute panels — an
              // operator sent here for more panels should not be handed the
              // whole catalog. Offered only when it leads somewhere: with no
              // panel extension installed at all, a button whose whole
              // purpose is "find the panel you want" opening an empty list is
              // worse than no button.
              onManageExtensions: _hasPanelExtensions
                  ? () => unawaited(() async {
                      await showModalPane<void>(
                        context,
                        title: context.t.activitiesView.manageExtensions,
                        closeLabel: context.t.common.close,
                        // The list scrolls; the footer stays pinned under it
                        // and its Done is the way out — so no X in the header
                        // (see haloDialogFooterBand).
                        scrollable: false,
                        closeButton: false,
                        builder: (_) => ExtensionsPanel(services: dockServices, onlyHook: HookCategories.panel, footer: true),
                      );
                      await dockServices.panels.refreshExtensionPanels();
                      bumpSheet();
                    }())
                  : null,
            );
          },
        ),
      );
    } finally {
      _sheetRevision = null;
      revision.dispose();
      // The sheet's own close, an Escape and a tap on the barrier all land
      // here.
      if (mounted) _rebuild(() => layoutSheetOpen = false);
    }
  }

  /// Enables or installs an extension from the Add a Panel sheet, then waits
  /// for its panels to be listed, so the sheet's search lands on them. False
  /// covers a cancelled install and a failure, which is reported here; the
  /// sheet then only stops its progress bar and leaves the search as it was.
  Future<bool> _gainPanelExtension(Future<bool> Function() gain) async {
    try {
      if (!await gain()) return false;
      await dockServices.panels.refreshExtensionPanels();
      bumpSheet();
      return true;
    } catch (e, stack) {
      debugPrint('[layout] gaining a panel extension failed: $e');
      ErrorReportingService.report(e, stack, context: 'layout:gain-panel-extension');
      return false;
    }
  }
}
