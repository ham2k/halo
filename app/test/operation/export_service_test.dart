// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Developer Mode QSON export: the raw QSON payload (operation + QSOs in one
// JSON file, same shape app-polo exports) must be offered only when developer
// mode is on, and must be generated core-side — no extension runtime needed —
// so it works even while the extension host is still booting.

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ham2k_logger/services/android_file_save.dart';
import 'package:ham2k_logger/services/export_service.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/hook_payloads.dart';
import 'package:ham2k_logger/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoDatabase db;
  late SettingsService settings;
  late ExportService exports;
  late Operation operation;

  setUp(() async {
    db = HaLoDatabase(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    settings = await SettingsService.load();
    final operations = OperationsRepository(db);
    final qsos = QsosRepository(db);
    // ExtensionService never started: host stays null, so extension-suggested
    // options are empty and any option we see comes from the core.
    exports = ExportService(extensions: ExtensionService(), qsos: qsos, settings: settings);

    final created = await operations.create(stationCall: 'N0CALL', userTitle: 'Test Op');
    await qsos.add(created.uuid, {
      'their': {'call': 'W1AW'},
      'band': '20m',
      'mode': 'SSB',
      'startAtMillis': DateTime.utc(2026, 7, 15, 12).millisecondsSinceEpoch,
    });
    // Re-fetch so startAtMillisMax (stamped by the QSO write) is populated —
    // the QSON filename derives its date from it.
    operation = (await operations.get(created.uuid))!;
  });

  tearDown(() async {
    await db.close();
  });

  test('an operation with nothing logged offers no options, and is not a failure', () async {
    // The panel renders a thrown ExportException as "Export failed: …", so a
    // throw here is a red wall in front of anyone who opens Exports before
    // their first contact. Asking what CAN be exported is a question an
    // empty log answers; exporting one is a request it refuses.
    await settings.setDeveloperMode(true);
    final operations = OperationsRepository(db);
    final empty = await operations.create(stationCall: 'N0CALL', userTitle: 'Empty Op');

    final none = await exports.getExportOptions(empty);
    expect(none, isEmpty);
    // Sorted, because that is the first thing the panel does with the list
    // (`_load`) and `sort` throws on an unmodifiable one whatever its length.
    // Asserting only `isEmpty` cannot fail on an empty answer the caller
    // cannot use.
    expect(() => none.sort((a, b) => 0), returnsNormally);

    // …and the refusal is still there where it belongs: asked to actually
    // produce a file for a log with nothing in it, the service throws.
    final options = await exports.getExportOptions(operation);
    await expectLater(exports.generateExports(empty, options), throwsA(isA<ExportException>()));
  });

  test('QSON option is hidden unless developer mode is enabled', () async {
    expect(await exports.getExportOptions(operation), isEmpty);

    await settings.setDeveloperMode(true);
    final options = await exports.getExportOptions(operation);
    expect(options, hasLength(1));
    expect(options.single['exportType'], 'devmode-qson');
    expect(options.single['selectedByDefault'], false);
    expect(options.single['filename'], endsWith('.qson'));
  });

  test('generates a single JSON file with operation data and QSOs, without the extension host', () async {
    await settings.setDeveloperMode(true);
    final options = await exports.getExportOptions(operation);

    final files = await exports.generateExports(operation, options);
    expect(files, hasLength(1));
    expect(files.single['mimeType'], 'application/json');
    expect(files.single['filename'], '2026-07-15 N0CALL ${operation.uuid.split('-').first}.qson');

    final decoded = jsonDecode(files.single['content'] as String) as Map<String, dynamic>;
    final operationData = decoded['operation'] as Map<String, dynamic>;
    expect(operationData['uuid'], operation.uuid);
    expect(operationData['stationCall'], 'N0CALL');
    expect(operationData['userTitle'], 'Test Op');
    final qsoList = decoded['qsos'] as List;
    expect(qsoList, hasLength(1));
    expect((qsoList.single as Map)['their'], {'call': 'W1AW'});
  });

  test("the QSON dump names the operation's operators as stored, whichever seat exports it", () async {
    // The hook payload resolves the operator for THIS device's seat and writes
    // it over the positionless slot; a dump built from it hands a copy of the
    // log the second seat's operator as everyone's.
    await settings.setDeveloperMode(true);
    final seated = Operation(
      uuid: operation.uuid,
      data: {...operation.data, 'operatorCall': 'K1A', 'operator2': 'K2B'},
      startAtMillisMin: operation.startAtMillisMin,
      startAtMillisMax: operation.startAtMillisMax,
      localData: {multiIdentifierKey: '2'},
    );

    final file = (await exports.generateExports(seated, await exports.getExportOptions(seated))).single;
    final dumped = (jsonDecode(file['content'] as String) as Map)['operation'] as Map;
    expect(dumped['operatorCall'], 'K1A');
    expect(dumped['operator2'], 'K2B');
    expect(dumped['local'], {'operatorCall': 'K1A'}, reason: 'where app-polo reads it');
  });

  test('the QSON dump carries the whole stored log, and imports back segmented', () async {
    // The segments live in `break`/`start` event rows, which the contact list
    // the other exports read leaves out; a dump read from that list imports
    // as ONE segment, every later contact under the base operation's park.
    await settings.setDeveloperMode(true);
    final operations = OperationsRepository(db);
    final qsos = QsosRepository(db);
    final noon = DateTime.utc(2026, 7, 15, 12).millisecondsSinceEpoch;
    await qsos.add(operation.uuid, {
      'band': 'event',
      'event': {
        'event': 'break',
        'operation': {
          'refs': [
            {'type': 'potaActivation', 'ref': 'US-0002'},
          ],
        },
      },
      'startAtMillis': noon + 60000,
    });
    await qsos.add(operation.uuid, {
      'their': {'call': 'K2ABC'},
      'band': '20m',
      'mode': 'SSB',
      'startAtMillis': noon + 120000,
    });
    // A row column, not `data`: without folding it in, a tombstone reads as a
    // live contact in the file and is imported as one.
    await qsos.softDelete(
      await qsos.add(operation.uuid, {
        'their': {'call': 'N3XYZ'},
        'band': '20m',
        'mode': 'SSB',
        'startAtMillis': noon + 180000,
      }),
    );
    final stored = (await operations.get(operation.uuid))!;

    final file = (await exports.generateExports(stored, await exports.getExportOptions(stored))).single;
    final dumped = ((jsonDecode(file['content'] as String) as Map)['qsos'] as List).cast<Map<String, dynamic>>();
    expect(dumped.where((q) => q['band'] == 'event'), hasLength(1));
    expect(dumped.singleWhere((q) => asQsonMap(q['their'])?['call'] == 'N3XYZ')['deleted'], isTrue);

    final copy = await importQsonOperation(db: db, operations: operations, qsos: qsos, bytes: utf8.encode(file['content'] as String));
    final copied = await qsos.forOperation(copy.uuid, includeDeleted: true);
    final segmented = SegmentedOperation.from(operation: copy.data, qsos: copied);
    expect(segmented.isSegmented, isTrue);
    final later = copied.singleWhere((q) => q.theirCall == 'K2ABC');
    expect((segmented.effectiveAt(later.startAtMillis)['refs'] as List).single['ref'], 'US-0002');
    expect(copied.map((q) => q.theirCall), isNot(contains('N3XYZ')));
  });

  // A multi-operator station logs everything in one operation but owes each
  // callsign its own submission, so the hooks are asked once per call against
  // an operation cloned to carry only that one.
  group('multiple station callsigns', () {
    late OperationsRepository operations;
    late QsosRepository qsos;

    setUp(() {
      operations = OperationsRepository(db);
      qsos = QsosRepository(db);
    });

    Future<Operation> multiOp() async {
      final created = await operations.create(stationCall: 'N0CALL, W1AW', userTitle: 'Multi Op');
      await qsos.add(created.uuid, {
        'our': {'call': 'N0CALL'},
        'their': {'call': 'DL1ABC'},
        'band': '20m',
        'mode': 'SSB',
        'startAtMillis': DateTime.utc(2026, 7, 15, 12).millisecondsSinceEpoch,
      });
      // The two operators working each other — valid in the log, impossible
      // in W1AW's own submission.
      await qsos.add(created.uuid, {
        'our': {'call': 'N0CALL'},
        'their': {'call': 'W1AW'},
        'band': '40m',
        'mode': 'CW',
        'startAtMillis': DateTime.utc(2026, 7, 15, 13).millisecondsSinceEpoch,
      });
      return (await operations.get(created.uuid))!;
    }

    // Claiming and filtering is a MULTI-operator rule. Applied to an ordinary
    // single-station log it would silently drop a QSO the operator made with
    // their own other rig — from every file, the whole-log backup included.
    test('a single-callsign operation is passed through untouched', () async {
      final operations = OperationsRepository(db);
      final qsos = QsosRepository(db);
      final created = await operations.create(stationCall: 'N0CALL', userTitle: 'Solo');
      await qsos.add(created.uuid, {
        // Worked their own callsign — a second rig at the same station.
        'our': {'call': 'OTHERCALL'},
        'their': {'call': 'N0CALL'},
        'band': '20m',
        'mode': 'SSB',
        'startAtMillis': DateTime.utc(2026, 7, 15, 12).millisecondsSinceEpoch,
      });
      final op = (await operations.get(created.uuid))!;

      final extensions = _ExtensionsWithHost(_CapturingHost());
      final service = ExportService(extensions: extensions, qsos: qsos, settings: settings);
      await service.getExportOptions(op);

      final sent = extensions.optionRequests.single['qsos'] as List;
      expect(sent, hasLength(1), reason: 'nothing is dropped when there is only one callsign');
      expect(((sent.single as Map)['our'] as Map)['call'], 'OTHERCALL', reason: 'the logged operator call is left alone, not rewritten');
    });

    test('the comma-separated field parses into one call per submission', () async {
      final op = await multiOp();
      expect(op.stationCalls, ['N0CALL', 'W1AW']);
    });

    test('a single call — the normal case — still yields exactly one', () async {
      expect(operation.stationCalls, ['N0CALL']);
    });

    test('a repeated call is a typo, not a request for two identical file sets', () async {
      final created = await operations.create(stationCall: 'N0CALL, n0call ', userTitle: 'Dupe');
      expect((await operations.get(created.uuid))!.stationCalls, ['N0CALL']);
    });

    test('a call that only a segment names is still offered its own files', () async {
      // A log that changed callsign at a BREAK has two calls while the
      // operation itself names one. Reading the base alone would offer the
      // last call's files and nothing for the stretch before it.
      final created = await operations.create(stationCall: 'W1AW', userTitle: 'Roved');
      await qsos.addEvent(created.uuid, kind: 'start', atMillis: 1000, operation: {'stationCall': 'N0CALL'});
      await qsos.addEvent(created.uuid, kind: 'break', atMillis: 3000, operation: {'stationCall': 'W1AW'});
      final op = (await operations.get(created.uuid))!;
      await qsos.add(op.uuid, {
        'our': {'call': 'N0CALL'},
        'their': {'call': 'DL1ABC'},
        'band': '20m',
        'startAtMillis': 2000,
      });
      await qsos.add(op.uuid, {
        'our': {'call': 'W1AW'},
        'their': {'call': 'K1ABC'},
        'band': '20m',
        'startAtMillis': 4000,
      });

      final extensions = _ExtensionsWithHost(_CapturingHost());
      final service = ExportService(extensions: extensions, qsos: qsos, settings: settings);
      await service.getExportOptions(op);

      // Unordered: what matters is that BOTH are offered. The order is the
      // segments' own — the base operation first, then each override as it
      // appears — which the panel groups by and nothing else depends on.
      expect(
        extensions.optionRequests.map((r) => (r['operation'] as Map)['stationCall']),
        unorderedEquals(['N0CALL', 'W1AW']),
        reason: 'the call the first stretch ran under owes files too',
      );
      // ACROSS segments a call takes only its own stretch — the opposite of
      // several calls WITHIN one, where each claims the whole log. Claiming
      // everything here would put N0CALL's contacts into W1AW's submission,
      // by a station that was not on the air for them.
      final byCall = {
        for (final request in extensions.optionRequests)
          ((request['operation'] as Map)['stationCall'] as String): ((request['qsos'] as List).map((qso) => ((qso as Map)['their'] as Map)['call']).toList()),
      };
      expect(byCall['N0CALL'], ['DL1ABC']);
      expect(byCall['W1AW'], ['K1ABC']);
    });

    test('the hooks are asked once per call, each seeing only its own', () async {
      final extensions = _ExtensionsWithHost(_CapturingHost());
      final service = ExportService(extensions: extensions, qsos: qsos, settings: settings);

      await service.getExportOptions(await multiOp());

      expect(extensions.optionRequests, hasLength(2));
      expect(
        extensions.optionRequests.map((r) => (r['operation'] as Map)['stationCall']),
        ['N0CALL', 'W1AW'],
        reason:
            'each hook call sees a single-station operation, so filenames and '
            'ADIF/Cabrillo callsign fields name the right one without the hooks knowing',
      );
    });

    test("every QSO is claimed by whichever call is exporting", () async {
      final extensions = _ExtensionsWithHost(_CapturingHost());
      final service = ExportService(extensions: extensions, qsos: qsos, settings: settings);

      await service.getExportOptions(await multiOp());

      List<String?> ourCalls(int index) => [
        for (final qso in extensions.optionRequests[index]['qsos'] as List) ((qso as Map)['our'] as Map)['call'] as String?,
      ];
      expect(ourCalls(0), everyElement('N0CALL'));
      expect(ourCalls(1), everyElement('W1AW'), reason: "W1AW's log is W1AW's, not a copy of N0CALL's");
    });

    // Otherwise W1AW's file claims a QSO in which W1AW worked W1AW, which no
    // program will accept.
    test('the two operators working each other drops out of the second one\'s log', () async {
      final extensions = _ExtensionsWithHost(_CapturingHost());
      final service = ExportService(extensions: extensions, qsos: qsos, settings: settings);

      await service.getExportOptions(await multiOp());

      expect((extensions.optionRequests[0]['qsos'] as List), hasLength(2), reason: 'N0CALL worked both');
      expect((extensions.optionRequests[1]['qsos'] as List), hasLength(1), reason: 'W1AW cannot have worked itself');
    });

    test("each call's file carries only its own stretches' events", () async {
      // The full ADIF writes the events it is handed among the contacts, so
      // another call's breaks and notes would land in a log it never kept.
      final created = await operations.create(stationCall: 'W1AW');
      await qsos.addEvent(created.uuid, kind: 'start', atMillis: 1000, operation: {'stationCall': 'N0CALL'});
      await qsos.addEvent(created.uuid, kind: 'break', atMillis: 3000, operation: {'stationCall': 'W1AW'});
      for (final (call, at) in [('DL1ABC', 2000), ('K1ABC', 4000)]) {
        await qsos.add(created.uuid, {
          'their': {'call': call},
          'band': '20m',
          'startAtMillis': at,
        });
      }
      final host = _CapturingHost();
      final service = ExportService(extensions: _ExtensionsWithHost(host), qsos: qsos, settings: settings);

      await service.generateExports((await operations.get(created.uuid))!, [
        {'hookKey': 'adif', 'exportType': 'adif', 'stationCall': 'N0CALL'},
        {'hookKey': 'adif', 'exportType': 'adif', 'stationCall': 'W1AW'},
      ]);

      List<Object?> eventTimes(String call) => [
        for (final request in host.calls)
          if (((request['args'] as Map)['operation'] as Map)['stationCall'] == call)
            for (final event in (request['args'] as Map)['events'] as List) (event as Map)['startAtMillis'],
      ];
      expect(eventTimes('N0CALL'), [1000]);
      expect(eventTimes('W1AW'), [3000]);
    });

    test('generating rebuilds the payload for the call the option was listed under', () async {
      final host = _CapturingHost();
      final service = ExportService(extensions: _ExtensionsWithHost(host), qsos: qsos, settings: settings);
      final op = await multiOp();

      await service.generateExports(op, [
        {'hookKey': 'adif', 'exportType': 'adif', 'stationCall': 'W1AW'},
      ]);

      final args = host.calls.single['args'] as Map;
      expect((args['operation'] as Map)['stationCall'], 'W1AW');
    });
  });

  // "Use compact file names" is a setting the CORE owns but the EXTENSIONS
  // apply — each hook builds its own name from it (`exportFilename` in the
  // SDK). So the only thing the core can be held to is that the setting
  // actually reaches both hook calls, and that the name the panel showed is
  // the name the file gets.
  group('filename form', () {
    test('the QSON dump takes both forms, so developer mode is not an exception', () async {
      await settings.setDeveloperMode(true);
      expect((await exports.getExportOptions(operation)).single['filename'], '2026-07-15 N0CALL ${operation.uuid.split('-').first}.qson');

      await settings.setUseCompactFileNames(true);
      expect((await exports.getExportOptions(operation)).single['filename'], 'N0CALL-20260715-${operation.uuid.split('-').first}.qson');
    });

    test('the setting reaches the hooks that list options AND the ones that generate', () async {
      final qsos = QsosRepository(db);
      final extensions = _ExtensionsWithHost(_CapturingHost());
      final service = ExportService(extensions: extensions, qsos: qsos, settings: settings);

      await settings.setUseCompactFileNames(true);
      await service.getExportOptions(operation);
      expect(extensions.optionRequests.single['compactFilenames'], isTrue);

      await service.generateExports(operation, [
        {'hookKey': 'adif', 'exportType': 'adif'},
      ]);
      final host = extensions.host as _CapturingHost;
      expect((host.calls.single['args'] as Map)['compactFilenames'], isTrue);
    });

    test('generation receives the stable type and each selected option key', () async {
      final host = _CapturingHost();
      final service = ExportService(extensions: _ExtensionsWithHost(host), qsos: QsosRepository(db), settings: settings);

      await service.generateExports(operation, [
        {'hookKey': 'pota', 'exportType': 'potaActivation-adif', 'exportKey': 'pota-adif:US-1234'},
        {'hookKey': 'pota', 'exportType': 'potaActivation-adif', 'exportKey': 'pota-adif:US-5678'},
        {'hookKey': 'adif', 'exportType': 'adif'},
      ]);
      final args = host.calls.map((call) => call['args'] as Map).toList();
      expect(args.map((a) => a['exportType']), ['potaActivation-adif', 'potaActivation-adif', 'adif']);
      expect(args.map((a) => a['exportKey']), ['pota-adif:US-1234', 'pota-adif:US-5678', 'adif']);
    });

    // Most exports exist to be uploaded — a park's log to POTA's servers, a
    // Cabrillo to a sponsor — and none of those want the operator's notes
    // about who they met. The whole-log backup is the exception.
    test('private data is withheld by default and released by the setting', () async {
      final host = _CapturingHost();
      final service = ExportService(extensions: _ExtensionsWithHost(host), qsos: QsosRepository(db), settings: settings);

      await service.generateExports(operation, [
        {'hookKey': 'pota', 'exportType': 'potaActivation-adif', 'exportKey': 'pota-adif:US-1234'},
      ]);
      expect((host.calls.single['args'] as Map)['includePrivateData'], isFalse);

      host.calls.clear();
      await settings.setIncludePrivateData(true);
      await service.generateExports(operation, [
        {'hookKey': 'pota', 'exportType': 'potaActivation-adif', 'exportKey': 'pota-adif:US-1234'},
      ]);
      expect((host.calls.single['args'] as Map)['includePrivateData'], isTrue);
    });

    test('an export declaring alwaysIncludePrivateData ignores the setting', () async {
      final host = _CapturingHost();
      final service = ExportService(extensions: _ExtensionsWithHost(host), qsos: QsosRepository(db), settings: settings);

      // The setting is off — the full-log backup still gets everything.
      expect(settings.includePrivateData, isFalse);
      await service.generateExports(operation, [
        {'hookKey': 'adif', 'exportType': 'adif', 'alwaysIncludePrivateData': true},
      ]);
      expect((host.calls.single['args'] as Map)['includePrivateData'], isTrue);
    });

    // The panel lists a name and then writes the file — those have to be the
    // same string. They can diverge because `generateExport` is handed only
    // the QSOs the option's refType covers, so a hook recomputing the name
    // dates it from a different first QSO than the listing did.
    test('the name the panel offered wins over the one the hook returns', () async {
      final qsos = QsosRepository(db);
      final service = ExportService(extensions: _ExtensionsWithHost(_CapturingHost()), qsos: qsos, settings: settings);

      final files = await service.generateExports(operation, [
        {'hookKey': 'cqww', 'exportType': 'cabrillo', 'filename': '2026-07-15 N0CALL for CQ-WW-CW.log'},
      ]);

      // _CapturingHost answers '<key>.txt' for everything.
      expect(files.single['filename'], '2026-07-15 N0CALL for CQ-WW-CW.log');
    });

    test('a hook that offers no name still gets the one it generates', () async {
      final qsos = QsosRepository(db);
      final service = ExportService(extensions: _ExtensionsWithHost(_CapturingHost()), qsos: qsos, settings: settings);

      final files = await service.generateExports(operation, [
        {'hookKey': 'cqww', 'exportType': 'cabrillo'},
      ]);

      expect(files.single['filename'], 'cqww.txt');
    });
  });

  group('an export only claims the segments its activity ran in', () {
    // The bug this closes: a contest export took `args.qsos` — the whole
    // operation — so a contest that started or ended at a break put contacts
    // made when it wasn't running into its Cabrillo. That is a false claim in a
    // file the operator submits, and it is the same mistake the SCORER made
    // before §5.1.3 gated it (fixed in M6; exports were left behind).
    late _CapturingHost host;
    late ExportService sliced;
    late Operation segmentedOp;

    /// A contest for the first half, a park for the second.
    setUp(() async {
      final operations = OperationsRepository(db);
      final qsos = QsosRepository(db);
      host = _CapturingHost();
      sliced = ExportService(extensions: _ExtensionsWithHost(host), qsos: qsos, settings: settings);

      final created = await operations.create(stationCall: 'N0CALL');
      await operations.saveData(
        Operation(
          uuid: created.uuid,
          data: {
            ...created.data,
            'refs': [
              {'type': 'cqww', 'mode': 'CW'},
            ],
          },
        ),
      );

      final start = DateTime.utc(2026, 7, 15, 12).millisecondsSinceEpoch;
      await qsos.add(created.uuid, {
        'their': {'call': 'IN1CONTEST'},
        'band': '20m',
        'mode': 'CW',
        'startAtMillis': start,
      });
      // The contest ends here: from now on the operation is a park activation.
      await qsos.addEvent(
        created.uuid,
        kind: 'break',
        atMillis: start + 1000,
        operation: {
          'refs': [
            {'type': 'pota', 'ref': 'US-0001'},
          ],
        },
      );
      await qsos.add(created.uuid, {
        'their': {'call': 'AFTERWARDS'},
        'band': '20m',
        'mode': 'CW',
        'startAtMillis': start + 2000,
      });

      segmentedOp = (await operations.get(created.uuid))!;
    });

    List<String> callsSentTo(int callIndex) => [
      for (final qso in ((host.calls[callIndex]['args'] as Map)['qsos'] as List)) ((qso as Map)['their'] as Map)['call'] as String,
    ];

    test('prepared template counts match generation scope for each activity', () async {
      final extension = _RegisteredCountExtensions(host);
      final service = ExportService(extensions: extension, qsos: QsosRepository(db), settings: settings);
      final options = await service.getExportOptions(segmentedOp);
      expect(options.map((option) => option['qsoCount']), [1, 2]);
      await service.generateExports(segmentedOp, options);
      for (var index = 0; index < options.length; index++) {
        final generatedQsos = (host.calls[index]['args'] as Map)['qsos'] as List;
        expect(options[index]['qsoCount'], generatedQsos.length);
      }
    });

    // A hook is handed ONE operation for the whole file, so the base
    // operation's state, county and location are what it reads — and a rover
    // who moved at a break made half the log somewhere else. The segment's
    // answer reaches a hook the only way it can: on the contact.
    test('a segment stamps its own location onto the contacts it covers', () async {
      final operations = OperationsRepository(db);
      final qsos = QsosRepository(db);
      final created = await operations.create(stationCall: 'N0CALL');
      await operations.saveData(Operation(uuid: created.uuid, data: {...created.data, 'state': 'CA', 'county': 'Marin', 'grid': 'CM87ss'}));

      final start = DateTime.utc(2026, 7, 15, 12).millisecondsSinceEpoch;
      await qsos.add(created.uuid, {
        'their': {'call': 'BEFORE'},
        'startAtMillis': start,
      });
      await qsos.addEvent(created.uuid, kind: 'break', atMillis: start + 1000, operation: {'state': 'NV', 'county': 'Washoe', 'grid': 'DM09'});
      await qsos.add(created.uuid, {
        'their': {'call': 'AFTER'},
        'startAtMillis': start + 2000,
      });

      await sliced.generateExports((await operations.get(created.uuid))!, [
        {'hookKey': 'adif', 'exportType': 'adif'},
      ]);

      final sent = ((host.calls.last['args'] as Map)['qsos'] as List).cast<Map>().where((qso) => qso['their'] != null).toList();
      Map ourOf(String call) => sent.firstWhere((qso) => (qso['their'] as Map)['call'] == call)['our'] as Map;

      expect(ourOf('BEFORE')['state'], 'CA');
      expect(ourOf('BEFORE')['county'], 'Marin');
      expect(ourOf('BEFORE')['grid'], 'CM87ss');
      expect(ourOf('AFTER')['state'], 'NV', reason: 'the base operation still says CA');
      expect(ourOf('AFTER')['county'], 'Washoe');
      expect(ourOf('AFTER')['grid'], 'DM09');

      // And the segments themselves travel (`ExportRequest.segments`), the
      // same wire shape the scoring pass sends: what a contest keeps on a REF
      // — a QSO party's county — is not in `our`, so a hook can only read it
      // per contact from the resolved timeline.
      final segments = ((host.calls.last['args'] as Map)['segments'] as List).cast<Map>();
      expect(segments.map((s) => (s['operation'] as Map)['county']), ['Marin', 'Washoe']);
      expect(segments.last['fromMillis'], start + 1000);
    });

    test('an unsegmented log sends no segments', () async {
      // The harness treats a single segment as no timeline, so a one-entry
      // list would be pure payload on every ordinary export.
      final operations = OperationsRepository(db);
      final qsos = QsosRepository(db);
      final created = await operations.create(stationCall: 'N0CALL');
      await qsos.add(created.uuid, {
        'their': {'call': 'ONLY'},
      });

      await sliced.generateExports((await operations.get(created.uuid))!, [
        {'hookKey': 'adif', 'exportType': 'adif'},
      ]);
      expect((host.calls.last['args'] as Map).containsKey('segments'), isFalse);
    });

    test("the log's events travel beside its contacts, and the operation its span", () async {
      // Among `qsos`, every hook that counts or files contacts would take a
      // break for one; left out, the full ADIF loses the log's timeline. The
      // span is two row columns, not `data`, and the templates' start and end
      // values render empty without them.
      final operations = OperationsRepository(db);
      final qsos = QsosRepository(db);
      final created = await operations.create(stationCall: 'N0CALL');
      final start = DateTime.utc(2026, 7, 15, 12).millisecondsSinceEpoch;
      await qsos.add(created.uuid, {
        'their': {'call': 'FIRST'},
        'startAtMillis': start,
      });
      await qsos.addEvent(created.uuid, kind: 'break', atMillis: start + 1000, operation: {'grid': 'DM09'});
      await qsos.add(created.uuid, {
        'their': {'call': 'LAST'},
        'startAtMillis': start + 2000,
      });

      await sliced.generateExports((await operations.get(created.uuid))!, [
        {'hookKey': 'adif', 'exportType': 'adif'},
      ]);

      final args = host.calls.last['args'] as Map;
      expect((args['qsos'] as List).map((qso) => ((qso as Map)['their'] as Map?)?['call']), ['FIRST', 'LAST']);
      expect((args['events'] as List).single, containsPair('event', containsPair('event', 'break')));
      expect((args['operation'] as Map)['startAtMillisMin'], start);
      expect((args['operation'] as Map)['startAtMillisMax'], start + 2000);
    });

    // The segment is the default for a stretch; a contact that recorded where
    // it was actually made from outranks it, or a rover logging each contact's
    // own grid would have them all replaced by the stretch's.
    test('a contact that carries its own location keeps it', () async {
      final operations = OperationsRepository(db);
      final qsos = QsosRepository(db);
      final created = await operations.create(stationCall: 'N0CALL');
      await operations.saveData(Operation(uuid: created.uuid, data: {...created.data, 'state': 'CA'}));

      final start = DateTime.utc(2026, 7, 15, 12).millisecondsSinceEpoch;
      await qsos.addEvent(created.uuid, kind: 'break', atMillis: start, operation: {'state': 'NV', 'grid': 'DM09'});
      await qsos.add(created.uuid, {
        'their': {'call': 'ROVING'},
        'our': {'grid': 'DM09ab', 'lat': 39.5, 'lon': -119.8},
        'startAtMillis': start + 1000,
      });

      await sliced.generateExports((await operations.get(created.uuid))!, [
        {'hookKey': 'adif', 'exportType': 'adif'},
      ]);

      final our = ((host.calls.last['args'] as Map)['qsos'] as List).cast<Map>().firstWhere((qso) => qso['their'] != null)['our'] as Map;
      expect(our['grid'], 'DM09ab');
      expect(our['lat'], 39.5);
      // The segment's grid must not arrive beside the contact's own coordinate.
      expect(our['state'], 'NV', reason: 'state is independent of the grid/coordinate group');
    });

    test('a refType-scoped export gets only its own segments', () async {
      await sliced.generateExports(segmentedOp, [
        {'hookKey': 'cqww', 'exportType': 'cabrillo', 'refType': 'cqww'},
      ]);

      expect(callsSentTo(0), ['IN1CONTEST'], reason: 'the contest ended at the break, so the later QSO is not its to claim');

      // And it is handed the option's OWN type's refs, deduped — not every ref
      // every segment carried. Without the narrowing this reads ['cqww', 'pota'],
      // and `adifFields` would stamp the park onto the contest's own records.
      final given = ((host.calls.single['args'] as Map)['operation'] as Map)['refs'] as List;
      expect([for (final ref in given) (ref as Map)['type']], ['cqww']);
    });

    test("a slice's span is its own contacts', not the operation's", () async {
      // The templates' op.startDate…op.endTime read it: a contest file dated to
      // the end of the park activation after it states a span it does not hold.
      await sliced.generateExports(segmentedOp, [
        {'hookKey': 'cqww', 'exportType': 'cabrillo', 'refType': 'cqww'},
      ]);

      final operation = (host.calls.single['args'] as Map)['operation'] as Map;
      expect(operation['startAtMillisMin'], segmentedOp.startAtMillisMin);
      expect(operation['startAtMillisMax'], segmentedOp.startAtMillisMin, reason: 'the contest ended at the break');
    });

    test("an activity's file gets the events of its own stretches, and the full log all of them", () async {
      // The break opens the park: in the contest's Cabrillo it would describe
      // a stretch the file leaves out.
      await sliced.generateExports(segmentedOp, [
        {'hookKey': 'cqww', 'exportType': 'cabrillo', 'refType': 'cqww'},
        {'hookKey': 'adif', 'exportType': 'adif'},
      ]);

      final byHook = {for (final call in host.calls) call['key']: call['args'] as Map};
      expect(byHook['cqww']!.containsKey('events'), isFalse);
      expect((byHook['adif']!['events'] as List).single, containsPair('event', containsPair('event', 'break')));
    });

    test('an export with no refType still gets the whole log', () async {
      // The full ADIF covers the operation, not one activity within it.
      await sliced.generateExports(segmentedOp, [
        {'hookKey': 'adif', 'exportType': 'adif'},
      ]);

      expect(callsSentTo(0), ['IN1CONTEST', 'AFTERWARDS']);
    });

    test('a refType the operation never carried is not silently emptied', () async {
      // Nothing offers this today, but writing an empty file over a hook's own
      // judgement is a worse failure than exporting too much.
      await sliced.generateExports(segmentedOp, [
        {'hookKey': 'sota', 'exportType': 'sota', 'refType': 'sota'},
      ]);

      expect(callsSentTo(0), ['IN1CONTEST', 'AFTERWARDS']);
    });

    test('a ref carried only by a segment is still offered its export', () async {
      // A contest that ENDED at a break: the operation has moved on, but the
      // segments still carry the contest ref and half the log is contest QSOs.
      // Every contest's suggestExportOptions gates on the operation's own refs,
      // so asking with the base alone offers no Cabrillo at all — the same
      // base-only asymmetry ScoringService fixed for scorers, which means such
      // an operation is SCORED as a contest it cannot be exported as.
      final operations = OperationsRepository(db);
      final repo = QsosRepository(db);
      final created = await operations.create(stationCall: 'N0CALL');
      final start = DateTime.utc(2026, 7, 15, 12).millisecondsSinceEpoch;

      // The contest lives only in the start event; the operation itself is a park.
      await operations.saveData(
        Operation(
          uuid: created.uuid,
          data: {
            ...created.data,
            'refs': [
              {'type': 'pota', 'ref': 'US-0001'},
            ],
          },
        ),
      );
      await repo.addEvent(
        created.uuid,
        kind: 'start',
        atMillis: start - 1000,
        operation: {
          'refs': [
            {'type': 'cqww', 'mode': 'CW'},
          ],
        },
      );
      await repo.add(created.uuid, {
        'their': {'call': 'IN1CONTEST'},
        'band': '20m',
        'mode': 'CW',
        'startAtMillis': start,
      });

      final extensions = _ExtensionsWithHost(_CapturingHost());
      final service = ExportService(extensions: extensions, qsos: repo, settings: settings);
      await service.getExportOptions((await operations.get(created.uuid))!);

      // The hook is asked about every ref ANY segment carries, so the contest
      // gets its chance to offer a Cabrillo.
      final asked = (extensions.optionRequests.single['operation'] as Map)['refs'] as List;
      expect([for (final ref in asked) (ref as Map)['type']], containsAll(<String>['pota', 'cqww']));

      // ...and it must still SEE that ref when it writes the file. Both halves
      // of one contract, and they were asymmetric: the options call patched the
      // refs and the generate call didn't, so an extension gating its writer on
      // its own ref — every shipped contest does — produced an empty file with
      // an empty filename for a log it had just offered to export. Since
      // `activityExportHook` THROWS when it can't find the reference its
      // exportKey names, the same gap turns POTA's per-park ADIF into an
      // outright failure rather than a quiet one.
      await service.generateExports((await operations.get(created.uuid))!, [
        {'hookKey': 'cqww', 'exportType': 'cabrillo', 'refType': 'cqww'},
      ]);
      final given = ((extensions.host as _CapturingHost).calls.single['args'] as Map)['operation'] as Map;
      expect([for (final ref in (given['refs'] as List)) (ref as Map)['type']], containsAll(<String>['pota', 'cqww']));
    });

    test('an export that names no refType keeps the operation’s own refs', () async {
      // The other half of the same rule, and the one that bites an operator who
      // never enters a contest: the plain ADIF covers the whole operation, so it
      // must NOT be handed refs from segments the base operation has moved on
      // from. `adifFields` reads them, so a park activated after a break would
      // otherwise be stamped onto every QSO made before it — including this log's
      // first contact, made when the operation was a contest and no park at all.
      await sliced.generateExports(segmentedOp, [
        {'hookKey': 'adif', 'exportType': 'adif'},
      ]);

      final given = (host.calls.single['args'] as Map)['operation'] as Map;
      expect(
        [for (final ref in (given['refs'] as List)) (ref as Map)['type']],
        ['cqww'],
        reason: 'the base operation carried only the contest; the park is a segment override',
      );
    });

    test('a slice that comes out empty falls back rather than writing an empty file', () async {
      // Reachable today: the Activities view writes `operation.refs` with no
      // segment bookkeeping, so turning an activity ON for a polo-synced log
      // leaves every segment override omitting it. The ref is present, so the
      // refs.isEmpty bail-out doesn't fire, and the slice is empty — an
      // operator would get a Cabrillo with no QSOs in it and no reason why.
      final operations = OperationsRepository(db);
      final repo = QsosRepository(db);
      final created = await operations.create(stationCall: 'N0CALL');
      final start = DateTime.utc(2026, 7, 15, 12).millisecondsSinceEpoch;

      await operations.saveData(
        Operation(
          uuid: created.uuid,
          data: {
            ...created.data,
            'refs': [
              {'type': 'cqww', 'mode': 'CW'},
            ],
          },
        ),
      );
      // Every QSO lives after an override that does NOT carry cqww.
      await repo.addEvent(
        created.uuid,
        kind: 'start',
        atMillis: start - 1000,
        operation: {
          'refs': [
            {'type': 'pota', 'ref': 'US-0001'},
          ],
        },
      );
      await repo.add(created.uuid, {
        'their': {'call': 'ONLYQSO'},
        'band': '20m',
        'mode': 'CW',
        'startAtMillis': start,
      });

      final capturing = _CapturingHost();
      final service = ExportService(extensions: _ExtensionsWithHost(capturing), qsos: repo, settings: settings);
      await service.generateExports((await operations.get(created.uuid))!, [
        {'hookKey': 'cqww', 'exportType': 'cabrillo', 'refType': 'cqww'},
      ]);

      final sent = ((capturing.calls.single['args'] as Map)['qsos'] as List);
      expect(sent, hasLength(1), reason: 'an empty submission is the worse failure of the two');
    });

    test('an UNSEGMENTED operation is untouched, which is the common case', () async {
      final operations = OperationsRepository(db);
      final qsos = QsosRepository(db);
      final plain = await operations.create(stationCall: 'N0CALL');
      await operations.saveData(
        Operation(
          uuid: plain.uuid,
          data: {
            ...plain.data,
            'refs': [
              {'type': 'cqww', 'mode': 'CW'},
            ],
          },
        ),
      );
      for (final call in ['ONE', 'TWO']) {
        await qsos.add(plain.uuid, {
          'their': {'call': call},
          'band': '20m',
          'mode': 'CW',
          'startAtMillis': DateTime.utc(2026, 7, 15, 12).millisecondsSinceEpoch,
        });
      }

      await sliced.generateExports((await operations.get(plain.uuid))!, [
        {'hookKey': 'cqww', 'exportType': 'cabrillo', 'refType': 'cqww'},
      ]);

      expect(callsSentTo(0), ['ONE', 'TWO'], reason: 'one segment carries everything');
    });
  });

  // The payload every coarse hook reads an operation through. The operator is
  // RESOLVED into it, because at a position it lives in that position's own
  // slot and nothing in Dart reads it back out — the readers are on the far
  // side of the extension bridge, so a Dart-only search comes up clean while
  // REG1TEST's RCall and ADIF's OPERATORS quietly name the wrong operator.
  group('the operator reaches an export hook', () {
    Map<String, dynamic> operationIn(Map<String, dynamic> payload) => (payload['operation'] as Map).cast<String, dynamic>();

    test("the seat's operator is what an export sees, not the operation's", () {
      final payload = qsonPayloadFor(
        operation: Operation(
          uuid: 'u',
          data: {'stationCall': 'K2SUL', 'operatorCall': 'KI2D', 'operator2': 'W2ABC'},
          localData: const {'multiIdentifier': '2'},
        ),
        qsos: const [],
      );
      // Both names, because the contest writers are split across them:
      // REG1TEST/EDI reads the first, the ADIF OPERATORS header the second.
      expect(operationIn(payload)['operatorCall'], 'W2ABC');
      expect((operationIn(payload)['local'] as Map)['operatorCall'], 'W2ABC');
    });

    test('an operation with no position names its own operator', () {
      final payload = qsonPayloadFor(
        operation: Operation(uuid: 'u', data: {'stationCall': 'K2SUL', 'operatorCall': 'KI2D'}),
        qsos: const [],
      );
      expect(operationIn(payload)['operatorCall'], 'KI2D');
      expect((operationIn(payload)['local'] as Map)['operatorCall'], 'KI2D');
    });

    test('an operation from before the operator was synced still names it', () {
      final payload = qsonPayloadFor(
        operation: Operation(uuid: 'u', data: {'stationCall': 'K2SUL'}, localData: const {'operatorCall': 'W2ABC'}),
        qsos: const [],
      );
      expect(operationIn(payload)['operatorCall'], 'W2ABC');
    });

    // localData also holds the scoring cache and the title fragments, which
    // have no business crossing the extension bridge on every export.
    test('the rest of the device-local blob stays behind', () {
      final payload = qsonPayloadFor(
        operation: Operation(
          uuid: 'u',
          data: {'stationCall': 'K2SUL'},
          localData: const {
            'operatorCall': 'W2ABC',
            'scoring': {'huge': 'blob'},
          },
        ),
        qsos: const [],
      );
      expect((operationIn(payload)['local'] as Map).keys, ['operatorCall']);
    });
  });

  group('stashing', () {
    final now = DateTime.utc(2026, 9, 30, 18).millisecondsSinceEpoch;
    const withEmail = {'uuid': 'a', 'email': 'n0call@example.com'};
    const paid = {
      'id': 42,
      'status': 'active',
      'ends_at': null,
      'plan': {'stash_retention_in_days': 30},
    };
    const free = {
      'current_account': withEmail,
      'subscription': {
        'id': null,
        'plan': {'slug': 'default'},
      },
    };
    Map<String, dynamic> stash(String status, Duration age, {String? groupTitle, String filename = 'a.adi'}) => {
      'status': status,
      'filename': filename,
      'group_title': ?groupTitle,
      'created_at': DateTime.fromMillisecondsSinceEpoch(now, isUtc: true).subtract(age).toIso8601String(),
    };

    // A paid account keeps every stash for its retention window, so nothing
    // it sends replaces anything — a question there is noise.
    test('a paid account is never asked', () {
      final preflight = stashPreflightFrom(
        accountData: {'current_account': withEmail, 'subscription': paid},
        stashFiles: {
          'stash_files': [stash('uploaded', const Duration(minutes: 5))],
        },
        nowMillis: now,
      );
      expect(preflight, (needsEmail: false, freeAccount: false, replaces: null));
    });

    // The server keeps only the latest stash unless the subscription is LIVE
    // and its plan retains stashes at all (api-lofi `visible_stash_files`). A
    // lapsed subscription keeps its id on the account, so an id alone would
    // skip the question for exactly the account whose stash is replaced.
    test('a subscription the server does not count as paid is asked like a free one', () {
      final expired = DateTime.fromMillisecondsSinceEpoch(now, isUtc: true).subtract(const Duration(days: 1)).toIso8601String();
      for (final subscription in [
        {...paid, 'status': 'lapsed'},
        {...paid, 'status': 'cancelled'},
        {...paid, 'ends_at': expired},
        {
          ...paid,
          'plan': {'stash_retention_in_days': 0},
        },
      ]) {
        final preflight = stashPreflightFrom(
          accountData: {'current_account': withEmail, 'subscription': subscription},
          stashFiles: {
            'stash_files': [stash('uploaded', const Duration(minutes: 5), groupTitle: 'N0CALL Field Day')],
          },
          nowMillis: now,
        );
        expect(preflight, (needsEmail: false, freeAccount: true, replaces: 'N0CALL Field Day'), reason: '$subscription');
      }
    });

    test('an unverified purchase, a future end and a plan naming no retention all count as paid', () {
      final later = DateTime.fromMillisecondsSinceEpoch(now, isUtc: true).add(const Duration(days: 30)).toIso8601String();
      for (final subscription in [
        {...paid, 'status': 'unverified'},
        {...paid, 'ends_at': later},
        {
          ...paid,
          'plan': {'stash_retention_in_days': null},
        },
      ]) {
        final preflight = stashPreflightFrom(accountData: {'current_account': withEmail, 'subscription': subscription}, stashFiles: null, nowMillis: now);
        expect(preflight.freeAccount, isFalse, reason: '$subscription');
      }
    });

    test('a free account is asked about an unfetched stash from the last hours, by its title', () {
      final preflight = stashPreflightFrom(
        accountData: free,
        stashFiles: {
          'stash_files': [stash('seen', const Duration(hours: 5), groupTitle: 'N0CALL Field Day')],
        },
        nowMillis: now,
      );
      expect(preflight, (needsEmail: false, freeAccount: true, replaces: 'N0CALL Field Day'));
    });

    test('a stash with no group title is named by its file', () {
      final preflight = stashPreflightFrom(
        accountData: free,
        stashFiles: {
          'stash_files': [stash('uploaded', Duration.zero)],
        },
        nowMillis: now,
      );
      expect(preflight.replaces, 'a.adi');
    });

    // Fetched means safe, and a stash left for longer than the window is one
    // the operator has moved on from — asking every time would teach them to
    // tap through the question that matters.
    test('a fetched or an old stash is replaced without asking', () {
      final preflight = stashPreflightFrom(
        accountData: free,
        stashFiles: {
          'stash_files': [stash('downloaded', const Duration(minutes: 1)), stash('uploaded', const Duration(hours: 7))],
        },
        nowMillis: now,
      );
      expect(preflight, (needsEmail: false, freeAccount: true, replaces: null));
    });

    // Unknown is not free: a tier note or a warning on a guess would tell a
    // subscriber they're on the free plan.
    test('an account that could not be read claims nothing', () {
      expect(stashPreflightFrom(accountData: null, stashFiles: null, nowMillis: now), (needsEmail: false, freeAccount: null, replaces: null));
    });

    // The listing alone shows there is something to lose; a failed account
    // read is no reason to replace it without asking.
    test('an unread account is still asked when the listing shows an unfetched stash', () {
      final preflight = stashPreflightFrom(
        accountData: null,
        stashFiles: {
          'stash_files': [stash('uploaded', const Duration(minutes: 20), groupTitle: 'N0CALL Field Day')],
        },
        nowMillis: now,
      );
      expect(preflight, (needsEmail: false, freeAccount: null, replaces: 'N0CALL Field Day'));
    });

    // stash.ham2k.net signs in by email and the link goes to the confirmed
    // address; a pending one reaches nobody until it's confirmed. Paid or
    // free makes no difference — a stash nobody can fetch is no use to either.
    test('an account with no confirmed email needs one before it can stash', () {
      for (final account in [
        {'uuid': 'a'},
        {'uuid': 'a', 'email': ''},
        {'uuid': 'a', 'email': null, 'pending_email': 'n0call@example.com'},
      ]) {
        for (final subscription in [
          {'id': null},
          {'id': 42},
        ]) {
          final preflight = stashPreflightFrom(accountData: {'current_account': account, 'subscription': subscription}, stashFiles: null, nowMillis: now);
          expect(preflight.needsEmail, isTrue, reason: '$account, $subscription');
        }
      }
    });

    // The stash page lists a group's files side by side; two named alike
    // are two the operator can't tell apart, and one group per press is
    // what a free account keeps.
    test('one press is one group, with the names a save would give', () async {
      final extensions = _StashRecordingExtensions();
      final service = ExportService(extensions: extensions, qsos: QsosRepository(db), settings: settings);
      final result = await service.stashFiles([
        {'filename': 'log.adi', 'content': 'a', 'mimeType': 'text/plain'},
        {'filename': 'log.adi', 'content': 'b', 'mimeType': 'text/plain'},
      ], groupTitle: 'N0CALL Test Op');

      expect(result.uploaded, 2);
      expect(result.errors, isEmpty);
      expect(extensions.calls.map((c) => c.file['filename']), ['log.adi', 'log-2.adi']);
      expect(extensions.calls.map((c) => c.file['content']), ['a', 'b']);
      expect(extensions.calls.map((c) => c.groupUuid).toSet(), hasLength(1), reason: 'one press, one group');
      expect(extensions.calls.first.groupUuid, matches(RegExp(r'^[0-9a-f-]{36}$')));
      expect(extensions.calls.map((c) => c.groupTitle).toSet(), {'N0CALL Test Op'});
    });

    // A file the server refuses costs that file alone; the rest of the
    // group still arrives.
    test('a refused file is named, and the rest are still sent', () async {
      final extensions = _StashRecordingExtensions()..answers = {'b.adi': (uploaded: false, error: 'is too large (max 5MB)', fatal: false)};
      final service = ExportService(extensions: extensions, qsos: QsosRepository(db), settings: settings);
      final result = await service.stashFiles([
        for (final name in ['a.adi', 'b.adi', 'c.adi']) {'filename': name, 'content': 'x'},
      ]);

      expect(extensions.calls, hasLength(3));
      expect(result.uploaded, 2);
      expect(result.errors, ['b.adi: is too large (max 5MB)']);
    });

    // After an account refusal or an unreachable stash, every further file
    // would fail the same way — each after waiting out its own timeout — so
    // the batch stops, and still accounts for every file that isn't there.
    test('a fatal failure stops the batch and names every file never tried', () async {
      final extensions = _StashRecordingExtensions()..answers = {'b.adi': (uploaded: false, error: 'unreachable', fatal: true)};
      final service = ExportService(extensions: extensions, qsos: QsosRepository(db), settings: settings);
      final result = await service.stashFiles([
        for (final name in ['a.adi', 'b.adi', 'c.adi', 'd.adi']) {'filename': name, 'content': 'x'},
      ]);

      expect(extensions.calls.map((c) => c.file['filename']), ['a.adi', 'b.adi']);
      expect(result.uploaded, 1);
      expect(result.errors, ['b.adi: unreachable', 'c.adi: not sent', 'd.adi: not sent']);
    });
  });

  group('stashing (real ham2k-lofi extension)', () {
    // Covers the seam the fakes cannot: that the three stash calls are
    // registered on the syncTransport hook and answer in the shapes the
    // Dart side reads. An unregistered method resolves null, which the
    // wrappers would report as the runtime being down — the refusal text is
    // what proves the hook actually ran.
    //
    // Offline BECAUSE of what it asserts: with no settings behind the service
    // `syncEnabled` reads false, so the hooks refuse before `request()`,
    // which would otherwise register this device against the live server.
    late ExtensionService extensions;

    setUpAll(() async {
      extensions = ExtensionService();
      await extensions.start();
    });

    test('every stash call refuses without sync, in its own words', () async {
      final upload = await extensions.uploadStashFile(file: {'filename': 'a.adi', 'content': 'x'}, groupUuid: 'u');
      expect(upload.uploaded, isFalse);
      expect(upload.error, contains('enable sync in Settings'));
      expect(upload.fatal, isTrue, reason: 'every other file would be refused the same way');
      expect((await extensions.listStashFiles())?['error'], contains('enable sync in Settings'));
      expect((await extensions.emailStashLink())?['error'], contains('enable sync in Settings'));
    });
  });

  group('saving on Android', () {
    // `file_selector_android` implements neither `getSaveLocation` nor a
    // writable directory picker, so anything reaching `file_selector` here is
    // an "Export failed: UnimplementedError: getSavePath() has not been
    // implemented." toast in the operator's face — which is exactly what
    // these assert never happens again.
    late _FakeAndroidFileSave saver;
    late ExportService service;

    setUp(() {
      // `flutter test` already reports itself as Android, so this override is
      // what makes the DESKTOP case below reachable — not this one.
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      saver = _FakeAndroidFileSave();
      service = ExportService(extensions: ExtensionService(), qsos: QsosRepository(db), settings: settings, androidFileSave: saver);
    });

    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('one file goes to the create-document dialog, not file_selector', () async {
      final saved = await service.saveToDisk([
        {'filename': 'N0CALL.adi', 'mimeType': 'text/plain', 'content': 'ADIF'},
      ]);

      expect(saver.asked, [
        {'filename': 'N0CALL.adi', 'content': 'ADIF'},
      ]);
      // The platform renames around a collision, so the name it reports back is
      // the one the panel has to show — not the one we asked for.
      expect(saved?.location, 'saved-N0CALL.adi');
      expect(saved?.count, 1);
      expect(saved?.namesFiles, isTrue, reason: 'the SAF never says WHERE, so this names the files themselves');
    });

    test('every OTHER platform still goes to file_selector', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      // No plugin is registered under `flutter test`, so file_selector throwing
      // is itself the proof the desktop branch was taken. Without this the
      // platform guard is untestable: widening it to every platform — which
      // hands every desktop operator a MissingPluginException where their save
      // dialog was — passes every other test in this group.
      await expectLater(
        service.saveToDisk([
          {'filename': 'N0CALL.adi', 'content': 'ADIF'},
        ]),
        throwsA(isA<MissingPluginException>()),
      );
      expect(saver.asked, isEmpty);
    });

    test('several files are offered one at a time, under distinct names', () async {
      await service.saveToDisk([
        {'filename': 'N0CALL.adi', 'content': 'one'},
        {'filename': 'N0CALL.adi', 'content': 'two'},
      ]);

      // Deduplicated before the dialogs, not after: two files offered under one
      // name walk the operator into overwriting the first export with the
      // second, having been told nothing.
      expect(saver.asked, [
        {'filename': 'N0CALL.adi', 'content': 'one'},
        {'filename': 'N0CALL-2.adi', 'content': 'two'},
      ]);
    });

    test('a cancelled dialog abandons the rest and reports what was saved', () async {
      // Three offered, the operator cancelled the third: the message names the
      // two that landed, and the third was never written. Reporting all three
      // would tell them a file exists that doesn't.
      saver.cancelAt = 2;

      final saved = await service.saveToDisk([
        {'filename': 'A.adi', 'content': 'a'},
        {'filename': 'B.adi', 'content': 'b'},
        {'filename': 'C.adi', 'content': 'c'},
      ]);

      expect(saved?.location, 'saved-A.adi, saved-B.adi');
      // TWO, not the three that were offered: the caller announces this
      // number, and "3 files saved" over two names sends the operator looking
      // for one that was never written.
      expect(saved?.count, 2);
      expect(saver.asked.map((f) => f['filename']), ['A.adi', 'B.adi'], reason: 'the abandoned file is not offered again after the cancel');
    });

    test('cancelling the first dialog is a null answer, not a failure', () async {
      saver.cancelAt = 0;
      expect(
        await service.saveToDisk([
          {'filename': 'N0CALL.adi', 'content': 'ADIF'},
        ]),
        isNull,
      );
    });

    test('a write that fails partway still names the files already on disk', () async {
      // The operator is left with A and B written and C not. An error that
      // mentions only C sends them looking for files they already have.
      saver.failAt = 2;

      await expectLater(
        service.saveToDisk([
          {'filename': 'A.adi', 'content': 'a'},
          {'filename': 'B.adi', 'content': 'b'},
          {'filename': 'C.adi', 'content': 'c'},
        ]),
        throwsA(isA<ExportException>().having((e) => e.toString(), 'message', allOf(contains('No space left'), contains('saved-A.adi, saved-B.adi')))),
      );
    });
  });
}

/// Captures what each `generateExport` call was handed, and answers with a
/// well-formed but empty result — the point is the ARGUMENTS, not the file.
class _CapturingHost implements ExtensionHost {
  final List<Map<String, dynamic>> calls = [];

  @override
  Future<dynamic> invokeHook(String category, {String? key, required String method, Object? args, Duration timeout = const Duration(seconds: 10)}) async {
    calls.add({'key': key, 'method': method, 'args': args});
    return {'filename': '$key.txt', 'mimeType': 'text/plain', 'content': ''};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ExtensionsWithHost extends ExtensionService {
  final ExtensionHost mock;
  _ExtensionsWithHost(this.mock);

  /// What `suggestExportOptions` was handed. Captured HERE rather than on the
  /// host because option collection goes through `invokeHookAll` on the private
  /// host field, which a mock can't reach — only generation uses the public
  /// getter below.
  final List<Map<String, dynamic>> optionRequests = [];

  @override
  Future<List<Map<String, dynamic>>> exportTypeSettings(Map<String, dynamic> global, Map<String, dynamic> Function(String) overrides) async => [];

  @override
  Future<List<Map<String, dynamic>>> getExportOptions(Map<String, dynamic> args) async {
    optionRequests.add(args);
    return const [];
  }

  @override
  ExtensionHost? get host => mock;

  @override
  Future<void> start() async {}
}

class _RegisteredCountExtensions extends _ExtensionsWithHost {
  _RegisteredCountExtensions(super.mock);

  @override
  Future<List<Map<String, dynamic>>> exportTypeSettings(Map<String, dynamic> global, Map<String, dynamic> Function(String) overrides) async => [
    {'exportType': 'potaActivation-adif', 'settings': <String, dynamic>{}},
    {'exportType': 'adif', 'settings': <String, dynamic>{}},
  ];

  @override
  Future<List<Map<String, dynamic>>> getExportOptions(Map<String, dynamic> args) async => [
    {'exportType': 'potaActivation-adif', 'hookKey': 'pota', 'refType': 'pota', 'format': 'adif'},
    {'exportType': 'adif', 'hookKey': 'adif', 'format': 'adif'},
  ];

  @override
  Future<List<Map<String, dynamic>>> prepareExports(Map<String, dynamic> args) async => (args['options'] as List).cast<Map<String, dynamic>>();
}

/// Stands in for the platform channel, recording what the Android save flow
/// was asked to write.
class _FakeAndroidFileSave extends AndroidFileSave {
  final List<Map<String, String>> asked = [];

  /// The index of the dialog the operator cancels, and the one whose write
  /// fails — the two ways a run ends short of every file.
  int? cancelAt;
  int? failAt;

  @override
  Future<String?> saveFile({required String filename, required String content}) async {
    if (asked.length == cancelAt) return null;
    if (asked.length == failAt) throw PlatformException(code: 'save_failed', message: 'No space left');
    asked.add({'filename': filename, 'content': content});
    // Deliberately NOT the name asked for: the platform renames around a
    // collision, which is the whole reason the channel reports a name back.
    return 'saved-$filename';
  }
}

/// Records what each stash upload was handed, without a runtime, answering
/// by filename from [answers] and succeeding otherwise.
class _StashRecordingExtensions extends ExtensionService {
  final List<({Map<String, dynamic> file, String groupUuid, String? groupTitle})> calls = [];
  Map<String, ({bool uploaded, String? error, bool fatal})> answers = {};

  @override
  Future<({bool uploaded, String? error, bool fatal})> uploadStashFile({
    required Map<String, dynamic> file,
    required String groupUuid,
    String? groupTitle,
  }) async {
    calls.add((file: file, groupUuid: groupUuid, groupTitle: groupTitle));
    return answers[file['filename']] ?? (uploaded: true, error: null, fatal: false);
  }
}
