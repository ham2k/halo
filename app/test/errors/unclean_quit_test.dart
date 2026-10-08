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
import 'package:halo_core/halo_core.dart' show realNowMillis;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/services/error_policy.dart';
import 'package:ham2k_logger/services/error_reporting_service.dart';
import 'package:ham2k_logger/services/unclean_quit.dart';

import '../support/error_reporting_fakes.dart';

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
    final prefs = await _prefs({quitStageKey: QuitStage.databaseClose.name});

    final lines = await capturedPrints(() => reportUncleanQuit(prefs));

    expect(lines.join('\n'), contains('db:unclean-quit'));
    expect(lastQuitStage(prefs), isNull, reason: 'a second boot must not report it again');
  });

  test('the report names the step that was running, not just "a quit"', () async {
    // The whole point of the stage: a quit wedged in the radio shutdown and a
    // quit that lost a database write are different bugs with different
    // fixes, and a single message for both groups them into one issue where
    // the rarer of the two is never seen.
    final prefs = await _prefs({quitStageKey: QuitStage.cat.name});

    final lines = await capturedPrints(() => reportUncleanQuit(prefs));

    expect(lines.join('\n'), contains('radios'));
    expect(lines.join('\n'), contains('db:unclean-quit:cat'));
  });

  test("an older build's bare mark still reports, as the close it meant", () async {
    // The bool was only ever written in front of the close. An operator
    // upgrading into this build carries one from their last quit, and a boot
    // that only understood the new key would drop it silently.
    final prefs = await _prefs({uncleanQuitKey: true});

    final lines = await capturedPrints(() => reportUncleanQuit(prefs));

    expect(lines.join('\n'), contains('closing the database'));
    expect(prefs.getBool(uncleanQuitKey), isNull, reason: 'and must not report on every boot after');
  });

  test('a stage name from a newer build reports rather than vanishing', () async {
    // Downgrades happen, and a stage this build does not know is still an
    // unclean quit. Dropping it would make the quit path look healthier the
    // older the build is.
    final prefs = await _prefs({quitStageKey: 'somethingThisBuildNeverHeardOf'});

    final lines = await capturedPrints(() => reportUncleanQuit(prefs));

    expect(lines.join('\n'), contains('db:unclean-quit'));
  });

  test('an ordinary boot reports nothing', () async {
    final prefs = await _prefs();
    final lines = await capturedPrints(() => reportUncleanQuit(prefs));
    expect(lines, isEmpty);
  });

  group('one upload per stage per day', () {
    // A quit that dies at the radios dies there on every quit, so a device
    // with a wedging rig would upload once per launch and drown out every
    // other install. The window has to mute the REPEAT without muting a
    // different step, a stale stamp, or the mark's own clearing.
    Future<List<String?>> uploadedContexts(SharedPreferences prefs) async {
      final backend = FakeErrorReportingBackend();
      await withErrorHooks(backend: backend, () => reportUncleanQuit(prefs));
      return [for (final e in backend.exceptions) e.context];
    }

    int hoursAgo(int hours) => realNowMillis() - Duration(hours: hours).inMilliseconds;

    test('a second quit dying at the same step within the day is not uploaded, and is still consumed', () async {
      final prefs = await _prefs({quitStageKey: QuitStage.cat.name});
      expect(await uploadedContexts(prefs), ['db:unclean-quit:cat']);

      await markQuitStage(prefs, QuitStage.cat);
      expect(await uploadedContexts(prefs), isEmpty);
      expect(lastQuitStage(prefs), isNull, reason: 'a muted report must not leave the mark for the next boot to find');
    });

    test('a quit dying at a different step still uploads inside the window', () async {
      // The stages are different bugs; a wedged radio must not hide a lost
      // database write on the same device.
      final prefs = await _prefs({quitStageKey: QuitStage.databaseClose.name, quitReportedAtKey(QuitStage.cat.name): hoursAgo(1)});
      expect(await uploadedContexts(prefs), ['db:unclean-quit:databaseClose']);
    });

    test('the same step uploads again once the day is over', () async {
      final prefs = await _prefs({quitStageKey: QuitStage.cat.name, quitReportedAtKey(QuitStage.cat.name): hoursAgo(25)});
      expect(await uploadedContexts(prefs), ['db:unclean-quit:cat']);
    });

    test('a stamp from the future does not mute the report', () async {
      // Written while the device clock was wrong; trusting it would mute this
      // step for as long as the stamp stays ahead of real time.
      final prefs = await _prefs({quitStageKey: QuitStage.cat.name, quitReportedAtKey(QuitStage.cat.name): hoursAgo(-48)});
      expect(await uploadedContexts(prefs), ['db:unclean-quit:cat']);
    });
  });

  test('the report is uploaded but never shown to the operator', () {
    // What was lost is already lost, and a boot is the worst moment to hand
    // someone a fright they cannot act on. The tier is the whole decision:
    // `notify` would put a "Something went wrong" card in front of an operator
    // starting a session, and `logOnly` would mean nobody ever learns the quit
    // path is failing in the field.
    final decision = ErrorPolicy.decide(const UncleanDatabaseQuit(QuitStage.cat));
    expect(decision.disposition, ErrorDisposition.report);
    expect(decision.disposition.uploads, isTrue);
    expect(decision.disposition.notifies, isFalse);
  });
}
