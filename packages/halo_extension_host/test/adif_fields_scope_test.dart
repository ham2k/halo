// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Which extensions the FULL ADIF export asks for fields about a contact: the
// ones claiming a reference its operation or the contact itself carries, and
// those whose manifest opts into every contact (docs/extensions/hooks.md,
// `adifFields`).
//
// Driven through the real kernel and the real `adif` exporter, beside small
// extensions written here whose hooks answer EVERY contact with no check of
// their own — the shape that, asked about every contact, stamps its
// CONTEST_ID on every log the operator exports. A fake kernel would test the
// filter against our own idea of it.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';

import 'support/bundles.dart';

/// An extension whose `adifFields` answers every contact it is asked about
/// with `<field>:Y`, handling the references [refCategories] name, and carrying
/// [manifest] (a line of object literal) on its definition the way a bundle
/// spreads its manifest into `defineExtension`.
String _extension(String key, {required String field, List<String> refCategories = const [], String manifest = ''}) =>
    '''
__polo.defineExtension({
  key: '$key',
  name: '$key',
  version: '0.0.1',
  $manifest
  onActivation: function (api) {
    ${refCategories.map((category) => "api.registerHook('$category', { key: '$key', hook: { decorateRef: async function (args) { return args.ref } } })").join('\n    ')}
    api.registerHook('adifFields', { key: '$key', hook: {
      fieldsForOneQSO: async function () { return [{ name: '$field', value: 'Y' }] },
    }})
  },
})
''';

/// An extension answering names the contact's own record also writes: one it
/// may take (STATE) and ones that identify the contact and it may not — one
/// the contact left empty (FREQ) and one in lower case.
const _overreach = '''
__polo.defineExtension({
  key: 'overreach',
  name: 'overreach',
  version: '0.0.1',
  onActivation: function (api) {
    api.registerHook('ref:overreach', { key: 'overreach', hook: { decorateRef: async function (args) { return args.ref } } })
    api.registerHook('adifFields', { key: 'overreach', hook: {
      fieldsForOneQSO: async function () {
        return [
          { name: 'STATE', value: 'ZZ' },
          { name: 'MODE', value: 'FT8' },
          { name: 'FREQ', value: '14074' },
          { name: 'call', value: 'X1X' },
        ]
      },
    }})
  },
})
''';

void main() {
  requireBundles();

  late ExtensionHost host;

  setUpAll(() async {
    host = await ExtensionHost.start(
      kernelSource: bundleSource('kernel'),
      extensions: [
        ExtensionBundle(key: 'adif', source: bundleSource('adif')),
        ExtensionBundle(key: 'ham2k-sota', source: bundleSource('ham2k-sota')),
        // Two extensions claiming the same reference type equally precisely,
        // the way a program that resolves another's references while that one
        // is off claims them.
        ExtensionBundle(
          key: 'first-claim',
          source: _extension('first-claim', field: 'APP_TEST_FIRST_CLAIM', refCategories: ['ref:shared']),
        ),
        ExtensionBundle(
          key: 'second-claim',
          source: _extension('second-claim', field: 'APP_TEST_SECOND_CLAIM', refCategories: ['ref:shared']),
        ),
        ExtensionBundle(
          key: 'careless',
          source: _extension('careless', field: 'APP_TEST_CARELESS', refCategories: ['ref:careless']),
        ),
        // The bundled QSO-party extension and one party, as they stand on an
        // operation logged before each party had its own: `qp` claims the
        // whole family, `qp/ca` one code in it.
        ExtensionBundle(
          key: 'family',
          source: _extension('family', field: 'APP_TEST_FAMILY', refCategories: ['ref:qp']),
        ),
        ExtensionBundle(
          key: 'claimant',
          source: _extension('claimant', field: 'APP_TEST_CLAIMANT', refCategories: ['ref:qp/ca']),
        ),
        ExtensionBundle(
          key: 'everywhere',
          source: _extension('everywhere', field: 'APP_TEST_EVERYWHERE', manifest: "adifFieldsScope: 'always',"),
        ),
        ExtensionBundle(
          key: 'orphan',
          source: _extension('orphan', field: 'APP_TEST_ORPHAN'),
        ),
        ExtensionBundle(key: 'overreach', source: _overreach),
      ],
    );
  });

  tearDownAll(() => host.dispose());

  Future<String> export({List<Map<String, dynamic>> operationRefs = const [], List<Map<String, dynamic>> qsoRefs = const [], String? mainHandler}) async {
    final result =
        await host.invokeHook(
              'export',
              key: 'adif',
              method: 'generateExport',
              args: {
                'operation': {'uuid': 'op', 'stationCall': 'N0DEV', 'refs': operationRefs},
                'qsos': [
                  {
                    'uuid': 'q0',
                    'our': {'call': 'N0DEV', 'sent': '59'},
                    'their': {'call': 'W1AW', 'sent': '59'},
                    'band': '20m',
                    'mode': 'SSB',
                    'startAtMillis': DateTime.utc(2026, 7, 1, 12).millisecondsSinceEpoch,
                    'refs': qsoRefs,
                  },
                ],
                'exportType': 'adif',
                'mainHandler': ?mainHandler,
              },
              timeout: const Duration(seconds: 20),
            )
            as Map;
    return result['content'] as String;
  }

  test('an extension the contact has nothing to do with writes nothing, however careless its hook', () async {
    final content = await export(
      operationRefs: [
        {'type': 'sotaActivation', 'ref': 'W7A/LC-001'},
      ],
    );

    expect(content, contains('<MY_SOTA_REF:10>W7A/LC-001'), reason: 'the program the log belongs to still writes');
    expect(content, isNot(contains('APP_TEST_CARELESS')));
    expect(content, isNot(contains('APP_TEST_FAMILY')));
    expect(content, isNot(contains('APP_TEST_CLAIMANT')));
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('a reference on the operation brings its extension in', () async {
    final content = await export(
      operationRefs: [
        {'type': 'careless', 'ref': 'C-1'},
      ],
    );

    expect(content, contains('<APP_TEST_CARELESS:1>Y'));
  }, timeout: const Timeout(Duration(seconds: 60)));

  // A hunter's log carries its programs on the contacts alone: the operation
  // activates nothing. Scoping by the operation's refs would strip every
  // SOTA_REF out of a chaser's backup.
  test('a reference on the contact alone brings its extension in', () async {
    final content = await export(
      qsoRefs: [
        {'type': 'sota', 'ref': 'W7A/LC-001'},
        {'type': 'careless', 'ref': 'C-1'},
      ],
    );

    expect(content, contains('<SOTA_REF:10>W7A/LC-001'));
    expect(content, contains('<APP_TEST_CARELESS:1>Y'));
  }, timeout: const Timeout(Duration(seconds: 60)));

  // `{type: 'qp', ref: 'CA'}` belongs to the longest claim that begins its
  // code. Asking every extension that matched at all would put the bundled
  // extension's CONTEST_ID beside the party's own on every old California log,
  // and the first to arrive would win.
  test('an old reference belongs to the extension claiming it most precisely', () async {
    final california = await export(
      operationRefs: [
        {'type': 'qp', 'ref': 'CA'},
      ],
    );
    expect(california, contains('<APP_TEST_CLAIMANT:1>Y'));
    expect(california, isNot(contains('APP_TEST_FAMILY')));

    final newYork = await export(
      operationRefs: [
        {'type': 'qp', 'ref': 'NY'},
      ],
    );
    expect(newYork, contains('<APP_TEST_FAMILY:1>Y'), reason: 'no party claims NY, so the family does');
    expect(newYork, isNot(contains('APP_TEST_CLAIMANT')));
  }, timeout: const Timeout(Duration(seconds: 60)));

  // Two extensions registering the same `ref:` category equally precisely
  // are both owners of it. Asking only whichever registered first leaves the
  // other program's own fields out of the file whenever it loses that race.
  test('equal claims on a reference are all asked, whatever order they registered in', () async {
    final content = await export(
      operationRefs: [
        {'type': 'shared', 'ref': 'S-1'},
      ],
    );

    expect(content, contains('<APP_TEST_FIRST_CLAIM:1>Y'));
    expect(content, contains('<APP_TEST_SECOND_CLAIM:1>Y'));
  }, timeout: const Timeout(Duration(seconds: 60)));

  // A program's answer outranks the contact's generic one — but a hook that
  // could restate who was worked, when, or on what would rewrite every record
  // of every file it is asked about, the whole-log backup included.
  test("a hook's field outranks the contact's own, except the fields that identify the contact", () async {
    final content = await export(
      operationRefs: [
        {'type': 'overreach', 'ref': 'O-1'},
      ],
    );

    expect(content, contains('<STATE:2>ZZ'));
    expect(content, contains('<CALL:4>W1AW'));
    expect(content, contains('<MODE:3>SSB'));
    expect(content, isNot(contains('X1X')));
    expect(content, isNot(contains('FT8')));
    expect(content, isNot(contains('14074')), reason: 'a name the contact left empty is still not the hook\'s');
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('an extension whose manifest opts in is asked about every contact', () async {
    final content = await export();

    expect(content, contains('<APP_TEST_EVERYWHERE:1>Y'));
  }, timeout: const Timeout(Duration(seconds: 60)));

  // Neither a reference nor the opt-in means the export never asks, and the
  // file gives no sign of it — so activation has to say so.
  test('one that handles no reference and does not opt in is never asked, and says so as it activates', () async {
    final content = await export(
      operationRefs: [
        {'type': 'careless', 'ref': 'C-1'},
      ],
    );

    expect(content, isNot(contains('APP_TEST_ORPHAN')));
    expect(host.logLines.join('\n'), contains('extension orphan registers adifFields but handles no reference'));
    expect(host.logLines.join('\n'), isNot(contains('extension everywhere registers adifFields but')));
  }, timeout: const Timeout(Duration(seconds: 60)));

  // A file that claims one program asks that program by name; which references
  // a contact carries is the full export's question, not this one's.
  test('a program named as the main handler is asked whatever the contact carries', () async {
    final content = await export(mainHandler: 'careless');

    expect(content, contains('<APP_TEST_CARELESS:1>Y'));
    expect(content, isNot(contains('APP_TEST_EVERYWHERE')), reason: 'a named file asks only its own program');
  }, timeout: const Timeout(Duration(seconds: 60)));
}
