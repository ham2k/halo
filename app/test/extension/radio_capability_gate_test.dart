// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The radio host calls are manifest capabilities (`requiresRadioRead`,
// `requiresRadioWrite`). Ungated, any installed bundle could retune the rig,
// drop the CAT link or key the transmitter from any hook, with nothing in its
// manifest saying so.
//
// Driven through the REAL kernel with hand-written probe bundles, because the
// gate has two halves and either alone is worthless: the host checks a key, and
// the kernel is what makes that key the caller's own rather than an argument.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/panel_radio_service.dart';

String probe(String key) =>
    '''
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
  Future<Map<String, dynamic>> set(Map<String, dynamic> args) async {
    commands.add('set');
    return {'accepted': true, 'state': null};
  }

  @override
  Map<String, dynamic> sendCw(Map<String, dynamic> args) {
    commands.add('cw');
    return {'accepted': true, 'state': null};
  }

  @override
  Map<String, dynamic> playVoice(Map<String, dynamic> args) {
    commands.add('voice');
    return {'accepted': true, 'state': null};
  }

  @override
  Map<String, dynamic> setPtt(Map<String, dynamic> args) {
    commands.add('ptt');
    return {'accepted': true, 'state': null};
  }

  @override
  Map<String, dynamic> stopTransmit(Map<String, dynamic> args) {
    commands.add('stop');
    return {'accepted': true, 'state': null};
  }

  @override
  Map<String, dynamic> setSpectrum(Map<String, dynamic> args) {
    commands.add('spectrum');
    return {'accepted': true, 'state': null};
  }
}

({String source, ExtensionInfo info}) bundle(String key, {bool read = false, bool write = false}) => (
  source: probe(key),
  info: ExtensionInfo(key: key, file: '$key.js', source: ExtensionSource.dev, core: true, name: key, requiresRadioRead: read, requiresRadioWrite: write),
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
      // A separately installed bundle NAMED like a sub-extension of `writer`.
      'writer-themes': bundle('writer-themes'),
    });
  });

  Future<dynamic> call(String who, String method, [Map<String, dynamic> params = const {}]) =>
      extensions.host!.invokeHook('bench', key: who, method: 'call', args: {'method': method, 'params': params}, timeout: const Duration(seconds: 10));

  // Every call that commands a radio, with arguments it would accept. The
  // keying calls are here because they put the transmitter on the air.
  const writes = <String, Map<String, dynamic>>{
    'setRadio': {'id': 'a', 'frequencyHz': 7000000},
    'tuneRadio': {'id': 'a', 'frequencyHz': 7000000},
    'setRadioConnection': {'id': 'a', 'connected': false},
    'setRadioSpectrum': {'id': 'a', 'spanHz': 50000},
    'sendRadioCw': {'id': 'a', 'text': 'CQ'},
    'playRadioVoice': {'id': 'a', 'memory': 1},
    'setRadioPtt': {'id': 'a', 'on': true},
    'stopRadioTransmit': {'id': 'a'},
  };

  Matcher blockedFor(String capability) => throwsA(isA<ExtensionHostException>().having((e) => e.toString(), 'message', contains(capability)));

  test('an extension that declares nothing can neither read nor command a radio', () async {
    await expectLater(call('plain', 'listRadios'), blockedFor('requiresRadioRead'));
    await expectLater(call('plain', 'readRadio'), blockedFor('requiresRadioRead'));
    for (final MapEntry(key: method, value: params) in writes.entries) {
      await expectLater(call('plain', method, params), blockedFor('requiresRadioWrite'));
    }
    expect(commands, isEmpty);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('read does not grant write', () async {
    expect(await call('reader', 'listRadios'), hasLength(1));
    expect((await call('reader', 'readRadio', {'id': 'b'}) as Map)['id'], 'b');
    // A scope setting moves nothing on the air, but it is still the radio's
    // state another program shares — a reader must not change it, any more
    // than it may key the transmitter.
    for (final MapEntry(key: method, value: params) in writes.entries) {
      await expectLater(call('reader', method, params), blockedFor('requiresRadioWrite'));
    }
    expect(commands, isEmpty);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('write grants both: a command answers with the state a read would', () async {
    for (final MapEntry(key: method, value: params) in writes.entries) {
      expect((await call('writer', method, params) as Map)['accepted'], true, reason: method);
    }
    expect(await call('writer', 'listRadios'), hasLength(1));
    // `tuneRadio` is the API 6 name for `setRadio`, still answered for the
    // bundles built against it.
    expect(commands, ['set', 'set', 'connection', 'spectrum', 'cw', 'voice', 'ptt', 'stop']);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('naming a capable extension in the call does not borrow its capability', () async {
    // The kernel stamps the caller's own key over whatever the params carry.
    // If the radio calls were missing from its identity list, this argument
    // would arrive at the host as-is — and be believed.
    for (final MapEntry(key: method, value: params) in writes.entries) {
      await expectLater(call('plain', method, {...params, 'extensionKey': 'writer'}), blockedFor('requiresRadioWrite'));
    }
    expect(commands, isEmpty);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('a bundle named like a capable one\'s sub-extension does not inherit its capability', () async {
    // Sub-extensions share their bundle's grant (`pota-all-parks` from `pota`),
    // and a bare prefix test is how: but `writer-themes` is a bundle of its
    // own, whose consent screen claimed nothing. Matched by prefix it would
    // retune the rig on `writer`'s say-so.
    await expectLater(call('writer-themes', 'tuneRadio', {'id': 'a', 'frequencyHz': 7000000}), blockedFor('requiresRadioWrite'));
    await expectLater(call('writer-themes', 'listRadios'), blockedFor('requiresRadioRead'));
    expect(commands, isEmpty);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
