// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// `host.updateDraft`: who may change the QSO the operator is composing, and
// what reaches the operation. The grant is what the operator agreed to at
// install, so a call without it must fail where it is made; and a frequency,
// band or mode moves the radio, so those also take the radio grant.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart' show ExtensionHostException;
import 'package:ham2k_logger/services/extensions/extension_info.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final delivered = <({Map<String, dynamic> patch, String? operationUuid, bool replace})>[];

  ExtensionServiceWithFakeHost harness({bool draftWrite = true, bool radioWrite = false}) {
    final extensions = ExtensionServiceWithFakeHost(FakeExtensionHost({}));
    final infos = [
      ExtensionInfo(
        key: 'k1abc-coach',
        file: 'k1abc-coach.js',
        name: 'Coach',
        core: false,
        source: ExtensionSource.installed,
        requiresDraftWrite: draftWrite,
        requiresRadioWrite: radioWrite,
      ),
    ];
    extensions.debugSetAvailableExtensions(infos);
    // As a runtime start resolves them.
    extensions.radioCalls.allow(infos);
    extensions.onUpdateDraft = (patch, operationUuid, {required replace}) {
      delivered.add((patch: patch, operationUuid: operationUuid, replace: replace));
      return true;
    };
    addTearDown(extensions.bandAnnotations.dispose);
    addTearDown(extensions.spotMarks.dispose);
    delivered.clear();
    return extensions;
  }

  Future<dynamic> call(ExtensionServiceWithFakeHost extensions, Map<String, dynamic> rest) =>
      extensions.debugHandleHostCall('updateDraft', {'ns': 'k1abc-coach', 'extensionKey': 'k1abc-coach', ...rest});

  test('is refused without requiresDraftWrite, and reaches nothing', () async {
    final extensions = harness(draftWrite: false);
    await expectLater(
      call(extensions, {
        'patch': {
          'their': {'sent': '579'},
        },
      }),
      throwsA(isA<ExtensionHostException>()),
    );
    expect(delivered, isEmpty);
  });

  test('carries the patch to the operation named, merging unless asked to replace', () async {
    final extensions = harness();
    expect(
      await call(extensions, {
        'patch': {
          'their': {'call': 'K1ABC'},
        },
        'operationUuid': 'op-1',
      }),
      {'accepted': true},
    );
    expect(delivered.single.operationUuid, 'op-1');
    expect(delivered.single.replace, isFalse);
    expect(delivered.single.patch, {
      'their': {'call': 'K1ABC'},
    });
  });

  test('a frequency, band or mode moves the radio, so it also needs requiresRadioWrite', () async {
    await expectLater(
      call(harness(), {
        'patch': {'freq': 14074.0},
      }),
      throwsA(isA<ExtensionHostException>()),
    );
    expect(delivered, isEmpty);
    await call(harness(radioWrite: true), {
      'patch': {'freq': 14074.0},
    });
    expect(delivered.single.patch, {'freq': 14074.0});
  });

  test('a replacement is a new contact, so it needs a call', () async {
    await expectLater(
      call(harness(), {
        'patch': {'notes': 'hi'},
        'replace': true,
      }),
      throwsA(isA<FormatException>()),
    );
  });
}
