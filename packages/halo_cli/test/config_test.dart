// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:convert';
import 'dart:io';

import 'package:halo_cli/src/config.dart';
import 'package:halo_cli/src/runtime.dart' show CliUsageError;
import 'package:test/test.dart';

void main() {
  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync('halo-cli-config'));
  tearDown(() => temp.deleteSync(recursive: true));

  File configWith(Map<String, Object?> json) =>
      File('${temp.path}/halo-cli.json')..writeAsStringSync(jsonEncode(json));

  group('loading', () {
    test('a missing default file is a fresh start, a missing NAMED one is a typo', () {
      // The asymmetry is the point: most commands need no configuration, but
      // an operator who passed --config meant to pass credentials, and
      // running the command without them would look like the extension had
      // none rather than like the file was misspelled.
      expect(() => CliConfig.load(path: '${temp.path}/nope.json'), throwsA(isA<CliUsageError>()));
      expect(() => CliConfig.load(environment: {'XDG_CONFIG_HOME': temp.path}), returnsNormally);
    });

    test('malformed JSON names the file instead of throwing a decoder error', () {
      File('${temp.path}/bad.json').writeAsStringSync('{not json');
      expect(
        () => CliConfig.load(path: '${temp.path}/bad.json'),
        throwsA(isA<CliUsageError>().having((e) => e.message, 'message', contains('bad.json'))),
      );
    });

    test('settings merge OVER the defaults rather than replacing them', () {
      // An extension reading `showRSTFields` must not get null just because
      // the operator set one unrelated key — every key in the app's
      // getSettings view has to survive a partial config.
      final config = CliConfig.load(path: configWith({
        'settings': {'operatorCall': 'KI2D'}
      }).path);
      expect(config.settings['operatorCall'], 'KI2D');
      expect(config.settings['showRSTFields'], true);
      expect(config.settings['bands'], defaultSettings['bands']);
    });
  });

  group('accounts', () {
    test('an unknown account reads as empty, never as null', () {
      // The kernel turns a null host answer into `undefined`, which an
      // extension reads as a logged-out account. Empty maps say the same
      // thing without depending on how the bridge encodes absence.
      final account = CliConfig.load(environment: {'XDG_CONFIG_HOME': temp.path}).accountFor('qrz');
      expect(account['credentials'], isEmpty);
      expect(account['session'], isEmpty);
    });

    test('a session write survives a reload', () {
      final path = configWith({
        'accounts': {
          'qrz': {
            'credentials': {'username': 'KI2D'}
          }
        }
      }).path;
      CliConfig.load(path: path).setAccountSession('qrz', {'key': 'abc123'});

      final reloaded = CliConfig.load(path: path).accountFor('qrz');
      expect((reloaded['session'] as Map)['key'], 'abc123');
      // The write must not clobber what it did not touch.
      expect((reloaded['credentials'] as Map)['username'], 'KI2D');
    });
  });

  test('extension settings writes are namespaced to the calling extension', () {
    // `setSettings` carries an SDK-injected `ns`; storing under the raw name
    // would let one extension's group collide with another's, and would not
    // be readable back as the `extension_<ns>` key the app uses.
    final path = configWith(const {}).path;
    CliConfig.load(path: path).setExtensionSettings('pota', {'showSpots': true});
    expect(CliConfig.load(path: path).settingsGroups['extension_pota'], {'showSpots': true});
  });

  group('the environment', () {
    test('supplies secrets to the run but never persists them', () {
      // Persisting one would quietly turn a one-off `HALO_SECRET_…` — a CI
      // variable, a value pasted for a single command — into a credential
      // stored on disk that the operator never chose to save.
      final path = configWith({
        'secrets': {'TOTA_API_KEY': 'from-file'}
      }).path;
      final config = CliConfig.load(path: path, environment: {'HALO_SECRET_SOTA_OAUTH_CLIENT_ID': 'from-env'});
      expect(config.secrets['SOTA_OAUTH_CLIENT_ID'], 'from-env');

      config.save();
      final saved = (jsonDecode(File(path).readAsStringSync()) as Map)['secrets'] as Map;
      expect(saved['TOTA_API_KEY'], 'from-file');
      expect(saved.containsKey('SOTA_OAUTH_CLIENT_ID'), isFalse);
    });

    test('overrides a setting the file also sets, and parses its JSON', () {
      final path = configWith({
        'settings': {'developerMode': false, 'locale': 'en'}
      }).path;
      final config = CliConfig.load(path: path, environment: {
        'HALO_SETTING_developerMode': 'true',
        'HALO_SETTING_locale': 'es',
      });
      // `true` the boolean, not "true" the string — an extension branching on
      // it would take the wrong path on a truthy string.
      expect(config.settings['developerMode'], isTrue);
      expect(config.settings['locale'], 'es');
    });
  });
}
