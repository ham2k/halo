// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/drivers/cw_send_queue.dart';

void main() {
  group('sanitizeCwText', () {
    test('uppercases, and drops what neither keyer has a code for', () {
      // A prosign in angle brackets is the likeliest thing an operator types
      // that the radios' documented character sets do not include.
      expect(sanitizeCwText('cq de n0dev <ar>'), 'CQ DE N0DEV AR');
    });

    test('collapses whitespace and trims, so a gap is never keyed twice', () {
      expect(sanitizeCwText('  cq   cq \n de  '), 'CQ CQ DE');
    });

    test('keeps the punctuation both keyers accept', () {
      expect(sanitizeCwText('5nn? tu = k+'), '5NN? TU = K+');
    });
  });

  group('splitCwText', () {
    test('cuts on word boundaries, never mid-word while a word fits', () {
      expect(splitCwText('CQ CQ CQ DE N0DEV N0DEV N0DEV K', 30), ['CQ CQ CQ DE N0DEV N0DEV N0DEV', 'K']);
    });

    test('a word longer than the chunk is cut where it must be', () {
      expect(splitCwText('ABCDEFGHIJ KL', 4), ['ABCD', 'EFGH', 'IJ', 'KL']);
    });

    test('nothing sendable yields no chunks, so an empty message keys nothing', () {
      expect(splitCwText('', 30), isEmpty);
    });
  });

  group('cwDuration', () {
    test('PARIS is the 50-unit word the WPM definition is built on', () {
      // 43 dits of elements and gaps plus the 7-dit word gap this
      // function always appends; at 20 WPM a dit is 60 ms.
      expect(cwDuration('PARIS', 20), const Duration(milliseconds: 3000));
      expect(cwDuration('PARIS', 40), const Duration(milliseconds: 1500));
    });

    test('a space is a seven-dit gap, replacing the three-dit character gap', () {
      // E E: 1 + 3 + 1 = 5 dits, +7 trailing = 12. E<space>E: 1 + 7 + 1 = 9,
      // +7 = 16.
      expect(cwDuration('EE', 20), const Duration(milliseconds: 720));
      expect(cwDuration('E E', 20), const Duration(milliseconds: 960));
    });
  });

  group('cwCharacterEnds', () {
    test('each character ends when its last element does, gaps charged to what follows', () {
      // E (1 dit), then a 3-dit gap, then T (3 dits): E ends at 1, T at 7.
      expect(cwCharacterEnds('ET', 20), [const Duration(milliseconds: 60), const Duration(milliseconds: 420)]);
      // A space is the 7-dit word gap, and the next character pays no
      // character gap on top of it.
      expect(cwCharacterEnds('E E', 20), [const Duration(milliseconds: 60), const Duration(milliseconds: 480), const Duration(milliseconds: 540)]);
    });

    test('the last end is the message\'s length without the trailing word gap', () {
      // PARIS is 43 dits of elements and gaps; cwDuration adds the 7-dit
      // trailing gap the pacing needs, a progress bar should not.
      expect(cwCharacterEnds('PARIS', 20).last, const Duration(milliseconds: 2580));
      expect(cwDuration('PARIS', 20) - cwCharacterEnds('PARIS', 20).last, const Duration(milliseconds: 420));
    });

    test('sentAt counts the characters finished by then', () {
      final progress = CwSendProgress(id: 1, text: 'ET', characterEnds: cwCharacterEnds('ET', 20));
      expect(progress.sentAt(Duration.zero), 0);
      expect(progress.sentAt(const Duration(milliseconds: 60)), 1);
      expect(progress.sentAt(const Duration(milliseconds: 419)), 1);
      expect(progress.sentAt(const Duration(seconds: 1)), 2);
      expect(progress.total, const Duration(milliseconds: 420));
    });
  });

  group('CwSendQueue progress', () {
    test('reports each message as it starts, and null once the queue is silent', () {
      fakeAsync((async) {
        final reports = <CwSendProgress?>[];
        final queue = CwSendQueue(maxChunkLength: 30, send: (_) {}, speedWpm: () => 20, onProgress: reports.add);

        queue.enqueue('cq test');
        queue.enqueue('k');
        // The second is shown behind the first the moment it is pressed —
        // as a re-report of the first (same id, so nothing restarts), not as
        // its own start.
        expect(reports.map((r) => r?.text), ['CQ TEST', 'CQ TEST']);
        expect(reports.map((r) => r?.id), [1, 1]);
        expect(reports.first!.pending, isEmpty);
        expect(reports.last!.pending, ['K']);
        expect(reports.last!.characterEnds, cwCharacterEnds('CQ TEST', 20));

        async.elapse(cwDuration('CQ TEST', 20));
        expect(reports.map((r) => r?.text), ['CQ TEST', 'CQ TEST', 'K'], reason: 'the next replaces, no null between');
        expect(reports.last!.id, 2);
        expect(reports.last!.pending, isEmpty);

        async.flushTimers();
        expect(reports.map((r) => r?.text), ['CQ TEST', 'CQ TEST', 'K', null]);
      });
    });

    test('a message split into chunks is reported ONCE, as a whole', () {
      fakeAsync((async) {
        final reports = <CwSendProgress?>[];
        final queue = CwSendQueue(maxChunkLength: 5, send: (_) {}, speedWpm: () => 20, onProgress: reports.add);

        queue.enqueue('EEE EEE');
        async.flushTimers();
        expect(reports.map((r) => r?.text), ['EEE EEE', null]);
      });
    });

    test('dropPending removes one waiting message and re-reports the rest', () {
      fakeAsync((async) {
        final reports = <CwSendProgress?>[];
        final queue = CwSendQueue(maxChunkLength: 30, send: (_) {}, speedWpm: () => 20, onProgress: reports.add);
        queue.enqueue('CQ');
        queue.enqueue('5NN');
        queue.enqueue('TU');
        expect(reports.last!.pending, ['5NN', 'TU']);

        expect(reports.last!.pendingIds, [2, 3]);
        queue.dropPending(2);
        expect(reports.last!.pending, ['TU']);
        expect(reports.last!.id, 1, reason: 'the message keying is untouched');
        final count = reports.length;
        queue.dropPending(2);
        expect(reports.length, count, reason: 'an id no longer waiting drops nothing, and says nothing');

        async.flushTimers();
        expect(reports.map((r) => r?.text), ['CQ', 'CQ', 'CQ', 'CQ', 'TU', null], reason: '5NN never went out');
      });
    });

    test('dropAllPending keeps the chunk on the radio in the report — for a keyer nothing can interrupt', () {
      fakeAsync((async) {
        final reports = <CwSendProgress?>[];
        final sent = <String>[];
        final chunked = CwSendQueue(maxChunkLength: 5, send: sent.add, speedWpm: () => 20, onProgress: reports.add);
        chunked.enqueue('EEE EEE EEE');
        chunked.enqueue('TU');
        chunked.dropAllPending();
        expect(reports.last!.text, 'EEE EEE EEE', reason: 'its first chunk is still going out on the radio');
        expect(reports.last!.pending, isEmpty);
        expect(chunked.sending, isTrue);
        async.flushTimers();
        expect(sent, ['EEE'], reason: 'the rest of the message is not written behind the playing chunk');
        expect(reports.last, isNull);
        expect(chunked.sending, isFalse);
      });
    });

    test('clear reports silence, and nothing sendable reports nothing at all', () {
      fakeAsync((async) {
        final reports = <CwSendProgress?>[];
        final queue = CwSendQueue(maxChunkLength: 30, send: (_) {}, speedWpm: () => 20, onProgress: reports.add);

        queue.enqueue('<>');
        expect(reports, isEmpty);
        queue.clear();
        expect(reports, isEmpty, reason: 'nothing was sending, so nothing stopped');

        queue.enqueue('CQ');
        queue.clear();
        expect(reports.map((r) => r?.text), ['CQ', null]);
      });
    });
  });

  group('CwSendQueue', () {
    test('sends what fits now and the rest only once the first chunk has keyed', () {
      fakeAsync((async) {
        final sent = <String>[];
        final queue = CwSendQueue(maxChunkLength: 5, send: sent.add, speedWpm: () => 20);

        queue.enqueue('EEE EEE');

        expect(sent, ['EEE']);
        expect(queue.sending, isTrue);
        // EEE = 1+3+1+3+1 = 9 dits, +7 = 16 dits = 960 ms at 20 WPM. The
        // trap is sending the second chunk early — the radio NAKs it.
        async.elapse(const Duration(milliseconds: 900));
        expect(sent, ['EEE']);
        async.elapse(const Duration(milliseconds: 100));
        expect(sent, ['EEE', 'EEE']);
        expect(queue.sending, isTrue, reason: 'the second chunk is keying now');

        async.elapse(const Duration(seconds: 1));
        expect(queue.sending, isFalse);
      });
    });

    test('a message queued while one is going out waits its turn', () {
      fakeAsync((async) {
        final sent = <String>[];
        final queue = CwSendQueue(maxChunkLength: 10, send: sent.add, speedWpm: () => 20);

        queue.enqueue('E');
        queue.enqueue('T');
        expect(sent, ['E'], reason: 'T is behind E, not on top of it');

        async.elapse(const Duration(seconds: 1));
        expect(sent, ['E', 'T']);
        async.flushTimers();
      });
    });

    test('paces at the default speed until the radio has said otherwise', () {
      fakeAsync((async) {
        final sent = <String>[];
        final queue = CwSendQueue(maxChunkLength: 3, send: sent.add, speedWpm: () => null);

        queue.enqueue('EEE EEE');
        expect(cwDuration('EEE', defaultCwSpeedWpm), const Duration(milliseconds: 960));
        async.elapse(const Duration(milliseconds: 959));
        expect(sent, hasLength(1));
        async.elapse(const Duration(milliseconds: 1));
        expect(sent, hasLength(2));
        async.flushTimers();
      });
    });

    test('clear drops what is still waiting and stops claiming to send', () {
      fakeAsync((async) {
        final sent = <String>[];
        final queue = CwSendQueue(maxChunkLength: 3, send: sent.add, speedWpm: () => 20);

        queue.enqueue('EEE EEE EEE');
        queue.clear();
        expect(queue.sending, isFalse);

        async.elapse(const Duration(seconds: 10));
        expect(sent, ['EEE'], reason: 'the chunks behind the first never go out');
      });
    });
  });
}
