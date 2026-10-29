// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The header's layout controls and the options buttons on panes and views,
// as the dock host draws them (docs/design/layouts.md). A part of
// dock_host.dart, like named_layouts.dart, for the host's private state.
//
// These are extension members, so a view cannot override them: one it
// declares under the same name shadows it only for the view's own calls,
// while every call from the host still reaches the one here.

part of '../dock_host.dart';

extension LayoutControls<T extends StatefulWidget> on DockHost<T> {
  /// Whether any extension the operator could enable contributes a panel. The
  /// Extensions list this opens is filtered to the `panel` hook, and a gated
  /// extension is not in it either.
  bool get _hasPanelExtensions {
    final extensions = dockServices.extensions;
    return extensions.availableExtensions.any((info) => !info.core && info.hooks.contains(HookCategories.panel) && extensions.isExtensionAvailable(info));
  }

  double? get _addPanelButtonRightInset {
    final box = _addPanelButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return null;
    final rightEdge = box.localToGlobal(Offset(box.size.width, 0)).dx;
    return math.max(0.0, MediaQuery.sizeOf(context).width - rightEdge);
  }

  /// The one control a pane carries while the layout is being edited, at the
  /// trailing end of its own header: its LAYOUT options.
  ///
  /// Deliberately not the panel's own settings, which are a different kind of
  /// thing and reachable from the panel while it is being used. These are the
  /// dock's business — what the pane is called here, whether it shows a
  /// header, how big it draws — and every pane has them whichever panel is in
  /// it (see [PaneLayoutOptions]).
  ///
  /// Removing a pane is NOT here: it is the drag target at the top of the
  /// dock. A delete button on every pane is one an operator can hit while
  /// doing something else, and what it destroys is a pane they arranged and
  /// configured.
  Widget paneEditControls(BuildContext context, String id) {
    final theme = Theme.of(context);
    final panel = dockServices.panels[id];
    final options = paneOptions[id] ?? PaneLayoutOptions.none;
    // What the pane would be called with no override — the placeholder the
    // dialog shows, so the operator can see what they are replacing.
    final defaultTitle = defaultTitleFor(id);
    // A plain-form extension panel's settings embed as an
    // [EmbeddedPanelSettingsForm]; a pane the VIEW answers for natively is
    // reached through a target instead and builds its own form above.
    final embeddablePanel = _panelSettingsOverride(context, id) == null && panel != null && panel.formFields.isNotEmpty ? panel : null;
    return IconButton(
      icon: Icon(
        MdiIcons.viewDashboardEdit,
        color: theme.colorScheme.onPrimary,
        semanticLabel: _t.paneOptionsTitle(panel: options.title ?? defaultTitle),
      ),
      onPressed: () async {
        // A mutable copy, not the host's own map — kept current below as each
        // field commits, so a later edit's no-op check compares against what
        // was actually last WRITTEN, not this snapshot from when the dialog
        // opened. Against a snapshot that never moves, an edit landing back on
        // the value the dialog opened with reads as "already this" and is
        // dropped, even after a real commit moved it away and back.
        final panelConfig = embeddablePanel != null ? Map<String, dynamic>.of(await dockServices.panels.configFor(embeddablePanel)) : null;
        if (!context.mounted) return;
        unawaited(
          showPaneLayoutOptions(
            context,
            paneTitle: options.title ?? defaultTitle,
            defaultTitle: defaultTitle,
            // The header is the tab strip once a pane shares a group, so hiding it
            // is not on offer there — nor for a CONTAINER at all, whose tab is the
            // only thing naming it and the only handle for moving or removing it.
            // A toggle that wrote a setting nothing reads would be worse than none.
            inTabset: groupSizeOf(id) > 1 || isDockContainerId(id),
            // A container's subtree is rendered by the DOCK, not through this
            // view's per-pane wrapper, so these three would be stored and never
            // read. Its title still is — that comes from `dockTitles`.
            showSizeFields: !isDockContainerId(id),
            headerByDefault: !defaultHeaderlessModules.contains(id),
            developerMode: dockServices.settings.developerMode,
            current: options,
            resetTitle: _t.resetPaneConfirm(panel: options.title ?? defaultTitle),
            resetBody: _t.resetPaneConfirmBody,
            onReset: () => _rebuild(() => paneOptions.remove(id)),
            // The keyboard/screen-reader route to what the delete target does: a
            // drag cannot be made without a pointer, and Restore Defaults is the
            // whole arrangement. Absent for the last pane, which the dock refuses
            // to remove — an empty dock has no tab left to drag anything back
            // with — and for a pinned one, which it refuses for its own reasons
            // (see [pinnedModuleIds]); an offered Remove that silently did nothing
            // would be worse than none.
            onDelete: _canRemove(id)
                ? () {
                    final dock = dockKey.currentState;
                    // NOT asserted-impossible: the dialog this button lives in is
                    // a route, which outlives the dock across a breakpoint that
                    // crosses the two-pane threshold and unmounts it — same
                    // condition [AddPanelSheet.openAddPanelSheet] and `onAdd` guard against.
                    if (dock == null) return;
                    // No forget here: the dock reports every module it actually
                    // dropped through `onModuleDeleted`, which is one id for a
                    // pane and several for a container.
                    dock.removeModule(id);
                  }
                : null,
            // Hiding a pane's header takes the tab action with it, and that is the
            // only other way to a panel's own settings.
            //
            // No `actions` / no `type: 'action'` elements in any of these: an
            // action here would need a route of its own to signal "done" by
            // closing, and this embed has none — it lives inside the pane layout
            // options dialog, not behind a route it owns.
            panelSettingsBuilder:
                _panelSettingsOverride(context, id) ??
                (embeddablePanel != null && panelConfig != null
                    ? (builderContext) => EmbeddedPanelSettingsForm(
                        fields: embeddablePanel.formFields.where((field) => field['type'] != 'action').toList(),
                        initial: panelConfig,
                        developerMode: dockServices.settings.developerMode,
                        onFieldChange: (key, value, state) async {
                          final field = embeddablePanel.formFields.firstWhere((f) => f['key'] == key, orElse: () => const {});
                          if (sameConfigValue(value, panelConfig[key], field['value'])) return;
                          await dockServices.extensions.commitSettingsFieldValue(
                            kind: 'simple',
                            hookKey: embeddablePanel.hookKey ?? embeddablePanel.id,
                            panelKey: embeddablePanel.id,
                            fieldKey: key,
                            value: value,
                            state: state,
                            isSecret: field['fieldType'] == 'secret',
                          );
                          // Keeps the no-op check above comparing against what
                          // was actually last committed.
                          panelConfig[key] = value;
                          dockServices.panels.markConfigChanged(embeddablePanel.id);
                        },
                      )
                    : null),
            onChanged: (next) => _rebuild(() {
              // Dropped rather than stored empty, so a layout carries options only
              // for the panes that actually have any.
              if (next.isEmpty) {
                paneOptions.remove(id);
              } else {
                paneOptions[id] = next;
              }
            }),
          ),
        );
      },
    );
  }

  /// An extension panel's own configuration, on its tab — the counterpart of
  /// the logging pane's tune button, and the only route to a form whose fields
  /// configure that pane and nothing else.
  Widget buildPanelSettingsButton(PanelDefinition panel, {required BuildContext context}) {
    final theme = Theme.of(context);
    return Builder(
      builder: (buttonContext) => IconButton(
        icon: Icon(
          MdiIcons.tune,
          color: theme.appBarTheme.foregroundColor ?? theme.colorScheme.onPrimary,
          semanticLabel: _t.panelSettings(panel: panel.title),
        ),
        onPressed: () => unawaited(
          // The panels that answer for their own settings do so from BOTH
          // routes — this button and the pane layout options' embed — or the
          // same panel would offer two different settings surfaces depending
          // on which way in the operator took.
          switch (_panelSettingsOverride(buttonContext, panel.id)) {
            final override? => showHaloDialog<void>(
              context: buttonContext,
              builder: (dialogContext) => HaloDialog(
                title: Text(panel.title),
                // An override scrolls itself, as the pane layout options'
                // embed already requires of it; a second scroll view around a
                // reorderable list would leave a drag nothing to auto-scroll.
                scrollable: false,
                content: Builder(builder: override),
                cancel: TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(dialogContext.t.common.done)),
              ),
            ),
            null => showPanelSettings(buttonContext, services: dockServices, panel: panel),
          },
        ),
      ),
    );
  }

  /// A tune-icon button that opens a target-scoped settings dialog — the
  /// counterpart of [buildPanelSettingsButton] for a pane the VIEW answers
  /// for natively (through its own [nativePanelSettingsForm] override)
  /// rather than through `formFields`.
  Widget buildTargetSettingsButton(
    BuildContext context, {
    required String target,
    required String title,
    List<TargetDialogAction> actions = const [],
    Map<String, SettingsGroup>? groupOverrides,
  }) {
    final theme = Theme.of(context);
    return Builder(
      builder: (buttonContext) => IconButton(
        icon: Icon(
          MdiIcons.tune,
          color: theme.appBarTheme.foregroundColor ?? theme.colorScheme.onPrimary,
          semanticLabel: MaterialLocalizations.of(context).showMenuTooltip,
        ),
        onPressed: () =>
            showSettingsForTarget(buttonContext, services: dockServices, target: target, title: title, actions: actions, groupOverrides: groupOverrides),
      ),
    );
  }

  /// The VIEW's own layout options, beside the title rather than out in the
  /// actions group: it is about the thing the title names, and the actions are
  /// about the EDIT — add a panel, discard it, save it. Hidden while the Add a
  /// Panel sheet is up, like every other control down here, since the view's
  /// header takes no taps under a modal route.
  Widget? viewOptionsButton(BuildContext context, {required bool editing}) {
    if (!editing || layoutSheetOpen) return null;
    final theme = Theme.of(context);
    return IconButton(
      // The same glyph a pane's options carry, because it is the same kind of
      // thing one level up. What tells them apart is where they are.
      icon: Icon(MdiIcons.viewDashboardEdit, color: theme.appBarTheme.foregroundColor ?? theme.colorScheme.onPrimary, semanticLabel: _t.viewOptions),
      onPressed: () => unawaited(
        showPaneLayoutOptions(
          context,
          paneTitle: viewOptions.title ?? _t.viewName,
          defaultTitle: _t.viewName,
          inTabset: false,
          // A view has no header of its own to hide, and this one is the app's,
          // so its name is not the operator's to change.
          showHeaderField: false,
          titleEnabled: false,
          developerMode: dockServices.settings.developerMode,
          current: viewOptions,
          onChanged: (next) => _rebuild(() => viewOptions = next),
          resetTitle: _t.resetViewConfirm,
          resetBody: _t.resetViewConfirmBody,
          onReset: restoreLayoutDefaults,
        ),
      ),
    );
  }

  /// The header's layout controls.
  ///
  /// Out of edit mode this is one always-visible button, and pressing it goes
  /// straight into editing: there is no sheet in the way, because what an
  /// operator wants when they reach for this is to move a pane.
  ///
  /// Built HERE but rendered in two places, never both at once: the view's own
  /// header while no sheet is up, and the Add a Panel sheet's `headerTrailing`
  /// while one is — the view's header takes no taps under a modal route, so a
  /// button left there would be visible and dead. [inSheet] for the sheet's own
  /// copy. Only the VIEW's copy carries [_addPanelButtonKey]: popping the sheet
  /// completes its route future — and so un-suppresses the view's copy — while
  /// the route is still animating out, so for those few frames both copies are
  /// mounted, and one GlobalKey across two of them throws.
  List<Widget> layoutHeaderControls(BuildContext context, {bool inSheet = false}) {
    // The VIEW's copy is suppressed while the sheet is up — the route draws
    // its own into the strip of header it leaves uncovered, and a copy left
    // here would be a second set of Save/Discard buttons, visible and dead
    // under a modal route. Enforced HERE rather than at each call site: this
    // method's contract is "rendered in two places, never both at once", and a
    // host that has to remember a guard is a host that will forget it.
    if (!inSheet && layoutSheetOpen) return const [];
    final theme = Theme.of(context);
    // The app shows no hover tooltips (docs/design/user-interface.md), so an
    // icon button's accessible name is the only place it is named.
    final onHeader = theme.appBarTheme.foregroundColor ?? theme.colorScheme.onPrimary;
    if (!layoutEditing) {
      return [
        // With one layout there is nothing to switch to, and the editor is
        // where a second one is made.
        if (namedLayoutsOffered && viewLayouts.layouts.length > 1) _layoutSwitcher(context, onHeader, inSheet: inSheet),
        Listener(
          // Pointer-down, not `onPressed`. A click anywhere outside a text
          // field unfocuses it first — TextField's own tap-outside — and that
          // unfocus clears the scope's memory of WHICH child had it. By the
          // time the callback runs, `primaryFocus` is the scope, and handing
          // that back at the end of the edit focuses nothing.
          onPointerDown: (_) => _focusAtPress = FocusManager.instance.primaryFocus,
          // Dropped again once the press is over. A press dragged off the
          // button never becomes a tap, and a capture left behind is one a
          // LATER keyboard-activated entry would restore instead of what was
          // actually focused then — putting the operator's next keystrokes in
          // a field they left minutes ago. The post-frame is what lets
          // [startLayoutEditing] claim it first on a real tap.
          onPointerUp: (_) => _dropPressFocusCapture(),
          onPointerCancel: (_) => _dropPressFocusCapture(),
          child: IconButton(
            icon: Icon(MdiIcons.viewDashboard, color: onHeader, semanticLabel: _t.editLayout),
            onPressed: startLayoutEditing,
          ),
        ),
      ];
    }
    return [
      // Not in the sheet's own copy: this is the button that OPENED it, and
      // pressing it again is refused (see [AddPanelSheet.openAddPanelSheet]). An enabled,
      // focusable, screen-reader-announced control that does nothing is worse
      // than one that is not there — the sheet in front of the operator is
      // already the answer.
      if (!inSheet)
        IconButton(
          key: _addPanelButtonKey,
          icon: Icon(MdiIcons.plus, color: onHeader, semanticLabel: _t.title),
          onPressed: () => unawaited(openAddPanelSheet()),
        ),
      IconButton(
        // Left of Save, and an icon rather than a second labelled button:
        // saving is what the operator came here to do, and discarding is the
        // way back out from a rearrangement they thought better of.
        icon: Icon(MdiIcons.undoVariant, semanticLabel: _t.revertLayout),
        color: onHeader,
        onPressed: () => _endEditingFrom(context, inSheet: inSheet, exit: revertLayout),
      ),
      // With named layouts, the edit says WHICH layout it is saving into: the
      // same switcher as outside the edit sits left of a bare Save, which
      // stays the rightmost control.
      if (namedLayoutsOffered) ...[
        _layoutSwitcher(context, onHeader, inSheet: inSheet),
        IconButton(
          icon: Icon(MdiIcons.contentSave, semanticLabel: _t.saveLayout),
          color: onHeader,
          onPressed: () => _endEditingFrom(context, inSheet: inSheet, exit: saveLayout),
        ),
      ] else
        TextButton.icon(
          onPressed: () => _endEditingFrom(context, inSheet: inSheet, exit: saveLayout),
          icon: const Icon(MdiIcons.contentSave, size: 18),
          label: Text(_t.saveLayout),
          style: TextButton.styleFrom(foregroundColor: onHeader),
        ),
    ];
  }
}
