// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Supporter badges: the distribution build supplies the artwork, and either
// a store entitlement or a per-callsign grant earns a badge. The traps:
// showing a badge nobody earned, dropping support given outside the stores
// (the grant), and the footer that carries them — pinned under the Settings
// sidebar — either never getting out of the way of a list that needs the
// room, or folding away for good when the list has nothing left to scroll.
// And a contribute button that, with no account to bind a purchase to,
// does nothing and says nothing.

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/purchase_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/settings/supporter_row.dart';
import 'package:ham2k_logger/views/settings_view.dart';

import '../support/halo_test_support.dart';

final _image = MemoryImage(base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII='));

final _art = SupporterArt(
  badges: [(key: 'supporter_2025', year: 2025, image: _image), (key: 'supporter_2026', year: 2026, image: _image)],
  contributeNow: _image,
  contributeMore: _image,
);

class _Purchases implements PurchaseService {
  @override
  final ValueNotifier<Set<String>> entitlements = ValueNotifier(const {});

  @override
  bool get isAvailable => true;

  @override
  SupporterArt get supporterArt => _art;

  @override
  Future<void> identify(String appUserId) async {}

  @override
  Future<void> refreshEntitlements() async {}

  @override
  Future<PurchaseResult> presentPaywall({String? offering}) async => PurchaseResult.cancelled;

  @override
  Future<bool> manageSubscriptions() async => false;

  @override
  String? channelReference(String entitlement) => null;
}

void main() {
  group('earning a badge', () {
    test('an active entitlement earns its badge, and nothing else does', () {
      final badges = supporterBadges(_art, const {}, {'supporter_2026', 'lofi_2025'});
      expect(badges.map((b) => b.key), ['supporter_2026']);
    });

    test('a per-callsign grant earns a badge without any purchase', () {
      final badges = supporterBadges(_art, {
        'badges': {'supporter_2025': true, 'supporter_2026': false},
      }, const {});
      expect(badges.map((b) => b.key), ['supporter_2025']);
    });
  });

  group('the sidebar footer', () {
    Future<void> openSettings(WidgetTester tester, {required double height}) async {
      tester.view.physicalSize = Size(1000, height);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService(await SharedPreferences.getInstance());
      final db = HaLoDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final services = HaLoServices(db, settings, extensions: ExtensionServiceWithFakeHost()..settings = settings, purchases: _Purchases());
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(home: SettingsView(services: services)),
        ),
      );
      await tester.pumpAndSettle();
    }

    Finder contribute() => find.bySemanticsLabel(t.settings.supporter.contribute).hitTestable();

    testWidgets('folds while a list that needs the room scrolls down, and returns on the way up', (tester) async {
      await openSettings(tester, height: 400);
      expect(contribute(), findsOneWidget);

      await tester.drag(find.byType(ListView).first, const Offset(0, -60));
      await tester.pumpAndSettle();
      expect(contribute(), findsNothing);

      await tester.drag(find.byType(ListView).first, const Offset(0, 30));
      await tester.pumpAndSettle();
      expect(contribute(), findsOneWidget);
    });

    testWidgets('contributing with no sync account to buy for says why nothing opened', (tester) async {
      await openSettings(tester, height: 1400);

      await tester.tap(contribute());
      await tester.pump();

      expect(find.text(t.settings.syncPanel.purchaseUnavailable), findsOneWidget);
    });

    testWidgets('stays when the list would have nothing left to scroll without it', (tester) async {
      // Folded there, nothing could scroll back up to bring it back.
      await openSettings(tester, height: 400);
      final position = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
      final content = position.maxScrollExtent + position.viewportDimension;
      final footer = tester.getSize(find.byType(SupporterRow)).height;
      // Overflowing by half the footer: it has to scroll, but folding the
      // footer would leave nothing to scroll.
      tester.view.physicalSize = Size(1000, 400 + content - position.viewportDimension - footer / 2);
      await tester.pumpAndSettle();
      expect(position.maxScrollExtent, greaterThan(0));

      // Not even for a moment: folding and springing back would flash.
      await tester.drag(find.byType(ListView).first, const Offset(0, -60));
      await tester.pump();
      expect(tester.widget<AnimatedAlign>(find.byType(AnimatedAlign)).heightFactor, 1);
    });

    testWidgets('comes back when a taller window leaves nothing to scroll', (tester) async {
      await openSettings(tester, height: 400);
      await tester.drag(find.byType(ListView).first, const Offset(0, -60));
      await tester.pumpAndSettle();
      expect(contribute(), findsNothing);

      tester.view.physicalSize = const Size(1000, 2000);
      await tester.pumpAndSettle();
      expect(contribute(), findsOneWidget);
    });
  });
}
