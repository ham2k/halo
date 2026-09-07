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
import 'package:ham2k_logger/services/cat/drivers/placeholder_radio_driver.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';

import 'support/halo_test_support.dart';

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
    final node = await cat.addNode(
      typeKey: 'placeholder-radio',
      name: 'Bench Rig',
      config: placeholderRadioModel.variants.single.defaultConfig,
    );
    await cat.connect(node.uuid);
    addTearDown(() => cat.disconnect(node.uuid));
  }

  group('CW', () {
    test('the wait starts when the message ENDS, and the next send follows it', () async {
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
    });

    test('a stop ends the chain, and so does an explicit cancel', () async {
      await connectPlaceholder();
      cat.armKeyerRepeat(delay: const Duration(seconds: 2), text: 'CQ', send: () {});
      expect(cat.keyerRepeating, isTrue);
      cat.stopCw();
      expect(cat.keyerRepeating, isFalse);
      expect(cat.keyerRepeatActive.value, isFalse);

      cat.armKeyerRepeat(delay: const Duration(seconds: 2), text: 'CQ', send: () {});
      cat.cancelKeyerRepeat();
      expect(cat.keyerRepeating, isFalse);
    });

    test('keyerRepeatActive is a NOTIFIER, because the strip has to rebuild on the gap', () async {
      // The gap between a wait ending and the next message reaching the
      // radio is a template render long. The keyer area hides its buttons
      // for the whole chain rather than only the wait — a getter would
      // notify nobody, and the buttons would flash back mid-chain.
      final seen = <bool>[];
      cat.keyerRepeatActive.addListener(() => seen.add(cat.keyerRepeatActive.value));
      cat.armKeyerRepeat(delay: const Duration(seconds: 2), text: 'CQ', send: () {});
      cat.cancelKeyerRepeat();
      expect(seen, [true, false]);
    });

    test('re-arming inside a chain does not start a new one', () async {
      // The five-minute deadline is the chain's, not each repeat's — a
      // repeat that pushed it further away is a CQ that never stops. Its
      // EXPIRY is not exercised here on purpose: the deadline is read from
      // the real clock (docs/design/time.md), so elapsing fake timers past
      // it would pass while testing nothing. What is testable is that a
      // re-arm leaves the wait it inherited alone.
      expect(CatService.keyerRepeatLimit, const Duration(minutes: 5));
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
    });
  });

  group('voice', () {
    test('memory 1 repeats when the setting says so; the rest end a chain', () async {
      await connectPlaceholder();
      await services.settings.setVoiceRepeatDelay(3);

      cat.playVoiceMemory(1);
      expect(cat.keyerRepeating, isTrue);
      expect(cat.keyerRepeat.value, isNull, reason: 'the memory is playing; nothing is waiting yet');

      // Any OTHER memory is the operator moving on to the exchange.
      cat.playVoiceMemory(2);
      expect(cat.keyerRepeating, isFalse);
      cat.stopVoice();
    });

    test('only memory 1, and only with a delay set', () async {
      await connectPlaceholder();
      cat.playVoiceMemory(1);
      expect(cat.keyerRepeating, isFalse, reason: 'no delay set: nothing repeats');
      cat.stopVoice();
    });

    test('the editor auditions a memory: Play there never starts a chain', () async {
      await connectPlaceholder();
      await services.settings.setVoiceRepeatDelay(3);
      // A CQ that started repeating from inside a settings dialog would be
      // one nobody was watching the air for.
      cat.playVoiceMemory(1, repeat: false);
      expect(cat.keyerRepeating, isFalse);
      cat.stopVoice();
    });

    test('the wait carries the MEMORY, so the strip names it by its own label', () async {
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
    });

    test('a stop ends a voice chain the same way it ends a CW one', () async {
      await connectPlaceholder();
      await services.settings.setVoiceRepeatDelay(3);
      cat.playVoiceMemory(1);
      expect(cat.keyerRepeating, isTrue);
      cat.stopVoice();
      expect(cat.keyerRepeating, isFalse);
    });
  });
}
