// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The keying envelopes (HALO-585, docs/design/cat.md § Keying a peer's
// radio): what a station is keying crosses intact, an older peer's offer
// reads as "keys nothing", and a request this build cannot read fully is
// refused rather than half-acted on — the thing on the other end of every
// guess here is a transmitter.

import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

void main() {
  PeerMessage roundTrip(PeerMessage message) => PeerMessage.decode(message.encode())!;

  group('the offer', () {
    test('carries what the far station will do with that radio', () {
      final radios = roundTrip(
        PeerMessage.catOffer(const [
          PeerRadioOffer(id: 'rig-1', name: 'IC-705', keysCw: true, voiceMemories: 8, recordsVoice: true),
          PeerRadioOffer(id: 'rig-2', name: 'QMX'),
        ]),
      ).catOffersOrNull!;

      expect(radios.first.keysCw, isTrue);
      expect(radios.first.voiceMemories, 8);
      expect(radios.first.recordsVoice, isTrue);
      expect(radios.last.keysCw, isFalse, reason: 'a radio offered for tuning alone');
      expect(radios.last.voiceMemories, 0);
    });

    test('an offer from a build that predates keying reads as keying nothing', () {
      // The reason this needed no protocol bump: the fields absent mean
      // exactly what an older peer means by omitting them.
      final radios = PeerMessage.decode(
        PeerMessage(PeerMessageType.catOffer, {
          'radios': [
            {'id': 'rig-1', 'name': 'IC-705'},
          ],
        }).encode(),
      )!.catOffersOrNull!;

      expect(radios.single.keysCw, isFalse);
      expect(radios.single.voiceMemories, 0);
      expect(radios.single.recordsVoice, isFalse);
    });

    test('two offers differing only in what they can key are not equal', () {
      // The offer is deduped before it is broadcast, so an offer that
      // compared equal on its ids alone would leave a controller believing a
      // station still keys after its key was unplugged.
      expect(const PeerRadioOffer(id: 'rig-1', name: 'IC-705', keysCw: true), isNot(const PeerRadioOffer(id: 'rig-1', name: 'IC-705')));
    });
  });

  group('the status', () {
    test('the message going out survives the wire, timing and progress included', () {
      final status = roundTrip(
        PeerMessage.keyStatus(
          const PeerKeyStatusPayload(
            radioId: 'rig-1',
            keyerSpeedWpm: 24,
            keyerSpeedMin: 5,
            keyerSpeedMax: 60,
            cw: PeerCwProgressPayload(id: 9, text: 'CQ TEST', characterEndsMs: [100, 250, 400], pending: ['TU'], pendingIds: [10], sentCount: 2),
          ),
        ),
      ).keyStatusOrNull!;

      expect(status.radioId, 'rig-1');
      expect(status.keyerSpeedWpm, 24);
      expect((status.keyerSpeedMin, status.keyerSpeedMax), (5, 60));
      expect(status.cw!.id, 9, reason: 'the id is what tells a re-report from a fresh message');
      expect(status.cw!.characterEndsMs, [100, 250, 400]);
      expect(status.cw!.pendingIds, [10]);
      expect(status.cw!.sentCount, 2);
    });

    test('a memory playing crosses with its doubt intact', () {
      // Doubt is the far side's, and shown as doubt: resolving it here would
      // either hide a refused memory or claim one that is on the air ended.
      final status = roundTrip(
        PeerMessage.keyStatus(
          const PeerKeyStatusPayload(
            radioId: 'rig-1',
            voice: PeerVoiceActivityPayload(memory: 3, doubtful: true),
            voiceLabels: ['CQ', 'TU'],
            voiceDurationsMs: [4200, 0],
          ),
        ),
      ).keyStatusOrNull!;

      expect(status.voice!.memory, 3);
      expect(status.voice!.doubtful, isTrue);
      expect(status.voice!.recording, isFalse);
      expect(status.voiceLabels, ['CQ', 'TU']);
      expect(status.voiceDurationsMs, [4200, 0]);
    });

    test('an empty status is a real answer: nothing is keying', () {
      final status = roundTrip(PeerMessage.keyStatus(const PeerKeyStatusPayload(radioId: 'rig-1'))).keyStatusOrNull!;

      expect(status.cw, isNull);
      expect(status.voice, isNull);
      expect(status.keyerSpeedWpm, isNull);
    });

    test('a status naming no radio is malformed, not a status about "the" radio', () {
      expect(PeerMessage(PeerMessageType.keyStatus, const {'wpm': 20}).keyStatusOrNull, isNull);
    });

    test('a half-missing speed range is no range at all', () {
      // A picker builds its list from both ends; one of them alone would
      // offer speeds the far keyer clamps without saying so.
      final status = PeerMessage(PeerMessageType.keyStatus, const {'radioId': 'rig-1', 'wpmMin': 5}).keyStatusOrNull!;

      expect(status.keyerSpeedMin, isNull);
      expect(status.keyerSpeedMax, isNull);
    });

    test('pending texts and ids that do not pair drop TOGETHER', () {
      // One fact in two lists: a surface walks the texts and indexes the ids
      // by the same position, so keeping the texts alone is a tap that throws.
      final status = PeerMessage(PeerMessageType.keyStatus, const {
        'radioId': 'rig-1',
        'cw': {
          'id': 1,
          'text': 'CQ',
          'pending': ['TU', 'TEST'],
          'pendingIds': [7],
        },
      }).keyStatusOrNull!;

      expect(status.cw!.pending, isEmpty);
      expect(status.cw!.pendingIds, isEmpty);
    });

    test('a speed range no keyer could have is no range', () {
      // The picker builds ONE ITEM PER WPM from this: a garbled or hostile
      // `wpmMax` is the app materializing a menu until it dies.
      final status = PeerMessage(PeerMessageType.keyStatus, const {'radioId': 'rig-1', 'wpmMin': 5, 'wpmMax': 100000}).keyStatusOrNull!;

      expect(status.keyerSpeedMin, isNull);
      expect(status.keyerSpeedMax, isNull);
    });

    test('a sent count past the message is clamped to it', () {
      // The strip takes `text.substring(0, sentCount)`; a local keyer keeps
      // that invariant, and the wire does not re-establish it.
      final status = PeerMessage(PeerMessageType.keyStatus, const {
        'radioId': 'rig-1',
        'cw': {'id': 1, 'text': 'CQ', 'sent': 99},
      }).keyStatusOrNull!;

      expect(status.cw!.sentCount, 2);
    });
  });

  group('the request', () {
    test('each operation carries what it needs', () {
      for (final request in const [
        PeerKeyRequestPayload(radioId: 'rig-1', op: PeerKeyOp.cw, text: 'CQ TEST'),
        PeerKeyRequestPayload(radioId: 'rig-1', op: PeerKeyOp.stopCw),
        PeerKeyRequestPayload(radioId: 'rig-1', op: PeerKeyOp.dropCw, queuedId: 4),
        PeerKeyRequestPayload(radioId: 'rig-1', op: PeerKeyOp.wpm, wpm: 27),
        PeerKeyRequestPayload(radioId: 'rig-1', op: PeerKeyOp.voice, memory: 2),
        PeerKeyRequestPayload(radioId: 'rig-1', op: PeerKeyOp.record, memory: 2),
        PeerKeyRequestPayload(radioId: 'rig-1', op: PeerKeyOp.stopVoice),
      ]) {
        final decoded = roundTrip(PeerMessage.keySet(request)).keyRequestOrNull;
        expect(decoded, isNotNull, reason: '${request.op} must survive the wire');
        expect(decoded!.op, request.op);
        expect(decoded.radioId, 'rig-1');
        expect(decoded.text, request.text);
        expect(decoded.wpm, request.wpm);
        expect(decoded.memory, request.memory);
        expect(decoded.queuedId, request.queuedId);
      }
    });

    test('a request read only as far as "some sort of keying" is refused', () {
      // Each of these would otherwise reach a transmitter as a guess: a
      // message with nothing in it, a speed of nothing, memory zero, a drop
      // naming no message, an operation this build has never heard of.
      for (final fields in const [
        {'radioId': 'rig-1', 'op': PeerKeyOp.cw},
        {'radioId': 'rig-1', 'op': PeerKeyOp.cw, 'text': '   '},
        {'radioId': 'rig-1', 'op': PeerKeyOp.wpm},
        {'radioId': 'rig-1', 'op': PeerKeyOp.wpm, 'wpm': 0},
        {'radioId': 'rig-1', 'op': PeerKeyOp.voice},
        {'radioId': 'rig-1', 'op': PeerKeyOp.record, 'n': 0},
        {'radioId': 'rig-1', 'op': PeerKeyOp.dropCw},
        {'radioId': 'rig-1', 'op': 'transmitForever'},
        {'op': PeerKeyOp.stopCw},
      ]) {
        expect(PeerMessage(PeerMessageType.keySet, fields).keyRequestOrNull, isNull, reason: 'refused: $fields');
      }
    });

    test('a garbage element in a list costs the element, never the link', () {
      // `onEphemeral` runs synchronously out of the session's dispatch with
      // no catch around it — "unreadable is dropped, never fatal" — so a
      // number field holding a string here would escape into the socket
      // subscription and take the peer link down.
      final status = PeerMessage(PeerMessageType.keyStatus, const {
        'radioId': 'rig-1',
        'durations': ['nope', 4200],
        'cw': {
          'id': 1,
          'text': 'CQ',
          'ends': [true, 200],
        },
      }).keyStatusOrNull!;

      expect(status.voiceDurationsMs, [0, 4200]);
      expect(status.cw!.characterEndsMs, [0, 200]);
    });

    test('an unknown message type is ignored, not a broken link', () {
      // What lets these types be added without a protocol bump.
      expect(PeerMessage(PeerMessageType.keySet, const {'radioId': 'r', 'op': PeerKeyOp.stopCw}).keyStatusOrNull, isNull);
      expect(PeerMessage('keyerSomethingNewer', const {}).keyRequestOrNull, isNull);
    });
  });
}
