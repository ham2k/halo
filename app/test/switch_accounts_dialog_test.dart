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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/views/switch_accounts_dialog.dart';
import 'package:qr_flutter/qr_flutter.dart';

Map<String, dynamic> accountData({String uuid = 'acct-1', List<Map<String, dynamic>> others = const []}) => {
      'current_account': {'uuid': uuid, 'call': 'N0CALL', 'email': 'me@example.com'},
      'accounts': others,
      // The current account's counts arrive as top-level totals, not stats.
      'operations': {'total': 3},
      'qsos': {'total': 120},
    };

Future<void> pumpDialog(
  WidgetTester tester, {
  required Future<Map<String, dynamic>?> Function() fetchAccountData,
  required Future<Map<String, dynamic>?> Function(String? email) linkClient,
  Future<Map<String, dynamic>?> Function(String email)? linkClientWithEmail,
  DateTime Function()? now,
  List<bool?>? results,
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

  testWidgets('Escape cannot abandon an active QR poll, but the Cancel button still can', (tester) async {
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

    // Escape must not abandon an active poll any more than a stray tap
    // outside could — the pane opened with barrierDismissible: false
    // specifically to prevent that.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(results, isEmpty, reason: 'Escape must not abandon an active poll');
    expect(find.byType(QrImageView), findsOneWidget, reason: 'the pane must still be open');

    // The explicit Cancel button is a deliberate action and still works —
    // it pops directly rather than through the canPop-gated path.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(results, [false]);
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
