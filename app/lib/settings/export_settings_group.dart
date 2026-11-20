// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:halo_extension_host/halo_extension_host.dart' show ExtensionHostException;
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../config/experiments.dart';
import '../services/export_preferences.dart';
import '../services/error_reporting_service.dart';
import '../services/extensions/extension_service.dart';
import '../services/settings_service.dart';
import 'settings_registry.dart';
import 'settings_section_folds.dart';

/// Exports & Imports: the export file settings, and under `EXP PUSH` each
/// service a `transfer` hook sends to with the account it signs in with
/// (docs/design/transfer.md §3). A service's own options are its
/// extension's panel, placed here by `section: "exports"`
/// (docs/extensions/settings.md).
class ExportsSettingsGroup extends SettingsGroup {
  final SettingsService settings;
  final ExtensionService? extensions;

  /// Opens an account's pane by its key, finishing when it closes. Null
  /// leaves the services out: tests of the file settings.
  final Future<void> Function(String accountKey)? openAccount;

  ExportsSettingsGroup(this.settings, [this.extensions, this.openAccount]);

  /// Rung when an account pane closes: what it saved is the account's
  /// identity, which nothing else this group listens to announces.
  final _accountChanges = _Relay();

  /// A service row's key: the service, then the account's key. A service
  /// key never holds a colon, so the account's is everything after the
  /// second.
  static const _servicePrefix = 'transfer:';

  @override
  String get key => 'exports';
  @override
  String get title => t.settings.exports.title;
  @override
  int get order => 25;
  @override
  Listenable get listenable => Listenable.merge([settings, _accountChanges, if (extensions != null) extensions!.runtimeGeneration]);

  Future<List<Map<String, dynamic>>> _types() async => await extensions?.exportTypeSettings(settings.exportGlobalSettings, settings.exportTypeOverrides) ?? [];

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
      // A folded section rather than a disclosure: the rows stay top-level,
      // where the operation's Export Settings dialog and SET/SHOW find them.
      {'type': 'header', 'style': 'section', 'key': 'fileExportOptions', 'title': t.settings.exports.fileOptions, 'collapsed': true},
      {
        'type': 'field',
        'fieldType': 'checkbox',
        'key': 'useCompactFileNames',
        'label': t.operation.export.compactFileNames.title,
        'icon': 'file-arrow-left-right-outline',
        'description': settings.useCompactFileNames ? t.exportSettings.compactFileNamesDescriptionOn : t.exportSettings.compactFileNamesDescriptionOff,
        'value': settings.useCompactFileNames,
        'target': 'exports',
      },
      if (types.isEmpty)
        {
          'type': 'field',
          'fieldType': 'checkbox',
          'key': 'includePrivateData',
          'label': t.operation.export.includePrivateData.title,
          'icon': 'account-lock-outline',
          'description': settings.includePrivateData ? t.exportSettings.includePrivateDataDescriptionOn : t.exportSettings.includePrivateDataDescriptionOff,
          'value': settings.includePrivateData,
          'target': 'exports',
        },
      for (final type in types)
        {'type': 'action', 'style': 'row', 'key': type['exportType'], 'label': _label(type), 'icon': 'file-cog-outline', 'target': 'exports'},
      ...await _serviceRows(),
    ];
  }

  /// A row per service and account its extension declares, saying who it
  /// signs in as. Read from the keychain, never from the service: opening
  /// Settings calls nobody.
  Future<List<Map<String, dynamic>>> _serviceRows() async {
    final extensions = this.extensions;
    if (extensions == null || openAccount == null || !settings.experimentEnabled(kPushExperiment)) return const [];
    final TransferServices services;
    try {
      services = await extensions.transferServices();
    } on ExtensionHostException catch (error, stack) {
      // Without a runtime yet, its generation rings when one starts and the
      // rows come back with it. A timeout or a dead runtime rings nothing, so
      // ErrorPolicy decides what it deserves.
      if (extensions.host != null) ErrorReportingService.report(error, stack, context: 'settings:transfer-services');
      return const [];
    }
    // Null is "the extensions could not be asked", not "no accounts": each
    // service still gets its row, saying so, and a tap asks again.
    final accounts = await extensions.getAccounts();
    final identities = <String, String>{};
    var storageUnavailable = false;
    Future<String> identityOf(String kvKey) async {
      if (storageUnavailable) return t.formChrome.storageUnavailable;
      if (identities[kvKey] case final known?) return known;
      // Null means secure storage could not be reached, and every read would
      // fail and report the same way: stop asking.
      final credentials = await extensions.getAccountCredentials(kvKey);
      if (credentials == null) storageUnavailable = true;
      return identities[kvKey] = switch (credentials) {
        null => t.formChrome.storageUnavailable,
        final c when c.isEmpty => t.settings.accounts.notConfigured,
        final c => ExtensionService.identityFromCredentials(c) ?? t.settings.accounts.connected,
      };
    }

    Map<String, dynamic> row(String key, String label, String description) => {
      'type': 'action',
      'style': 'row',
      'key': '$_servicePrefix$key',
      'label': label,
      'icon': 'cloud-upload-outline',
      'description': description,
    };
    final rows = <Map<String, dynamic>>[];
    for (final service in services.byKey.values) {
      if (accounts == null) {
        rows.add(row('${service.key}:', service.label, t.settings.accounts.lookupFailed));
        continue;
      }
      for (final account in accounts.where((account) => service.extensionKey != null && account['extensionKey'] == service.extensionKey)) {
        final kvKey = account['kvKey'] as String;
        final accountLabel = account['label'] as String? ?? kvKey;
        rows.add(row('${service.key}:$kvKey', service.label, t.settings.exports.serviceAccount(account: accountLabel, identity: await identityOf(kvKey))));
      }
    }
    // A hook that could not list its services keeps a row with its error,
    // as in the push rows: left out, it would read as not installed.
    for (final MapEntry(key: hookKey, value: error) in services.failed.entries) {
      rows.add(row('$hookKey:', hookKey, error));
    }
    if (rows.isEmpty) return const [];
    return [
      {'type': 'header', 'style': 'section', 'key': 'transferServices', 'title': t.settings.exports.services},
      ...rows,
    ];
  }

  @override
  Future<void> openAction(BuildContext context, String actionKey) async {
    if (actionKey.startsWith(_servicePrefix)) {
      final rest = actionKey.substring(_servicePrefix.length);
      final kvKey = rest.substring(rest.indexOf(':') + 1);
      // A row without an account is one that failed: ringing builds it again.
      if (kvKey.isNotEmpty) await openAccount?.call(kvKey);
      _accountChanges.notify();
      return;
    }
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
      'exportType': id,
      'format': format,
      'extension': {'adif': 'adi', 'cabrillo': 'log', 'reg1test': 'edi'}[format] ?? 'txt',
      'ref': '',
      'refName': '',
      'modifier': id == 'adif' ? 'Full' : '',
      ...Map<String, dynamic>.from(sample['log'] as Map? ?? {}),
    };

    Map<String, dynamic> field(String key, String label, {bool template = false, String? icon, String? description}) => {
      'type': 'field',
      'key': '$id::$key',
      'label': label,
      'fieldType': template ? 'textTemplate' : 'checkbox',
      'icon': icon ?? (template ? 'file-code-outline' : 'cog-outline'),
      'description': ?description,
      'value': values[key],
      'defaultValue': defaults[key],
      'target': 'exports',
      if (key == 'includeLookupData') 'disabled': values['includePrivateData'] != true,
      if (template) ...{
        'templateContext': key.startsWith('adif') ? 'adif' : 'export',
        'disabled': id != 'default' && values['customTemplates'] != true,
        'templateSample': {
          ...sample,
          'operation': {
            'refs': <dynamic>[],
            ...Map<String, dynamic>.from(sample['operation'] as Map? ?? {}),
            if (key.startsWith('reference'))
              'refs': [
                {'type': 'potaActivation', 'ref': 'US-1234'},
              ],
          },
          'log': {
            ...sampleLog,
            if (key.startsWith('reference')) ...{'activity': 'POTA', 'ref': 'US-1234', 'refName': 'Example Park'},
            if (key.startsWith('other')) 'activity': 'CQ WW',
          },
        },
      },
    };
    final picks = Map<String, dynamic>.from(values['choices'] as Map? ?? {});
    return [
      {'type': 'markdown', 'text': id == 'default' ? labels.defaultsDescription : labels.shared},
      for (final choice in _choices(definition))
        {
          'type': 'field',
          'fieldType': 'select',
          'key': '$id::$_choicePrefix${choice['key']}',
          'label': choice['label'],
          'icon': 'cog-outline',
          'description': ?choice['description'],
          'value': picks[choice['key']] ?? choice['default'],
          'defaultValue': choice['default'],
          'options': choice['options'],
          'target': 'exports',
        },
      if (definition['format'] == 'adif') ...[
        field(
          'includePrivateData',
          t.operation.export.includePrivateData.title,
          icon: 'account-lock-outline',
          description: values['includePrivateData'] == true ? labels.includePrivateDataDescriptionOn : labels.includePrivateDataDescriptionOff,
        ),
        field(
          'includeLookupData',
          labels.includeLookupData,
          icon: 'database-search-outline',
          description: values['includeLookupData'] == true ? labels.includeLookupDataDescriptionOn : labels.includeLookupDataDescriptionOff,
        ),
      ],
      if (id != 'default')
        field(
          'customTemplates',
          labels.customTemplates,
          description: values['customTemplates'] == true ? labels.customTemplatesDescriptionOn : labels.customTemplatesDescriptionOff,
        ),
      if (id == 'default') ...[
        {'type': 'header', 'style': 'section', 'key': 'referenceActivities', 'title': labels.referenceActivities},
        field('referenceFilenameTemplate', labels.filenameTemplate, template: true),
        field('referenceCompactFilenameTemplate', labels.compactFilenameTemplate, template: true),
        field('referenceTitleTemplate', labels.titleTemplate, template: true),
        {'type': 'header', 'style': 'section', 'key': 'otherActivities', 'title': labels.otherActivities},
        field('otherFilenameTemplate', labels.filenameTemplate, template: true),
        field('otherCompactFilenameTemplate', labels.compactFilenameTemplate, template: true),
        field('otherTitleTemplate', labels.titleTemplate, template: true),
        {'type': 'header', 'style': 'section', 'key': 'adifFields', 'title': labels.adifFields},
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

  static const _choicePrefix = 'choices/';

  /// The type's own `choices` (ExportChoice), each with a key, a label, a
  /// default and options of string values, the default among them. An
  /// extension's malformed entry is left off the page, by the same rule that
  /// leaves it out of `ExportSettings.choices` (`wellFormedChoices` in the
  /// SDK's exportSettings.ts): a hook gets a pick only for a choice shown here.
  List<Map<String, dynamic>> _choices(Map<String, dynamic> definition) => [
    for (final choice in (definition['choices'] as List? ?? const []).whereType<Map<dynamic, dynamic>>())
      if (choice['key'] is String && choice['label'] is String && choice['default'] is String && choice['options'] is List)
        if (_options(choice['options'] as List) case final options when options.any((o) => o['value'] == choice['default']))
          {
            'key': choice['key'],
            'label': choice['label'],
            if (choice['description'] is String) 'description': choice['description'],
            'default': choice['default'],
            'options': options,
          },
  ];

  static List<Map<String, String>> _options(List<dynamic> options) => [
    for (final option in options.whereType<Map<dynamic, dynamic>>())
      if (option['value'] is String && option['label'] is String) {'value': option['value'] as String, 'label': option['label'] as String},
  ];

  @override
  Future<void> commit(String fieldKey, dynamic value) async {
    final separator = fieldKey.indexOf('::');
    if (separator >= 0) {
      final type = fieldKey.substring(0, separator);
      final key = fieldKey.substring(separator + 2);
      if (key.startsWith(_choicePrefix)) {
        // One map for every choice of the type, as `ExportSettings.choices`
        // reads it: a pick is saved beside the others, never over them.
        final picks = Map<String, dynamic>.from(settings.exportTypeOverrides(type)['choices'] as Map? ?? {});
        await settings.setExportTypeSetting(type, 'choices', {...picks, key.substring(_choicePrefix.length): value});
        return;
      }
      await settings.setExportTypeSetting(type, key, value);
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
    setState(() {
      _elements = elements;
    });
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(context.t.exportSettings.loadFailed),
                TextButton(onPressed: _reload, child: Text(context.t.exportSettings.retry)),
              ],
            ),
          );
        }
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        return FormRenderer(
          formDefinition: {'elements': snapshot.data!},
          initialState: const {},
          settingsList: true,
          showActions: false,
          showTitle: false,
          sectionFolds: SettingsSectionFolds(widget.group.settings.prefs, '${widget.group.key}/${widget.type}'),
          onChange: (key, value, state) async {
            await widget.group.commit(key, value);
            return null;
          },
          onSubmit: (_) {},
          onCancel: () {},
        );
      },
    ),
    cancel: TextButton(onPressed: () => Navigator.pop(context), child: Text(context.t.common.done)),
  );
}

/// A notifier anyone may ring: [ChangeNotifier.notifyListeners] is protected.
class _Relay extends ChangeNotifier {
  void notify() => notifyListeners();
}
