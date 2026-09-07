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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HardwareKeyboard, KeyDownEvent, KeyEvent, LogicalKeyboardKey;
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../config/dev_bridge.dart';
import '../services/command_actions.dart';
import '../services/halo_services.dart';
import '../services/error_reporting_service.dart';
import '../services/cat/zero_beat.dart';
import '../services/extension_service.dart' show TemplateError;
import '../services/panel_service.dart';
import '../services/settings_service.dart';
import '../settings/settings_target_dialog.dart';
import 'dock_host.dart';
import 'operation_dialogs.dart';
import 'panel_use_tracker.dart';
import 'operation/adif_import_flow.dart';
import 'operation/activities_view.dart';
import 'operation/call_info_panel.dart';
import 'operation/cw_function_keys.dart';
import 'operation/extension_panel.dart';
import 'operation/information_panel.dart';
import 'operation/logging_panel.dart';
import 'operation/map_panel.dart';
import 'operation/operation_export_panel.dart';
import 'operation/operation_import_panel.dart';
import 'operation/spots_panel.dart';
import 'tester_overlay.dart' show testerOverlayCovering;
import 'operation/positions_panel.dart';
import 'peers_panel.dart';
import '../tools/operation_title.dart';
import '../i18n/strings.g.dart';

/// How far into the sheet's open/close slide (0 closed, 1 open) the header's
/// falling-dots handoff to the accept button completes — shared by the
/// title's leading-gap animation ([_OperationViewState._leadingGapWidth]),
/// the accept button's own grow-in (headerLeading in _openOperationSheet),
/// and the dots' fade-out ([_FallingDotsPainter]), which all have to reach
/// their end state at the same instant for the handoff to read as one
/// motion rather than three drifting apart.
const _sheetHandoffThreshold = 0.6;

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

  /// A QSON-shaped suggestion to put into the logging fields as this view
  /// opens — a `/qso` deep link that had to push the view to land anywhere.
  ///
  /// A constructor argument rather than a call on the command context,
  /// because the context of a view being pushed has no `suggestQso` yet: the
  /// caller would have to poll for the state to mount (which is what app-polo
  /// does, with a 2s retry loop). Applied once, in `initState`.
  final Map<String, dynamic>? initialSuggestedQso;

  const OperationView({
    super.key,
    required this.services,
    required this.operationUuid,
    this.openActivities = false,
    this.initialSuggestedQso,
  });

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
  Set<String> get pinnedModuleIds =>
      dockLayoutClass == DockLayoutClass.narrow ? const {'logging'} : const {};

  @override
  Set<String> get nativeModuleIds => {
    ..._dockModuleIds,
    // Only while the experiment is on — and it must match `children` below
    // exactly. Named here but absent there renders no pane at all; absent
    // from both is what routes a saved placement to MissingPanelPane.
    if (_peerPositionsPanel) 'positions',
  };

  /// Whether the Positions panel exists in this build at all.
  bool get _peerPositionsPanel =>
      widget.services.settings.experimentEnabled('p2p') /* stored key, see experiments.yaml */;

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
  // `_refreshLoggingControls` now has three independent callers (a ref
  // change, a draft edit, a runtime-generation retry) that can overlap —
  // bumped before each fetch and checked on return, so a slower call
  // started earlier can't clobber a faster one that started later.
  int _loggingControlsRequestId = 0;
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
  late DxFlags _dxFlags = widget.services.settings.dxFlags;

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

  /// Map is the last tab in both arrangements. Like [_kSpotsTabIndex] it has
  /// to move with any reorder: it decides whether the map thinks it is being
  /// PAINTED, and a webview that is only laid out never renders — which is
  /// the one thing MapLibre's `load` waits for, and the whole input to the
  /// map's ready horizons (see MapReadyWatchdog).
  static const int _kMapTabIndex = _kTabCount - 1;

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
  /// The tab controller is only ever the answer for the FIXED narrow
  /// arrangement — with customization on there is a dock at every width, and
  /// this side is unconditionally true so `DockPaneVisibility` decides alone.
  void _syncSpotsVisibility() {
    _spotsVisible.value = _customLayout || _tabController?.index == _kSpotsTabIndex;
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
  /// Reaches the target width on the same `progress / _sheetHandoffThreshold`
  /// curve the accept button's own grow-in uses (see headerLeading in
  /// _openOperationSheet), not raw progress — the button finishes growing at
  /// that threshold and holds there while the sheet keeps sliding to 1.0, so
  /// a gap that kept widening past that point would still be making room for
  /// a button that had already stopped growing, and one still catching up on
  /// the way in (or shrinking early on the way out) reads as the button
  /// overlapping the title.
  /// Where the sheet's accept button sits on a narrow layout — the header's
  /// own leading corner, less whatever the native window controls need (see
  /// `narrowLeftInset` in [_openOperationSheet]). Shared with
  /// [_leadingGapWidth], which has to know how far LEFT of this control that
  /// button starts.
  double _narrowSheetLeftInset(BuildContext context) =>
      isMacOSChromelessWindow ? macOSTrafficLightClearance(context) : 0;

  double _leadingGapWidth(BuildContext context, {required bool isTwoPane}) {
    const dotsWidth = _headerDotsWidth;
    final progress = _sheetAnimation?.value ?? 0.0;
    if (progress == 0.0) return dotsWidth;
    final growth = (progress / _sheetHandoffThreshold).clamp(0.0, 1.0);
    var targetWidth = _sheetOkButtonWidth ?? dotsWidth;
    if (!isTwoPane) {
      // Narrow starts that button at the header's leading corner, which is
      // the width of the (faded) chevron's own slot to the LEFT of where
      // this control begins — so only the part of it that overhangs into
      // this control needs room made here. Reserving its full width instead
      // would leave exactly that slot's width of dead space between the
      // button and the title. Wide has no overhang: the button starts at
      // this control's own left edge.
      final overhang = targetWidth - (_leadingWidthFor(false, context) - _narrowSheetLeftInset(context));
      targetWidth = math.max(dotsWidth, overhang);
    }
    return dotsWidth + (targetWidth - dotsWidth) * growth;
  }

  /// Shared fade for the AppBar's own leading/Options/Export/layout icons
  /// while the sheet is up — same curve and threshold the falling dots use
  /// ([_FallingDotsPainter]), so the whole header's hand-off to the sheet's
  /// live copies reads as one motion instead of several independently-timed
  /// ones.
  double get _headerIconsFadeOpacity {
    final progress = _sheetAnimation?.value ?? 0.0;
    return (1.0 - progress / _sheetHandoffThreshold).clamp(0.0, 1.0);
  }

  /// Whether the AppBar's own leading/Options/Export/layout icons should
  /// ignore taps — true for the whole time the sheet is up or animating, not
  /// just once fully faded. The Exports/Tools copy sits exactly over the
  /// group it stands in for and is opaque from the first frame, so the real
  /// one is reachable underneath for as long as anything but this stops it —
  /// and a tap it took would act on the operation behind a sheet that is
  /// buffering edits to it.
  bool get _headerIconsInert => (_sheetAnimation?.value ?? 0.0) > 0.0;

  /// The VIEW's layout controls dim to Material's disabled opacity while the
  /// operation's setup sheet is up, on the same curve everything else in the
  /// header uses.
  ///
  /// Only those. The operation's own Exports/Imports/Tools stay at full
  /// strength and stay pressable (see [_headerTrailingControls]) — what the
  /// sheet edits is the operation, and reaching for its exports mid-edit is
  /// a reasonable thing to do. Rearranging the view is not, so those go
  /// disabled rather than away: they do NOT fade out like the chevron,
  /// because nothing replaces them. [_headerIconsInert] is what actually
  /// stops the taps; this is only how that reads.
  double get _layoutControlsDisabledOpacity {
    final progress = _sheetAnimation?.value ?? 0.0;
    final growth = (progress / _sheetHandoffThreshold).clamp(0.0, 1.0);
    return 1.0 - (1.0 - 0.38) * growth;
  }

  /// Tracks the arrangement across dependency changes so the flip can be
  /// detected BEFORE build (see didChangeDependencies). Null until first
  /// resolved.
  bool? _wasTwoPane;

  /// [reveal] false fills the fields and leaves the operator where they are —
  /// what sliding a spot row open does. The spots list is the thing being
  /// worked in that gesture, and on a narrow window surfacing the logging
  /// panel would take it away mid-slide. A row TAP still reveals: there the
  /// operator has chosen the station and wants the fields.
  ///
  /// [measured] marks a suggestion that reports where this operator's own
  /// radio IS, rather than where someone else heard a station — a `/qso` deep
  /// link from a companion app. Avoid Zero-Beating exists to move off a
  /// SPOT's frequency, so applying it to a measured one would mistune the rig
  /// the link is describing, and would disagree with the VFO write the same
  /// link already made. Both entry points must pass the same value: the
  /// offset is a property of where the suggestion came from, never of whether
  /// the operation happened to be open when it arrived.
  void _suggestQso(Map<String, dynamic> qso, {bool reveal = true, bool measured = false}) {
    setState(() {
      _suggestedQso =
          measured ? qso : zeroBeatSuggestionFor(qso, services: widget.services, offsetter: _zeroBeat);
      // A slide peek is the one suggestion the operator has not committed to.
      _suggestedQsoIsTentative = !reveal;
    });
    // A tentative suggestion belongs to the open row, and the panel may hold
    // it back rather than overwrite work in progress — [_suggestionSettled]
    // is where that is put to the operator, once the gesture is over, and
    // [_withdrawSuggestedQso] is where it goes when the row closes.
    if (!reveal) return;
    // On two-pane layouts the logging pane is already visible on the left —
    // and tab 0 is Info there, so switching would be wrong twice over. In
    // dock mode the user may have tabbed the logging pane behind others, so
    // surface it (no-op when it's already visible).
    _revealLoggingPanel();
  }

  /// Takes back a suggestion a slide made — the row that made it has closed.
  /// Only ever a tentative one: a station the operator TAPPED (or typed) is
  /// theirs, and a slide closing somewhere else may not take it away.
  void _withdrawSuggestedQso(String? call) {
    // A row discarded while open withdraws AFTER the frame (see its
    // `dispose`), which is late enough for this view to have gone with it —
    // a whole operation closing takes both down together.
    if (!mounted || !_suggestedQsoIsTentative) return;
    // And late enough for the fields to belong to a different row by then, so
    // a withdrawal only ever takes back the station it put there.
    final suggested = (_suggestedQso?['their'] as Map?)?['call'] as String?;
    if (call != null && suggested != null && call.toUpperCase() != suggested.toUpperCase()) return;
    setState(() {
      _suggestedQso = null;
      _suggestedQsoIsTentative = false;
    });
  }

  /// Bumped when a slid row comes to rest open — see
  /// `LoggingControls.suggestionSettledSerial`.
  int _suggestionSettledSerial = 0;

  void _suggestionSettled() => setState(() => _suggestionSettledSerial++);

  /// Bumped when the operator works the call field themselves — see
  /// `SpotsPanel.closeSlidesSerial`.
  int _closeSlidesSerial = 0;

  void _onCallEdited() => setState(() => _closeSlidesSerial++);

  /// The spots list's slid-right action, carrying the QSO it means to log —
  /// see `LoggingControls.logRequest`. The serial is what makes a repeat of
  /// the same spot a new request.
  ({int serial, Map<String, dynamic> qso})? _logRequest;

  /// Whether [_suggestedQso] came from a gesture the operator can still take
  /// back — see `LoggingControls.suggestedQsoIsTentative`.
  bool _suggestedQsoIsTentative = false;

  /// Log a spot outright, without surfacing the logging panel: the operator
  /// stays on the spots list and the contact is logged behind it.
  void _logQsoFromSpot(Map<String, dynamic> qso) {
    final zeroBeat = zeroBeatSuggestionFor(qso, services: widget.services, offsetter: _zeroBeat);
    setState(() {
      _suggestedQso = zeroBeat;
      _logRequest = (serial: (_logRequest?.serial ?? 0) + 1, qso: zeroBeat);
    });
  }

  /// The logging panel has work a slid spot would destroy. Ask, rather than
  /// letting a gesture made on another surface throw it away — and on "go
  /// back", surface the panel so the operator lands on the thing they kept.
  Future<bool> _confirmLogOverwrite({required bool editing}) async {
    final t = context.t;
    final clear = await showHaloDialog<bool>(
      context: context,
      builder: (context) => HaloDialog(
        title: Text(t.operation.spots.logConflict.title),
        content: Text(
          editing ? t.operation.spots.logConflict.editingBody : t.operation.spots.logConflict.composingBody,
        ),
        cancel: TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(t.operation.spots.logConflict.goBack),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(t.operation.spots.logConflict.clearAndLog),
          ),
        ],
      ),
    );
    if (clear == true) return true;
    // Kept what they had — so put them in front of it. Without this the
    // operator is left on the spots list wondering what their choice did.
    if (mounted) _revealLoggingPanel();
    return false;
  }

  /// Surface the logging panel wherever this layout keeps it.
  void _revealLoggingPanel() {
    // The dock answers for both classes; the tab controller only for the fixed
    // narrow arrangement customization-off still draws.
    if (_customLayout) {
      dockKey.currentState?.revealModule('logging');
    } else if (!ShirtSize.of(context).isTwoPane) {
      _tabController?.animateTo(0);
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
    // Only for the FIXED narrow arrangement: with customization on, narrowing
    // hands over to the narrow DOCK, which opens on its own stored selection
    // and keeps every pane mounted, so there is no page to inflate and no
    // State to rescue. An edit in progress crosses the boundary with the
    // operator (docs/design/layouts.md) rather than being stranded there.
    if (!_customLayout && _wasTwoPane == true && !isTwoPane) _tabController?.index = 0;
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
        s.jumpAfterRST != _jumpAfterRST ||
        s.dxFlags != _dxFlags;
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
        _dxFlags = s.dxFlags;
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
    // A ref-add's own refresh (`_onOperationChanged` below) can race a
    // runtime restart triggered by enabling the extension in the same
    // gesture — `_refreshLoggingControls` sees `loadFailed` and, correctly,
    // keeps the stale controls rather than blanking the panel. Nothing then
    // retries, so the just-added contest's exchange field stays missing
    // until something unrelated (a callsign lookup) happens to refresh
    // after the restart settles. `runtimeGeneration` ticks once the runtime
    // is actually live again (extension_service.dart), which is the signal
    // to try once more.
    widget.services.extensions.runtimeGeneration.addListener(_onRuntimeGenerationChanged);
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
    // Lets a `/qso` deep link prefill THIS operation while it is the
    // front-most one, without pushing a second copy of the view over it.
    // `measured` because only a deep link reaches this callback.
    _commandContext.suggestQso = (qso) => _suggestQso(qso, measured: true);
    // Whether the operator can actually SEE this operation — false with
    // Settings, or another operation, pushed over it. A suggestion delivered
    // to a view nobody is looking at is not lost, but it is invisible, and
    // the caller says so rather than leaving the link looking dead.
    _commandContext.isVisible = () => mounted && (ModalRoute.of(context)?.isCurrent ?? false);
    // The link that pushed this view. Set directly rather than through
    // `_suggestQso`: that one calls setState and reveals the logging panel,
    // neither of which is legal before the first build, and the panel it
    // would reveal is the one about to be built anyway. No zero-beat offset
    // here for the same reason `measured` skips it above.
    _suggestedQso = widget.initialSuggestedQso;
    // F1-F8 key CW messages while this operation is in front — see
    // [_onCwKeyEvent]. A HardwareKeyboard handler rather than a Shortcuts
    // widget, because the keys must work whichever field has focus, and the
    // main key handler (main.dart) only looks at modified chords.
    HardwareKeyboard.instance.addHandler(_onCwKeyEvent);
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

  /// Whether a function key could play a voice memory: the keying
  /// experiment on, and radio1 able to play. Read at build, like
  /// [_cwMessagesConfigured]; the view rebuilds on the CAT service's
  /// notifications, so a radio connecting takes effect on the next one.
  bool get _voiceKeyingPossible {
    final settings = widget.services.settings;
    if (!settings.experimentEnabled('gato') /* stored key, see experiments.yaml */) return false;
    if (!settings.experimentEnabled('keyer') /* stored key, see experiments.yaml */) return false;
    return widget.services.cat.canPlayVoice;
  }

  /// Whether a function key would key anything — the draft is worth
  /// tracking for the messages only once one exists. Read at build, so a
  /// message typed mid-operation takes effect on the next rebuild.
  bool get _cwMessagesConfigured {
    final settings = widget.services.settings;
    if (!settings.experimentEnabled('gato') /* stored key, see experiments.yaml */) return false;
    if (!settings.experimentEnabled('keyer') /* stored key, see experiments.yaml */) return false;
    for (var n = 1; n <= SettingsService.cwMessageCount; n++) {
      if (settings.cwMessage(n).trim().isNotEmpty) return true;
    }
    return false;
  }

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

  /// Whether this device is sharing its logging state with peers at all —
  /// the experiment, the master switch, and a holder to publish into.
  bool get _peerSharingDrafts =>
      widget.services.settings.experimentEnabled('p2p') /* stored key, see experiments.yaml */ &&
      widget.services.settings.peerSyncEnabled;

  /// Publishes the composed contact to every peer sharing this operation.
  ///
  /// Deliberately NOT debounced the way [_onQsoDraftChanged] is. That
  /// debounce exists to coalesce a keystroke burst into one setState, which
  /// rebuilds three panes here; this one crosses a socket and rebuilds
  /// nothing locally, and the whole value of the panel on the other end is
  /// that it keeps up with the operator. The publisher upstream already
  /// fires at most once per frame per distinct draft.
  /// The header last sent, so a change to it can be noticed. Position and
  /// operator are attached HERE rather than inside the controls, so they are
  /// in neither of the publisher's dedupe keys — without this, running
  /// `POSITION 2` or `OPER` mid-contact moves nothing the publisher compares
  /// and every peer keeps rendering the old header until the next keystroke.
  (String, String)? _lastPeerHeader;

  /// Re-sends the block this device already published, under a header the
  /// operator has just changed. Cheap and rare: only a `POSITION`/`OPER`
  /// write reaches it, and it does nothing until one does.
  void _republishPeerHeaderIfChanged(Operation operation) {
    if (!_peerSharingDrafts) return;
    final drafts = widget.services.peerDrafts;
    final draft = drafts.localDraft;
    if (draft == null || draft.operationUuid != operation.uuid) return;
    final header = _peerHeaderFor(operation);
    if (header == _lastPeerHeader) return;
    _lastPeerHeader = header;
    drafts.publishLocal(PeerQsoDraftPayload(
      qso: draft.qso,
      operationUuid: draft.operationUuid,
      fields: draft.fields,
      position: header.$1,
      operatorCall: header.$2,
    ));
  }

  /// Read fresh every time: the operator can set either from the command bar
  /// mid-contact, and a value captured once when the view mounted would name
  /// the wrong position for the rest of the session.
  (String, String) _peerHeaderFor(Operation operation) => (
        multiIdentifierFor(operation),
        operatorCallFor(operation),
      );

  void _onPeerDraft(Operation operation, Map<String, dynamic> qso, List<PeerDraftField> fields) {
    final header = _peerHeaderFor(operation);
    _lastPeerHeader = header;
    widget.services.peerDrafts.publishLocal(PeerQsoDraftPayload(
      qso: qso,
      operationUuid: operation.uuid,
      fields: [
        for (final field in fields)
          PeerDraftFieldPayload(key: field.key, label: field.label, value: field.value, hint: field.hint),
      ],
      position: header.$1,
      operatorCall: header.$2,
    ));
  }

  /// The QSO being composed, republished from the logging panel for panels
  /// declaring `qso`. Null until one of them is in the arrangement — the
  /// render args then leave `qso` out entirely rather than sending `{}`.
  /// Once one is, this carries the draft even with an empty call: the band
  /// and mode come from the radio, and are worth showing before anything is
  /// typed.
  Map<String, dynamic>? _draftQso;
  Timer? _draftQsoDebounce;

  /// The draft as of the last keystroke — [_draftQso] before the debounce
  /// has let it through. Read by [_sendCwMessage] and [_keyingPhone] only.
  Map<String, dynamic>? _latestDraftQso;

  /// Whether the function keys play voice memories rather than key CW:
  /// the draft's mode is Phone. From the LATEST draft, and handed to the
  /// keyer area as a value, so the keys and the strip answer from one
  /// snapshot — the strip's rebuild still waits for the debounce, but a
  /// build never disagrees with the keys about which keyer it is.
  bool get _keyingPhone => superModeForMode(_latestDraftQso?['mode'] as String?) == 'Phone';

  /// Coalesces the keystroke burst of typing a callsign into one rebuild.
  ///
  /// The panel's own [panelRenderThrottle] already bounds how often it may
  /// cross the bridge, but that is downstream of this view's setState — and
  /// the setState is the expensive half, rebuilding the logging, spots and
  /// map panes alongside the panel that asked. Debounced on the same window,
  /// so a panel sees one draft per pause rather than one per letter.
  void _onQsoDraftChanged(Map<String, dynamic> qso) {
    // Kept as it arrives, ahead of the debounce below: a CW message keyed
    // in the pause the debounce is waiting out must carry the call as typed,
    // not the last draft that settled.
    _latestDraftQso = qso;
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

  /// F1-F8 key the matching CW message through the key in use — or, while
  /// the draft contact is in a Phone mode, play the matching voice memory
  /// of radio1; Escape stops either while it is still going out. Only while
  /// this view is the front-most route — a dialog over it (the message
  /// editors included) owns the keyboard — and only with a radio that can
  /// key (or play), so on a station without one the keys stay free for
  /// whatever else wants them.
  bool _onCwKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (testerOverlayCovering.value) return false;
    if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? false)) return false;
    final services = widget.services;
    // ANY key ends a repeat, before anything else here decides whether this
    // one is the keyer's: an operator typing a call has come back to the
    // radio, and a CQ keying over what they are about to send is the one
    // thing a repeating CQ must never do. Pressing F1 itself lands here
    // first and then arms a fresh chain below.
    services.cat.cancelKeyerRepeat();
    // And the memory on the air goes with it. Typing is the operator working
    // the contact, which a CQ still playing over the top of is worse than a
    // message cut short — so the play is stopped without CLAIMING the key,
    // which belongs to the field being typed into. Escape is left to the
    // handler below: it stops the same play but must also answer `true`, or
    // the same keystroke wipes the logging fields (logging-fields.md).
    // A recording is never touched: it only runs from a dialog, where this
    // handler is not the front route at all.
    final playing = services.cat.voiceActivity.value;
    if (playing != null && !playing.recording && event.logicalKey != LogicalKeyboardKey.escape) {
      services.cat.stopVoice();
    }
    if (!services.settings.experimentEnabled('gato') /* stored key, see experiments.yaml */) return false;
    if (!services.settings.experimentEnabled('keyer') /* stored key, see experiments.yaml */) return false;
    final cat = services.cat;
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isMetaPressed || keyboard.isControlPressed || keyboard.isAltPressed) return false;

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      // Stops a message from wherever focus is. NOT what keeps the logging
      // fields from also wiping on the same keystroke — a handler's answer
      // here never stops the focus tree's dispatch — that is
      // LoggingControls.escapeClaimed, wired in logging_panel.dart. With
      // nothing to stop, Escape keeps its usual meaning. Ahead of the
      // capability gate below, and for either keyer whatever the mode: a CW
      // message keyed just before the draft went to SSB is still the one
      // to stop, on a station whose radio plays no voice at all.
      if (cat.voiceActivity.value != null) {
        cat.stopVoice();
        return true;
      }
      if (!cat.cwSending) return false;
      cat.stopCw();
      return true;
    }

    // The DRAFT's mode decides — [_keyingPhone], the same answer the keyer
    // area is built with: the message is for the contact being logged,
    // whatever the rig sits in.
    final phone = _keyingPhone;
    if (phone ? !cat.canPlayVoice : !cat.canKeyCw) return false;

    final n = cwMessageIndexForKey(event.logicalKey);
    if (n == null) return false;
    if (phone) {
      // A key past the radio's last memory keys nothing, and stays free.
      if (n > cat.voiceMemoryCount) return false;
      // A recording is not interrupted by a play: the dialog disables its
      // buttons while one runs, and a key must not do what a button cannot
      // — on a K4 the recording would be lost unsaved.
      if (cat.voiceActivity.value?.recording ?? false) return true;
      cat.playVoiceMemory(n);
      return true;
    }
    final template = services.settings.cwMessage(n);
    if (template.trim().isEmpty) return false;
    unawaited(_sendCwMessage(n, template));
    return true;
  }

  /// The keyer area's message buttons: the same send the function keys make.
  void _sendCwMessageNumber(int n) {
    final template = widget.services.settings.cwMessage(n);
    if (template.trim().isEmpty) return;
    unawaited(_sendCwMessage(n, template));
  }

  /// A message other than 1 ends a repeat: the operator has moved on to the
  /// exchange, and message 1 is a CQ nobody wants keyed over it. Called
  /// where the keyer area's buttons arrive, since a tap reaches no key
  /// handler.
  void _sendCwMessageFromArea(int n) {
    if (n != 1) widget.services.cat.cancelKeyerRepeat();
    _sendCwMessageNumber(n);
  }

  /// Renders message [n]'s template against the operation and the draft
  /// contact (the same context a panel gets — docs/extensions/templates.md),
  /// then hands the text to the radio. A template that does not parse is
  /// the operator's own typo, shown where they will see it rather than sent
  /// as-is with the braces keyed out in Morse.
  Future<void> _sendCwMessage(int n, String template) async {
    final services = widget.services;
    final ctx = panelRenderContext;
    String? text;
    String? failure;
    try {
      text = await services.extensions.renderTemplate(
        template,
        operation: ctx.operation == null ? null : operationHookArgs(ctx.operation!),
        qso: _latestDraftQso ?? ctx.qso,
        qsoCount: ctx.qsoCount,
      );
    } on TemplateError catch (e) {
      failure = e.message;
    } catch (e, st) {
      // A hook timeout or a dead runtime — reported, and ALSO said here:
      // the operator pressed a key and nothing keyed, which the console
      // alone would leave them to discover on the air.
      ErrorReportingService.report(e, st, context: 'cw:render-message');
      failure = '$e';
    }
    // Leaving the operation while the render was in flight is leaving the
    // message behind too — nothing goes on the air from a view that is gone.
    if (!mounted) {
      services.cat.cancelKeyerRepeat();
      return;
    }
    if (failure != null) {
      services.statusBar.showNotice(
        key: 'cw-message-$n',
        icon: 'alert-circle-outline',
        text: context.t.commands.cwMessageError(n: n, error: failure),
        persist: false,
      );
      services.cat.cancelKeyerRepeat();
      return;
    }
    if (text == null) {
      // No runtime to render with (restarting, or failed to load): a key
      // that keys nothing must not look like a key that worked.
      services.statusBar.showNotice(
        key: 'cw-message-$n',
        icon: 'alert-circle-outline',
        text: context.t.commands.cwMessageNotRendered(n: n),
        persist: false,
      );
      services.cat.cancelKeyerRepeat();
      return;
    }
    // A chain waits for the message to STOP keying before its next send, so
    // a send that keys nothing — a failed render, a dead runtime, a message
    // that sanitizes away, a radio gone between repeats — would leave it
    // armed with nothing to end it, and the keyer area showing neither
    // buttons nor a countdown.
    if (text.trim().isEmpty) {
      services.cat.cancelKeyerRepeat();
      return;
    }
    services.cat.sendCw(text);
    // Nothing keying after the send is a message the queue dropped (empty
    // once sanitized) or a radio that went away — either way there is no end
    // coming to start the next wait on.
    if (!services.cat.cwSending) {
      services.cat.cancelKeyerRepeat();
      return;
    }
    // Message 1 only — see SettingsService.cwRepeatDelay. Armed after the
    // send, so the wait starts from the message ENDING rather than from the
    // keypress.
    final delay = services.settings.cwRepeatDelay;
    if (n == 1 && delay > Duration.zero) {
      services.cat.armKeyerRepeat(delay: delay, text: text, send: () => _sendCwMessageNumber(1));
    }
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
    HardwareKeyboard.instance.removeHandler(_onCwKeyEvent);
    widget.services.settings.removeListener(_onSettingsChanged);
    widget.services.extensions.runtimeGeneration.removeListener(_onRuntimeGenerationChanged);
    // Only clear if it's still ours — a newer OperationView may have taken over.
    if (DevBridge.instance.stateProvider == _devBridgeState) {
      DevBridge.instance.stateProvider = null;
    }
    // This device stops being a position in the operation it is leaving.
    // Nothing else says so: a peer learns a position is gone from its session
    // dropping, and this device's session is still up.
    widget.services.peerDrafts.clearLocalFor(widget.operationUuid);
    _operationSub?.cancel();
    _rescoreSub?.cancel();
    _rescoreDebounce?.cancel();
    _draftQsoDebounce?.cancel();
    _tabController?.dispose();
    _spotsVisible.dispose();
    _sheetHeaderLines.dispose();
    widget.services.closeOperationContext(_commandContext);
    _unsubscribeSpots?.call();
    widget.services.spots.removeListener(_onSpotsChanged);
    // "Listen for other apps" stops routing captures here once this view
    // closes — but only if THIS operation is still the one receiving; a
    // second OperationView may have taken over already. Unconditional,
    // deliberately: gating this on `listenForOtherAppsEnabled` looks free
    // but isn't safe — turning the setting off does not clear
    // `receivingOperationUuid` (only starts/stops the sockets), so a stale
    // receiver would survive past this view's close and later silently
    // catch captures meant for whatever operation is open when listening
    // is turned back on. Constructing `inboundQsos` here costs a cheap
    // object and one listener registration — worth it for correctness.
    widget.services.inboundQsos.stopReceivingFor(widget.operationUuid);
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

  /// Whether the last [_refreshLoggingControls] fetch failed — read by
  /// [_onRuntimeGenerationChanged] so a generation tick unrelated to any
  /// pending mismatch (any extension anywhere getting toggled restarts the
  /// whole runtime) doesn't cost every open operation a round trip for
  /// nothing.
  bool _loggingControlsStale = false;

  Future<void> _refreshLoggingControls(Operation operation) async {
    final requestId = ++_loggingControlsRequestId;
    final result = await widget.services.extensions.loggingControls(operation.data);
    if (!mounted || requestId != _loggingControlsRequestId) return;
    // A fetch that failed says nothing about what the activities want, so the
    // panel keeps what it is already showing rather than blanking a live
    // logging panel because the runtime happened to be restarting.
    //
    // A REF CHANGE is what usually re-runs this, so a failure here is
    // typically a set that no longer matches the operation — the contest
    // just added has no exchange field, the POTA ref just removed still has
    // one. `_onRuntimeGenerationChanged` below is what corrects it once the
    // runtime that was restarting comes back up; without that retry, nothing
    // would until the operation is reopened. Keeping the mismatch quiet in
    // the meantime would leave the operator staring at the wrong fields with
    // no account of why, which is the whole defect this change exists to end.
    _loggingControlsStale = result.loadFailed;
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

  /// Retries [_refreshLoggingControls] once the extension runtime is live
  /// again, but only when the last fetch actually failed — every runtime
  /// restart (any extension anywhere being toggled) ticks the generation,
  /// and most of those have nothing to do with this operation.
  void _onRuntimeGenerationChanged() {
    if (!_loggingControlsStale) return;
    // `_draftOperation`, not just `_operation` — the Activities/Setup sheet
    // can still be open with a ref the operator just added, and refreshing
    // against the committed, ref-less operation instead would overwrite the
    // draft's own controls with the wrong set.
    final operation = _draftOperation ?? _operation;
    if (operation == null) return;
    unawaited(_refreshLoggingControls(operation));
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
    // Profile first, because the operation write is the one that can fail:
    // `WritePolicy` refuses it on a travelled clock, and an operation created
    // while travelling is born `/TEST`, so the very callsign this prompt
    // exists to collect is one the gate declines to store. Sequencing the
    // operation first would take the profile write down with it and leave the
    // operator with neither.
    await widget.services.setOperatorCall(result);
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
  }

  /// Tap on the compact call-info area: on wide layouts the detail
  /// already lives on the Info tab, so just surface it; on narrow, open it as a
  /// modal (which re-reads the latest `_callInfo` on rebuild via the modal's
  /// own key, so live updates flow through while it's open).
  Future<void> _handleCallInfoTap(Operation operation) async {
    if (_revealInfoPane()) return;
    final info = _callInfo;
    if (info == null) return;
    await showModalPane<void>(
      context,
      title: info.call,
      closeLabel: context.t.common.close,
      // The panel is a ListView and scrolls itself; wrapped in the pane's own
      // scroll view it would sit in unbounded height and lay out blank.
      scrollable: false,
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

  /// On wide layouts the Info pane is already in the layout — surface it and
  /// let it show whatever it shows. Answers whether it actually did: a custom
  /// layout the operator has dropped the Info pane out of has nothing to
  /// reveal (`revealModule` no-ops on a module that isn't there), and a tap
  /// that stops here would spend its splash on nothing. Saying so lets the
  /// caller fall back to the modal, which always works.
  bool _revealInfoPane() {
    // Asked of the dock first, at either width: the narrow arrangement ships
    // without an Info pane but the operator may have added one, and `modules`
    // is what actually answers that — a width test would refuse a pane that
    // is on screen.
    if (_customLayout) {
      final dock = dockKey.currentState;
      if (dock == null || !dock.modules.contains('info')) return false;
      dock.revealModule('info');
      return true;
    }
    if (!ShirtSize.of(context).isTwoPane) return false;
    if (_tabController == null) return false;
    if (_tabController!.index != 0) _tabController!.animateTo(0);
    return true;
  }

  /// Tap on a day header in the QSO list: the operation's own info — its stats
  /// and scoring, the counterpart to the call-info area standing for the
  /// contact. Same two presentations as [_handleCallInfoTap], and the same
  /// consequence on wide: the Info pane shows what it shows, which is the
  /// call detail while one is being composed. The modal, which is this tap's
  /// own, is the stats unconditionally.
  Future<void> _handleOperationInfoTap(Operation operation, List<Qso> qsos) async {
    if (_revealInfoPane()) return;
    await showModalPane<void>(
      context,
      // The operation, the way the Call Info modal is titled with the call —
      // `InformationPanel` heads its own body "Operation Stats", so naming
      // the pane that too would say it twice.
      title: displayTitleFor(context, operation),
      closeLabel: context.t.common.close,
      // See the Call Info modal above — InformationPanel is a ListView too.
      scrollable: false,
      builder: (_) => InformationPanel(
        operation: operation,
        qsos: qsos,
        services: widget.services,
        ourEntityPrefix: _ourEntityPrefix,
        activityControls: _loggingControls,
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

    // Captured so the `finally` block below can arm a defensive fallback
    // against this specific animation object — see its own comment.
    Animation<double>? sheetAnim;
    try {
      await showTopModalPane<void>(
        context,
        onAnimation: (anim) {
          sheetAnim = anim;
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
        // Narrow has no card edge to line the accept button up with (the
        // pane is full-bleed there), and the control it stands in for — the
        // header's own chevron — has faded out of that corner, so it takes
        // the corner itself rather than sitting indented behind nothing.
        // Only the native window controls still get their room.
        narrowLeftInset: _narrowSheetLeftInset(context),
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
            // in at full size — same _sheetHandoffThreshold cutoff the dots
            // fade out by (see _FallingDotsPainter), so the two read as one
            // handoff rather than two unrelated motions layered on each
            // other.
            builder: (context, child) {
              final growth = ((_sheetAnimation?.value ?? 1.0) / _sheetHandoffThreshold).clamp(0.0, 1.0);
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
        // Live copies of the AppBar's own X and Options/Export, reachable
        // above the barrier the same way the accept button is — the real
        // ones fade out and stop taking taps in step with this (see the
        // AppBar's own `leading`/`actions`). Each closes the sheet before
        // applying its own action, rather than just dismissing it the way an
        // ordinary barrier tap does: the operator tapped a specific control,
        // not empty space, so it should do what it says.
        //
        // Both copies stay put, exactly over the real ones they stand in
        // for — nothing in this header moves because a sheet opened.
        // `SizedBox` sizes this to the full header width so each can
        // `Positioned` itself within it independently.
        // Only the chevron has a copy up here. The operation's own
        // Exports/Imports/Tools group — and the layout controls beside it —
        // stay exactly where they are in the AppBar below, untouched and
        // merely disabled while the sheet is up (see the AppBar's own
        // `actions`), so nothing about that end of the header moves,
        // recolours or duplicates itself around a sheet. The chevron is the
        // exception because something really does replace it: the accept
        // button takes its corner.
        headerTrailing: Builder(
          builder: (context) {
            final isTwoPane = ShirtSize.of(context).isTwoPane;
            final toolbarHeight = Theme.of(context).appBarTheme.toolbarHeight ?? kToolbarHeight;
            return SizedBox(
              width: double.infinity,
              height: toolbarHeight,
              child: ValueListenableBuilder<({String title, String subtitle})?>(
                valueListenable: _sheetHeaderLines,
                builder: (context, pushedLines, _) => AnimatedBuilder(
                  animation: _sheetAnimation ?? const AlwaysStoppedAnimation(1.0),
                  builder: (context, _) {
                    final growth =
                        ((_sheetAnimation?.value ?? 1.0) / _sheetHandoffThreshold).clamp(0.0, 1.0);
                    final lines = pushedLines ?? _headerTitleLines(context, _draftOperation ?? operation);
                    return Stack(
                      children: [
                        // Fades out on the same curve as the real one it stood
                        // in for — the accept button (headerLeading) is the
                        // sheet's dismiss control once it's up, so this doesn't
                        // need to keep offering a second one once that button
                        // has taken over.
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          width: _leadingWidthFor(isTwoPane, context),
                          child: IgnorePointer(
                            ignoring: _headerIconsInert,
                            child: Opacity(
                              opacity: _headerIconsFadeOpacity,
                              // macOSAwareBackButton, not a bare IconButton:
                              // it's the one place that already knows to clear
                              // the traffic lights on a chromeless macOS window.
                              child: Center(
                                child: macOSAwareBackButton(
                                  context,
                                  close: true,
                                  boxSize: 40,
                                  onPressed: () async {
                                    await sheetKey.currentState?.saveAndClose();
                                    if (context.mounted) unawaited(Navigator.of(context).maybePop());
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                        // The trailing row, live, standing exactly over the
                        // inert one in the AppBar — same builder, same children,
                        // so it lines up without measuring anything. This is the
                        // copy that makes Exports/Imports/Tools pressable at
                        // all while the sheet is up; the layout controls come
                        // along disabled, both to match what is underneath and
                        // because they occupy width the actions must clear.
                        //
                        // Opaque is not the same as live: at progress 0 the REAL
                        // row underneath is the one taking taps (see
                        // [_headerIconsInert]), so without the IgnorePointer
                        // this copy would swallow the tap meant for it.
                        Positioned(
                          right: windowsCaptionClearance(context),
                          top: 0,
                          bottom: 0,
                          child: IgnorePointer(
                            ignoring: growth <= 0,
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: _headerTrailingControls(
                                  context,
                                  isTwoPane: isTwoPane,
                                  // The sheet cannot coexist with layout
                                  // editing: the title control that opens it is
                                  // inert while editing, and the layout button
                                  // that would start editing is inert while the
                                  // sheet is up. False is the only value this
                                  // call site can see.
                                  editingHeader: false,
                                  lines: lines,
                                  // Width only — the AppBar's row underneath is
                                  // the one that paints them.
                                  layoutControlsOpacity: 0.0,
                                  onOptions: () async {
                                    final op = _draftOperation ?? operation;
                                    await sheetKey.currentState?.saveAndClose();
                                    if (mounted) {
                                      unawaited(_showOperationOptions(op,
                                          includeExport: !isTwoPane,
                                          includeImport: !isTwoPane,
                                          includeEditLayout: !isTwoPane && _customLayout && !layoutEditing));
                                    }
                                  },
                                  onExport: () async {
                                    final op = _draftOperation ?? operation;
                                    await sheetKey.currentState?.saveAndClose();
                                    if (mounted) unawaited(_export(op));
                                  },
                                  onImport: () async {
                                    final op = _draftOperation ?? operation;
                                    await sheetKey.currentState?.saveAndClose();
                                    if (mounted) unawaited(_import(op));
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(right: 0, top: 0, bottom: 0, child: Center(child: windowsCaptionSpacer(context))),
                      ],
                    );
                  },
                ),
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
            // Refs are the only input the title (and the logging row's
            // activity fields) are built from, so nothing else in the draft
            // is worth a hook fan-out.
            //
            // The build method reads `_draftOperation ?? _operation`, so the
            // LoggingPanel below sees a ref the operator just added
            // immediately — but its `activityControls` (the descriptor that
            // actually makes the field render) only ever refreshes off the
            // COMMITTED operation, via `_onOperationChanged`'s own ref-diff.
            // A draft edit never reaches the database until the sheet
            // closes, so without this call that hook never fires for it: the
            // ref shows on the operation but the field it should turn on
            // stays missing until something else (any unrelated cause of
            // `_onOperationChanged` firing, or a per-QSO refresh landing
            // once a callsign is typed) happens to catch it up.
            if (previous == null || !_sameRefs(previous.data['refs'], updated.data['refs'])) {
              unawaited(_retitleDraft(updated));
              unawaited(_refreshLoggingControls(updated));
            }
          },
          onEditDetails: () async {
            final updated = await editOperationDetails(
              context,
              widget.services,
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
                  // The dialog persists local data itself, so the draft takes
                  // what came back rather than keeping its own stale copy.
                  localData: updated.localData,
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
          // Back to the live fallback, so the next open's first frame reads
          // the title that is on screen rather than the one this session
          // left behind (see [_sheetHeaderLines]).
          _sheetHeaderLines.value = null;
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
      // Defensive fallback: the header's own leading/Tools/Export/layout
      // icons stay faded and non-interactive for as long as _sheetAnimation
      // is non-null (see _headerIconsFadeOpacity/_headerIconsInert), and the
      // ONLY path that clears it is onAnimation's statusListener reaching
      // AnimationStatus.dismissed above. If the route is torn down some
      // other way that skips that status (a forcibly reset Navigator, a
      // disposed AnimationController mid-transition), nothing else would
      // ever un-stick those controls. TopModalPaneRoute's own
      // transitionDuration is 600ms; comfortably past that, if this is
      // still the SAME animation onAnimation captured (a newer sheet
      // reopening would have replaced it already), force it null rather
      // than trust a status change that evidently isn't coming.
      final anim = sheetAnim;
      if (anim != null) {
        unawaited(Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted && identical(_sheetAnimation, anim)) {
            debugPrint('[operation] sheet-animation-stuck: dismissed status never fired within the fallback window');
            setState(() => _sheetAnimation = null);
          }
        }));
      }
    }
  }

  Future<void> _resolveOurEntityPrefix(Operation operation) async {
    final ourInfo = await widget.services.extensions.lookupCall(
      // One callsign: the raw field can hold several, and a lookup of
      // "KI2D, W1AW" resolves nothing — leaving the operation with no entity,
      // no ITU region and no country, which the logging controls and the
      // scorers both read.
      operation.stationCalls.first,
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

  Future<void> _import(Operation operation) =>
      showOperationImportPanel(context, services: widget.services, operation: operation);

  /// The header's trailing controls: the operation's own Exports/Imports/
  /// Tools, and the view's layout controls beside them where the dock layout
  /// is live.
  ///
  /// ONE builder for both the AppBar's own row and the copy the setup sheet
  /// draws above its barrier, so the copy stands exactly over what it
  /// replaces by construction — same children, same order, same widths — with
  /// nothing measured and so nothing to go stale. Copying only the actions
  /// and pinning them to the trailing edge would land them over the layout
  /// controls wherever those are present.
  ///
  /// The copy exists because the real row cannot be pressed while a modal
  /// route is up (see [TopModalPaneRoute.headerTrailing]), and the
  /// operation's actions should still work. The layout controls should not,
  /// so they carry their own inert treatment here, in the shared builder,
  /// rather than at either call site.
  ///
  /// [layoutControlsOpacity] is which of the two rows actually PAINTS those
  /// controls. Both must hold them — they are width the actions have to
  /// clear, and dropping them from one row would misalign it — but the rows
  /// sit exactly on top of each other over an undimmed header, so painting
  /// both at Material's disabled 0.38 composites to about 0.62 and reads as
  /// merely faint. The copy passes 0 and keeps only the space.
  List<Widget> _headerTrailingControls(
    BuildContext context, {
    required bool isTwoPane,
    required bool editingHeader,
    required ({String title, String subtitle}) lines,
    required double layoutControlsOpacity,
    required VoidCallback onOptions,
    required VoidCallback onExport,
    required VoidCallback onImport,
  }) =>
      [
        // Operation-level actions, not scoped to the setup sheet: an operator
        // reaches for Options/Export without necessarily opening it. Gone
        // during layout editing along with the rest of the operation's own
        // identity in this header — nothing about the operation is what's
        // being arranged then. Narrow keeps only the gear — there isn't room
        // for a second icon beside the title — with Export Logs folded into
        // its menu instead of dropped.
        if (!editingHeader)
          _operationHeaderActions(
            context,
            isTwoPane: isTwoPane,
            headerTitle: lines.title,
            headerSubtitle: lines.subtitle,
            onOptions: onOptions,
            onExport: onExport,
            onImport: onImport,
          ),
        // Narrow gives the way IN to the Tools menu (see
        // [_showOperationOptions]) — the header there has room for the title
        // and one button, and the operation's own title has the better claim.
        // Once editing, the controls come back here at every width: a menu is
        // not somewhere to hide the only way out of a mode.
        if (_customLayout && (isTwoPane || layoutEditing)) ...[
          // The LAYOUT sheet draws its own copy of these while IT is up; two
          // would be one too many, and the one down here would be the
          // unreachable one.
          if (!layoutSheetOpen) ...[
            // Separates it from Exports/Tools rather than the two groups
            // sitting flush — they act on different things (the operation vs.
            // the view's own arrangement), and nothing about a labeled
            // TextButton.icon's own padding guarantees a gap here the way a
            // plain IconButton's did.
            if (!editingHeader) const SizedBox(width: Space.md),
            IgnorePointer(
              ignoring: _headerIconsInert,
              child: Opacity(
                opacity: layoutControlsOpacity,
                child: Row(mainAxisSize: MainAxisSize.min, children: layoutHeaderControls(context)),
              ),
            ),
          ],
        ],
      ];

  /// The header's two title lines as the sheet's copy of the trailing
  /// controls last saw them (headerTrailing in [_openOperationSheet]).
  ///
  /// That copy lives in the sheet's route rather than in this build, and its
  /// own AnimatedBuilder stops ticking once the sheet is open and still — so
  /// adding or removing an activity, which retitles the operation under it,
  /// reaches it through nothing else. Without this it keeps the label fit it
  /// was built with (see [_headerActionsFitLabels]) while the title it was
  /// measured against changes width, and the copy and the row underneath it
  /// disagree about their own size.
  ///
  /// Pushed from a post-frame callback rather than mid-build, where
  /// notifying a listener would rebuild the route's subtree during this
  /// one's build.
  final _sheetHeaderLines = ValueNotifier<({String title, String subtitle})?>(null);

  /// The two lines the header's title control shows for [operation]. One
  /// derivation, read both by the control itself and by
  /// [_headerActionsFitLabels] — a second copy of this would let the labels
  /// be weighed against a title other than the one on screen.
  ///
  /// The ref-derived subtitle only exists once OperationTitleService has run
  /// at least once; until then it falls back to the raw ref labels so the
  /// header isn't blank.
  ({String title, String subtitle}) _headerTitleLines(BuildContext context, Operation operation) {
    final suggested = displaySubtitleFor(operation);
    return (
      title: '${headerCallsignFor(operation)} ${displayTitleFor(context, operation)}',
      subtitle: suggested.isNotEmpty
          ? suggested
          : operation.refs.map((r) => r['shortLabel'] ?? r['ref']).whereType<String>().join(' • '),
    );
  }

  /// The falling-dots control's own footprint in the title row — the width
  /// the leading gap rests at while the sheet is closed.
  static const double _headerDotsWidth = 10.0;

  /// A labeled header button's own chrome beyond the 48 logical pixels an
  /// icon-only IconButton spends on the same icon — TextButton.icon's
  /// start/end padding and the gap it sets between icon and label.
  /// Approximate on purpose: it decides only WHERE the labels drop out, and
  /// being a few pixels off moves that point rather than breaking anything.
  static const double _headerLabelChrome = 12.0;

  /// The same measure for the sheet's accept button, which is a
  /// FilledButton.icon rather than a TextButton.icon and carries the heavier
  /// M3 padding of one. Separate from [_headerLabelChrome] because reusing
  /// that one under-counts this button by enough to keep labels at widths
  /// that cannot hold them — the exact failure the fit exists to prevent.
  static const double _acceptButtonChrome = 28.0;

  /// The title control's own insets: the padding either side of the text
  /// plus the dots slot and the gap after it (see the AppBar's `title`
  /// below). Derived rather than typed, so a change to [Space] or to the
  /// dots cannot silently drift the point at which labels drop out. Narrow
  /// drops the left inset, as the title control itself does.
  double _headerTitleChrome(bool isTwoPane) =>
      (isTwoPane ? Space.xs : 0) + _headerDotsWidth + Space.xs + Space.lg;

  /// Whether the header's Exports/Imports/Tools group can afford to carry
  /// its labels.
  ///
  /// The group and the operation's own title share one header, so what the
  /// labels add over the icon-only group comes out of whatever the title
  /// does not need. Measured rather than pinned to a shirt size: the title
  /// runs as long as the operator's callsign, title and refs happen to make
  /// it, and the labels as long as the locale's words, so no fixed width is
  /// the right answer for both — an S window with a short title has room a
  /// wide one with a long title does not.
  ///
  /// The title's NATURAL width is what it is weighed at. It can survive on
  /// less (shrinkToFitText takes it to 75% before ellipsizing), but that
  /// headroom is there for a title too long for the header at any label
  /// setting — spending it to buy labels would shrink the operation's own
  /// name to pay for a word that repeats an icon.
  bool _headerActionsFitLabels(
    BuildContext context, {
    required bool isTwoPane,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    final t = context.t.activitiesView;
    final titleStyle = theme.appBarTheme.titleTextStyle ?? theme.textTheme.titleLarge ?? const TextStyle();
    final subtitleStyle = theme.textTheme.labelMedium ?? const TextStyle();
    final labelStyle = theme.textTheme.labelLarge ?? const TextStyle();

    // What the header gives up to the setup sheet's accept button while the
    // sheet is up ([_leadingGapWidth] widens the title's leading gap to it),
    // costed the same way a labeled button above is. Reserved even while the
    // sheet is closed, and derived rather than read off the live button, so
    // this answers the same either way: a decision that swung on the sheet
    // would drop the labels partway through the opening animation and put
    // them back partway through the close, and [_sheetOkButtonWidth] reads
    // null between opens besides.
    final acceptButtonReserve =
        kMinInteractiveDimension + _acceptButtonChrome + textWidth(context, context.t.common.ok, labelStyle);

    final labels = isTwoPane ? [t.exports, t.imports, t.tools] : [t.tools];
    final labelsCost = labels.fold<double>(
      0.0,
      (sum, label) => sum + _headerLabelChrome + textWidth(context, label, labelStyle),
    );

    final titleWanted = math.max(
      textWidth(context, title, titleStyle),
      subtitle.isEmpty ? 0.0 : textWidth(context, subtitle, subtitleStyle),
    );

    // The view's layout controls sit in this same row (see
    // [_headerTrailingControls]) and take width the labels cannot also
    // spend. One button: the three-button editing form only appears while
    // layoutEditing, and that is exactly when these actions are not built at
    // all (`editingHeader`), so it can never coincide with this measurement.
    //
    // Untested, deliberately. [acceptButtonReserve] is charged even with the
    // sheet closed and over-reserves by more than this term is worth, so
    // omitting it only misjudges a band of title widths roughly this button
    // wide, and only while the sheet is open. A test tuned to that band
    // would be measuring the placeholder font's glyph advance more than the
    // arithmetic, and would break on any padding change. It is here because
    // the budget must describe the row it is measuring.
    final layoutControlsWidth = _customLayout && !layoutSheetOpen && (isTwoPane || layoutEditing)
        ? Space.md + kMinInteractiveDimension
        : 0.0;

    final slack = MediaQuery.sizeOf(context).width -
        _leadingWidthFor(isTwoPane, context) -
        acceptButtonReserve -
        windowsCaptionClearance(context) -
        labels.length * kMinInteractiveDimension -
        layoutControlsWidth -
        _headerTitleChrome(isTwoPane) -
        titleWanted;
    return slack >= labelsCost;
  }

  /// (wide only) Export + Tools — shared between the AppBar's own actions and
  /// their live copy in headerTrailing (see _openOperationSheet): same icons,
  /// only the press handlers differ (immediate here, close-the-sheet-first
  /// there). Export leads and Tools trails: Export is
  /// the more frequent reach of the two, and Tools — being the one that's
  /// always there, narrow included — anchors the group's trailing edge
  /// instead of shifting position as Export appears and disappears across
  /// the width breakpoint.
  ///
  /// Which of the three show at all is L's breakpoint: Exports and Imports
  /// are dropped on S, where their only way in is Tools' own menu (see
  /// [_showOperationOptions]'s `includeExport`/`includeImport`).
  ///
  /// Whether they carry LABELS is not a breakpoint at all — see
  /// [_headerActionsFitLabels], which weighs them against the title they
  /// take the room from.
  Widget _operationHeaderActions(
    BuildContext context, {
    required bool isTwoPane,
    required String headerTitle,
    required String headerSubtitle,
    required VoidCallback onOptions,
    required VoidCallback onExport,
    required VoidCallback onImport,
  }) {
    final t = context.t.activitiesView;
    final labeled = _headerActionsFitLabels(
      context,
      isTwoPane: isTwoPane,
      title: headerTitle,
      subtitle: headerSubtitle,
    );
    final onHeader = Theme.of(context).appBarTheme.foregroundColor ?? Theme.of(context).colorScheme.onPrimary;
    Widget headerButton({required IconData icon, required String label, required VoidCallback onPressed}) =>
        labeled
            ? TextButton.icon(
                icon: Icon(icon),
                label: Text(label),
                style: TextButton.styleFrom(foregroundColor: onHeader),
                onPressed: onPressed,
              )
            : IconButton(
                icon: Icon(icon, semanticLabel: label),
                onPressed: onPressed,
              );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isTwoPane) headerButton(icon: MdiIcons.export, label: t.exports, onPressed: onExport),
        if (isTwoPane) headerButton(icon: MdiIcons.import, label: t.imports, onPressed: onImport),
        headerButton(icon: MdiIcons.tools, label: t.tools, onPressed: onOptions),
      ],
    );
  }

  /// The operation-level actions that don't belong in the activities list
  /// itself. Share and Archive are declared but inert — the rows are here so
  /// the menu's shape is settled, and they stay disabled until each has an
  /// implementation behind it. Standalone rather than routed through the
  /// setup sheet: reached both from the AppBar's own Options button (sheet
  /// closed) and from its live copy in headerTrailing (sheet open — see
  /// _openOperationSheet), which closes the sheet first and calls this with
  /// its already-saved draft, so [operation] is always current by the time
  /// this actually shows. Editing details here saves directly either way
  /// (editOperationDetails' own `save: true` default), not through a draft.
  ///
  /// [includeExport] and [includeImport] add Export Logs and Imports as the
  /// top two rows, in that order — the header's own group reads
  /// Exports/Imports left to right, and a menu standing in for it keeps that
  /// order rather than inventing a second one. Narrow layouts drop those
  /// icons from the header for lack of room beside the title, so this menu
  /// is their only way in there; wide layouts keep the icons and leave them
  /// out here rather than offer the same action twice.
  ///
  /// [includeEditLayout] adds Edit Layout after them, on the same terms and
  /// for the same reason: a narrow header has room for the title and one
  /// button, and the operation's own title has the better claim on it. The
  /// controls the edit ITSELF needs — the plus, Discard, Save — stay in the
  /// header at every width, because a menu is not somewhere an operator can
  /// be expected to find the way out of a mode.
  Future<void> _showOperationOptions(
    Operation operation, {
    bool includeExport = false,
    bool includeImport = false,
    bool includeEditLayout = false,
  }) async {
    final t = context.t.activitiesView;
    final theme = Theme.of(context);
    await showHaloDialog<void>(
      context: context,
      builder: (dialogContext) => HaloDialog(
        title: Text(t.toolsTitle),
        // The rows ARE the dialog's content, so they take the shell's list
        // padding: to the card's edges, with their contents inset off the
        // same SettingsList every other list in the app reads.
        list: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (includeExport)
              ListTile(
                leading: const Icon(MdiIcons.export),
                title: Text(t.exportLogs),
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  unawaited(_export(operation));
                },
              ),
            if (includeImport)
              ListTile(
                leading: const Icon(MdiIcons.import),
                title: Text(t.imports),
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  unawaited(_import(operation));
                },
              ),
            if (includeEditLayout)
              ListTile(
                leading: const Icon(MdiIcons.viewDashboard),
                title: Text(context.t.operation.layout.editLayout),
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  startLayoutEditing();
                },
              ),
            ListTile(
              leading: const Icon(MdiIcons.noteEditOutline),
              title: Text(t.operationDetails),
              onTap: () {
                Navigator.of(dialogContext).pop();
                unawaited(editOperationDetails(context, widget.services, operation));
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
            // Past the destructive row on purpose: it is a readout, not an
            // action, so it must not sit between two things the operator
            // taps.
            //
            // Both gate terms, not just the experiment: with peer sync off
            // every row would read "Not connected", and unlike the Settings
            // panel this dialog carries no switch to say that is the reason.
            if (widget.services.settings.peerSyncEnabled &&
                widget.services.settings
                    .experimentEnabled('p2p') /* stored key, see experiments.yaml */) ...[
              SectionHeader(dialogContext.t.settings.peers.pairedDevices),
              LinkedDevicesList(services: widget.services),
            ],
          ],
        ),
        // Every row here closes the menu itself, so this is a way out rather
        // than a confirm — and a dialog without a footer band ends on nothing,
        // which is what sets one apart from the rest.
        cancel: TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(context.t.common.done),
        ),
      ),
    );
  }

  Future<void> _handleCommandAction(String action, [Map<String, dynamic>? params]) =>
      runCommandAction(widget.services, action, params, context);

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
  Widget _buildMapSettingsButton({BuildContext? context}) => buildTargetSettingsButton(
        context ?? this.context,
        target: 'map',
        title: (context ?? this.context).t.operation.menu.mapSettingsTitle,
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

  /// Mirrors the fixed layout of its own class — and is what Restore Defaults
  /// puts back.
  ///
  /// Wide: logging on the left, the rest tabbed on the right. Narrow: one tab
  /// strip of QSOs, Spots and Map, exactly the set the hardcoded narrow
  /// `TabBar` draws, so an operator who never edits sees nothing move. Info is
  /// not in it there either — it is a tap away on the callsign area — but it
  /// is offered by the sheet like any other panel.
  @override
  DockNode buildDefaultDockSpec(DockLayoutClass layoutClass, {bool migrate = true}) =>
      switch (layoutClass) {
        DockLayoutClass.narrow => DockGroup(['logging', 'spots', 'map']),
        DockLayoutClass.wide => DockSplit(Axis.horizontal, [
          DockGroup(['logging']),
          // Selected: Info, matching the fixed wide layout's initial tab.
          DockGroup(['info', 'spots', 'map']),
        ], [2, 1]),
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
    // Registered only with the experiment on, exactly as Remote Screen is: a
    // saved arrangement holding one then falls to the missing-panel
    // placeholder rather than vanishing, and the operator keeps their layout.
    if (widget.services.settings.experimentEnabled('p2p') /* stored key, see experiments.yaml */) {
      service.registerNative(PanelDefinition(
        id: 'positions',
        title: t.positions.panelTitle,
        description: t.positions.panelDescription,
        icon: 'accountGroup',
        source: PanelSource.native,
        views: const {PanelViews.operation},
      ));
    }
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
          builder: (context) => KeyboardAccessoryVisibility(
            visible: DockPaneVisibility.of(context),
            child: loggingPanel,
          ),
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
            ourEntityPrefix: _ourEntityPrefix,
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
      extraChildren: (inLayout) => sharedDashboardPanes(
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
        final headerLines = _headerTitleLines(context, operation);
        final refsLine = headerLines.subtitle;
        // The only thing that tells the sheet's copy of the trailing
        // controls that the title moved under it — see [_sheetHeaderLines].
        if (_activeSheetKey != null && _sheetHeaderLines.value != headerLines) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _activeSheetKey != null) _sheetHeaderLines.value = headerLines;
          });
        }

        final isTwoPane = ShirtSize.of(context).isTwoPane;
        // Which arrangement the dock draws — assigned before anything below
        // reads the mixin's spec, options or state, all of which resolve
        // through it.
        dockLayoutClass = isTwoPane ? DockLayoutClass.wide : DockLayoutClass.narrow;

        // Edit mode as the HEADER sees it. `layoutEditing` alone is not
        // enough: Save and Discard are only emitted where there is an
        // arrangement to edit, so a header that dresses itself for editing on
        // any wider condition strands the operator the moment there is none —
        // the dock gone, the operation's own title and setup route replaced by
        // a view name, and nothing on screen to end the edit with. With
        // customization off that is exactly what a narrow window is, since the
        // fixed `TabBar` is what it draws instead.
        final editingHeader = layoutEditing && _customLayout;

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
            onSendCwMessage: _sendCwMessageFromArea,
            cwTemplateContext: panelRenderContext,
            keyingPhone: _keyingPhone,
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
            dxFlags: _dxFlags,
            ourEntityPrefix: _ourEntityPrefix,
            ourItuRegion: _ourItuRegion,
            ourCountryCode: _ourCountryCode,
            suggestedQso: _suggestedQso,
            suggestedQsoIsTentative: _suggestedQsoIsTentative,
            suggestionSettledSerial: _suggestionSettledSerial,
            onCallEdited: _onCallEdited,
            // Gated like the drafts: with sharing off the panel's own fallback
            // is the same answer, and touching the field would construct the
            // peer service on an install that never turned the experiment on.
            serialNumbers: _peerSharingDrafts ? widget.services.serialClaims : null,
            logRequest: _logRequest,
            confirmLogOverwrite: _confirmLogOverwrite,
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
            //
            // A CW message counts too: `{{ qso.call }}` in one is rendered
            // against this draft (`_sendCwMessage`), and with nothing else
            // asking for it F1 would key the message with the call blank.
            // And the voice keyer: its MODE is the draft's (`_keyingPhone`),
            // so with nothing tracking the draft F1 in SSB would fall
            // through to a CW keyer that keys nothing, silently.
            onQsoChanged: _anyPanelWants('qso') || _anyPanelWants('lookup') || _cwMessagesConfigured || _voiceKeyingPossible
                ? _onQsoDraftChanged
                : null,
            // Peer sharing is its own reason to publish, independent of the
            // layout: the panel that reads this lives on ANOTHER device, so
            // gating it on what a panel here declares would leave a position
            // invisible to its peers whenever nothing local happened to want
            // a draft. Null while sharing is off, which is what keeps the
            // whole path off the keystroke route.
            onPeerDraftChanged:
                _peerSharingDrafts ? (qso, fields) => _onPeerDraft(operation, qso, fields) : null,
            onCallInfoTap: () => _handleCallInfoTap(operation),
            onOperationInfoTap: () => _handleOperationInfoTap(operation, qsos),
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
                onWithdrawSuggestion: _withdrawSuggestedQso,
                onSuggestionSettled: _suggestionSettled,
                closeSlidesSerial: _closeSlidesSerial,
                onLogQso: _logQsoFromSpot,
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
                geoshapes: widget.services.geoshapes,
                // The same list the Information panel is given, so a
                // reference's outline here wears the color its own row wears
                // everywhere else.
                activityControls: _loggingControls,
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
          // The map's half of the same problem the logging panel has above,
          // and the reason it needs telling at all: `_LazyTab` keeps the pane
          // alive behind the other tabs, where it is neither laid out nor
          // painted, so its webview cannot render and cannot report ready.
          // Left unsaid, the pane reads the absence of a frame it was never
          // going to get as a map that failed to load. The dock arrangement
          // publishes this for itself; this is the fixed one's half.
          ListenableBuilder(
            listenable: _tabController!,
            builder: (context, child) => DockPaneVisibility(
              visible: _tabController!.index == _kMapTabIndex,
              child: child!,
            ),
            child: mapPanel,
          ),
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
              // A chevron even though this view arrives over the whole window
              // (rail and mark included) with no trail to actually step back
              // along — the control closes it and nothing else. Boxed to
              // match the Options/Export/layout icons across the same header
              // (see macOSAwareBackButton's boxSize doc) rather than filling
              // the leading slot's own larger default.
              //
              // Fades out with the rest of the header's own icons while the
              // sheet is up — the falling dots and the accept button they
              // hand off to (headerLeading in _openOperationSheet) already
              // cover dismissal from that corner, so this one steps aside
              // rather than sitting duplicated beside them.
              leading: IgnorePointer(
                ignoring: _headerIconsInert,
                child: Opacity(
                  opacity: _headerIconsFadeOpacity,
                  child: macOSAwareBackButton(context, close: true, boxSize: 40),
                ),
              ),
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
                // Inert as a whole while the sheet is up: its copy above the
                // barrier (headerTrailing in _openOperationSheet) is the one
                // taking taps then, drawn in this same spot from the same
                // builder. Nothing here moves, fades or duplicates visibly —
                // only the layout controls change, going dim and disabled
                // inside the shared builder.
                IgnorePointer(
                  ignoring: _headerIconsInert,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: _headerTrailingControls(
                      context,
                      isTwoPane: isTwoPane,
                      editingHeader: editingHeader,
                      lines: headerLines,
                      layoutControlsOpacity: _layoutControlsDisabledOpacity,
                      onOptions: () => unawaited(
                        _showOperationOptions(
                          _draftOperation ?? operation,
                          includeExport: !isTwoPane,
                          includeImport: !isTwoPane,
                          includeEditLayout: !isTwoPane && _customLayout && !layoutEditing,
                        ),
                      ),
                      onExport: () => unawaited(_export(_draftOperation ?? operation)),
                      onImport: () => unawaited(_import(_draftOperation ?? operation)),
                    ),
                  ),
                ),
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
                          width: _leadingGapWidth(context, isTwoPane: isTwoPane),
                          height: 32,
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: _HeaderDotsControl(
                              progress: _sheetAnimation?.value ?? 0.0,
                            ),
                          ),
                        ),
                        // Separates the title from whichever control
                        // precedes it — the dots, or the accept button that
                        // grows out of them. Constant, not animated with the
                        // gap above: what that gap corrects for is the
                        // button's own left overhang, not the breathing room
                        // after it, which both states want the same.
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
                                    : headerLines.title,
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
              // The dock draws its own tab strip in both classes, so this
              // one is only for the fixed narrow arrangement — the one
              // `layoutCustomization` off still gets.
              bottom: isTwoPane || _customLayout ? null : _narrowTabBar(realQsoCount, qsos),
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
            child: _customLayout
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
    final opacity = (1.0 - progress / _sheetHandoffThreshold).clamp(0.0, 1.0);
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
  // The main VFO specifically — a rig connected in the shack but not driving
  // the panel is not going to be retuned by this suggestion either. A PEER's
  // rig is: an operator's move reaches it as `catSet`, so leaving it out
  // would tune it exactly zero beat, which is what this prevents.
  return offsetter.apply(
    qso,
    enabled: true,
    radioConnected: services.radio1IsLive,
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

