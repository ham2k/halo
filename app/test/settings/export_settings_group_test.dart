// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

void main() {
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
