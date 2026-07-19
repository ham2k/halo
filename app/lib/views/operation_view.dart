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

import '../main.dart';
import '../services/settings_service.dart';
import 'operation_dialogs.dart';
import 'operation/activities_view.dart';
import 'operation/call_info_panel.dart';
import 'operation/information_panel.dart';
import 'operation/logging_panel.dart';
import 'operation/map_panel.dart';
import 'operation/operation_export_screen.dart';
import 'operation/operation_location_screen.dart';
import 'operation/spots_panel.dart';
import '../i18n/strings.g.dart';

class OperationView extends StatefulWidget {
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

class _OperationViewState extends State<OperationView> with SingleTickerProviderStateMixin {
  Operation? _operation;
  List<Map<String, dynamic>> _loggingControls = const [];
  late bool _showRSTFields = widget.services.settings.showRSTFields;
  late bool _showStateField = widget.services.settings.showStateField;
  late bool _showGridField = widget.services.settings.showGridField;
  late bool _showDeletedQSOs = widget.services.settings.showDeletedQSOs;
  late bool _showQsoNumbers = widget.services.settings.showQsoNumbers;

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
  late final TabController _tabController = TabController(length: 4, vsync: this);

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
    // and tab 0 is Info there, so switching would be wrong twice over.
    if (!ShirtSize.of(context).isTwoPane) _tabController.animateTo(0);
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
    if (_wasTwoPane == true && !isTwoPane) _tabController.index = 0;
    _wasTwoPane = isTwoPane;
  }

  @override
  void initState() {
    super.initState();
    _operationSub = widget.services.operations.watchOperation(widget.operationUuid).listen(_onOperationChanged);
    // Non-deleted, non-event set — the same QSOs the scorer sees. A
    // soft-delete/undelete changes this set (and each QSO's updatedAtMillis),
    // so the fingerprint below still moves.
    _rescoreSub = widget.services.qsos.watchForOperation(widget.operationUuid).listen(_onQsosChanged);
  }

  @override
  void dispose() {
    _operationSub?.cancel();
    _rescoreSub?.cancel();
    _rescoreDebounce?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _onOperationChanged(Operation? operation) {
    if (!mounted) return;
    final previous = _operation;
    setState(() => _operation = operation);
    if (operation == null) return;

    // Post-frame: the view must be laid out before showModalPane can size
    // itself against it. With no profile callsign yet (fresh install — no
    // onboarding flow exists), the callsign editor takes the Activities
    // pane's place: setting an identity comes first.
    if (widget.openActivities && !_openedActivities) {
      _openedActivities = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (widget.services.settings.activeProfile.operatorCall.isEmpty) {
          _promptForCallsign(operation);
        } else {
          _editActivities(operation);
        }
      });
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
      }
    }
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
      title: 'Callsign',
      fieldLabel: 'Callsign',
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
      if (_tabController.index != 0) _tabController.animateTo(0);
      return;
    }
    final info = _callInfo;
    if (info == null) return;
    await showModalPane<void>(
      context,
      title: info.call,
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

  Future<void> _editActivities(Operation operation) async {
    // No manual re-fetch on pop: watchOperation streams the change back.
    // Non-scrollable: the pane's accordion sections divide its height
    // themselves (see activities_view.dart). Not barrier/Escape-dismissible:
    // as a pushed screen this had explicit-back dismissal only, and Escape
    // while typing in the suggestions search would close the whole pane.
    await showModalPane<void>(
      context,
      title: context.t.activitiesView.title,
      scrollable: false,
      barrierDismissible: false,
      builder: (_) => ActivitiesPane(services: widget.services, operation: operation),
    );
  }

  Future<void> _editDetails(Operation operation) async {
    // The edit persists through the repository; watchOperation delivers the
    // new row (and _onOperationChanged re-resolves the entity prefix if the
    // station call changed) — no manual setState needed.
    await editOperationDetails(context, widget.services.operations, operation);
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

  Future<void> _editLocation(Operation operation) async {
    // No manual re-fetch on pop: watchOperation streams the change back.
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OperationLocationScreen(services: widget.services, operation: operation),
      ),
    );
  }

  Future<void> _delete(Operation operation) async {
    final deleted = await confirmDeleteOperation(context, widget.services.operations, operation);
    if (deleted && mounted) Navigator.of(context).pop();
  }

  Future<void> _export(Operation operation) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OperationExportScreen(services: widget.services, operation: operation),
      ),
    );
  }

  Future<void> _handleCommandAction(String action, [Map<String, dynamic>? params]) async {
    final messenger = ScaffoldMessenger.of(context);
    final message = await widget.services.handleCommandAction(action, params);
    if (message != null) messenger.showSnackBar(SnackBar(content: Text(message)));
  }

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

  @override
  Widget build(BuildContext context) {
    final operation = _operation;
    if (operation == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return StreamBuilder<List<Qso>>(
      stream: _qsosStream(),
      builder: (context, snapshot) {
        final qsos = snapshot.data ?? const <Qso>[];
        // Start/break/end markers ride the same list (for QsoList to render
        // them inline) but aren't real contacts — every QSO *count* shown to
        // the user excludes them, matching scoring/export.
        final realQsoCount = qsos.where((q) => q.isRealContact).length;
        final refsLine = operation.refs.map((r) => r['shortLabel'] ?? r['ref']).whereType<String>().join(' • ');

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
              if (appeared && ShirtSize.of(context).isTwoPane && _tabController.index != 0) {
                _tabController.animateTo(0);
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
            child: MapPanel(operation: operation, qsos: qsos, settings: widget.services.settings),
          ),
        );
        final settingsPanel = OperationSettingsPanel(
          operation: operation,
          qsoCount: realQsoCount,
          onEditDetails: () => _editDetails(operation),
          onEditActivities: () => _editActivities(operation),
          onEditLocation: () => _editLocation(operation),
          onExport: realQsoCount == 0 ? null : () => _export(operation),
          onDelete: () => _delete(operation),
        );

        // ONE tab bar and one page list serve both arrangements — only slot
        // 0 differs (the logging pane is a tab when narrow, the always-
        // visible left pane when wide, with Info taking its tab). Keeping a
        // single declaration means labels, styling, and page pairing can't
        // drift between the two layouts; the shared _tabController's
        // length: 4 and _suggestQso's slot-0 assumption complete the
        // contract.
        final tabBar = TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.tab,
          indicatorWeight: 4,
          tabs: [
            Tab(text: isTwoPane ? context.t.operation.tabs.info : context.t.operation.tabs.qsos(count: realQsoCount)),
            Tab(text: context.t.operation.tabs.spots),
            Tab(text: context.t.operation.tabs.map),
            Tab(text: context.t.operation.tabs.operation),
          ],
        );
        final tabView = TabBarView(
          controller: _tabController,
          // Tabs change only via the tab bar — horizontal swipes would
          // fight the logging strip's own horizontal scrolling (and map
          // panning), so page-swiping is disabled in both layouts.
          physics: const NeverScrollableScrollPhysics(),
          children: [
            isTwoPane
                ? InformationPanel(
                    operation: operation,
                    qsos: qsos,
                    commandMarkdown: _commandMarkdown,
                    services: widget.services,
                    callInfo: _callInfo,
                    ourEntityPrefix: _ourEntityPrefix,
                  )
                : _KeepAlive(child: loggingPanel),
            spotsPanel,
            mapPanel,
            settingsPanel,
          ],
        );

        return Scaffold(
          // The body extends full height behind the on-screen keyboard, so
          // each pane paints its own background there (and a two-pane split
          // reflects for free). The logging panel keeps its fields above the
          // keyboard with its own bottom spacer (see LoggingControls); the
          // Quick Lookup / branding panes do the same on Home.
          resizeToAvoidBottomInset: false,
          appBar: AppBar(
            flexibleSpace: windowHeaderGestureArea(),
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    operation.title.isEmpty ? operation.stationCall : '${operation.stationCall} ${operation.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (refsLine.isNotEmpty)
                    Text(
                      refsLine,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.85),
                      ),
                    ),
                ],
              ),
            ),
            // On two-pane layouts the tabs move into the right-side pane
            // below.
            bottom: isTwoPane ? null : tabBar,
          ),
          // One tab set either way, always 4 tabs on the one controller —
          // it is never recreated, so the selected index carries across a
          // flip: index 0 maps QSOs ↔ Info, which is sensible since logging
          // is always visible in the wide split.
          body: isTwoPane
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

/// Operation settings/activities/data, a scoped-down port of app-polo's
/// OpSettingsTab: just what this app already has actions for (editing
/// station/title, managing activity refs, location, export, delete)
/// rather than app-polo's full set (templates, Wavelog export, etc.), which
/// this app doesn't have the underlying data/features for yet.
class OperationSettingsPanel extends StatelessWidget {
  final Operation operation;
  final int qsoCount;
  final VoidCallback onEditDetails;
  final VoidCallback onEditActivities;
  final VoidCallback onEditLocation;
  final VoidCallback? onExport;
  final VoidCallback onDelete;

  const OperationSettingsPanel({
    super.key,
    required this.operation,
    required this.qsoCount,
    required this.onEditDetails,
    required this.onEditActivities,
    required this.onEditLocation,
    required this.onExport,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final refsLine = operation.refs.map((r) => r['shortLabel'] ?? r['ref']).whereType<String>().join(' • ');
    final locationLine = [
      operation.grid,
      operation.data['state'],
      operation.data['county'],
    ].whereType<String>().where((s) => s.isNotEmpty).join(' • ');

    // Rows render edge-to-edge; their CONTENT insets by the split's
    // grab-strip clearance (PaneSafeArea — zero when this panel is a
    // narrow-mode tab), and section headers shift with them so text stays
    // aligned.
    final safeLeft = PaneSafeArea.leftOf(context);
    Widget header(String title, {Color? color}) =>
        Padding(padding: EdgeInsets.only(left: safeLeft), child: SectionHeader(title, color: color));

    return ListTileTheme.merge(
      contentPadding: EdgeInsets.only(left: 16 + safeLeft, right: 16),
      // Clears the bottom safe area (home indicator) itself, now that the
      // status footer no longer reserves it globally; the panel fills behind.
      child: SafeArea(
        top: false,
        left: false,
        right: false,
        child: ListView(
      children: [
        header(context.t.operation.sections.stationOperator),
        ListTile(
          leading: Icon(MdiIcons.radioTower),
          title: operation.stationCall.isEmpty
              ? Text(context.t.operation.stationCallsignNone)
              : Text(operation.stationCall, style: const TextStyle(fontFamily: 'RobotoMono')),
          subtitle: Text(operation.title.isEmpty ? context.t.operation.titleNone : operation.title),
          onTap: onEditDetails,
          mouseCursor: SystemMouseCursors.click,
        ),
        header(context.t.operation.sections.activities),
        ListTile(
          leading: Icon(MdiIcons.pineTree),
          title: Text(context.t.operation.sections.activities),
          subtitle: Text(refsLine.isEmpty ? context.t.operation.activitiesNone : refsLine),
          onTap: onEditActivities,
          mouseCursor: SystemMouseCursors.click,
        ),
        header(context.t.operation.sections.location),
        ListTile(
          leading: Icon(resolveIconName('map-marker-outline')),
          title: Text(context.t.operation.sections.location),
          subtitle: Text(locationLine.isEmpty ? context.t.operation.locationNone : locationLine),
          onTap: onEditLocation,
          mouseCursor: SystemMouseCursors.click,
        ),
        header(context.t.operation.sections.operationData),
        ListTile(
          leading: Icon(MdiIcons.fileExportOutline),
          title: Text(context.t.operation.export.title),
          subtitle: Text(context.t.operation.tabs.qsos(count: qsoCount)),
          onTap: onExport,
          mouseCursor: SystemMouseCursors.click,
        ),
        header(context.t.operation.sections.dangerZone, color: theme.colorScheme.error),
        ListTile(
          leading: Icon(MdiIcons.delete, color: theme.colorScheme.error),
          title: Text(context.t.operation.deleteOperation, style: TextStyle(color: theme.colorScheme.error)),
          onTap: onDelete,
          mouseCursor: SystemMouseCursors.click,
        ),
      ],
      ),
      ),
    );
  }
}
