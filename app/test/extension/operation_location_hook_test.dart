// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';

import '../support/shipped_extensions.dart';

({String source, ExtensionInfo info}) _bundle(String key, {required String answer, bool granted = true, bool declares = true, String? impersonate}) => (
  source:
      '''
    globalThis.__halo.defineExtension({
      key: '$key', name: '$key', version: '1.0.0',
      onActivation({ registerHook }) {
        const received = [];
        const hook = { resolve: async (args) => { received.push(args); return $answer; } };
        registerHook('operationLocation', { hook });
        ${impersonate == null ? '' : "registerHook('operationLocation', { key: '$impersonate', hook, priority: 100 });"}
        registerHook('bench', { hook: { received: async () => received } });
      },
    });
  ''',
  info: ExtensionInfo(
    key: key,
    file: '$key.js',
    source: ExtensionSource.dev,
    core: true,
    name: key,
    hooks: ['bench', if (declares) HookCategories.operationLocation],
    requiresLocation: granted,
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('only granted declared providers see the fix, and competing subdivisions stay choices', () async {
    final extensions = ExtensionService();
    prepareExtensionServiceForTest(extensions);
    await extensions.setDevBundles({
      'trusted-boundary': _bundle('trusted-boundary', answer: "{ state: 'ri', county: 'Kent' }"),
      'second-boundary': _bundle(
        'second-boundary',
        answer: '''
          args.accuracyMeters > 40 ? { candidates: [{ state: 'New Brunswick' }, { state: 'RI', county: 'Kent' }] } :
          args.accuracyMeters > 30 ? { state: 'New Brunswick' } :
          { state: 'RI', county: args.accuracyMeters > 20 ? 'Providence' : 'kent' }
        ''',
      ),
      'malformed-boundary': _bundle('malformed-boundary', answer: "{ state: 44, candidates: [{ county: 'Kent' }, true, { state: 'RI', county: 3 }] }"),
      'plain-boundary': _bundle('plain-boundary', answer: "{ state: 'CT' }", granted: false, impersonate: 'trusted-boundary'),
      'undeclared-boundary': _bundle('undeclared-boundary', answer: "{ state: 'CT' }", declares: false),
    });

    const fix = GridLocation(41.7, -71.5);
    final agreed = await extensions.resolveOperationLocation(fix, accuracyMeters: 15);
    expect(agreed.state, 'RI');
    expect(agreed.county, equalsIgnoringCase('Kent'));
    expect(agreed.candidates, isEmpty);

    final ambiguous = await extensions.resolveOperationLocation(fix, accuracyMeters: 25);
    expect(ambiguous.state, 'RI');
    expect(ambiguous.county, isNull);
    expect(ambiguous.candidates, unorderedEquals([(state: 'RI', county: 'Kent'), (state: 'RI', county: 'Providence')]));

    const stateLineChoices = [(state: 'RI', county: 'Kent'), (state: 'New Brunswick', county: null)];
    final competingStates = await extensions.resolveOperationLocation(fix, accuracyMeters: 35);
    expect(competingStates.state, isNull);
    expect(competingStates.county, isNull);
    expect(competingStates.candidates, unorderedEquals(stateLineChoices));

    final stateOnlyCandidate = await extensions.resolveOperationLocation(fix, accuracyMeters: 45);
    expect(stateOnlyCandidate.state, isNull);
    expect(stateOnlyCandidate.county, isNull);
    expect(stateOnlyCandidate.candidates, unorderedEquals(stateLineChoices));

    Future<dynamic> received(String key) => extensions.host!.invokeHook('bench', key: key, method: 'received');
    expect(await received('trusted-boundary'), [
      for (final accuracy in [15, 25, 35, 45]) {'latitude': 41.7, 'longitude': -71.5, 'accuracyMeters': accuracy},
    ]);
    expect(await received('plain-boundary'), isEmpty);
    expect(await received('undeclared-boundary'), isEmpty);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
