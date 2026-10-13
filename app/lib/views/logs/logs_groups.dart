// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Logs view's grouping: what the QSO table's rows are grouped under, the
// rows it draws with their headers, and the header row itself.

part of '../logs_view.dart';

/// What the QSO table's rows are grouped under — a header per level, each
/// with its QSO count, collapsible, and pinned while its rows scroll by.
/// The path a QSO with no usable start time groups under, at every level.
const _undated = '!';

enum LogsGrouping {
  /// One flat list in the sort's order, with no headers at all.
  none,

  /// Year, month and UTC day.
  date,

  /// Continent and DXCC entity.
  dx;

  /// Whether a group nobody has opened or closed yet starts closed: DX's
  /// continents and entities are many, and read best as an index to open
  /// from.
  bool get startsCollapsed => this == LogsGrouping.dx;

  int get levels => switch (this) {
    LogsGrouping.none => 0,
    LogsGrouping.date => 3,
    LogsGrouping.dx => 2,
  };

  String label(BuildContext context) => switch (this) {
    LogsGrouping.none => context.t.home.logs.groupBy.none,
    LogsGrouping.date => context.t.home.logs.groupBy.date,
    LogsGrouping.dx => context.t.home.logs.groupBy.dx,
  };

  /// [qso]'s group at each level, outermost first. Each is a path that
  /// carries its parents' (`2026-10` under `2026`), so it alone tells two
  /// groups apart, and the innermost one alone orders the QSOs into their
  /// groups.
  List<String> pathOf(Qso qso) {
    switch (this) {
      case LogsGrouping.none:
        return const [];
      case LogsGrouping.date:
        final at = qso.startAtMillis;
        final d = at == null ? null : DateTime.fromMillisecondsSinceEpoch(at, isUtc: true);
        // `!` sorts before every digit, so the undated group sits at the
        // oldest end. A year before 1 has no four-digit path to give.
        if (d == null || d.year < 1) return const [_undated, '$_undated-', '$_undated--'];
        final year = d.year.toString().padLeft(4, '0');
        final month = '$year-${d.month.toString().padLeft(2, '0')}';
        return [year, month, '$month-${d.day.toString().padLeft(2, '0')}'];
      case LogsGrouping.dx:
        // `~` sorts after every letter: the unknowns go last. Empty is
        // unknown too — an empty continent's path would be `''`, the key the
        // outermost groups hang under in [_LogsGrouped.children].
        String known(String? value) => value == null || value.isEmpty ? '~' : value;
        final continent = known(qso.theirContinent?.toUpperCase());
        return [continent, '$continent/${known(qso.theirEntityName?.toLowerCase())}'];
    }
  }
}

/// A group's header among the table's rows — one row tall like everything
/// else in the list (see [_LogsTableRows]).
class _LogsGroupHeader {
  final LogsGrouping grouping;

  /// 0 for the outermost.
  final int level;

  /// See [LogsGrouping.pathOf]; what [_LogsViewState]'s toggled sets hold.
  final String path;

  /// The first QSO in the group, for what the path alone doesn't keep: an
  /// entity's name as written, and its flag.
  final Qso first;
  final int count;
  final bool collapsed;

  const _LogsGroupHeader({required this.grouping, required this.level, required this.path, required this.first, required this.count, required this.collapsed});

  String label(BuildContext context) {
    final t = context.t;
    if (grouping == LogsGrouping.date) {
      if (path.startsWith(_undated)) return t.home.logs.groupBy.unknownDate;
      if (level == 0) return path;
      final locale = Localizations.localeOf(context).toLanguageTag();
      final parts = path.split('-').map(int.parse).toList();
      final day = DateTime.utc(parts[0], parts[1], level == 2 ? parts[2] : 1);
      return level == 1 ? DateFormat.LLLL(locale).format(day) : DateFormat.MMMEd(locale).format(day);
    }
    if (level == 0) {
      final continents = t.operation.spots.continents;
      return switch (path) {
        'AF' => continents.af,
        'AS' => continents.as,
        'EU' => continents.eu,
        'NA' => continents.na,
        'OC' => continents.oc,
        'SA' => continents.sa,
        'AN' => continents.an,
        _ => t.home.logs.groupBy.unknownContinent,
      };
    }
    final name = first.theirEntityName;
    if (name == null || name.isEmpty) return t.home.logs.groupBy.unknownEntity;
    final flag = first.theirFlag;
    return flag == null ? name : '$flag $name';
  }
}

/// The searched, sorted QSOs regrouped so each group's QSOs run together:
/// the groups in their own order — dates newest first unless a clock sort
/// says otherwise, DX alphabetically — and the sort within them. Whatever is
/// collapsed has no say here, so a header tap only rebuilds the
/// [_LogsTableRows] over it, a pass with no sorting in it.
class _LogsGrouped {
  final LogsGrouping grouping;
  final List<Qso> qsos;

  /// [LogsGrouping.pathOf] for each of [qsos], in step with it.
  final List<List<String>> paths;
  final Map<String, int> counts;

  /// Each group's subgroups, by path — the outermost under `''` — whether or
  /// not a collapsed group hides them.
  final Map<String, List<String>> children;

  _LogsGrouped._(this.grouping, this.qsos, this.paths, this.counts, this.children);

  factory _LogsGrouped(List<Qso> sorted, {required LogsGrouping grouping, required _LogsSort sort}) {
    final paths = [for (final qso in sorted) grouping.pathOf(qso)];
    final order = List<int>.generate(sorted.length, (i) => i);
    final leaf = grouping.levels - 1;
    // By the clock, each day's QSOs already run together, in the direction
    // the date groups run: sorting them again is a whole log's worth of
    // string compares for nothing.
    if (leaf >= 0 && !(grouping == LogsGrouping.date && sort.chronological)) {
      final descending = grouping == LogsGrouping.date;
      order.sort((a, b) {
        final compared = paths[a][leaf].compareTo(paths[b][leaf]);
        if (compared != 0) return descending ? -compared : compared;
        return a - b;
      });
    }
    final counts = <String, int>{};
    final children = <String, Set<String>>{};
    for (final i in order) {
      final path = paths[i];
      for (final (l, key) in path.indexed) {
        counts[key] = (counts[key] ?? 0) + 1;
        (children[l == 0 ? '' : path[l - 1]] ??= <String>{}).add(key);
      }
    }
    return _LogsGrouped._(grouping, [for (final i in order) sorted[i]], [for (final i in order) paths[i]], counts, {
      for (final MapEntry(:key, :value) in children.entries) key: value.toList(),
    });
  }
}

/// What the table draws, in order: the [_LogsGrouped] QSOs under their
/// [_LogsGroupHeader]s, minus whatever a collapsed group holds. A header is
/// one row tall like everything else in the list (see [_QsoListPanel]), so any
/// item's scroll offset is still its index times the row height, which is
/// what lets the keyboard bring a row into view and the headers pin without
/// measuring anything.
class _LogsTableRows {
  final _LogsGrouped grouped;

  /// Only the QSOs on screen — what ↑/↓ step through.
  final List<Qso> qsos;

  /// Each element a [Qso] or a [_LogsGroupHeader].
  final List<Object> items;

  final Map<String, int> _qsoIndex;
  final Map<String, int> _itemIndex;

  /// Per level, the item index of the header each item sits under at that
  /// level, or -1 for none — an item that is itself a header of an outer
  /// level starts a group with no header at this one yet.
  final List<Int32List> _headerAt;

  _LogsTableRows._(this.grouped, this.qsos, this.items, this._qsoIndex, this._itemIndex, this._headerAt);

  /// Every QSO the filter and search match, collapsed or not — what the
  /// counts and the column auto-fit read.
  List<Qso> get all => grouped.qsos;

  LogsGrouping get grouping => grouped.grouping;

  Map<String, List<String>> get children => grouped.children;

  factory _LogsTableRows(_LogsGrouped grouped, {required bool Function(String path) collapsed}) {
    final levels = grouped.grouping.levels;
    final shown = <Qso>[];
    final items = <Object>[];
    final qsoIndex = <String, int>{};
    final itemIndex = <String, int>{};
    final headerAt = <List<int>>[for (var l = 0; l < levels; l++) <int>[]];
    final current = List<int>.filled(levels, -1);
    List<String>? previous;
    void add(Object item) {
      for (var l = 0; l < levels; l++) {
        headerAt[l].add(current[l]);
      }
      items.add(item);
    }

    for (final (i, qso) in grouped.qsos.indexed) {
      final path = grouped.paths[i];
      // The outermost level whose group changes here: a header for it and
      // for every level inside it — unless a group around it is collapsed.
      var from = 0;
      while (previous != null && from < path.length && previous[from] == path[from]) {
        from++;
      }
      previous = path;
      var hidden = false;
      for (var l = 0; l < from; l++) {
        if (collapsed(path[l])) hidden = true;
      }
      for (var l = from; l < path.length && !hidden; l++) {
        for (var inner = l; inner < levels; inner++) {
          current[inner] = -1;
        }
        current[l] = items.length;
        final isCollapsed = collapsed(path[l]);
        add(_LogsGroupHeader(grouping: grouped.grouping, level: l, path: path[l], first: qso, count: grouped.counts[path[l]]!, collapsed: isCollapsed));
        if (isCollapsed) hidden = true;
      }
      if (hidden) continue;
      qsoIndex[qso.uuid] = shown.length;
      itemIndex[qso.uuid] = items.length;
      shown.add(qso);
      add(qso);
    }
    return _LogsTableRows._(grouped, shown, items, qsoIndex, itemIndex, [for (final level in headerAt) Int32List.fromList(level)]);
  }

  int? qsoIndexOf(String uuid) => _qsoIndex[uuid];

  int? itemIndexOf(String uuid) => _itemIndex[uuid];

  /// Where [path]'s header is in [items], when no collapsed group hides it.
  int? headerIndexOf(String path) {
    for (final (index, item) in items.indexed) {
      if (item is _LogsGroupHeader && item.path == path) return index;
    }
    return null;
  }

  /// [header]'s group and its siblings — the groups under the same parent —
  /// and every group inside any of them.
  List<String> siblingsAndDescendants(_LogsGroupHeader header) {
    final parent = header.level == 0 ? '' : _parentOf(header.path);
    final found = <String>[];
    void walk(String path) {
      found.add(path);
      for (final child in children[path] ?? const <String>[]) {
        walk(child);
      }
    }

    for (final sibling in children[parent] ?? [header.path]) {
      walk(sibling);
    }
    return found;
  }

  String _parentOf(String path) {
    for (final MapEntry(:key, :value) in children.entries) {
      if (value.contains(path)) return key;
    }
    return '';
  }

  /// The headers pinned over the list at [firstItem] — the item at its top
  /// edge — outermost first: at each level, the header of the group the row
  /// under that level's pinned slot belongs to. A level whose row starts a
  /// new outer group pins nothing.
  List<int> pinnedAt(int firstItem) {
    final pinned = <int>[];
    for (var l = 0; l < grouping.levels; l++) {
      final index = firstItem + pinned.length;
      if (index < 0 || index >= items.length) break;
      final header = _headerAt[l][index];
      if (header >= 0) pinned.add(header);
    }
    return pinned;
  }
}

/// A group's header row: a chevron that says whether it is collapsed, the
/// group, and its QSO count — indented by level, and tapped to collapse or
/// expand. The innermost level carries [DayHeaderRow]'s heavier bottom rule,
/// the break right above the QSOs; the outer ones a hairline.
class _LogsGroupHeaderRow extends StatelessWidget {
  final _LogsGroupHeader header;
  final VoidCallback onTap;

  const _LogsGroupHeaderRow({required this.header, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = context.t.loggingControls.info;
    // DayHeaderRow's row-sized text: the header is a divider within the
    // list, not a heavier element above it.
    final rowStyle = theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.0);
    final innermost = header.level == header.grouping.levels - 1;
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: InkWell(
        onTap: onTap,
        child: Container(
          foregroundDecoration: BoxDecoration(
            border: Border(
              bottom: innermost ? BorderSide(color: theme.colorScheme.outline, width: 3) : BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          padding: PaneSafeArea.symmetricOf(context, horizontal: Space.lg, vertical: 0).add(EdgeInsetsDirectional.only(start: header.level * Space.xl)),
          child: Row(
            children: [
              Icon(header.collapsed ? MdiIcons.chevronRight : MdiIcons.chevronDown, size: 18, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: Space.xs),
              Flexible(
                child: Text(
                  header.label(context),
                  style: rowStyle?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: Space.md),
              Text(header.count == 1 ? info.qsoCountOne : info.qsoCountOther(count: formatNumber(header.count)), style: rowStyle),
            ],
          ),
        ),
      ),
    );
  }
}
