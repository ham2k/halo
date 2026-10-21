// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The one platform scan that peer discovery and the CAT device picker share.
// The trap it exists for: the plugin runs a single scan per process, so the
// picker starting its own would replace peer discovery's filter, and its
// stop would end peer discovery outright — with every indicator still
// saying it is looking.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/ble/ble_scan_coordinator.dart';
import 'package:universal_ble/universal_ble.dart';

const _peer = '1cec4c5f-355c-4fd1-9e97-921c328b59cd';
const _nus = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';

class _FakePlatform extends UniversalBlePlatform {
  /// Every scan the plugin was asked to start, as its service filter — null
  /// for unfiltered — and `'stop'` for every stop.
  final calls = <Object?>[];
  bool get scanning => _scanning;
  bool _scanning = false;

  @override
  Future<void> startScan({ScanFilter? scanFilter, PlatformConfig? platformConfig}) async {
    _scanning = true;
    calls.add(scanFilter?.withServices);
  }

  /// Delivered while a stop is in flight, as a result the platform had
  /// already queued from the scan being stopped.
  BleDevice? inFlightAtStop;

  /// Android's answer to a stop while Bluetooth is off.
  Object? failStop;

  @override
  Future<void> stopScan() async {
    if (failStop case final error?) {
      failStop = null;
      _scanning = false;
      throw error;
    }
    final late = inFlightAtStop;
    inFlightAtStop = null;
    if (late != null) updateScanResult(late);
    await Future<void>.delayed(Duration.zero);
    _scanning = false;
    calls.add('stop');
  }

  void advertise(String id, List<String> services) => updateScanResult(BleDevice(deviceId: id, name: id, services: services));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakePlatform platform;
  final coordinator = BleScanCoordinator.instance;

  setUp(() {
    platform = _FakePlatform();
    UniversalBle.setInstance(platform);
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('the picker\'s scan widens peer discovery\'s, and ending it narrows it back', () async {
    final peerSeen = <String>[];
    final pickerSeen = <String>[];
    final peer = await coordinator.acquire(services: {_peer}, onResult: (d) => peerSeen.add(d.deviceId));
    expect(platform.calls.last, [_peer]);

    final picker = await coordinator.acquire(onResult: (d) => pickerSeen.add(d.deviceId));
    expect(platform.calls.last, isNull, reason: 'the picker looks for anything with a name');

    platform.advertise('phone', [_peer]);
    platform.advertise('bridge', [_nus]);
    await settle();
    expect(pickerSeen, ['phone', 'bridge']);
    expect(peerSeen, ['phone'], reason: 'peer discovery must not try to pair with a radio bridge');

    await coordinator.release(picker);
    expect(platform.scanning, isTrue, reason: 'the picker closing must not end peer discovery');
    expect(platform.calls.last, [_peer]);

    await coordinator.release(peer);
    expect(platform.scanning, isFalse);
  });

  test('a wide scan\'s last results are never handed to peer discovery as peers', () async {
    // While the picker's scan narrows back, results it already queued still
    // arrive. Read as the peer filter's, a radio bridge would be dialed as a
    // peer — and the failed dial disconnects the bridge out from under CAT.
    final peerSeen = <String>[];
    final peer = await coordinator.acquire(services: {_peer}, onResult: (d) => peerSeen.add(d.deviceId));
    final picker = await coordinator.acquire(onResult: (_) {});
    platform.inFlightAtStop = BleDevice(deviceId: 'bridge', name: 'bridge', services: const [_nus]);
    await coordinator.release(picker);
    await settle();
    expect(peerSeen, isEmpty);
    await coordinator.release(peer);
  });

  test('a lone filtered lease gets what the platform filter let through', () async {
    // A platform that matched the filter but left the service out of the
    // result would otherwise lose every peer sighting here.
    final seen = <String>[];
    final peer = await coordinator.acquire(services: {_peer}, onResult: (d) => seen.add(d.deviceId));
    platform.advertise('phone', const []);
    await settle();
    expect(seen, ['phone']);
    await coordinator.release(peer);
  });

  test('a stop refused while Bluetooth is off does not keep the next start from running', () async {
    // Peer discovery stops its scan when Bluetooth goes off and starts it
    // again when it comes back. Read as still running, the refused stop
    // would make that start a no-op, and peer discovery would look for
    // devices for the rest of the session with no scan under it.
    final first = await coordinator.acquire(services: {_peer}, onResult: (_) {});
    platform.failStop = Exception('Bluetooth not enabled');
    await expectLater(coordinator.release(first), throwsException);

    final again = await coordinator.acquire(services: {_peer}, onResult: (_) {});
    expect(platform.scanning, isTrue);
    expect(platform.calls.last, [_peer]);
    await coordinator.release(again);
  });

  test('releasing twice stops nothing that another lease still needs', () async {
    final a = await coordinator.acquire(onResult: (_) {});
    final b = await coordinator.acquire(onResult: (_) {});
    await coordinator.release(a);
    await coordinator.release(a);
    expect(platform.scanning, isTrue);
    await coordinator.release(b);
    expect(platform.scanning, isFalse);
  });
}
