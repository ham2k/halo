// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The repeat engine, which serves both keyers: message 1 goes again after a
// wait, the wait is what the keyer area counts down, and every way an
// operator comes back to the radio ends the chain. Against the placeholder
// radio, whose pretend playback ends on its own — so a voice chain's own
// end is a session's report rather than a hand-built one.
//
// The CW half is driven through CatService directly rather than through the
// operation view: what arms a chain there is a rendered template, and the
// rule under test is the ENGINE's — when a wait starts, when the next send
// goes, and what stops it.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:ham2k_logger/services/cat/keyer_repeat.dart';
import 'package:ham2k_logger/services/cat/drivers/placeholder_radio_driver.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';

import '../support/fake_clock.dart';
import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoServices services;
  late CatService cat;

  setUp(() async {
    final harness = await makeHaLoServices();
    final settings = harness.settings;
    services = harness.services;
    cat = services.cat;
    await settings.setExperimentEnabled('keyer', true);
  });

  Future<void> connectPlaceholder() async {
    final node = await cat.addNode(typeKey: 'placeholder-radio', name: 'Bench Rig', config: placeholderRadioModel.variants.single.defaultConfig);
    await cat.connect(node.uuid);
    addTearDown(() => cat.disconnect(node.uuid));
  }

  group('CW', () {
    test(
      'the wait starts when the message ENDS, and the next send follows it',
      () => runOnFakeClock((_) async {
        await connectPlaceholder();
        var sends = 0;
        cat.sendCw('E');
        cat.armKeyerRepeat(delay: const Duration(seconds: 3), text: 'CQ', send: () => sends++);
        expect(cat.keyerRepeating, isTrue);
        expect(cat.keyerRepeat.value, isNull, reason: 'the message is still keying; nothing is waiting yet');

        // The queue reports null when it drains, which is the ONLY thing that
        // starts a wait: a chain timed from the keypress would key over the
        // message it just sent.
        await pumpEventQueue();
        await Future<void>.delayed(const Duration(seconds: 1));
        expect(cat.keyerRepeat.value?.delay, const Duration(seconds: 3));
        expect(cat.keyerRepeat.value?.text, 'CQ');
        expect(sends, 0);

        await Future<void>.delayed(const Duration(seconds: 3, milliseconds: 200));
        expect(sends, 1);
        expect(cat.keyerRepeat.value, isNull, reason: 'the wait is over; the message is going again');
      }),
    );

    test(
      'a stop ends the chain, and so does an explicit cancel',
      () => runOnFakeClock((_) async {
        await connectPlaceholder();
        cat.armKeyerRepeat(delay: const Duration(seconds: 2), text: 'CQ', send: () {});
        expect(cat.keyerRepeating, isTrue);
        cat.stopCw();
        expect(cat.keyerRepeating, isFalse);
        expect(cat.keyerRepeatActive.value, isFalse);

        cat.armKeyerRepeat(delay: const Duration(seconds: 2), text: 'CQ', send: () {});
        cat.cancelKeyerRepeat();
        expect(cat.keyerRepeating, isFalse);
      }),
    );

    test(
      'keyerRepeatActive is a NOTIFIER, because the strip has to rebuild on the gap',
      () => runOnFakeClock((_) async {
        // The gap between a wait ending and the next message reaching the
        // radio is a template render long. The keyer area hides its buttons
        // for the whole chain rather than only the wait — a getter would
        // notify nobody, and the buttons would flash back mid-chain.
        final seen = <bool>[];
        cat.keyerRepeatActive.addListener(() => seen.add(cat.keyerRepeatActive.value));
        cat.armKeyerRepeat(delay: const Duration(seconds: 2), text: 'CQ', send: () {});
        cat.cancelKeyerRepeat();
        expect(seen, [true, false]);
      }),
    );

    test(
      're-arming inside a chain does not start a new one',
      () => runOnFakeClock((_) async {
        // The five-minute deadline is the chain's, not each repeat's — a
        // repeat that pushed it further away is a CQ that never stops. Its
        // expiry has a test of its own below; this one is that a re-arm
        // leaves the wait it inherited alone.
        expect(keyerRepeatLimit, const Duration(minutes: 5));
        await connectPlaceholder();
        cat.sendCw('E');
        cat.armKeyerRepeat(delay: const Duration(seconds: 4), text: 'CQ', send: () {});
        await pumpEventQueue();
        await Future<void>.delayed(const Duration(seconds: 1));
        final wait = cat.keyerRepeat.value;
        expect(wait, isNotNull, reason: 'the message drained, so a wait is running');

        cat.armKeyerRepeat(delay: const Duration(seconds: 4), text: 'CQ', send: () {});
        expect(cat.keyerRepeatActive.value, isTrue);
        expect(cat.keyerRepeat.value, isNull, reason: 'the new send is what the next wait times from');
        cat.cancelKeyerRepeat();
      }),
    );
  });

  // A CQ left repeating while the operator walked away would key the radio
  // for the rest of the session. The deadline reads the real clock, which
  // the fake one drives here (docs/design/time.md §7).
  test(
    'a CW chain stops five minutes after its first send, however many repeats fit',
    () => runOnFakeClock((_) async {
      await connectPlaceholder();
      var sends = 0;
      void repeat() {
        sends++;
        cat.sendCw('E');
        cat.armKeyerRepeat(delay: const Duration(seconds: 30), text: 'CQ', send: repeat);
      }

      cat.sendCw('E');
      cat.armKeyerRepeat(delay: const Duration(seconds: 30), text: 'CQ', send: repeat);
      await Future<void>.delayed(keyerRepeatLimit - const Duration(seconds: 15));
      expect(cat.keyerRepeating, isTrue);
      expect(sends, greaterThan(5), reason: 'the chain was repeating all along');
      final sent = sends;

      await Future<void>.delayed(const Duration(minutes: 1));
      expect(cat.keyerRepeating, isFalse);
      expect(sends, sent, reason: 'the repeat due after the deadline never went');
    }),
  );

  group('voice sequence', () {
    // Enter Sends Messages' voice steps (docs/design/logging-fields.md § Enter
    // Sends Messages): one memory after another, and a stop is the end of
    // all of them. The placeholder radio plays each for four real seconds.
    test(
      'the next memory plays when the one on the air ends',
      () => runOnFakeClock((_) async {
        await connectPlaceholder();
        cat.playVoiceSequence([2, 3]);
        await pumpEventQueue();
        expect(cat.voiceActivity.value?.memory, 2);
        await Future<void>.delayed(placeholderVoicePlayDuration + const Duration(milliseconds: 300));
        expect(cat.voiceActivity.value?.memory, 3);
        cat.stopVoice();
      }),
    );

    test(
      'a stop partway through keeps the rest off the air',
      () => runOnFakeClock((_) async {
        // Cutting the exchange short must not leave the thanks queued behind
        // it — the stop here is the keyer area's, which no keypress passes.
        await connectPlaceholder();
        cat.playVoiceSequence([2, 3]);
        await pumpEventQueue();
        cat.stopVoice();
        // Well inside the next memory's length: waiting past it would find a
        // wrongly played thanks already over.
        await Future<void>.delayed(const Duration(milliseconds: 500));
        expect(cat.voiceActivity.value, isNull);
      }),
    );
  });

  group('a callsign typed over message 1', () {
    // CatService.stopMessageOne, which the logging panel calls on every
    // operator edit of the callsign field. Only message 1 goes, with any
    // chain holding it: an exchange or a TU keying while the operator
    // corrects the call is the contact being worked, and stopping it would
    // cut the answer short.
    const long = 'CQ CQ TEST N0DEV N0DEV TEST';

    test(
      'stops a CW message 1 and its chain',
      () => runOnFakeClock((_) async {
        await connectPlaceholder();
        cat.sendCw(long, hasMessageOne: true);
        cat.armKeyerRepeat(delay: const Duration(seconds: 3), text: long, send: () {});
        expect(cat.cwSending, isTrue);

        cat.stopMessageOne();
        expect(cat.cwSending, isFalse);
        expect(cat.keyerRepeating, isFalse);
      }),
    );

    test(
      'leaves any other CW message keying',
      () => runOnFakeClock((_) async {
        await connectPlaceholder();
        cat.sendCw(long);
        cat.stopMessageOne();
        expect(cat.cwSending, isTrue, reason: 'an exchange is the contact, not a CQ');
        cat.stopCw();
      }),
    );

    test(
      'a newer send than the CQ is not the CQ',
      () => runOnFakeClock((_) async {
        // The queue carries no message numbers, so what is on the air is read
        // off the NEWEST send — a message 2 behind the CQ makes it not a CQ.
        await connectPlaceholder();
        cat.sendCw(long, hasMessageOne: true);
        cat.sendCw(long);
        cat.stopMessageOne();
        expect(cat.cwSending, isTrue);
        cat.stopCw();
      }),
    );

    test(
      'stops voice memory 1, and leaves any other memory playing',
      () => runOnFakeClock((_) async {
        await connectPlaceholder();
        cat.playVoiceMemory(2);
        await pumpEventQueue();
        cat.stopMessageOne();
        expect(cat.voiceActivity.value?.memory, 2);
        cat.stopVoice();
        await pumpEventQueue();

        await services.settings.setVoiceRepeatDelay(3);
        cat.playVoiceMemory(1);
        await pumpEventQueue();
        expect(cat.keyerRepeating, isTrue);
        cat.stopMessageOne();
        await pumpEventQueue();
        expect(cat.voiceActivity.value, isNull);
        expect(cat.keyerRepeating, isFalse);
      }),
    );

    test(
      'a voice chain holding memory 1 stops whole, whichever memory is playing',
      () => runOnFakeClock((_) async {
        // CW keys a chain as one message the queue cannot split, so voice
        // stops a chain holding memory 1 whole too, and the two keyers answer
        // a typed call alike.
        await connectPlaceholder();
        cat.playVoiceSequence([3, 1]);
        await pumpEventQueue();
        expect(cat.voiceActivity.value?.memory, 3);
        cat.stopMessageOne();
        await pumpEventQueue();
        expect(cat.voiceActivity.value, isNull);
        await Future<void>.delayed(placeholderVoicePlayDuration + const Duration(milliseconds: 300));
        expect(cat.voiceActivity.value, isNull, reason: 'and the CQ never starts');
      }),
    );

    test(
      'a voice chain WITHOUT memory 1 plays on',
      () => runOnFakeClock((_) async {
        await connectPlaceholder();
        cat.playVoiceSequence([2, 3]);
        await pumpEventQueue();
        cat.stopMessageOne();
        await Future<void>.delayed(placeholderVoicePlayDuration + const Duration(milliseconds: 300));
        expect(cat.voiceActivity.value?.memory, 3, reason: 'the exchange and its thanks are the contact');
        cat.stopVoice();
      }),
    );

    test(
      'a finished chain with memory 1 does not make the next memory one',
      () => runOnFakeClock((_) async {
        // The chain's memory-1 mark lasts until its LAST memory ends, and no
        // longer — a memory 2 played by hand afterwards is only an exchange.
        await connectPlaceholder();
        cat.playVoiceSequence([1]);
        await pumpEventQueue();
        await Future<void>.delayed(placeholderVoicePlayDuration + const Duration(milliseconds: 300));
        expect(cat.voiceActivity.value, isNull);
        cat.playVoiceMemory(2);
        await pumpEventQueue();
        cat.stopMessageOne();
        expect(cat.voiceActivity.value?.memory, 2);
        cat.stopVoice();
      }),
    );
  });

  group('Escape', () {
    // CatService.stopKeying: every message, chain and repeat, whatever it
    // holds — and false with nothing to stop, which is what leaves Escape
    // its usual meaning in the logging fields.
    test(
      'stops any CW message',
      () => runOnFakeClock((_) async {
        await connectPlaceholder();
        cat.sendCw('CQ CQ TEST N0DEV N0DEV TEST');
        expect(cat.stopKeying(), isTrue);
        expect(cat.cwSending, isFalse);
      }),
    );

    test(
      'ends a repeat while it waits, with nothing on the air',
      () => runOnFakeClock((_) async {
        // A keypress ends no chain on its own, so a wait Escape left running
        // would bring the CQ back with nothing to stop it.
        await connectPlaceholder();
        cat.sendCw('E');
        cat.armKeyerRepeat(delay: const Duration(seconds: 3), text: 'CQ', send: () {});
        await pumpEventQueue();
        await Future<void>.delayed(const Duration(seconds: 1));
        expect(cat.keyerRepeat.value, isNotNull, reason: 'waiting, not keying');
        expect(cat.stopKeying(), isTrue);
        expect(cat.keyerRepeating, isFalse);
      }),
    );

    test(
      'stops any voice memory and its chain',
      () => runOnFakeClock((_) async {
        await connectPlaceholder();
        cat.playVoiceSequence([2, 3]);
        await pumpEventQueue();
        expect(cat.stopKeying(), isTrue);
        await Future<void>.delayed(placeholderVoicePlayDuration + const Duration(milliseconds: 300));
        expect(cat.voiceActivity.value, isNull);
      }),
    );

    test(
      'is not claimed with nothing to stop',
      () => runOnFakeClock((_) async {
        await connectPlaceholder();
        expect(cat.stopKeying(), isFalse);
      }),
    );
  });

  group('voice', () {
    test(
      'memory 1 repeats when the setting says so; the rest end a chain',
      () => runOnFakeClock((_) async {
        await connectPlaceholder();
        await services.settings.setVoiceRepeatDelay(3);

        cat.playVoiceMemory(1);
        expect(cat.keyerRepeating, isTrue);
        expect(cat.keyerRepeat.value, isNull, reason: 'the memory is playing; nothing is waiting yet');

        // Any OTHER memory is the operator moving on to the exchange.
        cat.playVoiceMemory(2);
        expect(cat.keyerRepeating, isFalse);
        cat.stopVoice();
      }),
    );

    test(
      'only memory 1, and only with a delay set',
      () => runOnFakeClock((_) async {
        await connectPlaceholder();
        cat.playVoiceMemory(1);
        expect(cat.keyerRepeating, isFalse, reason: 'no delay set: nothing repeats');
        cat.stopVoice();
      }),
    );

    test(
      'the editor auditions a memory: Play there never starts a chain',
      () => runOnFakeClock((_) async {
        await connectPlaceholder();
        await services.settings.setVoiceRepeatDelay(3);
        // A CQ that started repeating from inside a settings dialog would be
        // one nobody was watching the air for.
        cat.playVoiceMemory(1, repeat: false);
        expect(cat.keyerRepeating, isFalse);
        cat.stopVoice();
      }),
    );

    test(
      'the wait carries the MEMORY, so the strip names it by its own label',
      () => runOnFakeClock((_) async {
        await connectPlaceholder();
        await services.settings.setVoiceRepeatDelay(2);
        cat.playVoiceMemory(1);
        // The placeholder's pretend playback ends on its own, which is what
        // starts the wait — the voice counterpart of the CW queue draining.
        await Future<void>.delayed(placeholderVoicePlayDuration + const Duration(milliseconds: 300));
        expect(cat.keyerRepeat.value?.memory, 1);
        expect(cat.keyerRepeat.value?.text, isEmpty, reason: 'audio has no text; the label is resolved where it is shown');
        cat.cancelKeyerRepeat();
        cat.stopVoice();
      }),
    );

    test(
      'a stop ends a voice chain the same way it ends a CW one',
      () => runOnFakeClock((_) async {
        await connectPlaceholder();
        await services.settings.setVoiceRepeatDelay(3);
        cat.playVoiceMemory(1);
        expect(cat.keyerRepeating, isTrue);
        cat.stopVoice();
        expect(cat.keyerRepeating, isFalse);
      }),
    );
  });
}
