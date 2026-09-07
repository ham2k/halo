// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Peer Devices settings panel (HALO-310). The service beneath it has its
// own end-to-end tests; these cover what those cannot — that the panel
// reflects the switch, lists what is paired, and that the destructive action
// asks first.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/services/peer/peer_service.dart';
import 'package:ham2k_logger/views/peers_panel.dart';

import 'support/peer_network_fakes.dart';

import 'support/halo_test_support.dart';

void main() {
  late HaLoDatabase db;
  late SettingsService settings;
  late HaLoServices services;

  setUp(() async {
    final harness = await makeHaLoServices(extensions: ExtensionServiceWithFakeHost());
    services = harness.services;
    db = harness.db;
    settings = harness.settings;
  });

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
    /// A services bundle whose peer service runs on an in-memory segment, so
    /// the "gate open" case can actually start without touching the real
    /// discovery port (or another HaLo running on this machine).
    Future<HaLoServices> servicesOnFakeLan() async {
      final peer = PeerService(
        db: db,
        outbox: PeerOutbox(db),
        operations: OperationsRepository(db),
        qsos: QsosRepository(db),
        localDeviceId: 'local',
        localDeviceName: 'Local',
        network: FakeLan().host().network,
      );
      addTearDown(() async {
        await peer.setEnabled(false);
        peer.dispose();
      });
      return HaLoServices(db, settings,
          extensions: ExtensionServiceWithFakeHost()..settings = settings, peerService: peer);
    }

    test('with the experiment off, an open operation and the switch on start nothing', () async {
      final withPeer = await servicesOnFakeLan();
      await settings.setPeerSyncEnabled(true);
      withPeer.openOperationContext('op-1');
      // Not merely "no UI": nothing may bind, announce, or be reachable.
      expect(withPeer.peerService.running, isFalse);
    });

    test('with the experiment on, the same state does start sharing', () async {
      await settings.setExperimentEnabled('p2p', true);
      final withPeer = await servicesOnFakeLan();
      await settings.setPeerSyncEnabled(true);
      withPeer.openOperationContext('op-1');
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(withPeer.peerService.running, isTrue);
      expect(withPeer.peerService.sharedOperationUuid, 'op-1');
    });

    test('turning the experiment back off tears down a running session', () async {
      await settings.setExperimentEnabled('p2p', true);
      final withPeer = await servicesOnFakeLan();
      await settings.setPeerSyncEnabled(true);
      withPeer.openOperationContext('op-1');
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(withPeer.peerService.running, isTrue);

      await settings.setExperimentEnabled('p2p', false);
      withPeer.updatePeerSharing();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(withPeer.peerService.running, isFalse,
          reason: 'a device already on the network must leave it when the gate closes');
    });
  });

  testWidgets('the switch is off by default, and says what turning it on would do', (tester) async {
    await pump(tester);
    final toggle = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(toggle.value, isFalse);
    // One description in both states: it describes what the switch is FOR,
    // so an operator deciding whether to turn it on reads the same promise
    // the one who already did sees.
    expect(find.text(t.settings.peers.enableDescription), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('turning the switch on persists it', (tester) async {
    await pump(tester);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(settings.peerSyncEnabled, isTrue);
    expect(find.text(t.settings.peers.enableDescription), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('with nothing paired it says so, rather than showing an empty space', (tester) async {
    await pump(tester);
    expect(find.text(t.settings.peers.noPairedDevices), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a linked device is listed by name, with a short id to check against', (tester) async {
    // A real device id is a v4 UUID, and the row shows only its first group:
    // an 8-character fixture would pass whether the shortening works, breaks,
    // or is deleted.
    const deviceId = '6f1c2a90-8f3e-4d21-9b77-2ce20b8dff84';
    await PeerTrustStore(db).trust(deviceId, name: 'Phone');
    await pump(tester);

    expect(find.text('Phone'), findsOneWidget);
    expect(find.text('6f1c2a90'), findsOneWidget);
    expect(find.text(deviceId), findsNothing,
        reason: 'the full id belongs to no row — it is what the short form replaces');
    expect(find.text(t.settings.peers.noPairedDevices), findsNothing);
    await unmount(tester);
  });

  testWidgets('a Bluetooth failure is on screen — it is the only signal there is', (tester) async {
    // The panel has no positive "Bluetooth is on" row any more, so this
    // string is the ONLY thing that distinguishes a refused radio from an
    // empty room. Deleting the row would otherwise break nothing visible.
    await settings.setPeerSyncEnabled(true);
    services.peerService.bleError = 'Bluetooth is turned off';
    await pump(tester);

    expect(find.text(t.settings.peers.bleProblem(error: 'Bluetooth is turned off')), findsOneWidget);
    await unmount(tester);
  });

  group('the nearby group', () {
    test('a linked device that is also beaconing is not listed a second time', () {
      // It belongs to the linked group, which carries its live status.
      // Listing it here too shows one box as two — what a Nearby section
      // beside an Allowed Devices one did.
      expect(unlinkedPeerDeviceIds({'mine'}, ['mine', 'stranger']), ['stranger']);
    });

    test('a device nobody has linked is listed', () {
      expect(unlinkedPeerDeviceIds(const <String>{}, ['stranger']), ['stranger']);
    });
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
