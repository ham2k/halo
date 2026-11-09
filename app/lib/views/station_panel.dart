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

import 'package:halo_i18n/halo_i18n.dart';
import '../services/halo_services.dart';
import 'add_equipment_dialog.dart';
import 'midi_controller_pane.dart';
import '../services/cat/equipment.dart';
import '../services/cat/telemetry_poller.dart';
import '../services/cat/transports/placeholder_transport.dart' show PlaceholderTransport;
import '../services/cat/transports/serial_transport.dart' show SerialTransportConfig, serialDtrHighConfigKey, serialRtsHighConfigKey;
import '../services/cat/drivers/antenna_genius_driver.dart';
import '../services/cat/drivers/icom_civ_driver.dart' show civScopeAdjustConfigKey, civScopeConfigKey;
import '../services/cat/drivers/rotator_config.dart';
import '../services/cat/equipment_registry.dart';
import '../services/cat/cat_service.dart';
import '../services/peer/peer_remote_radios.dart';
import '../services/peer/peer_station_radios.dart';
import '../services/settings_service.dart';
import 'equipment_report.dart';
import 'keying_pickers.dart';
import 'so2r_switch_dialog.dart';
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

/// The equipment editor's Advanced Settings fold, inside Connection: the
/// link's own fields marked `'advanced': true` fold under it.
const _advancedDisclosureKey = 'advanced';

/// How often an open equipment editor looks again for serial ports — a
/// cable plugged in while the pane is open.
const _portRefresh = Duration(seconds: 3);

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
    // Added at once and opened in its own pane: its fields are a device to
    // pick and controls to learn, neither of which a form before the node
    // exists can offer.
    if (model.category == kCategoryMidi) {
      final node = await _cat.addNode(typeKey: variants.first.key, name: _cat.suggestedNameFor(variants.first.key), config: const {});
      if (context.mounted) await _editMidiController(context, node);
      return;
    }
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
        showRotator: services.settings.experimentEnabled('rotator') /* stored key, see experiments.yaml */,
        showSo2rSwitch: services.settings.experimentEnabled('so2r') /* stored key, see experiments.yaml */,
        showMidi: services.settings.experimentEnabled('midi') /* stored key, see experiments.yaml */,
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
    if (type.category == kCategoryMidi) return _editMidiController(context, node);

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

    // No-op for every transport except the web serial one, which uses this
    // to fetch and cache navigator.serial's already-granted device list
    // before configElements() (synchronous, so it can't await this itself)
    // reads it. Every offered pairing's transport gets prepared, not just
    // the selected one: they all render, so they all have to be ready before
    // the first build.
    Future<void> prepareVariants() async {
      for (final candidate in variants) {
        await candidate.transport.prepareConfigElements();
      }
    }

    await prepareVariants();
    if (!context.mounted) return null;
    // A connected rotator's editor refreshes faster, so its readout keeps up
    // with a turn — but still enumerates ports only every [_portRefresh].
    final refreshEvery = model.category == kCategoryRotator ? _rotatorReadoutRefresh : _portRefresh;
    final ticksPerPrepare = _portRefresh.inMilliseconds ~/ refreshEvery.inMilliseconds;
    var refreshTicks = 0;

    // The link's own rarely-touched fields — the serial lines, the USB
    // driver — belong with the connection they configure; the driver's —
    // the poll and meter cadences, a rotator's limits — with the rest. Told
    // apart by key, since the editor sees one merged list per pairing, and
    // by each transport's declared keys rather than its elements: building
    // those enumerates serial ports, and the form rebuilds every few seconds.
    final linkKeys = {for (final candidate in variants) ...candidate.transport.recognizedConfigKeys};
    final connects = choosable || linkKeys.isNotEmpty;

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
                // `transport` value no field sets. Beside the driver's own
                // condition, never over it: a rotator's elevation fields
                // hide for an az-only rotator on either transport.
                if (choosable)
                  'visibleWhen': [
                    ?element['visibleWhen'],
                    {'field': 'transport', 'equals': candidate.transportKey},
                  ],
              },
      ];
      // A pairing's troubleshooting notes (every note is collapsible
      // markdown, a registry test holds that): read only when something is
      // wrong, so they close the form rather than sit between the fields.
      bool isNote(Map<String, dynamic> element) => element['type'] == 'markdown' && element['collapsible'] == true;
      bool isAdvanced(Map<String, dynamic> element) => element['advanced'] == true && !isNote(element);
      bool isLinkAdvanced(Map<String, dynamic> element) => isAdvanced(element) && linkKeys.contains(element['key']);
      List<Map<String, dynamic>> rotatorRows(List<Map<String, dynamic>> rows) => model.category == kCategoryRotator ? _addressRows(rows) : rows;
      return [
        {'type': 'field', 'fieldType': 'text', 'key': 'name', 'label': st.name, 'description': st.nameDescription},
        // What the category itself asks first — an antenna's bands, a
        // receiver's radio — right under the name, ahead of Connection: an
        // antenna has no connection, and its bands are its main question.
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
        // The FILLED band: the editor's own top-level groups, with nothing
        // above them to say so (docs/design/user-interface.md § Settings
        // lists). Only for equipment that is connected at all — an antenna's
        // own fields are not a connection — and gone when the chosen pairing
        // asks nothing.
        if (connects) {'type': 'header', 'style': 'category', 'title': st.transport, 'hideWhenEmpty': true},
        if (choosable)
          {
            'type': 'field',
            'fieldType': 'segmented',
            'key': 'transport',
            // Announced, not drawn: the band above already shows it.
            'label': st.transport,
            'hideLabel': true,
            // The model's own ways in, then the placeholder, as segments;
            // the pairings derived for every radio of its kind behind Other
            // (EquipmentModel.offersBehindOther).
            'options': [
              for (final candidate in variants)
                if (!model.offersBehindOther(candidate.variant)) {'value': candidate.transportKey, 'label': candidate.transportLabel},
            ],
            'moreOptions': [
              for (final candidate in variants)
                if (model.offersBehindOther(candidate.variant)) {'value': candidate.transportKey, 'label': candidate.transportLabel},
            ],
            'moreLabel': st.transportOther,
            // A pick joins the model's own ways in, ahead of "no control".
            'moreBefore': PlaceholderTransport.transportKey,
          },
        ...rotatorRows(connection.where((element) => !isAdvanced(element) && !isNote(element)).toList()),
        // Closed until asked for: holding a serial line high can key a
        // transmitter, and most operators never need to. FormRenderer hides
        // the fold whenever the chosen pairing has nothing in it, and opens
        // it on an error inside.
        {'type': 'disclosure', 'key': _advancedDisclosureKey, 'title': st.advancedSettings, 'elements': rotatorRows(connection.where(isLinkAdvanced).toList())},
        // Which of the operator's own antennas is on each of the switch's
        // antenna ports. Here rather than in the driver's own
        // configElements(): a driver is pure catalogue data with no access
        // to the station's inventory, and this list is the operator's
        // equipment, not the switch's.
        // What the switch is doing now, before how it is set up: an
        // operator opening this dialog mid-operation is looking for the
        // former, and the latter is answered once and rarely revisited.
        // Both bring their own bands, so they stand between Connection and
        // More rather than inside either.
        if (model.category == kCategoryAntennaSwitch) ...[..._switchCurrentState(context, node), ..._switchWiring(context, type, node)],
        if (model.category == kCategoryRotator) ..._rotatorCurrentState(context, node),
        // Everything else, last: the driver's rarely-touched fields — the
        // poll and meter cadences — and the pairing's troubleshooting
        // notes. Gone when the chosen pairing leaves nothing under it.
        {'type': 'header', 'style': 'category', 'title': st.moreBand, 'hideWhenEmpty': true},
        ...rotatorRows(connection.where((element) => isAdvanced(element) && !isLinkAdvanced(element)).toList()),
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
        // A serial node's lines open where it connects them: a key it never
        // stored reads low at connect, so a prefill seeded here would tick a
        // box the connection ignores, and any save would then raise the line
        // — on a Digirig, keying the transmitter. Only a pairing that reads
        // the key: a placeholder or BLE node switched to serial here starts
        // from the prefill, as an added one does.
        if (node != null && type.transport is SerialTransportConfig) ...{serialRtsHighConfigKey: false, serialDtrHighConfigKey: false},
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
      validator: (key, value, values) async =>
          isSwitchPortRoutingFormKey(key) || isRotatorFormKey(key) ? null : _cat.validateEquipmentEditorField(typeForState(values), node, key, value, values),
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
        if (_runRotatorAction(context, node, actionKey, state) case final rotated?) return rotated;
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
        every: refreshEvery,
        build: () async {
          if (++refreshTicks % ticksPerPrepare == 0) await prepareVariants();
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
          // Nor are a rotator's target boxes: a heading is a command.
          if (entry.key != 'name' && entry.key != 'transport' && !isSwitchPortRoutingFormKey(entry.key) && !isRotatorFormKey(entry.key)) entry.key: entry.value,
      },
    );
  }

  /// A MIDI controller's editor — see midi_controller_pane.dart for why it
  /// is not the equipment form. Remove closes the pane before confirming, as
  /// the form's own does.
  Future<void> _editMidiController(BuildContext context, EquipmentNode node) =>
      showMidiControllerPane(context, services: services, nodeUuid: node.uuid, onRemove: () => unawaited(_removeEquipment(context, node)));

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

  /// Stores [value] on [node], then reconnects it if it is connected: its
  /// session reads the setting when it starts, and a choice that waited for
  /// the next connect would leave HaLo driving the radio's front panel after
  /// the operator had told it to stop.
  Future<void> _applyScopeAdjust(EquipmentNode node, String value) async {
    await _cat.updateNode(node.copyWith(config: {...node.config, civScopeAdjustConfigKey: value}));
    if (_cat.stateFor(node.uuid).status != EquipmentStatus.connected) return;
    await _cat.disconnect(node.uuid);
    await _cat.connect(node.uuid);
  }

  /// [uuid]'s bandscope choice as a details row, when it is an Icom whose
  /// scope is its own screen; [radio] names it under SO2R.
  Widget? _scopeAdjustRow(BuildContext context, String? uuid, {required String? radio, required EdgeInsets inset}) {
    final node = uuid == null ? null : _cat.nodeFor(uuid);
    if (node == null || _cat.typeFor(node)?.overrides[civScopeConfigKey] != true) return null;
    final st = context.t.settings.station;
    return Padding(
      padding: EdgeInsets.fromLTRB(inset.left, 0, inset.right, Space.md),
      child: ScopeAdjustField(
        node: node,
        label: radio == null ? st.civScopeAdjust : st.so2rRadioName(radio: radio, name: st.civScopeAdjust),
        onChanged: (value) => unawaited(_applyScopeAdjust(node, value)),
      ),
    );
  }

  /// [node]'s plug on its inventory row — disabled, not absent, while it has
  /// nowhere to connect to, so the row keeps its shape.
  RowPlug _plugFor(EquipmentNode node) {
    final state = _cat.stateFor(node.uuid);
    final unconfigured = _cat.typeFor(node)?.isUnconfigured(node.config) ?? false;
    return RowPlug(
      busy: state.status == EquipmentStatus.connecting || state.status == EquipmentStatus.disconnecting,
      // A radio that has stopped answering reads as the loss it is, as on
      // the current transceiver's row: the plug pulled, its tap reconnecting.
      connected: state.status == EquipmentStatus.connected && !state.stale,
      onConnect: unconfigured ? null : () => _cat.connect(node.uuid),
      onDisconnect: () => _cat.disconnect(node.uuid),
    );
  }

  /// [StationExpansionScope]'s key for the folding details section — not a
  /// category, so it cannot collide with the inventory's.
  static const _detailsSection = 'details';

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
            picker: picker,
            onTap: () => showPeerRadioElsewhere(
              context,
              radio: selection.radioName.isEmpty ? selection.radioId : selection.radioName,
              device: selection.deviceName.isEmpty ? selection.deviceId : selection.deviceName,
            ),
          );
        }
        final node = localRadio1 == null ? null : _cat.nodeFor(localRadio1);
        final so2r = services.settings.experimentEnabled('so2r') /* stored key, see experiments.yaml */;
        if (node == null) {
          // Nothing to edit, so the whole row is the way to pick one.
          return CurrentRowFrame(
            leading: picker,
            child: ListTile(
              leading: const TransceiverGlyph.bare(inUse: false),
              title: Text(st.noTransceiverSelected),
              onTap: toggle,
              mouseCursor: SystemMouseCursors.click,
            ),
          );
        }
        return CurrentTransceiverTile(
          displayName: so2r ? st.so2rRadioName(radio: 'A', name: _displayName(node)) : _displayName(node),
          connection: connectionTextFor(context, _cat.typeFor(node), node.config),
          transportType: _cat.typeFor(node),
          state: _cat.stateFor(node.uuid),
          unconfigured: _cat.typeFor(node)?.isUnconfigured(node.config) ?? false,
          onEdit: () => _editEquipment(context, node),
          onConnect: () => _cat.connect(node.uuid),
          onDisconnect: () => _cat.disconnect(node.uuid),
          picker: picker,
        );
      },
    );
  }

  /// SO2R's Radio B, under the Main VFO's row: the same row, picked from this
  /// station's own transceivers only — never the Main VFO's, which one rig
  /// cannot be at the same time.
  Widget _radio2Row(BuildContext context) {
    final st = context.t.settings.station;
    return TransceiverMenu(
      rows: (context, close) {
        void pick(String? uuid) {
          close();
          unawaited(_cat.setRadio2(uuid));
        }

        return [
          for (final node in _cat.nodes)
            if (_cat.typeFor(node)?.category == kCategoryTransceiver && !_cat.isRadio1(node.uuid))
              TransceiverRow(
                name: _displayName(node),
                channel: _cat.typeFor(node)?.describeChannel(node.config),
                connection: connectionTextFor(context, _cat.typeFor(node), node.config),
                transportType: _cat.typeFor(node),
                selected: _cat.isRadio2(node.uuid),
                onSelect: () => pick(node.uuid),
                onEdit: () => pick(node.uuid),
              ),
          TransceiverRow(name: st.noTransceiver, connection: '', selected: _cat.radio2 == null, onSelect: () => pick(null), onEdit: () => pick(null)),
        ];
      },
      builder: (context, toggle) {
        final picker = SizedBox.square(
          dimension: transceiverPickerWidth,
          child: IconButton(
            icon: Icon(MdiIcons.menuDown, semanticLabel: st.chooseTransceiver),
            onPressed: toggle,
          ),
        );
        final uuid = _cat.radio2;
        final node = uuid == null ? null : _cat.nodeFor(uuid);
        if (node == null) {
          return CurrentRowFrame(
            leading: picker,
            child: ListTile(
              leading: const TransceiverGlyph.bare(inUse: false),
              title: Text(st.noRadioBSelected),
              onTap: toggle,
              mouseCursor: SystemMouseCursors.click,
            ),
          );
        }
        return CurrentTransceiverTile(
          displayName: st.so2rRadioName(radio: 'B', name: _displayName(node)),
          connection: connectionTextFor(context, _cat.typeFor(node), node.config),
          transportType: _cat.typeFor(node),
          state: _cat.stateFor(node.uuid),
          unconfigured: _cat.typeFor(node)?.isUnconfigured(node.config) ?? false,
          onEdit: () => _editEquipment(context, node),
          onConnect: () => _cat.connect(node.uuid),
          onDisconnect: () => _cat.disconnect(node.uuid),
          picker: picker,
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
        final detailsInset = EdgeInsets.only(left: currentRowDetailsInset(context), right: rowInset.right);
        // The current rig's ground, half way back to the surface, so the rig
        // reads as the band's content rather than more heading — and its
        // details, under it, as the rig's.
        final rigGround = Color.lerp(Theme.of(context).colorScheme.surface, haloCategoryBandColor(context), 0.5)!;
        final nodes = _cat.nodes;
        final antennas = [
          for (final node in nodes)
            if (_cat.typeFor(node)?.category == kCategoryAntenna) node,
        ];
        // The key in use: a paddle on the desk, or what keys for the app —
        // a keyer, or a radio whose CAT can. One pick, because a station
        // with more than one has to say which one the messages go through.
        final keyerExperiment = services.settings.experimentEnabled('keyer') /* stored key, see experiments.yaml */;
        final keys = keyNodes(services);
        final offersKey = keys.isNotEmpty || (keyerExperiment && _cat.peerOffersCwKeying);
        // A peer's radio plays what its own station picked, so its line is
        // there for the messages, not the pick. Recordings on this computer
        // need no radio: they are recorded before the rig is on the desk.
        final offersPhone = keyerExperiment && (!_cat.voiceMessagesAreLocal || _cat.radio1OffersVoiceMemories || _cat.computerVoiceAudio != null);
        // Radio B's own line, under its antenna and key: its rig's memories,
        // or the computer's recordings through its rig's sound device.
        final offersPhoneB = keyerExperiment && (_cat.keyer('B').offersVoiceMemories || _cat.computerVoiceAudio != null);
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
        final so2r = services.settings.experimentEnabled('so2r') /* stored key, see experiments.yaml */;
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

        final keyOutside = services.settings.trackStationInfo && services.settings.stationInfoTrackedFields.contains('key');
        final keyLine = _keyingLine(
          picker: cwKeyPicker(
            context,
            services,
            keys: keys,
            label: so2r ? st.so2rRadioName(radio: 'A', name: st.keyInUse) : st.keyInUse,
          ),
          controls: [if (keyerExperiment) cwKeyingOptionsButton(context)],
        );
        final details = [
          // Whether HaLo adjusts each radio in use's bandscope — only where the
          // scope it draws is the radio's own screen (an Icom's), so what HaLo
          // does to it shows on the front panel too.
          ?_scopeAdjustRow(context, localRadio1, radio: so2r ? 'A' : null, inset: detailsInset),
          // The key when it is not tracked, and under it what keys phone.
          if ((!keyOutside && offersKey) || offersPhone)
            Padding(
              padding: EdgeInsets.fromLTRB(detailsInset.left, 0, detailsInset.right, Space.md),
              child: Column(
                spacing: Space.md,
                children: [
                  if (!keyOutside && offersKey) keyLine,
                  if (offersPhone) _phoneKeyingLine(context, radio: 'A'),
                ],
              ),
            ),
          if (so2r && _cat.radio2 != null && (antennas.isNotEmpty || keys.isNotEmpty))
            _radio2Picks(context, antennas: antennas, keys: keys, inset: detailsInset),
          if (so2r) ?_scopeAdjustRow(context, _cat.radio2, radio: 'B', inset: detailsInset),
          if (so2r && _cat.radio2 != null && offersPhoneB)
            Padding(
              padding: EdgeInsets.fromLTRB(detailsInset.left, 0, detailsInset.right, Space.md),
              child: _phoneKeyingLine(context, radio: 'B'),
            ),
          if (so2r && _cat.radio2 != null && (_cat.so2rSwitchNodes.isNotEmpty || _cat.so2rAudioRadio != null)) _so2rSwitchLine(context, inset: detailsInset),
          if (so2r && _cat.radio2 != null && keyerExperiment) _so2rQueueRow(context, inset: detailsInset),
        ];

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
                so2r ? st.currentTransceivers : st.currentTransceiver,
                below: Material(
                  color: rigGround,
                  child: so2r
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _currentTransceiverRow(context, localRadio1: localRadio1, selection: selection, absentSelection: absentSelection),
                            _radio2Row(context),
                          ],
                        )
                      : _currentTransceiverRow(context, localRadio1: localRadio1, selection: selection, absentSelection: absentSelection),
                ),
              ),
              // Which antenna and key a QSO's captured station info should
              // credit, on the rig's ground under it — out of the fold: the
              // antenna always, the key when the operator tracks it, since
              // then it changes as often as the antenna does. The key row also
              // offers a peer's key, though it is no node of this station: the
              // phone this is for has no key inventory of its own, and without
              // it its operator could not step off the peer's key.
              if (antennas.isNotEmpty || (keyOutside && offersKey))
                ColoredBox(
                  color: rigGround,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(detailsInset.left, Space.md, detailsInset.right, Space.md),
                    child: Column(
                      spacing: Space.md,
                      children: [
                        if (antennas.isNotEmpty)
                          DesignationDropdown(
                            key: ValueKey(_cat.designatedFor(kCategoryAntenna)),
                            label: so2r ? st.so2rRadioName(radio: 'A', name: st.antennaInUse) : st.antennaInUse,
                            nodes: antennas,
                            selected: _cat.designatedFor(kCategoryAntenna),
                            displayName: _displayName,
                            noneLabel: st.noneSelected,
                            onChanged: (uuid) => unawaited(_cat.setDesignated(kCategoryAntenna, uuid)),
                          ),
                        if (keyOutside && offersKey) keyLine,
                      ],
                    ),
                  ),
                ),
              // The rest of the rig's details, on its ground, indented under
              // it and folded until asked for. Absent when there is nothing to
              // fold: a heading over no rows opens onto nothing.
              if (details.isNotEmpty) ...[
                SectionHeader(
                  st.configurationSection,
                  indent: detailsInset.left - rowInset.left,
                  background: rigGround,
                  expanded: expanded.contains(_detailsSection),
                  onTap: () => toggle(_detailsSection),
                ),
                ColoredBox(
                  color: rigGround,
                  // The gap under the heading is the column's, and every row
                  // brings only the gap below it: whichever row comes first.
                  child: Padding(
                    padding: const EdgeInsets.only(top: Space.md),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: details),
                  ),
                ),
              ],
              // Room at the foot of the rig's ground, before the inventory —
              // slivers of its own, so folding the details does not fold it.
              SectionedSlivers(
                slivers: [
                  SliverToBoxAdapter(
                    child: ColoredBox(
                      color: rigGround,
                      child: const SizedBox(height: Space.lg),
                    ),
                  ),
                ],
              ),
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
                // The SO2R switcher, when it is a device of its own.
                if (_cat.so2rSwitch case final uuid? when uuid != so2rSwitchRadios)
                  if (_cat.nodeFor(uuid) case final node?)
                    EquipmentTile(
                      node: node,
                      type: _cat.typeFor(node),
                      state: _cat.stateFor(uuid),
                      developerMode: services.settings.developerMode,
                      displayName: _displayName(node),
                      isMainVfo: false,
                      onEdit: () => _editEquipment(context, node),
                      onRemoveUnknown: () => _removeEquipment(context, node),
                      onConnect: () => _cat.connect(uuid),
                      onDisconnect: () => _cat.disconnect(uuid),
                    ),
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
                        plug: _plugFor(node),
                        state: _cat.stateFor(node.uuid),
                        unconfigured: _cat.typeFor(node)?.isUnconfigured(node.config) ?? false,
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

  /// The SO2R switcher — what puts the two radios in the headphones — and
  /// beside it the button to its settings, once one is picked
  /// (docs/design/cat.md § The SO2R switcher).
  Widget _so2rSwitchLine(BuildContext context, {required EdgeInsets inset}) {
    final st = context.t.settings.station;
    final radio = _cat.so2rAudioRadio;
    return Padding(
      padding: EdgeInsets.fromLTRB(inset.left, 0, inset.right, Space.md),
      child: _keyingLine(
        picker: DesignationDropdown(
          key: ValueKey('so2rSwitch:${_cat.so2rSwitch}:${radio?.uuid}'),
          label: st.so2rSwitch,
          nodes: _cat.so2rSwitchNodes,
          selected: _cat.so2rSwitch,
          displayName: _displayName,
          noneLabel: st.noneSelected,
          extras: [if (radio != null) (value: so2rSwitchRadios, label: st.so2rSwitchBuiltIn(radio: _displayName(radio)))],
          onChanged: (pick) => unawaited(_cat.setSo2rSwitch(pick)),
        ),
        controls: [
          IconButton(
            icon: Icon(MdiIcons.tune, semanticLabel: st.so2rSwitchSettings),
            // Not for a pick the dropdown cannot show: the radios no longer
            // slices of one, which reads as None.
            onPressed: _cat.so2rSwitch == null || (_cat.so2rSwitch == so2rSwitchRadios && radio == null)
                ? null
                : () => showSo2rSwitchSettingsDialog(context, services.settings),
          ),
        ],
      ),
    );
  }

  /// How the two radios take the air (docs/design/cat.md § Radio B, for
  /// SO2R): a message keyed for one while the other is sending waits for it,
  /// or stops it.
  Widget _so2rQueueRow(BuildContext context, {required EdgeInsets inset}) {
    final settings = services.settings;
    final label = context.t.settings.station.so2rQueueMessages;
    return Padding(
      padding: EdgeInsets.fromLTRB(inset.left, 0, inset.right, Space.md),
      child: Row(
        children: [
          ListenableBuilder(
            listenable: settings,
            builder: (context, _) => Semantics(
              label: label,
              child: Switch(value: settings.so2rQueueMessages, onChanged: (queue) => unawaited(settings.setSo2rQueueMessages(queue))),
            ),
          ),
          const SizedBox(width: Space.sm),
          Flexible(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }

  /// SO2R's Radio B's own antenna and key, under the Main VFO's: the picks
  /// are per radio, and a contact logged on Radio B — or a message keyed from
  /// its set — uses these.
  Widget _radio2Picks(BuildContext context, {required List<EquipmentNode> antennas, required List<EquipmentNode> keys, required EdgeInsets inset}) {
    final st = context.t.settings.station;
    final radio2 = _cat.radio2!;
    Widget picker(String category, String label, List<EquipmentNode> nodes, {String Function(EquipmentNode)? displayName}) => Expanded(
      child: DesignationDropdown(
        key: ValueKey('radio2:$category:${_cat.designatedFor(category, radio: radio2)}'),
        label: st.so2rRadioName(radio: 'B', name: label),
        nodes: nodes,
        selected: _cat.designatedFor(category, radio: radio2),
        displayName: displayName ?? _displayName,
        noneLabel: st.noneSelected,
        onChanged: (uuid) => unawaited(_cat.setDesignated(category, uuid, radio: radio2)),
      ),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(inset.left, 0, inset.right, Space.md),
      child: Row(
        children: [
          if (antennas.isNotEmpty) picker(kCategoryAntenna, st.antennaInUse, antennas),
          if (antennas.isNotEmpty && keys.isNotEmpty) const SizedBox(width: Space.md),
          if (keys.isNotEmpty)
            picker(
              kCategoryKey,
              st.keyInUse,
              // Never radio A's key: one key keys one radio's messages.
              [
                for (final node in keys)
                  if (node.uuid != _cat.designatedFor(kCategoryKey)) node,
              ],
              displayName: (node) => _cat.typeFor(node)?.category == kCategoryTransceiver ? st.keyViaRadio(radio: _displayName(node)) : _displayName(node),
            ),
        ],
      ),
    );
  }

  /// A keying line: its picker, then the controls that go with it.
  Widget _keyingLine({required Widget picker, required List<Widget> controls}) => Row(
    children: [
      Expanded(child: picker),
      for (final control in controls) ...[const SizedBox(width: Space.sm), control],
    ],
  );

  /// Where [radio]'s (`A` or `B`) phone messages come from
  /// ([phoneKeyingParts]).
  Widget _phoneKeyingLine(BuildContext context, {required String radio}) {
    final parts = phoneKeyingParts(context, services, radio: radio);
    return _keyingLine(picker: parts.picker, controls: parts.controls);
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
