// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The FYI area's SWR message (docs/design/logging-fields.md § The FYI
// area), read off the average CAT keeps per transmission — against real
// placeholder rigs, whose SWR is what they are configured with, keyed
// through the real send queue.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/cat/main_vfo.dart';
import 'package:ham2k_logger/services/cat/swr_watch.dart';
import 'package:ham2k_logger/services/fyi_service.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoServices services;

  setUp(() async {
    final harness = await makeHaLoServices();
    services = harness.services;
    await harness.settings.setExperimentEnabled('keyer', true);
    services.swrWatch.start();
    addTearDown(services.swrWatch.dispose);
  });

  Future<String> rig(String name, num swr) async {
    final node = await services.cat.addNode(
      typeKey: 'placeholder-radio',
      name: name,
      config: {...placeholderRadioModel.variants.single.defaultConfig, 'placeholderSwr': swr},
    );
    await services.cat.connect(node.uuid);
    addTearDown(() => services.cat.disconnect(node.uuid));
    return node.uuid;
  }

  /// Keys a short message on [radio]'s keyer — the rig at [uuid] — and
  /// waits until the rig has been on the air and is off it again.
  Future<void> key(String radio, String uuid) async {
    expect(services.cat.keyer(radio).sendCw('E'), isTrue, reason: 'sanity: it keys');
    bool onAir() => services.cat.stateFor(uuid).telemetry.transmitting == true;
    var wasOn = false;
    for (var i = 0; i < 150 && !(wasOn && !onAir()); i++) {
      if (onAir()) wasOn = true;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(wasOn, isTrue, reason: 'sanity: it went on the air');
    expect(onAir(), isFalse, reason: 'sanity: it ended');
  }

  FyiMessage? swrFor(String radio) => services.fyi.messageFor(SwrWatch.keyFor(radio));

  test('a transmission into a bad match alerts, a middling one warns, and a good one takes the message down', () async {
    await services.settings.setExperimentEnabled('so2r', true);
    // All three before any is designated: the newest transceiver added takes
    // the Main VFO, and Radio B refuses the rig that is radio1.
    final bad = await rig('Bad', 2.4);
    final middling = await rig('Middling', 1.7);
    final good = await rig('Good', 1.2);
    await services.cat.setRadio1(LocalRadio(bad));
    await services.cat.setRadio2(middling);
    expect(swrFor('A'), isNull, reason: 'nothing has transmitted yet');

    await key('A', bad);
    final alert = swrFor('A');
    expect(alert?.category, FyiCategory.alert);
    expect(alert?.text, 'High SWR 2.4');
    expect(alert?.radio, 'A', reason: "radio A's trouble, in set A's area");
    expect(services.fyi.messagesFor('B'), isEmpty);

    await key('B', middling);
    final warning = swrFor('B');
    expect(warning?.category, FyiCategory.warning);
    expect(warning?.text, 'SWR 1.7');
    expect(swrFor('A')?.category, FyiCategory.alert, reason: 'each radio under its own key');

    // The trap: a message that outlives the radio it was about.
    await services.cat.setRadio1(LocalRadio(good));
    expect(swrFor('A'), isNull, reason: 'what the old rig read says nothing about the new one');
    await key('A', good);
    expect(swrFor('A'), isNull, reason: 'a match under the warning has nothing to say');
  });

  test('the message stands between transmissions, and through the start of the next one', () async {
    final bad = await rig('Bad', 2.4);
    await services.cat.setRadio1(LocalRadio(bad));
    await key('A', bad);
    expect(swrFor('A'), isNotNull);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(swrFor('A'), isNotNull, reason: 'the last transmission is what the operator has to go on');
    // Key-down before a reading: the message must not blink out.
    var blinked = false;
    void watch() {
      if (swrFor('A') == null) blinked = true;
    }

    services.fyi.addListener(watch);
    await key('A', bad);
    services.fyi.removeListener(watch);
    expect(blinked, isFalse, reason: 'a transmission just begun has no reading yet, and what the last one said stands');
    expect(swrFor('A')?.category, FyiCategory.alert);
  });

  test("the operator's dismissal holds the message down while the reading persists", () async {
    final bad = await rig('Bad', 2.4);
    await services.cat.setRadio1(LocalRadio(bad));
    await key('A', bad);
    services.fyi.dismiss(SwrWatch.keyFor('A'));
    await key('A', bad);
    expect(swrFor('A'), isNull, reason: 'the same alert on the next over is the nag the dismissal was for');
  });

  test('removing the radio takes its message with it', () async {
    final bad = await rig('Bad', 2.4);
    await services.cat.setRadio1(LocalRadio(bad));
    await key('A', bad);
    expect(swrFor('A'), isNotNull, reason: 'sanity');
    await services.cat.removeNode(bad);
    // The trap: a role with no radio skipped over, leaving an alert about a
    // rig that is gone standing with nothing to ever take it down.
    expect(swrFor('A'), isNull);
  });
}
