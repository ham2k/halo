// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// End-to-end verification of the annotation commands (annotation-commands
// extension, ham2k/app-halo-dist#64): NOTE/TODO add note/todo event
// pseudo-QSOs to the log via `addQso`, SOLAR/WEATHER do the same with
// fetched conditions — fetched only at execute time, so everything below
// exercises the describe/error paths, which never touch the network.
// (The SOLAR/WEATHER data shaping itself is unit-tested in
// extensions/core/annotation-commands/src/annotations.test.ts.)

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
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

  // All four commands are operation-scoped, so the tests pass the operation
  // map the logging panel would; the no-operation cases are their own tests.
  Future<Map<String, dynamic>?> interpret(
    String input, {
    Map<String, dynamic>? operation = const {'stationCall': 'KI2D'},
  }) async {
    final entries = await extensions.host!.invokeHookAll(
      'command',
      method: 'interpret',
      args: {
        'input': input,
        if (operation != null) 'operation': operation,
      },
    );
    for (final entry in entries) {
      if (entry['ok'] == true && entry['value'] is Map) {
        return (entry['value'] as Map).cast<String, dynamic>();
      }
    }
    return null;
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
    test('describe preview never fetches — a cheap describe-only result', () async {
      // `execute` is unset above, so a fetch here would be a bug even if it
      // worked; the deterministic describe-only result is the proof it
      // didn't happen.
      final result = await interpret('SOLAR');
      expect(result, {'describe': 'Add current solar conditions to the log?'});
    });

    test('without an operation, SOLAR is an error', () async {
      final result = await interpret('SOLAR', operation: null);
      expect(result, {'error': 'SOLAR needs an open operation'});
    });

    test('"SOLARX" is not a command', () async {
      expect(await interpret('SOLARX'), isNull);
    });
  });

  group('WEATHER command', () {
    test('with a gridded operation, the describe preview never fetches', () async {
      final result = await interpret(
        'WEATHER',
        operation: {'stationCall': 'KI2D', 'grid': 'FN21vs'},
      );
      expect(result, {'describe': 'Add current weather to the log?'});
    });

    test('without a grid on the operation, WEATHER is an error (no geolocation fallback)', () async {
      final result = await interpret('WEATHER');
      expect(result?['error'], contains('grid'));
    });

    test('without an operation, WEATHER is an error', () async {
      final result = await interpret('WEATHER', operation: null);
      expect(result, {'error': 'WEATHER needs an open operation'});
    });
  });
}
