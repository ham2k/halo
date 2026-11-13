// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A patch to a scene document (docs/design/panel-scenes.md § Patches): steps
// applied in order, each naming its place by a path of keys and ids — a key
// in an object, or the `id` of an item in a list of them. Only the objects
// and lists along each step's path are copied, each once however many steps
// pass through it; everything else in the patched document is the very
// object it was before, which is how the parser knows what it can keep
// without reading it again.

/// The most steps one patch takes: past it, a whole scene says it as well.
const scenePatchMaxSteps = 8192;

/// The deepest a step's path reaches.
const scenePatchMaxDepth = 16;

/// [document] with [steps] applied, in order. Throws a [FormatException]
/// naming the step at fault — a patch that cannot apply is refused whole,
/// never applied in part.
Map<dynamic, dynamic> patchScene(Map<dynamic, dynamic> document, Object? steps) {
  if (steps is! List) throw const FormatException('A scene patch is a list of steps');
  if (steps.length > scenePatchMaxSteps) throw FormatException('A scene patch takes at most $scenePatchMaxSteps steps, not ${steps.length}');
  final patch = _Patch();
  var out = document;
  for (final (i, step) in steps.indexed) {
    try {
      out = patch.apply(out, step);
    } on FormatException catch (e) {
      throw FormatException('Scene patch step ${i + 1}: ${e.message}');
    }
  }
  return out;
}

class _Patch {
  /// The copies this patch made, which later steps change in place: copied
  /// again on every step, a patch of a thousand markers would copy their
  /// list a thousand times.
  final _owned = Set<Object>.identity();

  /// Each list's items by id, as far as it has been searched.
  final _indexes = Map<List<dynamic>, Map<String, int>>.identity();

  Map<dynamic, dynamic> _ownMap(Map<dynamic, dynamic> map) {
    if (_owned.contains(map)) return map;
    final copy = Map<dynamic, dynamic>.of(map);
    _owned.add(copy);
    return copy;
  }

  List<dynamic> _ownList(List<dynamic> list) {
    if (_owned.contains(list)) return list;
    final copy = List<dynamic>.of(list);
    _owned.add(copy);
    if (_indexes[list] case final index?) _indexes[copy] = index;
    return copy;
  }

  int _indexOf(List<dynamic> list, String id) {
    final index = _indexes[list] ??= {for (var i = 0; i < list.length; i++) ?_idOf(list[i]): i};
    return index[id] ?? -1;
  }

  Map<dynamic, dynamic> apply(Map<dynamic, dynamic> document, Object? step) {
    if (step is! Map) throw const FormatException('a step is an object');
    final ops = [
      for (final op in const ['set', 'merge', 'remove', 'insert'])
        if (step.containsKey(op)) op,
    ];
    if (ops.length != 1) throw const FormatException('a step is one of set, merge, remove or insert');
    final op = ops.single;
    final path = _path(step[op]);
    if (op == 'insert') return _within(document, path, 0, (list) => _insert(list, step, path)) as Map<dynamic, dynamic>;
    if (path.isEmpty) throw const FormatException('a step names a place in the scene');
    return _within(document, path.sublist(0, path.length - 1), 0, (container) => _change(container, op, step, path)) as Map<dynamic, dynamic>;
  }

  /// [node], owned, with [change] made to what [path] names from [from] on.
  Object? _within(Object? node, List<String> path, int from, Object? Function(Object? target) change) {
    if (from == path.length) return change(node);
    final segment = path[from];
    switch (node) {
      case final Map<dynamic, dynamic> map:
        if (!map.containsKey(segment)) throw FormatException('${_shown(path.sublist(0, from + 1))} is not there');
        final own = _ownMap(map);
        own[segment] = _within(map[segment], path, from + 1, change);
        return own;
      case final List<dynamic> list:
        final at = _indexOf(list, segment);
        if (at < 0) throw FormatException('${_shown(path.sublist(0, from + 1))} is not there');
        final own = _ownList(list);
        own[at] = _within(list[at], path, from + 1, change);
        return own;
      default:
        throw FormatException('${_shown(path.sublist(0, from))} holds neither keys nor items');
    }
  }

  Object? _insert(Object? target, Map<dynamic, dynamic> step, List<String> path) {
    if (target is! List) throw FormatException('${_shown(path)} is not a list');
    final value = step['value'];
    final before = step['before'];
    final id = _idOf(value);
    if (id == null) throw const FormatException('an insert\'s value is an object with an id');
    if (before != null && before is! String) throw const FormatException('an insert\'s before is an id');
    if (_indexOf(target, id) >= 0) throw FormatException('${_shown(path)} already has $id');
    final at = before == null ? target.length : _indexOf(target, before as String);
    if (at < 0) throw FormatException('${_shown(path)} has no $before to insert before');
    final own = _ownList(target)..insert(at, value);
    _indexes.remove(own);
    return own;
  }

  Object? _change(Object? container, String op, Map<dynamic, dynamic> step, List<String> path) {
    final last = path.last;
    switch (container) {
      case final Map<dynamic, dynamic> map:
        switch (op) {
          case 'set':
            if (!step.containsKey('value')) throw const FormatException('a set has a value');
            return _ownMap(map)..[last] = step['value'];
          case 'merge':
            return _ownMap(map)..[last] = _merged(map[last], step['value'], path);
          default:
            if (!map.containsKey(last)) throw FormatException('${_shown(path)} is not there');
            return _ownMap(map)..remove(last);
        }
      case final List<dynamic> list:
        final at = _indexOf(list, last);
        switch (op) {
          case 'set':
            // An item keeps the id it is found by: one set under another
            // would leave two the list cannot tell apart.
            if (_idOf(step['value']) != last) throw FormatException('${_shown(path)} is set to an object with the id $last');
            final own = _ownList(list);
            if (at >= 0) return own..[at] = step['value'];
            _indexes.remove(own);
            return own..add(step['value']);
          case 'merge':
            if (at < 0) throw FormatException('${_shown(path)} is not there');
            final merged = _merged(list[at], step['value'], path);
            if (_idOf(merged) != last) throw FormatException('${_shown(path)} keeps its id');
            return _ownList(list)..[at] = merged;
          default:
            if (at < 0) throw FormatException('${_shown(path)} is not there');
            final own = _ownList(list)..removeAt(at);
            _indexes.remove(own);
            return own;
        }
      default:
        throw FormatException('${_shown(path.sublist(0, path.length - 1))} holds neither keys nor items');
    }
  }
}

/// [value]'s fields over [target]'s, as JSON Merge Patch reads them: a
/// null removes the field.
Map<dynamic, dynamic> _merged(Object? target, Object? value, List<String> path) {
  if (target is! Map) throw FormatException('${_shown(path)} is not an object to merge into');
  if (value is! Map) throw const FormatException('a merge\'s value is an object');
  final copy = Map<dynamic, dynamic>.of(target);
  if (value.containsKey('__proto__')) throw const FormatException('a merge names no __proto__');
  for (final MapEntry(:key, value: field) in value.entries) {
    field == null ? copy.remove(key) : copy[key] = field;
  }
  return copy;
}

List<String> _path(Object? raw) {
  if (raw is! List || raw.any((s) => s is! String)) throw const FormatException('a path is a list of keys and ids');
  if (raw.length > scenePatchMaxDepth) throw FormatException('a path reaches at most $scenePatchMaxDepth deep');
  // Refused as the extension's runtime refuses it, where it names the
  // object's prototype rather than a key: the two scenes stay one.
  if (raw.contains('__proto__')) throw const FormatException('a path names no __proto__');
  return raw.cast<String>();
}

String? _idOf(Object? item) => item is Map && item['id'] is String ? item['id'] as String : null;

String _shown(List<String> path) => path.isEmpty ? 'the scene' : path.join(' › ');
