// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/cw_live_typing.dart';
import 'package:ham2k_logger/services/cat/drivers/cw_send_queue.dart';

void main() {
  late List<String> sent;
  late int stops;
  late ValueNotifier<CwSendProgress?> progress;
  late int doneCalls;
  late ValueNotifier<int> stopCount;

  /// A key in use that is busy from a send until the test says it drained.
  CwLiveTyping start() {
    sent = [];
    stops = 0;
    doneCalls = 0;
    progress = ValueNotifier(null);
    stopCount = ValueNotifier(0);
    return CwLiveTyping(
      send: (text) {
        sent.add(text);
        progress.value = CwSendProgress(id: sent.length, text: text, characterEnds: const []);
      },
      stop: () {
        stops++;
        stopCount.value++;
        progress.value = null;
      },
      busy: () => progress.value != null,
      progress: progress,
      stops: stopCount,
      onDone: () => doneCalls++,
    );
  }

  const shortOfPause = Duration(milliseconds: 400);

  test('an unfinished word waits for a pause, so a typo can still be fixed before it goes', () {
    fakeAsync((async) {
      final typing = start();
      typing.update('c');
      async.elapse(shortOfPause);
      typing.update('cw');
      async.elapse(shortOfPause);
      expect(sent, isEmpty, reason: 'typing steadily is not a pause, even with the key idle');
      expect(typing.update('c'), isTrue, reason: 'the W is still the operator\'s');
      typing.update('cq');
      async.elapse(cwLiveTypingDebounce);
      expect(sent, ['CQ']);
    });
  });

  test('a space hands the finished word over at once, and keeps the word being typed back', () {
    fakeAsync((async) {
      final typing = start();
      typing.update('cq ');
      expect(sent, ['CQ '], reason: 'a finished word has nothing left to fix; waiting would only delay it');
      progress.value = null;
      typing.update('cq de n0');
      expect(sent, ['CQ ', 'DE '], reason: 'N0 is half a callsign — handed over, it would key with a word gap inside it');
      progress.value = null;
      async.elapse(cwLiveTypingDebounce);
      expect(sent, ['CQ ', 'DE ', 'N0']);
    });
  });

  test('what is ready while the key is busy goes as ONE piece when it drains', () {
    fakeAsync((async) {
      final typing = start();
      typing.update('cq ');
      typing.update('cq de ');
      typing.update('cq de n0dev ');
      // The trap: a piece per word as each is finished. The key is busy, so
      // they wait, and go together the moment it is free.
      expect(sent, ['CQ ']);
      progress.value = null;
      expect(sent, ['CQ ', 'DE N0DEV ']);
      expect(typing.handedOff, typing.text.length);
    });
  });

  test('Backspace reaches what the keyer does not have yet, and never what it does', () {
    fakeAsync((async) {
      final typing = start();
      typing.update('cq ');
      typing.update('cq de');
      expect(typing.update('cq d'), isTrue, reason: '"DE" is still held: it is unfinished and the key is busy');
      expect(typing.text, 'CQ D');
      expect(typing.update('c'), isFalse, reason: 'CQ is on the radio, and no keyer here can take it back');
      expect(typing.text, 'CQ D');
      expect(typing.update('xq d'), isFalse, reason: 'an edit inside the handed-over part is the same thing');
    });
  });

  test('keeps only what the keyers can send, uppercased', () {
    fakeAsync((async) {
      final typing = start();
      typing.update('c!q#?');
      expect(typing.text, 'CQ?');
    });
  });

  test('spaces alone are held, and stay deletable', () {
    fakeAsync((async) {
      final typing = start();
      typing.update('k ');
      progress.value = null;
      typing.update('k  ');
      async.elapse(cwLiveTypingDebounce);
      expect(sent, ['K '], reason: 'the queue drops a bare space; sending it would claim a hand-off that keyed nothing');
      expect(typing.update('k '), isTrue);
    });
  });

  test('Enter hands over everything held at once, behind what is keying', () {
    fakeAsync((async) {
      final typing = start();
      typing.update('cq ');
      typing.update('cq test');
      typing.finish();
      // Without this, the tail would wait for a drain nothing is listening
      // for any more, and the operator's last word would never be keyed.
      expect(sent, ['CQ ', 'TEST']);
      expect(stops, 0);
      expect(typing.done, isTrue);
      expect(doneCalls, 1);
    });
  });

  test('Escape stops what is keying and drops what is held', () {
    fakeAsync((async) {
      final typing = start();
      typing.update('cq ');
      typing.update('cq test ');
      typing.cancel();
      expect(stops, 1);
      progress.value = null;
      async.elapse(cwLiveTypingDebounce);
      expect(sent, ['CQ '], reason: 'a drain after Escape must not key the held text');
      expect(doneCalls, 1);
    });
  });

  test('a stop from elsewhere drops every word, and leaves the mode on and empty', () {
    fakeAsync((async) {
      final typing = start();
      typing.update('cq ');
      typing.update('cq de n0dev ');
      // What CatKeying.stopCw does: counts the stop, THEN the queue empties
      // and reports quiet. The trap is that quiet read as "the key is free",
      // keying the held words right after the operator asked for silence —
      // a tap on the message, or Escape reaching the operation view first.
      stopCount.value++;
      progress.value = null;
      async.elapse(cwLiveTypingDebounce);
      expect(sent, ['CQ ']);
      expect(typing.done, isFalse, reason: 'the mode stays, ready for a fresh message');
      expect(typing.text, isEmpty);
      typing.update('k');
      async.elapse(cwLiveTypingDebounce);
      expect(sent, ['CQ ', 'K'], reason: 'what is typed after the stop is a fresh message');
    });
  });

  test('a refused keystroke still counts as the operator being there', () {
    fakeAsync((async) {
      final typing = start();
      typing.update('cq ');
      async.elapse(const Duration(seconds: 4));
      // Backspacing against what the keyer already has changes nothing, but
      // an operator doing it has not walked away.
      typing.update('cq');
      async.elapse(const Duration(seconds: 4));
      expect(typing.done, isFalse);
    });
  });

  test('five seconds without a keystroke ends keyboard mode the way Enter does', () {
    fakeAsync((async) {
      final typing = start();
      typing.update('cq ');
      async.elapse(const Duration(seconds: 4));
      typing.update('cq de');
      async.elapse(const Duration(seconds: 4));
      expect(typing.done, isFalse, reason: 'each keystroke restarts the wait');
      async.elapse(const Duration(seconds: 1));
      expect(typing.done, isTrue);
      expect(sent, ['CQ ', 'DE'], reason: 'a timeout is not an Escape: what was typed goes out');
    });
  });
}
