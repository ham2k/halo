// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The radio host calls are manifest capabilities (`requiresRadioRead`,
// `requiresRadioWrite`). Ungated, any installed bundle could retune the rig or
// drop the CAT link from any hook, with nothing in its manifest saying so.
//
// Driven through the REAL kernel with hand-written probe bundles, because the
// gate has two halves and either alone is worthless: the host checks a key, and
// the kernel is what makes that key the caller's own rather than an argument.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:ham2k_logger/services/extension_service.dart';
import 'package:ham2k_logger/services/panel_radio_service.dart';

String probe(String key) => '''
  globalThis.__polo.defineExtension({
    key: '$key',
    name: '$key probe',
    version: '0.0.1',
    onActivation({ registerHook, hostCall }) {
      registerHook('bench', {
        key: '$key',
        hook: {
          call: async (args) => await hostCall(args.method, args.params ?? {}),
        },
      });
    },
  });
''';

class FakeRadio extends Fake implements PanelRadioService {
  final commands = <String>[];
  @override
  List<Map<String, dynamic>> list() => [
    {'id': 'a'},
  ];
  @override
  Map<String, dynamic> read([String? selection]) => {'id': selection ?? 'a'};
  @override
  Map<String, dynamic> setConnection(Map<String, dynamic> args) {
    commands.add('connection');
    return {'accepted': true, 'state': null};
  }

  @override
  Future<Map<String, dynamic>> tune(Map<String, dynamic> args) async {
    commands.add('tune');
    return {'accepted': true, 'state': null};
  }
}

({String source, ExtensionInfo info}) bundle(String key, {bool read = false, bool write = false}) => (
  source: probe(key),
  info: ExtensionInfo(
    key: key,
    file: '$key.js',
    source: ExtensionSource.dev,
    core: true,
    name: key,
    requiresRadioRead: read,
    requiresRadioWrite: write,
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ExtensionService extensions;
  late List<String> commands;

  setUp(() async {
    final radio = FakeRadio();
    commands = radio.commands;
    extensions = ExtensionService()..radioCalls.radio = radio;
    await extensions.setDevBundles({
      'reader': bundle('reader', read: true),
      'writer': bundle('writer', write: true),
      'plain': bundle('plain'),
    });
  });

  Future<dynamic> call(String who, String method, [Map<String, dynamic> params = const {}]) =>
      extensions.host!.invokeHook(
        'bench',
        key: who,
        method: 'call',
        args: {'method': method, 'params': params},
        timeout: const Duration(seconds: 10),
      );

  Matcher blockedFor(String capability) =>
      throwsA(isA<ExtensionHostException>().having((e) => e.toString(), 'message', contains(capability)));

  test('an extension that declares nothing can neither read nor command a radio', () async {
    await expectLater(call('plain', 'listRadios'), blockedFor('requiresRadioRead'));
    await expectLater(call('plain', 'readRadio'), blockedFor('requiresRadioRead'));
    await expectLater(call('plain', 'tuneRadio', {'id': 'a', 'frequencyHz': 7000000}), blockedFor('requiresRadioWrite'));
    await expectLater(
      call('plain', 'setRadioConnection', {'id': 'a', 'connected': false}),
      blockedFor('requiresRadioWrite'),
    );
    expect(commands, isEmpty);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('read does not grant write', () async {
    expect(await call('reader', 'listRadios'), hasLength(1));
    expect((await call('reader', 'readRadio', {'id': 'b'}) as Map)['id'], 'b');
    await expectLater(call('reader', 'tuneRadio', {'id': 'a', 'frequencyHz': 7000000}), blockedFor('requiresRadioWrite'));
    expect(commands, isEmpty);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('write grants both: a command answers with the state a read would', () async {
    expect((await call('writer', 'tuneRadio', {'id': 'a', 'frequencyHz': 7000000}) as Map)['accepted'], true);
    expect((await call('writer', 'setRadioConnection', {'id': 'a', 'connected': false}) as Map)['accepted'], true);
    expect(await call('writer', 'listRadios'), hasLength(1));
    expect(commands, ['tune', 'connection']);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('naming a capable extension in the call does not borrow its capability', () async {
    // The kernel stamps the caller's own key over whatever the params carry.
    // If the radio calls were missing from its identity list, this argument
    // would arrive at the host as-is — and be believed.
    await expectLater(
      call('plain', 'tuneRadio', {'id': 'a', 'frequencyHz': 7000000, 'extensionKey': 'writer'}),
      blockedFor('requiresRadioWrite'),
    );
    expect(commands, isEmpty);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
