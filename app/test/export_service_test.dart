// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Developer Mode QSON export: the raw QSON payload (operation + QSOs in one
// JSON file, same shape app-polo exports) must be offered only when developer
// mode is on, and must be generated core-side — no extension runtime needed —
// so it works even while the extension host is still booting.

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ham2k_logger/services/export_service.dart';
import 'package:ham2k_logger/services/extension_service.dart';
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

    final created = await operations.create(stationCall: 'N0CALL', title: 'Test Op');
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
    expect(files.single['filename'], '2026-07-15.N0CALL.${operation.uuid.split('-').first}.qson');

    final decoded = jsonDecode(files.single['content'] as String) as Map<String, dynamic>;
    final operationData = decoded['operation'] as Map<String, dynamic>;
    expect(operationData['uuid'], operation.uuid);
    expect(operationData['stationCall'], 'N0CALL');
    expect(operationData['title'], 'Test Op');
    final qsoList = decoded['qsos'] as List;
    expect(qsoList, hasLength(1));
    expect((qsoList.single as Map)['their'], {'call': 'W1AW'});
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
      await operations.saveData(Operation(uuid: created.uuid, data: {
        ...created.data,
        'refs': [
          {'type': 'cqww', 'mode': 'CW'},
        ],
      }));

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
          for (final qso in ((host.calls[callIndex]['args'] as Map)['qsos'] as List))
            ((qso as Map)['their'] as Map)['call'] as String,
        ];

    test('a refType-scoped export gets only its own segments', () async {
      await sliced.generateExports(segmentedOp, [
        {'hookKey': 'cqww', 'exportType': 'cabrillo', 'refType': 'cqww'},
      ]);

      expect(
        callsSentTo(0),
        ['IN1CONTEST'],
        reason: 'the contest ended at the break, so the later QSO is not its to claim',
      );
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
      await operations.saveData(Operation(uuid: created.uuid, data: {
        ...created.data,
        'refs': [
          {'type': 'pota', 'ref': 'US-0001'},
        ],
      }));
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
      expect(
        [for (final ref in asked) (ref as Map)['type']],
        containsAll(<String>['pota', 'cqww']),
      );

      // ...and it must still SEE that ref when it writes the file. Both halves
      // of one contract, and they were asymmetric: the options call patched the
      // refs and the generate call didn't, so an extension gating its writer on
      // its own ref — every shipped contest does — produced an empty file with
      // an empty filename for a log it had just offered to export. Since
      // `activityExportHook` THROWS when it can't find the reference its
      // exportType names, the same gap turns POTA's per-park ADIF into an
      // outright failure rather than a quiet one.
      await service.generateExports((await operations.get(created.uuid))!, [
        {'hookKey': 'cqww', 'exportType': 'cabrillo', 'refType': 'cqww'},
      ]);
      final given = ((extensions.host as _CapturingHost).calls.single['args'] as Map)['operation'] as Map;
      expect(
        [for (final ref in (given['refs'] as List)) (ref as Map)['type']],
        containsAll(<String>['pota', 'cqww']),
      );
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

      await operations.saveData(Operation(uuid: created.uuid, data: {
        ...created.data,
        'refs': [
          {'type': 'cqww', 'mode': 'CW'},
        ],
      }));
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
      final service = ExportService(
        extensions: _ExtensionsWithHost(capturing),
        qsos: repo,
        settings: settings,
      );
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
      await operations.saveData(Operation(uuid: plain.uuid, data: {
        ...plain.data,
        'refs': [
          {'type': 'cqww', 'mode': 'CW'},
        ],
      }));
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
}

/// Captures what each `generateExport` call was handed, and answers with a
/// well-formed but empty result — the point is the ARGUMENTS, not the file.
class _CapturingHost implements ExtensionHost {
  final List<Map<String, dynamic>> calls = [];

  @override
  Future<dynamic> invokeHook(
    String category, {
    String? key,
    required String method,
    Object? args,
    Duration timeout = const Duration(seconds: 10),
  }) async {
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
  Future<List<Map<String, dynamic>>> getExportOptions(Map<String, dynamic> args) async {
    optionRequests.add(args);
    return const [];
  }

  @override
  ExtensionHost? get host => mock;

  @override
  Future<void> start() async {}
}
