// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// End-to-end verification of the NOTE call-field command (note-command
// extension): "NOTE <text>" sets the QSO's notes field via `updateQso`, and
// a bare "NOTE" expects params (recognized prefix, not executable yet) —
// the same `expectsParams` contract exercised by reload_command_test.dart.

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

  Future<Map<String, dynamic>?> interpret(String input) async {
    final entries = await extensions.host!.invokeHookAll(
      'command',
      method: 'interpret',
      args: {'input': input},
    );
    for (final entry in entries) {
      if (entry['ok'] == true && entry['value'] is Map) {
        return (entry['value'] as Map).cast<String, dynamic>();
      }
    }
    return null;
  }

  group('NOTE command interpretation (real note-command extension)', () {
    test('"NOTE This is nice" sets the notes field via updateQso', () async {
      final result = await interpret('NOTE This is nice');
      expect(result, isNotNull);
      final commands = (result!['commands'] as List).cast<Map>();
      expect(commands.single['updateQso'], {'notes': 'This is nice'});
    });

    test('a bare "NOTE" expects params — it is recognized but not executable yet', () async {
      final result = await interpret('NOTE');
      expect(result, {'expectsParams': true});
    });

    test('"NOTE" followed only by whitespace also expects params', () async {
      final result = await interpret('NOTE   ');
      expect(result, {'expectsParams': true});
    });

    test('text that does not start with NOTE is not a command', () async {
      expect(await interpret('W1AW'), isNull);
    });
  });
}
