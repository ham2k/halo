// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Peer Devices settings panel (HALO-310). The service beneath it has its
// own real-socket tests; these cover what those cannot — that the panel
// reflects the switch, lists what is paired, and that the destructive action
// asks first.

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/extension_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/services/peer/peer_service.dart';
import 'package:ham2k_logger/views/peers_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The real ExtensionService boots a JS runtime and leaves timers running,
/// which a widget test fails on ("A Timer is still pending"). Every other
/// panel test stubs it the same way — see about_panel_test.dart.
class _MockExtensionHost implements ExtensionHost {
  @override
  Future<dynamic> invokeHook(
    String category, {
    String? key,
    required String method,
    Object? args,
    Duration timeout = const Duration(seconds: 10),
  }) async => null;

  @override
  Future<List<Map<String, dynamic>>> invokeHookAll(
    String category, {
    required String method,
    Object? args,
    Duration timeout = const Duration(seconds: 10),
    bool partialOnTimeout = false,
  }) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubExtensionService extends ExtensionService {
  @override
  ExtensionHost? get host => _mockHost;
  final _mockHost = _MockExtensionHost();

  @override
  Future<void> start() async {}
}

void main() {
  late HaLoDatabase db;
  late SettingsService settings;
  late HaLoServices services;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = HaLoDatabase(NativeDatabase.memory());
    settings = SettingsService(await SharedPreferences.getInstance());
    services = HaLoServices(db, settings, extensions: _StubExtensionService()..settings = settings);
  });

  tearDown(() async => db.close());

  /// Explicit pumps, never pumpAndSettle: the paired-device list is a
  /// StreamBuilder over a live drift query, which keeps the tree scheduling
  /// frames — pumpAndSettle waits out its full 10-minute budget and then
  /// fails, naming whatever test happened to be running.
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(home: Scaffold(body: PeersPanel(services: services))),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// Tears the tree down INSIDE the test body.
  ///
  /// The paired-device list holds a drift query stream, and drift schedules a
  /// zero-duration timer from `StreamQueryStore.markAsClosed` when that
  /// stream is cancelled. Left to teardown, that timer is still pending when
  /// the binding checks, and every test fails with "A Timer is still pending"
  /// naming nothing useful. Unmounting here lets it fire first.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    // Several: drift's close path schedules a timer whose handler can
    // schedule the next step of the same teardown, so one pump is not
    // enough to drain it.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  group('the EXP P2P gate', () {
    Future<int> freePort() async {
      final probe = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = probe.port;
      probe.close();
      return port;
    }

    /// A services bundle whose peer service beacons on an ephemeral port, so
    /// the "gate open" case can actually start without touching the real
    /// discovery port (or another HaLo running on this machine).
    Future<HaLoServices> servicesOnFreePort() async {
      final peer = PeerService(
        db: db,
        outbox: PeerOutbox(db),
        operations: OperationsRepository(db),
        qsos: QsosRepository(db),
        localDeviceId: 'local',
        localDeviceName: 'Local',
        beaconPort: await freePort(),
      );
      addTearDown(() async {
        await peer.setOpenOperation(null);
        peer.dispose();
      });
      return HaLoServices(db, settings,
          extensions: _StubExtensionService()..settings = settings, peerService: peer);
    }

    test('with the experiment off, an open operation and the switch on start nothing', () async {
      final withPeer = await servicesOnFreePort();
      await settings.setPeerSyncEnabled(true);
      withPeer.openOperationContext('op-1');
      // Not merely "no UI": nothing may bind, announce, or be reachable.
      expect(withPeer.peerService.activeOperationUuid, isNull);
    });

    test('with the experiment on, the same state does start sharing', () async {
      await settings.setExperimentEnabled('p2p', true);
      final withPeer = await servicesOnFreePort();
      await settings.setPeerSyncEnabled(true);
      withPeer.openOperationContext('op-1');
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(withPeer.peerService.activeOperationUuid, 'op-1');
    });

    test('turning the experiment back off tears down a running session', () async {
      await settings.setExperimentEnabled('p2p', true);
      final withPeer = await servicesOnFreePort();
      await settings.setPeerSyncEnabled(true);
      withPeer.openOperationContext('op-1');
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(withPeer.peerService.activeOperationUuid, 'op-1');

      await settings.setExperimentEnabled('p2p', false);
      withPeer.updatePeerSharing();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(withPeer.peerService.activeOperationUuid, isNull,
          reason: 'a device already on the network must leave it when the gate closes');
    });
  });

  testWidgets('the switch is off by default and says the device is invisible', (tester) async {
    await pump(tester);
    final toggle = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(toggle.value, isFalse);
    expect(find.text(t.settings.peers.disabledDescription), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('turning the switch on persists it and changes what the row promises', (tester) async {
    await pump(tester);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(settings.peerSyncEnabled, isTrue);
    expect(find.text(t.settings.peers.enabledDescription), findsOneWidget);
    // Nothing is being shared until an operation is open, and the panel has
    // to say so — otherwise "on" looks broken when no peer ever appears.
    expect(find.text(t.settings.peers.shareNothingOpen), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('with nothing paired it says so, rather than showing an empty space', (tester) async {
    await pump(tester);
    expect(find.text(t.settings.peers.noPairedDevices), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a paired device is listed by name, with its id shown to check against', (tester) async {
    await PeerTrustStore(db).trust('device-b', name: 'Phone');
    await pump(tester);

    expect(find.text('Phone'), findsOneWidget);
    expect(find.text('device-b'), findsOneWidget);
    expect(find.text(t.settings.peers.noPairedDevices), findsNothing);
    await unmount(tester);
  });

  testWidgets('forgetting a device asks first, and cancelling really does nothing', (tester) async {
    final trust = PeerTrustStore(db);
    await trust.trust('device-b', name: 'Phone');
    await pump(tester);

    await tester.tap(find.byIcon(MdiIcons.close));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(t.settings.peers.forgetTitle(name: 'Phone')), findsOneWidget);

    await tester.tap(find.text(t.common.cancel));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(await trust.isTrusted('device-b'), isTrue,
        reason: 'cancelling a destructive confirm must not perform it');

    await tester.tap(find.byIcon(MdiIcons.close));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(FilledButton, t.settings.peers.forget));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(await trust.isTrusted('device-b'), isFalse);
    await unmount(tester);
  });
}
