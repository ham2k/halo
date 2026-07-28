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
      expect(((sent.single as Map)['our'] as Map)['call'], 'OTHERCALL',
          reason: 'the logged operator call is left alone, not rewritten');
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

    test('the hooks are asked once per call, each seeing only its own', () async {
      final extensions = _ExtensionsWithHost(_CapturingHost());
      final service = ExportService(extensions: extensions, qsos: qsos, settings: settings);

      await service.getExportOptions(await multiOp());

      expect(extensions.optionRequests, hasLength(2));
      expect(
        extensions.optionRequests.map((r) => (r['operation'] as Map)['stationCall']),
        ['N0CALL', 'W1AW'],
        reason: 'each hook call sees a single-station operation, so filenames and '
            'ADIF/Cabrillo callsign fields name the right one without the hooks knowing',
      );
    });

    test("every QSO is claimed by whichever call is exporting", () async {
      final extensions = _ExtensionsWithHost(_CapturingHost());
      final service = ExportService(extensions: extensions, qsos: qsos, settings: settings);

      await service.getExportOptions(await multiOp());

      List<String?> ourCalls(int index) => [
            for (final qso in extensions.optionRequests[index]['qsos'] as List)
              ((qso as Map)['our'] as Map)['call'] as String?,
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
      expect(
        (await exports.getExportOptions(operation)).single['filename'],
        '2026-07-15 N0CALL ${operation.uuid.split('-').first}.qson',
      );

      await settings.setUseCompactFileNames(true);
      expect(
        (await exports.getExportOptions(operation)).single['filename'],
        'N0CALL-20260715-${operation.uuid.split('-').first}.qson',
      );
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

    // Most exports exist to be uploaded — a park's log to POTA's servers, a
    // Cabrillo to a sponsor — and none of those want the operator's notes
    // about who they met. The whole-log backup is the exception.
    test('private data is withheld by default and released by the setting', () async {
      final host = _CapturingHost();
      final service = ExportService(extensions: _ExtensionsWithHost(host), qsos: QsosRepository(db), settings: settings);

      await service.generateExports(operation, [
        {'hookKey': 'pota', 'exportType': 'pota-adif:US-1234'},
      ]);
      expect((host.calls.single['args'] as Map)['includePrivateData'], isFalse);

      host.calls.clear();
      await settings.setIncludePrivateData(true);
      await service.generateExports(operation, [
        {'hookKey': 'pota', 'exportType': 'pota-adif:US-1234'},
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
      final service = ExportService(
        extensions: _ExtensionsWithHost(_CapturingHost()),
        qsos: qsos,
        settings: settings,
      );

      final files = await service.generateExports(operation, [
        {'hookKey': 'cqww', 'exportType': 'cabrillo', 'filename': '2026-07-15 N0CALL for CQ-WW-CW.log'},
      ]);

      // _CapturingHost answers '<key>.txt' for everything.
      expect(files.single['filename'], '2026-07-15 N0CALL for CQ-WW-CW.log');
    });

    test('a hook that offers no name still gets the one it generates', () async {
      final qsos = QsosRepository(db);
      final service = ExportService(
        extensions: _ExtensionsWithHost(_CapturingHost()),
        qsos: qsos,
        settings: settings,
      );

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

      // And it is handed the option's OWN type's refs, deduped — not every ref
      // every segment carried. Without the narrowing this reads ['cqww', 'pota'],
      // and `adifFields` would stamp the park onto the contest's own records.
      final given = ((host.calls.single['args'] as Map)['operation'] as Map)['refs'] as List;
      expect([for (final ref in given) (ref as Map)['type']], ['cqww']);
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
