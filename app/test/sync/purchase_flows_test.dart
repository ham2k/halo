// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Purchases are bound to the sync account and reach the sync server as a
// channel reference it verifies itself. The traps: a purchase offered with no
// account behind it (no other device could ever see it), a sync purchase that
// never reaches the server because it finished outside the paywall call (a
// browser checkout, another device) or because Settings was closed when it
// did, one sent again for an account whose plan already reflects it, one
// handed to the account the device switched to, and a subscribed account
// offered a second checkout while the server can't be reached.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/purchase_flows.dart';
import 'package:ham2k_logger/services/purchase_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/settings_view.dart';

import '../support/halo_test_support.dart';

class _Purchases implements PurchaseService {
  final identified = <String>[];
  final paywalls = <String?>[];
  PurchaseResult paywallResult = PurchaseResult.cancelled;

  /// What a completed paywall purchase grants, as the store would report it.
  Set<String> grantedByPurchase = const {};

  @override
  final ValueNotifier<Set<String>> entitlements = ValueNotifier(const {});

  @override
  bool get isAvailable => true;

  @override
  SupporterArt? get supporterArt => null;

  /// As a store does: another account's entitlements are not this one's.
  @override
  Future<void> identify(String appUserId) async {
    if (identified.lastOrNull == appUserId) return;
    identified.add(appUserId);
    entitlements.value = const {};
  }

  @override
  Future<void> refreshEntitlements() async {}

  @override
  Future<PurchaseResult> presentPaywall({String? offering}) async {
    paywalls.add(offering);
    if (paywallResult == PurchaseResult.purchased) entitlements.value = grantedByPurchase;
    return paywallResult;
  }

  @override
  Future<bool> manageSubscriptions() async => false;

  @override
  String? channelReference(String entitlement) => identified.isEmpty ? null : 'store:$entitlement:${identified.last}';
}

/// Written from the real `syncAccountData`: every fetch persists the payload
/// into `syncState['accountData']`, which is what the flows read.
class _Extensions extends ExtensionServiceWithFakeHost {
  Map<String, dynamic>? account;
  Map<String, dynamic>? subscription;
  final subscriptionRequests = <String>[];
  Map<String, dynamic>? createResult;

  _Extensions(this.account) : super(FakeExtensionHost({}));

  @override
  Future<Map<String, dynamic>?> syncAccountData({Duration timeout = const Duration(seconds: 10)}) async {
    if (account == null) return null;
    final data = {
      'current_account': account,
      'subscription': subscription ?? {'id': null},
    };
    await settings!.setSyncState({...settings!.syncState, 'accountData': data});
    return data;
  }

  @override
  Future<Map<String, dynamic>?> syncCreateSubscription(String channelReference) async {
    subscriptionRequests.add(channelReference);
    if (createResult != null) return createResult;
    subscription = {'id': 7};
    return {'subscription': subscription};
  }
}

Future<(HaLoServices, _Extensions, _Purchases)> makeServices(Map<String, dynamic>? account) async {
  SharedPreferences.setMockInitialValues({'flutter.syncEnabled': true});
  final settings = SettingsService(await SharedPreferences.getInstance());
  final db = HaLoDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final extensions = _Extensions(account)..settings = settings;
  final purchases = _Purchases();
  return (HaLoServices(db, settings, extensions: extensions, purchases: purchases), extensions, purchases);
}

void main() {
  group('identifying the purchaser', () {
    test('uses the sync account uuid, fetching the account when none is cached', () async {
      final (services, _, purchases) = await makeServices({'uuid': 'acct-1'});

      expect(await identifyPurchaser(services), isTrue);
      expect(purchases.identified, ['acct-1']);
    });

    test('with no account to name, no paywall is shown', () async {
      final (services, _, purchases) = await makeServices(null);

      expect(await presentPaywall(services), PurchaseResult.unavailable);
      expect(purchases.identified, isEmpty);
      expect(purchases.paywalls, isEmpty);
    });
  });

  group('handing a sync purchase to the server', () {
    test('a sync purchase from the paywall reaches the server under the account it was bought for', () async {
      final (services, extensions, purchases) = await makeServices({'uuid': 'acct-1'});
      purchases
        ..paywallResult = PurchaseResult.purchased
        ..grantedByPurchase = {syncEntitlement};

      await presentPaywall(services, offering: syncOffering);

      expect(purchases.paywalls, [syncOffering]);
      expect(extensions.subscriptionRequests, ['store:$syncEntitlement:acct-1']);
    });

    test('a purchase that grants no sync entitlement is not sent', () async {
      final (services, extensions, purchases) = await makeServices({'uuid': 'acct-1'});
      purchases
        ..paywallResult = PurchaseResult.purchased
        ..grantedByPurchase = {'supporter_2026'};

      await presentPaywall(services);

      expect(extensions.subscriptionRequests, isEmpty);
    });

    test('an account already on a paid plan is not sent the purchase again', () async {
      final (services, extensions, purchases) = await makeServices({'uuid': 'acct-1'});
      extensions.subscription = {'id': 3};
      await identifyPurchaser(services);
      purchases.entitlements.value = {syncEntitlement};

      expect(await attachSyncPurchase(services), isNull);
      expect(extensions.subscriptionRequests, isEmpty);
    });

    test("after an account switch, the previous account's purchase is not handed to the new one", () async {
      // The store still answers for the account it was last told of until
      // something identifies the purchaser again.
      final (services, extensions, purchases) = await makeServices({'uuid': 'acct-1'});
      extensions.createResult = {'error': 'Subscription belongs to a different account', 'error_status': 406};
      await identifyPurchaser(services);
      purchases.entitlements.value = {syncEntitlement};
      await attachSyncPurchase(services);
      extensions.subscriptionRequests.clear();

      extensions.account = {'uuid': 'acct-2'};
      await services.extensions.syncAccountData();
      await attachSyncPurchase(services);

      expect(purchases.identified.last, 'acct-2');
      expect(extensions.subscriptionRequests, isEmpty);
    });

    test('a purchase finished while Settings is closed reaches the server', () async {
      // What boot starts: the paywall call returned long ago, and no panel
      // is listening.
      final (services, extensions, purchases) = await makeServices({'uuid': 'acct-1'});
      await services.extensions.syncAccountData();
      watchSyncPurchases(services);
      await pumpEventQueue();
      expect(purchases.identified, ['acct-1']);

      purchases.entitlements.value = {syncEntitlement};
      await pumpEventQueue();

      expect(extensions.subscriptionRequests, ['store:$syncEntitlement:acct-1']);
    });

    test('two attaches at once send the purchase once', () async {
      // The panel attaches on opening and on every entitlement change, and an
      // identify can set off both together.
      final (services, extensions, purchases) = await makeServices({'uuid': 'acct-1'});
      await identifyPurchaser(services);
      purchases.entitlements.value = {syncEntitlement};

      await Future.wait([attachSyncPurchase(services), attachSyncPurchase(services)]);

      expect(extensions.subscriptionRequests, ['store:$syncEntitlement:acct-1']);
    });
  });

  group('Sync panel', () {
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
      await tester.tap(find.text('Cloud Sync').first);
      await tester.pumpAndSettle();
    }

    testWidgets('a purchase finished outside the app reaches the server while the panel is open', (tester) async {
      // A browser checkout returns nothing to the paywall call; the store's
      // entitlements changing is the only sign it happened.
      final (services, extensions, purchases) = await makeServices({'uuid': 'acct-1'});
      await openSyncPanel(tester, services);
      expect(find.text(t.settings.syncPanel.subscribe), findsOneWidget);

      purchases.entitlements.value = {syncEntitlement};
      await tester.pumpAndSettle();

      expect(extensions.subscriptionRequests, ['store:$syncEntitlement:acct-1']);
      expect(find.text(t.settings.syncPanel.subscribed), findsOneWidget);
    });

    testWidgets('a purchase already loaded when the panel opens reaches the server', (tester) async {
      // The supporter row identifies first, so by the time the panel opens
      // the entitlements are already in and never change again.
      final (services, extensions, purchases) = await makeServices({'uuid': 'acct-1'});
      await identifyPurchaser(services);
      purchases.entitlements.value = {syncEntitlement};

      await openSyncPanel(tester, services);

      expect(extensions.subscriptionRequests, ['store:$syncEntitlement:acct-1']);
      expect(find.text(t.settings.syncPanel.subscribed), findsOneWidget);
    });

    testWidgets('a subscribed account is not offered Subscribe while the server is out of reach', (tester) async {
      // Subscribe there would open a second checkout for the same account.
      final (services, extensions, _) = await makeServices({'uuid': 'acct-1'});
      extensions.subscription = {'id': 3};
      await services.extensions.syncAccountData();
      extensions.account = null;

      await openSyncPanel(tester, services);

      expect(find.text(t.settings.syncPanel.subscribed), findsOneWidget);
      expect(find.text(t.settings.syncPanel.subscribe), findsNothing);
    });

    testWidgets('a subscription with nothing to manage says so rather than doing nothing', (tester) async {
      final (services, extensions, _) = await makeServices({'uuid': 'acct-1'});
      extensions.subscription = {'id': 3};
      await openSyncPanel(tester, services);

      await tester.tap(find.text(t.settings.syncPanel.subscribed));
      await tester.pump();

      expect(find.text(t.settings.syncPanel.manageUnavailable), findsOneWidget);
    });

    testWidgets('a purchase the server refuses says why', (tester) async {
      final (services, extensions, purchases) = await makeServices({'uuid': 'acct-1'});
      extensions.createResult = {'error': 'Subscription belongs to a different account', 'error_status': 406};
      await openSyncPanel(tester, services);

      purchases.entitlements.value = {syncEntitlement};
      await tester.pumpAndSettle();

      expect(find.text(t.settings.syncPanel.subscriptionRefused(error: 'Subscription belongs to a different account')), findsOneWidget);
      expect(find.text(t.settings.syncPanel.subscribe), findsOneWidget);
    });
  });
}
