// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

part of 'scene_model.dart';

/// One node of a scene's layout: Flutter's Row, Column and Wrap, with
/// Flexible, Spacer and SizedBox folded in as fields, and a grid. JSON names
/// the type by its one key — `{row: [...]}`, `{grid: [...]}`, `{control: 'id'}`,
/// `{cell: 'id'}`, `{scene: true}`, `{spacer: 1}`.
///
/// Refused here, rather than left to throw in layout: a `flex` anywhere but a
/// row or column's direct child (Flutter asserts on the parent data). One the
/// parser cannot see — a row with no room to share, itself an unflexed child
/// of a row — is laid out unflexed by the view instead.
///
/// A grid puts its children in slots [unit] in size with [gap] between them,
/// row by row in order, each at the first place it fits from where the one
/// before it went, so the order on screen is the order written. A grid within
/// a grid takes its parent's [unit] and [gap] unless it names its own. A child
/// spans [span] slots; a cell, by default, the slots its size covers. A grid
/// within a grid has no [span]: one with [columns] takes the slots its content
/// needs, and one that wraps takes a whole row of its parent and wraps within
/// it — otherwise its width would wait on the parent's columns, and the
/// parent's columns on its width.
class SceneLayoutNode {
  static const maxDepth = 12, maxNodes = 512;
  static const _types = ['row', 'column', 'wrap', 'grid', 'control', 'cell', 'scene', 'spacer'];

  final String type;
  final List<SceneLayoutNode> children;
  final String? control, cell;
  final int? flex;
  final bool tight;
  final double? width, height;
  final EdgeInsetsDirectional padding;
  final double spacing, runSpacing;
  final String mainAxisAlignment, crossAxisAlignment;

  /// A grid's slot and the space between slots, across and down: its own, or its parent grid's.
  final Size? unit;
  final Offset? gap;

  /// A grid's fixed width in slots, scrolling sideways in a pane too narrow for it. Null: as
  /// many as fit, wrapping onto new rows.
  final int? columns;
  final SceneGridStyle? style;

  /// A grid child's slots across and down.
  final ({int columns, int rows})? span;

  SceneLayoutNode._(
    Map<dynamic, dynamic> json,
    this.type,
    this.children, {
    required bool inFlex,
    required bool inGrid,
    required ({Size unit, Offset gap})? grid,
  }) : control = type == 'control' ? string(json, 'control') : null,
       cell = type == 'cell' ? string(json, 'cell') : null,
       unit = type == 'grid' ? grid!.unit : null,
       gap = type == 'grid' ? grid!.gap : null,
       columns = type == 'grid' && json['columns'] != null ? number(json, 'columns', min: 1, max: 256).round() : null,
       style = type == 'grid' && json['style'] != null ? SceneGridStyle(_map(json, 'style')) : null,
       span = json['span'] == null ? null : _span(json['span']),
       flex = type == 'spacer'
           ? number(json, 'spacer', min: 1, max: 1000).round()
           : json['flex'] == null
           ? null
           : number(json, 'flex', min: 1, max: 1000).round(),
       tight = _oneOf(json, 'fit', const ['tight', 'loose']) != 'loose',
       width = json['width'] == null ? null : number(json, 'width', min: 0, max: 8192),
       height = json['height'] == null ? null : number(json, 'height', min: 0, max: 8192),
       padding = _padding(json['padding']),
       spacing = number(json, 'spacing', fallback: 0, min: 0, max: 1000),
       runSpacing = number(json, 'runSpacing', fallback: 0, min: 0, max: 1000),
       mainAxisAlignment = _oneOf(json, 'mainAxisAlignment', const ['start', 'center', 'end', 'spaceBetween', 'spaceAround', 'spaceEvenly']) ?? 'start',
       crossAxisAlignment = _oneOf(json, 'crossAxisAlignment', const ['start', 'center', 'end', 'stretch']) ?? 'center' {
    if (type == 'scene' && json['scene'] != true) throw const FormatException('Invalid scene layout node');
    if (flex != null && !inFlex) throw const FormatException('Layout flex outside a row or column');
    if (type == 'wrap' && crossAxisAlignment == 'stretch') throw const FormatException('A wrap cannot stretch its runs');
    if (span != null && (!inGrid || type == 'grid')) throw const FormatException('Layout span outside a grid, or on a grid');
    for (final key in const ['unit', 'gap', 'columns', 'style']) {
      if (json[key] != null && type != 'grid') throw FormatException('Layout $key on a node that is not a grid');
    }
  }

  static SceneLayoutNode parse(Object? json) {
    var count = 0;
    SceneLayoutNode node(Object? raw, int depth, {required bool inFlex, required bool inGrid, ({Size unit, Offset gap})? grid}) {
      if (raw is! Map<dynamic, dynamic>) throw const FormatException('Invalid scene layout');
      if (++count > maxNodes) throw PanelContentRefusal(PanelBudget.items, maxNodes, 'scene layout has more than $maxNodes nodes');
      if (depth > maxDepth) throw PanelContentRefusal(PanelBudget.layoutDepth, maxDepth, 'scene layout nests $depth deep, at most $maxDepth');
      final types = _types.where(raw.containsKey).toList();
      if (types.length != 1) throw const FormatException('A layout node needs exactly one type');
      final type = types.single;
      if (type == 'grid') {
        final unit = raw['unit'] == null ? grid?.unit : _layoutPair(raw, 'unit', min: 1, max: 8192, as: (w, h) => Size(w, h));
        if (unit == null) throw const FormatException('A grid needs a unit');
        final gap = switch (raw['gap']) {
          null => grid?.gap ?? Offset.zero,
          num _ => Offset(number(raw, 'gap', max: 1000, min: 0), number(raw, 'gap', max: 1000, min: 0)),
          _ => _layoutPair(raw, 'gap', min: 0, max: 1000, as: Offset.new),
        };
        grid = (unit: unit, gap: gap);
      }
      final children = const {'row', 'column', 'wrap', 'grid'}.contains(type)
          ? items(
              raw[type],
              maxNodes,
              what: 'layout children',
            ).map((c) => node(c, depth + 1, inFlex: type == 'row' || type == 'column', inGrid: type == 'grid', grid: grid)).toList()
          : const <SceneLayoutNode>[];
      return SceneLayoutNode._(raw, type, children, inFlex: inFlex, inGrid: inGrid, grid: grid);
    }

    return node(json, 1, inFlex: false, inGrid: false);
  }

  void visit(void Function(SceneLayoutNode) f) {
    f(this);
    for (final child in children) {
      child.visit(f);
    }
  }

  /// A grid child's fixed slots, or null for a grid, which takes the slots its content needs.
  /// A cell without a [span] covers what its size does.
  ({int columns, int rows})? spanIn(SceneLayoutNode grid, Map<String, Size> cells) {
    if (type == 'grid') return null;
    if (span case final span?) return span;
    return cellSlots(grid, cells) ?? (columns: 1, rows: 1);
  }

  /// The slots of [grid] this node's cell covers at its own size; null for anything but a cell.
  ({int columns, int rows})? cellSlots(SceneLayoutNode grid, Map<String, Size> cells) {
    final size = cell == null ? null : cells[cell];
    if (size == null) return null;
    return (columns: grid.slotsFor(size.width, horizontal: true), rows: grid.slotsFor(size.height, horizontal: false));
  }

  /// How many of this grid's slots [extent] pixels cover, across or down.
  int slotsFor(double extent, {required bool horizontal}) {
    final (u, g) = horizontal ? (unit!.width, gap!.dx) : (unit!.height, gap!.dy);
    return math.max(1, ((extent + g) / (u + g) - 1e-6).ceil());
  }

  /// For a wrapping grid within [parent]: the slots of the parent its narrowest takes across.
  int minColumnsIn(SceneLayoutNode parent, Map<String, Size> cells) => parent.slotsFor(minSlotsWidth(cells) + padding.horizontal, horizontal: true);

  /// The width of [columns] slots of this grid.
  double slotsWidth(int columns) => columns * unit!.width + (columns - 1) * gap!.dx;

  /// The narrowest this grid lays out at, padding and title aside: its widest child's slots, a
  /// wrapping grid within it at its own narrowest. Narrower than this, the pane scrolls sideways.
  /// A grid with [columns] scrolls itself, so it asks for one slot.
  double minSlotsWidth(Map<String, Size> cells) {
    var widest = 1;
    for (final child in children) {
      final cols = switch (child.spanIn(this, cells)) {
        final span? => span.columns,
        _ when child.columns != null => 1,
        _ => child.minColumnsIn(this, cells),
      };
      if (cols > widest) widest = cols;
    }
    return slotsWidth(widest);
  }
}

({int columns, int rows}) _span(Object? raw) => _layoutPair({'span': raw}, 'span', min: 1, max: 256, as: (c, r) => (columns: c.round(), rows: r.round()));

/// A layout node's `[a, b]` field [key], each within [min]…[max], refused by its name.
T _layoutPair<T>(Map<dynamic, dynamic> json, String key, {required double min, required double max, required T Function(double, double) as}) {
  final raw = json[key];
  if (raw is! List || raw.length != 2) throw FormatException('Invalid layout $key: expected two numbers');
  return as(number({key: raw[0]}, key, min: min, max: max), number({key: raw[1]}, key, min: min, max: max));
}

/// A grid's box, drawn by the app around its slots: [background] and a [borderColor] border
/// [borderWidth] wide, corners rounded to [radius], and [title] above the slots in the label
/// typography. A color is a role the render environment names, or `#RRGGBB`/`#AARRGGBB`.
class SceneGridStyle {
  final String? background, borderColor, title;
  final double borderWidth, radius;

  SceneGridStyle(Map<dynamic, dynamic> json)
    : background = json['background'] == null ? null : _color(json, 'background'),
      borderColor = json['border'] is Map ? _color(json['border'] as Map<dynamic, dynamic>, 'color') : null,
      borderWidth = json['border'] is Map ? number(json['border'] as Map<dynamic, dynamic>, 'width', fallback: 1, min: 0, max: 64) : 0,
      radius = number(json, 'radius', fallback: 0, min: 0, max: 1000),
      title = json['title'] == null ? null : string(json, 'title') {
    if (json['border'] != null && json['border'] is! Map) throw const FormatException('Invalid grid border');
    if ((title?.length ?? 0) > 256) throw _overLength('grid title', title!.length, 256);
  }

  static String _color(Map<dynamic, dynamic> json, String key) {
    final value = string(json, key);
    if (!panelColorRoles.contains(value) && parseExtensionColor(value) == null) throw FormatException('Invalid grid color: $value');
    return value;
  }
}

/// A number for all four sides, or `[start, top, end, bottom]`.
EdgeInsetsDirectional _padding(Object? raw) {
  if (raw == null) return EdgeInsetsDirectional.zero;
  if (raw is num) return EdgeInsetsDirectional.all(number({'p': raw}, 'p', min: 0, max: 1000));
  if (raw is! List || raw.length != 4) throw const FormatException('Invalid layout padding');
  final p = [
    for (final v in raw) number({'p': v}, 'p', min: 0, max: 1000),
  ];
  return EdgeInsetsDirectional.fromSTEB(p[0], p[1], p[2], p[3]);
}

Map<String, Size> _cells(Object? raw) {
  if (raw == null) return const {};
  final cells = <String, Size>{};
  for (final cell in items(raw, 256, what: 'cells')) {
    final id = string(cell, 'id');
    if (cells.containsKey(id)) throw const FormatException('Duplicate cell ID');
    cells[id] = Size(number(cell, 'width', min: 1, max: 8192), number(cell, 'height', min: 1, max: 8192));
  }
  return cells;
}

/// What all a scene's grids may cover between them, in slots: laying one out walks each slot its
/// children take, and that walk runs again at every resize.
const sceneGridMaxSlots = 16384;

extension on PanelScene {
  /// Refuses, here, every grid a layout could only draw by cutting a cell short or spilling it over
  /// its neighbors: the parser knows each cell's size, each unit and each width in slots, and a
  /// cell cropped in layout would be a piece of the scene missing with nothing to say so.
  void _checkGrids(SceneLayoutNode root) {
    var slots = 0;
    void check(SceneLayoutNode node, {SceneLayoutNode? grid, required bool underGrid}) {
      final where = node.cell ?? node.control ?? node.type;
      if (node.type == 'cell' && (node.width != null || node.height != null || node.flex != null || node.padding != EdgeInsetsDirectional.zero)) {
        throw FormatException('A cell keeps its own size, with no width, height, flex or padding: $where');
      }
      if (grid != null && (node.width != null || node.height != null || (node.type != 'grid' && node.padding != EdgeInsetsDirectional.zero))) {
        throw FormatException('A grid gives its child its slots, so the child takes no width, height or padding: $where');
      }
      // Outside its parent grid's slots, a grid would have neither the parent's room nor a scroll of its
      // own, and a cell would be given one slot, whatever its size.
      if (node.type == 'grid' && underGrid && grid == null) throw const FormatException('A grid within a grid is its direct child');
      if (node.type == 'cell' && underGrid && grid == null) throw FormatException('A cell within a grid is its direct child: $where');
      if (node.type != 'grid') {
        for (final child in node.children) {
          check(child, underGrid: underGrid);
        }
        return;
      }
      for (final child in node.children) {
        final where = child.cell ?? child.control ?? child.type;
        if (child.spanIn(node, cells) case final span?) {
          if (span.columns > 256 || span.rows > 256) throw FormatException('A grid child covers more than 256 slots across or down: $where');
          if (child.cellSlots(node, cells) case final covered? when span.columns < covered.columns || span.rows < covered.rows) {
            throw FormatException('A span smaller than its cell would cut the cell short: $where');
          }
          if (node.columns case final columns? when span.columns > columns) throw FormatException("A grid child is wider than its grid's columns: $where");
          slots += span.columns * span.rows;
        } else if (child.columns == null && node.columns != null && child.minColumnsIn(node, cells) > node.columns!) {
          throw FormatException("A wrapping grid is wider than its parent's columns: $where");
        }
        check(child, grid: node, underGrid: true);
      }
    }

    check(root, underGrid: false);
    if (slots > sceneGridMaxSlots) {
      throw PanelContentRefusal(PanelBudget.items, sceneGridMaxSlots, 'scene grids cover $slots slots, at most $sceneGridMaxSlots');
    }
  }
}
