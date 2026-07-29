// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Station Configuration panel: the equipment the station is made of,
// and whether the app can currently talk to it (docs/design/gato.md).
//
// Hand-built rather than a declarative `fieldType: 'list'` — that field's
// `itemFields` is a static declaration and can't express a Connect button
// or a live status line. Individual editors DO go through the declarative
// path: `showFormPane` over the equipment type's own `configElements`, so a
// new type contributes its settings without touching this file.

import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../i18n/strings.g.dart';
import '../main.dart';
import '../services/gato/discovery.dart';
import '../services/gato/equipment.dart';
import '../services/gato/equipment_registry.dart';
import '../services/gato/gato_service.dart';
import '../tools/form_chrome_labels.dart';

class StationPanel extends StatelessWidget {
  final HaLoServices services;

  const StationPanel({super.key, required this.services});

  GatoService get _gato => services.gato;

  Future<void> _addEquipment(BuildContext context) async {
    // Discovery holds a bound UDP socket, so it runs only while the dialog
    // that shows its results is open — and the socket has to be released
    // even if the dialog throws, or `isDiscovering` stays true and every
    // later Add silently reuses an orphaned subscription.
    _gato.startDiscovery();
    final _AddChoice? choice;
    try {
      choice = await _showAddDialog(context);
    } finally {
      _gato.stopDiscovery();
    }
    if (choice == null || !context.mounted) return;

    if (choice.discovered != null) {
      // Already has everything it needs — no form to fill in.
      await _gato.addDiscovered(choice.discovered!);
      return;
    }

    final type = choice.type!;
    final values = await _editValues(context, type: type, name: '', config: type.defaultConfig);
    if (values == null) return;

    await _gato.addNode(typeKey: type.key, name: values.name, config: values.config);
  }

  Future<_AddChoice?> _showAddDialog(BuildContext context) {
    return showHaloDialog<_AddChoice>(
      context: context,
      builder: (context) => ListenableBuilder(
        listenable: _gato,
        builder: (context, _) {
          final st = context.t.settings.station;
          final found = _gato.discovered;
          final error = _gato.discoveryError;

          return HaloDialog(
            title: Text(st.addTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // What announced itself, first: for a Flex this is the whole
                // interaction — tap it and it's configured.
                if (error != null)
                  ListTile(
                    leading: Icon(Icons.wifi_off, color: Theme.of(context).colorScheme.error),
                    title: Text(st.discoveryUnavailable(error: error)),
                  )
                else if (found.isEmpty)
                  const ListTile(
                    leading: SizedBox(
                        width: 24,
                        height: 24,
                        child: Padding(padding: EdgeInsets.all(2), child: CircularProgressIndicator(strokeWidth: 2))),
                    title: _SearchingLabel(),
                  )
                else ...[
                  SectionHeader(st.found),
                  for (final device in found)
                    ListTile(
                      leading: Icon(_iconForCategory(_gato.registry.typeFor(device.typeKey)?.category)),
                      title: Text(device.name),
                      subtitle: device.detail == null ? null : Text(device.detail!),
                      onTap: () => Navigator.of(context).pop(_AddChoice.discovered(device)),
                      mouseCursor: SystemMouseCursors.click,
                    ),
                ],
                const Divider(),
                // A radio on another subnet, or behind a router that doesn't
                // forward broadcasts, never announces. Neither app-polo
                // branch had this path, and both were unusable without it.
                SectionHeader(st.addManually),
                for (final type in _gato.registry.types)
                  ListTile(
                    leading: Icon(_iconForCategory(type.category)),
                    title: Text(type.name),
                    // Which drivers have actually been run against the real
                    // hardware, rather than presenting them all as equal.
                    subtitle: type.driver.hardwareVerified ? null : Text(st.unverified),
                    onTap: () => Navigator.of(context).pop(_AddChoice.type(type)),
                    mouseCursor: SystemMouseCursors.click,
                  ),
              ],
            ),
            cancel: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.t.common.cancel),
            ),
          );
        },
      ),
    );
  }

  Future<void> _editEquipment(BuildContext context, EquipmentNode node) async {
    final type = _gato.typeFor(node);
    if (type == null) return;

    final values = await _editValues(context, type: type, name: node.name, config: node.config);
    if (values == null) return;

    await _gato.updateNode(node.copyWith(name: values.name, config: values.config));
  }

  /// The name field plus whatever the type asks for, in one form.
  Future<({String name, Map<String, dynamic> config})?> _editValues(
    BuildContext context, {
    required EquipmentType type,
    required String name,
    required Map<String, dynamic> config,
  }) async {
    final st = context.t.settings.station;
    final elements = [
      {
        'type': 'field',
        'fieldType': 'text',
        'key': 'name',
        'label': st.name,
        'description': st.nameDescription,
      },
      ...type.configElements(),
    ];

    final result = await showFormPane(
      context,
      formDefinition: {'title': type.name, 'elements': elements},
      initialState: {'name': name, ...config},
      // Runs per field on submit, so a bad address blocks the save and says
      // so on the address field rather than failing later at connect time.
      validator: (key, value, values) async => type.validateField(key, value, values),
      // Cancel/Save/Close and the rest of the pane's chrome. Without this
      // the form's own fields are translated and the buttons around them
      // are not.
      labels: formRendererLabelsFor(context.t),
    );
    if (result == null) return null;

    return (
      name: (result['name'] as String? ?? '').trim(),
      config: {
        for (final entry in result.entries)
          if (entry.key != 'name') entry.key: entry.value,
      },
    );
  }

  Future<void> _removeEquipment(BuildContext context, EquipmentNode node) async {
    final st = context.t.settings.station;
    final confirmed = await showHaloDialog<bool>(
      context: context,
      builder: (context) => HaloDialog(
        title: Text(st.removeTitle(name: _displayName(node))),
        content: Text(st.removeMessage),
        cancel: TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.t.common.cancel),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(st.remove),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _gato.removeNode(node.uuid);
  }

  String _displayName(EquipmentNode node) {
    if (node.name.isNotEmpty) return node.name;
    return _gato.typeFor(node)?.name ?? node.typeKey;
  }

  @override
  Widget build(BuildContext context) {
    final st = context.t.settings.station;

    return ListenableBuilder(
      listenable: _gato,
      builder: (context, _) {
        final safeLeft = PaneSafeArea.leftOf(context);
        final nodes = _gato.nodes;

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          children: [
            Padding(padding: EdgeInsets.only(left: safeLeft), child: SectionHeader(st.title)),
            if (nodes.isEmpty) ListTile(title: Text(st.none)),
            for (final node in nodes)
              _EquipmentTile(
                node: node,
                type: _gato.typeFor(node),
                state: _gato.stateFor(node.uuid),
                displayName: _displayName(node),
                isMainVfo: _gato.isRadio1(node.uuid),
                // Only worth offering once there's something to choose
                // between — a one-radio shack never has to think about it.
                canChooseRadio1: nodes.length > 1 && !_gato.isRadio1(node.uuid),
                onUseAsMainVfo: () => _gato.setRadio1(node.uuid),
                onEdit: () => _editEquipment(context, node),
                onRemove: () => _removeEquipment(context, node),
                onConnect: () => _gato.connect(node.uuid),
                onDisconnect: () => _gato.disconnect(node.uuid),
              ),
            ListTile(
              leading: const Icon(Icons.add),
              title: Text(st.add),
              onTap: () => _addEquipment(context),
              mouseCursor: SystemMouseCursors.click,
            ),
          ],
        );
      },
    );
  }
}

/// Either a device that announced itself (ready to add as-is) or a type to
/// configure by hand.
class _AddChoice {
  final EquipmentType? type;
  final DiscoveredEquipment? discovered;

  const _AddChoice.type(this.type) : discovered = null;
  const _AddChoice.discovered(this.discovered) : type = null;
}

/// Its own widget so the const ListTile above can hold it while the label
/// still comes from the ambient translations.
class _SearchingLabel extends StatelessWidget {
  const _SearchingLabel();

  @override
  Widget build(BuildContext context) => Text(context.t.settings.station.searching);
}

/// The same glyph the logging panel's own Radio control uses — a
/// transceiver should look like one thing throughout the app.
IconData _iconForCategory(String? category) =>
    category == kCategoryTransceiver ? MdiIcons.radio : Icons.developer_board;

class _EquipmentTile extends StatelessWidget {
  final EquipmentNode node;
  final EquipmentType? type;
  final EquipmentState state;
  final String displayName;

  /// This is `radio1` — the node whose VFO is the logging panel's, shown
  /// to the operator as "Main VFO".
  final bool isMainVfo;
  final bool canChooseRadio1;
  final VoidCallback onUseAsMainVfo;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  const _EquipmentTile({
    required this.node,
    required this.type,
    required this.state,
    required this.displayName,
    required this.isMainVfo,
    required this.canChooseRadio1,
    required this.onUseAsMainVfo,
    required this.onEdit,
    required this.onRemove,
    required this.onConnect,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    final st = context.t.settings.station;
    final theme = Theme.of(context);
    final resolvedType = type;

    // A record whose type isn't in the catalogue — written by a newer build,
    // or by a driver since removed. It stays listed and says so, rather than
    // silently disappearing along with the user's settings.
    if (resolvedType == null) {
      return ListTile(
        leading: Icon(Icons.help_outline, color: theme.colorScheme.error),
        title: Text(displayName),
        subtitle: Text(st.unknownType(typeKey: node.typeKey)),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, semanticLabel: st.remove),
          onPressed: onRemove,
        ),
      );
    }

    final busy = state.status == EquipmentStatus.connecting;
    final connected = state.status == EquipmentStatus.connected;

    return ListTile(
      leading: Icon(_iconForCategory(resolvedType.category)),
      title: Text(displayName),
      subtitle: Text.rich(TextSpan(children: [
        // Which radio the logging panel is actually following. Inline in the
        // subtitle rather than a box beside the title: the trailing row
        // already claims up to 190px, and a fixed-width pill next to the
        // name would squeeze the name out again on a narrow pane. First in
        // the line, so a wrap can't strand it below the fold.
        if (isMainVfo) ...[
          WidgetSpan(alignment: PlaceholderAlignment.middle, child: _MainVfoPill(label: st.mainVfo)),
          const TextSpan(text: '  '),
        ],
        TextSpan(text: resolvedType.describeTarget(node.config)),
        const TextSpan(text: '  ·  '),
        TextSpan(
          text: _statusLabel(context, state),
          style: TextStyle(color: _statusColor(theme, state.status)),
        ),
      ])),
      onTap: onEdit,
      mouseCursor: SystemMouseCursors.click,
      // ListTile hands `trailing` unbounded width and gives the title
      // whatever is left, so a long translation of "Disconnect" ("Desconectar")
      // squeezes the equipment's own name out of a narrow pane. Capped in
      // plain logical pixels — the Font Scale setting scales the whole UI
      // from one root wrapper (docs/design/ui-scaling.md), so this must not
      // be multiplied by it.
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 190),
        child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: TextButton(
              onPressed: busy ? null : (connected ? onDisconnect : onConnect),
              child: Text(connected ? st.disconnect : st.connect, overflow: TextOverflow.ellipsis),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (choice) => switch (choice) {
              'remove' => onRemove(),
              'radio1' => onUseAsMainVfo(),
              _ => onEdit(),
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'edit', child: Text(st.edit)),
              if (canChooseRadio1) PopupMenuItem(value: 'radio1', child: Text(st.useAsMainVfo)),
              PopupMenuItem(value: 'remove', child: Text(st.remove)),
            ],
          ),
          ],
        ),
      ),
    );
  }

  /// Connected radios show what they're reporting; that live frequency is
  /// the only proof the whole chain works end to end.
  String _statusLabel(BuildContext context, EquipmentState state) {
    final st = context.t.settings.station;
    switch (state.status) {
      case EquipmentStatus.disconnected:
        return st.statusDisconnected;
      case EquipmentStatus.connecting:
        return st.statusConnecting;
      case EquipmentStatus.error:
        return state.error ?? st.statusDisconnected;
      case EquipmentStatus.connected:
        final vfo = state.vfo;
        if (vfo.freqKHz == null && vfo.mode == null) return st.statusConnected;
        return [
          if (vfo.freqKHz != null) fmtFreq(vfo.freqKHz!),
          if (vfo.mode != null) vfo.mode!,
        ].join('  ');
    }
  }

  Color? _statusColor(ThemeData theme, EquipmentStatus status) => switch (status) {
        EquipmentStatus.error => theme.colorScheme.error,
        EquipmentStatus.connected => theme.colorScheme.primary,
        _ => null,
      };
}

/// Marks the node whose VFO is the logging panel's — `radio1` in the data
/// model (docs/design/gato.md). Shaped like activities_view's
/// `_AlreadySelectedChip`: nothing pill-like is exported from halo_widgets,
/// and that chip says the same kind of thing — "this row is the designated
/// one". Plain logical pixels, since the Font Scale setting scales the whole
/// UI from one root wrapper (docs/design/ui-scaling.md).
class _MainVfoPill extends StatelessWidget {
  final String label;

  const _MainVfoPill({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSecondaryContainer),
      ),
    );
  }
}
