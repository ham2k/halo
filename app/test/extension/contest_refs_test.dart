// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// An operation handed to an extension marks the refs a contest extension
// owns, however it is handed: an assistant's, a panel's, a template's, or
// read back with `getOperation`. A ref's type alone (`cqww`, `potaActivation`) says nothing
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
}
