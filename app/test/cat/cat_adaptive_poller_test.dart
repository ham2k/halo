// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The poll cadence, which exists because of what a live FT-891 costs on the
// wire: a poll cycle is 50ms at 4800 baud, and one pushed `IF` frame is 58ms
// — MORE than a whole poll. So the moment polling would be most expensive
// (a dial being spun, with transceive pushing every step) is exactly the
// moment it is redundant.

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/adaptive_poller.dart';

void main() {
  test('a radio nobody is touching is polled at the slow rate', () {
    fakeAsync((async) {
      var polls = 0;
      final poller = AdaptivePoller(onPoll: () => polls++)..start();
      addTearDown(poller.stop);

      async.elapse(const Duration(seconds: 9));
      // Three seconds apart, not two hundred milliseconds: an idle radio
      // must cost nothing.
      expect(polls, 3);
      expect(poller.interval, kPollSlow);
    });
  });

  test('a moving radio is polled fast', () {
    fakeAsync((async) {
      var polls = 0;
      final poller = AdaptivePoller(onPoll: () => polls++)..start();
      addTearDown(poller.stop);

      poller.noteChange();
      expect(poller.interval, kPollFast);

      async.elapse(const Duration(seconds: 1));
      // ~5 polls a second while the dial moves, rather than one every three.
      expect(polls, greaterThanOrEqualTo(4));
    });
  });

  test('it eases back off once the radio settles', () {
    fakeAsync((async) {
      var polls = 0;
      final poller = AdaptivePoller(onPoll: () => polls++)..start();
      addTearDown(poller.stop);

      poller.noteChange();
      expect(poller.interval, kPollFast);

      // Nothing new for a while. Geometric, so it reaches the slow rate
      // without a long tail of nearly-fast polls on the way.
      async.elapse(const Duration(seconds: 10));
      expect(poller.interval, kPollSlow);

      final settled = polls;
      async.elapse(const Duration(seconds: 9));
      expect(polls - settled, 3, reason: 'back to one poll every three seconds');
    });
  });

  test('a radio that keeps talking is never polled at all', () {
    fakeAsync((async) {
      var polls = 0;
      final poller = AdaptivePoller(onPoll: () => polls++)..start();
      addTearDown(poller.stop);

      // Transceive pushing a frame every 100ms — a dial being spun. Each one
      // defers the next poll, so the whole turn costs zero polls. Polling on
      // top of this is what would queue behind the pushed frames and delay
      // our own tune commands.
      for (var i = 0; i < 50; i++) {
        poller.noteData();
        poller.noteChange();
        async.elapse(const Duration(milliseconds: 100));
      }
      expect(polls, 0);

      // And when the operator stops, polling resumes — because transceive is
      // a radio-side setting that can be switched off, and nothing in CAT
      // lets us read back whether it is on.
      async.elapse(const Duration(seconds: 1));
      expect(polls, greaterThan(0));
    });
  });

  test('data alone defers a poll without speeding it up', () {
    fakeAsync((async) {
      var polls = 0;
      final poller = AdaptivePoller(onPoll: () => polls++)..start();
      addTearDown(poller.stop);

      // An answer that says the same thing as last time is still an answer:
      // it defers the next question, but it is not the radio moving.
      async.elapse(const Duration(seconds: 2));
      poller.noteData();
      expect(poller.interval, kPollSlow, reason: 'a repeat is not a move');
      async.elapse(const Duration(seconds: 2));
      expect(polls, 0, reason: 'the timer restarted when the data arrived');

      async.elapse(const Duration(seconds: 2));
      expect(polls, 1);
    });
  });

  test('stop means stop, including from inside a poll', () {
    fakeAsync((async) {
      var polls = 0;
      late final AdaptivePoller poller;
      poller = AdaptivePoller(
        onPoll: () {
          polls++;
          poller.stop();
        },
      )..start();

      async.elapse(const Duration(seconds: 30));
      // A driver tearing down inside its own poll callback must not leave a
      // timer running against a dead connection.
      expect(polls, 1);
      expect(poller.isRunning, isFalse);
    });
  });

  test('a radio that chatters forever is still asked directly, eventually', () {
    fakeAsync((async) {
      var polls = 0;
      final poller = AdaptivePoller(onPoll: () => polls++)..start();
      addTearDown(poller.stop);

      // Data with no change: a rig repeating one frame, or line noise
      // decoding to a steady drip. noteData defers the poll, and without a
      // ceiling it would defer it for the life of the connection — leaving
      // the backstop for "transceive is off or lying" permanently unarmed.
      for (var i = 0; i < 600; i++) {
        poller.noteData();
        async.elapse(const Duration(milliseconds: 100));
      }
      expect(polls, greaterThan(0), reason: 'the ceiling fired despite constant deferral');
    });
  });

  test('a callback that throws does not end polling', () {
    fakeAsync((async) {
      var polls = 0;
      final poller = AdaptivePoller(
        onPoll: () {
          polls++;
          if (polls == 1) throw StateError('a write to a port that just went away');
        },
      )..start();
      addTearDown(poller.stop);

      // Timer.periodic, which this replaced, would have fired again next
      // interval. Losing the reschedule here would stop the radio being
      // polled for the life of the connection, silently, with the UI still
      // showing it connected.
      async.elapse(const Duration(seconds: 10));
      expect(polls, greaterThan(1));
    });
  });

  test('starting again resets a raised interval', () {
    fakeAsync((async) {
      final poller = AdaptivePoller(onPoll: () {})..start();
      addTearDown(poller.stop);

      poller.noteChange();
      expect(poller.interval, kPollFast);

      // A resync, or a session reused across a reconnect. Without this the
      // already-running guard skipped the reset and a stationary radio was
      // polled at 200ms indefinitely.
      poller.start();
      expect(poller.interval, kPollSlow);
    });
  });
}
