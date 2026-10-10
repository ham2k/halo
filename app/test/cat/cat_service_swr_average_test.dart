// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The SWR a transmission averaged, as CatService measures it from what a
// session reports — against the placeholder radio, whose meters read exactly
// what it was configured with while it is keyed.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_models_other_radios.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoServices services;

  setUp(() async {
    services = (await makeHaLoServices()).services;
  });

  Future<EquipmentNode> connectPlaceholder(Map<String, dynamic> config) async {
    final node = await services.cat.addNode(
      typeKey: 'placeholder-radio',
      name: 'Bench Rig',
      config: {...placeholderRadioModel.variants.single.defaultConfig, ...config},
    );
    await services.cat.connect(node.uuid);
    addTearDown(() => services.cat.disconnect(node.uuid));
    return node;
  }

  test('a transmission leaves its average SWR behind, and when it ended', () async {
    final cat = services.cat;
    final node = await connectPlaceholder({'placeholderSwr': 2.4});
    expect(cat.lastTransmissionFor(node.uuid), isNull, reason: 'nothing has been sent yet');

    cat.togglePtt(node.uuid);
    expect(cat.stateFor(node.uuid).telemetry.transmitting, isTrue, reason: 'sanity: the placeholder keys on PTT');
    expect(cat.lastTransmissionFor(node.uuid), isNull, reason: 'a transmission under way has not ended');
    cat.togglePtt(node.uuid);

    final last = cat.lastTransmissionFor(node.uuid);
    expect(last?.swrAverage, 2.4);
    expect(last?.endedAtMillis, isPositive);
  });

  test('readings taken with no RF out do not count', () async {
    // Between words on SSB a radio reads SWR 1.0 at no power; counted, it
    // would flatter every average toward a perfect match.
    final cat = services.cat;
    final node = await connectPlaceholder({'placeholderSwr': 3.0, 'placeholderPower': 0});
    cat.togglePtt(node.uuid);
    cat.togglePtt(node.uuid);
    expect(cat.lastTransmissionFor(node.uuid)?.swrAverage, isNull);
  });

  test('what draws meters live hears a disconnect, which sends no meter reading of its own', () async {
    // Unheard, a scene would keep the last S-meter and power readings up as if the radio were live.
    final cat = services.cat;
    final node = await connectPlaceholder({});
    var heard = 0;
    void listener() => heard++;
    cat.meterReadings.addListener(listener);
    addTearDown(() => cat.meterReadings.removeListener(listener));
    await cat.disconnect(node.uuid);
    expect(heard, isPositive);
  });

  test('CW break-in keys a whole over as one transmission, so its average is the over\'s', () async {
    // Unkeyed between characters, a CW over is dozens of key-downs: averaged
    // one by one, what is left after the over is the last element's reading.
    // The placeholder reads one SWR per connection, so a reconnect changes it.
    final cat = services.cat;
    final node = await connectPlaceholder({'placeholderSwr': 2.4});
    Future<void> element({required num swr}) async {
      await cat.disconnect(node.uuid);
      await cat.updateNode(node.copyWith(config: {...cat.nodes.firstWhere((n) => n.uuid == node.uuid).config, 'placeholderSwr': swr}));
      await cat.connect(node.uuid);
      cat.togglePtt(node.uuid);
      cat.togglePtt(node.uuid);
    }

    cat.togglePtt(node.uuid);
    cat.togglePtt(node.uuid);
    await element(swr: 1.0);
    expect(cat.lastTransmissionFor(node.uuid)?.swrAverage, closeTo(1.7, 1e-9), reason: 'a gap under 500 ms continues the over');

    await Future<void>.delayed(const Duration(milliseconds: 600));
    await element(swr: 1.2);
    expect(cat.lastTransmissionFor(node.uuid)?.swrAverage, closeTo(1.2, 1e-9), reason: 'a longer gap starts the next transmission');
  });
}
