// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Logs view's QSO table: its columns, the header that resizes, reorders
// and hides them, and the fixed-extent rows below it.

part of '../logs_view.dart';

/// Every column the QSO table can show, in default header order — the id a
/// [_LogsColumnWidths] entry or a [_LogsViewState._visibleColumns] entry is
/// keyed by, and what the right-click column menu offers. Name defaults to
/// last because the trailing column is the one that stretches (see
/// [_LogsTableWidth]), and a stretched Name reads better than a stretched
/// anything else.
const _allLogsColumns = ['date', 'time', 'station', 'freq', 'band', 'mode', 'sent', 'rcvd', 'call', 'grid', 'state', 'country', 'refs', 'name'];

/// All a compact row has room for, whatever else is switched on: the columns
/// a QSO can be told apart by. With no header at that width there is no way
/// to scroll sideways to anything more, so an extra column would overflow.
const _compactLogsColumns = {'date', 'time', 'freq', 'mode', 'call'};

/// What a table nobody has configured shows. The rest wait in the column
/// menu: this is a cross-operation log, where most of what a single
/// operation's list earns a column for is noise until someone asks for it.
const _defaultVisibleLogsColumns = {'date', 'time', 'freq', 'mode', 'call', 'name'};

/// [_allLogsColumns]' header labels — one table, read by the header and the
/// column menu alike, so the two cannot name a column differently.
String _logsColumnLabel(BuildContext context, String id) {
  final t = context.t.home.logs.columns;
  return switch (id) {
    'date' => t.date,
    'time' => t.time,
    'station' => t.station,
    'freq' => t.freq,
    'band' => t.band,
    'mode' => t.mode,
    'sent' => t.sent,
    'rcvd' => t.rcvd,
    'call' => t.call,
    'grid' => t.grid,
    'state' => t.state,
    'country' => t.country,
    'refs' => t.refs,
    'name' => t.name,
    _ => id,
  };
}

/// User-resizable widths for the QSO table's columns (see
/// [_LogQsoSummaryRow]) — every column carries a real width, Name's
/// included, because any of them can end up as the table's trailing column
/// (see [_LogsTableWidth]), and only the trailing one gets to skip having a
/// fixed width of its own. Persisted under [LayoutKeys.logsQsoColumnWidths],
/// one JSON map like every other layout dimension
/// (`SettingsService.layoutData`).
class _LogsColumnWidths {
  static const _min = 32.0;

  static const _defaults = {
    'date': 92.0,
    'time': 56.0,
    'station': 100.0,
    'freq': 78.0,
    'band': 48.0,
    'mode': 42.0,
    'sent': 40.0,
    'rcvd': 40.0,
    'call': 100.0,
    'grid': 64.0,
    'state': 48.0,
    'country': 64.0,
    'refs': 110.0,
    'name': 150.0,
  };

  final Map<String, double> _widths;

  const _LogsColumnWidths() : _widths = _defaults;

  const _LogsColumnWidths._(this._widths);

  double widthOf(String id) => _widths[id] ?? _defaults[id] ?? 0;

  /// A stored width that isn't a number takes the default rather than
  /// throwing: a view that fails in `initState` takes its own column menu —
  /// the only way to reset it — down with it.
  factory _LogsColumnWidths.fromMap(Map<String, dynamic>? map) => _LogsColumnWidths._({
    for (final id in _allLogsColumns)
      id: switch (map?[id]) {
        final num width => math.max(_min, width.toDouble()),
        _ => _defaults[id]!,
      },
  });

  Map<String, dynamic> toMap() => {..._widths};

  _LogsColumnWidths _copyWith(String column, double value) => _defaults.containsKey(column) ? _LogsColumnWidths._({..._widths, column: value}) : this;

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

/// How long the editor takes to open above the list — and so how long a
/// keyboard-selected row can be pushed around by it (see
/// `_LogsViewState._moveSelection`).
const _logsEditorRevealDuration = Duration(milliseconds: 400);

/// The QSO table's sort — which column, and which way. Persisted under
/// [LayoutKeys.logsQsoSort]; newest first until the operator clicks a header.
class _LogsSort {
  final String column;
  final bool ascending;

  const _LogsSort({this.column = 'date', this.ascending = false});

  factory _LogsSort.fromMap(Map<String, dynamic>? map) {
    final column = map?['column'];
    if (column is! String || !_allLogsColumns.contains(column)) return const _LogsSort();
    return _LogsSort(column: column, ascending: map?['ascending'] == true);
  }

  Map<String, dynamic> toMap() => {'column': column, 'ascending': ascending};

  /// Date and Time are one clock, so both sort by it — and both draw the
  /// day dividers (see [_LogsTableRows]).
  bool get chronological => _isChronological(column);

  static bool _isChronological(String id) => id == 'date' || id == 'time';

  /// A click on the sorted column flips it, and so does one on its
  /// chronological twin — otherwise clicking Time under a Date sort would
  /// move the arrow and change nothing. Any other column starts ascending,
  /// except the clock, which starts newest first like the table itself.
  _LogsSort tapped(String id) {
    if (id == column || (chronological && _isChronological(id))) return _LogsSort(column: id, ascending: !ascending);
    return _LogsSort(column: id, ascending: !_isChronological(id));
  }
}

/// Where each band sits in frequency order, for the Band column's sort.
final _bandOrder = {for (final (index, band) in bands.indexed) band.name: index};

/// The value [column] sorts [qso] by — null for a QSO with nothing there,
/// which sorts last whichever way the column runs. Date and Time never get
/// here: [_sortedQsos] takes the query's own order for them.
Comparable<Object>? _sortKeyOf(String column, Qso qso) {
  String? text(String? value) => (value == null || value.isEmpty) ? null : value.toLowerCase();
  return switch (column) {
        // The whole timestamp for both: by the date alone a day's contacts would
        // fall in no order, and by the time of day alone the days would
        // interleave.
        'date' || 'time' => qso.startAtMillis,
        'station' => text(qso.ourCall),
        // A QSO with no frequency shows its band there, so it sorts at its band.
        'freq' => qso.freq ?? bands.where((band) => band.name == qso.band).firstOrNull?.minKHz,
        'band' => _bandOrder[qso.band],
        'mode' => text(displayMode(qso.mode, freqKHz: qso.freq, band: qso.band)),
        'sent' => text(qso.sentRST),
        'rcvd' => text(qso.receivedRST),
        'call' => text(qso.theirCall),
        'grid' => text(qso.theirGrid),
        'state' => text(qso.theirState),
        'country' => text(qso.theirEntityPrefix),
        'refs' => text(_refsText(qso)),
        'name' => text(qso.theirName),
        _ => null,
      }
      as Comparable<Object>?;
}

/// [qsos] in [sort]'s order — a new list wherever the order changes, since
/// the stream's own list is unmodifiable. Ties fall back to newest first, then
/// to the uuid, so rows that compare equal keep their places between rebuilds.
///
/// By the clock there is nothing to sort: `QsosRepository.watchForOurCalls`
/// already returns the log oldest first, so newest first is that list
/// reversed. Sorting it anyway costs every change to a log of tens of
/// thousands of QSOs a full sort in the order the table opens in. The query's
/// order stands for the ties too — contacts in the same second keep the order
/// the database returns them in, flipped for newest first — and a QSO with no
/// start time, which the repository never writes, sits with the oldest.
List<Qso> _sortedQsos(List<Qso> qsos, _LogsSort sort) {
  if (sort.chronological) return sort.ascending ? qsos : qsos.reversed.toList();
  final keyed = [for (final qso in qsos) (qso: qso, key: _sortKeyOf(sort.column, qso))];
  int byClock(Qso a, Qso b) {
    final clock = (b.startAtMillis ?? 0).compareTo(a.startAtMillis ?? 0);
    return clock != 0 ? clock : a.uuid.compareTo(b.uuid);
  }

  keyed.sort((a, b) {
    final (keyA, keyB) = (a.key, b.key);
    if (keyA == null || keyB == null) {
      if (keyA != keyB) return keyA == null ? 1 : -1;
      return byClock(a.qso, b.qso);
    }
    final compared = sort.ascending ? keyA.compareTo(keyB) : keyB.compareTo(keyA);
    return compared != 0 ? compared : byClock(a.qso, b.qso);
  });
  return [for (final entry in keyed) entry.qso];
}

/// A day's divider among the table's rows.
class _LogsDayDivider {
  final int dayMillis;
  final int count;

  const _LogsDayDivider(this.dayMillis, this.count);
}

/// One UTC day in milliseconds — the same boundary [DayHeaderRow] labels.
const _logsDayMillis = 1000 * 60 * 60 * 24;

/// What the table draws, in order: the searched, sorted QSOs, and — while the
/// sort is chronological — a [_LogsDayDivider] ahead of each UTC day. A
/// divider is one row tall like everything else in the list (see
/// [_QsoListPanel]), so any item's scroll offset is still its index times
/// the row height, which is what lets the keyboard bring a row into view
/// without measuring anything.
class _LogsTableRows {
  /// Only QSOs — what ↑/↓ step through.
  final List<Qso> qsos;

  /// Each element a [Qso] or a [_LogsDayDivider].
  final List<Object> items;

  final Map<String, int> _qsoIndex;
  final Map<String, int> _itemIndex;

  _LogsTableRows._(this.qsos, this.items, this._qsoIndex, this._itemIndex);

  factory _LogsTableRows(List<Qso> sorted, {required bool dayDividers}) {
    final items = <Object>[];
    final qsoIndex = <String, int>{};
    final itemIndex = <String, int>{};
    int? dayOf(Qso qso) => qso.startAtMillis == null ? null : qso.startAtMillis! - qso.startAtMillis! % _logsDayMillis;
    for (var i = 0; i < sorted.length; i++) {
      final qso = sorted[i];
      final day = dayOf(qso);
      // Chronological order keeps each day's QSOs together, so the count is
      // the run of them from here.
      if (dayDividers && day != null && (i == 0 || dayOf(sorted[i - 1]) != day)) {
        var count = 1;
        while (i + count < sorted.length && dayOf(sorted[i + count]) == day) {
          count++;
        }
        items.add(_LogsDayDivider(day, count));
      }
      qsoIndex[qso.uuid] = i;
      itemIndex[qso.uuid] = items.length;
      items.add(qso);
    }
    return _LogsTableRows._(sorted, items, qsoIndex, itemIndex);
  }

  int? qsoIndexOf(String uuid) => _qsoIndex[uuid];

  int? itemIndexOf(String uuid) => _itemIndex[uuid];
}

/// The middle pane: every QSO the filter and search match, in [sort]'s order
/// — the callsign picker, count/date-span and search field live in the view's
/// own AppBar (see `_LogsViewState._buildTitle`), so the only header this pane
/// draws is [_QsoListHeaderRow], labeling, sorting and resizing the
/// fixed-width columns below it. It sits BELOW the edit panel that's pinned
/// above the list while a QSO is selected — the labels belong to the list,
/// not to whatever's currently being edited — and, like the list, stays fully
/// visible regardless of where the list itself happens to be scrolled
/// VERTICALLY, the same way a page's header stays put while its body scrolls
/// underneath. HORIZONTALLY the two move together instead: widening the
/// fixed-width columns can push the table past the pane's own width, so
/// header and rows share ONE [SingleChildScrollView] (see [_LogsTableWidth]
/// and this class's own `build`) rather than each carrying its own
/// independent, and therefore driftable, horizontal offset.
///
/// The list itself is FIXED-extent ([LayoutMetrics.qsoRowHeight], the same
/// row height [QsoList] declares, and the height [DayHeaderRow] is built to)
/// so a scrollbar drag resolves to a target offset in O(1) —
/// [RenderSliverFixedExtentList] computes it as `itemExtent * index` instead
/// of walking every off-screen row to find out how tall it painted. A real
/// log can run into the tens of thousands of QSOs — exactly the size that
/// walk turns into a multi-second stall on every scrollbar drag. That fixed
/// extent is what forces the edit form out of the row and into
/// [_LogQsoEditPanel] — a row whose own height changed on selection would be
/// right back to a variable extent.
class _QsoListPanel extends StatelessWidget {
  final HaLoServices services;

  /// What the empty state names — a callsign, or "all callsigns". Null when
  /// nothing has been picked, which only happens with nothing logged at all.
  final String? callLabel;

  /// Already searched and sorted — null before a callsign has ever been
  /// picked.
  final _LogsTableRows? rows;
  final String? selectedUuid;

  /// The same lookup [_LogsInfoPanel] and [_LogsMapPanel] get — found in the
  /// UNFILTERED list, so a search that hides the selected row doesn't lose
  /// the edit panel out from under the operator.
  final Qso? selected;

  /// Keyed per selection by `_LogsViewState`, which reaches the editor
  /// through it to ask whether leaving would lose an edit.
  final GlobalKey<_LogQsoEditPanelState> editorKey;
  final ValueChanged<String> onTapRow;
  final VoidCallback onEditorDone;
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
  final void Function(String dragged, String? before) onReorderColumn;

  final _LogsSort sort;
  final ValueChanged<String> onSort;

  /// See [_maxFreqMhzDigits] — computed once by `_LogsViewState` over [rows],
  /// not per row.
  final int freqMhzDigits;

  /// Owned by `_LogsViewState`, which scrolls a keyboard-selected row into
  /// view and handles the keys the rows' [listFocusNode] receives.
  final ScrollController scrollController;
  final FocusNode listFocusNode;
  final FocusOnKeyEventCallback onListKey;

  const _QsoListPanel({
    required this.services,
    required this.callLabel,
    required this.rows,
    required this.selectedUuid,
    required this.selected,
    required this.editorKey,
    required this.onTapRow,
    required this.onEditorDone,
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
    required this.sort,
    required this.onSort,
    required this.freqMhzDigits,
    required this.scrollController,
    required this.listFocusNode,
    required this.onListKey,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    // `_LogsViewState` opens on a callsign (or All) the moment the list is
    // non-empty, so reaching here with nothing picked AND the list already
    // loaded only happens when nothing has been logged at all.
    final label = callLabel;
    if (label == null) return Center(child: Text(context.t.home.logs.emptyCallsigns));
    final tableRows = rows;
    if (tableRows == null) return const Center(child: CircularProgressIndicator());
    // In the table's place, not the pane's: a search that matches nothing
    // hides the selected row too, and the editor above has to outlive it —
    // replaced with the pane, it would take an edit in progress with it.
    final empty = tableRows.qsos.isEmpty
        ? Center(child: Text(searching ? context.t.home.logs.noSearchMatches : context.t.home.logs.emptyQsos(call: label)))
        : null;
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
              // Keyed per selection so switching it remounts fresh
              // controllers rather than reusing the previous QSO's — no
              // live update arriving mid-edit can overwrite what the
              // operator is typing (see [_LogQsoEditPanel]'s own doc
              // comment).
              : _LogQsoEditPanel(key: editorKey, services: services, qso: selected!, onDone: onEditorDone),
          secondChild: const SizedBox(width: double.infinity),
          crossFadeState: selected == null ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: _logsEditorRevealDuration,
          sizeCurve: Curves.easeInOut,
        ),
        // Below the edit panel, not above it — column labels belong to the
        // list they sit on top of, not to whatever's currently being edited.
        // The focus the keys arrive on wraps the rows alone: around the
        // editor too, it would take ↑/↓ from the text fields.
        Expanded(
          child:
              empty ??
              Focus(
                focusNode: listFocusNode,
                onKeyEvent: onListKey,
                child: compact
                    // No header, no horizontal scroll, no Name column at this
                    // width — the same boundary the view itself falls back to a
                    // list-only layout at (see `_LogsViewState._buildScaffold`).
                    ? _buildRows(context, tableRows, rowExtent, compact: true, tableWidth: _compactTableWidth)
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
                                    sort: sort,
                                    onSort: onSort,
                                    onResize: onResizeColumn,
                                    onResizeEnd: onResizeColumnEnd,
                                    onAutoFit: (column) => onAutoFitColumn(
                                      column,
                                      _autoFitColumnWidth(column, context, tableRows.qsos, freqMhzDigits, sorted: column == sort.column),
                                    ),
                                    onShowMenu: onShowColumnMenu,
                                    onReorder: onReorderColumn,
                                  ),
                                  Expanded(child: _buildRows(context, tableRows, rowExtent, compact: false, tableWidth: tableWidth)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
        ),
      ],
    );
  }

  /// Compact never shows Name or a header (see the branch above), so nothing
  /// in [_LogQsoSummaryRow] ever reads this — a placeholder rather than a
  /// nullable `tableWidth` param everywhere else has to null-check.
  static const _compactTableWidth = _LogsTableWidth(content: 0, flexWidth: 0, flexId: null);

  Widget _buildRows(BuildContext context, _LogsTableRows tableRows, double rowExtent, {required bool compact, required _LogsTableWidth tableWidth}) {
    final items = tableRows.items;
    return ListView.builder(
      controller: scrollController,
      itemCount: items.length,
      itemExtent: rowExtent,
      itemBuilder: (context, index) => switch (items[index]) {
        final _LogsDayDivider divider => DayHeaderRow(dayMillis: divider.dayMillis, count: divider.count),
        final Qso qso => _LogQsoSummaryRow(
          qso: qso,
          selected: qso.uuid == selectedUuid,
          // The selected row's own accent border already marks its bottom
          // edge (see [_LogQsoSummaryRow]); a divider under it too would
          // paint over that border, foreground decorations painting
          // child-to-ancestor. Nor does a row ahead of a day header need one:
          // the header's own background is the break. The very last row has
          // nothing below it to divide from either way.
          drawDivider: index < items.length - 1 && qso.uuid != selectedUuid && items[index + 1] is Qso,
          compact: compact,
          widths: columnWidths,
          visibleColumns: visibleColumns,
          columnOrder: columnOrder,
          freqMhzDigits: freqMhzDigits,
          tableWidth: tableWidth,
          onTap: () => onTapRow(qso.uuid),
        ),
        _ => const SizedBox.shrink(),
      },
    );
  }
}

/// Labels [_QsoListPanel]'s columns and carries the drag handles that resize
/// them. Every label — Name's included — also drags, to reorder: a column
/// dropped over another's left half lands before it, over its right half
/// after it, and a bold line in the gap says which while the drag is over the
/// header (see `_LogsViewState._moveColumn`). A tap on a label sorts by it.
/// Shown only alongside the two-pane,
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
class _QsoListHeaderRow extends StatefulWidget {
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

  /// A column was dropped just before [before], or after the last visible
  /// column when that is null — see `_LogsViewState._moveColumn`.
  final void Function(String dragged, String? before) onReorder;

  /// The sorted column carries an arrow; a click on any label re-sorts (see
  /// [_LogsSort.tapped]).
  final _LogsSort sort;
  final ValueChanged<String> onSort;

  const _QsoListHeaderRow({
    required this.widths,
    required this.visibleColumns,
    required this.sort,
    required this.onSort,
    required this.onResize,
    required this.onResizeEnd,
    required this.onAutoFit,
    required this.onShowMenu,
    required this.tableWidth,
    required this.columnOrder,
    required this.onReorder,
  });

  @override
  State<_QsoListHeaderRow> createState() => _QsoListHeaderRowState();
}

/// What a dragged column header carries. A type of its own, not the column's
/// id as a bare `String`: the dock's tab strips accept any `String` as a pane
/// to add, so a header let go over one would plant an empty pane named after
/// the column, and the layout would keep it.
class _LogsColumnDrag {
  final String id;

  const _LogsColumnDrag(this.id);
}

/// How thick the line marking where a dragged column would land is — bolder
/// than the resize handle's, which shares its gap.
const double _logsDropLineWidth = 3;

class _QsoListHeaderRowState extends State<_QsoListHeaderRow> {
  /// The labels' row, which pointer positions are converted into.
  final _rowKey = GlobalKey();

  /// Where the dragged column would land, as a gap between the visible
  /// columns: 0 before the first, their count after the last. Null with no
  /// drag in flight, and where the drop would leave the column where it is.
  int? _dropGap;

  List<String> get _visible => [
    for (final id in widget.columnOrder)
      if (widget.visibleColumns.contains(id)) id,
  ];

  double _widthOf(String id) => id == widget.tableWidth.flexId ? widget.tableWidth.flexWidth : widget.widths.widthOf(id);

  /// Follows the pointer, not the dragged copy of the label: grabbed near
  /// one end of a wide column, the copy's middle is far from where the
  /// operator is pointing.
  void _dragMoved(String dragged, Offset globalPosition) {
    final box = _rowKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final x = box.globalToLocal(globalPosition).dx;
    final visible = _visible;
    // Left of a column's middle is the gap before it; right of the last
    // middle, the gap after the last column.
    var gap = visible.length;
    var start = 0.0;
    for (final (index, id) in visible.indexed) {
      final width = _widthOf(id);
      if (x < start + width / 2) {
        gap = index;
        break;
      }
      start += width + Space.lg;
    }
    // The gaps either side of the dragged column are where it already is.
    final from = visible.indexOf(dragged);
    final landing = (gap == from || gap == from + 1) ? null : gap;
    if (landing != _dropGap) setState(() => _dropGap = landing);
  }

  void _dragEnded() {
    if (_dropGap != null) setState(() => _dropGap = null);
  }

  void _drop(String dragged) {
    final gap = _dropGap;
    _dragEnded();
    if (gap == null) return;
    final visible = _visible;
    widget.onReorder(dragged, gap < visible.length ? visible[gap] : null);
  }

  /// The middle of [gap] in the labels' row: the column gap between two
  /// columns, and half of one outside the first and the last, where the
  /// row's own padding is.
  double _gapCenter(int gap) {
    final visible = _visible;
    var x = -Space.lg / 2;
    for (final id in visible.take(gap)) {
      x += _widthOf(id) + Space.lg;
    }
    return x;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700);
    final sort = widget.sort;

    // The arrow is a sibling of the text rather than a glyph inside it, so an
    // ellipsis takes the label and never the direction.
    Widget label(String id) => Row(
      children: [
        Flexible(
          child: Text(_logsColumnLabel(context, id), style: labelStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        if (id == sort.column) Icon(sort.ascending ? MdiIcons.arrowUp : MdiIcons.arrowDown, size: _logsSortArrowSize, color: labelStyle?.color),
      ],
    );

    Widget handle(String column, {bool asOverlay = false}) => _ColumnResizeHandle(
      width: Space.lg,
      asOverlay: asOverlay,
      onDragUpdate: (delta) => widget.onResize(column, delta),
      onDragEnd: widget.onResizeEnd,
      onDoubleTap: () => widget.onAutoFit(column),
    );

    // What the pointer carries is the header cell itself: the same gray,
    // label and bottom rule, as wide as the column plus half the gap either
    // side, so the operator sees which column they are moving and how much
    // room it will take.
    Widget lifted(String id, double width) => Material(
      elevation: 6,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Container(
        width: width + Space.lg,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: Space.xs),
        foregroundDecoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: theme.colorScheme.outline, width: 3)),
        ),
        child: SizedBox(width: width, child: label(id)),
      ),
    );

    Widget draggableColumn(String id, double width) {
      final box = SizedBox(width: width, child: label(id));
      return Draggable<_LogsColumnDrag>(
        data: _LogsColumnDrag(id),
        // Level with where the label was grabbed, but hung just under the
        // header rather than over it: laid on the header, the copy would
        // cover the very gap whose line says where it will land.
        dragAnchorStrategy: (draggable, context, position) {
          final grabbed = childDragAnchorStrategy(draggable, context, position);
          final labelHeight = (context.findRenderObject() as RenderBox?)?.size.height ?? 0;
          return Offset(grabbed.dx + Space.lg / 2, grabbed.dy - labelHeight - Space.xs);
        },
        feedback: lifted(id, width),
        onDragUpdate: (details) => _dragMoved(id, details.globalPosition),
        onDragEnd: (_) => _dragEnded(),
        childWhenDragging: Opacity(opacity: 0.35, child: box),
        // A tap sorts; the Draggable only claims the pointer once it moves
        // past the drag slop, so the two never compete for one gesture.
        child: GestureDetector(
          onTap: () => widget.onSort(id),
          child: MouseRegion(cursor: SystemMouseCursors.grab, child: box),
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
    for (final id in _visible) {
      if (id == widget.tableWidth.flexId) {
        children.add(draggableColumn(id, widget.tableWidth.flexWidth));
        offset += widget.tableWidth.flexWidth;
      } else {
        children.add(draggableColumn(id, widget.widths.widthOf(id)));
        offset += widget.widths.widthOf(id);
        // Where a strip is overlaid, the strip IS the handle — it paints the
        // line as well as owning the gesture, so hover and drag feedback stay
        // in the one widget that sees the pointer. The row keeps the gap the
        // line sits in and nothing else.
        children.add(touchSlop > 0 ? const SizedBox(width: Space.lg) : handle(id));
        if (touchSlop > 0) {
          strips.add(Positioned(left: offset - touchSlop, top: 0, bottom: 0, width: Space.lg + touchSlop * 2, child: handle(id, asOverlay: true)));
        }
        offset += Space.lg;
      }
    }

    // One target for the whole row: the gap under the pointer is the drop
    // point, so there is nothing a per-column target would add.
    return DragTarget<_LogsColumnDrag>(
      onWillAcceptWithDetails: (details) => widget.visibleColumns.contains(details.data.id),
      onAcceptWithDetails: (details) => _drop(details.data.id),
      builder: (context, candidates, _) {
        // Only while the drag is over the header: released anywhere else it
        // lands nowhere, and a line promising otherwise would be a lie.
        final gap = candidates.isEmpty ? null : _dropGap;
        return GestureDetector(
          onSecondaryTapUp: (details) => widget.onShowMenu(details.globalPosition),
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
              // it gets without the Stack — the strips and the drop line are
              // placed from column widths this row was already built from. The
              // line runs the header's full height and can sit in the row's
              // side padding, so it is allowed past the Stack's edges.
              child: Stack(
                fit: StackFit.passthrough,
                clipBehavior: Clip.none,
                children: [
                  Row(key: _rowKey, children: children),
                  ...strips,
                  if (gap != null)
                    Positioned(
                      key: const ValueKey('logsColumnDropLine'),
                      left: _gapCenter(gap) - _logsDropLineWidth / 2,
                      top: -Space.xs,
                      bottom: -Space.xs,
                      width: _logsDropLineWidth,
                      // `secondary`, not the resize handle's `primary`: that
                      // is one tone in both themes, and in dark it all but
                      // vanishes into this gray.
                      child: IgnorePointer(child: ColoredBox(color: theme.colorScheme.secondary)),
                    ),
                ],
              ),
            ),
          ),
        );
      },
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

  const _ColumnResizeHandle({required this.width, required this.onDragUpdate, required this.onDragEnd, required this.onDoubleTap, this.asOverlay = false});

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

  static double _dragSlop(PointerDeviceKind kind) => kind == PointerDeviceKind.touch ? kTouchSlop : kPrecisePointerPanSlop;

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
        builder: (context) => const Positioned.fill(
          child: IgnorePointer(child: ColoredBox(color: Colors.transparent)),
        ),
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

final _dateFormat = DateFormat('yyyy-MM-dd');
final _timeFormat = DateFormat('HH:mm');

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

/// What the notes marker adds to a Name cell, gap included — what
/// [_autoFitColumnWidth] reserves for it.
const double _notesMarkerExtent = Space.xs + qsoNotesMarkerSize;

/// The sorted column's arrow in [_QsoListHeaderRow] — what
/// [_autoFitColumnWidth] reserves beside that column's label.
const double _logsSortArrowSize = 14;

/// The Country cell's flag, at the row's text size rather than the flag
/// glyph's own default, which would stand taller than the row's text.
const double _logsFlagSize = 14;

/// Their references, as the Refs cell shows them.
String _refsText(Qso qso) => [
  for (final ref in qso.refs)
    if (asQsonString(ref['ref']) case final text? when text.isNotEmpty) text,
].join(', ');

/// Their grid as the Grid cell shows it — through [gridForDisplay], so a
/// coordinate from a lookup reads at the operator's Grid Precision rather
/// than as whatever length the lookup's derived square happened to be
/// (docs/design/locations.md).
String _theirGridText(Qso qso) {
  final location = qso.theirExactLocation;
  return gridForDisplay(lat: location?.latitude, lon: location?.longitude, grid: qso.theirGrid) ?? '';
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
double _autoFitColumnWidth(String column, BuildContext context, List<Qso> qsos, int freqMhzDigits, {required bool sorted}) {
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

  final (dataText, dataStyle) = switch (column) {
    'date' => ('0000-00-00', monoStyle),
    'time' => ('00:00z', monoStyle),
    'station' => (widest(qsos.map((qso) => qso.ourCall)), monoStyle),
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
    ),
    'band' => (widest(qsos.map((qso) => qso.band ?? '')), monoStyle),
    // The DISPLAYED mode, like the cell below — measuring a stored `LSB` for
    // a cell that renders `SSB` reserves a width no row uses.
    'mode' => (widest(qsos.map((qso) => displayMode(qso.mode, freqKHz: qso.freq, band: qso.band) ?? '')), monoStyle),
    'sent' => (widest(qsos.map((qso) => qso.sentRST ?? '')), monoStyle),
    'rcvd' => (widest(qsos.map((qso) => qso.receivedRST ?? '')), monoStyle),
    'call' => (widest(qsos.map((qso) => qso.theirCall)), callStyle),
    'grid' => (widest(qsos.map(_theirGridText)), monoStyle),
    'state' => (widest(qsos.map((qso) => qso.theirState ?? '')), monoStyle),
    'country' => (widest(qsos.map((qso) => qso.theirEntityPrefix ?? '')), monoStyle),
    'refs' => (widest(qsos.map(_refsText)), monoStyle),
    'name' => (widest(qsos.map((qso) => qso.theirName ?? '')), nameStyle),
    _ => ('', monoStyle),
  };
  // Beside-the-text glyphs count as the cell's: the notes marker in Name, a
  // flag in Country. This measures the column, not the string.
  final glyphExtent = switch (column) {
    'name' when qsos.any((qso) => qso.hasNotes) => _notesMarkerExtent,
    'country' => switch (qsos.map((qso) => qso.theirFlag).firstWhere((flag) => flag != null && flag.isNotEmpty, orElse: () => null)) {
      final flag? => textWidth(context, flag, emojiStyle(fontSize: _logsFlagSize)) + Space.xs,
      null => 0.0,
    },
    _ => 0.0,
  };
  final width = math.max(
    textWidth(context, dataText, dataStyle ?? const TextStyle()) + glyphExtent,
    textWidth(context, _logsColumnLabel(context, column), labelStyle ?? const TextStyle()) + (sorted ? _logsSortArrowSize : 0),
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
/// screen. Whichever of [_allLogsColumns] [visibleColumns] keeps — the ones
/// beyond [_defaultVisibleLogsColumns] only when the operator asks for them,
/// and nothing that only means something inside one operation (QSO#,
/// contest exchange). Date is first: unlike a single operation's log, a row
/// here can be from any day.
///
/// [compact] keeps only [_compactLogsColumns] regardless of [visibleColumns]
/// and tightens them — the same single-pane boundary the view itself falls
/// back to a list-only layout at (see `_LogsViewState._buildScaffold`),
/// where there simply isn't the width for more, and the numeric ones
/// (date/time/freq — mode and the callsign stay put, both short and already
/// tight) go to a condensed cut of the same mono face rather than a smaller
/// size, which would just make them harder to read at exactly the width
/// where every column already had to fight for room.
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
    final start = qso.startAtMillis == null ? null : DateTime.fromMillisecondsSinceEpoch(qso.startAtMillis!, isUtc: true);
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
    Widget plain(String? value, TextStyle? style) => Text(value ?? '', style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
    final flag = qso.theirFlag;
    // Built per visible column, on demand: a row is rebuilt every scroll
    // frame, and most columns — the grid decode and the refs join among them
    // — are hidden by default.
    Widget cellContent(String id) => switch (id) {
      'date' => Text(date, style: condensedStyle, maxLines: 1, softWrap: false),
      'time' => Text(time, style: condensedStyle),
      'station' => plain(qso.ourCall, monoStyle),
      'freq' => freqKHz == null ? Text(qso.band ?? '', style: condensedStyle) : _freqField(freqKHz, condensedStyle, mhzDigits: freqMhzDigits),
      'band' => plain(qso.band, monoStyle),
      // `SSB` for the sideband the band runs; the one it doesn't is spelled
      // out, in the error color, because that is the whole reason to spell it.
      'mode' => Text(
        displayMode(qso.mode, freqKHz: freqKHz, band: qso.band) ?? '',
        style: isUnexpectedSideband(qso.mode, freqKHz: freqKHz, band: qso.band) ? monoStyle?.copyWith(color: theme.colorScheme.error) : monoStyle,
      ),
      'sent' => plain(qso.sentRST, monoStyle),
      'rcvd' => plain(qso.receivedRST, monoStyle),
      'call' => callsignText,
      'grid' => plain(_theirGridText(qso), monoStyle),
      'state' => plain(qso.theirState, monoStyle),
      'country' => Row(
        children: [
          if (flag != null && flag.isNotEmpty) ...[flagGlyph(flag, fontSize: _logsFlagSize), const SizedBox(width: Space.xs)],
          Flexible(child: plain(qso.theirEntityPrefix, monoStyle)),
        ],
      ),
      'refs' => plain(_refsText(qso), monoStyle),
      // The notes marker rides in the Name cell, this row having no badge
      // column: where Name goes — [compact], or hidden in the column menu —
      // the marker goes with it, deliberately. A sibling of the text rather
      // than a span inside it, which would go with the ellipsis.
      'name' => Row(
        children: [
          Flexible(
            child: Text(
              qso.theirName ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
            ),
          ),
          if (qsoNotesMarker(qso, color: textColor ?? theme.textTheme.bodyMedium?.color) case final marker?) ...[
            if ((qso.theirName ?? '').isNotEmpty) const SizedBox(width: Space.xs),
            marker,
          ],
        ],
      ),
      _ => const SizedBox.shrink(),
    };
    final rowChildren = <Widget>[];
    if (compact) {
      // The trailing visible column (usually Call, but hiding or reordering
      // can put another one there) is the one that gets `Expanded` — a
      // hardcoded `id == 'call'` check left dead space on the right if Call
      // itself was ever hidden, since nothing else would step up to fill it.
      final compactVisible = [
        for (final id in columnOrder)
          if (_compactLogsColumns.contains(id) && visibleColumns.contains(id)) id,
      ];
      final compactFlexId = compactVisible.isEmpty ? null : compactVisible.last;
      // Gap only BETWEEN what's left after hiding — there's no header here
      // to stay pixel-aligned with, and the trailing column already soaks up
      // whatever's left via `Expanded`, so a gap after it would just be dead
      // space before nothing. Anything outside [_compactLogsColumns] is
      // skipped outright, regardless of [visibleColumns] or where reordering
      // put it — see the class doc.
      for (final id in compactVisible) {
        if (rowChildren.isNotEmpty) rowChildren.add(SizedBox(width: columnGap));
        rowChildren.add(id == compactFlexId ? Expanded(child: cellContent(id)) : SizedBox(width: columnWidths.widthOf(id), child: cellContent(id)));
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
        rowChildren.add(SizedBox(width: isFlex ? tableWidth.flexWidth : columnWidths.widthOf(id), child: cellContent(id)));
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
            : (drawDivider ? Border(bottom: BorderSide(width: 1, color: DividerTheme.of(context).color ?? theme.dividerColor)) : null),
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
