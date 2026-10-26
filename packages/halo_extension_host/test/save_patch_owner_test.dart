// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The ref types a `processQsoBeforeSave` patch arrives with: the ones its
// extension owns, which are the refs the app lets it write (`mergeQsoPatch`).
// A catalog contest's key is not its ref type (`ham2k-cqww` keeps `cqww`
// refs), so ownership goes by type — and since any extension may register a
// handler for any type, a type is owned only by an extension that alone
// answers for it by bare name and declares that in its manifest.
//
// Driven through the real kernel: the claims are the kernel's to know.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';

import 'support/bundles.dart';

/// An extension registering [refCategories], declaring [declared] in its
/// manifest `hooks`, and answering every save with a patch of a `contest` ref
/// — or with null when [patches] is false.
String _extension(String key, {List<String> refCategories = const [], List<String>? declared, bool patches = true}) {
  final hooks = [...(declared ?? refCategories), 'activity'].map((h) => "'$h'").join(', ');
  return '''
__polo.defineExtension({
  key: '$key',
  name: '$key',
  version: '0.0.1',
  hooks: [$hooks],
  onActivation: function (api) {
    ${refCategories.map((category) => "api.registerHook('$category', { key: '$key', hook: { decorateRef: async function (args) { return args.ref } } })").join('\n    ')}
    api.registerHook('activity', { key: '$key', hook: {
      processQsoBeforeSave: async function () { return ${patches ? "{ refs: [{ type: 'contest', location: 'NY' }] }" : 'null'} },
    }})
  },
})
''';
}

void main() {
  requireBundles();

  late ExtensionHost host;

  setUpAll(() async {
    host = await ExtensionHost.start(
      kernelSource: bundleSource('kernel'),
      extensions: [
        ExtensionBundle(
          key: 'ki2d-contest',
          source: _extension('ki2d-contest', refCategories: ['ref:contest', 'ref:contestExtra', 'ref:shared', 'ref:qp/ny']),
        ),
        // Answers for `shared` too, the way WCA resolves ECA's castles.
        ExtensionBundle(
          key: 'also-shared',
          source: _extension('also-shared', refCategories: ['ref:shared']),
        ),
        // Registers a handler for `pota` without declaring it.
        ExtensionBundle(
          key: 'undeclared',
          source: _extension('undeclared', refCategories: ['ref:pota'], declared: const []),
        ),
        ExtensionBundle(key: 'no-claims', source: _extension('no-claims')),
        ExtensionBundle(
          key: 'quiet',
          source: _extension('quiet', refCategories: ['ref:quiet'], patches: false),
        ),
      ],
    );
  });

  tearDownAll(() => host.dispose());

  Future<Map<Object?, Map<String, dynamic>>> save() async {
    final entries = await host.invokeHookAll(
      'activity',
      method: 'processQsoBeforeSave',
      args: {
        'qso': {
          'their': {'call': 'W1AW'},
        },
        'operation': {
          'refs': [
            {'type': 'contest'},
          ],
        },
      },
      timeout: const Duration(seconds: 20),
    );
    return {for (final entry in entries) entry['key']: entry};
  }

  test('a patch arrives with the types its extension alone claims by name and declares, whatever its key', () async {
    final byKey = await save();
    // Not `qp`: a qualified claim shares its type with every other code's
    // claimant, and the patch names a type, not a code. Not `shared`: another
    // extension answers for it too.
    expect(byKey['ki2d-contest']?['refTypes'], unorderedEquals(['contest', 'contestExtra']));
    expect(byKey['ki2d-contest']?['value'], {
      'refs': [
        {'type': 'contest', 'location': 'NY'},
      ],
    });
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('a type two extensions answer for belongs to neither, and an undeclared handler owns nothing', () async {
    final byKey = await save();
    expect(byKey['also-shared']?['refTypes'], isEmpty);
    expect(byKey['undeclared']?['refTypes'], isEmpty);
    expect(byKey['no-claims']?['refTypes'], isEmpty);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('only a patch carries them: not a null answer, nor any other hook', () async {
    final byKey = await save();
    expect(byKey['quiet']?['value'], isNull);
    expect(byKey['quiet']?.containsKey('refTypes'), isFalse);

    final other = await host.invokeHookAll(
      'ref:contest',
      method: 'decorateRef',
      args: {
        'ref': {'type': 'contest'},
      },
      timeout: const Duration(seconds: 20),
    );
    expect(other.single.containsKey('refTypes'), isFalse);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
