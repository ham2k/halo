// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Gaining an extension for a reference nothing handled has to CLEAR that
// row. A per-event QSO party publishes `ny-qso-party` while the operation
// carries `{type: 'qp', ref: 'NY'}`, and it reaches back for that pair rather
// than rewriting it: the operation is the one the operator logged, and a log
// that edits itself when an extension arrives is worse than a red row.
//
// So the claim has to be honoured on the MATCHING side, twice over — the
// manifest's `ref:qp/ny` decides who is offered, and the control's own
// `alsoHandles` decides who answers once they are on. This holds both, and
// holds the refs unchanged through it.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:halo_widgets/halo_widgets.dart' show refWithFormResult;

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/extension_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/operation/activities_view.dart';

import '../support/halo_test_support.dart';

const _nyqpInfo = ExtensionInfo(
  key: 'ham2k-new-york-qso-party',
  file: 'ham2k-new-york-qso-party.js',
  core: false,
  name: 'New York QSO Party',
  enabledByDefault: false,
  hooks: ['activity', 'ref:ny-qso-party', 'ref:qp/ny'],
);

/// The control the party loads once it is on: its own type, plus the legacy
/// family qualified by the code this party used to be filed under.
const _nyqpControl = <String, dynamic>{
  'key': 'ham2k-new-york-qso-party/setup',
  'label': 'New York QSO Party',
  'input': {
    'kind': 'form',
    'refType': 'ny-qso-party',
    'alsoHandles': ['qp/ny'],
  },
};

const _legacyRef = {'type': 'qp', 'ref': 'NY', 'name': 'New York QSO Party', 'exchange': '59 ONO'};

class _Extensions extends ExtensionServiceWithFakeHost {
  _Extensions() : super(FakeExtensionHost({}));

  List<Map<String, dynamic>> controls = const [];

  @override
  Future<ControlsResult> operationControls(Map<String, dynamic> operationData, {Map<String, dynamic>? qso}) async => (controls: controls, loadFailed: false);

  @override
  Future<void> setExtensionEnabled(String key, bool enabled) async {
    await settings!.setExtensionOverrides({...settings!.extensionOverrides, key: enabled});
    if (enabled) controls = const [_nyqpControl];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('enabling the extension that claims a legacy reference answers for it, and leaves it alone', (tester) async {
    SharedPreferences.setMockInitialValues(const {});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    final extensions = _Extensions()..settings = settings;
    extensions.debugSetAvailableExtensions(const [_nyqpInfo]);
    final services = HaLoServices(db, settings, extensions: extensions);

    var operation = Operation(
      uuid: 'op-1',
      data: const {
        'refs': [_legacyRef],
      },
    );
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: OperationSheet(services: services, operation: operation, onOperationChanged: (updated) => operation = updated),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Enable New York QSO Party').hitTestable());
    await tester.pumpAndSettle();

    // Byte for byte what the operator logged. Mutated to rewrite the ref, this
    // is where it shows — and an operation that edits itself is the failure
    // this whole approach exists to avoid.
    expect(operation.refs, [_legacyRef]);
    // And the row is answered all the same: the control claims `qp/ny`, so
    // nothing is unhandled and the offer that fixed it is gone rather than
    // standing beside a row that is still red.
    expect(find.text('Enable New York QSO Party'), findsNothing);
  });

  test('a setup form edit lands back on the reference it was opened from', () {
    // The rule that makes "we do not modify existing operations" hold past the
    // first edit. The control publishes `ny-qso-party` and answers for
    // `qp/ny`; taking the control's type here would retype the operation the
    // moment the operator opened its form to change their power class.
    expect(refWithFormResult(const {'type': 'qp', 'ref': 'NY', 'power': 'LOW'}, const {'power': 'HIGH'}, refType: 'ny-qso-party'), {
      'type': 'qp',
      'ref': 'NY',
      'power': 'HIGH',
    });
  });

  test('a reference being created takes the control\'s own type', () {
    expect(refWithFormResult(null, const {'power': 'LOW'}, refType: 'ny-qso-party'), {'power': 'LOW', 'type': 'ny-qso-party'});
  });
}
