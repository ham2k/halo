// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Gaining an extension for a reference nothing handled has to CLEAR that
// row, not merely answer for it under another name. A per-event QSO party
// publishes `nyqp` while the operation carries `{type: 'qp', ref: 'NY'}`, so
// the manifest's qualified claim (`ref:qp/ny`) is honoured by rewriting the
// reference as the extension comes on — the step without which the offer
// leaves the row exactly as red as it was.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  hooks: ['activity', 'ref:nyqp', 'ref:qp/ny'],
);

/// The control the party loads once it is on — for its OWN type, which is the
/// whole reason the legacy reference has to change.
const _nyqpControl = <String, dynamic>{
  'key': 'ham2k-new-york-qso-party/setup',
  'label': 'New York QSO Party',
  'input': {'kind': 'form', 'refType': 'nyqp'},
};

const _legacyRef = {'type': 'qp', 'ref': 'NY', 'name': 'New York QSO Party', 'exchange': '59 ONO'};

class _Extensions extends ExtensionServiceWithFakeHost {
  _Extensions() : super(FakeExtensionHost({}));

  List<Map<String, dynamic>> controls = const [];

  @override
  Future<ControlsResult> operationControls(
    Map<String, dynamic> operationData, {
    Map<String, dynamic>? qso,
  }) async =>
      (controls: controls, loadFailed: false);

  @override
  Future<void> setExtensionEnabled(String key, bool enabled) async {
    await settings!.setExtensionOverrides({...settings!.extensionOverrides, key: enabled});
    if (enabled) controls = const [_nyqpControl];
  }

  @override
  Future<ActivitySuggestionResult> suggestActivities(
    Map<String, dynamic> operationData, {
    String? searchTerm,
    GridLocation? fallbackLocation,
    List<String>? activityKeys,
    List<String>? preferredKeys,
    String? preferredSearchTerm,
  }) async =>
      (suggestions: const <Map<String, dynamic>>[], allSourcesFailed: false);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('enabling the extension that claims a legacy reference rewrites it into the type it publishes',
      (tester) async {
    SharedPreferences.setMockInitialValues(const {});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    final extensions = _Extensions()..settings = settings;
    extensions.debugSetAvailableExtensions(const [_nyqpInfo]);
    final services = HaLoServices(db, settings, extensions: extensions);

    var operation = Operation(uuid: 'op-1', data: const {
      'refs': [_legacyRef]
    });
    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        home: Scaffold(
          body: OperationSheet(
            services: services,
            operation: operation,
            onOperationChanged: (updated) => operation = updated,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Enable New York QSO Party').hitTestable());
    await tester.pumpAndSettle();

    expect(operation.refs, [
      // The code is gone because the type carries its meaning now, and the
      // exchange the operator typed is not the migration's to throw away.
      {'type': 'nyqp', 'name': 'New York QSO Party', 'exchange': '59 ONO'},
    ]);
    // The point of the rewrite: the row is no longer one nothing handles, so
    // the offer that fixed it is gone rather than standing beside a red row.
    expect(find.text('Enable New York QSO Party'), findsNothing);
  });
}
