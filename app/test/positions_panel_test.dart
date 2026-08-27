// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// How one operating position's block reads (HALO-395). The routing and the
// wire are covered over real sockets in peer_channels_test; this is the half
// that decides what an operator actually sees — above all, which values read
// as their own answer and which as the app's.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';

import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/services/peer/peer_drafts.dart';
import 'package:ham2k_logger/views/operation/positions_panel.dart';

void main() {
  final operation = Operation(uuid: 'op-1', data: {'stationCall': 'K2SUL'});

  PeerDraftBlock blockOf({
    String deviceId = 'device-b',
    String deviceName = '',
    String position = '',
    String operatorCall = '',
    List<PeerDraftFieldPayload> fields = const [],
    Map<String, dynamic>? their,
    Map<String, dynamic> vfo = const {'band': '20m', 'mode': 'CW', 'freq': 14025.0},
  }) =>
      PeerDraftBlock(
        deviceId: deviceId,
        deviceName: deviceName,
        draft: PeerQsoDraftPayload(
          qso: {'their': their ?? const {}, ...vfo},
          operationUuid: 'op-1',
          fields: fields,
          position: position,
          operatorCall: operatorCall,
        ),
      );

  Future<void> pump(WidgetTester tester, PeerDraftBlock block) async {
    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        home: Scaffold(
          body: PositionBlockView(
            block: block,
            operation: operation,
            miles: false,
            showBearing: false,
          ),
        ),
      ),
    ));
  }

  /// Every rendered run, in order, with the colour it actually came out as —
  /// the assertion that matters here, since a typed value and a suggested one
  /// differ by nothing else. Two runs can carry the same text (a typed `59`
  /// and a hinted `59`), so position in this list is what tells them apart.
  List<(String, Color?)> runs(WidgetTester tester) => [
        for (final widget in tester.widgetList<Text>(find.byType(Text)))
          if (widget.textSpan case final TextSpan span)
            for (final child in span.children ?? const <InlineSpan>[])
              if (child is TextSpan && (child.text ?? '').trim().isNotEmpty)
                (child.text!, child.style?.color),
      ];

  Color? colorOf(WidgetTester tester, String text) =>
      runs(tester).where((run) => run.$1 == text).map((run) => run.$2).firstOrNull;

  group('the header says whose block this is', () {
    testWidgets('position and operator together', (tester) async {
      await pump(tester, blockOf(position: '2', operatorCall: 'KI2D'));
      expect(find.text('Pos: 2 - Op: KI2D'), findsOneWidget);
    });

    testWidgets('the operator alone when no position is set', (tester) async {
      await pump(tester, blockOf(operatorCall: 'KI2D'));
      expect(find.text('Op: KI2D'), findsOneWidget);
    });

    // The last resort. Two unlabelled blocks would be indistinguishable, which
    // is the one thing a panel of several positions cannot afford.
    testWidgets("the device's own name when it has neither", (tester) async {
      await pump(tester, blockOf(deviceName: "SD's MacBook"));
      expect(find.text("SD's MacBook"), findsOneWidget);
    });

    // A peer with nothing to identify it at all.
    testWidgets('a nameless peer is still called something', (tester) async {
      await pump(tester, blockOf());
      expect(find.text('Another position'), findsOneWidget);
    });

    // This device has no beacon name to fall back on, so it would land on the
    // peer wording — a lie about the one block the operator is sitting at.
    testWidgets("this device's own block says so", (tester) async {
      await pump(tester, blockOf(deviceId: localDraftPeerId));
      expect(find.text('Our operating position'), findsOneWidget);
      expect(find.text('Another position'), findsNothing);
    });
  });

  group('the VFO line', () {
    testWidgets('reads band, mode and frequency', (tester) async {
      await pump(tester, blockOf());
      expect(find.text('20m CW 14,025'), findsOneWidget);
    });

    // A radio that has not answered yet must not have a band invented for it.
    testWidgets('says only what the position actually has', (tester) async {
      await pump(tester, blockOf(vfo: const {'band': '20m'}));
      expect(find.text('20m'), findsOneWidget);
    });
  });

  group('the operator\'s answers read differently from the app\'s', () {
    // The distinction the whole panel exists for. Both reports say 59; only
    // which of value/hint carries it says who decided.
    testWidgets('a typed report and a defaulted one do not look alike', (tester) async {
      await pump(
        tester,
        blockOf(fields: const [
          PeerDraftFieldPayload(key: 'call', value: 'KN2X'),
          PeerDraftFieldPayload(key: 'sent', value: '59'),
          PeerDraftFieldPayload(key: 'rcvd', hint: '59'),
        ]),
      );
      final row = runs(tester);
      expect(row.map((run) => run.$1), ['KN2X', '59', '59'],
          reason: 'the row renders in the order the sender sent it');
      // Both read "59". Sent was typed, Rcvd is only what the app would send —
      // and an operator has to be able to see which is which at a glance.
      expect(row[1].$2, row[0].$2, reason: 'a typed report reads like any other typed value');
      expect(row[2].$2, isNot(row[1].$2), reason: 'a defaulted report must not read as answered');
    });

    testWidgets('a field with neither a value nor a hint takes no room', (tester) async {
      await pump(
        tester,
        blockOf(fields: const [
          PeerDraftFieldPayload(key: 'call', value: 'KN2X'),
          PeerDraftFieldPayload(key: 'state'),
        ]),
      );
      expect(runs(tester).map((run) => run.$1), ['KN2X'],
          reason: 'a field with nothing to say is left out, not rendered blank');
    });

    // The row is the SENDER's, so a control this build has no extension for
    // still has to appear — that is what putting it on the wire buys.
    testWidgets('a control this build knows nothing about still renders', (tester) async {
      await pump(
        tester,
        blockOf(fields: const [
          PeerDraftFieldPayload(key: 'wfd_class', label: 'Class', value: '3A'),
        ]),
      );
      expect(colorOf(tester, '3A'), isNotNull);
    });
  });

  group('the call-info lines', () {
    testWidgets("the operator's own name outranks the lookup's", (tester) async {
      await pump(tester, blockOf(their: const {
        'name': 'Johnny',
        'guess': {'name': 'John'},
      }));
      expect(colorOf(tester, 'Johnny'), isNotNull);
      expect(colorOf(tester, 'John'), isNull);
    });

    testWidgets("the lookup's name shows when the operator set none", (tester) async {
      await pump(tester, blockOf(their: const {
        'guess': {'name': 'John'},
      }));
      expect(colorOf(tester, 'John'), isNotNull);
    });

    testWidgets('a place joins the name', (tester) async {
      await pump(tester, blockOf(their: const {
        'guess': {'name': 'John', 'location': 'Wurstboro, NY'},
      }));
      expect(colorOf(tester, 'Wurstboro, NY'), isNotNull);
    });
  });
}
