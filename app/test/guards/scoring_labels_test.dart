// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// `scoreNoticeLabel`'s own doc states the rule: "every notice a shipped scorer
// produces belongs here — an unlabelled key reaches the operator as raw
// camelCase, which is worse than useless mid-contest."
//
// Rather than pin a hand-written list that drifts the moment a contest adds a
// key — `missingExchange` reached the pill row verbatim that way — this reads
// what the app ships and holds the map to every key it can actually emit: the
// core extensions' SOURCE, and the built JS of every catalog bundle the app
// pre-loads. A catalog extension the app does not pre-load is not scanned, so
// a key only it emits is not held to anything here.

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart' show ChaseNotice, ChaseVerdict, ChasingProgram;

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/tools/scoring_labels.dart';

/// Every string literal a scorer hands to `notices` or `alerts`.
///
/// Deliberately a scan and not a fixed list: a new contest gets caught the day
/// it ships, which is the whole point — "remember to add it" is what failed.
Set<String> _emittedKeys() {
  final root = Directory('../extensions');
  final preloaded = Directory('assets/preloaded-extensions');
  // Loudly, not vacuously: a suite run from an unexpected cwd would otherwise
  // scan nothing, find no keys, and pass while enforcing nothing at all.
  if (!root.existsSync() || !preloaded.existsSync()) {
    throw StateError('extensions/ or the pre-loaded bundles not found from ${Directory.current.path} — this guard scans what ships, so it cannot run blind');
  }
  final keys = <String>{};

  // Three forms, because the shipped scorers genuinely use all three:
  //   `alerts: ['x']` / `alerts = ['x', 'y']`   — the contest scorers
  //   `notices.push('x')`                       — iaru-hf, naqp
  //   `alerts.add('x')`                         — core/scoring, which builds
  //                                                Sets rather than arrays
  // The `.add` form was missed on the first attempt, which left the DEFAULT
  // scorer — the one every operation runs — invisible to this guard.
  final listForm = RegExp(r"""(?:alerts|notices)\s*[:=]\s*\[([^\]]*)\]""");
  final callForm = RegExp(r"""(?:alerts|notices)\.(?:push|add)\(\s*(['"])([A-Za-z][A-Za-z0-9]*)\1""");
  final literal = RegExp(r"""(['"])([A-Za-z][A-Za-z0-9]*)\1""");

  final sources = [
    for (final entity in root.listSync(recursive: true))
      if (entity is File && entity.path.endsWith('.ts') && !entity.path.contains('/node_modules/') && !entity.path.endsWith('.test.ts'))
        entity.readAsStringSync(),
    for (final entity in preloaded.listSync())
      if (entity is File && entity.path.endsWith('.h2kext'))
        utf8.decode(ZipDecoder().decodeBytes(entity.readAsBytesSync()).findFile('index.js')!.content as List<int>),
  ];
  for (final source in sources) {
    for (final m in listForm.allMatches(source)) {
      for (final l in literal.allMatches(m.group(1)!)) {
        keys.add(l.group(2)!);
      }
    }
    for (final m in callForm.allMatches(source)) {
      keys.add(m.group(2)!);
    }
  }
  return keys;
}

void main() {
  testWidgets('every scoring key a shipped scorer emits has a localized label', (tester) async {
    final emitted = _emittedKeys();
    // A guard on the scan itself: if the regexes stop matching, the test would
    // pass vacuously and the rule would go unenforced again.
    expect(emitted, contains('duplicate'));
    expect(emitted, contains('newMult'));
    expect(emitted, contains('missingExchange'));
    expect(emitted.length, greaterThanOrEqualTo(8), reason: 'the scan found suspiciously few keys');

    late BuildContext ctx;
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    final unlabelled = [
      for (final key in emitted)
        if (scoreNoticeLabel(ctx, key) == key) key,
    ]..sort();

    expect(unlabelled, isEmpty, reason: 'these reach the operator as raw camelCase; add them to scoreNoticeLabel and both i18n catalogs');
  });

  // A program's label names the checklist ("POTA Hunter"); a notice names
  // one reference of it. "New POTA Hunter" tells the operator nothing about
  // the park on the spot.
  testWidgets('a chasing notice names what the program calls one reference, or the program when it does not say', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    final programs = {
      'pota': ChasingProgram.tryParse('pota', {'label': 'POTA Hunter', 'refLabel': 'POTA Park', 'version': 1, 'editions': 'lifetime'})!,
      'dxcc': ChasingProgram.tryParse('dxcc', {'label': 'DXCC', 'version': 1, 'editions': 'lifetime'})!,
    };
    String label(String program) => scoreNoticeLabel(
      ctx,
      ChaseNotice(program: program, verdict: ChaseVerdict.newRef).key,
      programs: programs,
    );
    expect(label('pota'), 'New POTA Park');
    expect(label('dxcc'), 'New DXCC');
  });

  testWidgets('a program that words its own notices is read in its words, with the band or mode filled in', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    final programs = {
      'ham2k-dxcc': ChasingProgram.tryParse('ham2k-dxcc', {
        'label': 'DXCC',
        'version': 1,
        'editions': 'lifetime',
        'notices': {'newRef': 'DXCC ATNO', 'newBand': 'DXCC in {{band}}', 'newMode': 'DXCC in {{ mode }}'},
        'modeLabels': {'PHONE': 'Phone'},
      })!,
    };
    String label(ChaseNotice notice) => scoreNoticeLabel(ctx, notice.key, programs: programs);
    expect(label(const ChaseNotice(program: 'ham2k-dxcc', verdict: ChaseVerdict.newRef)), 'DXCC ATNO');
    expect(label(const ChaseNotice(program: 'ham2k-dxcc', verdict: ChaseVerdict.newBand, band: '80m')), 'DXCC in 80m');
    expect(label(const ChaseNotice(program: 'ham2k-dxcc', verdict: ChaseVerdict.newMode, mode: 'PHONE')), 'DXCC in Phone');
    expect(label(const ChaseNotice(program: 'ham2k-dxcc', verdict: ChaseVerdict.newMode, mode: 'CW')), 'DXCC in CW');
    expect(label(const ChaseNotice(program: 'ham2k-dxcc', verdict: ChaseVerdict.newRef, guess: true)), 'Probably DXCC ATNO');
    // A notice without the band its words name — one made before notices
    // carried it — reads the app's way rather than "DXCC in ".
    expect(label(const ChaseNotice(program: 'ham2k-dxcc', verdict: ChaseVerdict.newBand)), 'New DXCC band');
    expect(
      label(const ChaseNotice(program: 'ham2k-dxcc', verdict: ChaseVerdict.unconfirmed)),
      'DXCC unconfirmed',
      reason: 'a verdict it does not word',
    );
  });
}
