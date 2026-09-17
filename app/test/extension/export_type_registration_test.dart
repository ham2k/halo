// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';

import '../support/fake_extension_host.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final failure in [
    {'key': 'adif', 'ok': false, 'error': 'registration threw'},
    {'key': 'adif', 'ok': false, 'timedOut': true},
  ]) {
    test('a failed registration cannot silently drop per-type privacy settings: $failure', () async {
      var resolvedPartialRegistry = false;
      final service = ExtensionServiceWithFakeHost(FakeExtensionHost({
        'export:*:getExportTypes': [
          failure,
          {'key': 'legacy', 'ok': true, 'value': null},
        ],
        'template:templates:exportSettings': (Object? args) {
          resolvedPartialRegistry = true;
          return <Map<String, dynamic>>[];
        },
      }));

      await expectLater(
        service.exportTypeSettings({}, (_) => {'includePrivateData': false}),
        throwsA(isA<ExtensionHostException>()),
      );
      expect(resolvedPartialRegistry, isFalse,
        reason: 'an empty registry would send ADIF through its always-include-private legacy fallback');
    });
  }

  test('a whole registration fan-out timeout propagates instead of becoming an empty registry', () async {
    final failure = HookTimeoutException('export.getExportTypes timed out');
    final service = ExtensionServiceWithFakeHost(FakeExtensionHost({'export:*:getExportTypes': failure}));
    await expectLater(service.getExportTypes(), throwsA(same(failure)));
  });

  test('legacy missing methods remain valid and shared types retain the first registration', () async {
    final service = ExtensionServiceWithFakeHost(FakeExtensionHost({
      'export:*:getExportTypes': [
        {'key': 'legacy', 'ok': true, 'value': null},
        {'key': 'first', 'ok': true, 'value': [
          {'exportType': 'potaActivation-adif', 'format': 'adif', 'label': 'POTA'},
        ]},
        {'key': 'second', 'ok': true, 'value': [
          {'exportType': 'potaActivation-adif', 'format': 'adif', 'label': 'Other POTA'},
        ]},
      ],
    }));
    final definitions = await service.getExportTypes();
    expect(definitions, hasLength(1));
    expect(definitions.single['label'], 'POTA');
  });
}
