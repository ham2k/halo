// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Integrations panel. The Captured QSOs band is built inside the StreamBuilder
// that watches the captures, where the SectionedListView around it cannot
// see it — so the panel must cut that section itself. Handed over as a plain
// row instead, the band trips SectionHeader's debug assertion and the panel
// shows an error box where the captures belong.

import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/extensions/extension_info.dart';
import 'package:ham2k_logger/services/inbound_qso_listener_service.dart';
import 'package:ham2k_logger/services/integration_service.dart';
import 'package:ham2k_logger/views/operation/operation_integrations_panel.dart';

import '../support/halo_test_support.dart';

/// One extension offering two integrations, whose `describe` answers come
/// from [describe].
class _ClubIntegrations extends ExtensionServiceWithFakeHost {
  _ClubIntegrations(Object? Function(Map<dynamic, dynamic> args) describe)
    : super(
        FakeExtensionHost({
          'integration:*:getIntegrations': [
            {
              'key': 'k1abc',
              'extensionKey': 'k1abc',
              'ok': true,
              'value': [
                {'key': 'stream', 'title': 'Club Stream', 'description': 'Streams contacts to the club'},
                {'key': 'score', 'title': 'Club Score', 'description': 'Posts the score to the club'},
              ],
            },
          ],
          'integration:k1abc:describe': (Object? args) => describe(args! as Map),
        }),
      );

  @override
  List<ExtensionInfo> get availableExtensions => [
    ExtensionInfo(key: 'k1abc', file: 'k1abc.js', source: ExtensionSource.dev, core: false, name: 'Club', hooks: const ['integration']),
  ];
}

const _stream = 'integration:k1abc:stream';
const _score = 'integration:k1abc:score';

Future<void> _switchOn(HaLoHarness h, String operationUuid, List<String> ids) =>
    h.services.operations.updateLocalData(operationUuid, {IntegrationService.localDataKey: ids});

/// The catalog, the operation's writes and the answers all come over the
/// real event loop.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
  }
}

/// In the body: drift's stream close arms a timer that must fire before the
/// binding's pending-timer check.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
}

Future<Operation> _openWith(WidgetTester tester, HaLoHarness h, List<String> on) async {
  final created = (await tester.runAsync(() => h.services.operations.create(stationCall: 'KI2D')))!;
  if (on.isNotEmpty) await tester.runAsync(() => _switchOn(h, created.uuid, on));
  final operation = (await tester.runAsync(() => h.services.operations.get(created.uuid)))!;
  await pumpHaLo(
    tester,
    (services) => Scaffold(
      body: OperationIntegrationsPanel(services: services, operation: operation),
    ),
    harness: h,
  );
  await _settle(tester);
  return operation;
}

void main() {
  testWidgets('the Captured QSOs band pins over its own rows', (tester) async {
    final operation = Operation(uuid: 'op-1', data: const {'refs': []});
    await pumpHaLo(
      tester,
      (services) => Scaffold(
        body: OperationIntegrationsPanel(services: services, operation: operation),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);
    expect(
      find.ancestor(of: find.byType(SectionHeader), matching: find.byType(PinnedHeaderSliver)),
      findsOneWidget,
      reason: 'a band the list cannot see is not pinned, and its rows join the section above',
    );

    // Unmounted in the body: drift's stream close arms a timer that must fire
    // before the binding's pending-timer check.
    await tester.pumpWidget(const SizedBox.shrink());
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  });

  // Nothing in a datagram says who sent it, so a contact another device sent
  // waits here rather than reaching the log on its own; the operator, who
  // knows their own devices, says which ones to trust.
  testWidgets("another device's contacts wait under its address, and Always add keeps it and adds them here", (tester) async {
    const stranger = '203.0.113.5';
    final h = await makeHaLoServices();
    final operation = (await tester.runAsync(() => h.services.operations.create(stationCall: 'KI2D')))!;
    await tester.runAsync(
      () => h.services.inboundCaptures.capture(
        source: wsjtxSource,
        dedupeKey: 'w1aw',
        qsoData: {
          'their': {'call': 'W1AW'},
          'band': '20m',
          'mode': 'FT8',
        },
        sender: stranger,
      ),
    );
    await pumpHaLo(
      tester,
      (services) => Scaffold(
        body: OperationIntegrationsPanel(services: services, operation: operation),
      ),
      harness: h,
    );
    // The capture comes from the database, and whether its address is this
    // device's own from the network: both on the real event loop.
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }

    final strings = t.operation.import;
    expect(find.text(strings.heldTitle(sender: stranger)), findsOneWidget);

    await tester.tap(find.text(strings.heldAlwaysAction));
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }

    expect(h.settings.inboundSendersAllowed, [stranger]);
    final logged = (await tester.runAsync(() => h.services.qsos.watchForOperation(operation.uuid).first))!;
    expect(logged.map((q) => (q.data['their'] as Map)['call']), ['W1AW']);

    // The added contact's lookup waits out the extension runtime this test
    // never starts.
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pumpWidget(const SizedBox.shrink());
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  });

  // Turning on "Add to this operation" adds the backlog; a held device's
  // contacts in it would reach the log without the operator having said
  // which devices are theirs.
  testWidgets("turning on Add to this operation leaves another device's contacts waiting", (tester) async {
    const stranger = '203.0.113.5';
    final h = await makeHaLoServices();
    final operation = (await tester.runAsync(() => h.services.operations.create(stationCall: 'KI2D')))!;
    for (final (call, sender) in [('W1AW', null), ('K3TN', stranger)]) {
      await tester.runAsync(
        () => h.services.inboundCaptures.capture(
          source: wsjtxSource,
          dedupeKey: call,
          qsoData: {
            'their': {'call': call},
            'band': '20m',
            'mode': 'FT8',
          },
          sender: sender,
        ),
      );
    }
    await pumpHaLo(
      tester,
      (services) => Scaffold(
        body: OperationIntegrationsPanel(services: services, operation: operation),
      ),
      harness: h,
    );
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }

    await tester.tap(find.byType(SwitchListTile));
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }

    final logged = (await tester.runAsync(() => h.services.qsos.watchForOperation(operation.uuid).first))!;
    expect(logged.map((q) => (q.data['their'] as Map)['call']), ['W1AW']);
    expect(find.text(t.operation.import.heldTitle(sender: stranger)), findsOneWidget);

    h.services.inboundQsos.stopReceivingFor(operation.uuid);
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pumpWidget(const SizedBox.shrink());
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  });

  // Switching an integration on in an operation is the operator's consent to
  // what it does there: one that is off is never handed the operation, not
  // even to say what it would do with it.
  testWidgets('an integration off in the operation is never asked about it, and says what it does there once on', (tester) async {
    final asked = <String>[];
    final h = await makeHaLoServices(
      extensions: _ClubIntegrations((args) {
        asked.add(args['integrationKey'] as String);
        return '${args['integrationKey']} answers';
      }),
    );
    final operation = await _openWith(tester, h, const []);
    expect(find.text('Streams contacts to the club'), findsOneWidget);
    expect(asked, isEmpty);

    await tester.runAsync(() => _switchOn(h, operation.uuid, [_stream]));
    await _settle(tester);
    expect(asked, ['stream']);
    expect(find.text('stream answers'), findsOneWidget);
    expect(find.text('Posts the score to the club'), findsOneWidget);

    await tester.runAsync(() => _switchOn(h, operation.uuid, const []));
    await _settle(tester);
    expect(asked, ['stream']);
    expect(find.text('Streams contacts to the club'), findsOneWidget, reason: 'what it said is about an operation it is no longer on in');
    await _unmount(tester);
  });

  // Every contact logged writes the operation (its count, its time range):
  // asking again for each would throw away answers still on their way. And
  // an answer about the operation as it was must never land over one about
  // it as it is.
  testWidgets('a contact logged asks no integration again; an edit to the operation does, and only its answer shows', (tester) async {
    final answers = <Completer<String>>[];
    final h = await makeHaLoServices(extensions: _ClubIntegrations((_) => (answers..add(Completer<String>())).last.future));
    final operation = await _openWith(tester, h, [_stream]);
    expect(answers, hasLength(1));

    // What logging a contact writes to the operation row: its count and time
    // range (`QsosRepository`'s counters). Logged through the repository, its
    // lifecycle follow-up waits on this test's fake clock.
    await tester.runAsync(
      () => (h.db.update(h.db.operations)..where((row) => row.uuid.equals(operation.uuid))).write(
        const OperationsCompanion(qsoCount: Value(1), startAtMillisMin: Value(1700000000000), startAtMillisMax: Value(1700000000000)),
      ),
    );
    await _settle(tester);
    expect(answers, hasLength(1));

    // An edit to the operation, as one synced in writes it. Saved through the
    // repository, its segment restamp waits on this test's fake clock too.
    await tester.runAsync(
      () => (h.db.update(
        h.db.operations,
      )..where((row) => row.uuid.equals(operation.uuid))).write(OperationsCompanion(data: Value(jsonEncode({...operation.data, 'userTitle': 'Field Day'})))),
    );
    await _settle(tester);
    expect(answers, hasLength(2));

    answers[1].complete('Streams Field Day');
    await tester.pump();
    answers[0].complete('Streams the operation as it was');
    await tester.pump();
    expect(find.text('Streams Field Day'), findsOneWidget);
    expect(find.text('Streams the operation as it was'), findsNothing);
    await _unmount(tester);
  });

  // Each integration is asked on its own: one asked again, or switched off,
  // must not throw away another's answer still on its way.
  testWidgets("switching one integration off keeps another's answer coming", (tester) async {
    final score = Completer<String>();
    final h = await makeHaLoServices(extensions: _ClubIntegrations((args) => args['integrationKey'] == 'score' ? score.future : 'Streams'));
    final operation = await _openWith(tester, h, [_stream, _score]);
    expect(find.text('Streams'), findsOneWidget);

    await tester.runAsync(() => _switchOn(h, operation.uuid, [_score]));
    await _settle(tester);
    score.complete('Posts the score');
    await tester.pump();
    expect(find.text('Posts the score'), findsOneWidget);
    expect(find.text('Streams contacts to the club'), findsOneWidget);
    await _unmount(tester);
  });
}
