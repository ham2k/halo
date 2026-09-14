// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Switch Accounts dialog (issue #79) is a small state machine over
// `POST v1/client/permissions`, and each transition encodes a user promise:
// an already-permitted account switches with one tap, an email challenge
// puts the confirmation code ON THIS SCREEN (the other device types it), a
// QR code carries the exact deep link app-polo's scanner expects, and
// success is only ever declared when the server says the account actually
// changed. These tests pin those promises, not widget cosmetics.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/error_reporting_service.dart';
import 'package:ham2k_logger/services/sibling_apps_service.dart';
import 'package:ham2k_logger/views/switch_accounts_dialog.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../support/error_reporting_fakes.dart';

Map<String, dynamic> accountData({String uuid = 'acct-1', List<Map<String, dynamic>> others = const []}) => {
      'current_account': {'uuid': uuid, 'call': 'N0CALL', 'email': 'me@example.com'},
      'accounts': others,
      // The current account's counts arrive top-level, not as stats — and on
      // the device's rule (`active`/`contacts`), never the tombstone-counting
      // `total`, which is the one the Sync panel must agree with.
      'operations': {'total': 4, 'active': 3},
      'qsos': {'total': 180, 'contacts': 120},
    };

Future<void> pumpDialog(
  WidgetTester tester, {
  required Future<Map<String, dynamic>?> Function() fetchAccountData,
  required Future<Map<String, dynamic>?> Function(String? email) linkClient,
  Future<Map<String, dynamic>?> Function(String email)? linkClientWithEmail,
  DateTime Function()? now,
  List<bool?>? results,
  List<SiblingApp> siblings = const [],
  Future<bool> Function(SiblingApp app, String url)? openSibling,
}) async {
  await tester.pumpWidget(
    TranslationProvider(
        child: MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            // The production path (showSwitchAccountsDialog) is a Modal
            // Pane; opened here directly so tests can inject the poll
            // interval and clock.
            final result = await showModalPane<bool>(
              context,
              title: 'Switch Accounts',
              barrierDismissible: false,
              builder: (context) => SwitchAccountsPane(
                fetchAccountData: fetchAccountData,
                linkClient: linkClient,
                linkClientWithEmail: linkClientWithEmail ?? (email) async => {},
                // Mirrors showSwitchAccountsDialog. The header close icon
                // decides where the footer needs a Cancel of its own, so this
                // file — the DIALOG's harness — must set it; the `false`
                // configuration is the onboarding step's, covered over in
                // onboarding_test.dart.
                hostHasCloseIcon: true,
                siblings: siblings,
                openSibling: openSibling,
                pollInterval: const Duration(seconds: 5),
                now: now ?? DateTime.now,
              ),
            );
            results?.add(result);
          },
          child: const Text('open'),
        ),
      ),
    )),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('quick switch: tapping an already-permitted account links by its email and closes as switched', (tester) async {
    final linkedEmails = <String?>[];
    final results = <bool?>[];
    await pumpDialog(
      tester,
      results: results,
      fetchAccountData: () async => accountData(others: [
        {
          'uuid': 'acct-2',
          'call': 'K2XYZ',
          'email': 'other@example.com',
          'stats': {'qso_count': 42, 'operation_count': 1},
        },
      ]),
      linkClient: (email) async {
        linkedEmails.add(email);
        return {
          'permission': {'status': 'active', 'account': 'acct-2'},
        };
      },
    );

    // The current account gets its own headed row — the email identity on
    // the first line (never the callsign: accounts are identified by email),
    // counts (from the response's top-level totals) on the second — and
    // other accounts follow under their own header with per-account stats.
    expect(find.text('Current account'), findsOneWidget);
    expect(find.text('me@example.com'), findsOneWidget);
    expect(find.text('120 QSOs · 3 operations'), findsOneWidget);
    expect(find.text('Other accounts'), findsOneWidget);
    expect(find.text('other@example.com'), findsOneWidget);
    expect(find.text('42 QSOs · 1 operation'), findsOneWidget);
    await tester.tap(find.text('other@example.com'));
    await tester.pumpAndSettle();

    // The switch reuses the existing permission — linked by that account's
    // email — and reports success so the caller kicks reconciliation.
    expect(linkedEmails, ['other@example.com']);
    expect(results, [true]);
  });

  testWidgets('quick switch: rows show the confirmed email their tap acts on, and email-less rows are inert', (tester) async {
    final linkedEmails = <String?>[];
    await pumpDialog(
      tester,
      fetchAccountData: () async => accountData(others: [
        // An account reachable only via the QR/blank-permission path.
        {'uuid': '0a1b2c3d-4e5f-6789-abcd-ef0123456789', 'call': 'K2XYZ'},
        {'uuid': 'acct-9', 'email': 'confirmed@example.com', 'pending_email': 'unconfirmed@example.com'},
      ]),
      linkClient: (email) async {
        linkedEmails.add(email);
        return {'permission': {}};
      },
    );

    // The trap: displaying an address the tap wouldn't use. Quick switch
    // links by the confirmed email, so that's the one on the row — never
    // the pending address.
    expect(find.text('confirmed@example.com'), findsOneWidget);
    expect(find.textContaining('unconfirmed@example.com'), findsNothing);

    // An email-less account has nothing to switch to: the row is labeled
    // but a tap must be a no-op, not a silent failed link attempt.
    expect(find.text('Anonymous Account (#0A1B2C3D)'), findsOneWidget);
    await tester.tap(find.text('Anonymous Account (#0A1B2C3D)'));
    await tester.pumpAndSettle();
    expect(linkedEmails, isEmpty);
  });

  testWidgets('a sub-mode offers Back alone, and the menu the way out', (tester) async {
    final results = <bool?>[];
    await pumpDialog(
      tester,
      results: results,
      fetchAccountData: () async => accountData(),
      linkClient: (email) async => {'permission': {'status': 'pending', 'challenge_token': 'A1B2C3'}},
    );

    // The menu has no Back, so it carries the way out itself. Nothing is
    // pending there — a quick switch takes effect on the tap — so the verb is
    // Done, never Cancel (user-interface.md §Dialogs).
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Cancel'), findsNothing);

    await tester.tap(find.text('Link with an email address'));
    await tester.pumpAndSettle();

    // A sub-mode's Back IS the way out of it, so nothing sits beside it: a
    // Cancel here would be a second dismiss next to the first, and a third
    // next to the header's close icon.
    expect(find.text('Back'), findsOneWidget);
    expect(find.text('Cancel'), findsNothing);
    expect(find.text('Done'), findsNothing);

    // Back retraces rather than closing, and Done is a way out, not decoration.
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Link with a QR code'), findsOneWidget, reason: 'Back returns to the menu');
    expect(results, isEmpty, reason: 'Back must not close the pane');

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(results, [false]);
  });

  testWidgets('the header icon closes from the menu, having backed out of a poll', (tester) async {
    // The path a user actually walks out of a QR challenge: Back to the menu,
    // then close. Both legs go through code that a live poll changes the
    // meaning of, so this pins the whole sequence rather than either half.
    final results = <bool?>[];
    await pumpDialog(
      tester,
      results: results,
      fetchAccountData: () async => accountData(),
      linkClient: (email) async => {
        'permission': {'status': 'pending', 'client': 'c1', 'challenge_token': 'FFEE99'},
      },
    );

    await tester.tap(find.text('Link with a QR code'));
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsOneWidget);

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(MdiIcons.close));
    await tester.pumpAndSettle();
    expect(find.text('Link with a QR code'), findsNothing, reason: 'the header icon must still close the pane');
  });

  testWidgets('a request that never returns still leaves an enabled way out', (tester) async {
    // Onboarding embeds this pane with no chrome of its own, so the footer is
    // the entire control surface. Back-to-menu is disabled while busy; if the
    // host call throws or hangs, _busy never clears, and without an exit
    // beside it the user is stranded on a spinner during first-run setup.
    var cancelled = false;
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: SwitchAccountsPane(
              fetchAccountData: () async => accountData(),
              // Never completes — a host call that has gone away, which is
              // what leaves _busy stuck true.
              linkClient: (email) => Completer<Map<String, dynamic>?>().future,
              linkClientWithEmail: (email) => Completer<Map<String, dynamic>?>().future,
              hideAccountsList: true,
              cancelLabel: 'Back',
              onCancel: () => cancelled = true,
              onLinked: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Link with a QR code'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Plain pumps, never pumpAndSettle, for the rest of this test: _busy is
    // stuck true, so the busy spinner animates forever and nothing settles —
    // which is the stranding this test is about.
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    // Exactly one Back — never two spelled the same — and it works.
    expect(find.text('Back'), findsOneWidget);
    await tester.tap(find.text('Back'));
    await tester.pump();
    expect(cancelled, isTrue, reason: 'the only control on screen must not be a dead one');
  });

  testWidgets('email flow: a pending permission shows its challenge code on screen', (tester) async {
    await pumpDialog(
      tester,
      fetchAccountData: () async => accountData(),
      linkClient: (email) async => {
        'permission': {'status': 'pending', 'challenge_token': 'A1B2C3'},
      },
    );

    await tester.tap(find.text('Link with an email address'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'friend@example.com');
    await tester.tap(find.text('Link account'));
    await tester.pumpAndSettle();

    // The code the OTHER device must type is displayed here, verbatim.
    expect(find.text('A1B2C3'), findsOneWidget);
    expect(find.textContaining('friend@example.com'), findsOneWidget);
  });

  testWidgets('email flow: the challenge code can be copied to the clipboard', (tester) async {
    // Typing the code onto another device is error-prone; a copy button
    // puts it on the clipboard verbatim.
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    await pumpDialog(
      tester,
      fetchAccountData: () async => accountData(),
      linkClient: (email) async => {
        'permission': {'status': 'pending', 'challenge_token': 'A1B2C3'},
      },
    );

    await tester.tap(find.text('Link with an email address'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'friend@example.com');
    await tester.tap(find.text('Link account'));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Copy code'));
    await tester.pumpAndSettle();

    expect(copied, 'A1B2C3');
    expect(find.text('Copied code to clipboard'), findsOneWidget);
  });

  testWidgets('email flow: a 404 tells the user no account matched, not a generic failure', (tester) async {
    await pumpDialog(
      tester,
      fetchAccountData: () async => accountData(),
      linkClient: (email) async => {'error': 'LoFi request failed: HTTP 404', 'error_status': 404},
    );

    await tester.tap(find.text('Link with an email address'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'typo@example.com');
    await tester.tap(find.text('Link account'));
    await tester.pumpAndSettle();

    expect(find.text('No account found for typo@example.com.'), findsOneWidget);
    // Still on the entry form — the user can correct the address.
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('email flow: "send a confirmation email instead" falls back to the emailed link', (tester) async {
    final emailed = <String>[];
    await pumpDialog(
      tester,
      fetchAccountData: () async => accountData(),
      linkClient: (email) async => {
        'permission': {'status': 'pending', 'challenge_token': 'A1B2C3'},
      },
      linkClientWithEmail: (email) async {
        emailed.add(email);
        return {'permission': {}};
      },
    );

    await tester.tap(find.text('Link with an email address'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'friend@example.com');
    await tester.tap(find.text('Link account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send a confirmation email instead'));
    await tester.pumpAndSettle();

    expect(emailed, ['friend@example.com']);
    expect(find.textContaining('An email was sent to friend@example.com'), findsOneWidget);
  });

  testWidgets('quick switch: a revoked permission falls through to the code view with the fresh challenge', (tester) async {
    await pumpDialog(
      tester,
      fetchAccountData: () async => accountData(others: [
        {'uuid': 'acct-2', 'call': 'K2XYZ', 'email': 'other@example.com'},
      ]),
      // The permission this client held was revoked server-side, so the
      // switch comes back pending — but with a usable challenge.
      linkClient: (email) async => {
        'permission': {'status': 'pending', 'challenge_token': 'D4E5F6'},
      },
    );

    await tester.tap(find.text('other@example.com'));
    await tester.pumpAndSettle();

    // Straight to the code view — no retyping the email.
    expect(find.text('D4E5F6'), findsOneWidget);
    expect(find.textContaining('other@example.com'), findsOneWidget);
  });

  testWidgets('email flow: an expired challenge code is renewed on the next poll tick', (tester) async {
    var fakeNow = DateTime.utc(2026, 1, 1, 12, 0, 0);
    var issued = 0;
    await pumpDialog(
      tester,
      fetchAccountData: () async => accountData(),
      now: () => fakeNow,
      linkClient: (email) async {
        issued++;
        return {
          'permission': {
            'status': 'pending',
            'challenge_token': issued == 1 ? 'AAA111' : 'BBB222',
            'challenge_expires_at': fakeNow.add(const Duration(minutes: 10)).toIso8601String(),
          },
        };
      },
    );

    await tester.tap(find.text('Link with an email address'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'friend@example.com');
    await tester.tap(find.text('Link account'));
    await tester.pumpAndSettle();
    expect(find.text('AAA111'), findsOneWidget);

    // While the challenge is alive, poll ticks must NOT reissue it (the
    // code the user may be mid-typing elsewhere would churn).
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(issued, 1);

    // The server expires challenges after 10 minutes; a dead code on
    // screen with "waiting for confirmation" would wait forever.
    fakeNow = fakeNow.add(const Duration(minutes: 11));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(issued, 2);
    expect(find.text('BBB222'), findsOneWidget);
    expect(find.text('AAA111'), findsNothing);
  });

  testWidgets('QR flow: encodes the app-polo deep link and closes once the account actually changes', (tester) async {
    var currentUuid = 'acct-1';
    final results = <bool?>[];
    await pumpDialog(
      tester,
      results: results,
      fetchAccountData: () async => accountData(uuid: currentUuid),
      linkClient: (email) async {
        expect(email, isNull, reason: 'the QR permission must be a blank (account-less) request');
        return {
          'permission': {
            'status': 'pending',
            'client': 'client-uuid-1',
            'challenge_token': 'FFEE99',
            'challenge_expires_at': DateTime.now().add(const Duration(minutes: 10)).toUtc().toIso8601String(),
          },
        };
      },
    );

    await tester.tap(find.text('Link with a QR code'));
    await tester.pumpAndSettle();

    // The QR payload is the deep link an already-linked phone consumes —
    // scheme, path, and both params, exactly as app-polo builds it. The
    // widget is keyed by its payload, which is how we can read it back.
    expect(
      find.byKey(const ValueKey('com.ham2k:///link_client?id=client-uuid-1&token=FFEE99')),
      findsOneWidget,
    );
    expect(find.byType(QrImageView), findsOneWidget);

    // One poll tick with the account unchanged: dialog stays open, waiting.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(results, isEmpty);

    // The other device approves (server now reports a different account):
    // the next tick declares success.
    currentUuid = 'acct-9';
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(results, [true]);
  });

  testWidgets('sibling flow: the menu offers each app on the device, and hands it the QR link', (tester) async {
    // Same permission, same link as the QR flow — the reader differs, not
    // the payload. A sibling list with no opener is not offered at all: a
    // row that leads nowhere is worse than none.
    const polo = SiblingApp(id: 'com.ham2k.polo.prod', name: 'Ham2K Portable Logger');
    var currentUuid = 'acct-1';
    final results = <bool?>[];
    final opened = <(SiblingApp, String)>[];
    await pumpDialog(
      tester,
      results: results,
      siblings: const [polo],
      openSibling: (app, url) async {
        opened.add((app, url));
        return true;
      },
      fetchAccountData: () async => accountData(uuid: currentUuid),
      linkClient: (email) async {
        expect(email, isNull);
        return {
          'permission': {
            'status': 'pending',
            'client': 'client-uuid-1',
            'challenge_token': 'FFEE99',
            'challenge_expires_at': DateTime.now().add(const Duration(minutes: 10)).toUtc().toIso8601String(),
          },
        };
      },
    );

    await tester.tap(find.text('Link with account in older version'));
    await tester.pumpAndSettle();
    expect(opened, [(polo, 'com.ham2k:///link_client?id=client-uuid-1&token=FFEE99')]);
    expect(find.textContaining('Approve the request in Ham2K Portable Logger'), findsOneWidget);
    // No onFallback here: the Settings pane's way out is Back, not a
    // "set up fresh" that means nothing outside onboarding.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.textContaining("Didn't work?"), findsOneWidget);
    expect(find.text('Set up fresh'), findsNothing);

    currentUuid = 'acct-9';
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(results, [true]);
  });

  Map<String, dynamic> pendingPermission() => {
        'permission': {
          'status': 'pending',
          'client': 'client-uuid-1',
          'challenge_token': 'FFEE99',
          'challenge_expires_at': DateTime.now().add(const Duration(minutes: 10)).toUtc().toIso8601String(),
        },
      };
  const polo = SiblingApp(id: 'com.ham2k.polo.prod', name: 'Ham2K Portable Logger');

  testWidgets('sibling flow: two PoLo flavors are named, one is "the older version"', (tester) async {
    // Each row opens a different app; two reading identically leave the
    // operator guessing.
    await pumpDialog(
      tester,
      siblings: const [polo, SiblingApp(id: 'com.ham2k.polo.beta', name: 'Ham2K Portable Logger (Beta)')],
      openSibling: (_, _) async => true,
      fetchAccountData: () async => accountData(),
      linkClient: (email) async => {},
    );
    expect(find.text('Link with account in older version'), findsNothing);
    expect(find.text('Link with Ham2K Portable Logger'), findsOneWidget);
    expect(find.text('Link with Ham2K Portable Logger (Beta)'), findsOneWidget);
  });

  testWidgets('sibling flow: a resume whose poll got no answer says unreachable, not "didn\'t work"', (tester) async {
    // The fallback that line offers (in onboarding, "set up fresh") is a
    // choice against an account that may well be linked by now; a tick the
    // server never answered must not be read as "not yet".
    var reachable = true;
    await pumpDialog(
      tester,
      siblings: const [polo],
      openSibling: (_, _) async => true,
      fetchAccountData: () async => reachable ? accountData() : throw StateError('offline'),
      linkClient: (email) async => pendingPermission(),
    );
    await tester.tap(find.text('Link with account in older version'));
    await tester.pumpAndSettle();
    reachable = false;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.textContaining("Didn't work?"), findsNothing);
    expect(find.text('Could not reach the sync server. Try again later.'), findsOneWidget);
  });

  testWidgets('sibling flow: an expired challenge is renewed AND the operator is told to hand it across again', (tester) async {
    // A QR repaints itself with the new token; the sibling still holds the
    // dead one, and only the operator can carry the new one over.
    var now = DateTime.utc(2026, 1, 1, 12);
    var requests = 0;
    await pumpDialog(
      tester,
      now: () => now,
      siblings: const [polo],
      openSibling: (_, _) async => true,
      fetchAccountData: () async => accountData(),
      linkClient: (email) async {
        requests++;
        return {
          'permission': {
            'status': 'pending',
            'client': 'client-uuid-1',
            'challenge_token': 'T$requests',
            'challenge_expires_at': now.add(const Duration(minutes: 10)).toIso8601String(),
          },
        };
      },
    );
    await tester.tap(find.text('Link with account in older version'));
    await tester.pumpAndSettle();
    expect(find.textContaining('The link expired'), findsNothing);
    now = now.add(const Duration(minutes: 11));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(requests, 2);
    expect(find.textContaining('The link expired'), findsOneWidget);
  });

  testWidgets('sibling flow: an opener that throws is reported and painted, and a later success ends the streak', (tester) async {
    // The service lets a PlatformException through precisely so that a
    // native defect reaches here and is reported rather than painted as
    // "could not open" and forgotten.
    final backend = FakeErrorReportingBackend();
    ErrorReportingService.resetFailureStreaks();
    addTearDown(ErrorReportingService.resetFailureStreaks);
    var throws = true;
    await withErrorHooks(() async {
      await pumpDialog(
        tester,
        siblings: const [polo],
        openSibling: (_, _) async => throws ? throw PlatformException(code: 'error', message: 'native blew up') : true,
        fetchAccountData: () async => accountData(),
        linkClient: (email) async => pendingPermission(),
      );
      await tester.tap(find.text('Link with account in older version'));
      await tester.pumpAndSettle();
      expect(find.text('Could not open Ham2K Portable Logger.'), findsOneWidget);
      await tester.tap(find.text('Open Ham2K Portable Logger again'));
      await tester.pumpAndSettle();
      expect(backend.exceptions, isEmpty, reason: 'two in a row is a flaky day, not yet a defect');
      throws = false;
      await tester.tap(find.text('Open Ham2K Portable Logger again'));
      await tester.pumpAndSettle();
      expect(find.text('Could not open Ham2K Portable Logger.'), findsNothing);
      throws = true;
      await tester.tap(find.text('Open Ham2K Portable Logger again'));
      await tester.pumpAndSettle();
      expect(backend.exceptions, isEmpty, reason: 'the success in between reset the streak');
    }, backend: backend);
  });

  testWidgets('sibling flow: no opener, no rows', (tester) async {
    await pumpDialog(
      tester,
      siblings: const [SiblingApp(id: 'com.ham2k.polo.prod', name: 'Ham2K Portable Logger')],
      fetchAccountData: () async => accountData(),
      linkClient: (email) async => {},
    );
    expect(find.text('Link with account in older version'), findsNothing);
    expect(find.text('Link with a QR code'), findsOneWidget);
  });

  // Through the PRODUCTION helper, not pumpDialog: the barrier flag is
  // showSwitchAccountsDialog's own argument, so a harness that passes its own
  // copy pins nothing about what ships. Everything else here goes through
  // pumpDialog for the poll clock it can inject.
  testWidgets('dismissing mid-request abandons it, and leaves no poll behind', (tester) async {
    // The gap between asking for a challenge and polling for it. A guard that
    // watches only the poll leaves this window open: a dismissal inside it
    // slips past uninterrupted, handing the caller a null where it needs "not
    // switched", and _showQr — resuming on a State dispose has finished with —
    // starts a periodic Timer nothing can cancel, calling fetchAccountData
    // every 5s for the life of the process with every reply thrown away.
    var polls = 0;
    final gate = Completer<Map<String, dynamic>?>();
    final results = <bool?>[];

    await pumpDialog(
      tester,
      results: results,
      fetchAccountData: () async {
        polls++;
        return accountData();
      },
      linkClient: (email) => gate.future,
    );

    await tester.tap(find.text('Link with a QR code'));
    await tester.pump();
    final pollsAtDismiss = polls;

    await tester.tap(find.byIcon(MdiIcons.close));
    await tester.pumpAndSettle();
    expect(results, [false], reason: 'the dismissal must be intercepted, not slip past as a bare pop');

    // Let the request land on the now-disposed State, then run well past
    // several poll intervals. A leaked Timer also fails the test outright —
    // the binding reports one still pending after disposal.
    gate.complete(const {
      'permission': {'status': 'pending', 'client': 'c1', 'challenge_token': 'TOK'},
    });
    await tester.pump();
    await tester.pump(const Duration(seconds: 30));
    expect(polls, pollsAtDismiss, reason: 'nothing may keep polling once the pane is gone');
  });

  testWidgets('a poll that lands after dismissal cannot close the screen underneath', (tester) async {
    // `mounted` is not "still on screen": a route stays mounted for its whole
    // exit animation. A poll suspended on the network across a dismissal wakes
    // on a live State whose route is already leaving, and if it declares
    // success there, its Navigator.pop lands on the caller's own screen and
    // shuts it. Needs a route underneath to catch that, so no pumpDialog here.
    final gate = Completer<Map<String, dynamic>?>();
    var fetches = 0;
    final results = <bool?>[];

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Builder(
            builder: (rootContext) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(rootContext).push(MaterialPageRoute(
                  builder: (settingsContext) => Scaffold(
                    body: TextButton(
                      onPressed: () async => results.add(await showModalPane<bool>(
                        settingsContext,
                        title: 'Switch Accounts',
                        barrierDismissible: false,
                        builder: (_) => SwitchAccountsPane(
                          fetchAccountData: () async {
                            fetches++;
                            if (fetches == 1) return {'current_account': {'uuid': 'acct-1'}, 'accounts': []};
                            return gate.future;
                          },
                          linkClient: (email) async => {
                            'permission': {'status': 'pending', 'client': 'c1', 'challenge_token': 'TOK'},
                          },
                          linkClientWithEmail: (email) async => const {},
                          hostHasCloseIcon: true,
                          pollInterval: const Duration(seconds: 5),
                        ),
                      )),
                      child: const Text('stand-in for Settings'),
                    ),
                  ),
                )),
                child: const Text('root'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('root'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('stand-in for Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Link with a QR code'));
    await tester.pumpAndSettle();

    // One tick fires and hangs on the gate; dismiss while it is suspended.
    await tester.pump(const Duration(seconds: 6));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    // It resumes to find the account genuinely changed — the one case that
    // makes it want to declare success and pop.
    gate.complete(const {'current_account': {'uuid': 'acct-2'}, 'accounts': []});
    await tester.pumpAndSettle();

    expect(results, [false], reason: 'the first exit decides the answer');
    expect(find.text('stand-in for Settings'), findsOneWidget,
        reason: "the caller's screen must survive a late success");
  });

  // Failure paths. Everything below is a way this pane can fail to do what
  // was asked; each one reached the operator as a spinner that stopped, or a
  // screen waiting on something that was never created, before these existed.

  testWidgets('a host call that throws leaves a message, not a spinner', (tester) async {
    await pumpDialog(
      tester,
      fetchAccountData: () async => accountData(),
      // syncLinkClient converts only ExtensionHostException to null; anything
      // else escapes the await and takes _busy with it.
      linkClient: (email) async => throw StateError('the host blew up'),
    );

    await tester.tap(find.text('Link with an email address'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'friend@example.com');
    await tester.tap(find.text('Link account'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'the throw must be handled, not escape the handler');

    expect(find.text(t.switchAccounts.requestFailed), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing, reason: 'not left spinning');
    expect(find.text('Link account'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Link account')).onPressed,
        isNotNull, reason: 'the operator must be able to try again');
  });

  testWidgets('three throws in a row are reported; one is not', (tester) async {
    // The bargain reportIfRepeated exists for: a tunnel is not a defect, a
    // call that never works is.
    final backend = FakeErrorReportingBackend();
    ErrorReportingService.resetFailureStreaks();
    addTearDown(ErrorReportingService.resetFailureStreaks);

    await withErrorHooks(() async {
      await pumpDialog(
        tester,
        fetchAccountData: () async => accountData(),
        linkClient: (email) async => throw StateError('the host blew up'),
      );
      await tester.tap(find.text('Link with an email address'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'friend@example.com');

      for (var attempt = 1; attempt <= 3; attempt++) {
        await tester.tap(find.text('Link account'));
        await tester.pumpAndSettle();
        tester.takeException();
        expect(backend.exceptions, hasLength(attempt < 3 ? 0 : 1),
            reason: 'upload lands on the third failure, not before and not twice');
      }
    }, backend: backend);
  });

  testWidgets('a quick switch the server neither accepts nor challenges says so', (tester) async {
    // Reachable, no error field, but the permission is neither active nor
    // carries a challenge — a shape this client has no move for. Without a
    // message the spinner just stops and the row reads as a dead control.
    await pumpDialog(
      tester,
      fetchAccountData: () async => accountData(others: [
        {'uuid': 'acct-2', 'email': 'other@example.com'},
      ]),
      linkClient: (email) async => {'permission': {'status': 'revoked'}},
    );

    await tester.tap(find.text('other@example.com'));
    await tester.pumpAndSettle();

    expect(find.text(t.switchAccounts.switchNotAccepted), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('no challenge means no challenge screen', (tester) async {
    // A null permission still moved to the code view and started polling: an
    // em dash under "Waiting for confirmation…", waiting on a challenge the
    // server never made. An empty map is enough to trigger it.
    await pumpDialog(
      tester,
      fetchAccountData: () async => accountData(),
      linkClient: (email) async => const {},
    );

    await tester.tap(find.text('Link with an email address'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'friend@example.com');
    await tester.tap(find.text('Link account'));
    await tester.pumpAndSettle();

    expect(find.text(t.switchAccounts.noConfirmationCode), findsOneWidget);
    expect(find.text(t.switchAccounts.waitingForConfirmation), findsNothing,
        reason: 'nothing is being waited for');
    expect(find.text('—'), findsNothing, reason: 'no code was ever issued');
    expect(find.text(t.switchAccounts.emailAddress), findsOneWidget, reason: 'still on the email step');
  });

  testWidgets('a failed QR request leaves no spinner claiming to load', (tester) async {
    var attempts = 0;
    await pumpDialog(
      tester,
      fetchAccountData: () async => accountData(),
      linkClient: (email) async {
        attempts++;
        // First attempt unreachable, second works.
        if (attempts == 1) return null;
        return {'permission': {'client': 'c1', 'challenge_token': 'TOK'}};
      },
    );

    await tester.tap(find.text('Link with a QR code'));
    await tester.pumpAndSettle();
    expect(find.text(t.switchAccounts.serverUnreachable), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing,
        reason: 'a failed request must not leave a spinner claiming to be loading');

    // Back out and retry: the code now renders, and the red text is gone.
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Link with a QR code'));
    await tester.pumpAndSettle();

    expect(find.byType(QrImageView), findsOneWidget);
  });

  testWidgets('a renewal that succeeds clears the failure that came before it', (tester) async {
    // The renewal path never passes through the taps that reset _error, so
    // only the shared attempt helper can retire a stale message here. Without
    // that, a code the operator can actually use sits under red text saying
    // the server could not be reached.
    var fakeNow = DateTime.utc(2026, 1, 1, 12, 0, 0);
    var issued = 0;
    await pumpDialog(
      tester,
      fetchAccountData: () async => accountData(),
      now: () => fakeNow,
      linkClient: (email) async {
        issued++;
        // First issues a challenge; the renewal fails; the one after works.
        if (issued == 2) return null;
        return {
          'permission': {
            'status': 'pending',
            'challenge_token': issued == 1 ? 'AAA111' : 'CCC333',
            'challenge_expires_at': fakeNow.add(const Duration(minutes: 10)).toIso8601String(),
          },
        };
      },
    );

    await tester.tap(find.text('Link with an email address'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'friend@example.com');
    await tester.tap(find.text('Link account'));
    await tester.pumpAndSettle();
    expect(find.text('AAA111'), findsOneWidget);

    // Expire it: the renewal tick fails, and says so.
    fakeNow = fakeNow.add(const Duration(minutes: 11));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text(t.switchAccounts.serverUnreachable), findsOneWidget);

    // The next tick renews successfully — the new code appears and the
    // stale failure goes with it.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('CCC333'), findsOneWidget);
    expect(find.text(t.switchAccounts.serverUnreachable), findsNothing);
  });

  testWidgets('the fetch on mount fails quietly — nobody asked for it', (tester) async {
    // The onboarding step embeds this pane with hideAccountsList, so it never
    // shows account data and both linking flows work without it. Painting
    // "could not reach the server" there greets the operator with a failure
    // for something they did not ask for and does not need.
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: SwitchAccountsPane(
              // What syncAccountData returns when there is no host.
              fetchAccountData: () async => null,
              linkClient: (email) async => const {},
              linkClientWithEmail: (email) async => const {},
              hideAccountsList: true,
              cancelLabel: 'Back',
              onCancel: () {},
              onLinked: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(t.switchAccounts.serverUnreachable), findsNothing);
    expect(find.text('Link with a QR code'), findsOneWidget, reason: 'the step is usable regardless');
  });

  testWidgets('a poll-driven renewal never builds the streak a person owns', (tester) async {
    // The streak separates "the world is unreliable" from "this is broken",
    // and only somebody pressing a button carries that meaning. A renewal
    // retrying every five seconds would otherwise reach the threshold on its
    // own, uploading the tunnel case the threshold exists to exclude — and
    // burning the count so a later real failure can never report.
    final backend = FakeErrorReportingBackend();
    ErrorReportingService.resetFailureStreaks();
    addTearDown(ErrorReportingService.resetFailureStreaks);

    await withErrorHooks(() async {
      var fakeNow = DateTime.utc(2026, 1, 1, 12, 0, 0);
      var issued = 0;
      await pumpDialog(
        tester,
        fetchAccountData: () async => accountData(),
        now: () => fakeNow,
        linkClient: (email) async {
          issued++;
          if (issued == 1) {
            return {
              'permission': {
                'status': 'pending',
                'challenge_token': 'AAA111',
                'challenge_expires_at': fakeNow.add(const Duration(minutes: 10)).toIso8601String(),
              },
            };
          }
          throw StateError('renewal keeps failing');
        },
      );

      await tester.tap(find.text('Link with an email address'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'friend@example.com');
      await tester.tap(find.text('Link account'));
      await tester.pumpAndSettle();
      expect(find.text('AAA111'), findsOneWidget);

      // Expire it and let several renewal ticks fail in a row.
      fakeNow = fakeNow.add(const Duration(minutes: 11));
      for (var tick = 0; tick < 4; tick++) {
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        tester.takeException();
      }

      expect(issued, greaterThan(3), reason: 'the renewals really did run and fail');
      expect(backend.exceptions, isEmpty, reason: 'a timer pressing the button is not a person doing it');
    }, backend: backend);
  });

  testWidgets('a rejection between throws breaks the streak', (tester) async {
    // "Failed three times in a row" has to be true. A server that ANSWERS —
    // even to say no — proves the call itself works, so it ends the run.
    final backend = FakeErrorReportingBackend();
    ErrorReportingService.resetFailureStreaks();
    addTearDown(ErrorReportingService.resetFailureStreaks);

    await withErrorHooks(() async {
      var call = 0;
      await pumpDialog(
        tester,
        fetchAccountData: () async => accountData(),
        linkClient: (email) async {
          call++;
          if (call == 3) return {'error': 'nope', 'error_status': 400};
          throw StateError('boom');
        },
      );
      await tester.tap(find.text('Link with an email address'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'friend@example.com');

      // throw, throw, rejection, throw — never three throws running.
      for (var i = 1; i <= 4; i++) {
        await tester.tap(find.text('Link account'));
        await tester.pumpAndSettle();
        tester.takeException();
      }
      expect(backend.exceptions, isEmpty);
    }, backend: backend);
  });

  testWidgets('submitting an empty address says so, from the button and from Go', (tester) async {
    // The guard returned in silence, so whichever control they pressed did
    // nothing at all — and it returned BEFORE the _error reset, leaving the
    // previous attempt's message on screen saying something else entirely.
    var calls = 0;
    await pumpDialog(
      tester,
      fetchAccountData: () async => accountData(),
      linkClient: (email) async {
        calls++;
        return null; // unreachable, so the first attempt leaves a message
      },
    );

    await tester.tap(find.text('Link with an email address'));
    await tester.pumpAndSettle();

    // Land a different message first, so silence would be visibly wrong.
    await tester.enterText(find.byType(TextField), 'friend@example.com');
    await tester.tap(find.text(t.switchAccounts.linkAccount));
    await tester.pumpAndSettle();
    expect(find.text(t.switchAccounts.serverUnreachable), findsOneWidget);

    // Now empty it and press the button.
    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.text(t.switchAccounts.linkAccount));
    await tester.pumpAndSettle();
    expect(find.text(t.switchAccounts.emailRequired), findsOneWidget);
    expect(find.text(t.switchAccounts.serverUnreachable), findsNothing,
        reason: 'the stale message must not outlive the attempt it described');
    expect(calls, 1, reason: 'an empty field makes no request');

    // The soft keyboard's Go key reaches _submitEmail without the button.
    await tester.enterText(find.byType(TextField), '');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text(t.switchAccounts.emailRequired), findsOneWidget);
    expect(calls, 1);
  });

  testWidgets('the shipped dialog refuses a tap outside', (tester) async {
    final results = <bool?>[];
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => results.add(await showSwitchAccountsDialog(
                context,
                fetchAccountData: () async => accountData(),
                linkClient: (email) async => const {},
                linkClientWithEmail: (email) async => const {},
              )),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Link with a QR code'), findsOneWidget);

    // Nothing is in flight here and the pane would happily close — this is
    // about the gesture, not the state. Losing a challenge to a mis-aimed tap
    // costs a trip back to the other device for a fresh code.
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(results, isEmpty, reason: 'the barrier must not dismiss this pane');
    expect(find.text('Link with a QR code'), findsOneWidget);

    // Escape is a decision, and it does close.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(results, hasLength(1));
  });

  testWidgets('Escape abandons an active QR poll; a tap outside still cannot', (tester) async {
    final results = <bool?>[];
    await pumpDialog(
      tester,
      results: results,
      fetchAccountData: () async => accountData(),
      linkClient: (email) async => {
        'permission': {
          'status': 'pending',
          'client': 'client-uuid-1',
          'challenge_token': 'FFEE99',
          'challenge_expires_at': DateTime.now().add(const Duration(minutes: 10)).toUtc().toIso8601String(),
        },
      },
    );

    await tester.tap(find.text('Link with a QR code'));
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsOneWidget);

    // A stray tap outside must never cost a challenge: losing it means a trip
    // back to the other device for a fresh code. The barrier's own handler is
    // null, so this is inert no matter what the PopScope says.
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(results, isEmpty, reason: 'a tap outside must not abandon the request');
    expect(find.byType(QrImageView), findsOneWidget, reason: 'the pane must still be open');

    // Escape is a deliberate act, so it abandons rather than being swallowed:
    // the poll stops and the caller is told the account did not change.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(results, [false]);
    expect(find.byType(QrImageView), findsNothing);
  });

  testWidgets('the header icon abandons an active poll too, not just Escape', (tester) async {
    final results = <bool?>[];
    await pumpDialog(
      tester,
      results: results,
      fetchAccountData: () async => accountData(),
      linkClient: (email) async => {
        'permission': {'status': 'pending', 'client': 'c1', 'challenge_token': 'FFEE99'},
      },
    );

    await tester.tap(find.text('Link with a QR code'));
    await tester.pumpAndSettle();

    // Both dismissals route through maybePop, so both meet the same PopScope
    // — a gesture it swallows is a control that does nothing.
    await tester.tap(find.byIcon(MdiIcons.close));
    await tester.pumpAndSettle();
    expect(results, [false]);
    expect(find.byType(QrImageView), findsNothing);
  });

  testWidgets('server unreachable: linking reports it and never fakes success', (tester) async {
    final results = <bool?>[];
    await pumpDialog(
      tester,
      results: results,
      fetchAccountData: () async => accountData(),
      linkClient: (email) async => null,
    );

    await tester.tap(find.text('Link with an email address'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'friend@example.com');
    await tester.tap(find.text('Link account'));
    await tester.pumpAndSettle();

    expect(find.text('Could not reach the sync server. Try again later.'), findsOneWidget);
    expect(results, isEmpty);
  });
}
