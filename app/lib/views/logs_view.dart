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

part 'logs/logs_table.dart';
part 'logs/logs_side_panes.dart';
part 'logs/logs_edit_panel.dart';
part 'logs/logs_adif_drop.dart';

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
    _countAndDatesWidth = _measureCountAndDates(context);
  }

  /// See [_measureCountAndDates] — taken here, where a change to the theme,
  /// the language or the text scale it depends on comes through, rather than
  /// in every build of the header for a width none of the header's own
  /// changes can move.
  double _countAndDatesWidth = 0;

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

  final _pickerKey = GlobalKey();

  // The search, the sort and the date-range scan are each at least O(n)
  // over the whole log, which the QSO scale this view targets (see
  // `_QsoListPanel`'s own doc comment) makes worth not repeating: this
  // widget's `build` reruns on state changes that don't touch the QSO list,
  // the search text or the sort at all, e.g. selecting a row. Keyed on the
  // identity of the source list (unchanged across an unrelated rebuild,
  // since it's the same snapshot from the stream) rather than deep-equality,
  // and on the identity of [_sort], which is replaced rather than mutated.
  List<Qso>? _cachedRowsSource;
  String? _cachedRowsQuery;
  _LogsSort? _cachedRowsSort;

  /// Also what the keyboard steps through: it is exactly what is on screen.
  _LogsTableRows? _cachedRows;
  List<Qso>? _cachedRangeSource;
  (int, int)? _cachedRange;
  List<Qso>? _cachedFreqDigitsSource;
  int? _cachedFreqDigits;

  _LogsTableRows _tableRowsFor(List<Qso> qsos) {
    if (identical(qsos, _cachedRowsSource) && _searchQuery == _cachedRowsQuery && identical(_sort, _cachedRowsSort)) {
      return _cachedRows!;
    }
    final rows = _LogsTableRows(_sortedQsos(_applySearch(qsos), _sort), dayDividers: _sort.chronological);
    _cachedRowsSource = qsos;
    _cachedRowsQuery = _searchQuery;
    _cachedRowsSort = _sort;
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
    if (remember) {
      unawaited(widget.services.settings.setLayoutData(LayoutKeys.logsFilter, {'call': filter.allCalls ? null : filter.stationCall}));
    }
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
      if (top < position.pixels) {
        _listScroll.jumpTo(top);
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
  /// and closes, the same one-shot `showMenu` [_openCallsignPicker] uses for
  /// its own menu, rather than staying open for several toggles in a row.
  Future<void> _openColumnMenu(Offset globalPosition) async {
    final selection = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(globalPosition.dx, globalPosition.dy, globalPosition.dx, globalPosition.dy),
      items: [
        for (final column in _allLogsColumns)
          CheckedPopupMenuItem(value: column, checked: _visibleColumns.contains(column), child: Text(_logsColumnLabel(context, column))),
      ],
    );
    // Same guard [_openCallsignPicker] uses for its own awaited `showMenu` —
    // the menu can still resolve after this state is disposed (navigate away
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

  Future<void> _openCallsignPicker() async {
    final box = _pickerKey.currentContext?.findRenderObject() as RenderBox?;
    final overlayBox = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlayBox == null) return;
    final topLeft = box.localToGlobal(Offset(0, box.size.height), ancestor: overlayBox);
    final position = RelativeRect.fromLTRB(topLeft.dx, topLeft.dy, overlayBox.size.width - topLeft.dx, 0);
    final theme = Theme.of(context);
    final sortedCalls = _callsigns.keys.toList()..sort();
    PopupMenuItem<LogFilter> item(LogFilter value, Widget label, int count) => PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Expanded(child: label),
          const SizedBox(width: Space.md),
          // Same count-pill treatment the operation list uses for its own
          // QSO count.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.xxs),
            decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
            child: Text(formatNumber(count), style: theme.textTheme.labelLarge),
          ),
        ],
      ),
    );
    final picked = await showMenu<LogFilter>(
      context: context,
      position: position,
      items: [
        item(const LogFilter.all(), Text(context.t.home.logs.allCallsigns), _callsigns.values.fold(0, (sum, count) => sum + count)),
        const PopupMenuDivider(),
        for (final call in sortedCalls)
          item(
            LogFilter(stationCall: call),
            Text(
              call,
              style: const TextStyle(fontFamily: 'RobotoMono', fontWeight: FontWeight.w700),
            ),
            _callsigns[call] ?? 0,
          ),
      ],
    );
    if (picked != null && mounted) await _pickFilter(picked);
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

  Widget _buildScaffold(BuildContext context, List<Qso>? qsos) {
    final rows = qsos == null ? null : _tableRowsFor(qsos);
    final filtered = rows?.qsos;
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
    // A picker with one entry is no choice at all: the title just names it.
    final picking = _callsigns.length > 1;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        InkWell(
          key: _pickerKey,
          onTap: picking ? _openCallsignPicker : null,
          // The visible title alone names the button, not run together with
          // a label for the arrow: Flutter web lays the name out as DOM text
          // inside this box with its overflow showing, and a name long enough
          // to wrap spills below the AppBar, where its lines take the clicks
          // meant for the table header underneath.
          // A node of its own when there is nothing to pick and the InkWell
          // makes none — and only then: with a picker, a separate node would
          // hang the label under the button's instead of naming it.
          child: Semantics(
            container: !picking,
            label: call != null
                ? '${t.home.logs.titleFor} $call'
                : _filter.allCalls
                ? t.home.logs.titleAll
                : t.home.logs.title,
            excludeSemantics: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  call != null
                      ? '${t.home.logs.titleFor} '
                      : _filter.allCalls
                      ? t.home.logs.titleAll
                      : t.home.logs.title,
                  style: baseStyle,
                ),
                if (call != null)
                  Text(
                    call,
                    style: baseStyle.copyWith(fontFamily: 'RobotoMono', fontWeight: FontWeight.w800),
                  ),
                if (picking) ...[const SizedBox(width: Space.xs), Icon(MdiIcons.menuDown, color: foreground)],
              ],
            ),
          ),
        ),
        const SizedBox(width: Space.xxl),
        // Flexible for the same reason as the search field below — on a
        // narrow AppBar the picker text plus this fixed-width box can
        // already fill the available room, and a box that can't shrink
        // turns that into a RenderFlex overflow instead of just clipping.
        Flexible(
          child: SizedBox(
            width: _countAndDatesWidth,
            // Blank while the callsign list is still loading — the list pane
            // itself carries the loading spinner (see [_QsoListPanel]), so
            // this stays quiet rather than doubling it up in the header.
            child: (_callsignsLoaded && !_filter.isEmpty && filtered != null) ? _countAndDates(context, filtered, foreground) : null,
          ),
        ),
        // Dropped below the two-pane boundary rather than shrunk — see
        // [_narrowSearchRow], which puts the same field on its own row
        // instead.
        if (includeSearch) ...[
          const SizedBox(width: Space.xxl),
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

  TextStyle _countStyle(ThemeData theme) => (theme.textTheme.bodyMedium ?? const TextStyle()).copyWith(fontWeight: FontWeight.w700);

  TextStyle _datesStyle(ThemeData theme) => theme.textTheme.bodySmall ?? const TextStyle();

  /// Room for the widest count and date span the header can show, measured
  /// rather than fixed: neither ellipsizes, and since it doesn't follow the
  /// numbers on screen, switching callsigns never shifts the search field.
  double _measureCountAndDates(BuildContext context) {
    final theme = Theme.of(context);
    final info = context.t.loggingControls.info;
    // A span of dates is as wide as any other in this fixed format.
    final span = _dateRangeLabel(0, 400 * _logsDayMillis);
    return math.max(textWidth(context, info.qsoCountOther(count: formatNumber(888888)), _countStyle(theme)), textWidth(context, span, _datesStyle(theme)));
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
        Text(countLabel, style: _countStyle(theme).copyWith(color: color)),
        if (rangeLabel != null) Text(rangeLabel, style: _datesStyle(theme).copyWith(color: color)),
      ],
    );
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
