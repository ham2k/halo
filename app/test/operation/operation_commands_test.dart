// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// OPER / POSITION (operation-commands extension), through the real bundled
// JS. The parsing itself is covered by the extension's own node tests; what
// these pin is everything those cannot see — that the bundle is registered
// and reached at all, and that both commands answer with the
// `updateOperation` action the app dispatches, with the operator callsign
// and the position in the fields the app writes to different places.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ExtensionService extensions;

  setUp(() async {
    extensions = ExtensionService();
    await extensions.start();
  });

  /// Both commands are operation-scoped, so the operation goes in — without
  /// it every one of them answers with `error` instead.
  Future<Map<String, dynamic>?> interpret(String input, {bool withOperation = true}) async {
    final entries = await extensions.host!.invokeHookAll(
      'command',
      method: 'interpret',
      args: {
        'input': input,
        if (withOperation) 'operation': {'stationCall': 'K2SUL'},
      },
    );
    for (final entry in entries) {
      if (entry['ok'] == true && entry['value'] is Map) {
        return (entry['value'] as Map).cast<String, dynamic>();
      }
    }
    return null;
  }

  Map<String, dynamic> actionOf(Map<String, dynamic> result) =>
      ((result['commands'] as List).cast<Map>().single['updateOperation'] as Map).cast<String, dynamic>();

  test('"OPER KI2D" sets the operator callsign', () async {
    final result = await interpret('OPER KI2D');
    expect(result, isNotNull);
    expect(actionOf(result!), {'operatorCall': 'KI2D'});
  });

  test('the longer OPERATOR and the slash form reach the same action', () async {
    for (final input in ['OPERATOR KI2D', 'OPER/KI2D']) {
      expect(actionOf((await interpret(input))!), {'operatorCall': 'KI2D'}, reason: input);
    }
  });

  test('"POSITION 2" sets the position, and 0 clears it', () async {
    expect(actionOf((await interpret('POSITION 2'))!), {'multiIdentifier': '2'});
    // The only way to undo a position without opening the dialog.
    expect(actionOf((await interpret('POSITION 0'))!), {'multiIdentifier': ''});
  });

  test('a position that is not a number is refused rather than guessed at', () async {
    // It would otherwise end up inside a callsign on the air.
    final result = await interpret('POSITION LEFT');
    expect(result!['error'], isA<String>());
    expect(result['commands'], isNull);
  });

  test('the bare words wait for their parameter instead of logging as a callsign', () async {
    for (final input in ['OPER', 'OPERATOR', 'POSITION']) {
      final result = await interpret(input);
      expect(result, isNotNull, reason: input);
      expect(result!['expectsParams'], isTrue, reason: input);
      expect(result['commands'], isNull, reason: input);
    }
  });

  test('START, BREAK, STOP and END answer with a markSegment action of their kind', () async {
    Future<Map<String, dynamic>> segmentOf(String input) async =>
        ((((await interpret(input))!['commands'] as List).single as Map)['markSegment'] as Map).cast<String, dynamic>();
    expect(await segmentOf('START'), {'kind': 'start'});
    expect(await segmentOf('BREAK'), {'kind': 'break'});
    expect(await segmentOf('STOP'), {'kind': 'stop'});
    // END is polo's alias, and writes the same `stop` row.
    expect(await segmentOf('end'), {'kind': 'stop'});
    // ROVERQTH is a break that goes on to ask for the new location.
    expect(await segmentOf('ROVERQTH'), {'kind': 'break', 'setLocation': true});
    // A longer word is a callsign.
    expect(await interpret('STOPX'), isNull);
  });

  test('with no operation open every one of them says so rather than silently doing nothing', () async {
    for (final input in ['OPER KI2D', 'POSITION 2', 'START', 'BREAK', 'STOP', 'ROVERQTH']) {
      final result = await interpret(input, withOperation: false);
      expect(result!['error'], isA<String>(), reason: input);
    }
  });

  test('a callsign that merely starts with the word still logs as a callsign', () async {
    expect(await interpret('OPERA'), isNull);
  });
}
