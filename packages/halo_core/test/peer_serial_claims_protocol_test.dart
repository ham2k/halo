// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The serialClaims envelope (docs/design/contests.md §5.8.1): what a
// position holds crosses the wire intact, and what it cannot read costs
// only the entry that is unreadable.

import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

void main() {
  PeerMessage roundTrip(PeerMessage message) => PeerMessage.decode(message.encode())!;

  test('the claim set survives the wire, conflict mark and ack included', () {
    final payload = roundTrip(PeerMessage.serialClaims(
      operationUuid: 'op-1',
      seq: 7,
      claims: const [
        PeerSerialClaim(label: 'cqwpx/serial', number: 42),
        PeerSerialClaim(label: 'r1vhf/serial/2m', number: 3, conflicted: true),
        PeerSerialClaim(label: 'cqwpx/serial', number: 41, committed: true),
      ],
      ack: 5,
    )).serialClaimsOrNull!;
    expect(payload.operationUuid, 'op-1');
    expect(payload.seq, 7);
    expect(payload.ack, 5);
    expect(payload.claims, const [
      PeerSerialClaim(label: 'cqwpx/serial', number: 42),
      PeerSerialClaim(label: 'r1vhf/serial/2m', number: 3, conflicted: true),
      PeerSerialClaim(label: 'cqwpx/serial', number: 41, committed: true),
    ]);
  });

  test('an empty set is a real message — it is how a position says it holds nothing', () {
    final payload = roundTrip(PeerMessage.serialClaims(operationUuid: 'op-1', seq: 1, claims: const []))
        .serialClaimsOrNull!;
    expect(payload.claims, isEmpty);
    expect(payload.ack, isNull);
  });

  test('a message naming no operation is refused', () {
    // Numbers held against the wrong operation would block a sequence that
    // never competed with them.
    expect(const PeerMessage(PeerMessageType.serialClaims, {'seq': 1, 'claims': []}).serialClaimsOrNull, isNull);
    expect(
      const PeerMessage(PeerMessageType.serialClaims, {'opUuid': '', 'seq': 1, 'claims': []}).serialClaimsOrNull,
      isNull,
    );
  });

  test('a message with no version is refused — nothing could order it', () {
    expect(
      const PeerMessage(PeerMessageType.serialClaims, {'opUuid': 'op-1', 'claims': []}).serialClaimsOrNull,
      isNull,
    );
  });

  test('an unreadable claim costs only itself', () {
    final payload = const PeerMessage(PeerMessageType.serialClaims, {
      'opUuid': 'op-1',
      'seq': 2,
      'claims': [
        {'l': 'cqwpx/serial', 'n': 9},
        {'l': '', 'n': 1},
        {'l': 'x', 'n': 'nine'},
        'junk',
      ],
    }).serialClaimsOrNull!;
    expect(payload.claims, const [PeerSerialClaim(label: 'cqwpx/serial', number: 9)]);
  });

  test('another message type never reads as a claim set', () {
    expect(PeerMessage.qsoDraft(qso: const {}, operationUuid: 'op-1').serialClaimsOrNull, isNull);
  });
}
