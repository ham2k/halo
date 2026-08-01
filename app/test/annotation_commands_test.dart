// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// End-to-end verification of the annotation commands (annotation-commands
// extension, ham2k/app-halo-dist#64): NOTE/TODO add note/todo event
// pseudo-QSOs to the log via `addQso`, SOLAR/WEATHER do the same with
// fetched conditions. Since issue #189, SOLAR/WEATHER kick off their fetch
// in the background on ANY recognized interpret() call, not just execute —
// so a "SOLAR" match here does trigger a real (unawaited, unasserted)
// network request as a side effect; only the "not a command" case returns
// before that happens and stays fully network-free. Unlike SOLAR, WEATHER's
// fetch checks location first (operation grid, else `host.getLocation()`,
// APP-34) and bails before ever calling host.fetch when neither is
// available — this test's ExtensionService has no `location` wired, so its
// WEATHER cases stay network-free too. The fetched-data shaping itself, and
// the updateInterpretation push mechanism, are unit-tested elsewhere: solar/
// weather formatting in extensions/core/annotation-commands/src/
// annotations.test.ts, and the push contract in
// packages/halo_extension_host/test/extension_host_test.dart (against a
// fake command hook, no live network).

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:ham2k_logger/services/extension_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoDatabase db;
  late LookupRepository lookups;
  late ExtensionService extensions;

  setUp(() async {
    db = HaLoDatabase(NativeDatabase.memory());
    lookups = LookupRepository(db);
    extensions = ExtensionService()..lookups = lookups;
    await extensions.start();
  });

  tearDown(() async {
    await db.close();
  });

  // NOTE/TODO are operation-scoped, so most tests pass the operation map the
  // logging panel would; the no-operation cases are their own tests. SOLAR/
  // WEATHER are operation-OPTIONAL (APP-34) — `execute` lets a test drive
  // their execute-time (logging) path instead of just the describe preview.
  Future<Map<String, dynamic>?> interpret(
    String input, {
    Map<String, dynamic>? operation = const {'stationCall': 'KI2D'},
    bool execute = false,
  }) async {
    final entries = await extensions.host!.invokeHookAll(
      'command',
      method: 'interpret',
      args: {
        'input': input,
        if (operation != null) 'operation': operation,
        if (execute) 'execute': true,
      },
    );
    for (final entry in entries) {
      if (entry['ok'] == true && entry['value'] is Map) {
        return (entry['value'] as Map).cast<String, dynamic>();
      }
    }
    return null;
  }

  // The ⌘K command dialog's catalog entries — `needsOperation: true` greys
  // an entry out with no operation open (see CommandCatalogEntry in the
  // SDK), so this must track the same operation-optional/-scoped split as
  // `interpret` above, or the palette contradicts what typing the command
  // actually does.
  Future<Map<String, dynamic>> catalogFor(String command) async {
    final entries = await extensions.host!.invokeHookAll('command', method: 'catalog', args: {});
    for (final entry in entries) {
      if (entry['ok'] != true || entry['value'] is! List) continue;
      for (final item in (entry['value'] as List).cast<Map>()) {
        if (item['command'] == command) return item.cast<String, dynamic>();
      }
    }
    fail('no catalog entry for $command');
  }

  group('NOTE command (real annotation-commands extension)', () {
    test('"NOTE This is nice" adds a note event QSO via addQso', () async {
      final result = await interpret('NOTE This is nice');
      expect(result, isNotNull);
      final commands = (result!['commands'] as List).cast<Map>();
      final qsoData = (commands.single['addQso'] as Map).cast<String, dynamic>();
      expect(qsoData['band'], 'event');
      expect(qsoData['event'], {
        'event': 'note',
        'command': 'NOTE This is nice',
        'icon': 'sticker-text-outline',
        'note': 'This is nice',
      });
      // The COMPLETE result must also carry mixedCase — without it, the call
      // field would snap back to uppercase-only while the note is still
      // being typed past the first word.
      expect(result['mixedCase'], isTrue);
    });

    test('an event QSO from NOTE lands in the log as Qso.isEvent, not a contact', () async {
      final operations = OperationsRepository(db);
      final qsos = QsosRepository(db);
      final operation = await operations.create(stationCall: 'KI2D');

      final result = await interpret('NOTE This is when the cops showed up');
      final commands = (result!['commands'] as List).cast<Map>();
      final qsoData = (commands.single['addQso'] as Map).cast<String, dynamic>();
      final qso = await qsos.add(operation.uuid, qsoData);

      expect(qso.isEvent, isTrue);
      expect(qso.isRealContact, isFalse);
      expect(qso.eventKind, 'note');
      expect(qso.event?['note'], 'This is when the cops showed up');
      expect(qso.startAtMillis, isNotNull); // stamped by the repository
    });

    test('"NOTES ..." is an accepted alias', () async {
      final result = await interpret('NOTES also works');
      final commands = (result!['commands'] as List).cast<Map>();
      final event = ((commands.single['addQso'] as Map)['event'] as Map).cast<String, dynamic>();
      expect(event['note'], 'also works');
    });

    test('a bare "NOTE" expects params — it is recognized but not executable yet', () async {
      final result = await interpret('NOTE');
      expect(result, {'expectsParams': true, 'mixedCase': true});
    });

    test('"NOTE" followed only by whitespace also expects params', () async {
      // The exact state the field is in the instant the user types the
      // space before the note text — must not become a complete command
      // with empty text or a non-match.
      final result = await interpret('NOTE   ');
      expect(result, {'expectsParams': true, 'mixedCase': true});
    });

    test('text that does not start with NOTE is not a command', () async {
      expect(await interpret('W1AW'), isNull);
    });

    test('without an operation (home quick search), NOTE is an error, not a silent non-match', () async {
      final result = await interpret('NOTE This is nice', operation: null);
      expect(result, {'error': 'NOTE needs an open operation'});
    });
  });

  group('TODO command', () {
    test('"TODO Fix this call" adds a todo event QSO, initially not done', () async {
      final result = await interpret('TODO Fix this call');
      final commands = (result!['commands'] as List).cast<Map>();
      final qsoData = (commands.single['addQso'] as Map).cast<String, dynamic>();
      expect(qsoData['band'], 'event');
      expect(qsoData['event'], {
        'event': 'todo',
        'command': 'TODO Fix this call',
        'icon': 'sticker-outline',
        'note': 'Fix this call',
        'data': {'done': false},
      });
      expect(result['mixedCase'], isTrue);
    });

    test('a bare "TODO" expects params', () async {
      final result = await interpret('TODO');
      expect(result, {'expectsParams': true, 'mixedCase': true});
    });

    test('without an operation, TODO is an error', () async {
      final result = await interpret('TODO Fix this call', operation: null);
      expect(result, {'error': 'TODO needs an open operation'});
    });
  });

  group('SOLAR command', () {
    test('a recognized describe preview returns a placeholder immediately, without awaiting its fetch (issue #189)', () async {
      // interpret() itself never blocks on the network — it kicks the fetch
      // off in the background (see the file header) and returns this
      // placeholder synchronously. What that fetch eventually pushes via
      // host.updateInterpretation isn't asserted here.
      final result = await interpret('SOLAR');
      expect(result, {'describe': 'Fetching solar conditions…'});
    });

    // Solar conditions are global data, not tied to any operation (APP-34) —
    // SOLAR fetches/describes the same with or without one open; only its
    // `addQso` logging step (untested here, since it needs a real network
    // fetch to resolve) is skipped with no operation to log to.
    test('without an operation (home quick search), SOLAR still fetches instead of erroring (APP-34)', () async {
      final result = await interpret('SOLAR', operation: null);
      expect(result, {'describe': 'Fetching solar conditions…'});
    });

    test('"SOLARX" is not a command', () async {
      expect(await interpret('SOLARX'), isNull);
    });

    test('the ⌘K palette entry is not greyed out for lack of an operation (APP-34)', () async {
      final entry = await catalogFor('SOLAR');
      expect(entry['needsOperation'], isNot(true));
    });
  });

  group('WEATHER command', () {
    test('with a gridded operation, a recognized describe preview returns a placeholder immediately (issue #189)', () async {
      final result = await interpret(
        'WEATHER',
        operation: {'stationCall': 'KI2D', 'grid': 'FN21vs'},
      );
      expect(result, {'describe': 'Fetching current weather…'});
    });

    // The grid/location check moved into the background fetch (APP-34), so
    // even a grid-less/operation-less describe preview returns the same
    // placeholder immediately — see the execute:true tests below for what
    // it resolves to.
    test('without a grid on the operation, the describe preview still returns a placeholder', () async {
      final result = await interpret('WEATHER');
      expect(result, {'describe': 'Fetching current weather…'});
    });

    test('without an operation, the describe preview still returns a placeholder (APP-34)', () async {
      final result = await interpret('WEATHER', operation: null);
      expect(result, {'describe': 'Fetching current weather…'});
    });

    // No device location is wired into this test's ExtensionService (no
    // `location` set in setUp), so `host.getLocation()` resolves null and
    // this hits the "no location at all" error path — without a live
    // network call, since fetchWeatherData bails before calling host.fetch.
    test('executed with a grid-less operation and no device location, WEATHER errors instead of logging', () async {
      final result = await interpret('WEATHER', execute: true);
      expect(result?['error'], contains('grid'));
    });

    test('executed with no operation and no device location, WEATHER errors — not "needs an operation" (APP-34)', () async {
      final result = await interpret('WEATHER', operation: null, execute: true);
      expect(result?['error'], isNot('WEATHER needs an open operation'));
      expect(result?['error'], contains('location'));
    });

    test('the ⌘K palette entry is not greyed out for lack of an operation (APP-34)', () async {
      final entry = await catalogFor('WEATHER');
      expect(entry['needsOperation'], isNot(true));
    });
  });

  group('getLocation host call gate (APP-34)', () {
    // `getLocation` exposes the device's raw GPS position — like host.fetch's
    // `domains` allowlist, an extension must declare a manifest capability
    // (`requiresLocation`) before it's allowed to call it. annotation-commands
    // does (manifest.json), so its own key is allowed; any other extension
    // key is refused, whether or not it's a real extension.
    test('an extension that declares requiresLocation (annotation-commands) is allowed', () async {
      // No `location` service wired in this test host, so the call still
      // resolves null — but NOT via the gate's ExtensionHostException.
      final result = await extensions.debugHandleHostCall('getLocation', {'extensionKey': 'annotation-commands'});
      expect(result, isNull);
    });

    test('an extension that does not declare requiresLocation is blocked', () async {
      expect(
        () => extensions.debugHandleHostCall('getLocation', {'extensionKey': 'pota'}),
        throwsA(isA<ExtensionHostException>().having((e) => e.toString(), 'message', contains('requiresLocation'))),
      );
    });

    test('a call with no extension identity at all is blocked', () async {
      expect(
        () => extensions.debugHandleHostCall('getLocation', {}),
        throwsA(isA<ExtensionHostException>()),
      );
    });
  });
}
