// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The chaser/hunter side of `huntingExportHook` (extensions/sdk/src/activityExports.ts),
// registered under its own `<key>-hunter` key so it can't collide with
// `activityExportHook`'s activator registration — see activity_export_test.dart
// for that half.
//
// Driven through the real runtime with both bundles, same reason
// activity_export_test.dart is: the mechanism is `exportType` round-tripping
// through the core and the activity delegating back to `adif` inside the same
// kernel, which a stub would not exercise.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';

import 'support/bundles.dart';

void main() {
  requireBundles();

  Map<String, dynamic> operation({List<String> activating = const []}) => {
        'uuid': 'op',
        'stationCall': 'N0DEV',
        'title': 'Summit run',
        'refs': [for (final ref in activating) {'type': 'sotaActivation', 'ref': ref}],
      };

  Map<String, dynamic> qso(String call, {List<String> hunted = const []}) => {
        'uuid': 'q-$call',
        'our': {'call': 'N0DEV', 'sent': '59'},
        'their': {'call': call, 'sent': '59'},
        'band': '20m',
        'mode': 'SSB',
        'startAtMillis': DateTime.utc(2026, 7, 1, 12).millisecondsSinceEpoch,
        'refs': [for (final ref in hunted) {'type': 'sota', 'ref': ref}],
      };

  Future<ExtensionHost> startHost() => sharedHost(['adif', 'sota']);

  test('hunting a summit offers a hunter export', () async {
    final host = await startHost();
    final options = (await host.invokeHook(
      'export',
      key: 'sota-hunter',
      method: 'suggestExportOptions',
      args: {
        'operation': operation(),
        'qsos': [qso('W0ABC', hunted: ['W7A/LC-001'])],
      },
      timeout: const Duration(seconds: 20),
    ) as List).cast<Map>();

    expect(options.length, 1);
    expect(options.first['label'], 'SOTA Hunter Log');
    expect(options.first['exportType'], 'sota-hunter');
    // Unlike the activator export, it names no single reference — a hunter
    // file spans every summit worked, so it takes the "for SOTA" filename
    // shape rather than "at W7A/LC-001".
    expect(options.first['filename'], contains('for SOTA'));
    // No `refType` — a hunted ref lives on the QSO, never on the operation,
    // so there's nothing for the core to slice segments by. `color` carries
    // the panel's accent instead (see `HuntingExportRules.color`).
    expect(options.first.containsKey('refType'), isFalse);
    // sota/manifest.json's accentColor, threaded through explicitly since
    // there's no refType for the panel to resolve one from (see
    // `HuntingExportRules.color`).
    expect(options.first['color'], '#6295BF');
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('an operation that hunted nothing offers no hunter export', () async {
    final host = await startHost();
    final options = await host.invokeHook(
      'export',
      key: 'sota-hunter',
      method: 'suggestExportOptions',
      args: {
        'operation': operation(),
        'qsos': [qso('W0ABC')],
      },
      timeout: const Duration(seconds: 20),
    ) as List;

    expect(options, isEmpty);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('activating SOTA suppresses its own hunter export', () async {
    final host = await startHost();
    // An operation activating a summit already owes an activator log for any
    // summit-to-summit contact it made; offering a hunter log alongside it
    // would submit those same contacts a second time.
    final options = await host.invokeHook(
      'export',
      key: 'sota-hunter',
      method: 'suggestExportOptions',
      args: {
        'operation': operation(activating: ['W7A/LC-002']),
        'qsos': [qso('W0ABC', hunted: ['W7A/LC-001'])],
      },
      timeout: const Duration(seconds: 20),
    ) as List;

    expect(options, isEmpty);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('activating SOTA between listing and generating withdraws the export, not silently duplicates it', () async {
    final host = await startHost();
    // The option was offered against an operation that wasn't activating —
    // generate against one that now is, the same staleness
    // `activityExportHook`'s identical test guards. Producing the file
    // anyway would duplicate every same-program S2S contact the activator
    // log already claims.
    await expectLater(
      host.invokeHook(
        'export',
        key: 'sota-hunter',
        method: 'generateExport',
        args: {
          'operation': operation(activating: ['W7A/LC-002']),
          'qsos': [qso('W0ABC', hunted: ['W7A/LC-001'])],
          'exportType': 'sota-hunter',
        },
        timeout: const Duration(seconds: 20),
      ),
      throwsA(anything),
    );
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('the hunter file claims every summit worked, and only the ones hunted', () async {
    final host = await startHost();
    final result = await host.invokeHook(
      'export',
      key: 'sota-hunter',
      method: 'generateExport',
      args: {
        'operation': operation(),
        'qsos': [
          qso('W0ABC', hunted: ['W7A/LC-001']),
          qso('W1XYZ', hunted: ['W7A/LC-003']),
          qso('W2NUL'), // worked, but nothing hunted — must not appear
        ],
        'exportType': 'sota-hunter',
      },
      timeout: const Duration(seconds: 20),
    ) as Map;
    final content = result['content'] as String;

    expect(content, contains('<SOTA_REF:10>W7A/LC-001'));
    expect(content, contains('<SOTA_REF:10>W7A/LC-003'));
    expect('<EOR>'.allMatches(content).length, 2);
    expect(content, isNot(contains('W2NUL')));
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('an exportType it never offered is refused, not delegated', () async {
    final host = await startHost();
    // Same guard as the activator export's identical test: answering for an
    // exportType this hook never suggested would delegate to `adif` and
    // recurse rather than fail (see contest_export_test.dart).
    await expectLater(
      host.invokeHook(
        'export',
        key: 'sota-hunter',
        method: 'generateExport',
        args: {
          'operation': operation(),
          'qsos': [qso('W0ABC', hunted: ['W7A/LC-001'])],
          'exportType': 'adif',
        },
        timeout: const Duration(seconds: 20),
      ),
      throwsA(anything),
    );
  }, timeout: const Timeout(Duration(seconds: 60)));

  // Same risk activity_export_test.dart's identical test guards: a dropped
  // forward silently leaks the operator's notes into an uploaded hunter log,
  // or silently strips them when the operator asked to keep them.
  test('a hunter export forwards the private-data flag to the ADIF it delegates to', () async {
    final host = await startHost();

    Future<String> adifFor({required bool includePrivateData}) async {
      final result = await host.invokeHook(
        'export',
        key: 'sota-hunter',
        method: 'generateExport',
        args: {
          'operation': operation(),
          'qsos': [
            {
              ...qso('W0ABC', hunted: ['W7A/LC-001']),
              'their': {'call': 'W0ABC', 'sent': '59', 'name': 'Alice', 'grid': 'EM79'},
              'notes': 'met at Hamvention',
            },
          ],
          'exportType': 'sota-hunter',
          'includePrivateData': includePrivateData,
        },
        timeout: const Duration(seconds: 20),
      ) as Map;
      return result['content'] as String;
    }

    final withheld = await adifFor(includePrivateData: false);
    for (final private in ['Alice', 'EM79', 'Hamvention']) {
      expect(withheld, isNot(contains(private)));
    }

    final released = await adifFor(includePrivateData: true);
    for (final private in ['Alice', 'EM79', 'Hamvention']) {
      expect(released, contains(private));
    }
  }, timeout: const Timeout(Duration(seconds: 60)));
}
