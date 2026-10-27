// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The bottom chrome's rebuild budget. Its builder divides the bottom of the
// window and hands the rail its shell, so a rebuild of it is a rebuild of
// both — and nothing it decides depends on the radio or the peers. A radio
// reports a reading several times a second while it is being tuned; those
// must reach the status that names the radio and stop there.
//
// Pumps the REAL overlay over a CatService whose fake radio reports back, so
// a reading takes the path it takes in the app, and counts the framework's
// own rebuilds rather than trusting the listenable lists.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/config/navigation.dart';
import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:ham2k_logger/services/halo_services.dart';
import 'package:ham2k_logger/services/peer/peer_service.dart';
import 'package:ham2k_logger/services/radio_service.dart';
import 'package:ham2k_logger/views/app_shell/status_bar_overlay.dart';
import 'package:ham2k_logger/views/home_navigation_rail.dart';

import '../support/fake_cat_radio.dart';
import '../support/halo_test_support.dart';

/// A peer service whose live links are stated rather than dialled, and change
/// after mount — [PeerService.hasSession] is what the badge counts.
class _PeerServiceWithLinks extends PeerService {
  _PeerServiceWithLinks({
    required super.db,
    required super.outbox,
    required super.operations,
    required super.qsos,
    required super.localDeviceId,
    required super.localDeviceName,
  });

  final live = <String>{};

  @override
  bool hasSession(String peerDeviceId) => live.contains(peerDeviceId);

  /// A link came up or dropped: what the real service says when a session
  /// opens or closes.
  void linksChanged() => notifyListeners();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoHarness harness;
  late FakeRadio radio;
  late RadioService radioService;
  late CatService cat;
  late HaLoServices services;
  final rebuilds = <Type, int>{};

  setUp(() async {
    harness = await makeHaLoServices();
    radio = FakeRadio();
    radioService = RadioService(harness.settings.prefs, writeDelay: Duration.zero);
    cat = radio.catService(harness.settings, radioService);
    addTearDown(radioService.dispose);
    rebuilds.clear();
    // The framework's own word on what rebuilt, element by element.
    final previous = debugOnRebuildDirtyWidget;
    debugOnRebuildDirtyWidget = (element, _) {
      final widget = element.widget;
      if (widget is HomeRailShell || widget is StatusBarFooter) rebuilds.update(widget.runtimeType, (n) => n + 1, ifAbsent: () => 1);
    };
    addTearDown(() => debugOnRebuildDirtyWidget = previous);
  });

  int rebuildsOf(Type type) => rebuilds[type] ?? 0;

  /// The overlay where `MaterialApp.builder` mounts it, over the REAL
  /// Navigator the statuses' actions reach through [navigatorKey].
  Future<void> pumpOverlay(WidgetTester tester) async {
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          navigatorKey: navigatorKey,
          builder: (context, child) => StatusBarOverlay(services: services, child: child ?? const SizedBox.shrink()),
          home: const Scaffold(resizeToAvoidBottomInset: false, body: SizedBox.expand()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Runs [body] and disposes the CatService after it, whatever happened: a
  /// connected radio arms its silence watch on every reading, and the
  /// binding's pending-timer check runs before any tearDown could cancel it,
  /// so a failing expect would otherwise report that timer on top of itself
  /// and leave the radio armed under the next test.
  Future<void> withRadio(Future<void> Function() body) async {
    try {
      await body();
    } finally {
      cat.dispose();
    }
  }

  testWidgets(
    'VFO readings reach the radio status and stop there: neither the chrome nor the rail rebuilds',
    (tester) => withRadio(() async {
      services = HaLoServices(harness.db, harness.settings, cat: cat);
      // Real time for the CAT layer's own awaits: inside the test's fake-async
      // zone a connect that waits on a timer never returns.
      await tester.runAsync(() => connectFakeRadio1(cat));
      await pumpOverlay(tester);
      expect(find.byIcon(MdiIcons.cat), findsOneWidget, reason: 'the radio status is in the bar');
      // The mount is the positive control: the hook counts both, so a zero
      // below is a chrome that was not rebuilt, not a count that never ran.
      expect(rebuildsOf(HomeRailShell), greaterThan(0));
      expect(rebuildsOf(StatusBarFooter), greaterThan(0));
      // The first readings prove the radio, which is news the chrome may carry
      // once; what is counted below is the steady state, a rig being tuned.
      radio.reports(freqKHz: 14074, mode: 'CW');
      radio.reports(freqKHz: 14075, mode: 'CW');
      await tester.pumpAndSettle();
      rebuilds.clear();

      // Each reading moves the frequency, so each one is CatService notifying.
      for (var i = 0; i < 10; i++) {
        radio.reports(freqKHz: 14100 + i.toDouble(), mode: 'CW');
        await tester.pump();
      }
      expect(rebuildsOf(HomeRailShell), 0, reason: 'the rail rebuilt for a reading it does not show');
      expect(rebuildsOf(StatusBarFooter), 0, reason: 'the footer rebuilt for a glyph that does not change');

      // The status still follows the radio, through its own builder: a
      // disconnect reaches its line in the menu.
      final station = TranslationProvider.of(tester.element(find.byType(StatusBarOverlay))).translations.settings.station;
      await tester.runAsync(() => cat.disconnect((cat.radio1 as LocalRadio).uuid));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(MdiIcons.cat));
      await tester.pumpAndSettle();
      expect(find.textContaining(station.statusDisconnected), findsOneWidget);
      expect(rebuildsOf(HomeRailShell), 0, reason: 'a state change is the status\'s news, not the chrome\'s');
    }),
  );

  testWidgets(
    'a peer link coming up reaches the badge and stops there',
    (tester) => withRadio(() async {
      await harness.settings.setExperimentEnabled('p2p', true);
      final peers = _PeerServiceWithLinks(
        db: harness.db,
        outbox: PeerOutbox(harness.db),
        operations: OperationsRepository(harness.db),
        qsos: QsosRepository(harness.db),
        localDeviceId: 'me',
        localDeviceName: 'This Mac',
      );
      services = HaLoServices(harness.db, harness.settings, cat: cat, peerService: peers);
      await peers.trust.trust('device-a', name: 'Shack Mac');
      await peers.refreshLinkedDevices();
      await pumpOverlay(tester);
      expect(find.text('0'), findsOneWidget, reason: 'one linked device, none live');
      expect(rebuildsOf(HomeRailShell), greaterThan(0), reason: 'the mount is the positive control');
      rebuilds.clear();

      peers.live.add('device-a');
      peers.linksChanged();
      await tester.pump();
      expect(find.text('1'), findsOneWidget, reason: 'the badge followed the live count');
      expect(rebuildsOf(HomeRailShell), 0, reason: 'the rail rebuilt for a peer link it does not show');
      expect(rebuildsOf(StatusBarFooter), 0, reason: 'the footer rebuilt for one badge');
    }),
  );
}
