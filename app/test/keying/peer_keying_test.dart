// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Keying a radio on another device (HALO-585), from both ends of the link,
// through `CatService` — which is the whole of what the surfaces see: the
// function keys, the strip, the WPM command and both dialogs read these same
// getters and call these same methods whether the rig is here or there.
//
// No sockets: the requests a controller would send are collected off
// `sendPeerKeyRequest` (the router's slot) and the statuses a peer would send
// are handed to `notePeerKeyStatus` directly. What the router does with them
// is peer_channels_test's; what is asserted here is the DECISION — which side
// keys, and what the surfaces then read.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/peer/peer_station_radios.dart';
import 'package:ham2k_logger/services/settings_service.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoServices services;
  late SettingsService settings;
  late CatService cat;

  /// Every request this device asked a peer for, in order.
  late List<PeerKeyRequestPayload> requests;

  const pick = PeerRadioSelection(
    deviceId: 'device-a',
    radioId: 'rig-1',
    deviceName: 'Shack Mac',
    radioName: 'IC-705',
  );

  /// The offer a keying peer sends: its key answers for the radio, and the
  /// radio has memories of its own.
  const keyingOffer = PeerRadioOffer(
    id: 'rig-1',
    name: 'IC-705',
    keysCw: true,
    voiceMemories: 4,
    recordsVoice: true,
  );

  setUp(() async {
    final harness = await makeHaLoServices();
    settings = harness.settings;
    services = harness.services;
    cat = services.cat;
    await settings.setExperimentEnabled('keyer', true);
    requests = [];
    cat.sendPeerKeyRequest = requests.add;
  });

  /// Picks that peer's radio and hears the offer that says what it can do —
  /// the two halves the app gets separately, since a pick survives the peer
  /// walking away and an offer arrives without anyone picking again.
  Future<void> followPeerRadio({PeerRadioOffer offer = keyingOffer}) async {
    await cat.setRadio1(const PeerRadio(pick));
    cat.noteOffer(pick.deviceId, pick.deviceName, [offer]);
  }

  Future<EquipmentNode> connectPlaceholder({String name = 'Bench Rig'}) async {
    final node = await cat.addNode(
      typeKey: 'placeholder-radio',
      name: name,
      config: placeholderRadioModel.variants.single.defaultConfig,
    );
    await cat.connect(node.uuid);
    addTearDown(() => cat.disconnect(node.uuid));
    return node;
  }

  group('as the controller', () {
    test('a message goes to the peer instead of being keyed here', () async {
      await followPeerRadio();

      expect(cat.canKeyCw, isTrue, reason: 'the peer said it keys, so the function keys are live');
      cat.sendCw('CQ TEST');

      expect(requests.single.op, PeerKeyOp.cw);
      expect(requests.single.radioId, 'rig-1');
      expect(requests.single.text, 'CQ TEST');
    });

    test('what crosses is the RENDERED message, never a template', () async {
      // The far station has no draft contact to render against, so a
      // template reaching it would be keyed with its braces in Morse.
      // Rendering happens above this call; what this proves is that nothing
      // here re-wraps or re-derives the text.
      await followPeerRadio();

      cat.sendCw('N0DEV 5NN');

      expect(requests.single.text, 'N0DEV 5NN');
    });

    test('a peer that offers no keying keys nothing, and nothing is sent', () async {
      await followPeerRadio(offer: const PeerRadioOffer(id: 'rig-1', name: 'IC-705'));

      expect(cat.canKeyCw, isFalse);
      cat.sendCw('CQ');

      expect(requests, isEmpty, reason: 'a device that keys nothing must not be asked to');
    });

    test('a local key chosen for that radio keys HERE, and the peer is not asked', () async {
      // A paddle and a rig can be in different rooms. The peer's own key is
      // only the DEFAULT, and an operator who picked a key of their own for
      // this radio picked it for a reason.
      final local = await connectPlaceholder(name: 'Bench Keyer');
      await followPeerRadio();
      await cat.setDesignated(kCategoryKey, local.uuid);

      cat.sendCw('CQ');

      expect(requests, isEmpty);
      expect(cat.cwProgress.value?.text, 'CQ', reason: 'the local keyer took it');
    });

    test('None means None, even though the peer would key', () async {
      // The trap: "nothing designated" is what makes the peer key, and an
      // explicit None looks like nothing designated to any check that reads
      // the value instead of asking whether one is stored.
      await followPeerRadio();
      await cat.setDesignated(kCategoryKey, null);

      expect(cat.canKeyCw, isFalse);
      cat.sendCw('CQ');

      expect(requests, isEmpty);
    });

    test('the strip shows the far side\'s message, its own timing included', () async {
      await followPeerRadio();

      cat.notePeerKeyStatus(
        pick.deviceId,
        const PeerKeyStatusPayload(
          radioId: 'rig-1',
          keyerSpeedWpm: 24,
          keyerSpeedMin: 5,
          keyerSpeedMax: 60,
          cw: PeerCwProgressPayload(
            id: 7,
            text: 'CQ',
            characterEndsMs: [200, 400],
            pending: ['TEST'],
            pendingIds: [8],
            sentCount: 1,
          ),
        ),
      );

      final progress = cat.cwProgress.value;
      expect(progress?.id, 7, reason: 'the far id is kept, so a re-report is not a fresh start');
      expect(progress?.text, 'CQ');
      expect(progress?.characterEnds, [const Duration(milliseconds: 200), const Duration(milliseconds: 400)]);
      expect(progress?.sentCount, 1, reason: 'a keyer that reports its own progress is not re-estimated');
      expect(cat.keyerSpeed, 24, reason: 'the speed shown is what that radio took');
      expect(cat.keyerSpeedRange, (min: 5, max: 60));
    });

    test('a status about another radio, or from another device, is dropped', () async {
      await followPeerRadio();

      cat.notePeerKeyStatus(pick.deviceId,
          const PeerKeyStatusPayload(radioId: 'rig-2', cw: PeerCwProgressPayload(id: 1, text: 'NOPE')));
      cat.notePeerKeyStatus('device-b',
          const PeerKeyStatusPayload(radioId: 'rig-1', cw: PeerCwProgressPayload(id: 2, text: 'NOPE')));

      expect(cat.cwProgress.value, isNull,
          reason: 'a device that offers radios hears its own controllers, and two writers fight');
    });

    test('a message ENDING over there is what starts the repeat wait here', () async {
      // The chain lives on the controller — it supplies the send — so the
      // only thing that can start its wait is the far side saying the
      // message is over.
      await followPeerRadio();
      cat.notePeerKeyStatus(pick.deviceId,
          const PeerKeyStatusPayload(radioId: 'rig-1', cw: PeerCwProgressPayload(id: 1, text: 'CQ')));
      cat.armKeyerRepeat(delay: const Duration(seconds: 3), text: 'CQ', send: () {});
      expect(cat.keyerRepeat.value, isNull, reason: 'still keying over there');

      cat.notePeerKeyStatus(pick.deviceId, const PeerKeyStatusPayload(radioId: 'rig-1'));

      expect(cat.keyerRepeat.value?.delay, const Duration(seconds: 3));
    });

    test('the memories are the far radio\'s, and so are their names and lengths', () async {
      await followPeerRadio();
      await settings.setVoiceMessageLabel(1, 'MY CQ');
      await settings.setVoiceMessageDuration(1, 9000);

      cat.notePeerKeyStatus(
        pick.deviceId,
        const PeerKeyStatusPayload(
          radioId: 'rig-1',
          voiceLabels: ['THEIR CQ', 'THEIR TU'],
          voiceDurationsMs: [4200, 1100],
        ),
      );

      expect(cat.canPlayVoice, isTrue);
      expect(cat.voiceMemoryCount, 4, reason: 'as many as that radio has');
      expect(cat.canRecordVoice, isTrue);
      expect(cat.voiceMessagesAreLocal, isFalse, reason: 'a label editor here would rename audio it is not about');
      expect(cat.voiceMessageLabel(1), 'THEIR CQ');
      expect(cat.voiceMessageDuration(1), 4200,
          reason: 'a length measured here would pace a bar against a different recording');
    });

    test('play, record and stop all address the peer', () async {
      await followPeerRadio();

      cat.playVoiceMemory(2, repeat: false);
      cat.recordVoiceMemory(3);
      cat.stopVoice();

      expect(requests.map((r) => (r.op, r.memory)), [
        (PeerKeyOp.voice, 2),
        (PeerKeyOp.record, 3),
        (PeerKeyOp.stopVoice, null),
      ]);
    });

    test('a radio that cannot record is not asked to', () async {
      await followPeerRadio(
          offer: const PeerRadioOffer(id: 'rig-1', name: 'IC-705', keysCw: true, voiceMemories: 4));

      expect(cat.canRecordVoice, isFalse);
      cat.recordVoiceMemory(1);

      expect(requests, isEmpty);
    });

    test('the Station dialog can ask for the keyer node while a peer keys', () async {
      // A peer's key is no node of this station, and nothing designated it —
      // so `keyInUse` is null while `designatedKeyIsKeyer` is true. A getter
      // that assumed the two agree throws while the compact Station dialog
      // is building.
      await followPeerRadio();

      expect(cat.designatedKeyIsKeyer, isTrue, reason: 'the keyer row is where the speed is reached');
      expect(cat.designatedKeyerNode, isNull);
    });

    test('a peer walking away leaves a LOCAL keyer\'s message on the strip', () async {
      // The scenario is the one above it: a peer radio drives the VFO and a
      // key of this operator's own keys for it. The peer leaving takes its
      // own keying away and nothing else — a strip blanked here is a
      // transmitter still keying with nothing on screen to stop it.
      final local = await connectPlaceholder(name: 'Bench Keyer');
      await followPeerRadio();
      await cat.setDesignated(kCategoryKey, local.uuid);
      cat.sendCw('CQ TEST');
      expect(cat.cwProgress.value?.text, 'CQ TEST');

      cat.forgetPeerRadios(pick.deviceId);

      expect(cat.cwProgress.value?.text, 'CQ TEST', reason: 'this keyer is still keying it');
    });

    test('re-picking the key that is keying does not abort the message', () async {
      // A dropdown reports the already-selected item being tapped, and the
      // key-in-use change hook stops whatever the outgoing key had going. The
      // radio here is its OWN key by default, so this tap is the first thing
      // ever stored for it — the one case an "unchanged value" early return
      // deliberately no longer catches, since None had to become storable.
      final local = await connectPlaceholder(name: 'Bench Rig');
      expect(cat.designatedFor(kCategoryKey), local.uuid, reason: 'the default, nothing chosen yet');
      cat.sendCw('CQ TEST');
      expect(cat.cwProgress.value?.text, 'CQ TEST');

      await cat.setDesignated(kCategoryKey, local.uuid);

      expect(cat.cwProgress.value?.text, 'CQ TEST');
    });

    test('picking a radio adopts what that device already said about it', () async {
      // Both the offer and the status are sent when the far station CHANGES,
      // and picking a radio is not the far station changing. Without a cache
      // the radio is unkeyable, the speed unknown and the memories unnamed
      // until it happens to key something — which mid-contest is the whole
      // feature missing.
      cat.noteOffer(pick.deviceId, pick.deviceName, [keyingOffer]);
      cat.notePeerKeyStatus(
        pick.deviceId,
        const PeerKeyStatusPayload(
          radioId: 'rig-1',
          keyerSpeedWpm: 26,
          keyerSpeedMin: 5,
          keyerSpeedMax: 60,
          voiceLabels: ['THEIR CQ'],
        ),
      );

      // Only now does the operator pick it.
      await cat.setRadio1(const PeerRadio(pick));

      expect(cat.canKeyCw, isTrue);
      expect(cat.keyerSpeed, 26);
      expect(cat.keyerSpeedRange, (min: 5, max: 60));
      expect(cat.voiceMessageLabel(1), 'THEIR CQ');
    });

    test('a message advancing does not notify every equipment row', () async {
      // What `cwProgress` is a notifier for at all: a WinKeyer echoes each
      // character, so a service-wide notification per status would rebuild
      // the whole Station panel per character.
      await followPeerRadio();
      var notifications = 0;
      cat.addListener(() => notifications++);

      for (var sent = 1; sent <= 4; sent++) {
        cat.notePeerKeyStatus(
          pick.deviceId,
          PeerKeyStatusPayload(
            radioId: 'rig-1',
            cw: PeerCwProgressPayload(id: 1, text: 'CQ TEST', sentCount: sent),
          ),
        );
      }

      expect(cat.cwProgress.value?.sentCount, 4, reason: 'the strip still follows every one');
      expect(notifications, 0, reason: 'nothing the rows read has moved');
    });

    test('moving the pick off a peer radio takes its keying off the strip', () async {
      // A message left over a radio nobody follows is bad enough. The voice
      // half is worse: `escapeClaimed` returns true while an activity is
      // shown, so an activity nothing can stop leaves Escape claimed and the
      // logging fields stop clearing for the rest of the session
      // (docs/design/logging-fields.md).
      await followPeerRadio();
      cat.notePeerKeyStatus(
        pick.deviceId,
        const PeerKeyStatusPayload(
          radioId: 'rig-1',
          cw: PeerCwProgressPayload(id: 1, text: 'CQ'),
          voice: PeerVoiceActivityPayload(memory: 1),
        ),
      );
      expect(cat.cwProgress.value, isNotNull);
      expect(cat.voiceActivity.value, isNotNull);

      await cat.setRadio1(null);

      expect(cat.cwProgress.value, isNull);
      expect(cat.voiceActivity.value, isNull, reason: 'nothing here could stop it, so nothing may show it');
    });

    test('a peer claiming more memories than the surfaces can draw is clamped', () async {
      // The buttons and the dialog rows index eight icons. A rig this build
      // has not met — or a garbled message — would throw inside build.
      await followPeerRadio(
          offer: const PeerRadioOffer(id: 'rig-1', name: 'Big Rig', keysCw: true, voiceMemories: 32));

      expect(cat.voiceMemoryCount, 8);
    });

    test('a voice chain still ends at the five-minute limit', () async {
      // The limit is the chain's, and a cancel drops the deadline: cancelling
      // before re-arming each repeat restarted it, so an unattended CQ keyed
      // forever — over the link, somebody else's transmitter.
      await followPeerRadio();
      await settings.setVoiceRepeatDelay(5);

      cat.playVoiceMemory(1);
      expect(cat.keyerRepeating, isTrue);
      final first = cat.keyerRepeatDeadlineMillis;
      expect(first, isNotNull);

      cat.playVoiceMemory(1);
      cat.playVoiceMemory(1);

      expect(cat.keyerRepeatDeadlineMillis, first,
          reason: 'five minutes from the FIRST send, not five from each repeat');

      // And a memory that is NOT the chain's still ends it.
      cat.playVoiceMemory(3);
      expect(cat.keyerRepeating, isFalse);
    });

    test('a rig that drops and comes back does not bring its old message with it', () async {
      // The status goes with the offer. Kept, it is re-adopted when the rig
      // returns: a phantom message over a quiet transmitter, and a phantom
      // activity holding Escape — with nothing to clear it until that station
      // next keys.
      await followPeerRadio();
      cat.notePeerKeyStatus(
        pick.deviceId,
        const PeerKeyStatusPayload(
          radioId: 'rig-1',
          cw: PeerCwProgressPayload(id: 1, text: 'CQ'),
          voice: PeerVoiceActivityPayload(memory: 1),
        ),
      );

      // The far rig's link drops — an empty offer is how that is said — and
      // then comes back.
      cat.noteOffer(pick.deviceId, pick.deviceName, const []);
      expect(cat.cwProgress.value, isNull);
      cat.noteOffer(pick.deviceId, pick.deviceName, [keyingOffer]);

      expect(cat.cwProgress.value, isNull, reason: 'it stopped keying when it went');
      expect(cat.voiceActivity.value, isNull);
    });

    test('a peer walking away mid-chain does not leave the repeat armed', () async {
      // The chain waits on the far side reporting the end, which can no longer
      // arrive: latched, the strip says a chain is running with nothing
      // playing — and if that peer returns inside the five minutes its first
      // idle status keys its transmitter again.
      await followPeerRadio();
      await settings.setVoiceRepeatDelay(5);
      cat.playVoiceMemory(1);
      expect(cat.keyerRepeating, isTrue);

      cat.forgetPeerRadios(pick.deviceId);

      expect(cat.keyerRepeating, isFalse);
    });

    test('nothing is armed when the request reached no bridge', () async {
      // The buttons are live off the last offer heard, so M1 can be pressed
      // with no router under it. A chain armed there waits for an end nothing
      // will ever report.
      await followPeerRadio();
      await settings.setVoiceRepeatDelay(5);
      cat.sendPeerKeyRequest = null;

      cat.playVoiceMemory(1);

      expect(cat.keyerRepeating, isFalse);
    });

    test('the peer walking away leaves the surfaces quiet, and the pick standing', () async {
      await followPeerRadio();
      cat.notePeerKeyStatus(pick.deviceId,
          const PeerKeyStatusPayload(radioId: 'rig-1', cw: PeerCwProgressPayload(id: 1, text: 'CQ')));

      cat.forgetPeerRadios(pick.deviceId);

      expect(cat.canKeyCw, isFalse);
      expect(cat.canPlayVoice, isFalse);
      expect(cat.cwProgress.value, isNull, reason: 'a strip over a device that is not there is a lie');
      expect(cat.radio1, const PeerRadio(pick), reason: 're-engages by itself when the peer returns');
      cat.sendCw('CQ');
      expect(requests, isEmpty);
    });

    test('an offer that stops naming the picked radio withdraws its keying', () async {
      await followPeerRadio();
      expect(cat.canKeyCw, isTrue);

      // That rig's link went down over there — the offer is how a station
      // says so, and an EMPTY one is a real answer.
      cat.noteOffer(pick.deviceId, pick.deviceName, const []);

      expect(cat.canKeyCw, isFalse);
      expect(cat.canPlayVoice, isFalse);
    });

    test('nothing is sent when no bridge is up', () async {
      // A build with peer sharing off constructs no router, so nothing sets
      // the slot. The surfaces are live off the last offer heard, and the
      // requests must go nowhere rather than into a silent void that looks
      // like keying.
      await followPeerRadio();
      cat.sendPeerKeyRequest = null;

      cat.sendCw('CQ');
      cat.playVoiceMemory(1, repeat: false);

      expect(requests, isEmpty);
      expect(cat.setKeyerSpeed(22), isFalse, reason: 'the WPM command says so rather than confirming');
    });
  });

  group('as the offerer', () {
    test('what it offers says whether it will key, and what memories it has', () async {
      final node = await connectPlaceholder();

      final offer = cat.offeredRadios.single;
      expect(offer.id, node.uuid);
      expect(offer.keysCw, isTrue, reason: 'the placeholder radio is its own key by default');
      expect(offer.voiceMemories, greaterThan(0));
    });

    test('a station keying through a PEER offers its own radios as unkeyable', () async {
      // The trap: `canKeyCw` is true on this device — over the link — and
      // offering that would advertise a relay nothing implements, keying a
      // transmitter two devices away for an operator who picked neither.
      await connectPlaceholder();
      await followPeerRadio();
      await cat.setDesignated(kCategoryKey, null);
      expect(cat.canKeyCw, isFalse);
      await cat.setDesignated(kCategoryKey, cat.nodes.first.uuid);
      expect(cat.canKeyCw, isTrue);

      // Now point the key at the peer's radio: this station keys nothing.
      await cat.setDesignated(kCategoryKey, peerRadioValue(pick));

      expect(cat.canKeyCw, isTrue, reason: 'over the link');
      expect(cat.offeredRadios.single.keysCw, isFalse, reason: 'but not with anything of its own');
    });

    test('a request keys the station, and its progress is what a controller reads', () async {
      final node = await connectPlaceholder();

      cat.handleKeyRequest(PeerKeyRequestPayload(radioId: node.uuid, op: PeerKeyOp.cw, text: 'CQ'));

      final status = cat.keyStatusForOfferedRadio(node.uuid);
      expect(status?.cw?.text, 'CQ');
      expect(status?.cw?.characterEndsMs, isNotEmpty, reason: 'the far strip paces on this station\'s own timing');
    });

    test('a request for a radio it does not offer keys nothing', () async {
      final node = await connectPlaceholder();

      cat.handleKeyRequest(PeerKeyRequestPayload(radioId: 'not-ours', op: PeerKeyOp.cw, text: 'CQ'));

      expect(cat.keyStatusForOfferedRadio(node.uuid)?.cw, isNull);
      expect(cat.cwProgress.value, isNull);
    });

    test('a request is never relayed onward to the radio THIS device follows', () async {
      // Two hops is a transmitter nobody pointed at: the operator who asked
      // picked this station's rig, not whatever this station is following.
      final node = await connectPlaceholder();
      await followPeerRadio();

      cat.handleKeyRequest(PeerKeyRequestPayload(radioId: node.uuid, op: PeerKeyOp.cw, text: 'CQ'));

      expect(requests, isEmpty);
    });

    test('a speed request moves the station\'s keyer, and is reported back', () async {
      final node = await connectPlaceholder();

      cat.handleKeyRequest(PeerKeyRequestPayload(radioId: node.uuid, op: PeerKeyOp.wpm, wpm: 27));
      await pumpEventQueue();

      expect(cat.keyStatusForOfferedRadio(node.uuid)?.keyerSpeedWpm, 27);
    });

    test('a memory plays on the radio the request names', () async {
      final node = await connectPlaceholder();

      cat.handleKeyRequest(PeerKeyRequestPayload(radioId: node.uuid, op: PeerKeyOp.voice, memory: 2));
      await pumpEventQueue();

      expect(cat.keyStatusForOfferedRadio(node.uuid)?.voice?.memory, 2);
      expect(cat.voiceActivity.value?.memory, 2, reason: 'radio1 here, so this station sees it too');
    });

    test('a peer\'s play arms no chain of this operator\'s', () async {
      // The chain belongs to whoever pressed the key, on their own device —
      // and a repeat armed here would key this station's transmitter after
      // the asker had stopped.
      final node = await connectPlaceholder();
      await settings.setVoiceRepeatDelay(5);

      cat.handleKeyRequest(PeerKeyRequestPayload(radioId: node.uuid, op: PeerKeyOp.voice, memory: 1));

      expect(cat.keyerRepeating, isFalse);
    });

    test('a station with keying switched off offers nothing keyable, and keys nothing', () async {
      // Its operator has no keyer area and no Escape handler, so nothing here
      // could stop a message a peer started.
      final node = await connectPlaceholder();
      await settings.setExperimentEnabled('keyer', false);

      final offer = cat.offeredRadios.single;
      expect(offer.keysCw, isFalse);
      expect(offer.voiceMemories, 0);
      expect(offer.recordsVoice, isFalse);

      // And a controller holding the older offer is refused: the experiment
      // can go off under an established session.
      cat.handleKeyRequest(PeerKeyRequestPayload(radioId: node.uuid, op: PeerKeyOp.cw, text: 'CQ'));
      expect(cat.cwProgress.value, isNull);
    });

    test('what it publishes is its OWN keying, never what it is following', () async {
      // A station can offer a rig while its own radio1 is a third device's.
      // Publishing that device's message as this radio's status would be the
      // relay this design forbids, one report instead of one request.
      final node = await connectPlaceholder();
      await followPeerRadio();
      cat.notePeerKeyStatus(
        pick.deviceId,
        const PeerKeyStatusPayload(
          radioId: 'rig-1',
          keyerSpeedWpm: 31,
          keyerSpeedMin: 5,
          keyerSpeedMax: 60,
          cw: PeerCwProgressPayload(id: 5, text: 'NOT MINE'),
        ),
      );

      final status = cat.keyStatusForOfferedRadio(node.uuid);
      expect(status?.cw, isNull);
      expect(status?.keyerSpeedWpm, isNot(31));
      // The RANGE too: it is the one field that had its own accessor and went
      // on being read through the effective getter.
      expect(status?.keyerSpeedMin, isNot(5));
      expect(status?.keyerSpeedMax, isNot(60));
    });

    test('a peer\'s stop ends what this station had going, chain included', () async {
      // The transmitter is shared: a stop that left an unattended CQ
      // re-keying it five seconds later is worse than a message cut short.
      // Both keyers answer the same way — a voice stop that spared the chain
      // would replay memory 1 over the silence somebody asked for.
      final node = await connectPlaceholder();
      cat.armKeyerRepeat(delay: const Duration(seconds: 5), text: 'CQ', send: () {});
      expect(cat.keyerRepeating, isTrue);

      cat.handleKeyRequest(PeerKeyRequestPayload(radioId: node.uuid, op: PeerKeyOp.stopCw));
      expect(cat.keyerRepeating, isFalse);

      cat.armKeyerRepeat(delay: const Duration(seconds: 5), text: '', memory: 1, send: () {});
      cat.handleKeyRequest(PeerKeyRequestPayload(radioId: node.uuid, op: PeerKeyOp.stopVoice));
      expect(cat.keyerRepeating, isFalse);
    });

    test('the labels it reports are its own, and only as many as the radio has', () async {
      final node = await connectPlaceholder();
      await settings.setVoiceMessageLabel(1, 'MY CQ');

      final status = cat.keyStatusForOfferedRadio(node.uuid);
      expect(status?.voiceLabels.first, 'MY CQ');
      expect(status?.voiceLabels.length, cat.voiceMemoryCount,
          reason: 'a label for a ninth memory is a label for a button nobody is shown');
    });
  });
}
