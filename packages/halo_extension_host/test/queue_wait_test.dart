// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Two things: what a caller is left holding when arguments the core cannot
// encode reach it, and the queue-wait summary's aggregation.
//
// What is NOT here is the queue measurement end to end. It is only ever
// non-zero when the core runs on its own isolate, and this suite cannot reach
// that — as extension_host_test.dart's header records, isolates and FFI don't
// mix reliably inside flutter_test, so every host here runs the core
// in-process, where dispatch is synchronous and the wait is genuinely zero.
// A test asserting "the wait is small" would therefore pass whether or not
// any of the plumbing worked, so there isn't one; the aggregation is covered
// instead, through a seam that takes samples directly.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:halo_extension_host/src/hook_call_stats.dart';

import 'support/bundles.dart';

HookCallSample _sample(String label, int queueMicros) => HookCallSample(label: label, totalMillis: 0, jsMillis: 0, queueMicros: queueMicros);

/// Something `jsonEncode` cannot take and that no `toJson` rescues.
class _Unencodable {
  const _Unencodable();
}

void main() {
  requireBundles();

  group('arguments the caller cannot encode', () {
    // The args are encoded by the CORE now, not by the caller, so the failure
    // happens across a bridge with nobody on the far side to turn a throw
    // back into an answer. These pin what a caller is left holding, because
    // every caller of a hook degrades quietly — a wrong answer here is a
    // feature that stops working with nothing on screen and nothing in the
    // log that names it.
    test('reach the caller as an error naming the hook, not as a timeout', () async {
      final host = await sharedHost(['lookups']);

      await expectLater(
        host.invokeHook('lookup', method: 'lookupCall', args: {'bad': const _Unencodable()}),
        throwsA(
          isA<ExtensionHostException>()
              // NOT a HookTimeoutException: before the encode moved, this
              // threw on the caller's own isolate. If the failure ever
              // becomes a timeout instead, a caller waits the full 10s and
              // is then told the extension was slow, which is a lie that
              // sends the reader to the wrong side of the bridge entirely.
              .having((e) => e.toString(), 'message', contains('lookup.lookupCall'))
              .having((e) => e.toString(), 'message', contains('not JSON-encodable')),
        ),
      );
    });

    test('do not stop the host answering the next call', () async {
      // The failing call is settled through the same path a normal result
      // takes; if it stopped short of that, the runtime would keep counting
      // it as outstanding and the pump would spin for the rest of the
      // session.
      final host = await sharedHost(['lookups']);

      await expectLater(host.invokeHook('lookup', method: 'lookupCall', args: {'bad': const _Unencodable()}), throwsA(isA<ExtensionHostException>()));

      final echo = await host.invokeHook('bench', key: 'kernel', method: 'echo', args: {'x': 1});
      expect(echo, {'x': 1});
    });
  });
  test('ranks by the worst wait, not the mean', () {
    // Built so the two orderings DISAGREE, which is the only way this test
    // can catch a mean-based sort: `chatty` waits moderately every time
    // (mean 500ms), while `rare` is almost always instant and stalled once
    // (mean 45ms) — but that one stall is the second an operator felt.
    final stats = summarizeQueueWaits([
      for (var i = 0; i < 20; i++) _sample('chatty', 500 * 1000),
      _sample('rare', 900 * 1000),
      for (var i = 0; i < 19; i++) _sample('rare', 0),
    ]);

    expect(stats.first.meanMicros, lessThan(stats.last.meanMicros));

    expect(stats.first.label, 'rare');
    expect(stats.first.worstMicros, 900 * 1000);
    expect(stats.last.label, 'chatty');
  });

  test('groups per label, counting every call and averaging over all of them', () {
    final stats = summarizeQueueWaits([
      _sample('scoring.scoreQsos', 100 * 1000),
      _sample('scoring.scoreQsos', 300 * 1000),
      _sample('lookup.lookupCall', 20 * 1000),
    ]);

    final scoring = stats.firstWhere((s) => s.label == 'scoring.scoreQsos');
    expect(scoring.calls, 2);
    expect(scoring.worstMicros, 300 * 1000);
    // Averaged over the label's calls, not over the sample list: a hook that
    // waits once out of many is not the same as one that always waits, and
    // dividing by the wrong denominator makes them read alike.
    expect(scoring.meanMicros, 200 * 1000);

    expect(stats.firstWhere((s) => s.label == 'lookup.lookupCall').calls, 1);
  });

  test('a label whose calls never waited still reports, at zero', () {
    // Absence of a wait is an answer — "this hook is not the problem" — and
    // dropping the row would make a quiet hook indistinguishable from one
    // that was never called.
    final stats = summarizeQueueWaits([_sample('instant', 0), _sample('instant', 0)]);

    expect(stats, hasLength(1));
    expect(stats.single.calls, 2);
    expect(stats.single.worstMicros, 0);
    expect(stats.single.meanMicros, 0);
  });

  test('no samples is an empty summary, not a crash', () {
    expect(summarizeQueueWaits([]), isEmpty);
  });
}
