// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The logging view: four tabs, ported from app-polo's OperationView —
// "N QSOs" (list + logging panel; a wide-layout info side panel appears
// there too, the first step toward the module-docking layout of
// DESIGN.md §7), Spots, Map, and Operation (settings/activities/data, a
// scoped-down OpSettingsTab).

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../config/dev_bridge.dart';
import '../main.dart';
import '../services/cat/equipment.dart';
import '../services/cat/zero_beat.dart';
import '../services/panel_service.dart';
import '../services/settings_service.dart';
import '../settings/settings_target_dialog.dart';
import 'operation_dialogs.dart';
import 'panel_use_tracker.dart';
import 'extensions_panel.dart';
import 'operation/adif_import_flow.dart';
import 'operation/activities_view.dart';
import 'operation/call_info_panel.dart';
import 'operation/clock/clock_panel.dart';
import 'operation/clock/clock_zones.dart';
import 'operation/weather/weather_panel.dart';
import 'operation/website/website_panel.dart';
import 'operation/extension_panel.dart';
import 'operation/information_panel.dart';
import 'operation/layout_sheet.dart';
import 'operation/logging_panel.dart';
import 'operation/map_panel.dart';
import 'operation/missing_panel_pane.dart';
import 'operation/panel_settings.dart';
import 'operation/pane_layout_options.dart';
import 'operation/operation_export_panel.dart';
import 'operation/spots_panel.dart';
import '../tools/operation_title.dart';
import '../i18n/strings.g.dart';

class OperationView extends StatefulWidget {
  /// The Operation view is the (currently only) layout-customizable view
  /// (docs/design/layouts.md): its panes are dock-arrangeable behind the
  /// Enable Layout Customization setting, and ALL its dividers — the fixed split's and the
  /// dock's — use the solid header-colored style (the default).
  static const layoutPolicy = ViewLayoutPolicy.customizable;

  final HaLoServices services;
  final String operationUuid;

  /// Open the Activities pane as soon as the operation loads — the
  /// new-operation flow skips its old call/title dialog and lands here, so
  /// picking activities is the first step of setting up an operation.
  /// Fallback until an onboarding flow exists: when the active profile has
  /// no callsign yet, the callsign editor opens instead (see
  /// [_OperationViewState._promptForCallsign]).
  final bool openActivities;

  const OperationView({super.key, required this.services, required this.operationUuid, this.openActivities = false});

  @override
  State<OperationView> createState() => _OperationViewState();
}

// TickerProviderStateMixin, not the Single- variant: this State creates a NEW
// TabController whenever the tab count changes (the two-pane breakpoint swaps
// a 4-tab layout for a 3-tab one), so more than one ticker exists over its
// lifetime — which is exactly what SingleTickerProviderStateMixin asserts
// against, and what resizing across the breakpoint would trip.
class _OperationViewState extends State<OperationView> with TickerProviderStateMixin {
  Operation? _operation;
  List<Map<String, dynamic>> _loggingControls = const [];
  late bool _showRSTFields = widget.services.settings.showRSTFields;
  late bool _showStateField = widget.services.settings.showStateField;
  late bool _showGridField = widget.services.settings.showGridField;
  late bool _showDeletedQSOs = widget.services.settings.showDeletedQSOs;
  late bool _showQsoNumbers = widget.services.settings.showQsoNumbers;
  late String _defaultReport = widget.services.settings.defaultReport;
  late String _defaultReportCW = widget.services.settings.defaultReportCW;
  late String _defaultReportFT8 = widget.services.settings.defaultReportFT8;
  late bool _switchSentRcvd = widget.services.settings.switchSentRcvd;
  late bool _jumpAfterRST = widget.services.settings.jumpAfterRST;

  /// Gate for the drag-and-drop dock layout (DESIGN.md §7), replacing the
  /// wide arrangement's fixed split-plus-tabs with a user-arrangeable
  /// [DockLayoutView]. Narrow layouts are unaffected. Driven by the operator's
  /// own Enable Layout Customization setting — [_onSettingsChanged] keeps it
  /// live, so turning it on re-arranges an open operation without a restart.
  late bool _customLayout = widget.services.settings.layoutCustomization;

  /// Programmatic tab selection inside the dock layout (revealModule) — the
  /// dock-mode counterpart of `_tabController.animateTo`.
  final _dockKey = GlobalKey<DockLayoutViewState>();

  /// The dock arrangement, resolved from settings (or the default) ONCE —
  /// DockLayoutView copies its initialSpec into its own State on first
  /// build and ignores it afterward, so re-parsing the persisted JSON every
  /// build would be pure waste on this hot path. Kept in sync with the
  /// widget's mutations via onSpecChanged.
  DockNode? _dockSpec;

  /// True while the Add a Panel sheet's route is on screen. It is a top modal
  /// pane, which leaves this view's header uncovered but NOT tappable — so
  /// while it is up the header's layout controls are drawn by the route
  /// instead (see [_layoutHeaderControls]).
  bool _layoutSheetOpen = false;

  /// Whether the arrangement is being edited (see [DockLayoutView.editing]).
  /// While this is on, the dock's changes are a DRAFT: nothing reaches
  /// settings until Save Layout.
  bool _layoutEditing = false;

  /// Per-pane layout options, keyed by module id (see [PaneLayoutOptions]).
  /// Read once and then owned here, like [_dockSpec] and for the same reason
  /// — they are edited as part of the same draft and written by the same
  /// save.
  late Map<String, PaneLayoutOptions> _paneOptions = PaneLayoutOptions.mapFromJson(
    widget.services.settings.layoutData(LayoutKeys.operationPaneOptions),
  );

  /// The VIEW's own layout options — read once and owned here, like
  /// [_paneOptions], edited in the same draft and written by the same save.
  late PaneLayoutOptions _viewOptions = PaneLayoutOptions.fromJson(
    widget.services.settings.layoutData(LayoutKeys.operationViewOptions),
  );

  /// The arrangement as it was when editing began, as JSON — what the revert
  /// button restores. JSON rather than the tree itself because the dock
  /// mutates its nodes IN PLACE (a divider drag edits a split's weights), so
  /// holding the live objects would hold a snapshot that changes with them.
  Map<String, dynamic>? _layoutSnapshot;

  /// [_paneOptions] as it was when editing began — the other half of what a
  /// discard restores. Kept as JSON for the same reason [_layoutSnapshot] is:
  /// what is edited must not be the same objects the snapshot holds.
  Map<String, dynamic>? _paneOptionsSnapshot;
  Map<String, dynamic>? _viewOptionsSnapshot;

  /// Panes dropped while editing, whose contents are forgotten only if the
  /// edit is SAVED. Forgetting on removal is what makes a re-added pane
  /// arrive empty rather than holding the last one's notes — but a revert
  /// brings the pane back, and it has to come back with what was in it.
  final _pendingForgets = <String>[];

  /// The station's own DXCC entity, resolved once per operation load (not
  /// per QSO — the station call essentially never changes DXCC entity
  /// mid-operation) so the QSO row can tell a DX contact from a domestic
  /// one. `online: false` skips network lookup hooks (QRZ/HamDB), running
  /// only the local, no-network callsign-annotation step that's all this
  /// needs — see extensions/core/lookups/src/annotate.ts.
  String? _ourEntityPrefix;

  /// The station's own ITU region (1/2/3) and lowercase ISO country code
  /// — resolved alongside [_ourEntityPrefix], from the same guess,
  /// and fed to LoggingControls' band-plan mode guess so it can prefer/
  /// exclude region- or country-scoped segments for where the operator
  /// actually is instead of guessing blind.
  int? _ourItuRegion;
  String? _ourCountryCode;

  /// Cached QSO stream. Recreating `watchForOperation` inside `build` would
  /// make a fresh drift query on every rebuild — a menu toggle, a
  /// `_loggingControls` arrival, an entity-prefix resolve, a rescore refresh
  /// — each tearing
  /// down and re-running the whole query. Keyed on `_showDeletedQSOs`, the
  /// only input that changes during the view's life (the uuid is fixed).
  Stream<List<Qso>>? _qsoStream;
  bool? _qsoStreamIncludesDeleted;
  Operation? _draftOperation;

  /// The draft's ref-derived title fragments, suggested but deliberately not
  /// cached (the draft has no saved row to cache into) — null until the first
  /// suggestion for the current draft lands, at which point the header stops
  /// using the saved row's now-stale cache. Same generation-counter guard as
  /// OperationTitleService: an older, slower fan-out must not overwrite a
  /// newer one's result.
  OperationTitleFragments? _draftTitleFragments;
  int _draftTitleGeneration = 0;

  /// Carries the draft's last-known-good title fragments PAST the moment the
  /// sheet closes and _draftTitleFragments is dropped — saveAndClose()
  /// persists the sheet's own (still stale-titleSuggestion) operation, so
  /// watchOperation's very next emission reads that stale cache straight
  /// back over whatever _withTitleSuggestion patched into _operation at
  /// close. Kept alive and re-applied to every incoming stream emission
  /// (see [_onOperationChanged]) until the row's OWN persisted cache
  /// actually catches up — the separate, async
  /// OperationTitleService.retitleOperation() call that same emission
  /// triggers — at which point it's cleared as redundant.
  OperationTitleFragments? _pendingTitleFragments;

  bool _sameTitleFragments(OperationTitleFragments a, OperationTitleFragments b) =>
      a.title == b.title && a.forText == b.forText && a.atText == b.atText && a.subtitle == b.subtitle;

  /// Re-suggests the header title for the sheet's buffered draft. Fire-and-
  /// forget, like the saved-row retitle — the title is a display enhancement,
  /// so a failed or superseded run just leaves the previous one showing.
  Future<void> _retitleDraft(Operation draft) async {
    final generation = ++_draftTitleGeneration;
    final fragments = await widget.services.operationTitles.suggestFragments(draft);
    if (!mounted || fragments == null || generation != _draftTitleGeneration) return;
    setState(() => _draftTitleFragments = fragments);
  }

  Stream<List<Qso>> _qsosStream() {
    if (_qsoStream == null || _qsoStreamIncludesDeleted != _showDeletedQSOs) {
      _qsoStream = widget.services.qsos.watchForOperation(widget.operationUuid, includeDeleted: _showDeletedQSOs);
      _qsoStreamIncludesDeleted = _showDeletedQSOs;
    }
    return _qsoStream!;
  }

  /// The operation row, kept live by [OperationsRepository.watchOperation]
  /// rather than manually re-fetched after every mutating action.
  StreamSubscription<Operation?>? _operationSub;

  /// Drives live rescoring: any scoring-relevant QSO change reschedules a
  /// debounced rescore. See [_onQsosChanged].
  StreamSubscription<List<Qso>>? _rescoreSub;
  Timer? _rescoreDebounce;
  List<Qso> _latestQsos = const [];

  /// The QSO-set fingerprint the last completed rescore was computed from —
  /// deliberately built from `updatedAtMillis` (stamped on every real edit,
  /// Milestone A) and NOT `scoreCache`, so a rescore's own `score_cache`
  /// write re-emits the QSO stream with an unchanged fingerprint and can't
  /// trigger itself. Null until a rescore has actually run with the
  /// extension runtime available.
  String? _lastScoredFingerprint;

  bool _sideInitStarted = false;

  /// Whether [OperationView.openActivities] has fired — the operation stream
  /// re-emits on every change, and the pane must only auto-open once.
  bool _openedActivities = false;

  /// Whether THIS view has already auto-opened the sheet for the
  /// 'operation-sheet' onboarding flow — same one-shot guard as
  /// [_openedActivities], for the same reason: the operation stream re-emits
  /// on every change. Independent of [_openedActivities]: this fires for
  /// ANY operation, new or existing, the first time ever for this user;
  /// that one only fires for a freshly created operation.
  bool _openedOperationSheetOnboarding = false;

  /// Explicit (not `DefaultTabController`) so `_suggestQso` can switch to
  /// the QSOs tab programmatically — this is its only use in the app.
  /// Because of this, the `Scaffold` below is NOT wrapped in a
  /// `DefaultTabController` — `TabBar`/`TabBarView` are given this
  /// controller directly. `DefaultTabController` always creates its own
  /// internal controller, so it can't be combined with an externally-owned
  /// one without the two drifting out of sync. If a future descendant widget
  /// calls `DefaultTabController.of(context)` here, it will throw (no
  /// ancestor found) — reach for `_tabController` directly instead, or
  /// thread it down explicitly.
  TabController? _tabController;

  /// Both layouts always show exactly 3 tabs — one primary tab (QSOs
  /// narrow / Info wide) plus Spots and Map — which is why the call site
  /// below can't just pass `tabs.length`: it has to run before `tabs` is
  /// built (see that call site's own comment). Keep this in sync if a tab
  /// is ever added to or removed from either layout's list.
  static const int _kTabCount = 3;

  /// Spots is the middle tab in both arrangements — QSOs/Info, Spots, Map.
  /// Keep this in sync alongside [_kTabCount] if either list is reordered: it
  /// decides whether the Spots pane thinks it is on screen, and pointing it at
  /// the wrong tab means the hidden panel scrolls and the visible one doesn't.
  static const int _kSpotsTabIndex = 1;

  /// Whether the Spots TAB is the selected one, for [SpotsPanel.visible].
  /// Only half the answer — in the dock arrangement the pane's own
  /// `DockPaneVisibility` is the other half, and the panel ANDs the two. This
  /// side is a notifier rather than a prop because the tab controller notifies
  /// on every frame of the tab-change animation, and nothing else in this view
  /// rebuilds on a tab change.
  final _spotsVisible = ValueNotifier(false);

  /// Re-reads that, from [_wasTwoPane] rather than a fresh `ShirtSize.of` so
  /// it can also run from the tab controller's listener — reading an inherited
  /// widget outside build would register a dependency there. Safe to call from
  /// build: `SpotsPanel` answers it without a setState of its own.
  ///
  /// The dock arrangement has no tab strip of its own here, so this side is
  /// unconditionally true there and `DockPaneVisibility` decides alone.
  void _syncSpotsVisibility() {
    _spotsVisible.value =
        (_wasTwoPane == true && _customLayout) || _tabController?.index == _kSpotsTabIndex;
  }

  void _updateTabControllerIfNeeded(int requiredLength) {
    if (_tabController == null || _tabController!.length != requiredLength) {
      final oldIndex = _tabController?.index ?? 0;
      final previous = _tabController;
      _tabController = TabController(
        length: requiredLength,
        vsync: this,
        initialIndex: oldIndex.clamp(0, requiredLength - 1),
      )..addListener(_syncSpotsVisibility);
      // Disposed after the frame, not here: this runs DURING build, and the
      // TabBar/TabBarView still holding the old controller are only rebuilt
      // with the new one later in the same frame — disposing it inline makes
      // them touch a dead controller.
      if (previous != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
      }
    }
  }

  /// A QSON-shaped `{their: {call}, freq?, band?, mode?, refs?}` map handed
  /// from the Spots tab (tapping a spot — see `SpotsPanel.onSuggestQso`) to
  /// prefill the Logging tab's fields. Not cleared after being applied —
  /// `LoggingControls` only re-applies a suggestion when this becomes a NEW
  /// map instance (see its `suggestedQso` doc comment), so a stale
  /// reference here is harmless.
  Map<String, dynamic>? _suggestedQso;

  /// The current call-info, pushed up from LoggingControls — shown
  /// as the Call Info detail on the Info tab (wide) or a modal (narrow) — the
  /// producer (LoggingPanel) and the display (InformationPanel) are sibling
  /// panes.
  CallInfoData? _callInfo;

  /// Keep the pane subtrees' State alive when the layout flips between the
  /// narrow tab arrangement and the wide split (docs/design/layouts.md rule
  /// 2): Flutter reparents a GlobalKey'd subtree instead of rebuilding it,
  /// so a half-typed callsign survives a window resize across the S/L
  /// boundary. Both arrangements come from the one build below — the keys
  /// are never mounted twice in a frame (rule 3).
  ///
  /// Adoption only happens for subtrees BUILT in the new arrangement's
  /// first frame: the logging pane always is (always-visible in wide;
  /// didChangeDependencies snaps to its tab going narrow), and so is the
  /// selected right-side tab. A visited-but-unselected Spots/Map pane lives
  /// in the TabBarView's keep-alive bucket, which doesn't carry across the
  /// flip — those reset. Known limitation, preferable to the alternatives
  /// (transferring the bucket wholesale defers the page warp past the
  /// frame, which would dispose the logging pane instead).
  final _loggingKey = GlobalKey();
  final _spotsKey = GlobalKey();
  final _mapKey = GlobalKey();

  /// The header's dots-and-title control — measured (not computed from
  /// theme constants) to left-align the operation sheet with it, since
  /// AppBar's actual leading width when `leadingWidth` is null varies by
  /// platform in ways not worth re-deriving here.
  final _headerTitleKey = GlobalKey();

  /// The control's current on-screen left edge, or null before its first
  /// layout (falls back to [showTopModalPane]'s default centering).
  double? get _headerTitleLeftInset {
    final box = _headerTitleKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return null;
    return box.localToGlobal(Offset.zero).dx;
  }

  /// Tracks the arrangement across dependency changes so the flip can be
  /// detected BEFORE build (see didChangeDependencies). Null until first
  /// resolved.
  bool? _wasTwoPane;

  void _suggestQso(Map<String, dynamic> qso) {
    setState(() => _suggestedQso = zeroBeatSuggestionFor(qso, services: widget.services, offsetter: _zeroBeat));
    // On two-pane layouts the logging pane is already visible on the left —
    // and tab 0 is Info there, so switching would be wrong twice over. In
    // dock mode the user may have tabbed the logging pane behind others, so
    // surface it (no-op when it's already visible).
    if (!ShirtSize.of(context).isTwoPane) {
      _tabController?.animateTo(0);
    } else if (_customLayout) {
      _dockKey.currentState?.revealModule('logging');
    }
  }

  /// This view's zero-beat draw cache — per view, because it is keyed by spot
  /// and only meaningful for the spots this operation is working. The rule it
  /// feeds is [zeroBeatSuggestionFor].
  final _zeroBeat = ZeroBeatOffsetter();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _registerNativePanels();
    final isTwoPane = ShirtSize.of(context).isTwoPane;
    // Flipping to narrow, land on the QSOs tab: the logging pane was the
    // always-visible left pane, so it's the natural continuation — and it
    // MUST be the selected tab for its GlobalKey'd subtree to be built (and
    // its State adopted) in the narrow TabBarView's first frame; on any
    // other index, page 0 wouldn't be inflated and the in-progress QSO
    // entry would be disposed.
    if (_wasTwoPane == true && !isTwoPane) _tabController?.index = 0;
    // Narrowing takes the dock away, and with it the header's edit controls
    // — as far as the operator can see, the edit is over. The DRAFT stays
    // (widening returns to it), but the focus edit mode took has to come
    // back, or they meet a normal-looking logging view that swallows every
    // keystroke. Kept, not consumed: the eventual Save or discard hands it
    // back again if the operator widens and finishes there.
    if (_wasTwoPane == true && !isTwoPane && _layoutEditing) _restoreFocusAfterEditing(keep: true);
    _wasTwoPane = isTwoPane;
  }

  void _onSettingsChanged() {
    final s = widget.services.settings;
    final enabled = s.layoutCustomization;
    // Turning customization off mid-edit takes the dock away, and with it
    // every control that could have finished the edit. Discard first, so the
    // draft goes back to what was saved rather than becoming the arrangement
    // that reappears when they turn it on again.
    if (!enabled && _layoutEditing) _revertLayout();
    // Local mirrors of the logging panel's own toggles (see
    // _buildLoggingSettingsButton) — flipped from the settings dialog,
    // so this is the only place they follow SettingsService.
    final changed = enabled != _customLayout ||
        s.showRSTFields != _showRSTFields ||
        s.showStateField != _showStateField ||
        s.showGridField != _showGridField ||
        s.showDeletedQSOs != _showDeletedQSOs ||
        s.showQsoNumbers != _showQsoNumbers ||
        s.defaultReport != _defaultReport ||
        s.defaultReportCW != _defaultReportCW ||
        s.defaultReportFT8 != _defaultReportFT8 ||
        s.switchSentRcvd != _switchSentRcvd ||
        s.jumpAfterRST != _jumpAfterRST;
    if (changed && mounted) {
      setState(() {
        _customLayout = enabled;
        _showRSTFields = s.showRSTFields;
        _showStateField = s.showStateField;
        _showGridField = s.showGridField;
        _showDeletedQSOs = s.showDeletedQSOs;
        _showQsoNumbers = s.showQsoNumbers;
        _defaultReport = s.defaultReport;
        _defaultReportCW = s.defaultReportCW;
        _defaultReportFT8 = s.defaultReportFT8;
        _switchSentRcvd = s.switchSentRcvd;
        _jumpAfterRST = s.jumpAfterRST;
      });
    }
  }

  /// One per screen instance — see [PanelUseTracker].
  late final _panels = PanelUseTracker(track: widget.services.track, screen: 'operation');

  @override
  void initState() {
    super.initState();
    widget.services.track('screen_viewed', {'screen': 'operation'});
    widget.services.settings.addListener(_onSettingsChanged);
    _operationSub = widget.services.operations.watchOperation(widget.operationUuid).listen(_onOperationChanged);
    // Non-deleted, non-event set — the same QSOs the scorer sees. A
    // soft-delete/undelete changes this set (and each QSO's updatedAtMillis),
    // so the fingerprint below still moves.
    _rescoreSub = widget.services.qsos.watchForOperation(widget.operationUuid).listen(_onQsosChanged);
    // Feed the dev bridge (window.__halo.getState) the current operation +
    // compose state while this screen is active — only when the bridge was
    // actually installed (dev/preview build on web), so nothing runs in
    // production or on native.
    if (DevBridge.instance.installed) DevBridge.instance.stateProvider = _devBridgeState;
    // Claims this view's slot on the ⌘K command-context stack. Held by
    // identity so popping back from a nested operation reveals this one again
    // rather than leaving the palette context-less — see
    // HaLoServices.openOperationContext.
    _commandContext = widget.services.openOperationContext(widget.operationUuid);
    // Keeps spots flowing for as long as an operation is open, not just
    // while the Spots Panel is on screen: the `spot-history` lookup reads
    // that cache to pull a hunted park/summit into the QSO as the callsign
    // is typed, which has to work from the logging panel alone. Refcounted,
    // so closing every operation stops the fetching.
    _unsubscribeSpots = widget.services.spots.subscribe();
    widget.services.spots.addListener(_onSpotsChanged);
    widget.services.panels.addListener(_onPanelCatalogChanged);
    // Extensions are asked for their panels once per view, not once per
    // build: the runtime restarts when an extension is enabled or disabled,
    // and this view is rebuilt from scratch either way.
    unawaited(widget.services.panels.refreshExtensionPanels());
  }

  /// The catalog changed — an extension enabled, disabled, or its runtime
  /// restarted. Nothing is reconciled against it: a module the catalog
  /// cannot explain keeps its pane and renders as a placeholder, so a panel
  /// that is only *temporarily* missing repairs itself here, and one that is
  /// really gone waits for the operator to remove it from Layout Setup.
  /// Rebuilding is the whole response.
  void _onPanelCatalogChanged() {
    if (!mounted) return;
    setState(() {});
    // An open Layout Setup is listing this.
    _bumpSheet();
  }

  /// Releases this view's spot-cache subscription (see initState).
  VoidCallback? _unsubscribeSpots;

  /// Tab labels panels supplied for themselves, by panel id — what tells two
  /// placements of one panel apart ("Antenna notes" and "Sked list", not
  /// "Custom Text" twice). A panel that supplies none is simply absent here
  /// and keeps its descriptor's title.
  final _panelTitles = <String, String>{};

  /// What dropping a pane means, in one place so the remove control and
  /// Restore Defaults cannot disagree: the label goes, and so does whatever the
  /// operator typed into it.
  ///
  /// Only an INSTANCE forgets its config — see
  /// [PanelService.forgetInstanceConfig], which draws that line. Fire and
  /// forget: nothing here should wait on storage, and a config outliving its
  /// pane costs a stale value rather than a broken layout.
  void _forgetPanes(Iterable<String> ids) {
    // Held back while editing — a removal that revert can undo must not have
    // destroyed anything in the meantime. See [_pendingForgets].
    if (_layoutEditing) {
      _pendingForgets.addAll(ids);
      return;
    }
    _forgetPanesNow(ids);
  }

  /// The forget itself, for the two callers that have already decided it is
  /// due: [_saveLayout], and [_revertLayout] for panes the revert is dropping
  /// (added during the edit, so nothing outside it ever knew them).
  void _forgetPanesNow(Iterable<String> ids) {
    for (final id in ids.toList()) {
      _panelTitles.remove(id);
      // Its layout options go with it — they describe a place in the
      // arrangement, and that place is gone.
      _paneOptions.remove(id);
      unawaited(widget.services.panels.forgetInstanceConfig(id));
    }
  }

  void _onPanelTitle(String id, String? title) {
    // A panel is free to return the same title on every render, so dropping
    // the repeat is this side's job — otherwise every render of every titled
    // panel would rebuild the whole view.
    if (title == null ? !_panelTitles.containsKey(id) : _panelTitles[id] == title) return;
    setState(() {
      if (title == null) {
        _panelTitles.remove(id);
      } else {
        _panelTitles[id] = title;
      }
    });
  }

  /// Counts spot refreshes rather than carrying the spots themselves: it
  /// exists only to fire an extension panel's `spots` trigger, and the
  /// panels that care read the cache themselves.
  int _spotsRevision = 0;

  /// Whether a panel in the CURRENT arrangement declared [trigger]. Every
  /// signal an extension panel can be woken by costs this view something to
  /// produce — a rebuild on a timer, or a QSO draft rebuilt per keystroke —
  /// so each one is gated on somebody actually having asked for it. A layout
  /// that can't hold an extension panel at all never gets past the first
  /// line.
  /// Reads the EFFECTIVE triggers, so a signal only one placement asked for
  /// in its last render — an operator's template naming the callsign being
  /// typed — starts being produced. `PanelService` notifies when that set
  /// changes, and [_onPanelCatalogChanged] rebuilds, which is what makes the
  /// new answer take effect. The first render of such a template necessarily
  /// happens before it: the panel is answered with no draft, then woken by
  /// the next change to one.
  bool _anyPanelWants(String trigger) {
    if (!_customLayout) return false;
    return _dockSpec?.collectModules().any((id) => widget.services.panels.triggersFor(id).contains(trigger)) ?? false;
  }

  void _onSpotsChanged() {
    // Every other operation view would be rebuilding itself on a two-minute
    // timer for nothing.
    if (!mounted || !_anyPanelWants('spots')) return;
    setState(() => _spotsRevision++);
  }

  /// The QSO being composed, republished from the logging panel for panels
  /// declaring `qso`. Null until one of them is in the arrangement — the
  /// render args then leave `qso` out entirely rather than sending `{}`.
  /// Once one is, this carries the draft even with an empty call: the band
  /// and mode come from the radio, and are worth showing before anything is
  /// typed.
  Map<String, dynamic>? _draftQso;
  Timer? _draftQsoDebounce;

  /// Coalesces the keystroke burst of typing a callsign into one rebuild.
  ///
  /// The panel's own [panelRenderThrottle] already bounds how often it may
  /// cross the bridge, but that is downstream of this view's setState — and
  /// the setState is the expensive half, rebuilding the logging, spots and
  /// map panes alongside the panel that asked. Debounced on the same window,
  /// so a panel sees one draft per pause rather than one per letter.
  void _onQsoDraftChanged(Map<String, dynamic> qso) {
    _draftQsoDebounce?.cancel();
    // The FIRST draft, carrying a call that resolved before anyone asked for
    // it — a `lookup` panel added to the layout while a callsign is already
    // in the field. Its `lookup` already fired against no draft at all, and
    // `_lookupAnsweredFor` holds that call, so nothing would fire again
    // until a DIFFERENT callsign resolved: the panel would sit on call-less
    // content indefinitely.
    if (_draftQso == null && (qso['their'] as Map?)?['guess'] != null) _flushDraft = true;
    if (_flushDraft) {
      // A lookup just resolved, and the guess it resolved to lives inside
      // this draft. Both are pushed from one post-frame callback — call-info
      // first, draft second — so waiting out the debounce here would fire
      // `lookup` against the draft from BEFORE the answer, and a panel
      // declaring only `lookup` would never see a later one.
      _flushDraft = false;
      setState(() {
        _draftQso = qso;
        // So a panel woken by `lookup` is woken for THIS draft. Without it
        // the first draft arrives as a `qso` change, which a lookup-only
        // panel does not listen for.
        _lookupRevision++;
      });
      return;
    }
    _draftQsoDebounce = Timer(panelRenderThrottle, () {
      if (!mounted) return;
      setState(() => _draftQso = qso);
    });
  }

  /// Set when a lookup resolves, so the draft carrying its guess skips the
  /// debounce. Cleared by the next draft either way — a lookup that changes
  /// nothing about the draft must not leave the next keystroke unbuffered.
  bool _flushDraft = false;

  /// Bumped when a callsign RESOLVES, so `lookup` is a trigger about lookups
  /// rather than a second, slower `qso`. Carries no value into the render
  /// args: the resolved guess already travels inside the draft QSO.
  int _lookupRevision = 0;

  /// The call the current guess answers for — null while nothing has
  /// resolved. Cleared that way on every keystroke that drops the guess, so
  /// retyping the same call resolves afresh.
  String? _lookupAnsweredFor;

  /// This view's entry on the command-context stack.
  late final OperationCommandContext _commandContext;

  /// The snapshot `window.__halo.getState()` returns while an operation is open:
  /// the operation, the callsign being composed/edited and its lookup guess,
  /// and the current VFO. Kept JSON-able (maps/strings/nums) so it js-ifies.
  Map<String, dynamic> _devBridgeState() {
    final op = _operation;
    final info = _callInfo;
    return {
      'view': 'operation',
      'operation': op == null
          ? null
          : {'uuid': op.uuid, 'stationCall': op.stationCall, 'title': op.title, 'qsoCount': op.qsoCount},
      'call': info?.call,
      'editing': info?.isEditing ?? false,
      'guess': info?.guess,
      'vfo': widget.services.radio.vfoA.toJson(),
    };
  }

  @override
  void dispose() {
    widget.services.settings.removeListener(_onSettingsChanged);
    // Only clear if it's still ours — a newer OperationView may have taken over.
    if (DevBridge.instance.stateProvider == _devBridgeState) {
      DevBridge.instance.stateProvider = null;
    }
    _operationSub?.cancel();
    _rescoreSub?.cancel();
    _rescoreDebounce?.cancel();
    _draftQsoDebounce?.cancel();
    _tabController?.dispose();
    _spotsVisible.dispose();
    widget.services.closeOperationContext(_commandContext);
    _unsubscribeSpots?.call();
    widget.services.spots.removeListener(_onSpotsChanged);
    widget.services.panels.removeListener(_onPanelCatalogChanged);
    super.dispose();
  }

  /// Publishes this view's operation into its stack entry, so the ⌘K dialog's
  /// operation-scoped commands (SEED, NOTE, SPOT) have something to run
  /// against. Same map shape `logging_controls.dart` passes its own
  /// `interpretCommand` calls.
  void _setCommandContext(Operation? operation) {
    _commandContext.operation =
        operation == null ? null : {...operation.data, 'uuid': operation.uuid};
  }

  void _onOperationChanged(Operation? operation) {
    if (!mounted) return;
    final previous = _operation;
    var patched = operation;
    final pending = _pendingTitleFragments;
    if (patched != null && pending != null) {
      if (_sameTitleFragments(patched.titleFragments, pending)) {
        // The row's own cache has caught up (retitleOperation's write from
        // a PRIOR emission landed) — stop overriding, it's redundant now.
        _pendingTitleFragments = null;
      } else {
        patched = _withTitleSuggestion(patched, pending);
      }
    }
    setState(() => _operation = patched);
    _setCommandContext(patched);
    if (operation == null) return;

    // With no profile callsign yet (fresh install — no onboarding flow
    // exists), the callsign editor takes the Activities pane's place:
    // setting an identity comes first.
    if (widget.openActivities && !_openedActivities) {
      _openedActivities = true;
      // Also consumes the independent trigger below for THIS view: a new
      // operation is this view's to handle end to end, including the
      // case where operatorCall is still empty and only
      // the callsign prompt shows, never the sheet — that must stay exactly
      // as it is, not get a second, onboarding-driven attempt to reopen
      // something on a later re-emission of the operation stream.
      _openedOperationSheetOnboarding = true;
      final markOnboardingSeen =
          widget.services.settings.onboardingShownCount(OnboardingFlows.operationSheet) == 0;
      _afterPushTransition(() => _openActivitiesOrPromptForCallsign(operation, markOnboardingSeen: markOnboardingSeen));
    } else if (!_openedOperationSheetOnboarding &&
        widget.services.settings.onboardingShownCount(OnboardingFlows.operationSheet) == 0) {
      // Independent of the new-operation auto-open above: the
      // FIRST operation this user ever opens — new or existing — shows the
      // sheet once, so it isn't a surprise the first time they go looking
      // for it on an operation that predates the sheet.
      _openedOperationSheetOnboarding = true;
      _afterPushTransition(() => _openActivitiesOrPromptForCallsign(operation, markOnboardingSeen: true));
    }

    if (!_sideInitStarted) {
      _sideInitStarted = true;
      unawaited(_initExtensionState(operation));
    } else {
      // Re-derive the extension-fed side state only when its input actually
      // changed — not on every counter/localData emission (a QSO add, a
      // rescore) — so this stays cheap.
      if (previous?.stationCall != operation.stationCall) {
        unawaited(_resolveOurEntityPrefix(operation));
      }
      if (previous == null || !_sameRefs(previous.data['refs'], operation.data['refs'])) {
        unawaited(_refreshLoggingControls(operation));
        // Refs are what suggestOperationTitle reads
        // — no debounce needed, refs only change on a deliberate edit, unlike
        // the QSO list's rescore trigger below.
        unawaited(widget.services.operationTitles.retitleOperation(operation));
      }
    }
  }

  /// Runs [action] once this view's push transition has settled. The pane
  /// showModalPane opens sizes itself against this view, so it must not go up
  /// before the view is laid out — and pushing it mid-transition races the
  /// teardown of the screen we were pushed over.
  void _afterPushTransition(VoidCallback action) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final animation = ModalRoute.of(context)?.animation;
      if (animation == null || animation.status == AnimationStatus.completed) {
        action();
        return;
      }
      void onStatus(AnimationStatus status) {
        if (status != AnimationStatus.completed) return;
        animation.removeStatusListener(onStatus);
        if (mounted) action();
      }

      animation.addStatusListener(onStatus);
    });
  }

  bool _sameRefs(Object? a, Object? b) => jsonEncode(a) == jsonEncode(b);

  /// One-time, extension-runtime-dependent setup: the runtime may still be
  /// booting when the operation first arrives, so this awaits it, then does
  /// the initial controls/entity-prefix resolve and kicks the first rescore.
  Future<void> _initExtensionState(Operation operation) async {
    await widget.services.extensions.start();
    if (!mounted) return;
    await _refreshLoggingControls(operation);
    await _resolveOurEntityPrefix(operation);
    // `_operation`, not the `operation` parameter: extension-runtime boot
    // (the await above) can take long enough for the user to edit refs
    // before it resolves, and the ref-changed branch below would then have
    // already cached the correct, fresher suggestion — retitling from this
    // stale closed-over snapshot would silently overwrite it with the old
    // one (there's no ordering guard on the cache
    // write to catch this, unlike the fingerprinted rescore below).
    unawaited(widget.services.operationTitles.retitleOperation(_operation ?? operation));
    // The extension runtime is ready now; a rescore scheduled before it was
    // (which no-op'd) never recorded a fingerprint, so this re-attempts it.
    _maybeScheduleRescore();
  }

  Future<void> _refreshLoggingControls(Operation operation) async {
    final result = await widget.services.extensions.loggingControls(operation.data);
    if (!mounted) return;
    // A fetch that failed says nothing about what the activities want, so the
    // panel keeps what it is already showing rather than blanking a live
    // logging panel because the runtime happened to be restarting.
    //
    // But the only thing that re-runs this is a REF CHANGE, so a failure here
    // is always a set that no longer matches the operation — the contest just
    // added has no exchange field, the POTA ref just removed still has one —
    // and nothing corrects it until the operation is reopened. Keeping it
    // quiet would leave the operator staring at the wrong fields with no
    // account of why, which is the whole defect this change exists to end.
    if (result.loadFailed) {
      widget.services.statusBar.setMessage(
        key: 'operation:logging-controls-stale',
        text: context.t.operation.loggingControlsStale,
      );
      if (_loggingControls.isNotEmpty) return;
    } else {
      widget.services.statusBar.clear('operation:logging-controls-stale');
    }
    setState(() => _loggingControls = result.controls);
  }

  void _onQsosChanged(List<Qso> qsos) {
    _latestQsos = qsos;
    _maybeScheduleRescore();
  }

  /// Debounced live rescore (DESIGN.md §11's per-edit TODO). Fires only when
  /// the fingerprint moves, and records it only once a rescore actually runs
  /// with a host — so an edit that arrives while the runtime is still booting
  /// isn't silently marked scored. The score-cache/localData writes a rescore
  /// makes flow back to the UI through the QSO and operation streams; neither
  /// perturbs the fingerprint, so there's no feedback loop.
  void _maybeScheduleRescore() {
    final fingerprint = _fingerprintFor(_latestQsos);
    if (fingerprint == _lastScoredFingerprint) return;
    _rescoreDebounce?.cancel();
    _rescoreDebounce = Timer(const Duration(milliseconds: 750), () async {
      final operation = _operation;
      if (operation == null || widget.services.extensions.host == null) {
        return; // not ready — retried on the next change
      }
      _lastScoredFingerprint = fingerprint;
      await widget.services.scoring.rescoreOperation(operation);
    });
  }

  String _fingerprintFor(List<Qso> qsos) => qsos.map((q) => '${q.uuid}:${q.updatedAtMillis ?? ''}').join(',');

  /// A cheap "has the log changed?" signal for the Spots Panel, which scores
  /// its spots against the log. Count alone would miss an edit, and
  /// [_fingerprintFor] is far too heavy to build on every rebuild of a long
  /// log — `updatedAtMillis` only moves forward, so its maximum plus the count
  /// catches an insert, a delete and an edit alike.
  String _logRevisionFor(List<Qso> qsos) {
    var latest = 0;
    for (final qso in qsos) {
      final at = qso.updatedAtMillis ?? 0;
      if (at > latest) latest = at;
    }
    return '${qsos.length}:$latest';
  }

  /// The same Callsign field as Settings → Callsign, offered when a new
  /// operation was started with no profile callsign: the save lands in the
  /// profile (like the settings panel) AND on this operation, which was
  /// created before the callsign existed. Cancelling leaves both unset —
  /// the operation's own settings can fix it later.
  Future<void> _promptForCallsign(Operation operation) async {
    final result = await editOneFieldDialog(
      context,
      title: context.t.common.callsign,
      fieldLabel: context.t.common.callsign,
      fieldInitial: '',
      fieldCapitalization: TextCapitalization.characters,
    );
    if (result == null || result.trim().isEmpty) return;
    // Operation first: it's the local, can't-fail write. setOperatorCall
    // also pushes sync credentials (keychain + extension bridge), and a
    // failure there must not leave the operation callsign-less.
    await widget.services.operations.saveData(
      Operation(
        uuid: operation.uuid,
        data: {...operation.data, 'stationCall': result.trim().toUpperCase()},
        qsoCount: operation.qsoCount,
        startAtMillisMin: operation.startAtMillisMin,
        startAtMillisMax: operation.startAtMillisMax,
        localData: operation.localData,
      ),
    );
    await widget.services.setOperatorCall(result);
  }

  /// Tap on the compact call-info area: on wide layouts the detail
  /// already lives on the Info tab, so just surface it; on narrow, open it as a
  /// modal (which re-reads the latest `_callInfo` on rebuild via the modal's
  /// own key, so live updates flow through while it's open).
  Future<void> _handleCallInfoTap(Operation operation) async {
    if (ShirtSize.of(context).isTwoPane) {
      if (_customLayout) {
        _dockKey.currentState?.revealModule('info');
      } else if (_tabController?.index != 0) {
        _tabController?.animateTo(0);
      }
      return;
    }
    final info = _callInfo;
    if (info == null) return;
    await showModalPane<void>(
      context,
      title: info.call,
      closeLabel: context.t.common.close,
      builder: (_) => CallInfoPanel(
        operation: operation,
        services: widget.services,
        call: info.call,
        guess: info.guess,
        lookups: info.lookups,
        alertKeys: info.alertKeys,
        noticeKeys: info.noticeKeys,
        ourEntityPrefix: _ourEntityPrefix,
      ),
    );
  }

  Future<void> _editActivities(Operation operation) => _openOperationSheet(operation);

  /// Opens the operation sheet, or — if the profile still has no operator
  /// callsign (fresh install, no onboarding flow existed for it before) —
  /// the callsign prompt in its place. [markOnboardingSeen] records the
  /// 'operation-sheet' onboarding flow as shown, but only once the sheet
  /// ITSELF actually opens: the callsign prompt isn't the sheet, so hitting
  /// that branch must not count as having seen it.
  void _openActivitiesOrPromptForCallsign(Operation operation, {required bool markOnboardingSeen}) {
    // The screen we were pushed over can still hold focus while its
    // subtree goes away; leaving it focused lets the engine move DOM
    // focus through a Focus node that is already inactive (web).
    FocusManager.instance.primaryFocus?.unfocus();
    if (widget.services.settings.activeProfile.operatorCall.isEmpty) {
      _promptForCallsign(operation);
    } else {
      if (markOnboardingSeen) {
        unawaited(widget.services.settings.recordOnboardingShown(OnboardingFlows.operationSheet));
      }
      _editActivities(operation);
    }
  }

  Animation<double>? _sheetAnimation;
  VoidCallback? _sheetAnimationListener;
  GlobalKey<OperationSheetState>? _activeSheetKey;

  Future<void> _openOperationSheet(Operation operation) async {
    // No manual re-fetch on pop: watchOperation streams the change back.
    // Non-scrollable: the pane's accordion sections divide its height
    // themselves (see activities_view.dart). Not barrier/Escape-dismissible:
    // as a pushed screen this had explicit-back dismissal only, and Escape
    // while typing in the suggestions search would close the whole pane.
    final sheetKey = GlobalKey<OperationSheetState>();
    if (!mounted) return;
    setState(() {
      _draftOperation = operation;
      _activeSheetKey = sheetKey;
    });

    try {
      await showTopModalPane<void>(
        context,
        onAnimation: (anim) {
          _sheetAnimationListener?.call();
          _sheetAnimation = anim;
          void animListener() {
            if (mounted) setState(() {});
          }
          // Navigator.push()'s Future (what `await showTopModalPane` below
          // is waiting on) completes the instant saveAndClose()/revert-
          // AndClose() calls pop() — well before the route's reverse
          // transition actually finishes playing. If this listener were
          // torn down in that `finally` block instead, _sheetAnimation
          // would go null immediately, snapping the header's dots
          // control straight to "closed" while the sheet itself keeps
          // sliding away for the rest of its 600ms. So this detaches
          // itself only once the animation genuinely reaches
          // AnimationStatus.dismissed, keeping the header in sync with
          // the pane for the whole reverse transition; the `identical`
          // check guards against a late-firing dismissal from a PREVIOUS
          // sheet clobbering a new one that's already open.
          void statusListener(AnimationStatus status) {
            if (status != AnimationStatus.dismissed) return;
            anim.removeListener(animListener);
            anim.removeStatusListener(statusListener);
            if (mounted && identical(_sheetAnimation, anim)) {
              setState(() => _sheetAnimation = null);
            }
          }
          anim.addListener(animListener);
          anim.addStatusListener(statusListener);
          _sheetAnimationListener = () {
            anim.removeListener(animListener);
            anim.removeStatusListener(statusListener);
          };
        },
        closeLabel: context.t.common.close,
        // Left-aligned with the dots-and-title control that opens it,
        // rather than centered in the pane.
        leftInset: _headerTitleLeftInset,
        scrollable: false,
        barrierDismissible: true,
        onDismiss: () => sheetKey.currentState?.saveAndClose(),
        // The sheet's own accept button — the header's top dot visually
        // hands off to it as the sheet slides down (see _HeaderDotsControl).
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(MdiIcons.check, semanticLabel: context.t.common.save),
            style: IconButton.styleFrom(
              backgroundColor: fabAccentColor,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            onPressed: () => sheetKey.currentState?.saveAndClose(),
          ),
        ),
        // The title and the Options/Exports controls share ONE slot — see
        // _OperationSheetHeader. The operation's own identity travels with its
        // activities instead (activities_view.dart's _operationPills).
        title: _OperationSheetHeader(
          onOptions: () => sheetKey.currentState?.showOptions(),
          onExport: () => _export(_draftOperation ?? operation),
          dimExport: operation.qsoCount == 0,
        ),
        // Explicitly empty rather than absent: an absent trailing gets the
        // pane's default close button, and this sheet closes through its own
        // leading accept button.
        trailing: const SizedBox.shrink(),
        builder: (_) => OperationSheet(
          key: sheetKey,
          services: widget.services,
          operation: operation,
          onOperationChanged: (updated) {
            if (!mounted) return;
            final previous = _draftOperation;
            setState(() => _draftOperation = updated);
            // Refs are the only input the title is built from, so nothing
            // else in the draft is worth a hook fan-out.
            if (previous == null || !_sameRefs(previous.data['refs'], updated.data['refs'])) {
              unawaited(_retitleDraft(updated));
            }
          },
          onEditDetails: () async {
            final updated = await editOperationDetails(
              context,
              widget.services.operations,
              _draftOperation ?? operation,
              save: false,
            );
            if (updated != null && mounted) {
              setState(() {
                _draftOperation = Operation(
                  uuid: _draftOperation!.uuid,
                  data: {
                    ..._draftOperation!.data,
                    ...updated.data,
                  },
                  qsoCount: _draftOperation!.qsoCount,
                  startAtMillisMin: _draftOperation!.startAtMillisMin,
                  startAtMillisMax: _draftOperation!.startAtMillisMax,
                  localData: _draftOperation!.localData,
                );
              });
              sheetKey.currentState?.updateOperation(_draftOperation!);
            }
          },
          onImportAdif: () => pickAndImportAdif(
            context,
            services: widget.services,
            // The SAVED operation, not the draft: an import writes QSOs
            // against a row that exists, and a draft's unsaved edits are a
            // different thing entirely.
            operation: operation,
          ),
          // Close the sheet first: both the confirmation and the pop that
          // follows it belong to this screen, not to the pane stacked over
          // it — and the draft's unsaved edits are moot once it's deleted.
          onDelete: () => confirmDeleteOperation(context, widget.services, _draftOperation ?? operation).then(
            (deleted) {
              if (deleted && mounted) {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              }
            },
          ),
        ),
      );
    } finally {
      // _sheetAnimation/_sheetAnimationListener are NOT reset here — this
      // `finally` runs as soon as Navigator.push() resolves, which is at
      // pop() time, well before the route's reverse transition actually
      // finishes. The status listener attached in onAnimation above cleans
      // both up itself once the animation truly reaches
      // AnimationStatus.dismissed (with a defensive re-detach at the top of
      // the next onAnimation call, in case a sheet reopens before that
      // fires).
      if (mounted) {
        setState(() {
          _activeSheetKey = null;
          // Carry the draft's final (just-saved — see saveAndClose(), the
          // only path that reaches here today) values into _operation
          // BEFORE dropping the draft, rather than leaving the header to
          // fall back on _operation as it stood before this edit session
          // and wait for watchOperation's stream to catch up. That gap
          // would show a flicker of stale values in the header for a
          // frame or two while the sheet was still closing. If a live
          // title-preview was showing (refs edited during this session),
          // bake ITS suggestion into the carried-forward operation too —
          // otherwise the draft's own titleSuggestion cache is still the
          // PRE-edit one (only the ephemeral preview knew about the new
          // refs), so dropping _draftTitleFragments in the same breath
          // would swap the correct preview for that stale cached title.
          // The fragments also live on as _pendingTitleFragments (NOT
          // cleared here) — saveAndClose() persisted the sheet's own,
          // still stale-titleSuggestion operation, so watchOperation's very
          // next emission would read that stale cache straight back over
          // this fix; _onOperationChanged keeps re-patching it in until the
          // row's real cache (retitleOperation's separate async write)
          // actually catches up.
          final draft = _draftOperation;
          final fragments = _draftTitleFragments;
          _operation = draft == null
              ? _operation
              : fragments == null
                  ? draft
                  : _withTitleSuggestion(draft, fragments);
          _pendingTitleFragments = fragments ?? _pendingTitleFragments;
          _draftOperation = null;
          _draftTitleFragments = null;
          _draftTitleGeneration++;
        });
      }
    }
  }

  Future<void> _resolveOurEntityPrefix(Operation operation) async {
    final ourInfo = await widget.services.extensions.lookupCall(
      operation.stationCall,
      qso: const {},
      operation: operation.data,
      online: false,
    );
    final ourGuess = ourInfo?['guess'] as Map<String, dynamic>?;
    if (mounted) {
      setState(() {
        _ourEntityPrefix = ourGuess?['entityPrefix'] as String?;
        _ourItuRegion = (ourGuess?['ituRegion'] as num?)?.toInt();
        _ourCountryCode = ourGuess?['countryCode'] as String?;
      });
    }
  }

  Future<void> _export(Operation operation) =>
      showOperationExportPanel(context, services: widget.services, operation: operation);

  Future<void> _handleCommandAction(String action, [Map<String, dynamic>? params]) =>
      runCommandAction(widget.services, action, params);

  /// The logging panel's own settings — field visibility, dupe/number
  /// display, a bulk lookup refresh — behind the tune icon, built from
  /// every declared setting targeting `'logging'`
  /// (settings/settings_target_dialog.dart), rather than the operation
  /// view's AppBar, since none of this applies to the Info/Spots/Map tabs.
  /// Rendered at three call sites depending on layout (the dock module
  /// header, the narrow tab bar's QSOs tab, the fixed wide split's new
  /// logging-pane title bar) — same content everywhere, so they can't
  /// drift.
  Widget _buildLoggingSettingsButton(List<Qso> qsos, {BuildContext? context}) {
    // Defaults to this State's own context, but the dock layout's
    // `tabActions` is a `WidgetBuilder` specifically so its call site can
    // pass a context at the module's real tree position instead (see
    // `_buildGroup`'s own Builder) — using the
    // wrong one is currently harmless (no nested Theme/Localizations
    // override exists anywhere in the dock tree today) but would silently
    // read the wrong ambient values the day one is added.
    final effectiveContext = context ?? this.context;
    // Every call site sits on a header-colored surface (the dock module
    // header, the tab bar riding on the AppBar's own color, the wide
    // split's new title bar) — same resolution the headers themselves use
    // for their foreground, so the icon reads against all three.
    final theme = Theme.of(effectiveContext);
    final iconColor = theme.appBarTheme.foregroundColor ?? theme.colorScheme.onPrimary;
    return Builder(
      builder: (buttonContext) => IconButton(
        // A plain IconButton doesn't supply an accessible name by default —
        // set explicitly as a semanticLabel, not a tooltip, since the app
        // shows no hover labels (docs/design/user-interface.md).
        icon: Icon(MdiIcons.tune, color: iconColor, semanticLabel: MaterialLocalizations.of(effectiveContext).showMenuTooltip),
        onPressed: () => _openLoggingSettings(buttonContext, qsos),
      ),
    );
  }

  /// The logging pane's own settings dialog, in one place so the tab button
  /// and the pane's layout options open the SAME thing. The logging panel is
  /// native and reaches its settings through a target rather than through
  /// `formFields`, so nothing else here would find it.
  Future<void> _openLoggingSettings(BuildContext buttonContext, List<Qso> qsos) {
    final effectiveContext = buttonContext;
    return showSettingsForTarget(
          buttonContext,
          services: widget.services,
          target: 'logging',
          // The logging view's own title for its own dialog — distinct from
          // LoggingSettingsGroup.title ("Logging"), which names the group as
          // it appears in All Settings/Common Preferences, a different
          // surface with a different audience.
          title: effectiveContext.t.operation.menu.loggingSettingsTitle,
          actions: [
            (
              icon: 'refresh',
              label: effectiveContext.t.operation.menu.lookupAllQsos,
              // Refreshes lookup data (QRZ, HamDB…) for the whole log via
              // the background queue — progress shows in the status bar,
              // and rows repaint as results land. The queue itself filters
              // out event markers etc. Not itself a persisted setting, so
              // it's an Actions-section item rather than a target element.
              onTap: () {
                Navigator.of(buttonContext).pop();
                widget.services.lookupQueue.enqueueAll(qsos);
              },
            ),
          ],
        );
  }

  /// The Map tab's basemap picker (see MapSettingsGroup). Same shape as
  /// [_buildLoggingSettingsButton]: the Map
  /// panel is native and reaches its settings through a target, not
  /// `formFields`, so `_buildPanelSettingsButton` wouldn't find it either.
  Widget _buildMapSettingsButton({BuildContext? context}) {
    final effectiveContext = context ?? this.context;
    final theme = Theme.of(effectiveContext);
    final iconColor = theme.appBarTheme.foregroundColor ?? theme.colorScheme.onPrimary;
    return Builder(
      builder: (buttonContext) => IconButton(
        icon: Icon(MdiIcons.tune, color: iconColor, semanticLabel: MaterialLocalizations.of(effectiveContext).showMenuTooltip),
        onPressed: () => _openMapSettings(buttonContext),
      ),
    );
  }

  Future<void> _openMapSettings(BuildContext buttonContext) => showSettingsForTarget(
        buttonContext,
        services: widget.services,
        target: 'map',
        title: buttonContext.t.operation.menu.mapSettingsTitle,
      );

  /// Floor for [_narrowTabBar]'s QSOs-tab padding — shrunk before the tab
  /// is ever allowed to grow past an even third (and, in turn, before
  /// Spots/Map are ever asked to give up any of their own share).
  static const double _kNarrowTabMinPadding = 4;

  /// The selection indicator's thickness, taken from the hand-rolled strips
  /// so all three agree. Named here because the wide `TabBar` reports its
  /// height as tab + indicator, so the tabs have to be sized against it for
  /// the strip to land on the chrome height.
  static const double _tabIndicatorWeight = TabChrome.defaultIndicatorWidth;

  /// The narrow layout's tab strip. Hand-built rather than a stock [TabBar]
  /// (which always splits its width equally across tabs): the QSOs tab
  /// carries both its label and the settings button
  /// (_buildLoggingSettingsButton), so on the narrowest phones an equal
  /// third isn't always enough room for both, and a widget nested inside a
  /// `Tab` competes with the tab bar's own tap handling for that gesture and
  /// loses, so it never receives taps either. The label stays centered
  /// across the tab's full width, same as any other tab, with the button
  /// pinned to the tab's right edge regardless — which needs room for the
  /// button on *both* sides of the centered label, not just the one it
  /// occupies, to avoid the two overlapping. Fitting that: first the tab's
  /// own horizontal padding shrinks (down to [_kNarrowTabMinPadding]); only
  /// once padding is already at that floor does the tab grow past an even
  /// third, taking space from Spots/Map. The reserved width always assumes
  /// the button is showing (not just when QSOs is selected), so the strip
  /// doesn't reflow when the selection changes.
  PreferredSizeWidget _narrowTabBar(int realQsoCount, List<Qso> qsos) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.titleSmall;
    final qsosLabel = context.t.operation.tabs.qsos(count: formatNumber(realQsoCount));
    // textWidth (not a bare TextPainter): it folds in the ambient
    // DefaultTextStyle and text scaler the same way the actual rendered
    // Text does, so this reservation doesn't under-measure under OS/browser
    // accessibility text scaling the way a raw TextPainter would.
    final qsosLabelWidth = textWidth(context, qsosLabel, (labelStyle ?? const TextStyle()).copyWith(fontWeight: FontWeight.bold));
    // The button's own width, reserved on both sides of the centered label
    // (see the doc comment above).
    final qsosContentWidth = qsosLabelWidth + LayoutDensity.chromeHeightOf(context) * 2;

    return PreferredSize(
      key: const Key('narrowTabBar'),
      preferredSize: Size.fromHeight(LayoutDensity.chromeHeightOf(context)),
      child: AnimatedBuilder(
        animation: _tabController!,
        builder: (context, child) {
          return Material(
            color: theme.appBarTheme.backgroundColor ?? theme.colorScheme.primary,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final evenShare = constraints.maxWidth / 3;
                double qsosWidth;
                double qsosPadding;
                if (qsosContentWidth + kTabLabelPadding.horizontal <= evenShare) {
                  qsosWidth = evenShare;
                  qsosPadding = kTabLabelPadding.horizontal / 2;
                } else if (qsosContentWidth + _kNarrowTabMinPadding * 2 <= evenShare) {
                  qsosWidth = evenShare;
                  qsosPadding = (evenShare - qsosContentWidth) / 2;
                } else {
                  qsosWidth = qsosContentWidth + _kNarrowTabMinPadding * 2;
                  qsosPadding = _kNarrowTabMinPadding;
                }
                return Row(
                  children: [
                    SizedBox(
                      width: qsosWidth,
                      // Row's incoming height constraint here is loose, so a
                      // shorter tab (Spots/Map, just a label) would
                      // otherwise size its Container to its own content and
                      // paint the bottom-border indicator at ITS bottom
                      // edge — above the bar's true bottom — while the
                      // taller QSOs tab (label + button) sits lower. An
                      // explicit height forces every tab's Container to the
                      // bar's full height regardless, so every indicator
                      // lands flush at the same bottom edge, same as a
                      // stock TabBar.
                      height: LayoutDensity.chromeHeightOf(context),
                      child: _narrowTab(
                        0,
                        qsosLabel,
                        labelStyle,
                        padding: EdgeInsets.symmetric(horizontal: qsosPadding),
                        trailing: _buildLoggingSettingsButton(qsos),
                      ),
                    ),
                    Expanded(
                      child: SizedBox(
                        height: LayoutDensity.chromeHeightOf(context),
                        child: _narrowTab(1, context.t.operation.tabs.spots, labelStyle),
                      ),
                    ),
                    Expanded(
                      child: SizedBox(
                        height: LayoutDensity.chromeHeightOf(context),
                        child: _narrowTab(2, context.t.operation.tabs.map, labelStyle),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _narrowTab(
    int index,
    String label,
    TextStyle? labelStyle, {
    Widget? trailing,
    EdgeInsetsGeometry padding = kTabLabelPadding,
  }) {
    final selected = _tabController!.index == index;
    return TabChrome(
      selected: selected,
      semanticLabel: label,
      padding: padding,
      onTap: () => _tabController!.animateTo(index),
      builder: (context, labelColor) {
        final text = Text(label, style: labelStyle?.copyWith(color: labelColor, fontWeight: selected ? FontWeight.bold : null));
        if (trailing == null) return Center(child: text);
        return Stack(
          alignment: Alignment.center,
          children: [
            Center(child: text),
            Align(
              alignment: Alignment.centerRight,
              // Reserved width already accounts for the button whether
              // it's showing or not (see _narrowTabBar's doc comment) —
              // AnimatedOpacity never collapses its own layout space
              // either way, so the tab doesn't reflow when the selection
              // changes. IgnorePointer keeps the faded-out button from
              // eating taps meant for the tab underneath it (opacity alone
              // doesn't affect hit testing); ExcludeSemantics keeps a
              // screen reader from landing on a "Show menu" control that
              // isn't actually there to look at; ExcludeFocus does the
              // same for keyboard/switch-access focus traversal, which
              // IgnorePointer alone doesn't block.
              child: ExcludeSemantics(
                excluding: !selected,
                child: ExcludeFocus(
                  excluding: !selected,
                  child: IgnorePointer(
                    ignoring: !selected,
                    child: AnimatedOpacity(
                      opacity: selected ? 1 : 0,
                      duration: const Duration(milliseconds: 150),
                      child: trailing,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// The dock-layout prototype's wide arrangement: the same five panes as
  /// the fixed layout, but arranged by a persisted, user-editable dock tree
  /// (drag a tab to move a pane; see dock_layout.dart). The default mirrors
  /// the fixed layout — logging on the left, the rest tabbed on the right.
  /// No 'operation' pane: its settings live in the operation sheet.
  static const _dockModuleIds = ['logging', 'info', 'spots', 'map'];

  /// Mirrors the fixed wide layout — logging on the left, the rest tabbed on
  /// the right — and is what Restore Defaults puts back.
  DockNode _defaultDockSpec() => DockSplit(Axis.horizontal, [
    DockGroup(['logging']),
    // Selected: Info, matching the fixed wide layout's initial tab.
    DockGroup(['info', 'spots', 'map']),
  ], [2, 1]);

  /// Reads the saved arrangement once, or falls back to the default when
  /// there is nothing saved or it does not parse.
  ///
  /// Deliberately does NOT check the modules against the catalog. A module
  /// this view cannot build is shown as a placeholder pane, not treated as a
  /// broken arrangement — an extension disabled, uninstalled, or merely slow
  /// to answer must never cost the operator their layout, and setting a
  /// saved arrangement aside is as destructive as deleting from it, because
  /// the next thing written replaces it.
  void _ensureDockSpec() {
    if (_dockSpec != null) return;
    final persisted = DockNode.fromJson(widget.services.settings.layoutData(LayoutKeys.operationDock));
    _dockSpec = persisted != null && _hasNoDuplicates(persisted) ? persisted : _defaultDockSpec();
  }

  /// The one thing a saved arrangement still cannot be. A module listed
  /// twice hands the same widget instance to two groups, and the logging
  /// pane carries a GlobalKey — so the view throws on every build, and
  /// because nothing rewrites the spec it throws again after a relaunch,
  /// with Layout Setup unreachable to undo it. Unreachable through the UI
  /// (both `addModule` and the drop handler dedupe), which is exactly why it
  /// would only ever arrive in a file nobody could then repair.
  bool _hasNoDuplicates(DockNode spec) {
    final modules = spec.collectModules();
    if (modules.length == modules.toSet().length) return true;
    debugPrint('[layout] saved dock arrangement lists a module twice; falling back to the default');
    return false;
  }

  /// The dock's STATE — which pane is on top — kept in its own settings key,
  /// apart from the arrangement.
  ///
  /// Kept CURRENT, not read once: the dock is unmounted and rebuilt whenever
  /// the layout crosses the two-pane boundary (a window resize, or a font
  /// scale change that moves the effective width), and its `initState`
  /// applies this over the live tree. Stale here means reopening on whatever
  /// tab was on top at launch, undoing the operator's selection every time
  /// they resize past the boundary and back.
  late DockState _dockState = DockState.fromJson(
    widget.services.settings.layoutData(LayoutKeys.operationDockState),
  );

  Map<String, String> _dockTitles(int realQsoCount) => {
    // The logging tab carries a live count; the catalog's own title for it
    // is the plain name the Layout Setup sheet lists.
    'logging': context.t.operation.tabs.qsos(count: realQsoCount),
    'info': context.t.operation.tabs.info,
    'spots': context.t.operation.tabs.spots,
    'map': context.t.operation.tabs.map,
    for (final panel in widget.services.panels.catalog)
      if (panel.source == PanelSource.extension) panel.id: panel.title,
    // Every extension module actually in the arrangement, which the catalog
    // loop above misses for a PLACEMENT: `ext:hook:key#1` is not a catalog
    // id, so without this a Custom Text pane whose name is still empty — the
    // default the moment one is added — has a tab reading its raw id.
    // A module the catalog cannot explain at all falls back to its own key,
    // which reads better than the full id; the pane behind it says what is
    // actually wrong.
    for (final id in _dockSpec?.collectModules() ?? const <String>[])
      if (!_dockModuleIds.contains(id)) id: widget.services.panels[id]?.title ?? panelKeyOfPanelId(id),
    // A panel may name its own tab, which is what tells two placements of
    // one panel apart. LAST but one in the map, so it wins over every
    // fallback above — a descriptor's title is the panel's guess, this is
    // what it actually rendered.
    ..._panelTitles,
    // LAST: the operator's own name for the pane beats everything, including
    // what the panel calls itself. Nobody else gets to overrule what they
    // typed into that box.
    for (final entry in _paneOptions.entries)
      if (entry.value.title != null) entry.key: entry.value.title!,
  };

  /// Registers this view's own panels with the service. Called from
  /// [didChangeDependencies] rather than [initState] because the titles are
  /// localized — a locale change has to reach the catalog too.
  void _registerNativePanels() {
    final t = context.t.operation;
    final service = widget.services.panels;
    service.registerNative(PanelDefinition(
      id: 'logging',
      title: t.tabs.qsosPlain,
      description: t.layout.panels.loggingDescription,
      icon: 'notebook',
      source: PanelSource.native,
      // The same field-visibility and dupe/number toggles the logging
      // panel's own tune button opens.
      settingsTarget: 'logging',
    ));
    service.registerNative(PanelDefinition(
      id: 'info',
      title: t.tabs.info,
      description: t.layout.panels.infoDescription,
      icon: 'informationOutline',
      source: PanelSource.native,
    ));
    service.registerNative(PanelDefinition(
      id: 'spots',
      title: t.tabs.spots,
      description: t.layout.panels.spotsDescription,
      icon: 'radioTower',
      source: PanelSource.native,
    ));
    service.registerNative(PanelDefinition(
      id: 'map',
      title: t.tabs.map,
      description: t.layout.panels.mapDescription,
      icon: 'map',
      source: PanelSource.native,
    ));
    service.registerNative(PanelDefinition(
      id: clockPanelId,
      title: t.tabs.clock,
      description: t.layout.panels.clockDescription,
      icon: 'clock-outline',
      source: PanelSource.native,
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
      // Placed once, deliberately, and so its location survives the pane
      // being removed and put back — see `forgetInstanceConfig`, which names
      // this panel as the case that distinction exists for.
      formFields: [
        {
          'type': 'field',
          'key': weatherLocationKey,
          'fieldType': 'text',
          'label': t.layout.panels.weatherLocation,
          'description': t.layout.panels.weatherLocationDescription,
          'value': '',
        },
      ],
    ));
    service.registerNative(PanelDefinition(
      id: websitePanelId,
      title: t.tabs.website,
      description: t.layout.panels.websiteDescription,
      icon: 'web',
      source: PanelSource.native,
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

  Widget _dockLayout({
    required Widget loggingPanel,
    required Widget infoPanel,
    required Widget spotsPanel,
    required Widget mapPanel,
    required int realQsoCount,
    required List<Qso> qsos,
    required Operation operation,
  }) {
    _ensureDockSpec();
    final inLayout = _dockSpec!.collectModules();
    return DockLayoutView(
      key: _dockKey,
      initialSpec: _dockSpec!,
      titles: _dockTitles(realQsoCount),
      children: {
        for (final entry in {
          'logging': loggingPanel,
          'info': infoPanel,
          'spots': spotsPanel,
          'map': mapPanel,
          // Extension panels are built only for what the arrangement actually
          // holds: an ExtensionPanel renders on mount, so building one for a
          // panel nobody added would cross the bridge for a pane that is never
          // shown.
          for (final id in inLayout)
            // Ahead of the extension branch, and ahead of the missing-pane
            // fallback: an instance id like `clock#2` is in neither the fixed
            // entries above nor `_dockModuleIds`, so without this the fallback
            // claims it and the operator is told an extension is missing for a
            // pane that has nothing to do with extensions.
            //
            // One widget per PLACEMENT, not one for the descriptor: the
            // instance id is the config key, and a single widget handed to two
            // groups is one element in two places.
            if (PanelDefinition.descriptorIdOf(id) == clockPanelId)
              id: ClockPanel(
                key: ValueKey('panel-$id'),
                panelId: id,
                panels: widget.services.panels,
                onTitle: (title) => _onPanelTitle(id, title),
              )
            else if (id == weatherPanelId)
              id: WeatherPanel(
                key: const ValueKey('panel-$weatherPanelId'),
                panelId: id,
                panels: widget.services.panels,
                settings: widget.services.settings,
                // The saved operation's grid, not the draft's: the pane
                // refetches when this changes, and a half-typed grid square
                // would send a request per keystroke.
                operationGrid: operation.grid,
                onTitle: (title) => _onPanelTitle(id, title),
              )
            else if (PanelDefinition.descriptorIdOf(id) == websitePanelId)
              id: WebsitePanel(
                key: ValueKey('panel-$id'),
                panelId: id,
                panels: widget.services.panels,
                onTitle: (title) => _onPanelTitle(id, title),
                // From `_callInfo`, which this view keeps current
                // unconditionally — NOT from the QSO draft, which is only
                // produced when a panel declares `qso` and costs a rebuild
                // plus a deep compare on every keystroke. A pull-only
                // question asked once a minute must not put the whole view on
                // the typing path to answer it.
                isEnteringQso: () => (_callInfo?.call ?? '').isNotEmpty,
              )
            else if (widget.services.panels[id]?.source == PanelSource.extension)
              id: ExtensionPanel(
                key: ValueKey('panel-$id'),
                panel: widget.services.panels[id]!,
                panels: widget.services.panels,
                onTitle: (title) => _onPanelTitle(id, title),
                renderContext: PanelRenderContext(
                  operation: _draftOperation ?? operation,
                  qso: _draftQso,
                  qsoCount: realQsoCount,
                  spotsRevision: _spotsRevision,
                  lookupRevision: _lookupRevision,
                ),
              )
            // A module nothing in the catalog explains — an extension disabled
            // or uninstalled since this arrangement was saved. It keeps its
            // pane and says so, rather than costing the operator the layout.
            else if (!_dockModuleIds.contains(id))
              id: MissingPanelPane(extensionName: extensionKeyOfPanelId(id) ?? id),
        }.entries)
          entry.key: _withPaneOverrides(entry.key, entry.value),
      },
      // What a pane offers while it is being USED. The dock hides all of it
      // while editing, where a tab is a grab handle — a panel's own settings
      // are reachable from the panel, and its LAYOUT options from its header
      // (see [_paneEditControls]); the two are different questions and this
      // is the one that belongs to the panel.
      tabActions: {
        'logging': (context) => _buildLoggingSettingsButton(qsos, context: context),
        'map': (context) => _buildMapSettingsButton(context: context),
        for (final id in inLayout)
          if (widget.services.panels[id]?.formFields.isNotEmpty ?? false)
            id: (context) => _buildPanelSettingsButton(widget.services.panels[id]!, context: context),
      },
      editing: _layoutEditing,
      editingPaneControls: (paneContext, id) => _paneEditControls(paneContext, id, qsos: qsos),
      headerlessModules: {
        for (final entry in _paneOptions.entries)
          if (!entry.value.showHeader) entry.key,
      },
      // Only after the dock has actually dropped it — it refuses for the last
      // module, and forgetting a pane that is still on screen would wipe what
      // the operator can see.
      onModuleDeleted: (id) => _forgetPanes([id]),
      initialState: _dockState,
      onStateChanged: (state) {
        // No setState: which pane is on top changes nothing this build
        // depends on, and the dock has already redrawn itself. The field
        // still has to move, since it is what a remounted dock opens on.
        // A pane that cares which one is on top reads `DockPaneVisibility`,
        // which the dock derives per rebuild and this can never contradict.
        _dockState = state;
        widget.services.settings.setLayoutData(LayoutKeys.operationDockState, state.toJson());
      },
      onSpecChanged: (node) {
        // setState, not a bare assignment: `children` above is built from
        // the modules the arrangement held at the LAST parent build, so a
        // pane added from the layout sheet would otherwise get no widget and
        // render as an empty tab until something unrelated rebuilt the view.
        setState(() => _dockSpec = node);
        // While editing, the arrangement is a draft and storage hears nothing
        // — which is the whole basis on which the revert button can promise
        // anything. Outside edit mode this is a divider drag, and those save
        // as they always have.
        if (!_layoutEditing) {
          widget.services.settings.setLayoutData(LayoutKeys.operationDock, node.toJson());
        }
        // The layout sheet, if it is open, is listing this very tree.
        _bumpSheet();
      },
    );
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
  Widget _paneEditControls(BuildContext context, String id, {required List<Qso> qsos}) {
    final theme = Theme.of(context);
    final panel = widget.services.panels[id];
    final options = _paneOptions[id] ?? PaneLayoutOptions.none;
    // What the pane would be called with no override — the placeholder the
    // dialog shows, so the operator can see what they are replacing.
    final defaultTitle = _panelTitles[id] ?? panel?.title ?? panelKeyOfPanelId(id);
    return IconButton(
      icon: Icon(
        MdiIcons.viewDashboardEdit,
        color: theme.colorScheme.onPrimary,
        semanticLabel: context.t.operation.layout.paneOptionsTitle(panel: options.title ?? defaultTitle),
      ),
      onPressed: () => unawaited(showPaneLayoutOptions(
        context,
        paneTitle: options.title ?? defaultTitle,
        defaultTitle: defaultTitle,
        // The header is the tab strip once a pane shares a group, so hiding
        // it is not on offer there.
        inTabset: _groupSizeOf(id) > 1,
        developerMode: widget.services.settings.developerMode,
        current: options,
        resetTitle: context.t.operation.layout.resetPaneConfirm(panel: options.title ?? defaultTitle),
        resetBody: context.t.operation.layout.resetPaneConfirmBody,
        onReset: () => setState(() => _paneOptions.remove(id)),
        // Hiding a pane's header takes the tab action with it, and that is
        // the only other way to a panel's own settings — for a native pane
        // reached through a target (the logging panel) as much as for an
        // extension panel with a form of its own.
        // The keyboard/screen-reader route to what the delete target does:
        // a drag cannot be made without a pointer, and Restore Defaults is the
        // whole arrangement. Absent for the last pane, which the dock
        // refuses to remove — an empty dock has no tab left to drag anything
        // back with.
        onDelete: _paneCount() > 1
            ? () {
                final dock = _dockKey.currentState;
                if (dock == null) return;
                if (dock.removeModule(id)) _forgetPanes([id]);
              }
            : null,
        onPanelSettings: switch (id) {
          'logging' => () => unawaited(_openLoggingSettings(context, qsos)),
          'map' => () => unawaited(_openMapSettings(context)),
          _ when panel != null && panel.formFields.isNotEmpty =>
            () => unawaited(showPanelSettings(context, services: widget.services, panel: panel)),
          _ => null,
        },
        onChanged: (next) => setState(() {
          // Dropped rather than stored empty, so a layout carries options
          // only for the panes that actually have any.
          if (next.isEmpty) {
            _paneOptions.remove(id);
          } else {
            _paneOptions[id] = next;
          }
        }),
      )),
    );
  }

  /// An extension panel's own configuration, on its tab — the counterpart of
  /// the logging pane's tune button, and the only route to a form whose
  /// fields configure that pane and nothing else.
  Widget _buildPanelSettingsButton(PanelDefinition panel, {required BuildContext context}) {
    final theme = Theme.of(context);
    return Builder(
      builder: (buttonContext) => IconButton(
        icon: Icon(
          MdiIcons.tune,
          color: theme.appBarTheme.foregroundColor ?? theme.colorScheme.onPrimary,
          semanticLabel: context.t.operation.layout.panelSettings(panel: panel.title),
        ),
        onPressed: () => unawaited(showPanelSettings(buttonContext, services: widget.services, panel: panel)),
      ),
    );
  }

  /// A pane's own font-scale and density overrides, applied around the pane's
  /// widget and nowhere else.
  ///
  /// Font scale is a [SubtreeUiScale] rather than a hand-multiplied
  /// dimension, which is the only way to do this that
  /// [docs/design/ui-scaling.md]'s rules allow: everything inside stays in
  /// plain logical pixels, and the pane simply lives in a coordinate space
  /// scaled once more. NOT a bare [UiScale], which is a root primitive and
  /// stretches a pane's two axes by different factors — see its doc.
  ///
  /// Density is a scope, the same one a vertical split already publishes for
  /// a shortened pane. Set explicitly here it stops being a function of
  /// height, which is the point: a pane can be told to stay compact in a
  /// window with room to spare.
  /// Each wrapper closes over `inner`, a FINAL copy, never over the `wrapped`
  /// variable it is about to be assigned to. A builder that reads `wrapped`
  /// resolves it at BUILD time — by which point it is the builder itself, so
  /// the builder becomes its own child and the tree mounts forever. It does
  /// not throw where the mistake is; it blows the stack a thousand mounts
  /// later, while Flutter is formatting the error.
  Widget _withPaneOverrides(String id, Widget pane) => _withOverrides(_paneOptions[id], pane);

  /// The same wrapping for the VIEW as a whole. Applied around the dock, so a
  /// pane that overrides nothing inherits it and one that does wins — each
  /// level names an ABSOLUTE size, and the innermost that names one decides.
  Widget _withViewOverrides(Widget dock) => _withOverrides(_viewOptions, dock);

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
    return wrapped;
  }

  /// Whether any extension the operator could enable contributes a panel.
  /// The Extensions list this opens is filtered to the `panel` hook, and a
  /// gated extension is not in it either.
  bool get _hasPanelExtensions {
    final extensions = widget.services.extensions;
    return extensions.availableExtensions
        .any((info) => !info.core && info.hooks.contains('panel') && extensions.isExtensionAvailable(info));
  }

  /// How many panes the whole arrangement holds — panes, not groups: one
  /// group can hold several. One is the floor the dock enforces, so a
  /// removal control has nothing to offer there.
  int _paneCount() => _dockSpec?.collectModules().length ?? 0;

  /// How many modules share [id]'s group, or 1 when nothing in the
  /// arrangement holds it.
  int _groupSizeOf(String id) {
    int? sizeIn(DockNode node) => switch (node) {
      DockGroup(:final modules) => modules.contains(id) ? modules.length : null,
      DockSplit(:final children) => children.map(sizeIn).nonNulls.firstOrNull,
    };
    return _dockSpec == null ? 1 : sizeIn(_dockSpec!) ?? 1;
  }

  /// Bumped on every change an open layout sheet is listing — dock
  /// mutations and catalog refreshes both. The sheet sits in its own route,
  /// above the view that owns the tree, so a `setState` here does not reach
  /// it.
  ///
  /// Created when the sheet opens and disposed when it closes, rather than
  /// living as long as the view: a notifier the view disposes while the
  /// sheet's route is still mounted throws when that route finally removes
  /// its listener.
  ValueNotifier<int>? _sheetRevision;

  void _bumpSheet() => _sheetRevision?.value++;

  /// The header's plus button — measured, like [_headerTitleLeftInset],
  /// rather than derived from theme constants, and as a distance from the
  /// window's RIGHT edge, which is the edge the sheet aligns to.
  final _addPanelButtonKey = GlobalKey();

  double? get _addPanelButtonRightInset {
    final box = _addPanelButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return null;
    final rightEdge = box.localToGlobal(Offset(box.size.width, 0)).dx;
    return math.max(0.0, MediaQuery.sizeOf(context).width - rightEdge);
  }

  /// Turns the dock into an editor.
  ///
  /// Nothing else about the view changes: the draft IS the live arrangement,
  /// so what the operator drags is what they are looking at. Only the write
  /// to settings is held back (see the dock's `onSpecChanged`).
  void _startLayoutEditing() {
    // A second press must not re-take the snapshot: discard would then roll
    // back to the last press rather than to where editing began.
    if (_layoutEditing) return;
    // Editing excludes the panes from focus traversal, which unfocuses
    // whatever was in them — the call field, ordinarily. Nothing puts it
    // back on the way out: the pane is never remounted, so its autofocus
    // does not fire again, and the operator returns to a view that looks
    // ready to log and swallows every keystroke.
    // The press's capture when there was one (see [_layoutHeaderControls]);
    // otherwise whatever holds focus now, which is the keyboard-activated
    // case — no pointer-down, so nothing has been unfocused.
    _focusBeforeLayoutEditing = _focusAtPress ?? FocusManager.instance.primaryFocus;
    _focusAtPress = null;
    final spec = _dockSpec;
    if (spec == null) {
      debugPrint('[layout] Edit Layout pressed with no arrangement resolved');
      return;
    }
    setState(() {
      _layoutSnapshot = spec.toJson();
      _paneOptionsSnapshot = PaneLayoutOptions.mapToJson(_paneOptions);
      _viewOptionsSnapshot = _viewOptions.toJson();
      _layoutEditing = true;
    });
    // Entering from the sheet's own header copy: those are the buttons that
    // change, and the route rebuilds them on the revision, not on setState.
    _bumpSheet();
  }

  /// Cancels the edit: the arrangement goes back to where editing found it
  /// and edit mode ends. The counterpart of [_saveLayout], and the reason
  /// leaving is safe — every way out of edit mode either keeps everything or
  /// keeps nothing.
  ///
  /// Selection is deliberately NOT reverted: which pane is on top is state,
  /// not arrangement (see [DockState]), and it is saved as the operator makes
  /// it whether or not they are editing.
  void _revertLayout() {
    final snapshot = _layoutSnapshot;
    final spec = snapshot == null ? null : DockNode.fromJson(snapshot);
    if (spec == null) {
      // Leave anyway. Edit mode left on has no way out from here: the same
      // bail runs when customization is switched off mid-edit, and that
      // unmounts the dock and with it every control that could end the edit.
      debugPrint('[layout] revert pressed with nothing to revert to');
      setState(() {
        _pendingForgets.clear();
        _layoutEditing = false;
        _layoutSnapshot = null;
        _paneOptionsSnapshot = null;
        _viewOptionsSnapshot = null;
      });
      // The other two halves of any exit: focus goes back where the edit took
      // it from, and a sheet still up redraws the controls that just changed.
      _restoreFocusAfterEditing();
      _bumpSheet();
      return;
    }
    // NOT required. A narrow window has no dock mounted, and that is exactly
    // when this runs on its own — turning the setting off mid-edit. Bailing
    // there leaves the draft live and edit mode stuck on, so the arrangement
    // that reappears when the setting comes back is the one the operator
    // discarded. `_dockSpec` below is what a remounting dock reads.
    final dock = _dockKey.currentState;
    // Panes this revert is DROPPING: added during the edit, so nothing
    // outside it ever knew them, and their contents go the way any removed
    // pane's do. Without this an added-then-reverted `#2` leaves its config
    // behind for the next `#2` to inherit — the same defect the deferred
    // forget prevents, running the other way.
    // Panes this revert is DROPPING: everything the edit brought into being
    // that the restored arrangement does not hold — those still on screen
    // (added) AND those already taken out again (added, then removed, so in
    // `_pendingForgets` and in neither tree). Miss the second set and a
    // discarded pane's notes wait for the next placement to reuse its id,
    // which is the leak the deferred forget exists to prevent.
    final restored = spec.collectModules().toSet();
    final dropped = {..._pendingForgets, ...?_dockSpec?.collectModules()}.difference(restored);
    _dockState.applyTo(spec);
    // emit: false — a revert is the operator UNDOING their own edits, and
    // reporting it back would be recorded as one more of them.
    dock?.replaceSpec(spec, emit: false);
    setState(() {
      _dockSpec = spec;
      // The panes the edit's removals took out are back on screen; forgetting
      // their contents now would empty a pane the operator can see.
      _pendingForgets.clear();
      _paneOptions = PaneLayoutOptions.mapFromJson(_paneOptionsSnapshot);
      _viewOptions = PaneLayoutOptions.fromJson(_viewOptionsSnapshot);
      _layoutEditing = false;
      _layoutSnapshot = null;
      _paneOptionsSnapshot = null;
      _viewOptionsSnapshot = null;
    });
    _forgetPanesNow(dropped);
    _restoreFocusAfterEditing();
    _bumpSheet();
  }

  /// What held focus when editing began, to be handed back when it ends.
  FocusNode? _focusBeforeLayoutEditing;

  /// What held focus when the Edit Layout button was PRESSED, which is before
  /// the press itself unfocused it. Claimed by [_startLayoutEditing] if the
  /// press becomes a tap, and dropped a frame later if it does not.
  FocusNode? _focusAtPress;

  void _dropPressFocusCapture() =>
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusAtPress = null);

  /// Restores it, a frame later: the panes are still excluded from traversal
  /// during the build that ends edit mode, and a request made then is
  /// refused.
  void _restoreFocusAfterEditing({bool keep = false}) {
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
      // caret nowhere — worse than leaving it where it is, since it also
      // takes focus off whatever did have it.
      if (node is FocusScopeNode) return;
      node.requestFocus();
    });
  }

  /// Runs one of the two exits, and — pressed from the sheet's own header
  /// copy — takes the sheet down with it.
  ///
  /// The sheet is a control panel for an edit in progress: it lists what can
  /// be added. Left open past the exit, that add writes straight to settings
  /// the moment it is pressed — with the Discard that was beside it a second
  /// ago gone — and the sheet's own header still offers a Save for an edit
  /// that is already over.
  void _endEditingFrom(BuildContext context, {required bool inSheet, required VoidCallback exit}) {
    exit();
    // Pop AFTER: the exits call `_bumpSheet`, and a route already gone simply
    // has nothing listening.
    if (inSheet && Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  /// Commits the draft and leaves edit mode.
  void _saveLayout() {
    final spec = _dockSpec;
    // Panes this save is DROPPING: removed during the edit and NOT back in
    // the arrangement being saved. The same set difference the revert takes,
    // running the other way — a pane dropped and then re-added (or a new
    // instance handed the freed id, which [PanelService.nextInstanceId]
    // does on purpose) is a pane the operator can see, and forgetting it
    // would empty one they just filled in.
    final kept = spec?.collectModules().toSet() ?? const <String>{};
    final forgotten = _pendingForgets.toSet().difference(kept);
    // Before the writes, never after: forgetting drops these panes' entries
    // from [_paneOptions], and a map serialized first would carry a removed
    // pane's title and overrides to disk for whatever takes its id next.
    _forgetPanesNow(forgotten);
    if (spec != null) widget.services.settings.setLayoutData(LayoutKeys.operationDock, spec.toJson());
    widget.services.settings.setLayoutData(
      LayoutKeys.operationPaneOptions,
      PaneLayoutOptions.mapToJson(_paneOptions),
    );
    widget.services.settings.setLayoutData(LayoutKeys.operationViewOptions, _viewOptions.toJson());
    setState(() {
      _layoutEditing = false;
      _layoutSnapshot = null;
      _paneOptionsSnapshot = null;
      _viewOptionsSnapshot = null;
      _pendingForgets.clear();
    });
    _restoreFocusAfterEditing();
    // Saving from the sheet's own header copy has to redraw it: these very
    // buttons are what changes.
    _bumpSheet();
  }

  /// The guard below is not reachable through the UI any more (the sheet's
  /// header no longer carries a plus), which is exactly why it is worth a
  /// test: it is what stops a second caller stacking a route over the first.
  @visibleForTesting
  Future<void> openAddPanelSheetForTest() => _openAddPanelSheet();

  Future<void> _openAddPanelSheet() async {
    // The sheet's own header carries this very button (see [headerTrailing]),
    // so the obvious thing to press while it is up reopens it. A second route
    // would take over `_sheetRevision` — orphaning the first sheet's list —
    // and on closing would clear `_layoutSheetOpen` under a sheet still on
    // screen, putting a dead copy of the controls in the header beneath it.
    if (_layoutSheetOpen) return;
    final dock = _dockKey.currentState;
    if (dock == null) {
      // The button is only rendered alongside the dock, so this is a bug
      // rather than a state the operator can be in — and a button that does
      // nothing at all is not something they could report.
      debugPrint('[layout] add-panel button pressed with no dock mounted');
      return;
    }
    // An extension enabled since this view mounted has panels nobody has
    // asked for yet, and this is where the operator would go looking for
    // them. The answer lands after the sheet is already built, which is why
    // the sheet rebuilds on `revision` rather than reading the catalog once.
    unawaited(widget.services.panels.refreshExtensionPanels());
    final revision = _sheetRevision = ValueNotifier<int>(0);
    final t = context.t.operation.layout;
    setState(() => _layoutSheetOpen = true);
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
      // while this is up (see [_layoutHeaderControls]). Rebuilt on the same
      // revision the sheet body is, since Save Layout is one of them and
      // changes which of them there are.
      headerTrailing: ValueListenableBuilder<int>(
        valueListenable: revision,
        // A context from inside the route, so the buttons resolve their theme
        // and their locale where they are actually drawn.
        builder: (headerContext, _, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [..._layoutHeaderControls(headerContext, inSheet: true), windowsCaptionSpacer(context)],
        ),
      ),
      // A mirror of the operation sheet's top row, because this sheet hangs
      // off the opposite end of the same header: Options where that one puts
      // its accept button, the title against the edge the sheet came from,
      // and the accept button at that edge.
      // Its own trailing inset: HaloDialogHeader puts the title's Expanded
      // and the accept button flush against each other, and a right-aligned
      // title ends exactly where that button starts.
      title: Padding(
        padding: const EdgeInsets.only(right: Space.lg),
        child: Text(t.title, textAlign: TextAlign.right),
      ),
      // The same accept button the operation sheet carries. Nothing is held
      // back to be saved here — a removed panel is gone the moment it's
      // tapped — so this only dismisses; it exists because a sheet with an
      // accept button and one without read as two different kinds of
      // surface.
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
          // (a resize past the two-pane breakpoint), and the list is then
          // about an arrangement that is not on screen. Falling back to the
          // draft keeps it describing the same thing the header does.
          final inLayout = _dockKey.currentState?.modules ?? _dockSpec?.collectModules() ?? const <String>[];
          return LayoutSheet(
            // Catalog order, not the order things were taken out in, so a
            // panel returns to the same place in the list it left from.
            // Everything a row shows — name, description, preview — comes
            // from the panels service, so a panel an extension contributed
            // lists exactly like one of ours.
            available: [
              for (final panel in widget.services.panels.catalog)
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
              // re-adding the descriptor: its id is what its config is
              // stored under, so two panes sharing one would share their
              // contents too.
              // Re-read for the same reason the reset above does.
              final dock = _dockKey.currentState;
              if (dock == null) return;
              final panel = widget.services.panels[id];
              dock.addModule(
                panel != null && panel.multiple
                    // Ids waiting to be forgotten are NOT free. Their config
                    // outlives the removal until the save commits it, so
                    // handing one to a new placement gives the operator a
                    // pane that arrives holding the last one's notes — and
                    // the save then spares it, seeing the id back in the
                    // arrangement.
                    ? PanelService.nextInstanceId(id, [...dock.modules, ..._pendingForgets])
                    : id,
              );
            },
            // Filtered to the extensions that contribute panels — an operator
            // sent here for more panels should not be handed the whole
            // catalog. Whatever they enable lands in the catalog behind this
            // sheet, so the refresh and the bump are what make it appear
            // without closing anything.
            // Offered only when it leads somewhere. Panel extensions are
            // themselves behind the `panels` experiment, so with that off
            // there are none at all — and a button whose whole purpose is
            // "find the panel you want" opening an empty list is worse than
            // no button.
            onManageExtensions: _hasPanelExtensions
                ? () => unawaited(() async {
                    await showModalPane<void>(
                      context,
                      title: context.t.activitiesView.manageExtensions,
                      closeLabel: context.t.common.close,
                      scrollable: false,
                      builder: (_) => ExtensionsPanel(services: widget.services, onlyHook: 'panel'),
                    );
                    await widget.services.panels.refreshExtensionPanels();
                    _bumpSheet();
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
      if (mounted) setState(() => _layoutSheetOpen = false);
    }
  }

  /// The header's layout controls. Present only where there is an
  /// arrangement to edit — the dock, which is two-pane and behind the
  /// operator's own Enable Layout Customization setting.
  ///
  /// Out of edit mode this is one always-visible button, and pressing it goes
  /// straight into editing: there is no sheet in the way, because what an
  /// operator wants when they reach for this is to move a pane.
  ///
  /// Built HERE but rendered in two places, never both at once: the view's
  /// own header while no sheet is up, and the Add a Panel sheet's
  /// `headerTrailing` while one is — the view's header takes no taps under a
  /// modal route, so a button left there would be visible and dead.
  /// [inSheet] for the sheet's own copy. Only the VIEW's copy carries
  /// [_addPanelButtonKey]: popping the sheet completes its route future — and
  /// so un-suppresses the view's copy — while the route is still animating
  /// out, so for those few frames both copies are mounted, and one GlobalKey
  /// across two of them throws.
  /// The VIEW's own layout options, beside the title rather than out in the
  /// actions group: it is about the thing the title names, and the actions
  /// are about the EDIT — add a panel, discard it, save it. Hidden while the
  /// Add a Panel sheet is up, like every other control down here, since the
  /// view's header takes no taps under a modal route.
  Widget? _viewOptionsButton(BuildContext context, {required bool editing}) {
    if (!editing || _layoutSheetOpen) return null;
    final theme = Theme.of(context);
    final t = context.t.operation.layout;
    return IconButton(
      // The same glyph a pane's options carry, because it is the same kind of
      // thing one level up. What tells them apart is where they are.
      icon: Icon(
        MdiIcons.viewDashboardEdit,
        color: theme.appBarTheme.foregroundColor ?? theme.colorScheme.onPrimary,
        semanticLabel: t.viewOptions,
      ),
      onPressed: () => unawaited(showPaneLayoutOptions(
        context,
        paneTitle: _viewOptions.title ?? t.viewName,
        defaultTitle: t.viewName,
        inTabset: false,
        // A view has no header of its own to hide, and this one is the app's,
        // so its name is not the operator's to change.
        showHeaderField: false,
        titleEnabled: false,
        developerMode: widget.services.settings.developerMode,
        current: _viewOptions,
        onChanged: (next) => setState(() => _viewOptions = next),
        resetTitle: t.resetViewConfirm,
        resetBody: t.resetViewConfirmBody,
        onReset: _restoreLayoutDefaults,
      )),
    );
  }

  /// Everything about this view's layout, back to how it ships: the default
  /// arrangement, the view's own options, and every pane's.
  ///
  /// One control rather than two. A reset that put the options back but left
  /// the arrangement alone is not a restore — the operator asking for
  /// defaults is asking for the view they started with, and having to find a
  /// second control in another menu to finish the job is how they end up
  /// half-way between two layouts.
  ///
  /// Part of the DRAFT like everything else in edit mode, so discard undoes
  /// it and the panes come back with what was in them.
  void _restoreLayoutDefaults() {
    // Re-read, never a captured reference: a resize past the two-pane
    // breakpoint takes the dock down while a dialog over it stays up, and a
    // call on the disposed State is a setState-after-dispose.
    final dock = _dockKey.currentState;
    // Dropping a pane means the same thing here as it does anywhere else —
    // a placement's contents go with it. Without this, restoring and then
    // adding a Custom Text pane hands back `#1` still holding the notes that
    // were on screen a moment ago.
    _forgetPanes(dock?.modules ?? _dockSpec?.collectModules() ?? const []);
    final defaults = _defaultDockSpec();
    // emit: false, like the revert. An emit reports the new arrangement's
    // SELECTION through `onStateChanged`, which is not gated on edit mode —
    // it would write which pane is on top to settings there and then, and a
    // discard could not take it back.
    dock?.replaceSpec(defaults, emit: false);
    setState(() {
      _dockSpec = defaults;
      _viewOptions = PaneLayoutOptions.none;
      _paneOptions.clear();
    });
  }

  List<Widget> _layoutHeaderControls(BuildContext context, {bool inSheet = false}) {
    final theme = Theme.of(context);
    final t = context.t.operation.layout;
    // The app shows no hover tooltips (docs/design/user-interface.md), so an
    // icon button's accessible name is the only place it is named.
    final onHeader = theme.appBarTheme.foregroundColor ?? theme.colorScheme.onPrimary;
    if (!_layoutEditing) {
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
          // actually focused then — putting the operator's next keystrokes
          // in a field they left minutes ago. The post-frame is what lets
          // `_startLayoutEditing` claim it first on a real tap.
          onPointerUp: (_) => _dropPressFocusCapture(),
          onPointerCancel: (_) => _dropPressFocusCapture(),
          child: IconButton(
            icon: Icon(MdiIcons.viewDashboard, color: onHeader, semanticLabel: t.editLayout),
            onPressed: _startLayoutEditing,
          ),
        ),
      ];
    }
    return [
      // Not in the sheet's own copy: this is the button that OPENED it, and
      // pressing it again is refused (see [_openAddPanelSheet]). An enabled,
      // focusable, screen-reader-announced control that does nothing is worse
      // than one that is not there — the sheet in front of the operator is
      // already the answer.
      if (!inSheet)
        IconButton(
          key: _addPanelButtonKey,
          icon: Icon(MdiIcons.plus, color: onHeader, semanticLabel: t.title),
          onPressed: () => unawaited(_openAddPanelSheet()),
        ),
      IconButton(
        // Left of Save, and an icon rather than a second labelled button:
        // saving is what the operator came here to do, and discarding is the
        // way back out from a rearrangement they thought better of.
        icon: Icon(MdiIcons.undoVariant, semanticLabel: t.revertLayout),
        color: onHeader,
        onPressed: () => _endEditingFrom(context, inSheet: inSheet, exit: _revertLayout),
      ),
      TextButton.icon(
        onPressed: () => _endEditingFrom(context, inSheet: inSheet, exit: _saveLayout),
        icon: const Icon(MdiIcons.contentSave, size: 18),
        label: Text(t.saveLayout),
        style: TextButton.styleFrom(foregroundColor: onHeader),
      ),
    ];
  }

  /// Bakes [fragments] into [operation]'s own `localData['titleSuggestion']`
  /// — the same shape `OperationTitleService` persists, and the one
  /// `displayTitleFor`/`operation.titleFragments` actually reads. Used both
  /// by the live preview in [build] and, on close, to carry that preview's
  /// result into `_operation` in the same breath the draft is dropped — see
  /// the `finally` block in [_openOperationSheet] for why the LATTER matters:
  /// without it, the header falls back to whatever stale titleSuggestion is
  /// still cached on the saved row until retitleOperation's own async
  /// refresh catches up, flickering back to the pre-edit title in between.
  Operation _withTitleSuggestion(Operation operation, OperationTitleFragments fragments) => Operation(
        uuid: operation.uuid,
        data: operation.data,
        qsoCount: operation.qsoCount,
        startAtMillisMin: operation.startAtMillisMin,
        startAtMillisMax: operation.startAtMillisMax,
        localData: {
          ...operation.localData,
          'titleSuggestion': fragments.isEmpty
              ? null
              : {
                  'title': fragments.title,
                  'for': fragments.forText,
                  'at': fragments.atText,
                  'subtitle': fragments.subtitle,
                },
        },
      );

  @override
  Widget build(BuildContext context) {
    final current = _draftOperation ?? _operation;
    if (current == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    Operation operation = current;
    // While the sheet buffers ref edits, the row's cached titleSuggestion
    // still describes the SAVED refs — swap in the draft's freshly suggested
    // fragments so the header retitles as activities are picked, not on Save.
    if (_draftOperation != null && _draftTitleFragments != null) {
      operation = _withTitleSuggestion(operation, _draftTitleFragments!);
    }

    return StreamBuilder<List<Qso>>(
      stream: _qsosStream(),
      builder: (context, snapshot) {
        final qsos = snapshot.data ?? const <Qso>[];
        // Start/break/end markers ride the same list (for QsoList to render
        // them inline) but aren't real contacts — every QSO *count* shown to
        // the user excludes them, matching scoring/export.
        final realQsoCount = qsos.where((q) => q.isRealContact).length;
        // The ref-derived subtitle only exists once
        // OperationTitleService has run at least once — until then, fall
        // back to the raw ref labels so the header isn't blank.
        final suggestedSubtitle = displaySubtitleFor(operation);
        final refsLine = suggestedSubtitle.isNotEmpty
            ? suggestedSubtitle
            : operation.refs.map((r) => r['shortLabel'] ?? r['ref']).whereType<String>().join(' • ');

        final isTwoPane = ShirtSize.of(context).isTwoPane;

        // Edit mode as the HEADER sees it. `_layoutEditing` alone is not
        // enough: Save and Discard are only emitted where there is an
        // arrangement to edit, so a header that dresses itself for editing on
        // any wider condition strands the operator the moment the window
        // narrows — the dock gone, the operation's own title and setup route
        // replaced by a view name, and nothing on screen to end the edit
        // with. The draft survives in state, so widening returns to it.
        final layoutEditing = _layoutEditing && isTwoPane && _customLayout;

        // The pane subtrees, built once and placed by whichever arrangement
        // is active (their GlobalKeys carry the State across a flip).
        // The Listeners below sit INSIDE each KeyedSubtree so the keys still
        // wrap the same subtree they always did — the reparenting between
        // layouts depends on that. They only observe: pointer-down does not
        // compete for the gesture or change hit testing.
        final loggingPanel = KeyedSubtree(
          key: _loggingKey,
          child: Listener(
            onPointerDown: (_) => _panels.used('logging'),
            child: LoggingPanel(
            operation: operation,
            services: widget.services,
            qsos: qsos,
            loggingControls: _loggingControls,
            onCommandAction: _handleCommandAction,
            showRSTFields: _showRSTFields,
            showStateField: _showStateField,
            showGridField: _showGridField,
            showQsoNumbers: _showQsoNumbers,
            defaultReport: _defaultReport,
            defaultReportCW: _defaultReportCW,
            defaultReportFT8: _defaultReportFT8,
            switchSentRcvd: _switchSentRcvd,
            jumpAfterRST: _jumpAfterRST,
            ourEntityPrefix: _ourEntityPrefix,
            ourItuRegion: _ourItuRegion,
            ourCountryCode: _ourCountryCode,
            suggestedQso: _suggestedQso,
            onCallInfoChanged: (info) {
              // Entering a call is logging-panel use, and it is the one
              // interaction the pointer listener below cannot see: the call
              // field is autofocused, so an operator who just types never
              // puts a pointer down inside the panel. Hooking this existing
              // callback keeps key handling out of it — the focus ladder is
              // a contract (docs/design/logging-fields.md), and a
              // panel-wide key listener is exactly what it forbids.
              _panels.used('logging');
              // A callsign being ANSWERED FOR is what `lookup` is about, and
              // this callback also fires for every letter typed. Keyed on
              // which call has an answer, so typing K→KI→KI2 fires nothing
              // and KI2D resolving fires once. Not an identity check on the
              // guess map: editing a QSO rebuilds it on every call, which
              // would make this per-keystroke after all.
              //
              // A LATER source answering the same call is not seen here: the
              // callback upstream dedupes on a signature holding the guess's
              // display fields, so a second lookup that only adds others
              // never reaches this. Widening it would re-render the Info
              // pane for the same fields it is already showing.
              // A NULL info says the call-info area isn't showing — a command
              // message has the space — which is not news about lookups.
              // Forgetting here would fire `lookup` a second time for the
              // same already-resolved call the moment the message clears.
              var resolved = false;
              if (info != null) {
                final answeredFor = info.guess == null ? null : info.call;
                resolved = answeredFor != null && answeredFor != _lookupAnsweredFor;
                _lookupAnsweredFor = answeredFor;
              }
              if (resolved) _flushDraft = true;
              setState(() {
                _callInfo = info;
                if (resolved) _lookupRevision++;
              });
            },
            // Null unless a panel in this arrangement asked for something
            // that lives in the draft: the draft is rebuilt and deep-compared
            // on every keystroke to produce, so the only cheap version of it
            // is the one nobody asked for.
            //
            // `lookup` counts. Its payload IS the draft — a resolved guess
            // travels inside `their.guess` and nowhere else — so a panel
            // declaring only `lookup` would otherwise be woken with no
            // callsign at all, forever. What `lookup` buys over `qso` is
            // renders, not this.
            onQsoChanged:
                _anyPanelWants('qso') || _anyPanelWants('lookup') ? _onQsoDraftChanged : null,
            onCallInfoTap: () => _handleCallInfoTap(operation),
            ),
          ),
        );
        final spotsPanel = KeyedSubtree(
          key: _spotsKey,
          child: Listener(
            onPointerDown: (_) => _panels.used('spots'),
            child: _LazyTab(
              child: SpotsPanel(
                operation: operation,
                services: widget.services,
                onSuggestQso: _suggestQso,
                logRevision: _logRevisionFor(qsos),
                qsos: qsos,
                // Same payload the map panel highlights from, so the two panes
                // agree on which station is being worked and on the
                // new-vs-editing accent that says so.
                callInfo: _callInfo,
                visible: _spotsVisible,
              ),
            ),
          ),
        );
        final mapPanel = KeyedSubtree(
          key: _mapKey,
          child: Listener(
            onPointerDown: (_) => _panels.used('map'),
            child: _LazyTab(
              // Stretches to the split's very edge: the divider overlay's
              // near-invisible wash (see resizable_split_view.dart) is what
              // keeps the native map view from stealing drags on the strip.
              child: MapPanel(
                operation: operation,
                qsos: qsos,
                settings: widget.services.settings,
                callInfo: _callInfo,
              ),
            ),
          ),
        );
        // ONE construction serving both wide arrangements (fixed tab slot 0
        // and the dock's 'info' module) so their props can't drift apart.
        final infoPanel = Listener(
          onPointerDown: (_) => _panels.used('info'),
          child: InformationPanel(
            operation: operation,
            qsos: qsos,
            services: widget.services,
            callInfo: _callInfo,
            ourEntityPrefix: _ourEntityPrefix,
            activityControls: _loggingControls,
          ),
        );
        // Built before `tabBar`/`tabView`/`_narrowTabBar` below, all of
        // which read `_tabController!` directly — the controller must
        // already be this build's final instance, not the one about to be
        // replaced, by the time any of them are constructed.
        _updateTabControllerIfNeeded(_kTabCount);
        // After the controller, and after `_dockState`/`_customLayout` have
        // settled for this build — the tab controller's own listener only
        // covers the index moving under a view that isn't rebuilding.
        _syncSpotsVisibility();

        // Wide: Info, Spots, Map — logging has its own pane in the split.
        // Narrow: QSOs, Spots, Map — logging is what the view is for, and
        // Info is one tap away via the callsign area.
        // `TabBar` has no height of its own: it reports its tallest Tab plus
        // `indicatorWeight`. So the height goes on the Tabs, less the
        // indicator, and the strip lands on exactly the chrome height — which
        // is what makes it line up with the title bar across the divider.
        // Left to Flutter's defaults this bar was 50 against the title bar's
        // 48, and the comment at the split claimed they matched.
        final tabHeight = LayoutDensity.chromeHeightOf(context) - _tabIndicatorWeight;
        final List<Widget> tabs = [
          if (!isTwoPane)
            Tab(height: tabHeight, text: context.t.operation.tabs.qsos(count: formatNumber(realQsoCount))),
          if (isTwoPane) Tab(height: tabHeight, text: context.t.operation.tabs.info),
          Tab(height: tabHeight, text: context.t.operation.tabs.spots),
          Tab(height: tabHeight, text: context.t.operation.tabs.map),
        ];
        final List<Widget> tabChildren = [
          // The logging panel is kept alive behind the other tabs, so tabbing
          // away leaves it built AND still holding focus. That is fine for the
          // panel itself, but its mobile numbers row is drawn by the app's
          // status-bar overlay, outside this tab view — so it has to be told
          // when it is no longer the visible pane, or the row hangs over
          // whatever tab replaced it and types into the hidden call field.
          // ListenableBuilder because nothing else here rebuilds on tab change.
          if (!isTwoPane)
            ListenableBuilder(
              listenable: _tabController!,
              builder: (context, child) => KeyboardAccessoryVisibility(
                visible: _tabController!.index == 0,
                child: child!,
              ),
              child: _KeepAlive(child: loggingPanel),
            ),
          if (isTwoPane) infoPanel,
          spotsPanel,
          mapPanel,
        ];

        final tabBar = TabBar(
          controller: _tabController!,
          indicatorSize: TabBarIndicatorSize.tab,
          indicatorWeight: _tabIndicatorWeight,
          tabs: tabs,
        );
        final tabView = TabBarView(
          controller: _tabController!,
          // Tabs change only via the tab bar — horizontal swipes would
          // fight the logging strip's own horizontal scrolling (and map
          // panning), so page-swiping is disabled in both layouts.
          physics: const NeverScrollableScrollPhysics(),
          children: tabChildren,
        );

        return Scaffold(
          // The body extends full height behind the on-screen keyboard, so
          // each pane paints its own background there (and a two-pane split
          // reflects for free). The logging panel keeps its fields above the
          // keyboard with its own bottom spacer (see LoggingControls); the
          // Quick Lookup / branding panes do the same on Home.
          resizeToAvoidBottomInset: false,
          appBar: AppBar(
              flexibleSpace: GestureDetector(
                behavior: HitTestBehavior.opaque,
                // Inert while editing, for the same reason the title above it
                // is: the operation's own setup is not what is being
                // arranged. Gating one and not the other leaves the empty
                // header between them opening the very sheet the other
                // refuses.
                onTap: layoutEditing ? null : () => _editActivities(operation),
                child: Stack(
                  children: [
                    if (windowHeaderGestureArea() != null)
                      windowHeaderGestureArea()!,
                  ],
                ),
              ),
              leadingWidth: macOSAwareLeadingWidth(context),
              leading: macOSAwareBackButton(context),
              // Tight against the back button — the dots-and-title control
              // supplies its own (small) inset instead of relying on the
              // theme's default gap here.
              titleSpacing: 0,
              // The logging-only settings menu travels with the logging
              // panel itself, not this AppBar (dock module header,
              // narrow QSOs tab, or the fixed wide split's pane title bar —
              // see _buildLoggingSettingsButton), since none of its toggles
              // apply to the Info/Spots/Map tabs.
              //
              // The layout button, by contrast, is about the arrangement of
              // the whole view, so it belongs here — and only where there IS
              // an arrangement to edit: the dock layout, which is two-pane
              // and experiment-gated.
              actions: [
                if (isTwoPane && _customLayout) ...[
                  // The sheet draws its own copy over this header while it
                  // is up; two would be one too many, and the one down here
                  // would be the unreachable one.
                  if (!_layoutSheetOpen) ..._layoutHeaderControls(context),
                ],
                windowsCaptionSpacer(context),
              ],
              title: InkWell(
                key: _headerTitleKey,
                // Inert while editing: the operation's own setup is not what
                // is being arranged, and the dots that hand off to its sheet
                // would be offering a second thing to do with a header that
                // has just become part of the layout editor.
                onTap: layoutEditing
                    ? null
                    : () {
                        final progress = _sheetAnimation?.value ?? 0.0;
                        if (progress > 0.5) {
                          _activeSheetKey?.currentState?.saveAndClose();
                        } else {
                          _editActivities(operation);
                        }
                      },
                mouseCursor: SystemMouseCursors.click,
                borderRadius: BorderRadius.circular(8),
                // Default M3 hover/pressed overlays are tuned for a surface-
                // colored widget and barely show up on this teal AppBar —
                // same bump as TabBar's own overlayColor (theme.dart).
                overlayColor: WidgetStateProperty.resolveWith((states) {
                  final onPrimary = Theme.of(context).colorScheme.onPrimary;
                  if (states.contains(WidgetState.pressed) || states.contains(WidgetState.focused)) {
                    return onPrimary.withValues(alpha: 0.20);
                  }
                  if (states.contains(WidgetState.hovered)) {
                    return onPrimary.withValues(alpha: 0.16);
                  }
                  return null;
                }),
                child: Padding(
                  // A small left inset so the dots control doesn't
                  // sit flush against the back button, and a small right
                  // inset — the title doesn't stretch to fill the AppBar —
                  // so the control's own edge doesn't sit flush against
                  // whatever's to its right (actions, or the window's own
                  // edge).
                  padding: const EdgeInsets.only(left: Space.md, right: Space.lg, top: Space.xxs, bottom: Space.xxs),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!layoutEditing) ...[
                        _HeaderDotsControl(
                          progress: _sheetAnimation?.value ?? 0.0,
                        ),
                        const SizedBox(width: Space.xs),
                      ],
                      // Flexible (loose), not Expanded (tight): Expanded
                      // forces this Column — and so the InkWell's whole
                      // tap/hover area above — to stretch to the AppBar's
                      // full available width regardless of how little text
                      // there is. Flexible still hands shrinkToFitText below
                      // a bounded max width to shrink/ellipsize against (a
                      // bare, non-flexible Row child gets an UNBOUNDED main-
                      // axis constraint instead — Flutter only bounds a
                      // Row's main axis for Expanded/Flexible children —
                      // which would overflow), without forcing
                      // the Column to consume space it doesn't need.
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title and description each shrink to fit their own
                            // width independently rather than
                            // truncating — down to 75% of their natural font size,
                            // past which the line ellipsizes instead. The
                            // description tries Roboto's condensed glyph width
                            // first, before shrinking its font size at all.
                            // While editing, the header names the VIEW rather
                            // than the operation in it: what is being
                            // rearranged belongs to the view, and it outlives
                            // this operation and every other one.
                            shrinkToFitText(
                              Text(
                                layoutEditing
                                    ? (_viewOptions.title ?? context.t.operation.layout.viewName)
                                    : '${operation.stationCall} ${displayTitleFor(context, operation)}',
                              ),
                            ),
                            if (!layoutEditing && refsLine.isNotEmpty)
                              shrinkToFitText(
                                Text(
                                  refsLine,
                                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.85),
                                  ),
                                ),
                                condensed: true,
                              ),
                          ],
                        ),
                      ),
                      ?_viewOptionsButton(context, editing: layoutEditing),
                    ],
                  ),
                ),
              ),
              // On two-pane layouts the tabs move into the right-side pane
              // below.
              bottom: isTwoPane ? null : _narrowTabBar(realQsoCount, qsos),
            ),
          // One tab set either way, always _kTabCount tabs on the one
          // controller — it is never recreated, so the selected index
          // carries across a flip: index 0 maps QSOs ↔ Info, which is
          // sensible since logging is always visible in the wide split.
          body: AdifDropTarget(
            // Wraps the whole body so a log file can be dropped anywhere on
            // the operation, not onto some particular panel — the operator is
            // dropping it "into this operation", and which pane happened to be
            // under the cursor is not a distinction they are making.
            onFile: (file) => importAdifFile(
              context,
              services: widget.services,
              operation: operation,
              file: file,
            ),
            child: PaneSafeArea.root(
            context,
            // Real device safe-area insets (notch, home indicator) bubble
            // in from here; PaneSafeArea's own
            // divider-clearance role composes with it further down.
            child: isTwoPane && _customLayout
                ? _withViewOverrides(_dockLayout(
                    loggingPanel: loggingPanel,
                    infoPanel: infoPanel,
                    spotsPanel: spotsPanel,
                    mapPanel: mapPanel,
                    realQsoCount: realQsoCount,
                    qsos: qsos,
                    operation: operation,
                  ))
                : isTwoPane
                ? ResizableSplitView(
                    // Null when never dragged → the split's own 2/3-capped-
                    // at-sMax default applies.
                    preferredPrimaryWidth: widget.services.settings.layoutDimension(LayoutKeys.operationLeftColumn),
                    onPreferredPrimaryWidthChanged: (width) =>
                        widget.services.settings.setLayoutDimension(LayoutKeys.operationLeftColumn, width),
                    // The fixed split's counterpart to the dock layout's
                    // module header and the narrow view's QSOs tab: the
                    // logging pane has no title of its own otherwise, and
                    // that's where its settings button lives.
                    // One chrome height for both sides of the split, so the
                    // title bar and the secondary's TabBar line up at the
                    // divider — see `tabHeight` above for why the TabBar has
                    // to be told, rather than left to its own default.
                    primary: Column(
                      children: [
                        Material(
                          color:
                              Theme.of(context).appBarTheme.backgroundColor ?? Theme.of(context).colorScheme.primary,
                          child: SizedBox(
                            height: LayoutDensity.chromeHeightOf(context),
                            // A Builder, not this method's own `context`: that
                            // context is an ANCESTOR of the `PaneSafeArea.root`
                            // wrapping the whole body below, so `leftOf` would
                            // always resolve to its `?? 0` default instead of
                            // the real inset — same pattern as
                            // dock_layout.dart's `_buildGroup`.
                            child: Builder(
                              builder: (context) => Padding(
                                padding: EdgeInsets.only(left: PaneSafeArea.leftOf(context)),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: Space.xl),
                                        child: Text(
                                          context.t.operation.tabs.qsos(count: formatNumber(realQsoCount)),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                            color: Theme.of(context).appBarTheme.foregroundColor ??
                                                Theme.of(context).colorScheme.onPrimary,
                                          ),
                                        ),
                                      ),
                                    ),
                                    _buildLoggingSettingsButton(qsos),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(child: loggingPanel),
                      ],
                    ),
                    secondary: Column(
                      children: [
                        Material(
                          // The TabBar theme assumes it sits on the AppBar's
                          // color (see theme.dart's tabBarTheme note). Tabs
                          // deliberately do NOT inset by PaneSafeArea: they
                          // stretch to the split's very edge (the grab strip
                          // shaving a sliver off the first tab's tap area is
                          // fine for a wide target like a tab).
                          color: Theme.of(context).appBarTheme.backgroundColor ?? Theme.of(context).colorScheme.primary,
                          child: tabBar,
                        ),
                        Expanded(child: tabView),
                      ],
                    ),
                  )
                : tabView,
          ),
          ),
        );
      },
    );
  }
}

/// Keeps the QSO list + logging panel's state alive while another tab is
/// showing — a bare TabBarView disposes off-screen tabs by default, which
/// would silently drop whatever's mid-typed in the logging panel the
/// moment someone glances at the Map tab.
class _KeepAlive extends StatefulWidget {
  final Widget child;

  const _KeepAlive({required this.child});

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// Like [_KeepAlive], but also defers [child]'s first build by
/// [kTabScrollDuration] behind a placeholder — for panels (Spots, Map) whose
/// first inflation is expensive enough to stutter if it lands on the same
/// frames as the tab-switch animation that reveals them. Only defers once:
/// [AutomaticKeepAliveClientMixin] keeps the real child alive afterward, so
/// switching away and back doesn't show the placeholder again.
class _LazyTab extends StatefulWidget {
  final Widget child;

  const _LazyTab({required this.child});

  @override
  State<_LazyTab> createState() => _LazyTabState();
}

class _LazyTabState extends State<_LazyTab> with AutomaticKeepAliveClientMixin {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(kTabScrollDuration, () {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _ready ? widget.child : const Center(child: CircularProgressIndicator());
  }
}

class _HeaderDotsControl extends StatelessWidget {
  final double progress;

  const _HeaderDotsControl({required this.progress});

  @override
  Widget build(BuildContext context) {
    final onPrimary = Theme.of(context).colorScheme.onPrimary;

    // Fixed width: the space stays reserved while the sheet is open, so the
    // header title never shifts — the accept button lives in the sheet's own
    // top row, not here.
    return SizedBox(
      width: 10,
      height: 32,
      child: CustomPaint(
        size: const Size(10, 32),
        painter: _FallingDotsPainter(
          progress: progress,
          dotColor: onPrimary,
        ),
      ),
    );
  }
}

class _FallingDotsPainter extends CustomPainter {
  final double progress;
  final Color dotColor;

  _FallingDotsPainter({
    required this.progress,
    required this.dotColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // The dots fall toward the sheet sliding in below and fade out on the
    // way; the top dot grows slightly as it goes, reading as a hand-off to
    // the accept button in the sheet's top row.
    final opacity = (1.0 - progress / 0.6).clamp(0.0, 1.0);
    if (opacity <= 0) return;

    final paint = Paint()
      ..color = dotColor.withValues(alpha: dotColor.a * opacity)
      ..style = PaintingStyle.fill;

    const x = 4.0;
    const dotRadius = 1.8;
    final dy = 26.0 * progress;

    canvas.drawCircle(Offset(x, 10.0 + dy), dotRadius + 4.0 * progress, paint);
    canvas.drawCircle(Offset(x, 16.0 + dy), dotRadius, paint);
    canvas.drawCircle(Offset(x, 22.0 + dy), dotRadius, paint);
  }

  @override
  bool shouldRepaint(_FallingDotsPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.dotColor != dotColor;
}



/// [qso] with a CW frequency moved a few Hz off the spotted one, so that
/// everyone answering the same spot isn't transmitting on the same note
/// (services/cat/zero_beat.dart).
///
/// Resolved from [services] here, at the one place every suggestion passes
/// through that can see both the settings and the CAT state — halo_widgets is
/// a package below the app and reaches neither. Offsetting once, at the
/// source, is also what keeps the frequency field, the logged QSO and the VFO
/// showing the same number: everything downstream reads this one value.
///
/// A top-level function rather than a method so a test can pin the joints
/// that fail silently — that `enabled` reads `settings.avoidZeroBeat`, that
/// the range reaches the draw, and that "connected" means radio1 rather than
/// any node in the shack.
///
/// Returns the caller's own map untouched when nothing should move, and a
/// copy when something does — the map it is handed belongs to the spot list
/// either way, so neither is safe to mutate.
Map<String, dynamic> zeroBeatSuggestionFor(
  Map<String, dynamic> qso, {
  required HaLoServices services,
  required ZeroBeatOffsetter offsetter,
}) {
  final settings = services.settings;
  // Both gates are checked before `services.cat`, which is what keeps it
  // untouched: that getter is a `late final`, so reading it builds a
  // CatService — registry, stored equipment, a RadioService listener held for
  // the process — and this runs on every spot tap. The experiment is the
  // structural one and stays first: without Station Configuration there is no
  // way to connect a radio at all, so the answer would be "not connected"
  // however the setting is left.
  if (!settings.experimentEnabled('gato') /* stored key, see experiments.yaml */) return qso;
  if (!settings.avoidZeroBeat) return qso;
  final cat = services.cat;
  // radio1 specifically — the one node the logging panel drives. A rig
  // connected in the shack but not driving the panel is not going to be
  // retuned by this suggestion either.
  final radio1 = cat.radio1;
  return offsetter.apply(
    qso,
    enabled: true,
    radioConnected: radio1 != null && cat.stateFor(radio1).status == EquipmentStatus.connected,
    rangeHz: settings.zeroBeatRangeHz,
  );
}

/// How the operation sheet's header row spends [available] width.
///
/// Decided in one place because the title and the controls opposite it
/// compete for the same pixels: the first arrangement that fits wins, so the
/// row drops the title's leading word before either control's label, and the
/// Options label before the Exports one. Nothing fits below the last rung —
/// there [shrinkToFitText] takes over on the title.
class _SheetHeaderFit {
  final String title;
  final bool optionsLabel;
  final bool exportsLabel;

  const _SheetHeaderFit(this.title, {required this.optionsLabel, required this.exportsLabel});

  /// A labelled control's fixed cost around its text: the icon, the gap
  /// Material puts between icon and label, and the button's own padding. Not
  /// scaled by the text scaler, and deliberately so — the icon does not scale
  /// (nothing here sets `applyTextScaling`) and `ButtonStyleButton.scaledPadding`
  /// SHRINKS the padding as text grows, so the unscaled figure is the upper
  /// bound at every scale.
  static const _labelledChrome = 18.0 + Space.md + 32.0;

  /// What the same control takes with the label gone.
  static const _iconOnlyWidth = 48.0;

  /// `ButtonStyle.minimumSize`'s width for a labelled control.
  static const _minButtonWidth = 64.0;

  /// The widths are measured rather than assumed so a translated title or label
  /// degrades at the width it actually needs, not at one tuned for English.
  static _SheetHeaderFit of(BuildContext context, double available) {
    final theme = Theme.of(context);
    final t = context.t.activitiesView;

    // The title style is the one the header itself installed, which is also
    // what shrinkToFitText will measure against — hence the empty override.
    double titleWidth(String title) => textWidth(context, title, const TextStyle());
    // Material's own minimum: a short label in some locale makes the button
    // wider than its text plus chrome.
    double labelled(String label) => math.max(
          _minButtonWidth,
          textWidth(context, label, theme.textTheme.labelLarge ?? const TextStyle()) + _labelledChrome,
        );
    final withLabels = labelled(t.options) + labelled(t.exports);
    final optionsDropped = _iconOnlyWidth + labelled(t.exports);
    final bothDropped = _iconOnlyWidth * 2;

    final rungs = [
      (_SheetHeaderFit(t.sheetTitle, optionsLabel: true, exportsLabel: true), withLabels),
      (_SheetHeaderFit(t.sheetTitleShort, optionsLabel: true, exportsLabel: true), withLabels),
      (_SheetHeaderFit(t.sheetTitleShort, optionsLabel: false, exportsLabel: true), optionsDropped),
      (_SheetHeaderFit(t.sheetTitleShort, optionsLabel: false, exportsLabel: false), bothDropped),
    ];
    for (final (fit, controlsWidth) in rungs) {
      if (titleWidth(fit.title) + controlsWidth <= available) return fit;
    }
    return rungs.last.$1;
  }
}

/// The operation sheet's header row: its title and the Options and Exports
/// controls for the operation as a whole.
///
/// Both live in the header's TITLE slot, not one each in title and trailing,
/// because they compete for the same width and only the title slot has a
/// finite one to measure against — HaloDialogHeader puts the title in an
/// Expanded and hands `trailing` unbounded constraints, so nothing over there
/// can tell how much room is left. Measuring here means the arrangement also
/// re-decides itself on a resize with no dependency on how the pane computes
/// its own width.
class _OperationSheetHeader extends StatelessWidget {
  final VoidCallback onOptions;
  final VoidCallback onExport;

  /// An operation with nothing logged yet still exports, just less usefully.
  final bool dimExport;

  const _OperationSheetHeader({required this.onOptions, required this.onExport, required this.dimExport});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.t.activitiesView;
    final onColor = theme.colorScheme.onSurface;

    // A stripped control keeps its icon and its semantic label, so a screen
    // reader still names it; the app shows no hover labels
    // (docs/design/user-interface.md), so there is no tooltip to gain.
    Widget action({
      required IconData icon,
      required String label,
      required bool labelled,
      required VoidCallback onPressed,
    }) =>
        labelled
            ? TextButton.icon(
                onPressed: onPressed,
                icon: Icon(icon, size: 18),
                label: Text(label),
                style: TextButton.styleFrom(foregroundColor: onColor),
              )
            : IconButton(
                onPressed: onPressed,
                icon: Icon(icon, size: 18, semanticLabel: label),
                color: onColor,
              );

    return LayoutBuilder(
      builder: (context, constraints) {
        final fit = _SheetHeaderFit.of(context, constraints.maxWidth);
        return Row(
          children: [
            Expanded(child: shrinkToFitText(Text(fit.title))),
            action(
              icon: MdiIcons.cog,
              label: t.options,
              labelled: fit.optionsLabel,
              onPressed: onOptions,
            ),
            Opacity(
              opacity: dimExport ? 0.8 : 1.0,
              child: action(
                icon: MdiIcons.fileExportOutline,
                label: t.exports,
                labelled: fit.exportsLabel,
                onPressed: onExport,
              ),
            ),
          ],
        );
      },
    );
  }
}
