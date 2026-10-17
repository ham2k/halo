// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// DEVTT's app side (docs/design/time.md). The parser is unit-tested in
// extensions/core/dev-commands/src/timetravel.test.ts; everything that protects
// real data lives HERE, because none of it is visible from inside the sandbox:
//
//  • The sync-account gate, which fails CLOSED: a real (email-identified)
//    account must never receive the travelled `startAtMillis` a QSO logged while
//    travelled carries, and an account that cannot be SHOWN to be a test one is
//    refused rather than assumed safe. `/TEST`, as a whole segment, is the
//    opt-out.
//  • Sync does not run while travelling, and the operator's `syncEnabled`
//    setting is never written to achieve it — a dev tool that wrote it would
//    leave sync off for good if the app were quit before travel ended, and
//    nothing about that looks like a clock bug.
//  • Developer mode is required, and losing it puts the clock back — otherwise a
//    non-developer app is stranded on a fake clock with no way to type its way
//    out (the command doesn't even match without developer mode).

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';

import '../support/halo_test_support.dart';
import '../support/fake_clock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(AppClock.instance.reset);

  Future<HaLoServices> buildServices({bool developerMode = true, bool syncEnabled = false, Map<String, dynamic>? currentAccount}) async {
    final HaLoHarness(:services, :settings) = await makeHaLoServices();
    await settings.setDeveloperMode(developerMode);
    if (syncEnabled) await settings.setSyncEnabled(true);
    if (currentAccount != null) {
      await settings.setSyncState({
        'accountData': {'current_account': currentAccount},
      });
    }
    return services;
  }

  /// What the call field would show after running the command.
  Future<CommandActionOutcome?> travel(HaLoServices services, Map<String, dynamic> params) => services.handleCommandAction('devTimeTravel', params);

  group('applying travel', () {
    test('an offset moves the clock', () async {
      final services = await buildServices();
      final outcome = await travel(services, {'deltaMillis': const Duration(hours: 3).inMilliseconds});

      expect(outcome!.failed, isFalse);
      expect(AppClock.instance.offset.inMinutes, closeTo(180, 1));
      // The resulting time is the operator's only confirmation — the command
      // hook deliberately has no `confirm`, since only the app knows it.
      expect(outcome.text, contains('Clock now'));
      expect(outcome.text, contains('+3h'));
    });

    test('a speed factor applies', () async {
      final services = await buildServices();
      await travel(services, {'deltaMillis': 0, 'speed': 4.0});
      expect(AppClock.instance.speed, 4.0);
    });

    test('a refused speed reports instead of throwing', () async {
      final services = await buildServices();
      final outcome = await travel(services, {'deltaMillis': 0, 'speed': 0.0});
      expect(outcome!.failed, isTrue);
      expect(AppClock.instance.isTravelling, isFalse);
    });

    test('reset returns to real time', () async {
      final services = await buildServices();
      await travel(services, {'deltaMillis': const Duration(days: 2).inMilliseconds});
      final outcome = await travel(services, {'reset': true});

      expect(outcome!.failed, isFalse);
      expect(AppClock.instance.isTravelling, isFalse);
    });

    test('a status bar item stands for as long as travel does', () async {
      final services = await buildServices();
      await travel(services, {'deltaMillis': const Duration(days: 3).inMilliseconds});
      final item = services.statusBar.itemForKey(HaLoServices.timeTravelStatusKey);
      expect(item, isNotNull, reason: 'a travelled clock must be visible without asking');
      // The TITLE, deliberately: the collapsed footer — the always-visible one —
      // renders `title ?? text`, so anything in `text` is invisible until
      // someone expands the bar, which this item must not depend on.
      expect(item!.title, contains('+3d'));
      expect(item.text, isNull, reason: 'a separate text would only show when expanded');

      await travel(services, {'reset': true});
      expect(services.statusBar.itemForKey(HaLoServices.timeTravelStatusKey), isNull);
    });

    test('the item names both the offset and the speed, where the footer shows them', () async {
      final services = await buildServices();
      await travel(services, {'deltaMillis': const Duration(hours: 2).inMilliseconds, 'speed': 3.0});
      final title = services.statusBar.itemForKey(HaLoServices.timeTravelStatusKey)!.title!;
      expect(title, contains('+2h'));
      expect(title, contains('3x'));
      expect(title, startsWith('Time travel'), reason: 'one readable line, not a bare offset');
    });

    test(
      'the item follows the clock instead of freezing at the command',
      () => runOnFakeClock((_) async {
        // The offset GROWS under a factor, and a speed-only hop starts with none
        // at all — so a snapshot would read "at 1000x" for the whole session while
        // the clock ran days ahead, which is the opposite of the visibility this
        // item exists for. Driven by the shared WallClock, so it costs one post
        // per second only while it is actually changing.
        final services = await buildServices();
        await travel(services, {'deltaMillis': 0, 'speed': AppClock.maxSpeed});
        final first = services.statusBar.itemForKey(HaLoServices.timeTravelStatusKey)!.title;

        // WallClock re-arms at its 100ms floor at the top factor; on the fake
        // clock, so is the time it reads.
        await Future<void>.delayed(const Duration(milliseconds: 400));

        final later = services.statusBar.itemForKey(HaLoServices.timeTravelStatusKey)!.title;
        expect(later, isNot(first), reason: 'the offset it reports must keep up with the clock');
        expect(later, contains('1000x'));

        // And the ticker lets go, so nothing keeps posting after a reset.
        await travel(services, {'reset': true});
        await Future<void>.delayed(const Duration(milliseconds: 300));
        expect(services.statusBar.itemForKey(HaLoServices.timeTravelStatusKey), isNull);
      }),
    );
  });

  group('developer mode', () {
    test('travel is refused without it', () async {
      final services = await buildServices(developerMode: false);
      final outcome = await travel(services, {'deltaMillis': const Duration(hours: 1).inMilliseconds});

      expect(outcome!.failed, isTrue);
      expect(outcome.text, contains('developer mode'));
      expect(AppClock.instance.isTravelling, isFalse);
    });

    test('losing it puts the clock back', () async {
      final services = await buildServices();
      await travel(services, {'deltaMillis': const Duration(days: 1).inMilliseconds});
      expect(AppClock.instance.isTravelling, isTrue);

      await services.settings.setDeveloperMode(false);
      // The listener is synchronous with the settings notification, but the
      // reset it starts is a future (it may have sync to restore).
      await Future<void>.delayed(Duration.zero);

      expect(AppClock.instance.isTravelling, isFalse);
      expect(services.statusBar.itemForKey(HaLoServices.timeTravelStatusKey), isNull);
    });

    test('reset still works without it, so nobody is stranded', () async {
      final services = await buildServices();
      await travel(services, {'deltaMillis': const Duration(days: 1).inMilliseconds});
      await services.settings.setDeveloperMode(false);
      await Future<void>.delayed(Duration.zero);

      final outcome = await travel(services, {'reset': true});
      expect(outcome!.failed, isFalse);
    });
  });

  // Travel is permitted whatever the sync account is, including a real
  // email-identified one: `WritePolicy` admits only test data while the clock
  // is travelled, so the account's identity says nothing about what the
  // session can damage. These pin that, because the obvious "safer" instinct
  // is to re-add a gate here — and it would key on a cached `accountData`
  // payload that fails closed on absence but open on staleness.
  group('travel and the sync account', () {
    test('a real, email-identified account no longer refuses travel', () async {
      final services = await buildServices(syncEnabled: true, currentAccount: {'uuid': 'abc12345', 'email': 'ki2d@example.com', 'call': 'KI2D'});
      final outcome = await travel(services, {'deltaMillis': const Duration(hours: 1).inMilliseconds});
      expect(outcome!.failed, isFalse);
      expect(AppClock.instance.isTravelling, isTrue);
    });

    test('sync on with no account payload in hand travels too', () async {
      // Nothing is keyed off the account, so an absent payload cannot be
      // misread as "anonymous": there is no question here to get wrong.
      final services = await buildServices(syncEnabled: true);
      final outcome = await travel(services, {'deltaMillis': const Duration(hours: 1).inMilliseconds});
      expect(outcome!.failed, isFalse);
    });

    test('an anonymous account still travels', () async {
      final services = await buildServices(currentAccount: {'uuid': 'abc12345'});
      final outcome = await travel(services, {'deltaMillis': const Duration(hours: 1).inMilliseconds});
      expect(outcome!.failed, isFalse);
    });
  });

  group('sync while travelling', () {
    Future<HaLoServices> withSync() => buildServices(syncEnabled: true, currentAccount: {'uuid': 'abc12345'});

    test('sync keeps running, and the operator\'s setting is untouched', () async {
      final services = await withSync();
      expect(services.settings.syncEnabled, isTrue, reason: 'sanity: sync started on');

      await travel(services, {'deltaMillis': const Duration(days: 1).inMilliseconds});

      // Both halves matter. The setting was never written — a dev tool that
      // writes it leaves it wrong for good if the app is quit before travel
      // ends — and nothing holds sync off any more either, because what a
      // travelled session may write is bounded instead.
      expect(services.settings.syncEnabled, isTrue);
      expect(services.syncEngine.travelRefusesSync, isTrue, reason: 'the flag survives for the destructive pair, which still refuse');
    });

    test('sync can be turned ON while travelling, from any surface', () async {
      final services = await buildServices();
      await travel(services, {'deltaMillis': const Duration(days: 1).inMilliseconds});

      await services.setSyncEnabled(true);
      expect(services.settings.syncEnabled, isTrue);
      expect(
        services.statusBar.activeNotices.map((n) => n.key),
        isNot(contains('clock:timeTravelHoldsSync')),
        reason: 'the refusal notice went with the refusal',
      );
    });

    test('stepping the clock costs the operator nothing', () async {
      // Several hops and a reset: with the setting untouched throughout there is
      // no remembered value to get wrong, which is what the old
      // remember-and-restore shape could do on a second hop.
      final services = await withSync();
      for (var i = 0; i < 3; i++) {
        await travel(services, {'deltaMillis': const Duration(days: 1).inMilliseconds});
      }
      await travel(services, {'reset': true});
      expect(services.settings.syncEnabled, isTrue);
    });

    test('a refused travel leaves sync exactly as it was', () async {
      // The ordering trap: anything switched off on travel's behalf BEFORE
      // `travel()` validates its arguments stays off, with no travel to undo it.
      final services = await withSync();
      final outcome = await travel(services, {'deltaMillis': 0, 'speed': 0.0});

      expect(outcome!.failed, isTrue);
      expect(services.settings.syncEnabled, isTrue);
      expect(AppClock.instance.isTravelling, isFalse);
    });
  });

  // The real dev-commands extension, so what is asserted about the palette is
  // what the palette actually gets.
  group('the real command hook', () {
    late SettingsService settings;
    late ExtensionService extensions;

    Future<void> boot({required bool developerMode}) async {
      SharedPreferences.setMockInitialValues({});
      settings = SettingsService(await SharedPreferences.getInstance());
      await settings.setDeveloperMode(developerMode);
      extensions = ExtensionService()..settings = settings;
      await startWithShippedExtensions(extensions);
    }

    Future<Map<String, dynamic>?> interpret(String input) async {
      final entries = await extensions.host!.invokeHookAll('command', method: 'interpret', args: {'input': input});
      for (final entry in entries) {
        if (entry['ok'] == true && entry['value'] is Map) {
          return (entry['value'] as Map).cast<String, dynamic>();
        }
      }
      return null;
    }

    test('DEVTT dispatches devTimeTravel with the parsed offset', () async {
      await boot(developerMode: true);
      final result = await interpret('DEVTT +3h');
      expect(result, isNotNull);
      final commands = (result!['commands'] as List).cast<Map>();
      expect(commands.single['devTimeTravel'], {'deltaMillis': 3 * 60 * 60 * 1000});
    });

    test('bare DEVTT dispatches a reset', () async {
      await boot(developerMode: true);
      final result = await interpret('DEVTT');
      final commands = (result!['commands'] as List).cast<Map>();
      expect(commands.single['devTimeTravel'], {'reset': true});
    });

    test('DEVTT does not exist outside developer mode', () async {
      // Not an error and not a refusal — no match at all, so the field treats it
      // as ordinary text. Every other guard in this feature is app-side; this is
      // the one that keeps a non-developer from reaching them in the first place.
      await boot(developerMode: false);
      expect(await interpret('DEVTT'), isNull);
      expect(await interpret('DEVTT +3h'), isNull);
    });

    test('DEVTT is never listed in the command palette, even in developer mode', () async {
      // The explicit requirement, and the reason the hook has no `catalog` at
      // all: the palette and the empty-field samples are DISCOVERY surfaces, and
      // a clock that disagrees with the operator's wristwatch must not be
      // something anyone finds by browsing.
      //
      // Belt and braces on purpose. A `catalog` gated on developer mode would
      // ALSO be invisible today — but only because every catalog hook is
      // currently handed `args` where it declares `ctx` (the kernel's generic
      // member call is `member(args, ctx)`), so `ctx.developerMode` is
      // undefined for all of them. Having no catalog at all is what keeps this
      // command out of the palette on purpose rather than by accident, and keeps
      // it out once that is fixed.
      await boot(developerMode: true);
      final entries = await extensions.host!.invokeHookAll('command', method: 'catalog', args: const {});
      final commands = <String>[];
      for (final entry in entries) {
        if (entry['ok'] == true && entry['value'] is List) {
          for (final item in entry['value'] as List) {
            if (item is Map && item['command'] is String) commands.add(item['command'] as String);
          }
        }
      }
      expect(commands, contains('RELOAD'), reason: 'sanity: the catalog fan-out answered — absence below is real, not an empty read');
      expect(commands, isNot(contains('DEVTT')));
      expect(commands, isNot(contains('DEVTIMETRAVEL')));
    });
  });
}
