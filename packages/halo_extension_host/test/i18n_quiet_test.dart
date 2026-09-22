// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// QuickJS-NG has no Intl, so i18next's PluralResolver probes for
// Intl.PluralRules, does not find it, and logs "Your environment seems not to
// be Intl API compatible" through the HOST log. createCachedTranslator builds
// one instance per extension per locale, so that was one ERROR line per
// translator on every platform after the engine swap — noise that looks like a
// real failure and is not. createTranslator now declares compatibilityJSON v3.

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';

import 'support/bundles.dart';

void main() {
  requireBundles();

  test('building a translator logs no Intl-compatibility error', () async {
    // Its OWN host, deliberately not `sharedHost`. This asserts on the host's
    // whole log stream, so a shared host would fold in every other test's
    // output — and the translator is built once per host
    // (extensions/sdk/src/i18n.ts caches it), so on a reused host the very log
    // line this looks for would already have been emitted before the test ran,
    // making the assertion vacuous rather than merely noisy.
    final host = await ExtensionHost.start(
      kernelSource: bundleSource('kernel'),
      extensions: [ExtensionBundle(key: 'scoring', source: bundleSource('scoring'))],
    );
    addTearDown(host.dispose);
    final logs = <String>[];
    final subscription = host.logs.listen(logs.add);
    addTearDown(subscription.cancel);

    // scoreQsos renders tally labels, which is what builds a translator.
    final result = await host.invokeHook(
      'scoring',
      key: 'core',
      method: 'scoreQsos',
      args: {
        'operation': {'uuid': 'op', 'stationCall': 'N0DEV', 'refs': <Map<String, dynamic>>[]},
        'qsos': [
          {
            'uuid': 'q',
            'startAtMillis': 0,
            'band': '20m',
            'mode': 'CW',
            'our': {'call': 'N0DEV'},
            'their': {'call': 'DL1ABC'},
          },
        ],
      },
      timeout: const Duration(seconds: 30),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));

    // FIRST prove the code under test actually ran. Without this the test is
    // vacuous: two "no such log line" assertions both pass trivially if
    // scoreQsos ever stops rendering labels, or returns early, or the hook
    // quietly fails — and a test that cannot fail is worse than no test.
    // Labels are what force i18next to build a translator, which is the whole
    // thing being checked for silence.
    final summary = (result as Map?)?['operationSummary'] as Map?;
    expect(
      summary,
      isNotNull,
      reason:
          'scoreQsos returned no operationSummary, so nothing rendered a '
          'label and the silence below proves nothing',
    );
    final labelled = summary!.values.whereType<Map>().where((e) => e['label'] is String && (e['label'] as String).isNotEmpty);
    expect(
      labelled,
      isNotEmpty,
      reason:
          'no tally in the summary carried a label, so no translator was '
          'built: ${const JsonEncoder.withIndent('  ').convert(summary)}',
    );

    expect(logs.where((l) => l.contains('pluralResolver')), isEmpty, reason: 'i18next must not report the missing Intl on every translator build');
    expect(logs.where((l) => l.contains('ERROR')), isEmpty, reason: 'a routine hook call should produce no ERROR log at all');
  }, timeout: const Timeout(Duration(seconds: 90)));
}
