// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:ham2k_logger/services/extension_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingsService settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = SettingsService(await SharedPreferences.getInstance());
  });

  test('getSettingsPanels flattens getPanels entries and sorts by order', () async {
    final mockHost = MockExtensionHost({
      'settingsPanel:*:getPanels': [
        {
          'key': 'pota_spots',
          'ok': true,
          'value': {'panelKey': 'pota_spots', 'hookKey': 'pota', 'extensionKey': 'pota', 'title': 'POTA Spots', 'kind': 'dynamic', 'order': 2},
        },
        {
          'key': 'pota',
          'ok': true,
          'value': {'panelKey': 'pota', 'hookKey': 'pota', 'extensionKey': 'pota', 'title': 'POTA', 'kind': 'dynamic', 'order': 1},
        },
        // A failed entry (e.g. getPanels() threw) must not appear.
        {'key': 'broken', 'ok': false, 'error': 'boom'},
      ],
    });
    final extensions = MockExtensionService(mockHost)..settings = settings;

    final panels = await extensions.getSettingsPanels();

    expect(panels.length, 2);
    expect(panels[0]['panelKey'], 'pota'); // order 1 before order 2
    expect(panels[1]['panelKey'], 'pota_spots');
  });

  test('getSettingsPanelDefinition overlays stored values for a Tier 1 (simple) panel', () async {
    final mockHost = MockExtensionHost({
      'settingsPanel:pota:getDefinition': {
        'title': 'POTA',
        'elements': [
          {'type': 'field', 'fieldType': 'text', 'key': 'apiKey', 'label': 'API Key', 'value': 'default'},
        ],
      },
    });
    final extensions = MockExtensionService(mockHost)..settings = settings;

    // Nothing stored yet: the static default from the definition survives.
    final firstLoad = await extensions.getSettingsPanelDefinition(hookKey: 'pota', panelKey: 'pota', kind: 'simple');
    expect((firstLoad!['elements'] as List).first['value'], 'default');

    // Commit a new value, then re-fetch: the overlay now wins over the static default.
    await extensions.commitSettingsFieldValue(
      kind: 'simple',
      hookKey: 'pota',
      panelKey: 'pota',
      fieldKey: 'apiKey',
      value: 'committed-value',
      state: const {},
    );
    final secondLoad = await extensions.getSettingsPanelDefinition(hookKey: 'pota', panelKey: 'pota', kind: 'simple');
    expect((secondLoad!['elements'] as List).first['value'], 'committed-value');
  });

  test('getSettingsPanelDefinition does not overlay values for a Tier 2 (dynamic) panel', () async {
    final mockHost = MockExtensionHost({
      'settingsPanel:lofi:getDefinition': {
        'title': 'LoFi',
        'elements': [
          {'type': 'field', 'fieldType': 'text', 'key': 'endpoint', 'label': 'Endpoint', 'value': 'from-extension'},
        ],
      },
    });
    final extensions = MockExtensionService(mockHost)..settings = settings;

    // Even though Dart storage has a value for this key (as if left over
    // from another panel), a dynamic panel must never see it — Tier 2 owns
    // its own persistence entirely.
    await extensions.commitSettingsFieldValue(
      kind: 'simple',
      hookKey: 'lofi',
      panelKey: 'lofi',
      fieldKey: 'endpoint',
      value: 'stale-tier1-leftover',
      state: const {},
    );

    final definition = await extensions.getSettingsPanelDefinition(hookKey: 'lofi', panelKey: 'lofi', kind: 'dynamic');
    expect((definition!['elements'] as List).first['value'], 'from-extension');
  });

  test('getSettingsPanelDefinition never persists fieldType account through settings storage', () async {
    final mockHost = MockExtensionHost({
      'settingsPanel:pota:getDefinition': {
        'title': 'POTA',
        'elements': [
          {
            'type': 'field',
            'fieldType': 'account',
            'key': 'qrzStatus',
            'label': 'QRZ.com Account',
            'account': {'key': 'qrz'},
          },
        ],
      },
    });
    // No account credentials override in this test — getAccountCredentials
    // hits real (unmocked) secure storage and throws, exercising
    // _resolveAccountStatus's own guard, which must fall back to
    // {connected: false} rather than let the exception take down the whole
    // panel fetch.
    final extensions = MockExtensionService(mockHost)..settings = settings;

    await extensions.commitSettingsFieldValue(
      kind: 'simple',
      hookKey: 'pota',
      panelKey: 'pota',
      fieldKey: 'qrzStatus',
      value: 'should-never-be-read-back-as-account-status',
      state: const {},
    );

    final definition = await extensions.getSettingsPanelDefinition(hookKey: 'pota', panelKey: 'pota', kind: 'simple');
    expect((definition!['elements'] as List).first['value'], {'connected': false});
  });

  test('getSettingsPanelDefinition resolves fieldType account to {connected: true, label} from account credentials, for either tier', () async {
    final mockHost = MockExtensionHost({
      'settingsPanel:pota:getDefinition': {
        'title': 'POTA',
        'elements': [
          {
            'type': 'field',
            'fieldType': 'account',
            'key': 'qrzStatus',
            'label': 'QRZ.com Account',
            'account': {'key': 'qrz'},
          },
        ],
      },
    });
    final extensions = AccountStubExtensionService(mockHost, credentials: {'qrz': {'username': 'KI2D'}})..settings = settings;

    for (final kind in ['simple', 'dynamic']) {
      final definition = await extensions.getSettingsPanelDefinition(hookKey: 'pota', panelKey: 'pota', kind: kind);
      expect((definition!['elements'] as List).first['value'], {'connected': true, 'label': 'Connected as KI2D'});
    }
  });

  test('validateSettingsField: Tier 1 checks pattern locally, no bridge call needed', () async {
    final mockHost = MockExtensionHost(const {}); // no bridge entries registered — a bridge call would return null and hide a real failure
    final extensions = MockExtensionService(mockHost)..settings = settings;

    final field = {'pattern': r'^\d{2}$', 'patternError': 'Exchange must be a 2-digit number'};

    final ok = await extensions.validateSettingsField(
      kind: 'simple',
      hookKey: 'contest',
      panelKey: 'contest',
      field: field,
      fieldKey: 'exchange',
      value: '42',
      state: const {},
    );
    expect(ok, isNull);

    final error = await extensions.validateSettingsField(
      kind: 'simple',
      hookKey: 'contest',
      panelKey: 'contest',
      field: field,
      fieldKey: 'exchange',
      value: 'abc',
      state: const {},
    );
    expect(error, 'Exchange must be a 2-digit number');
  });

  test('validateSettingsField: Tier 1 with a malformed pattern returns an error instead of throwing', () async {
    final mockHost = MockExtensionHost(const {});
    final extensions = MockExtensionService(mockHost)..settings = settings;

    // Unclosed group — RegExp(pattern) throws a FormatException. Must not
    // propagate: FormRenderer's on-blur path has no try/catch around this
    // call, unlike its submit-batch path.
    final field = {'pattern': r'(abc', 'patternError': 'Exchange must be a 2-digit number'};

    final error = await extensions.validateSettingsField(
      kind: 'simple',
      hookKey: 'contest',
      panelKey: 'contest',
      field: field,
      fieldKey: 'exchange',
      value: 'anything',
      state: const {},
    );
    expect(error, isNotNull);
  });

  test('validateSettingsField: Tier 2 forwards to the validateField hook method', () async {
    final mockHost = MockExtensionHost({
      'settingsPanel:lofi:validateField': 'Invalid endpoint URL',
    });
    final extensions = MockExtensionService(mockHost)..settings = settings;

    final error = await extensions.validateSettingsField(
      kind: 'dynamic',
      hookKey: 'lofi',
      panelKey: 'lofi',
      field: const {},
      fieldKey: 'endpoint',
      value: 'not-a-url',
      state: const {},
    );
    expect(error, 'Invalid endpoint URL');
  });

  test('runSettingsAction forwards the action element method and returns the result banner text', () async {
    final mockHost = MockExtensionHost({
      'settingsPanel:qrz:clearCache': 'Cache cleared',
    });
    final extensions = MockExtensionService(mockHost)..settings = settings;

    final result = await extensions.runSettingsAction(
      hookKey: 'qrz',
      panelKey: 'qrz',
      method: 'clearCache',
      state: const {},
    );
    expect(result, 'Cache cleared');
  });

  test('transformSettingsField falls back to the original value when the hook has no transformField method', () async {
    // No 'settingsPanel:core:transformField' entry registered — the bridge
    // call resolves to null, same as a Tier 2 hook that never declared
    // transformField at all. Must not let that null silently replace a
    // real value before it reaches onChangeField/commitSettingsFieldValue.
    final mockHost = MockExtensionHost(const {});
    final extensions = MockExtensionService(mockHost)..settings = settings;

    final result = await extensions.transformSettingsField(
      hookKey: 'core',
      panelKey: 'core',
      fieldKey: 'themeMode',
      value: 'dark',
      state: const {},
    );
    expect(result, 'dark');
  });

  test('transformSettingsField still applies a real transformField result when the hook has one', () async {
    final mockHost = MockExtensionHost({
      'settingsPanel:lofi:transformField': 'TRANSFORMED',
    });
    final extensions = MockExtensionService(mockHost)..settings = settings;

    final result = await extensions.transformSettingsField(
      hookKey: 'lofi',
      panelKey: 'lofi',
      fieldKey: 'endpoint',
      value: 'raw',
      state: const {},
    );
    expect(result, 'TRANSFORMED');
  });

  test('identityFromCredentials picks username, then email, then login, in that order', () {
    expect(ExtensionService.identityFromCredentials({'username': 'KI2D', 'email': 'x@y.com'}), 'KI2D');
    expect(ExtensionService.identityFromCredentials({'email': 'x@y.com', 'login': 'other'}), 'x@y.com');
    expect(ExtensionService.identityFromCredentials({'login': 'ki2d'}), 'ki2d');
    expect(ExtensionService.identityFromCredentials({}), isNull);
  });
}

class MockExtensionHost implements ExtensionHost {
  final Map<String, dynamic> mockHookResults;
  MockExtensionHost(this.mockHookResults);

  @override
  Future<dynamic> invokeHook(
    String category, {
    String? key,
    required String method,
    Object? args,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final hookKey = '$category:$key:$method';
    if (mockHookResults.containsKey(hookKey)) {
      final res = mockHookResults[hookKey];
      if (res is Function) return res(args);
      return res;
    }
    return null;
  }

  @override
  Future<List<Map<String, dynamic>>> invokeHookAll(
    String category, {
    required String method,
    Object? args,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final hookKey = '$category:*:$method';
    if (mockHookResults.containsKey(hookKey)) {
      return (mockHookResults[hookKey] as List).cast<Map<String, dynamic>>();
    }
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockExtensionService extends ExtensionService {
  final MockExtensionHost mockHost;
  MockExtensionService(this.mockHost);

  @override
  ExtensionHost? get host => mockHost;
}

/// Stubs [getAccountCredentials] with canned data instead of hitting real
/// (unmocked in tests) secure storage — for exercising the "account is
/// actually connected" branch of account-status resolution.
class AccountStubExtensionService extends MockExtensionService {
  final Map<String, Map<String, String>> credentials;
  AccountStubExtensionService(super.mockHost, {required this.credentials});

  @override
  Future<Map<String, String>> getAccountCredentials(String kvKey) async => credentials[kvKey] ?? const {};
}
