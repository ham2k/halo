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
import 'dock_host.dart';
import 'operation_dialogs.dart';
import 'panel_use_tracker.dart';
import 'operation/adif_import_flow.dart';
import 'operation/activities_view.dart';
import 'operation/call_info_panel.dart';
import 'operation/clock/clock_panel.dart';
import 'operation/clock/clock_zones.dart';
import 'operation/panel_settings.dart';
import 'operation/weather/weather_panel.dart';
import 'operation/website/website_panel.dart';
import 'operation/extension_panel.dart';
import 'operation/information_panel.dart';
import 'operation/logging_panel.dart';
import 'operation/map_panel.dart';
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
class _OperationViewState extends State<OperationView> with TickerProviderStateMixin, DockHost<OperationView> {
  @override
  HaLoServices get dockServices => widget.services;

  @override
  String get dockView => PanelViews.operation;

  @override
  DockLayoutKeys get dockKeys => const DockLayoutKeys(
    spec: LayoutKeys.operationDock,
    state: LayoutKeys.operationDockState,
    paneOptions: LayoutKeys.operationPaneOptions,
    viewOptions: LayoutKeys.operationViewOptions,
  );

  @override
  Set<String> get nativeModuleIds => _dockModuleIds.toSet();

  @override
  Map<String, String> get nativeTitles => {
    // The logging tab carries a live count; the catalog's own title for it is
    // the plain name the Add a Panel sheet lists.
    'logging': context.t.operation.tabs.qsos(count: _realQsoCountForTabs),
    'info': context.t.operation.tabs.info,
    'spots': context.t.operation.tabs.spots,
    'map': context.t.operation.tabs.map,
  };

  /// The count the logging tab's label carries, kept as a field because
  /// [nativeTitles] is read by the mixin without it.
  int _realQsoCountForTabs = 0;

  @override
  PanelRenderContext get panelRenderContext => PanelRenderContext(
    operation: _draftOperation ?? _operationForPanels,
    qso: _draftQso,
    qsoCount: _realQsoCountForTabs,
    spotsRevision: _spotsRevision,
    lookupRevision: _lookupRevision,
  );

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

  /// The AppBar's own `leadingWidth` — factored out so the sheet's
  /// headerTrailing can size its own (X) copy identically (see
  /// _openOperationSheet): a copy centered in a differently-sized box would
  /// land at a different x than the real one it's standing in for, and the
  /// two would visibly double up rather than the live one simply replacing
  /// the inert one underneath. Explicit 56.0 rather than null for wide's
  /// non-macOS case — AppBar's own default — so both callers agree on an
  /// actual number instead of one of them silently trusting a framework
  /// default the other can't see.
  double _leadingWidthFor(bool isTwoPane, BuildContext context) => isTwoPane
      ? (macOSAwareLeadingWidth(context) ?? 56.0)
      : (isMacOSChromelessWindow ? 40 + macOSTrafficLightClearance(context) : 40);

  /// The header's dots-and-title control — measured (not computed from
  /// theme constants) to left-align the operation sheet with it, since
  /// AppBar's actual leading width when `leadingWidth` is null varies by
  /// platform in ways not worth re-deriving here.
  final _headerTitleKey = GlobalKey();

  /// The control's left edge WITHIN this view, or null before its first layout
  /// (falls back to [showTopModalPane]'s default centering).
  ///
  /// Measured against the view rather than the window: this route slides in
  /// from the left, and the sheet opens while it is still travelling — a
  /// window-relative reading taken then is off-screen and puts the sheet
  /// wherever the animation happened to be. At rest the view's origin IS the
  /// window's, so the two agree once it lands.
  double? get _headerTitleLeftInset {
    final box = _headerTitleKey.currentContext?.findRenderObject() as RenderBox?;
    final view = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || view == null || !view.attached) return null;
    return box.localToGlobal(Offset.zero, ancestor: view).dx;
  }

  /// The sheet's accept button (headerLeading — see _openOperationSheet)
  /// draws OVER this same corner of the header, not inside its layout, so
  /// nothing here naturally makes room for it — measured so the title Row
  /// can animate its own leading gap open to match, in step with the sheet's
  /// own slide. Null before the button has ever laid out (before the first
  /// open, or between opens): [_leadingGapWidth] falls back to the dots
  /// control's own fixed width then, which is exactly correct at progress 0.
  final _sheetOkButtonKey = GlobalKey();

  double? get _sheetOkButtonWidth {
    // The `.mounted` check alone isn't reliable insurance here — this key's
    // element lives inside the pane's own route, not this state's build, and
    // a resize crossing the narrow/wide boundary can reparent that whole
    // subtree (the route re-presenting itself in place) between the check
    // and the call in ways a `mounted` read a moment earlier can't see
    // coming. `findRenderObject()` throws FlutterError on an inactive
    // element — but only in debug: the check lives inside an `assert`, which
    // release/profile builds strip, so there it just returns the (possibly
    // detached) renderObject instead of throwing. `!box.attached` below is
    // what actually catches that case; the catch only helps in debug.
    final element = _sheetOkButtonKey.currentContext;
    if (element == null || !element.mounted) return null;
    try {
      final box = element.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) return null;
      return box.size.width;
    } on FlutterError {
      debugPrint('[operation] sheet-ok-button-race: cross-route RenderBox read hit an inactive element');
      return null;
    }
  }

  /// The title Row's leading gap, animating from the dots control's own
  /// width to the accept button's — see [_sheetOkButtonWidth]'s doc on why
  /// something has to. Reuses [_sheetAnimation]'s value, not a separate
  /// AnimationController: the two need to move together exactly, and a
  /// second controller can drift out of sync with the route's own reverse
  /// transition (variable duration/curve) for no benefit.
  ///
  /// Reaches the target width on the same `progress / 0.6` curve the accept
  /// button's own grow-in uses (see headerLeading in _openOperationSheet),
  /// not raw progress — the button finishes growing at progress 0.6 and
  /// holds there while the sheet keeps sliding to 1.0, so a gap that kept
  /// widening past that point would still be making room for a button that
  /// had already stopped growing, and one still catching up on the way in
  /// (or shrinking early on the way out) reads as the button overlapping
  /// the title.
  double get _leadingGapWidth {
    const dotsWidth = 10.0;
    final progress = _sheetAnimation?.value ?? 0.0;
    if (progress == 0.0) return dotsWidth;
    final growth = (progress / 0.6).clamp(0.0, 1.0);
    final targetWidth = _sheetOkButtonWidth ?? dotsWidth;
    return dotsWidth + (targetWidth - dotsWidth) * growth;
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
      dockKey.currentState?.revealModule('logging');
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
    if (_wasTwoPane == true && !isTwoPane && layoutEditing) restoreFocusAfterEditing(keep: true);
    _wasTwoPane = isTwoPane;
  }

  void _onSettingsChanged() {
    final s = widget.services.settings;
    final enabled = s.layoutCustomization;
    // Turning customization off mid-edit takes the dock away, and with it
    // every control that could have finished the edit. Discard first, so the
    // draft goes back to what was saved rather than becoming the arrangement
    // that reappears when they turn it on again.
    if (!enabled && layoutEditing) revertLayout();
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
  }


  /// Releases this view's spot-cache subscription (see initState).
  VoidCallback? _unsubscribeSpots;





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
  /// changes, and the dock host's catalog listener rebuilds, which is what
  /// makes the new answer take effect. The first render of such a template
  /// necessarily happens before it: the panel is answered with no draft,
  /// then woken by the next change to one.
  bool _anyPanelWants(String trigger) {
    if (!_customLayout) return false;
    return dockSpec?.collectModules().any((id) => widget.services.panels.triggersFor(id).contains(trigger)) ?? false;
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
        dockKey.currentState?.revealModule('info');
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
        // Left-aligned with the dots-and-title control that opens it,
        // rather than centered in the pane.
        leftInset: _headerTitleLeftInset,
        scrollable: false,
        barrierDismissible: true,
        onDismiss: () => sheetKey.currentState?.saveAndClose(),
        // The view's AppBar (X, title, Options/Export, the accept button
        // below) stays visible on narrow too instead of the sheet covering
        // the whole screen — the same header serves both layouts, so there
        // is no separate narrow-only header to keep in sync with it. Actual
        // reachability for X/Options/Export is headerTrailing's job, below —
        // this alone only stops the sheet from painting over them.
        keepHeaderVisible: true,
        // No header band of its own: the accept control lives in the strip
        // of VIEW header this pane leaves uncovered instead (headerLeading,
        // reachable above the pane's own dismiss layer — see its doc in
        // modal_pane.dart), left-aligned with the title it covers. Dismissal
        // still works via the barrier tap, Escape, and onDismiss above.
        showHeader: false,
        headerLeading: Builder(
          builder: (context) => AnimatedBuilder(
            animation: _sheetAnimation ?? const AlwaysStoppedAnimation(1.0),
            // Grows out of the falling dots' top circle instead of popping
            // in at full size — same 0.6 cutoff the dots fade out by (see
            // _FallingDotsPainter), so the two read as one handoff rather
            // than two unrelated motions layered on each other.
            builder: (context, child) {
              final growth = ((_sheetAnimation?.value ?? 1.0) / 0.6).clamp(0.0, 1.0);
              return Opacity(
                opacity: growth,
                child: Transform.scale(
                  scale: 0.2 + 0.8 * growth,
                  alignment: Alignment.centerLeft,
                  child: child,
                ),
              );
            },
            child: KeyedSubtree(
              key: _sheetOkButtonKey,
              child: _sheetOkButton(context, sheetKey),
            ),
          ),
        ),
        // Live copies of the AppBar's own X/Options/Export, reachable above
        // the barrier the same way the accept button is — the real ones sit
        // BELOW it and only ever look pressable. Each closes the sheet
        // before applying its own action, rather than just dismissing it
        // the way an ordinary barrier tap does: the operator tapped a
        // specific control, not empty space, so it should do what it says.
        // `SizedBox(width: double.infinity)` inside headerTrailing's own
        // `Align` is what spans the X copy to the header's leading edge —
        // headerTrailing normally end-aligns a single trailing control, but
        // a child that claims the max width sizes to fill the box Align
        // hands it, so the alignment becomes moot and a `spaceBetween` Row
        // inside places its own children at both ends instead.
        headerTrailing: Builder(
          builder: (context) {
            final isTwoPane = ShirtSize.of(context).isTwoPane;
            return SizedBox(
              width: double.infinity,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Boxed to _leadingWidthFor, the same width the real
                  // leading slot gets — its own boxSize:40 button centers
                  // within whatever box it's handed, same as AppBar centers
                  // it in `leadingWidth` for the real one below; a copy
                  // narrower than that would land closer to the edge than
                  // the inert original and the two would visibly double up
                  // instead of one cleanly standing in for the other.
                  SizedBox(
                    width: _leadingWidthFor(isTwoPane, context),
                    // macOSAwareBackButton, not a bare IconButton: it's the
                    // one place that already knows to clear the traffic
                    // lights on a chromeless macOS window.
                    child: macOSAwareBackButton(
                      context,
                      close: true,
                      boxSize: 40,
                      onPressed: () async {
                        await sheetKey.currentState?.saveAndClose();
                        if (mounted) Navigator.of(context).maybePop();
                      },
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(MdiIcons.cog, semanticLabel: context.t.activitiesView.options),
                        onPressed: () async {
                          final op = _draftOperation ?? operation;
                          await sheetKey.currentState?.saveAndClose();
                          if (mounted) unawaited(_showOperationOptions(op, includeExport: !isTwoPane));
                        },
                      ),
                      if (isTwoPane)
                        Opacity(
                          opacity: (_draftOperation ?? operation).qsoCount == 0 ? 0.8 : 1.0,
                          child: IconButton(
                            icon: Icon(MdiIcons.fileExportOutline, semanticLabel: context.t.activitiesView.exports),
                            onPressed: () async {
                              final op = _draftOperation ?? operation;
                              await sheetKey.currentState?.saveAndClose();
                              if (mounted) unawaited(_export(op));
                            },
                          ),
                        ),
                      windowsCaptionSpacer(context),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
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

  /// The operation-level actions that don't belong in the activities list
  /// itself. Share and Archive are declared but inert — the rows are here so
  /// the menu's shape is settled, and they stay disabled until each has an
  /// implementation behind it. Standalone rather than routed through the
  /// setup sheet: the AppBar's Options button — its only caller — is itself
  /// unreachable while the sheet is open (nothing behind a modal pane is),
  /// so [operation] is always the real one, never the sheet's draft, and is
  /// saved directly (editOperationDetails' own `save: true` default).
  ///
  /// [includeExport] adds Export Logs as the top row — narrow layouts drop
  /// the AppBar's own Export icon for lack of room beside the title, so this
  /// menu is Export's only way in there; wide layouts keep the icon and
  /// leave it out here rather than offer the same action twice.
  Future<void> _showOperationOptions(Operation operation, {bool includeExport = false}) async {
    final t = context.t.activitiesView;
    final theme = Theme.of(context);
    await showHaloDialog<void>(
      context: context,
      builder: (dialogContext) => HaloDialog(
        title: Text(t.optionsTitle),
        // The rows are the dialog's whole content, so they get the header's
        // horizontal inset from the ListTiles themselves rather than a
        // content padding that would double it.
        contentPadding: const EdgeInsets.symmetric(vertical: Space.md),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (includeExport)
              ListTile(
                leading: const Icon(MdiIcons.fileExportOutline),
                title: Text(t.exportLogs),
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  unawaited(_export(operation));
                },
              ),
            ListTile(
              leading: const Icon(MdiIcons.noteEditOutline),
              title: Text(t.operationDetails),
              onTap: () {
                Navigator.of(dialogContext).pop();
                unawaited(editOperationDetails(context, widget.services.operations, operation));
              },
            ),
            ListTile(
              leading: const Icon(MdiIcons.fileImportOutline),
              title: Text(t.importAdif),
              // The menu closes first: the picker is a platform sheet, and the
              // import's own summary dialog belongs to the screen underneath
              // rather than stacked on a menu that is going away.
              onTap: () {
                Navigator.of(dialogContext).pop();
                unawaited(pickAndImportAdif(context, services: widget.services, operation: operation));
              },
            ),
            ListTile(
              enabled: false,
              leading: const Icon(MdiIcons.shareVariant),
              title: Text(t.share),
            ),
            ListTile(
              enabled: false,
              leading: Icon(MdiIcons.archiveOutline),
              title: Text(t.archive),
            ),
            ListTile(
              leading: Icon(MdiIcons.delete, color: theme.colorScheme.error),
              title: Text(t.deleteOperation, style: TextStyle(color: theme.colorScheme.error)),
              // The menu closes with the confirmation: deleting is about the
              // operation as a whole, and its confirmation belongs to the
              // screen underneath, not to a menu that is going away.
              onTap: () {
                Navigator.of(dialogContext).pop();
                unawaited(confirmDeleteOperation(context, widget.services, operation).then((deleted) {
                  if (!deleted || !mounted) return;
                  Navigator.of(context).pop();
                }));
              },
            ),
          ],
        ),
      ),
    );
  }

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
  ///
  /// The pane's layout options embeds this same target's fields too, but
  /// without this dialog's Actions section — see [_paneEditControls]'s
  /// `panelSettingsBuilder`, which passes none.
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
  @override
  DockNode buildDefaultDockSpec({bool migrate = true}) => DockSplit(Axis.horizontal, [
    DockGroup(['logging']),
    // Selected: Info, matching the fixed wide layout's initial tab.
    DockGroup(['info', 'spots', 'map']),
  ], [2, 1]);





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
      views: const {PanelViews.operation},
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
      views: const {PanelViews.operation},
    ));
    service.registerNative(PanelDefinition(
      id: 'spots',
      title: t.tabs.spots,
      description: t.layout.panels.spotsDescription,
      icon: 'radioTower',
      source: PanelSource.native,
      views: const {PanelViews.operation},
    ));
    service.registerNative(PanelDefinition(
      id: 'map',
      title: t.tabs.map,
      description: t.layout.panels.mapDescription,
      icon: 'map',
      source: PanelSource.native,
      views: const {PanelViews.operation},
    ));
    service.registerNative(PanelDefinition(
      id: clockPanelId,
      title: t.tabs.clock,
      description: t.layout.panels.clockDescription,
      icon: 'clock-outline',
      source: PanelSource.native,
      views: const {PanelViews.operation},
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
      views: const {PanelViews.operation},
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
      views: const {PanelViews.operation},
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
    _operationForPanels = operation;
    return buildDock(
      children: {
        'logging': loggingPanel,
        'info': infoPanel,
        'spots': spotsPanel,
        'map': mapPanel,
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
          if (PanelDefinition.descriptorIdOf(id) == clockPanelId)
            id: ClockPanel(
              key: ValueKey('panel-$id'),
              panelId: id,
              panels: widget.services.panels,
              onTitle: (title) => onPanelTitle(id, title),
            )
          else if (id == weatherPanelId)
            id: WeatherPanel(
              key: const ValueKey('panel-$weatherPanelId'),
              panelId: id,
              panels: widget.services.panels,
              settings: widget.services.settings,
              // The saved operation's grid, not the draft's: the pane refetches
              // when this changes, and a half-typed grid square would send a
              // request per keystroke.
              operationGrid: _operationForPanels?.grid,
              onTitle: (title) => onPanelTitle(id, title),
            )
          else if (PanelDefinition.descriptorIdOf(id) == websitePanelId)
            id: WebsitePanel(
              key: ValueKey('panel-$id'),
              panelId: id,
              panels: widget.services.panels,
              onTitle: (title) => onPanelTitle(id, title),
              // From `_callInfo`, which this view keeps current
              // unconditionally — NOT from the QSO draft, which is only
              // produced when a panel declares `qso` and costs a rebuild plus
              // a deep compare on every keystroke. A pull-only question asked
              // once a minute must not put the whole view on the typing path
              // to answer it.
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
    _ => null,
  };


























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

        // Edit mode as the HEADER sees it. `layoutEditing` alone is not
        // enough: Save and Discard are only emitted where there is an
        // arrangement to edit, so a header that dresses itself for editing on
        // any wider condition strands the operator the moment the window
        // narrows — the dock gone, the operation's own title and setup route
        // replaced by a view name, and nothing on screen to end the edit
        // with. The draft survives in state, so widening returns to it.
        final editingHeader = layoutEditing && isTwoPane && _customLayout;

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
        // After the controller, and after `dockState`/`_customLayout` have
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
                onTap: editingHeader ? null : () => _editActivities(operation),
                child: Stack(
                  children: [
                    if (windowHeaderGestureArea() != null)
                      windowHeaderGestureArea()!,
                  ],
                ),
              ),
              leadingWidth: _leadingWidthFor(isTwoPane, context),
              // A cross, not an arrow: this view arrives over the whole window,
              // rail and mark included, so there is no trail behind it to step
              // back along — the control closes it and nothing else. Boxed to
              // match the Options/Export/layout icons across the same header
              // (see macOSAwareBackButton's boxSize doc) rather than filling
              // the leading slot's own larger default.
              leading: macOSAwareBackButton(context, close: true, boxSize: 40),
              // Tight against it — the dots-and-title control
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
                // Operation-level actions, not scoped to the setup sheet: an
                // operator reaches for Options/Export without necessarily
                // opening it. Gone during layout editing along with the rest
                // of the operation's own identity in this header — nothing
                // about the operation is what's being arranged then. Narrow
                // keeps only the gear — there isn't room for a second icon
                // beside the title — with Export Logs folded into its menu
                // instead of dropped.
                if (!editingHeader) ...[
                  IconButton(
                    icon: Icon(MdiIcons.cog, semanticLabel: context.t.activitiesView.options),
                    onPressed: () => unawaited(
                      _showOperationOptions(_draftOperation ?? operation, includeExport: !isTwoPane),
                    ),
                  ),
                  if (isTwoPane)
                    Opacity(
                      opacity: (_draftOperation ?? operation).qsoCount == 0 ? 0.8 : 1.0,
                      child: IconButton(
                        icon: Icon(MdiIcons.fileExportOutline, semanticLabel: context.t.activitiesView.exports),
                        onPressed: () => unawaited(_export(_draftOperation ?? operation)),
                      ),
                    ),
                ],
                if (isTwoPane && _customLayout) ...[
                  // The sheet draws its own copy over this header while it
                  // is up; two would be one too many, and the one down here
                  // would be the unreachable one.
                  if (!layoutSheetOpen) ...layoutHeaderControls(context),
                ],
                windowsCaptionSpacer(context),
              ],
              title: InkWell(
                key: _headerTitleKey,
                // Inert while editing: the operation's own setup is not what
                // is being arranged, and the dots that hand off to its sheet
                // would be offering a second thing to do with a header that
                // has just become part of the layout editor.
                onTap: editingHeader
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
                  // Wide keeps a small left inset so the dots control
                  // doesn't sit flush against the back button. Narrow sits
                  // the title right against it instead — the leading slot is
                  // already sized to the button alone there (see
                  // leadingWidth above), so there's no residual gap left to
                  // close on that side. Both keep a small right inset — the
                  // title doesn't stretch to fill the AppBar — so the
                  // control's own edge doesn't sit flush against whatever's
                  // to its right (actions, or the window's own edge).
                  padding: EdgeInsets.only(
                    left: isTwoPane ? Space.xs : 0,
                    right: Space.lg,
                    top: Space.xxs,
                    bottom: Space.xxs,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!editingHeader) ...[
                        // Widens from the dots control's own footprint to
                        // the accept button's as the sheet opens — that
                        // button draws OVER this corner via headerLeading,
                        // wider than the dots it covers, so without this the
                        // title behind it would sit UNDER the button's tail
                        // end instead of clear of it (see _leadingGapWidth).
                        // The dots stay mounted and animating underneath
                        // purely so they're not visibly stuck mid-fall for
                        // the instant between the route unmounting at the
                        // end of a close and their own progress catching up
                        // to 0.
                        SizedBox(
                          width: _leadingGapWidth,
                          height: 32,
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: _HeaderDotsControl(
                              progress: _sheetAnimation?.value ?? 0.0,
                            ),
                          ),
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
                                editingHeader
                                    ? (viewOptions.title ?? context.t.operation.layout.viewName)
                                    : '${operation.stationCall} ${displayTitleFor(context, operation)}',
                              ),
                            ),
                            if (!editingHeader && refsLine.isNotEmpty)
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
                      ?viewOptionsButton(context, editing: editingHeader),
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
                ? withViewOverrides(_dockLayout(
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
    // header title never shifts — the accept button draws over this corner
    // via headerLeading instead (see _sheetOkButton's doc).
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
    // the accept button growing in over it (see headerLeading in
    // _openOperationSheet).
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

/// The operation sheet's accept button, shown in the VIEW's own header (left
/// of the title) via `headerLeading` while the sheet is open — it has no
/// header band of its own to carry this (see `_openOperationSheet`'s
/// `showHeader: false`). `headerLeading` draws above the pane's own dismiss
/// layer, which is what makes this reachable at all: the same button placed
/// directly in the view's AppBar sits BELOW that layer and never receives a
/// tap (see `headerLeading`'s own doc in modal_pane.dart).
Widget _sheetOkButton(BuildContext context, GlobalKey<OperationSheetState> sheetKey) => FilledButton.icon(
  icon: const Icon(MdiIcons.check),
  label: Text(context.t.common.ok),
  style: FilledButton.styleFrom(
    backgroundColor: fabAccentColor,
    foregroundColor: Theme.of(context).colorScheme.onPrimary,
  ),
  onPressed: () => sheetKey.currentState?.saveAndClose(),
);

