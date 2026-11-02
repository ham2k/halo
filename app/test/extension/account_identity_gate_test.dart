// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Account credentials, settings groups and dynamic forms belong to an identity
// the kernel derives from which bundle is calling, never to what a host call
// says. Each test here is one bundle claiming to be another, driven through
// the REAL kernel by hand-written probe bundles that reach for `__polo`
// directly: the SDK's own wrappers never make these calls, so a test through
// them would prove nothing about the host. In-runtime composition
// (`invokeLocal`) is held by halo_extension_host's composition_allowlist_test.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/shipped_extensions.dart';

/// Owns an account, and reports what its hooks and forms are handed.
const victim = r'''
  globalThis.__polo.defineExtension({
    key: 'victim',
    name: 'victim',
    version: '0.0.1',
    onActivation(api) {
      api.registerHook('account', { hook: { label: 'Victim', fields: [], testCredentials: async () => 'ok' } });
      api.registerHook('bench', {
        hook: {
          call: async (args, ctx) => {
            switch (args.probe) {
              case 'ownForm':
                api.registerDynamicForm('own', { grab: async (a, c) => ({ account: c.account ?? null }) });
                return null;
              case 'dropOwnForm':
                api.unregisterDynamicForm('own');
                return null;
              case 'holdForm':
                api.registerDynamicForm('login', { grab: async (a, c) => ({ owner: 'victim', account: c.account ?? null }) });
                return null;
              case 'dropForm':
                api.unregisterDynamicForm('login');
                return null;
            }
            return { account: ctx.account ?? null };
          },
        },
      });
    },
  });
''';

/// Claims the victim's account, forms and traffic every way the public
/// kernel surface allows.
const thief = r'''
  const polo = globalThis.__polo;
  const originalHostResponse = polo.hostResponse;
  const originalQsonTools = polo.sharedModules['@ham2k/lib-qson-tools'];
  const originalParse = JSON.parse;
  let wrapperCalls = 0;
  globalThis.__polo.defineExtension({
    key: 'thief',
    name: 'thief',
    version: '0.0.1',
    onActivation(api) {
      api.registerHook('account', { hook: { label: 'Thief', kvKey: 'victim', fields: [], testCredentials: async () => 'ok' } });
      api.registerHook('bench', {
        hook: {
          call: async (args, ctx) => {
            switch (args.probe) {
              case 'account':
                return { account: ctx.account ?? null };
              case 'publicSetSettings':
                return await polo.hostCall('setSettings', { ns: 'victim', values: { pwned: true } });
              case 'boundSetSettings':
                return await api.hostCall('setSettings', { ns: 'victim', values: { pwned: true } });
              case 'forgedForm':
                polo.registerDynamicForm('forged', 'victim', { grab: async (a, c) => ({ account: c.account ?? null }) });
                return null;
              case 'dropForgedForm':
                polo.unregisterDynamicForm('forged');
                return null;
              case 'claimForm':
                polo.registerDynamicForm('login', 'victim', { grab: async () => ({ owner: 'thief' }) });
                return null;
              case 'publicUnregister':
                polo.unregisterDynamicForm('login');
                return null;
              case 'boundUnregister':
                api.unregisterDynamicForm('login');
                return null;
              case 'tamper': {
                try { globalThis.__polo = { hostResponse() {} }; } catch (e) {}
                try { polo.hostResponse = function () {}; } catch (e) {}
                try { polo.host.showForm = async () => null; } catch (e) {}
                try { polo.sharedModules['@ham2k/lib-qson-tools'] = {}; } catch (e) {}
                try { JSON.parse = (s) => { wrapperCalls++; return originalParse(s); }; } catch (e) {}
                return {
                  frozen: Object.isFrozen(globalThis.__polo),
                  sameKernel: globalThis.__polo === polo,
                  hostResponseIntact: polo.hostResponse === originalHostResponse,
                  sharedIntact: polo.sharedModules['@ham2k/lib-qson-tools'] === originalQsonTools,
                  jsonIntact: JSON.parse === originalParse,
                };
              }
              case 'wrapperCalls':
                return { wrapperCalls };
              case 'boundFormApi':
                return { showForm: typeof api.showForm, register: typeof api.registerDynamicForm, unregister: typeof api.unregisterDynamicForm };
            }
            return null;
          },
        },
      });
    },
  });
''';

({String source, ExtensionInfo info}) bundle(String key, String source) =>
    (source: source, info: ExtensionInfo(key: key, file: '$key.js', source: ExtensionSource.dev, core: true, name: key));

const victimCredentials = {'username': 'v', 'password': 'p'};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ExtensionService extensions;
  late SettingsService settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = await SettingsService.load();
    extensions = ExtensionService()..settings = settings;
    prepareExtensionServiceForTest(extensions);
    await extensions.setAccountCredentials('victim', victimCredentials);
    await extensions.setDevBundles({'victim': bundle('victim', victim), 'thief': bundle('thief', thief)});
  });

  Future<dynamic> call(String who, String probe) =>
      extensions.host!.invokeHook('bench', key: who, method: 'call', args: {'probe': probe}, timeout: const Duration(seconds: 10));

  Map<String, dynamic> accountOf(dynamic result) => ((result as Map)['account'] as Map).cast<String, dynamic>();

  /// What every record registered under form id [formId] answers, asked the
  /// way the app asks a form: over the bridge, never from inside the runtime.
  Future<List<Map<String, dynamic>>> formAnswers(String formId) async =>
      (await extensions.host!.invokeHookAll('form', method: 'grab', timeout: const Duration(seconds: 10))).where((e) => e['key'] == formId).toList();

  /// The one answer form id [formId] gives, as a map.
  Future<Map<String, dynamic>> theOnlyAnswer(String formId) async {
    final list = await formAnswers(formId);
    expect(list, hasLength(1), reason: 'one record per form id');
    final entry = list.single as Map;
    expect(entry['ok'], true, reason: '${entry['error']}');
    return (entry['value'] as Map).cast<String, dynamic>();
  }

  Matcher refusedWith(String fragment) => throwsA(isA<ExtensionHostException>().having((e) => e.toString(), 'message', contains(fragment)));

  test('an extension reads its own account: through its hooks, and through a dynamic form it registered itself', () async {
    expect(accountOf(await call('victim', 'account'))['credentials'], victimCredentials);
    await call('victim', 'ownForm');
    addTearDown(() async {
      await call('victim', 'dropOwnForm');
      expect(await formAnswers('own'), isEmpty, reason: 'a form left registered answers every later grab in this file');
    });
    expect(accountOf(await theOnlyAnswer('own'))['credentials'], victimCredentials);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test("an account hook naming another extension's kvKey gets its own, empty account, and the kernel says why", () async {
    expect(accountOf(await call('thief', 'account'))['credentials'], isEmpty);
    expect(extensions.host!.logLines, anyElement(contains("kvKey 'victim' must equal 'thief'")));
  }, timeout: const Timeout(Duration(seconds: 60)));

  test("the host refuses an account outside the caller's namespace on its own, whatever the kernel stamped", () async {
    await expectLater(extensions.debugHandleHostCall('getAccount', {'ns': 'thief', 'kvKey': 'victim'}), refusedWith('outside its own namespace'));
    await expectLater(
      extensions.debugHandleHostCall('setAccountSession', {
        'ns': 'thief',
        'kvKey': 'victim',
        'session': {'token': 'x'},
      }),
      refusedWith('outside its own namespace'),
    );
    // No key at all is a refusal too, not a type error out of the gate.
    await expectLater(extensions.debugHandleHostCall('getAccount', {'ns': 'thief'}), refusedWith('outside its own namespace'));
    expect(((await extensions.debugHandleHostCall('getAccount', {'ns': 'victim', 'kvKey': 'victim'})) as Map)['credentials'], victimCredentials);
    // A sub-key stays inside the namespace.
    expect(((await extensions.debugHandleHostCall('getAccount', {'ns': 'victim', 'kvKey': 'victim_xml'})) as Map)['credentials'], isEmpty);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('setSettings lands in the calling extension\'s own group whatever ns it names, and the public path refuses it', () async {
    await expectLater(call('thief', 'publicSetSettings'), refusedWith('identity'));
    await call('thief', 'boundSetSettings');
    expect(settings.settingsGroup('extension_thief'), {'pwned': true});
    expect(settings.settingsGroup('extension_victim'), isEmpty);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test("a dynamic form registered under another extension's key is handed no account", () async {
    await call('thief', 'forgedForm');
    addTearDown(() async {
      await call('thief', 'dropForgedForm');
      expect(await formAnswers('forged'), isEmpty, reason: 'a form left registered answers every later grab in this file');
    });
    expect((await theOnlyAnswer('forged'))['account'], isNull);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test("a live form id cannot be joined or unregistered by another extension", () async {
    await call('victim', 'holdForm');
    // Claiming the id registers nothing: the victim's record alone answers.
    await call('thief', 'claimForm');
    expect((await theOnlyAnswer('login'))['owner'], 'victim');
    expect(extensions.host!.logLines, anyElement(contains("registerDynamicForm('login') as victim: the id is in use by victim")));
    // Neither the public entry nor the thief's own bound entry removes it.
    await call('thief', 'publicUnregister');
    expect((await theOnlyAnswer('login'))['owner'], 'victim');
    await call('thief', 'boundUnregister');
    expect((await theOnlyAnswer('login'))['owner'], 'victim');
    // The owner's does.
    await call('victim', 'dropForm');
    expect(await formAnswers('login'), isEmpty);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('the kernel can be neither replaced nor rewritten from a bundle, and JSON stays its own', () async {
    expect(await call('thief', 'tamper'), {'frozen': true, 'sameKernel': true, 'hostResponseIntact': true, 'sharedIntact': true, 'jsonIntact': true});
    // The same runtime answers afterwards, and its traffic crossed no wrapper.
    expect(accountOf(await call('victim', 'account'))['credentials'], victimCredentials);
    expect(await call('thief', 'wrapperCalls'), {'wrapperCalls': 0});
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('activation hands out form entries bound to the extension', () async {
    expect(await call('thief', 'boundFormApi'), {'showForm': 'function', 'register': 'function', 'unregister': 'function'});
  }, timeout: const Timeout(Duration(seconds: 60)));
}
