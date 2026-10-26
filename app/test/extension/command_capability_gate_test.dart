// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A `command` hook needs no capability to answer the call field, and it
// controls its own match pattern and preview text — so without this gate any
// installed bundle could flip developer mode, change any catalogued setting,
// drive the radio or file a report the moment the operator pressed Enter on a
// word it chose. A settings action runs only for an extension whose manifest
// says `requiresSettingsWrite`, a radio action only with `requiresRadioWrite`,
// a developer action only for the app's own. Driven through the REAL kernel
// with probe bundles, because the extension an answer is attributed to is the
// kernel's record of who answered, not the answer's own word.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/shipped_extensions.dart';

/// One extension, [key], answering a few words with one action each.
String probe(String key) =>
    '''
  globalThis.__polo.defineExtension({
    key: '$key',
    name: '$key probe',
    version: '0.0.1',
    onActivation({ registerHook }) {
      ${hook()}
    },
  });
''';

/// A bundle [key] that defines its command hook in a sub-extension of its
/// own, `<key>-cmds`, the way `pota` defines `pota-all-parks`.
String probeWithSub(String key) =>
    '''
  globalThis.__polo.defineExtension({ key: '$key', name: '$key probe', version: '0.0.1', onActivation() {} });
  globalThis.__polo.defineExtension({
    key: '$key-cmds',
    name: '$key commands',
    version: '0.0.1',
    onActivation({ registerHook }) {
      ${hook()}
    },
  });
''';

String hook() => '''
      registerHook('command', {
        hook: {
          interpret: async ({ input }) => {
            switch (input) {
              case 'DEV':
                return { describe: 'Developer mode on', confirm: 'Developer mode on', commands: [{ updateSettings: { developerMode: true } }] };
              case 'THEME':
                return { describe: 'Theme dark', confirm: 'Theme dark', commands: [{ updateSetting: { key: 'theme', value: 'dark' } }] };
              case 'LAYOUTS':
                return { describe: 'Layouts on', confirm: 'Layouts on', commands: [{ toggleExperiment: { token: 'layouts' } }] };
              case 'WPM':
                return { describe: '25 wpm', confirm: '25 wpm', commands: [{ setKeyerSpeed: { wpm: 25 } }] };
              case 'POWER':
                return { describe: '100 W', confirm: '100 W', commands: [{ setPower: { watts: 100 } }] };
              case 'SENTRY':
                return { describe: 'Files a report', confirm: 'Filed', commands: [{ devSentry: { message: 'hi' } }] };
              case 'HELLO':
                return { describe: 'Says hello', confirm: 'Hello', commands: [] };
            }
            return null;
          },
          catalog: async () => [{ command: 'HELLO', describe: 'Says hello' }],
        },
      });
''';

({String source, ExtensionInfo info}) bundle(String key, {bool settingsWrite = false, bool radioWrite = false, bool core = true, String? source}) => (
  source: source ?? probe(key),
  info: ExtensionInfo(
    key: key,
    file: '$key.js',
    source: ExtensionSource.dev,
    core: core,
    name: '$key probe',
    requiresSettingsWrite: settingsWrite,
    requiresRadioWrite: radioWrite,
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ExtensionService extensions;

  setUpAll(() => LocaleSettings.setLocaleRaw('en'));

  /// One probe at a time: every probe answers the same words, and the first
  /// `ok` answer is the one the app runs.
  Future<void> load(({String source, ExtensionInfo info}) only) async {
    extensions = ExtensionService();
    prepareExtensionServiceForTest(extensions);
    await extensions.setDevBundles({only.info.key: only});
  }

  Future<Map<String, dynamic>?> interpret(String input, {bool execute = false}) => extensions.interpretCommand(input, null, null, execute);

  test('a settings action from an extension without the capability is refused, in the preview and at execute time', () async {
    await load(bundle('plain'));
    for (final word in ['DEV', 'THEME', 'LAYOUTS', 'WPM']) {
      for (final execute in [false, true]) {
        final result = await interpret(word, execute: execute);
        expect(result?['error'], t.extensionService.commandMayNotChangeSettings(name: 'plain probe'), reason: '$word execute=$execute');
        expect(result?['commands'], isNull, reason: '$word execute=$execute');
        expect(result?['confirm'], isNull, reason: 'nothing may read as done');
      }
    }
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('a radio action needs the radio grant, and a developer action the app\'s own authorship', () async {
    await load(bundle('plain', core: false));
    expect((await interpret('POWER', execute: true))?['error'], t.extensionService.commandMayNotControlRadio(name: 'plain probe'));
    expect((await interpret('SENTRY', execute: true))?['error'], t.extensionService.commandDeveloperOnly(name: 'plain probe'));

    await load(bundle('rig', radioWrite: true, core: false));
    expect((await interpret('POWER', execute: true))?['commands'], [
      {
        'setPower': {'watts': 100},
      },
    ]);
    expect((await interpret('SENTRY', execute: true))?['error'], t.extensionService.commandDeveloperOnly(name: 'rig probe'));

    await load(bundle('own'));
    expect((await interpret('SENTRY', execute: true))?['commands'], [
      {
        'devSentry': {'message': 'hi'},
      },
    ]);
  }, timeout: const Timeout(Duration(seconds: 90)));

  test('the same extension still answers a command that changes nothing', () async {
    await load(bundle('plain'));
    final result = await interpret('HELLO', execute: true);
    expect(result?['error'], isNull);
    expect(result?['describe'], 'Says hello');
    expect(result?['commands'], isEmpty);
    expect(result?['extensionKey'], 'plain');
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('an extension that declared the capability runs its settings actions, attributed', () async {
    await load(bundle('trusted', settingsWrite: true));
    final result = await interpret('DEV', execute: true);
    expect(result?['error'], isNull);
    expect(result?['commands'], [
      {
        'updateSettings': {'developerMode': true},
      },
    ]);
    expect(result?['extensionKey'], 'trusted');
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('a sub-extension a declaring bundle defines under its own key shares the grant', () async {
    await load(bundle('trusted', settingsWrite: true, source: probeWithSub('trusted')));
    final result = await interpret('DEV', execute: true);
    expect(result?['error'], isNull, reason: 'the grant belongs to the bundle, as every other grant does');
    expect(result?['extensionKey'], 'trusted-cmds');
  }, timeout: const Timeout(Duration(seconds: 60)));

  test(
    "a command from an extension that is not the app's own is described under its name, in the preview and in the palette",
    () async {
      await load(bundle('visitor', core: false));
      expect((await interpret('HELLO'))?['describe'], t.extensionService.commandDescribeBy(describe: 'Says hello', extension: 'visitor probe'));
      final listed = (await extensions.getCommandCatalog()).where((e) => e['command'] == 'HELLO');
      expect(listed.map((e) => e['describe']), [t.extensionService.commandDescribeBy(describe: 'Says hello', extension: 'visitor probe')]);
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test("the app's own command extensions declare what they emit, so SET, DEVMODE, POWER and WPM keep working", () async {
    SharedPreferences.setMockInitialValues({});
    extensions = ExtensionService()..settings = SettingsService(await SharedPreferences.getInstance());
    await startWithShippedExtensions(extensions);
    for (final key in ['settings-commands', 'dev-commands', 'radio-commands']) {
      expect(extensions.extensionInfo(key)?.requiresSettingsWrite, isTrue, reason: key);
    }
    expect(extensions.extensionInfo('radio-commands')?.requiresRadioWrite, isTrue);
  }, timeout: const Timeout(Duration(seconds: 120)));
}
