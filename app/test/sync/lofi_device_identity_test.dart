// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// How this device names itself to LoFi. The server's device list shows HaLo
// and PoLo rows side by side, so the description must keep PoLo's
// `manufacturer | model | name` order — a reordered or re-separated string
// still "works" and only reads wrong there. The name is what another device's
// link prompt shows; a platform without one must come back EMPTY, not as a
// placeholder, or the app's fallback to its own name never fires — and iOS's
// generic "iPhone" is such a placeholder. What the extension is seeded with
// is the other half: a `deviceName` sent empty, or a fallback dropped, renames
// the client on the server to nothing useful.

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ham2k_logger/config/device_identity.dart';
import 'package:ham2k_logger/services/extension_service.dart';

AndroidDeviceInfo _android({required String manufacturer, required String board, required String name}) => AndroidDeviceInfo.setMockInitialValues(
  version: AndroidBuildVersion.setMockInitialValues(codename: 'REL', incremental: '1', previewSdkInt: 0, release: '14', sdkInt: 34),
  board: board,
  bootloader: '',
  brand: manufacturer,
  device: 'dm1q',
  display: '',
  fingerprint: '',
  hardware: 'qcom',
  host: '',
  id: '',
  manufacturer: manufacturer,
  model: 'SM-S911U',
  product: '',
  name: name,
  supported32BitAbis: const [],
  supported64BitAbis: const [],
  supportedAbis: const [],
  tags: '',
  type: 'user',
  isPhysicalDevice: true,
  freeDiskSize: 0,
  totalDiskSize: 0,
  systemFeatures: const [],
  isLowRamDevice: false,
  physicalRamSize: 0,
  availableRamSize: 0,
);

IosDeviceInfo _ios({required String name}) => IosDeviceInfo.setMockInitialValues(
  name: name,
  systemName: 'iOS',
  systemVersion: '18.0',
  model: 'iPhone',
  modelName: 'iPhone 15',
  localizedModel: 'iPhone',
  freeDiskSize: 0,
  totalDiskSize: 0,
  isPhysicalDevice: true,
  isiOSAppOnMac: false,
  isiOSAppOnVision: false,
  physicalRamSize: 0,
  availableRamSize: 0,
  utsname: IosUtsname.setMockInitialValues(sysname: 'Darwin', nodename: '', release: '', version: '', machine: 'iPhone15,4'),
);

void main() {
  test("an Android device reads exactly as PoLo's does", () {
    final identity = identityFrom(_android(manufacturer: 'samsung', board: 'kalama', name: " Michael's S23 "));

    expect(identity.description, "samsung | kalama | Michael's S23");
    expect(identity.name, "Michael's S23");
  });

  test('an unnamed device leaves the name empty and the blank part out', () {
    final identity = identityFrom(_android(manufacturer: 'onn', board: 'mid7019_mr_32', name: ''));

    expect(identity.name, isEmpty);
    expect(identity.description, 'onn | mid7019_mr_32');
  });

  test('a browser has no device name to give', () {
    final identity = identityFrom(
      WebBrowserInfo.fromMap({'userAgent': 'Mozilla/5.0 (Macintosh) AppleWebKit/537.36 Chrome/140.0 Safari/537.36', 'platform': 'MacIntel'}),
    );

    expect(identity.name, isEmpty);
    expect(identity.description, 'chrome | MacIntel');
  });

  test("iOS's generic model name is no device name", () {
    expect(identityFrom(_ios(name: 'iPhone')), (name: '', description: 'Apple | iPhone15,4'));
    expect(identityFrom(_ios(name: "Michael's iPhone")).name, "Michael's iPhone");
  });

  test('a named device registers and renames under its own name', () {
    final seed = ExtensionService.lofiClientSeed((name: 'Chirimena', description: 'Apple | Mac17,9 | Chirimena'), appVersion: 'halo 26.9.0 (macos next 171)');

    expect(seed['clientName'], 'Chirimena');
    expect(seed['diagnostics'], {'device': 'Apple | Mac17,9 | Chirimena', 'deviceName': 'Chirimena', 'appVersion': 'halo 26.9.0 (macos next 171)'});
  });

  test('an unnamed device registers as the app and sends no deviceName', () {
    final seed = ExtensionService.lofiClientSeed((name: '', description: 'chrome | MacIntel'), appVersion: 'halo 26.9.0 (web next)');

    expect(seed['clientName'], startsWith('Ham2K '));
    expect((seed['diagnostics']! as Map).containsKey('deviceName'), isFalse);
  });
}
