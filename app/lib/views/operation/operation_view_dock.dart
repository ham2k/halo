// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Operation view's dock: which panes it has, how they are registered
// and titled, the default arrangements, and the settings each pane offers.

part of '../operation_view.dart';

mixin _OperationDock on State<OperationView>, DockHost<OperationView> {
  // Owned by `_OperationViewState`.
  OperationRuntimeState get _runtime;
  CallInfoData? get _callInfo;
  void _republishPeerHeaderIfChanged(Operation operation);
  void _openFind();

  @override
  HaLoServices get dockServices => widget.services;

  @override
  String get dockView => PanelViews.operation;

  @override
  DockLayoutKeys dockKeysFor(DockLayoutClass layoutClass) => switch (layoutClass) {
    DockLayoutClass.wide => const DockLayoutKeys(
      spec: LayoutKeys.operationDock,
      state: LayoutKeys.operationDockState,
      paneOptions: LayoutKeys.operationPaneOptions,
      viewOptions: LayoutKeys.operationViewOptions,
    ),
    DockLayoutClass.narrow => const DockLayoutKeys(
      spec: LayoutKeys.operationNarrowDock,
      state: LayoutKeys.operationNarrowDockState,
      paneOptions: LayoutKeys.operationNarrowPaneOptions,
      viewOptions: LayoutKeys.operationNarrowViewOptions,
    ),
  };

  /// The logging pane is pinned NARROW and only narrow. A phone with no
  /// logging pane cannot enter a QSO at all, and the arrangement that took it
  /// away looks like any other — whereas wide always draws logging alongside
  /// whatever else is arranged, so there is nothing there to protect.
  @override
  Set<String> pinnedModuleIdsIn(DockLayoutClass layoutClass) => layoutClass == DockLayoutClass.narrow ? const {'logging'} : const {};

  @override
  Set<String> get nativeModuleIds => {
    ..._dockModuleIds,
    // Only while the experiment is on — and it must match `children` below
    // exactly. Named here but absent there renders no pane at all; absent
    // from both is what routes a saved placement to MissingPanelPane.
    if (_peerPositionsPanel) 'positions',
  };

  /// Whether the Positions panel exists in this build at all.
  bool get _peerPositionsPanel => widget.services.settings.experimentEnabled('p2p') /* stored key, see experiments.yaml */;

  @override
  Map<String, String> get nativeTitles => {
    // The logging tab carries a live count; the catalog's own title for it is
    // the plain name the Add a Panel sheet lists.
    'logging': context.t.operation.tabs.qsos(count: _realQsoCountForTabs),
    'info': context.t.operation.tabs.info,
    'spots': context.t.operation.tabs.spots,
    'map': context.t.operation.tabs.map,
    if (_peerPositionsPanel) 'positions': context.t.operation.positions.panelTitle,
  };

  /// The count the logging tab's label carries, kept as a field because
  /// [nativeTitles] is read by the mixin without it.
  int _realQsoCountForTabs = 0;

  /// The log stream's latest list, for the panels' `qsoLogged` trigger
  /// (`PanelRenderContext.log`).
  List<Qso>? _logForPanels;

  /// Surface the logging panel wherever this layout keeps it.
  void _revealLoggingPanel() => dockKey.currentState?.revealModule('logging');

  /// Whether a panel in the CURRENT arrangement declared [trigger]. Every
  /// signal an extension panel can be woken by costs this view something to
  /// produce — a rebuild on a timer, or a QSO draft rebuilt per keystroke —
  /// so each one is gated on somebody actually having asked for it.
  /// Reads the EFFECTIVE triggers, so a signal only one placement asked for
  /// in its last render — an operator's template naming the callsign being
  /// typed — starts being produced. `PanelService` notifies when that set
  /// changes, and the dock host's catalog listener rebuilds, which is what
  /// makes the new answer take effect. The first render of such a template
  /// necessarily happens before it: the panel is answered with no draft,
  /// then woken by the next change to one.
  bool _anyPanelWants(String trigger) {
    return dockSpec?.collectModules().any((id) => widget.services.panels.triggersFor(id).contains(trigger)) ?? false;
  }

  /// Where the Info pane is in the layout, surface it and let it show
  /// whatever it shows. Answers whether it actually did: a custom
  /// layout the operator has dropped the Info pane out of has nothing to
  /// reveal (`revealModule` no-ops on a module that isn't there), and a tap
  /// that stops here would spend its splash on nothing. Saying so lets the
  /// caller fall back to the modal, which always works.
  bool _revealInfoPane() {
    // Asked of the dock, never of the width: the narrow arrangement ships
    // without an Info pane but the operator may have added one, and `modules`
    // is what actually answers that — a width test would refuse a pane that
    // is on screen.
    final dock = dockKey.currentState;
    if (dock == null || !dock.modules.contains('info')) return false;
    dock.revealModule('info');
    return true;
  }

  /// The logging panel's own settings — field visibility, dupe/number
  /// display, a bulk lookup refresh — behind the tune icon, built from
  /// every declared setting targeting `'logging'`
  /// (settings/settings_target_dialog.dart), rather than the operation
  /// view's AppBar, since none of this applies to the Info/Spots/Map tabs.
  /// Rendered on the logging module's own tab or pane header, in both dock
  /// classes.
  Widget _buildLoggingSettingsButton(List<Qso> qsos, {BuildContext? context}) {
    // Defaults to this State's own context, but the dock layout's
    // `tabActions` is a `WidgetBuilder` specifically so its call site can
    // pass a context at the module's real tree position instead (see
    // `_buildGroup`'s own Builder) — using the
    // wrong one is currently harmless (no nested Theme/Localizations
    // override exists anywhere in the dock tree today) but would silently
    // read the wrong ambient values the day one is added.
    final effectiveContext = context ?? this.context;
    return buildTargetSettingsButton(
      effectiveContext,
      target: 'logging',
      // The logging view's own title for its own dialog — distinct from
      // LoggingSettingsGroup.title ("Logging"), which names the group as it
      // appears in Settings, a different surface
      // with a different audience.
      title: effectiveContext.t.operation.menu.loggingSettingsTitle,
      // The pane's layout options embeds this same target's fields too, but
      // without this Actions section — see [_paneEditControls]'s
      // `panelSettingsBuilder`, which passes none.
      actions: [
        // ⌘F's twin, for a device with no keyboard to press it on.
        (
          icon: 'magnify',
          label: effectiveContext.t.qsoList.find.menuItem(shortcut: findChordLabel),
          onTap: () {
            Navigator.of(effectiveContext).pop();
            _openFind();
          },
        ),
        (
          icon: 'refresh',
          label: effectiveContext.t.operation.menu.lookupAllQsos,
          // Refreshes lookup data (QRZ, HamDB…) for the whole log via the
          // background queue — rows repaint as results land, and anything
          // but a handful of QSOs also shows progress in the status bar.
          // The queue itself filters out event markers etc. Not itself a
          // persisted setting, so it's an Actions-section item rather than
          // a target element.
          onTap: () {
            Navigator.of(effectiveContext).pop();
            widget.services.lookupQueue.enqueueAll(qsos);
          },
        ),
      ],
    );
  }

  /// The Map tab's basemap picker (see MapSettingsGroup). Same shape as
  /// [_buildLoggingSettingsButton]: the Map panel is native and reaches its
  /// settings through a target, not `formFields`, so
  /// [DockHost.buildPanelSettingsButton] wouldn't find it either.
  Widget _buildMapSettingsButton({BuildContext? context}) =>
      buildTargetSettingsButton(context ?? this.context, target: 'map', title: (context ?? this.context).t.operation.menu.mapSettingsTitle);

  /// The panes this view builds itself, arranged by a persisted,
  /// user-editable dock tree (drag a tab to move a pane; see
  /// dock_layout.dart). No 'operation' pane: its settings live in the
  /// operation sheet.
  static const _dockModuleIds = ['logging', 'info', 'spots', 'map'];

  /// What an operator who never edits sees, and what Restore Defaults puts
  /// back.
  ///
  /// Wide: logging on the left, the rest tabbed on the right. Narrow: one tab
  /// strip of QSOs, Spots and Map. Info is not in the narrow one — it is a tap
  /// away on the callsign area — but it is offered by the sheet like any
  /// other panel.
  @override
  DockNode buildDefaultDockSpec(DockLayoutClass layoutClass, {bool migrate = true}) => switch (layoutClass) {
    DockLayoutClass.narrow => DockGroup(['logging', 'spots', 'map']),
    DockLayoutClass.wide => DockSplit(
      Axis.horizontal,
      [
        DockGroup(['logging']),
        // Selected: Info.
        DockGroup(['info', 'spots', 'map']),
      ],
      [2, 1],
    ),
  };

  /// Registers this view's own panels with the service. Called from
  /// [didChangeDependencies] rather than [initState] because the titles are
  /// localized — a locale change has to reach the catalog too.
  void _registerNativePanels() {
    final t = context.t.operation;
    final service = widget.services.panels;
    service.registerNative(
      PanelDefinition(
        id: 'logging',
        title: t.tabs.qsosPlain,
        description: t.layout.panels.loggingDescription,
        icon: 'notebook',
        source: PanelSource.native,
        views: const {PanelViews.operation},
        // The same field-visibility and dupe/number toggles the logging
        // panel's own tune button opens.
        settingsTarget: 'logging',
      ),
    );
    service.registerNative(
      PanelDefinition(
        id: 'info',
        title: t.tabs.info,
        description: t.layout.panels.infoDescription,
        icon: 'informationOutline',
        source: PanelSource.native,
        views: const {PanelViews.operation},
      ),
    );
    // Registered only with the experiment on, exactly as Remote Screen is: a
    // saved arrangement holding one then falls to the missing-panel
    // placeholder rather than vanishing, and the operator keeps their layout.
    if (widget.services.settings.experimentEnabled('p2p') /* stored key, see experiments.yaml */ ) {
      service.registerNative(
        PanelDefinition(
          id: 'positions',
          title: t.positions.panelTitle,
          description: t.positions.panelDescription,
          icon: 'accountGroup',
          source: PanelSource.native,
          views: const {PanelViews.operation},
        ),
      );
    }
    service.registerNative(
      PanelDefinition(
        id: 'spots',
        title: t.tabs.spots,
        description: t.layout.panels.spotsDescription,
        icon: 'radioTower',
        source: PanelSource.native,
        views: const {PanelViews.operation},
      ),
    );
    service.registerNative(
      PanelDefinition(
        id: 'map',
        title: t.tabs.map,
        description: t.layout.panels.mapDescription,
        icon: 'map',
        source: PanelSource.native,
        views: const {PanelViews.operation},
      ),
    );
    service.registerNative(
      PanelDefinition(
        id: operationSummariesPanelId,
        title: t.tabs.summaries,
        description: t.layout.panels.summariesDescription,
        icon: 'trophy-outline',
        source: PanelSource.native,
        views: const {PanelViews.operation},
        // Several, each with its own picks: a contest's score in one pane
        // and the states grid in another.
        multiple: true,
        formFields: operationSummariesFields,
      ),
    );
    registerSharedDashboardPanels();
  }

  /// This view's panes, handed to the shared dock host. The clock is built
  /// per PLACEMENT rather than once — the instance id is its config key, and a
  /// single widget handed to two groups is one element in two places — which
  /// only this view can do, so it comes through [extraChildren].
  Widget _dockLayout({
    required Widget loggingPanel,
    required Widget infoPanel,
    required Widget spotsPanel,
    required Widget mapPanel,
    required int realQsoCount,
    required List<Qso> qsos,
    required Operation operation,
  }) {
    _realQsoCountForTabs = realQsoCount;
    _logForPanels = qsos;
    _operationForPanels = operation;
    // A local_data write rebuilds this view, which is the only signal a
    // POSITION or OPER change gives — see [_republishPeerHeaderIfChanged].
    _republishPeerHeaderIfChanged(operation);
    return buildDock(
      children: {
        // The mobile numbers row is drawn by the app's status-bar overlay,
        // OUTSIDE this tree, so it has to be told when the logging pane is no
        // longer the one showing — otherwise it hangs over whatever tab
        // replaced it and types into the hidden call field. The dock keeps
        // every pane in a group mounted, so the pane itself cannot tell.
        //
        // At both widths, not just narrow: a wide arrangement is free to put
        // logging in a tab group too, and the row is no less wrong there.
        'logging': Builder(
          builder: (context) => KeyboardAccessoryVisibility(visible: DockPaneVisibility.of(context), child: loggingPanel),
        ),
        'info': infoPanel,
        'spots': spotsPanel,
        'map': mapPanel,
        if (_peerPositionsPanel)
          'positions': PositionsPanel(
            drafts: widget.services.peerDrafts,
            operation: operation,
            miles: widget.services.settings.distanceUnits == DistanceUnits.miles,
            showBearing: widget.services.settings.showBearing,
            showReverseBearing: widget.services.settings.showReverseBearing,
            ourEntityPrefix: _runtime.ourEntityPrefix,
          ),
      },
      // What a pane offers while it is being USED. The dock hides all of it
      // while editing, where a tab is a grab handle — a panel's own settings
      // are reachable from the panel, and its LAYOUT options from its header
      // (see `DockHost.paneEditControls`); the two are different questions and
      // this is the one that belongs to the panel.
      tabActions: {
        'logging': (context) => _buildLoggingSettingsButton(qsos, context: context),
        'map': (context) => _buildMapSettingsButton(context: context),
      },
      extraChildren: (inLayout) => {
        for (final id in inLayout)
          if (PanelDefinition.descriptorIdOf(id) == operationSummariesPanelId)
            id: OperationSummariesPanel(
              key: ValueKey('panel-$id'),
              panelId: id,
              panels: widget.services.panels,
              operation: operation,
              qsos: qsos,
              activityControls: _runtime.loggingControls,
              write: summariesConfigWriter(widget.services, id),
            ),
        ...sharedDashboardPanes(
          inLayout,
          // The saved operation's grid, not the draft's: the pane refetches
          // when this changes, and a half-typed grid square would send a
          // request per keystroke. The DISPLAY grid, so a pane reading it gets
          // the operation's real position where one is stored.
          operationGrid: _operationForPanels?.displayGrid,
          // From `_callInfo`, which this view keeps current unconditionally —
          // NOT from the QSO draft, which is only produced when a panel
          // declares `qso` and costs a rebuild plus a deep compare on every
          // keystroke. A pull-only question asked once a minute must not put
          // the whole view on the typing path to answer it.
          isEnteringQso: () => (_callInfo?.call ?? '').isNotEmpty,
        ),
      },
    );
  }

  /// The operation an extension panel renders against, kept as a field because
  /// [panelRenderContext] is read by the mixin without it. The draft wins while
  /// the operation sheet is open, so a panel follows an edit in progress.
  Operation? _operationForPanels;

  /// Logging and the map are reached through a target rather than through
  /// `formFields`, so their settings embed as the same target-scoped widget a
  /// standalone dialog would show — the host builds the extension-panel case
  /// itself.
  @override
  WidgetBuilder? nativePanelSettingsForm(BuildContext context, String id) => switch (id) {
    'logging' => (builderContext) => settingsFormForTarget(services: widget.services, target: 'logging'),
    'map' => (builderContext) => settingsFormForTarget(services: widget.services, target: 'map'),
    _ when PanelDefinition.descriptorIdOf(id) == operationSummariesPanelId => switch (_operationForPanels) {
      final operation? => (builderContext) => OperationSummariesSettings(
        panelId: id,
        panels: widget.services.panels,
        sections: operationSummarySections(builderContext, operation: operation, qsos: _logForPanels ?? const [], activityControls: _runtime.loggingControls),
        write: summariesConfigWriter(widget.services, id),
      ),
      null => null,
    },
    _ => null,
  };
}

/// Defers [child]'s first build by [kTabScrollDuration] behind a placeholder
/// — for panels (Spots, Map) whose first inflation is expensive enough to
/// stutter if it lands on the same frames as the view's own arrival. Only
/// defers once: the dock keeps a mounted pane mounted, so switching away and
/// back doesn't show the placeholder again.
class _LazyTab extends StatefulWidget {
  final Widget child;

  const _LazyTab({required this.child});

  @override
  State<_LazyTab> createState() => _LazyTabState();
}

class _LazyTabState extends State<_LazyTab> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(kTabScrollDuration, () {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return _ready ? widget.child : const Center(child: CircularProgressIndicator());
  }
}
