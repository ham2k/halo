// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/cat_server/cat_server_rig.dart';
import 'package:ham2k_logger/services/cat_server/cat_server_service.dart';
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
  late SettingsService settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    radio = RadioService(prefs, writeDelay: Duration.zero);
    settings = SettingsService(prefs);
    cat = CatService(settings, radio: radio);
    addTearDown(cat.dispose);
    rig = StationCatServerRig(cat: cat, radio: radio, peerRadios: PeerRemoteRadios(), settings: settings);
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
    rig = StationCatServerRig(cat: cat, radio: radio, peerRadios: peers, settings: settings);
    await cat.setRadio1(const PeerRadio(PeerRadioSelection(deviceId: 'dev', radioId: 'r1', deviceName: 'Shack', radioName: 'IC-705')));
    expect(rig.available, isFalse, reason: 'not offered yet');

    peers.setOffers('dev', 'Shack', [const PeerRadioOffer(id: 'r1', name: 'IC-705')]);
    expect(rig.available, isTrue);

    peers.forgetPeer('dev');
    expect(rig.available, isFalse);
  });

  test('a peer coming or going is announced — nothing in CatService or vfoA moves when it does', () async {
    final peers = PeerRemoteRadios();
    rig = StationCatServerRig(cat: cat, radio: radio, peerRadios: peers, settings: settings);
    await cat.setRadio1(const PeerRadio(PeerRadioSelection(deviceId: 'dev', radioId: 'r1', deviceName: 'Shack', radioName: 'IC-705')));
    var notified = 0;
    rig.changes.addListener(() => notified++);
    peers.setOffers('dev', 'Shack', [const PeerRadioOffer(id: 'r1', name: 'IC-705')]);
    expect(notified, 1);
    peers.forgetPeer('dev');
    expect(notified, 2);
  });

  group('PTT', () {
    Future<void> allowTransmit([bool allow = true]) => settings.setSettingValue(SettingsService.radioGroup, CatServerSettings.allowTransmitKey, allow);
    final client = Object(), otherClient = Object();

    test('a client cannot key until the operator allows it, however capable the radio', () async {
      await connectedPlaceholder();
      expect(rig.canTransmit, isFalse);
      expect(rig.keyPtt(client), isFalse);
      expect(cat.radio1IsTransmitting, isFalse);

      await allowTransmit();
      expect(rig.canTransmit, isTrue);
      expect(rig.keyPtt(client), isTrue);
    });

    test("a client's key is the station's one key: on the Main VFO radio, and dropped by Escape", () async {
      await connectedPlaceholder();
      await allowTransmit();
      rig.keyPtt(client);
      expect(cat.pttHeldOnRadio1, isTrue);
      expect(rig.transmitting, isTrue);

      cat.stopKeying();
      expect(rig.transmitting, isFalse, reason: 'Escape must take an app off the air as it does the operator');
    });

    test("a client's unkey reaches the radio it keyed after the Main VFO moved to another", () async {
      final first = await connectedPlaceholder();
      final second = await connectedPlaceholder();
      await allowTransmit();
      await cat.setRadio1(LocalRadio(first));
      expect(rig.keyPtt(client), isTrue);
      await cat.setRadio1(LocalRadio(second));
      expect(cat.localRadio1, second);
      expect(cat.pttKeys.held.value, isTrue, reason: 'the key stays with the radio it went to');

      rig.releasePtt(client);
      expect(cat.pttKeys.held.value, isFalse, reason: 'left to the timeout, the first radio stays on the air for minutes');
    });

    test("a client's unkey leaves the operator's key, and another client's, alone", () async {
      final uuid = await connectedPlaceholder();
      await allowTransmit();
      cat.togglePtt(uuid);
      rig.releasePtt(client);
      expect(rig.transmitting, isTrue, reason: "a program sending PTT off as it opens must not end the operator's over");

      expect(rig.keyPtt(otherClient), isFalse, reason: "taking the key over, its unkey would end the operator's over");
      expect(rig.transmitting, isTrue);
    });

    test("a refused key changes nothing: the operator's key stays theirs", () async {
      final uuid = await connectedPlaceholder();
      await allowTransmit();
      cat.togglePtt(uuid);
      final held = cat.pttKeys.held.value;
      expect(rig.keyPtt(client), isFalse);
      expect(cat.pttKeys.held.value, held);
      expect(cat.pttOwner, isNull);
    });

    test("Escape drops a client's key from anywhere; ['] drops it only where ['] is the PTT key", () async {
      await connectedPlaceholder();
      await allowTransmit();
      rig.keyPtt(client);
      expect(cat.pttKeys.release(), isFalse, reason: 'an apostrophe typed into a note while FT8 transmits must type, not unkey');
      expect(rig.transmitting, isTrue);
      expect(cat.stopKeying(), isTrue);
      expect(rig.transmitting, isFalse);
    });

    test("withdrawing the permission drops a client's key, and leaves the operator's", () async {
      final uuid = await connectedPlaceholder();
      await allowTransmit();
      CatServerPtt(rig).set(true);
      rig.releaseClientPtt();
      expect(rig.transmitting, isFalse);

      cat.togglePtt(uuid);
      rig.releaseClientPtt();
      expect(rig.transmitting, isTrue, reason: "the operator's own key is theirs to drop");
    });

    test("a peer's radio is never keyed from here", () async {
      final peers = PeerRemoteRadios();
      rig = StationCatServerRig(cat: cat, radio: radio, peerRadios: peers, settings: settings);
      await allowTransmit();
      await cat.setRadio1(const PeerRadio(PeerRadioSelection(deviceId: 'dev', radioId: 'r1', deviceName: 'Shack', radioName: 'IC-705')));
      peers.setOffers('dev', 'Shack', [const PeerRadioOffer(id: 'r1', name: 'IC-705')]);
      expect(rig.available, isTrue);
      expect(rig.transmitAllowed, isTrue);
      expect(rig.canTransmit, isFalse);
      expect(rig.keyPtt(client), isFalse);
    });

    test("a client's key drops itself at three minutes, longer than the operator's minute", () async {
      await connectedPlaceholder();
      await allowTransmit();
      fakeAsync((async) {
        rig.keyPtt(client);
        async.elapse(catServerPttTimeout - const Duration(seconds: 1));
        expect(rig.transmitting, isTrue, reason: 'a JS8 or fldigi transmission runs past a minute');
        async.elapse(const Duration(seconds: 1));
        expect(rig.transmitting, isFalse, reason: 'a client that hung mid-over must not leave the radio on the air');
      });
    });
  });
}
