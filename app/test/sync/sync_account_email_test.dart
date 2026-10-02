// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Sync panel's account email: the address IS the account's identity, and
// a change to it only takes effect once the operator opens a confirmation
// link. So the panel must never report a change as done, must offer a resend
// exactly while one is genuinely outstanding, and must surface the server's
// refusal (a taken address) instead of letting it look like success.

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stream_channel/stream_channel.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/pusher_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/settings_view.dart';
import 'package:ham2k_logger/views/settings/sync_panel.dart';

import '../support/halo_test_support.dart';

/// Plays the server's WebSocket end for a real [PusherService], the same
/// way pusher_service_test does.
class _FakeSocket {
  final _controller = StreamChannelController<dynamic>(sync: true);

  StreamChannel<dynamic> get local => _controller.local;

  void send(String event, {String? channel, Object? data}) {
    _controller.foreign.sink.add(jsonEncode({'event': event, 'channel': ?channel, 'data': jsonEncode(data ?? const {})}));
  }

  void establish() => send('pusher:connection_established', data: {'socket_id': '1.1'});
}

class _Extensions extends ExtensionServiceWithFakeHost {
  final Map<String, dynamic>? account;
  final List<String> emailsSet = [];
  var resendCount = 0;
  var accountFetches = 0;
  Map<String, dynamic>? setEmailResult;

  /// Mutable so a test can have the world change under an open panel —
  /// which is the whole point of the poll and the push.
  int? pendingChallenges;
  bool unreachable = false;

  _Extensions(this.account, {this.pendingChallenges}) : super(FakeExtensionHost({}));

  @override
  Future<Map<String, dynamic>?> syncAccountData({Duration timeout = const Duration(seconds: 10)}) async {
    accountFetches++;
    if (unreachable || account == null) return null;
    return {'current_account': account, if (pendingChallenges != null) 'pending_challenges': pendingChallenges};
  }

  @override
  Future<Map<String, dynamic>?> syncSetAccountEmail(String email) async {
    emailsSet.add(email);
    return setEmailResult ?? const {'account': {}};
  }

  @override
  Future<Map<String, dynamic>?> syncResendAccountEmail() async {
    resendCount++;
    return const {'account': {}};
  }
}

Future<(HaLoServices, _Extensions)> makeServices(Map<String, dynamic>? account, {int? pendingChallenges, PusherService? pusher}) async {
  SharedPreferences.setMockInitialValues({'flutter.syncEnabled': true});
  final settings = SettingsService(await SharedPreferences.getInstance());
  final db = HaLoDatabase(NativeDatabase.memory());
  final extensions = _Extensions(account, pendingChallenges: pendingChallenges)..settings = settings;
  return (HaLoServices(db, settings, extensions: extensions, pusher: pusher), extensions);
}

Future<void> openSyncPanel(WidgetTester tester, HaLoServices services) async {
  tester.view.physicalSize = const Size(1000, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(home: SettingsView(services: services)),
    ),
  );
  await tester.pumpAndSettle();
  // `.first`: the sidebar's entry. The Settings panel showing beside it
  // carries a band of the same name.
  await tester.tap(find.text('Cloud Sync').first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a change in flight offers a resend, naming the address it is waiting on', (tester) async {
    final (services, _) = await makeServices({'uuid': 'acct-1', 'email': 'old@example.com', 'pending_email': 'new@example.com'});
    await openSyncPanel(tester, services);

    expect(find.text(t.settings.syncPanel.resendConfirmation), findsOneWidget);
    expect(find.text(t.settings.syncPanel.resendConfirmationDescription(email: 'new@example.com')), findsOneWidget);
  });

  testWidgets('a pending_email equal to the confirmed one is not a change in flight', (tester) async {
    // The trap: LoFi leaves pending_email set to the address that was just
    // confirmed, so testing the field for presence alone would leave a
    // "resend confirmation" row up forever on a settled account.
    final (services, _) = await makeServices({'uuid': 'acct-1', 'email': 'me@example.com', 'pending_email': 'me@example.com'});
    await openSyncPanel(tester, services);

    expect(find.text(t.settings.syncPanel.resendConfirmation), findsNothing);
  });

  testWidgets('a settled account offers no resend', (tester) async {
    final (services, _) = await makeServices({'uuid': 'acct-1', 'email': 'me@example.com'});
    await openSyncPanel(tester, services);

    expect(find.text(t.settings.syncPanel.resendConfirmation), findsNothing);
  });

  testWidgets('resending asks the server to mail the confirmation again', (tester) async {
    final (services, extensions) = await makeServices({'uuid': 'acct-1', 'email': 'old@example.com', 'pending_email': 'new@example.com'});
    await openSyncPanel(tester, services);

    await tester.tap(find.text(t.settings.syncPanel.resendConfirmation));
    await tester.pumpAndSettle();

    expect(extensions.resendCount, 1);
  });

  testWidgets('saving a new address sends it trimmed, and says it is only pending', (tester) async {
    final (services, extensions) = await makeServices({'uuid': 'acct-1', 'email': 'old@example.com'});
    await openSyncPanel(tester, services);

    await tester.tap(find.text(t.settings.syncPanel.account));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '  new@example.com ');
    await tester.tap(find.text(t.common.save));
    await tester.pumpAndSettle();

    expect(extensions.emailsSet, ['new@example.com']);
    // "Sent", never "changed": the account keeps its old address until the
    // link in that mail is opened.
    expect(find.text(t.settings.syncPanel.accountEmailSent(email: 'new@example.com')), findsOneWidget);
  });

  testWidgets('re-entering the address already on file asks the server for nothing', (tester) async {
    final (services, extensions) = await makeServices({'uuid': 'acct-1', 'email': 'me@example.com'});
    await openSyncPanel(tester, services);

    await tester.tap(find.text(t.settings.syncPanel.account));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.common.save));
    await tester.pumpAndSettle();

    expect(extensions.emailsSet, isEmpty);
  });

  testWidgets('a refused address is reported, not passed off as sent', (tester) async {
    final (services, extensions) = await makeServices({'uuid': 'acct-1', 'email': 'old@example.com'});
    // The shape the extension really produces: api-lofi renders this one
    // under `account_errors`, never as a top-level `error`, and
    // loFiErrorMessage is what digs the sentence back out (see
    // extensions/sync/ham2k-lofi/src/errors.test.ts). Stubbing a bare
    // `error` here would be inventing a reply the server never sends.
    extensions.setEmailResult = const {'error': 'LoFi request failed: in use by another account', 'error_status': 422};
    await openSyncPanel(tester, services);

    await tester.tap(find.text(t.settings.syncPanel.account));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'taken@example.com');
    await tester.tap(find.text(t.common.save));
    await tester.pumpAndSettle();

    expect(find.textContaining('in use by another account'), findsOneWidget);
    expect(find.text(t.settings.syncPanel.accountEmailSent(email: 'taken@example.com')), findsNothing);
  });

  testWidgets('re-entering the address already awaiting confirmation resends it', (tester) async {
    // Someone who never got the mail retypes the address. Doing nothing at
    // all — the obvious reading of "unchanged" — leaves them with no
    // feedback and no mail.
    final (services, extensions) = await makeServices({'uuid': 'acct-1', 'email': 'old@example.com', 'pending_email': 'new@example.com'});
    await openSyncPanel(tester, services);

    await tester.tap(find.text(t.settings.syncPanel.account));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.common.save));
    await tester.pumpAndSettle();

    expect(extensions.emailsSet, isEmpty);
    expect(extensions.resendCount, 1);
  });

  testWidgets('a refresh that cannot reach the server says so and keeps the account', (tester) async {
    // The loud counterpart of the quiet-poll rule. `syncAccountData`
    // returns null only when the host call failed — an unlinked device
    // still answers with a map — so writing it through would claim the
    // account vanished, and take the resend and connection-request rows
    // with it.
    final (services, extensions) = await makeServices({'uuid': 'acct-1', 'email': 'me@example.com'});
    await openSyncPanel(tester, services);

    extensions.unreachable = true;
    await tester.tap(find.byIcon(MdiIcons.refresh));
    await tester.pumpAndSettle();

    expect(find.text(t.switchAccounts.serverUnreachable), findsOneWidget);
    expect(find.text(t.settings.syncPanel.notLinked), findsNothing);
    expect(find.textContaining('me@example.com'), findsWidgets);
  });

  group('connection requests', () {
    testWidgets('the row is absent while nobody is waiting', (tester) async {
      // A permanent row would invite typing a code nobody has issued.
      final (services, _) = await makeServices({'uuid': 'acct-1', 'email': 'me@example.com'});
      await openSyncPanel(tester, services);

      expect(find.text(t.settings.syncPanel.connectionRequests), findsNothing);
    });

    testWidgets('a pending request shows the row, counted', (tester) async {
      final (services, _) = await makeServices({'uuid': 'acct-1', 'email': 'me@example.com'}, pendingChallenges: 2);
      await openSyncPanel(tester, services);

      expect(find.text(t.settings.syncPanel.connectionRequests), findsOneWidget);
      expect(find.text(t.settings.syncPanel.connectionRequestsDescription(count: 2, n: '2')), findsOneWidget);
    });

    testWidgets('a request arriving while the panel is open shows up on its own', (tester) async {
      // Without realtime the poll IS the only way this row ever appears —
      // the operator has no reason to think a refresh is needed for
      // something they didn't do.
      final (services, extensions) = await makeServices({'uuid': 'acct-1', 'email': 'me@example.com'});
      await openSyncPanel(tester, services);
      expect(find.text(t.settings.syncPanel.connectionRequests), findsNothing);

      extensions.pendingChallenges = 1;
      await tester.pump(syncAccountPollWithoutRealtime);
      await tester.pumpAndSettle();

      expect(find.text(t.settings.syncPanel.connectionRequests), findsOneWidget);
    });

    testWidgets('a push about this account refreshes without waiting for the poll', (tester) async {
      // api-lofi fires `permission` on the account's channel the moment
      // another device asks in — the whole point of the long fallback
      // interval is that this arrives first.
      final server = _FakeSocket();
      final pusher = PusherService(appKey: 'k', cluster: 'mt1', connect: (_) => server.local);
      final (services, extensions) = await makeServices({'uuid': 'acct-1', 'email': 'me@example.com', 'push_channel': 'account-abc-1234'}, pusher: pusher);
      await openSyncPanel(tester, services);
      server.establish();
      await tester.pumpAndSettle();

      extensions.pendingChallenges = 1;
      server.send('permission', channel: 'account-abc-1234');
      await tester.pumpAndSettle();

      expect(find.text(t.settings.syncPanel.connectionRequests), findsOneWidget);
      // Well inside the fallback interval, which is what proves the push
      // and not a poll did it.
      expect(extensions.accountFetches, greaterThan(1));
      pusher.dispose();
    });

    testWidgets('a push about somebody else\'s account is ignored', (tester) async {
      final server = _FakeSocket();
      final pusher = PusherService(appKey: 'k', cluster: 'mt1', connect: (_) => server.local);
      final (services, extensions) = await makeServices({'uuid': 'acct-1', 'email': 'me@example.com', 'push_channel': 'account-abc-1234'}, pusher: pusher);
      await openSyncPanel(tester, services);
      server.establish();
      await tester.pumpAndSettle();
      final before = extensions.accountFetches;

      server.send('permission', channel: 'account-zzz-9999');
      await tester.pumpAndSettle();

      expect(extensions.accountFetches, before);
      pusher.dispose();
    });

    testWidgets('a poll that cannot reach the server leaves the account on screen', (tester) async {
      // Overwriting with null would turn a linked account into "Not linked
      // yet" once a minute on a flaky connection, with nothing the operator
      // did to explain it.
      final (services, extensions) = await makeServices({'uuid': 'acct-1', 'email': 'me@example.com'});
      await openSyncPanel(tester, services);
      expect(find.textContaining('me@example.com'), findsWidgets);

      extensions.unreachable = true;
      await tester.pump(syncAccountPollWithoutRealtime);
      await tester.pumpAndSettle();

      expect(find.textContaining('me@example.com'), findsWidgets);
      expect(find.text(t.settings.syncPanel.notLinked), findsNothing);
    });

    testWidgets('the row is coloured to be noticed, not to blend in', (tester) async {
      final (services, _) = await makeServices({'uuid': 'acct-1', 'email': 'me@example.com'}, pendingChallenges: 1);
      await openSyncPanel(tester, services);

      final tile = tester.widget<ListTile>(find.ancestor(of: find.text(t.settings.syncPanel.connectionRequests), matching: find.byType(ListTile)));
      final context = tester.element(find.text(t.settings.syncPanel.connectionRequests));
      expect((tile.leading! as Icon).color, HaLoColors.of(context).important);
    });
  });

  testWidgets('an anonymous account can be claimed from the same row', (tester) async {
    // No email at all is the state a new install lands in now that sync
    // starts on, and it is the one that most needs an address.
    final (services, extensions) = await makeServices({'uuid': 'acct-1'});
    await openSyncPanel(tester, services);

    await tester.tap(find.text(t.settings.syncPanel.account));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'mine@example.com');
    await tester.tap(find.text(t.common.save));
    await tester.pumpAndSettle();

    expect(extensions.emailsSet, ['mine@example.com']);
  });
}
