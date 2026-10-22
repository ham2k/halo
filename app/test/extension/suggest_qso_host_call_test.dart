// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// `host.suggestQso` lets an extension's panel do what tapping a spot in the
// Spots Panel does: put the station into the logging fields. What it must not
// do is write anything a spot does not carry into the contact being logged,
// or fill the fields of an operation other than the one the panel belongs to
// — a log the operator is not looking at. It tunes the radio as a tap does,
// and it answers a click: from a timer or a render it would overwrite a
// half-typed call with nothing on screen asking for it.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/halo_services.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/shipped_extensions.dart';

ExtensionInfo panelExtension(String key, {bool write = true}) =>
    ExtensionInfo(key: key, file: '$key.js', source: ExtensionSource.dev, core: true, name: key, requiresRadioWrite: write);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // As the kernel stamps a call from inside the panel's `onEvent`.
  Future<Object?> suggest(ExtensionService extensions, Map<String, dynamic> params) =>
      extensions.debugHandleHostCall('suggestQso', {...params, 'extensionKey': 'panel', 'duringPanelEvent': true});

  ExtensionService granted() => ExtensionService()..radioCalls.allow([panelExtension('panel')]);

  test('only what a tapped spot carries reaches the logging fields', () async {
    final extensions = granted();
    final suggested = <Map<String, dynamic>>[];
    extensions.onSuggestQso = (qso, _) {
      suggested.add(qso);
      return true;
    };
    final answer = await suggest(extensions, {
      'qso': {
        'their': {'call': ' K1ABC ', 'name': 'Al'},
        'freq': 14074,
        'band': '20m',
        'mode': 'FT8',
        'refs': [
          {
            'type': 'pota',
            'ref': 'US-1234',
            'name': 'Somewhere SP',
            'nested': {'x': 1},
          },
          {'type': 'pota'},
          'not a ref',
        ],
        // A contact's own fields: an extension prefilling one must never set them.
        'startAtMillis': 1,
        'our': {'call': 'N0DEV'},
        'rst': '59',
      },
    });
    expect(answer, {'accepted': true});
    expect(suggested.single, {
      'their': {'call': 'K1ABC'},
      'freq': 14074.0,
      'band': '20m',
      'mode': 'FT8',
      // As a tap passes it, but plain fields only: the fields hold what a QSO keeps.
      'refs': [
        {'type': 'pota', 'ref': 'US-1234', 'name': 'Somewhere SP'},
      ],
    });
  });

  test('a suggestion without a call is refused, and with nothing to take it is not accepted', () async {
    final extensions = granted();
    expect(() => suggest(extensions, {'qso': <String, dynamic>{}}), throwsFormatException);
    expect(
      await suggest(extensions, {
        'qso': {
          'their': {'call': 'K1ABC'},
        },
      }),
      {'accepted': false},
    );
  });

  group('in the app', () {
    late HaLoServices services;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.load();
      final db = HaLoDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      services = HaLoServices(db, settings, extensions: granted());
    });

    Future<Object?> fromPanelOf(String uuid) => suggest(services.extensions, {
      'qso': {
        'their': {'call': 'K1ABC'},
      },
      'operationUuid': uuid,
    });

    test('fills the operation in front as a spot tap does, and only the panel\'s own', () async {
      final filled = <String>[];
      services.openOperationContext('op-1').suggestSpot = (_) => filled.add('op-1');
      expect(await fromPanelOf('op-1'), {'accepted': true});
      expect(await fromPanelOf('op-2'), {'accepted': false});
      // Another operation pushed over it: the first one's panel no longer fills anything.
      services.openOperationContext('op-2').suggestSpot = (_) => filled.add('op-2');
      expect(await fromPanelOf('op-1'), {'accepted': false});
      expect(filled, ['op-1']);
    });
  });

  // Through the real kernel: the host checks the grant and whether a panel event is running, and
  // only the kernel can say either about the caller rather than take the caller's word for it.
  group('through the kernel', () {
    String probe(String key) =>
        '''
      globalThis.__polo.defineExtension({
        key: '$key',
        name: '$key probe',
        version: '0.0.1',
        onActivation({ registerHook, hostCall }) {
          const suggest = (extra) => hostCall('suggestQso', { qso: { their: { call: 'K1ABC' } }, ...extra })
          registerHook('panel', { key: '$key', hook: { onEvent: async (args) => await suggest(args.extra ?? {}) } })
          registerHook('bench', { key: '$key', hook: { call: async (args) => await suggest(args.extra ?? {}) } })
        },
      });
    ''';

    late ExtensionService extensions;
    late List<String> filled;

    setUp(() async {
      filled = [];
      extensions = ExtensionService()
        ..onSuggestQso = (qso, _) {
          filled.add((qso['their'] as Map)['call'] as String);
          return true;
        };
      prepareExtensionServiceForTest(extensions);
      await extensions.setDevBundles({
        'map': (source: probe('map'), info: panelExtension('map')),
        'plain': (source: probe('plain'), info: panelExtension('plain', write: false)),
      });
    });

    Future<dynamic> fromPanel(String who, [Map<String, dynamic> extra = const {}]) =>
        extensions.host!.invokeHook('panel', key: who, method: 'onEvent', args: {'extra': extra}, timeout: const Duration(seconds: 10));
    Future<dynamic> fromElsewhere(String who, [Map<String, dynamic> extra = const {}]) =>
        extensions.host!.invokeHook('bench', key: who, method: 'call', args: {'extra': extra}, timeout: const Duration(seconds: 10));
    Matcher blocked(String why) => throwsA(isA<ExtensionHostException>().having((e) => e.toString(), 'message', contains(why)));

    test('a panel answering a click fills the fields; the same call from anywhere else does not', () async {
      expect(await fromPanel('map'), {'accepted': true});
      await expectLater(fromElsewhere('map'), blocked('outside its panel'));
      // The stamp is the kernel's, laid over whatever the call carries.
      await expectLater(fromElsewhere('map', {'duringPanelEvent': true}), blocked('outside its panel'));
      expect(filled, ['K1ABC']);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('it tunes the radio, so it needs requiresRadioWrite, and naming one that has it borrows nothing', () async {
      await expectLater(fromPanel('plain'), blocked('requiresRadioWrite'));
      await expectLater(fromPanel('plain', {'extensionKey': 'map'}), blocked('requiresRadioWrite'));
      expect(filled, isEmpty);
    }, timeout: const Timeout(Duration(seconds: 60)));
  });
}
