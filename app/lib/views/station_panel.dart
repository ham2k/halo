// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Station Configuration panel: the equipment the station is made of,
// and whether the app can currently talk to it (docs/design/cat.md).
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
import '../services/cat/discovery.dart';
import '../services/cat/equipment.dart';
import '../services/cat/equipment_registry.dart';
import '../services/cat/cat_service.dart';
import '../tools/form_chrome_labels.dart';

/// Shown as the HINT of a secret field whose value is already in the keychain,
/// never as its value: a hint cannot be submitted, cannot be revealed by the
/// field's show/hide eye, and leaves the field genuinely empty — which is what
/// CatService reads as "keep what is stored".
///
/// A fixed count, deliberately. Matching the real length would leak it.
const _storedSecretPlaceholder = '••••••••';

class StationPanel extends StatelessWidget {
  final HaLoServices services;

  const StationPanel({super.key, required this.services});

  CatService get _cat => services.cat;

  Future<void> _addEquipment(BuildContext context) async {
    // Only FlexRadio announces itself today, over a UDP broadcast the web
    // build's transport can't open — starting discovery there would just
    // bind a socket that never reports anything, and `_showAddDialog`
    // would spin its "searching" state forever for no reason.
    final canDiscover =
        _cat.registry.types.any((type) => type.discoverer != null && type.isSupportedOnThisPlatform);
    // Discovery holds a bound UDP socket, so it runs only while the dialog
    // that shows its results is open — and the socket has to be released
    // even if the dialog throws, or `isDiscovering` stays true and every
    // later Add silently reuses an orphaned subscription.
    if (canDiscover) _cat.startDiscovery();
    final _AddChoice? choice;
    try {
      choice = await _showAddDialog(context, showDiscovery: canDiscover);
    } finally {
      if (canDiscover) _cat.stopDiscovery();
    }
    if (choice == null || !context.mounted) return;

    if (choice.discovered != null) {
      // Already has everything it needs — no form to fill in.
      await _cat.addDiscovered(choice.discovered!);
      return;
    }

    final type = choice.type!;
    final values = await _editValues(context, type: type, name: '', config: type.defaultConfig);
    if (values == null) return;

    await _cat.addNode(typeKey: type.key, name: values.name, config: values.config);
  }

  Future<_AddChoice?> _showAddDialog(BuildContext context, {required bool showDiscovery}) {
    return showHaloDialog<_AddChoice>(
      context: context,
      builder: (context) => ListenableBuilder(
        listenable: _cat,
        builder: (context, _) {
          final st = context.t.settings.station;
          final found = _cat.discovered;
          final error = _cat.discoveryError;
          // A radio whose transport can't connect on this platform at all
          // (TCP, Icom network, on web) would only fail loudly once picked
          // — no point offering it.
          final manualTypes = _cat.registry.types.where((type) => type.isSupportedOnThisPlatform).toList();

          return HaloDialog(
            title: Text(st.addTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showDiscovery) ...[
                  // What announced itself, first: for a Flex this is the
                  // whole interaction — tap it and it's configured.
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
                          child:
                              Padding(padding: EdgeInsets.all(2), child: CircularProgressIndicator(strokeWidth: 2))),
                      title: _SearchingLabel(),
                    )
                  else ...[
                    SectionHeader(st.found),
                    for (final device in found)
                      ListTile(
                        leading: Icon(_iconForCategory(_cat.registry.typeFor(device.typeKey)?.category)),
                        title: Text(device.name),
                        subtitle: device.detail == null ? null : Text(device.detail!),
                        onTap: () => Navigator.of(context).pop(_AddChoice.discovered(device)),
                        mouseCursor: SystemMouseCursors.click,
                      ),
                  ],
                  const Divider(),
                ],
                // A radio on another subnet, or behind a router that doesn't
                // forward broadcasts, never announces — the manual path must
                // always be offered.
                SectionHeader(st.addManually),
                for (final type in manualTypes)
                  ListTile(
                    leading: Icon(_iconForCategory(type.category)),
                    title: Text(type.name),
                    // Which drivers have actually been run against the real
                    // hardware, rather than presenting them all as equal.
                    subtitle: type.hardwareVerified ? null : Text(st.unverified),
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
    final type = _cat.typeFor(node);
    if (type == null) return;

    final values = await _editValues(context, type: type, name: node.name, config: node.config, node: node);
    // Null also means the editor removed the node, or was cancelled — either
    // way there is nothing left to write back.
    if (values == null) return;

    await _cat.updateNode(node.copyWith(name: values.name, config: values.config));
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

    // Which secrets already exist — the keys only; the values stay in the
    // keychain and never enter this form. A stored password otherwise renders
    // as an empty box that looks like nothing was ever saved, and the obvious
    // fix (prefill it) is the one thing we must not do: the form's values are
    // written back on save, and a revealed secret field would show it.
    // A placeholder says "something is here" and costs nothing, because an
    // untouched field still submits empty, which CatService reads as
    // "unchanged".
    final storedSecrets = node == null ? const <String>{} : await _cat.storedSecretFields(node.uuid);
    if (!context.mounted) return null;

    // No-op for every transport except the web serial one, which uses this
    // to fetch and cache navigator.serial's already-granted device list
    // before configElements() (synchronous, so it can't await this itself)
    // reads it.
    await type.transport.prepareConfigElements();
    if (!context.mounted) return null;

    // Reused whenever an action changes what's available to pick (a newly
    // granted USB device, say) — configElements() reflects the transport's
    // CURRENT state each time it's called, so rebuilding from it is enough;
    // nothing here needs to know what specifically changed.
    List<Map<String, dynamic>> buildElements() => [
          {
            'type': 'field',
            'fieldType': 'text',
            'key': 'name',
            'label': st.name,
            'description': st.nameDescription,
          },
          for (final element in type.configElements())
            if (storedSecrets.contains(element['key'])) {...element, 'placeholder': _storedSecretPlaceholder} else element,
        ];

    final result = await showFormPane(
      context,
      formDefinition: {'title': type.name, 'elements': buildElements()},
      initialState: {'name': name, ...config},
      // Runs per field on submit, so a bad address blocks the save and says
      // so on the address field rather than failing later at connect time.
      validator: (key, value, values) async => type.validateField(key, value, values),
      // A transport's own action — the web serial transport's "add a USB
      // device" option, so far, living inside the port field's own list —
      // CatService's layer speaks its own EquipmentActionResult rather
      // than importing halo_widgets, so this is the one place that
      // translates.
      onAction: (actionKey, method, state) async {
        final actionResult = await type.runAction(actionKey, method, state);
        if (actionResult == null) return null;
        return FormActionResult(
          message: actionResult.message,
          fieldUpdates: actionResult.fieldUpdates,
          // A field changing might mean something newly exists to pick —
          // the granted device isn't in the ORIGINAL options at all, so
          // its own field alone isn't enough to make it selectable.
          elements: actionResult.fieldUpdates == null ? null : buildElements(),
        );
      },
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
    await _cat.removeNode(node.uuid);
  }

  String _displayName(EquipmentNode node) {
    if (node.name.isNotEmpty) return node.name;
    return _cat.typeFor(node)?.name ?? node.typeKey;
  }

  @override
  Widget build(BuildContext context) {
    final st = context.t.settings.station;

    return ListenableBuilder(
      listenable: _cat,
      builder: (context, _) {
        final safeLeft = PaneSafeArea.leftOf(context);
        final nodes = _cat.nodes;
        // Every transceiver the station knows about, connected or not —
        // this is the station's configuration, not its current link state.
        final transceivers = [
          for (final node in nodes)
            if (_cat.typeFor(node)?.category == kCategoryTransceiver) node,
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
                // shows whatever radio1 was on first build. CatService
                // reassigns it behind this panel's back — auto-designating
                // the first transceiver added, and re-designating when the
                // current one is removed — and neither would have appeared.
                key: ValueKey(_cat.radio1),
                initialValue: transceivers.any((n) => n.uuid == _cat.radio1) ? _cat.radio1 : null,
                decoration: poloFieldDecoration(context, st.transceiverForMainVfo),
                menuMaxHeight: dropdownMenuMaxHeight(context),
                items: [
                  DropdownMenuItem<String?>(value: null, child: Text(st.noTransceiver)),
                  for (final radio in transceivers)
                    DropdownMenuItem<String?>(value: radio.uuid, child: Text(_displayName(radio))),
                ],
                onChanged: (uuid) => unawaited(_cat.setRadio1(uuid)),
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
                type: _cat.typeFor(node),
                state: _cat.stateFor(node.uuid),
                displayName: _displayName(node),
                isMainVfo: _cat.isRadio1(node.uuid),
                onEdit: () => _editEquipment(context, node),
                onRemoveUnknown: () => _removeEquipment(context, node),
                onConnect: () => _cat.connect(node.uuid),
                onDisconnect: () => _cat.disconnect(node.uuid),
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

    // Both directions take time and both deserve the spinner: connecting
    // negotiates a handshake, disconnecting sends a goodbye that must not be
    // rushed.
    final busy = state.status == EquipmentStatus.connecting ||
        state.status == EquipmentStatus.disconnecting;
    final vfo = state.vfo;
    final reading = [
      if (vfo.freqKHz != null) fmtFreq(vfo.freqKHz!),
      if (vfo.mode != null) vfo.mode!,
    ].join('  ');
    final connected = state.status == EquipmentStatus.connected;

    final failed = state.status == EquipmentStatus.error && state.error != null;

    // Two lines. The top one is identity — what it is, then where it is.
    // The bottom is what it is doing, EXCEPT when something went wrong, in
    // which case the reason takes the whole row: an explanation squeezed
    // into half a line and ellipsized is not an explanation.
    //
    // Both rows split with spaceBetween rather than a Spacer or a trailing
    // Expanded: a flex child that uses LESS than its share leaves the slack
    // at the END of the row, which keeps the right-hand items from reaching
    // the edge.
    return ListTile(
      leading: Icon(_iconForCategory(resolvedType.category)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 3:2 — identity earns more of the row than the address does, and
          // a pill is a fixed-width thing competing with a name that can
          // ellipsize, so the split has to favour this side.
          Flexible(
            flex: 3,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Text(displayName, overflow: TextOverflow.ellipsis)),
                // Beside the name: which radio drives the logging panel is
                // part of what this equipment IS, not what it is doing.
                if (isMainVfo) ...[
                  const SizedBox(width: 8),
                  // Flexible, because the pill has an intrinsic width and a
                  // non-flex child in a bounded Row overflows rather than
                  // shrinking — the name collapses to nothing and the row
                  // still blows past the edge by whatever the pill needed.
                  Flexible(
                    child: _Pill(
                      label: st.mainVfo,
                      background: theme.colorScheme.secondaryContainer,
                      foreground: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Flexible(
            flex: 2,
            child: Padding(
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
      subtitle: failed
          ? Text(
              state.error!,
              // Two lines' worth: these say what to do about it, and the
              // useful part is rarely in the first forty characters.
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    reading,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      // Dimmed once it is no longer being confirmed. The
                      // number is the last thing the radio actually said,
                      // and how old it is matters as much as what it is.
                      color: state.stale
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (connected)
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: _Pill(
                      // A link that is up but silent must not wear the same
                      // confident green as one that is working: the
                      // frequency shown may be minutes old.
                      label: state.stale ? st.statusStale : st.statusConnected,
                      background: state.stale ? theme.colorScheme.error : _connectedGreen(theme),
                      foreground: Colors.white,
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
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: foreground),
      ),
    );
  }
}

/// The plug: pulled out (grey) or pushed in (green). Pressing it does the
/// other thing. A glyph rather than a "Not connected" label plus a Connect
/// button — two localized words' worth of row width to say what one glyph
/// says, on a row whose whole point is to show a live frequency.
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
