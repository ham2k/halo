// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The queue's own promises, apart from any driver: what the HRD and
// Commander sessions rely on when a question goes unanswered.

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/request_queue.dart';

void main() {
  test('a callback that throws on a timeout does not leave the queue draining for good', () {
    fakeAsync((async) {
      final sent = <int>[];
      final errors = <Object>[];
      late RequestQueue<String> queue;
      runZonedGuarded(() {
        queue = RequestQueue<String>(
          send: (bytes) => sent.addAll(bytes),
          onUnanswered: (_) => throw StateError('a driver bug'),
          answerTimeout: const Duration(seconds: 1),
          quiet: const Duration(milliseconds: 500),
        );
        queue.ask('first', () => [1]);
      }, (error, _) => errors.add(error));
      async.elapse(const Duration(seconds: 1));
      expect(errors.single, isStateError);
      queue.ask('second', () => [2]);
      async.elapse(const Duration(milliseconds: 600));
      // Stuck draining, the queue would never send again: every poll and
      // every set held for the life of the connection.
      expect(sent, [1, 2]);
    });
  });
}
