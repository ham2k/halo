// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What assistants say about spots on the board (docs/extensions/spots.md
// § Marking spots): an icon, a colour, a note, a boost that pins the spot
// among the picks, or a request to hide it. Kept by the extension that put
// each, against the spots' stable ids (spotIdFor), so a mark outlives the
// refreshes that replace the spots it names. Beside the spots, like the band
// annotations: a mark changing judges no spot again.

import 'package:flutter/foundation.dart';

import 'spots_service.dart';

/// One extension's word on one spot id.
typedef SpotMark = ({String? icon, String? color, String? note, double boost, bool hidden});

/// Every mark on one spot, from every extension that put one, as the board
/// draws them: the icons and notes in the order their extensions are named,
/// the strongest boost and the colour of the mark that gave it (the first
/// colour given, where none boosts), and the extensions that hid it.
typedef SpotMarking = ({List<({String icon, String? color})> icons, List<String> notes, String? color, double boost, Set<String> hiddenBy});

class SpotMarksService extends ChangeNotifier {
  /// The most marks one extension holds: a contest weekend's board is a few
  /// thousand spots, and an assistant marks the few worth a look.
  static const maxMarksPerExtension = 1000;

  /// Extension key → spot id → its mark.
  final _bySource = <String, Map<String, SpotMark>>{};

  var _disposed = false;

  bool get isEmpty => _bySource.isEmpty;

  /// The keys of the extensions holding marks.
  Iterable<String> get sources => _bySource.keys;

  /// Puts [mark] on each of [ids] for [source], replacing what [source] said
  /// about them before. Throws [SpotsPushRefused], changing nothing, when
  /// [source] would hold more than [maxMarksPerExtension].
  void mark(String source, List<String> ids, SpotMark mark) {
    if (_disposed || ids.isEmpty) return;
    final held = _bySource[source] ?? const {};
    // Marking again with what is held is no change, and says nothing to the
    // listeners: an assistant re-marking its picks on its `spots` trigger
    // would otherwise wake itself, through the trigger, for good.
    if (ids.every((id) => held[id] == mark)) return;
    final after = {...held, for (final id in ids) id: mark};
    if (after.length > maxMarksPerExtension) {
      throw SpotsPushRefused("'$source' would hold ${after.length} spot marks, and an extension holds at most $maxMarksPerExtension");
    }
    _bySource[source] = after;
    notifyListeners();
  }

  /// Takes [source]'s marks off [ids], or every mark it put.
  void unmark(String source, [List<String>? ids]) {
    if (_disposed) return;
    final held = _bySource[source];
    if (held == null) return;
    if (ids == null) {
      _bySource.remove(source);
    } else {
      final taken = ids.toSet();
      final after = {...held}..removeWhere((id, _) => taken.contains(id));
      if (after.length == held.length) return;
      if (after.isEmpty) {
        _bySource.remove(source);
      } else {
        _bySource[source] = after;
      }
    }
    notifyListeners();
  }

  /// Drops the marks of the extensions under [extensionKeys] (and their
  /// sub-keys), or every extension's: they are being unloaded, and put their
  /// marks again as they activate.
  void forget([Iterable<String>? extensionKeys]) {
    if (_disposed || _bySource.isEmpty) return;
    final before = _bySource.length;
    if (extensionKeys == null) {
      _bySource.clear();
    } else {
      final keys = extensionKeys.toSet();
      _bySource.removeWhere((source, _) => keys.contains(source) || keys.any((key) => source.startsWith('${key}_')));
    }
    if (_bySource.length != before) notifyListeners();
  }

  /// Every mark on a board spot carrying [ids] — one spot, or the several a
  /// merged row stands for — or null when none has any.
  SpotMarking? markingFor(Iterable<String> ids) {
    if (_bySource.isEmpty) return null;
    final icons = <({String icon, String? color})>[];
    final notes = <String>[];
    final hiddenBy = <String>{};
    String? firstColor, boostColor;
    var boost = 0.0;
    var any = false;
    // Every id a row stands for, not the first one marked: a merged row can
    // be several stations, and what an extension said about each one counts.
    for (final MapEntry(key: source, value: marks) in _bySource.entries) {
      for (final id in ids) {
        final mark = marks[id];
        if (mark == null) continue;
        any = true;
        if (mark.icon case final icon? when icons.every((seen) => seen.icon != icon)) icons.add((icon: icon, color: mark.color));
        if (mark.note case final note? when !notes.contains(note)) notes.add(note);
        firstColor ??= mark.color;
        if (mark.boost > boost) {
          boost = mark.boost;
          boostColor = mark.color;
        }
        if (mark.hidden) hiddenBy.add(source);
      }
    }
    return any ? (icons: icons, notes: notes, color: boost > 0 ? boostColor : firstColor, boost: boost, hiddenBy: hiddenBy) : null;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
