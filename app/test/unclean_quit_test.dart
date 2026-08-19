// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The mark a quit leaves while its database close runs is the ONLY evidence
// that survives a close which failed or timed out — the engine tears the app
// down as soon as the exit hook returns, so nothing reported in the moment
// gets anywhere. Which makes two mutations invisible everywhere else: a boot
// that never looks at the mark (a lost write nobody ever hears about), and a
// boot that reports without clearing it (every later boot reporting the same
// long-gone quit, and the rate that decides whether the quit path is sound
// becoming meaningless).

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/services/error_policy.dart';
import 'package:ham2k_logger/services/error_reporting_service.dart';
import 'package:ham2k_logger/services/unclean_quit.dart';

Future<List<String>> capturedPrints(Future<void> Function() body) async {
  final lines = <String>[];
  final previous = debugPrint;
  debugPrint = (message, {wrapWidth}) => lines.add(message ?? '');
  try {
    await body();
  } finally {
    debugPrint = previous;
  }
  return lines;
}

Future<SharedPreferences> _prefs([Map<String, Object> initial = const {}]) async {
  SharedPreferences.setMockInitialValues(initial);
  return SharedPreferences.getInstance();
}

void main() {
  setUp(ErrorReportingService.resetForTesting);

  test('a mark left by the previous run is reported, once', () async {
    final prefs = await _prefs({uncleanQuitKey: true});

    final lines = await capturedPrints(() => reportUncleanQuit(prefs));

    expect(lines.join('\n'), contains('db:unclean-quit'));
    expect(prefs.getBool(uncleanQuitKey), isNull, reason: 'a second boot must not report it again');
  });

  test('an ordinary boot reports nothing', () async {
    final prefs = await _prefs();
    final lines = await capturedPrints(() => reportUncleanQuit(prefs));
    expect(lines, isEmpty);
  });

  test('the report is uploaded but never shown to the operator', () {
    // What was lost is already lost, and a boot is the worst moment to hand
    // someone a fright they cannot act on. The tier is the whole decision:
    // `notify` would put a "Something went wrong" card in front of an operator
    // starting a session, and `logOnly` would mean nobody ever learns the quit
    // path is failing in the field.
    final decision = ErrorPolicy.decide(const UncleanDatabaseQuit());
    expect(decision.disposition, ErrorDisposition.report);
    expect(decision.disposition.uploads, isTrue);
    expect(decision.disposition.notifies, isFalse);
  });
}
