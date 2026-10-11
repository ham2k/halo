// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Extensions must read the same clock the Dart side does (docs/design/time.md).
// The kernel achieves that by REPLACING the sandbox's `Date` with a `Proxy`
// around the real constructor (extensions/sdk/src/appClock.ts), which is the
// kind of thing that either works completely or fails completely — and only in
// the engine that ships. `appClock.test.ts` covers the proxy's surface under
// Node; what needs an engine is everything below:
//
//  • QuickJS-NG has to honour the proxy at all — a `construct` trap, a `get`
//    trap over a native constructor, and `Reflect.construct` with a newTarget.
//    Where it didn't, every date in every extension would be wrong at once.
//  • The kernel's own `Date` references resolve to the GLOBAL it just replaced,
//    so its perf timings and cache TTLs have to be on the captured real clock.
//    Getting that wrong makes `jsMillis` scale with the speed factor.
//  • The travel state lives in the main isolate while the runtime lives in
//    another one (or a worker), so it has to cross that boundary — at boot and
//    on every change. A silent revert to real time is invisible from Dart.
//
// The probe is the core `templates` extension rendering a `{{ now }}` template:
// the SDK's `templateContext` resolves that through the sandbox's `Date`, so the
// rendered timestamp is a direct, readable statement of what time the sandbox
// thinks it is. Deliberately a core bundle whose only job is rendering what it
// is told — probing a panel that exists to show a clock ties this file to that
// panel's continued existence.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_extension_host/halo_extension_host.dart';

import 'support/bundles.dart';

void main() {
  requireBundles();

  tearDown(AppClock.instance.reset);

  /// Hands the sandbox the clock's current travel state — by hand, because the
  /// ExtensionService listener that normally does this lives in the app, above
  /// this package.
  Future<ExtensionHost> travelledHost() async {
    final host = await sharedHost(['templates']);
    final clock = AppClock.instance;
    host.setClockTravel(anchorRealMillis: clock.anchorRealMillis, anchorVirtualMillis: clock.anchorVirtualMillis, speed: clock.speed);
    return host;
  }

  /// Renders `{{ now }}`, which the SDK's templateContext fills from the
  /// sandbox's `Date`, and returns the rendered text.
  Future<String> renderClock(ExtensionHost host) async {
    final result = await host.invokeHook(
      'template',
      key: 'templates',
      method: 'render',
      args: const {'template': 'NOW={{ now }}'},
      timeout: const Duration(seconds: 30),
    );
    return (result as Map)['text'] as String;
  }

  /// The date the sandbox rendered, as `YYYY-MM-DD`.
  Future<String> renderedDate() async {
    final text = await renderClock(await travelledHost());
    final match = RegExp(r'NOW=(\d{4}-\d{2}-\d{2})').firstMatch(text);
    expect(match, isNotNull, reason: 'the template should have rendered its {{ now }}:\n$text');
    return match!.group(1)!;
  }

  String isoDate(DateTime utc) => utc.toIso8601String().substring(0, 10);

  test('the sandbox reads real time when the clock is not travelled', () async {
    expect(await renderedDate(), isoDate(nowUtc()));
  });

  test('the sandbox follows an offset', () async {
    // Three weeks, not hours: a date-only assertion has to move the DATE, and
    // three weeks also crosses a month boundary from most starting points.
    AppClock.instance.travel(delta: const Duration(days: 21));
    final rendered = await renderedDate();
    expect(rendered, isoDate(nowUtc()));
    expect(
      rendered,
      isNot(isoDate(DateTime.now().toUtc())), // clock:allow — proving it is NOT real time
      reason: 'the sandbox must be rendering the travelled date, not the real one',
    );
  });

  test('the sandbox follows a backward offset', () async {
    AppClock.instance.travel(delta: const Duration(days: -400));
    expect(await renderedDate(), isoDate(nowUtc()));
  });

  test('date arithmetic still works on a constructed date', () async {
    // `templateContext` formats through `new Date(ms)` and the ISO getters, so
    // this proves the proxied constructor really produces a working Date in this
    // engine. A construction the engine mishandles renders NaNs, which no
    // date-shaped regex alone would catch.
    AppClock.instance.travel(delta: const Duration(days: 500, hours: 7, minutes: 13));
    final expected = nowUtc();
    final text = await renderClock(await travelledHost());

    String hhmm(DateTime utc) => '${utc.hour.toString().padLeft(2, '0')}:${utc.minute.toString().padLeft(2, '0')}';
    // Either minute: the render lands a few milliseconds after `expected` was
    // read, which can be the far side of a minute boundary.
    expect(
      text,
      anyOf(contains('T${hhmm(expected)}'), contains('T${hhmm(expected.add(const Duration(minutes: 1)))}')),
      reason: 'the rendered timestamp should read the travelled time:\n$text',
    );
  });

  test('returning to real time puts the sandbox back', () async {
    AppClock.instance.travel(delta: const Duration(days: 30));
    expect(await renderedDate(), isNot(isoDate(DateTime.now().toUtc()))); // clock:allow — the contrast
    AppClock.instance.reset();
    expect(await renderedDate(), isoDate(DateTime.now().toUtc())); // clock:allow — back on real time
  });

  test('a runtime that BOOTS while travelled is travelled from the start', () async {
    // Its own host, not the shared one: this is the boot path, which the shared
    // host has already been through. What it covers is the whole reason
    // ExtensionHost.start takes a clock at all — `start` evaluates the bundles
    // AND runs their activations, so a clock pushed after it returns has already
    // missed them, and an extension reading a date while activating bakes in the
    // real one and then renders it beside travelled app UI. This is also the
    // path a runtime CRASH-restart takes while travel is on.
    AppClock.instance.travel(delta: const Duration(days: 45));
    final clock = AppClock.instance;
    final host = await ExtensionHost.start(
      kernelSource: bundleSource('kernel'),
      extensions: [ExtensionBundle(key: 'templates', source: bundleSource('templates'))],
      clock: ClockTravelState(anchorRealMillis: clock.anchorRealMillis, anchorVirtualMillis: clock.anchorVirtualMillis, speed: clock.speed),
    );
    addTearDown(host.dispose);

    // No setClockTravel call anywhere: everything this asserts came from the
    // boot payload.
    final text = await renderClock(host);
    expect(text, contains(isoDate(nowUtc())));
    expect(text, isNot(contains(isoDate(DateTime.now().toUtc())))); // clock:allow — the contrast
  });

  test('a speed factor does not trip the template render limit', () async {
    // The SDK bounds a template render at 250 ms, and in this engine
    // liquidjs's timer falls back to `Date` — the travelled one — unless the
    // build points it at the real clock. At 1000x a loop taking a few real
    // milliseconds then reads as seconds and fails with `template render limit
    // exceeded`, on every template a time-travelled session renders.
    AppClock.instance.travel(speed: AppClock.maxSpeed);
    final host = await travelledHost();
    final result = await host.invokeHook(
      'template',
      key: 'templates',
      method: 'render',
      args: const {'template': '{% for i in (1..3000) %}x{% endfor %}'},
      timeout: const Duration(seconds: 30),
    );
    expect(result, {'text': 'x' * 3000});
  });

  test('a speed factor does not distort the hook timings the kernel reports', () async {
    // The kernel times hooks with the REAL clock it captured before replacing
    // the global. At 1000x a render taking a few real milliseconds would report
    // SECONDS of jsMillis if it were reading the travelled one, silently
    // poisoning every latency number the app profiles with.
    AppClock.instance.travel(speed: AppClock.maxSpeed);
    final host = await travelledHost();
    final before = host.samples.length;
    await renderClock(host);
    expect(host.samples.length, greaterThan(before), reason: 'sanity: the call was sampled');
    // Against the Dart-side round trip rather than a fixed bound: the JS time is
    // by definition a part of it, so this holds at any machine speed, while a
    // kernel reading the travelled clock would overshoot by the whole factor.
    // The slack absorbs the two clocks' independent millisecond truncation — a
    // sub-millisecond render legitimately reports 1 against a total of 0 — and
    // is three orders of magnitude below the ~1000x error being looked for.
    final sample = host.samples.last;
    expect(sample.jsMillis, lessThanOrEqualTo(sample.totalMillis + 5), reason: 'jsMillis must be real elapsed milliseconds, not travelled ones');
  });
}
