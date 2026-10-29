/// The machinery a root view needs to host a user-arrangeable dock: the
/// arrangement and its draft, edit mode's snapshot/save/discard, the Add a
/// Panel sheet, per-pane and per-view layout options, and the header controls
/// that drive all of it.
///
/// Home and Operation are both [ViewLayoutPolicy.customizable] and differ only
/// in which panels they offer and where they persist — everything else here is
/// the same behaviour, and a second copy of it is how the two views' edit modes
/// would come to disagree about what Discard promises.
///
/// See [docs/design/layouts.md]; the dock widget itself is
/// `packages/halo_widgets/lib/src/dock_layout.dart`.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:collection/collection.dart' show DeepCollectionEquality;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:halo_core/halo_core.dart' show GridLocation, HookCategories, asQsonString, locationForQsoInfo, locationFromGuess;
import 'package:halo_widgets/halo_widgets.dart';

import 'package:halo_i18n/halo_i18n.dart';
import '../services/halo_services.dart';
import '../services/cat/cat_service.dart';
import '../services/cat/equipment.dart';
import 'operation/panel_scene/cat_spectrum_source.dart';
import '../services/extensions/catalog_service.dart';
import '../services/error_reporting_service.dart';
import '../services/panel_service.dart';
import '../services/settings_service.dart';
import '../services/status_bar_service.dart';
import '../settings/settings_registry.dart' show SettingsGroup;
import '../settings/settings_target_dialog.dart';
import 'extensions_panel.dart';
import 'operation/clock/clock_panel.dart';
import 'operation/activities_catalog_tier.dart' show CatalogTier, installCatalogExtension;
import 'operation/clock/clock_zones.dart';
import 'operation/extension_panel.dart';
import 'operation/layout_sheet.dart';
import 'operation/missing_panel_pane.dart';
import 'operation/pane_layout_options.dart';
import 'operation/panel_settings.dart';
import 'operation/solar/solar_panel.dart';
import 'operation/weather/weather_panel.dart';
import 'operation/radio/radio_panel.dart';
import 'operation/remote_screen/remote_screen_panel.dart';
import 'operation/rotator/rotator_panel.dart';
import 'operation/remote_screen/remote_screen_picker.dart';
import 'operation/website/website_panel.dart';
import 'dock_layouts/layout_file.dart';
import 'dock_layouts/layout_menu.dart' show LayoutSwitcherButton, showLayoutsSheet;
import 'dock_layouts/view_layouts.dart';

part 'dock_layouts/add_panel_sheet.dart';
part 'dock_layouts/layout_controls.dart';
part 'dock_layouts/named_layouts.dart';
part 'dock_layouts/shared_panels.dart';

/// Which of a view's two arrangements is being drawn.
///
/// The split is the shirt size's own two-pane boundary and nothing else: a
/// window at or above it draws [wide], below it [narrow]. Two arrangements
/// rather than one tree that reflows, because a dock's tree names no widths —
/// the same splits and weights drawn at 360 logical pixels give a two-thirds
/// list and a 120-pixel neighbour. Each class has its own default, its own
/// stored spec, its own dock state and its own pane and view options; see
/// [DockLayoutKeys] and docs/design/layouts.md.
///
/// The two are edited TOGETHER. A resize mid-edit moves the operator from one
/// draft to the other with Save and Discard still on screen, and each of those
/// commits or rolls back both — an edit that half-committed on a resize is one
/// the operator has no way to finish or undo.
enum DockLayoutClass {
  wide,
  narrow;

  DockLayoutClass get other => this == wide ? narrow : wide;
}

/// Where one view's layout lives in settings. Four keys rather than one: the
/// reasons they are kept apart are on [LayoutKeys]'s own members, and a view
/// that bundled them would re-learn each of them the hard way.
class DockLayoutKeys {
  /// The `spec` key of EVERY dock in the app.
  ///
  /// An instance id is a slot in the extensions' config store, which is one
  /// store for the whole app — so "is this id free" is a question about every
  /// arrangement, not about the one being edited. Home's dock and an
  /// operation's are both live at once (Home stays mounted underneath), and
  /// each offers the same extension panels, so a dock that only consulted its
  /// own modules hands out an id the other one is already storing content
  /// under. A new dock belongs in this list on the day it is added; nothing
  /// enforces that, which is why the list is here beside the keys rather than
  /// somewhere a reader of those keys would not look.
  /// Both classes of every dock: a narrow arrangement is a separate tree with
  /// separate placements, so an id it holds is as taken as one the wide
  /// arrangement holds.
  static const everySpec = [
    LayoutKeys.homeDock,
    LayoutKeys.operationDock,
    LayoutKeys.logsDock,
    LayoutKeys.chaseDock,
    LayoutKeys.homeNarrowDock,
    LayoutKeys.operationNarrowDock,
    LayoutKeys.logsNarrowDock,
    LayoutKeys.chaseNarrowDock,
  ];

  /// The arrangement — splits, weights and module ids.
  final String spec;

  /// Which pane is on top. Written as the operator selects, edit mode or not.
  final String state;

  /// Per-pane options, keyed by module id. Part of the arrangement.
  final String paneOptions;

  /// The view's own options — scale and density for everything in it.
  final String viewOptions;

  const DockLayoutKeys({required this.spec, required this.state, required this.paneOptions, required this.viewOptions});

  /// These keys as the named layout [layoutId] stores them — see
  /// [ViewLayouts.layoutKey].
  DockLayoutKeys forLayout(String layoutId) => DockLayoutKeys(
    spec: ViewLayouts.layoutKey(spec, layoutId),
    state: ViewLayouts.layoutKey(state, layoutId),
    paneOptions: ViewLayouts.layoutKey(paneOptions, layoutId),
    viewOptions: ViewLayouts.layoutKey(viewOptions, layoutId),
  );

  List<String> get all => [spec, state, paneOptions, viewOptions];

  /// [everySpec] in every named layout of every view — the layouts not on
  /// screen place instances too, and their config is just as stored.
  static Iterable<String> everySpecIn(SettingsService settings) sync* {
    for (final base in everySpec) {
      final view = base.substring(0, base.indexOf('.'));
      for (final layout in ViewLayouts.read(settings, view).layouts) {
        yield ViewLayouts.layoutKey(base, layout.id);
      }
    }
  }
}

/// Hosts a [DockLayoutView] on behalf of a root view.
///
/// The host supplies what is view-specific — [dockServices], [dockView],
/// [dockKeys], [buildDefaultDockSpec], [nativeModuleIds], [nativeTitles] and
/// [panelSettingsAction] — and builds its panes; everything below is shared.
mixin DockHost<T extends StatefulWidget> on State<T> {
  // ---------------------------------------------------------------- contract

  /// The services this view was handed. Named apart from any `services` getter
  /// the host may already have, so adopting the mixin cannot collide with one.
  HaLoServices get dockServices;

  /// Which view this is, for scoping the panel catalog — a [PanelViews] value.
  String get dockView;

  /// Where this view's layout is persisted, for one of its two classes.
  /// A view that has not diverged its narrow arrangement still answers with a
  /// DIFFERENT set of keys for it — the same keys would make a phone's edits
  /// land in the desktop's tree.
  DockLayoutKeys dockKeysFor(DockLayoutClass layoutClass);

  /// The arrangement this view ships with for [layoutClass], and what Restore
  /// Defaults puts back.
  ///
  /// [migrate] is false for a RESTORE: a view that folds an older stored
  /// dimension into its default (Home's pre-dock column width) must not fold
  /// it in here, or Restore Defaults hands back the operator's own old
  /// measurement forever and nothing in the app reaches the shipped layout.
  DockNode buildDefaultDockSpec(DockLayoutClass layoutClass, {bool migrate = true});

  /// The module ids this view builds itself. A module in the arrangement that
  /// is in neither this set nor the catalog is shown as a placeholder pane
  /// (see [MissingPanelPane]) rather than treated as a broken layout.
  Set<String> get nativeModuleIds;

  /// Tab labels for [nativeModuleIds]. Separate from the catalog's titles
  /// because a tab may carry live state the catalog entry cannot — the
  /// logging tab's QSO count.
  Map<String, String> get nativeTitles;

  /// What an extension panel in this view renders against, and what its
  /// triggers fire on. Required, not defaulted: a host that inherits an empty
  /// context silently gives every extension pane it holds a `changesFrom` that
  /// is always empty, so no declared trigger can ever fire and the panes are
  /// frozen at whatever they rendered on mount — with nothing on screen to say
  /// so. Answering it is a decision each view has to make out loud.
  PanelRenderContext get panelRenderContext;

  /// What a native pane's own settings control opens, or null when it has
  /// none. Extension panels and native panels with declared form fields are
  /// handled here already; this is for a native pane whose settings are
  /// assembled some other way (the logging panel's tune dialog).
  /// The view's OWN panes' settings, embedded in the pane options dialog.
  ///
  /// A builder rather than a callback: the dialog shows these under its Panel
  /// Settings heading instead of opening a second dialog over itself. Null for
  /// a pane this view has nothing native to offer for — an extension panel's
  /// form is built by the host below, from `formFields`, which every view
  /// handles the same way.
  WidgetBuilder? nativePanelSettingsForm(BuildContext context, String id) => null;

  /// Modules this view will not let the operator drag away or remove — see
  /// [DockLayoutView.pinnedModuleIds]. Read per build, so a view may pin
  /// different modules in each [DockLayoutClass]: the Operation view's logging
  /// pane is pinned narrow, where it is the only place a QSO can be entered,
  /// and free wide, where the arrangement always has room for it.
  ///
  /// Empty by default. A pane nothing pins is a pane the operator can throw
  /// away, which is the whole point of an arrangement.
  Set<String> get pinnedModuleIds => pinnedModuleIdsIn(dockLayoutClass);

  /// [pinnedModuleIds] in [layoutClass], drawn or not: an import fills the
  /// class off screen too, and has to keep what that class pins.
  Set<String> pinnedModuleIdsIn(DockLayoutClass layoutClass) => const {};

  /// Modules whose header is off until the operator says otherwise. Empty by
  /// default: a pane that names itself is the safe assumption, and a view
  /// overrides this only where the panes are self-evident from their content.
  ///
  /// A DEFAULT, not a rule — [PaneLayoutOptions.showHeader] still wins for any
  /// pane the operator has an opinion about, in either direction.
  Set<String> get defaultHeaderlessModules => const {};

  /// Whether the dock would actually drop [id] — ASKED of the dock, never a
  /// second copy of its rule here. This decides whether the keyboard route
  /// OFFERS the removal, and a Remove that silently does nothing is worse than
  /// no Remove, so the two must not be able to disagree. False with no dock
  /// mounted, where the removal could not run anyway.
  bool _canRemove(String id) => dockKey.currentState?.canRemoveModule(id) ?? false;

  /// Whether [id] shows its header right now, resolving the operator's own
  /// choice against this view's default.
  bool _showsHeader(String id) => (paneOptions[id] ?? PaneLayoutOptions.none).showsHeader(byDefault: !defaultHeaderlessModules.contains(id));

  // ------------------------------------------------------------------- state

  /// Programmatic access to the mounted dock — `revealModule`, `addModule`,
  /// `removeModule`, `replaceSpec`.
  ///
  /// One key PER CLASS, so crossing the two-pane boundary mounts a different
  /// dock rather than handing a new `initialSpec` to the same one.
  /// [DockLayoutView] copies `initialSpec` into its State on first build and
  /// ignores it afterward, so a shared key would leave the phone looking at
  /// the desktop's tree — and every later edit would be made to that. Only one
  /// is ever mounted, which is what makes two GlobalKeys safe. The panes
  /// themselves carry their own keys and are reparented across the swap, so
  /// nothing being typed is lost.
  GlobalKey<DockLayoutViewState> get dockKey => _active.dockKey;

  /// Which arrangement is on screen. Assigned by the host from `build`, off
  /// the same `isTwoPane` it uses to choose what to draw — a plain field
  /// rather than a `setState`, since the build that sets it is the build that
  /// reads it.
  DockLayoutClass dockLayoutClass = DockLayoutClass.wide;

  /// Everything the host owns PER ARRANGEMENT. Both classes are live at once,
  /// whichever is drawn: an edit spans them (see [startLayoutEditing]), and
  /// the class not on screen still holds a draft that Save must commit.
  ///
  /// Replaced wholesale when the operator switches named layouts: each class
  /// holds keys, a dock key and drafts that all belong to ONE layout, and a
  /// new dock key is what makes the dock re-read its `initialSpec`.
  late Map<DockLayoutClass, _DockClassState> _dockClasses = _classesFor(viewLayouts.active);

  Map<DockLayoutClass, _DockClassState> _classesFor(String layoutId) => {
    for (final layoutClass in DockLayoutClass.values) layoutClass: _DockClassState(dockServices.settings, dockKeysFor(layoutClass).forLayout(layoutId)),
  };

  /// This view's named layouts, and which one is on screen
  /// (docs/design/layouts.md § Named layouts).
  late ViewLayouts viewLayouts = _readViewLayouts();

  /// The layout on screen when another view of this kind deleted it: listed
  /// here until this view moves off it, never written back to the list.
  String? _layoutDeletedElsewhere;

  /// The class being drawn. Every unqualified accessor below reads this one.
  _DockClassState get _active => _dockClasses[dockLayoutClass]!;

  /// The class NOT being drawn — the other half of the same edit.
  _DockClassState get _inactive => _dockClasses[dockLayoutClass.other]!;

  /// Where the class on screen is persisted, in the named layout on screen.
  DockLayoutKeys get dockKeys => _active.keys;

  /// The arrangement, resolved from settings (or the default) ONCE per class:
  /// [DockLayoutView] copies its `initialSpec` into its own State on first
  /// build and ignores it afterward, so re-parsing the persisted JSON every
  /// build would be pure waste on this hot path. Kept in sync with the
  /// widget's mutations via `onSpecChanged`.
  DockNode? get dockSpec => _active.spec;
  set dockSpec(DockNode? spec) => _active.spec = spec;

  /// True from the moment a saved arrangement is found unreadable until the
  /// operator explicitly accepts the default shown in its place (the
  /// StatusBar notice's action, see [_hasNoDuplicates]). While this is on,
  /// nothing writes that class's [DockLayoutKeys.spec] — the unreadable
  /// original is what a future fix would need to recover, and every ordinary
  /// write path (a divider drag, a save) would otherwise replace it with the
  /// default the moment it runs, which is exactly the silent loss this guards
  /// against.
  ///
  /// Per class, and so is its notice: one arrangement being unreadable says
  /// nothing about the other, and a single flag would freeze writes to a
  /// perfectly good layout the operator can see.
  bool get _showingRecoveredDefault => _active.showingRecoveredDefault;

  /// The dock's STATE — which pane is on top — in its own key, apart from the
  /// arrangement.
  ///
  /// Kept CURRENT, not read once: the dock is unmounted and rebuilt whenever
  /// the layout crosses a breakpoint (a window resize, or a font scale change
  /// that moves the effective width), and its `initState` applies this over
  /// the live tree. Stale here means reopening on whatever tab was on top at
  /// launch, undoing the operator's selection every time they resize past the
  /// boundary and back.
  DockState get dockState => _active.state;
  set dockState(DockState state) => _active.state = state;

  /// Per-pane layout options, keyed by module id. Read once and then owned
  /// here, like [dockSpec] and for the same reason — edited as part of the
  /// same draft and written by the same save.
  Map<String, PaneLayoutOptions> get paneOptions => _active.paneOptions;
  set paneOptions(Map<String, PaneLayoutOptions> options) => _active.paneOptions = options;

  /// The VIEW's own layout options, read once and owned here for the same
  /// reason [paneOptions] is.
  PaneLayoutOptions get viewOptions => _active.viewOptions;
  set viewOptions(PaneLayoutOptions options) => _active.viewOptions = options;

  /// Whether the arrangement is being edited (see [DockLayoutView.editing]).
  /// While this is on, the dock's changes are a DRAFT: nothing reaches
  /// settings until Save Layout.
  bool layoutEditing = false;

  /// True while the Add a Panel sheet's route is on screen. It is a top modal
  /// pane, which leaves this view's header uncovered but NOT tappable — so
  /// while it is up the header's layout controls are drawn by the route
  /// instead (see [LayoutControls.layoutHeaderControls]).
  bool layoutSheetOpen = false;

  /// The snapshots Discard restores live on each [_DockClassState] — one set
  /// per class, taken and released together, because a resize mid-edit moves
  /// the operator between the two and both exits act on both.

  /// Panes dropped while editing, whose contents are forgotten only if the
  /// edit is SAVED — see [_DockClassState.pendingForgets]. Per class, like the
  /// options they would take with them: a native module id (the logging pane,
  /// the map) is in BOTH arrangements, so a flat list would have a removal in
  /// one class forget the other class's copy on save.
  List<String> get _pendingForgets => _active.pendingForgets;

  /// Every id waiting to be forgotten, in either class — what a new placement
  /// must not be handed. See [_instanceIdsInEveryDock] for the same argument.
  Iterable<String> get _allPendingForgets => _dockClasses.values.expand((klass) => klass.pendingForgets);

  /// What each panel most recently called itself, which is what tells two
  /// placements of one panel apart.
  final panelTitles = <String, String>{};

  /// What held focus when editing began, to be handed back when it ends.
  FocusNode? _focusBeforeLayoutEditing;

  /// What held focus when the Edit Layout button was PRESSED, which is before
  /// the press itself unfocused it. Claimed by [startLayoutEditing] if the
  /// press becomes a tap, and dropped a frame later if it does not.
  FocusNode? _focusAtPress;

  /// Bumped on every change an open layout sheet is listing — dock mutations
  /// and catalog refreshes both. The sheet sits in its own route, above the
  /// view that owns the tree, so a `setState` here does not reach it.
  ///
  /// Created when the sheet opens and disposed when it closes, rather than
  /// living as long as the view: a notifier the view disposes while the
  /// sheet's route is still mounted throws when that route finally removes its
  /// listener.
  ValueNotifier<int>? _sheetRevision;

  /// The header's plus button, measured as a distance from the window's RIGHT
  /// edge — the edge the sheet aligns to.
  final _addPanelButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _mountedHosts.add(this);
    dockServices.panels.addListener(_onPanelCatalogChanged);
    dockServices.cat.addListener(_onEquipmentChanged);
    // Extensions are asked for their panels once per view, not once per build:
    // the runtime restarts when an extension is enabled or disabled, and a
    // view is rebuilt from scratch either way.
    unawaited(dockServices.panels.refreshExtensionPanels());
  }

  @override
  void dispose() {
    _mountedHosts.remove(this);
    dockServices.panels.removeListener(_onPanelCatalogChanged);
    dockServices.cat.removeListener(_onEquipmentChanged);
    for (final klass in _dockClasses.values) {
      if (klass.recoveredDefaultNoticeListener case final listener?) {
        dockServices.statusBar.removeListener(listener);
      }
    }
    super.dispose();
  }

  /// What the Radio panel's descriptor is built from, as a single string.
  ///
  /// CatService notifies on every READING — `_applyReading` sets state, and
  /// that is knob-spin rate on a live rig, not the "few times a minute" a
  /// connection status change would be. Re-registering on each one would
  /// re-resolve translations and rebuild every shared descriptor's form just
  /// to deep-compare it back to equal, on the UI thread, per mounted view.
  /// So the listener compares what the form actually shows — which radios
  /// exist, what they are called, and which one drives VFO A — and does
  /// nothing when a frequency moves.
  String _equipmentDescriptorKey() {
    final cat = dockServices.cat;
    return [
      switch (cat.radio1) {
        LocalRadio(:final uuid) => uuid,
        _ => '',
      },
      for (final node in cat.nodes) '${node.uuid}:${cat.displayNameFor(node)}',
    ].join('|');
  }

  String? _lastEquipmentKey;

  /// The station's equipment changed in a way the panel catalog can see — a
  /// radio added, removed or renamed, or a different one designated for
  /// VFO A.
  ///
  /// The Radio panel's descriptor names the designated radio and lists the
  /// configured ones, so its form is only as fresh as its last registration
  /// (docs/design/layouts.md). Registering is what publishes it.
  void _onEquipmentChanged() {
    if (!mounted) return;
    final key = _equipmentDescriptorKey();
    if (key == _lastEquipmentKey) return;
    _lastEquipmentKey = key;
    registerSharedDashboardPanels();
  }

  /// The catalog changed — an extension enabled, disabled, or its runtime
  /// restarted. Nothing is reconciled against it: a module the catalog cannot
  /// explain keeps its pane and renders as a placeholder, so a panel that is
  /// only *temporarily* missing repairs itself here, and one that is really
  /// gone waits for the operator to remove it. Rebuilding is the whole
  /// response.
  ///
  /// In the mixin because the repair is not view-specific, and a view without
  /// it strands every extension pane that was placed before the runtime
  /// answered — which on Home, mounted before extensions load, is every one.
  void _onPanelCatalogChanged() {
    if (!mounted) return;
    // Straight through unless we are INSIDE a build, which is the one case
    // that cannot take a `setState`. A host registers its own native panels
    // from `didChangeDependencies`, and the first such registration notifies
    // while the view is still mounting — set-state-during-build, which
    // ErrorPolicy keeps off the screen (docs/design/error-reporting.md), so it
    // would cost a console line and nothing else while the rebuild it asked
    // for never happened.
    //
    // Narrowed to that case on purpose rather than always deferring: an
    // extension answering mid-session is the common path, and pushing its
    // repair a frame later would make every caller wait on a frame boundary
    // for a rebuild that was safe to do now.
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onPanelCatalogChanged();
      });
      return;
    }
    setState(() {});
    // An open Add a Panel sheet is listing this.
    bumpSheet();
  }

  // ------------------------------------------------------- the arrangement

  /// Reads the saved arrangement once, or falls back to the default when there
  /// is nothing saved or it does not parse.
  ///
  /// Deliberately does NOT check the modules against the catalog. A module
  /// this view cannot build is shown as a placeholder pane, not treated as a
  /// broken arrangement — an extension disabled, uninstalled, or merely slow
  /// to answer must never cost the operator their layout, and setting a saved
  /// arrangement aside is as destructive as deleting from it, because the next
  /// thing written replaces it.
  void ensureDockSpec([DockLayoutClass? layoutClass]) {
    final klass = _dockClasses[layoutClass ?? dockLayoutClass]!;
    if (klass.spec != null) return;
    var persisted = DockNode.fromJson(dockServices.settings.layoutData(klass.keys.spec));
    for (final id in retiredModules) {
      persisted = persisted?.without(id);
    }
    final resolved = layoutClass ?? dockLayoutClass;
    klass.spec = persisted != null && _hasNoDuplicates(klass, resolved, persisted) ? persisted : buildDefaultDockSpec(resolved);
  }

  /// Modules a saved arrangement may name that this view does not offer as
  /// panes. One in a stored spec describes something that cannot be built, so
  /// it is dropped and its siblings take the space — which is only safe for a
  /// module whose content the view still shows somewhere else, outside the
  /// arrangement.
  Set<String> get retiredModules => const {};

  /// The one thing a saved arrangement still cannot be. A module listed twice
  /// hands the same widget instance to two groups — so the view throws on
  /// every build, and because nothing rewrites the spec it throws again after
  /// a relaunch, with the layout controls unreachable to undo it. Unreachable
  /// through the UI (both `addModule` and the drop handler dedupe), which is
  /// exactly why it would only ever arrive in a file nobody could then repair.
  /// Every module id any dock has saved, this one included.
  ///
  /// Read from the STORED specs rather than from live docks: an operation's
  /// arrangement is off screen most of the time, and the config its panes hold
  /// is still there. A spec that will not parse contributes nothing, which is
  /// the safe direction — the worst case is an id handed out twice, and an
  /// unparseable spec is one whose panes are about to be replaced anyway.
  Iterable<String> _instanceIdsInEveryDock() sync* {
    for (final key in DockLayoutKeys.everySpecIn(dockServices.settings)) {
      final spec = DockNode.fromJson(dockServices.settings.layoutData(key));
      if (spec != null) yield* spec.collectModules();
    }
    // The class NOT on screen holds a draft storage has not seen — mid-edit
    // nothing has been written, so a pane added to the narrow layout and then
    // one added to the wide would otherwise both be handed `#1`, and the save
    // would store two arrangements pointing at one config.
    yield* _inactive.spec?.collectModules() ?? const <String>[];
  }

  /// Writes [_recoveredDefaultSpec] and lets ordinary writes resume — the
  /// operator has said the substituted default replaces the unreadable
  /// original. Idempotent: the notice's action and
  /// [_recoveredDefaultNoticeListener] can both reach here (the action's own
  /// `dismissNotice` call re-triggers the listener), so the guard is checked
  /// first rather than assumed.
  void _acceptRecoveredDefault(_DockClassState klass) {
    if (!klass.showingRecoveredDefault) return;
    klass.showingRecoveredDefault = false;
    if (klass.recoveredDefaultSpec case final spec?) {
      dockServices.settings.setLayoutData(klass.keys.spec, spec.toJson());
    }
    if (klass.recoveredDefaultNoticeListener case final listener?) {
      dockServices.statusBar.removeListener(listener);
      klass.recoveredDefaultNoticeListener = null;
    }
  }

  bool _hasNoDuplicates(_DockClassState klass, DockLayoutClass layoutClass, DockNode spec) {
    // Containers alongside the modules: two slots claiming one container id
    // would hand the same subtree to two tabs, which is the same unbuildable
    // arrangement a module listed twice is.
    final modules = [...spec.collectModules(), ...spec.collectContainerIds()];
    if (modules.length == modules.toSet().length) return true;
    debugPrint('[layout] saved $dockView ${layoutClass.name} arrangement lists a module twice; falling back to the default');
    klass.showingRecoveredDefault = true;
    klass.recoveredDefaultSpec = buildDefaultDockSpec(layoutClass);
    // The class is in the key: one arrangement being unreadable says nothing
    // about the other, and a shared key would let the second notice replace
    // the first — leaving one class frozen against writes with nothing on
    // screen offering to release it.
    final noticeKey = 'layout:$dockView:${layoutClass.name}:unreadable';
    // Deferred to a microtask: `_hasNoDuplicates` runs from `ensureDockSpec`,
    // which runs from `build`, and `showNotice`'s `notifyListeners()` would
    // otherwise mark a StatusBar listener dirty mid-build — the identical
    // hazard `ErrorReportingService.notify` defers around, for the same
    // reason (see its own comment).
    scheduleMicrotask(() {
      if (!mounted) return;
      // The notice card's own dismiss button calls `dismissNotice` directly
      // (see `main.dart`'s `NoticeStack`) — nothing routes through this
      // file's action. Without this, dismissing any way but the action below
      // leaves `_showingRecoveredDefault` on forever (the notice cannot
      // reappear — `ensureDockSpec` resolves once), silently no-opping every
      // later save for the rest of the session.
      void onNoticeChanged() {
        final stillActive = dockServices.statusBar.activeNotices.any((n) => n.key == noticeKey);
        if (!stillActive) _acceptRecoveredDefault(klass);
      }

      klass.recoveredDefaultNoticeListener = onNoticeChanged;
      dockServices.statusBar.addListener(onNoticeChanged);
      dockServices.statusBar.showNotice(
        key: noticeKey,
        icon: 'alert-circle',
        title: _t.layoutUnreadableTitle,
        text: _t.layoutUnreadableBody,
        // Not persisted: `StatusBarNotice._toJson` drops `actions` (a
        // `VoidCallback` can't survive a restart), so a persisted-but-not-yet-
        // accepted copy would reload with its title and body but no "Use this
        // layout" button — the same reason `ErrorReportingService.notify`
        // sets this false for its own action notice.
        persist: false,
        actions: [
          StatusBarAction(
            label: _t.layoutUnreadableAction,
            onTap: () {
              _acceptRecoveredDefault(klass);
              dockServices.statusBar.dismissNotice(noticeKey);
            },
          ),
        ],
      );
    });
    return false;
  }

  /// How many panes the whole arrangement holds — panes, not groups: one group
  /// can hold several. One is the floor the dock enforces, so a removal
  /// control has nothing to offer there.
  int paneCount() => dockSpec?.collectModules().length ?? 0;

  /// How many modules share [id]'s group, or 1 when nothing in the arrangement
  /// holds it.
  int groupSizeOf(String id) {
    int? sizeIn(DockNode node) => switch (node) {
      // Nested containers too: a pane inside one is in whatever tab set the
      // container holds, and answering 1 for it offers to hide a header that
      // is a tab strip — which is not this pane's to hide.
      DockGroup(:final modules, :final nested) => modules.contains(id) ? modules.length : nested.values.map(sizeIn).nonNulls.firstOrNull,
      DockSplit(:final children) => children.map(sizeIn).nonNulls.firstOrNull,
    };
    return dockSpec == null ? 1 : sizeIn(dockSpec!) ?? 1;
  }

  /// What [id] is called when nobody has renamed it — the placeholder a pane's
  /// options dialog shows, and the fallback [dockTitles] lands on. In one
  /// place because the dialog offers to REPLACE this string, and a dialog
  /// showing a different default from the tab it renames is offering to
  /// replace something that is not there.
  String defaultTitleFor(String id) {
    // A container names no panel — nothing in the catalog answers for it, and
    // its raw id ("nested#1") is an implementation detail. It is a place to
    // put panes, so it is called what a place to put panes is called.
    if (isDockContainerId(id)) return _t.nestedPaneTitle;
    return panelTitles[id] ?? dockServices.panels[id]?.title ?? nativeTitles[id] ?? panelKeyOfPanelId(id);
  }

  /// Every tab's label, in precedence order — see the comments inline, which
  /// are the whole point of the ordering.
  Map<String, String> dockTitles() => {
    ...nativeTitles,
    // Containers, before everything a panel or the operator has to say: they
    // are neither, and this is only the default their own rename replaces.
    for (final id in dockSpec?.collectContainerIds() ?? const <String>[]) id: _t.nestedPaneTitle,
    for (final panel in dockServices.panels.catalog)
      if (panel.source == PanelSource.extension) panel.id: panel.title,
    // Every extension module actually in the arrangement, which the catalog
    // loop above misses for a PLACEMENT: `ext:hook:key#1` is not a catalog id,
    // so without this a Custom Text pane whose name is still empty — the
    // default the moment one is added — has a tab reading its raw id. A module
    // the catalog cannot explain at all falls back to its own key, which reads
    // better than the full id; the pane behind it says what is actually wrong.
    for (final id in dockSpec?.collectModules() ?? const <String>[])
      if (!nativeModuleIds.contains(id)) id: dockServices.panels[id]?.title ?? panelKeyOfPanelId(id),
    // A panel may name its own tab. LAST but one in the map, so it wins over
    // every fallback above — a descriptor's title is the panel's guess, this
    // is what it actually rendered.
    ...panelTitles,
    // LAST: the operator's own name for the pane beats everything, including
    // what the panel calls itself. Nobody else gets to overrule what they
    // typed into that box.
    for (final entry in paneOptions.entries)
      if (entry.value.title != null) entry.key: entry.value.title!,
  };

  /// A panel reporting what it rendered itself as.
  void onPanelTitle(String id, String? title) {
    // A panel is free to return the same title on every render, so dropping
    // the repeat is this side's job — otherwise every render of every titled
    // panel would rebuild the whole view.
    if (title == null ? !panelTitles.containsKey(id) : panelTitles[id] == title) return;
    setState(() {
      if (title == null) {
        panelTitles.remove(id);
      } else {
        panelTitles[id] = title;
      }
    });
  }

  /// What dropping a pane means, in one place so the remove control and
  /// Restore Defaults cannot disagree: the label goes, and so does whatever
  /// the operator typed into it.
  ///
  /// Only an INSTANCE forgets its config — see
  /// [PanelService.forgetInstanceConfig], which draws that line. Fire and
  /// forget: nothing here should wait on storage, and a config outliving its
  /// pane costs a stale value rather than a broken layout.
  void forgetPanes(Iterable<String> ids) {
    // Held back while editing — a removal that Discard can undo must not have
    // destroyed anything in the meantime. See [_pendingForgets].
    if (layoutEditing) {
      _pendingForgets.addAll(ids);
      return;
    }
    _forgetPanesNow(_active, ids);
  }

  void _forgetPanesNow(_DockClassState klass, Iterable<String> ids) {
    final other = _dockClasses.values.firstWhere((each) => each != klass);
    // The persisted spec when the class is not resolved — NOT `ensureDockSpec`,
    // which is a resolution with side effects: it can find that class's saved
    // arrangement unreadable and set `showingRecoveredDefault`, and this runs
    // from inside `saveLayout`'s own loop, so the class the loop has not
    // reached yet would flip mid-save and have its writes skipped. The
    // operator's edits to a layout they cannot even see would go, silently.
    //
    // Reading it raw matters because the fallback falls the DESTRUCTIVE way:
    // an unknown class reads as holding nothing, so the config goes even
    // though that class's arrangement still places the id — and that is the
    // arrangement it draws when next shown.
    final otherSpec = other.spec ?? DockNode.fromJson(dockServices.settings.layoutData(other.keys.spec));
    final stillPlaced = otherSpec?.collectModules().toSet() ?? const <String>{};
    for (final id in ids.toList()) {
      // Its layout options go with it — they describe a place in the
      // arrangement, and that place is gone.
      klass.paneOptions.remove(id);
      // The CONFIG, though, is one store for the whole app, and a descriptor
      // that may only be placed once (Solar, the Map) sits in both classes
      // under the same id. Dropping it from the phone's layout must not empty
      // the one the desktop is still showing.
      if (stillPlaced.contains(id)) continue;
      panelTitles.remove(id);
      unawaited(_forgetInstance(id));
    }
  }

  // -------------------------------------------------------------- edit mode

  void bumpSheet() => _sheetRevision?.value++;

  void _dropPressFocusCapture() => WidgetsBinding.instance.addPostFrameCallback((_) => _focusAtPress = null);

  /// Restores focus a frame later: the panes are still excluded from traversal
  /// during the build that ends edit mode, and a request made then is refused.
  void restoreFocusAfterEditing() {
    final node = _focusBeforeLayoutEditing;
    _focusBeforeLayoutEditing = null;
    if (node == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Gone with a pane the edit removed, or with the view itself. Asked of
      // the ELEMENT: `FocusNode.detach` leaves `context` pointing at the dead
      // one, so a null check here never fires — and `requestFocus` on a
      // detached node silently latches, stealing focus if that pane is ever
      // remounted.
      if (!mounted || node.context?.mounted != true) return;
      // A scope is what an unfocus leaves behind, and focusing one puts the
      // caret nowhere — worse than leaving it where it is, since it also takes
      // focus off whatever did have it.
      if (node is FocusScopeNode) return;
      node.requestFocus();
    });
  }

  /// Turns the dock into an editor.
  ///
  /// Nothing else about the view changes: the draft IS the live arrangement,
  /// so what the operator drags is what they are looking at. Only the write to
  /// settings is held back (see the dock's `onSpecChanged`).
  void startLayoutEditing() {
    // A second press must not re-take the snapshot: Discard would then roll
    // back to the last press rather than to where editing began.
    if (layoutEditing) return;
    // Editing excludes the panes from focus traversal, which unfocuses
    // whatever was in them — the call field, ordinarily. Nothing puts it back
    // on the way out: the pane is never remounted, so its autofocus does not
    // fire again, and the operator returns to a view that looks ready to log
    // and swallows every keystroke.
    _focusBeforeLayoutEditing = _focusAtPress ?? FocusManager.instance.primaryFocus;
    _focusAtPress = null;
    // BOTH classes, not just the one on screen. A resize mid-edit hands the
    // operator the other draft with Save and Discard still up, and a class
    // that was never snapshotted has nothing for Discard to restore — so the
    // resize alone would make the edit uncancellable for half the app.
    // Resolving the off-screen class here is what makes its snapshot real:
    // `ensureDockSpec` runs from `build`, which only ever draws one of them.
    for (final layoutClass in DockLayoutClass.values) {
      ensureDockSpec(layoutClass);
    }
    if (dockSpec == null) {
      // `ensureDockSpec` always resolves this before the dock (and this
      // button) can be built — reachable only if that contract breaks.
      assert(false, 'layout:edit-no-arrangement: Edit Layout pressed with no arrangement resolved');
      debugPrint('[layout] edit-no-arrangement: Edit Layout pressed with no arrangement resolved');
      return;
    }
    setState(() {
      for (final klass in _dockClasses.values) {
        klass.specSnapshot = klass.spec?.toJson();
        klass.paneOptionsSnapshot = PaneLayoutOptions.mapToJson(klass.paneOptions);
        klass.viewOptionsSnapshot = klass.viewOptions.toJson();
      }
      layoutEditing = true;
    });
    // Entering from the sheet's own header copy: those are the buttons that
    // change, and the route rebuilds them on the revision, not on setState.
    bumpSheet();
  }

  /// Cancels the edit: the arrangement goes back to where editing found it and
  /// edit mode ends. The counterpart of [saveLayout], and the reason leaving is
  /// safe — every way out of edit mode either keeps everything or keeps
  /// nothing.
  ///
  /// Selection is deliberately NOT reverted: which pane is on top is state,
  /// not arrangement (see [DockState]), and it is saved as the operator makes
  /// it whether or not they are editing.
  void revertLayout() {
    // A second call must not re-read a snapshot the first already cleared —
    // unlike a stray extra press elsewhere in this file, this one is reachable
    // in practice: nothing disables Discard until the rebuild its own
    // `setState` schedules actually lands, so two taps landing in the same
    // frame both call in before `layoutEditing` visibly goes false on screen
    // (the FIELD is already false the moment this returns, which is what this
    // guard reads).
    if (!layoutEditing) return;
    _pendingSettingWrites.clear();
    final activeSnapshot = _active.specSnapshot;
    final activeSpec = activeSnapshot == null ? null : DockNode.fromJson(activeSnapshot);
    if (activeSpec == null) {
      // Leave anyway. Edit mode left on has no way out from here.
      // `startLayoutEditing` always sets every class's snapshot from a live,
      // already-valid `DockNode` before `layoutEditing` can turn on, so
      // neither a null snapshot nor one that fails to parse back should be
      // reachable here.
      assert(false, 'layout:revert-no-snapshot: discard pressed with nothing to revert to');
      debugPrint('[layout] revert-no-snapshot: discard pressed with nothing to revert to');
      setState(() {
        for (final klass in _dockClasses.values) {
          klass.pendingForgets.clear();
          klass.clearSnapshots();
        }
        layoutEditing = false;
      });
      restoreFocusAfterEditing();
      bumpSheet();
      return;
    }
    // NOT required: the class on screen may be between docks. Each class's
    // `spec` below is what a remounting dock reads.
    final dock = dockKey.currentState;
    // Panes this discard is DROPPING, per class: everything the edit brought
    // into being that the restored arrangement does not hold — those still on
    // screen (added) AND those already taken out again (added, then removed,
    // so in `pendingForgets` and in neither tree). Miss the second set and a
    // discarded pane's notes wait for the next placement to reuse its id,
    // which is the leak the deferred forget exists to prevent.
    final dropped = <_DockClassState, Set<String>>{};
    final restoredSpecs = <_DockClassState, DockNode>{};
    for (final klass in _dockClasses.values) {
      final spec = klass == _active ? activeSpec : (klass.specSnapshot == null ? null : DockNode.fromJson(klass.specSnapshot!));
      if (spec == null) {
        // The same impossibility the active class asserts on, and worse here:
        // the loop below clears every class's snapshot, so a silent skip
        // leaves this one holding uncommitted edits with nothing left to
        // revert to — the operator's Discard having applied to half the app.
        assert(false, 'layout:revert-no-snapshot: a class has nothing to revert to');
        debugPrint('[layout] revert-no-snapshot: a class has nothing to revert to');
        continue;
      }
      restoredSpecs[klass] = spec;
      final restored = spec.collectModules().toSet();
      dropped[klass] = {...klass.pendingForgets, ...?klass.spec?.collectModules()}.difference(restored);
    }
    for (final entry in restoredSpecs.entries) {
      entry.key.state.applyTo(entry.value);
    }
    // emit: false — a discard is the operator UNDOING their own edits, and
    // reporting it back would be recorded as one more of them.
    dock?.replaceSpec(activeSpec, emit: false);
    setState(() {
      for (final entry in restoredSpecs.entries) {
        entry.key.spec = entry.value;
      }
      for (final klass in _dockClasses.values) {
        // The panes the edit's removals took out are back on screen; forgetting
        // their contents now would empty a pane the operator can see.
        klass.pendingForgets.clear();
        klass.paneOptions = PaneLayoutOptions.mapFromJson(klass.paneOptionsSnapshot);
        klass.viewOptions = PaneLayoutOptions.fromJson(klass.viewOptionsSnapshot);
        klass.clearSnapshots();
      }
      layoutEditing = false;
    });
    for (final entry in dropped.entries) {
      _forgetPanesNow(entry.key, entry.value);
    }
    restoreFocusAfterEditing();
    bumpSheet();
  }

  /// Commits the draft and leaves edit mode.
  void saveLayout() {
    // Both classes, for the same reason both are snapshotted: a resize
    // mid-edit is not a decision about the layout, so Save commits what the
    // operator did on either side of it.
    for (final klass in _dockClasses.values) {
      // Panes this save is DROPPING: removed during the edit and NOT back in
      // the arrangement being saved. The same set difference the discard
      // takes, running the other way — a pane dropped and then re-added (or a
      // new instance handed the freed id, which
      // [PanelService.nextInstanceId] does on purpose) is a pane the operator
      // can see, and forgetting it would empty one they just filled in.
      final kept = klass.spec?.collectModules().toSet() ?? const <String>{};
      final forgotten = klass.pendingForgets.toSet().difference(kept);
      // Same guard as `onSpecChanged`'s divider-drag write — see
      // [_showingRecoveredDefault]. An edit session reachable while a saved
      // arrangement is unread is editing the DEFAULT, and NONE of it — the
      // spec, the pane options, the view options, or a forgotten pane's config
      // — may reach settings before the operator has chosen to keep it. A
      // pane id the default happens to share with the real arrangement would
      // otherwise have its options clobbered ahead of that choice.
      if (!klass.showingRecoveredDefault) {
        // Before the writes, never after: forgetting drops these panes'
        // entries from that class's [paneOptions], and a map serialized first
        // would carry a removed pane's title and overrides to disk for
        // whatever takes its id next.
        _forgetPanesNow(klass, forgotten);
        final settings = dockServices.settings;
        if (klass.spec case final spec?) settings.setLayoutData(klass.keys.spec, spec.toJson());
        settings.setLayoutData(klass.keys.paneOptions, PaneLayoutOptions.mapToJson(klass.paneOptions));
        settings.setLayoutData(klass.keys.viewOptions, klass.viewOptions.toJson());
      }
    }
    for (final entry in _pendingSettingWrites.entries) {
      unawaited(_queuePanelSettings(entry.key, entry.value));
    }
    _pendingSettingWrites.clear();
    setState(() {
      layoutEditing = false;
      for (final klass in _dockClasses.values) {
        klass.clearSnapshots();
        klass.pendingForgets.clear();
      }
    });
    restoreFocusAfterEditing();
    // Saving from the sheet's own header copy has to redraw it: these very
    // buttons are what changes.
    bumpSheet();
  }

  /// Runs one of the two exits, and — pressed from the sheet's own header copy
  /// — takes the sheet down with it.
  ///
  /// The sheet is a control panel for an edit in progress: it lists what can be
  /// added. Left open past the exit, that add writes straight to settings the
  /// moment it is pressed — with the Discard that was beside it a second ago
  /// gone — and the sheet's own header still offers a Save for an edit that is
  /// already over.
  void _endEditingFrom(BuildContext context, {required bool inSheet, required VoidCallback exit}) {
    exit();
    // Pop AFTER: the exits call `_bumpSheet`, and a route already gone simply
    // has nothing listening.
    if (inSheet && Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  /// Everything about this view's layout, back to how it ships: the default
  /// arrangement, the view's own options, and every pane's.
  ///
  /// The class ON SCREEN only. The two arrangements are separate layouts with
  /// separate options, and an operator asking a phone for defaults has said
  /// nothing about the desktop — a restore that took both would throw away a
  /// layout they cannot even see from here. Like every other edit it is part
  /// of the draft, so Discard undoes it.
  ///
  /// One control rather than two. A reset that put the options back but left
  /// the arrangement alone is not a restore — the operator asking for defaults
  /// is asking for the view they started with, and having to find a second
  /// control in another menu to finish the job is how they end up half-way
  /// between two layouts.
  ///
  /// Part of the DRAFT like everything else in edit mode, so Discard undoes it
  /// and the panes come back with what was in them.
  void restoreLayoutDefaults() {
    // Re-read, never a captured reference: a resize past a breakpoint takes
    // the dock down while a dialog over it stays up, and a call on the
    // disposed State is a setState-after-dispose.
    final dock = dockKey.currentState;
    // Dropping a pane means the same thing here as it does anywhere else — a
    // placement's contents go with it. Without this, restoring and then adding
    // a Custom Text pane hands back `#1` still holding the notes that were on
    // screen a moment ago.
    forgetPanes(dock?.modules ?? dockSpec?.collectModules() ?? const []);
    final defaults = buildDefaultDockSpec(dockLayoutClass, migrate: false);
    // emit: false, like the discard. An emit reports the new arrangement's
    // SELECTION through `onStateChanged`, which is not gated on edit mode — it
    // would write which pane is on top to settings there and then, and a
    // discard could not take it back.
    dock?.replaceSpec(defaults, emit: false);
    setState(() {
      dockSpec = defaults;
      viewOptions = PaneLayoutOptions.none;
      paneOptions.clear();
    });
  }

  // --------------------------------------------------------- named layouts
  // The rest of this section is the [NamedLayouts] extension, in
  // dock_layouts/named_layouts.dart.

  /// Shared panels' settings an import is to overwrite, held until Save — a
  /// panel placed once keeps ONE set of settings for every layout showing
  /// it, so writing them mid-edit is a change Discard could not undo.
  final _pendingSettingWrites = <String, Map<String, dynamic>>{};

  /// Where the next shared panel's settings write waits its turn — see
  /// [NamedLayouts._queuePanelSettings].
  Future<void> _panelSettingsQueue = Future.value();

  /// Every docked view mounted, so a layout one deletes can move another
  /// view of the same kind off it before its instances are forgotten.
  static final _mountedHosts = <DockHost>{};

  /// [setState] for the extension, which may not call it itself.
  void _rebuild(VoidCallback fn) => setState(fn);

  // ------------------------------------------------------------- the overrides

  /// A pane's own font-scale and density overrides, applied around the pane's
  /// widget and nowhere else.
  ///
  /// Font scale is a [SubtreeUiScale] rather than a hand-multiplied dimension,
  /// which is the only way to do this that [docs/design/ui-scaling.md]'s rules
  /// allow: everything inside stays in plain logical pixels, and the pane
  /// simply lives in a coordinate space scaled once more. NOT a bare
  /// [UiScale], which is a root primitive and stretches a pane's two axes by
  /// different factors — see its doc.
  Widget withPaneOverrides(String id, Widget pane) => _withOverrides(paneOptions[id], pane);

  /// The same wrapping for the VIEW as a whole. Applied around the dock, so a
  /// pane that overrides nothing inherits it and one that does wins — each
  /// level names an ABSOLUTE size, and the innermost that names one decides.
  Widget withViewOverrides(Widget dock) => _withOverrides(viewOptions, dock);

  /// Each wrapper closes over `inner`, a FINAL copy, never over the `wrapped`
  /// variable it is about to be assigned to. A builder that reads `wrapped`
  /// resolves it at BUILD time — by which point it is the builder itself, so
  /// the builder becomes its own child and the tree mounts forever. It does
  /// not throw where the mistake is; it blows the stack a thousand mounts
  /// later, while Flutter is formatting the error.
  Widget _withOverrides(PaneLayoutOptions? options, Widget pane) {
    if (options == null) return pane;
    var wrapped = pane;
    if (options.densityValue case final preference?) {
      final inner = wrapped;
      wrapped = LayoutBuilder(
        // Resolved against the PANE's own height, not the window's — the
        // ceiling `resolve` puts on a roomier pick is about whether the rows
        // fit, and what they have to fit in here is this pane.
        builder: (context, constraints) => LayoutDensityScope(density: preference.resolve(constraints.maxHeight), child: inner),
      );
    }
    if (options.fontScaleValue case final scale?) {
      final inner = wrapped;
      wrapped = SubtreeUiScale(scale: scale.scaleFactor, child: inner);
    }
    if (options.themeBrightness case final brightness?) {
      final inner = wrapped;
      wrapped = Theme(data: buildHaLoTheme(brightness), child: inner);
    }
    return wrapped;
  }

  // ------------------------------------------------------------- the controls

  /// The strings below live under `operation.layout` for historical reasons
  /// and are view-neutral in content ("Add a Panel", "Save Layout") — the key
  /// path is not user-visible, and moving the subtree would rewrite both
  /// locales and every reference for no change on screen.
  Translations$operation$layout$en get _t => context.t.operation.layout;

  // The rest of this section is the [LayoutControls] extension, in
  // dock_layouts/layout_controls.dart.

  /// The guard below is not reachable through the UI (the sheet's header
  /// carries no plus), which is exactly why it is worth a test: it is what
  /// stops a second caller stacking a route over the first.
  @visibleForTesting
  Future<void> openAddPanelSheetForTest() => openAddPanelSheet();

  // ----------------------------------------------- the shared dashboard panels
  // The [SharedDashboardPanels] extension, in dock_layouts/shared_panels.dart.

  // ----------------------------------------------------------------- the dock

  /// Builds the dock itself. [children] is what this view puts in each of
  /// [nativeModuleIds]; every other module in the arrangement — extension
  /// panels, and the placeholders for those nothing explains — is built here.
  ///
  /// [extraChildren] is for a native panel the host builds per PLACEMENT
  /// rather than once (the clock, one widget per instance id), which this
  /// cannot do for it: only the host knows the widget.
  Widget buildDock({
    required Map<String, Widget> children,
    Map<String, Widget> Function(List<String> inLayout)? extraChildren,
    Map<String, Widget Function(BuildContext)> tabActions = const {},
  }) {
    ensureDockSpec();
    final inLayout = dockSpec!.collectModules();
    final extras = extraChildren?.call(inLayout) ?? const <String, Widget>{};
    return DockLayoutView(
      key: dockKey,
      initialSpec: dockSpec!,
      titles: dockTitles(),
      children: {
        for (final entry in {
          ...children,
          ...extras,
          // Extension panels are built only for what the arrangement actually
          // holds: an ExtensionPanel renders on mount, so building one for a
          // panel nobody added would cross the bridge for a pane that is never
          // shown.
          for (final id in inLayout)
            if (!children.containsKey(id) && !extras.containsKey(id))
              if (dockServices.panels[id]?.source == PanelSource.extension)
                id: ExtensionPanel(
                  key: ValueKey('panel-$id'),
                  panel: dockServices.panels[id]!,
                  panels: dockServices.panels,
                  onTitle: (title) => onPanelTitle(id, title),
                  renderContext: panelRenderContext,
                  spectrum: dockServices.extensions.radioCalls.canRead(dockServices.panels[id]!.hookKey)
                      ? CatSpectrumSource(
                          dockServices.cat,
                          settings: dockServices.settings,
                          canCommand: dockServices.extensions.radioCalls.canWrite(dockServices.panels[id]!.hookKey),
                        )
                      : null,
                )
              // A module nothing in the catalog explains — an extension
              // disabled or uninstalled since this arrangement was saved. It
              // keeps its pane and says so, rather than costing the operator
              // the layout.
              else if (!nativeModuleIds.contains(id))
                id: MissingPanelPane(services: dockServices, panelId: id, gainWith: _gainPanelExtension),
        }.entries)
          entry.key: withPaneOverrides(entry.key, entry.value),
      },
      // What a pane offers while it is being USED. The dock hides all of it
      // while editing, where a tab is a grab handle — a panel's own settings
      // are reachable from the panel, and its LAYOUT options from its header
      // (see [LayoutControls.paneEditControls]); the two are different questions and this is
      // the one that belongs to the panel.
      tabActions: {
        ...tabActions,
        for (final id in inLayout)
          if (!tabActions.containsKey(id) && (dockServices.panels[id]?.formFields.isNotEmpty ?? false))
            id: (context) => buildPanelSettingsButton(dockServices.panels[id]!, context: context),
      },
      editing: layoutEditing,
      pinnedModuleIds: pinnedModuleIds,
      editingPaneControls: paneEditControls,
      // Every module in the arrangement, not just those with stored options:
      // a view's default reaches panes the operator has never configured, and
      // those have no entry in [paneOptions] at all.
      headerlessModules: {
        for (final id in inLayout)
          if (!_showsHeader(id)) id,
      },
      // A panel's own declared minimum, when it has one — see
      // [PanelDefinition.minWidth]/[minHeight]. Missing entries fall back to
      // the dock's default floor, so this only needs to name the panels that
      // ask for more.
      moduleMinimumSizes: {
        for (final id in inLayout)
          if (dockServices.panels[id] case final panel? when panel.minWidth != null || panel.minHeight != null)
            id: Size(panel.minWidth ?? 0, panel.minHeight ?? 0),
      },
      // Only after the dock has actually dropped it — it refuses for the last
      // module, and forgetting a pane that is still on screen would wipe what
      // the operator can see.
      onModuleDeleted: (id) => forgetPanes([id]),
      initialState: dockState,
      onStateChanged: (state) {
        // No setState: which pane is on top changes nothing this build depends
        // on, and the dock has already redrawn itself. The field still has to
        // move, since it is what a remounted dock opens on. A pane that cares
        // which one is on top reads `DockPaneVisibility`, which the dock
        // derives per rebuild and this can never contradict.
        dockState = state;
        dockServices.settings.setLayoutData(dockKeys.state, state.toJson());
      },
      onSpecChanged: (node) {
        // A container that has left the tree takes its options with it. Done
        // here rather than from a callback because a container can go without
        // anyone dropping it: `collapseNested` retires one the moment it is
        // down to a single module. Left behind, the rename and the overrides
        // would be written to settings by the next save AND handed straight
        // back — `_newContainerId` reuses the lowest free number — so the next
        // container built in this dock would arrive already named.
        //
        // Safe inside an edit: a discard restores `paneOptions` wholesale from
        // its snapshot, so a container the draft dropped comes back with its
        // name, exactly as a pane does.
        final live = node.collectContainerIds().toSet();
        paneOptions.removeWhere((id, _) => isDockContainerId(id) && !live.contains(id));
        // setState, not a bare assignment: `children` above is built from the
        // modules the arrangement held at the LAST parent build, so a pane
        // added from the layout sheet would otherwise get no widget and render
        // as an empty tab until something unrelated rebuilt the view.
        setState(() => dockSpec = node);
        // While editing, the arrangement is a draft and storage hears nothing
        // — which is the whole basis on which Discard can promise anything.
        // Outside edit mode this is a divider drag, and those save as they
        // always have — unless the operator hasn't yet accepted the recovered
        // default (see [_showingRecoveredDefault]), in which case even a drag
        // must not be the write that clobbers the unreadable original.
        if (!layoutEditing && !_showingRecoveredDefault) {
          dockServices.settings.setLayoutData(dockKeys.spec, node.toJson());
        }
        // The layout sheet, if it is open, is listing this very tree.
        bumpSheet();
      },
    );
  }
}

/// One view's arrangement for one [DockLayoutClass]: the tree, its state, its
/// options, and the snapshots an edit in progress can be rolled back to.
///
/// A class rather than four parallel maps on the mixin: these move together —
/// resolved together, snapshotted together, saved together — and a field that
/// forgot to grow a second copy is a phone writing into the desktop's layout,
/// which nothing on screen would say.
class _DockClassState {
  _DockClassState(SettingsService settings, this.keys)
    : state = DockState.fromJson(settings.layoutData(keys.state)),
      paneOptions = PaneLayoutOptions.mapFromJson(settings.layoutData(keys.paneOptions)),
      viewOptions = PaneLayoutOptions.fromJson(settings.layoutData(keys.viewOptions));

  final DockLayoutKeys keys;

  /// This class's own dock — see [DockHost.dockKey].
  final dockKey = GlobalKey<DockLayoutViewState>();

  /// Null until [DockHost.ensureDockSpec] resolves it — which happens on the
  /// first build that DRAWS this class, so the class off screen may still be
  /// unresolved when an edit begins. See [DockHost.startLayoutEditing], which
  /// resolves both rather than snapshotting a null.
  DockNode? spec;

  DockState state;

  /// Panes this class dropped while editing, whose contents are forgotten only
  /// if the edit is SAVED. Forgetting on removal is what makes a re-added pane
  /// arrive empty rather than holding the last one's notes — but a discard
  /// brings the pane back, and it has to come back with what was in it.
  final pendingForgets = <String>[];

  Map<String, PaneLayoutOptions> paneOptions;
  PaneLayoutOptions viewOptions;

  /// What Discard restores, as JSON rather than as the tree itself: the dock
  /// mutates its nodes IN PLACE (a divider drag edits a split's weights), so
  /// holding the live objects would hold a snapshot that changes with them.
  Map<String, dynamic>? specSnapshot;
  Map<String, dynamic>? paneOptionsSnapshot;
  Map<String, dynamic>? viewOptionsSnapshot;

  /// See [DockHost._showingRecoveredDefault] — per class, and so is the
  /// StatusBar notice that resolves it.
  bool showingRecoveredDefault = false;
  DockNode? recoveredDefaultSpec;
  VoidCallback? recoveredDefaultNoticeListener;

  void clearSnapshots() {
    specSnapshot = null;
    paneOptionsSnapshot = null;
    viewOptionsSnapshot = null;
  }
}
