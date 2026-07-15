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
import 'operation_dialogs.dart';
import 'operation/activities_view.dart';
import 'operation/logging_panel.dart';
import 'operation/map_panel.dart';
import 'operation/operation_export_screen.dart';
import 'operation/operation_location_screen.dart';
import 'operation/spots_panel.dart';
import '../i18n/strings.g.dart';

class OperationView extends StatefulWidget {
  final HaLoServices services;
  final String operationUuid;

  const OperationView({super.key, required this.services, required this.operationUuid});

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

  void _suggestQso(Map<String, dynamic> qso) {
    setState(() => _suggestedQso = qso);
    _tabController.animateTo(0);
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
      if (operation == null || widget.services.extensions.host == null) return; // not ready — retried on the next change
      _lastScoredFingerprint = fingerprint;
      await widget.services.scoring.rescoreOperation(operation);
    });
  }

  String _fingerprintFor(List<Qso> qsos) =>
      qsos.map((q) => '${q.uuid}:${q.updatedAtMillis ?? ''}').join(',');

  Future<void> _editActivities(Operation operation) async {
    // No manual re-fetch on pop: watchOperation streams the change back.
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ActivitiesView(services: widget.services, operation: operation)),
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
      MaterialPageRoute(builder: (_) => OperationLocationScreen(services: widget.services, operation: operation)),
    );
  }

  Future<void> _delete(Operation operation) async {
    final deleted = await confirmDeleteOperation(context, widget.services.operations, operation);
    if (deleted && mounted) Navigator.of(context).pop();
  }

  Future<void> _export(Operation operation) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => OperationExportScreen(services: widget.services, operation: operation)),
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

        return Scaffold(
          appBar: AppBar(
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
                ],
              ),
              const SizedBox(width: 8),
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
            bottom: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorWeight: 4,
              tabs: [
                Tab(text: context.t.operation.tabs.qsos(count: realQsoCount)),
                Tab(text: context.t.operation.tabs.spots),
                Tab(text: context.t.operation.tabs.map),
                Tab(text: context.t.operation.tabs.operation),
              ],
            ),
          ),
          body: TabBarView(controller: _tabController, children: [
            _KeepAlive(
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
              ),
            ),
            _KeepAlive(
              child: SpotsPanel(operation: operation, services: widget.services, onSuggestQso: _suggestQso),
            ),
            _KeepAlive(child: MapPanel(operation: operation, qsos: qsos, settings: widget.services.settings)),
            OperationSettingsPanel(
              operation: operation,
              qsoCount: realQsoCount,
              onEditDetails: () => _editDetails(operation),
              onEditActivities: () => _editActivities(operation),
              onEditLocation: () => _editLocation(operation),
              onExport: realQsoCount == 0 ? null : () => _export(operation),
              onDelete: () => _delete(operation),
            ),
          ]),
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
    final locationLine = [operation.grid, operation.data['state'], operation.data['county']]
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .join(' • ');

    return ListView(
      children: [
        SectionHeader(context.t.operation.sections.stationOperator),
        ListTile(
          leading: Icon(MdiIcons.radioTower),
          title: Text(operation.stationCall.isEmpty ? context.t.operation.stationCallsignNone : operation.stationCall),
          subtitle: Text(operation.title.isEmpty ? context.t.operation.titleNone : operation.title),
          onTap: onEditDetails,
          mouseCursor: SystemMouseCursors.click,
        ),
        SectionHeader(context.t.operation.sections.activities),
        ListTile(
          leading: Icon(MdiIcons.pineTree),
          title: Text(context.t.operation.sections.activities),
          subtitle: Text(refsLine.isEmpty ? context.t.operation.activitiesNone : refsLine),
          onTap: onEditActivities,
          mouseCursor: SystemMouseCursors.click,
        ),
        SectionHeader(context.t.operation.sections.location),
        ListTile(
          leading: Icon(resolveIconName('map-marker-outline')),
          title: Text(context.t.operation.sections.location),
          subtitle: Text(locationLine.isEmpty ? context.t.operation.locationNone : locationLine),
          onTap: onEditLocation,
          mouseCursor: SystemMouseCursors.click,
        ),
        SectionHeader(context.t.operation.sections.operationData),
        ListTile(
          leading: Icon(MdiIcons.fileExportOutline),
          title: Text(context.t.operation.export.title),
          subtitle: Text(context.t.operation.tabs.qsos(count: qsoCount)),
          onTap: onExport,
          mouseCursor: SystemMouseCursors.click,
        ),
        SectionHeader(context.t.operation.sections.dangerZone, color: theme.colorScheme.error),
        ListTile(
          leading: Icon(MdiIcons.delete, color: theme.colorScheme.error),
          title: Text(context.t.operation.deleteOperation, style: TextStyle(color: theme.colorScheme.error)),
          onTap: onDelete,
          mouseCursor: SystemMouseCursors.click,
        ),
      ],
    );
  }
}
