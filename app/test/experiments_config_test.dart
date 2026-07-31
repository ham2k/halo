// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The experiments catalog's contract: experiments.yaml parses into
// definitions with sane defaults; a malformed entry is skipped without
// taking down the catalog (the file is hand-edited); and EXP-command token
// resolution matches keys and aliases case-insensitively — command input
// arrives uppercased by the call field, while the yaml is naturally
// lowercase, so a case-sensitive match would break every EXP invocation.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/config/experiments.dart';

void main() {
  test('the SHIPPED catalog parses and defines the experiments gate', () {
    // The real file, not a fixture: a hand-edit that breaks parsing (or
    // renames the 'experiments' meta-experiment the Developer panel gates
    // the Experiments tile on) should fail here, not silently hide the UI.
    final definitions = parseExperimentsYaml(File('experiments.yaml').readAsStringSync());
    expect(findExperiment(definitions, 'EXPERIMENTS')?.key, 'experiments');
    expect(findExperiment(definitions, 'EXP')?.key, 'experiments');
    // CAT gates the Station Configuration section (docs/design/cat.md);
    // losing the entry would leave no way to turn the section on at all.
    expect(findExperiment(definitions, 'GATO')?.key, 'gato');
    expect(findExperiment(definitions, 'CAT')?.key, 'gato');
  });

  test('parses full and minimal entries with defaults', () {
    final definitions = parseExperimentsYaml('''
experiments:
  - key: layouts
    name: Customizable Layouts
    description: Drag panes around.
    aliases: [layout, dock]
    hidden: false
  - key: bare
''');
    expect(definitions, hasLength(2));
    final layouts = definitions[0];
    expect(layouts.key, 'layouts');
    expect(layouts.name, 'Customizable Layouts');
    expect(layouts.description, 'Drag panes around.');
    expect(layouts.aliases, ['layout', 'dock']);
    expect(layouts.hidden, isFalse);
    final bare = definitions[1];
    expect(bare.name, 'bare', reason: 'name falls back to the key');
    expect(bare.description, isNull);
    expect(bare.aliases, isEmpty);
    expect(bare.hidden, isFalse);
  });

  test('skips malformed entries without losing the rest', () {
    final definitions = parseExperimentsYaml('''
experiments:
  - key: good
  - name: no key here
  - just a string
  - key: also-good
    aliases: not-a-list
''');
    // `aliases: not-a-list` fails that entry's cast; `- just a string` and
    // the keyless map are skipped — only clean entries survive.
    expect([for (final d in definitions) d.key], ['good']);
  });

  test('empty, non-map, or syntactically broken documents parse to an empty catalog', () {
    expect(parseExperimentsYaml('experiments: []'), isEmpty);
    expect(parseExperimentsYaml(''), isEmpty);
    expect(parseExperimentsYaml('- a\n- b'), isEmpty);
    // A whole-file syntax error must not throw: loadExperiments caches its
    // future, so a thrown parse would poison the session.
    expect(parseExperimentsYaml('experiments:\n  - key: x\n "broken'), isEmpty);
  });

  test('findExperiment matches key and aliases case-insensitively', () {
    final definitions = parseExperimentsYaml('''
experiments:
  - key: layouts
    aliases: [layout, dock]
''');
    // The call field uppercases command input; yaml is lowercase.
    expect(findExperiment(definitions, 'LAYOUTS')?.key, 'layouts');
    expect(findExperiment(definitions, 'DOCK')?.key, 'layouts');
    expect(findExperiment(definitions, 'layout')?.key, 'layouts');
    expect(findExperiment(definitions, 'nope'), isNull);
    expect(findExperiment(definitions, ''), isNull);
  });
}
