// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Select Server dialog, opened from the DX Cluster section's Cluster
// Server row: one of the known servers, or any other by server and port
// (docs/design/cluster.md § Choosing a node).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../services/cluster/cluster_settings.dart';
import '../services/settings_service.dart';

bool _isOther(SettingsService settings) => settings.settingValue(ClusterSettings.group, ClusterSettings.nodeKey) == ClusterSettings.custom;

String _storedHost(SettingsService settings) => '${settings.settingValue(ClusterSettings.group, ClusterSettings.customHostKey) ?? ''}'.trim();

int? _storedPort(SettingsService settings) {
  final raw = settings.settingValue(ClusterSettings.group, ClusterSettings.customPortKey);
  return raw is num ? raw.toInt() : int.tryParse('${raw ?? ''}');
}

/// The server the settings name, as the section's row says it.
String clusterServerText(SettingsService settings) {
  final node = ClusterSettings.node(settings);
  if (!_isOther(settings)) return '${node.name} · ${node.address} · ${node.description}';
  // Another server with no host yet posts to the default one; saying so is
  // the only place the operator learns it.
  if (_storedHost(settings).isEmpty) return t.settings.cluster.serverOtherIncomplete(node: node.name);
  return node.address;
}

/// The server settings as declared fields, so SET and SHOW reach them; the
/// section lists none of them (the dialog edits them).
List<Map<String, dynamic>> clusterServerElements(SettingsService settings) {
  final s = t.settings.cluster;
  return [
    {
      'type': 'field',
      'fieldType': 'select',
      'key': ClusterSettings.nodeKey,
      'label': s.server,
      'value': _isOther(settings) ? ClusterSettings.custom : ClusterSettings.node(settings).name,
      'options': [
        for (final known in knownClusterNodes) {'label': '${known.name} · ${known.description}', 'value': known.name},
        {'label': s.serverOther, 'value': ClusterSettings.custom},
      ],
    },
    {'type': 'field', 'fieldType': 'text', 'key': ClusterSettings.customHostKey, 'label': s.customHost, 'value': _storedHost(settings)},
    {'type': 'field', 'fieldType': 'number', 'key': ClusterSettings.customPortKey, 'label': s.customPort, 'value': _storedPort(settings)},
  ];
}

Future<void> commitClusterServerSetting(SettingsService settings, String key, dynamic value) async {
  switch (key) {
    case ClusterSettings.customPortKey:
      final port = value is num ? value.toInt() : int.tryParse('${value ?? ''}'.trim());
      await settings.setSettingValue(ClusterSettings.group, key, port);
    case ClusterSettings.nodeKey || ClusterSettings.customHostKey:
      await settings.setSettingValue(ClusterSettings.group, key, value is String ? value.trim() : value);
  }
}

class ClusterServerDialog extends StatefulWidget {
  final SettingsService settings;

  const ClusterServerDialog({super.key, required this.settings});

  @override
  State<ClusterServerDialog> createState() => _ClusterServerDialogState();
}

class _ClusterServerDialogState extends State<ClusterServerDialog> {
  late bool _other = _isOther(widget.settings);
  late final _host = TextEditingController(text: _storedHost(widget.settings));
  late final _port = TextEditingController(text: _storedPort(widget.settings)?.toString() ?? '');
  final _hostFocus = FocusNode();

  void _pick(ClusterNode node) {
    _other = false;
    unawaited(widget.settings.setSettingValue(ClusterSettings.group, ClusterSettings.nodeKey, node.name));
    Navigator.pop(context);
  }

  void _pickOther() {
    setState(() => _other = true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _hostFocus.requestFocus());
  }

  /// What was typed for another server, kept by every way out of the dialog
  /// — Done, Escape, a tap outside — since none of them means discard it.
  /// With no server typed, the previous choice stands: another server with
  /// no host would quietly post to the default.
  Future<void> _commitOther(SettingsService settings, String host, String port) async {
    if (host.isEmpty) return;
    // Host and port before the switch, so the service reconnects once, to
    // the whole address.
    await commitClusterServerSetting(settings, ClusterSettings.customHostKey, host);
    await commitClusterServerSetting(settings, ClusterSettings.customPortKey, port);
    await commitClusterServerSetting(settings, ClusterSettings.nodeKey, ClusterSettings.custom);
  }

  @override
  void dispose() {
    if (_other) unawaited(_commitOther(widget.settings, _host.text.trim(), _port.text.trim()));
    _host.dispose();
    _port.dispose();
    _hostFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.t.settings.cluster;
    final current = ClusterSettings.node(widget.settings);
    void done() => Navigator.pop(context);
    return HaloDialog(
      title: Text(s.selectServer),
      // Edge to edge, as the app's other select dialogs are.
      contentPadding: EdgeInsets.zero,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final node in knownClusterNodes)
            ListTile(
              title: Text(node.name),
              subtitle: node.description == null ? null : Text(node.description!),
              trailing: !_other && node == current ? const Icon(MdiIcons.check) : null,
              onTap: () => _pick(node),
              mouseCursor: SystemMouseCursors.click,
            ),
          ListTile(title: Text(s.serverOther), trailing: _other ? const Icon(MdiIcons.check) : null, onTap: _pickOther, mouseCursor: SystemMouseCursors.click),
          if (_other)
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.xl, Space.xs, Space.xl, Space.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _host,
                      focusNode: _hostFocus,
                      autocorrect: false,
                      keyboardType: TextInputType.url,
                      decoration: poloFieldDecoration(context, s.customHost, hintText: 'dxc.example.net'),
                      onSubmitted: (_) => done(),
                    ),
                  ),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: TextField(
                      controller: _port,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)],
                      decoration: poloFieldDecoration(context, s.customPort, hintText: '23'),
                      onSubmitted: (_) => done(),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      cancel: TextButton(onPressed: done, child: Text(context.t.common.done)),
    );
  }
}
