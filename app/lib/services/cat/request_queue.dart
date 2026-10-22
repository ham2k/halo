// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// One request on the wire at a time, for a peer that answers questions and
// volunteers nothing — the HRD and DXLab Commander drivers.
//
// A question waits for its answer, or for [RequestQueue.answerTimeout]: a
// peer version that ignores one command must not stop every poll behind it
// for the life of the connection. A message that gets no answer by design
// (a set) is followed by a pause instead, so two messages never share a read
// on a peer that might parse only the first.
//
// A timeout is where the danger starts, not where it ends. An answer that
// arrives after its question was given up on would be read as the answer to
// the NEXT question — and on a peer whose replies do not say what they
// answer (HRD's `14074000`), every answer after it too, for good. So after a
// timeout nothing is sent for [quiet]: a late answer lands while nothing is
// outstanding and is dropped, and the next question starts in step. An
// answer later than the timeout and the quiet together still lands on the
// next question; the drivers' shape checks are the net under that.

import 'dart:async';

class RequestQueue<A> {
  final void Function(List<int> bytes) send;

  /// A question went unanswered — for a driver's diagnostic, its PTT-watch
  /// back-off, or a retry, which waits out the drain like everything else.
  final void Function(A ask) onUnanswered;

  final Duration answerTimeout;
  final Duration quiet;

  RequestQueue({required this.send, required this.onUnanswered, required this.answerTimeout, required this.quiet});

  final _pending = <_Request<A>>[];
  _Request<A>? _outstanding;
  Timer? _timer;
  bool _draining = false;

  /// The question on the wire, or null — also null while a set's pause runs.
  A? get outstanding => _outstanding?.expectsAnswer == true ? _outstanding!.ask : null;

  /// Whether anything is waiting behind the request on the wire. One in
  /// flight and nothing waiting is a healthy session, not a backlog — see
  /// FlrigSession._requestFrequencyAndMode.
  bool get backlogged => _pending.isNotEmpty;

  /// Whether [ask] is on the wire or waiting.
  bool holds(A ask) => _outstanding?.ask == ask || _pending.any((r) => r.ask == ask);

  /// Queues a question. [build] runs when it is SENT, so it sees whatever the
  /// answers ahead of it taught the session; null drops it. [first] puts it
  /// ahead of everything waiting.
  void ask(A ask, List<int>? Function() build, {bool first = false}) => _add(_Request(ask, build, expectsAnswer: true), first: first);

  /// Queues a message the peer does not answer, followed by [gap]. [first]
  /// puts it ahead of everything waiting, as for [ask].
  void tell(A ask, List<int>? Function() build, {required Duration gap, bool first = false}) =>
      _add(_Request(ask, build, expectsAnswer: false, gap: gap), first: first);

  void _add(_Request<A> request, {required bool first}) {
    first ? _pending.insert(0, request) : _pending.add(request);
    _pump();
  }

  /// A whole reply arrived. Answers the question it belongs to, or null when
  /// nothing is waiting for one — a late answer, or one to a set. The caller
  /// handles the reply and then calls [settle].
  A? replyArrived() => outstanding;

  /// The outstanding question is answered; the next request goes out.
  void settle() {
    if (_outstanding?.expectsAnswer != true) return;
    _next();
  }

  void _next() {
    _timer?.cancel();
    _timer = null;
    _outstanding = null;
    _pump();
  }

  void _pump() {
    while (_outstanding == null && !_draining && _pending.isNotEmpty) {
      final request = _pending.removeAt(0);
      final bytes = request.build();
      if (bytes == null) continue;
      _outstanding = request;
      if (request.expectsAnswer) {
        _timer = Timer(answerTimeout, _gaveUp);
      } else {
        _timer = Timer(request.gap, _next);
      }
      send(bytes);
    }
  }

  void _gaveUp() {
    final request = _outstanding;
    _timer = null;
    _outstanding = null;
    // Draining, and its end armed, before the callback: a retry it queues
    // must wait out the late answer like everything else, and a callback
    // that throws must not leave the queue draining for good.
    _draining = true;
    _timer = Timer(quiet, () {
      _timer = null;
      _draining = false;
      _pump();
    });
    if (request != null) onUnanswered(request.ask);
  }

  /// Forgets everything, for a new connection.
  void clear() {
    _timer?.cancel();
    _timer = null;
    _pending.clear();
    _outstanding = null;
    _draining = false;
  }
}

class _Request<A> {
  final A ask;
  final List<int>? Function() build;
  final bool expectsAnswer;
  final Duration gap;

  _Request(this.ask, this.build, {required this.expectsAnswer, this.gap = Duration.zero});
}

/// A PTT watch on a peer that may not answer it: some radios behind HRD or
/// Commander have no readable PTT, and each unanswered question holds the
/// wire for a whole answer timeout while the frequency poll waits behind it.
///
/// After [misses] unanswered in a row the watch asks only every [slowEvery]
/// ticks, and one answer puts it back to every tick. It slows rather than
/// stops: a peer that was merely busy for a few seconds keeps its PTT.
class WatchBackoff {
  final int misses;
  final int slowEvery;

  WatchBackoff({this.misses = 2, this.slowEvery = 25});

  int _missed = 0;
  int _skipped = 0;

  /// Whether this tick of the watch should ask.
  bool shouldAsk() {
    if (_missed < misses) return true;
    if (++_skipped < slowEvery) return false;
    _skipped = 0;
    return true;
  }

  void answered() {
    _missed = 0;
    _skipped = 0;
  }

  void unanswered() => _missed++;

  void reset() => answered();
}
