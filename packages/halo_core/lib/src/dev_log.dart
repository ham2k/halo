// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:convert' show jsonEncode;

import 'app_clock.dart';

/// Dev-only structured, tagged logging. Bakes in the
/// "instrument + grep the console" pattern instead of sprinkling one-off
/// `debugPrint`s: [log] emits a stable `[tag] {json}` line to the console (so
/// `read_console_messages` picks it up) AND buffers the event so agents can
/// query recent history via `window.__halo.recentLog()` rather than only
/// streaming.
///
/// Pure Dart with no Flutter dependency, so every package (core, widgets, app)
/// can call it. Inert until [enabled] is set true — the app flips it on only in
/// dev builds (see `main()`), so release builds emit and buffer nothing, and
/// every call is a cheap early-return until then.
class DevLog {
  DevLog._();
  static final DevLog instance = DevLog._();

  /// Off by default. The app sets it true in dev/preview only, so nothing ships
  /// to release. While false, [log] is a no-op — no console output, no buffer.
  bool enabled = false;

  /// How many of the most recent events [recent] retains (a ring buffer, so a
  /// long session can't grow it without bound).
  int capacity = 500;

  final List<Map<String, Object?>> _buffer = [];

  /// Records a tagged structured event: prints `[tag] {json}` to the console
  /// and appends it to the queryable buffer. No-op unless [enabled].
  ///
  /// [data] must hold JSON-encodable values (strings/numbers/bools/null and
  /// lists/maps of those) — it's both console-serialized and returned to JS.
  void log(String tag, [Map<String, Object?>? data]) {
    if (!enabled) return;
    final entry = <String, Object?>{
      // Real time: these stamps exist to line log lines up with the operator's
      // wall clock and with console output from outside the app, which a
      // travelled clock would silently desynchronize.
      'ms': realNowMillis(),
      'tag': tag,
      ...?data,
    };
    _buffer.add(entry);
    if (_buffer.length > capacity) {
      _buffer.removeRange(0, _buffer.length - capacity);
    }
    // A log call must never take its caller down — if [data] violates the
    // JSON-encodable contract, fall back to toString rather than throwing
    // jsonEncode out of, say, QsosRepository.add after the QSO committed.
    try {
      print(data == null ? '[$tag]' : '[$tag] ${jsonEncode(data)}');
    } catch (_) {
      print('[$tag] $data');
    }
  }

  /// Buffered events, oldest-first — optionally filtered to a single [tag] and
  /// capped to the last [limit]. Returns copies so a caller can't mutate the
  /// buffer.
  List<Map<String, Object?>> recent({String? tag, int? limit}) {
    Iterable<Map<String, Object?>> events = _buffer;
    if (tag != null) events = events.where((e) => e['tag'] == tag);
    var list = events.toList();
    if (limit != null && list.length > limit) {
      list = list.sublist(list.length - limit);
    }
    return List<Map<String, Object?>>.unmodifiable(list.map(Map<String, Object?>.from));
  }

  /// Drops all buffered events.
  void clear() => _buffer.clear();
}
