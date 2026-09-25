// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Every hook the host calls is named once, in halo_core's catalog
// (hook_names.dart). A hook name spelled at a call site is a misspelling
// waiting to happen, and a misspelled one is never an error: the runtime
// answers a category or method nothing registers with an absence, so the
// feature behind it simply stops, with nothing anywhere to say why.
//
// So lib code reaches a hook only through a HookRef from the catalog: calls go
// through `invoke`/`invokeAll`, batch calls through `HookRef.withArgs`, and a
// reference handler's category through `Hooks.ref` / `Hooks.refTypeOf`.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const _catalog = '../packages/halo_core/lib/src/hook_names.dart';

/// The extension side's list of categories — see [_categoriesDeclaredIn].
const _sdkCategories = '../extensions/sdk/src/hookCategories.ts';

/// What a line may not contain, and why — each one a way to name a hook
/// without the catalog.
final _rules = <(RegExp, String)>[
  (RegExp(r'\.invokeHook(All)?\('), 'a raw invokeHook call — go through invoke/invokeAll with a HookRef from Hooks'),
  (RegExp(r"""\bmethod: *['"]"""), 'a hook method spelled out — use a HookRef from Hooks (HookRef.withArgs for a batch)'),
  (RegExp(r"""(hooks\.contains\(|onlyHook: *)['"]"""), 'a manifest hook category spelled out — use HookCategories'),
  (RegExp(r"""['"]ref:"""), 'a `ref:` category spelled out — use Hooks.ref / Hooks.refTypeOf'),
  (RegExp(r"""HookRef\(\s*['"]"""), 'a HookRef named at the call site — add it to the catalog'),
];

/// What [source] does wrong, one line each, attributed to [file].
List<String> offendersIn(String source, {String file = '<source>'}) {
  final offenders = <String>[];
  final lines = source.split('\n');
  for (final (i, line) in lines.indexed) {
    final code = line.trimLeft();
    if (code.startsWith('//')) continue;
    for (final (rule, why) in _rules) {
      if (rule.hasMatch(line)) offenders.add('$file:${i + 1} — $why');
    }
  }
  return offenders;
}

/// The lib code that calls hooks: the app, the distribution layer where it
/// exists, halo_core, whose sync engine speaks `syncTransport`, and the CLI.
List<File> _sources() {
  final roots = [
    Directory('lib'),
    Directory('../packages/halo_core/lib'),
    Directory('../packages/halo_cli/lib'),
    if (Directory('../app_dist/lib').existsSync()) Directory('../app_dist/lib'),
  ];
  for (final root in roots.take(3)) {
    // Loudly, not vacuously: run from anywhere else, this would scan nothing.
    if (!root.existsSync()) fail('expected ${root.path} to exist — run this suite from the app package (cwd: ${Directory.current.path})');
  }
  return [
    for (final root in roots)
      ...root
          .listSync(recursive: true)
          .whereType<File>()
          // Compared as paths, not strings: Windows lists them with backslashes.
          .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart') && !p.equals(f.path, _catalog)),
  ];
}

/// The string values of a Dart `abstract final class` of `static const`s.
Set<String> _constantsOf(String source, String className) {
  final body = RegExp('class $className \\{([^}]*)\\}').firstMatch(source)?.group(1) ?? '';
  return {for (final m in RegExp(r"static const \w+ = '([^']+)';").allMatches(body)) m.group(1)!};
}

/// The categories the SDK's `HOOK_CATEGORIES` array lists.
Set<String> _categoriesDeclaredIn(String source) {
  final body = RegExp(r'HOOK_CATEGORIES = \[([^\]]*)\]').firstMatch(source)?.group(1) ?? '';
  return {for (final m in RegExp(r'"([^"]+)"').allMatches(body)) m.group(1)!};
}

void main() {
  test('every hook is named through the catalog', () {
    expect(
      [for (final file in _sources()) ...offendersIn(file.readAsStringSync(), file: file.path)],
      isEmpty,
      reason: 'Name hooks through halo_core\'s Hooks catalog (packages/halo_core/lib/src/hook_names.dart).',
    );
  });

  test('the host spells every category the way the extension side does', () {
    // Each language has one spelling, and nothing else ties the two together:
    // a typo in the Dart one passes analyze, this guard and tsc alike, and
    // every call through it is then answered with an absence.
    final dart = _constantsOf(File(_catalog).readAsStringSync(), 'HookCategories');
    final sdk = _categoriesDeclaredIn(File(_sdkCategories).readAsStringSync());
    expect(dart, isNotEmpty, reason: 'the catalog parse found no categories — a guard reading nothing checks nothing');
    expect(sdk, isNotEmpty, reason: 'the SDK parse found no categories');
    expect(dart.difference(sdk), isEmpty, reason: 'categories the host names that the SDK does not list');
  });

  // A handful of regexes, and a guard that cannot fail guards nothing. These pin each
  // shape it has to see, against source it does not read from disk.
  test('the guard sees each way to name a hook without the catalog', () {
    for (final shape in [
      "host.invokeHook('spots', method: 'fetchSpots');",
      "await host.invokeHookAll('account', method: 'getDefinition');",
      "host.invokeHookBatch([(category: 'activity', key: key, method: 'suggest', args: args)]);",
      // Any layout of a batch record: it always carries its method.
      "host.invokeHookBatch([(key: k, category: category, method: 'suggest', args: a)]);",
      "info.hooks.contains('panel')",
      "ExtensionsPanel(services: services, onlyHook: 'panel')",
      "final category = 'ref:\$type';",
      "host.invoke(HookRef('spots', 'fetchSpots'));",
    ]) {
      expect(offendersIn(shape), isNotEmpty, reason: shape);
    }
  });

  test('the guard leaves catalog calls and unrelated categories alone', () {
    // A database row's category is not a hook's; a comment may name anything.
    expect(offendersIn("host.invokeAll(Hooks.spotsFetchSpots, partialOnTimeout: true);"), isEmpty);
    expect(offendersIn("host.invokeHookBatch([Hooks.activitySuggest.withArgs(args, key: key)]);"), isEmpty);
    expect(offendersIn("info.hooks.contains(HookCategories.panel)"), isEmpty);
    expect(offendersIn("LookupRow(category: geoshapeLookupCategory, key: url, data: geojson)"), isEmpty);
    expect(offendersIn("// host.invokeHook('spots', method: 'fetchSpots')"), isEmpty);
  });
}
