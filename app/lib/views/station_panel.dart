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

import 'dart:async';

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

    final values = await _editValues(context, type: type, name: node.name, config: node.config, node: node);
    // Null also means the editor removed the node, or was cancelled — either
    // way there is nothing left to write back.
    if (values == null) return;

    await _gato.updateNode(node.copyWith(name: values.name, config: values.config));
  }

  /// The name field plus whatever the type asks for, in one form.
  /// [node] is null when adding: the actions below act on equipment that
  /// already exists, so they only appear once it does.
  Future<({String name, Map<String, dynamic> config})?> _editValues(
    BuildContext context, {
    required EquipmentType type,
    required String name,
    required Map<String, dynamic> config,
    EquipmentNode? node,
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
      // Only when the equipment already exists — there is nothing to delete
      // from the Add flow. Closes the editor before confirming: the question
      // is about the equipment, not about this form's unsaved edits, and
      // leaving the pane behind it would offer to Save a node about to be
      // gone.
      destructiveAction: node == null
          ? null
          : (
              label: st.remove,
              color: Theme.of(context).colorScheme.error,
              // showFormPane closes the pane before calling this, so all
              // that is left here is the confirmation.
              onPressed: () => unawaited(_removeEquipment(context, node)),
            ),
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
        // Every transceiver the station knows about, connected or not —
        // this is the station's configuration, not its current link state.
        final transceivers = [
          for (final node in nodes)
            if (_gato.typeFor(node)?.category == kCategoryTransceiver) node,
        ];

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          children: [
            // What the station IS right now: the choices that decide how the
            // rest of the app behaves. Today that is one question.
            Padding(
              padding: EdgeInsets.only(left: safeLeft),
              child: SectionHeader(st.currentConfiguration),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(safeLeft + 16, 8, 16, 8),
              child: DropdownButtonFormField<String?>(
                // FormFieldState reads `initialValue` once and never again
                // (its didUpdateWidget only handles forceErrorText), so
                // without a key that changes with the value this dropdown
                // shows whatever radio1 was on first build. GatoService
                // reassigns it behind this panel's back — auto-designating
                // the first transceiver added, and re-designating when the
                // current one is removed — and neither would have appeared.
                key: ValueKey(_gato.radio1),
                initialValue: transceivers.any((n) => n.uuid == _gato.radio1) ? _gato.radio1 : null,
                decoration: poloFieldDecoration(context, st.transceiverForMainVfo),
                menuMaxHeight: dropdownMenuMaxHeight(context),
                items: [
                  DropdownMenuItem<String?>(value: null, child: Text(st.noTransceiver)),
                  for (final radio in transceivers)
                    DropdownMenuItem<String?>(value: radio.uuid, child: Text(_displayName(radio))),
                ],
                onChanged: (uuid) => unawaited(_gato.setRadio1(uuid)),
              ),
            ),

            // What the station is made OF. Every piece of equipment, whatever
            // its category and whether or not it is in use.
            Padding(
              padding: EdgeInsets.only(left: safeLeft),
              child: SectionHeader(st.equipmentInventory),
            ),
            if (nodes.isEmpty) ListTile(title: Text(st.none)),
            for (final node in nodes)
              _EquipmentTile(
                node: node,
                type: _gato.typeFor(node),
                state: _gato.stateFor(node.uuid),
                displayName: _displayName(node),
                isMainVfo: _gato.isRadio1(node.uuid),
                onEdit: () => _editEquipment(context, node),
                onRemoveUnknown: () => _removeEquipment(context, node),
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
  final VoidCallback onEdit;

  /// Only reachable for a record whose type isn't in the catalogue — every
  /// other row removes from inside the editor.
  final VoidCallback onRemoveUnknown;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  const _EquipmentTile({
    required this.node,
    required this.type,
    required this.state,
    required this.displayName,
    required this.isMainVfo,
    required this.onEdit,
    required this.onRemoveUnknown,
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
        // An unrecognized type has no editor to put Remove inside, so this
        // row keeps its own — it is the only way to get rid of the record.
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, semanticLabel: st.remove),
          onPressed: onRemoveUnknown,
        ),
      );
    }

    final busy = state.status == EquipmentStatus.connecting;
    final vfo = state.vfo;
    final reading = [
      if (vfo.freqKHz != null) fmtFreq(vfo.freqKHz!),
      if (vfo.mode != null) vfo.mode!,
    ].join('  ');
    final connected = state.status == EquipmentStatus.connected;

    // Two lines, each split left/right:
    //   1. what it is          ...  where it is
    //   2. what it is hearing  ...  how it is doing
    //
    // Both rows use spaceBetween rather than a Spacer or a trailing
    // Expanded. A flex child that uses LESS than its share leaves the slack
    // at the END of the row, so the right-hand item stops short of the edge
    // — which is exactly how the address and the Connected pill ended up
    // not quite right-aligned. spaceBetween puts that slack between the two
    // groups instead, which is where it belongs.
    return ListTile(
      leading: Icon(_iconForCategory(resolvedType.category)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: Text(displayName, overflow: TextOverflow.ellipsis)),
          Flexible(
            child: Padding(
              // A minimum gap, as a pad rather than a sibling SizedBox —
              // spaceBetween would treat a third child as another gap.
              padding: const EdgeInsets.only(left: 12),
              child: Text(
                resolvedType.describeTarget(node.config),
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ),
        ],
      ),
      subtitle: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: what the radio is doing, and whether it drives the panel.
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (reading.isNotEmpty)
                  Flexible(
                    child: Text(
                      reading,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (isMainVfo) ...[
                  if (reading.isNotEmpty) const SizedBox(width: 8),
                  _Pill(
                    label: st.mainVfo,
                    background: theme.colorScheme.secondaryContainer,
                    foreground: theme.colorScheme.onSecondaryContainer,
                  ),
                ],
              ],
            ),
          ),
          // Right: status. An error explains itself; otherwise the green
          // pill is the whole message.
          Flexible(
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Align(
                alignment: Alignment.centerRight,
                child: state.status == EquipmentStatus.error && state.error != null
                    ? Text(
                        state.error!,
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                      )
                    : connected
                        ? _Pill(
                            label: st.statusConnected,
                            background: _connectedGreen(theme),
                            foreground: Colors.white,
                          )
                        : const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
      trailing: _ConnectionToggle(
        busy: busy,
        connected: connected,
        onConnect: onConnect,
        onDisconnect: onDisconnect,
      ),
      onTap: onEdit,
      mouseCursor: SystemMouseCursors.click,
    );
  }
}

/// One green that reads on both a light and a dark surface. Spelled out
/// because the scheme has no semantic "success" colour, and `primary` is the
/// app's accent — it says nothing about being connected.
Color _connectedGreen(ThemeData theme) =>
    theme.brightness == Brightness.dark ? Colors.green.shade600 : Colors.green.shade700;

/// A small rounded label. Same shape as activities_view's
/// `_AlreadySelectedChip` — nothing pill-like is exported from halo_widgets,
/// and that chip says the same kind of thing about a row. Plain logical
/// pixels: the Font Scale setting scales the whole UI from one root wrapper
/// (docs/design/ui-scaling.md).
class _Pill extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;

  const _Pill({required this.label, required this.background, required this.foreground});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(10)),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: foreground),
      ),
    );
  }
}

/// The plug: pulled out (grey) or pushed in (green). Pressing it does the
/// other thing. This replaced a "Not connected" label plus a Connect button
/// — two localized words' worth of row width to say what one glyph says,
/// on a row whose whole point is to show a live frequency.
class _ConnectionToggle extends StatelessWidget {
  final bool busy;
  final bool connected;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  const _ConnectionToggle({
    required this.busy,
    required this.connected,
    required this.onConnect,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    final st = context.t.settings.station;
    final theme = Theme.of(context);

    if (busy) {
      return const SizedBox(
        width: 48,
        height: 48,
        child: Padding(padding: EdgeInsets.all(14), child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    // No semantic "success" colour in the scheme, so it is spelled out here
    // rather than borrowed from `primary` (which is the app's accent and
    // says nothing about being connected). Two shades because one green
    // cannot carry both a light and a dark surface.
    return IconButton(
      icon: Icon(
        connected ? MdiIcons.powerPlug : MdiIcons.powerPlugOff,
        // The app has no hover tooltips, so the accessible name is the only
        // place this control is named.
        semanticLabel: connected ? st.disconnect : st.connect,
        color: connected ? _connectedGreen(theme) : theme.colorScheme.onSurfaceVariant,
      ),
      onPressed: connected ? onDisconnect : onConnect,
    );
  }
}
