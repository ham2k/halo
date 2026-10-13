// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:intl/intl.dart';

import 'package:halo_i18n/halo_i18n.dart';
import '../services/halo_services.dart';
import 'app_shell/home_rail_state.dart';
import '../services/adif_import_plan.dart';
import '../services/adif_import_service.dart';
import '../services/error_reporting_service.dart';
import '../services/panel_service.dart';
import '../services/settings_service.dart';
import '../services/status_bar_service.dart';
import '../settings/settings_target_dialog.dart';
import '../tools/operation_title.dart';
import 'dock_host.dart';
import 'home_navigation_rail.dart';
import 'operation/adif_import_flow.dart';
import 'operation/call_info_panel.dart';
import 'operation/extension_panel.dart';
import 'operation/map_panel.dart';
import 'operation_view.dart';
import 'sheet_header_dots.dart';

part 'logs/logs_table.dart';
part 'logs/logs_side_panes.dart';
part 'logs/logs_edit_panel.dart';
part 'logs/logs_adif_drop.dart';
part 'logs/logs_sheet.dart';
part 'logs/logs_groups.dart';

/// The Logs destination's active filter (docs card HALO-273) — one station
/// callsign, or all of them at once, with room to grow into other filter
/// dimensions. [_LogsViewState] is the only writer; the QSO table only reads
/// it, so it doesn't need to know how the callsign was picked.
class LogFilter {
  final String? stationCall;

  /// Every station callsign together; [stationCall] is null then.
  final bool allCalls;

  const LogFilter({this.stationCall}) : allCalls = false;

  const LogFilter.all() : stationCall = null, allCalls = true;

  bool get isEmpty => stationCall == null && !allCalls;

  bool sameAs(LogFilter other) => stationCall == other.stationCall && allCalls == other.allCalls;
}

/// The Logs destination (gated behind the `logs` experiment, see
/// [HomeNavigationRail]): a user-arrangeable dock, like Home and the
/// operation view, holding a virtualized table of the selected callsign's
/// QSOs across every operation, an info panel, and a map — the latter two
/// scoped to whichever QSO is selected. The callsign picker, QSO count, date
/// span and search field live in the QSO table pane's OWN header, not a
/// page-wide bar — see [_QsoListPanel].
///
/// Tapping a QSO selects it — the same "one row is the selected QSO, its
/// fields open for editing" relationship `LoggingPanel` has with its own
/// `_selectedQso`, just lifted here so the info/map panels can read it too.
class LogsView extends StatefulWidget {
  static const layoutPolicy = ViewLayoutPolicy.customizable;

  static const qsoTablePanelId = 'logsQsoTable';
  static const infoPanelId = 'logsInfo';
  static const mapPanelId = 'logsMap';

  final HaLoServices services;

  const LogsView({super.key, required this.services});

  @override
  State<LogsView> createState() => _LogsViewState();
}

class _LogsViewState extends State<LogsView> with DockHost<LogsView>, _LogsAdifDrop {
  @override
  HaLoServices get dockServices => widget.services;

  @override
  String get dockView => PanelViews.logs;

  @override
  DockLayoutKeys dockKeysFor(DockLayoutClass layoutClass) => switch (layoutClass) {
    DockLayoutClass.wide => const DockLayoutKeys(
      spec: LayoutKeys.logsDock,
      state: LayoutKeys.logsDockState,
      paneOptions: LayoutKeys.logsPaneOptions,
      viewOptions: LayoutKeys.logsViewOptions,
    ),
    DockLayoutClass.narrow => const DockLayoutKeys(
      spec: LayoutKeys.logsNarrowDock,
      state: LayoutKeys.logsNarrowDockState,
      paneOptions: LayoutKeys.logsNarrowPaneOptions,
      viewOptions: LayoutKeys.logsNarrowViewOptions,
    ),
  };

  @override
  Set<String> get nativeModuleIds => const {LogsView.qsoTablePanelId, LogsView.infoPanelId, LogsView.mapPanelId};

  @override
  Map<String, String> get nativeTitles => {
    LogsView.qsoTablePanelId: context.t.home.logs.panels.qsos,
    LogsView.infoPanelId: context.t.home.logs.panels.info,
    LogsView.mapPanelId: context.t.home.logs.panels.map,
  };

  /// The QSO table pane carries its own rich header (picker, count, date
  /// span, search) — the dock's generic title bar would just repeat "QSO
  /// Log" above it. Info and Map keep theirs; only this one's off by default.
  @override
  Set<String> get defaultHeaderlessModules => const {LogsView.qsoTablePanelId};

  /// No live operation/qso/spots triggers to fire — same reasoning as
  /// Home's: this view has no single "current" operation for those triggers
  /// to mean anything against.
  @override
  PanelRenderContext get panelRenderContext => const PanelRenderContext();

  /// The map is reached through a target rather than through `formFields`,
  /// so its settings embed as the same target-scoped widget
  /// [_buildMapSettingsButton]'s dialog would show — see OperationView's own
  /// copy of this override.
  @override
  WidgetBuilder? nativePanelSettingsForm(BuildContext context, String id) => switch (id) {
    LogsView.mapPanelId => (builderContext) => settingsFormForTarget(services: widget.services, target: 'map'),
    _ => null,
  };

  /// The table beside the info+map column, stacked — the shipped arrangement.
  /// No migration to fold in: this dock has no pre-dock history like Home's.
  ///
  /// Narrow ships as the table alone. Info and Map stay addable from the
  /// sheet, and arrive as TABS: three groups sharing a phone's width is three
  /// panes none of which can be read.
  @override
  DockNode buildDefaultDockSpec(DockLayoutClass layoutClass, {bool migrate = true}) => switch (layoutClass) {
    DockLayoutClass.narrow => DockGroup([LogsView.qsoTablePanelId]),
    DockLayoutClass.wide => DockSplit(
      Axis.horizontal,
      [
        DockGroup([LogsView.qsoTablePanelId]),
        DockSplit(
          Axis.vertical,
          [
            DockGroup([LogsView.infoPanelId]),
            DockGroup([LogsView.mapPanelId]),
          ],
          [1, 1],
        ),
      ],
      [2, 1],
    ),
  };

  void _registerNativePanels() {
    final t = context.t.home.logs.panels;
    final service = widget.services.panels;
    service.registerNative(
      PanelDefinition(
        id: LogsView.qsoTablePanelId,
        title: t.qsos,
        description: t.qsosDescription,
        icon: 'notebook',
        source: PanelSource.native,
        views: const {PanelViews.logs},
      ),
    );
    service.registerNative(
      PanelDefinition(
        id: LogsView.infoPanelId,
        title: t.info,
        description: t.infoDescription,
        icon: 'informationOutline',
        source: PanelSource.native,
        views: const {PanelViews.logs},
      ),
    );
    service.registerNative(
      PanelDefinition(
        id: LogsView.mapPanelId,
        title: t.map,
        description: t.mapDescription,
        icon: 'map',
        source: PanelSource.native,
        views: const {PanelViews.logs},
      ),
    );
    registerSharedDashboardPanels();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _registerNativePanels();
  }

  @override
  LogFilter _filter = const LogFilter();

  /// Whether [_filter] is the lone station callsign the view settled on by
  /// itself (see [_subscribeCallsigns]) rather than one the operator picked —
  /// the one kind a second callsign arriving should widen.
  bool _pinnedAlone = false;
  late _LogsColumnWidths _columnWidths;

  /// Which of [_allLogsColumns] the QSO table currently shows — toggled from
  /// the right-click menu (see [_openColumnMenu]). Never empty: [_toggleColumnVisible]
  /// refuses to remove the last one, so the table can't end up with no
  /// columns and no way back short of clearing app data.
  late Set<String> _visibleColumns;

  /// Left-to-right order of all [_allLogsColumns], Name included — whichever
  /// ends up trailing (after hiding) is the one [_LogsTableWidth] stretches
  /// to fill the pane. Dragged from [_QsoListHeaderRow]; see [_moveColumn].
  late List<String> _columnOrder;

  late _LogsSort _sort;

  String? _selectedUuid;

  /// The row ↑/↓ steps from while nothing is selected — the one selected
  /// last, so closing the editor doesn't send the keyboard back to the top.
  String? _keyboardAnchor;

  /// A new key per selection: it remounts the editor with fresh controllers
  /// (see [_LogQsoEditPanel]), and it is how [_settleEditor] reaches the one
  /// on screen.
  GlobalKey<_LogQsoEditPanelState> _editorKey = GlobalKey();

  final _listFocus = FocusNode(debugLabel: 'logsQsoList');
  final _listScroll = ScrollController();

  /// What the table is filtered by — the search field's text once typing
  /// has paused for [_searchDebounce], or at once on Enter (see
  /// [_searchTyped]).
  String _searchQuery = '';
  final _searchController = TextEditingController();

  /// Each search refilters and re-sorts a log that can run to tens of
  /// thousands of QSOs, so a keystroke alone doesn't start one: the typing
  /// has to stop first.
  static const _searchDebounce = Duration(milliseconds: 700);
  Timer? _searchTimer;

  /// Cached from the callsigns stream (see [_subscribeCallsigns]), call ->
  /// its QSO count — the picker menu needs a synchronous map to build its
  /// items from (the count becomes a pill next to each entry).
  Map<String, int> _callsigns = const {};

  /// `false` until the callsigns stream delivers its first snapshot — the
  /// view shows a spinner for that stretch rather than the "select a
  /// callsign" prompt, which would otherwise flash before there is anything
  /// to select.
  bool _callsignsLoaded = false;
  StreamSubscription<Map<String, int>>? _callsignsSubscription;

  /// Empty until a filter is picked — the query needs one, so there is
  /// nothing to watch before then.
  Stream<List<Qso>>? _qsosStream;

  LogsGrouping _grouping = LogsGrouping.date;

  /// Per grouping, the groups the operator has turned from how they start
  /// ([LogsGrouping.startsCollapsed]), by [LogsGrouping.pathOf] path: closed
  /// ones under Date, opened ones under DX. Stored with the filter, and each
  /// set replaced rather than changed, so the row cache can tell by identity.
  Map<LogsGrouping, Set<String>> _toggled = const {};

  bool _isCollapsed(LogsGrouping grouping, String path) => grouping.startsCollapsed != (_toggled[grouping]?.contains(path) ?? false);

  /// The span of the log on screen, applied to the stream's QSOs before the
  /// search and the sort (see [_inPeriod]).
  LogsPeriod _period = LogsPeriod.allTime;

  /// The days [LogsPeriod.custom] spans, end day included — kept while
  /// another period is picked, so going back to Custom finds it again.
  DateTimeRange? _customRange;

  final _headerTitleKey = GlobalKey();

  /// Ticks whenever anything the open sheet shows changes — the callsigns
  /// and their counts, the filter, the grouping, the period. The sheet's
  /// route is not under this view, so this view's own rebuilds never reach
  /// it, and changes the view makes on its own (a callsign falling back to
  /// All) write nothing a settings listener would hear.
  final _sheetRevision = ValueNotifier(0);

  /// The sheet's slide while it is up or going away — what the header's dots
  /// and the leading gap behind the OK button follow. Cleared once the slide
  /// has finished closing, so the dots don't snap back while the sheet is
  /// still on its way out.
  Animation<double>? _sheetAnimation;

  /// The sheet's OK button, measured so the title's leading gap can open to
  /// its width — it draws over this corner of the header, not inside it.
  final _sheetOkButtonKey = GlobalKey();

  double get _sheetProgress => _sheetAnimation?.value ?? 0.0;

  /// The OK button's laid-out width, or null when it cannot be read — see
  /// ChaseView's own copy of this read for why it is guarded.
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

  /// The title control's left edge in the overlay the sheet is drawn in,
  /// which spans the whole navigator rather than this view beside the rail.
  double? get _headerTitleLeftInset {
    final box = _headerTitleKey.currentContext?.findRenderObject() as RenderBox?;
    final overlay = Overlay.maybeOf(context)?.context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || overlay == null || !overlay.attached) return null;
    return box.localToGlobal(Offset.zero, ancestor: overlay).dx;
  }

  // The search, the sort and the date-range scan are each at least O(n)
  // over the whole log, which the QSO scale this view targets (see
  // `_QsoListPanel`'s own doc comment) makes worth not repeating: this
  // widget's `build` reruns on state changes that don't touch the QSO list,
  // the search text or the sort at all, e.g. selecting a row. Keyed on the
  // identity of the source list (unchanged across an unrelated rebuild,
  // since it's the same snapshot from the stream) rather than deep-equality,
  // and on the identity of [_sort], which is replaced rather than mutated.
  // Two levels: the grouped order, then the rows over it — a header tap
  // changes only what is collapsed, and must not re-sort the whole log.
  List<Qso>? _cachedRowsSource;
  String? _cachedRowsQuery;
  _LogsSort? _cachedRowsSort;
  _LogsGrouped? _cachedGrouped;
  Set<String>? _cachedRowsToggled;

  /// Also what the keyboard steps through: it is exactly what is on screen.
  _LogsTableRows? _cachedRows;
  List<Qso>? _cachedRangeSource;
  (int, int)? _cachedRange;
  List<Qso>? _cachedFreqDigitsSource;
  int? _cachedFreqDigits;

  List<Qso>? _cachedPeriodSource;
  ({int? start, int? end})? _cachedPeriodBounds;
  List<Qso>? _cachedPeriodQsos;

  /// [qsos] cut down to [_period] — the same list instance while neither the
  /// source nor the bounds move, so the row cache below keeps hitting. A QSO
  /// with no start time falls in no period but All time, where Date grouping
  /// gives it a group of its own.
  List<Qso> _inPeriod(List<Qso> qsos) {
    final bounds = _period.bounds(nowUtc(), range: _customRange);
    if (bounds.start == null && bounds.end == null) return qsos;
    if (identical(qsos, _cachedPeriodSource) && bounds == _cachedPeriodBounds) return _cachedPeriodQsos!;
    final start = bounds.start;
    final end = bounds.end;
    final list = [
      for (final qso in qsos)
        if (qso.startAtMillis case final at? when (start == null || at >= start) && (end == null || at < end)) qso,
    ];
    _cachedPeriodSource = qsos;
    _cachedPeriodBounds = bounds;
    _cachedPeriodQsos = list;
    return list;
  }

  _LogsTableRows _tableRowsFor(List<Qso> qsos) {
    var grouped = _cachedGrouped;
    if (grouped == null ||
        !identical(qsos, _cachedRowsSource) ||
        _searchQuery != _cachedRowsQuery ||
        !identical(_sort, _cachedRowsSort) ||
        grouped.grouping != _grouping) {
      grouped = _LogsGrouped(_sortedQsos(_applySearch(qsos), _sort), grouping: _grouping, sort: _sort);
      _cachedRowsSource = qsos;
      _cachedRowsQuery = _searchQuery;
      _cachedRowsSort = _sort;
      _cachedGrouped = grouped;
    }
    final cached = _cachedRows;
    if (cached != null && identical(cached.grouped, grouped) && identical(_toggled[_grouping], _cachedRowsToggled)) return cached;
    final rows = _LogsTableRows(grouped, collapsed: (path) => _isCollapsed(_grouping, path));
    _cachedRowsToggled = _toggled[_grouping];
    _cachedRows = rows;
    return rows;
  }

  (int, int)? _cachedMillisRange(List<Qso> list) {
    if (identical(list, _cachedRangeSource)) return _cachedRange;
    final range = _millisRange(list.map((qso) => qso.startAtMillis));
    _cachedRangeSource = list;
    _cachedRange = range;
    return range;
  }

  int _cachedMaxFreqMhzDigits(List<Qso> list) {
    if (identical(list, _cachedFreqDigitsSource)) return _cachedFreqDigits!;
    final digits = _maxFreqMhzDigits(list);
    _cachedFreqDigitsSource = list;
    _cachedFreqDigits = digits;
    return digits;
  }

  /// Shared between the two-pane dock and the narrow single-pane fallback in
  /// [_buildScaffold] — same widget instance under the same key in both, so
  /// crossing the `isTwoPane` boundary reparents the live list (selection,
  /// scroll position, in-progress search) instead of rebuilding it from
  /// scratch, the same way `HomeView`'s own narrow fallback does.
  final _qsoListPaneKey = GlobalKey();

  static const _searchFieldWidth = 280.0;

  @override
  void initState() {
    super.initState();
    // Same self-tracking `SettingsView` does — this pane is unmounted while
    // hidden (see `HomeView`'s `_logsSlide` `isDismissed` check) and remounted
    // fresh each time the destination switches back to it, so `initState` is
    // exactly "a visit started".
    widget.services.track('screen_viewed', {'screen': 'logs'});
    final settings = widget.services.settings;
    _columnWidths = _LogsColumnWidths.fromMap(settings.layoutData(LayoutKeys.logsQsoColumnWidths));
    // A column the stored map doesn't mention — one added since it was last
    // written — takes its default rather than appearing unasked.
    final storedVisibility = settings.layoutData(LayoutKeys.logsQsoVisibleColumns);
    final visible = {
      for (final column in _allLogsColumns)
        if (switch (storedVisibility?[column]) {
          final bool shown => shown,
          _ => _defaultVisibleLogsColumns.contains(column),
        })
          column,
    };
    // Never empty (see the field's doc), stored or not: a header with no
    // columns leaves no label to right-click for the menu that fixes it.
    _visibleColumns = visible.isEmpty ? {..._defaultVisibleLogsColumns} : visible;
    // Every stored read here tolerates a shape it doesn't expect: a throw in
    // `initState` takes the column menu — the only way to reset them — down
    // with the view.
    _columnOrder = _healedColumnOrder(switch (settings.layoutData(LayoutKeys.logsQsoColumnOrder)?['order']) {
      final List<dynamic> order => order.whereType<String>().toList(),
      _ => const [],
    });
    _sort = _LogsSort.fromMap(settings.layoutData(LayoutKeys.logsQsoSort));
    final storedFilter = settings.layoutData(LayoutKeys.logsFilter);
    _period = LogsPeriod.values.asNameMap()[storedFilter?['period']] ?? LogsPeriod.allTime;
    _grouping = LogsGrouping.values.asNameMap()[storedFilter?['group']] ?? LogsGrouping.date;
    if (storedFilter?['toggled'] case final Map<String, dynamic> toggled) {
      _toggled = {
        for (final MapEntry(:key, :value) in toggled.entries)
          if ((LogsGrouping.values.asNameMap()[key], value) case (final grouping?, final List<dynamic> paths)) grouping: paths.whereType<String>().toSet(),
      };
    }
    if ((DateTime.tryParse('${storedFilter?['from']}'), DateTime.tryParse('${storedFilter?['to']}')) case (final from?, final to?) when !to.isBefore(from)) {
      _customRange = DateTimeRange(start: from, end: to);
    }
    // Custom with no days to span would show all time under a title that
    // says otherwise.
    if (_period == LogsPeriod.custom && _customRange == null) _period = LogsPeriod.allTime;
    homeRail.setLeaveGuard(HomeDestination.logs, _settleAndClose);
    _subscribeCallsigns();
  }

  /// Self-healing rather than all-or-nothing: an id this build no longer
  /// recognizes (a future rename) is dropped instead of discarding the whole
  /// order, and one this build knows but [stored] doesn't (a column added
  /// since) goes in right after the column it follows by default — appended
  /// instead, it would land after Name and take over as the stretching
  /// trailing column the moment it was switched on.
  static List<String> _healedColumnOrder(List<String> stored) {
    final order = stored.where(_allLogsColumns.contains).toList();
    for (final (index, column) in _allLogsColumns.indexed) {
      if (order.contains(column)) continue;
      final after = index == 0 ? -1 : order.indexOf(_allLogsColumns[index - 1]);
      order.insert(after + 1, column);
    }
    return order;
  }

  @override
  void dispose() {
    homeRail.clearLeaveGuard(HomeDestination.logs, _settleAndClose);
    unawaited(_callsignsSubscription?.cancel());
    _listFocus.dispose();
    _listScroll.dispose();
    _searchTimer?.cancel();
    _searchController.dispose();
    _sheetRevision.dispose();
    super.dispose();
  }

  /// Also called by [_resumeLog] once an ADIF import's writes are done (see
  /// [_pauseLog]). Requests a fresh stream each time rather than reusing one
  /// cached instance: Drift's `.watch()` streams are single-subscription, so
  /// a stream already cancelled once cannot be listened to again.
  void _subscribeCallsigns() {
    _callsignsSubscription = widget.services.qsos.watchDistinctOurCalls().listen((calls) {
      setState(() {
        _callsignsLoaded = true;
        _callsigns = calls;
      });
      _sheetRevision.value++;
      if (calls.isEmpty) return;
      if (calls.length == 1) {
        // One station callsign is all there is to show, so the view is its
        // — and says so in the title, with no picker (see [_buildTitle]).
        // Kept selection: every QSO still in the log is still in this list,
        // so an editor open on one stays open, edit and all.
        _applyFilter(LogFilter(stationCall: calls.keys.single), remember: false, keepSelection: !_filter.isEmpty);
        _pinnedAlone = true;
      } else if (_pinnedAlone) {
        // A second callsign under a filter the view chose, not the operator:
        // All, so the new callsign's QSOs show — not the stored pick, which
        // could hide the QSO an open editor is on, where All keeps it.
        _pinnedAlone = false;
        _applyFilter(const LogFilter.all(), remember: false, keepSelection: true);
      } else if (_filter.isEmpty) {
        // A fresh view opens on the last pick, or on All when there is none
        // (or its callsign has nothing left behind it).
        final stored = widget.services.settings.layoutData(LayoutKeys.logsFilter)?['call'];
        _applyFilter(stored is String && calls.containsKey(stored) ? LogFilter(stationCall: stored) : const LogFilter.all(), remember: false);
      } else if (!_filter.allCalls && !calls.containsKey(_filter.stationCall)) {
        // The selected callsign's last QSO is gone: rather than sit on an
        // empty list, fall back to everything. Not remembered — the pick
        // stands if that callsign logs again.
        _applyFilter(const LogFilter.all(), remember: false);
      }
    });
  }

  @override
  Future<void> _pauseLog() async {
    await _callsignsSubscription?.cancel();
    _callsignsSubscription = null;
    if (mounted) setState(() => _qsosStream = null);
  }

  @override
  void _resumeLog(LogFilter filter) {
    _subscribeCallsigns();
    setState(() => _qsosStream = _streamFor(filter));
  }

  Stream<List<Qso>>? _streamFor(LogFilter filter) {
    if (filter.allCalls) return widget.services.qsos.watchForAnyOurCall();
    final call = filter.stationCall;
    return call == null ? null : widget.services.qsos.watchForOurCalls([call]);
  }

  /// Switches the list to [filter] without asking — the operator's picks go
  /// through [_pickFilter], which settles the editor first. [keepSelection]
  /// is for a switch the log made on its own, which must not close an editor
  /// the operator never asked to leave.
  void _applyFilter(LogFilter filter, {bool remember = true, bool keepSelection = false}) {
    if (filter.sameAs(_filter)) return;
    setState(() {
      _filter = filter;
      _qsosStream = _streamFor(filter);
      if (!keepSelection) {
        // The old selection and search belonged to the previous list.
        _selectedUuid = null;
        _keyboardAnchor = null;
        _editorKey = GlobalKey();
        _searchTimer?.cancel();
        _searchController.clear();
        _searchQuery = '';
      }
    });
    _sheetRevision.value++;
    if (remember) _rememberFilter(call: true);
  }

  /// The grouping and the period, and with [call] the callsign as the
  /// operator just picked it — one stored map, so writing any keeps the rest. A callsign the view
  /// fell back to on its own is never written over the operator's pick.
  void _rememberFilter({bool call = false}) {
    final settings = widget.services.settings;
    final range = _customRange;
    unawaited(
      settings.setLayoutData(LayoutKeys.logsFilter, {
        ...?settings.layoutData(LayoutKeys.logsFilter),
        if (call) 'call': _filter.allCalls ? null : _filter.stationCall,
        'group': _grouping.name,
        'toggled': {for (final MapEntry(:key, :value) in _toggled.entries) key.name: value.toList()},
        'period': _period.name,
        'from': range == null ? null : _dateFormat.format(range.start),
        'to': range == null ? null : _dateFormat.format(range.end),
      }),
    );
  }

  /// [LogsPeriod.custom] asks for its days first, and is not taken without
  /// them.
  Future<void> _pickPeriod(LogsPeriod period) async {
    var range = _customRange;
    if (period == LogsPeriod.custom) {
      final now = nowUtc();
      final today = DateTime(now.year, now.month, now.day);
      range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(1900),
        lastDate: today,
        initialDateRange: range == null || range.end.isAfter(today) ? null : range,
      );
      if (range == null || !mounted) return;
    } else if (period == _period) {
      return;
    }
    if (!await _settleAndClose() || !mounted) return;
    setState(() {
      _period = period;
      _customRange = range;
    });
    _sheetRevision.value++;
    _rememberFilter();
  }

  @override
  Future<void> _pickFilter(LogFilter filter) async {
    if (filter.sameAs(_filter) || !await _settleEditor() || !mounted) return;
    _pinnedAlone = false;
    _applyFilter(filter);
  }

  /// The one writer of [_selectedUuid] once a list is up.
  void _select(String? uuid) {
    if (uuid == _selectedUuid) return;
    setState(() {
      _selectedUuid = uuid;
      if (uuid != null) _keyboardAnchor = uuid;
      _editorKey = GlobalKey();
    });
  }

  /// A tap selects the row, or closes it when it already is — either way
  /// only once any edit in the open editor is settled (see [_settleEditor]).
  Future<void> _onTapRow(String uuid) async {
    _listFocus.requestFocus();
    // Decided before the wait: a save in flight closes the editor while this
    // waits on it, and read afterwards, a tap meant to close the row would
    // find it closed already and open it again.
    final closing = _selectedUuid == uuid;
    if (!await _settleEditor() || !mounted) return;
    _select(closing ? null : uuid);
  }

  /// The editor saved, deleted or discarded, and closes — the keyboard goes
  /// back to the list, still anchored on that row.
  void _onEditorDone() {
    _select(null);
    _listFocus.requestFocus();
  }

  /// Whether the open editor, if any, may close. True at once unless it
  /// holds an edit; then the operator saves it, discards it, or stays — an
  /// edit is never dropped without being asked. Everything that closes the
  /// editor other than its own buttons comes through here: another row,
  /// ↑/↓, Esc, another callsign, and — through [_settleAndClose] — leaving
  /// the destination and an ADIF drop.
  ///
  /// One answer for every caller that asks while it is still out: two
  /// triggers landing before the first dialog has focus — a held ↓ — would
  /// otherwise stack two dialogs about one edit.
  Future<bool> _settleEditor() => _settling ??= _settle().whenComplete(() {
    _settling = null;
  });

  Future<bool>? _settling;

  /// [_settleEditor], then the editor closed when it may: for the callers
  /// that go somewhere other than another row — leaving the destination
  /// (registered with [homeRail] as its leave guard) and an ADIF drop.
  /// Settled is not closed: left open, a saved edit would still read as
  /// unsaved and a discarded one would still be on screen.
  @override
  Future<bool> _settleAndClose() async {
    if (!await _settleEditor()) return false;
    if (mounted) _select(null);
    return true;
  }

  Future<bool> _settle() async {
    final editor = _editorKey.currentState;
    if (editor == null) return true;
    // Mid-write the edit is already on its way to the log: wait for it
    // rather than ask about it, and settle on how it went.
    if (editor.inFlight case final pending?) return pending;
    if (!editor.isDirty) return true;
    final t = context.t;
    // A staged delete is the change on the table, and Save is what commits
    // it: a dialog that called it unsaved changes would have the operator
    // delete the QSO while meaning to keep their work.
    final deleting = editor.isDeleting;
    final save = await showHaloDialog<bool>(
      context: context,
      builder: (dialogContext) => HaloDialog(
        title: Text(t.home.logs.unsavedTitle),
        content: Text(deleting ? t.home.logs.pendingDeleteBody : t.home.logs.unsavedBody),
        destructive: TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(t.home.logs.discard)),
        cancel: TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(t.common.cancel)),
        actions: [FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(deleting ? t.common.delete : t.common.save))],
      ),
    );
    if (save == null || !mounted) return false;
    if (!save) return true;
    if (!editor.mounted) {
      // The row has left the list while the dialog was up — deleted, or
      // moved out of it from another device — taking the editor and the
      // edit with it. Saving was asked for, so say that it didn't happen.
      widget.services.statusBar.showNotice(key: 'logsQsoEdit:gone', text: t.home.logs.editGone);
      return true;
    }
    return editor.commit();
  }

  /// ↑/↓ step the selection through the rows on screen, Enter moves into the
  /// editor (or reopens the last row), Esc closes it. The list's own focus
  /// only: while a field in the editor has focus, the editor takes the keys
  /// (see [_LogQsoEditPanel]).
  KeyEventResult _onListKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.arrowUp) {
      unawaited(_moveSelection(key == LogicalKeyboardKey.arrowDown ? 1 : -1));
      return KeyEventResult.handled;
    }
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      if (_selectedUuid != null) {
        _editorKey.currentState?.focusFirstField();
      } else if (_keyboardAnchor case final anchor? when _cachedRows?.qsoIndexOf(anchor) != null) {
        _select(anchor);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape && _selectedUuid != null) {
      unawaited(_settleEditor().then((settled) => settled && mounted ? _select(null) : null));
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _moveSelection(int delta) async {
    final rows = _cachedRows;
    if (rows == null || rows.qsos.isEmpty) return;
    final anchor = _selectedUuid ?? _keyboardAnchor;
    final current = anchor == null ? null : rows.qsoIndexOf(anchor);
    // From nothing, ↓ starts at the top and ↑ at the bottom.
    final next = current == null ? (delta > 0 ? 0 : rows.qsos.length - 1) : (current + delta).clamp(0, rows.qsos.length - 1);
    final uuid = rows.qsos[next].uuid;
    if (uuid == _selectedUuid || !await _settleEditor() || !mounted) return;
    // The wait can outlast the row: the dialog stays up for as long as the
    // operator leaves it, and a sync can take the row meanwhile. Selected
    // anyway, it would open no editor, and the keyboard would be anchored on
    // nothing; the settled editor closes instead, the keyboard still on its
    // row.
    if (_cachedRows?.qsoIndexOf(uuid) == null) {
      _select(null);
      return;
    }
    final opening = _selectedUuid == null;
    _select(uuid);
    _revealRow(uuid);
    // The editor opening shrinks the list from above as it grows, which can
    // push a row near the bottom out of view again.
    if (opening) unawaited(Future<void>.delayed(_logsEditorRevealDuration, () => _revealRow(uuid)));
  }

  /// Scrolls just far enough to show [uuid]'s row — from its item index, not
  /// a measurement: every row in the list is one extent (see
  /// [_LogsTableRows]).
  void _revealRow(String uuid) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final index = _cachedRows?.itemIndexOf(uuid);
      // The list's own context, not this view's: the pane can carry a
      // density of its own (an override, or the dock's for a pane in a
      // vertical split), and at the wrong row height the offset drifts by
      // thousands of pixels a few thousand rows down.
      final listContext = _listFocus.context;
      if (!mounted || index == null || listContext == null || !_listScroll.hasClients) return;
      final extent = LayoutDensity.metricsOf(listContext).qsoRowHeight;
      final position = _listScroll.position;
      final top = index * extent;
      // Under the group headers pinned over the top, not behind them.
      final pinned = (_cachedRows?.grouping.levels ?? 0) * extent;
      if (top < position.pixels + pinned) {
        _listScroll.jumpTo(math.max(0, top - pinned));
      } else if (top + extent > position.pixels + position.viewportDimension) {
        _listScroll.jumpTo(math.min(position.maxScrollExtent, top + extent - position.viewportDimension));
      }
    });
  }

  void _searchTyped(String text) {
    _searchTimer?.cancel();
    _searchTimer = Timer(_searchDebounce, () => _searchNow(text));
  }

  /// Applies [text] without waiting — Enter, the clear button, or the pause
  /// [_searchTyped] waits for.
  void _searchNow(String text) {
    _searchTimer?.cancel();
    _searchTimer = null;
    if (mounted && text != _searchQuery) setState(() => _searchQuery = text);
  }

  void _sortBy(String column) {
    setState(() => _sort = _sort.tapped(column));
    unawaited(widget.services.settings.setLayoutData(LayoutKeys.logsQsoSort, _sort.toMap()));
    if (_selectedUuid case final uuid?) _revealRow(uuid);
  }

  /// Folds [header]'s group shut or opens it — and with Ctrl, ⌘ or Alt held,
  /// its siblings and every group inside any of them the same way. A header
  /// tapped where it was pinned is brought back to its pinned place, rather
  /// than the list staying put somewhere past the group it just folded.
  void _toggleGroup(_LogsGroupHeader header, int itemIndex) {
    final keyboard = HardwareKeyboard.instance;
    final all = keyboard.isControlPressed || keyboard.isMetaPressed || keyboard.isAltPressed;
    final grouping = header.grouping;
    final collapse = !header.collapsed;
    final targets = all ? (_cachedRows?.siblingsAndDescendants(header) ?? [header.path]) : [header.path];
    final next = {...?_toggled[grouping]};
    for (final path in targets) {
      if (collapse != grouping.startsCollapsed) {
        next.add(path);
      } else {
        next.remove(path);
      }
    }
    final listContext = _listFocus.context;
    final extent = listContext == null ? null : LayoutDensity.metricsOf(listContext).qsoRowHeight;
    final wasPinned = extent != null && _listScroll.positions.length == 1 && _listScroll.offset > (itemIndex - header.level) * extent;
    setState(() => _toggled = {..._toggled, grouping: next});
    _rememberFilter();
    if (!wasPinned) return;
    // Siblings above it can fold too, so the header's place is looked up
    // again in the rows this toggle rebuilt.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final index = _cachedRows?.headerIndexOf(header.path);
      if (!mounted || index == null || _listScroll.positions.length != 1) return;
      _listScroll.jumpTo(math.min((index - header.level) * extent, _listScroll.position.maxScrollExtent));
    });
  }

  void _pickGrouping(LogsGrouping grouping) {
    if (grouping == _grouping || !mounted) return;
    setState(() => _grouping = grouping);
    _sheetRevision.value++;
    _rememberFilter();
  }

  /// Live-updates the dragged column as the pointer moves; the drag itself
  /// never touches settings storage — see [_persistColumnWidths], called
  /// once the pointer lifts, so a fast drag doesn't write prefs every frame.
  void _resizeColumn(String column, double delta) => setState(() => _columnWidths = _columnWidths.resized(column, delta));

  void _persistColumnWidths() => unawaited(widget.services.settings.setLayoutData(LayoutKeys.logsQsoColumnWidths, _columnWidths.toMap()));

  /// Double-click "auto-fit" — sets and persists in one step, unlike a drag's
  /// [_resizeColumn]/[_persistColumnWidths] pair, since there's no in-between
  /// pointer-moves stretch to skip writing prefs during.
  void _autoFitColumn(String column, double width) {
    setState(() => _columnWidths = _columnWidths.withWidth(column, width));
    _persistColumnWidths();
  }

  /// Refuses to remove the last visible column (see [_visibleColumns]'s own
  /// doc) rather than silently no-opping past the check-menu's own state —
  /// the operator would see the checkbox uncheck and then, seeing nothing
  /// change, assume the app is broken rather than that the action was
  /// disallowed.
  void _toggleColumnVisible(String column) {
    if (_visibleColumns.contains(column) && _visibleColumns.length <= 1) return;
    setState(() {
      final next = Set<String>.from(_visibleColumns);
      if (!next.remove(column)) next.add(column);
      _visibleColumns = next;
    });
    unawaited(
      widget.services.settings.setLayoutData(LayoutKeys.logsQsoVisibleColumns, {
        for (final column in _allLogsColumns) column: _visibleColumns.contains(column),
      }),
    );
  }

  /// The right-click "manage columns" menu — a single tap toggles one column
  /// and closes, a one-shot `showMenu` rather than staying open for several
  /// toggles in a row.
  Future<void> _openColumnMenu(Offset globalPosition) async {
    final selection = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(globalPosition.dx, globalPosition.dy, globalPosition.dx, globalPosition.dy),
      items: [
        for (final column in _allLogsColumns)
          CheckedPopupMenuItem(value: column, checked: _visibleColumns.contains(column), child: Text(_logsColumnLabel(context, column))),
      ],
    );
    // The menu can still resolve after this state is disposed (navigate away
    // mid-pick), and `_toggleColumnVisible`'s `setState` would throw.
    if (selection != null && mounted) _toggleColumnVisible(selection);
  }

  /// Moves [dragged] to just before [before], or right after the last
  /// visible column when that is null — where a header drag let go (see
  /// [_QsoListHeaderRow]). Hidden columns keep their places around it.
  void _moveColumn(String dragged, String? before) {
    final order = List<String>.from(_columnOrder);
    if (dragged == before || !order.remove(dragged)) return;
    final at = before == null ? order.lastIndexWhere(_visibleColumns.contains) + 1 : order.indexOf(before);
    if (at < 0) return;
    order.insert(at, dragged);
    if (listEquals(order, _columnOrder)) return;
    setState(() => _columnOrder = order);
    unawaited(widget.services.settings.setLayoutData(LayoutKeys.logsQsoColumnOrder, {'order': _columnOrder}));
  }

  List<Qso> _applySearch(List<Qso> qsos) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return qsos;
    return [
      for (final qso in qsos)
        if (qso.theirCall.toLowerCase().contains(query) || (qso.theirName ?? '').toLowerCase().contains(query)) qso,
    ];
  }

  /// The view's sheet — the station callsigns and the time period — dropping
  /// from the title the way the Chasing view's and an operation's do, with an
  /// OK button grown out of the title's dots.
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
        listenable: _sheetRevision,
        builder: (context, _) => _LogsSheet(
          callsigns: _callsigns,
          filter: _filter,
          grouping: _grouping,
          period: _period,
          customRange: _customRange,
          onGrouping: _pickGrouping,
          onFilter: (filter) => unawaited(_pickFilter(filter)),
          onPeriod: (period) => unawaited(_pickPeriod(period)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stream = _qsosStream;
    if (stream == null) return _buildScaffold(context, null);
    // One StreamBuilder for the whole view, not one per pane:
    // `watchForOurCalls` is a single-subscription Drift stream, and a second
    // `StreamBuilder` listening to the same instance throws "Stream has
    // already been listened to" the moment both are on screen together. The
    // header (count/date span) reads from the same snapshot as the dock, so
    // it has to sit inside this same builder rather than the plain `build`
    // above.
    return StreamBuilder<List<Qso>>(stream: stream, builder: (context, snapshot) => _buildScaffold(context, snapshot.data));
  }

  Widget _buildScaffold(BuildContext context, List<Qso>? streamed) {
    final qsos = streamed == null ? null : _inPeriod(streamed);
    final rows = qsos == null ? null : _tableRowsFor(qsos);
    final filtered = rows?.all;
    Qso? selected;
    if (qsos != null) {
      for (final qso in qsos) {
        if (qso.uuid == _selectedUuid) {
          selected = qso;
          break;
        }
      }
    }
    // Both sides of the two-pane boundary are docks; what changes is WHICH
    // arrangement, since a tree that names no widths cannot be drawn at both
    // (docs/design/layouts.md). Assigned before anything below builds one:
    // every accessor the mixin offers reads this field.
    final isTwoPane = ShirtSize.of(context).isTwoPane;
    dockLayoutClass = isTwoPane ? DockLayoutClass.wide : DockLayoutClass.narrow;
    final qsoListPane = KeyedSubtree(
      key: _qsoListPaneKey,
      child: _QsoListPanel(
        services: widget.services,
        callLabel: _filter.allCalls ? context.t.home.logs.allCallsigns : _filter.stationCall,
        rows: rows,
        selectedUuid: _selectedUuid,
        selected: selected,
        editorKey: _editorKey,
        onTapRow: _onTapRow,
        onEditorDone: _onEditorDone,
        searching: _searchQuery.trim().isNotEmpty,
        loading: !_callsignsLoaded,
        columnWidths: _columnWidths,
        onResizeColumn: _resizeColumn,
        onResizeColumnEnd: _persistColumnWidths,
        onAutoFitColumn: _autoFitColumn,
        visibleColumns: _visibleColumns,
        onShowColumnMenu: _openColumnMenu,
        columnOrder: _columnOrder,
        onReorderColumn: _moveColumn,
        sort: _sort,
        onSort: _sortBy,
        onToggleGroup: _toggleGroup,
        freqMhzDigits: filtered == null ? 1 : _cachedMaxFreqMhzDigits(filtered),
        scrollController: _listScroll,
        listFocusNode: _listFocus,
        onListKey: _onListKey,
      ),
    );
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: windowHeaderGestureArea(),
        leadingWidth: HomeRailLogo.headerReserveOf(context, railWidth: HomeNavigationRail.widthFor(context, expanded: homeRail.expanded)),
        leading: const SizedBox.shrink(),
        titleSpacing: Space.xl,
        // Rebuilt with the sheet's slide on its own — the dots and the gap
        // follow it frame by frame.
        title: AnimatedBuilder(
          animation: _sheetAnimation ?? kAlwaysDismissedAnimation,
          builder: (context, _) => _buildTitle(context, filtered, includeSearch: isTwoPane),
        ),
        actions: [
          ?viewOptionsButton(context, editing: layoutEditing),
          ...layoutHeaderControls(context),
          windowsCaptionSpacer(context),
        ],
        // Row two, narrow only: the search field the title row dropped.
        bottom: isTwoPane ? null : _narrowSearchRow(context),
      ),
      // AdifDropTarget over the whole body: a drop anywhere on the Logs view
      // imports, not just over the QSO table.
      body: AdifDropTarget(
        onFile: _handleAdifDrop,
        child: withViewOverrides(
          buildDock(
            children: {
              LogsView.qsoTablePanelId: qsoListPane,
              LogsView.infoPanelId: _LogsInfoPanel(services: widget.services, totalCount: filtered?.length ?? 0, selected: selected),
              LogsView.mapPanelId: _LogsMapPanel(services: widget.services, selected: selected),
            },
            tabActions: {LogsView.mapPanelId: (context) => _buildMapSettingsButton(context)},
            extraChildren: sharedDashboardPanes,
          ),
        ),
      ),
    );
  }

  /// The Map panel's basemap picker, same target-scoped dialog the
  /// Operation view's own Map tab opens (see OperationView's own copy of
  /// this button) — Map is native and reached through a target rather than
  /// through `formFields`, so [DockHost.buildPanelSettingsButton] wouldn't
  /// find it either.
  Widget _buildMapSettingsButton(BuildContext context) => buildTargetSettingsButton(context, target: 'map', title: context.t.operation.menu.mapSettingsTitle);

  /// The search field's own row, shown only below the two-pane boundary —
  /// the title row (see [_buildTitle]) drops it there rather than shrinking
  /// it away, since a search box too narrow to read from isn't worth the
  /// horizontal space it would still take.
  PreferredSizeWidget _narrowSearchRow(BuildContext context) {
    const height = 48.0;
    return PreferredSize(
      preferredSize: const Size.fromHeight(height),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.lg, Space.sm),
        child: SizedBox(height: 36, child: _searchField(context)),
      ),
    );
  }

  /// The title that opens the sheet, then the search field, all in the
  /// view's own AppBar rather than the QSO table pane's header — the pane
  /// stays genuinely headerless (see [defaultHeaderlessModules]) so it reads
  /// as one continuous list. Two lines, like an operation's: what is shown,
  /// then how many QSOs and over what span. "Logs" carries the AppBar's usual
  /// Roboto Slab, but at regular weight rather than the app-wide Black — the
  /// callsign next to it is what's meant to read as the emphasized part, in
  /// mono to match every other callsign display in the app.
  Widget _buildTitle(BuildContext context, List<Qso>? filtered, {required bool includeSearch}) {
    final theme = Theme.of(context);
    final t = context.t;
    final baseStyle = (theme.appBarTheme.titleTextStyle ?? const TextStyle()).copyWith(fontWeight: FontWeight.w400);
    final foreground = theme.appBarTheme.foregroundColor ?? theme.colorScheme.onPrimary;
    final call = _filter.stationCall;
    final lead = call != null
        ? '${t.home.logs.titleFor} '
        : _filter.allCalls
        ? t.home.logs.titleAll
        : t.home.logs.title;
    // Blank while the callsign list is still loading — the list pane itself
    // carries the loading spinner (see [_QsoListPanel]), so this stays quiet
    // rather than doubling it up in the header.
    final periodTitle = _period.titleLabel(context, nowUtc());
    final inPeriod = periodTitle == null ? null : t.home.logs.periodTitle.inSpan(span: periodTitle);
    final subtitle = (_callsignsLoaded && !_filter.isEmpty && filtered != null) ? _countAndSpan(context, filtered) : '';
    final titleControl = InkWell(
      key: _headerTitleKey,
      onTap: _sheetProgress > 0 ? null : () => _openSheet(context),
      mouseCursor: SystemMouseCursors.click,
      borderRadius: BorderRadius.circular(8),
      // The operation header's own bump: M3's default overlays barely
      // show on the teal bar.
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed) || states.contains(WidgetState.focused)) return foreground.withValues(alpha: 0.20);
        if (states.contains(WidgetState.hovered)) return foreground.withValues(alpha: 0.16);
        return null;
      }),
      // The visible title alone names the button: Flutter web lays the
      // name out as DOM text inside this box with its overflow showing,
      // and a name long enough to wrap spills below the AppBar, where
      // its lines take the clicks meant for the table header underneath.
      child: Semantics(
        label: [
          [if (call != null) '$lead$call' else lead, ?inPeriod].join(' '),
          if (subtitle.isNotEmpty) subtitle,
        ].join(', '),
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.only(left: Space.xs, right: Space.lg, top: Space.xxs, bottom: Space.xxs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: sheetLeadingGapWidth(_sheetProgress, _sheetOkButtonWidth),
                height: 32,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: SheetHeaderDots(progress: _sheetProgress),
                ),
              ),
              const SizedBox(width: Space.xs),
              // The operation header's two lines. The first ellipsizes rather
              // than going through shrinkToFitText, which paints plain text
              // and would drop the callsign's own style.
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: lead),
                          if (call != null)
                            TextSpan(
                              text: call,
                              style: const TextStyle(fontFamily: 'RobotoMono', fontWeight: FontWeight.w800),
                            ),
                          if (inPeriod != null) TextSpan(text: ' $inPeriod'),
                        ],
                      ),
                      style: baseStyle.copyWith(color: foreground),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle.isNotEmpty)
                      shrinkToFitText(Text(subtitle, style: theme.textTheme.labelMedium?.copyWith(color: foreground.withValues(alpha: 0.85))), condensed: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!includeSearch) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [Flexible(child: titleControl)],
      );
    }
    // The search field at the middle of the title slot, between two equal
    // sides: the title takes the left one and ellipsizes there rather than
    // pushing the field off center.
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        children: [
          Expanded(
            child: Align(alignment: AlignmentDirectional.centerStart, child: titleControl),
          ),
          const SizedBox(width: Space.xxl),
          SizedBox(width: math.min(_searchFieldWidth, constraints.maxWidth / 3), height: 36, child: _searchField(context)),
          const SizedBox(width: Space.xxl),
          const Spacer(),
        ],
      ),
    );
  }

  /// The search field itself, shared between the title row (two-pane) and
  /// [_narrowSearchRow]'s own row (narrow) — one controller, one set of
  /// formatting/decoration rules, wherever it's drawn.
  ///
  /// A Material search bar in the header's height: a filled pill with no
  /// outline, the magnifier leading and a clear button trailing once there
  /// is something to clear — the same shape as Home's Quick Lookup.
  Widget _searchField(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.t;
    // Rebuilt with the text, not with the search: the clear button follows
    // what is typed, which runs ahead of [_searchQuery] by the debounce.
    return ListenableBuilder(
      listenable: _searchController,
      builder: (context, _) => TextField(
        controller: _searchController,
        onChanged: _searchTyped,
        onSubmitted: _searchNow,
        enabled: !_filter.isEmpty,
        inputFormatters: const [UpperCaseTextFormatter()],
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: theme.colorScheme.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: Space.lg),
          prefixIcon: const Icon(MdiIcons.magnify),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  icon: Icon(MdiIcons.close, semanticLabel: t.common.clear),
                  onPressed: () {
                    _searchController.clear();
                    _searchNow('');
                  },
                ),
          hintText: t.home.logs.searchHint,
          // Dimmed by hand: nothing themed does it for a hand-built
          // decoration, and at full strength the hint reads as a search
          // already typed.
          hintStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.38)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  /// The count and the exact days of the period the title names in months
  /// or years: "1,234 QSOs · 2026-08-01 – 2026-10-13". Over all time, which
  /// has no days of its own, the span the QSOs themselves cover.
  String _countAndSpan(BuildContext context, List<Qso> list) {
    final info = context.t.loggingControls.info;
    final count = list.length == 1 ? info.qsoCountOne : info.qsoCountOther(count: formatNumber(list.length));
    if (_period.dateSpan(nowUtc(), range: _customRange) case final span?) return '$count · $span';
    final range = _cachedMillisRange(list);
    return range == null ? count : '$count · ${_dateRangeLabel(range.$1, range.$2)}';
  }
}

/// The earliest and latest of a set of millis-since-epoch values, `null`s
/// skipped. `null` when nothing in [values] has one to offer.
(int, int)? _millisRange(Iterable<int?> values) {
  int? minMillis;
  int? maxMillis;
  for (final millis in values) {
    if (millis == null) continue;
    if (minMillis == null || millis < minMillis) minMillis = millis;
    if (maxMillis == null || millis > maxMillis) maxMillis = millis;
  }
  if (minMillis == null || maxMillis == null) return null;
  return (minMillis, maxMillis);
}

String _dateRangeLabel(int minMillis, int maxMillis) {
  final start = _dateFormat.format(DateTime.fromMillisecondsSinceEpoch(minMillis, isUtc: true));
  final end = _dateFormat.format(DateTime.fromMillisecondsSinceEpoch(maxMillis, isUtc: true));
  return start == end ? start : '$start – $end';
}
