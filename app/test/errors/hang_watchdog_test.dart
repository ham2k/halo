// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The watchdog ends the process, so the one thing that must not be wrong is
// WHEN. Two mistakes are available, and they are opposites:
//
//  * treating a slow call as a wedged one, which kills an app somebody is
//    using — a connect waiting out a TCP timeout, a keychain prompt sitting
//    open while the operator reads it;
//  * treating a wedged isolate as a slow call, which is the bug it exists for.
//
// Both are decided by one choice — measuring SILENCE from a heartbeat rather
// than elapsed time on the call — and neither is visible anywhere else, since
// the mechanism's only output is a dead process.

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/hang_watchdog.dart';

void main() {
  group('when it fires', () {
    const silence = Duration(seconds: 20);
    const grace = Duration(seconds: 5);

    /// Runs [script] against [runWatchdog] with a hand-fed message stream,
    /// then goes quiet for [thenSilentFor], and reports whether the process
    /// was ended.
    bool firedAfter(Duration thenSilentFor, void Function(void Function(Object) say, FakeAsync async) script) {
      var fired = false;
      fakeAsync((async) {
        final messages = StreamController<Object?>();
        runWatchdog(messages.stream, silence: silence, grace: grace, onSilence: () => fired = true);
        script(messages.add, async);
        async.elapse(thenSilentFor);
        messages.close();
      });
      return fired;
    }

    test('an isolate that stops saying anything is ended', () {
      final fired = firedAfter(const Duration(seconds: 30), (say, async) {
        say(watchdogPing);
        async.elapse(const Duration(seconds: 1));
        // And then nothing at all: the shape of an FFI call that never
        // returns, which is not a slow call but an isolate that has stopped
        // running everything, this heartbeat included.
      });
      expect(fired, isTrue);
    });

    test('a call that is merely slow is left alone, for as long as it takes', () {
      // The false positive that matters. A connect can honestly sit for
      // seconds — a TCP timeout, a keychain prompt an operator is reading —
      // and killing the app under them would be a far worse bug than the one
      // being fixed. The isolate is alive throughout, and says so.
      final fired = firedAfter(const Duration(seconds: 1), (say, async) {
        for (var i = 0; i < 300; i++) {
          say(watchdogPing);
          async.elapse(const Duration(seconds: 1));
        }
      });
      expect(fired, isFalse);
    });

    test('a heartbeat that arrives just too late is still a live isolate', () {
      // The one silence a heartbeat cannot tell from a wedge is a SUSPENDED
      // process: sleep stops both isolates, and on wake the deadline is
      // already past due and races the first heartbeat with no ordering
      // between them. Staged as that race — the deadline runs out, and the
      // isolate is heard from immediately afterwards — because killing an app
      // for having been asleep is the worst thing this mechanism could do.
      final fired = firedAfter(const Duration(seconds: 1), (say, async) {
        say(watchdogPing);
        async.elapse(silence + const Duration(seconds: 1));
        // Awake again, and heart-beating as it did before.
        for (var i = 0; i < 30; i++) {
          say(watchdogPing);
          async.elapse(const Duration(seconds: 1));
        }
      });
      expect(fired, isFalse, reason: 'a resumed process was killed for having been asleep');
    });

    test('a call that came back is not chased afterwards', () {
      final fired = firedAfter(const Duration(minutes: 1), (say, async) {
        say(watchdogPing);
        async.elapse(const Duration(seconds: 2));
        say(watchdogDisarm);
        // The app goes on living, idle, with nothing guarded. Silence here
        // means nothing at all — most of a session is silence.
      });
      expect(fired, isFalse);
    });
  });

  group('what the guarded isolate says', () {
    late List<Object> said;
    late HangWatchdog watchdog;

    setUp(() {
      said = [];
      watchdog = HangWatchdog(said.add);
      HangWatchdog.installForTesting(watchdog);
      addTearDown(HangWatchdog.resetForTesting);
    });

    test('a guarded call is announced before it starts, not after', () async {
      // Arming on the first heartbeat tick instead would leave the call
      // unwatched for a second — and the call this guards can wedge on its
      // first instruction.
      final started = Completer<void>();
      final release = Completer<void>();
      final guarded = HangWatchdog.guard(() {
        started.complete();
        return release.future;
      });

      await started.future;
      expect(said, [watchdogPing]);

      release.complete();
      await guarded;
      expect(said.last, watchdogDisarm);
    });

    test('a guarded call keeps saying so, for as long as it lasts', () {
      // The whole false-positive defence is this heartbeat outrunning the
      // silence budget. Without it the arming ping is the only thing ever
      // sent, and every honest wait longer than that budget — a TCP timeout, a
      // keychain prompt an operator is reading — ends the process.
      fakeAsync((async) {
        final release = Completer<void>();
        unawaited(HangWatchdog.guard(() => release.future));
        async.elapse(watchdogSilence * 3);
        expect(said.where((m) => m == watchdogPing).length, greaterThan(3), reason: 'the guarded call went quiet while it was still running');
        release.complete();
        async.flushMicrotasks();
      });
    });

    test('a call that throws still puts the watchdog away', () async {
      // Otherwise one failed connect leaves the process a heartbeat away from
      // being killed for the rest of the session.
      await expectLater(HangWatchdog.guard(() async => throw StateError('the port is gone')), throwsStateError);
      expect(said.last, watchdogDisarm);
    });

    test('two overlapping calls disarm once, when the last of them is done', () async {
      // Two radios reconnect at the same time. The inner call finishing must
      // not tell the watchdog to stand down while the other is still inside a
      // call that may never return.
      final first = Completer<void>();
      final second = Completer<void>();
      final a = HangWatchdog.guard(() => first.future);
      final b = HangWatchdog.guard(() => second.future);

      first.complete();
      await a;
      expect(said, isNot(contains(watchdogDisarm)), reason: 'the other call is still in flight');

      second.complete();
      await b;
      expect(said.last, watchdogDisarm);
    });
  });
}
