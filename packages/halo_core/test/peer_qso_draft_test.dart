// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The qsoDraft envelope: what one operating position is composing, as its
// peers read it off the wire.

import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

void main() {
  Map<String, dynamic> draft({Object? lookups, String call = 'KN2X'}) => {
        'their': {
          'call': call,
          'sent': '59',
          'guess': {'name': 'John', 'state': 'NY'},
          'lookups': ?lookups,
        },
        'our': {'call': 'K2SUL', 'sent': '59'},
        'freq': 14025.0,
        'band': '20m',
        'mode': 'CW',
      };

  /// Encode and decode, as a real link does.
  PeerQsoDraftPayload? roundTrip(PeerMessage message) => PeerMessage.decode(message.encode())?.qsoDraftOrNull;

  test('the draft survives the wire', () {
    final payload = roundTrip(PeerMessage.qsoDraft(
      qso: draft(),
      operationUuid: 'op-1',
      fields: const [
        PeerDraftFieldPayload(key: 'call', label: 'Call', value: 'KN2X'),
        PeerDraftFieldPayload(key: 'sent', label: 'Sent', hint: '59'),
      ],
      position: '2',
      operatorCall: 'KI2D',
    ))!;
    expect((payload.qso['their'] as Map)['call'], 'KN2X');
    expect((payload.qso['their'] as Map)['guess'], {'name': 'John', 'state': 'NY'});
    expect(payload.qso['band'], '20m');
    expect(payload.fields.map((f) => f.key), ['call', 'sent']);
    expect(payload.fields.first.label, 'Call');
    // The operator's own answer, and the app's, told apart by which of the two
    // is populated — the distinction the whole panel rests on.
    expect(payload.fields.first.value, 'KN2X');
    expect(payload.fields.last.value, isEmpty);
    expect(payload.fields.last.hint, '59');
    expect(payload.position, '2');
    expect(payload.operatorCall, 'KI2D');
  });

  // `lookups` is the raw evidence behind `their.guess` — kilobytes of it,
  // nothing on the receiving end reads it, and it would ride the wire on
  // every keystroke that changed anything.
  test('the lookup evidence is left behind', () {
    final payload = roundTrip(PeerMessage.qsoDraft(
      operationUuid: 'op-1',
      qso: draft(lookups: [
        {'source': 'qrz', 'name': 'John', 'padding': 'x' * 4096},
      ]),
    ))!;
    expect((payload.qso['their'] as Map).containsKey('lookups'), isFalse);
    // The guess it produced is what the panel actually shows, so stripping
    // the evidence must not take the answer with it.
    expect((payload.qso['their'] as Map)['guess'], {'name': 'John', 'state': 'NY'});
  });

  // The published draft shares nested maps with the QSO being edited and with
  // the dedupe's own copy of it (`LoggingControls._lastPublishedQso`). A strip
  // that removed `lookups` from the caller's map in place would move both
  // sides of that comparison together, and the panel watching it would
  // silently stop updating.
  test('stripping never reaches into the caller\'s draft', () {
    final original = draft(lookups: [
      {'source': 'qrz'},
    ]);
    PeerMessage.qsoDraft(qso: original, operationUuid: 'op-1');
    expect((original['their'] as Map).containsKey('lookups'), isTrue);
  });

  // How a position says it has just logged or wiped. A reader that rejected
  // this would leave the last contact on screen for good.
  test('a draft with no callsign is a real draft', () {
    final payload = roundTrip(PeerMessage.qsoDraft(qso: draft(call: ''), operationUuid: 'op-1'))!;
    expect((payload.qso['their'] as Map)['call'], '');
  });

  test('a position and operator that were never set arrive empty', () {
    final payload = roundTrip(PeerMessage.qsoDraft(qso: draft(), operationUuid: 'op-1'))!;
    expect(payload.position, '');
    expect(payload.operatorCall, '');
    expect(payload.fields, isEmpty);
  });

  test('the draft names the operation it belongs to', () {
    expect(roundTrip(PeerMessage.qsoDraft(qso: draft(), operationUuid: 'op-1'))!.operationUuid, 'op-1');
  });

  // A session outlives an operation change on either side, so a draft that
  // named no operation would be shown against whatever the reader happens to
  // have open — attributing a peer's contact to the wrong operation, which is
  // worse than a block that never appears.
  test('a draft that names no operation is refused', () {
    expect(PeerMessage(PeerMessageType.qsoDraft, {'qso': draft()}).qsoDraftOrNull, isNull);
    expect(PeerMessage(PeerMessageType.qsoDraft, {'qso': draft(), 'opUuid': ''}).qsoDraftOrNull, isNull);
  });

  test('a draft that is not an object at all is refused', () {
    expect(PeerMessage(PeerMessageType.qsoDraft, const {'qso': 'nope', 'opUuid': 'op-1'}).qsoDraftOrNull, isNull);
    expect(PeerMessage(PeerMessageType.qsoDraft, const {}).qsoDraftOrNull, isNull);
  });

  test('another message type never reads as a draft', () {
    expect(PeerMessage.catStatus(radioId: 'rig-1', freqKHz: 14025).qsoDraftOrNull, isNull);
  });

  // A peer on a newer build may put controls in its row this one has never
  // heard of, and the list crossed a network to get here. One bad entry must
  // cost that entry — a block missing a field still says what the position is
  // working.
  test('an unreadable entry in the field row costs only itself', () {
    final payload = PeerMessage(PeerMessageType.qsoDraft, {
      'qso': draft(),
      'opUuid': 'op-1',
      'fields': [
        {'k': 'call', 'v': 'KN2X'},
        42,
        null,
        {'l': 'no key at all'},
        {'k': 'state', 'v': 'NY'},
      ],
    }).qsoDraftOrNull!;
    expect(payload.fields.map((f) => f.key), ['call', 'state']);
  });

  // A contest exchange this build has no extension for still has to render
  // under the name its own extension gave it — that is what putting the row
  // on the wire buys over deriving it at the far end.
  test('a control this build knows nothing about still arrives named', () {
    final payload = roundTrip(PeerMessage.qsoDraft(
      qso: draft(),
      operationUuid: 'op-1',
      fields: const [PeerDraftFieldPayload(key: 'wfd_class', label: 'Class', value: '3A')],
    ))!;
    expect(payload.fields.single.label, 'Class');
    expect(payload.fields.single.value, '3A');
  });
}
