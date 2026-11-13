// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// How long an extension's cluster `match` pattern can take on one line. The
// app runs these patterns itself, on its main isolate, with a backtracking
// engine and no time limit, so a pattern is admitted only when its worst case
// is small whatever the line says (docs/extensions/spots.md).
//
// [clusterPatternSteps] bounds the steps a backtracking engine takes. Each
// part of a pattern costs a linear function of what comes after it:
// `a·K + b`, where K is the cost of the rest of the pattern, a is how many
// times the rest can be tried, and b the part's own steps. A repeat tries the
// rest once for every place it can stop — up to the line's length — when
// what follows could continue the repeat (`.*X`, `a*a`), and multiplies what
// it repeats. One the rest cannot continue (`\d+\s`) still tries every
// place it could stop, but only to find the rest's first character missing:
// that adds up to the line's length, and multiplies nothing.
//
// A cluster line is Latin-1 — `ClusterLineDecoder` turns each byte into one
// character — so what an atom can match is a set of 256 characters, worked
// out exactly by asking the engine about each one.

import 'dart:math' as math;
import 'dart:typed_data';

/// About the most steps [source], compiled with [flags], takes on a line
/// [lineLength] characters long that it never matches, from every place the
/// search could start. [source] must already compile. Throws
/// [FormatException] for a reference back to a group, whose cost has no
/// such bound.
double clusterPatternSteps(String source, String flags, int lineLength) {
  final pattern = _Parser(source, flags).parse();
  final cost = _Estimate(lineLength).cost(pattern, _Chars.none);
  return _finite((cost.a + cost.b) * (lineLength + 1));
}

/// A set of Latin-1 characters.
class _Chars {
  _Chars(this._in);

  static final none = _Chars(Uint8List(256));
  static final all = _Chars(Uint8List(256)..fillRange(0, 256, 1));

  final Uint8List _in;

  bool overlaps(_Chars other) {
    for (var c = 0; c < 256; c++) {
      if (_in[c] == 1 && other._in[c] == 1) return true;
    }
    return false;
  }

  _Chars operator |(_Chars other) => _Chars(Uint8List.fromList([for (var c = 0; c < 256; c++) _in[c] | other._in[c]]));
}

/// A part of a pattern, with what it can start with and whether it can
/// match no characters at all.
sealed class _Node {
  _Node(this.first, this.nullable);
  final _Chars first;
  final bool nullable;
}

/// One character from [first].
class _Atom extends _Node {
  _Atom(_Chars chars) : super(chars, false);
}

/// `^`, `$`, `\b`, `\B`: matches no character.
class _Assertion extends _Node {
  _Assertion() : super(_Chars.none, true);
}

/// A lookahead or lookbehind: matches no character, but runs [body] there.
/// It counts as able to start with any character: a repeat before it tries
/// [body] at every place it could stop, as it would a rest that continues it.
class _Look extends _Node {
  _Look(this.body) : super(_Chars.all, true);
  final _Node body;
}

class _Sequence extends _Node {
  _Sequence(this.items) : super(_firstOf(items), items.every((item) => item.nullable));
  final List<_Node> items;

  static _Chars _firstOf(List<_Node> items) {
    var first = _Chars.none;
    for (final item in items) {
      first = first | item.first;
      if (!item.nullable) break;
    }
    return first;
  }
}

class _Alternation extends _Node {
  _Alternation(this.branches) : super(branches.map((b) => b.first).reduce((a, b) => a | b), branches.any((b) => b.nullable));
  final List<_Node> branches;
}

/// [body] from [min] to [max] times; [max] null for no bound.
class _Repeat extends _Node {
  _Repeat(this.body, this.min, this.max) : super(body.first, min == 0 || body.nullable);
  final _Node body;
  final int min;
  final int? max;
}

/// A part's cost, given the cost K of what follows it: `a·K + b`.
typedef _Cost = ({double a, double b});

/// [x], or infinity for a value too large to count — including the NaN an
/// infinity divided by an infinity makes.
double _finite(double x) => x.isNaN || x > 1e300 ? double.infinity : x;

/// [outer] after [inner]: `outer(inner(K))`.
_Cost _then(_Cost outer, _Cost inner) => (a: _finite(outer.a * inner.a), b: _finite(outer.a * inner.b + outer.b));

class _Estimate {
  _Estimate(this.lineLength);

  final int lineLength;

  /// [node]'s cost when [follow] is what may come after it. Each node is
  /// costed once: a repeat's body is costed once for all its passes.
  _Cost cost(_Node node, _Chars follow) {
    switch (node) {
      case _Atom() || _Assertion():
        return (a: 1, b: 1);
      case _Look(:final body):
        final inside = cost(body, _Chars.none);
        return (a: 1, b: _finite(1 + inside.a + inside.b));
      case _Sequence(:final items):
        var total = (a: 1.0, b: 0.0);
        var after = follow;
        for (final item in items.reversed) {
          total = _then(cost(item, after), total);
          after = item.nullable ? item.first | after : item.first;
        }
        return total;
      case _Alternation(:final branches):
        final costs = [for (final branch in branches) cost(branch, follow)];
        final starts = [for (final branch in branches) branch.nullable ? branch.first | follow : branch.first];
        var alike = false;
        for (var i = 0; i < starts.length && !alike; i++) {
          for (var j = i + 1; j < starts.length && !alike; j++) {
            alike = starts[i].overlaps(starts[j]);
          }
        }
        // Alternatives that start apart: past its first character, only
        // one goes on.
        if (!alike) {
          return (a: costs.map((c) => c.a).reduce(math.max), b: _finite(costs.map((c) => c.b).reduce(math.max) + costs.length));
        }
        return (a: _finite(costs.fold(0.0, (sum, c) => sum + c.a)), b: _finite(costs.fold(0.0, (sum, c) => sum + c.b)));
      case _Repeat(:final body, :final min, :final max):
        // No pattern makes more passes than a line has characters, plus
        // one: a pass that matches nothing ends the repeat.
        final most = lineLength + 1;
        final required = math.min(min, most);
        final optional = (max == null ? most : math.min(max, most)) - required;
        final pass = cost(body, max == 1 ? follow : body.first | follow);
        final requiredPasses = _power(pass, required);
        final continues = body.first.overlaps(follow) || body.nullable;
        final optionalPasses = _optional(pass, math.max(optional, 0), continues: continues);
        return _then(requiredPasses, optionalPasses);
    }
  }

  /// [pass] made [times] times in a row.
  static _Cost _power(_Cost pass, int times) {
    if (times == 0) return (a: 1, b: 0);
    if (pass.a <= 1) return (a: 1, b: _finite(times * pass.b));
    final a = _finite(math.pow(pass.a, times).toDouble());
    return (a: a, b: _finite(pass.b * (a - 1) / (pass.a - 1)));
  }

  /// Up to [times] more passes, greedy: each tries another pass, and the
  /// rest of the pattern where it stops. When what follows cannot continue
  /// the repeat ([continues] false), the rest gets past its first character
  /// at one stop only.
  static _Cost _optional(_Cost pass, int times, {required bool continues}) {
    if (times == 0) return (a: 1, b: 0);
    if (!continues && pass.a <= 1) return (a: 1, b: _finite(times * (pass.b + 2)));
    if (pass.a <= 1) return (a: times + 1.0, b: _finite(times * pass.b));
    final grown = _finite(math.pow(pass.a, times).toDouble());
    return (a: _finite((grown * pass.a - 1) / (pass.a - 1)), b: _finite(pass.b * (grown - 1) / (pass.a - 1)));
  }
}

/// Reads a JavaScript regular expression's source into [_Node]s. The source
/// has already compiled, so only what it is made of matters here, not
/// whether it is well formed.
class _Parser {
  _Parser(this.source, String flags) : _caseSensitive = !flags.contains('i'), _dotAll = flags.contains('s'), _unicode = flags.contains('u');

  final String source;
  final bool _caseSensitive;
  final bool _dotAll;
  final bool _unicode;
  var _i = 0;
  late final _groups = _countGroups();

  static final _hex2 = RegExp(r'^[0-9A-Fa-f]{2}');
  static final _hex4 = RegExp(r'^[0-9A-Fa-f]{4}');
  static final _braces = RegExp(r'^\{(\d+)(,(\d*))?\}');

  _Node parse() {
    final node = _alternation();
    if (_i != source.length) throw const FormatException('could not be read');
    return node;
  }

  _Node _alternation() {
    final branches = [_sequence()];
    while (_i < source.length && source[_i] == '|') {
      _i++;
      branches.add(_sequence());
    }
    return branches.length == 1 ? branches.single : _Alternation(branches);
  }

  _Node _sequence() {
    final items = <_Node>[];
    while (_i < source.length && source[_i] != '|' && source[_i] != ')') {
      items.add(_quantified(_term()));
    }
    return _Sequence(items);
  }

  _Node _term() {
    final c = source[_i];
    switch (c) {
      case '(':
        return _group();
      case '[':
        final start = _i;
        _i++;
        while (_i < source.length && source[_i] != ']') {
          _i += source[_i] == r'\' ? 2 : 1;
        }
        _i++;
        return _atom(source.substring(start, _i));
      case r'\':
        return _escape();
      case '^' || r'$':
        _i++;
        return _Assertion();
      default:
        _i++;
        return _atom(c);
    }
  }

  _Node _group() {
    final rest = source.substring(_i);
    final look = rest.startsWith('(?=') || rest.startsWith('(?!') || rest.startsWith('(?<=') || rest.startsWith('(?<!');
    if (rest.startsWith('(?<=') || rest.startsWith('(?<!')) {
      _i += 4;
    } else if (rest.startsWith('(?<')) {
      _i = source.indexOf('>', _i) + 1;
    } else if (look || rest.startsWith('(?:')) {
      _i += 3;
    } else if (rest.startsWith('(?')) {
      // `(?i:…)` and its kin change what the atoms inside match, which
      // [_atom] does not see.
      throw const FormatException('has a `(?` group other than `(?:`, `(?=`, `(?!`, `(?<=`, `(?<!` or `(?<name>`');
    } else {
      _i += 1;
    }
    final body = _alternation();
    _i++; // ')'
    return look ? _Look(body) : body;
  }

  _Node _escape() {
    final start = _i;
    final next = _i + 1 < source.length ? source[_i + 1] : '';
    // `\1`… and `\k<name>` refer back to a group only when the pattern has
    // one to refer to; otherwise, outside unicode mode, they are the
    // characters they spell (`\8`, `\k`) or an octal escape (`\12`, `\041`).
    final digits = RegExp(r'^\d+').stringMatch(source.substring(_i + 1));
    final refersBack = digits != null ? next != '0' && int.parse(digits) <= _groups.count : next == 'k' && (_unicode || _groups.named);
    if (refersBack) throw const FormatException('refers back to a group, which can take a line forever');
    if (digits != null) {
      final octal = RegExp(r'^[0-7]{1,3}').stringMatch(source.substring(_i + 1));
      _i += 1 + (octal == null ? 1 : (int.parse(octal, radix: 8) > 255 ? octal.length - 1 : octal.length));
      return _atom(source.substring(start, _i));
    }
    if (next == 'b' || next == 'B') {
      _i += 2;
      return _Assertion();
    }
    final after = source.substring(_i + 2);
    // Outside unicode mode, `\c` not before a letter is a backslash, and the
    // `c` is a character of its own.
    if (next == 'c' && !(after.isNotEmpty && RegExp(r'[A-Za-z]').hasMatch(after[0]))) {
      _i += 1;
      return _atom(r'\\');
    }
    _i += switch (next) {
      'x' when _hex2.hasMatch(after) => 4,
      'u' when _unicode && after.startsWith('{') => after.indexOf('}') + 3,
      'u' when _hex4.hasMatch(after) => 6,
      'c' => 3,
      'p' || 'P' when _unicode && after.startsWith('{') => after.indexOf('}') + 3,
      _ => 2,
    };
    return _atom(source.substring(start, _i));
  }

  /// The capturing groups in [source], and whether any is named.
  ({int count, bool named}) _countGroups() {
    var count = 0;
    var named = false;
    var inClass = false;
    for (var i = 0; i < source.length; i++) {
      final c = source[i];
      if (c == r'\') {
        i++;
      } else if (inClass) {
        inClass = c != ']';
      } else if (c == '[') {
        inClass = true;
      } else if (c == '(') {
        final rest = source.substring(i + 1);
        if (!rest.startsWith('?')) {
          count++;
        } else if (rest.startsWith('?<') && !rest.startsWith('?<=') && !rest.startsWith('?<!')) {
          count++;
          named = true;
        }
      }
    }
    return (count: count, named: named);
  }

  _Node _quantified(_Node node) {
    if (_i >= source.length) return node;
    int min;
    int? max;
    switch (source[_i]) {
      case '*':
        (min, max) = (0, null);
        _i++;
      case '+':
        (min, max) = (1, null);
        _i++;
      case '?':
        (min, max) = (0, 1);
        _i++;
      case '{':
        final braces = _braces.firstMatch(source.substring(_i));
        if (braces == null) return node;
        min = int.parse(braces[1]!);
        max = braces[2] == null ? min : (braces[3]!.isEmpty ? null : int.parse(braces[3]!));
        _i += braces[0]!.length;
      default:
        return node;
    }
    if (_i < source.length && source[_i] == '?') _i++;
    return _Repeat(node, min, max);
  }

  final _atoms = <String, _Chars>{};

  /// The characters [atom] — one character, class or escape — matches.
  _Node _atom(String atom) => _Atom(
    _atoms.putIfAbsent(atom, () {
      final one = RegExp('^(?:$atom)\$', caseSensitive: _caseSensitive, dotAll: _dotAll, unicode: _unicode);
      return _Chars(Uint8List.fromList([for (var c = 0; c < 256; c++) one.hasMatch(String.fromCharCode(c)) ? 1 : 0]));
    }),
  );
}
