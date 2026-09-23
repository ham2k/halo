// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/cat_server/cat_server_protocol.dart';
import 'package:ham2k_logger/services/cat_server/cat_server_rig.dart';
import 'package:ham2k_logger/services/cat_server/cat_server_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/settings/cat_server_dialog.dart';
import 'package:ham2k_logger/settings/core_settings_groups.dart';
import 'package:ham2k_logger/settings/settings_registry.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_cat_server_rig.dart';

class _Listener implements CatServerListener {
  @override
  final int port;

  _Listener(this.port);

  @override
  int get clientCount => 2;

  @override
  Future<void> close() async {}
}

void main() {
  late SettingsService settings;
  late FakeCatServerRig rig;
  late CatServerService service;
  Object? bindError;

  Future<void> setUpWith({bool cat = true, bool server = true, Map<String, dynamic> radio = const {}}) async {
    SharedPreferences.setMockInitialValues({
      'experiments': jsonEncode({
        if (cat) 'gato': {'enabled': true},
        if (server) 'server': {'enabled': true},
      }),
      'settings.radio': jsonEncode(radio),
    });
    settings = SettingsService(await SharedPreferences.getInstance());
    rig = FakeCatServerRig();
    Future<CatServerListener> bind(
      CatServerProtocol protocol,
      CatServerRig rig, {
      required int port,
      required bool lan,
      void Function()? onClientsChanged,
      void Function()? onStopped,
    }) async {
      if (bindError != null) throw bindError!;
      return _Listener(port);
    }

    service = CatServerService(settings: settings, rig: rig, bind: bind, rebindDelay: Duration.zero);
    addTearDown(service.dispose);
    await pumpEventQueue();
  }

  setUp(() => bindError = null);

  Map<String, dynamic> element(String key) => catServerElements(service).firstWhere((e) => e['key'] == key);

  Map<String, dynamic> port() => catServerElements(service).firstWhere((e) => e['fieldType'] == 'number');

  group('the Radio section', () {
    test('offers the CAT Server as one row, saying what the server is doing', () async {
      await setUpWith(radio: {CatServerSettings.protocolKey: 'rigctld'});
      final elements = await RadioSettingsGroup(settings, catServer: () => service).buildElements();
      final row = elements.singleWhere((e) => e['key'] == 'catServer');
      expect(row['type'], 'action');
      expect(row['description'], t.settings.catServer.listening(protocol: 'Hamlib rigctld', port: 4532, clients: 2));
      expect(elements.where((e) => '${e['key']}'.startsWith('catServer')), [row], reason: 'the protocol, port and access live in the dialog, not the section');
    });

    test('the row is in the current radio\'s settings dialog too', () async {
      await setUpWith(radio: {CatServerSettings.protocolKey: 'rigctld'});
      final elements = await RadioSettingsGroup(settings, catServer: () => service).buildElements();
      final row = elements.singleWhere((e) => e['key'] == 'catServer');
      expect(elementMatchesTarget(row, 'current-radio'), isTrue);
    });

    test('stays subscribed to the server across the experiment coming on while Settings is open', () async {
      // Settings subscribes once when the section mounts and unsubscribes when
      // it goes; if the object handed out changed with the experiment, the
      // row would stop updating, or leave a listener on the server behind.
      await setUpWith(server: false, radio: {CatServerSettings.protocolKey: 'rigctld'});
      final group = RadioSettingsGroup(settings, catServer: () => service);
      final listenable = group.listenable;
      var heard = 0;
      void listener() => heard++;
      listenable.addListener(listener);

      await settings.setExperimentEnabled('server', true);
      await pumpEventQueue();
      expect(identical(group.listenable, listenable), isTrue);
      heard = 0;
      rig.available = false;
      rig.move(); // the server announces that the radio went away
      expect(heard, greaterThan(0), reason: 'the server\'s own news reaches the row');

      listenable.removeListener(listener);
      heard = 0;
      rig.available = true;
      rig.move();
      expect(heard, 0);
    });

    test('has no CAT Server row without its own experiment', () async {
      await setUpWith(server: false);
      final elements = await RadioSettingsGroup(settings, catServer: () => service).buildElements();
      expect(elements.where((e) => e['key'] == 'catServer'), isEmpty);
      expect(elements, isNotEmpty, reason: 'the rest of the Radio section is CAT\'s, and stays');
    });

    test('has no CAT Server row without CAT, which is still an experiment', () async {
      await setUpWith(cat: false);
      expect(await RadioSettingsGroup(settings, catServer: () => service).buildElements(), isEmpty);
    });
  });

  group('the dialog', () {
    test('offers Disabled and the four programs, Ham Radio Deluxe with its registered mark', () async {
      await setUpWith();
      final protocol = element(CatServerSettings.protocolKey);
      expect(protocol['value'], CatServerSettings.off);
      expect((protocol['options'] as List).map((o) => o['label']), ['Disabled', 'Hamlib rigctld', 'flrig', 'Ham Radio Deluxe®', 'N3FJP']);
    });

    test('greys the port and access while Disabled, and fills in the program\'s own port once picked', () async {
      await setUpWith();
      expect(port()['disabled'], isTrue);
      expect(element(CatServerSettings.openAccessKey)['disabled'], isTrue);

      await commitCatServerSetting(settings, CatServerSettings.protocolKey, 'hrd');
      expect(port()['value'], 7809);
      expect(port()['disabled'], isFalse);
      expect(element(CatServerSettings.openAccessKey)['value'], isFalse, reason: 'only this computer until the operator says otherwise');
    });

    test('each program keeps its own port, through a switch to another and through Disabled', () async {
      // The usual reason for a custom port is the real program still holding
      // the default one; losing it on a round trip binds straight into it.
      await setUpWith(radio: {CatServerSettings.protocolKey: 'rigctld'});
      await commitCatServerSetting(settings, port()['key'] as String, 4533);
      await commitCatServerSetting(settings, CatServerSettings.protocolKey, 'flrig');
      expect(port()['value'], 12345, reason: 'flrig\'s own, not rigctld\'s');
      await commitCatServerSetting(settings, CatServerSettings.protocolKey, CatServerSettings.off);
      await commitCatServerSetting(settings, CatServerSettings.protocolKey, 'rigctld');
      expect(port()['value'], 4533);
    });

    test('the port is a number, as the field reports an edit back', () async {
      // A text value never equals what the field holds after an edit, and the
      // field then stops taking values from the definition at all.
      await setUpWith(radio: {CatServerSettings.protocolKey: 'rigctld'});
      expect(port()['value'], isA<int>());
    });

    test('a port outside 1-65535 is not stored', () async {
      await setUpWith(radio: {CatServerSettings.protocolKey: 'rigctld'});
      final key = port()['key'] as String;
      await commitCatServerSetting(settings, key, '70000');
      expect(settings.settingValue(SettingsService.radioGroup, key), isNull);
      await commitCatServerSetting(settings, key, '4533');
      expect(CatServerSettings.port(settings, CatServerProtocol.rigctld), 4533);
    });

    test('an unknown protocol changes nothing', () async {
      await setUpWith(radio: {CatServerSettings.protocolKey: 'rigctld'});
      await commitCatServerSetting(settings, CatServerSettings.protocolKey, 'omnirig');
      expect(CatServerSettings.protocol(settings), CatServerProtocol.rigctld);
    });

    test('the status says when there is no radio behind the server, rather than looking healthy', () async {
      await setUpWith(radio: {CatServerSettings.protocolKey: 'rigctld'});
      rig.available = false;
      rig.move();
      expect(catServerStatusText(service), t.settings.catServer.listeningNoRadio(protocol: 'Hamlib rigctld', port: 4532));
    });

    test('a port another program holds is said in words the operator can act on, not the system\'s', () async {
      bindError = SocketException('Failed to create server socket', osError: OSError('Address already in use', 48));
      await setUpWith(radio: {CatServerSettings.protocolKey: 'rigctld'});
      expect(catServerStatusText(service), t.settings.catServer.portInUse(protocol: 'Hamlib rigctld', port: 4532));
    });

    test('the status names a port it could not bind, and why', () async {
      bindError = StateError('address in use');
      await setUpWith(radio: {CatServerSettings.protocolKey: 'hrd'});
      expect(catServerStatusText(service), allOf(contains('address in use'), contains('7809'), contains('Ham Radio Deluxe®')));
    });
  });
}
