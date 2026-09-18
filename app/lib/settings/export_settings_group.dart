// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../services/export_preferences.dart';
import '../services/error_reporting_service.dart';
import '../services/extension_service.dart';
import '../services/settings_service.dart';
import 'settings_registry.dart';

class ExportsSettingsGroup extends SettingsGroup {
  final SettingsService settings;
  final ExtensionService? extensions;
  ExportsSettingsGroup(this.settings, [this.extensions]);

  @override
  String get key => 'exports';
  @override
  String get title => t.settings.exports.title;
  @override
  int get order => 25;
  @override
  Listenable get listenable => Listenable.merge([settings, if (extensions != null) extensions!.runtimeGeneration]);

  Future<List<Map<String, dynamic>>> _types() async =>
      await extensions?.exportTypeSettings(settings.exportGlobalSettings, settings.exportTypeOverrides) ?? [];

  String _label(Map<String, dynamic> type) {
    if (type['exportType'] == 'default') return t.exportSettings.defaults;
    final label = type['label'] as String;
    final format = (type['format'] as String).toUpperCase();
    return label.toUpperCase().split(' ').contains(format) ? label : '$label $format';
  }

  @override
  Future<List<Map<String, dynamic>>> buildElements() async {
    final types = await _types();
    return [
      {
        'type': 'field', 'fieldType': 'checkbox', 'key': 'useCompactFileNames',
        'label': t.operation.export.compactFileNames.title, 'icon': 'file-arrow-left-right-outline',
        'description': settings.useCompactFileNames
            ? t.exportSettings.compactFileNamesDescriptionOn : t.exportSettings.compactFileNamesDescriptionOff,
        'value': settings.useCompactFileNames, 'target': 'exports',
      },
      if (types.isEmpty) {
        'type': 'field', 'fieldType': 'checkbox', 'key': 'includePrivateData',
        'label': t.operation.export.includePrivateData.title, 'icon': 'account-lock-outline',
        'description': settings.includePrivateData
            ? t.exportSettings.includePrivateDataDescriptionOn : t.exportSettings.includePrivateDataDescriptionOff,
        'value': settings.includePrivateData, 'target': 'exports',
      },
      for (final type in types) {
        'type': 'action', 'style': 'row', 'key': type['exportType'],
        'label': _label(type), 'icon': 'file-cog-outline', 'target': 'exports',
      },
    ];
  }

  @override
  Future<void> openAction(BuildContext context, String actionKey) async {
    final definition = (await _types()).where((type) => type['exportType'] == actionKey).firstOrNull;
    if (definition == null || !context.mounted) return;
    await showHaloDialog<void>(
      context: context,
      builder: (_) => _ExportTypeDialog(group: this, type: actionKey, title: _label(definition)),
    );
  }

  Future<List<Map<String, dynamic>>> typeElements(String id) async {
    final definition = (await _types()).where((type) => type['exportType'] == id).firstOrNull;
    if (definition == null) return [];
    final labels = t.exportSettings;
    final values = Map<String, dynamic>.from(definition['settings'] as Map? ?? {});
    final defaults = Map<String, dynamic>.from(definition['defaults'] as Map? ?? {});
    final format = definition['format'] as String;
    final sample = Map<String, dynamic>.from(definition['templateSample'] as Map? ?? {});
    final sampleLog = {
      'activity': id == 'default' || id == 'adif' ? '' : definition['label'],
      'exportType': id, 'format': format,
      'extension': {'adif': 'adi', 'cabrillo': 'log', 'reg1test': 'edi'}[format] ?? 'txt',
      'ref': '', 'refName': '', 'modifier': id == 'adif' ? 'Full' : '',
      ...Map<String, dynamic>.from(sample['log'] as Map? ?? {}),
    };

    Map<String, dynamic> field(String key, String label, {bool template = false, String? icon, String? description}) => {
      'type': 'field', 'key': '$id::$key', 'label': label,
      'fieldType': template ? 'textTemplate' : 'checkbox',
      'icon': icon ?? (template ? 'file-code-outline' : 'cog-outline'),
      'description': ?description,
      'value': values[key], 'defaultValue': defaults[key], 'target': 'exports',
      if (key == 'includeLookupData') 'disabled': values['includePrivateData'] != true,
      if (template) ...{
        'templateContext': key.startsWith('adif') ? 'adif' : 'export',
        'disabled': id != 'default' && values['customTemplates'] != true,
        'templateSample': {
          ...sample,
          'operation': {
            'refs': <dynamic>[], ...Map<String, dynamic>.from(sample['operation'] as Map? ?? {}),
            if (key.startsWith('reference')) 'refs': [{'type': 'potaActivation', 'ref': 'US-1234'}],
          },
          'log': {
            ...sampleLog,
            if (key.startsWith('reference')) ...{'activity': 'POTA', 'ref': 'US-1234', 'refName': 'Example Park'},
            if (key.startsWith('other')) 'activity': 'CQ WW',
          },
        },
      },
    };
    return [
        {'type': 'markdown', 'text': id == 'default' ? labels.defaultsDescription : labels.shared},
        if (definition['format'] == 'adif') ...[
          field('includePrivateData', t.operation.export.includePrivateData.title,
            icon: 'account-lock-outline', description: values['includePrivateData'] == true
                ? labels.includePrivateDataDescriptionOn : labels.includePrivateDataDescriptionOff),
          field('includeLookupData', labels.includeLookupData,
            icon: 'database-search-outline', description: values['includeLookupData'] == true
                ? labels.includeLookupDataDescriptionOn : labels.includeLookupDataDescriptionOff),
        ],
        if (id != 'default') field('customTemplates', labels.customTemplates,
          description: values['customTemplates'] == true
              ? labels.customTemplatesDescriptionOn : labels.customTemplatesDescriptionOff),
        if (id == 'default') ...[
          {'type': 'header', 'style': 'section', 'title': labels.referenceActivities},
          field('referenceFilenameTemplate', labels.filenameTemplate, template: true),
          field('referenceCompactFilenameTemplate', labels.compactFilenameTemplate, template: true),
          field('referenceTitleTemplate', labels.titleTemplate, template: true),
          {'type': 'header', 'style': 'section', 'title': labels.otherActivities},
          field('otherFilenameTemplate', labels.filenameTemplate, template: true),
          field('otherCompactFilenameTemplate', labels.compactFilenameTemplate, template: true),
          field('otherTitleTemplate', labels.titleTemplate, template: true),
          {'type': 'header', 'style': 'section', 'title': labels.adifFields},
        ] else ...[
          field('filenameTemplate', labels.filenameTemplate, template: true),
          field('compactFilenameTemplate', labels.compactFilenameTemplate, template: true),
          if (format == 'adif') field('titleTemplate', labels.titleTemplate, template: true),
        ],
        if (format == 'adif') ...[
          field('adifNotesTemplate', labels.adifNotesTemplate, template: true),
          field('adifCommentTemplate', labels.adifCommentTemplate, template: true),
          field('adifQslMessageTemplate', labels.adifQslMessageTemplate, template: true),
        ],
    ];
  }

  @override
  Future<void> commit(String fieldKey, dynamic value) async {
    final separator = fieldKey.indexOf('::');
    if (separator >= 0) {
      await settings.setExportTypeSetting(fieldKey.substring(0, separator), fieldKey.substring(separator + 2), value);
    } else {
      await settings.setSettingValue(SettingsService.exportsGroup, fieldKey, value);
    }
  }
}

class _ExportTypeDialog extends StatefulWidget {
  final ExportsSettingsGroup group;
  final String type;
  final String title;
  const _ExportTypeDialog({required this.group, required this.type, required this.title});

  @override
  State<_ExportTypeDialog> createState() => _ExportTypeDialogState();
}

class _ExportTypeDialogState extends State<_ExportTypeDialog> {
  late final Listenable _changes;
  late Future<List<Map<String, dynamic>>?> _elements;

  @override
  void initState() {
    super.initState();
    _elements = _loadElements();
    _changes = widget.group.listenable..addListener(_reload);
  }

  Future<List<Map<String, dynamic>>?> _loadElements() async {
    try {
      return await widget.group.typeElements(widget.type);
    } catch (error, stack) {
      ErrorReportingService.report(error, stack, context: 'exports:load-settings');
      return null;
    }
  }

  void _reload() {
    final elements = _loadElements();
    setState(() { _elements = elements; });
  }

  @override
  void dispose() {
    _changes.removeListener(_reload);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HaloDialog(
    title: Text(widget.title),
    wide: true,
    list: true,
    content: FutureBuilder<List<Map<String, dynamic>>?>(
      future: _elements,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.data == null) {
          return Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(context.t.exportSettings.loadFailed),
              TextButton(onPressed: _reload, child: Text(context.t.exportSettings.retry)),
            ]),
          );
        }
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        return FormRenderer(
          formDefinition: {'elements': snapshot.data!},
          initialState: const {},
          settingsList: true, showActions: false, showTitle: false,
          onChange: (key, value, state) async {
            await widget.group.commit(key, value);
            return null;
          },
          onSubmit: (_) {}, onCancel: () {},
        );
      },
    ),
    cancel: TextButton(onPressed: () => Navigator.pop(context), child: Text(context.t.common.done)),
  );
}
