// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The status bar's peer status: present exactly while this device has linked
// devices, badged with the number connected right now, and opening the Peer
// Devices panel as a modal pane.
//
// Pumps the REAL `StatusBarOverlay` against a real trust store, because what
// is being checked is the wiring between the two — a status built from a
// count the test itself supplied would pass with nothing behind it.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/peer/peer_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/peers_panel.dart';

import 'fake_secure_storage.dart';

/// A peer service whose live links are stated rather than dialled.
///
/// [PeerService.hasSession] is what the badge counts, and standing a real
/// pair up inside a widget test buys nothing the mapping under test needs —
/// peer_service_test drives the real sessions.
class _PeerServiceWithLinks extends PeerService {
  _PeerServiceWithLinks({
    required super.db,
    required super.outbox,
    required super.operations,
    required super.qsos,
    required super.localDeviceId,
    required super.localDeviceName,
    required this.live,
  });

  final Set<String> live;

  @override
  bool hasSession(String peerDeviceId) => live.contains(peerDeviceId);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoServices services;
  late HaLoDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance(), secureStorage: FakeSecureStorage());
    // Peer sync is behind an experiment, and so is the Peers panel this
    // status opens.
    await settings.setExperimentEnabled('p2p', true);
    db = HaLoDatabase(NativeDatabase.memory());
    services = HaLoServices(db, settings);
  });

  tearDown(() async => db.close());

  /// Pairs a device the way the pairing flow does: the store write AND the
  /// service's re-read of it, which is what every surface reading
  /// [PeerService.linkedDeviceIds] depends on.
  Future<void> link(String deviceId, String name) async {
    await services.peerService.trust.trust(deviceId, name: name);
    await services.peerService.refreshLinkedDevices();
  }

  /// The overlay where `MaterialApp.builder` mounts it, wrapping the builder's
  /// own child — the REAL Navigator.
  ///
  /// A stand-in for that child would not do: the status's action reaches the
  /// pane through the app-wide [navigatorKey] (the footer is drawn above the
  /// Navigator and its own context has none), so a tree without one takes the
  /// tap, logs a line, and opens nothing.
  Future<void> pumpOverlay(WidgetTester tester) async {
    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        navigatorKey: navigatorKey,
        builder: (context, child) =>
            StatusBarOverlay(services: services, child: child ?? const SizedBox.shrink()),
        home: const Scaffold(resizeToAvoidBottomInset: false, body: SizedBox.expand()),
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// Tears the tree down INSIDE the test body.
  ///
  /// Once the Peers panel is up, its device list holds a drift query stream,
  /// and drift schedules a zero-duration timer when that stream is cancelled.
  /// Left to teardown, the timer is still pending when the binding checks and
  /// the test fails with "A Timer is still pending" — see peers_panel_test.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  testWidgets('no linked devices, no status', (tester) async {
    // An operator who has never linked a device is not told "0 devices": the
    // status would be chrome reporting on a feature they do not use.
    await pumpOverlay(tester);
    expect(find.byIcon(MdiIcons.lanConnect), findsNothing);
  });

  testWidgets('without the experiment there is no status, whatever is linked', (tester) async {
    // The action opens the Peers panel, which Settings itself only publishes
    // under the experiment — a status that led to a panel the operator cannot
    // otherwise reach would be the one way into a hidden feature.
    await services.settings.setExperimentEnabled('p2p', false);
    await link('device-a', 'Shack Mac');
    await pumpOverlay(tester);
    expect(find.byIcon(MdiIcons.lanConnect), findsNothing);
  });

  testWidgets('a linked device puts the status in the bar, and its line opens the panel', (tester) async {
    await link('device-a', 'Shack Mac');
    await link('device-b', 'Handheld');
    await pumpOverlay(tester);

    // The badge counts LIVE links — neither device has a session here — while
    // the line carries both numbers, which is what makes the zero mean
    // something.
    expect(find.byIcon(MdiIcons.lanConnect), findsOneWidget);
    expect(find.text('0'), findsOneWidget);

    await tester.tap(find.byIcon(MdiIcons.lanConnect));
    await tester.pumpAndSettle();
    expect(find.text(TranslationProvider.of(tester.element(find.byType(StatusBarOverlay)))
        .translations.settings.peers.statusPerma(connected: 0, linked: 2)), findsOneWidget);

    // The entry opens the panel itself, not a summary of it. Explicit pumps
    // from here: the panel's device list is a StreamBuilder over a live drift
    // query, and pumpAndSettle waits out its whole 10-minute budget on one.
    await tester.tap(find.textContaining('of 2'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // the pane's route transition
    expect(find.byType(PeersPanel), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('the badge counts the LIVE links, and stops being dim once one is up', (tester) async {
    // The number beside the glyph is what the operator reads at a glance, and
    // the one thing it must not be is the number of devices they have paired:
    // "2" with both devices asleep in another room is the status answering a
    // question nobody asked.
    final peers = _PeerServiceWithLinks(
      db: db,
      outbox: PeerOutbox(db),
      operations: OperationsRepository(db),
      qsos: QsosRepository(db),
      localDeviceId: 'me',
      localDeviceName: 'This Mac',
      live: {'device-a'},
    );
    services = HaLoServices(db, services.settings, peerService: peers);
    await link('device-a', 'Shack Mac');
    await link('device-b', 'Handheld');
    await pumpOverlay(tester);

    expect(find.text('1'), findsOneWidget);
    expect(tester.widget<Icon>(find.byIcon(MdiIcons.lanConnect)).color!.a, 1.0,
        reason: 'a live link is not a status standing down');

    await tester.tap(find.byIcon(MdiIcons.lanConnect));
    await tester.pumpAndSettle();
    expect(find.text(TranslationProvider.of(tester.element(find.byType(StatusBarOverlay)))
        .translations.settings.peers.statusPerma(connected: 1, linked: 2)), findsOneWidget);
  });

  testWidgets('forgetting the last device takes the status away again', (tester) async {
    // The count is a cache on the service, refreshed by whatever writes trust
    // — a status read once at mount would go on reporting a device this
    // operator has removed.
    await link('device-a', 'Shack Mac');
    await pumpOverlay(tester);
    expect(find.byIcon(MdiIcons.lanConnect), findsOneWidget);

    await services.peerService.revokeTrust('device-a');
    await tester.pumpAndSettle();
    expect(find.byIcon(MdiIcons.lanConnect), findsNothing);
  });
}
