// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// An operation handed to an extension marks the refs a contest extension
// owns, however it is handed: in any hook's args, or read back with
// `getOperation` and `listOperations`. A ref's type alone (`cqww`, `potaActivation`) says nothing
// of what it is, so without the mark an extension offering what suits a
// contest only (Super Check Partial's suggestions) cannot tell a contest
// from a park.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart' show HaLoDatabase, OperationsRepository;
import 'package:ham2k_logger/services/extensions/extension_info.dart';

import '../support/halo_test_support.dart';

const _contest = ExtensionInfo(key: 'ham2k-cqww', file: 'cqww.js', core: false, name: 'CQ WW', category: 'contest', hooks: ['ref:cqww']);
const _activity = ExtensionInfo(key: 'ham2k-pota', file: 'pota.js', core: false, name: 'POTA', category: 'activity', hooks: ['ref:pota', 'ref:potaActivation']);
const _naqp = ExtensionInfo(key: 'ham2k-naqp', file: 'naqp.js', core: false, name: 'NAQP', category: 'contest', hooks: ['ref:naqp']);

class _Installed extends ExtensionServiceWithFakeHost {
  _Installed(super.host);

  @override
  List<ExtensionInfo> get availableExtensions => const [_contest, _activity, _naqp];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const operation = {
    'uuid': 'op-1',
    'refs': [
      {'type': 'cqww'},
      {'type': 'potaActivation', 'ref': 'US-0001'},
      {'type': 'naqp'},
    ],
  };

  Future<List<Object?>> handed(Future<void> Function(ExtensionServiceWithFakeHost extensions) call, String stub) async {
    Object? args;
    final extensions = _Installed(FakeExtensionHost({stub: (Object? a) => args = a}))
      // NAQP is installed but not running: its answers are nobody's.
      ..debugLoadedExtensionKeys = {'ham2k-cqww', 'ham2k-pota'};
    await call(extensions);
    return ((args as Map)['operation'] as Map)['refs'] as List;
  }

  test("an assistant sees a running contest's ref marked, and an activity's or a stopped extension's unmarked", () async {
    final refs = await handed(
      (extensions) => extensions.observe(hookKey: 'coach', assistantKey: 'scp', args: {'operation': operation}),
      'assistant:coach:observe',
    );
    expect(refs, [
      {'type': 'cqww', 'contest': true},
      {'type': 'potaActivation', 'ref': 'US-0001'},
      {'type': 'naqp'},
    ]);
  });

  test('a panel sees them marked too, rendering and answering an event', () async {
    final rendered = await handed((extensions) => extensions.renderPanel(hookKey: 'scp', panelKey: 'scp', args: {'operation': operation}), 'panel:scp:render');
    expect(rendered.first, {'type': 'cqww', 'contest': true});
    final evented = await handed((extensions) => extensions.panelEvent(hookKey: 'scp', panelKey: 'scp', args: {'operation': operation}), 'panel:scp:onEvent');
    expect(evented.first, {'type': 'cqww', 'contest': true});
  });

  test('a template rendering against the operation sees them marked', () async {
    final rendered = await handed((extensions) => extensions.renderTemplate('{{ op.refs }}', operation: operation), 'template:templates:render');
    expect(rendered.first, {'type': 'cqww', 'contest': true});
    final many = await handed((extensions) => extensions.renderTemplates(['{{ op.refs }}'], operation: operation), 'template:templates:renderMany');
    expect(many.first, {'type': 'cqww', 'contest': true});
  });

  // A hook that marks its own args, rather than going through the host's one
  // filter, hands every other hook the operation unmarked: a command, here.
  test('any hook handed the operation sees them marked, a command among them', () async {
    Object? args;
    final extensions = _Installed(
      FakeExtensionHost({
        'command:*:interpret': (Object? a) {
          args = a;
          return const <Map<String, dynamic>>[];
        },
      }),
    )..debugLoadedExtensionKeys = {'ham2k-cqww', 'ham2k-pota'};
    await extensions.interpretCommand('CQ', operation);
    expect((((args as Map)['operation'] as Map)['refs'] as List).first, {'type': 'cqww', 'contest': true});
  });

  // A scorer or an export of a segmented log reads each contact against its
  // own segment's operation, and a rove's later segment may be the contest.
  test("each segment's operation has them marked too", () async {
    final extensions = _Installed(FakeExtensionHost())..debugLoadedExtensionKeys = {'ham2k-cqww', 'ham2k-pota'};
    final args =
        extensions.markOperationArgs({
              'segments': [
                {
                  'fromMillis': 1,
                  'operation': {
                    'refs': [
                      {'type': 'potaActivation', 'ref': 'US-0001'},
                    ],
                  },
                },
                {'fromMillis': 2, 'operation': operation},
              ],
            })
            as Map;
    final segments = args['segments'] as List;
    expect(((segments[0] as Map)['operation'] as Map)['refs'], [
      {'type': 'potaActivation', 'ref': 'US-0001'},
    ]);
    expect((((segments[1] as Map)['operation'] as Map)['refs'] as List).first, {'type': 'cqww', 'contest': true});
  });

  // Every hook call passes through the filter, a batch of lookups hundreds of
  // times over: one marking nothing must hand the call its own args, not a copy.
  test('args with nothing to mark come back as themselves', () {
    final extensions = _Installed(FakeExtensionHost())..debugLoadedExtensionKeys = {'ham2k-pota'};
    final args = <String, dynamic>{
      'operation': operation,
      'segments': [
        {'fromMillis': 1, 'operation': operation},
      ],
    };
    expect(identical(extensions.markOperationArgs(args), args), isTrue);
  });

  // Which types are a contest's is remembered between calls; an extension
  // started since must not be answered from what was running before.
  test('a contest extension started since is marked from then on', () {
    final extensions = _Installed(FakeExtensionHost())..debugLoadedExtensionKeys = {'ham2k-cqww', 'ham2k-pota'};
    List<Object?> refs() => ((extensions.markOperationArgs({'operation': operation}) as Map)['operation'] as Map)['refs'] as List;
    expect(refs().last, {'type': 'naqp'});
    extensions.debugLoadedExtensionKeys = {'ham2k-cqww', 'ham2k-pota', 'ham2k-naqp'};
    expect(refs().last, {'type': 'naqp', 'contest': true});
  });

  // A record can keep a mark from before its contest extension stopped; read
  // as it stands, it would call a contest what nothing running says is one.
  test('a mark nothing running stands behind is taken away', () {
    final extensions = _Installed(FakeExtensionHost())..debugLoadedExtensionKeys = {'ham2k-pota'};
    final args =
        extensions.markOperationArgs({
              'operation': {
                'refs': [
                  {'type': 'naqp', 'contest': true},
                  {'type': 'potaActivation', 'ref': 'US-0001'},
                ],
              },
            })
            as Map;
    expect((args['operation'] as Map)['refs'], [
      {'type': 'naqp'},
      {'type': 'potaActivation', 'ref': 'US-0001'},
    ]);
  });

  // An untyped map is cast to be read, and the cast is a new object: handed
  // on, it would make every call with one a copy.
  test('an untyped operation with nothing to mark comes back as itself', () {
    final extensions = _Installed(FakeExtensionHost())..debugLoadedExtensionKeys = {'ham2k-pota'};
    final args = <String, dynamic>{'operation': Map<dynamic, dynamic>.of(operation)};
    expect(identical(extensions.markOperationArgs(args), args), isTrue);
  });

  // Every hook call passes through the filter: one that throws would cost
  // the call, a whole batch of them with it.
  test('an operation that cannot be marked is handed over as it was', () {
    final extensions = _Installed(FakeExtensionHost())..debugLoadedExtensionKeys = {'ham2k-cqww'};
    final args = <String, dynamic>{
      'operation': <dynamic, dynamic>{
        1: 'not a field name',
        'refs': [
          {'type': 'cqww'},
        ],
      },
    };
    expect(identical(extensions.markOperationArgs(args), args), isTrue);
  });

  // An extension reading the operation back must not find a park where it was
  // just handed a contest.
  test('an operation read back with getOperation has them marked too', () async {
    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final operations = OperationsRepository(db);
    final created = await operations.createFromData({'stationCall': 'N0DEV', 'refs': operation['refs']});
    final extensions = _Installed(FakeExtensionHost())
      ..debugLoadedExtensionKeys = {'ham2k-cqww', 'ham2k-pota'}
      ..operations = operations;
    final read = await extensions.debugHandleHostCall('getOperation', {'uuid': created.uuid}) as Map;
    expect(read['refs'], [
      {'type': 'cqww', 'contest': true},
      {'type': 'potaActivation', 'ref': 'US-0001'},
      {'type': 'naqp'},
    ]);
  });

  test('the operations listOperations answers have them marked too', () async {
    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final operations = OperationsRepository(db);
    await operations.createFromData({'stationCall': 'N0DEV', 'refs': operation['refs']});
    final extensions = _Installed(FakeExtensionHost())
      ..debugLoadedExtensionKeys = {'ham2k-cqww', 'ham2k-pota'}
      ..operations = operations;
    final listed = await extensions.debugHandleHostCall('listOperations', {}) as List;
    expect((listed.single as Map)['refs'], [
      {'type': 'cqww', 'contest': true},
      {'type': 'potaActivation', 'ref': 'US-0001'},
      {'type': 'naqp'},
    ]);
  });
}
