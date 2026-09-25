// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// ExtensionService._start() resolves each account's `synchronizable` flag by
// asking the kernel for the account definitions. The kernel answers that by
// calling BACK into Dart (`getAccount`, to build the hook ctx for any account
// member that is a function — QRZ's description/fields, SOTA's oauth2), and
// that host call used to wait on the very completer the refresh was on its way
// to completing. The two waited on each other until the hook's 2s timeout fired.
//
// It failed on EVERY launch, on every platform — reproduced on macOS and on web
// — and the timeout was the only thing that ended it, so raising the budget
// only lengthened the stall (measured: a 30s budget failed at 30199ms, and the
// call right after it took 7ms).
//
// The visible symptom was one log line, but the damage was silent: the timeout
// is swallowed into an empty list, so the flag map stayed empty for the whole
// session and QRZ's declared `synchronizable: true` was ignored — on iOS that
// reads and writes the wrong keychain item, and a QRZ login stops following the
// user between devices with no error anywhere.

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Boots a real service against the real kernel and bundles, capturing
  /// debugPrint so the test can see the failure the service swallows.
  Future<({ExtensionService extensions, List<String> logs, Duration elapsed})> boot() async {
    final logs = <String>[];
    final original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) logs.add(message);
    };
    addTearDown(() => debugPrint = original);

    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final extensions = ExtensionService()..lookups = LookupRepository(db);

    final clock = Stopwatch()..start();
    await extensions.start();
    clock.stop();
    return (extensions: extensions, logs: logs, elapsed: clock.elapsed);
  }

  test('the boot-time account refresh does not deadlock against its own gate', () async {
    final booted = await boot();

    // The flags are the point. An empty map means the refresh never got its
    // answer — which is what shipped: every account silently device-local.
    expect(
      booted.extensions.accountSynchronizable,
      isNotEmpty,
      reason:
          'the boot-time account refresh resolved no flags at all, so every '
          'account falls back to device-local for the whole session',
    );
    expect(
      booted.extensions.accountSynchronizable['qrz'],
      isTrue,
      reason:
          "QRZ declares synchronizable: true so a QRZ login follows the user "
          'across their Apple devices; losing that flag breaks iCloud Keychain '
          'sync silently, with no error and no failed operation',
    );

    // The deadlock announced itself here before the fix. Asserting on it keeps
    // the test honest: the flags could also be resolved by some future path
    // that still eats a 2s timeout on the way, and that is still a bug.
    expect(
      booted.logs.where((l) => l.contains('getAccounts failed')),
      isEmpty,
      reason:
          'boot logged a getAccounts failure:\n'
          '${booted.logs.where((l) => l.contains('getAccounts')).join('\n')}',
    );
  });

  test('start() does not stall on the account hook timeout', () async {
    final booted = await boot();

    // The healthy fan-out costs single-digit ms; the deadlock cost exactly the
    // 2000ms hook budget, every launch. A whole second of margin keeps this
    // from being a flaky timing assertion while still catching a reintroduced
    // wait — and unlike the log check above, this one still fires if someone
    // "fixes" the deadlock by lowering the timeout.
    expect(
      booted.elapsed,
      lessThan(const Duration(milliseconds: 1500)),
      reason:
          'start() took ${booted.elapsed.inMilliseconds}ms, which is the '
          'shape of waiting out a hook timeout rather than doing work',
    );
  });

  test('a direct caller still waits for the flags, so the gate keeps working', () async {
    // The gate itself must survive the fix: lookups fire as soon as `ready`
    // flips, which happens BEFORE the flags are cached, and letting them through
    // unresolved is the race the gate was added for (#139). Verified to fail if
    // the gate is deleted outright.
    //
    // What this does NOT catch, measured rather than assumed: widening the
    // bypass to every caller instead of just host calls. That only changes
    // behaviour for a call arriving inside the few-ms refresh window at the end
    // of start(), and a call issued here parks on the gate long before that
    // window opens. Landing in it deterministically needs a seam the service
    // doesn't have, so the scoping is held by review and by the comment on
    // _accountKeychainOptions, not by this test. Said plainly because a test
    // named for a guarantee it doesn't provide is worse than no test.
    const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async => null);
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));

    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final extensions = ExtensionService()..lookups = LookupRepository(db);

    final starting = extensions.start();
    var credentialsResolved = false;
    final credentials = extensions.getAccountCredentials('qrz').then((value) {
      credentialsResolved = true;
      return value;
    });

    // Yield generously. Start has to load and evaluate every bundle, so it
    // cannot possibly be finished — which means the gate is still shut and a
    // direct caller must still be parked behind it. With a blanket bypass this
    // read would sail through against an unresolved flag.
    for (var i = 0; i < 50; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(
      credentialsResolved,
      isFalse,
      reason:
          'a direct credential read resolved before the boot-time flags did, '
          'so it used the device-local default instead of the account\'s '
          'declared flag — the race the gate exists to prevent',
    );

    await starting;
    await credentials;
    expect(credentialsResolved, isTrue);
    expect(extensions.accountSynchronizable['qrz'], isTrue);
  });
}
