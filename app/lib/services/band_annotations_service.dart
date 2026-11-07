// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The band annotations the app holds for its panels (docs/extensions/spots.md
// § Band annotations): those extensions put, the operator's own band tags, and
// what the `bandAnnotations` hooks answer for a band. Kept beside the spots
// (SpotsService.bandAnnotations), but a change here says nothing about the
// spots: it repaints the panels that draw annotations and judges no spot again.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:halo_core/halo_core.dart';

import 'error_reporting_service.dart';

/// What the `bandAnnotations` hooks said about a band: their annotations as
/// held, each with its `source`, and whether every hook answered — one that
/// failed or missed its time is asked again.
typedef BandAnnotationsAnswer = ({List<Map<String, dynamic>> items, bool complete});

/// Asks every `bandAnnotations` hook for [band], at [station]'s location
/// where one is known (ExtensionService.getBandAnnotations); null when no
/// hook was there to ask.
typedef BandAnnotationsFetch = Future<BandAnnotationsAnswer?> Function({required String band, String? station});

class BandAnnotationsService extends ChangeNotifier {
  BandAnnotationsService({this.fetch, this.hooksSettled}) {
    hooksSettled?.addListener(_askShortAnswersAgain);
  }

  /// Null asks no hook: only what was put is held.
  final BandAnnotationsFetch? fetch;

  /// Fires when the extensions' hooks are all in place, as a runtime finishes
  /// activating them (ExtensionService.runtimeGeneration). A band asked before
  /// then, as an operation opening at launch asks its own, is short of the
  /// hooks not yet in place, and is asked again then rather than
  /// [askAgainAfter] later, and one that found no hook at all to ask is
  /// asked only then.
  final Listenable? hooksSettled;

  /// How long a band whose hooks did not all answer waits before they are
  /// asked again, unprompted: soon enough that a plan missed on a busy boot
  /// comes back while the dial sits still, not so soon that a broken hook is
  /// asked on every repaint.
  static const askAgainAfter = Duration(seconds: 30);

  final _store = BandAnnotationStore();

  /// The hooks' answers by band and station, and the questions out to them.
  final _answers = <String, List<Map<String, dynamic>>>{};
  final _asking = <String>{};

  /// The questions whose answer is short of some hook's, each asked again
  /// when its timer fires.
  final _askAgain = <String, Timer>{};

  /// The questions that found no hook to ask, each asked as [hooksSettled]
  /// fires. No timer: until the hooks change, one would only find none again,
  /// and leave a band with no plan extension asking nobody every while.
  final _waiting = <String>{};

  /// Bumped when the hooks' answers are forgotten, so an answer to a question
  /// asked before is not kept: it came from a runtime that is gone.
  var _generation = 0;

  Timer? _expiry;
  var _disposed = false;

  /// Every annotation on [band] for [station]: those put, and the hooks'. The
  /// first read of a band asks the hooks, in the background — the caller may be
  /// a hook itself, which must not wait on another — and the listeners hear
  /// when they answer. The band and the callsign are taken in any case: one
  /// band asked for as `20M` and read as `20m` is asked once.
  List<Map<String, dynamic>> forBand(String band, {String? station}) {
    band = band.trim().toLowerCase();
    final call = station?.trim().toUpperCase();
    station = call == null || call.isEmpty ? null : call;
    final question = '$band|${station ?? ''}';
    if (!_answers.containsKey(question)) unawaited(_ask(question, band, station));
    final now = nowMillis();
    return [
      ..._store.forBand(band, now: now),
      for (final annotation in _answers[question] ?? const <Map<String, dynamic>>[])
        if ((annotation['expiresAt'] as int? ?? now + 1) > now) annotation,
    ];
  }

  Future<void> _ask(String question, String band, String? station) async {
    final fetch = this.fetch;
    if (fetch == null || _disposed || !_asking.add(question)) return;
    final generation = _generation;
    try {
      final answer = await fetch(band: band, station: station);
      if (_disposed || generation != _generation) return;
      if (answer == null) {
        _answers.putIfAbsent(question, () => const []);
        _waiting.add(question);
        return;
      }
      ErrorReportingService.recordSuccess('bandAnnotations:ask');
      final had = _answers[question];
      final now = nowMillis();
      // Expired as it is said, it would be dropped and asked for again at
      // once, and say the same, without end.
      final items = [
        for (final item in answer.items)
          if ((item['expiresAt'] as int? ?? now + 1) > now) item,
      ];
      _answers[question] = items;
      if (answer.complete) {
        _askAgain.remove(question)?.cancel();
      } else {
        _askAgainLater(question, band, station);
      }
      _scheduleExpiry();
      // Nothing said, and nothing taken back, adds nothing to repaint.
      if (items.isNotEmpty || (had?.isNotEmpty ?? false)) notifyListeners();
    } catch (e, stack) {
      if (_disposed || generation != _generation) return;
      // What answered before stands; asked again later rather than on every
      // read, which a panel repainting each tick would turn into a flood.
      _answers.putIfAbsent(question, () => const []);
      _askAgainLater(question, band, station);
      ErrorReportingService.reportIfRepeated('bandAnnotations:ask', e, stack, context: 'bandAnnotations:ask $band');
    } finally {
      if (generation == _generation) _asking.remove(question);
    }
  }

  void _askAgainLater(String question, String band, String? station) {
    _askAgain.remove(question)?.cancel();
    _askAgain[question] = Timer(askAgainAfter, () {
      _askAgain.remove(question);
      unawaited(_ask(question, band, station));
    });
  }

  void _askShortAnswersAgain() {
    for (final question in {..._askAgain.keys, ..._waiting}) {
      _askAgain.remove(question)?.cancel();
      _waiting.remove(question);
      final [band, station] = question.split('|');
      unawaited(_ask(question, band, station.isEmpty ? null : station));
    }
  }

  /// Puts [annotations] under [source], replacing those with the same keys.
  /// Throws [FormatException] for a malformed one, putting none.
  void put(String source, List<Object?> annotations) {
    if (_disposed) return;
    _store.put(source, annotations);
    _scheduleExpiry();
    notifyListeners();
  }

  /// Takes [source]'s annotations under [keys], or all of them.
  void remove(String source, [Iterable<String>? keys]) {
    if (_disposed || !_store.remove(source, keys)) return;
    notifyListeners();
  }

  /// Takes the annotations [test] picks from [source].
  void removeWhere(String source, bool Function(Map<String, dynamic> annotation) test) {
    if (_disposed || !_store.removeWhere(source, test)) return;
    notifyListeners();
  }

  /// Forgets what the extensions keyed [sources] put, every one's when null,
  /// and every hook's answers, which are asked for again: a runtime replaced
  /// may hold another set of extensions, and one reloaded says what its new
  /// code says, those that remain putting theirs again as they activate. The
  /// operator's own stay.
  void forgetExtensions([Iterable<String>? sources]) {
    if (_disposed) return;
    _generation++;
    _asking.clear();
    for (final timer in _askAgain.values) {
      timer.cancel();
    }
    _askAgain.clear();
    _waiting.clear();
    final had = _answers.isNotEmpty;
    _answers.clear();
    final taken = sources?.toSet();
    final removed = _store.removeSourcesWhere((source) => source != userBandAnnotationSource && (taken == null || taken.contains(source)));
    if (removed || had) notifyListeners();
  }

  /// The listeners hear when the next annotation expires, so what draws them
  /// takes it down then rather than at its next repaint. A hook's answer that
  /// expires is asked for again: what it says next is the band's now.
  void _scheduleExpiry() {
    _expiry?.cancel();
    var next = _store.nextExpiry;
    for (final answers in _answers.values) {
      for (final annotation in answers) {
        final at = annotation['expiresAt'] as int?;
        if (at != null && (next == null || at < next)) next = at;
      }
    }
    if (next == null) return;
    // A timer's longest: a browser fires one past it at once, and this one
    // would set itself again, without end. Written out, as `1 << 31` is one
    // past it on the web.
    _expiry = Timer(Duration(milliseconds: (next - nowMillis()).clamp(0, 2147483647)), () {
      if (_disposed) return;
      final now = nowMillis();
      var changed = _store.dropExpired(now);
      for (final question in [..._answers.keys]) {
        final answers = _answers[question]!;
        final standing = [
          for (final a in answers)
            if ((a['expiresAt'] as int? ?? now + 1) > now) a,
        ];
        if (standing.length == answers.length) continue;
        _answers[question] = standing;
        final [band, station] = question.split('|');
        unawaited(_ask(question, band, station.isEmpty ? null : station));
        changed = true;
      }
      if (changed) notifyListeners();
      _scheduleExpiry();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    hooksSettled?.removeListener(_askShortAnswersAgain);
    _expiry?.cancel();
    for (final timer in _askAgain.values) {
      timer.cancel();
    }
    super.dispose();
  }
}
