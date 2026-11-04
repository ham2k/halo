// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The engine's busy-time accounting: how spans become buckets, how buckets
// read back as idle, and that a real hook's time lands under its own name.

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart' show realNowUtc;
import 'package:halo_extension_host/halo_extension_host.dart' show ExtensionBundle, ExtensionHost;
import 'package:halo_extension_host/src/engine_load.dart';

import 'support/bundles.dart';

const _ms = 1000;

/// Bucket boundaries in real use are epoch-aligned; a round base keeps the
/// arithmetic in these tests readable.
const _t0 = 1000 * engineLoadBucketMicros;

void main() {
  requireBundles();

  group('EngineLoadMeter', () {
    test('splits a span across the slices it covers, and keeps its full length as the longest', () {
      // A 250ms eval starting 50ms into a slice covers three of them. Charged
      // whole to one slice, that slice would read 250% busy; reported only
      // per slice, the longest would read 100ms — and a call queued behind it
      // waited 250ms, which is the number worth seeing.
      final emitted = <EngineLoadBucket>[];
      var now = _t0;
      final meter = EngineLoadMeter(onBucket: emitted.add, nowMicros: () => now);

      now = _t0 + 400 * _ms;
      meter.record(_t0 + 50 * _ms, _t0 + 300 * _ms, 'scoring.scoreQsos');

      expect(emitted.map((b) => b.busyMicros), [50 * _ms, 100 * _ms, 100 * _ms]);
      expect(emitted.last.longestMicros, 250 * _ms);
      expect(emitted.last.longestLabel, 'scoring.scoreQsos');
      expect(emitted.first.busyByLabel, {'scoring.scoreQsos': 50 * _ms});
      meter.dispose();
    });

    test('charges a nested entry to nobody', () {
      // The engine re-enters itself — a host call answered from inside the
      // eval that made it. Charged at both depths, 80ms of work would read
      // as 160ms and a busy engine as more than 100% busy.
      final emitted = <EngineLoadBucket>[];
      var now = _t0;
      final meter = EngineLoadMeter(onBucket: emitted.add, nowMicros: () => now, monotonicMicros: () => now);

      meter.run('lookup.lookupCall', () {
        now += 30 * _ms;
        meter.run('host:kvGet', () => now += 20 * _ms);
        now += 30 * _ms;
      });
      now = _t0 + engineLoadBucketMicros;
      meter.record(now, now + 1, 'next');

      expect(emitted.single.busyMicros, 80 * _ms);
      expect(emitted.single.busyByLabel, {'lookup.lookupCall': 80 * _ms});
      meter.dispose();
    });

    test('measures a span on the monotonic clock, so a sleep mid-call is not busy time', () {
      // The wall clock runs on while a laptop sleeps; measured on it, one
      // pump tick caught by an 8h sleep would read as 8h busy — a false
      // report, and a slice message for every 100ms of the night.
      final emitted = <EngineLoadBucket>[];
      var wall = _t0;
      var mono = 0;
      final meter = EngineLoadMeter(onBucket: emitted.add, nowMicros: () => wall, monotonicMicros: () => mono);

      meter.run('jobs', () {
        mono += 10 * _ms;
        wall += 8 * 3600 * 1000 * _ms;
      });
      wall += engineLoadBucketMicros;
      meter.record(wall, wall + 1, 'next');

      expect(emitted.single.busyMicros, 10 * _ms);
      meter.dispose();
    });

    test('caps a recorded span at the longest window anything reads', () {
      final emitted = <EngineLoadBucket>[];
      var now = _t0;
      final meter = EngineLoadMeter(onBucket: emitted.add, nowMicros: () => now);

      now = _t0 + 3600 * 1000 * _ms;
      meter.record(_t0, now - 1, 'message');

      expect(emitted.fold<int>(0, (sum, b) => sum + b.busyMicros), EngineLoadMeter.maxSpanMicros);
      meter.dispose();
    });

    test('reports the last busy slice before a quiet spell without waiting for more work', () {
      // Without the flush timer, the slice before the engine goes quiet sits
      // unreported until the NEXT busy span, which can be minutes — and the
      // readout would claim the engine idle through the very burst it missed.
      fakeAsync((async) {
        final emitted = <EngineLoadBucket>[];
        int now() => _t0 + async.elapsed.inMicroseconds;
        final meter = EngineLoadMeter(onBucket: emitted.add, nowMicros: now);

        async.elapse(const Duration(milliseconds: 10));
        meter.record(now() - 5 * _ms, now(), 'jobs');
        expect(emitted, isEmpty, reason: 'the slice is still running');

        async.elapse(const Duration(milliseconds: 100));
        expect(emitted.single.busyMicros, 5 * _ms);
        meter.dispose();
      });
    });

    test('arms one flush timer per busy slice, not one per span', () {
      // While a hook awaits, the 5ms pump records a span 20 times a slice; a
      // timer cancelled and re-made on each is churn the engine pays for
      // exactly when it is busiest.
      fakeAsync((async) {
        var created = 0;
        runZoned(
          () {
            int now() => _t0 + async.elapsed.inMicroseconds;
            final emitted = <EngineLoadBucket>[];
            final meter = EngineLoadMeter(onBucket: emitted.add, nowMicros: now);
            for (var i = 0; i < 18; i++) {
              async.elapse(const Duration(milliseconds: 5));
              meter.record(now() - 1 * _ms, now(), 'jobs');
            }
            expect(created, 1);
            async.elapse(const Duration(milliseconds: 100));
            expect(emitted.single.busyMicros, 18 * _ms, reason: 'the one timer must still flush the slice');
            meter.dispose();
          },
          zoneSpecification: ZoneSpecification(
            createTimer: (self, parent, zone, duration, callback) {
              created++;
              return parent.createTimer(zone, duration, callback);
            },
          ),
        );
      });
    });

    test('records nothing for a pump that found the queue empty', () {
      // The pump ticks every 5ms while a hook awaits the network; timed when
      // it does nothing, an engine idle on a fetch would read as working and
      // send a slice every 100ms to say so.
      fakeAsync((async) {
        final emitted = <EngineLoadBucket>[];
        final meter = EngineLoadMeter(onBucket: emitted.add, nowMicros: () => _t0 + async.elapsed.inMicroseconds);
        for (var i = 0; i < 40; i++) {
          meter.runIfWorked('jobs', () => false);
          async.elapse(const Duration(milliseconds: 5));
        }
        expect(emitted, isEmpty);
        expect(async.pendingTimers, isEmpty);

        meter.runIfWorked('jobs', () => true);
        async.elapse(const Duration(milliseconds: 200));
        expect(emitted, hasLength(1), reason: 'a pump that ran a job is still busy time');
        meter.dispose();
      });
    });

    test('arms nothing while idle', () {
      // An all-day session must not pay a wake-up per slice to report silence.
      fakeAsync((async) {
        final meter = EngineLoadMeter(onBucket: (_) {}, nowMicros: () => _t0 + async.elapsed.inMicroseconds);
        async.elapse(const Duration(seconds: 1));
        expect(async.pendingTimers, isEmpty);
        meter.dispose();
      });
    });
  });

  group('EngineLoadWindow', () {
    EngineLoadBucket bucket(int index, int busyMs, {String label = 'x'}) => EngineLoadBucket(
      _t0 ~/ engineLoadBucketMicros + index,
      busyMicros: busyMs * _ms,
      longestMicros: busyMs * _ms,
      longestLabel: label,
      busyByLabel: {label: busyMs * _ms},
    );

    test('reads idle over complete slices only', () {
      // The slice in progress has not been reported; counting it as idle
      // would flatter the number at exactly the moment the engine is busiest.
      final window = EngineLoadWindow();
      final now = _t0 + 10 * engineLoadBucketMicros + 50 * _ms;
      for (var i = 0; i < 10; i++) {
        window.add(bucket(i, 80), nowMicros: now);
      }

      expect(window.idleFraction(const Duration(seconds: 1), nowMicros: now), closeTo(0.2, 1e-9));
      expect(window.idleFraction(const Duration(seconds: 10), nowMicros: now), closeTo(0.92, 1e-9));
    });

    test('names the longest span and ranks busy time by label', () {
      final window = EngineLoadWindow();
      final now = _t0 + 5 * engineLoadBucketMicros;
      window.add(bucket(0, 90, label: 'spots.fetchSpots'), nowMicros: now);
      window.add(bucket(1, 40, label: 'jobs'), nowMicros: now);
      window.add(bucket(2, 30, label: 'jobs'), nowMicros: now);

      expect(window.longest(const Duration(seconds: 1), nowMicros: now), (micros: 90 * _ms, label: 'spots.fetchSpots'));
      expect(window.busyByLabel(const Duration(seconds: 1), nowMicros: now).map((e) => e.key), ['spots.fetchSpots', 'jobs']);
    });

    test('merges a slice reported twice without touching the bucket it was given', () {
      // The first bucket is also the host's `recent` list entry; merged into
      // in place, a monitor attaching later would read the duplicate twice.
      final window = EngineLoadWindow();
      final now = _t0 + 5 * engineLoadBucketMicros;
      final first = bucket(0, 30);
      window.add(first, nowMicros: now);
      window.add(bucket(0, 20), nowMicros: now);

      expect(first.busyMicros, 30 * _ms);
      expect(first.busyByLabel, {'x': 30 * _ms});
      expect(window.idleFraction(const Duration(milliseconds: 500), nowMicros: now), closeTo(0.9, 1e-9));
    });

    test('counts every slice since a stall as busy', () {
      // A call still running has reported none of its time; without this,
      // a wedged engine reads 100% idle for as long as it stays wedged.
      final window = EngineLoadWindow();
      final now = _t0 + 10 * engineLoadBucketMicros;
      window.add(bucket(0, 50), nowMicros: now);

      expect(window.idleFraction(const Duration(seconds: 1), nowMicros: now), closeTo(0.95, 1e-9));
      expect(window.idleFraction(const Duration(seconds: 1), nowMicros: now, stalledSinceMicros: _t0 + 5 * engineLoadBucketMicros), closeTo(0.45, 1e-9));
    });

    test('forgets buckets older than its span', () {
      final window = EngineLoadWindow(span: const Duration(seconds: 1));
      window.add(bucket(0, 100), nowMicros: _t0 + engineLoadBucketMicros);
      final later = _t0 + 30 * engineLoadBucketMicros;
      window.add(bucket(29, 10), nowMicros: later);

      expect(window.busyByLabel(const Duration(seconds: 60), nowMicros: later).single.value, 10 * _ms);
    });
  });

  group('EngineLoadFeed', () {
    test('a ping left unanswered for a heartbeat reads as a stall since it was sent', () {
      fakeAsync((async) {
        int now() => _t0 + async.elapsed.inMicroseconds;
        var pings = 0;
        final stalls = <int>[];
        final feed = EngineLoadFeed(ping: () => pings++, nowMicros: now)..wake();
        feed.stalls.listen(stalls.add);

        async.elapse(engineHeartbeat);
        expect(pings, 1);
        final sentAt = now();
        expect(feed.stalledSinceMicros, isNull, reason: 'one heartbeat is the engine\'s time to answer');

        async.elapse(engineHeartbeat);
        expect(feed.stalledSinceMicros, sentAt);
        expect(stalls, [sentAt], reason: 'no bucket arrives during a stall, so this is the only news');
        expect(pings, 1, reason: 'one ping outstanding at a time');

        feed.pong();
        expect(feed.stalledSinceMicros, isNull);
        feed.dispose();
      });
    });

    test('a feed disposed mid-stall stops reading as one', () {
      // Disposed when its engine dies: a dead engine answers no ping, and a
      // stall left standing would read 0% idle — and report the engine busy —
      // through the whole wait for a replacement.
      fakeAsync((async) {
        final feed = EngineLoadFeed(ping: () {}, nowMicros: () => _t0 + async.elapsed.inMicroseconds)..wake();
        async.elapse(engineHeartbeat * 2);
        expect(feed.stalledSinceMicros, isNotNull);

        feed.dispose();
        expect(feed.stalledSinceMicros, isNull);
        expect(async.pendingTimers, isEmpty);
      });
    });

    test('stops beating once the engine has been quiet a while', () {
      // An all-day session with an idle engine must not pay a wake-up a
      // second for a heartbeat nobody needs.
      fakeAsync((async) {
        late final EngineLoadFeed feed;
        feed = EngineLoadFeed(ping: () => feed.pong(), nowMicros: () => _t0 + async.elapsed.inMicroseconds)..wake();
        async.elapse(EngineLoadFeed.quietAfter + engineHeartbeat * 2);
        expect(async.pendingTimers, isEmpty);

        feed.wake();
        expect(async.pendingTimers, hasLength(1), reason: 'the next call starts it again');
        feed.dispose();
      });
    });
  });

  test('a hook that holds the real engine reads as a stall while it runs, and not after', () async {
    // End to end: the ping has to cross to the engine's isolate and queue
    // behind the running hook. Answered from anywhere else, a wedged engine
    // would look responsive.
    //
    // Held for a span of wall time inside the engine, not a count of iterations
    // sized against a probe: load that changes between the probe and the run
    // ends the hold before the second heartbeat, and the stall is never seen.
    // Two seconds against the 200 ms a stall takes to show is the margin a
    // starved machine gets. Neither wait is a fixed sleep, and their deadlines
    // only stop a hang (time.md §7).
    //
    // Its own host, not a shared one: the heartbeat is read when the feed's
    // timer is armed, and a shared host's may already be running at 1 s,
    // which a stall needs two of — as long as the whole hold.
    final saved = engineHeartbeat;
    engineHeartbeat = const Duration(milliseconds: 100);
    addTearDown(() => engineHeartbeat = saved);
    final host = await ExtensionHost.start(
      kernelSource: bundleSource('kernel'),
      extensions: const [ExtensionBundle(key: 'holder', source: _holder)],
    );
    addTearDown(host.dispose);

    // A stall reports when its ping went out: one sent before the hold, its
    // pong merely late, would otherwise pass for the stall the hold causes.
    final sentFrom = realNowUtc().microsecondsSinceEpoch;
    final hold = host.invokeHook('bench', key: 'holder', method: 'hold', args: {'millis': 2000});
    // Its error still reaches the await below; this only keeps it from
    // escaping as an unhandled one after a failure above ends the test early.
    hold.ignore();
    // Raced, so a hold that ends first fails here with its own error, if it
    // has one, rather than as a timeout ten seconds on.
    final stalled = await Future.any<int>([
      host.engineLoad.stalls.first,
      hold.then<int>((_) => throw StateError('the hold returned before any stall was seen')),
    ]).timeout(const Duration(seconds: 10));
    expect(stalled, greaterThanOrEqualTo(sentFrom));
    expect(host.engineLoad.stalledSinceMicros, stalled);

    await hold;
    final cleared = Stopwatch()..start();
    while (host.engineLoad.stalledSinceMicros != null) {
      if (cleared.elapsed > const Duration(seconds: 10)) fail('still reading as a stall after the hook returned');
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  });

  test('a hook busy in the real engine is charged to that hook', () async {
    // End to end through a real engine: if any link between the core's
    // timing and the host's stream breaks, the readout sits at 100% idle
    // while the engine is pinned — the one failure this whole measurement
    // exists to rule out.
    //
    // Bounded by what each side knows for certain: the hook held the engine for
    // its whole hold, and the round trip around it took at least as long. A
    // share of the round trip instead would charge every delay in getting the
    // answer back against the engine, and a loaded machine adds plenty.
    final host = await ExtensionHost.start(
      kernelSource: bundleSource('kernel'),
      extensions: const [ExtensionBundle(key: 'holder', source: _holder)],
    );
    addTearDown(host.dispose);
    const holdMillis = 300;
    final watch = Stopwatch()..start();
    await host.invokeHook('bench', key: 'holder', method: 'hold', args: {'millis': holdMillis});
    final roundTripMicros = watch.elapsedMicroseconds;

    int charged() => host.engineLoad.recent.fold<int>(0, (sum, b) => sum + (b.busyByLabel['bench.hold@holder'] ?? 0));
    // The hold reads whole milliseconds, so it can end a millisecond short.
    const floor = (holdMillis - 2) * _ms;
    // The last slice reaches the host only when its flush timer fires: polled,
    // since that timer can run late.
    final flushed = Stopwatch()..start();
    while (charged() < floor && flushed.elapsed < const Duration(seconds: 10)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(charged(), greaterThanOrEqualTo(floor));
    expect(charged(), lessThanOrEqualTo(roundTripMicros));
  });
}

/// Holds the engine for `millis` of wall time, however fast the machine.
const _holder = '''
__halo.defineExtension({
  key: 'holder',
  name: 'Holder',
  version: '0.0.1',
  onActivation: function (api) {
    api.registerHook('bench', { key: 'holder', hook: {
      hold: async function (args) {
        const until = Date.now() + args.millis
        while (Date.now() < until) {}
      },
    }})
  },
})
''';
