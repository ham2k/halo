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
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../config/dev_bridge.dart';
import '../main.dart';
import '../services/settings_service.dart';
import 'operation_dialogs.dart';
import 'operation/activities_view.dart';
import 'operation/call_info_panel.dart';
import 'operation/information_panel.dart';
import 'operation/logging_panel.dart';
import 'operation/map_panel.dart';
import 'operation/operation_export_screen.dart';
import 'operation/spots_panel.dart';
import '../tools/operation_title.dart';
import '../i18n/strings.g.dart';

class OperationView extends StatefulWidget {
  /// The Operation view is the (currently only) layout-customizable view
  /// (docs/design/layouts.md): its panes are dock-arrangeable behind the
  /// 'layouts' experiment, and ALL its dividers — the fixed split's and the
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
// against, and what resizing across the breakpoint used to trip.
class _OperationViewState extends State<OperationView> with TickerProviderStateMixin {
  Operation? _operation;
  List<Map<String, dynamic>> _loggingControls = const [];
  late bool _showRSTFields = widget.services.settings.showRSTFields;
  late bool _showStateField = widget.services.settings.showStateField;
  late bool _showGridField = widget.services.settings.showGridField;
  late bool _showDeletedQSOs = widget.services.settings.showDeletedQSOs;
  late bool _showQsoNumbers = widget.services.settings.showQsoNumbers;

  /// Gate for the drag-and-drop dock layout (DESIGN.md §7), replacing the
  /// wide arrangement's fixed split-plus-tabs with a user-arrangeable
  /// [DockLayoutView]. Narrow layouts are unaffected. Driven by the
  /// 'layouts' experiment (EXP LAYOUTS, or Settings → Developer →
  /// Experiments) — [_onSettingsChanged] keeps it live so toggling the
  /// experiment re-arranges an open operation without a restart.
  late bool _customLayout = widget.services.settings.experimentEnabled('layouts');

  /// Programmatic tab selection inside the dock layout (revealModule) — the
  /// dock-mode counterpart of `_tabController.animateTo`.
  final _dockKey = GlobalKey<DockLayoutViewState>();

  /// The dock arrangement, resolved from settings (or the default) ONCE —
  /// DockLayoutView copies its initialSpec into its own State on first
  /// build and ignores it afterward, so re-parsing the persisted JSON every
  /// build would be pure waste on this hot path. Kept in sync with the
  /// widget's mutations via onSpecChanged.
  DockNode? _dockSpec;

  /// The station's own DXCC entity, resolved once per operation load (not
  /// per QSO — the station call essentially never changes DXCC entity
  /// mid-operation) so the QSO row can tell a DX contact from a domestic
  /// one. `online: false` skips network lookup hooks (QRZ/HamDB), running
  /// only the local, no-network callsign-annotation step that's all this
  /// needs — see extensions/core/lookups/src/annotate.ts.
  String? _ourEntityPrefix;

  /// Cached QSO stream. Recreating `watchForOperation` inside `build` made a
  /// fresh drift query on every rebuild — a menu toggle, a `_loggingControls`
  /// arrival, an entity-prefix resolve, a rescore refresh — each tearing
  /// down and re-running the whole query. Keyed on `_showDeletedQSOs`, the
  /// only input that changes during the view's life (the uuid is fixed).
  Stream<List<Qso>>? _qsoStream;
  bool? _qsoStreamIncludesDeleted;
  Operation? _draftOperation;

  /// The open sheet's own slide animation, or null when no sheet is up —
  /// what [_HeaderGrabHandle] animates against, so the handle moves WITH the
  /// pane instead of guessing at its timing. Null again the moment the pane
  /// is gone, which is the handle's cue to bounce back.
  final ValueNotifier<Animation<double>?> _sheetAnimation = ValueNotifier(null);

  /// The draft's ref-derived title fragments, suggested but deliberately not
  /// cached (the draft has no saved row to cache into) — null until the first
  /// suggestion for the current draft lands, at which point the header stops
  /// using the saved row's now-stale cache. Same generation-counter guard as
  /// OperationTitleService: an older, slower fan-out must not overwrite a
  /// newer one's result.
  OperationTitleFragments? _draftTitleFragments;
  int _draftTitleGeneration = 0;

  /// Re-suggests the header title for the sheet's buffered draft. Fire-and-
  /// forget, like the saved-row retitle — the title is a display enhancement,
  /// so a failed or superseded run just leaves the previous one showing.
  Future<void> _retitleDraft(Operation draft) async {
    final generation = ++_draftTitleGeneration;
    final fragments = await widget.services.operationTitles.suggestFragments(draft);
    if (!mounted || fragments == null || generation != _draftTitleGeneration) return;
    setState(() => _draftTitleFragments = fragments);
  }

  /// The operation header, with the grab pill painted ON TOP of the toolbar
  /// row rather than inside `flexibleSpace` — AppBar stacks flexibleSpace
  /// BEHIND the title, so the pill (and the opaque plate meant to keep a long
  /// subtitle clear of it) ended up under the very text it needed to mask.
  /// The pill still anchors to the toolbar's own bottom edge, so a tab bar
  /// attached below doesn't drag it down with it (issue #266).
  PreferredSizeWidget _headerWithGrabHandle(
    BuildContext context, {
    required AppBar appBar,
    required VoidCallback onGrabTap,
  }) {
    final theme = Theme.of(context);
    return PreferredSize(
      preferredSize: appBar.preferredSize,
      // Clip.none so the pill can hang below the header's own bounds — see
      // the translate below.
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          appBar,
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: theme.appBarTheme.toolbarHeight ?? kToolbarHeight,
            child: Align(
              alignment: Alignment.bottomCenter,
              // The 5px clearance from the toolbar's own bottom edge that the
              // original bottom:5 offset gave it, then translated DOWN so the
              // pill straddles the header's edge. A translate, not padding,
              // because it must not add to the header's height — the pill
              // floats over what's below rather than pushing it down.
              child: Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Transform.translate(
                  offset: const Offset(0, _headerGrabFloat),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onGrabTap,
                      // Opaque, in the header's own color, so a long subtitle
                      // runs behind the pill instead of through it. Sized by
                      // the pill, so it grows and shrinks with the open/close
                      // animation.
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
                        decoration: BoxDecoration(
                          color: theme.appBarTheme.backgroundColor ?? theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: _HeaderGrabHandle(
                          sheetAnimation: _sheetAnimation,
                          color: theme.colorScheme.onPrimary.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
  /// 'operation-sheet' onboarding flow (issue #348) — same one-shot guard as
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

  void _updateTabControllerIfNeeded(int requiredLength) {
    if (_tabController == null || _tabController!.length != requiredLength) {
      final oldIndex = _tabController?.index ?? 0;
      final previous = _tabController;
      _tabController = TabController(
        length: requiredLength,
        vsync: this,
        initialIndex: oldIndex.clamp(0, requiredLength - 1),
      );
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

  /// The last logging command's output, shown on the Info pane. Lives here
  /// (not in LoggingPanel, which produces it) because on two-pane layouts
  /// the producer and the display are sibling panes.
  String? _commandMarkdown;

  /// The current call-info (issue #40), pushed up from LoggingControls — shown
  /// as the Call Info detail on the Info tab (wide) or a modal (narrow). Same
  /// producer/sibling-pane reasoning as `_commandMarkdown`.
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

  /// Tracks the arrangement across dependency changes so the flip can be
  /// detected BEFORE build (see didChangeDependencies). Null until first
  /// resolved.
  bool? _wasTwoPane;

  void _suggestQso(Map<String, dynamic> qso) {
    setState(() => _suggestedQso = qso);
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isTwoPane = ShirtSize.of(context).isTwoPane;
    // Flipping to narrow, land on the QSOs tab: the logging pane was the
    // always-visible left pane, so it's the natural continuation — and it
    // MUST be the selected tab for its GlobalKey'd subtree to be built (and
    // its State adopted) in the narrow TabBarView's first frame; on any
    // other index, page 0 wouldn't be inflated and the in-progress QSO
    // entry would be disposed.
    if (_wasTwoPane == true && !isTwoPane) _tabController?.index = 0;
    _wasTwoPane = isTwoPane;
  }

  void _onSettingsChanged() {
    final enabled = widget.services.settings.experimentEnabled('layouts');
    if (enabled != _customLayout && mounted) setState(() => _customLayout = enabled);
  }

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
  }

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
    _tabController?.dispose();
    _sheetAnimation.dispose();
    super.dispose();
  }

  void _onOperationChanged(Operation? operation) {
    if (!mounted) return;
    final previous = _operation;
    setState(() => _operation = operation);
    if (operation == null) return;

    // With no profile callsign yet (fresh install — no onboarding flow
    // exists), the callsign editor takes the Activities pane's place:
    // setting an identity comes first.
    if (widget.openActivities && !_openedActivities) {
      _openedActivities = true;
      // Also consumes the independent trigger below for THIS view: a new
      // operation is this view's to handle end to end, including the
      // existing (pre-#348) case where operatorCall is still empty and only
      // the callsign prompt shows, never the sheet — that must stay exactly
      // as it was, not get a second, onboarding-driven attempt to reopen
      // something on a later re-emission of the operation stream.
      _openedOperationSheetOnboarding = true;
      final markOnboardingSeen =
          widget.services.settings.onboardingShownCount(OnboardingFlows.operationSheet) == 0;
      _afterPushTransition(() => _openActivitiesOrPromptForCallsign(operation, markOnboardingSeen: markOnboardingSeen));
    } else if (!_openedOperationSheetOnboarding &&
        widget.services.settings.onboardingShownCount(OnboardingFlows.operationSheet) == 0) {
      // Independent of the new-operation auto-open above (issue #348): the
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
        // Refs are what suggestOperationTitle reads (ham2k/app-halo-dist#174)
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
    // one (ham2k/app-halo-dist#174; there's no ordering guard on the cache
    // write to catch this, unlike the fingerprinted rescore below).
    unawaited(widget.services.operationTitles.retitleOperation(_operation ?? operation));
    // The extension runtime is ready now; a rescore scheduled before it was
    // (which no-op'd) never recorded a fingerprint, so this re-attempts it.
    _maybeScheduleRescore();
  }

  Future<void> _refreshLoggingControls(Operation operation) async {
    final controls = await widget.services.extensions.loggingControls(operation.data);
    if (mounted) setState(() => _loggingControls = controls);
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

  /// Tap on the compact call-info area (issue #40): on wide layouts the detail
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
      closeTooltip: context.t.common.close,
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

  Future<void> _openOperationSheet(Operation operation) async {
    // No manual re-fetch on pop: watchOperation streams the change back.
    // Non-scrollable: the pane's accordion sections divide its height
    // themselves (see activities_view.dart). Not barrier/Escape-dismissible:
    // as a pushed screen this had explicit-back dismissal only, and Escape
    // while typing in the suggestions search would close the whole pane.
    final sheetKey = GlobalKey<OperationSheetState>();
    final hasUpdatesNotifier = ValueNotifier<bool>(false);
    // The pane's header lives in the modal route's own subtree, so this
    // screen's setState never rebuilds it — the draft has to reach it as a
    // listenable or the chips freeze at the values the sheet opened with.
    final draftNotifier = ValueNotifier<Operation>(operation);
    if (!mounted) return;
    setState(() => _draftOperation = operation);
    try {
      await showTopModalPane<void>(
        context,
        closeTooltip: context.t.common.close,
        onAnimation: (animation) => _sheetAnimation.value = animation,
        title: ValueListenableBuilder<Operation>(
          valueListenable: draftNotifier,
          builder: (context, draft, _) {
            final stationCall = draft.stationCall;
            final operatorCall = draft.data['operatorCall'] as String?;
            final operationTitle = draft.title;
            final notes = (draft.data['notes'] as String?) ?? '';

            final theme = Theme.of(context);
            final chipColor = theme.appBarTheme.backgroundColor ?? theme.colorScheme.primary;
            final chipTextStyle = theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
            );
            Widget chip(Widget child) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: chipColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DefaultTextStyle.merge(style: chipTextStyle, child: child),
                );

            return Align(
              alignment: Alignment.centerLeft,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () async {
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
                      draftNotifier.value = _draftOperation!;
                      sheetKey.currentState?.updateOperation(_draftOperation!);
                    }
                  },
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      chip(
                        Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(text: 'Station: '),
                              TextSpan(
                                text: stationCall,
                                style: const TextStyle(fontFamily: 'RobotoMono'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (operatorCall != null && operatorCall.isNotEmpty)
                        chip(
                          Text.rich(
                            TextSpan(
                              children: [
                                const TextSpan(text: 'Op: '),
                                TextSpan(
                                  text: operatorCall,
                                  style: const TextStyle(fontFamily: 'RobotoMono'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // A title is free text and can run long — it ellipsizes
                      // rather than pushing the callsign chips off the header
                      // (or wrapping the whole row onto a second line).
                      if (operationTitle.isNotEmpty)
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 240),
                          child: chip(
                            Text(operationTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      // Notes have no useful short form, so this chip only
                      // says that there ARE notes — the details are one tap
                      // away, in the same operation-details dialog. The icon
                      // rides inside a Text so the chip takes its height from
                      // the same line box as its text-bearing siblings,
                      // rather than from the glyph.
                      if (notes.trim().isNotEmpty)
                        chip(
                          Text.rich(
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              // Nudged up 1px: the glyph's own bearing sits
                              // it slightly low against the text line box
                              // that PlaceholderAlignment.middle centers on.
                              child: Transform.translate(
                                offset: const Offset(0, -1),
                                child: Icon(
                                  resolveIconName('file-document'),
                                  size: 16,
                                  color: theme.colorScheme.onPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        scrollable: false,
        barrierDismissible: true,
        leading: ValueListenableBuilder<bool>(
          valueListenable: hasUpdatesNotifier,
          builder: (context, updates, child) {
            final theme = Theme.of(context);
            final isDark = theme.brightness == Brightness.dark;
            if (updates) {
              return IconButton(
                icon: const Icon(Icons.check),
                tooltip: context.t.common.save,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => sheetKey.currentState?.saveAndClose(),
              );
            } else {
              return IconButton(
                icon: Icon(Icons.check, color: isDark ? Colors.white : Colors.black),
                tooltip: context.t.common.save,
                onPressed: () => sheetKey.currentState?.saveAndClose(),
              );
            }
          },
        ),
        trailing: ValueListenableBuilder<bool>(
          valueListenable: hasUpdatesNotifier,
          builder: (context, updates, child) {
            final theme = Theme.of(context);
            if (updates) {
              return IconButton(
                icon: const Icon(Icons.undo),
                tooltip: context.t.common.cancel,
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.errorContainer,
                  foregroundColor: theme.colorScheme.onErrorContainer,
                ),
                onPressed: () => sheetKey.currentState?.revertAndClose(),
              );
            } else {
              return IconButton(
                icon: Icon(Icons.undo, color: theme.disabledColor),
                tooltip: context.t.common.cancel,
                onPressed: null,
              );
            }
          },
        ),
        builder: (_) => OperationSheet(
          key: sheetKey,
          services: widget.services,
          operation: operation,
          hasUpdatesNotifier: hasUpdatesNotifier,
          onOperationChanged: (updated) {
            if (!mounted) return;
            final previous = _draftOperation;
            setState(() => _draftOperation = updated);
            draftNotifier.value = updated;
            // Refs are the only input the title is built from, so nothing
            // else in the draft is worth a hook fan-out.
            if (previous == null || !_sameRefs(previous.data['refs'], updated.data['refs'])) {
              unawaited(_retitleDraft(updated));
            }
          },
          onExport: () => _export(_draftOperation ?? operation),
          // Close the sheet first: both the confirmation and the pop that
          // follows it belong to this screen, not to the pane stacked over
          // it — and the draft's unsaved edits are moot once it's deleted.
          onDelete: () {
            Navigator.of(context).pop();
            unawaited(_delete(operation));
          },
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _draftOperation = null;
          // Back to the saved row's own cache — which retitleOperation
          // refreshes off the stream if the draft was saved.
          _draftTitleFragments = null;
          _draftTitleGeneration++;
        });
      }
      _sheetAnimation.value = null;
      draftNotifier.dispose();
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
    if (mounted) setState(() => _ourEntityPrefix = ourGuess?['entityPrefix'] as String?);
  }

  Future<void> _delete(Operation operation) async {
    final deleted = await confirmDeleteOperation(context, widget.services, operation);
    if (deleted && mounted) Navigator.of(context).pop();
  }

  Future<void> _export(Operation operation) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OperationExportScreen(services: widget.services, operation: operation),
      ),
    );
  }

  Future<void> _handleCommandAction(String action, [Map<String, dynamic>? params]) =>
      runCommandAction(widget.services, this, action, params);

  /// Flips one of the logging-view menu's toggles: updates the local mirror
  /// (`apply`) so the AppBar menu's checkmark and the widgets below react
  /// immediately, and persists via `persist` so it survives a restart.
  void _toggleMenuSetting({
    required bool current,
    required void Function(bool value) apply,
    required Future<void> Function(bool value) persist,
  }) {
    final value = !current;
    setState(() => apply(value));
    persist(value);
  }

  /// The dock-layout prototype's wide arrangement: the same five panes as
  /// the fixed layout, but arranged by a persisted, user-editable dock tree
  /// (drag a tab to move a pane; see dock_layout.dart). The default mirrors
  /// the fixed layout — logging on the left, the rest tabbed on the right.
  Widget _dockLayout({
    required Widget loggingPanel,
    required Widget infoPanel,
    required Widget spotsPanel,
    required Widget mapPanel,
    required int realQsoCount,
  }) {
    // No 'operation' pane: its settings live in the operation sheet.
    const ids = ['logging', 'info', 'spots', 'map'];
    if (_dockSpec == null || !DockLayoutView.specMatches(_dockSpec, ids)) {
      final persisted = DockNode.fromJson(widget.services.settings.layoutData(LayoutKeys.operationDock));
      _dockSpec = DockLayoutView.specMatches(persisted, ids)
          ? persisted!
          : DockSplit(Axis.horizontal, [
              DockGroup(['logging']),
              // Selected: Info, matching the fixed wide layout's initial tab.
              DockGroup(['info', 'spots', 'map']),
            ], [2, 1]);
    }
    return DockLayoutView(
      key: _dockKey,
      initialSpec: _dockSpec!,
      titles: {
        'logging': context.t.operation.tabs.qsos(count: realQsoCount),
        'info': context.t.operation.tabs.info,
        'spots': context.t.operation.tabs.spots,
        'map': context.t.operation.tabs.map,
      },
      children: {
        'logging': loggingPanel,
        'info': infoPanel,
        'spots': spotsPanel,
        'map': mapPanel,
      },
      onSpecChanged: (node) {
        _dockSpec = node;
        widget.services.settings.setLayoutData(LayoutKeys.operationDock, node.toJson());
      },
    );
  }

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
    final draftFragments = _draftTitleFragments;
    if (_draftOperation != null && draftFragments != null) {
      operation = Operation(
        uuid: operation.uuid,
        data: operation.data,
        qsoCount: operation.qsoCount,
        startAtMillisMin: operation.startAtMillisMin,
        startAtMillisMax: operation.startAtMillisMax,
        localData: {
          ...operation.localData,
          'titleSuggestion': draftFragments.isEmpty
              ? null
              : {
                  'title': draftFragments.title,
                  'for': draftFragments.forText,
                  'at': draftFragments.atText,
                  'subtitle': draftFragments.subtitle,
                },
        },
      );
    }

    return StreamBuilder<List<Qso>>(
      stream: _qsosStream(),
      builder: (context, snapshot) {
        final qsos = snapshot.data ?? const <Qso>[];
        // Start/break/end markers ride the same list (for QsoList to render
        // them inline) but aren't real contacts — every QSO *count* shown to
        // the user excludes them, matching scoring/export.
        final realQsoCount = qsos.where((q) => q.isRealContact).length;
        // The ref-derived subtitle (ham2k/app-halo-dist#174) only exists once
        // OperationTitleService has run at least once — until then, fall
        // back to the raw ref labels so the header isn't blank.
        final suggestedSubtitle = displaySubtitleFor(operation);
        final refsLine = suggestedSubtitle.isNotEmpty
            ? suggestedSubtitle
            : operation.refs.map((r) => r['shortLabel'] ?? r['ref']).whereType<String>().join(' • ');

        final isTwoPane = ShirtSize.of(context).isTwoPane;

        // The pane subtrees, built once and placed by whichever arrangement
        // is active (their GlobalKeys carry the State across a flip).
        final loggingPanel = KeyedSubtree(
          key: _loggingKey,
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
            ourEntityPrefix: _ourEntityPrefix,
            suggestedQso: _suggestedQso,
            onCommandMessageChanged: (message) => setState(() {
              final appeared = message != null && _commandMarkdown == null;
              _commandMarkdown = message;
              // On two-pane layouts the output renders on the Info tab; the
              // old >=900 layout kept it always co-visible with the controls,
              // so surface it when a command starts producing output and
              // another tab is hiding it.
              if (appeared && ShirtSize.of(context).isTwoPane) {
                if (_customLayout) {
                  _dockKey.currentState?.revealModule('info');
                } else if (_tabController?.index != 0) {
                  _tabController?.animateTo(0);
                }
              }
            }),
            onCallInfoChanged: (info) => setState(() => _callInfo = info),
            onCallInfoTap: () => _handleCallInfoTap(operation),
          ),
        );
        final spotsPanel = KeyedSubtree(
          key: _spotsKey,
          child: _KeepAlive(
            child: SpotsPanel(operation: operation, services: widget.services, onSuggestQso: _suggestQso),
          ),
        );
        final mapPanel = KeyedSubtree(
          key: _mapKey,
          child: _KeepAlive(
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
        );
        // ONE construction serving both wide arrangements (fixed tab slot 0
        // and the dock's 'info' module) so their props can't drift apart.
        final infoPanel = InformationPanel(
          operation: operation,
          qsos: qsos,
          commandMarkdown: _commandMarkdown,
          services: widget.services,
          callInfo: _callInfo,
          ourEntityPrefix: _ourEntityPrefix,
        );
        // Wide: Info, Spots, Map — logging has its own pane in the split.
        // Narrow: QSOs first, since logging is what the view is for.
        final List<Widget> tabs = [
          if (!isTwoPane) Tab(text: context.t.operation.tabs.qsos(count: formatNumber(realQsoCount))),
          Tab(text: context.t.operation.tabs.info),
          Tab(text: context.t.operation.tabs.spots),
          Tab(text: context.t.operation.tabs.map),
        ];
        final List<Widget> tabChildren = [
          if (!isTwoPane) _KeepAlive(child: loggingPanel),
          infoPanel,
          spotsPanel,
          mapPanel,
        ];

        _updateTabControllerIfNeeded(tabs.length);

        final tabBar = TabBar(
          controller: _tabController!,
          indicatorSize: TabBarIndicatorSize.tab,
          indicatorWeight: 4,
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
          appBar: _headerWithGrabHandle(
            context,
            onGrabTap: () => _editActivities(operation),
            appBar: AppBar(
              flexibleSpace: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _editActivities(operation),
                child: Stack(
                  children: [
                    if (windowHeaderGestureArea() != null)
                      windowHeaderGestureArea()!,
                  ],
                ),
              ),
              leadingWidth: macOSAwareLeadingWidth(context),
              leading: macOSAwareBackButton(context),
              actions: [
                PopupMenuButton<VoidCallback>(
                  icon: Icon(resolveIconName('dots-vertical')),
                  onSelected: (toggle) => toggle(),
                  itemBuilder: (context) => [
                    CheckedPopupMenuItem<VoidCallback>(
                      checked: _showRSTFields,
                      value: () => _toggleMenuSetting(
                        current: _showRSTFields,
                        apply: (v) => _showRSTFields = v,
                        persist: widget.services.settings.setShowRSTFields,
                      ),
                      child: Text(context.t.operation.menu.showRstFields),
                    ),
                    CheckedPopupMenuItem<VoidCallback>(
                      checked: _showStateField,
                      value: () => _toggleMenuSetting(
                        current: _showStateField,
                        apply: (v) => _showStateField = v,
                        persist: widget.services.settings.setShowStateField,
                      ),
                      child: Text(context.t.operation.menu.showStateField),
                    ),
                    CheckedPopupMenuItem<VoidCallback>(
                      checked: _showGridField,
                      value: () => _toggleMenuSetting(
                        current: _showGridField,
                        apply: (v) => _showGridField = v,
                        persist: widget.services.settings.setShowGridField,
                      ),
                      child: Text(context.t.operation.menu.showGridField),
                    ),
                    CheckedPopupMenuItem<VoidCallback>(
                      checked: _showDeletedQSOs,
                      value: () => _toggleMenuSetting(
                        current: _showDeletedQSOs,
                        apply: (v) => _showDeletedQSOs = v,
                        persist: widget.services.settings.setShowDeletedQSOs,
                      ),
                      child: Text(context.t.operation.menu.showDeletedQsos),
                    ),
                    CheckedPopupMenuItem<VoidCallback>(
                      checked: _showQsoNumbers,
                      value: () => _toggleMenuSetting(
                        current: _showQsoNumbers,
                        apply: (v) => _showQsoNumbers = v,
                        persist: widget.services.settings.setShowQsoNumbers,
                      ),
                      child: Text(context.t.operation.menu.showQsoNumbers),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem<VoidCallback>(
                      // Refreshes lookup data (QRZ, HamDB…) for the whole log
                      // via the background queue — progress shows in the
                      // status bar, and rows repaint as results land. The
                      // queue itself filters out event markers etc.
                      value: () => widget.services.lookupQueue.enqueueAll(qsos),
                      child: Text(context.t.operation.menu.lookupAllQsos),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                windowsCaptionSpacer(context),
              ],
              title: InkWell(
                onTap: () => _editActivities(operation),
                mouseCursor: SystemMouseCursors.click,
                // Keeps the text out of the grab pill's band along the
                // toolbar's bottom edge (see _headerGrabBand). The pill
                // floats over this row, and a long subtitle would otherwise
                // run straight through it — most visibly mid-animation, when
                // the pill is at its widest.
                child: Padding(
                  padding: const EdgeInsets.only(bottom: _headerGrabBand),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and description each shrink to fit their own
                      // width independently (issue #182) rather than
                      // truncating — down to 75% of their natural font size,
                      // past which the line ellipsizes instead (#361). The
                      // description tries Roboto's condensed glyph width
                      // first, before shrinking its font size at all.
                      shrinkToFitText(
                        Text('${operation.stationCall} ${displayTitleFor(context, operation)}'),
                      ),
                      if (refsLine.isNotEmpty)
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
              ),
              // On two-pane layouts the tabs move into the right-side pane
              // below.
              bottom: isTwoPane ? null : tabBar,
            ),
          ),
          // One tab set either way, always 4 tabs on the one controller —
          // it is never recreated, so the selected index carries across a
          // flip: index 0 maps QSOs ↔ Info, which is sensible since logging
          // is always visible in the wide split.
          body: PaneSafeArea.root(
            context,
            // Real device safe-area insets (notch, home indicator) bubble
            // in from here (ham2k/app-halo-dist#205); PaneSafeArea's own
            // divider-clearance role composes with it further down.
            child: isTwoPane && _customLayout
                ? _dockLayout(
                    loggingPanel: loggingPanel,
                    infoPanel: infoPanel,
                    spotsPanel: spotsPanel,
                    mapPanel: mapPanel,
                    realQsoCount: realQsoCount,
                  )
                : isTwoPane
                ? ResizableSplitView(
                    // Null when never dragged → the split's own 2/3-capped-
                    // at-sMax default applies.
                    preferredPrimaryWidth: widget.services.settings.layoutDimension(LayoutKeys.operationLeftColumn),
                    onPreferredPrimaryWidthChanged: (width) =>
                        widget.services.settings.setLayoutDimension(LayoutKeys.operationLeftColumn, width),
                    primary: loggingPanel,
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


/// How far the grab pill floats DOWN past the toolbar's bottom edge at rest.
/// The header applies it as a fixed translate; [_HeaderGrabHandle] animates
/// the pill back up by the same amount while a sheet is in play.
const _headerGrabFloat = 8.0;

/// How far the grab pill reaches back UP into the toolbar, plus a little
/// breathing room. The plate is 11px tall (the 3px bar plus 4px of padding
/// each side) and its bottom lands [_headerGrabFloat] less the 5px it's
/// inset by BELOW the toolbar's edge, so the remainder sits inside the
/// toolbar. The header title reserves that band, so a long subtitle never
/// runs through the pill — most visible mid-animation, at the pill's widest.
const _headerGrabBand = (3 + 4 + 4) - (_headerGrabFloat - 5) + 2.0;

/// The grab pill in the operation header, animated against the sheet it
/// opens (ham2k/app-halo-dist#312).
///
/// Opening: it widens slightly, then collapses into its own center — it
/// reads as the pill *becoming* the sheet rather than blinking out.
/// Closing: it grows back out of the center as the sheet slides up, ending
/// [_expandFactor] wider than usual at the moment the sheet is gone, then
/// springs back to its resting width.
class _HeaderGrabHandle extends StatefulWidget {
  /// The open sheet's slide animation (0 = closed, 1 = fully open), or null
  /// when there's no sheet — see `_OperationViewState._sheetAnimation`.
  final ValueListenable<Animation<double>?> sheetAnimation;
  final Color color;

  const _HeaderGrabHandle({required this.sheetAnimation, required this.color});

  @override
  State<_HeaderGrabHandle> createState() => _HeaderGrabHandleState();
}

class _HeaderGrabHandleState extends State<_HeaderGrabHandle> with SingleTickerProviderStateMixin {
  /// Resting size — the pill as it looks with no sheet in play.
  static const _width = 24.0;
  static const _height = 3.0;

  /// How far it widens on the way out (a hint of movement) and on the way
  /// back in (the overshoot the spring settles from).
  static const _peekFactor = 1.3;
  static const _expandFactor = 2.4;

  /// Beat between the sheet clearing the screen and the spring — the pill
  /// sits at its widest for a moment, so the growth and the snap back read as
  /// two gestures rather than one continuous wobble.
  static const _holdBeforeSpring = Duration(milliseconds: 200);

  /// Where in the sheet's opening slide the pill finishes widening, and
  /// where it has finished collapsing. Both well before the sheet is fully
  /// down, so the pill is long gone by the time it arrives.
  static const _peekAt = 0.35;
  static const _goneAt = 0.8;

  /// The vertical move eases IN in both directions — it starts gently and
  /// picks up speed, so the pill looks like it's being pulled rather than
  /// snapping to its new spot.
  static const _liftCurve = Curves.easeIn;

  late final AnimationController _spring = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  Animation<double>? _sheet;

  /// True while the pill waits, fully grown, for [_holdBeforeSpring] to pass.
  bool _holdingExpanded = false;
  Timer? _holdTimer;

  @override
  void initState() {
    super.initState();
    widget.sheetAnimation.addListener(_onSheetAnimationChanged);
    _attach(widget.sheetAnimation.value);
  }

  @override
  void dispose() {
    widget.sheetAnimation.removeListener(_onSheetAnimationChanged);
    _sheet?.removeListener(_onTick);
    _sheet?.removeStatusListener(_onStatus);
    _holdTimer?.cancel();
    _spring.dispose();
    super.dispose();
  }

  void _onSheetAnimationChanged() {
    final next = widget.sheetAnimation.value;
    // Null means the sheet was POPPED, not that it has finished leaving:
    // Navigator's future completes when the pop is requested, with the
    // slide-up still to play. Dropping the animation here would end the
    // pill's growth the moment the sheet started moving. The animation
    // reaching `dismissed` is the real "gone" — see [_onStatus] — so a null
    // is simply ignored.
    if (next == null) return;

    // A sheet opening cancels any hold or spring: the pill belongs to the
    // new animation now.
    _holdTimer?.cancel();
    _holdingExpanded = false;
    _spring.stop();
    _attach(next);
  }

  void _attach(Animation<double>? animation) {
    _sheet?.removeListener(_onTick);
    _sheet?.removeStatusListener(_onStatus);
    _sheet = animation;
    _sheet?.addListener(_onTick);
    _sheet?.addStatusListener(_onStatus);
    if (mounted) setState(() {});
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.dismissed) return;
    // The sheet has finished sliding up and the pill is at its widest: let go
    // of the (about to be disposed) route animation, hold that width for a
    // beat, then spring back.
    _attach(null);
    if (!mounted) return;
    _holdTimer?.cancel();
    setState(() => _holdingExpanded = true);
    _holdTimer = Timer(_holdBeforeSpring, () {
      if (!mounted) return;
      setState(() => _holdingExpanded = false);
      _spring.forward(from: 0);
    });
  }

  void _onTick() => setState(() {});

  /// Width for a sheet [t] between 0 (closed) and 1 (open). Opening and
  /// closing are deliberately NOT mirror images: opening is a peek then a
  /// collapse, closing is one continuous grow that the spring resolves.
  double _widthForSheet(double t, AnimationStatus status) {
    if (status == AnimationStatus.reverse) {
      return _width * _expandFactor * Curves.easeOut.transform(1 - t);
    }
    if (t <= _peekAt) {
      return lerpDouble(_width, _width * _peekFactor, Curves.easeOut.transform(t / _peekAt))!;
    }
    final collapsing = ((t - _peekAt) / (_goneAt - _peekAt)).clamp(0.0, 1.0);
    return lerpDouble(_width * _peekFactor, 0, Curves.easeIn.transform(collapsing))!;
  }

  /// How far ABOVE its resting position the pill sits, 0..[_headerGrabFloat]:
  /// it tucks INTO the header as it collapses on open, and drops back out as
  /// it grows on close, so the vertical move reads as part of the same
  /// gesture rather than a separate hop.
  double get _currentLift {
    final sheet = _sheet;
    if (sheet == null) return 0;
    if (sheet.status == AnimationStatus.reverse) {
      return _headerGrabFloat * (1 - _liftCurve.transform(1 - sheet.value));
    }
    return _headerGrabFloat * _liftCurve.transform((sheet.value / _goneAt).clamp(0.0, 1.0));
  }

  double get _currentWidth {
    final sheet = _sheet;
    if (sheet != null) return _widthForSheet(sheet.value, sheet.status);
    if (_holdingExpanded) return _width * _expandFactor;
    if (_spring.isAnimating) {
      // elasticOut overshoots past its end value, so the pill settles with a
      // wobble rather than simply arriving.
      return lerpDouble(_width * _expandFactor, _width, Curves.elasticOut.transform(_spring.value))!;
    }
    return _width;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _spring,
      builder: (context, _) {
        final width = _currentWidth;
        return Transform.translate(
          offset: Offset(0, -_currentLift),
          child: SizedBox(
            // The pill's own box never changes height, so nothing around it
            // reflows while it animates.
            height: _height,
            width: width <= 0 ? 0 : width,
            child: width <= 0
                ? null
                : DecoratedBox(
                    key: const Key('operationHeaderGrab'),
                    decoration: BoxDecoration(
                      color: widget.color,
                      borderRadius: BorderRadius.circular(_height / 2),
                    ),
                  ),
          ),
        );
      },
    );
  }
}
