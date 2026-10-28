// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Chasing destination (`EXP CHASE`): logging contacts while chasing
// parks, summits and the like, outside of any operation. What it logs lands
// in the same loose bucket (`operationUuid: ''`) an ADIF import into Logs
// fills, and syncs the same way.

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HardwareKeyboard, KeyEvent;
import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../services/cat/zero_beat.dart';
import '../services/chase_service.dart';
import '../services/command_actions.dart';
import '../services/halo_services.dart';
import '../services/panel_service.dart';
import '../services/logging_scope.dart';
import '../services/settings_service.dart';
import '../services/spot_board_service.dart' show SpotBoardSubscription;
import '../settings/core_settings_groups.dart' show GeneralSettingsGroup, LoggingSettingsGroup;
import '../settings/settings_scan.dart' show frontSettingsOverrides;
import '../settings/settings_target_dialog.dart';
import 'dock_host.dart';
import 'extensions_panel.dart';
import 'home_navigation_rail.dart';
import 'chase_import_flow.dart';
import 'operation/extension_panel.dart';
import 'operation/information_panel.dart';
import 'operation/log_find_bar.dart';
import 'operation/logging_panel.dart';
import 'operation/map_panel.dart';
import 'operation/operation_location_pin.dart';
import 'operation/operation_location_screen.dart';
import 'operation/operation_runtime_state.dart';
import 'operation/spots_panel.dart';
import 'tester_overlay.dart' show testerOverlayCovering;
import 'operation_dialogs.dart' show editTwoFieldDialog;
import 'operation_view.dart' show zeroBeatSuggestionFor;
import 'sheet_header_dots.dart';

/// The span of the log the Chasing view shows, and counts in its header.
/// Calendar spans are UTC, like the log's own days.
enum ChasePeriod {
  today,
  thisWeek,
  last14Days,
  thisMonth;

  /// Where the span starts, for a clock reading [now] (UTC) — always a UTC
  /// midnight, so every period moves on at 0000Z and at no other time. Weeks
  /// start on Monday; the last 14 days are today and the 13 before it.
  int startMillis(DateTime now) {
    final day = DateTime.utc(now.year, now.month, now.day);
    return switch (this) {
      ChasePeriod.today => day,
      ChasePeriod.thisWeek => day.subtract(Duration(days: day.weekday - DateTime.monday)),
      ChasePeriod.last14Days => day.subtract(const Duration(days: 13)),
      ChasePeriod.thisMonth => DateTime.utc(now.year, now.month),
    }.millisecondsSinceEpoch;
  }

  String label(BuildContext context) => switch (this) {
    ChasePeriod.today => context.t.chase.period.today,
    ChasePeriod.thisWeek => context.t.chase.period.thisWeek,
    ChasePeriod.last14Days => context.t.chase.period.last14Days,
    ChasePeriod.thisMonth => context.t.chase.period.thisMonth,
  };

  /// The Info pane's heading over the period's stats — "Stats for today".
  String statsTitle(BuildContext context) => switch (this) {
    ChasePeriod.today => context.t.chase.periodStats.today,
    ChasePeriod.thisWeek => context.t.chase.periodStats.thisWeek,
    ChasePeriod.last14Days => context.t.chase.periodStats.last14Days,
    ChasePeriod.thisMonth => context.t.chase.periodStats.thisMonth,
  };

  /// The period as it reads at the end of the header's sentence — "KI2D
  /// chasing POTA today".
  String inlineLabel(BuildContext context) => switch (this) {
    ChasePeriod.today => context.t.chase.periodInline.today,
    ChasePeriod.thisWeek => context.t.chase.periodInline.thisWeek,
    ChasePeriod.last14Days => context.t.chase.periodInline.last14Days,
    ChasePeriod.thisMonth => context.t.chase.periodInline.thisMonth,
  };
}

/// Whether [control] hunts a reference — a `refList` carrying a ref type.
bool _isHuntingControl(Map<String, dynamic> control) {
  final input = control['input'];
  return input is Map && input['kind'] == 'refList' && (input['refType'] as String? ?? '').isNotEmpty;
}

/// [controls] as the Chasing view's logging panel shows them: every
/// hunting control, ahead of everything else. Whether a program is a goal
/// says what the view judges spots and calls against, not which references
/// the operator can log.
List<Map<String, dynamic>> chaseLoggingControls(List<Map<String, dynamic>> controls) => [
  for (final control in controls)
    if (_isHuntingControl(control)) control,
  for (final control in controls)
    if (!_isHuntingControl(control)) control,
];

/// The location keys the Chasing view keeps, in the shape the location
/// editor returns and an operation stores. The first four are one statement
/// about one place (docs/design/locations.md) and are only ever written
/// together.
const _chaseLocationPlaceKeys = ['grid', 'gridSource', 'lat', 'lon'];
const _chaseLocationKeys = [..._chaseLocationPlaceKeys, 'state', 'county'];

/// [qso] carrying the chasing [location] on its own side — `our.grid`,
/// `our.lat`/`lon` and the rest — for a contact that has no operation to
/// inherit one from.
///
/// Only a NEW contact, the rule [qsoWithOperator] keeps: re-saving an edit
/// to an earlier one must not move it to wherever the operator is now. And
/// the place is written whole or not at all — a grid stamped beside a
/// coordinate it did not come with is outranked by that coordinate
/// everywhere it is read.
Map<String, dynamic> qsoWithChaseLocation(Map<String, dynamic> qso, Map<String, dynamic> location) {
  if (qso['band'] == 'event') return qso;
  if ((asQsonString(qso['uuid']) ?? '').isNotEmpty) return qso;
  bool present(String key) => location[key] != null && location[key] != '';
  final hasPlace = present('grid') || (present('lat') && present('lon'));
  if (!hasPlace && !present('state') && !present('county')) return qso;
  final our = {...?asQsonMap(qso['our'])};
  if (hasPlace) {
    for (final key in _chaseLocationPlaceKeys) {
      present(key) ? our[key] = location[key] : our.remove(key);
    }
  }
  for (final key in const ['state', 'county']) {
    if (present(key)) our[key] = location[key];
  }
  return {...qso, 'our': our};
}

class ChaseView extends StatefulWidget {
  static const layoutPolicy = ViewLayoutPolicy.customizable;

  static const loggingPanelId = 'chaseLogging';
  static const spotsPanelId = 'chaseSpots';
  static const infoPanelId = 'chaseInfo';
  static const mapPanelId = 'chaseMap';

  final HaLoServices services;

  /// Whether the view is the destination on screen. It stays mounted while
  /// another one is up (see `HomeView`), so what it costs to keep live —
  /// spots, the clock, its say over SET/SHOW — follows this rather than the
  /// view's lifetime.
  final bool visible;

  const ChaseView({super.key, required this.services, this.visible = true});

  @override
  State<ChaseView> createState() => _ChaseViewState();
}

class _ChaseViewState extends State<ChaseView> with DockHost<ChaseView> {
  @override
  HaLoServices get dockServices => widget.services;

  @override
  String get dockView => PanelViews.chase;

  @override
  DockLayoutKeys dockKeysFor(DockLayoutClass layoutClass) => switch (layoutClass) {
    DockLayoutClass.wide => const DockLayoutKeys(
      spec: LayoutKeys.chaseDock,
      state: LayoutKeys.chaseDockState,
      paneOptions: LayoutKeys.chasePaneOptions,
      viewOptions: LayoutKeys.chaseViewOptions,
    ),
    DockLayoutClass.narrow => const DockLayoutKeys(
      spec: LayoutKeys.chaseNarrowDock,
      state: LayoutKeys.chaseNarrowDockState,
      paneOptions: LayoutKeys.chaseNarrowPaneOptions,
      viewOptions: LayoutKeys.chaseNarrowViewOptions,
    ),
  };

  /// Pinned narrow for the same reason as the Operation view's logging pane:
  /// a phone with no logging pane cannot enter a QSO at all.
  @override
  Set<String> pinnedModuleIdsIn(DockLayoutClass layoutClass) => layoutClass == DockLayoutClass.narrow ? const {ChaseView.loggingPanelId} : const {};

  @override
  Set<String> get nativeModuleIds => const {ChaseView.loggingPanelId, ChaseView.spotsPanelId, ChaseView.infoPanelId, ChaseView.mapPanelId};

  @override
  Map<String, String> get nativeTitles => {
    // The log's tab carries the period's count, as an operation's does.
    ChaseView.loggingPanelId: context.t.operation.tabs.qsos(count: _realQsoCount),
    ChaseView.spotsPanelId: context.t.chase.panels.spots,
    ChaseView.infoPanelId: context.t.chase.panels.info,
    ChaseView.mapPanelId: context.t.chase.panels.map,
  };

  @override
  PanelRenderContext get panelRenderContext => PanelRenderContext(operation: _operation, qsoCount: _realQsoCount, log: _logForPanels);

  /// This view's own copy of the logging settings, standing in for the
  /// operation's wherever its logging pane offers them — see [LoggingScope].
  /// The User Interface group too, which holds Show Deleted QSOs.
  late final _loggingSettings = {
    'logging': LoggingSettingsGroup(widget.services.settings, scope: LoggingScope.chase),
    'general': GeneralSettingsGroup(widget.services.settings, widget.services.extensions, scope: LoggingScope.chase),
  };

  bool _loggingDisplay(String key) => widget.services.settings.loggingDisplay(key, LoggingScope.chase);

  @override
  WidgetBuilder? nativePanelSettingsForm(BuildContext context, String id) => switch (id) {
    ChaseView.loggingPanelId => (builderContext) => settingsFormForTarget(services: widget.services, target: 'logging', groupOverrides: _loggingSettings),
    ChaseView.mapPanelId => (builderContext) => settingsFormForTarget(services: widget.services, target: 'map'),
    _ => null,
  };

  /// Wide: spots on the left, the log in the middle, Info over the Map on the
  /// right. Narrow: one tab strip of QSOs, Spots and Map, like an operation's.
  @override
  DockNode buildDefaultDockSpec(DockLayoutClass layoutClass, {bool migrate = true}) => switch (layoutClass) {
    DockLayoutClass.narrow => DockGroup([ChaseView.loggingPanelId, ChaseView.spotsPanelId, ChaseView.mapPanelId]),
    DockLayoutClass.wide => DockSplit(
      Axis.horizontal,
      [
        DockGroup([ChaseView.spotsPanelId]),
        DockGroup([ChaseView.loggingPanelId]),
        DockSplit(
          Axis.vertical,
          [
            DockGroup([ChaseView.infoPanelId]),
            DockGroup([ChaseView.mapPanelId]),
          ],
          [1, 1],
        ),
      ],
      [1, 2, 1],
    ),
  };

  void _registerNativePanels() {
    final t = context.t.chase.panels;
    final service = widget.services.panels;
    for (final (id, title, description, icon) in [
      (ChaseView.loggingPanelId, t.logging, t.loggingDescription, 'notebook'),
      (ChaseView.spotsPanelId, t.spots, t.spotsDescription, 'radioTower'),
      (ChaseView.infoPanelId, t.info, t.infoDescription, 'informationOutline'),
      (ChaseView.mapPanelId, t.map, t.mapDescription, 'map'),
    ]) {
      service.registerNative(
        PanelDefinition(
          id: id,
          title: title,
          description: description,
          icon: icon,
          source: PanelSource.native,
          views: const {PanelViews.chase},
          settingsTarget: id == ChaseView.loggingPanelId ? 'logging' : null,
        ),
      );
    }
    registerSharedDashboardPanels();
  }

  /// The chasing station for the active profile, as the sheet's Station pill
  /// set it: `stationCall` and `operatorCall`. Kept per profile, so switching
  /// profiles switches stations; an empty station call means the profile's
  /// own, which is what it starts as.
  Map<String, dynamic> get _station => asQsonMap(asQsonMap(_options['stations'])?[widget.services.settings.activeProfileId]) ?? const {};

  /// The chasing location, as the sheet's Location pill set it — the keys of
  /// [_chaseLocationKeys]. Stamped on every new contact (see
  /// [qsoWithChaseLocation]).
  Map<String, dynamic> get _location => asQsonMap(_options['location']) ?? const {};

  /// The stand-in operation everything here logs and renders against: no
  /// uuid — so a contact lands with no operation — and the chasing station
  /// and location, read afresh each time so a change to either reaches the
  /// next contact.
  Operation get _operation {
    final stationCall = (asQsonString(_station['stationCall']) ?? '').trim();
    final operatorCall = (asQsonString(_station['operatorCall']) ?? '').trim();
    final location = _location;
    return Operation(
      uuid: '',
      data: {
        'stationCall': stationCall.isNotEmpty ? stationCall : widget.services.settings.activeProfile.operatorCall,
        if (operatorCall.isNotEmpty) operatorCallKey: operatorCall,
        for (final key in _chaseLocationKeys)
          if (location[key] != null) key: location[key],
      },
    );
  }

  /// Only the controls side of the runtime state: with no current operation
  /// it never rescores — a pass over every loose contact on the account is
  /// not this view's to start.
  late final _runtime = OperationRuntimeState(services: widget.services, currentOperation: () => null, controlsOperation: () => _operation)
    ..addListener(_onRuntimeChanged);

  void _onRuntimeChanged() {
    if (mounted) setState(() {});
  }

  /// Keyed on whether deleted contacts show — the one input that changes
  /// which query this is.
  Stream<List<Qso>>? _qsoStream;
  bool? _qsoStreamIncludesDeleted;

  Stream<List<Qso>> _qsos() {
    final includeDeleted = _loggingDisplay('showDeletedQSOs');
    if (_qsoStream == null || _qsoStreamIncludesDeleted != includeDeleted) {
      _qsoStream = widget.services.qsos.watchForOperation('', includeDeleted: includeDeleted);
      _qsoStreamIncludesDeleted = includeDeleted;
    }
    return _qsoStream!;
  }

  /// Held only while the view is on screen — see [ChaseView.visible].
  SpotBoardSubscription? _spotBoardView;
  final _spotsVisible = ValueNotifier(true);

  /// The panes' subtrees, kept across a flip between the narrow and the wide
  /// dock — see OperationView's own: without them a half-typed contact, the
  /// open pill and the list's selection are rebuilt from nothing.
  final _loggingKey = GlobalKey();
  final _spotsKey = GlobalKey();
  final _mapKey = GlobalKey();
  final _zeroBeat = ZeroBeatOffsetter();

  Map<String, dynamic>? _suggestedQso;
  bool _suggestedQsoIsTentative = false;
  int _suggestionSettledSerial = 0;
  int _closeSlidesSerial = 0;
  ({int serial, Map<String, dynamic> qso})? _logRequest;
  CallInfoData? _callInfo;
  String? _selectedQsoUuid;
  int _realQsoCount = 0;
  List<Qso>? _logForPanels;

  /// The period's contacts for this station, and their fingerprint, as last
  /// filtered — redone only when the log, the period's start or the station
  /// changes. The loose bucket holds every contact the account has that
  /// belongs to no operation (ADIF imports into Logs included), and this
  /// view rebuilds far more often than any of those three move.
  ({List<Qso> source, int start, String station, List<Qso> qsos, String fingerprint})? _filtered;

  ({List<Qso> qsos, String fingerprint}) _filter(List<Qso> source, String stationCall) {
    final start = _period.startMillis(nowUtc());
    final station = stationCall.toUpperCase();
    final cached = _filtered;
    if (cached != null && identical(cached.source, source) && cached.start == start && cached.station == station) {
      return (qsos: cached.qsos, fingerprint: cached.fingerprint);
    }
    final qsos = [
      for (final qso in source)
        if ((qso.startAtMillis ?? 0) >= start && qso.ourCall.toUpperCase() == station) qso,
    ];
    final fingerprint = logFingerprintFor(qsos);
    _filtered = (source: source, start: start, station: station, qsos: qsos, fingerprint: fingerprint);
    return (qsos: qsos, fingerprint: fingerprint);
  }

  final _headerTitleKey = GlobalKey();

  /// The sheet's slide while it is up or going away — what the header's dots
  /// and the leading gap behind the OK button follow. Cleared once the slide
  /// has finished closing, not when the route pops, so the dots don't snap
  /// back while the sheet is still on its way out.
  Animation<double>? _sheetAnimation;

  /// The sheet's OK button, measured so the title's leading gap can open to
  /// its width — it draws over this corner of the header, not inside it.
  final _sheetOkButtonKey = GlobalKey();

  double get _sheetProgress => _sheetAnimation?.value ?? 0.0;

  double get _leadingGapWidth => sheetLeadingGapWidth(_sheetProgress, _sheetOkButtonWidth);

  /// The OK button's laid-out width, or null when it cannot be read. Its
  /// element lives in the sheet's route, not in this build, and is inactive
  /// for a frame whenever that route rebuilds under a dialog pushed over it
  /// (the Station or Location editor) — `findRenderObject` throws then in
  /// debug, which the catch is for, and hands back a detached box in release,
  /// which `attached` is for. The operation header's own read has the same
  /// guard for the same reason.
  double? get _sheetOkButtonWidth {
    final element = _sheetOkButtonKey.currentContext;
    if (element == null || !element.mounted) return null;
    try {
      final box = element.findRenderObject() as RenderBox?;
      return box != null && box.attached && box.hasSize ? box.size.width : null;
    } on FlutterError {
      return null;
    }
  }

  Map<String, dynamic> get _options => widget.services.settings.layoutData(LayoutKeys.chaseOptions) ?? const {};

  ChasePeriod get _period => ChasePeriod.values.asNameMap()[_options['period']] ?? ChasePeriod.today;

  List<ChaseGoal> get _goals => widget.services.chase.goals;

  Future<void> _setOptions(Map<String, dynamic> changes) => widget.services.settings.setLayoutData(LayoutKeys.chaseOptions, {..._options, ...changes});

  Future<void> _setGoals(List<ChaseGoal> goals) => widget.services.chase.setGoals(goals);

  /// The goals as last built, to tell a change to them from the many
  /// [ChaseService] notifications that only move a checklist.
  String _goalsKey = '';

  String get _goalsKeyNow => [for (final g in _goals) '${g.key}:${g.label}:${g.on}'].join(',');

  /// Each goal's checklist, for the Info panel — see [ChaseService.summaries].
  List<ChaseSummary> _summaries = const [];
  int _summariesRequest = 0;

  Future<void> _loadSummaries() async {
    final request = ++_summariesRequest;
    final summaries = await widget.services.chase.summaries(stationOfOperation(_operation));
    if (mounted && request == _summariesRequest) setState(() => _summaries = summaries);
  }

  void _onChaseChanged() {
    if (!mounted) return;
    final goals = _goalsKeyNow;
    if (goals != _goalsKey) setState(() => _goalsKey = goals);
    unawaited(_loadSummaries());
  }

  @override
  void initState() {
    super.initState();
    _inputs = _inputsNow();
    widget.services.settings.addListener(_onSettingsChanged);
    widget.services.extensions.runtimeGeneration.addListener(_onRuntimeGenerationChanged);
    widget.services.chase.addListener(_onChaseChanged);
    _goalsKey = _goalsKeyNow;
    unawaited(_loadSummaries());
    if (widget.visible) _shown();
    unawaited(_startRuntime());
  }

  @override
  void didUpdateWidget(ChaseView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible == oldWidget.visible) return;
    widget.visible ? _shown() : _hidden();
  }

  /// Bumped each time the view comes back on screen — see
  /// [LoggingPanel.focusRequest]. The first showing needs none: the call
  /// field's own autofocus has it.
  int _focusRequest = 0;

  void _shown() {
    _focusRequest++;
    widget.services.track('screen_viewed', {'screen': 'chase'});
    _spotBoardView = widget.services.spotBoard.subscribe();
    WallClock.seconds.addListener(_onTick);
    frontSettingsOverrides.set(this, _loggingSettings);
    HardwareKeyboard.instance.addHandler(_onFindKeyEvent);
  }

  void _hidden() {
    _spotBoardView?.cancel();
    _spotBoardView = null;
    WallClock.seconds.removeListener(_onTick);
    frontSettingsOverrides.clear(this);
    HardwareKeyboard.instance.removeHandler(_onFindKeyEvent);
  }

  /// Bumped to open the logging panel's Find bar — [LoggingPanel.findRequest].
  int _findRequest = 0;

  /// Opens Find over the log, bringing the logging pane forward first when
  /// another tab holds its place.
  void _openFind() {
    dockKey.currentState?.revealModule(ChaseView.loggingPanelId);
    setState(() => _findRequest++);
  }

  /// ⌘F/Ctrl+F while this view is on screen ([_shown] to [_hidden]), its
  /// route is the front-most one — a dialog over it owns the keyboard — and
  /// its layout has a logging pane to find in. Without one the chord is left
  /// to the platform: on web, the browser's own Find.
  bool _onFindKeyEvent(KeyEvent event) {
    if (!isFindChord(event) || testerOverlayCovering.value) return false;
    if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? false)) return false;
    if (!(dockKey.currentState?.modules.contains(ChaseView.loggingPanelId) ?? true)) return false;
    _openFind();
    return true;
  }

  /// The period ends at a UTC midnight that no write announces: "today"
  /// still holding yesterday's contacts would count a new day's hunt of the
  /// same park as a dupe. Rebuilds only on the tick the start actually moves.
  void _onTick() {
    final cached = _filtered;
    if (mounted && cached != null && cached.start != _period.startMillis(nowUtc())) setState(() {});
  }

  Future<void> _startRuntime() async {
    await widget.services.extensions.start();
    if (!mounted) return;
    await _runtime.refreshControls(_operation);
    if (!mounted) return;
    await _runtime.resolveOurEntity(_operation);
  }

  void _onRuntimeGenerationChanged() => _runtime.runtimeRestarted();

  /// Everything this view reads from settings, so [_onSettingsChanged] can
  /// tell a change it shows from the many writes it doesn't — SettingsService
  /// notifies on sync-state writes too, and a rebuild here rebuilds every pane.
  Object? _inputs;

  Object _inputsNow() {
    final s = widget.services.settings;
    return (
      options: jsonEncode(_options),
      profile: s.activeProfileId,
      profileCall: s.activeProfile.operatorCall,
      // Joined: a record compares a List by identity, and every read is a new one.
      display: [for (final key in loggingScopedKeys) _loggingDisplay(key)].join(','),
      reports: (s.defaultReport, s.defaultReportCW, s.defaultReportFT8),
      switchSentRcvd: s.switchSentRcvd,
      jumpAfterRST: s.jumpAfterRST,
      dxFlags: s.dxFlags,
    );
  }

  void _onSettingsChanged() {
    if (!mounted) return;
    final inputs = _inputsNow();
    if (inputs == _inputs) return;
    final before = _operation;
    _inputs = inputs;
    setState(() {});
    // What an operation re-derives when ITS station or refs change
    // (OperationRuntimeState.operationChanged): the entity the station call
    // resolves to, and the controls, which may key off where it is.
    final after = _operation;
    if (before.stationCall != after.stationCall) {
      unawaited(_runtime.resolveOurEntity(after));
    }
    if (before.stationCall != after.stationCall || jsonEncode(before.data) != jsonEncode(after.data)) {
      unawaited(_runtime.refreshControls(after));
      // A program may hold a checklist per place (WAS): a move shows another.
      unawaited(_loadSummaries());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _registerNativePanels();
  }

  @override
  void dispose() {
    widget.services.settings.removeListener(_onSettingsChanged);
    widget.services.extensions.runtimeGeneration.removeListener(_onRuntimeGenerationChanged);
    widget.services.chase.removeListener(_onChaseChanged);
    if (widget.visible) _hidden();
    _runtime.dispose();
    _spotsVisible.dispose();
    super.dispose();
  }

  void _suggestQso(Map<String, dynamic> qso, {bool reveal = true}) {
    setState(() {
      _suggestedQso = zeroBeatSuggestionFor(qso, services: widget.services, offsetter: _zeroBeat);
      _suggestedQsoIsTentative = !reveal;
    });
    if (reveal) dockKey.currentState?.revealModule(ChaseView.loggingPanelId);
  }

  void _withdrawSuggestedQso(String? call) {
    if (!mounted || !_suggestedQsoIsTentative) return;
    final suggested = (_suggestedQso?['their'] as Map?)?['call'] as String?;
    if (call != null && suggested != null && call.toUpperCase() != suggested.toUpperCase()) return;
    setState(() {
      _suggestedQso = null;
      _suggestedQsoIsTentative = false;
    });
  }

  void _logQsoFromSpot(Map<String, dynamic> qso) {
    final zeroBeat = zeroBeatSuggestionFor(qso, services: widget.services, offsetter: _zeroBeat);
    setState(() {
      _suggestedQso = zeroBeat;
      _logRequest = (serial: (_logRequest?.serial ?? 0) + 1, qso: zeroBeat);
    });
  }

  Future<void> _handleCommandAction(String action, [Map<String, dynamic>? params]) => runCommandAction(widget.services, action, params, context);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Qso>>(
      stream: _qsos(),
      builder: (context, snapshot) {
        final operation = _operation;
        final filtered = _filter(snapshot.data ?? const <Qso>[], operation.stationCalls.first);
        _realQsoCount = filtered.qsos.where((q) => q.isRealContact).length;
        // The stream's own list, not the filtered one: that is built again
        // on every build, and a new list is what tells panels the log changed.
        _logForPanels = snapshot.data;
        return _buildScaffold(context, operation, filtered.qsos, filtered.fingerprint);
      },
    );
  }

  Widget _buildScaffold(BuildContext context, Operation operation, List<Qso> qsos, String logRevision) {
    final isTwoPane = ShirtSize.of(context).isTwoPane;
    dockLayoutClass = isTwoPane ? DockLayoutClass.wide : DockLayoutClass.narrow;
    final goals = _goals;
    final loggingControls = chaseLoggingControls(_runtime.loggingControls);
    _spotBoardView?.show(operation, qsos, logRevision: logRevision, chasing: true);

    final loggingPanel = LoggingPanel(
      operation: operation,
      services: widget.services,
      qsos: qsos,
      loggingControls: loggingControls,
      onCommandAction: _handleCommandAction,
      controlsAboveLog: true,
      scope: LoggingScope.chase,
      focusRequest: _focusRequest,
      findRequest: _findRequest,
      showRSTFields: _loggingDisplay('showRSTFields'),
      showStateField: _loggingDisplay('showStateField'),
      showGridField: _loggingDisplay('showGridField'),
      showQsoNumbers: _loggingDisplay('showQsoNumbers'),
      defaultReport: widget.services.settings.defaultReport,
      defaultReportCW: widget.services.settings.defaultReportCW,
      defaultReportFT8: widget.services.settings.defaultReportFT8,
      switchSentRcvd: widget.services.settings.switchSentRcvd,
      jumpAfterRST: widget.services.settings.jumpAfterRST,
      dxFlags: widget.services.settings.dxFlags,
      ourEntityPrefix: _runtime.ourEntityPrefix,
      ourItuRegion: _runtime.ourItuRegion,
      ourCountryCode: _runtime.ourCountryCode,
      suggestedQso: _suggestedQso,
      suggestedQsoIsTentative: _suggestedQsoIsTentative,
      suggestionSettledSerial: _suggestionSettledSerial,
      onCallEdited: () => setState(() => _closeSlidesSerial++),
      logRequest: _logRequest,
      onSelectionChanged: (uuid) => setState(() => _selectedQsoUuid = uuid),
      onCallInfoChanged: (info) => setState(() => _callInfo = info),
      stampQso: (qso) => qsoWithChaseLocation(qso, _location),
    );
    final spotsPanel = SpotsPanel(
      operation: operation,
      services: widget.services,
      onSuggestQso: _suggestQso,
      onWithdrawSuggestion: _withdrawSuggestedQso,
      onSuggestionSettled: () => setState(() => _suggestionSettledSerial++),
      closeSlidesSerial: _closeSlidesSerial,
      onLogQso: _logQsoFromSpot,
      logRevision: logRevision,
      qsos: qsos,
      callInfo: _callInfo,
      visible: _spotsVisible,
      chasing: true,
    );
    final infoPanel = InformationPanel(
      operation: operation,
      qsos: qsos,
      services: widget.services,
      callInfo: _callInfo,
      ourEntityPrefix: _runtime.ourEntityPrefix,
      activityControls: loggingControls,
      statsTitle: _period.statsTitle(context),
      chaseSummaries: _summaries,
    );
    final mapPanel = MapPanel(
      operation: operation,
      qsos: qsos,
      settings: widget.services.settings,
      callInfo: _callInfo,
      selectedQsoUuid: _selectedQsoUuid,
      geoshapes: widget.services.geoshapes,
      activityControls: _runtime.mapControls,
      deviceGrid: widget.services.location.grid,
    );

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        flexibleSpace: windowHeaderGestureArea(),
        leadingWidth: HomeRailLogo.headerReserveOf(context),
        leading: const SizedBox.shrink(),
        // None: the title opens with the sheet's dots, whose own padding is
        // the gap after the mark.
        titleSpacing: 0,
        // Rebuilt with the sheet's slide on its own — the dots and the gap
        // follow it frame by frame, and nothing else in the view does.
        title: AnimatedBuilder(animation: _sheetAnimation ?? kAlwaysDismissedAnimation, builder: (context, _) => _buildTitle(context, operation, goals)),
        actions: [
          ?viewOptionsButton(context, editing: layoutEditing),
          ...layoutHeaderControls(context),
          windowsCaptionSpacer(context),
        ],
      ),
      body: BesideRail(
        child: PaneSafeArea.root(
          context,
          child: withViewOverrides(
            ChaseImportDropTarget(
              onFile: (file) => importDroppedChaseFile(context, widget.services, file, station: stationOfOperation(_operation)),
              child: buildDock(
                children: {
                  ChaseView.loggingPanelId: KeyedSubtree(
                    key: _loggingKey,
                    child: Builder(
                      builder: (context) => KeyboardAccessoryVisibility(visible: DockPaneVisibility.of(context), child: loggingPanel),
                    ),
                  ),
                  ChaseView.spotsPanelId: KeyedSubtree(key: _spotsKey, child: spotsPanel),
                  ChaseView.infoPanelId: infoPanel,
                  ChaseView.mapPanelId: KeyedSubtree(key: _mapKey, child: mapPanel),
                },
                tabActions: {
                  ChaseView.loggingPanelId: (context) => buildTargetSettingsButton(
                    context,
                    target: 'logging',
                    title: context.t.operation.menu.loggingSettingsTitle,
                    groupOverrides: _loggingSettings,
                    // ⌘F's twin, for a device with no keyboard to press it on.
                    actions: [
                      (
                        icon: 'magnify',
                        label: findMenuItemLabel(context.t),
                        onTap: () {
                          Navigator.of(context).pop();
                          _openFind();
                        },
                      ),
                    ],
                  ),
                  ChaseView.mapPanelId: (context) => buildTargetSettingsButton(context, target: 'map', title: context.t.operation.menu.mapSettingsTitle),
                },
                extraChildren: (inLayout) => sharedDashboardPanes(inLayout, operationGrid: operation.displayGrid),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// "**KI2D** chasing **POTA** today": who and what in bold, as one
  /// control that opens the sheet, where the goals and the period are set.
  /// An operator other than the station itself reads "N0DEV (op KI2D)" — not
  /// for the same call under a portable prefix or suffix, which is the
  /// station operating itself.
  Widget _buildTitle(BuildContext context, Operation operation, List<ChaseGoal> goals) {
    final theme = Theme.of(context);
    final t = context.t.chase;
    final on = [
      for (final g in goals)
        if (g.on) g.label,
    ];
    final goalsText = switch (on.length) {
      0 => null,
      1 => on[0],
      2 => t.goalsTwo(first: on[0], second: on[1]),
      _ => t.goalsMore(first: on[0], second: on[1]),
    };
    final foreground = theme.appBarTheme.foregroundColor ?? theme.colorScheme.onPrimary;
    final baseStyle = theme.appBarTheme.titleTextStyle ?? theme.textTheme.titleLarge;
    final bold = baseStyle?.copyWith(fontWeight: FontWeight.bold, color: foreground);
    final regular = baseStyle?.copyWith(fontWeight: FontWeight.normal, color: foreground);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: InkWell(
        key: _headerTitleKey,
        onTap: _sheetProgress > 0 ? null : () => _openSheet(context),
        mouseCursor: SystemMouseCursors.click,
        borderRadius: BorderRadius.circular(8),
        // The operation header's own bump: M3's default overlays barely show
        // on the teal bar.
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed) || states.contains(WidgetState.focused)) return foreground.withValues(alpha: 0.20);
          if (states.contains(WidgetState.hovered)) return foreground.withValues(alpha: 0.16);
          return null;
        }),
        child: Padding(
          padding: const EdgeInsets.only(left: Space.xs, right: Space.lg, top: Space.xxs, bottom: Space.xxs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: _leadingGapWidth,
                height: 32,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: SheetHeaderDots(progress: _sheetProgress),
                ),
              ),
              const SizedBox(width: Space.xs),
              Flexible(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: operation.stationCall, style: bold),
                      if (_distinctOperator(operation) case final operatorCall?) ...[
                        TextSpan(text: ' (${t.operatorPrefix} ', style: regular),
                        TextSpan(text: operatorCall, style: bold),
                        TextSpan(text: ')', style: regular),
                      ],
                      TextSpan(text: ' ${t.chasing} ', style: regular),
                      if (goalsText != null) TextSpan(text: '$goalsText ', style: bold),
                      TextSpan(text: _period.inlineLabel(context), style: regular),
                    ],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The Extensions panel, opened from the sheet's extensions band; then the
  /// controls again, since what was switched on or off there changes which
  /// activities can be chased.
  Future<void> _manageExtensions(BuildContext context) async {
    await showModalPane<void>(
      context,
      title: context.t.activitiesView.manageExtensions,
      closeLabel: context.t.common.close,
      scrollable: false,
      closeButton: false,
      builder: (_) => ExtensionsPanel(services: widget.services, footer: true),
    );
    if (!mounted) return;
    await widget.services.extensions.start();
    if (mounted) await _runtime.refreshControls(_operation);
  }

  /// [operation]'s operator, when it is someone other than the station.
  static String? _distinctOperator(Operation operation) {
    final operatorCall = operatorCallFor(operation);
    if (operatorCall.isEmpty || baseCallOf(operatorCall) == baseCallOf(operation.stationCall)) return null;
    return operatorCall;
  }

  /// The title control's left edge in the overlay the sheet is drawn in — not
  /// in this view, which sits to the right of the home rail while the sheet
  /// spans the whole navigator. Measured against the view, the sheet and its
  /// OK button land a rail's width left of the title.
  double? get _headerTitleLeftInset {
    final box = _headerTitleKey.currentContext?.findRenderObject() as RenderBox?;
    final overlay = Overlay.maybeOf(context)?.context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || overlay == null || !overlay.attached) return null;
    return box.localToGlobal(Offset.zero, ancestor: overlay).dx;
  }

  /// The station and operator callsigns — and nothing else an operation's
  /// details carry: there is no title, notes or position to a chase.
  Future<void> _editStation(BuildContext context) async {
    final result = await editTwoFieldDialog(
      context,
      title: context.t.chase.station.title,
      field1Label: context.t.dialogs.stationCallsign,
      field1Initial: _operation.stationCall,
      field2Label: context.t.settings.operatorCall,
      field2Initial: (asQsonString(_station['operatorCall']) ?? ''),
      callsigns: true,
    );
    if (result == null) return;
    final settings = widget.services.settings;
    final stationCall = result.$1.trim().toUpperCase();
    // The profile's own call is stored as no call at all, so the station goes
    // on following the profile — through a rename of it, too.
    final followsProfile = stationCall.isEmpty || stationCall == settings.activeProfile.operatorCall.trim().toUpperCase();
    await _setOptions({
      'stations': {
        ...?asQsonMap(_options['stations']),
        settings.activeProfileId: {'stationCall': followsProfile ? '' : stationCall, 'operatorCall': result.$2.trim().toUpperCase()},
      },
    });
  }

  /// The same editor an operation's location uses, its answer kept as the
  /// chasing location.
  Future<void> _editLocation(BuildContext context) async {
    final patch = await showHaloDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => OperationLocationScreen(services: widget.services, operation: _operation),
    );
    if (patch == null) return;
    await _setOptions({
      'location': {
        for (final key in _chaseLocationKeys)
          if (patch[key] != null && patch[key] != '') key: patch[key],
      },
    });
  }

  /// The view's sheet — station, location, period and goals — presented the
  /// way an operation's setup sheet is: dropping from the title it aligns
  /// with, with no header band of its own, and an OK button grown out of the
  /// title's dots. Every pill saves as it is used, so OK only closes.
  Future<void> _openSheet(BuildContext context) async {
    await showTopModalPane<void>(
      context,
      onAnimation: (animation) {
        setState(() => _sheetAnimation = animation);
        void status(AnimationStatus value) {
          if (value != AnimationStatus.dismissed) return;
          animation.removeStatusListener(status);
          if (mounted && identical(_sheetAnimation, animation)) setState(() => _sheetAnimation = null);
        }

        animation.addStatusListener(status);
      },
      leftInset: _headerTitleLeftInset,
      scrollable: false,
      barrierDismissible: true,
      keepHeaderVisible: true,
      showHeader: false,
      headerLeading: Builder(
        builder: (context) => SheetAcceptHandoff(
          animation: _sheetAnimation,
          child: KeyedSubtree(
            key: _sheetOkButtonKey,
            child: FilledButton.icon(
              icon: const Icon(MdiIcons.check),
              label: Text(context.t.common.ok),
              style: FilledButton.styleFrom(backgroundColor: fabAccentColor, foregroundColor: Theme.of(context).colorScheme.onPrimary),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ),
      ),
      builder: (context) => ListenableBuilder(
        listenable: Listenable.merge([widget.services.settings, _runtime]),
        // The sheet's full height, like an operation's: the goals list takes
        // whatever the bands above and below it leave.
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ChaseStationBand(
              operation: _operation,
              deviceGrid: widget.services.location.grid,
              period: _period,
              alerting: widget.services.chase.alerting,
              onEditStation: () => _editStation(context),
              onEditLocation: () => _editLocation(context),
              onPeriod: (period) => unawaited(_setOptions({'period': period.name})),
              onAlerting: (alerting) => unawaited(widget.services.chase.setAlerting(alerting)),
            ),
            Expanded(
              child: _ChaseGoalsEditor(
                goals: _goals,
                onChanged: _setGoals,
                importersOf: (key) => widget.services.chase.programs[key]?.imports ?? const [],
                onImport: (key, importer) {
                  final program = widget.services.chase.programs[key];
                  if (program != null) unawaited(runChaseImport(context, widget.services, program, importer, station: stationOfOperation(_operation)));
                },
                onManageExtensions: () => _manageExtensions(context),
                extensionsExpanded: _options['extensionsHidden'] != true,
                onToggleExtensions: () => unawaited(_setOptions({'extensionsHidden': _options['extensionsHidden'] != true})),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The sheet's top band: the goals' title, then the chasing station's
/// callsigns, where it is chasing from, and the span of the log the view
/// shows — each a pill that opens its editor.
class _ChaseStationBand extends StatelessWidget {
  /// What the title keeps before the pills wrap — room for "Chasing Goals"
  /// and the gutter it holds against them.
  static const _titleMinWidth = 160.0;

  final Operation operation;
  final String? deviceGrid;
  final ChasePeriod period;

  /// The verdicts that alert — see [ChaseService.alerting].
  final Set<ChaseVerdict> alerting;
  final VoidCallback onEditStation;
  final VoidCallback onEditLocation;
  final ValueChanged<ChasePeriod> onPeriod;
  final ValueChanged<Set<ChaseVerdict>> onAlerting;

  const _ChaseStationBand({
    required this.operation,
    required this.deviceGrid,
    required this.period,
    required this.alerting,
    required this.onEditStation,
    required this.onEditLocation,
    required this.onPeriod,
    required this.onAlerting,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.t.chase.station;
    final chipColor = theme.appBarTheme.backgroundColor ?? theme.colorScheme.primary;
    final textStyle = theme.textTheme.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold);
    const callStyle = TextStyle(fontFamily: 'RobotoMono');
    final operatorCall = operatorCallFor(operation);
    final located = operation.location != null;
    final pin = located ? operationLocationPin(operation, deviceGrid: deviceGrid) : (icon: MdiIcons.mapMarkerOff, color: const Color(0xFFC62828));

    // [onTap] null leaves the tap to whatever wraps the pill — the period's
    // menu button.
    Widget pill({required Color color, VoidCallback? onTap, required Widget child}) {
      final content = Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.xs),
        child: DefaultTextStyle.merge(style: textStyle, maxLines: 1, overflow: TextOverflow.ellipsis, child: child),
      );
      return Material(
        color: color,
        borderRadius: BorderRadius.circular(12),
        child: onTap == null ? content : InkWell(borderRadius: BorderRadius.circular(12), onTap: onTap, child: content),
      );
    }

    // The operation sheet's header row: the section's title at left, the pills
    // at right at their natural width, taking all but [_titleMinWidth] of the
    // row before they wrap under themselves.
    return Material(
      color: haloDialogBandColorAt(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.xl, Space.md, Space.lg, Space.md),
        child: LayoutBuilder(
          builder: (context, constraints) => Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: Space.xl),
                  child: Text(
                    context.t.chase.goals.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: math.max(0.0, constraints.maxWidth - _titleMinWidth)),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: Space.sm,
                  runSpacing: Space.xs,
                  children: [
                    pill(
                      color: chipColor,
                      onTap: onEditStation,
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: t.stationLabel),
                            TextSpan(text: operation.stationCall, style: callStyle),
                            if (operatorCall.isNotEmpty) ...[TextSpan(text: '  ${t.operatorLabel}'), TextSpan(text: operatorCall, style: callStyle)],
                          ],
                        ),
                      ),
                    ),
                    pill(
                      color: pin.color,
                      onTap: onEditLocation,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(pin.icon, size: 16, color: Colors.white),
                          const SizedBox(width: Space.xs),
                          Text(located ? (operation.displayGrid ?? '') : t.noLocation, style: located ? callStyle : null),
                        ],
                      ),
                    ),
                    PopupMenuButton<ChasePeriod>(
                      initialValue: period,
                      onSelected: onPeriod,
                      itemBuilder: (context) => [for (final p in ChasePeriod.values) PopupMenuItem(value: p, child: Text(p.label(context)))],
                      child: pill(
                        color: chipColor,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(MdiIcons.calendarRange, size: 16, color: Colors.white),
                            const SizedBox(width: Space.xs),
                            Text(period.label(context)),
                            const Icon(MdiIcons.menuDown, size: 18, color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                    // Each pick toggles one verdict; worked, which nothing
                    // new comes of, is not one to alert on.
                    PopupMenuButton<ChaseVerdict>(
                      onSelected: (verdict) => onAlerting(alerting.contains(verdict) ? ({...alerting}..remove(verdict)) : {...alerting, verdict}),
                      itemBuilder: (context) => [
                        for (final verdict in ChaseVerdict.values.reversed)
                          if (verdict != ChaseVerdict.worked)
                            CheckedPopupMenuItem(value: verdict, checked: alerting.contains(verdict), child: Text(_alertLabel(context, verdict))),
                      ],
                      child: pill(
                        color: chipColor,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(alerting.isEmpty ? MdiIcons.bellOffOutline : MdiIcons.bellRingOutline, size: 16, color: Colors.white),
                            const SizedBox(width: Space.xs),
                            Text(context.t.chase.alerts.title),
                            const Icon(MdiIcons.menuDown, size: 18, color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _alertLabel(BuildContext context, ChaseVerdict verdict) => switch (verdict) {
  ChaseVerdict.newRef => context.t.chase.alerts.newRef,
  ChaseVerdict.newBand => context.t.chase.alerts.newBand,
  ChaseVerdict.newMode => context.t.chase.alerts.newMode,
  ChaseVerdict.unconfirmed || ChaseVerdict.worked => context.t.chase.alerts.unconfirmed,
};

/// The goals sheet's body: the programs being chased, in order — each
/// dragged by its icon and dropped with its trash button — and, below them,
/// a band offering the rest, the way an operation's sheet offers its
/// activity types.
class _ChaseGoalsEditor extends StatefulWidget {
  final List<ChaseGoal> goals;
  final ValueChanged<List<ChaseGoal>> onChanged;
  final VoidCallback onManageExtensions;

  /// The files a goal's program imports, each offered on its row.
  final List<ChasingImporter> Function(String key) importersOf;
  final void Function(String key, ChasingImporter importer) onImport;

  /// Whether the extensions band is open — the operator's to decide, and
  /// remembered with the view's other options, like the operation sheet's
  /// own Activity Types band.
  final bool extensionsExpanded;
  final VoidCallback onToggleExtensions;

  const _ChaseGoalsEditor({
    required this.goals,
    required this.onChanged,
    required this.onManageExtensions,
    required this.importersOf,
    required this.onImport,
    required this.extensionsExpanded,
    required this.onToggleExtensions,
  });

  @override
  State<_ChaseGoalsEditor> createState() => _ChaseGoalsEditorState();
}

class _ChaseGoalsEditorState extends State<_ChaseGoalsEditor> {
  /// The activity's icon on its accent, the operation sheet's own treatment
  /// of an activity type.
  static Widget _goalIcon(ChaseGoal goal) {
    final color = resolveExtensionColor(goal.color);
    final icon = Icon(resolveIconName(goal.icon));
    return CircleAvatar(backgroundColor: color?.withValues(alpha: 0.6), child: icon);
  }

  /// One button for a program that imports one kind of file, a menu for
  /// one that imports several, nothing for one that imports none.
  List<Widget> _importButtons(BuildContext context, ChaseGoal goal) {
    final t = context.t.chase.imports;
    final importers = widget.importersOf(goal.key);
    if (importers.isEmpty) return const [];
    if (importers.length == 1) {
      final importer = importers.single;
      return [
        IconButton(
          icon: Icon(MdiIcons.fileImportOutline, semanticLabel: t.importFrom(label: importer.label)),
          onPressed: () => widget.onImport(goal.key, importer),
        ),
      ];
    }
    return [
      PopupMenuButton<ChasingImporter>(
        icon: Icon(MdiIcons.fileImportOutline, semanticLabel: t.importFrom(label: goal.label)),
        onSelected: (importer) => widget.onImport(goal.key, importer),
        itemBuilder: (context) => [
          for (final importer in importers)
            PopupMenuItem(
              value: importer,
              child: Text(t.importFrom(label: importer.label)),
            ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.chase.goals;
    final theme = Theme.of(context);
    final rowColor = haloSheetRowColor(context);
    final bandColor = haloDialogBandColorAt(context);
    final onBandColor = theme.colorScheme.onSurfaceVariant;
    final chased = [
      for (final goal in widget.goals)
        if (goal.on) goal,
    ];
    final available = [
      for (final goal in widget.goals)
        if (!goal.on) goal,
    ];
    // Stored as ONE list, chased first: dropping a goal moves it out of the
    // order, and adding one puts it at the end of what is chased.
    void save(List<ChaseGoal> chasedNow, List<ChaseGoal> availableNow) => widget.onChanged([...chasedNow, ...availableNow]);

    return Material(
      color: haloSheetListBackground(context),
      child: LayoutBuilder(
        builder: (context, constraints) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Everything the extensions band does not take.
            Expanded(
              child: ReorderableListView(
                buildDefaultDragHandles: false,
                onReorderItem: (from, to) {
                  final reordered = [...chased];
                  reordered.insert(to, reordered.removeAt(from));
                  save(reordered, available);
                },
                children: [
                  for (final (index, goal) in chased.indexed)
                    ListTile(
                      key: ValueKey(goal.key),
                      tileColor: rowColor,
                      leading: ReorderableDragStartListener(
                        index: index,
                        child: MouseRegion(cursor: SystemMouseCursors.grab, child: _goalIcon(goal)),
                      ),
                      title: Text(goal.label),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ..._importButtons(context, goal),
                          IconButton(
                            icon: Icon(MdiIcons.trashCanOutline, semanticLabel: t.remove(name: goal.label)),
                            onPressed: () => save(
                              [
                                for (final g in chased)
                                  if (g.key != goal.key) g,
                              ],
                              [goal.withOn(false), ...available],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            CollapsibleSection.band(
              title: Padding(
                padding: const EdgeInsets.only(right: Space.xl),
                child: Text(
                  t.extensionsTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(color: onBandColor, fontWeight: FontWeight.w600),
                ),
              ),
              expanded: widget.extensionsExpanded,
              onToggle: widget.onToggleExtensions,
              headerColor: bandColor,
              onHeaderColor: onBandColor,
              trailing: TextButton.icon(
                onPressed: widget.onManageExtensions,
                icon: Icon(MdiIcons.toyBrick, size: 18, color: onBandColor),
                label: Text(context.t.activitiesView.manage, style: TextStyle(color: onBandColor)),
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: Space.lg)),
              ),
              // Only as tall as its rows, and never more than half the sheet —
              // past that it scrolls, so the chased list keeps the rest.
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: constraints.maxHeight / 2),
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  // Its own ink layer inside the viewport, so a row scrolled out
                  // of it doesn't paint its background over the list above (see
                  // the operation sheet's Activity Types).
                  child: Material(
                    type: MaterialType.transparency,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final goal in available)
                          ListTile(
                            tileColor: rowColor,
                            leading: _goalIcon(goal),
                            title: Text(goal.label),
                            onTap: () => save(
                              [...chased, goal.withOn(true)],
                              [
                                for (final g in available)
                                  if (g.key != goal.key) g,
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
