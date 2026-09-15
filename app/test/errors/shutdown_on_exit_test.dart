// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// SQLite runs on drift's background isolate, and nothing but this hook ever
// closes it. Dropping the close is invisible in every other test — the app
// still quits, the data is still committed — but the VM's teardown then closes
// SQLite while the isolate group is already going down, and the Dart callbacks
// SQLite invokes to destroy its registered functions can no longer be entered:
// the process aborts inside sqlite3_close on the way out of every desktop
// quit, which is a macOS crash report after each Sparkle update relaunch.
//
// The extension runtime is the other isolate that lets native code call back
// into Dart (QuickJS's `send`), and the VM's teardown disables isolate
// creation BEFORE it kills what is still running — so a runtime left alive
// past the exit hook aborts the process on the way out of any quit that
// catches a hook mid flight (HALO-394).
//
// The mutations these catch: deleting `services.db.close()` from
// `closeDatabaseOnExit`, closing without draining first, leaving the
// unclean-quit mark set after a close that worked, leaving
// `ErrorPolicy.appIsExiting` set on an app that is still running — which would
// classify every write of a session that can no longer write at the quietest
// tier there is — dropping the extension runtime's shutdown from the exit
// path or moving it after the database close, letting a start sneak a
// runtime back in once the exit has begun, installing a boot that was already
// in flight, and letting a failed boot arm its retry timer on the way out.

import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:drift/native.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';

import 'package:ham2k_logger/main.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:ham2k_logger/services/error_policy.dart';
import 'package:ham2k_logger/services/extension_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/services/unclean_quit.dart';

import '../support/halo_test_support.dart';

Future<HaLoServices> _services() async {
  return (await makeHaLoServices()).services;
}

/// Answers every asset read with "no such asset" and counts them.
///
/// The extension runtime's boot starts with `assets/extensions/index.json`,
/// so the count says whether a boot BEGAN, independent of whether it could
/// have finished. The string cache is cleared first: an index another test
/// in this process already loaded would otherwise be served from memory and
/// never reach the channel.
///
/// Installed for the rest of the file, deliberately. The test binding's own
/// asset loader is itself a mock on this channel, and clearing ours does not
/// bring it back — a later real boot would then send to a platform that never
/// answers and hang, where this one fails it in a line. So every test in this
/// file that boots a real runtime runs BEFORE the first call to this.
int Function() _countAssetReads(WidgetTester tester) {
  rootBundle.clear();
  var reads = 0;
  tester.binding.defaultBinaryMessenger.setMockMessageHandler('flutter/assets', (message) async {
    reads++;
    return null;
  });
  return () => reads;
}

void main() {
  setUp(ErrorPolicy.resetForTesting);

  group('the exit hook', () {
    // ONE test in this group: the listener is installed into a
    // process-lifetime global (`_shutdownLifecycle ??=`), so a second one
    // would silently exercise the first test's already-closed database.
    testWidgets('a requested exit closes the database, and says so afterwards', (tester) async {
      final services = await _services();
      // Opens it for real: drift's close() is a no-op on a connection that was
      // never used, so a database this test never queried would look "closed"
      // even with the close deleted.
      await services.db.customSelect('SELECT 1').get();

      shutdownOnExit(services);

      expect(await WidgetsBinding.instance.handleRequestAppExit(), AppExitResponse.exit);

      // Set BEFORE the teardown, not after it: the writes that lose their race
      // with the close happen while it runs, and it is this flag that keeps
      // ErrorPolicy from uploading them as sync and peer defects.
      expect(ErrorPolicy.appIsExiting, isTrue);
      await expectLater(services.db.customSelect('SELECT 1').get(), throwsA(isA<StateError>()));
      expect(lastQuitStage(services.settings.prefs), isNull,
          reason: 'a close that finished must not leave the next boot reporting a lost write');

      // Still here, seconds later, with a database that cannot be reopened —
      // which is what a refused exit looks like from inside. The flag has to
      // come back off, or every failure that follows is classified as expected.
      await tester.pump(const Duration(seconds: 3));
      expect(ErrorPolicy.appIsExiting, isFalse);
    });
  });

  group('what a write past the close actually throws', () {
    // Built from the connection the APP uses — a background isolate — and
    // never from a hand-copied string: the in-process executor every other
    // test here opens raises entirely different wording, so a rule matched
    // against that would pass its own tests and never once fire in the field.
    // Which is exactly what happened: the first version of this rule matched
    // only drift's `DelegatedDatabase` messages, and the shipped app fails at
    // the isolate channel long before reaching that code.
    test('is the error ErrorPolicy quietens, on the real connection type', () async {
      final dir = Directory.systemTemp.createTempSync('halo-shutdown-test');
      addTearDown(() => dir.deleteSync(recursive: true));
      final db = HaLoDatabase(NativeDatabase.createBackgroundConnection(File('${dir.path}/db.sqlite')));
      await db.customSelect('SELECT 1').get();
      await db.close();

      Object? thrown;
      try {
        await db.customSelect('SELECT 1').get();
      } catch (e) {
        thrown = e;
      }

      expect(thrown, isNotNull, reason: 'a write past the close has to fail — quietly is not silently');
      ErrorPolicy.appIsExiting = true;
      expect(ErrorPolicy.decide(thrown!).disposition, ErrorDisposition.logOnly);
      ErrorPolicy.appIsExiting = false;
      expect(ErrorPolicy.decide(thrown).disposition, ErrorDisposition.notify,
          reason: 'the same failure mid-session is a defect');
    });
  });

  group('the extension runtime', () {
    testWidgets('is gone before the database closes, on the way out', (tester) async {
      final host = FakeExtensionHost();
      final harness = await makeHaLoServices(extensions: ExtensionServiceWithFakeHost(host));
      final services = harness.services;
      await services.db.customSelect('SELECT 1').get();
      // The database is what hooks write through, so the runtime has to go
      // FIRST: a dispose that finds it already closed is the wrong order.
      var databaseWasOpen = false;
      host.onDispose = () async {
        await services.db.customSelect('SELECT 1').get();
        databaseWasOpen = true;
      };

      expect(await tearDownForExit(services), AppExitResponse.exit);

      expect(host.isDead, isTrue, reason: 'the exit path never disposed the runtime');
      expect(databaseWasOpen, isTrue, reason: 'the runtime was disposed after the database closed');
      await expectLater(services.db.customSelect('SELECT 1').get(), throwsA(isA<StateError>()));
      // Drains the refused-exit timer the teardown arms.
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('a boot still in flight when the exit begins is disposed, not installed', (tester) async {
      // The app starts the runtime unawaited at boot, and an update relaunch
      // can quit within seconds of that. A shutdown that only looks at the
      // host it can see finds none, returns, and the boot then installs one
      // for the VM's teardown — the crash, with nothing left to report it.
      // A REAL boot, so it stays ahead of the asset-counting tests below.
      final service = ExtensionService();

      await tester.runAsync(() async {
        final boot = service.start();
        await service.shutdownForExit();
        await boot;
      });

      expect(service.ready, isFalse);
    });

    testWidgets('cannot be brought back once the exit has begun', (tester) async {
      // A crash-backoff timer, or a credential push arriving mid-quit, both
      // route through start(); a runtime booted from either would be alive
      // for the VM's teardown, which is the whole crash. Observed at the
      // asset channel rather than through `ready`: a boot that is allowed to
      // begin reads the extension index first, whether or not it then
      // succeeds — and a boot that fails after the exit began leaves no
      // other trace, since its retry is (rightly) stood down too.
      final assetReads = _countAssetReads(tester);
      final service = ExtensionService();

      await service.shutdownForExit();
      await service.start();

      expect(assetReads(), 0, reason: 'a start after the exit began must not even begin a boot');
      expect(service.ready, isFalse);
    });

    testWidgets('a boot that fails during the quit schedules no retry', (tester) async {
      // The retry timer would fire after the exit hook has answered, booting
      // a runtime straight into the VM's teardown. Its absence is what the
      // widget test checks on the way out: a timer left pending fails it.
      _countAssetReads(tester); // every asset read fails, so this boot does
      final service = ExtensionService();

      final boot = service.start();
      await service.shutdownForExit();
      await boot;

      expect(service.ready, isFalse);
    });
  });

  group('closing the database', () {
    test('drains before closing, so a write already in flight still lands', () async {
      final services = await _services();
      // Issued and NOT awaited, exactly as a sync round or a debounced local
      // write is in the moment someone hits Cmd-Q. Without the drain the close
      // reaches the isolate while this is mid-transaction and rolls it back.
      final pending = services.db.transaction(() async {
        await services.db.customSelect('SELECT 1').get();
        await services.db.customSelect('SELECT 2').get();
      });

      await closeDatabaseOnExit(services);

      await expectLater(pending, completes);
    });

    test('unmarks a quit whose close finished', () async {
      final services = await _services();
      await services.db.customSelect('SELECT 1').get();

      await closeDatabaseOnExit(services);

      expect(lastQuitStage(services.settings.prefs), isNull);
    });


  });

  group('the stage mark', () {
    test('the radios are marked before they are told to let go', () async {
      // The step that can WEDGE rather than fail, and the one the mark has to
      // reach first: without it a quit that dies saying goodbye to a radio
      // leaves no trace of any kind — no process to report it, since a wedged
      // one never dies, and on Windows a window that makes every later launch
      // a silent no-op instead.
      //
      // Marked BEFORE the step, not after: a mark written afterwards names
      // the last step that SUCCEEDED, which cannot tell a quit that died in
      // the next step from a clean one that got that far.
      late final _StageRecordingCat cat;
      final harness = await makeHaLoServices(
        cat: (settings) => cat = _StageRecordingCat(settings),
      );

      await tearDownForExit(harness.services);

      expect(cat.stageWhenToldToShutDown, QuitStage.cat);
    });

    test('a mark the store REFUSES leaves no stale step behind', () async {
      // The failure mode that matters on the platform this exists for:
      // shared_preferences_windows catches its own IO and answers false, so a
      // refused write never throws and a guard against a throw sees nothing.
      // Left alone, the previous step stays in the pref and the next boot
      // names it with full confidence — a quit that died in the database
      // reported as one that died on a radio, sending whoever reads it after
      // a serial port. No mark says less, and lies less.
      // Over a close that FAILS, so nothing else clears the mark on the way
      // past: with a close that succeeds, the ordinary clean-quit clear wipes
      // the stale step too and the assertion holds whether the refusal is
      // handled or not.
      final harness = await makeHaLoServices(
        prefs: {quitStageKey: QuitStage.cat.name},
        db: _ClosingFailsDatabase(),
      );
      final previous = SharedPreferencesStorePlatform.instance;
      addTearDown(() => SharedPreferencesStorePlatform.instance = previous);
      SharedPreferencesStorePlatform.instance = _RefusingStore();

      await closeDatabaseOnExit(harness.services);

      // Not `QuitStage.cat`, which is what an unhandled refusal leaves: the
      // database failed, and naming the radios would be a confident lie.
      expect(lastQuitStage(harness.settings.prefs), isNull);
    });

    test('a close that fails LEAVES the mark for the next boot to report', () async {
      // The other half, and the one the rest of the file cannot see: every
      // other assertion here is that a finished quit clears the mark, so
      // moving the clear where it always runs — into a finally, or past the
      // close — would keep them all green while the feature silently stopped
      // reporting anything at all.
      final harness = await makeHaLoServices(db: _ClosingFailsDatabase());

      await closeDatabaseOnExit(harness.services);

      expect(lastQuitStage(harness.settings.prefs), QuitStage.databaseClose);
    });
  });
}

/// A [CatService] that answers one question: what had the teardown recorded
/// by the time it reached the radios.
class _StageRecordingCat extends CatService {
  _StageRecordingCat(this._settings) : super(_settings);

  final SettingsService _settings;

  QuitStage? stageWhenToldToShutDown;

  @override
  Future<void> shutdown() async => stageWhenToldToShutDown = lastQuitStage(_settings.prefs);
}

/// A database whose close refuses, which is the only way a test can reach the
/// path where the mark has to survive.
class _ClosingFailsDatabase extends HaLoDatabase {
  _ClosingFailsDatabase() : super(NativeDatabase.memory());

  @override
  Future<void> close() async => throw StateError('close refused');
}

/// A preferences store that REFUSES writes the way the Windows one does —
/// answering false rather than throwing, which is what makes the failure
/// invisible to a caller guarding only against an exception.
class _RefusingStore extends InMemorySharedPreferencesStore {
  _RefusingStore() : super.empty();

  @override
  Future<bool> setValue(String valueType, String key, Object value) async => false;
}
