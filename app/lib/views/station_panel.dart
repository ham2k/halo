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
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'package:halo_i18n/halo_i18n.dart';
import '../services/halo_services.dart';
import 'add_equipment_dialog.dart';
import 'equipment_glyphs.dart';
import '../services/cat/equipment.dart';
import '../services/cat/telemetry_poller.dart';
import '../services/cat/drivers/antenna_genius_driver.dart';
import '../services/cat/equipment_registry.dart';
import '../services/cat/cat_service.dart';
import '../services/peer/peer_remote_radios.dart';
import '../services/peer/peer_station_radios.dart';
import '../services/settings_service.dart';
import 'cw_messages_dialog.dart';
import 'voice_messages_dialog.dart';
import 'equipment_report.dart';
import 'station_rows.dart';
import 'settings_view.dart' show settingsGroupRows;
import '../settings/core_settings_groups.dart' show moreStationSettingsKey, stationConfigurationSectionKey;

part 'station_panel_annotations.dart';

/// Shown as the HINT of a secret field whose value is already in the keychain,
/// never as its value: a hint cannot be submitted, cannot be revealed by the
/// field's show/hide eye, and leaves the field genuinely empty — which is what
/// CatService reads as "keep what is stored".
///
/// A fixed count, deliberately. Matching the real length would leak it.
const _storedSecretPlaceholder = '••••••••';

/// The equipment editor's Advanced Settings fold: every field a transport or
/// driver marks `'advanced': true` folds under it.
const _advancedDisclosureKey = 'advanced';

/// The inset the rows of this panel take: the ambient `ListTileTheme`, which
/// in the settings pane is the `SettingsList` one plus the pane's centring
/// offset, and which every `ListTile`, [SectionHeader] and [FormRenderer] row
/// here already reads for itself.
///
/// The hand-built rows below have to ask for it: one that names a spacing
/// rung instead spans the whole pane while the list rows above and below it
/// are centred in it.
///
/// Both hosts publish one — the Settings pane, and the compact dialog's
/// `SettingsList`. With none published it takes none, as [SectionHeader] and
/// [CategoryBand] do (docs/design/user-interface.md § Settings lists).
EdgeInsets _rowInset(BuildContext context) => (ListTileTheme.of(context).contentPadding ?? EdgeInsets.zero).resolve(Directionality.of(context));

/// What a piece of equipment is doing, in the panel's own vocabulary — shared
/// so the status bar's line and the panel's pill cannot come to word the same
/// state differently.
String equipmentStatusLabel(BuildContext context, EquipmentState state) {
  final st = context.t.settings.station;
  return switch (state.status) {
    // Connected but silent is not the same as connected: the reading on
    // screen may be minutes old, which is the whole point of the panel's
    // own two-colour pill.
    EquipmentStatus.connected => state.stale ? st.statusStale : st.statusConnected,
    EquipmentStatus.connecting => st.statusConnecting,
    EquipmentStatus.disconnecting => st.statusDisconnecting,
    EquipmentStatus.error => st.statusError,
    EquipmentStatus.disconnected => st.statusDisconnected,
  };
}

class StationPanel extends StatelessWidget {
  final HaLoServices services;

  /// The Radio control's quick-access dialog, as opposed to the full page
  /// under Settings: current configuration only, the inventory row for
  /// whichever rig is designated (not the whole catalogue), a Power field,
  /// and a footer offering the full page instead of Add Equipment/Other
  /// Options inline.
  final bool compact;

  /// Compact mode's way to the full page — required exactly when [compact]
  /// is true. A callback rather than a hardcoded `SettingsView` push, so the
  /// presenter decides how the page opens (station_config_dialog.dart closes
  /// its pane first).
  final VoidCallback? onMoreSettings;

  const StationPanel({super.key, required this.services, this.compact = false, this.onMoreSettings})
    : assert(!compact || onMoreSettings != null, 'compact mode needs onMoreSettings');

  CatService get _cat => services.cat;

  Future<void> _addEquipment(BuildContext context) async {
    // Only FlexRadio announces itself today, over a UDP broadcast the web
    // build's transport can't open — starting discovery there would just
    // bind a socket that never reports anything, and `_showAddDialog`
    // would spin its "searching" state forever for no reason.
    final canDiscover = _cat.registry.types.any((type) => type.discoverer != null && type.isSupportedOnThisPlatform);
    // Discovery holds a bound UDP socket, so it runs only while the dialog
    // that shows its results is open — and the socket has to be released
    // even if the dialog throws, or `isDiscovering` stays true and every
    // later Add silently reuses an orphaned subscription.
    if (canDiscover) _cat.startDiscovery();
    final AddChoice? choice;
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

    // A pane row that reports rather than offers (AddChoice.none) never pops
    // with itself, so this cannot fire today — but the type admits it, and a
    // bare `!` here would be a crash the day a new inert row forgets to
    // disable its own tap.
    final model = choice.model;
    if (model == null) return;
    final variants = _supportedVariants(model);
    if (variants.isEmpty) return;
    final values = await _editValues(
      context,
      model: model,
      type: variants.first,
      // Prefilled rather than left blank, and editable: the operator sees
      // what it will be called before agreeing to it. addNode computes the
      // same suggestion again if they clear the field, since this one is
      // already stale by the time they submit.
      name: _cat.suggestedNameFor(variants.first.key),
      config: const {},
    );
    if (values == null) return;

    await _cat.addNode(typeKey: values.typeKey, name: values.name, config: values.config);
  }

  /// A Modal Pane, not a dialog card: the catalogue is a long list under
  /// pinned brand headers, and a header only earns its pin against the full
  /// height a pane gives it. `scrollable: false` because the pane scrolls
  /// nothing itself — the dialog's two flex regions manage their own.
  ///
  /// No "Done" button: a pane carries its own dismissal in the header, and
  /// there is never a choice to discard — every row here either pops with a
  /// pick or adds nothing.
  Future<AddChoice?> _showAddDialog(BuildContext context, {required bool showDiscovery}) {
    return showModalPane<AddChoice>(
      context,
      title: context.t.settings.station.addTitle,
      scrollable: false,
      // Full height, always: the catalogue changes size as the operator works
      // it — a shelf folds open, a query narrows the list — and a card that
      // resized with it would walk every row under the pointer between one
      // keystroke and the next.
      fillHeight: true,
      closeLabel: context.t.common.done,
      builder: (context) => AddEquipmentDialog(
        cat: _cat,
        showDiscovery: showDiscovery,
        showAntennaAndKey: services.settings.trackStationInfo && services.settings.stationInfoTrackedFields.any((f) => f == 'antenna' || f == 'key'),
        showKeyer: services.settings.experimentEnabled('keyer') /* stored key, see experiments.yaml */,
        showSdr: services.settings.experimentEnabled('fall') /* stored key, see experiments.yaml */,
        supportedVariants: _supportedVariants,
      ),
    );
  }

  /// The inventory cut into its sections, in the order they are listed.
  ///
  /// Everything that is not a radio or an antenna shares the last one:
  /// keys, keyers and antenna switches are each one or two nodes in a shack,
  /// and a heading apiece would be more heading than list.
  List<({String title, String category, List<EquipmentNode> nodes})> _inventorySections(BuildContext context, List<EquipmentNode> nodes) {
    final st = context.t.settings.station;
    List<EquipmentNode> inCategory(bool Function(String?) matches) => [
      for (final node in nodes)
        if (matches(_cat.typeFor(node)?.category)) node,
    ];

    final transceivers = inCategory((category) => category == kCategoryTransceiver);
    final antennas = inCategory((category) => category == kCategoryAntenna);
    final other = inCategory((category) => category != kCategoryTransceiver && category != kCategoryAntenna);
    // Peers' radios count as Transceivers rows. That section always shows;
    // the others only when they have something in them.
    final radios = transceivers.length + services.peerRemoteRadios.all.length;
    return [
      (title: st.sectionTransceivers(count: radios), category: kCategoryTransceiver, nodes: transceivers),
      if (antennas.isNotEmpty) (title: st.sectionAntennas(count: antennas.length), category: kCategoryAntenna, nodes: antennas),
      if (other.isNotEmpty) (title: st.sectionOtherEquipment(count: other.length), category: '', nodes: other),
    ];
  }

  /// See [EquipmentRegistry.offeredVariants].
  List<EquipmentType> _supportedVariants(EquipmentModel model, {EquipmentType? current}) => _cat.registry.offeredVariants(
    model,
    tx500Experiment: services.settings.experimentEnabled('500mp') /* stored key, see experiments.yaml */,
    current: current,
  );

  Future<void> _editEquipment(BuildContext context, EquipmentNode node) async {
    final type = _cat.typeFor(node);
    if (type == null) return;

    final values = await _editValues(context, model: type.model, type: type, name: node.name, config: node.config, node: node);
    // Null also means the editor removed the node, or was cancelled — either
    // way there is nothing left to write back.
    if (values == null) return;

    await _cat.updateNode(node.copyWith(typeKey: values.typeKey, name: values.name, config: values.config));
  }

  /// The name field, how the radio is connected, and whatever that choice
  /// asks for, in one form. [node] is null when adding: the actions below act
  /// on equipment that already exists, so they only appear once it does.
  ///
  /// Every supported pairing's fields are rendered at once and narrowed with
  /// `visibleWhen`, rather than the form being rebuilt per transport. That is
  /// FormRenderer's own mechanism and it carries one contract with it (see
  /// its `_visibleElements` doc): a hidden field is still registered, still
  /// holds its value, and is still passed to the validator on submit. So
  /// everything below resolves the pairing from the `transport` value first
  /// and asks only that one — otherwise a serial port left over from a
  /// transport the operator switched away from would block the save.
  ///
  /// The upside of that same contract is what makes it worth it: switching
  /// transport and back keeps what was typed, with no state to thread.
  Future<({String typeKey, String name, Map<String, dynamic> config})?> _editValues(
    BuildContext context, {
    required EquipmentModel model,
    required EquipmentType type,
    required String name,
    required Map<String, dynamic> config,
    EquipmentNode? node,
  }) async {
    final st = context.t.settings.station;
    final variants = _supportedVariants(model, current: node == null ? null : type);
    // A model with one way in asks no question — the form is exactly what it
    // was before transports were selectable.
    final choosable = variants.length > 1;

    /// Which pairing the form is currently describing. Falls back to the one
    /// it opened on, so a missing or stale `transport` value can never leave
    /// this without a type to validate against.
    EquipmentType typeForState(Map<String, dynamic> state) {
      for (final candidate in variants) {
        if (candidate.transportKey == state['transport']) return candidate;
      }
      return type;
    }

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

    // Device lists are asynchronous, while configElements is synchronous.
    // Every offered pairing renders, so prepare all of their choices.
    Future<void> prepareVariants() async {
      for (final candidate in variants) {
        await candidate.transport.prepareConfigElements();
        await candidate.driver.prepareConfigElements();
      }
    }

    await prepareVariants();
    if (!context.mounted) return null;

    // Reused whenever an action changes what's available to pick (a newly
    // granted USB device, say) — configElements() reflects the transport's
    // CURRENT state each time it's called, so rebuilding from it is enough;
    // nothing here needs to know what specifically changed.
    List<Map<String, dynamic>> buildElements() {
      final connection = [
        for (final candidate in variants)
          for (final element in _annotateChannels(candidate, node, context))
            // The switch's layout field is re-emitted under Wiring below,
            // where it belongs with the antenna links. Left here too it
            // would render twice, and FormRenderer would bind both boxes
            // to the one value.
            if (element['key'] != switchLayoutConfigKey)
              {
                ...element,
                if (storedSecrets.contains(element['key'])) 'placeholder': _storedSecretPlaceholder,
                // What a BLANK cadence field actually does, in the box where
                // the operator would otherwise assume 200. Per candidate, so
                // the serial pairing shows the number its baud rate can
                // afford and the network one beside it shows its own — the
                // whole reason the field is left blank by default is that
                // the answer is not the same on both.
                if (element['key'] == telemetryIntervalConfigKey)
                  // Through the TYPE, so the entry's own overrides and
                  // prefills are part of the question — the same reason
                  // telemetryMetersFor exists. Handed the node's raw stored
                  // map instead, a radio whose speed comes from its entry
                  // rather than from a box the operator touched computes as
                  // though the link had no stated speed at all.
                  'placeholder': '${candidate.defaultTelemetryIntervalFor(node?.config ?? const {}).inMilliseconds}',
                // Only when there is a choice to hide behind: an unconditional
                // visibleWhen on a single-transport radio would depend on a
                // `transport` value no field sets.
                if (choosable) 'visibleWhen': {'field': 'transport', 'equals': candidate.transportKey},
              },
      ];
      // A pairing's troubleshooting notes (every note is collapsible
      // markdown, a registry test holds that): read only when something is
      // wrong, so they close the form rather than sit between the fields.
      bool isNote(Map<String, dynamic> element) => element['type'] == 'markdown' && element['collapsible'] == true;
      bool isAdvanced(Map<String, dynamic> element) => element['advanced'] == true && !isNote(element);
      return [
        {'type': 'field', 'fieldType': 'text', 'key': 'name', 'label': st.name, 'description': st.nameDescription},
        if (choosable)
          {
            'type': 'field',
            'fieldType': 'segmented',
            'key': 'transport',
            'label': st.transport,
            'options': [
              for (final candidate in variants) {'value': candidate.transportKey, 'label': candidate.transportLabel},
            ],
          },
        ...connection.where((element) => !isAdvanced(element) && !isNote(element)),
        // Everything most operators never touch — the serial lines, the
        // poll and meter cadences — folded away after what they do, closed
        // until asked for. FormRenderer hides the fold whenever the chosen
        // pairing has nothing in it.
        {'type': 'disclosure', 'key': _advancedDisclosureKey, 'title': st.advancedSettings, 'elements': connection.where(isAdvanced).toList()},
        // Which of the operator's own enabled bands (Preferences → Bands)
        // this antenna covers. Lives here rather than in AntennaDriver's
        // own configElements(): a driver is pure data with no settings
        // access, and this list is exactly the operator's, not the
        // catalogue's.
        if (model.category == kCategoryAntenna)
          {
            'type': 'field',
            'fieldType': 'checkboxGroup',
            'key': 'bands',
            'label': st.antennaBands,
            'options': [
              for (final band in services.settings.enabledBands) {'value': band, 'label': band},
            ],
          },
        // Which of the operator's own antennas is on each of the switch's
        // antenna ports. Here rather than in the driver's own
        // configElements() for exactly the reason the antenna bands above
        // are: a driver is pure catalogue data with no access to the
        // station's inventory, and this list is the operator's equipment,
        // not the switch's.
        // What the switch is doing now, before how it is set up: an
        // operator opening this dialog mid-operation is looking for the
        // former, and the latter is answered once and rarely revisited.
        if (model.category == kCategoryAntennaSwitch) ...[..._switchCurrentState(context, node), ..._switchWiring(context, type, node)],
        // Which radio this receiver shows the spectrum for. Here rather than
        // in the driver for the antenna bands' reason: the choices are the
        // station's own radios, which a driver cannot see.
        if (model.category == kCategorySdr)
          {
            'type': 'field',
            'fieldType': 'select',
            'key': sdrRadioConfigKey,
            'label': st.sdrRadio,
            'description': st.sdrRadioDescription,
            'options': [
              {'value': sdrRadioMain, 'label': st.sdrRadioMain},
              for (final candidate in _cat.nodes)
                if (_cat.typeFor(candidate)?.category == kCategoryTransceiver) {'value': candidate.uuid, 'label': _displayName(candidate)},
            ],
          },
        ...connection.where(isNote),
      ];
    }

    final result = await showFormPane(
      context,
      // The radio, not the pairing: how it is connected is a field inside the
      // form now, so putting it in the title too would contradict itself the
      // moment the operator changed it.
      formDefinition: {'title': model.name, 'elements': buildElements()},
      // The simulator knobs and the generic entries' keyer fields are
      // `devMode` elements: without this they never render, whatever the
      // setting says.
      developerMode: services.settings.developerMode,
      // Seeding every pairing up front is what makes switching transport
      // arrive at sensible defaults with no onChange plumbing — the fields of
      // a transport not currently chosen are inert until it is.
      initialState: {
        'name': name,
        // Every offered pairing's prefill, then the SELECTED one's on top:
        // two variants can name the same key, and the one the form actually
        // opens on is the one whose value belongs in the box. (A registry
        // self-check forbids them disagreeing at all, so this only decides
        // the order in which identical values land — it is the guard that
        // makes the merge safe, and this makes it correct anyway.)
        for (final candidate in variants) ...candidate.defaultConfig,
        ...type.defaultConfig,
        ...config,
        if (choosable) 'transport': type.transportKey,
        // Where each device port is pointing right now — live state, seeded
        // so the pickers open on the truth rather than blank. Last, so a key
        // collision could never let a stored value stand in for what the
        // switch just said.
        if (node != null)
          for (final port in _cat.stateFor(node.uuid).switchPorts) switchPortRoutingFormKey(port.key): ?port.selectedAntennaKey,
      },
      // Runs per field on submit, so a bad address blocks the save and says
      // so on the address field rather than failing later at connect time.
      // Asks the pairing the form is currently on: a field belonging to a
      // transport the operator switched away from is not theirs to get right.
      validator: (key, value, values) async => isSwitchPortRoutingFormKey(key) ? null : typeForState(values).validateEditorField(key, value, values),
      // A pairing's own field gets the companions its transport sets beside
      // it (a Bluetooth LE device's name). Routing a port is the one field
      // kind that acts as it is touched rather than on save: it is a command
      // to the switch, and an operator who cancels the pane has still moved
      // the relay. Returning no updates leaves the form's own value where the
      // operator put it; the switch's confirmation lands in the panel behind.
      onChange: (key, value, values) async {
        if (!isSwitchPortRoutingFormKey(key)) return typeForState(values).fieldChanged(key, value);
        if (node == null) return null;
        if (value is! String || value.isEmpty) return null;
        for (final port in _cat.stateFor(node.uuid).switchPorts) {
          if (switchPortRoutingFormKey(port.key) == key) _cat.selectAntenna(node.uuid, port.key, value);
        }
        return null;
      },
      // A transport's own action — the web serial transport's "add a USB
      // device" option, so far, living inside the port field's own list —
      // CatService's layer speaks its own EquipmentActionResult rather
      // than importing halo_widgets, so this is the one place that
      // translates.
      onAction: (actionKey, method, state) async {
        final actionResult = await typeForState(state).runAction(actionKey, method, state);
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
              icon: MdiIcons.trashCanOutline,
              // showFormPane closes the pane before calling this, so all
              // that is left here is the confirmation.
              onPressed: () => unawaited(_removeEquipment(context, node)),
            ),
      // Same condition as Remove, for the same reason: a radio being added
      // for the first time has never been talked to, so there is nothing yet
      // to say about whether it worked.
      //
      // Unlike Remove this does NOT close the editor — the report opens over
      // it (see showFormPane's secondaryAction), so an operator who reports a
      // radio finds their unsaved edits where they left them.
      secondaryAction: node == null
          ? null
          : (
              label: st.report,
              onPressed: () => unawaited(showEquipmentReportDialog(context, services: services, node: node, type: type, state: _cat.stateFor(node.uuid))),
            ),
      // A USB cable plugged in while this pane is open should show up in the
      // port picker without closing and reopening the editor — that pause,
      // with the cable in hand, is exactly when the operator is looking at
      // this form. Every transport gets re-prepared and the whole element
      // list rebuilt, because the transport's own state is what
      // configElements() reads; showFormPane republishes only when the
      // result actually differs, so an untouched machine costs one
      // enumeration and no rebuild.
      refreshElements: (
        every: const Duration(seconds: 3),
        build: () async {
          await prepareVariants();
          return buildElements();
        },
      ),
      // Cancel/Save/Close and the rest of the pane's chrome. Without this
      // the form's own fields are translated and the buttons around them
      // are not.
    );
    if (result == null) return null;

    return (
      typeKey: typeForState(result).key,
      name: (result['name'] as String? ?? '').trim(),
      // `transport` is the form's own discriminator, not a setting any
      // transport or driver reads — it leaves with the typeKey it chose.
      // Everything else stays, including fields belonging to a transport not
      // currently selected: switching back has to find them still there, and
      // `targetFor` narrows to what the connection actually needs anyway.
      // Merged over what was stored, not rebuilt from the form alone.
      // FormRenderer seeds its values from DECLARED FIELDS only, so a stored
      // key the form did not render is absent from `result` — and a wholesale
      // replace deletes it. That is reachable: an operator maps antennas to
      // all eight ports while the switch is disconnected, connects, and the
      // switch reports five of them as unwired, so those five link fields
      // stop rendering and Save silently drops the mapping.
      //
      // This is NOT the same as a field belonging to an unselected transport,
      // which the editor deliberately keeps: those DO render, hidden by
      // `visibleWhen`, so they are in `result` already.
      config: {
        // Under the stored values and the form's: a `devMode` field is not
        // rendered without developer mode, so it is absent from `result` —
        // and a key a validator requires (the placeholder's numbers) would
        // then be missing from a node added without it, which never connects.
        ...typeForState(result).defaultConfig,
        ...config,
        for (final entry in result.entries)
          // The routing pickers are the switch's live state, not settings.
          // Storing one would put a stale claim about a relay into the
          // record, and the panel would then have two answers to which
          // antenna is live.
          if (entry.key != 'name' && entry.key != 'transport' && !isSwitchPortRoutingFormKey(entry.key)) entry.key: entry.value,
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
        cancel: TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(context.t.common.cancel)),
        actions: [FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(st.remove))],
      ),
    );
    if (confirmed != true) return;
    await _cat.removeNode(node.uuid);
  }

  String _displayName(EquipmentNode node) => _cat.displayNameFor(node);

  /// What to call one of a switch's antenna ports.
  ///
  /// The operator's own antenna node wins where they linked one: the switch
  /// calls it what somebody typed into the switch's own web page, possibly
  /// years ago and on a different antenna. Falls back to the switch's name
  /// when there is no link, or when the link points at a node that has since
  /// been removed — a stale uuid must not render as a blank row.
  String _switchAntennaLabel(EquipmentNode node, SwitchAntenna antenna) {
    final uuid = node.config[switchAntennaNodeConfigKey(antenna.key)];
    if (uuid is String && uuid.isNotEmpty) {
      if (_cat.nodeFor(uuid) case final linked?) return _displayName(linked);
    }
    return _switchPortName(antenna);
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildContent(context);
    if (!compact) return content;
    // The compact dialog's own footer, pinned under the scrolling content —
    // same shape as the Exports pane's (operation_export_panel.dart).
    return Column(
      children: [
        Expanded(child: content),
        _compactFooter(context),
      ],
    );
  }

  /// The dropdown's value for a peer radio. Namespaced because the list is
  /// shared with local nodes and both are keyed by a uuid — one that means
  /// "a node in THIS station" and one that does not.
  static String? _peerValue(PeerRadioSelection? selection) => selection == null ? null : peerRadioValue(selection);

  static PeerRadioSelection _selectionFor(PeerRemoteRadio peer) =>
      PeerRadioSelection(deviceId: peer.deviceId, radioId: peer.radio.id, deviceName: peer.deviceName, radioName: peer.radio.name);

  /// One list, because there is one main VFO — see `CatService.radio1`, the
  /// single slot both kinds of pick are written to.
  ///
  /// The pick is rebuilt from the VALUE rather than looked up in the current
  /// offers, and that is the whole point: a menu's items are captured when it
  /// opens, so the peer can be gone by the time the operator taps one. A
  /// lookup would then match nothing and this would return having done
  /// nothing — while the dropdown has already adopted the tapped value, which
  /// now names no item at all.
  Future<void> _onMainVfoPicked(String? value) async {
    final picked = peerRadioSelectionFromValue(value);
    if (picked == null) return _cat.setRadio1(value == null ? null : LocalRadio(value));
    // Names from the live offer when there is one, and otherwise from the
    // pick being replaced — which is the same radio when the operator has
    // simply re-tapped an entry that went unavailable under them.
    final offered = services.peerRemoteRadios.find(picked.deviceId, picked.radioId);
    final kept = switch (_cat.radio1) {
      PeerRadio(:final selection) when selection.matches(picked.deviceId, picked.radioId) => selection,
      _ => null,
    };
    return _cat.setRadio1(
      PeerRadio(
        PeerRadioSelection(
          deviceId: picked.deviceId,
          radioId: picked.radioId,
          deviceName: offered?.deviceName ?? kept?.deviceName ?? '',
          radioName: offered?.radio.name ?? kept?.radioName ?? '',
        ),
      ),
    );
  }

  /// The rig the logging panel follows, first in the panel. Picking another
  /// is this row's menu, or the icon on an inventory row.
  Widget _currentTransceiverRow(
    BuildContext context, {
    required String? localRadio1,
    required PeerRadioSelection? selection,
    required PeerRadioSelection? absentSelection,
  }) {
    final st = context.t.settings.station;
    return TransceiverMenu(
      rows: _transceiverChoices,
      builder: (context, toggle) {
        final picker = SizedBox.square(
          dimension: transceiverPickerWidth,
          child: IconButton(
            icon: Icon(MdiIcons.menuDown, semanticLabel: st.chooseTransceiver),
            onPressed: toggle,
          ),
        );
        if (selection != null) {
          return PeerVfoTile(
            selection: selection,
            available: absentSelection == null,
            trailing: picker,
            onTap: () => showPeerRadioElsewhere(
              context,
              radio: selection.radioName.isEmpty ? selection.radioId : selection.radioName,
              device: selection.deviceName.isEmpty ? selection.deviceId : selection.deviceName,
            ),
          );
        }
        final node = localRadio1 == null ? null : _cat.nodeFor(localRadio1);
        if (node == null) {
          // Nothing to edit, so the whole row is the way to pick one.
          return ListTile(
            leading: Icon(iconForCategory(kCategoryTransceiver)),
            title: Text(st.noTransceiverSelected),
            trailing: picker,
            onTap: toggle,
            mouseCursor: SystemMouseCursors.click,
          );
        }
        return CurrentTransceiverTile(
          displayName: _displayName(node),
          connection: connectionTextFor(context, _cat.typeFor(node), node.config),
          transportType: _cat.typeFor(node),
          state: _cat.stateFor(node.uuid),
          unconfigured: _cat.typeFor(node)?.isUnconfigured(node.config) ?? false,
          onEdit: () => _editEquipment(context, node),
          onConnect: () => _cat.connect(node.uuid),
          onDisconnect: () => _cat.disconnect(node.uuid),
          trailing: picker,
        );
      },
    );
  }

  /// Every radio the main VFO could follow — this station's, the peers', and
  /// none — as the inventory's rows. A tap anywhere on a row picks it.
  List<Widget> _transceiverChoices(BuildContext context, VoidCallback close) {
    final st = context.t.settings.station;
    final selection = switch (_cat.radio1) {
      PeerRadio(:final selection) => selection,
      _ => null,
    };
    void pick(String? value) {
      close();
      unawaited(_onMainVfoPicked(value));
    }

    return [
      for (final node in _cat.nodes)
        if (_cat.typeFor(node)?.category == kCategoryTransceiver)
          TransceiverRow(
            name: _displayName(node),
            channel: _cat.typeFor(node)?.describeChannel(node.config),
            connection: connectionTextFor(context, _cat.typeFor(node), node.config),
            transportType: _cat.typeFor(node),
            selected: _cat.isRadio1(node.uuid),
            onSelect: () => pick(node.uuid),
            onEdit: () => pick(node.uuid),
          ),
      for (final peer in services.peerRemoteRadios.all)
        TransceiverRow(
          name: peer.radio.name,
          connection: st.peerRadioOnDevice(device: peer.deviceName),
          connectionIcon: MdiIcons.lan,
          selected: selection?.matches(peer.deviceId, peer.radio.id) ?? false,
          onSelect: () => pick(_peerValue(_selectionFor(peer))),
          onEdit: () => pick(_peerValue(_selectionFor(peer))),
        ),
      TransceiverRow(name: st.noTransceiver, connection: '', selected: _cat.radio1 == null, onSelect: () => pick(null), onEdit: () => pick(null)),
    ];
  }

  Widget _buildContent(BuildContext context) {
    final st = context.t.settings.station;

    return ListenableBuilder(
      // Settings as well as CAT: developer mode decides whether the rows show
      // what a driver worked out, and toggling it has to reach them. Both are
      // ChangeNotifiers, and listening to one left the other's changes
      // invisible until something else happened to rebuild this.
      listenable: Listenable.merge([_cat, services.settings, services.peerRemoteRadios]),
      builder: (context, _) {
        final rowInset = _rowInset(context);
        final nodes = _cat.nodes;
        final antennas = [
          for (final node in nodes)
            if (_cat.typeFor(node)?.category == kCategoryAntenna) node,
        ];
        // The key in use: a paddle on the desk, or what keys for the app —
        // a keyer, or a radio whose CAT can. One pick, because a station
        // with more than one has to say which one the messages go through.
        final keyerExperiment = services.settings.experimentEnabled('keyer') /* stored key, see experiments.yaml */;
        final keys = [
          for (final node in nodes)
            if (_cat.typeFor(node)?.category == kCategoryKey) node,
          if (keyerExperiment) ..._cat.keyerCandidates,
        ];
        // A peer's radio is picked from the same list as this device's own:
        // it drives the same one `vfoA`, so offering a second control for it
        // would be offering two answers to one question (HALO-416).
        final selection = switch (_cat.radio1) {
          PeerRadio(:final selection) => selection,
          _ => null,
        };
        final localRadio1 = switch (_cat.radio1) {
          LocalRadio(:final uuid) => uuid,
          _ => null,
        };
        final peerRadios = services.peerRemoteRadios.all;
        // A selection whose peer is not here stays SHOWN and selected, said
        // to be unavailable — dropping it would silently hand the VFO back
        // to a local radio the operator had deliberately stepped off, and
        // the pick is what re-engages by itself when the peer returns.
        final absentSelection = selection != null && !peerRadios.any((r) => selection.matches(r.deviceId, r.radio.id)) ? selection : null;
        // Keep nullable peer field reads outside the inventory loop. Dart
        // 3.12.2 AOT hoists radioName.isEmpty above the null guard when this
        // row is built inside that loop, crashing macOS release builds with
        // a local radio selected. See docs/quirks.md.
        final absentPeerRow = compact || absentSelection == null
            ? null
            : TransceiverRow(
                name: absentSelection.radioName.isEmpty ? absentSelection.radioId : absentSelection.radioName,
                connection: st.peerRadioNotAvailable,
                connectionIcon: MdiIcons.lan,
                selected: true,
                onSelect: () {},
                onEdit: () => showPeerRadioElsewhere(
                  context,
                  radio: absentSelection.radioName.isEmpty ? absentSelection.radioId : absentSelection.radioName,
                  device: absentSelection.deviceName.isEmpty ? absentSelection.deviceId : absentSelection.deviceName,
                ),
              );

        return StationExpansionScope(
          builder: (context, expanded, toggle) => SectionedListView(
            padding: const EdgeInsets.only(bottom: Space.md),
            children: [
              // What the station IS right now: the rig the logging panel
              // follows first, then the antenna, key and keyer that go with it.
              // The rig rides IN the band, pinned with it: it is what the
              // category is about, and it stays in view while the rest of
              // the page scrolls under it.
              CategoryBand(
                st.currentTransceiver,
                // A ground of its own, half way back to the surface, so the
                // rig reads as the band's content rather than more heading.
                below: Material(
                  color: Color.lerp(Theme.of(context).colorScheme.surface, haloCategoryBandColor(context), 0.5),
                  child: _currentTransceiverRow(context, localRadio1: localRadio1, selection: selection, absentSelection: absentSelection),
                ),
              ),
              SectionHeader(st.configurationSection),
              // Which antenna and key a QSO's captured station info should
              // credit, side by side — each only once there is something to
              // choose between. The key row also offers a peer's key, though
              // it is no node of this station: the phone this is for has no
              // key inventory of its own, and without it its operator could
              // not step off the peer's key.
              if (antennas.isNotEmpty || keys.isNotEmpty || (keyerExperiment && _cat.peerOffersCwKeying))
                Padding(
                  padding: EdgeInsets.fromLTRB(rowInset.left, Space.md, rowInset.right, Space.md),
                  child: Row(
                    children: [
                      if (antennas.isNotEmpty)
                        Expanded(
                          child: DesignationDropdown(
                            key: ValueKey(_cat.designatedFor(kCategoryAntenna)),
                            label: st.antennaInUse,
                            nodes: antennas,
                            selected: _cat.designatedFor(kCategoryAntenna),
                            displayName: _displayName,
                            noneLabel: st.noneSelected,
                            onChanged: (uuid) => unawaited(_cat.setDesignated(kCategoryAntenna, uuid)),
                          ),
                        ),
                      if (antennas.isNotEmpty && (keys.isNotEmpty || (keyerExperiment && _cat.peerOffersCwKeying))) const SizedBox(width: Space.md),
                      if (keys.isNotEmpty || (keyerExperiment && _cat.peerOffersCwKeying)) Expanded(child: _keyPicker(context, keys: keys)),
                    ],
                  ),
                ),

              // One keyer row for both keyers: the messages to edit, and the
              // switch that shows the logging panel's strip. In BOTH layouts,
              // unlike the Power field — they belong to the key picked
              // directly above, so a full page that named the key and then had
              // nothing to say about it would send the operator to the compact
              // dialog to finish the job.
              // Capability, not connection: see _keyerRow. With neither side
              // able to carry a message there is nothing for the row to open.
              if (keyerExperiment && (_cat.designatedKeyIsKeyer || _cat.radio1HasVoiceMemories)) _keyerRow(context, inset: rowInset),

              // The same break between categories as before CAT Control Preferences.
              const SizedBox(height: Space.xl * 2),
              // What the station is made OF. Compact shows only what is in use
              // — the rig driving the main VFO, and the key if it is a device
              // of its own — as quick-glance connect/status rows, not the whole
              // catalogue Add Equipment and the other radios imply.
              CategoryBand(
                compact ? st.equipmentInUse : st.equipmentInventory,
                // In the heading rather than as a last row: adding is what this
                // category is FOR, and a row at the bottom of a long inventory
                // is the one place an operator has to scroll to find it. Absent
                // in compact, which lists what is in use and adds nothing.
                trailing: compact
                    ? null
                    : FilledButton.icon(icon: const Icon(MdiIcons.plus, size: 18), label: Text(st.add), onPressed: () => _addEquipment(context)),
              ),
              if (compact) ...[
                // And the keyer in use, when it is a device of its own: the
                // row above is where it gets connected, so a radio keying
                // through its own CAT session must not draw a second row.
                if (keyerExperiment)
                  if (_cat.designatedKeyerNode case final keyer?)
                    if (!_cat.isRadio1(keyer.uuid))
                      EquipmentTile(
                        node: keyer,
                        type: _cat.typeFor(keyer),
                        state: _cat.stateFor(keyer.uuid),
                        developerMode: services.settings.developerMode,
                        displayName: _displayName(keyer),
                        isMainVfo: false,
                        onEdit: () => _editEquipment(context, keyer),
                        onRemoveUnknown: () => _removeEquipment(context, keyer),
                        onConnect: () => _cat.connect(keyer.uuid),
                        onDisconnect: () => _cat.disconnect(keyer.uuid),
                      ),
              ] else ...[
                if (nodes.isEmpty) ListTile(title: Text(st.none)),
                // Under the category, one section per kind — a shack's radios
                // are not a list its antennas belong in. A section with nothing
                // in it is absent rather than empty: an operator with no
                // antennas configured is not owed a heading saying so.
                for (final section in _inventorySections(context, nodes)) ...[
                  SectionHeader(
                    section.title,
                    // By category: the title's count changes under the operator.
                    expanded: expanded.contains(section.category),
                    onTap: () => toggle(section.category),
                  ),
                  for (final node in section.nodes)
                    if (section.category == kCategoryTransceiver && _cat.typeFor(node) != null)
                      TransceiverRow(
                        name: _displayName(node),
                        channel: _cat.typeFor(node)?.describeChannel(node.config),
                        connection: connectionTextFor(context, _cat.typeFor(node), node.config),
                        transportType: _cat.typeFor(node),
                        selected: _cat.isRadio1(node.uuid),
                        onSelect: () => unawaited(_onMainVfoPicked(node.uuid)),
                        onEdit: () => _editEquipment(context, node),
                      )
                    else
                      EquipmentTile(
                        node: node,
                        type: _cat.typeFor(node),
                        state: _cat.stateFor(node.uuid),
                        developerMode: services.settings.developerMode,
                        displayName: _displayName(node),
                        isMainVfo: _cat.isRadio1(node.uuid),
                        onEdit: () => _editEquipment(context, node),
                        onRemoveUnknown: () => _removeEquipment(context, node),
                        onConnect: () => _cat.connect(node.uuid),
                        onDisconnect: () => _cat.disconnect(node.uuid),
                      ),
                  // A peer's radio is picked from the same list as this
                  // device's own: it drives the same one `vfoA`, so a second
                  // control for it would offer two answers to one question.
                  if (section.category == kCategoryTransceiver) ...[
                    for (final peer in peerRadios)
                      TransceiverRow(
                        name: peer.radio.name,
                        connection: st.peerRadioOnDevice(device: peer.deviceName),
                        connectionIcon: MdiIcons.lan,
                        selected: selection?.matches(peer.deviceId, peer.radio.id) ?? false,
                        onSelect: () => unawaited(_onMainVfoPicked(_peerValue(_selectionFor(peer)))),
                        onEdit: () => showPeerRadioElsewhere(context, radio: peer.radio.name, device: peer.deviceName),
                      ),
                    ?absentPeerRow,
                  ],
                ],
              ],
              if (compact) _powerField(context, inset: rowInset),
              if (!compact) ...[
                // Its own sliver, not a row: as a row it would belong to the
                // last inventory section above and fold away with it.
                const SectionedSlivers(
                  slivers: [SliverToBoxAdapter(child: SizedBox(height: Space.xl * 2))],
                ),
                // The CAT Control preferences, the same rows Application
                // Preferences shows, less its link back to this panel.
                CategoryBand(st.catControlPreferences),
                settingsGroupRows(services: services, groupKey: 'radio', excludeKeys: const {moreStationSettingsKey, stationConfigurationSectionKey}),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Right after the current rig's row — the quick dialog's one write-in
  /// field among its pickers, though "write-in" undersells it once a rig is
  /// connected: a commit goes to the app's VFO ([Vfo.power]), which CAT
  /// forwards to radio1's session exactly as it forwards a typed frequency.
  /// The CAT reading, when there is one, still wins on the next external
  /// update — this only ever pushes a value.
  ///
  /// Sized to 4 digits (no legal amateur power runs to 5) rather than
  /// stretching the row, with "Watts" after it — baseline-aligned with the
  /// field's own text, not merely centered beside it — standing in for the
  /// unit label a bare number field doesn't carry.
  Widget _powerField(BuildContext context, {required EdgeInsets inset}) {
    final st = context.t.settings.station;
    final style = Theme.of(context).textTheme.titleMedium ?? const TextStyle();
    // 4 digits' width, plus poloFieldDecoration's own horizontal content
    // padding (theme.dart) and a small caret allowance — everything the
    // field needs beyond the glyphs themselves.
    final scale = MediaQuery.textScalerOf(context).scale(1.0);
    final fieldWidth = textWidth(context, '0000', style) + 8 * scale + 3 * scale;
    return Padding(
      padding: EdgeInsets.fromLTRB(inset.left, Space.md, inset.right, Space.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PowerField(
            power: _cat.displayedPower,
            label: st.trackFieldPower,
            wattsLabel: st.watts,
            width: fieldWidth,
            style: style,
            onCommit: (watts) => services.radio.setVfo('vfoA', power: watts, clearPower: watts == null),
          ),
          const SizedBox(width: Space.xxl),
          RadioModeField(cat: _cat),
        ],
      ),
    );
  }

  /// The key in use. NOT behind the keyer experiment: choosing which key a
  /// contact is logged with is ordinary station info. Only the peer's key
  /// among its choices, and the speed on the keyer row, are.
  Widget _keyPicker(BuildContext context, {required List<EquipmentNode> keys}) {
    final st = context.t.settings.station;
    final keyerExperiment = services.settings.experimentEnabled('keyer') /* stored key, see experiments.yaml */;
    // The peer whose radio drives the VFO, when one does: its own key is
    // what keys for this operator unless they pick otherwise (HALO-585).
    final peer = _cat.followedPeerRadio;
    return DesignationDropdown(
      key: ValueKey('${_cat.designatedFor(kCategoryKey)}:${_cat.peerKeyIsInUse}'),
      label: st.keyInUse,
      nodes: keys,
      // The peer's key is a default, so nothing is stored for it — and a
      // picker reading the stored value alone would say None while F1 keys
      // over the link.
      selected: peer != null && _cat.peerKeyIsInUse && _cat.peerOffersCwKeying ? peerRadioValue(peer) : _cat.designatedFor(kCategoryKey),
      // A radio in this list is its keyer, not the radio.
      displayName: (node) => _cat.typeFor(node)?.category == kCategoryTransceiver ? st.keyViaRadio(radio: _displayName(node)) : _displayName(node),
      noneLabel: st.noneSelected,
      // The peer whose radio drives the VFO keys for this operator unless
      // they say otherwise — offered here so saying otherwise can be undone.
      // Only while it OFFERS keying: a device that keys nothing is not a key.
      extras: [
        if (keyerExperiment && peer != null && _cat.peerOffersCwKeying)
          (value: peerRadioValue(peer), label: st.keyOnDevice(device: peer.deviceName.isEmpty ? peer.deviceId : peer.deviceName)),
      ],
      onChanged: (uuid) => unawaited(_cat.setDesignated(kCategoryKey, uuid)),
    );
  }

  /// The speed the designated keyer sends at, sized to its value ("30 WPM")
  /// rather than stretched across the row it shares with the keyer's
  /// switch and message buttons.
  Widget _keyerSpeed(BuildContext context) {
    final canKey = _cat.canKeyCw;
    final range = _cat.keyerSpeedRange;
    final speed = _cat.keyerSpeed;
    final inRange = speed != null && range != null && speed >= range.min && speed <= range.max;
    final ks = context.t.settings.radio.keyerSpeed;
    final theme = Theme.of(context);
    final valueStyle = theme.textTheme.titleMedium ?? const TextStyle();
    final labelStyle = theme.textTheme.bodySmall ?? const TextStyle();
    // The wider of the value and the floating label, plus the field's
    // content padding and the dropdown's trailing icon.
    final width = math.max(textWidth(context, '30 ${ks.unit}', valueStyle), textWidth(context, ks.title, labelStyle)) + 16 + 32;
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<int>(
        // Keyed on the value: FormFieldState reads initialValue once, and the
        // radio's answer arrives after the first build.
        key: ValueKey('keyerSpeed:${inRange ? speed : null}:$canKey'),
        isExpanded: true,
        initialValue: inRange ? speed : null,
        icon: dropdownTrailingIcon,
        decoration: poloFieldDecoration(context, ks.title),
        menuMaxHeight: dropdownMenuMaxHeight(context),
        items: [
          if (range != null)
            for (var wpm = range.min; wpm <= range.max; wpm++) DropdownMenuItem<int>(value: wpm, child: Text('$wpm ${ks.unit}')),
        ],
        onChanged: canKey ? (wpm) => wpm == null ? null : _cat.setKeyerSpeed(wpm) : null,
      ),
    );
  }

  /// Both keyers on one line: the way into each message editor, and the
  /// switch that shows the logging panel's keyer area.
  ///
  /// One row rather than two, because an operator has ONE keyer area and the
  /// switch that shows it cannot sensibly appear twice. Which editors are
  /// offered still differs: CW messages are the app's own and need a key
  /// that keys, while the voice memories are radio1's own.
  ///
  /// Laid out from CAPABILITY, never from the link: the row shows whenever
  /// either side could carry a message, both buttons are always present, and
  /// each is disabled only where its own side cannot send at all. A control
  /// that came and went with the connection would move under the operator
  /// every time the radio blinked, and "this rig has no voice memories" must
  /// not look like "the rig is unplugged".
  ///
  /// Icons, not labelled buttons: the row's own caption already says what
  /// they are for. No hover tooltips (docs/design/user-interface.md), so a
  /// disabled button says why in [Semantics] or nowhere.
  Widget _keyerRow(BuildContext context, {required EdgeInsets inset}) {
    final st = context.t.settings.station;
    final canKey = _cat.designatedKeyIsKeyer;
    final canVoice = _cat.radio1HasVoiceMemories;
    return Padding(
      padding: EdgeInsets.fromLTRB(inset.left, 0, inset.right, Space.md),
      // A Wrap, not a Row: nothing here can shrink, and on a narrow pane the
      // message buttons drop to a second line rather than overflow.
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: Space.sm,
        runSpacing: Space.sm,
        children: [
          // Leading: the switch is what the row is FOR — the editors behind
          // it are somewhere to go, not the state the row carries. Shows or
          // hides the keyer area in the logging panel, the same switch KEYER
          // and the area's X move, and it persists
          // (SettingsService.keyerAreaShown). The name lives in Semantics,
          // per docs/design/user-interface.md — never a tooltip.
          // The switch and its label stay together on the first line.
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: _cat.keyerAreaShown,
                builder: (context, shown, _) => Semantics(
                  label: st.cwKeyerArea,
                  child: Switch(value: shown, onChanged: (on) => on ? _cat.showKeyerArea() : _cat.hideKeyerArea()),
                ),
              ),
              const SizedBox(width: Space.sm),
              Text(st.keyerRowLabel, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(width: Space.sm),
            ],
          ),
          if (canKey) _keyerSpeed(context),
          // The same icon on both: what they open is a list of messages
          // either way, and the labels are what tell them apart. Both are
          // always here — a side that cannot send is a fact about the
          // station worth SEEING, and one that disappeared would leave a row
          // indistinguishable from a rig whose memories have not loaded yet.
          MessagesButton(
            label: st.cwMessagesButton,
            enabled: canKey,
            disabledReason: st.notSupportedByThisRadio,
            onPressed: () => showCwMessagesDialog(context, services),
          ),
          MessagesButton(
            label: st.voiceMessagesButton,
            enabled: canVoice,
            disabledReason: st.notSupportedByThisRadio,
            onPressed: () => showVoiceMessagesDialog(context, services),
          ),
        ],
      ),
    );
  }

  /// "More Settings" (leading) and "Done" (trailing) — [destructive] is used
  /// only for its LEADING position, the sole slot `haloDialogFooterRow`
  /// offers opposite the primary/cancel group; "More Settings" itself
  /// destroys nothing.
  Widget _compactFooter(BuildContext context) {
    final st = context.t.settings.station;
    return haloDialogFooterBand(
      context,
      destructive: TextButton(onPressed: onMoreSettings, child: Text(st.moreSettings)),
      cancel: TextButton(onPressed: () => Navigator.of(context).maybePop(), child: Text(context.t.common.done)),
    );
  }
}

/// The Power field's own text state, kept in a controller rather than
/// [TextFormField]'s bare `initialValue` — the field's value has TWO writers
/// (the operator typing, and a live CAT reading arriving from the radio) and
/// only a controller can tell "external update" apart from "an edit in
/// progress" rather than clobbering focus/cursor on every keystroke the way
/// a value-keyed `initialValue` field would.
///
/// Commits (to [SettingsService.currentPower] and the radio) on submit or on
/// losing focus, never per keystroke — the same reason the VFO frequency
/// sync dedupes against `lastSent` (docs/design/cat.md): a command per digit
/// would briefly send the radio through every intermediate value.
class _PowerField extends StatefulWidget {
  final num? power;
  final String label;
  final String wattsLabel;
  final double width;
  final TextStyle style;
  final ValueChanged<num?> onCommit;

  const _PowerField({required this.power, required this.label, required this.wattsLabel, required this.width, required this.style, required this.onCommit});

  @override
  State<_PowerField> createState() => _PowerFieldState();
}

class _PowerFieldState extends State<_PowerField> {
  late final TextEditingController _controller = TextEditingController(text: _textFor(widget.power));
  final FocusNode _focusNode = FocusNode();

  static String _textFor(num? power) => power?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) _commit();
  }

  @override
  void didUpdateWidget(_PowerField old) {
    super.didUpdateWidget(old);
    // A live CAT reading arriving behind this field's back must not
    // clobber what the operator is mid-typing — only take it while the
    // field isn't focused, the same rule the VFO frequency field follows
    // (docs/design/cat.md, "Never over the operator").
    if (!_focusNode.hasFocus && widget.power != old.power) {
      _controller.text = _textFor(widget.power);
    }
  }

  void _commit() => widget.onCommit(num.tryParse(_controller.text));

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocusChange)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        SizedBox(
          width: widget.width,
          child: TextFormField(
            controller: _controller,
            focusNode: _focusNode,
            keyboardType: const TextInputType.numberWithOptions(decimal: false),
            decoration: poloFieldDecoration(context, widget.label),
            onFieldSubmitted: (_) => _commit(),
          ),
        ),
        const SizedBox(width: Space.md),
        Text(widget.wattsLabel, style: widget.style),
      ],
    );
  }
}
