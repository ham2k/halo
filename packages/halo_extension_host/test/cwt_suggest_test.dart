// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// CWT is the only activity that keeps itself OUT of the picker's nearby list
// most of the time — it offers a session from three hours before it starts
// until an hour after it ends, and answers a search or a SCOPED ask on any day
// (extensions/contests/cwt/src/schedule.ts).
//
// Both halves are load-bearing and neither is reachable from the extension's
// own node tests, which call the schedule functions directly rather than the
// hook: what runs in the app is `suggest` inside the sandbox, reading the
// sandbox's `Date`. So this drives the real runtime with the app clock parked
// on a chosen weekday — the only way to make a date-gated hook testable at all,
// since a suite that ran on real time would pass or fail by the day of the week.
//
// The `scoped` half in particular has one caller (`ExtensionService
// .suggestActivities` passes `scoped: true` on its key-scoped invoke) and no
// other coverage: without it the extension's own "Activity Types" row comes
// back empty six days a week, silently.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_extension_host/halo_extension_host.dart';

import 'support/bundles.dart';

void main() {
  requireBundles();

  tearDown(AppClock.instance.reset);

  /// Parks the app clock on the next [weekday] at [hour]:[minute] UTC and hands
  /// back a host reading it. A fixed calendar date would drift out of the
  /// clock's travel ceiling as the years pass; "the next Wednesday" never does.
  Future<ExtensionHost> hostAt(int weekday, int hour, int minute) async {
    final now = nowUtc();
    var day = DateTime.utc(now.year, now.month, now.day);
    while (day.weekday != weekday) {
      day = day.add(const Duration(days: 1));
    }
    var target = day.add(Duration(hours: hour, minutes: minute));
    if (!target.isAfter(now)) target = target.add(const Duration(days: 7));
    AppClock.instance.travel(delta: target.difference(now));

    final host = await sharedHost(['cwt']);
    final clock = AppClock.instance;
    // By hand: the ExtensionService listener that normally pushes travel into
    // the sandbox lives in the app, above this package.
    host.setClockTravel(
      anchorRealMillis: clock.anchorRealMillis,
      anchorVirtualMillis: clock.anchorVirtualMillis,
      speed: clock.speed,
    );
    return host;
  }

  Future<List<Map<String, dynamic>>> suggest(ExtensionHost host, {bool scoped = false}) async {
    final result = await host.invokeHook(
      'activity',
      key: 'cwt',
      method: 'suggest',
      args: {
        'operation': const <String, dynamic>{},
        if (scoped) 'scoped': true,
      },
      timeout: const Duration(seconds: 10),
    ) as List?;
    return [for (final entry in result ?? const []) (entry as Map).cast<String, dynamic>()];
  }

  /// The session key for the day the clock is parked on, at [hour].
  String keyForToday(int hour) {
    final at = nowUtc();
    String pad(int v) => v.toString().padLeft(2, '0');
    return '${at.year}-${pad(at.month)}-${pad(at.day)}-${pad(hour)}00';
  }

  test('offers nothing unprompted on a day with no session', () async {
    // Monday. A weekly contest that always offered itself would head the nearby
    // list six days out of seven, which is what this gate exists to prevent.
    expect(await suggest(await hostAt(DateTime.monday, 12, 0)), isEmpty);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('offers nothing unprompted more than three hours before a session', () async {
    // Wednesday 0900z — a CWT day, but the 1300 is still four hours out.
    expect(await suggest(await hostAt(DateTime.wednesday, 9, 0)), isEmpty);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('offers exactly the session at hand once its lead window opens', () async {
    final host = await hostAt(DateTime.wednesday, 10, 30);
    final suggestions = await suggest(host);
    expect(suggestions, hasLength(1));
    expect(suggestions.single['type'], 'cwt');
    expect(suggestions.single['ref'], keyForToday(13));
    expect(suggestions.single['shortLabel'], 'CWT 1300z');
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('a scoped ask is answered on a day the nearby list stays silent', () async {
    // The operator tapped this extension's own "Activity Types" row on a
    // Monday. `scoped` is the ONLY thing separating that from the nearby list —
    // both arrive with no search term — so dropping the flag makes the row
    // look broken while every test still passes.
    final host = await hostAt(DateTime.monday, 12, 0);
    expect(await suggest(host), isEmpty);

    final scoped = await suggest(host, scoped: true);
    expect(scoped, hasLength(4), reason: 'a scope offers the next four sessions on any day');

    final refs = [for (final entry in scoped) entry['ref'] as String];
    // The week's four slots, in the order they run — a Monday's next session is
    // Wednesday's 1300. Sorted-and-distinct because the picker ranks these on
    // `relevance` alone, so the order the extension emits has to already be the
    // order an operator reads.
    expect(refs.toSet(), hasLength(4));
    expect(refs, orderedEquals(List.of(refs)..sort()));
    expect(refs.first, endsWith('-1300'));
  }, timeout: const Timeout(Duration(seconds: 60)));
}
