// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
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
import 'dock_host.dart';
import 'home_navigation_rail.dart';
import 'operation/adif_import_flow.dart';
import 'operation/call_info_panel.dart';
import 'operation/extension_panel.dart';
import 'operation/map_panel.dart';
import 'operation_view.dart';

/// The Logs destination's active filter (docs card HALO-273) — currently
/// just a station callsign, with room to grow into other filter dimensions.
/// [_LogsViewState] is the only writer; the QSO table only reads it, so it
/// doesn't need to know how the callsign was picked.
class LogFilter {
  final String? stationCall;

  const LogFilter({this.stationCall});

  bool get isEmpty => stationCall == null;
}

/// Every column the QSO table can show, in header order — the id a
/// [_LogsColumnWidths] field or a [_LogsViewState._visibleColumns] entry is
/// keyed by, and what the right-click column menu offers. `name` has no
/// width of its own (see [_LogsColumnWidths]) but is still a real column for
/// visibility purposes.
const _allLogsColumns = ['date', 'time', 'freq', 'mode', 'call', 'name'];

/// User-resizable widths for the QSO table's columns (see
/// [_LogQsoSummaryRow]) — all six carry a real width, including Name's,
/// because any of them can end up as the table's trailing column (see
/// [_LogsTableWidth]), and only the trailing one gets to skip having a fixed
/// width of its own. Persisted under [LayoutKeys.logsQsoColumnWidths], one
/// JSON map like every other layout dimension
/// (`SettingsService.layoutData`).
class _LogsColumnWidths {
  static const _min = 32.0;

  final double date;
  final double time;
  final double freq;
  final double mode;
  final double call;
  final double name;

  const _LogsColumnWidths({
    this.date = 92,
    this.time = 56,
    this.freq = 78,
    this.mode = 42,
    this.call = 100,
    this.name = 150,
  });

  double widthOf(String id) => switch (id) {
        'date' => date,
        'time' => time,
        'freq' => freq,
        'mode' => mode,
        'call' => call,
        'name' => name,
        _ => 0,
      };

  factory _LogsColumnWidths.fromMap(Map<String, dynamic>? map) {
    double read(String key, double fallback) => (map?[key] as num?)?.toDouble() ?? fallback;
    const defaults = _LogsColumnWidths();
    return _LogsColumnWidths(
      date: read('date', defaults.date),
      time: read('time', defaults.time),
      freq: read('freq', defaults.freq),
      mode: read('mode', defaults.mode),
      call: read('call', defaults.call),
      name: read('name', defaults.name),
    );
  }

  Map<String, dynamic> toMap() => {'date': date, 'time': time, 'freq': freq, 'mode': mode, 'call': call, 'name': name};

  _LogsColumnWidths _copyWith(String column, double value) => switch (column) {
        'date' => _LogsColumnWidths(date: value, time: time, freq: freq, mode: mode, call: call, name: name),
        'time' => _LogsColumnWidths(date: date, time: value, freq: freq, mode: mode, call: call, name: name),
        'freq' => _LogsColumnWidths(date: date, time: time, freq: value, mode: mode, call: call, name: name),
        'mode' => _LogsColumnWidths(date: date, time: time, freq: freq, mode: value, call: call, name: name),
        'call' => _LogsColumnWidths(date: date, time: time, freq: freq, mode: mode, call: value, name: name),
        'name' => _LogsColumnWidths(date: date, time: time, freq: freq, mode: mode, call: call, name: value),
        _ => this,
      };

  /// Widens or narrows [column] by [delta], clamped so a fast drag can't
  /// shrink it to nothing (or past it, going negative).
  _LogsColumnWidths resized(String column, double delta) => _copyWith(column, math.max(_min, widthOf(column) + delta));

  /// Sets [column] to exactly [width] (clamped) — the double-click "auto-fit"
  /// path, as opposed to [resized]'s relative drag delta.
  _LogsColumnWidths withWidth(String column, double width) => _copyWith(column, math.max(_min, width));
}

/// The trailing column's own floor once the table is wide enough to
/// scroll — below this, "Frederick N Pessaro, Jr" reads as noise, not a
/// name (and a Call or a Date squeezed this far isn't much better).
const _logsFlexColumnMinWidth = 120.0;

/// The QSO table's total (scrollable) content width, which column is
/// currently trailing, and that column's own share of the width — whichever
/// column [columnOrder] (filtered to [visibleColumns]) puts LAST is the one
/// that stretches to fill the pane, or holds at [_logsFlexColumnMinWidth]
/// once the table needs to scroll; every other visible column uses its own
/// [_LogsColumnWidths] entry. [_QsoListHeaderRow] and [_LogQsoSummaryRow]
/// both size to [content], inside the SAME [SingleChildScrollView] in
/// [_QsoListPanel.build], so a column resize or reorder that changes which
/// column trails moves the header and every row in lockstep rather than
/// letting them drift out of alignment.
///
/// Below the table's natural width, [content] is just [availableWidth] and
/// [flexWidth] stretches to fill it — the same "fill the pane" behavior the
/// table had before horizontal scrolling existed. Above it, [content] is the
/// natural width and [flexWidth] holds at [_logsFlexColumnMinWidth]. Either
/// way, `Row`'s children sum to EXACTLY [content] minus the outer padding:
/// no leftover slack for `Row` to distribute (there's no `Expanded` doing
/// that anymore) and no overflow.
class _LogsTableWidth {
  final double content;
  final double flexWidth;
  final String? flexId;

  const _LogsTableWidth({required this.content, required this.flexWidth, required this.flexId});

  factory _LogsTableWidth.of({
    required double availableWidth,
    required _LogsColumnWidths widths,
    required Set<String> visibleColumns,
    required List<String> columnOrder,
  }) {
    final visible = [
      for (final id in columnOrder)
        if (visibleColumns.contains(id)) id,
    ];
    if (visible.isEmpty) return const _LogsTableWidth(content: 0, flexWidth: 0, flexId: null);
    final flexId = visible.last;
    // The outer Padding, plus every non-trailing visible column and its OWN
    // trailing gap — that gap is the header's resize handle, present after
    // every non-trailing column regardless of what follows it, so this sum
    // has to count it the same unconditional way or the header and the rows
    // below it stop lining up the moment a column is hidden or reordered.
    var fixedWidth = Space.lg * 2;
    for (final id in visible) {
      if (id != flexId) fixedWidth += widths.widthOf(id) + Space.lg;
    }
    final content = math.max(availableWidth, fixedWidth + _logsFlexColumnMinWidth);
    return _LogsTableWidth(content: content, flexWidth: content - fixedWidth, flexId: flexId);
  }
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

class _LogsViewState extends State<LogsView> with DockHost<LogsView> {
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
  Set<String> get nativeModuleIds => const {
    LogsView.qsoTablePanelId,
    LogsView.infoPanelId,
    LogsView.mapPanelId,
  };

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
  DockNode buildDefaultDockSpec(DockLayoutClass layoutClass, {bool migrate = true}) =>
      switch (layoutClass) {
        DockLayoutClass.narrow => DockGroup([LogsView.qsoTablePanelId]),
        DockLayoutClass.wide => DockSplit(Axis.horizontal, [
          DockGroup([LogsView.qsoTablePanelId]),
          DockSplit(Axis.vertical, [
            DockGroup([LogsView.infoPanelId]),
            DockGroup([LogsView.mapPanelId]),
          ], [1, 1]),
        ], [2, 1]),
      };

  void _registerNativePanels() {
    final t = context.t.home.logs.panels;
    final service = widget.services.panels;
    service.registerNative(PanelDefinition(
      id: LogsView.qsoTablePanelId,
      title: t.qsos,
      description: t.qsosDescription,
      icon: 'notebook',
      source: PanelSource.native,
      views: const {PanelViews.logs},
    ));
    service.registerNative(PanelDefinition(
      id: LogsView.infoPanelId,
      title: t.info,
      description: t.infoDescription,
      icon: 'informationOutline',
      source: PanelSource.native,
      views: const {PanelViews.logs},
    ));
    service.registerNative(PanelDefinition(
      id: LogsView.mapPanelId,
      title: t.map,
      description: t.mapDescription,
      icon: 'map',
      source: PanelSource.native,
      views: const {PanelViews.logs},
    ));
    registerSharedDashboardPanels();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _registerNativePanels();
  }

  LogFilter _filter = const LogFilter();
  late _LogsColumnWidths _columnWidths;

  /// Which of [_allLogsColumns] the QSO table currently shows — toggled from
  /// the right-click menu (see [_openColumnMenu]). Never empty: [_toggleColumnVisible]
  /// refuses to remove the last one, so the table can't end up with no
  /// columns and no way back short of clearing app data.
  late Set<String> _visibleColumns;

  /// Left-to-right order of all [_allLogsColumns], Name included — whichever
  /// ends up trailing (after hiding) is the one [_LogsTableWidth] stretches
  /// to fill the pane. Dragged from [_QsoListHeaderRow]; see [_reorderColumn].
  late List<String> _columnOrder;

  String? _selectedUuid;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  /// Cached from the callsigns stream (see [_subscribeCallsigns]), call ->
  /// its QSO count — the picker menu needs a synchronous map to build its
  /// items from (the count becomes a pill next to each entry), and the keys
  /// are also what a fresh view auto-selects the first of.
  Map<String, int> _callsigns = const {};

  /// `false` until the callsigns stream delivers its first snapshot — the
  /// view shows a spinner for that stretch rather than the "select a
  /// callsign" prompt, which would otherwise flash before there is anything
  /// to select.
  bool _callsignsLoaded = false;
  StreamSubscription<Map<String, int>>? _callsignsSubscription;

  /// Empty until a callsign is picked — the query needs one, so there is
  /// nothing to watch before then.
  Stream<List<Qso>>? _qsosStream;

  final _pickerKey = GlobalKey();

  // The search filter and date-range scan are both O(n) over the whole
  // per-callsign log, which the QSO scale this view targets (see
  // `_LogQsoSummaryRow`'s own doc comment) makes worth not repeating: this
  // widget's `build` reruns on state changes that don't touch the QSO list
  // or the search text at all, e.g. selecting a row. Keyed on the identity
  // of the source list (unchanged across an unrelated rebuild, since it's
  // the same snapshot from the stream) rather than deep-equality.
  List<Qso>? _cachedSearchSource;
  String? _cachedSearchQuery;
  List<Qso>? _cachedSearchResult;
  List<Qso>? _cachedRangeSource;
  (int, int)? _cachedRange;
  List<Qso>? _cachedFreqDigitsSource;
  int? _cachedFreqDigits;

  List<Qso> _cachedApplySearch(List<Qso> qsos) {
    if (identical(qsos, _cachedSearchSource) && _searchQuery == _cachedSearchQuery) {
      return _cachedSearchResult!;
    }
    final result = _applySearch(qsos);
    _cachedSearchSource = qsos;
    _cachedSearchQuery = _searchQuery;
    _cachedSearchResult = result;
    return result;
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

  static const _countColumnWidth = 130.0;
  static const _searchFieldWidth = 220.0;

  @override
  void initState() {
    super.initState();
    // Same self-tracking `SettingsView` does — this pane is unmounted while
    // hidden (see `HomeView`'s `_logsSlide` `isDismissed` check) and remounted
    // fresh each time the destination switches back to it, so `initState` is
    // exactly "a visit started".
    widget.services.track('screen_viewed', {'screen': 'logs'});
    _columnWidths = _LogsColumnWidths.fromMap(widget.services.settings.layoutData(LayoutKeys.logsQsoColumnWidths));
    final storedVisibility = widget.services.settings.layoutData(LayoutKeys.logsQsoVisibleColumns);
    _visibleColumns = {
      for (final column in _allLogsColumns)
        if (storedVisibility?[column] != false) column,
    };
    // Self-healing rather than all-or-nothing: an id this build no longer
    // recognizes (a future rename) is dropped instead of discarding the
    // whole order, and one this build knows but the stored order doesn't
    // (a future addition) is appended rather than going missing.
    final storedOrder =
        (widget.services.settings.layoutData(LayoutKeys.logsQsoColumnOrder)?['order'] as List?)?.cast<String>() ??
            const [];
    final knownOrder = storedOrder.where(_allLogsColumns.contains).toList();
    _columnOrder = [...knownOrder, ..._allLogsColumns.where((column) => !knownOrder.contains(column))];
    _subscribeCallsigns();
  }

  @override
  void dispose() {
    unawaited(_callsignsSubscription?.cancel());
    _searchController.dispose();
    super.dispose();
  }

  /// Also called by [_runAdifDrop] to resubscribe after pausing this for the
  /// write phase — see that function's own doc comment on why. Requests a
  /// fresh stream each time rather than reusing one cached instance: Drift's
  /// `.watch()` streams are single-subscription, so a stream already
  /// cancelled once cannot be listened to again.
  void _subscribeCallsigns() {
    _callsignsSubscription = widget.services.qsos.watchDistinctOurCalls().listen((calls) {
      setState(() {
        _callsignsLoaded = true;
        _callsigns = calls;
        // A fresh view, or one whose selected callsign just dropped out of
        // the list (its last QSO deleted), opens on something rather than
        // getting stuck on a callsign with nothing left behind it.
        if (!calls.containsKey(_filter.stationCall) && calls.isNotEmpty) {
          _selectCall((calls.keys.toList()..sort()).first);
        }
      });
    });
  }

  void _selectCall(String call) {
    if (_filter.stationCall == call) return;
    setState(() {
      _filter = LogFilter(stationCall: call);
      _qsosStream = widget.services.qsos.watchForOurCalls([call]);
      // The old selection and search belonged to the previous callsign's
      // list.
      _selectedUuid = null;
      _searchController.clear();
      _searchQuery = '';
    });
  }

  void _toggleSelect(String uuid) => setState(() => _selectedUuid = _selectedUuid == uuid ? null : uuid);

  /// Live-updates the dragged column as the pointer moves; the drag itself
  /// never touches settings storage — see [_persistColumnWidths], called
  /// once the pointer lifts, so a fast drag doesn't write prefs every frame.
  void _resizeColumn(String column, double delta) =>
      setState(() => _columnWidths = _columnWidths.resized(column, delta));

  void _persistColumnWidths() =>
      unawaited(widget.services.settings.setLayoutData(LayoutKeys.logsQsoColumnWidths, _columnWidths.toMap()));

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
    unawaited(widget.services.settings.setLayoutData(
      LayoutKeys.logsQsoVisibleColumns,
      {for (final column in _allLogsColumns) column: _visibleColumns.contains(column)},
    ));
  }

  /// The right-click "manage columns" menu — a single tap toggles one column
  /// and closes, the same one-shot `showMenu` [_openCallsignPicker] uses for
  /// its own menu, rather than staying open for several toggles in a row.
  Future<void> _openColumnMenu(Offset globalPosition) async {
    final t = context.t.home.logs.columns;
    String labelFor(String column) => switch (column) {
          'date' => t.date,
          'time' => t.time,
          'freq' => t.freq,
          'mode' => t.mode,
          'call' => t.call,
          'name' => t.name,
          _ => column,
        };
    final selection = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(globalPosition.dx, globalPosition.dy, globalPosition.dx, globalPosition.dy),
      items: [
        for (final column in _allLogsColumns)
          CheckedPopupMenuItem(
            value: column,
            checked: _visibleColumns.contains(column),
            child: Text(labelFor(column)),
          ),
      ],
    );
    // Same guard [_openCallsignPicker] uses for its own awaited `showMenu` —
    // the menu can still resolve after this state is disposed (navigate away
    // mid-pick), and `_toggleColumnVisible`'s `setState` would throw.
    if (selection != null && mounted) _toggleColumnVisible(selection);
  }

  /// Drops [dragged] where [droppedOn] currently sits, shifting everything
  /// between the two over by one — the usual "reorder by dropping onto a
  /// neighbor" a spreadsheet does, not a plain two-column swap.
  void _reorderColumn(String dragged, String droppedOn) {
    if (dragged == droppedOn) return;
    setState(() {
      final order = List<String>.from(_columnOrder);
      // Index AFTER removal, not before: removing `dragged` shifts every
      // later index down by one, and inserting at the pre-removal index
      // would land one slot too far right whenever `dragged` started BEFORE
      // `droppedOn` — the same drop reading as "insert after" going one way
      // and "insert before" going the other.
      if (!order.remove(dragged)) return;
      final targetIndex = order.indexOf(droppedOn);
      if (targetIndex == -1) return;
      order.insert(targetIndex, dragged);
      _columnOrder = order;
    });
    unawaited(widget.services.settings.setLayoutData(LayoutKeys.logsQsoColumnOrder, {'order': _columnOrder}));
  }

  List<Qso> _applySearch(List<Qso> qsos) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return qsos;
    return [
      for (final qso in qsos)
        if (qso.theirCall.toLowerCase().contains(query) || (qso.theirName ?? '').toLowerCase().contains(query))
          qso,
    ];
  }

  Future<void> _openCallsignPicker() async {
    final box = _pickerKey.currentContext?.findRenderObject() as RenderBox?;
    final overlayBox = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlayBox == null) return;
    final topLeft = box.localToGlobal(Offset(0, box.size.height), ancestor: overlayBox);
    final position = RelativeRect.fromLTRB(topLeft.dx, topLeft.dy, overlayBox.size.width - topLeft.dx, 0);
    final theme = Theme.of(context);
    final sortedCalls = _callsigns.keys.toList()..sort();
    final picked = await showMenu<String>(
      context: context,
      position: position,
      items: [
        for (final call in sortedCalls)
          PopupMenuItem(
            value: call,
            child: Row(
              children: [
                Expanded(
                  child: Text(call, style: const TextStyle(fontFamily: 'RobotoMono', fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: Space.md),
                // Same count-pill treatment the operation list uses for its
                // own QSO count.
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.xxs),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(formatNumber(_callsigns[call] ?? 0), style: theme.textTheme.labelLarge),
                ),
              ],
            ),
          ),
      ],
    );
    if (picked != null && mounted) _selectCall(picked);
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
    return StreamBuilder<List<Qso>>(
      stream: stream,
      builder: (context, snapshot) => _buildScaffold(context, snapshot.data),
    );
  }

  Widget _buildScaffold(BuildContext context, List<Qso>? qsos) {
    final filtered = qsos == null ? null : _cachedApplySearch(qsos);
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
        call: _filter.stationCall,
        qsos: filtered,
        selectedUuid: _selectedUuid,
        selected: selected,
        onSelect: _toggleSelect,
        searching: _searchQuery.trim().isNotEmpty,
        loading: !_callsignsLoaded,
        columnWidths: _columnWidths,
        onResizeColumn: _resizeColumn,
        onResizeColumnEnd: _persistColumnWidths,
        onAutoFitColumn: _autoFitColumn,
        visibleColumns: _visibleColumns,
        onShowColumnMenu: _openColumnMenu,
        columnOrder: _columnOrder,
        onReorderColumn: _reorderColumn,
        freqMhzDigits: filtered == null ? 1 : _cachedMaxFreqMhzDigits(filtered),
      ),
    );
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: windowHeaderGestureArea(),
        leadingWidth: HomeRailLogo.headerReserveOf(
          context,
          railWidth: HomeNavigationRail.widthFor(context, expanded: homeRail.expanded),
        ),
        leading: const SizedBox.shrink(),
        titleSpacing: Space.xl,
        title: _buildTitle(context, filtered, includeSearch: isTwoPane),
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
        child: withViewOverrides(buildDock(
          children: {
            LogsView.qsoTablePanelId: qsoListPane,
            LogsView.infoPanelId:
                _LogsInfoPanel(services: widget.services, totalCount: filtered?.length ?? 0, selected: selected),
            LogsView.mapPanelId: _LogsMapPanel(services: widget.services, selected: selected),
          },
          tabActions: {LogsView.mapPanelId: (context) => _buildMapSettingsButton(context)},
          extraChildren: sharedDashboardPanes,
        )),
      ),
    );
  }

  /// The Map panel's basemap picker, same target-scoped dialog the
  /// Operation view's own Map tab opens (see OperationView's own copy of
  /// this button) — Map is native and reached through a target rather than
  /// through `formFields`, so [DockHost.buildPanelSettingsButton] wouldn't
  /// find it either.
  Widget _buildMapSettingsButton(BuildContext context) => buildTargetSettingsButton(
        context,
        target: 'map',
        title: context.t.operation.menu.mapSettingsTitle,
      );

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

  /// The callsign picker, count/date-span and search field, all in the
  /// view's own AppBar rather than the QSO table pane's header — the pane
  /// stays genuinely headerless (see [defaultHeaderlessModules]) so it reads
  /// as one continuous list. "Logs" carries the AppBar's usual Roboto Slab,
  /// but at regular weight rather than the app-wide Black — the callsign
  /// next to it is what's meant to read as the emphasized part, in mono to
  /// match every other callsign display in the app. The count/date-span and
  /// search field both get a FIXED width rather than sizing to content, so
  /// switching callsigns (a shorter count, a wider date span) doesn't
  /// reflow the rest of the bar.
  Widget _buildTitle(BuildContext context, List<Qso>? filtered, {required bool includeSearch}) {
    final theme = Theme.of(context);
    final t = context.t;
    final baseStyle = (theme.appBarTheme.titleTextStyle ?? const TextStyle()).copyWith(fontWeight: FontWeight.w400);
    final foreground = theme.appBarTheme.foregroundColor;
    final call = _filter.stationCall;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        InkWell(
          key: _pickerKey,
          onTap: _callsigns.isEmpty ? null : _openCallsignPicker,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(call == null ? t.home.logs.title : '${t.home.logs.titleFor} ', style: baseStyle),
              if (call != null)
                Text(call, style: baseStyle.copyWith(fontFamily: 'RobotoMono', fontWeight: FontWeight.w800)),
              const SizedBox(width: Space.xs),
              Icon(MdiIcons.menuDown, color: foreground, semanticLabel: t.home.logs.changeCallsign),
            ],
          ),
        ),
        const SizedBox(width: Space.lg),
        // Flexible for the same reason as the search field below — on a
        // narrow AppBar the picker text plus this fixed-width box can
        // already fill the available room, and a box that can't shrink
        // turns that into a RenderFlex overflow instead of just clipping.
        Flexible(
          child: SizedBox(
            width: _countColumnWidth,
            // Blank while the callsign list is still loading — the list pane
            // itself carries the loading spinner (see [_QsoListPanel]), so
            // this stays quiet rather than doubling it up in the header.
            child: (_callsignsLoaded && call != null && filtered != null)
                ? _countAndDates(context, filtered, foreground)
                : null,
          ),
        ),
        // Dropped below the two-pane boundary rather than shrunk — see
        // [_narrowSearchRow], which puts the same field on its own row
        // instead.
        if (includeSearch) ...[
          const SizedBox(width: Space.lg),
          // Flexible with a floor, not a bare fixed SizedBox: the AppBar
          // gives this title a bounded width, and the picker text plus the
          // two fixed-width boxes ahead of it can already fill most of a
          // narrow window (docs/design/ui-scaling.md's tightest case) — a
          // search box that can't shrink at all turns that into a
          // RenderFlex overflow instead of just a narrower field.
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _searchFieldWidth, minWidth: 80),
              child: SizedBox(height: 36, child: _searchField(context)),
            ),
          ),
        ],
      ],
    );
  }

  /// The search field itself, shared between the title row (two-pane) and
  /// [_narrowSearchRow]'s own row (narrow) — one controller, one set of
  /// formatting/decoration rules, wherever it's drawn.
  Widget _searchField(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.t;
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _searchQuery = value),
      enabled: _filter.stationCall != null,
      inputFormatters: const [UpperCaseTextFormatter()],
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: theme.colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: Space.sm),
        prefixIcon: const Icon(MdiIcons.magnify),
        hintText: t.home.logs.searchHint,
        border: const OutlineInputBorder(),
      ),
    );
  }

  /// The QSO count and, when at least one QSO has a date, the earliest-to-
  /// latest span, painted in the AppBar's own foreground color so it reads
  /// against the primary-colored bar.
  Widget _countAndDates(BuildContext context, List<Qso> list, Color? color) {
    final info = context.t.loggingControls.info;
    final theme = Theme.of(context);
    final countLabel = list.length == 1 ? info.qsoCountOne : info.qsoCountOther(count: formatNumber(list.length));
    final range = _cachedMillisRange(list);
    final rangeLabel = range == null ? null : _dateRangeLabel(range.$1, range.$2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(countLabel, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: color)),
        if (rangeLabel != null) Text(rangeLabel, style: theme.textTheme.bodySmall?.copyWith(color: color)),
      ],
    );
  }

  /// A deliberately simpler import than `operation/adif_import_flow.dart`'s:
  /// this reads straight from the parser, never stamping a record's own
  /// station callsign to match one target operation's (that's what
  /// `planAdifImport`'s `stationCall` param does, and what drives its
  /// "foreign station" warning and activation prompt — neither belongs to a
  /// cross-operation log). It still calls `planAdifImport` with
  /// `stationCall: null`, purely for the merge-vs-addition matching it does
  /// against EXISTING QSOs across every operation (broadened from that
  /// function's usual one-operation scope), so a record matching something
  /// already logged updates it in place instead of duplicating it.
  ///
  /// Anything left over lands with no operation at all (`operationUuid: ''`)
  /// — "loose", until an operator (or later, real operation-detection) puts
  /// it in one. A record that MERGES keeps whatever operation (or looseness)
  /// the matched QSO already had.
  Future<void> _handleAdifDrop(XFile file) async {
    final t = context.t.adifImport;
    // Same order `adif_import_flow.dart`'s entry points check these in — the
    // busy check first, so an identical drop reports identically regardless
    // of which view it lands on. Shared with those two entry points (see
    // that flag's own doc comment) — this plans across every operation, so a
    // second import racing it is the same stale-snapshot corruption with a
    // wider blast radius.
    if (adifImportInFlight) {
      await _showAdifNotice(t.busy);
      return;
    }
    if (!looksLikeAdif(file.name)) {
      await _showAdifNotice(t.notAdif(filename: file.name));
      return;
    }
    adifImportInFlight = true;
    try {
      await _runAdifDrop(file);
    } finally {
      adifImportInFlight = false;
    }
  }

  Future<void> _runAdifDrop(XFile file) async {
    final t = context.t.adifImport;
    final importT = context.t.home.logs.import;
    final title = ValueNotifier<String>(importT.readingTitle);
    final progress = ValueNotifier<double?>(0);
    final detail = ValueNotifier<String>('');
    void disposeNotifiers() {
      title.dispose();
      progress.dispose();
      detail.dispose();
    }

    // Captured now, while this is definitely still mounted, rather than
    // reading `Navigator.of(context)` at each pop site below — the import
    // can outlive this view (switching away mid-drop), and a `NavigatorState`
    // held directly stays poppable after that, unlike `context`, which
    // throws once the element backing it is gone. The dialog itself is
    // `PopScope(canPop: false)`, so as long as nothing else shows a competing
    // modal while this barrier is up, this is the only thing left to pop.
    final dialogNavigator = Navigator.of(context, rootNavigator: true);
    void closeProgressDialog() {
      if (dialogNavigator.mounted) dialogNavigator.pop();
    }

    unawaited(showHaloDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AdifProgressDialog(title: title, progress: progress, detail: detail),
    ));

    AdifLog log;
    AdifImportPlan plan;
    try {
      // Streamed rather than one `readAsBytes()` call, purely so this has
      // real bytes-read progress to show instead of an indeterminate spinner
      // for however long a large file takes.
      final total = await file.length();
      final builder = BytesBuilder(copy: false);
      var readSoFar = 0;
      await for (final chunk in file.openRead()) {
        builder.add(chunk);
        readSoFar += chunk.length;
        if (total > 0) progress.value = readSoFar / total;
        detail.value = importT.readingDetail(kb: formatNumber((readSoFar / 1024).round()));
      }
      // Parsing has no natural checkpoint to report progress from (a single
      // synchronous pass), but the ref-hook pass and the duplicate lookup
      // both already run in bounded batches/chunks — real per-record
      // progress for those, on one combined bar, rather than leaving the
      // whole stretch indeterminate. Each callback below reports progress
      // ABSOLUTE within its own phase; `checkTotal` covers both phases, so
      // the lookup's contribution is offset by the hooks phase's total
      // (already complete by the time lookup starts) rather than restarting
      // the bar at the boundary between them.
      title.value = importT.checkingTitle;
      detail.value = '';
      progress.value = null;
      log = parseAdifLogBytes(builder.takeBytes());
      // Normalized the same way `historyForCalls` normalizes its own `calls`
      // argument internally (trim + uppercase) — otherwise two records
      // differing only in case or stray whitespace count as two entries
      // here but collapse to one in `historyForCalls`'s own total, and the
      // combined progress bar below stalls just short of 100% because the
      // lookup phase can never report as many calls checked as this side
      // expects.
      final theirCalls = <String>{
        for (final record in log.qsos)
          if ((record.qso['their'] as Map?)?['call'] case final String call when call.isNotEmpty)
            call.trim().toUpperCase(),
      }..removeWhere((call) => call.isEmpty);
      final checkTotal = log.qsos.length + theirCalls.length;
      void reportChecked(int checked) {
        if (checkTotal > 0) progress.value = checked / checkTotal;
        detail.value = importT.checkingDetail(done: formatNumber(checked), total: formatNumber(checkTotal));
      }

      final hookOutcome = await AdifImportService(widget.services.extensions.host).applyHooks(
        log.qsos,
        onBatch: (done, total) => reportChecked(done),
      );
      // One batched query rather than one per distinct counterparty — a
      // large file's callsigns run into the thousands, and a sequential
      // `historyForCall` per callsign turns that into thousands of
      // round trips with the progress bar stuck on indeterminate.
      final existing = await widget.services.qsos.historyForCalls(
        theirCalls,
        onChunk: (done, total) => reportChecked(log.qsos.length + done),
      );
      // Threaded through to the plan the same way `adif_import_flow.dart`
      // does — dropping these silently degrades a ref-hook failure into a
      // clean-looking import with no references, indistinguishable from a
      // file that genuinely had none.
      plan = planAdifImport(
        filename: file.name,
        records: log.qsos,
        existing: existing,
        unusable: log.errors,
        failedHooks: hookOutcome.failedHooks,
        recordsUnreachable: hookOutcome.recordsUnreachable,
        recordsWithFailedHooks: hookOutcome.recordsWithFailedHooks,
      );
    } catch (e, stack) {
      disposeNotifiers();
      closeProgressDialog();
      ErrorReportingService.report(e, stack, context: 'logsAdifImport');
      if (mounted) await _showAdifNotice(t.failed(filename: file.name, error: e.toString()));
      return;
    }
    if (!mounted) {
      disposeNotifiers();
      closeProgressDialog();
      return;
    }
    closeProgressDialog();

    // Uppercased, like every other callsign path in this view — an ADIF
    // file's STATION_CALLSIGN case isn't guaranteed, and `_callsigns` (from
    // `watchDistinctOurCalls`) is always uppercase, so a mixed-case value
    // here would both double-count in this summary and fail to match an
    // entry in the picker after `_selectCall` below.
    final calls = <String>{
      for (final record in log.qsos)
        if ((record.qso['our'] as Map?)?['call'] case final String call when call.isNotEmpty)
          call.toUpperCase(),
    }.toList()
      ..sort();
    // Coerced through `qsoStartMillis` rather than cast directly — a JSON
    // number from `applyHooks`'s extension host can come back as a double,
    // and a raw `as int?` throws on that outside the try block above.
    final dateRange = _millisRange(log.qsos.map((record) => qsoStartMillis(record.qso)));
    final dateRangeLabel = dateRange == null ? null : _dateRangeLabel(dateRange.$1, dateRange.$2);
    if (!mounted) {
      disposeNotifiers();
      return;
    }
    final confirmed = await showHaloDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final importT = context.t.home.logs.import;
        final totalInFile = t.totalInFile(count: log.qsos.length, formatted: formatNumber(log.qsos.length));
        return HaloDialog(
          title: Text(t.title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(importT.callsigns(calls: calls.join(', '))),
              const SizedBox(height: Space.sm),
              // Three separate counts, not one combined figure — a re-import
              // of a file already fully in the log matches every record and
              // imports none of them, and "0 QSOs" on its own reads as
              // nothing in the file was recognized rather than as "nothing
              // has changed since last time."
              Text(dateRangeLabel == null ? totalInFile : '$totalInFile ($dateRangeLabel)'),
              if (plan.alreadyLoggedCount > 0)
                Text(t.alreadyLogged(count: plan.alreadyLoggedCount, formatted: formatNumber(plan.alreadyLoggedCount))),
              Text(t.willImport(count: plan.importCount, formatted: formatNumber(plan.importCount))),
              if (plan.refusedCount > 0) ...[
                const SizedBox(height: Space.sm),
                Text(
                  plan.refusedCount == 1
                      ? importT.skippedOne
                      : importT.skippedOther(count: formatNumber(plan.refusedCount)),
                  style: TextStyle(color: Theme.of(dialogContext).colorScheme.error),
                ),
              ],
              // Two separate sentences, not one shared count, for the same
              // reason `adif_import_flow.dart`'s summary keeps them apart:
              // nothing reaching the runtime means no references were
              // recovered at all, while one program's hook failing still
              // leaves every other hook's answer intact — the honest claim
              // for each kind of record is different.
              if (plan.recordsUnreachable > 0) ...[
                const SizedBox(height: Space.sm),
                Text(
                  t.missingRefs(count: plan.recordsUnreachable, formatted: formatNumber(plan.recordsUnreachable)),
                  style: Theme.of(dialogContext).textTheme.bodySmall,
                ),
              ],
              if (plan.recordsWithFailedHooks > 0) ...[
                const SizedBox(height: Space.sm),
                Text(
                  t.partialRefs(
                    programs: failedProgramNames(widget.services.extensions.availableExtensions, plan.failedHooks)
                        .join(', '),
                    count: plan.recordsWithFailedHooks,
                    formatted: formatNumber(plan.recordsWithFailedHooks),
                  ),
                  style: Theme.of(dialogContext).textTheme.bodySmall,
                ),
              ],
              // Truly nothing recognized — as opposed to a fully-matched
              // re-import, which still has `alreadyLoggedCount` to say so —
              // gets the same explicit line `adif_import_flow.dart`'s
              // summary shows for the same case.
              if (plan.isEmpty && plan.refusedCount == 0 && plan.alreadyLoggedCount == 0)
                Text(context.t.adifImport.nothingToImport),
            ],
          ),
          // Empty plans get no confirm action, the same way
          // `adif_import_flow.dart` handles them — nothing to write, so the
          // only thing to do is close the summary.
          actions: [
            if (!plan.isEmpty) FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(t.confirm)),
          ],
          cancel: TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(plan.isEmpty ? context.t.common.done : context.t.common.cancel),
          ),
        );
      },
    );
    if (confirmed != true || !mounted) {
      disposeNotifiers();
      return;
    }

    var written = 0;
    final totalPlanned = plan.importCount;
    title.value = importT.importingTitle;
    progress.value = 0;
    detail.value = importT.importingDetail(imported: formatNumber(written), total: formatNumber(totalPlanned));
    unawaited(showHaloDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AdifProgressDialog(title: title, progress: progress, detail: detail),
    ));

    // Unsubscribed for the write phase, not merely paused — a large import
    // commits dozens of chunks, and each commit makes a live Drift stream
    // re-run its query and re-decode the full result set REGARDLESS of
    // whether its listener is paused (pausing only withholds delivery, not
    // the underlying work). Nothing is watching either while this view sits
    // behind the non-dismissible progress dialog above, so cancel rather
    // than pause, and resubscribe once after the last chunk lands.
    await _callsignsSubscription?.cancel();
    _callsignsSubscription = null;
    final callBeforeWrite = _filter.stationCall;
    if (mounted) setState(() => _qsosStream = null);
    // Never allowed to throw — called right before the notifiers/dialog
    // cleanup on every exit path (success, write failure, unmount), and a
    // caller that skipped that cleanup because THIS threw would leave the
    // non-dismissible progress dialog stuck on screen with nothing able to
    // close it, and — on the write-failure path — the real error unreported
    // underneath whatever this raised instead.
    void resubscribe() {
      try {
        if (!mounted) return;
        _subscribeCallsigns();
        setState(() => _qsosStream = callBeforeWrite == null ? null : widget.services.qsos.watchForOurCalls([callBeforeWrite]));
      } catch (e, stack) {
        ErrorReportingService.report(e, stack, context: 'logsAdifImport:resubscribe');
      }
    }
    // `writeBatch` refuses a batch whose updates don't all share its
    // `operationUuid`, so each destination operation (or the loose bucket)
    // gets its own call — chunked, so `progress` moves as QSOs actually
    // land rather than jumping straight to done on one giant batch. 1000,
    // not something smaller: `writeBatch` compiles each chunk into one
    // `db.batch()` statement, so the per-chunk cost is now mostly the
    // transaction commit rather than per-row work, and a larger chunk still
    // leaves plenty of progress updates (tens of them) on a file large
    // enough for the chunking to matter at all.
    const chunkSize = 1000;
    // Each chunk skips `writeBatch`'s own counter refresh (`refreshCounters:
    // false`) — a large import writes the same operation across dozens of
    // chunks, and the counters only need to be right once writing to it is
    // done, not after every intermediate chunk. `refreshTouchedCounters`
    // below catches up whichever operations were actually written to, once,
    // regardless of whether the import completes or throws partway through.
    final touchedOperations = <String>{};
    Future<void> writeChunked(String operationUuid, {List<Map<String, dynamic>> inserts = const [], List<Qso> updates = const []}) async {
      if (operationUuid.isNotEmpty) touchedOperations.add(operationUuid);
      for (var i = 0; i < inserts.length; i += chunkSize) {
        final chunk = inserts.sublist(i, math.min(i + chunkSize, inserts.length));
        written += await widget.services.qsos.writeBatch(operationUuid: operationUuid, inserts: chunk, refreshCounters: false);
        if (totalPlanned > 0) progress.value = written / totalPlanned;
        detail.value = importT.importingDetail(imported: formatNumber(written), total: formatNumber(totalPlanned));
      }
      for (var i = 0; i < updates.length; i += chunkSize) {
        final chunk = updates.sublist(i, math.min(i + chunkSize, updates.length));
        // The whole plan's bases ride along with every chunk — writeBatch
        // only consults the uuids it is writing, and without them a row
        // that moved while the confirm dialog sat open is clobbered with
        // the stale plan-time fold (see `updateBases`).
        written += await widget.services.qsos
            .writeBatch(operationUuid: operationUuid, updates: chunk, updateBases: plan.mergeBases, refreshCounters: false);
        if (totalPlanned > 0) progress.value = written / totalPlanned;
        detail.value = importT.importingDetail(imported: formatNumber(written), total: formatNumber(totalPlanned));
      }
    }

    // Same "never throws" contract as `resubscribe` above, and for the same
    // reason — one operation's counter failing to refresh must not skip the
    // dialog cleanup, or bury the write failure the catch block below exists
    // to report.
    Future<void> refreshTouchedCounters() async {
      for (final operationUuid in touchedOperations) {
        try {
          await widget.services.qsos.refreshOperationCounters(operationUuid);
        } catch (e, stack) {
          ErrorReportingService.report(e, stack, context: 'logsAdifImport:refreshCounters');
        }
      }
    }

    final mergesByOperation = <String, List<Qso>>{};
    for (final qso in plan.merges) {
      mergesByOperation.putIfAbsent(qso.operationUuid, () => []).add(qso);
    }
    try {
      for (final entry in mergesByOperation.entries) {
        await writeChunked(entry.key, updates: entry.value);
      }
      if (plan.additions.isNotEmpty) {
        await writeChunked('', inserts: plan.additions);
      }
    } catch (e, stack) {
      await refreshTouchedCounters();
      resubscribe();
      disposeNotifiers();
      closeProgressDialog();
      ErrorReportingService.report(e, stack, context: 'logsAdifImport:write');
      // `written` still reflects whatever chunks landed before the throw —
      // some of the file may already be in the log, so this states that
      // rather than reading as a clean failure the operator would retry
      // whole.
      if (mounted) {
        await _showAdifNotice(
          written > 0
              ? '${t.failed(filename: file.name, error: e.toString())}\n\n'
                  '${importT.importingDetail(imported: formatNumber(written), total: formatNumber(totalPlanned))}'
              : t.failed(filename: file.name, error: e.toString()),
        );
      }
      return;
    }
    await refreshTouchedCounters();
    resubscribe();
    disposeNotifiers();
    closeProgressDialog();
    if (!mounted) return;
    widget.services.statusBar.setMessage(
      key: 'logsAdifImport:status',
      text: t.imported(count: written, filename: file.name, formatted: formatNumber(written)),
      dismissAfter: StatusBarService.completedDismissDelay,
    );
    // The repository counts rows actually affected, so a merge target
    // deleted while the confirm dialog was open shows up here — same
    // reconciliation `adif_import_flow.dart` does after its own write.
    if (written != plan.importCount) {
      widget.services.statusBar.showNotice(
        key: 'logsAdifImport:shortfall',
        text: t.shortfall(written: written, planned: plan.importCount),
      );
    }
    try {
      widget.services.track(
        'adif_imported',
        {'count': written, 'merged': plan.merges.length, 'planned': plan.importCount, 'source': 'logs'},
      );
    } catch (e, stack) {
      ErrorReportingService.report(e, stack, context: 'logsAdifImport:telemetry');
    }

    // The callsign with the most QSOs in the file, so a multi-callsign
    // import (e.g. a rover's log) lands the operator on the one they
    // probably came here for rather than wherever they happened to be.
    final callCounts = <String, int>{};
    for (final record in log.qsos) {
      if ((record.qso['our'] as Map?)?['call'] case final String call when call.isNotEmpty) {
        final upperCall = call.toUpperCase();
        callCounts[upperCall] = (callCounts[upperCall] ?? 0) + 1;
      }
    }
    String? winner;
    var winnerCount = -1;
    for (final entry in callCounts.entries) {
      if (entry.value > winnerCount) {
        winner = entry.key;
        winnerCount = entry.value;
      }
    }
    if (winner != null) _selectCall(winner);
  }

  Future<void> _showAdifNotice(String message) => showHaloDialog<void>(
        context: context,
        builder: (dialogContext) => HaloDialog(
          title: Text(context.t.adifImport.title),
          content: Text(message),
          cancel: TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(context.t.common.done)),
        ),
      );
}

/// The middle pane: every QSO the filter and search match, oldest first — the
/// callsign picker, count/date-span and search field live in the view's own
/// AppBar (see `_LogsViewState._buildTitle`), so the only header this pane
/// draws is [_QsoListHeaderRow], labeling and resizing the fixed-width
/// columns below it. It sits BELOW the edit panel that's pinned above the
/// list while a QSO is selected — the labels belong to the list, not to
/// whatever's currently being edited — and, like the list, stays fully
/// visible regardless of where the list itself happens to be scrolled
/// VERTICALLY, the same way a page's header stays put while its body scrolls
/// underneath. HORIZONTALLY the two move together instead: widening the
/// fixed-width columns can push the table past the pane's own width, so
/// header and rows share ONE [SingleChildScrollView] (see [_LogsTableWidth]
/// and this class's own `build`) rather than each carrying its own
/// independent, and therefore driftable, horizontal offset.
///
/// The list itself is FIXED-extent ([LayoutMetrics.qsoRowHeight], the same
/// row height [QsoList] declares) so a scrollbar drag resolves to a target
/// offset in O(1) — [RenderSliverFixedExtentList] computes it as
/// `itemExtent * index` instead of walking every off-screen row to find out
/// how tall it painted. A real per-callsign log can run into the tens of
/// thousands of QSOs — exactly the size that walk turns into a multi-second
/// stall on every scrollbar drag. That fixed extent is what forces the edit
/// form out of the row and into [_LogQsoEditPanel] — a row whose own height
/// changed on selection would be right back to a variable extent.
class _QsoListPanel extends StatelessWidget {
  final HaLoServices services;
  final String? call;

  /// Already search-filtered — null before a callsign has ever been picked.
  final List<Qso>? qsos;
  final String? selectedUuid;

  /// The same lookup [_LogsInfoPanel] and [_LogsMapPanel] get — found in the
  /// UNFILTERED list, so a search that hides the selected row doesn't lose
  /// the edit panel out from under the operator.
  final Qso? selected;
  final ValueChanged<String> onSelect;
  final bool searching;

  /// True until the callsign list's first snapshot arrives — a spinner
  /// covers that stretch rather than the "select a callsign" prompt, which
  /// would otherwise flash before there's anything to select.
  final bool loading;

  final _LogsColumnWidths columnWidths;
  final void Function(String column, double delta) onResizeColumn;
  final VoidCallback onResizeColumnEnd;
  final void Function(String column, double width) onAutoFitColumn;

  /// See `_LogsViewState._visibleColumns` — which of [_allLogsColumns] are
  /// shown at all, independent of [columnWidths].
  final Set<String> visibleColumns;
  final void Function(Offset globalPosition) onShowColumnMenu;

  /// See `_LogsViewState._columnOrder` — left-to-right order of
  /// [_allLogsColumns], Name included.
  final List<String> columnOrder;
  final void Function(String dragged, String droppedOn) onReorderColumn;

  /// See [_maxFreqMhzDigits] — computed once by `_LogsViewState` over [qsos],
  /// not per row.
  final int freqMhzDigits;

  const _QsoListPanel({
    required this.services,
    required this.call,
    required this.qsos,
    required this.selectedUuid,
    required this.selected,
    required this.onSelect,
    required this.searching,
    required this.loading,
    required this.columnWidths,
    required this.onResizeColumn,
    required this.onResizeColumnEnd,
    required this.onAutoFitColumn,
    required this.visibleColumns,
    required this.onShowColumnMenu,
    required this.columnOrder,
    required this.onReorderColumn,
    required this.freqMhzDigits,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    // `_LogsViewState` auto-selects the first loaded callsign the moment the
    // list is non-empty, so reaching here with no callsign selected AND the
    // list already loaded only happens when nothing has been logged at all.
    if (call == null) return Center(child: Text(context.t.home.logs.emptyCallsigns));
    final list = qsos;
    if (list == null) return const Center(child: CircularProgressIndicator());
    if (list.isEmpty) {
      return Center(
        child: Text(searching ? context.t.home.logs.noSearchMatches : context.t.home.logs.emptyQsos(call: call!)),
      );
    }
    final rowExtent = LayoutDensity.metricsOf(context).qsoRowHeight;
    // Same boundary the view's own single-pane fallback uses (see
    // `_LogsViewState._buildScaffold`) — below it there's no room for the
    // full row, so it drops to the columns a QSO can be told apart by.
    final compact = !ShirtSize.of(context).isTwoPane;
    return Column(
      children: [
        // Same cross-fade-and-resize `AccordionSection` uses for its own
        // reveal (longer duration: this panel is taller, and the fields
        // inside it need to be readable mid-animation, not just glimpsed) —
        // a panel that just snapped into existence read as a layout jump,
        // not a response to the tap that opened it.
        AnimatedCrossFade(
          firstChild: selected == null
              ? const SizedBox(width: double.infinity)
              // Keyed by uuid so switching the selection remounts fresh
              // controllers rather than reusing the previous QSO's — no
              // live update arriving mid-edit can overwrite what the
              // operator is typing (see [_LogQsoEditPanel]'s own doc
              // comment).
              : _LogQsoEditPanel(
                  key: ValueKey(selected!.uuid),
                  services: services,
                  qso: selected!,
                  onDone: () => onSelect(selected!.uuid),
                ),
          secondChild: const SizedBox(width: double.infinity),
          crossFadeState: selected == null ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 400),
          sizeCurve: Curves.easeInOut,
        ),
        // Below the edit panel, not above it — column labels belong to the
        // list they sit on top of, not to whatever's currently being edited.
        Expanded(
          child: compact
              // No header, no horizontal scroll, no Name column at this
              // width — the same boundary the view itself falls back to a
              // list-only layout at (see `_LogsViewState._buildScaffold`).
              ? _buildRows(context, list, rowExtent, compact: true, tableWidth: _compactTableWidth)
              // Measured from a LayoutBuilder, not the SingleChildScrollView
              // below it — that one's own constraints are unbounded along
              // the scroll axis, which would make every table "wide enough
              // to scroll" whether or not it actually was.
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final tableWidth = _LogsTableWidth.of(
                      availableWidth: constraints.maxWidth,
                      widths: columnWidths,
                      visibleColumns: visibleColumns,
                      columnOrder: columnOrder,
                    );
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: tableWidth.content,
                        height: constraints.maxHeight,
                        child: Column(
                          children: [
                            _QsoListHeaderRow(
                              widths: columnWidths,
                              visibleColumns: visibleColumns,
                              columnOrder: columnOrder,
                              tableWidth: tableWidth,
                              onResize: onResizeColumn,
                              onResizeEnd: onResizeColumnEnd,
                              onAutoFit: (column) => onAutoFitColumn(
                                column,
                                _autoFitColumnWidth(column, context, list, freqMhzDigits),
                              ),
                              onShowMenu: onShowColumnMenu,
                              onReorder: onReorderColumn,
                            ),
                            Expanded(
                              child: _buildRows(context, list, rowExtent, compact: false, tableWidth: tableWidth),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// Compact never shows Name or a header (see the branch above), so nothing
  /// in [_LogQsoSummaryRow] ever reads this — a placeholder rather than a
  /// nullable `tableWidth` param everywhere else has to null-check.
  static const _compactTableWidth = _LogsTableWidth(content: 0, flexWidth: 0, flexId: null);

  Widget _buildRows(
    BuildContext context,
    List<Qso> list,
    double rowExtent, {
    required bool compact,
    required _LogsTableWidth tableWidth,
  }) =>
      ListView.builder(
        itemCount: list.length,
        itemExtent: rowExtent,
        itemBuilder: (context, index) {
          final qso = list[index];
          return _LogQsoSummaryRow(
            qso: qso,
            selected: qso.uuid == selectedUuid,
            // The selected row's own accent border already marks its bottom
            // edge (see [_LogQsoSummaryRow]); a divider under it too would
            // paint over that border, foreground decorations painting
            // child-to-ancestor. The very last row has nothing below it to
            // divide from either way.
            drawDivider: index < list.length - 1 && qso.uuid != selectedUuid,
            compact: compact,
            widths: columnWidths,
            visibleColumns: visibleColumns,
            columnOrder: columnOrder,
            freqMhzDigits: freqMhzDigits,
            tableWidth: tableWidth,
            onTap: () => onSelect(qso.uuid),
          );
        },
      );
}

/// Labels [_QsoListPanel]'s columns and carries the drag handles that resize
/// them, plus a `Draggable`/`DragTarget` pair PER COLUMN LABEL — including
/// Name's — that reorders them: dropping one onto another moves it there
/// (see `_LogsViewState._reorderColumn`). Shown only alongside the two-pane,
/// non-[compact] row layout (see `_QsoListPanel.build`), which is the one
/// whose widths are user-resizable at all. Column widths and the gap
/// between them mirror [_LogQsoSummaryRow]'s own non-compact layout exactly,
/// so labels line up with the data beneath them; whichever column
/// [_LogsTableWidth] finds trailing skips its own resize handle and just
/// takes what's left, the same as the row's own trailing cell does. Same
/// gray background and bottom-border treatment as `DayHeaderRow`
/// (`QsoList`'s own per-day header in the operation view), for the same
/// reason: `surface` alone doesn't read as a header against the
/// plain-`surface` rows below it.
class _QsoListHeaderRow extends StatelessWidget {
  final _LogsColumnWidths widths;
  final Set<String> visibleColumns;
  final void Function(String column, double delta) onResize;
  final VoidCallback onResizeEnd;

  /// Snaps a column to the width [_autoFitColumnWidth] computes for it —
  /// double-clicking its resize handle, the same "auto-fit" gesture
  /// spreadsheets use.
  final void Function(String column) onAutoFit;

  /// Right-click anywhere on the row — opens `_LogsViewState._openColumnMenu`
  /// at the click position, the "which columns are shown" menu.
  final void Function(Offset globalPosition) onShowMenu;

  /// See [_LogsTableWidth] — computed once by `_QsoListPanel`, shared with
  /// every [_LogQsoSummaryRow] in the same build so the whole table (inside
  /// one shared horizontally-scrolling region) stays exactly
  /// [_LogsTableWidth.content] wide.
  final _LogsTableWidth tableWidth;

  /// See `_LogsViewState._columnOrder`.
  final List<String> columnOrder;

  /// A column was dropped onto another — see `_LogsViewState._reorderColumn`.
  final void Function(String dragged, String droppedOn) onReorder;

  const _QsoListHeaderRow({
    required this.widths,
    required this.visibleColumns,
    required this.onResize,
    required this.onResizeEnd,
    required this.onAutoFit,
    required this.onShowMenu,
    required this.tableWidth,
    required this.columnOrder,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.t.home.logs.columns;
    final labelStyle = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
    );

    Widget label(String text) => Text(text, style: labelStyle, maxLines: 1, overflow: TextOverflow.ellipsis);

    String labelOf(String id) => switch (id) {
          'date' => t.date,
          'time' => t.time,
          'freq' => t.freq,
          'mode' => t.mode,
          'call' => t.call,
          'name' => t.name,
          _ => id,
        };

    Widget handle(String column, {bool asOverlay = false}) => _ColumnResizeHandle(
          width: Space.lg,
          asOverlay: asOverlay,
          onDragUpdate: (delta) => onResize(column, delta),
          onDragEnd: onResizeEnd,
          onDoubleTap: () => onAutoFit(column),
        );

    // Drop target first, `Draggable` inside it: this cell needs to
    // recognize a drag landing on ITSELF (to swap in) as much as it needs
    // to start one, and only the outer widget sees `candidateData` to paint
    // the "drop here" highlight.
    Widget draggableColumn(String id, double width) {
      final box = SizedBox(width: width, child: label(labelOf(id)));
      return DragTarget<String>(
        onWillAcceptWithDetails: (details) => details.data != id,
        onAcceptWithDetails: (details) => onReorder(details.data, id),
        builder: (context, candidates, _) => ColoredBox(
          color: candidates.isNotEmpty ? theme.colorScheme.primary.withValues(alpha: 0.15) : Colors.transparent,
          child: Draggable<String>(
            data: id,
            dragAnchorStrategy: pointerDragAnchorStrategy,
            feedback: Material(
              elevation: 4,
              color: theme.colorScheme.primary,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.xs),
                child: Text(labelOf(id), style: labelStyle?.copyWith(color: theme.colorScheme.onPrimary)),
              ),
            ),
            childWhenDragging: Opacity(opacity: 0.35, child: box),
            child: MouseRegion(cursor: SystemMouseCursors.grab, child: box),
          ),
        ),
      );
    }

    // Transparent, touch-sized grab strips overlaid on the handles — empty
    // off a touch platform. The handle itself is only [Space.lg] wide and
    // can't grow: it is the very gap [_LogQsoSummaryRow] leaves between its
    // own columns, so widening it would slide the header out of line with
    // every QSO row under it. A strip can't merely overhang the handle
    // either — hit-testing runs in reverse child order, so the column cell
    // to its right would take back everything on that side.
    final touchSlop = paneDividerTouchSlop();
    final strips = <Widget>[];
    // Where in the row the next child starts, for placing those strips.
    var offset = 0.0;

    // Every visible column is draggable, including Name — whichever ends up
    // LAST (the loop's own [tableWidth.flexId]) skips the trailing handle,
    // since there's nothing after it left to resize against, and takes
    // [tableWidth.flexWidth] instead of its own stored width.
    final children = <Widget>[];
    for (final id in columnOrder) {
      if (!visibleColumns.contains(id)) continue;
      if (id == tableWidth.flexId) {
        children.add(draggableColumn(id, tableWidth.flexWidth));
        offset += tableWidth.flexWidth;
      } else {
        children.add(draggableColumn(id, widths.widthOf(id)));
        offset += widths.widthOf(id);
        // Where a strip is overlaid, the strip IS the handle — it paints the
        // line as well as owning the gesture, so hover and drag feedback stay
        // in the one widget that sees the pointer. The row keeps the gap the
        // line sits in and nothing else.
        children.add(touchSlop > 0 ? const SizedBox(width: Space.lg) : handle(id));
        if (touchSlop > 0) {
          strips.add(
            Positioned(
              left: offset - touchSlop,
              top: 0,
              bottom: 0,
              width: Space.lg + touchSlop * 2,
              child: handle(id, asOverlay: true),
            ),
          );
        }
        offset += Space.lg;
      }
    }

    return GestureDetector(
      onSecondaryTapUp: (details) => onShowMenu(details.globalPosition),
      child: Container(
        color: theme.colorScheme.surfaceContainerHighest,
        // `foregroundDecoration`, not `decoration` — same reason `DayHeaderRow`
        // uses it: `decoration`'s border would inset the child and grow this
        // row past a plain QSO row's height for the same padding.
        foregroundDecoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: theme.colorScheme.outline, width: 3)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.xs),
          // Passthrough so the row is laid out under exactly the constraints
          // it gets without the Stack — the strips are placed from column
          // widths this row was already built from.
          child: strips.isEmpty
              ? Row(children: children)
              : Stack(fit: StackFit.passthrough, children: [Row(children: children), ...strips]),
        ),
      ),
    );
  }
}

/// A drag handle between two [_QsoListHeaderRow] columns, sized to the same
/// [Space.lg] gap [_LogQsoSummaryRow] leaves between its own columns. Drives
/// its drag from a root-level capture overlay rather than its own
/// hit-testing once the pointer is down — the same technique
/// [SolidPaneDivider] uses, and for the same reason: this bar is only a
/// couple of device pixels wide, LogsView has a map webview a fast drag can
/// cross into, and a native view that steals the pointer-up leaves the drag
/// stuck "active" forever with no `onDragEnd` ever firing.
class _ColumnResizeHandle extends StatefulWidget {
  final double width;

  /// Laid over the header row rather than sized inside it, and
  /// [paneDividerTouchSlop] wider on each side than [width], so a fingertip
  /// can hit it. It paints the same line — the row leaves a plain gap where
  /// this one is used, so that the widget the pointer reaches is the widget
  /// that draws the feedback.
  ///
  /// It takes presses OPAQUELY: a translucent one would leave the column cell
  /// underneath in the gesture arena, and the drag that resizes the column
  /// would start dragging the column itself too. The cost is that a column
  /// REORDER can't be started from within a slop of a boundary.
  final bool asOverlay;

  final ValueChanged<double> onDragUpdate;
  final VoidCallback onDragEnd;
  final VoidCallback onDoubleTap;

  const _ColumnResizeHandle({
    required this.width,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onDoubleTap,
    this.asOverlay = false,
  });

  @override
  State<_ColumnResizeHandle> createState() => _ColumnResizeHandleState();
}

class _ColumnResizeHandleState extends State<_ColumnResizeHandle> {
  bool _hovered = false;
  bool _dragging = false;

  /// Non-null for the duration of a drag: a root-level, purely visual,
  /// fully-transparent overlay entry covering the ENTIRE window, above every
  /// platform view. See [SolidPaneDivider]'s own field doc — same technique,
  /// same reason: it exists only to claim the pointer route away from a
  /// native view, not to paint anything.
  OverlayEntry? _captureOverlay;

  /// The pointer this handle is currently watching, from its
  /// `PointerDownEvent` to its up/cancel — null the rest of the time.
  int? _trackingPointer;

  /// Set once the tracked pointer has moved past [_dragSlop] — null before
  /// that. Distinguishes a real drag (which owns [_captureOverlay] and has
  /// called `widget.onDragUpdate`) from a plain click still being watched.
  int? _activePointer;
  Offset? _downPosition;
  Offset? _lastPosition;

  static double _dragSlop(PointerDeviceKind kind) =>
      kind == PointerDeviceKind.touch ? kTouchSlop : kPrecisePointerPanSlop;

  void _handlePointerDown(PointerDownEvent event) {
    if (_trackingPointer != null) return;
    if (event.buttons != kPrimaryButton) return;
    _trackingPointer = event.pointer;
    _downPosition = event.position;
    _lastPosition = event.position;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (event.pointer != _trackingPointer) return;
    if (_activePointer == null) {
      if ((event.position - _downPosition!).distance < _dragSlop(event.kind)) return;
      _activePointer = event.pointer;
      setState(() => _dragging = true);
      final overlay = Overlay.of(context, rootOverlay: true);
      _captureOverlay = OverlayEntry(
        builder: (context) => const Positioned.fill(child: IgnorePointer(child: ColoredBox(color: Colors.transparent))),
      );
      overlay.insert(_captureOverlay!);
    }
    final last = _lastPosition!;
    _lastPosition = event.position;
    widget.onDragUpdate(event.position.dx - last.dx);
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (event.pointer != _trackingPointer) return;
    _endTracking();
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (event.pointer != _trackingPointer) return;
    _endTracking();
  }

  // Cancelled the same as completed, deliberately: a cancelled drag still
  // applied `onDragUpdate` deltas up to this point (`_resizeColumn` already
  // `setState`d the new width), so skipping `onDragEnd` here would leave
  // that width applied on screen but never persisted — silently lost on the
  // next settings reload.
  void _endTracking() {
    final wasActive = _activePointer != null;
    _trackingPointer = null;
    _activePointer = null;
    _downPosition = null;
    _lastPosition = null;
    // A plain click never started a drag (no overlay, no `onDragUpdate`) —
    // nothing to end.
    if (!wasActive) return;
    _captureOverlay?.remove();
    _captureOverlay = null;
    setState(() => _dragging = false);
    widget.onDragEnd();
  }

  @override
  void dispose() {
    // The overlay outlives a mere rebuild but not the handle itself.
    _captureOverlay?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = _hovered || _dragging;
    final behavior = widget.asOverlay ? HitTestBehavior.opaque : HitTestBehavior.translucent;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: behavior,
        onDoubleTap: widget.onDoubleTap,
        child: Listener(
          behavior: behavior,
          onPointerDown: _handlePointerDown,
          onPointerMove: _handlePointerMove,
          onPointerUp: _handlePointerUp,
          onPointerCancel: _handlePointerCancel,
          // The overlay takes the size its Positioned gives it; the line
          // centres in either, and the boundary is the centre of both.
          child: SizedBox(
            width: widget.asOverlay ? null : widget.width,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                width: active ? 2 : 1,
                height: 16,
                color: active ? theme.colorScheme.primary : theme.dividerColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Resolves a QSO's own [Operation] live, for panels (map, call info) that
/// want its real grid rather than a placeholder — [Operation.grid] is the
/// QTH fallback when a QSO has none of its own, so a synthetic empty
/// Operation would silently drop that fallback. A loose QSO's
/// `operationUuid` is `''`, which matches no row either way, so the same
/// synthetic fallback covers it without a separate branch.
class _QsoOperationBuilder extends StatelessWidget {
  final HaLoServices services;
  final String operationUuid;
  final Widget Function(BuildContext context, Operation operation) builder;

  const _QsoOperationBuilder({required this.services, required this.operationUuid, required this.builder});

  @override
  Widget build(BuildContext context) => StreamBuilder<Operation?>(
        stream: services.operations.watchOperation(operationUuid),
        builder: (context, snapshot) =>
            builder(context, snapshot.data ?? Operation(uuid: operationUuid, data: const {})),
      );
}

/// The info panel: no selection shows the filter's aggregate QSO count. A QSO
/// selected shows that QSO's counterparty looked up, the same [CallInfoPanel]
/// the operation view shows while composing/editing — fetched here directly
/// (`services.extensions.lookupCall`) since there is no `LoggingControls`
/// around to have already resolved it.
class _LogsInfoPanel extends StatefulWidget {
  final HaLoServices services;
  final int totalCount;
  final Qso? selected;

  const _LogsInfoPanel({required this.services, required this.totalCount, required this.selected});

  @override
  State<_LogsInfoPanel> createState() => _LogsInfoPanelState();
}

class _LogsInfoPanelState extends State<_LogsInfoPanel> {
  // Two separate trackers, not one: [_requestedFor] is set synchronously so
  // a second call before the first resolves doesn't fire a duplicate lookup;
  // [_resolvedFor] only advances once a result (or failure) actually lands,
  // and is what `build` checks for the spinner. A single shared tracker set
  // synchronously would read as "resolved" before the request is even in
  // flight, since `didUpdateWidget` runs before `build` in the same pass —
  // the spinner branch would never show, and the previous callsign's guess
  // and lookups would stay on screen, mislabeled under the new callsign, until the
  // network call happens to return.
  String? _requestedFor;
  String? _resolvedFor;
  Map<String, dynamic>? _guess;
  List<Map<String, dynamic>> _lookups = const [];

  @override
  void initState() {
    super.initState();
    _maybeLookup();
  }

  @override
  void didUpdateWidget(_LogsInfoPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeLookup();
  }

  void _maybeLookup() {
    final call = widget.selected?.theirCall;
    // Cleared on deselect, not left pointing at the last request — otherwise
    // reselecting the SAME callsign (after deselecting before its lookup
    // resolved) reads as already-requested and never fires again, leaving
    // `_resolvedFor` permanently behind and the spinner up for good.
    if (call == null) {
      _requestedFor = null;
      return;
    }
    if (call == _requestedFor) return;
    _requestedFor = call;
    widget.services.extensions.lookupCall(call, qso: const {}, operation: const {}).then((result) {
      if (!mounted || widget.selected?.theirCall != call) return;
      setState(() {
        _resolvedFor = call;
        _guess = result?['guess'] as Map<String, dynamic>?;
        _lookups = asQsonList(result?['lookups'])?.whereType<Map<String, dynamic>>().toList() ?? const [];
      });
    }, onError: (Object e, StackTrace stack) {
      ErrorReportingService.report(e, stack, context: 'logsInfoPanel:lookupCall');
      if (!mounted || widget.selected?.theirCall != call) return;
      // Cleared, not left at the previous callsign's values — a failed
      // lookup under the new callsign must not go on showing the old one's.
      setState(() {
        _resolvedFor = call;
        _guess = null;
        _lookups = const [];
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    if (selected == null) {
      final t = context.t.loggingControls.info;
      final countLabel = widget.totalCount == 1 ? t.qsoCountOne : t.qsoCountOther(count: formatNumber(widget.totalCount));
      return Center(child: Text(countLabel));
    }
    if (_resolvedFor != selected.theirCall) {
      return const Center(child: CircularProgressIndicator());
    }
    return _QsoOperationBuilder(
      services: widget.services,
      operationUuid: selected.operationUuid,
      builder: (context, operation) => CallInfoPanel(
        operation: operation,
        services: widget.services,
        call: selected.theirCall,
        guess: _guess,
        lookups: _lookups,
      ),
    );
  }
}

/// The map panel — the selected QSO's own location and nothing else plotted.
/// [MapPanel] already draws a great-circle line from a QSO's counterpart grid
/// to its resolved QTH (`qso.our.grid`, falling back to the operation's) for
/// every QSO it's handed; a one-element list is exactly the "just this
/// contact" case; that fallback is why this fetches the QSO's real
/// [Operation] rather than a placeholder.
class _LogsMapPanel extends StatelessWidget {
  final HaLoServices services;
  final Qso? selected;

  const _LogsMapPanel({required this.services, required this.selected});

  @override
  Widget build(BuildContext context) {
    final qso = selected;
    if (qso == null) {
      return Center(child: Text(context.t.home.logs.mapNoSelection));
    }
    return _QsoOperationBuilder(
      services: services,
      operationUuid: qso.operationUuid,
      builder: (context, operation) => MapPanel(operation: operation, qsos: [qso], settings: services.settings),
    );
  }
}

final _dateFormat = DateFormat('yyyy-MM-dd');
final _timeFormat = DateFormat('HH:mm');

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

/// The largest MHz-digit count among freq values in [qsos] — 1 when none has
/// a numeric freq at all. [_LogQsoSummaryRow] left-pads every row's MHz part
/// to this width (see [_freqField]'s `mhzDigits`), so in a monospace face the
/// digits land on the same column across rows via the padding spaces
/// themselves, without needing a fixed-width box or pixel-level alignment —
/// and a column left-anchored in a wider, user-resized [_LogsColumnWidths]
/// picks up the leftover width as trailing space rather than pulling the
/// digits away from Time.
int _maxFreqMhzDigits(List<Qso> qsos) {
  var digits = 1;
  for (final qso in qsos) {
    final freq = qso.freq;
    if (freq == null) continue;
    final mhzLength = freqDisplayParts(freq, hzDigits: 0).mhz.length;
    if (mhzLength > digits) digits = mhzLength;
  }
  return digits;
}

/// The narrowest [column] can get while still showing, in full, every value
/// currently in [qsos] AND its own header label — double-clicking a
/// [_QsoListHeaderRow] handle snaps to this, the same "auto-fit" gesture
/// spreadsheets use on a header border. Measures with [textWidth] — the same
/// helper the spots panel uses for the same reason: it lays a string out the
/// way a real `Text` widget would (ambient style merge, current
/// `textScaler`), rather than a bare `TextPainter`, which measures at
/// scale 1.0 and comes out too narrow under any OS/accessibility text
/// scaling above that. The Call column's font differs from the other mono
/// columns (bold, larger) and Name isn't mono at all (see
/// [_LogQsoSummaryRow]'s own `cellContent`), so only a per-column style,
/// matching what actually renders, is correct for either. `date`/`time` are
/// fixed-format, so their widest value is a representative sample rather
/// than anything read from [qsos].
double _autoFitColumnWidth(String column, BuildContext context, List<Qso> qsos, int freqMhzDigits) {
  final theme = Theme.of(context);
  final monoStyle = theme.textTheme.bodyMedium?.copyWith(fontFamily: 'RobotoMono');
  final callStyle = theme.textTheme.titleMedium?.copyWith(fontFamily: 'RobotoMono', fontWeight: FontWeight.w800);
  final nameStyle = theme.textTheme.bodyMedium;
  final labelStyle = theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700);

  String widest(Iterable<String> values) {
    var best = '';
    for (final value in values) {
      if (value.length > best.length) best = value;
    }
    return best;
  }

  final t = context.t.home.logs.columns;
  final (dataText, dataStyle, headerText) = switch (column) {
    'date' => ('0000-00-00', monoStyle, t.date),
    'time' => ('00:00z', monoStyle, t.time),
    'freq' => (
        widest([
          for (final qso in qsos)
            if (qso.freq case final khz?)
              (() {
                // The same string `_freqRow` draws — this measures the
                // column, so a separator of a different width under-reserves
                // it.
                final parts = freqDisplayParts(khz, hzDigits: 0);
                return '${groupDigits(parts.mhz).padLeft(freqMhzDigits)}'
                    '${NumberFormatting.instance.groupingSeparator}${parts.khz}';
              })()
            else
              ?qso.band,
        ]),
        monoStyle,
        t.freq,
      ),
    // The DISPLAYED mode, like the cell below — measuring a stored `LSB` for
    // a cell that renders `SSB` reserves a width no row uses.
    'mode' => (
        widest(qsos.map((qso) => displayMode(qso.mode, freqKHz: qso.freq, band: qso.band) ?? '')),
        monoStyle,
        t.mode,
      ),
    'call' => (widest(qsos.map((qso) => qso.theirCall)), callStyle, t.call),
    'name' => (widest(qsos.map((qso) => qso.theirName ?? '')), nameStyle, t.name),
    _ => ('', monoStyle, ''),
  };
  final width = math.max(
    textWidth(context, dataText, dataStyle ?? const TextStyle()),
    textWidth(context, headerText, labelStyle ?? const TextStyle()),
  );
  return math.max(_LogsColumnWidths._min, width);
}

/// Bolded-MHz/regular-kHz, dot-separated — the same split [QsoList] paints
/// its own frequency column with, rounded to the kHz (no Hz segment: this
/// list spans many operations at once, so there's no single QSO set to ask
/// "does anything here need sub-kHz precision"). [mhzDigits] left-pads the
/// MHz part with spaces (see [_maxFreqMhzDigits]) so every row in the current
/// set lines up its digits without the column needing to right-align at all.
Widget _freqField(double khz, TextStyle? style, {required int mhzDigits}) {
  final parts = freqDisplayParts(khz, hzDigits: 0);
  return Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.baseline,
    textBaseline: TextBaseline.alphabetic,
    children: [
      // kHz, like the QSO list and the spots panel: what divides these is a
      // thousands mark, not a decimal point. Padded AFTER grouping, so the
      // column still lines up once a separator has been inserted.
      Text(groupDigits(parts.mhz).padLeft(mhzDigits), style: style?.copyWith(fontWeight: FontWeight.w700)),
      Text(NumberFormatting.instance.groupingSeparator, style: style),
      Text(parts.khz, style: style),
    ],
  );
}

/// One fixed-height row in [_QsoListPanel]'s list — summary only, no edit
/// state; selecting a row is [onTap] plus whatever [_QsoListPanel] does with
/// it, and the actual editing happens in [_LogQsoEditPanel] elsewhere on
/// screen. Up to [_allLogsColumns]' six (whichever [visibleColumns] keeps)
/// — no RST (signal reports don't earn a column in a cross-operation log)
/// and no other operation-only columns (QSO#, DX flag/state, activity refs,
/// contest exchange), neither of which is offered in the column menu at
/// all. Date is first: unlike a single operation's log, a row here can be
/// from any day.
///
/// [compact] drops the name column regardless of [visibleColumns] and
/// tightens the rest — the same single-pane boundary the view itself falls
/// back to a list-only layout at (see `_LogsViewState._buildScaffold`),
/// where there simply isn't the width for a sixth column, and the numeric
/// ones (date/time/freq — mode and the callsign stay put, both short and
/// already tight) go to a condensed cut of the same mono face rather than a
/// smaller size, which would just make them harder to read at exactly the
/// width where every column already had to fight for room.
class _LogQsoSummaryRow extends StatelessWidget {
  final Qso qso;
  final bool selected;
  final bool drawDivider;
  final bool compact;

  /// Ignored when [compact] — the compact layout has its own fixed, tighter
  /// widths (see the class doc), not the user-resized ones from
  /// [_QsoListHeaderRow], which isn't shown at that width either.
  final _LogsColumnWidths widths;

  /// See `_LogsViewState._visibleColumns` — a column absent here is skipped
  /// entirely (box, gap and all), whether or not [compact] would otherwise
  /// show it.
  final Set<String> visibleColumns;

  /// See [_maxFreqMhzDigits] — computed once, over the whole displayed set,
  /// by [_QsoListPanel] rather than per row, so every row pads to the same
  /// width regardless of its own value.
  final int freqMhzDigits;

  /// See [_LogsTableWidth] — ignored when [compact], same as [widths].
  final _LogsTableWidth tableWidth;

  /// See `_LogsViewState._columnOrder` — same left-to-right order
  /// [_QsoListHeaderRow] draws its labels in, applied here whether or not
  /// [compact] (a reordered narrow fallback reads the same as the reordered
  /// full one, even with no header up there to show the order). `compact`
  /// still drops `name` regardless of where reordering put it — see the
  /// class doc.
  final List<String> columnOrder;

  final VoidCallback onTap;

  const _LogQsoSummaryRow({
    required this.qso,
    required this.selected,
    required this.drawDivider,
    required this.compact,
    required this.widths,
    required this.visibleColumns,
    required this.freqMhzDigits,
    required this.tableWidth,
    required this.columnOrder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final start =
        qso.startAtMillis == null ? null : DateTime.fromMillisecondsSinceEpoch(qso.startAtMillis!, isUtc: true);
    final date = start == null ? '' : _dateFormat.format(start);
    final time = start == null ? '' : '${_timeFormat.format(start)}z';
    final textColor = selected ? theme.colorScheme.onSecondaryContainer : null;
    final monoStyle = theme.textTheme.bodyMedium?.copyWith(fontFamily: 'RobotoMono', color: textColor);
    final condensedStyle = compact ? monoStyle?.copyWith(fontFamily: 'RobotoCondensed') : monoStyle;
    final columnGap = compact ? Space.xs : Space.lg;
    // The compact layout's own fixed widths, always the class's defaults —
    // see the class doc.
    final columnWidths = compact ? const _LogsColumnWidths() : widths;
    final freqKHz = qso.freq;
    final callsignText = Text(
      qso.theirCall,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.titleMedium?.copyWith(fontFamily: 'RobotoMono', fontWeight: FontWeight.w800, color: textColor),
    );
    // Content only, no width yet — the trailing visible column (Call, unless
    // it's been hidden or reordered away from the end) is `Expanded`, and
    // everything else's width depends on whether THIS build's
    // [tableWidth.flexId] happens to land on it, so wrapping happens per
    // loop iteration below, not here.
    final cellContent = {
      'date': Text(date, style: condensedStyle, maxLines: 1, softWrap: false),
      'time': Text(time, style: condensedStyle),
      'freq': freqKHz == null
          ? Text(qso.band ?? '', style: condensedStyle)
          : _freqField(freqKHz, condensedStyle, mhzDigits: freqMhzDigits),
      // `SSB` for the sideband the band runs; the one it doesn't is spelled
      // out, in the error color, because that is the whole reason to spell it.
      'mode': Text(
        displayMode(qso.mode, freqKHz: freqKHz, band: qso.band) ?? '',
        style: isUnexpectedSideband(qso.mode, freqKHz: freqKHz, band: qso.band)
            ? monoStyle?.copyWith(color: theme.colorScheme.error)
            : monoStyle,
      ),
      'call': callsignText,
      'name': Text(
        qso.theirName ?? '',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
      ),
    };
    final rowChildren = <Widget>[];
    if (compact) {
      // The trailing visible column (usually Call, but hiding or reordering
      // can put another one there) is the one that gets `Expanded` — a
      // hardcoded `id == 'call'` check left dead space on the right if Call
      // itself was ever hidden, since nothing else would step up to fill it.
      final compactVisible = [
        for (final id in columnOrder)
          if (id != 'name' && visibleColumns.contains(id)) id,
      ];
      final compactFlexId = compactVisible.isEmpty ? null : compactVisible.last;
      // Gap only BETWEEN what's left after hiding — there's no header here
      // to stay pixel-aligned with, and the trailing column already soaks up
      // whatever's left via `Expanded`, so a gap after it would just be dead
      // space before nothing. `name` is skipped outright — compact drops it
      // regardless of [visibleColumns] or where reordering put it, see the
      // class doc.
      for (final id in compactVisible) {
        if (rowChildren.isNotEmpty) rowChildren.add(SizedBox(width: columnGap));
        rowChildren.add(
          id == compactFlexId
              ? Expanded(child: cellContent[id]!)
              : SizedBox(width: columnWidths.widthOf(id), child: cellContent[id]!),
        );
      }
    } else {
      // Gap unconditionally AFTER every visible NON-TRAILING column —
      // matching [_QsoListHeaderRow]'s own resize handle, present after
      // every such column regardless of what follows it (see
      // [_LogsTableWidth]), so the two stay in lockstep pixel-for-pixel
      // whichever columns are hidden or reordered. `columnOrder` filtered to
      // [visibleColumns] always ends on [tableWidth.flexId] by construction
      // (see [_LogsTableWidth.of]), so this loop's own last iteration is
      // exactly the one that skips the gap.
      for (final id in columnOrder) {
        if (!visibleColumns.contains(id)) continue;
        final isFlex = id == tableWidth.flexId;
        rowChildren.add(SizedBox(width: isFlex ? tableWidth.flexWidth : columnWidths.widthOf(id), child: cellContent[id]!));
        if (!isFlex) rowChildren.add(const SizedBox(width: Space.lg));
      }
    }
    // foregroundDecoration paints over the already-laid-out child instead of
    // insetting it (unlike `decoration`, which turns a border into padding)
    // — the same technique [QsoList] uses for its own selected-row accent,
    // needed here for the same reason: a border can't add height on top of
    // the row's own fixed extent (see [_QsoListPanel]'s doc comment). The
    // divider is undrawn on the selected row for the same reason `QsoList`'s
    // own `_RowDivider` skips it: the accent border already marks that edge.
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: selected
            ? Border.symmetric(horizontal: BorderSide(color: theme.colorScheme.secondary, width: 3))
            : (drawDivider
                ? Border(bottom: BorderSide(width: 1, color: DividerTheme.of(context).color ?? theme.dividerColor))
                : null),
      ),
      child: Material(
        color: selected ? theme.colorScheme.secondaryContainer : theme.colorScheme.surface,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? Space.sm : Space.lg, vertical: Space.xs),
            child: Row(children: rowChildren),
          ),
        ),
      ),
    );
  }
}

/// The edit form for whichever QSO is selected, pinned above the list — the
/// same relationship `LoggingControls` has with the operation view's
/// `QsoList`, adopted here for the same reason: pulling the
/// form out of the row is what lets the row keep a fixed extent (see
/// [_QsoListPanel]'s doc comment). Keyed by the caller on `qso.uuid`, so a
/// fresh selection remounts this with fresh controllers rather than reusing
/// the previous QSO's — no live update arriving mid-edit can overwrite what
/// the operator is typing, because there is no `didUpdateWidget` path that
/// re-seeds an existing instance at all.
class _LogQsoEditPanel extends StatefulWidget {
  final HaLoServices services;
  final Qso qso;
  final VoidCallback onDone;

  const _LogQsoEditPanel({super.key, required this.services, required this.qso, required this.onDone});

  @override
  State<_LogQsoEditPanel> createState() => _LogQsoEditPanelState();
}

class _LogQsoEditPanelState extends State<_LogQsoEditPanel> {
  late final TextEditingController _call;
  late final TextEditingController _date;
  late final TextEditingController _time;
  late final TextEditingController _freqOrBand;
  late final TextEditingController _mode;

  /// What [_mode] was seeded with — the DISPLAYED mode, which for a contact
  /// stating neither a frequency nor a band collapses a stored sideband to
  /// `SSB` with nothing to resolve it back from. Saving that would take the
  /// sideband out of the log, so an untouched field keeps what was stored.
  late final String _modeSeed;
  late final TextEditingController _sentRst;
  late final TextEditingController _rcvdRst;
  late final TextEditingController _notes;
  bool _saving = false;

  /// Set while Delete has been tapped but not yet saved — mirrors
  /// LoggingControls' `_pendingDelete`: staged, fields locked, and the save
  /// button becomes the actual delete until Undo puts it back.
  bool _pendingDelete = false;

  /// The row as this panel loaded it — the snapshot the controllers were
  /// seeded from, and the `basedOn` the save passes. `widget.qso` cannot
  /// serve: the parent re-resolves it by uuid from the watched stream on
  /// every build, so after a sync pull lands mid-edit it IS the new row —
  /// its stamp equals the stored one, and update()'s concurrent-edit merge
  /// would self-disable in exactly the case it exists for.
  late final Qso _loadedQso;

  @override
  void initState() {
    super.initState();
    final qso = _loadedQso = widget.qso;
    final start = qso.startAtMillis == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(qso.startAtMillis!, isUtc: true);
    _call = TextEditingController(text: qso.theirCall);
    _date = TextEditingController(text: start == null ? '' : _dateFormat.format(start));
    _time = TextEditingController(text: start == null ? '' : _timeFormat.format(start));
    // kHz, seeded by the same formatter the logging panel's own frequency
    // field uses — and, critically, the inverse of the `parseFreq` that reads
    // this box back on save. A hand-built MHz string is not: it writes a
    // period whatever the operator's Number Formatting setting says, so on a
    // locale whose decimal is a comma `14.285` reads back as grouped kHz and
    // the QSO is saved three orders of magnitude off, having never been
    // touched. `fmtFreqInput` also emits no thousands separator at all, which
    // is what keeps 1296 MHz from parsing as 1296 kHz.
    _freqOrBand =
        TextEditingController(text: qso.freq != null ? fmtFreqInput(qso.freq!) : (qso.band ?? ''));
    // The mode as the row above shows it, or the dialog would read `LSB`
    // under a row reading `SSB`. Resolved again on save, against the seed
    // kept here so an untouched field cannot write the collapse back.
    _modeSeed = displayMode(qso.mode, freqKHz: qso.freq, band: qso.band) ?? '';
    _mode = TextEditingController(text: _modeSeed);
    _sentRst = TextEditingController(text: qso.sentRST ?? '');
    _rcvdRst = TextEditingController(text: qso.receivedRST ?? '');
    _notes = TextEditingController(text: qso.notes ?? '');
  }

  @override
  void dispose() {
    for (final controller in [_call, _date, _time, _freqOrBand, _mode, _sentRst, _rcvdRst, _notes]) {
      controller.dispose();
    }
    super.dispose();
  }

  /// `null` when the typed date/time doesn't parse — the save then keeps
  /// whatever `startAtMillis` the QSO already had rather than blanking it.
  int? _parsedStartAtMillis() {
    try {
      final dateParts = _date.text.trim().split('-').map(int.parse).toList();
      final timeParts = _time.text.trim().split(':').map(int.parse).toList();
      final parsed = DateTime.utc(dateParts[0], dateParts[1], dateParts[2], timeParts[0], timeParts[1]);
      // DateTime.utc normalizes out-of-range components (e.g. day 30 in
      // February) instead of throwing — round-tripping catches what the
      // FormatException/RangeError guards below can't.
      final roundTrips = parsed.year == dateParts[0] &&
          parsed.month == dateParts[1] &&
          parsed.day == dateParts[2] &&
          parsed.hour == timeParts[0] &&
          parsed.minute == timeParts[1];
      return roundTrips ? parsed.millisecondsSinceEpoch : null;
    } on FormatException {
      return null;
    } on RangeError {
      return null;
    }
  }

  Future<void> _save() async {
    // Composed from the SNAPSHOT the form was seeded from, not the live
    // `widget.qso` — the edit is "what the operator saw plus what they
    // typed", and update()'s merge below reconciles it against whatever the
    // row holds by now.
    final qso = _loadedQso;
    setState(() => _saving = true);
    try {
      final their = <String, dynamic>{...?asQsonMap(qso.data['their'])};
      final our = <String, dynamic>{...?asQsonMap(qso.data['our'])};
      their['call'] = _call.text.trim().toUpperCase();
      their['sent'] = _rcvdRst.text.trim();
      our['sent'] = _sentRst.text.trim();
      final startAtMillis = _parsedStartAtMillis() ?? qso.startAtMillis;
      final freqOrBand = _freqOrBand.text.trim();
      // Same parsing the main logging fields use — [parseFreq] accepts kHz or
      // MHz-with-decimal, [parseBandInput] a band name when it isn't a
      // frequency at all. Both keys are always written (one to its parsed
      // value, the other to null) rather than only the one that matched: the
      // `...qso.data` spread below carries the OLD value of both forward, so
      // a band-only edit that only set `band` would leave the QSO's old
      // `freq` in place — and the row and edit form both prefer `freq` when
      // it's present, so the edit would look like it silently didn't take.
      final parsedFreqKHz = parseFreq(freqOrBand);
      final parsedBand = parsedFreqKHz == null ? parseBandInput(freqOrBand) : null;
      // Neither parsed — text that names no frequency and no band, e.g. a
      // stray character or an accidental clear — keeps the QSO's existing
      // values rather than wiping both to null; same "unparseable input
      // changes nothing" rule `_parsedStartAtMillis` follows below.
      final freqFieldUnparseable = parsedFreqKHz == null && parsedBand == null;
      final updated = Qso(
        uuid: qso.uuid,
        operationUuid: qso.operationUuid,
        data: {
          ...qso.data,
          'their': their,
          'our': our,
          'freq': freqFieldUnparseable ? qso.freq : parsedFreqKHz,
          'band': freqFieldUnparseable ? qso.band : parsedBand,
          // Resolved against the freq/band this save settles on, like every
          // other mode a person types: a typed `SSB` is not a mode a radio can
          // be in, and storing it would put a generic mode in a log the rest
          // of the app keeps concrete.
          'mode': (() {
            final typed = _mode.text.trim().toUpperCase();
            final freq = freqFieldUnparseable ? qso.freq : parsedFreqKHz;
            final band = freqFieldUnparseable ? qso.band : parsedBand;
            // Nothing to resolve against, and the field was never touched:
            // the seed is a collapsed view of the stored mode, so writing it
            // through would swap a recorded `LSB` for a generic `SSB` that no
            // frequency can ever turn back.
            if (expectedSideband(freqKHz: freq, band: band) == null) {
              return typed == _modeSeed ? (qso.mode ?? typed) : typed;
            }
            return resolveSideband(typed, freq, band: band) ?? typed;
          })(),
          'notes': _notes.text,
          'startAtMillis': ?startAtMillis,
        },
        scoreCache: qso.scoreCache,
      );
      // `basedOn` is the same snapshot: if a sync pull moved the row while
      // the panel sat open, only the fields edited here overwrite it (see
      // mergeConcurrentEdit).
      await widget.services.qsos.update(updated, basedOn: _loadedQso);
    } catch (e, stack) {
      ErrorReportingService.report(e, stack, context: 'logsQsoEdit:save');
      if (mounted) {
        widget.services.statusBar.showNotice(key: 'logsQsoEdit:save', text: context.t.loggingControls.saveFailed(error: e));
      }
      return;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    widget.onDone();
  }

  Future<void> _delete() async {
    setState(() => _saving = true);
    try {
      await widget.services.qsos.softDelete(widget.qso);
    } catch (e, stack) {
      ErrorReportingService.report(e, stack, context: 'logsQsoEdit:delete');
      if (mounted) {
        setState(() => _saving = false);
        widget.services.statusBar.showNotice(key: 'logsQsoEdit:delete', text: context.t.loggingControls.deleteFailed(error: e));
      }
      return;
    }
    if (!mounted) return;
    setState(() => _saving = false);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.t;
    // Bottom border only, unlike the row's own symmetric accent — this
    // panel is pinned above the pane's own top edge, not sitting directly
    // under a row (a long list scrolls the selected row out of view while
    // this stays put), so only the edge shared with the scrolling list
    // below needs marking.
    return Material(
      color: theme.colorScheme.secondaryContainer,
      elevation: 4,
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.colorScheme.secondary, width: 3))),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (widget.qso.operationUuid.isNotEmpty)
                    IconButton(
                      icon: Icon(MdiIcons.openInNew, semanticLabel: t.home.logs.openOperation),
                      onPressed: () => Navigator.of(context).push(
                        slideInFromRight<void>(
                          (_) => OperationView(services: widget.services, operationUuid: widget.qso.operationUuid),
                        ),
                      ),
                    ),
                ],
              ),
              if (_pendingDelete)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.md),
                  child: Text(
                    t.loggingControls.pendingDeleteWarning,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.error, fontWeight: FontWeight.w700),
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _field(t.loggingControls.theirCall, _call, width: 140),
                  const SizedBox(width: Space.md),
                  _field(t.loggingControls.date, _date, width: 110),
                  const SizedBox(width: Space.md),
                  _field(t.loggingControls.timeUtc, _time, width: 90),
                  const Spacer(),
                  _saveButton(theme),
                ],
              ),
              const SizedBox(height: Space.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _field(t.loggingControls.frequency, _freqOrBand, width: 100),
                  const SizedBox(width: Space.md),
                  _field(t.loggingControls.mode, _mode, width: 90),
                  const SizedBox(width: Space.md),
                  _field(t.loggingControls.sent, _sentRst, width: 70),
                  const SizedBox(width: Space.md),
                  _field(t.loggingControls.rcvd, _rcvdRst, width: 70),
                  const Spacer(),
                  _deleteButton(context, theme),
                ],
              ),
              const SizedBox(height: Space.md),
              Padding(
                // The last field gets extra room below it, so the form
                // doesn't end flush against the panel's own bottom edge —
                // every other gap in this form is Space.md, breathing room
                // the notes field (the form's last element, and the one
                // most likely to wrap to more than one line) doesn't
                // otherwise get.
                padding: const EdgeInsets.only(bottom: Space.lg),
                child: TextField(
                  controller: _notes,
                  enabled: !_pendingDelete,
                  decoration: _fieldDecoration(context, t.qsoEditForm.notes),
                  minLines: 1,
                  maxLines: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController controller, {required double width}) => SizedBox(
        width: width,
        child: TextField(
          controller: controller,
          enabled: !_pendingDelete,
          decoration: _fieldDecoration(context, label),
        ),
      );

  /// Filled, matching the one documented "fields need a background"
  /// convention in the app (`LoggingControls`' secondary-fields panel, which
  /// paints its fields on `colorScheme.surface` regardless of the panel's
  /// own tinted background) — this panel's own background is the selection
  /// tint, same reasoning applies.
  InputDecoration _fieldDecoration(BuildContext context, String label) => InputDecoration(
        labelText: label,
        isDense: true,
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        border: const OutlineInputBorder(),
      );

  /// Same circular, `secondary`-filled button `LoggingControls` shows while
  /// editing (there it's a `tertiary`→`secondary` theme remap; here the
  /// panel's own accent already IS secondary, so this just paints straight
  /// from it). Becomes the actual delete action while [_pendingDelete].
  Widget _saveButton(ThemeData theme) {
    const diameter = 44.0;
    return SizedBox(
      width: diameter,
      height: diameter,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: theme.colorScheme.secondary,
          foregroundColor: theme.colorScheme.onSecondary,
          minimumSize: Size.zero,
          padding: EdgeInsets.zero,
          shape: const CircleBorder(),
        ),
        onPressed: _saving ? null : (_pendingDelete ? _delete : _save),
        child: _saving
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            // Same 60%-of-diameter sizing the delete button below uses —
            // `Icon`'s own default (24) reads small against a 44px button.
            : Icon(_pendingDelete ? MdiIcons.trashCan : MdiIcons.contentSave, size: diameter * 0.6),
      ),
    );
  }

  /// Delete → staged (`_pendingDelete = true`, nothing written yet) → Save
  /// commits the delete, or Undo (this same slot) drops the stage — the same
  /// three-state cycle `LoggingControls` runs its own delete button through.
  /// Icon-only, at the exact footprint `LoggingControls` gives its own
  /// wipe/delete button (`_buildWipeOrEditButton`): a `SizedBox`-authoritative
  /// 44×44 box, zero internal padding, an icon at 60% of that diameter —
  /// not `IconButton`'s own default constraints, which run smaller.
  Widget _deleteButton(BuildContext context, ThemeData theme) {
    const diameter = 44.0;
    final t = context.t.loggingControls;
    final IconData icon;
    final String label;
    final VoidCallback onPressed;
    if (_pendingDelete) {
      icon = MdiIcons.undo;
      label = t.undoDelete;
      onPressed = () => setState(() => _pendingDelete = false);
    } else {
      icon = MdiIcons.trashCanOutline;
      label = context.t.common.delete;
      onPressed = () => setState(() => _pendingDelete = true);
    }
    return SizedBox(
      width: diameter,
      height: diameter,
      child: IconButton(
        icon: Icon(icon, semanticLabel: label),
        iconSize: diameter * 0.6,
        padding: EdgeInsets.zero,
        color: theme.colorScheme.secondary,
        onPressed: onPressed,
      ),
    );
  }
}

/// A non-dismissible progress dialog for the ADIF import's two blocking
/// phases (reading the file, writing the batch) — popped by the caller once
/// that phase's work finishes, not by anything in here. [title] and [detail]
/// are `ValueNotifier`s rather than plain fields so the SAME dialog instance
/// can carry the caller through both phases — swapping the phase title,
/// resetting the bar, and updating the running count — instead of closing
/// and reopening one dialog per phase, which reads as a flicker rather than
/// one continuous import.
///
/// [progress] is `0..1` for a real fraction (bytes read, QSOs written so
/// far) or `null` for a stretch with no comparable unit to report (parsing,
/// the extension ref-hook pass) — the bar falls back to indeterminate for
/// exactly that stretch.
class _AdifProgressDialog extends StatelessWidget {
  final ValueListenable<String> title;
  final ValueListenable<double?> progress;
  final ValueListenable<String> detail;

  const _AdifProgressDialog({required this.title, required this.progress, required this.detail});

  @override
  Widget build(BuildContext context) => PopScope(
        // `barrierDismissible: false` on the call site keeps a tap outside
        // from closing this, but only the system back button/gesture goes
        // through `PopScope` — without this, that route is the one thing
        // able to pop the dialog out from under the code driving it, which
        // then pops whatever the NEXT topmost route happens to be instead.
        canPop: false,
        child: HaloDialog(
          title: ValueListenableBuilder<String>(valueListenable: title, builder: (context, value, _) => Text(value)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<double?>(
                valueListenable: progress,
                builder: (context, value, _) => LinearProgressIndicator(value: value),
              ),
              const SizedBox(height: Space.lg),
              ValueListenableBuilder<String>(
                valueListenable: detail,
                builder: (context, value, _) => Text(value),
              ),
            ],
          ),
        ),
      );
}
