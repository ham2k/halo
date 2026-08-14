// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:intl/intl.dart';

import '../i18n/strings.g.dart';
import '../main.dart';
import '../services/adif_import_plan.dart';
import '../services/adif_import_service.dart';
import '../services/error_reporting_service.dart';
import '../services/panel_service.dart';
import '../services/settings_service.dart';
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
  DockLayoutKeys get dockKeys => const DockLayoutKeys(
    spec: LayoutKeys.logsDock,
    state: LayoutKeys.logsDockState,
    paneOptions: LayoutKeys.logsPaneOptions,
    viewOptions: LayoutKeys.logsViewOptions,
  );

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

  /// The table beside the info+map column, stacked — the shipped arrangement.
  /// No migration to fold in: this dock has no pre-dock history like Home's.
  @override
  DockNode buildDefaultDockSpec({bool migrate = true}) => DockSplit(Axis.horizontal, [
    DockGroup([LogsView.qsoTablePanelId]),
    DockSplit(Axis.vertical, [
      DockGroup([LogsView.infoPanelId]),
      DockGroup([LogsView.mapPanelId]),
    ], [1, 1]),
  ], [2, 1]);

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
  String? _selectedUuid;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  /// Cached from [_callsignsStream] — the picker menu needs a synchronous
  /// list to build its items from, and this is also what a fresh view
  /// auto-selects the first entry of.
  List<String> _callsigns = const [];

  /// `false` until [_callsignsStream] delivers its first snapshot — the view
  /// shows a spinner for that stretch rather than the "select a callsign"
  /// prompt, which would otherwise flash before there is anything to select.
  bool _callsignsLoaded = false;
  StreamSubscription<List<String>>? _callsignsSubscription;

  /// Empty until a callsign is picked — the query needs one, so there is
  /// nothing to watch before then.
  Stream<List<Qso>>? _qsosStream;

  late final Stream<List<String>> _callsignsStream = widget.services.qsos.watchDistinctOurCalls();

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
    _callsignsSubscription = _callsignsStream.listen((calls) {
      setState(() {
        _callsignsLoaded = true;
        _callsigns = calls;
        // A fresh view, or one whose selected callsign just dropped out of
        // the list (its last QSO deleted), opens on something rather than
        // getting stuck on a callsign with nothing left behind it.
        if (!calls.contains(_filter.stationCall) && calls.isNotEmpty) _selectCall(calls.first);
      });
    });
  }

  @override
  void dispose() {
    unawaited(_callsignsSubscription?.cancel());
    _searchController.dispose();
    super.dispose();
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
    final picked = await showMenu<String>(
      context: context,
      position: position,
      items: [
        for (final call in _callsigns)
          PopupMenuItem(
            value: call,
            child: Text(call, style: const TextStyle(fontFamily: 'RobotoMono', fontWeight: FontWeight.w700)),
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
    // Below the two-pane boundary this view falls back to the QSO list
    // alone, no Info or Map — the same hard cut (never both mounted) Home
    // and the operation view make at the same boundary, per
    // docs/design/layouts.md. There is nothing to arrange at that width
    // either, so the layout-edit header controls go with it.
    final isTwoPane = ShirtSize.of(context).isTwoPane;
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
          if (isTwoPane) ?viewOptionsButton(context, editing: layoutEditing),
          if (isTwoPane) ...layoutHeaderControls(context),
          windowsCaptionSpacer(context),
        ],
        // Row two, narrow only: the search field the title row dropped.
        bottom: isTwoPane ? null : _narrowSearchRow(context),
      ),
      // AdifDropTarget over the whole body: a drop anywhere on the Logs view
      // imports, not just over the QSO table.
      body: AdifDropTarget(
        onFile: _handleAdifDrop,
        child: isTwoPane
            ? withViewOverrides(buildDock(
                children: {
                  LogsView.qsoTablePanelId: qsoListPane,
                  LogsView.infoPanelId:
                      _LogsInfoPanel(services: widget.services, totalCount: filtered?.length ?? 0, selected: selected),
                  LogsView.mapPanelId: _LogsMapPanel(services: widget.services, selected: selected),
                },
                extraChildren: sharedDashboardPanes,
              ))
            : qsoListPane,
      ),
    );
  }

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
      // Parsing and the extension ref-hook pass have no comparable per-unit
      // progress to report — back to indeterminate for this stretch.
      progress.value = null;
      log = parseAdifLogBytes(builder.takeBytes());
      final hookOutcome = await AdifImportService(widget.services.extensions.host).applyHooks(log.qsos);
      final theirCalls = <String>{
        for (final record in log.qsos)
          if ((record.qso['their'] as Map?)?['call'] case final String call when call.isNotEmpty) call,
      };
      // One batched query rather than one per distinct counterparty — a
      // large file's callsigns run into the thousands, and a sequential
      // `historyForCall` per callsign turns that into thousands of
      // round trips with the progress bar stuck on indeterminate.
      final existing = await widget.services.qsos.historyForCalls(theirCalls);
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

    if (plan.isEmpty) {
      disposeNotifiers();
      await _showAdifNotice(context.t.adifImport.nothingToImport);
      return;
    }

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
        final info = context.t.loggingControls.info;
        final importT = context.t.home.logs.import;
        return HaloDialog(
          title: Text(t.title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(importT.callsigns(calls: calls.join(', '))),
              const SizedBox(height: Space.sm),
              Text(
                plan.importCount == 1 ? info.qsoCountOne : info.qsoCountOther(count: formatNumber(plan.importCount)),
              ),
              if (dateRangeLabel != null) Text(dateRangeLabel),
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
                  t.missingRefs(count: plan.recordsUnreachable),
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
                  ),
                  style: Theme.of(dialogContext).textTheme.bodySmall,
                ),
              ],
            ],
          ),
          actions: [FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(t.confirm))],
          cancel: TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.t.common.cancel),
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
    // `writeBatch` refuses a batch whose updates don't all share its
    // `operationUuid`, so each destination operation (or the loose bucket)
    // gets its own call — chunked, so `progress` moves as QSOs actually
    // land rather than jumping straight to done on one giant batch.
    const chunkSize = 200;
    Future<void> writeChunked(String operationUuid, {List<Map<String, dynamic>> inserts = const [], List<Qso> updates = const []}) async {
      for (var i = 0; i < inserts.length; i += chunkSize) {
        final chunk = inserts.sublist(i, math.min(i + chunkSize, inserts.length));
        written += await widget.services.qsos.writeBatch(operationUuid: operationUuid, inserts: chunk);
        if (totalPlanned > 0) progress.value = written / totalPlanned;
        detail.value = importT.importingDetail(imported: formatNumber(written), total: formatNumber(totalPlanned));
      }
      for (var i = 0; i < updates.length; i += chunkSize) {
        final chunk = updates.sublist(i, math.min(i + chunkSize, updates.length));
        written += await widget.services.qsos.writeBatch(operationUuid: operationUuid, updates: chunk);
        if (totalPlanned > 0) progress.value = written / totalPlanned;
        detail.value = importT.importingDetail(imported: formatNumber(written), total: formatNumber(totalPlanned));
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
    disposeNotifiers();
    closeProgressDialog();
    if (!mounted) return;
    widget.services.statusBar.setMessage(
      key: 'logsAdifImport:status',
      text: t.imported(count: written, filename: file.name, formatted: formatNumber(written)),
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

/// The middle pane: every QSO the filter and search match, oldest first —
/// genuinely headerless (the callsign picker, count/date-span and search
/// field live in the view's own AppBar, see `_LogsViewState._buildTitle`),
/// so this is just the list plus, while a QSO is selected, the edit panel
/// pinned above it — always fully visible regardless of where the list
/// itself happens to be scrolled, the same way a page's header stays put
/// while its body scrolls underneath.
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

  const _QsoListPanel({
    required this.services,
    required this.call,
    required this.qsos,
    required this.selectedUuid,
    required this.selected,
    required this.onSelect,
    required this.searching,
    required this.loading,
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
        Expanded(
          child: ListView.builder(
            itemCount: list.length,
            itemExtent: rowExtent,
            itemBuilder: (context, index) {
              final qso = list[index];
              return _LogQsoSummaryRow(
                qso: qso,
                selected: qso.uuid == selectedUuid,
                // The selected row's own accent border already marks its
                // bottom edge (see [_LogQsoSummaryRow]); a divider under it
                // too would paint over that border, foreground decorations
                // painting child-to-ancestor. The very last row has nothing
                // below it to divide from either way.
                drawDivider: index < list.length - 1 && qso.uuid != selectedUuid,
                compact: compact,
                onTap: () => onSelect(qso.uuid),
              );
            },
          ),
        ),
      ],
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
        _lookups = (result?['lookups'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? const [];
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

/// Bolded-MHz/regular-kHz, dot-separated — the same split [QsoList] paints
/// its own frequency column with, rounded to the kHz (no Hz segment: this
/// list spans many operations at once, so there's no single QSO set to ask
/// "does anything here need sub-kHz precision").
Widget _freqField(double khz, TextStyle? style) {
  final parts = freqDisplayParts(khz, hzDigits: 0);
  return Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.baseline,
    textBaseline: TextBaseline.alphabetic,
    children: [
      Text(parts.mhz, style: style?.copyWith(fontWeight: FontWeight.w700)),
      Text('.', style: style),
      Text(parts.khz, style: style),
    ],
  );
}

/// One fixed-height row in [_QsoListPanel]'s list — summary only, no edit
/// state; selecting a row is [onTap] plus whatever [_QsoListPanel] does with
/// it, and the actual editing happens in [_LogQsoEditPanel] elsewhere on
/// screen. Date, time, freq/band, mode, callsign, name — no RST (signal
/// reports don't earn a column in a cross-operation log) and no other
/// operation-only columns (QSO#, DX flag/state, activity refs, contest
/// exchange). Date is first: unlike a single operation's log, a row here can
/// be from any day.
///
/// [compact] drops the name column and tightens the rest — the same
/// single-pane boundary the view itself falls back to a list-only layout at
/// (see `_LogsViewState._buildScaffold`), where there simply isn't the width
/// for a sixth column, and the numeric ones (date/time/freq — mode and the
/// callsign stay put, both short and already tight) go to a condensed cut of
/// the same mono face rather than a smaller size, which would just make
/// them harder to read at exactly the width where every column already had
/// to fight for room.
class _LogQsoSummaryRow extends StatelessWidget {
  final Qso qso;
  final bool selected;
  final bool drawDivider;
  final bool compact;
  final VoidCallback onTap;

  const _LogQsoSummaryRow({
    required this.qso,
    required this.selected,
    required this.drawDivider,
    required this.compact,
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
    final freqKHz = qso.freq;
    final callsignText = Text(
      qso.theirCall,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.titleMedium?.copyWith(fontFamily: 'RobotoMono', fontWeight: FontWeight.w800, color: textColor),
    );
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
            child: Row(
              children: [
                SizedBox(width: 92, child: Text(date, style: condensedStyle, maxLines: 1, softWrap: false)),
                SizedBox(width: columnGap),
                SizedBox(width: 56, child: Text(time, style: condensedStyle)),
                SizedBox(width: columnGap),
                SizedBox(
                  width: 78,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: freqKHz == null
                        ? Text(qso.band ?? '', style: condensedStyle, textAlign: TextAlign.right)
                        : _freqField(freqKHz, condensedStyle),
                  ),
                ),
                SizedBox(width: columnGap),
                SizedBox(width: 42, child: Text(qso.mode ?? '', style: monoStyle)),
                SizedBox(width: columnGap),
                if (compact)
                  Expanded(child: callsignText)
                else
                  SizedBox(width: 100, child: callsignText),
                if (!compact) ...[
                  const SizedBox(width: Space.lg),
                  Expanded(
                    child: Text(
                      qso.theirName ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
                    ),
                  ),
                ],
              ],
            ),
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
  late final TextEditingController _sentRst;
  late final TextEditingController _rcvdRst;
  late final TextEditingController _notes;
  bool _saving = false;

  /// Set while Delete has been tapped but not yet saved — mirrors
  /// LoggingControls' `_pendingDelete`: staged, fields locked, and the save
  /// button becomes the actual delete until Undo puts it back.
  bool _pendingDelete = false;

  @override
  void initState() {
    super.initState();
    final qso = widget.qso;
    final start = qso.startAtMillis == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(qso.startAtMillis!, isUtc: true);
    _call = TextEditingController(text: qso.theirCall);
    _date = TextEditingController(text: start == null ? '' : _dateFormat.format(start));
    _time = TextEditingController(text: start == null ? '' : _timeFormat.format(start));
    // QSON `freq` is kHz; the field reads/writes MHz, same as ADIF and every
    // other frequency entry point in the app.
    _freqOrBand =
        TextEditingController(text: qso.freq != null ? (qso.freq! / 1000).toStringAsFixed(3) : (qso.band ?? ''));
    _mode = TextEditingController(text: qso.mode ?? '');
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
    final qso = widget.qso;
    setState(() => _saving = true);
    try {
      final their = <String, dynamic>{...?(qso.data['their'] as Map?)?.cast<String, dynamic>()};
      final our = <String, dynamic>{...?(qso.data['our'] as Map?)?.cast<String, dynamic>()};
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
          'mode': _mode.text.trim().toUpperCase(),
          'notes': _notes.text,
          if (startAtMillis != null) 'startAtMillis': startAtMillis,
        },
        scoreCache: qso.scoreCache,
      );
      await widget.services.qsos.update(updated);
    } catch (e, stack) {
      ErrorReportingService.report(e, stack, context: 'logsQsoEdit:save');
      if (mounted) {
        widget.services.statusBar.showNotice(key: 'logsQsoEdit:save', text: context.t.qsoEditForm.saveFailed(error: e));
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
        widget.services.statusBar.showNotice(key: 'logsQsoEdit:delete', text: context.t.qsoEditForm.deleteFailed(error: e));
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
                        slideInFromRight(
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
