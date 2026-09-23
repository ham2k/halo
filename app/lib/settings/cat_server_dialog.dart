// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The CAT Server dialog, opened from its row in the Radio section: which
// program HaLo stands in for, on which port, and whether other computers
// may connect too (docs/design/cat.md § CAT server).

import 'package:flutter/material.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../services/cat_server/cat_server_protocol.dart';
import '../services/cat_server/cat_server_service.dart';
import '../services/settings_service.dart';

String _protocolName(CatServerProtocol protocol) => t['settings.catServer.protocolOpts.${protocol.key}'] as String;

/// One line saying what the server is doing — the Radio row's subtitle and
/// the dialog's first line.
String catServerStatusText(CatServerService service) {
  final s = t.settings.catServer;
  final status = service.status;
  final protocol = status.protocol;
  if (protocol == null) return s.off;
  final name = _protocolName(protocol);
  final error = status.error;
  if (error != null) {
    final port = status.attemptedPort ?? CatServerSettings.port(service.settings, protocol);
    return switch (status.failure) {
      CatServerFailure.portInUse => s.portInUse(protocol: name, port: port),
      CatServerFailure.portDenied => s.portDenied(protocol: name, port: port),
      CatServerFailure.stopped => s.stopped(protocol: name, port: port),
      _ => s.failed(protocol: name, port: port, error: error),
    };
  }
  final port = status.port;
  if (port == null) return s.starting(protocol: name);
  if (!service.radioAvailable) return s.listeningNoRadio(protocol: name, port: port);
  return s.listening(protocol: name, port: port, clients: status.clients);
}

/// The port row's key while no program is picked: a field with nothing to
/// store.
const _noPortKey = 'catServerPortOff';

/// The dialog's fields. Port and access stay visible while the server is
/// off, greyed, so the operator sees the dialog they will be using.
List<Map<String, dynamic>> catServerElements(CatServerService service) {
  final s = t.settings.catServer;
  final settings = service.settings;
  final protocol = CatServerSettings.protocol(settings);
  final openAccess = CatServerSettings.openAccess(settings);
  return [
    {'type': 'markdown', 'text': s.description},
    {
      'type': 'field',
      'fieldType': 'select',
      'key': CatServerSettings.protocolKey,
      'label': s.protocol,
      'icon': 'lan-connect',
      'description': catServerStatusText(service),
      'value': protocol?.key ?? CatServerSettings.off,
      'options': [
        {'label': s.protocolOpts.off, 'value': CatServerSettings.off},
        for (final p in CatServerProtocol.values) {'label': _protocolName(p), 'value': p.key},
      ],
    },
    {
      'type': 'field',
      'fieldType': 'number',
      // The picked program's own key, so switching programs is a different
      // field with its own value rather than one field asked to change what
      // it shows.
      'key': protocol == null ? _noPortKey : CatServerSettings.portKey(protocol),
      'label': s.port,
      'icon': 'ethernet',
      // A number, as the field reports it back: a text value never matches
      // what the field holds after an edit, and the field stops taking new
      // values from the definition.
      'value': protocol == null ? null : CatServerSettings.port(settings, protocol),
      'disabled': protocol == null,
    },
    {
      'type': 'field',
      'fieldType': 'checkbox',
      'key': CatServerSettings.openAccessKey,
      'label': s.openAccess,
      'icon': 'shield-lock-outline',
      'description': openAccess ? s.openAccessOn : s.openAccessOff,
      'value': openAccess,
      'disabled': protocol == null,
    },
  ];
}

Future<void> commitCatServerSetting(SettingsService settings, String key, dynamic value) async {
  switch (key) {
    case CatServerSettings.protocolKey:
      if (value is! String) return;
      if (value != CatServerSettings.off && !CatServerProtocol.values.any((p) => p.key == value)) return;
      if (value == (CatServerSettings.protocol(settings)?.key ?? CatServerSettings.off)) return;
      await settings.setSettingValue(SettingsService.radioGroup, key, value);
    case CatServerSettings.openAccessKey:
      if (value is bool) await settings.setSettingValue(SettingsService.radioGroup, key, value);
    default:
      if (CatServerSettings.protocolForPortKey(key) == null) return;
      final port = value is num ? value.toInt() : int.tryParse('$value'.trim());
      // Refused rather than stored: a port the server would read back as its
      // default is a setting that says one thing and does another.
      if (port == null || !CatServerSettings.isValidPort(port)) return;
      await settings.setSettingValue(SettingsService.radioGroup, key, port);
  }
}

class CatServerDialog extends StatefulWidget {
  final CatServerService service;

  const CatServerDialog({super.key, required this.service});

  @override
  State<CatServerDialog> createState() => _CatServerDialogState();
}

class _CatServerDialogState extends State<CatServerDialog> {
  late final Listenable _changes = Listenable.merge([widget.service.settings, widget.service]);

  @override
  void initState() {
    super.initState();
    _changes.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    _changes.removeListener(_rebuild);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HaloDialog(
    title: Text(context.t.settings.catServer.title),
    list: true,
    content: FormRenderer(
      formDefinition: {'elements': catServerElements(widget.service)},
      initialState: const {},
      settingsList: true,
      showActions: false,
      showTitle: false,
      onChange: (key, value, state) async {
        await commitCatServerSetting(widget.service.settings, key, value);
        return null;
      },
      onSubmit: (_) {},
      onCancel: () {},
    ),
    cancel: TextButton(onPressed: () => Navigator.pop(context), child: Text(context.t.common.done)),
  );
}
