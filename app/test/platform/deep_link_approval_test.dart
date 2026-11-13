// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Any web page or installed app can open a `com.ham2k://` link, and a
// `/vfo`, `/qso` or `/operation` one retunes the radio, fills in a contact
// or creates an operation. The traps: one that acts before the operator
// says so; a "don't ask again" for one sender that lets every other sender
// through; and a sender put back to asking that still goes through.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/config/navigation.dart' show navigatorKey;
import 'package:ham2k_logger/services/deep_link_router.dart';
import 'package:ham2k_logger/services/deep_link_service.dart';
import 'package:ham2k_logger/services/halo_services.dart';
import 'package:ham2k_logger/settings/integrations_settings_group.dart';

import '../support/halo_test_support.dart';

/// Stands in for the OS: delivers links, and says who sent each.
class _FakeDeepLinks extends DeepLinkService {
  final _controller = StreamController<Uri>.broadcast();
  final _senders = <String, LinkSender?>{};

  /// What [senderOf] throws, standing in for a native side that does not
  /// answer.
  Object? failure;

  @override
  Stream<Uri> get links => _controller.stream;

  @override
  Future<LinkSender?> senderOf(Uri uri) async {
    if (failure case final failure?) throw failure;
    return _senders[uri.toString()];
  }

  void deliver(String link, {LinkSender? from}) {
    _senders[link] = from;
    _controller.add(Uri.parse(link));
  }
}

const _sotacat = (id: 'android-app://com.example.sotacat', label: 'SOTAcat');
const _stranger = (id: 'android-app://com.example.stranger', label: 'Stranger');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<({HaLoServices services, _FakeDeepLinks links})> pump(WidgetTester tester) async {
    final links = _FakeDeepLinks();
    final harness = await makeHaLoServices(deepLinks: links);
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          navigatorKey: navigatorKey,
          home: const Scaffold(body: SizedBox.expand()),
        ),
      ),
    );
    listenForDeepLinks(harness.services);
    return (services: harness.services, links: links);
  }

  /// Lets the link reach the router, ask the fake who sent it, and act.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Finder allow() => find.widgetWithText(FilledButton, 'Allow');

  /// Ends the test with no timer left behind: a VFO write debounces.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  }

  testWidgets('a /vfo link tunes nothing until the operator allows it, and nothing at all when they deny it', (tester) async {
    final (:services, :links) = await pump(tester);

    links.deliver('com.ham2k:///vfo?frequency=14074000&mode=FT8', from: _sotacat);
    await settle(tester);
    expect(find.text('Link from SOTAcat'), findsOneWidget);
    expect(find.text('Tune the radio to 14.074 FT8?'), findsOneWidget);
    expect(services.radio.vfoA.freq, isNot(14074));

    await tester.tap(find.text('Deny'));
    await settle(tester);
    expect(services.radio.vfoA.freq, isNot(14074));

    links.deliver('com.ham2k:///vfo?frequency=14074000&mode=FT8', from: _sotacat);
    await settle(tester);
    await tester.tap(allow());
    await settle(tester);
    expect(services.radio.vfoA.freq, 14074);
    await unmount(tester);
  });

  testWidgets('"don\'t ask again" covers the sender it was given for, and no other', (tester) async {
    final (:services, :links) = await pump(tester);

    links.deliver('com.ham2k:///vfo?frequency=7030000&mode=CW', from: _sotacat);
    await settle(tester);
    await tester.tap(find.text('Don’t ask again for links from SOTAcat'));
    await tester.pump();
    await tester.tap(allow());
    await settle(tester);
    expect(services.radio.vfoA.freq, 7030);

    links.deliver('com.ham2k:///vfo?frequency=7031000&mode=CW', from: _sotacat);
    await settle(tester);
    expect(find.byType(Dialog), findsNothing);
    expect(services.radio.vfoA.freq, 7031);

    links.deliver('com.ham2k:///vfo?frequency=7032000&mode=CW', from: _stranger);
    await settle(tester);
    expect(find.text('Link from Stranger'), findsOneWidget);
    expect(services.radio.vfoA.freq, 7031);
    await tester.tap(find.text('Deny'));
    await settle(tester);

    // Every platform but Android and iOS names nobody, so "nobody" is a
    // sender of its own, and the remembered one does not stand in for it.
    links.deliver('com.ham2k:///vfo?frequency=7033000&mode=CW');
    await settle(tester);
    expect(find.text('Link from another app'), findsOneWidget);
    expect(services.radio.vfoA.freq, 7031);
    await tester.tap(find.text('Deny'));
    await settle(tester);
    await unmount(tester);
  });

  // An unknown sender is a question; a sender the app could not learn is a
  // refusal, or a sender denied for good would get past as "nobody named".
  testWidgets('a link whose sender cannot be learned is refused without asking', (tester) async {
    final (:services, :links) = await pump(tester);
    links.failure = PlatformException(code: 'gone');

    links.deliver('com.ham2k:///vfo?frequency=7030000&mode=CW', from: _stranger);
    await settle(tester);
    expect(find.byType(Dialog), findsNothing);
    expect(services.radio.vfoA.freq, isNot(7030));
    await unmount(tester);
  });

  // Nobody named is every other app and every web page at once: one Allow
  // kept for it would let all of them through unasked.
  testWidgets('links with no named sender can be denied for good, never allowed', (tester) async {
    final (:services, :links) = await pump(tester);

    links.deliver('com.ham2k:///vfo?frequency=7030000&mode=CW');
    await settle(tester);
    await tester.tap(find.text('Don’t ask again for links from any other apps'));
    await tester.pump();
    expect(tester.widget<FilledButton>(allow()).onPressed, isNull);
    await tester.tap(find.text('Deny'));
    await settle(tester);
    expect(services.settings.linkSenderDecisions['']?.allow, isFalse);

    final group = IntegrationsSettingsGroup(services.settings);
    final row = (await group.buildElements()).singleWhere((row) => row['fieldType'] == 'select');
    expect((row['options'] as List).map((option) => (option as Map)['value']), ['deny']);

    // However one got there, a kept Allow for nobody named still asks.
    await services.settings.decideLinkSender('', label: '', allow: true);
    links.deliver('com.ham2k:///vfo?frequency=7031000&mode=CW');
    await settle(tester);
    expect(find.text('Link from another app'), findsOneWidget);
    expect(services.radio.vfoA.freq, isNot(7031));
    await tester.tap(find.text('Deny'));
    await settle(tester);
    await unmount(tester);
  });

  testWidgets('an /operation link creates nothing unless allowed', (tester) async {
    final (:services, :links) = await pump(tester);

    links.deliver('com.ham2k:///operation?our.refs=pota:US-0001', from: _stranger);
    await settle(tester);
    expect(find.text('Open the operation for pota:US-0001, starting one if needed?'), findsOneWidget);
    await tester.tap(find.text('Deny'));
    await settle(tester);

    final operations = await tester.runAsync(() => services.operations.watchAll().first);
    expect(operations, isEmpty);
    await unmount(tester);
  });

  testWidgets('a /qso link that would retune says so, and fills in nothing when denied', (tester) async {
    final (:services, :links) = await pump(tester);

    links.deliver('com.ham2k:///qso?their.call=N0CALL&frequency=14250000&mode=SSB', from: _stranger);
    await settle(tester);
    expect(find.text('Fill in a contact with N0CALL and tune the radio to 14.250 SSB?'), findsOneWidget);
    await tester.tap(find.text('Deny'));
    await settle(tester);
    expect(services.radio.vfoA.freq, isNot(14250));
    await unmount(tester);
  });

  testWidgets('"don\'t ask again" on Deny refuses that sender from then on, without asking', (tester) async {
    final (:services, :links) = await pump(tester);

    links.deliver('com.ham2k:///vfo?frequency=7030000&mode=CW', from: _stranger);
    await settle(tester);
    await tester.tap(find.text('Don’t ask again for links from Stranger'));
    await tester.pump();
    await tester.tap(find.text('Deny'));
    await settle(tester);

    links.deliver('com.ham2k:///vfo?frequency=7030000&mode=CW', from: _stranger);
    await settle(tester);
    expect(find.byType(Dialog), findsNothing);
    expect(services.radio.vfoA.freq, isNot(7030));
    await unmount(tester);
  });

  // Every answer given for good is listed and can be changed: an Allow left
  // behind with no way to see it is a sender that tunes the radio forever.
  testWidgets('Settings lists each sender\'s answer, turns it around, and removes it so the links ask again', (tester) async {
    final (:services, :links) = await pump(tester);
    await services.settings.decideLinkSender(_sotacat.id, label: _sotacat.label, allow: true);
    await services.settings.decideLinkSender(_stranger.id, label: _stranger.label, allow: false);

    final group = IntegrationsSettingsGroup(services.settings);
    List<Map<String, dynamic>> senderRows(List<Map<String, dynamic>> rows) => rows.where((row) => row['fieldType'] == 'select').toList();
    final rows = senderRows(await group.buildElements());
    expect([for (final row in rows) (row['label'], row['value'])], [('SOTAcat', 'allow'), ('Stranger', 'deny')]);

    await group.commit('linkSender:${_sotacat.id}', 'deny');
    links.deliver('com.ham2k:///vfo?frequency=10136000&mode=FT8', from: _sotacat);
    await settle(tester);
    expect(find.byType(Dialog), findsNothing);
    expect(services.radio.vfoA.freq, isNot(10136));

    await group.commit('linkSender:${_sotacat.id}', 'remove');
    expect(senderRows(await group.buildElements()).map((row) => row['label']), ['Stranger']);
    links.deliver('com.ham2k:///vfo?frequency=10136000&mode=FT8', from: _sotacat);
    await settle(tester);
    expect(find.text('Link from SOTAcat'), findsOneWidget);
    await tester.tap(find.text('Deny'));
    await settle(tester);

    await group.commit('linkSender:${_stranger.id}', 'remove');
    expect(await group.buildElements(), isEmpty, reason: 'nothing decided, nothing listed');
    await unmount(tester);
  });
}
