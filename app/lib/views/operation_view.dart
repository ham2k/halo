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
import '../services/settings_service.dart';
import '../settings/settings_target_dialog.dart';
import 'operation_dialogs.dart';
import 'operation/activities_view.dart';
import 'operation/call_info_panel.dart';
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
// against, and what resizing across the breakpoint would trip.
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
    final s = widget.services.settings;
    final enabled = s.experimentEnabled('layouts');
    // Local mirrors of the logging panel's own toggles (see
    // _buildLoggingSettingsButton) — flipped from the settings dialog,
    // so this is the only place they follow SettingsService.
    final changed = enabled != _customLayout ||
        s.showRSTFields != _showRSTFields ||
        s.showStateField != _showStateField ||
        s.showGridField != _showGridField ||
        s.showDeletedQSOs != _showDeletedQSOs ||
        s.showQsoNumbers != _showQsoNumbers;
    if (changed && mounted) {
      setState(() {
        _customLayout = enabled;
        _showRSTFields = s.showRSTFields;
        _showStateField = s.showStateField;
        _showGridField = s.showGridField;
        _showDeletedQSOs = s.showDeletedQSOs;
        _showQsoNumbers = s.showQsoNumbers;
      });
    }
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
    // Claims this view's slot on the ⌘K command-context stack. Held by
    // identity so popping back from a nested operation reveals this one again
    // rather than leaving the palette context-less — see
    // HaLoServices.openOperationContext.
    _commandContext = widget.services.openOperationContext(widget.operationUuid);
  }

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
    _tabController?.dispose();
    widget.services.closeOperationContext(_commandContext);
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
  ValueNotifier<bool>? _activeHasUpdatesNotifier;

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
    setState(() {
      _draftOperation = operation;
      _activeSheetKey = sheetKey;
      _activeHasUpdatesNotifier = hasUpdatesNotifier;
    });

    void onUpdatesChanged() {
      if (mounted) setState(() {});
    }
    hasUpdatesNotifier.addListener(onUpdatesChanged);

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
          // would go null immediately, snapping the header's dots/accept
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
        title: ValueListenableBuilder<Operation>(
          valueListenable: draftNotifier,
          builder: (context, draft, _) {
            final stationCall = draft.stationCall;
            final operatorCall = draft.data['operatorCall'] as String?;
            final operationTitle = draft.userTitle;
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
        onDismiss: () => sheetKey.currentState?.saveAndClose(),
        leading: null,
        trailing: ValueListenableBuilder<bool>(
          valueListenable: hasUpdatesNotifier,
          builder: (context, updates, child) {
            final theme = Theme.of(context);
            if (updates) {
              return IconButton(
                icon: Icon(Icons.undo, semanticLabel: context.t.common.cancel),
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.errorContainer,
                  foregroundColor: theme.colorScheme.onErrorContainer,
                ),
                onPressed: () => sheetKey.currentState?.revert(),
              );
            } else {
              return IconButton(
                icon: Icon(Icons.undo, color: theme.disabledColor, semanticLabel: context.t.common.cancel),
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
      hasUpdatesNotifier.removeListener(onUpdatesChanged);
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
          _activeHasUpdatesNotifier = null;
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
      hasUpdatesNotifier.dispose();
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
      runCommandAction(widget.services, this, action, params);

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
        icon: Icon(Icons.tune, color: iconColor, semanticLabel: MaterialLocalizations.of(effectiveContext).showMenuTooltip),
        onPressed: () => showSettingsForTarget(
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
        ),
      ),
    );
  }

  /// Floor for [_narrowTabBar]'s QSOs-tab padding — shrunk before the tab
  /// is ever allowed to grow past an even third (and, in turn, before
  /// Spots/Map are ever asked to give up any of their own share).
  static const double _kNarrowTabMinPadding = 4;

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
    final qsosContentWidth = qsosLabelWidth + kMinInteractiveDimension * 2;

    return PreferredSize(
      key: const Key('narrowTabBar'),
      preferredSize: const Size.fromHeight(kTextTabBarHeight),
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
                      height: kTextTabBarHeight,
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
                        height: kTextTabBarHeight,
                        child: _narrowTab(1, context.t.operation.tabs.spots, labelStyle),
                      ),
                    ),
                    Expanded(
                      child: SizedBox(
                        height: kTextTabBarHeight,
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
      indicatorWidth: 4,
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
  Widget _dockLayout({
    required Widget loggingPanel,
    required Widget infoPanel,
    required Widget spotsPanel,
    required Widget mapPanel,
    required int realQsoCount,
    required List<Qso> qsos,
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
      tabActions: {'logging': (context) => _buildLoggingSettingsButton(qsos, context: context)},
      onSpecChanged: (node) {
        _dockSpec = node;
        widget.services.settings.setLayoutData(LayoutKeys.operationDock, node.toJson());
      },
    );
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
            ourItuRegion: _ourItuRegion,
            ourCountryCode: _ourCountryCode,
            suggestedQso: _suggestedQso,
            onCallInfoChanged: (info) => setState(() => _callInfo = info),
            onCallInfoTap: () => _handleCallInfoTap(operation),
          ),
        );
        final spotsPanel = KeyedSubtree(
          key: _spotsKey,
          child: _LazyTab(
            child: SpotsPanel(operation: operation, services: widget.services, onSuggestQso: _suggestQso),
          ),
        );
        final mapPanel = KeyedSubtree(
          key: _mapKey,
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
        );
        // ONE construction serving both wide arrangements (fixed tab slot 0
        // and the dock's 'info' module) so their props can't drift apart.
        final infoPanel = InformationPanel(
          operation: operation,
          qsos: qsos,
          services: widget.services,
          callInfo: _callInfo,
          ourEntityPrefix: _ourEntityPrefix,
          activityControls: _loggingControls,
        );
        // Built before `tabBar`/`tabView`/`_narrowTabBar` below, all of
        // which read `_tabController!` directly — the controller must
        // already be this build's final instance, not the one about to be
        // replaced, by the time any of them are constructed.
        _updateTabControllerIfNeeded(_kTabCount);

        // Wide: Info, Spots, Map — logging has its own pane in the split.
        // Narrow: QSOs, Spots, Map — logging is what the view is for, and
        // Info is one tap away via the callsign area.
        final List<Widget> tabs = [
          if (!isTwoPane) Tab(text: context.t.operation.tabs.qsos(count: formatNumber(realQsoCount))),
          if (isTwoPane) Tab(text: context.t.operation.tabs.info),
          Tab(text: context.t.operation.tabs.spots),
          Tab(text: context.t.operation.tabs.map),
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
              // Tight against the back button — the dots-and-title control
              // supplies its own (small) inset instead of relying on the
              // theme's default gap here.
              titleSpacing: 0,
              // The logging-only settings menu travels with the logging
              // panel itself, not this AppBar (dock module header,
              // narrow QSOs tab, or the fixed wide split's pane title bar —
              // see _buildLoggingSettingsButton), since none of its toggles
              // apply to the Info/Spots/Map tabs.
              actions: [windowsCaptionSpacer(context)],
              title: InkWell(
                key: _headerTitleKey,
                onTap: () {
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
                  // A small left inset so the dots/accept control doesn't
                  // sit flush against the back button, and a small right
                  // inset — the title doesn't stretch to fill the AppBar —
                  // so the control's own edge doesn't sit flush against
                  // whatever's to its right (actions, or the window's own
                  // edge).
                  padding: const EdgeInsets.only(left: 8, right: 12, top: 2, bottom: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _HeaderDotsAndAcceptControl(
                        progress: _sheetAnimation?.value ?? 0.0,
                        hasUpdates: _activeHasUpdatesNotifier?.value ?? false,
                      ),
                      const SizedBox(width: 4),
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
          body: PaneSafeArea.root(
            context,
            // Real device safe-area insets (notch, home indicator) bubble
            // in from here; PaneSafeArea's own
            // divider-clearance role composes with it further down.
            child: isTwoPane && _customLayout
                ? _dockLayout(
                    loggingPanel: loggingPanel,
                    infoPanel: infoPanel,
                    spotsPanel: spotsPanel,
                    mapPanel: mapPanel,
                    realQsoCount: realQsoCount,
                    qsos: qsos,
                  )
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
                    // `kTextTabBarHeight` matches the secondary's TabBar so
                    // both sides of the split line up at the divider.
                    primary: Column(
                      children: [
                        Material(
                          color:
                              Theme.of(context).appBarTheme.backgroundColor ?? Theme.of(context).colorScheme.primary,
                          child: SizedBox(
                            height: kTextTabBarHeight,
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
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
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

class _HeaderDotsAndAcceptControl extends StatelessWidget {
  final double progress;
  final bool hasUpdates;

  const _HeaderDotsAndAcceptControl({
    required this.progress,
    required this.hasUpdates,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onPrimary = theme.colorScheme.onPrimary;

    // Control width expands smoothly from 10px (tight 3-dots) to 28px (accept circle),
    // pushing the header title to the right at the exact animation speed.
    final controlWidth = 10.0 + (18.0 * progress);

    final bgColor = hasUpdates ? const Color(0xFFDCFCE7) : theme.colorScheme.onPrimary;
    final iconColor = hasUpdates ? const Color(0xFF15803D) : (theme.appBarTheme.backgroundColor ?? theme.colorScheme.primary);

    return SizedBox(
      width: controlWidth,
      height: 32,
      child: CustomPaint(
        size: Size(controlWidth, 32),
        painter: _MorphingDotsAcceptPainter(
          progress: progress,
          dotColor: onPrimary,
          buttonBgColor: bgColor,
          buttonIconColor: iconColor,
        ),
      ),
    );
  }
}

class _MorphingDotsAcceptPainter extends CustomPainter {
  final double progress;
  final Color dotColor;
  final Color buttonBgColor;
  final Color buttonIconColor;

  _MorphingDotsAcceptPainter({
    required this.progress,
    required this.dotColor,
    required this.buttonBgColor,
    required this.buttonIconColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Morphing Top Dot (Dot 1 -> Accept Circle)
    // Center morphs smoothly from (4.0, 10.0) [centered 3-dots] to (14.0, 16.0) [28px circle]
    final cx = 4.0 + (10.0 * progress);
    final cy = 10.0 + (6.0 * progress);
    // Radius morphs smoothly from 1.8px (dot) to 14.0px (28px diameter circle)
    final radius = 1.8 + (12.2 * progress);

    // Color morphs smoothly from dotColor to buttonBgColor with no crossfade
    final currentBgColor = Color.lerp(dotColor, buttonBgColor, progress) ?? buttonBgColor;

    final circlePaint = Paint()
      ..color = currentBgColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(cx, cy), radius, circlePaint);

    // Subtle elevation shadow as the circle expands into a button
    if (progress > 0.3) {
      final shadowOpacity = (progress - 0.3) / 0.7 * 0.15;
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: shadowOpacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
      canvas.drawCircle(Offset(cx, cy + 1), radius, shadowPaint);
      canvas.drawCircle(Offset(cx, cy), radius, circlePaint);
    }

    // 2. Checkmark Icon inside the expanding circle (scales & appears as circle grows)
    if (progress > 0.1) {
      final iconOpacity = ((progress - 0.1) / 0.9).clamp(0.0, 1.0);
      final checkPaint = Paint()
        ..color = buttonIconColor.withValues(alpha: buttonIconColor.a * iconOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final checkScale = (progress - 0.1) / 0.9;
      final path = Path()
        ..moveTo(cx - 4.5 * checkScale, cy + 0.5 * checkScale)
        ..lineTo(cx - 1.0 * checkScale, cy + 4.0 * checkScale)
        ..lineTo(cx + 4.5 * checkScale, cy - 3.5 * checkScale);

      canvas.drawPath(path, checkPaint);
    }

    // 3. Dots 2 and 3 (vertically centered when closed; translate down & fade out)
    final dotsOpacity = (1.0 - progress).clamp(0.0, 1.0);
    if (dotsOpacity > 0) {
      final dotsPaint = Paint()
        ..color = dotColor.withValues(alpha: dotColor.a * dotsOpacity)
        ..style = PaintingStyle.fill;

      const dotRadius = 1.8;
      const x = 4.0;

      // Middle dot (Dot 2) - starts at 16.0 (vertically centered in 32px height)
      final y2 = 16.0 + (14.0 * progress);
      canvas.drawCircle(Offset(x, y2), dotRadius, dotsPaint);

      // Bottom dot (Dot 3) - starts at 22.0
      final y3 = 22.0 + (14.0 * progress);
      canvas.drawCircle(Offset(x, y3), dotRadius, dotsPaint);
    }
  }

  @override
  bool shouldRepaint(_MorphingDotsAcceptPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.dotColor != dotColor ||
      oldDelegate.buttonBgColor != buttonBgColor ||
      oldDelegate.buttonIconColor != buttonIconColor;
}


