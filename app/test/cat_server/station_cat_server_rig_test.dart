// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/cat_server/cat_server_rig.dart';
import 'package:ham2k_logger/services/peer/peer_remote_radios.dart';
import 'package:ham2k_logger/services/peer/peer_station_radios.dart';
import 'package:ham2k_logger/services/radio_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CatService cat;
  late RadioService radio;
  late StationCatServerRig rig;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    radio = RadioService(prefs, writeDelay: Duration.zero);
    cat = CatService(SettingsService(prefs), radio: radio);
    addTearDown(cat.dispose);
    rig = StationCatServerRig(cat: cat, radio: radio, peerRadios: PeerRemoteRadios());
  });

  Future<String> connectedPlaceholder() async {
    final type = EquipmentRegistry().typeFor('placeholder-radio')!;
    final node = await cat.addNode(typeKey: 'placeholder-radio', config: type.defaultConfig);
    await cat.connect(node.uuid);
    return node.uuid;
  }

  test('with no Main VFO radio there is nothing to answer for', () {
    expect(rig.available, isFalse);
  });

  test('a connected Main VFO radio is available, and a disconnected one is not', () async {
    final uuid = await connectedPlaceholder();
    expect(cat.radio1, LocalRadio(uuid), reason: 'the first transceiver added becomes the Main VFO');
    expect(rig.available, isTrue);

    await cat.disconnect(uuid);
    expect(rig.available, isFalse);
  });

  test('a tune moves vfoA, and the radio with it', () async {
    final uuid = await connectedPlaceholder();
    rig.tune(freqKHz: 7074, mode: 'DATA-USB');
    await pumpEventQueue();
    expect(radio.vfoA.freq, 7074);
    // Reaching the radio is what a `user` origin buys: a `radio` one is taken
    // for the radio's own echo and never sent to it.
    expect(cat.stateFor(uuid).vfo.freqKHz, 7074);
  });

  test('a frequency no radio could be on never reaches vfoA, whichever codec let it through', () async {
    await connectedPlaceholder();
    final before = radio.vfoA.freq;
    rig.tune(freqKHz: double.nan);
    rig.tune(freqKHz: double.infinity);
    expect(radio.vfoA.freq, before);
  });

  test('with no radio a tune changes nothing, so a client cannot move a VFO nobody is following', () {
    rig.tune(freqKHz: 7074);
    expect(radio.vfoA.freq, isNot(7074));
  });

  test('a peer\'s radio is available while that peer offers it', () async {
    final peers = PeerRemoteRadios();
    rig = StationCatServerRig(cat: cat, radio: radio, peerRadios: peers);
    await cat.setRadio1(const PeerRadio(PeerRadioSelection(deviceId: 'dev', radioId: 'r1', deviceName: 'Shack', radioName: 'IC-705')));
    expect(rig.available, isFalse, reason: 'not offered yet');

    peers.setOffers('dev', 'Shack', [const PeerRadioOffer(id: 'r1', name: 'IC-705')]);
    expect(rig.available, isTrue);

    peers.forgetPeer('dev');
    expect(rig.available, isFalse);
  });

  test('a peer coming or going is announced — nothing in CatService or vfoA moves when it does', () async {
    final peers = PeerRemoteRadios();
    rig = StationCatServerRig(cat: cat, radio: radio, peerRadios: peers);
    await cat.setRadio1(const PeerRadio(PeerRadioSelection(deviceId: 'dev', radioId: 'r1', deviceName: 'Shack', radioName: 'IC-705')));
    var notified = 0;
    rig.changes.addListener(() => notified++);
    peers.setOffers('dev', 'Shack', [const PeerRadioOffer(id: 'r1', name: 'IC-705')]);
    expect(notified, 1);
    peers.forgetPeer('dev');
    expect(notified, 2);
  });
}
