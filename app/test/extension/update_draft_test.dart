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

  // A field of the wrong kind throws in the logging fields when the patch
  // lands (`notes: 42` in the notes controller, a `their` that is no map in
  // the merge), where the extension never hears of it and the operator's
  // contact is stuck. So it must be refused at the call, and reach nothing.
  test('a field of the wrong kind is refused at the call, naming the field, and reaches nothing', () async {
    final extensions = harness();
    for (final (patch, field) in [
      ({'notes': 42}, '`notes`'),
      ({'their': 'K1ABC'}, '`their`'),
      (
        {
          'their': {'call': 7},
        },
        '`their.call`',
      ),
      (
        {
          'our': {'sent': true},
        },
        '`our.sent`',
      ),
      ({'refs': 'pota'}, '`refs`'),
      (
        {
          'refs': [
            {'ref': 'US-1234'},
          ],
        },
        '`refs[0]`',
      ),
      (
        {
          'refs': [
            {
              'type': 'pota',
              'ref': 'US-1234',
              'location': {'lat': 45},
            },
          ],
        },
        '`refs[0]`',
      ),
    ]) {
      await expectLater(
        call(extensions, {'patch': patch}),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains(field))),
        reason: '$patch',
      );
    }
    expect(delivered, isEmpty);
  });

  // The draft's own refs come back this way: an extension adds a ref by
  // writing the list back whole, and a contest's exchange ref carries a
  // serial and no `ref`, a park its coordinates. Refusing those would break
  // the plainest use of the call.
  test('refs as the SDK writes them go on: no `ref` for an exchange, numbers and flags for a park', () async {
    final extensions = harness();
    final refs = [
      {'type': 'cqwpx', 'ourSerial': 12},
      {'type': 'pota', 'ref': 'US-1234', 'lat': 45.1, 'lon': -70.2, 'largeArea': false},
    ];
    await call(extensions, {
      'patch': {'refs': refs},
    });
    expect(delivered.single.patch, {'refs': refs});
  });

  // locations.md: a pair already on the contact (the More pane's, an earlier
  // patch's) outranks the grid written beside it, so the contact would be
  // placed, and exported, where it was not.
  test('a grid written or cleared without coordinates clears the ones beside it, and one written with them keeps them', () async {
    final extensions = harness();
    await call(extensions, {
      'patch': {
        'their': {'grid': 'FN42'},
      },
    });
    await call(extensions, {
      'patch': {
        'their': {'grid': null},
      },
    });
    await call(extensions, {
      'patch': {
        'our': {'grid': 'FN31', 'lat': 41.7, 'lon': -72.7},
      },
    });
    expect(delivered.map((d) => d.patch), [
      {
        'their': {'grid': 'FN42', 'lat': null, 'lon': null},
      },
      {
        'their': {'grid': null, 'lat': null, 'lon': null},
      },
      {
        'our': {'grid': 'FN31', 'lat': 41.7, 'lon': -72.7},
      },
    ]);
  });

  // Each of these clears the pair and puts nothing usable in its place: a
  // grid that names no square has no center to stand for the contact, and a
  // latitude laid beside the longitude already there is a point nobody
  // stated, which then outranks the grid.
  test('a grid that is no locator, or one axis of a coordinate alone, is refused and reaches nothing', () async {
    final extensions = harness();
    for (final (patch, field) in [
      (
        {
          'their': {'grid': 'FN3'},
        },
        '`their.grid`',
      ),
      (
        {
          'our': {'grid': 'hello'},
        },
        '`our.grid`',
      ),
      (
        {
          'their': {'grid': 'FN42', 'lat': 41.7},
        },
        '`their.lat`',
      ),
      (
        {
          'our': {'lon': -72.7},
        },
        '`our.lat`',
      ),
    ]) {
      await expectLater(
        call(extensions, {'patch': patch}),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains(field))),
        reason: '$patch',
      );
    }
    expect(delivered, isEmpty);
  });

  test('the refusal names the field and the kind in JavaScript\'s words', () async {
    await expectLater(
      call(harness(), {
        'patch': {'notes': {}},
      }),
      throwsA(isA<FormatException>().having((e) => e.message, 'message', 'updateDraft: `notes` must be text')),
    );
  });

  test('a number written as text arrives as the number, and a field the app does not know goes on as it is', () async {
    await call(harness(radioWrite: true), {
      'patch': {'freq': '14074.5', 'k1abcCoach': 42},
    });
    expect(delivered.single.patch, {'freq': 14074.5, 'k1abcCoach': 42});
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
