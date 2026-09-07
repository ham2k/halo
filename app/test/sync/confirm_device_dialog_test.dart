// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Confirm a Device dialog is the APPROVING side of client linking, and
// approving hands another device the operator's entire log. Each of these
// pins a promise that costs real data if it slips: the operator sees WHICH
// device before granting, an expired or wrong code never produces a
// confirm button that can only fail, and the token from a QR deep link is
// carried through to the approval — without it the server refuses, because
// that token is what binds an orphaned permission to this account.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/services/deep_link_service.dart';
import 'package:ham2k_logger/views/confirm_device_dialog.dart';

Future<void> pumpPane(
  WidgetTester tester, {
  Future<Map<String, dynamic>?> Function(String challengeToken)? findByCode,
  Future<Map<String, dynamic>?> Function({required String clientUuid, required String challengeToken})? findByClient,
  Future<Map<String, dynamic>?> Function({required String clientUuid, String? challengeToken})? approve,
  String? clientUuid,
  String? challengeToken,
  List<bool?>? results,
}) async {
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final result = await showModalPane<bool>(
                context,
                title: 'Confirm a Device',
                builder: (context) => ConfirmDevicePane(
                  findByCode: findByCode ?? (code) async => const {'permissions': []},
                  findByClient: findByClient ?? ({required clientUuid, required challengeToken}) async => const {},
                  approve: approve ?? ({required clientUuid, challengeToken}) async => const {},
                  clientUuid: clientUuid,
                  challengeToken: challengeToken,
                ),
              );
              results?.add(result);
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Map<String, dynamic> pendingPermission({String client = 'client-2', String name = "Sebastián's iPhone"}) => {
      'client': client,
      'client_name': name,
      'status': 'pending',
      'level': 'owner',
    };

void main() {
  testWidgets('a code names the device asking, and approving it links that client', (tester) async {
    final approved = <({String clientUuid, String? challengeToken})>[];
    final results = <bool?>[];
    await pumpPane(
      tester,
      results: results,
      findByCode: (code) async => {
        'permissions': [pendingPermission()],
      },
      approve: ({required clientUuid, challengeToken}) async {
        approved.add((clientUuid: clientUuid, challengeToken: challengeToken));
        return {
          'permission': {'status': 'active'},
        };
      },
    );

    await tester.enterText(find.byType(TextField), 'A1B2C3');
    await tester.tap(find.text(t.confirmDevice.lookUp));
    await tester.pumpAndSettle();

    // The device's name is the only thing the operator can check the
    // request against, so it must be on screen BEFORE the grant.
    expect(find.textContaining("Sebastián's iPhone"), findsOneWidget);

    await tester.tap(find.text(t.confirmDevice.linkIt));
    await tester.pumpAndSettle();

    expect(approved.single.clientUuid, 'client-2');
    // A permission matched by code is already raised against this account;
    // echoing the token back is only the orphaned-QR path's business.
    expect(approved.single.challengeToken, isNull);
    expect(results.single, isTrue);
  });

  testWidgets('a code that matches nothing says so and offers no way to approve', (tester) async {
    await pumpPane(tester, findByCode: (code) async => const {'permissions': []});

    await tester.enterText(find.byType(TextField), 'NOPE00');
    await tester.tap(find.text(t.confirmDevice.lookUp));
    await tester.pumpAndSettle();

    expect(find.text(t.confirmDevice.codeNotFound), findsOneWidget);
    expect(find.text(t.confirmDevice.linkIt), findsNothing);
  });

  testWidgets('a server rejection is shown verbatim rather than swallowed', (tester) async {
    await pumpPane(
      tester,
      findByCode: (code) async => const {'error': 'Account not found', 'error_status': 404},
    );

    await tester.enterText(find.byType(TextField), 'A1B2C3');
    await tester.tap(find.text(t.confirmDevice.lookUp));
    await tester.pumpAndSettle();

    expect(find.text('Account not found'), findsOneWidget);
  });

  testWidgets('an unreachable server is not reported as a bad code', (tester) async {
    await pumpPane(tester, findByCode: (code) async => null);

    await tester.enterText(find.byType(TextField), 'A1B2C3');
    await tester.tap(find.text(t.confirmDevice.lookUp));
    await tester.pumpAndSettle();

    expect(find.text(t.switchAccounts.serverUnreachable), findsOneWidget);
    expect(find.text(t.confirmDevice.codeNotFound), findsNothing);
  });

  testWidgets('a deep link skips the code step and carries its token into the approval', (tester) async {
    final approved = <({String clientUuid, String? challengeToken})>[];
    await pumpPane(
      tester,
      clientUuid: 'client-9',
      challengeToken: 'TOKEN9',
      findByClient: ({required clientUuid, required challengeToken}) async => {
        'permission': pendingPermission(client: clientUuid, name: 'PoLo on Android'),
      },
      approve: ({required clientUuid, challengeToken}) async {
        approved.add((clientUuid: clientUuid, challengeToken: challengeToken));
        return {
          'permission': {'status': 'active'},
        };
      },
    );

    expect(find.textContaining('PoLo on Android'), findsOneWidget);
    await tester.tap(find.text(t.confirmDevice.linkIt));
    await tester.pumpAndSettle();

    // Without the token the server can't attach the blank permission to
    // this account and answers "Permission not found".
    expect(approved.single, (clientUuid: 'client-9', challengeToken: 'TOKEN9'));
  });

  testWidgets('a deep link whose challenge has aged out falls back to code entry', (tester) async {
    // The server answers 200 with no permission in it — a success-shaped
    // reply that means "gone", and reading it as anything else would leave
    // a confirm button with nothing behind it.
    await pumpPane(
      tester,
      clientUuid: 'client-9',
      challengeToken: 'STALE',
      findByClient: ({required clientUuid, required challengeToken}) async => const {'permission': null},
    );

    expect(find.text(t.confirmDevice.linkExpired), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('a request that evaporates between lookup and approval returns to code entry', (tester) async {
    await pumpPane(
      tester,
      findByCode: (code) async => {
        'permissions': [pendingPermission()],
      },
      approve: ({required clientUuid, challengeToken}) async => const {
        'permission': {'status': 'pending'},
      },
    );

    await tester.enterText(find.byType(TextField), 'A1B2C3');
    await tester.tap(find.text(t.confirmDevice.lookUp));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.confirmDevice.linkIt));
    await tester.pumpAndSettle();

    expect(find.text(t.confirmDevice.codeNotFound), findsOneWidget);
    expect(find.text(t.confirmDevice.linkIt), findsNothing);
  });

  testWidgets('an unreachable server during approval keeps the request, so a QR arrival is not stranded', (tester) async {
    // The trap: treating "couldn't reach the server" the same as "the
    // request is gone" clears the pane back to code entry — and the
    // deep-link arrival has no code to type. A blip would cost a trip back
    // to the other device for a fresh QR.
    var calls = 0;
    await pumpPane(
      tester,
      clientUuid: 'client-9',
      challengeToken: 'TOKEN9',
      findByClient: ({required clientUuid, required challengeToken}) async =>
          {'permission': pendingPermission(client: clientUuid, name: 'PoLo on Android')},
      approve: ({required clientUuid, challengeToken}) async {
        calls++;
        return calls == 1 ? null : const {'permission': {'status': 'active'}};
      },
    );

    await tester.tap(find.text(t.confirmDevice.linkIt));
    await tester.pumpAndSettle();

    expect(find.text(t.switchAccounts.serverUnreachable), findsOneWidget);
    // Still on the confirmation, and retrying works.
    expect(find.text(t.confirmDevice.linkIt), findsOneWidget);
    await tester.tap(find.text(t.confirmDevice.linkIt));
    await tester.pumpAndSettle();
    expect(calls, 2);
  });

  testWidgets('a permission with no readable client is refused, not a dead button', (tester) async {
    var approvals = 0;
    await pumpPane(
      tester,
      findByCode: (code) async => {
        'permissions': [
          {'client_name': 'Some Device', 'status': 'pending'}, // no `client`
        ],
      },
      approve: ({required clientUuid, challengeToken}) async {
        approvals++;
        return const {'permission': {'status': 'active'}};
      },
    );

    await tester.enterText(find.byType(TextField), 'A1B2C3');
    await tester.tap(find.text(t.confirmDevice.lookUp));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.confirmDevice.linkIt));
    await tester.pumpAndSettle();

    expect(approvals, 0);
    expect(find.text(t.confirmDevice.malformedRequest), findsOneWidget);
  });

  testWidgets('a code typed after a failed deep-link lookup never approves the deep link\'s device', (tester) async {
    // The permission on screen is the only thing that may be granted. A
    // fallback to the deep link's client uuid would approve a device the
    // operator was never shown the name of.
    final approved = <String>[];
    await pumpPane(
      tester,
      clientUuid: 'deep-link-client',
      challengeToken: 'TOKEN9',
      findByClient: ({required clientUuid, required challengeToken}) async => const {'permission': null},
      findByCode: (code) async => {
        'permissions': [pendingPermission(client: 'typed-code-client', name: 'The Device On Screen')],
      },
      approve: ({required clientUuid, challengeToken}) async {
        approved.add(clientUuid);
        return const {'permission': {'status': 'active'}};
      },
    );

    expect(find.text(t.confirmDevice.linkExpired), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'A1B2C3');
    await tester.tap(find.text(t.confirmDevice.lookUp));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.confirmDevice.linkIt));
    await tester.pumpAndSettle();

    expect(approved, ['typed-code-client']);
  });

  group('link_client deep links', () {
    test('the QR payload Ham2K apps generate parses', () {
      // Exactly what switch_accounts_dialog.dart's linkClientQrUrl builds.
      final request = DeepLinkService.linkClientRequest(Uri.parse('com.ham2k:///link_client?id=abc&token=XYZ'));
      expect(request?.clientUuid, 'abc');
      expect(request?.challengeToken, 'XYZ');
    });

    test('the two-slash authority form parses too', () {
      // `link_client` lands in the host rather than the path here, and a
      // link that silently does nothing is indistinguishable from a broken
      // QR code to whoever is holding the phone.
      final request = DeepLinkService.linkClientRequest(Uri.parse('com.ham2k.logger://link_client?id=abc&token=XYZ'));
      expect(request?.clientUuid, 'abc');
    });

    test('other Ham2K links and half-filled ones are not link requests', () {
      expect(DeepLinkService.linkClientRequest(Uri.parse('com.ham2k:///qso?call=W1AW')), isNull);
      expect(DeepLinkService.linkClientRequest(Uri.parse('com.ham2k:///link_client?id=abc')), isNull);
      expect(DeepLinkService.linkClientRequest(Uri.parse('com.ham2k:///link_client?token=XYZ')), isNull);
      expect(DeepLinkService.linkClientRequest(Uri.parse('https://ham2k.com/link_client?id=abc&token=XYZ')), isNull);
    });
  });
}
