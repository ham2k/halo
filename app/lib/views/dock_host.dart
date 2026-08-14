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

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../i18n/strings.g.dart';
import '../main.dart';
import '../services/panel_service.dart';
import '../services/settings_service.dart';
import '../services/status_bar_service.dart';
import '../settings/settings_target_dialog.dart';
import 'extensions_panel.dart';
import 'operation/clock/clock_panel.dart';
import 'operation/clock/clock_zones.dart';
import 'operation/extension_panel.dart';
import 'operation/layout_sheet.dart';
import 'operation/missing_panel_pane.dart';
import 'operation/pane_layout_options.dart';
import 'operation/panel_settings.dart';
import 'operation/weather/weather_panel.dart';
import 'operation/website/website_panel.dart';

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
  static const everySpec = [LayoutKeys.homeDock, LayoutKeys.operationDock, LayoutKeys.logsDock];

  /// The arrangement — splits, weights and module ids.
  final String spec;

  /// Which pane is on top. Written as the operator selects, edit mode or not.
  final String state;

  /// Per-pane options, keyed by module id. Part of the arrangement.
  final String paneOptions;

  /// The view's own options — scale and density for everything in it.
  final String viewOptions;

  const DockLayoutKeys({
    required this.spec,
    required this.state,
    required this.paneOptions,
    required this.viewOptions,
  });
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

  /// Where this view's layout is persisted.
  DockLayoutKeys get dockKeys;

  /// The arrangement this view ships with, and what Restore Defaults puts
  /// back.
  /// The arrangement this view ships with.
  ///
  /// [migrate] is false for a RESTORE: a view that folds an older stored
  /// dimension into its default (Home's pre-dock column width) must not fold
  /// it in here, or Restore Defaults hands back the operator's own old
  /// measurement forever and nothing in the app reaches the shipped layout.
  DockNode buildDefaultDockSpec({bool migrate = true});

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

  /// Modules whose header is off until the operator says otherwise. Empty by
  /// default: a pane that names itself is the safe assumption, and a view
  /// overrides this only where the panes are self-evident from their content.
  ///
  /// A DEFAULT, not a rule — [PaneLayoutOptions.showHeader] still wins for any
  /// pane the operator has an opinion about, in either direction.
  Set<String> get defaultHeaderlessModules => const {};

  /// Whether [id] shows its header right now, resolving the operator's own
  /// choice against this view's default.
  bool _showsHeader(String id) =>
      (paneOptions[id] ?? PaneLayoutOptions.none)
          .showsHeader(byDefault: !defaultHeaderlessModules.contains(id));

  // ------------------------------------------------------------------- state

  /// Programmatic access to the mounted dock — `revealModule`, `addModule`,
  /// `removeModule`, `replaceSpec`.
  final dockKey = GlobalKey<DockLayoutViewState>();

  /// The arrangement, resolved from settings (or the default) ONCE:
  /// [DockLayoutView] copies its `initialSpec` into its own State on first
  /// build and ignores it afterward, so re-parsing the persisted JSON every
  /// build would be pure waste on this hot path. Kept in sync with the
  /// widget's mutations via `onSpecChanged`.
  DockNode? dockSpec;

  /// True from the moment a saved arrangement is found unreadable until the
  /// operator explicitly accepts the default shown in its place (the
  /// StatusBar notice's action, see [_hasNoDuplicates]). While this is on,
  /// nothing writes [DockLayoutKeys.spec] — the unreadable original is what a
  /// future fix would need to recover, and every ordinary write path (a
  /// divider drag, a save) would otherwise replace it with the default the
  /// moment it runs, which is exactly the silent loss this guards against.
  bool _showingRecoveredDefault = false;

  /// The default substituted when a saved arrangement was found unreadable —
  /// what "Use this layout" actually writes. A SEPARATE value from [dockSpec]
  /// on purpose: the operator can start editing while the notice is still up
  /// (`dockSpec` starts equal to this, but a live edit moves it, see
  /// `onSpecChanged`), and accepting must write the plain default that was
  /// shown, not whatever half-finished draft happens to be on screen at the
  /// moment they tap it — that draft has its own, later save.
  DockNode? _recoveredDefaultSpec;

  /// Listens for the StatusBar notice leaving [StatusBarService.activeNotices]
  /// by any means OTHER than its own action — chiefly the notice card's
  /// built-in dismiss button, which this file has no way to intercept
  /// directly. Live only while [_showingRecoveredDefault] is on; removed the
  /// moment it resolves one way or the other. See [_hasNoDuplicates].
  VoidCallback? _recoveredDefaultNoticeListener;

  /// The dock's STATE — which pane is on top — in its own key, apart from the
  /// arrangement.
  ///
  /// Kept CURRENT, not read once: the dock is unmounted and rebuilt whenever
  /// the layout crosses a breakpoint (a window resize, or a font scale change
  /// that moves the effective width), and its `initState` applies this over
  /// the live tree. Stale here means reopening on whatever tab was on top at
  /// launch, undoing the operator's selection every time they resize past the
  /// boundary and back.
  late DockState dockState = DockState.fromJson(dockServices.settings.layoutData(dockKeys.state));

  /// Per-pane layout options, keyed by module id. Read once and then owned
  /// here, like [dockSpec] and for the same reason — edited as part of the
  /// same draft and written by the same save.
  late Map<String, PaneLayoutOptions> paneOptions = PaneLayoutOptions.mapFromJson(
    dockServices.settings.layoutData(dockKeys.paneOptions),
  );

  /// The VIEW's own layout options, read once and owned here for the same
  /// reason [paneOptions] is.
  late PaneLayoutOptions viewOptions = PaneLayoutOptions.fromJson(
    dockServices.settings.layoutData(dockKeys.viewOptions),
  );

  /// Whether the arrangement is being edited (see [DockLayoutView.editing]).
  /// While this is on, the dock's changes are a DRAFT: nothing reaches
  /// settings until Save Layout.
  bool layoutEditing = false;

  /// True while the Add a Panel sheet's route is on screen. It is a top modal
  /// pane, which leaves this view's header uncovered but NOT tappable — so
  /// while it is up the header's layout controls are drawn by the route
  /// instead (see [layoutHeaderControls]).
  bool layoutSheetOpen = false;

  /// The arrangement as it was when editing began, as JSON — what Discard
  /// restores. JSON rather than the tree itself because the dock mutates its
  /// nodes IN PLACE (a divider drag edits a split's weights), so holding the
  /// live objects would hold a snapshot that changes with them.
  Map<String, dynamic>? _layoutSnapshot;
  Map<String, dynamic>? _paneOptionsSnapshot;
  Map<String, dynamic>? _viewOptionsSnapshot;

  /// Panes dropped while editing, whose contents are forgotten only if the
  /// edit is SAVED. Forgetting on removal is what makes a re-added pane arrive
  /// empty rather than holding the last one's notes — but a discard brings the
  /// pane back, and it has to come back with what was in it.
  final _pendingForgets = <String>[];

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
    dockServices.panels.addListener(_onPanelCatalogChanged);
    // Extensions are asked for their panels once per view, not once per build:
    // the runtime restarts when an extension is enabled or disabled, and a
    // view is rebuilt from scratch either way.
    unawaited(dockServices.panels.refreshExtensionPanels());
  }

  @override
  void dispose() {
    dockServices.panels.removeListener(_onPanelCatalogChanged);
    if (_recoveredDefaultNoticeListener case final listener?) {
      dockServices.statusBar.removeListener(listener);
    }
    super.dispose();
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
  void ensureDockSpec() {
    if (dockSpec != null) return;
    var persisted = DockNode.fromJson(dockServices.settings.layoutData(dockKeys.spec));
    for (final id in retiredModules) {
      persisted = persisted?.without(id);
    }
    dockSpec = persisted != null && _hasNoDuplicates(persisted) ? persisted : buildDefaultDockSpec();
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
    for (final key in DockLayoutKeys.everySpec) {
      final spec = DockNode.fromJson(dockServices.settings.layoutData(key));
      if (spec != null) yield* spec.collectModules();
    }
  }

  /// Writes [_recoveredDefaultSpec] and lets ordinary writes resume — the
  /// operator has said the substituted default replaces the unreadable
  /// original. Idempotent: the notice's action and
  /// [_recoveredDefaultNoticeListener] can both reach here (the action's own
  /// `dismissNotice` call re-triggers the listener), so the guard is checked
  /// first rather than assumed.
  void _acceptRecoveredDefault() {
    if (!_showingRecoveredDefault) return;
    _showingRecoveredDefault = false;
    if (_recoveredDefaultSpec case final spec?) {
      dockServices.settings.setLayoutData(dockKeys.spec, spec.toJson());
    }
    if (_recoveredDefaultNoticeListener case final listener?) {
      dockServices.statusBar.removeListener(listener);
      _recoveredDefaultNoticeListener = null;
    }
  }

  bool _hasNoDuplicates(DockNode spec) {
    final modules = spec.collectModules();
    if (modules.length == modules.toSet().length) return true;
    debugPrint('[layout] saved $dockView arrangement lists a module twice; falling back to the default');
    _showingRecoveredDefault = true;
    _recoveredDefaultSpec = buildDefaultDockSpec();
    final noticeKey = 'layout:$dockView:unreadable';
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
        if (!stillActive) _acceptRecoveredDefault();
      }

      _recoveredDefaultNoticeListener = onNoticeChanged;
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
              _acceptRecoveredDefault();
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
      DockGroup(:final modules) => modules.contains(id) ? modules.length : null,
      DockSplit(:final children) => children.map(sizeIn).nonNulls.firstOrNull,
    };
    return dockSpec == null ? 1 : sizeIn(dockSpec!) ?? 1;
  }

  /// Every tab's label, in precedence order — see the comments inline, which
  /// are the whole point of the ordering.
  Map<String, String> dockTitles() => {
    ...nativeTitles,
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
    _forgetPanesNow(ids);
  }

  void _forgetPanesNow(Iterable<String> ids) {
    for (final id in ids.toList()) {
      panelTitles.remove(id);
      // Its layout options go with it — they describe a place in the
      // arrangement, and that place is gone.
      paneOptions.remove(id);
      unawaited(dockServices.panels.forgetInstanceConfig(id));
    }
  }

  // -------------------------------------------------------------- edit mode

  void bumpSheet() => _sheetRevision?.value++;

  void _dropPressFocusCapture() =>
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusAtPress = null);

  /// Restores focus a frame later: the panes are still excluded from traversal
  /// during the build that ends edit mode, and a request made then is refused.
  /// [keep] holds the captured node for a LATER restore: crossing a
  /// breakpoint unmounts the dock mid-edit, and the exit that follows still
  /// has to hand focus back.
  void restoreFocusAfterEditing({bool keep = false}) {
    final node = _focusBeforeLayoutEditing;
    if (!keep) _focusBeforeLayoutEditing = null;
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
    final spec = dockSpec;
    if (spec == null) {
      // `ensureDockSpec` always resolves this before the dock (and this
      // button) can be built — reachable only if that contract breaks.
      assert(false, 'layout:edit-no-arrangement: Edit Layout pressed with no arrangement resolved');
      debugPrint('[layout] edit-no-arrangement: Edit Layout pressed with no arrangement resolved');
      return;
    }
    setState(() {
      _layoutSnapshot = spec.toJson();
      _paneOptionsSnapshot = PaneLayoutOptions.mapToJson(paneOptions);
      _viewOptionsSnapshot = viewOptions.toJson();
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
    final snapshot = _layoutSnapshot;
    final spec = snapshot == null ? null : DockNode.fromJson(snapshot);
    if (spec == null) {
      // Leave anyway. Edit mode left on has no way out from here.
      // `startLayoutEditing` always sets `_layoutSnapshot` from a live,
      // already-valid `DockNode` before `layoutEditing` can turn on, so
      // neither a null snapshot nor one that fails to parse back should be
      // reachable here.
      assert(false, 'layout:revert-no-snapshot: discard pressed with nothing to revert to');
      debugPrint('[layout] revert-no-snapshot: discard pressed with nothing to revert to');
      setState(() {
        _pendingForgets.clear();
        layoutEditing = false;
        _layoutSnapshot = null;
        _paneOptionsSnapshot = null;
        _viewOptionsSnapshot = null;
      });
      restoreFocusAfterEditing();
      bumpSheet();
      return;
    }
    // NOT required: a narrow window may have no dock mounted. `dockSpec` below
    // is what a remounting dock reads.
    final dock = dockKey.currentState;
    // Panes this discard is DROPPING: everything the edit brought into being
    // that the restored arrangement does not hold — those still on screen
    // (added) AND those already taken out again (added, then removed, so in
    // `_pendingForgets` and in neither tree). Miss the second set and a
    // discarded pane's notes wait for the next placement to reuse its id,
    // which is the leak the deferred forget exists to prevent.
    final restored = spec.collectModules().toSet();
    final dropped = {..._pendingForgets, ...?dockSpec?.collectModules()}.difference(restored);
    dockState.applyTo(spec);
    // emit: false — a discard is the operator UNDOING their own edits, and
    // reporting it back would be recorded as one more of them.
    dock?.replaceSpec(spec, emit: false);
    setState(() {
      dockSpec = spec;
      // The panes the edit's removals took out are back on screen; forgetting
      // their contents now would empty a pane the operator can see.
      _pendingForgets.clear();
      paneOptions = PaneLayoutOptions.mapFromJson(_paneOptionsSnapshot);
      viewOptions = PaneLayoutOptions.fromJson(_viewOptionsSnapshot);
      layoutEditing = false;
      _layoutSnapshot = null;
      _paneOptionsSnapshot = null;
      _viewOptionsSnapshot = null;
    });
    _forgetPanesNow(dropped);
    restoreFocusAfterEditing();
    bumpSheet();
  }

  /// Commits the draft and leaves edit mode.
  void saveLayout() {
    final spec = dockSpec;
    // Panes this save is DROPPING: removed during the edit and NOT back in the
    // arrangement being saved. The same set difference the discard takes,
    // running the other way — a pane dropped and then re-added (or a new
    // instance handed the freed id, which [PanelService.nextInstanceId] does
    // on purpose) is a pane the operator can see, and forgetting it would
    // empty one they just filled in.
    final kept = spec?.collectModules().toSet() ?? const <String>{};
    final forgotten = _pendingForgets.toSet().difference(kept);
    // Same guard as `onSpecChanged`'s divider-drag write — see
    // [_showingRecoveredDefault]. An edit session reachable while a saved
    // arrangement is unread is editing the DEFAULT, and NONE of it — the
    // spec, the pane options, the view options, or a forgotten pane's config
    // — may reach settings before the operator has chosen to keep it. A
    // pane id the default happens to share with the real arrangement would
    // otherwise have its options clobbered ahead of that choice.
    if (!_showingRecoveredDefault) {
      // Before the writes, never after: forgetting drops these panes' entries
      // from [paneOptions], and a map serialized first would carry a removed
      // pane's title and overrides to disk for whatever takes its id next.
      _forgetPanesNow(forgotten);
      final settings = dockServices.settings;
      if (spec != null) settings.setLayoutData(dockKeys.spec, spec.toJson());
      settings.setLayoutData(dockKeys.paneOptions, PaneLayoutOptions.mapToJson(paneOptions));
      settings.setLayoutData(dockKeys.viewOptions, viewOptions.toJson());
    }
    setState(() {
      layoutEditing = false;
      _layoutSnapshot = null;
      _paneOptionsSnapshot = null;
      _viewOptionsSnapshot = null;
      _pendingForgets.clear();
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
    final defaults = buildDefaultDockSpec(migrate: false);
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
        builder: (context, constraints) => LayoutDensityScope(
          density: preference.resolve(constraints.maxHeight),
          child: inner,
        ),
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

  /// Whether any extension the operator could enable contributes a panel. The
  /// Extensions list this opens is filtered to the `panel` hook, and a gated
  /// extension is not in it either.
  bool get _hasPanelExtensions {
    final extensions = dockServices.extensions;
    return extensions.availableExtensions
        .any((info) => !info.core && info.hooks.contains('panel') && extensions.isExtensionAvailable(info));
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
    final defaultTitle = panelTitles[id] ?? panel?.title ?? nativeTitles[id] ?? panelKeyOfPanelId(id);
    // A plain-form extension panel's settings embed as an
    // [EmbeddedPanelSettingsForm]; a pane the VIEW answers for natively is
    // reached through a target instead and builds its own form above.
    final embeddablePanel = nativePanelSettingsForm(context, id) == null && panel != null && panel.formFields.isNotEmpty
        ? panel
        : null;
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
        final panelConfig = embeddablePanel != null
            ? Map<String, dynamic>.of(await dockServices.panels.configFor(embeddablePanel))
            : null;
        if (!context.mounted) return;
        unawaited(showPaneLayoutOptions(
        context,
        paneTitle: options.title ?? defaultTitle,
        defaultTitle: defaultTitle,
        // The header is the tab strip once a pane shares a group, so hiding it
        // is not on offer there.
        inTabset: groupSizeOf(id) > 1,
        headerByDefault: !defaultHeaderlessModules.contains(id),
        developerMode: dockServices.settings.developerMode,
        current: options,
        resetTitle: _t.resetPaneConfirm(panel: options.title ?? defaultTitle),
        resetBody: _t.resetPaneConfirmBody,
        onReset: () => setState(() => paneOptions.remove(id)),
        // The keyboard/screen-reader route to what the delete target does: a
        // drag cannot be made without a pointer, and Restore Defaults is the
        // whole arrangement. Absent for the last pane, which the dock refuses
        // to remove — an empty dock has no tab left to drag anything back
        // with.
        onDelete: paneCount() > 1
            ? () {
                final dock = dockKey.currentState;
                // NOT asserted-impossible: the dialog this button lives in is
                // a route, which outlives the dock across a breakpoint that
                // crosses the two-pane threshold and unmounts it — same
                // condition [openAddPanelSheet] and `onAdd` guard against.
                if (dock == null) return;
                if (dock.removeModule(id)) forgetPanes([id]);
              }
            : null,
        // Hiding a pane's header takes the tab action with it, and that is the
        // only other way to a panel's own settings.
        //
        // No `actions` / no `type: 'action'` elements in any of these: an
        // action here would need a route of its own to signal "done" by
        // closing, and this embed has none — it lives inside the pane layout
        // options dialog, not behind a route it owns.
        panelSettingsBuilder: nativePanelSettingsForm(context, id) ??
            (embeddablePanel != null && panelConfig != null
                ? (builderContext) => EmbeddedPanelSettingsForm(
                      fields: embeddablePanel.formFields.where((field) => field['type'] != 'action').toList(),
                      initial: panelConfig,
                      developerMode: dockServices.settings.developerMode,
                      onFieldChange: (key, value, state) async {
                        final field = embeddablePanel.formFields.firstWhere(
                          (f) => f['key'] == key,
                          orElse: () => const {},
                        );
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
        onChanged: (next) => setState(() {
          // Dropped rather than stored empty, so a layout carries options only
          // for the panes that actually have any.
          if (next.isEmpty) {
            paneOptions.remove(id);
          } else {
            paneOptions[id] = next;
          }
        }),
        ));
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
        onPressed: () => unawaited(showPanelSettings(buttonContext, services: dockServices, panel: panel)),
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
  }) {
    final theme = Theme.of(context);
    return Builder(
      builder: (buttonContext) => IconButton(
        icon: Icon(
          MdiIcons.tune,
          color: theme.appBarTheme.foregroundColor ?? theme.colorScheme.onPrimary,
          semanticLabel: MaterialLocalizations.of(context).showMenuTooltip,
        ),
        onPressed: () => showSettingsForTarget(
          buttonContext,
          services: dockServices,
          target: target,
          title: title,
          actions: actions,
        ),
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
      icon: Icon(
        MdiIcons.viewDashboardEdit,
        color: theme.appBarTheme.foregroundColor ?? theme.colorScheme.onPrimary,
        semanticLabel: _t.viewOptions,
      ),
      onPressed: () => unawaited(showPaneLayoutOptions(
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
        onChanged: (next) => setState(() => viewOptions = next),
        resetTitle: _t.resetViewConfirm,
        resetBody: _t.resetViewConfirmBody,
        onReset: restoreLayoutDefaults,
      )),
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
      // pressing it again is refused (see [openAddPanelSheet]). An enabled,
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
      TextButton.icon(
        onPressed: () => _endEditingFrom(context, inSheet: inSheet, exit: saveLayout),
        icon: const Icon(MdiIcons.contentSave, size: 18),
        label: Text(_t.saveLayout),
        style: TextButton.styleFrom(foregroundColor: onHeader),
      ),
    ];
  }

  /// The guard below is not reachable through the UI (the sheet's header
  /// carries no plus), which is exactly why it is worth a test: it is what
  /// stops a second caller stacking a route over the first.
  @visibleForTesting
  Future<void> openAddPanelSheetForTest() => openAddPanelSheet();

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
    final t = _t;
    setState(() => layoutSheetOpen = true);
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
          builder: (headerContext, _, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [...layoutHeaderControls(headerContext, inSheet: true), windowsCaptionSpacer(context)],
          ),
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
            style: IconButton.styleFrom(
              backgroundColor: fabAccentColor,
              foregroundColor: Theme.of(buttonContext).colorScheme.onPrimary,
            ),
            onPressed: () => Navigator.of(buttonContext).pop(),
          ),
        ),
        builder: (_) => ValueListenableBuilder<int>(
          valueListenable: revision,
          builder: (context, _, _) {
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
                    ),
              ],
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
                dock.addModule(
                  panel != null && panel.multiple
                      // Ids waiting to be forgotten are NOT free. Their config
                      // outlives the removal until the save commits it, so
                      // handing one to a new placement gives the operator a
                      // pane that arrives holding the last one's notes — and
                      // the save then spares it, seeing the id back in the
                      // arrangement.
                      ? PanelService.nextInstanceId(id, [
                          ...dock.modules,
                          ..._pendingForgets,
                          ..._instanceIdsInEveryDock(),
                        ])
                      : id,
                );
              },
              // Filtered to the extensions that contribute panels — an
              // operator sent here for more panels should not be handed the
              // whole catalog. Offered only when it leads somewhere: panel
              // extensions are themselves behind the `panels` experiment, so
              // with that off there are none at all, and a button whose whole
              // purpose is "find the panel you want" opening an empty list is
              // worse than no button.
              onManageExtensions: _hasPanelExtensions
                  ? () => unawaited(() async {
                      await showModalPane<void>(
                        context,
                        title: context.t.activitiesView.manageExtensions,
                        closeLabel: context.t.common.close,
                        scrollable: false,
                        builder: (_) => ExtensionsPanel(services: dockServices, onlyHook: 'panel'),
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
      if (mounted) setState(() => layoutSheetOpen = false);
    }
  }

  /// Clock, Weather and Web Site: the three native panels every customizable
  /// view offers (docs/design/layouts.md), built here once so a change to one
  /// of them doesn't have to reach every view that hosts a dock. See
  /// [registerSharedDashboardPanels] for their catalog entry — this only
  /// builds the widget for whatever placement [inLayout] holds.
  ///
  /// [operationGrid] and [isEnteringQso] are the two things only an operation
  /// has: null outside the Operation view, which leaves Weather to its own
  /// configured location and Web Site to reload strictly on schedule.
  Map<String, Widget> sharedDashboardPanes(
    List<String> inLayout, {
    String? operationGrid,
    bool Function()? isEnteringQso,
  }) => {
    for (final id in inLayout)
      if (PanelDefinition.descriptorIdOf(id) == clockPanelId)
        id: ClockPanel(
          key: ValueKey('panel-$id'),
          panelId: id,
          panels: dockServices.panels,
          onTitle: (title) => onPanelTitle(id, title),
        )
      else if (PanelDefinition.descriptorIdOf(id) == weatherPanelId)
        id: WeatherPanel(
          key: ValueKey('panel-$id'),
          panelId: id,
          panels: dockServices.panels,
          settings: dockServices.settings,
          operationGrid: operationGrid,
          onTitle: (title) => onPanelTitle(id, title),
        )
      else if (PanelDefinition.descriptorIdOf(id) == websitePanelId)
        id: WebsitePanel(
          key: ValueKey('panel-$id'),
          panelId: id,
          panels: dockServices.panels,
          onTitle: (title) => onPanelTitle(id, title),
          isEnteringQso: isEnteringQso,
        ),
  };

  /// Clock, Weather and Web Site's catalog entries — see
  /// [sharedDashboardPanes] for the widgets. Every view that hosts a dock
  /// calls this from its own `_registerNativePanels`: [PanelService.registerNative]
  /// no-ops on an identical re-registration, so whichever view mounts first
  /// wins and the other two calls cost nothing. A single owner (Home, say,
  /// since it's the one view mounted for the app's whole lifetime) would
  /// leave these missing from Operation's or the Logs view's own catalog
  /// whenever either is exercised on its own — as every one of their widget
  /// tests does.
  void registerSharedDashboardPanels() {
    final t = context.t.operation;
    final service = dockServices.panels;
    const sharedViews = {PanelViews.home, PanelViews.operation, PanelViews.logs};
    service.registerNative(PanelDefinition(
      id: clockPanelId,
      title: t.tabs.clock,
      description: t.layout.panels.clockDescription,
      icon: 'clock-outline',
      source: PanelSource.native,
      views: sharedViews,
      // The one native pane an operator plausibly wants several of: a UTC
      // clock beside the DX's local time is the whole point of it.
      multiple: true,
      formFields: [
        {
          'type': 'field',
          'key': clockFaceKey,
          'fieldType': 'select',
          'label': t.layout.panels.clockFace,
          'value': clockFaceLcd,
          'options': [
            {'label': t.layout.panels.clockFaceLcd, 'value': clockFaceLcd},
            {'label': t.layout.panels.clockFaceAnalog, 'value': clockFaceAnalog},
          ],
        },
        {
          'type': 'field',
          'key': clockZoneKey,
          'fieldType': 'select',
          // `icon` is what puts this behind a full-list dialog rather than an
          // inline dropdown — 341 zones in a ten-row popup is not a picker.
          // The dialog searches past twenty options.
          'icon': 'earth',
          'label': t.layout.panels.clockZone,
          'value': utcZoneId,
          'options': clockZoneOptions(
            utcLabel: t.layout.panels.clockZoneUtc,
            deviceLabel: t.layout.panels.clockZoneDevice,
          ),
        },
        {
          'type': 'field',
          'key': clockShowSecondsKey,
          'fieldType': 'checkbox',
          'label': t.layout.panels.clockShowSeconds,
          'value': true,
        },
      ],
    ));
    service.registerNative(PanelDefinition(
      id: weatherPanelId,
      title: t.tabs.weather,
      description: t.layout.panels.weatherDescription,
      icon: 'weather-partly-cloudy',
      source: PanelSource.native,
      views: sharedViews,
      // Instanceable so a placement in Home, in an operation and in the Logs
      // view are three independent locations rather than one shared config
      // — the same reason Clock is (see its own comment below). Unlike
      // Clock, an operator plausibly wants only one at a time; `multiple`
      // exists for the cross-view case, not to invite several in one dock.
      multiple: true,
      formFields: [
        {
          'type': 'field',
          'key': weatherUseOperationLocationKey,
          'fieldType': 'checkbox',
          'label': t.layout.panels.weatherUseOperationLocation,
          'value': true,
        },
        {
          'type': 'field',
          'key': weatherLocationKey,
          'fieldType': 'text',
          'label': t.layout.panels.weatherLocation,
          'description': t.layout.panels.weatherLocationDescription,
          'value': '',
          // Deliberately never hidden by `visibleWhen`, even though it's
          // read only while [weatherUseOperationLocationKey] is off — a
          // config predating that checkbox never wrote it, so an existing
          // override's checkbox state is INFERRED (`_useOperationLocation`)
          // rather than read back, and can disagree with what the form
          // shows. A hidden field would put the one control that explains
          // — or fixes — that disagreement out of reach.
        },
      ],
    ));
    service.registerNative(PanelDefinition(
      id: websitePanelId,
      title: t.tabs.website,
      description: t.layout.panels.websiteDescription,
      icon: 'web',
      source: PanelSource.native,
      views: sharedViews,
      multiple: true,
      formFields: [
        {
          'type': 'field',
          'key': websiteUrlKey,
          // No `url` fieldType exists, and an unknown one renders as nothing
          // at all — no field, no error, no log.
          'fieldType': 'text',
          'label': t.layout.panels.websiteUrl,
          'placeholder': 'https://…',
          'value': '',
        },
        {
          'type': 'field',
          'key': websiteRefreshKey,
          'fieldType': 'select',
          'label': t.layout.panels.websiteRefresh,
          // `0`, not null: a null-valued select cannot tell "dismissed" from
          // "picked null". Ints survive the config's JSON round-trip as ints,
          // which is what the dropdown's `value ==` needs.
          'value': 0,
          'options': [
            {'label': t.layout.panels.websiteRefreshNever, 'value': 0},
            {'label': t.layout.panels.websiteRefresh1, 'value': 1},
            {'label': t.layout.panels.websiteRefresh5, 'value': 5},
            {'label': t.layout.panels.websiteRefresh15, 'value': 15},
          ],
        },
        {
          'type': 'field',
          'key': websiteTitleKey,
          'fieldType': 'text',
          'label': t.layout.panels.websiteTitle,
          'value': '',
        },
        // Live only because `showPanelSettings` passes `onAction`; without
        // that this button renders disabled.
        {
          'type': 'action',
          'key': 'refreshNow',
          'label': t.layout.panels.websiteRefreshNow,
          'method': panelRefreshMethod,
        },
      ],
    ));
  }

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
                )
              // A module nothing in the catalog explains — an extension
              // disabled or uninstalled since this arrangement was saved. It
              // keeps its pane and says so, rather than costing the operator
              // the layout.
              else if (!nativeModuleIds.contains(id))
                id: MissingPanelPane(extensionName: extensionKeyOfPanelId(id) ?? id),
        }.entries)
          entry.key: withPaneOverrides(entry.key, entry.value),
      },
      // What a pane offers while it is being USED. The dock hides all of it
      // while editing, where a tab is a grab handle — a panel's own settings
      // are reachable from the panel, and its LAYOUT options from its header
      // (see [paneEditControls]); the two are different questions and this is
      // the one that belongs to the panel.
      tabActions: {
        ...tabActions,
        for (final id in inLayout)
          if (!tabActions.containsKey(id) && (dockServices.panels[id]?.formFields.isNotEmpty ?? false))
            id: (context) => buildPanelSettingsButton(dockServices.panels[id]!, context: context),
      },
      editing: layoutEditing,
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
