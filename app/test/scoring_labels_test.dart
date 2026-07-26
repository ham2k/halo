// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// `scoreNoticeLabel`'s own doc states the rule: "every notice a shipped scorer
// produces belongs here — an unlabelled key reaches the operator as raw
// camelCase, which is worse than useless mid-contest."
//
// Nothing enforced it, and M4 promptly broke it: two new contests introduced
// `missingExchange` and it reached the pill row verbatim. So rather than pin a
// hand-written list that drifts the same way, this reads the shipped scorers'
// SOURCE and holds the map to every key they can actually emit.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/tools/scoring_labels.dart';

/// Every string literal a scorer hands to `notices` or `alerts`.
///
/// Deliberately a source scan and not a fixed list: a new contest gets caught
/// the day it lands, which is the whole point — the previous convention was
/// "remember to add it", and that is what failed.
Set<String> _emittedKeys() {
  final root = Directory('../extensions');
  // Loudly, not vacuously: a suite run from an unexpected cwd would otherwise
  // scan nothing, find no keys, and pass while enforcing nothing at all.
  if (!root.existsSync()) {
    throw StateError('extensions/ not found from ${Directory.current.path} — this guard scans source, so it cannot run blind');
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

  for (final entity in root.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.ts')) continue;
    if (entity.path.contains('/node_modules/') || entity.path.endsWith('.test.ts')) continue;
    final source = entity.readAsStringSync();

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
    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        home: Builder(builder: (context) {
          ctx = context;
          return const SizedBox();
        }),
      ),
    ));

    final unlabelled = [
      for (final key in emitted)
        if (scoreNoticeLabel(ctx, key) == key) key,
    ]..sort();

    expect(
      unlabelled,
      isEmpty,
      reason: 'these reach the operator as raw camelCase; add them to scoreNoticeLabel and both i18n catalogs',
    );
  });
}
