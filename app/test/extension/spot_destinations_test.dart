// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The destinations Settings › Spotting lists: the `spots` hooks that post,
// found in the runtime's roster of registered methods. The roster here has
// the shape the kernel's `runtime.listHooks` answers with
// (extensions/sdk/src/kernel.ts).

import 'package:flutter_test/flutter_test.dart';

import 'package:ham2k_logger/services/extensions/extension_info.dart';

import '../support/fake_extension_host.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, dynamic> hook(String category, String key, List<String> methods, {String? extensionKey}) => {
    'category': category,
    'key': key,
    'extensionKey': extensionKey ?? key,
    'priority': 0,
    'methods': methods,
  };

  // A feed listed as a destination would be a setting with nothing behind
  // it; asking each hook by calling a posting method would post. The icon
  // and accent are the EXTENSION's, found by the roster's extensionKey, not
  // the hook's key: one extension can register a hook under another key.
  test('lists the spots hooks that post, by name, with their extension\'s icon and accent, and no feed or other category', () async {
    final service = ExtensionServiceWithFakeHost(
      FakeExtensionHost({
        'runtime:kernel:listHooks': [
          hook('spots', 'ham2k-pota', ['fetchSpots', 'isSelfSpotEnabled', 'postSelfSpot', 'postOtherSpot']),
          hook('spots', 'ki2d-discord', ['isSelfSpotEnabled', 'postSelfSpot'], extensionKey: 'ki2d-chat'),
          hook('spots', 'ham2k-rbn', ['fetchSpots']),
          hook('spots', 'ham2k-hunter', ['isOtherSpotEnabled', 'postOtherSpot']),
          hook('lookupService', 'ham2k-qrz', ['postSelfSpot']),
        ],
        'spots:*:sourceName': [
          {'key': 'ham2k-pota', 'ok': true, 'value': 'POTA.app'},
          {'key': 'ham2k-rbn', 'ok': true, 'value': 'RBN'},
        ],
      }),
    );
    service.debugSetAvailableExtensions(const [
      ExtensionInfo(key: 'ham2k-pota', file: 'pota.js', core: false, name: 'Parks on the Air', icon: 'pine-tree', accentColor: '#2E7D32'),
      ExtensionInfo(key: 'ki2d-chat', file: 'chat.js', core: false, name: 'Chat', icon: 'chat'),
      ExtensionInfo(key: 'ki2d-discord', file: 'discord.js', core: false, name: 'Not this one', icon: 'wrong', accentColor: '#000000'),
    ]);
    expect(await service.getSpotDestinations(), {
      'ham2k-pota': (name: 'POTA.app', icon: 'pine-tree', accentColor: '#2E7D32', postsSelfSpots: true),
      'ki2d-discord': (name: 'ki2d-discord', icon: 'chat', accentColor: null, postsSelfSpots: true),
      'ham2k-hunter': (name: 'ham2k-hunter', icon: null, accentColor: null, postsSelfSpots: false),
    });
  });

  // Settings rebuilds the list on every change to any setting; asked each
  // time, every toggle is two more trips through the runtime. A new
  // runtime is a new set of extensions, which must be asked again.
  test('asks the runtime once per runtime generation', () async {
    var asked = 0;
    final service = ExtensionServiceWithFakeHost(
      FakeExtensionHost({
        'runtime:kernel:listHooks': (_) {
          asked++;
          return [
            hook('spots', 'ham2k-pota', ['postSelfSpot']),
          ];
        },
      }),
    );
    await service.getSpotDestinations();
    await service.getSpotDestinations();
    expect(asked, 1);
    service.runtimeGeneration.value++;
    expect((await service.getSpotDestinations()).keys, ['ham2k-pota']);
    expect(asked, 2);
  });

  test('a runtime that cannot answer lists none', () async {
    final service = ExtensionServiceWithFakeHost(FakeExtensionHost({'runtime:kernel:listHooks': Exception('runtime down')}));
    expect(await service.getSpotDestinations(), isEmpty);
  });
}
