// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';

import '../support/fake_gps_location.dart';
import '../support/shipped_extensions.dart';

class _OneShotGps extends FakeGpsLocation {
  @override
  Future<Position?> getCurrentPosition() async => position;
}

({String source, ExtensionInfo info}) _bundle(String key, {required bool granted}) => (
  source:
      '''
    globalThis.__halo.defineExtension({
      key: '$key', name: '$key', version: '1.0.0',
      onActivation({ registerHook, hostCall }) {
        registerHook('bench', { hook: { location: async () => await hostCall('getLocation', {}) } });
      },
    });
  ''',
  info: ExtensionInfo(key: key, file: '$key.js', source: ExtensionSource.dev, core: true, name: key, hooks: ['bench'], requiresLocation: granted),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('getLocation includes reported accuracy under the existing location grant', () async {
    const fix = GridLocation(41.7, -71.5);
    final gps = _OneShotGps()..setFix(fix, accuracy: 12.5);
    final extensions = ExtensionService()..location = gps;
    prepareExtensionServiceForTest(extensions);
    await extensions.setDevBundles({
      'trusted-location': _bundle('trusted-location', granted: true),
      'plain-location': _bundle('plain-location', granted: false),
    });

    Future<dynamic> location(String key) => extensions.host!.invokeHook('bench', key: key, method: 'location');
    expect(await location('trusted-location'), {'latitude': 41.7, 'longitude': -71.5, 'accuracyMeters': 12.5});
    await expectLater(
      location('plain-location'),
      throwsA(isA<ExtensionHostException>().having((error) => error.toString(), 'message', contains('requiresLocation'))),
    );

    // A coordinate with unknown accuracy remains usable.
    for (final accuracy in [0.0, -1.0, double.nan, double.infinity]) {
      gps.setFix(fix, accuracy: accuracy);
      expect(await location('trusted-location'), {'latitude': 41.7, 'longitude': -71.5});
    }
    gps.setFix(null);
    expect(await location('trusted-location'), isNull);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
