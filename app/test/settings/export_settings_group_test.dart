// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ham2k_logger/config/experiments.dart';
import 'package:ham2k_logger/services/export_preferences.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/settings/export_settings_group.dart';

class _Extensions extends ExtensionService {
  bool fail = false;
  @override
  Future<List<Map<String, dynamic>>> exportTypeSettings(Map<String, dynamic> global, Map<String, dynamic> Function(String) overrides) async {
    if (fail) throw StateError('Template bridge unavailable');
    return [
      for (final type in ['default', 'potaActivation-adif', 'cqww-cabrillo'])
        {
          'exportType': type,
          'label': type == 'cqww-cabrillo' ? 'CQ WW' : 'POTA',
          'format': type == 'cqww-cabrillo' ? 'cabrillo' : 'adif',
          'settings': {
            'includePrivateData': false,
            'includeLookupData': true,
            'filenameTemplate': '{{ log.station }}',
            'customTemplates': false,
            ...global,
            ...overrides(type),
          },
          'defaults': const <String, dynamic>{},
          if (type == 'potaActivation-adif')
            'choices': [
              {
                'key': 'sigFields',
                'label': 'Park fields',
                'description': 'Which fields name the parks.',
                'default': 'potaRef',
                'options': [
                  {'value': 'potaRef', 'label': 'POTA_REF only'},
                  {'value': 'both', 'label': 'POTA_REF and SIG_INFO'},
                ],
              },
              {
                'key': 'hunterFields',
                'label': 'Hunter fields',
                'default': 'a',
                'options': [
                  {'value': 'a', 'label': 'A'},
                  {'value': 'b', 'label': 'B'},
                ],
              },
              // No options: nothing to pick, so no row.
              {'key': 'broken', 'label': 'Broken', 'default': 'x'},
              // A default no option names: the SDK sends no pick for it, so a
              // row here would be a setting that reaches no hook.
              {
                'key': 'strayDefault',
                'label': 'Stray default',
                'default': 'x',
                'options': [
                  {'value': 'a', 'label': 'A'},
                ],
              },
            ],
        },
    ];
  }
}

/// Two transfer services, each from its own extension, and a third
/// extension whose account serves no transfer at all. Wavelog's hook key is
/// not its extension's key, as a hook's need not be.
class _TransferExtensions extends ExtensionService {
  bool accountsUnavailable = false;
  bool storageUnavailable = false;
  final credentialReads = <String>[];
  Map<String, String> failed = {};

  @override
  Future<List<Map<String, dynamic>>> exportTypeSettings(Map<String, dynamic> global, Map<String, dynamic> Function(String) overrides) async => [];

  @override
  Future<TransferServices> transferServices() async => (
    byKey: <String, TransferServiceInfo>{
      'qrz': (hookKey: 'ham2k-qrz', extensionKey: 'ham2k-qrz', key: 'qrz', label: 'QRZ.com Logbook', description: null, pushes: true),
      'wavelog': (hookKey: 'wavelog-transfer', extensionKey: 'wavelog', key: 'wavelog', label: 'Wavelog', description: null, pushes: true),
    },
    failed: failed,
  );

  @override
  Future<List<Map<String, dynamic>>?> getAccounts() async => accountsUnavailable
      ? null
      : [
          {'extensionKey': 'ham2k-qrz', 'key': 'ham2k-qrz', 'kvKey': 'ham2k-qrz', 'label': 'QRZ.com'},
          {'extensionKey': 'wavelog', 'key': 'wavelog', 'kvKey': 'wavelog', 'label': 'Wavelog server'},
          {'extensionKey': 'hamqth', 'key': 'hamqth', 'kvKey': 'hamqth', 'label': 'HamQTH'},
        ];

  @override
  Future<Map<String, String>?> getAccountCredentials(String kvKey) async {
    credentialReads.add(kvKey);
    if (storageUnavailable) return null;
    return kvKey == 'ham2k-qrz' ? {'username': 'KI2D', 'password': 'x'} : {};
  }
}

void main() {
  group('transfer services', () {
    late SettingsService settings;
    late _TransferExtensions extensions;
    final opened = <String>[];
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      settings = SettingsService(await SharedPreferences.getInstance());
      extensions = _TransferExtensions();
      opened.clear();
    });

    ExportsSettingsGroup groupOf() => ExportsSettingsGroup(settings, extensions, (key) async => opened.add(key));
    List<Map<String, dynamic>> serviceRows(List<Map<String, dynamic>> elements) => [
      for (final el in elements)
        if ((el['key'] as String?)?.startsWith('transfer:') ?? false) el,
    ];

    test('are not listed while EXP PUSH is off, since no transfer hook is asked anything then', () async {
      final elements = await groupOf().buildElements();
      expect(serviceRows(elements), isEmpty);
      expect(elements.where((el) => el['key'] == 'transferServices'), isEmpty);
    });

    test("each lists the account of its own extension and who it signs in as, and no other extension's", () async {
      await settings.setExperimentEnabled(kPushExperiment, true);
      final rows = serviceRows(await groupOf().buildElements());
      expect(
        [for (final row in rows) (row['label'], row['description'])],
        [('QRZ.com Logbook', 'QRZ.com: KI2D'), ('Wavelog', 'Wavelog server: ${t.settings.accounts.notConfigured}')],
      );
    });

    test("a row opens its account's pane, and the category re-reads the account when it closes", () async {
      await settings.setExperimentEnabled(kPushExperiment, true);
      final group = groupOf();
      final row = serviceRows(await group.buildElements()).first;
      var rang = 0;
      void ring() => rang++;
      group.listenable.addListener(ring);
      await group.openAction(_FakeContext(), row['key'] as String);
      group.listenable.removeListener(ring);
      expect(opened, ['ham2k-qrz']);
      expect(rang, greaterThan(0));
    });

    test("are Settings' alone: an operation's Export Settings dialog, which keeps its target's rows, shows none", () async {
      await settings.setExperimentEnabled(kPushExperiment, true);
      final elements = await groupOf().buildElements();
      expect(serviceRows(elements), isNotEmpty);
      expect(serviceRows(elements).where((row) => row.containsKey('target')), isEmpty);
    });

    test('with no keychain, each account says its login is unavailable, and the keychain is asked once', () async {
      await settings.setExperimentEnabled(kPushExperiment, true);
      extensions.storageUnavailable = true;
      final rows = serviceRows(await groupOf().buildElements());
      expect(
        [for (final row in rows) row['description']],
        ['QRZ.com: ${t.formChrome.storageUnavailable}', 'Wavelog server: ${t.formChrome.storageUnavailable}'],
      );
      // Each failed read reports: one per row would report the same outage again and again.
      expect(extensions.credentialReads, hasLength(1));
    });

    test('when the accounts cannot be asked, each service still has its row, saying so, and a tap asks again', () async {
      await settings.setExperimentEnabled(kPushExperiment, true);
      extensions.accountsUnavailable = true;
      final group = groupOf();
      final rows = serviceRows(await group.buildElements());
      expect(
        [for (final row in rows) (row['label'], row['description'])],
        [('QRZ.com Logbook', t.settings.accounts.lookupFailed), ('Wavelog', t.settings.accounts.lookupFailed)],
      );
      var rang = 0;
      void ring() => rang++;
      group.listenable.addListener(ring);
      await group.openAction(_FakeContext(), rows.first['key'] as String);
      group.listenable.removeListener(ring);
      expect(opened, isEmpty, reason: 'there is no account to open');
      expect(rang, greaterThan(0));
    });

    test('file options sit under their own folded section, which ends where Services begins', () async {
      await settings.setExperimentEnabled(kPushExperiment, true);
      final elements = await groupOf().buildElements();
      expect(elements.first, containsPair('key', 'fileExportOptions'));
      expect(elements.first, containsPair('collapsed', true));
      // Top-level, not inside a disclosure: the gear dialog and SET/SHOW only see a group's own elements.
      expect(elements.where((el) => el['key'] == 'useCompactFileNames'), hasLength(1));
      final services = elements.indexWhere((el) => el['key'] == 'transferServices');
      expect(elements[services], containsPair('style', 'section'), reason: 'a band of its own, or the fold would hide the services too');
    });

    test('a hook that could not list its services keeps a row with its error, rather than reading as not installed', () async {
      await settings.setExperimentEnabled(kPushExperiment, true);
      extensions.failed = {'clublog': 'Server list unreadable'};
      final rows = serviceRows(await groupOf().buildElements());
      expect((rows.last['label'], rows.last['description']), ('clublog', 'Server list unreadable'));
    });
  });

  test("a type's own choices are pickers on its page, each pick saved beside the others", () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final extensions = _Extensions();
    final group = ExportsSettingsGroup(settings, extensions);
    Map<String, dynamic> row(List<Map<String, dynamic>> fields, String key) => fields.firstWhere((e) => e['key'] == 'potaActivation-adif::choices/$key');

    final fields = await group.typeElements('potaActivation-adif');
    final park = row(fields, 'sigFields');
    expect(park['fieldType'], 'select');
    expect(park['label'], 'Park fields');
    expect(park['description'], 'Which fields name the parks.');
    expect(park['value'], 'potaRef', reason: 'an untouched choice shows the default the file is written with');
    expect((park['options'] as List).map((o) => o['label']), ['POTA_REF only', 'POTA_REF and SIG_INFO']);
    expect(fields.any((e) => e['key'] == 'potaActivation-adif::choices/broken'), isFalse);
    expect(fields.any((e) => e['key'] == 'potaActivation-adif::choices/strayDefault'), isFalse);
    expect((await group.typeElements('cqww-cabrillo')).any((e) => e['key'].toString().contains('choices/')), isFalse);

    await group.commit('potaActivation-adif::choices/sigFields', 'both');
    await group.commit('potaActivation-adif::choices/hunterFields', 'b');
    // Saved as the one map `ExportSettings.choices` reads, the first pick kept.
    expect(settings.exportTypeOverrides('potaActivation-adif')['choices'], {'sigFields': 'both', 'hunterFields': 'b'});
    final updated = await group.typeElements('potaActivation-adif');
    expect(row(updated, 'sigFields')['value'], 'both');
    settings.dispose();
    extensions.runtimeGeneration.dispose();
  });

  test('defaults have two independent template categories and shared ADIF fields', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final extensions = _Extensions();
    final group = ExportsSettingsGroup(settings, extensions);
    final fields = await group.typeElements('default');
    expect(fields.first['text'], t.exportSettings.defaultsDescription);
    expect(fields.where((e) => e['type'] == 'header').map((e) => e['title']), ['Reference Activities', 'Other Activities', 'ADIF Fields']);
    final templates = fields.where((e) => e['fieldType'] == 'textTemplate').toList();
    expect(templates, hasLength(9));
    expect(templates.every((e) => e['disabled'] == false), isTrue);
    expect(fields.any((e) => e['key'] == 'default::customTemplates'), isFalse);
    final reference = templates.firstWhere((e) => e['key'] == 'default::referenceFilenameTemplate');
    final other = templates.firstWhere((e) => e['key'] == 'default::otherFilenameTemplate');
    expect(reference['templateSample']['log']['ref'], 'US-1234');
    expect(other['templateSample']['log']['ref'], '');
    expect(other['templateSample']['log']['activity'], 'CQ WW');
    await group.commit('default::referenceFilenameTemplate', 'My park');
    await group.commit('default::otherFilenameTemplate', 'My contest');
    final updated = await group.typeElements('default');
    expect(updated.firstWhere((e) => e['key'] == reference['key'])['value'], 'My park');
    expect(updated.firstWhere((e) => e['key'] == other['key'])['value'], 'My contest');
    expect((await group.typeElements('potaActivation-adif')).first['text'], t.exportSettings.shared);
    settings.dispose();
    extensions.runtimeGeneration.dispose();
  });

  testWidgets('export rows open independent type settings without a shared selector', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final extensions = _Extensions();
    final group = ExportsSettingsGroup(settings, extensions);
    final elements = await group.buildElements();
    expect(elements.map((e) => e['label']), containsAll(['Defaults', 'POTA ADIF', 'CQ WW CABRILLO']));
    expect(elements.any((e) => e['key'] == 'editingType'), isFalse);
    expect(elements.any((e) => e['key'].toString().contains('::')), isFalse);
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => FormRenderer(
                formDefinition: {'elements': elements},
                initialState: const {},
                settingsList: true,
                showActions: false,
                showTitle: false,
                onAction: (key, method, state) async {
                  await group.openAction(context, key);
                  return null;
                },
                onSubmit: (_) {},
                onCancel: () {},
              ),
            ),
          ),
        ),
      ),
    );
    // The file options start folded.
    await tester.tap(find.text(t.settings.exports.fileOptions));
    await tester.pumpAndSettle();
    await tester.tap(find.text('POTA ADIF'));
    await tester.pumpAndSettle();
    expect(find.text('Include lookup data'), findsOneWidget);
    final modalForm = tester.widgetList<FormRenderer>(find.byType(FormRenderer)).last;
    final initialFields = modalForm.formDefinition['elements'] as List;
    expect(initialFields.firstWhere((e) => e['key'] == 'potaActivation-adif::includeLookupData')['disabled'], isTrue);
    await modalForm.onChange!('potaActivation-adif::includePrivateData', true, {});
    await tester.pumpAndSettle();
    final enabledForm = tester.widgetList<FormRenderer>(find.byType(FormRenderer)).last;
    final enabledFields = enabledForm.formDefinition['elements'] as List;
    expect(enabledFields.firstWhere((e) => e['key'] == 'potaActivation-adif::includeLookupData')['disabled'], isFalse);
    await enabledForm.onChange!('potaActivation-adif::customTemplates', true, {});
    await tester.pumpAndSettle();
    expect(settings.exportTypeOverrides('potaActivation-adif')['customTemplates'], isTrue);
    final updated = tester.widgetList<FormRenderer>(find.byType(FormRenderer)).last;
    final fields = updated.formDefinition['elements'] as List;
    expect(fields.firstWhere((e) => e['key'] == 'potaActivation-adif::filenameTemplate')['disabled'], isFalse);
    extensions.fail = true;
    await settings.setExportTypeSetting('potaActivation-adif', 'includeLookupData', false);
    await tester.pumpAndSettle();
    expect(find.text('Export settings could not be loaded.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    extensions.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Include lookup data'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CQ WW CABRILLO'));
    await tester.pumpAndSettle();
    expect(find.text('Include lookup data'), findsNothing);
    expect(find.text('Include private info'), findsNothing);
    expect(find.text('File name template'), findsOneWidget);
    expect(settings.exportTypeOverrides('cqww-cabrillo'), isEmpty);
    final cabrilloFields = tester.widgetList<FormRenderer>(find.byType(FormRenderer)).last.formDefinition['elements'] as List;
    final sample = cabrilloFields.firstWhere((e) => e['key'] == 'cqww-cabrillo::filenameTemplate')['templateSample'] as Map;
    expect(sample['log']['ref'], '');
    expect(sample['log']['activity'], 'CQ WW');
    expect(sample['log']['extension'], 'log');
    expect(sample['operation']['refs'], isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    settings.dispose();
    extensions.runtimeGeneration.dispose();
  });
}

class _FakeContext extends Fake implements BuildContext {}
