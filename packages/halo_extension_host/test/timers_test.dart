// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Extension timers through the real path: the kernel's queue, its `timerWake`
// message, the host's single Dart timer, and `__polo.runTimers()` back into
// QuickJS. sdk/src/timerQueue.test.ts holds the queue's rules against a clock
// moved by hand; this is where a timer has to actually fire, with no hook call
// outstanding to keep the engine pumped.
//
// On a fake clock (docs/design/time.md §7): the host's wake timer, the
// kernel's queue (through `extensionTimerClock`) and the test's own waits all
// read the one clock `fakeAsync` advances, so "it fired by then" is exact
// rather than a bet on how loaded the machine is. The one exception is pinned
// separately: with no test clock the kernel keeps its own monotonic one,
// which travelling the app clock does not move.
//
// The extension drives the kernel's `api.timers` directly, the way the SDK's
// `host.setTimeout` does, so what is under test is the kernel and the host.

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:halo_extension_host/src/engine_runtime_io.dart' show extensionEvalBudget;
import 'package:halo_extension_host/src/extension_timers.dart';

import 'support/bundles.dart';
import 'support/fake_clock.dart';

/// An extension that sets timers on request and records what they did.
///
/// Wrapped in its own closure as a built bundle is, so two of these keep two
/// sets of state.
String _timerExtension(String key) =>
    '''
(function () {
var timers = null
var fired = []
var shown = []
__polo.defineExtension({
  key: '$key',
  name: 'Timers',
  version: '0.0.1',
  onShow: function () { shown.push('show') },
  onHide: function () { shown.push('hide') },
  onActivation: function (api) {
    timers = api.timers
    api.registerHook('bench', { key: '$key', hook: {
      after: async function (args) {
        timers.set(function (tag) { fired.push({ tag: tag }) }, args.delay, false, [args.tag])
      },
      every: async function (args) {
        return timers.set(function () { fired.push({ tag: 'tick' }) }, args.delay, true, [])
      },
      clear: async function (args) { timers.clear(args.id) },
      spin: async function () {
        var chain = function () { timers.set(chain, 0, false, []) }
        timers.set(chain, 0, false, [])
      },
      throwOdd: async function () {
        timers.set(function () { throw Object.create(null) }, 0, false, [])
      },
      hang: async function () {
        timers.set(function () { while (true) {} }, 0, false, [])
      },
      markLater: async function (args) {
        timers.set(function () { globalThis.__timerProbe = 'the old code fired' }, args.delay, false, [])
      },
      probe: async function () { return globalThis.__timerProbe || null },
      keepSetter: async function () {
        globalThis.__oldSetTimer = function () { timers.set(function () { globalThis.__timerProbe = 'the old setter fired' }, 0, false, []) }
      },
      useOldSetter: async function () {
        try {
          globalThis.__oldSetTimer()
          return 'accepted'
        } catch (e) {
          return 'refused: ' + e.message
        }
      },
      fired: async function () { return fired },
      shown: async function () { return shown },
    }})
  },
})
})()
''';

/// An extension that sets an interval and a visibility handler, then fails
/// to activate.
String _failingActivation(String key) =>
    '''
(function () {
__polo.defineExtension({
  key: '$key',
  name: 'Fails',
  version: '0.0.1',
  onHide: function () { globalThis.__failedHeard = 'hide' },
  onActivation: function (api) {
    globalThis.__failedTicks = 0
    api.registerHook('bench', { key: '$key', hook: {
      ticks: async function () { return globalThis.__failedTicks },
      heard: async function () { return globalThis.__failedHeard || null },
    }})
    api.timers.set(function () { globalThis.__failedTicks++ }, 10, true, [])
    throw new Error('activation failed on purpose')
  },
})
})()
''';

/// An extension whose activation waits until its `release` hook is called.
String _gatedActivation(String key) =>
    '''
(function () {
var shown = []
var release = null
__polo.defineExtension({
  key: '$key',
  name: 'Gated',
  version: '0.0.1',
  onHide: function () { shown.push('hide') },
  onActivation: async function (api) {
    api.registerHook('bench', { key: '$key', hook: {
      release: async function () { release() },
      shown: async function () { return shown },
    }})
    await new Promise(function (resolve) { release = resolve })
  },
})
})()
''';

void main() {
  requireBundles();

  void onFakeClock(String description, Future<void> Function(FakeAsync async) body) => test(description, () => runOnFakeClock(body));

  Future<ExtensionHost> start(List<ExtensionBundle> bundles, {bool awaitActivation = true}) async {
    final host = await ExtensionHost.start(kernelSource: bundleSource('kernel'), extensions: bundles, useIsolate: false);
    addTearDown(host.dispose);
    if (awaitActivation) await host.activated;
    return host;
  }

  Future<ExtensionHost> hostWith(List<String> keys) => start([for (final key in keys) ExtensionBundle(key: key, source: _timerExtension(key))]);

  Future<Object?> call(ExtensionHost host, String key, String method, [Map<String, Object?> args = const {}]) =>
      host.invokeHook('bench', key: key, method: method, args: args);

  Future<List<Map>> fired(ExtensionHost host, String key) async => ((await call(host, key, 'fired')) as List).cast<Map>();

  Future<void> wait(int millis) => Future<void>.delayed(Duration(milliseconds: millis));

  onFakeClock('a timeout fires on its own, with no hook call keeping the engine awake, and not before its delay', (_) async {
    // The host pumps QuickJS only while a hook call is outstanding. A timer
    // that waited on that pump would fire only when something else happened
    // to call a hook — so this one is set, the call returns, and nothing
    // else is asked of the engine until it is due.
    final host = await hostWith(['a']);
    await call(host, 'a', 'after', {'delay': 100, 'tag': 'first'});
    await wait(80);
    expect(await fired(host, 'a'), isEmpty);
    await wait(40);
    expect((await fired(host, 'a')).map((f) => f['tag']), ['first']);
  });

  onFakeClock('an interval keeps firing until it is cleared, and never after', (_) async {
    final host = await hostWith(['a']);
    final id = await call(host, 'a', 'every', {'delay': 20});
    await wait(70);
    expect(await fired(host, 'a'), hasLength(3));
    await call(host, 'a', 'clear', {'id': id});
    await wait(200);
    expect(await fired(host, 'a'), hasLength(3));
  });

  onFakeClock("a zero-delay chain loses its timers, and nobody else's work stops with it", (_) async {
    // On the fake clock no time passes between the chain's wakes, so nothing
    // drains its debt and each wake's surcharge counts in full: the budget
    // breaks at a fixed number of links, at any machine speed.
    final host = await hostWith(['spinner', 'bystander']);
    final suspensions = <TimerSuspension>[];
    host.timerSuspensions.listen(suspensions.add);
    await call(host, 'bystander', 'every', {'delay': 20});
    await call(host, 'spinner', 'spin');
    await wait(1);
    expect(suspensions, [(extensionKey: 'spinner', reason: 'budget')]);

    // Its hooks still answer — it is the clock that misbehaved, not the
    // extension — and a new timer is refused out loud rather than thrown,
    // so the hook that asked keeps working.
    expect(await fired(host, 'spinner'), isEmpty);
    await call(host, 'spinner', 'after', {'delay': 0, 'tag': 'again'});
    expect(host.logLines, contains(contains('spinner set a timer while its timers are suspended')));
    final before = (await fired(host, 'bystander')).length;
    await wait(70);
    expect((await fired(host, 'bystander')).length, greaterThanOrEqualTo(before + 3), reason: "the bystander's interval keeps ticking");
  });

  onFakeClock('a callback that throws something unprintable is one failure, not a stuck callback', (_) async {
    // `String(Object.create(null))` throws. Formatting it inside the kernel's
    // own error handling once abandoned the run, which on native reads as an
    // interrupted callback and suspends the extension for the wrong reason —
    // and on web crashes the Worker, restarting every extension.
    final host = await hostWith(['a']);
    final suspensions = <TimerSuspension>[];
    host.timerSuspensions.listen(suspensions.add);
    await call(host, 'a', 'throwOdd');
    await wait(5000);
    expect(host.logLines, contains(contains('a timer callback: (an error that cannot be printed)')));
    expect(suspensions, isEmpty);
  });

  onFakeClock('reloading an extension cancels the timers its old code set', (_) async {
    // The old closure would otherwise fire into a runtime where its extension
    // no longer exists — work nobody can see, or cancel, or account for.
    final host = await hostWith(['a']);
    await call(host, 'a', 'markLater', {'delay': 150});
    await host.reloadBundle(ExtensionBundle(key: 'a', source: _timerExtension('a')));
    await wait(400);
    expect(await call(host, 'a', 'probe'), isNull);
  });

  onFakeClock("an unloaded extension's old code cannot set timers under the key its new code holds", (_) async {
    // Old code outlives its unload whenever something it awaited resolves
    // afterwards. Accepted, its timers would be a loop nobody can see or
    // clear, billed to the code that replaced it.
    final host = await hostWith(['a']);
    await call(host, 'a', 'keepSetter');
    await host.reloadBundle(ExtensionBundle(key: 'a', source: _timerExtension('a')));
    await call(host, 'a', 'useOldSetter');
    await wait(200);
    expect(await call(host, 'a', 'probe'), isNull);
    expect(host.logLines, contains(contains('a set a timer after it was unloaded')));
  });

  onFakeClock('an extension whose activation fails keeps no timers running, and hears nothing of the app', (_) async {
    final host = await start([ExtensionBundle(key: 'broken', source: _failingActivation('broken'))]);
    await wait(200);
    expect(await call(host, 'broken', 'ticks'), 0);
    host.setAppVisible(false);
    expect(await call(host, 'broken', 'heard'), isNull);
  });

  onFakeClock('an extension still activating when the app hides hears onHide once it has activated, not before', (_) async {
    // The host's push after boot waits for activation, but a lifecycle change
    // can land in that window; an onHide then would reach state its
    // onActivation has not finished building.
    final host = await start([ExtensionBundle(key: 'gated', source: _gatedActivation('gated'))], awaitActivation: false);
    host.setAppVisible(false);
    expect(await call(host, 'gated', 'shown'), isEmpty);
    await call(host, 'gated', 'release');
    await host.activated;
    expect(await call(host, 'gated', 'shown'), ['hide']);
  });

  onFakeClock('onHide and onShow reach an extension when the app changes, and only then', (_) async {
    final host = await hostWith(['a']);
    // What the app sends after every boot: an app already visible is no news.
    host.setAppVisible(true);
    expect(await call(host, 'a', 'shown'), isEmpty);
    host.setAppVisible(false);
    host.setAppVisible(false);
    expect(await call(host, 'a', 'shown'), ['hide']);
    host.setAppVisible(true);
    expect(await call(host, 'a', 'shown'), ['hide', 'show']);
  });

  onFakeClock("callbacks the engine has to interrupt cost only their own extensions' timers, even two in one run", (_) async {
    // The interrupt unwinds through every catch and finally in the kernel,
    // so the run it cut short never asks for its next wake. Without the host
    // running the queue again, every extension's timers stop for good; and
    // the run that recovers from the first stuck callback meets the second.
    //
    // The interrupts themselves are real: the engine stops a callback that
    // has spun its evaluation budget of the real clock, so each costs that
    // budget in real time — two seconds here rather than the real fifteen.
    // Everything around them, the retry and the bystander, is on the fake one.
    extensionEvalBudget = const Duration(seconds: 2);
    addTearDown(() => extensionEvalBudget = const Duration(seconds: 15));
    final host = await start([
      for (final key in ['runaway', 'stuck', 'bystander']) ExtensionBundle(key: key, source: _timerExtension(key)),
    ]);
    final suspensions = <TimerSuspension>[];
    host.timerSuspensions.listen(suspensions.add);
    await call(host, 'bystander', 'every', {'delay': 50});
    // Not awaited one by one: in-process, both evaluate before the host's
    // wake timer can fire, so both are due in the same run.
    await Future.wait([call(host, 'runaway', 'hang'), call(host, 'stuck', 'hang')]);
    await wait(2500);
    expect(suspensions, [(extensionKey: 'runaway', reason: 'interrupted'), (extensionKey: 'stuck', reason: 'interrupted')]);
    final before = (await fired(host, 'bystander')).length;
    await wait(170);
    expect((await fired(host, 'bystander')).length, greaterThanOrEqualTo(before + 3), reason: "the bystander's interval keeps ticking");
  });

  test("with no test clock, extension timers keep the engine's own clock, which travelling the app clock does not move", () async {
    // The seam's default is the contract (docs/design/time.md §7). A queue on
    // the app clock would find a 500 ms timer long overdue at the first wake
    // anything else asked for — here a 20 ms interval's — under DEVTT's
    // thousandfold speed. Real timers, asserting only what has NOT happened.
    final host = await hostWith(['a']);
    addTearDown(AppClock.instance.reset);
    AppClock.instance.travel(speed: AppClock.maxSpeed);
    final clock = AppClock.instance;
    host.setClockTravel(anchorRealMillis: clock.anchorRealMillis, anchorVirtualMillis: clock.anchorVirtualMillis, speed: clock.speed);
    await call(host, 'a', 'after', {'delay': 500, 'tag': 'late'});
    await call(host, 'a', 'every', {'delay': 20});
    await wait(200);
    expect((await fired(host, 'a')).map((f) => f['tag']), isNot(contains('late')));
  });

  group('ExtensionTimerWake', () {
    onFakeClock('a wake the kernel asks for meanwhile does not put off the retry after a failed run', (_) async {
      // The retry is the run that notices the interrupted callback. A hook
      // setting a timer a minute out before it fires would otherwise push that
      // notice — and the suspension — a minute later.
      var calls = 0;
      late final ExtensionTimerWake wake;
      wake = ExtensionTimerWake(
        runTimers: () {
          calls++;
          if (calls == 1) throw Exception('interrupted');
        },
        // Lands after the failed run and before its retry fires: where a hook
        // call setting a timer would land.
        log: (_) => scheduleMicrotask(() => wake.arm(60000)),
      );
      addTearDown(wake.dispose);
      wake.arm(0);
      await wait(100);
      expect(calls, 2);
    });

    onFakeClock('keeps retrying a run that fails, at once and then a second apart, until one succeeds', (_) async {
      // A run fails when the engine interrupts a stuck callback, and a second
      // stuck callback in the same run fails the retry too. Giving up after
      // one retry would leave every extension's timers stopped for good.
      var calls = 0;
      final wake = ExtensionTimerWake(
        runTimers: () {
          calls++;
          if (calls <= 3) throw Exception('interrupted');
        },
        log: (_) {},
      );
      addTearDown(wake.dispose);
      wake.arm(0);
      // Immediate, then 1s, then 1s: the retries back off rather than spin.
      await wait(500);
      expect(calls, 2);
      await wait(1000);
      expect(calls, 3);
      await wait(1000);
      expect(calls, 4);
      await wait(5000);
      expect(calls, 4, reason: 'a run that succeeded is not retried');
    });
  });
}
