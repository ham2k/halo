// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The operating style against a rig on the air (docs/design/logging-fields.md
// § Operating style): working split, a rig reports where it sends while it
// transmits, which is no QSY and no run frequency. A real placeholder rig,
// keyed through the real send queue.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/radio_service.dart' show VfoOrigin;
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/cat/operating_style.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The trap: Run stored from an earlier session, tracking then started by
  // the first message keyed in a new operation — an answer to a CQ — would
  // record every contact after it as Run.
  test('keying a message starts tracking in S&P, and message 1 makes it Run', () async {
    final services = (await makeHaLoServices()).services;
    final cat = services.cat;
    final node = await cat.addNode(typeKey: 'placeholder-radio', name: 'Bench Rig', config: placeholderRadioModel.variants.single.defaultConfig);
    await cat.connect(node.uuid);
    addTearDown(() => cat.disconnect(node.uuid));
    cat.setRunning('A', true);
    services.openOperationContext('op');
    expect(cat.tracksStyle, isFalse, reason: 'sanity: nothing keyed here yet');

    expect(cat.keyer('A').sendCw('5NN TU'), isTrue);
    expect((cat.tracksStyle, cat.styleOf('A')), (true, OperatingStyle.normal));
    cat.stopCw();
    expect(cat.keyer('A').sendCw('CQ TEST', hasMessageOne: true), isTrue);
    expect(cat.styleOf('A'), OperatingStyle.run);
    cat.stopCw();
  });

  // The trap: message 1 queued behind another while the rig is on the air
  // takes the transmit frequency as the run frequency, and the receive
  // reading after unkey reads as leaving it — the CQ just sent is S&P.
  for (final from in OperatingStyle.values) {
    test('working split, message 1 on the air runs where the rig receives, and the over flips nothing — from ${from.value}', () async {
      final services = (await makeHaLoServices()).services;
      services.openOperationContext('op');
      final node = await services.cat.addNode(typeKey: 'placeholder-radio', name: 'Bench Rig', config: placeholderRadioModel.variants.single.defaultConfig);
      await services.cat.connect(node.uuid);
      addTearDown(() => services.cat.disconnect(node.uuid));
      bool onAir() => services.cat.stateFor(node.uuid).telemetry.transmitting == true;
      services.radio.setVfo('vfoA', freq: 14025.0, mode: 'CW', origin: VfoOrigin.radio);
      services.cat.setStyle('A', from);

      expect(services.cat.keyer('A').sendCw('TEST TEST'), isTrue, reason: 'sanity: it keys');
      for (var i = 0; i < 150 && !onAir(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(onAir(), isTrue, reason: 'sanity: on the air');
      services.radio.setVfo('vfoA', freq: 14028.0, origin: VfoOrigin.radio);
      services.cat.operatingStyle.messageOne('A');
      expect(services.cat.styleOf('A'), OperatingStyle.run, reason: 'sanity');

      services.cat.stopCw();
      for (var i = 0; i < 150 && onAir(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(onAir(), isFalse, reason: 'sanity: off the air');
      expect(services.cat.styleOf('A'), OperatingStyle.run, reason: 'the transmit reading still in the store is no QSY');
      services.radio.setVfo('vfoA', freq: 14025.0, origin: VfoOrigin.radio);
      expect(services.cat.styleOf('A'), OperatingStyle.run);
      services.radio.setVfo('vfoA', freq: 14031.0, origin: VfoOrigin.radio);
      expect(services.cat.styleOf('A'), OperatingStyle.normal, reason: 'sanity: a QSY is still one');
    });
  }
}
