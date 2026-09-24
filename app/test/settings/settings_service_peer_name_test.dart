// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The default name this device announces to peers. An operator with a laptop
// and a phone on the same call sees both in every pairing prompt, so the
// default must tell them apart by the device's own name — "N0DEV (macos)"
// on two Macs does not. Where the platform has no name (web, Linux) the
// platform still has to show, or the default collapses to the bare callsign.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/config/device_identity.dart';
import 'package:ham2k_logger/config/user_agent.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SettingsService> makeSettings() async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    await settings.setProfileOperatorCall(settings.activeProfileId, 'n0dev');
    return settings;
  }

  tearDown(() => debugDeviceIdentity = null);

  test("the default pairs the callsign with the device's own name", () async {
    debugDeviceIdentity = (name: 'Chirimena', description: 'Apple | Mac17,9 | Chirimena');
    final settings = await makeSettings();

    expect(settings.peerDeviceName, 'N0DEV (Chirimena)');
  });

  test('a device without a name falls back to its platform', () async {
    debugDeviceIdentity = (name: '', description: 'chrome | MacIntel');
    final settings = await makeSettings();

    expect(settings.peerDeviceName, 'N0DEV (${platformName()})');
  });

  test("the operator's own name wins over either default", () async {
    debugDeviceIdentity = (name: 'Chirimena', description: '');
    final settings = await makeSettings();
    await settings.setPeerDeviceName('Shack laptop');

    expect(settings.peerDeviceName, 'Shack laptop');
  });
}
