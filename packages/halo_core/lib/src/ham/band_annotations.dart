// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Band annotations: what is said about a stretch of a band or a place on it —
// where the band starts and ends, the band plan's modes, the windows and
// frequencies known for something, and anything else worth marking — as
// extensions and the operator hand them over, and where they are kept. One
// parse and one store for both hosts: the app keeps them for its panels
// (app/lib/services/band_annotations_service.dart), the CLI for a run.

import 'radio.dart';

/// What an annotation marks: a band's allocated stretch (`edge`), a stretch
/// of its plan's modes or of a license's privileges (`plan`), a window or a
/// frequency known for something (`known`), or anything else (`general`).
const bandAnnotationTypes = {'edge', 'plan', 'known', 'general'};

/// How much an annotation matters, most first: a display short of room, or
/// set to show less, leaves out the least first.
const bandAnnotationImportances = {'primary', 'secondary', 'tertiary'};

/// The source the operator's own annotations are held under, beside the
/// extensions' keys.
const userBandAnnotationSource = 'user';

/// The most annotations one source holds at once.
const maxBandAnnotationsPerSource = 1000;

/// The longest a `key`, `label`, `icon`, `band` or `color` may be.
const maxBandAnnotationTextChars = 200;

/// `#RRGGBB`: a color a display may draw, with its own opacity added.
final _color = RegExp(r'^#[0-9a-fA-F]{6}$');

/// [value], an annotation as an extension hands it over, checked and in its
/// held shape: `band` worked out from its frequencies where it names none,
/// `importance` defaulting to `primary`. Throws [FormatException] for one
/// that is malformed or names an unknown field: an annotation taken in part
/// would be drawn as something it does not say.
Map<String, dynamic> bandAnnotationFrom(Object? value, {String context = 'band annotation'}) {
  if (value is! Map) throw FormatException('$context: must be an object');
  final map = value.cast<String, dynamic>();
  final unknown = map.keys.where((key) => !_known.contains(key));
  if (unknown.isNotEmpty) throw FormatException('$context: unknown field `${unknown.first}`');

  final type = map['type'];
  if (!bandAnnotationTypes.contains(type)) throw FormatException("$context: `type` must be one of ${bandAnnotationTypes.join(', ')}, not `$type`");
  final from = _hz(map, 'fromHz', context);
  if (from == null) throw FormatException('$context: `fromHz` is required');
  final to = _hz(map, 'toHz', context);
  if (to != null && to < from) throw FormatException('$context: `toHz` is below `fromHz`');
  final importance = map['importance'] ?? 'primary';
  if (!bandAnnotationImportances.contains(importance)) {
    throw FormatException("$context: `importance` must be one of ${bandAnnotationImportances.join(', ')}, not `$importance`");
  }
  final expiresAt = map['expiresAt'];
  if (expiresAt != null && (expiresAt is! num || !expiresAt.isFinite)) throw FormatException('$context: `expiresAt` must be a time in epoch milliseconds');
  final declaredBand = _text(map, 'band', context)?.trim().toLowerCase();
  final band = declaredBand ?? bandForFrequency(from / 1000) ?? (to == null ? null : bandForFrequency(to / 1000));
  if (band == null || band.isEmpty) throw FormatException('$context: no band at ${from}Hz; name one with `band`');

  return {
    'type': type,
    'fromHz': from,
    'toHz': ?to,
    'band': band,
    'key': ?_text(map, 'key', context),
    'label': ?_text(map, 'label', context),
    'icon': ?_text(map, 'icon', context),
    'importance': importance,
    'color': ?_colorOf(map, context),
    if (expiresAt is num) 'expiresAt': expiresAt.toInt(),
  };
}

const _known = {'type', 'fromHz', 'toHz', 'band', 'key', 'label', 'icon', 'importance', 'color', 'expiresAt'};

int? _hz(Map<String, dynamic> map, String field, String context) {
  final value = map[field];
  if (value == null) return null;
  if (value is! num || !value.isFinite || value <= 0) throw FormatException('$context: `$field` must be a positive frequency in Hz');
  return value.round();
}

/// A color any display can blend: one it cannot read fails the whole
/// picture it is drawn in, the other annotations' with it.
String? _colorOf(Map<String, dynamic> map, String context) {
  final value = map['color'];
  if (value == null) return null;
  if (value is! String || !_color.hasMatch(value)) throw FormatException('$context: `color` must be `#RRGGBB`');
  return value;
}

String? _text(Map<String, dynamic> map, String field, String context) {
  final value = map[field];
  if (value == null) return null;
  if (value is! String || value.length > maxBandAnnotationTextChars) {
    throw FormatException('$context: `$field` must be a string of at most $maxBandAnnotationTextChars characters');
  }
  return value;
}

/// The annotations each source has put, by their keys. An annotation put
/// without a key is held under one of its own, so putting it again adds
/// another: only a remove of all the source's takes it.
class BandAnnotationStore {
  final _bySource = <String, Map<String, Map<String, dynamic>>>{};
  var _unkeyed = 0;

  /// Puts [annotations] under [source], replacing any it holds with the same
  /// key. All or none: one malformed rejects the call, and so does going
  /// past [maxBandAnnotationsPerSource].
  void put(String source, List<Object?> annotations) {
    final parsed = [for (final (i, a) in annotations.indexed) bandAnnotationFrom(a, context: 'band annotation $i')];
    final held = {...?_bySource[source]};
    for (final annotation in parsed) {
      held[annotation['key'] as String? ?? '\u0000${_unkeyed++}'] = annotation;
    }
    if (held.length > maxBandAnnotationsPerSource) {
      throw FormatException("band annotations: '$source' would hold ${held.length}, past the $maxBandAnnotationsPerSource a source may");
    }
    _bySource[source] = held;
  }

  /// Takes the annotations under [keys] from [source], or all of them when
  /// [keys] is null. True when any was there.
  bool remove(String source, [Iterable<String>? keys]) {
    if (keys == null) return _bySource.remove(source) != null;
    final held = _bySource[source];
    if (held == null) return false;
    final before = held.length;
    keys.forEach(held.remove);
    if (held.isEmpty) _bySource.remove(source);
    return held.length != before;
  }

  /// Takes every source [test] picks. True when any was there.
  bool removeSourcesWhere(bool Function(String source) test) {
    final before = _bySource.length;
    _bySource.removeWhere((source, _) => test(source));
    return _bySource.length != before;
  }

  /// The annotations [source] holds, [test] picks, taken. True when any was.
  bool removeWhere(String source, bool Function(Map<String, dynamic> annotation) test) {
    final held = _bySource[source];
    if (held == null) return false;
    final before = held.length;
    held.removeWhere((_, annotation) => test(annotation));
    if (held.isEmpty) _bySource.remove(source);
    return held.length != before;
  }

  /// Every annotation on [band] not expired at [now], each with the
  /// `source` that put it. The expired are dropped as they are found.
  List<Map<String, dynamic>> forBand(String band, {required int now}) {
    dropExpired(now);
    return [
      for (final MapEntry(key: source, value: held) in _bySource.entries)
        for (final annotation in held.values)
          if (annotation['band'] == band) {...annotation, 'source': source},
    ];
  }

  /// Drops every annotation expired at [now]. True when any was.
  bool dropExpired(int now) {
    var dropped = false;
    for (final source in [..._bySource.keys]) {
      dropped = removeWhere(source, (a) => (a['expiresAt'] as int? ?? now + 1) <= now) || dropped;
    }
    return dropped;
  }

  /// When the next annotation held expires, or null when none does.
  int? get nextExpiry {
    int? next;
    for (final held in _bySource.values) {
      for (final annotation in held.values) {
        final at = annotation['expiresAt'] as int?;
        if (at != null && (next == null || at < next)) next = at;
      }
    }
    return next;
  }
}
