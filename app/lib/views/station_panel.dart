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

import '../i18n/strings.g.dart';
import '../services/halo_services.dart';
import 'accordion_section.dart';
import '../settings/settings_target_dialog.dart';
import '../services/cat/discovery.dart';
import '../services/cat/equipment.dart';
import '../services/cat/telemetry_poller.dart';
import '../services/cat/drivers/antenna_genius_driver.dart';
import '../services/cat/equipment_registry.dart';
import '../services/cat/transports/none_transport.dart';
import '../services/cat/cat_service.dart';
import '../services/peer/peer_remote_radios.dart';
import '../services/peer/peer_station_radios.dart';
import '../services/settings_service.dart';
import '../tools/form_chrome_labels.dart';
import 'cw_messages_dialog.dart';
import 'voice_messages_dialog.dart';
import 'equipment_report.dart';

/// Shown as the HINT of a secret field whose value is already in the keychain,
/// never as its value: a hint cannot be submitted, cannot be revealed by the
/// field's show/hide eye, and leaves the field genuinely empty — which is what
/// CatService reads as "keep what is stored".
///
/// A fixed count, deliberately. Matching the real length would leak it.
const _storedSecretPlaceholder = '••••••••';

/// The inset the rows of this panel take: the ambient `ListTileTheme`, which
/// in the settings pane is the `SettingsList` one plus the pane's centring
/// offset, and which every `ListTile`, [SectionHeader] and [FormRenderer] row
/// here already reads for itself.
///
/// The hand-built rows below have to ask for it: one that names a spacing
/// rung instead spans the whole pane while the list rows above and below it
/// are centred in it.
///
/// The fallback is a `ListTile`'s own — this panel also presents with no
/// ambient theme at all (`compact`, in a modal pane), and there the rows to
/// line up with are plain tiles at Material's inset.
EdgeInsets _rowInset(BuildContext context) =>
    (ListTileTheme.of(context).contentPadding ?? const EdgeInsets.symmetric(horizontal: Space.xl))
        .resolve(Directionality.of(context));

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
  /// under All Settings: current configuration only, the inventory row for
  /// whichever rig is designated (not the whole catalogue), a Power field,
  /// and a footer offering the full page instead of Add Equipment/Other
  /// Options inline.
  final bool compact;

  /// Compact mode's way to the full page — required exactly when [compact]
  /// is true. A callback rather than a hardcoded `SettingsView` push: this
  /// file and settings_view.dart already import each other for the reverse
  /// embedding, and a second cross-import isn't worth it for one button.
  final VoidCallback? onMoreSettings;

  const StationPanel({super.key, required this.services, this.compact = false, this.onMoreSettings})
      : assert(!compact || onMoreSettings != null, 'compact mode needs onMoreSettings');

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

    final model = choice.model!;
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

  Future<_AddChoice?> _showAddDialog(BuildContext context, {required bool showDiscovery}) {
    return showHaloDialog<_AddChoice>(
      context: context,
      builder: (context) => _AddEquipmentDialog(
        cat: _cat,
        showDiscovery: showDiscovery,
        showAntennaAndKey: services.settings.trackStationInfo &&
            services.settings.stationInfoTrackedFields.any((f) => f == 'antenna' || f == 'key'),
        showKeyer: services.settings.experimentEnabled('keyer') /* stored key, see experiments.yaml */,
        supportedVariants: _supportedVariants,
      ),
    );
  }

  /// The pairings of [model] this platform could actually connect — web has
  /// no raw sockets and no serial, so a model can be reachable everywhere
  /// but here.
  List<EquipmentType> _supportedVariants(EquipmentModel model) => [
        for (final variant in model.variants)
          if (_cat.registry.typeFor(variant.key) case final type?)
            if (type.isSupportedOnThisPlatform) type,
      ];

  Future<void> _editEquipment(BuildContext context, EquipmentNode node) async {
    final type = _cat.typeFor(node);
    if (type == null) return;

    final values =
        await _editValues(context, model: type.model, type: type, name: node.name, config: node.config, node: node);
    // Null also means the editor removed the node, or was cancelled — either
    // way there is nothing left to write back.
    if (values == null) return;

    await _cat.updateNode(
      node.copyWith(typeKey: values.typeKey, name: values.name, config: values.config),
    );
  }

  /// [variant]'s config fields, with the channel picker's options saying
  /// what each channel is doing right now.
  ///
  /// Only for a node that is CONNECTED: the inventory is live state, and a
  /// disconnected node has none, so its picker reads as the plain list of
  /// letters it was before. That asymmetry is the point — an operator
  /// choosing between a Flex's slices wants to know which one SmartSDR on
  /// the other machine already has, and the alternative is picking blind.
  ///
  /// Labels only. The values are the driver's, so a form saved while the
  /// annotation was showing stores exactly what one saved without it does.
  List<Map<String, dynamic>> _annotateChannels(
    EquipmentType variant,
    EquipmentNode? node,
    BuildContext context,
  ) {
    final elements = variant.configElements();
    final channelKey = variant.driver.channelKey;
    if (channelKey == null || node == null) return elements;
    final channels = _cat.stateFor(node.uuid).channels;
    if (channels.isEmpty) return elements;

    final byKey = {for (final channel in channels) channel.key: channel};
    return [
      for (final element in elements)
        if (element['key'] != channelKey || element['options'] is! List)
          element
        else
          {
            ...element,
            'options': [
              for (final option in (element['options'] as List).cast<Map<String, dynamic>>())
                if (byKey[option['value']] case final channel?)
                  {...option, 'label': '${option['label']}${_describeChannel(channel, context)}'}
                else
                  option,
            ],
          },
    ];
  }

  /// What to append to a channel's own label — what it is tuned to, and who
  /// has it. Empty when the equipment said nothing worth adding, so an
  /// unremarkable channel does not grow a trailing separator.
  String _describeChannel(EquipmentChannel channel, BuildContext context) {
    final st = context.t.settings.station;
    if (!channel.inUse) return ' — ${st.channelNotInUse}';
    final parts = [
      if (channel.freqKHz != null) fmtFreq(channel.freqKHz!),
      ?channel.mode,
      // Named where the equipment named them, and said to be held either
      // way: an owner we could not resolve must not read as a free channel,
      // which is the one answer this list exists to prevent.
      channel.usedBy ?? (channel.heldByUnknown ? st.channelHeldByUnknown : null),
    ].nonNulls;
    return parts.isEmpty ? '' : ' — ${parts.join(' · ')}';
  }

  /// How one of a switch's antenna ports is named in the editor: its number,
  /// and the switch's own name for it where there is one — "1 - Hex".
  ///
  /// The number always, because it is what is printed beside the socket on
  /// the back of the box. The name because "port 1" means nothing to an
  /// operator who has three antennas and knows them by name. Neither alone
  /// is enough to match a row to a piece of coax.
  String _switchPortName(SwitchAntenna antenna) =>
      antenna.name.isEmpty || antenna.name == antenna.key ? antenna.key : '${antenna.key} - ${antenna.name}';

  /// The Current State section: one picker per device port, saying what that
  /// port is on and changing it on the spot.
  ///
  /// Only for a connected switch, since this is its state rather than its
  /// configuration — and only in the editor, because the equipment list is a
  /// list of what the station is made of, not a control surface.
  ///
  /// These fields never reach the stored record; see
  /// [switchPortRoutingFormKey]. They also do not follow the switch while
  /// the editor is open: FormRenderer reads an initial value once, and a
  /// port that band-follows underneath the pane will show what it was on
  /// when the pane opened.
  List<Map<String, dynamic>> _switchCurrentState(BuildContext context, EquipmentNode? node) {
    if (node == null) return const [];
    final state = _cat.stateFor(node.uuid);
    if (state.status != EquipmentStatus.connected || state.switchPorts.isEmpty) return const [];
    final st = context.t.settings.station;

    final choices = _routableAntennas(state.switchAntennas);
    if (choices.isEmpty) return const [];

    return [
      {
        'type': 'header',
        'style': 'section',
        'title': st.switchCurrentStateHeader,
        'subtitle': st.switchCurrentStateDescription,
      },
      for (final port in state.switchPorts)
        {
          'type': 'field',
          'fieldType': 'select',
          'key': switchPortRoutingFormKey(port.key),
          'label': st.switchPortLabel(port: port.label),
          if (_switchPortDetail(port, st) case final detail?) 'description': detail,
          // A keyed port is refused by the driver as well — this only keeps
          // the operator from being offered a control whose answer is going
          // to be "not while you are transmitting".
          if (port.transmitting) 'disabled': true,
          'options': [
            for (final antenna in choices)
              {'value': antenna.key, 'label': _switchAntennaLabel(node, antenna)},
          ],
        },
    ];
  }

  /// The Wiring section: how the switch is arranged, and which of the
  /// operator's antennas is on each of its ports.
  ///
  /// The layout field is the driver's own — pulled out of the connection
  /// block above and re-emitted here, so it sits with the antenna links it
  /// belongs with rather than beside the host and port. [buildElements]
  /// filters it out of the variant loop by the same key; the two have to
  /// agree, which is why both go through [switchLayoutConfigKey] rather than
  /// either spelling it.
  List<Map<String, dynamic>> _switchWiring(
    BuildContext context,
    EquipmentType type,
    EquipmentNode? node,
  ) {
    final st = context.t.settings.station;
    final layout = [
      for (final element in _annotateSwitchLayout(
        type.driver.configElements(overrides: type.overrides, restrictions: type.restrictions),
        node,
        context,
      ))
        if (element['key'] == switchLayoutConfigKey) element,
    ];
    return [
      {'type': 'header', 'style': 'section', 'title': st.switchWiringHeader},
      ...layout,
      ..._switchAntennaLinks(context, type, node),
    ];
  }

  /// What to say under a device port's picker: which radio feeds it, where
  /// that radio is, and whether the switch will overrule the choice above.
  ///
  /// The switch volunteers all of this — it names the radio a port follows,
  /// and that radio's band and frequency — so the section answers "what is
  /// this port doing" rather than only "what is it connected to".
  ///
  /// The auto fragment earns its place: a band-following port overrules the
  /// operator's choice at the next band change, and one that reverted with
  /// no explanation reads as the app having failed to send the command.
  ///
  /// Null when there is nothing to add, so an idle port grows no empty line.
  String? _switchPortDetail(SwitchPort port, Translations$settings$station$en st) {
    if (port.transmitting) return st.switchPortTransmittingHint;
    final parts = [
      // An interlock: the other port is holding the antenna this one wants,
      // so it cannot transmit. First, because it is the one thing here that
      // says something is wrong rather than merely what is going on.
      if (port.inhibited) st.switchPortInhibitedHint,
      ?port.radioName,
      ?port.band,
      if (port.freqKHz != null) fmtFreq(port.freqKHz!),
      if (port.auto) st.switchPortAutoHint,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// Which of a switch's antenna ports are worth offering.
  ///
  /// Unconfigured ports are dropped rather than shown: an 8x2 with three
  /// antennas set up still reports all eight, and the five placeholders named
  /// `Antenna_4` upwards are not somewhere to route to.
  ///
  /// Unless NONE of them is configured, which is what a factory-fresh switch
  /// looks like — every port carrying an all-zero band mask. Filtering there
  /// makes connecting the hardware REMOVE the setup fields the operator had
  /// while it was disconnected, which is backwards. With nothing configured
  /// there is also nothing to distinguish, so the filter has no information
  /// to act on and should not act.
  List<SwitchAntenna> _routableAntennas(List<SwitchAntenna> reported) {
    final configured = [
      for (final antenna in reported)
        if (antenna.configured) antenna,
    ];
    return configured.isEmpty ? reported : configured;
  }

  /// A link field per antenna port on a switch, over the operator's own
  /// antenna nodes.
  ///
  /// Ports come from what the switch has actually reported when it is
  /// connected, and from [EquipmentDriver.antennaPortCount] when it is not.
  /// The fallback is the case that matters: an operator sets a switch up
  /// before they have ever connected it, and a form offering nothing to map
  /// would look like the feature was missing.
  ///
  /// Named by the switch's own port name where it has said one, so the
  /// operator matches the row to the label on the box rather than counting.
  List<Map<String, dynamic>> _switchAntennaLinks(
    BuildContext context,
    EquipmentType type,
    EquipmentNode? node,
  ) {
    final st = context.t.settings.station;
    final reported = node == null ? const <SwitchAntenna>[] : _cat.stateFor(node.uuid).switchAntennas;
    final ports = reported.isNotEmpty
        ? reported
        : [
            // No name to show: nothing has told us one yet, and inventing
            // "Antenna 1" would look like something the switch reported.
            for (var i = 1; i <= type.driver.antennaPortCount; i++) SwitchAntenna(key: '$i', name: ''),
          ];

    final antennas = [
      for (final candidate in _cat.nodes)
        if (_cat.typeFor(candidate)?.category == kCategoryAntenna) candidate,
    ];

    return [
      for (final port in _routableAntennas(ports))
          {
            'type': 'field',
            'fieldType': 'select',
            'key': switchAntennaNodeConfigKey(port.key),
            'label': st.switchAntennaFor(port: _switchPortName(port)),
            'description': st.switchAntennaForDescription,
            'options': [
              {'value': '', 'label': st.switchNoAntenna},
              for (final antenna in antennas)
                {'value': antenna.uuid, 'label': _displayName(antenna)},
            ],
          },
    ];
  }

  /// [elements] with the wiring picker's two options counted from what the
  /// switch actually reported, rather than from the catalogue's defaults.
  ///
  /// The driver labels them for an 8x2 because that is all it can know
  /// before anything is connected. An 8x1 reports one device port and would
  /// otherwise be offered "8 Antennas, 2 Radios" — a count of something the
  /// operator can see is wrong, on the one field whose whole job is matching
  /// the box in front of them.
  ///
  /// Labels only, like [_annotateChannels]: the values stay the driver's, so
  /// a form saved while connected stores exactly what one saved without a
  /// connection does.
  List<Map<String, dynamic>> _annotateSwitchLayout(
    List<Map<String, dynamic>> elements,
    EquipmentNode? node,
    BuildContext context,
  ) {
    if (node == null) return elements;
    final state = _cat.stateFor(node.uuid);
    final antennas = state.switchAntennas.length;
    final radios = state.switchPorts.length;
    if (antennas == 0 || radios == 0) return elements;
    final st = context.t.settings.station;

    return [
      for (final element in elements)
        if (element['key'] != switchLayoutConfigKey || element['options'] is! List)
          element
        else
          {
            ...element,
            'options': [
              for (final option in (element['options'] as List).cast<Map<String, dynamic>>())
                switch (option['value']) {
                  switchLayoutDevicePorts =>
                    {...option, 'label': st.switchLayoutSides(antennas: antennas, radios: radios)},
                  switchLayoutAntennaPorts =>
                    {...option, 'label': st.switchLayoutSides(antennas: radios, radios: antennas)},
                  _ => option,
                },
            ],
          },
    ];
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
    final variants = _supportedVariants(model);
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
          if (choosable)
            {
              'type': 'field',
              'fieldType': 'select',
              'key': 'transport',
              'label': st.transport,
              'description': st.transportDescription,
              'options': [
                for (final candidate in variants)
                  {
                    'value': candidate.transportKey,
                    // The short marker, not the sentence the Add list uses: a
                    // dropdown item is one unwrapped row, and the full wording
                    // overflows it.
                    'label': candidate.hardwareVerified
                        ? candidate.transportLabel
                        : '${candidate.transportLabel} (${st.unverifiedShort})',
                  },
              ],
            },
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
          if (model.category == kCategoryAntennaSwitch) ...[
            ..._switchCurrentState(context, node),
            ..._switchWiring(context, type, node),
          ],
        ];

    final result = await showFormPane(
      context,
      // The radio, not the pairing: how it is connected is a field inside the
      // form now, so putting it in the title too would contradict itself the
      // moment the operator changed it.
      formDefinition: {'title': model.name, 'elements': buildElements()},
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
          for (final port in _cat.stateFor(node.uuid).switchPorts)
            if (port.selectedAntennaKey case final selected?)
              switchPortRoutingFormKey(port.key): selected,
      },
      // Runs per field on submit, so a bad address blocks the save and says
      // so on the address field rather than failing later at connect time.
      // Asks the pairing the form is currently on: a field belonging to a
      // transport the operator switched away from is not theirs to get right.
      validator: (key, value, values) async =>
          isSwitchPortRoutingFormKey(key) ? null : typeForState(values).validateField(key, value, values),
      // The one field kind that acts as it is touched rather than on save:
      // routing a port is a command to the switch, and an operator who
      // cancels the pane has still moved the relay. Returning no updates
      // leaves the form's own value where the operator put it; the switch's
      // confirmation lands in the panel behind.
      onChange: (key, value, values) async {
        if (node == null || !isSwitchPortRoutingFormKey(key)) return null;
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
              onPressed: () => unawaited(showEquipmentReportDialog(
                context,
                services: services,
                node: node,
                type: type,
                state: _cat.stateFor(node.uuid),
              )),
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
      labels: formRendererLabelsFor(context.t),
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
        ...config,
        for (final entry in result.entries)
          // The routing pickers are the switch's live state, not settings.
          // Storing one would put a stale claim about a relay into the
          // record, and the panel would then have two answers to which
          // antenna is live.
          if (entry.key != 'name' && entry.key != 'transport' && !isSwitchPortRoutingFormKey(entry.key))
            entry.key: entry.value,
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
    return Column(children: [Expanded(child: content), _compactFooter(context)]);
  }

  /// The dropdown's value for a peer radio. Namespaced because the list is
  /// shared with local nodes and both are keyed by a uuid — one that means
  /// "a node in THIS station" and one that does not.
  static String? _peerValue(PeerRadioSelection? selection) =>
      selection == null ? null : peerRadioValue(selection);

  static PeerRadioSelection _selectionFor(PeerRemoteRadio peer) => PeerRadioSelection(
        deviceId: peer.deviceId,
        radioId: peer.radio.id,
        deviceName: peer.deviceName,
        radioName: peer.radio.name,
      );

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
    return _cat.setRadio1(PeerRadio(PeerRadioSelection(
      deviceId: picked.deviceId,
      radioId: picked.radioId,
      deviceName: offered?.deviceName ?? kept?.deviceName ?? '',
      radioName: offered?.radio.name ?? kept?.radioName ?? '',
    )));
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
        // Every transceiver the station knows about, connected or not —
        // this is the station's configuration, not its current link state.
        final transceivers = [
          for (final node in nodes)
            if (_cat.typeFor(node)?.category == kCategoryTransceiver) node,
        ];
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
        final absentSelection = selection != null &&
                !peerRadios.any((r) => selection.matches(r.deviceId, r.radio.id))
            ? selection
            : null;

        return ListView(
          padding: const EdgeInsets.only(bottom: Space.md),
          children: [
            // What the station IS right now: the choices that decide how the
            // rest of the app behaves. Today that is one question.
            SectionHeader(st.currentConfiguration),
            Padding(
              // Trailing edge short by the tune button's own padding, so the
              // glyph lands on the inset rather than the button's box does.
              padding: EdgeInsets.fromLTRB(rowInset.left, Space.md, math.max(0.0, rowInset.right - Space.lg), Space.md),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                // FormFieldState reads `initialValue` once and never again
                // (its didUpdateWidget only handles forceErrorText), so
                // without a key that changes with the value this dropdown
                // shows whatever radio1 was on first build. CatService
                // reassigns it behind this panel's back — auto-designating
                // the first transceiver added, and re-designating when the
                // current one is removed — and neither would have appeared.
                      key: ValueKey(localRadio1 ?? _peerValue(selection)),
                      // Without this the button lays its SELECTED item out
                      // unbounded, so ellipsizing the menu entries is not
                      // enough — a name wider than the field overflows the
                      // row rather than truncating.
                      isExpanded: true,
                      initialValue: transceivers.any((n) => n.uuid == localRadio1)
                          ? localRadio1
                          : _peerValue(selection),
                      icon: dropdownTrailingIcon,
                      decoration: poloFieldDecoration(context, st.transceiverForMainVfo),
                      menuMaxHeight: dropdownMenuMaxHeight(context),
                      items: [
                        DropdownMenuItem<String?>(value: null, child: Text(st.noTransceiver)),
                        for (final radio in transceivers)
                          DropdownMenuItem<String?>(
                            value: radio.uuid,
                            // Ellipsized: a DropdownMenuItem lays its child out
                            // unbounded, so a name longer than the field is wide
                            // — the operator's own, or a default like "Generic
                            // Radio via rigctld" — overflows the row rather
                            // than truncating.
                            child: Text(_displayName(radio), overflow: TextOverflow.ellipsis),
                          ),
                        for (final peer in peerRadios)
                          DropdownMenuItem<String?>(
                            value: _peerValue(_selectionFor(peer)),
                            child: Text(
                              st.peerTransceiver(radio: peer.radio.name, device: peer.deviceName),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        if (absentSelection != null)
                          DropdownMenuItem<String?>(
                            value: _peerValue(absentSelection),
                            child: Text(
                              st.peerTransceiverUnavailable(
                                radio: absentSelection.radioName.isEmpty
                                    ? absentSelection.radioId
                                    : absentSelection.radioName,
                                device: absentSelection.deviceName.isEmpty
                                    ? absentSelection.deviceId
                                    : absentSelection.deviceName,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) => unawaited(_onMainVfoPicked(value)),
                    ),
                  ),
                  // How the app behaves towards whichever radio is selected
                  // above — not that radio's own configuration, which is
                  // inside its row in the inventory below. Same tune glyph
                  // and the same target-built dialog the logging panel uses.
                  Builder(
                    builder: (buttonContext) => IconButton(
                      // The app shows no hover tooltips
                      // (docs/design/user-interface.md), so the accessible
                      // name is the only place this button is named.
                      icon: Icon(MdiIcons.tune, semanticLabel: st.currentRadioSettings),
                      onPressed: () => showSettingsForTarget(
                        buttonContext,
                        services: services,
                        target: 'current-radio',
                        title: st.currentRadioSettings,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Which antenna/key a QSO's captured station info should credit
            // — only once there's inventory to choose between; both share a
            // row since neither needs the tune button beside the main VFO.
            if (antennas.isNotEmpty || keys.isNotEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(rowInset.left, 0, rowInset.right, Space.md),
                child: Row(
                  children: [
                    if (antennas.isNotEmpty)
                      Expanded(
                        child: _DesignationDropdown(
                          key: ValueKey(_cat.designatedFor(kCategoryAntenna)),
                          label: st.antennaInUse,
                          nodes: antennas,
                          selected: _cat.designatedFor(kCategoryAntenna),
                          displayName: _displayName,
                          noneLabel: st.noneSelected,
                          onChanged: (uuid) => unawaited(_cat.setDesignated(kCategoryAntenna, uuid)),
                        ),
                      ),
                    if (antennas.isNotEmpty && keys.isNotEmpty) const SizedBox(width: Space.md),
                    if (keys.isNotEmpty)
                      Expanded(
                        child: _DesignationDropdown(
                          key: ValueKey(_cat.designatedFor(kCategoryKey)),
                          label: st.keyInUse,
                          nodes: keys,
                          selected: _cat.designatedFor(kCategoryKey),
                          // A radio in this list is its keyer, not the radio.
                          displayName: (node) => _cat.typeFor(node)?.category == kCategoryTransceiver
                              ? st.keyViaRadio(radio: _displayName(node))
                              : _displayName(node),
                          noneLabel: st.noneSelected,
                          onChanged: (uuid) => unawaited(_cat.setDesignated(kCategoryKey, uuid)),
                        ),
                      ),
                  ],
                ),
              ),

            // The CAT keyer: speed on the radio, messages in the app. In BOTH
            // layouts, unlike the Power field — the speed and the messages
            // belong to the key picked directly above, so a full page that
            // named the key and then had nothing to say about it would send
            // the operator to the compact dialog to finish the job.
            if (keyerExperiment && _cat.designatedKeyIsKeyer)
              _cwKeyerRow(context, inset: rowInset),

            // The voice keyer: radio1's own memories, whatever the key in
            // use — so its row stands on its own, and only while radio1 is
            // connected and has memories to name (a label is a setting, but
            // the row that has nowhere to play is not worth the space).
            if (keyerExperiment && _cat.canPlayVoice)
              _voiceKeyerRow(context, inset: rowInset),

            // What the station is made OF. Compact shows only what is in use
            // — the rig driving the main VFO, and the key if it is a device
            // of its own — as quick-glance connect/status rows, not the whole
            // catalogue Add Equipment and the other radios imply.
            SectionHeader(compact ? st.equipmentInUse : st.equipmentInventory),
            if (compact) ...[
              // A peer's radio drives the same one `vfoA` a local one does,
              // so it belongs in this section — which is the only place the
              // compact dialog names what the logging panel is following.
              // Nothing to connect or edit here: the session, and the rig,
              // are the other device's.
              if (_cat.radio1 case PeerRadio(selection: final peerSelection))
                _PeerVfoTile(selection: peerSelection, available: absentSelection == null),
              if (localRadio1 case final uuid?)
                if (_cat.nodeFor(uuid) case final node?)
                  _EquipmentTile(
                    node: node,
                    type: _cat.typeFor(node),
                    state: _cat.stateFor(node.uuid),
                    developerMode: services.settings.developerMode,
                    displayName: _displayName(node),
                    isMainVfo: true,
                    onEdit: () => _editEquipment(context, node),
                    onRemoveUnknown: () => _removeEquipment(context, node),
                    onConnect: () => _cat.connect(node.uuid),
                    onDisconnect: () => _cat.disconnect(node.uuid),
                  ),
              // And the keyer in use, when it is a device of its own: the
              // row above is where it gets connected, so a radio keying
              // through its own CAT session must not draw a second row.
              if (keyerExperiment)
                if (_cat.designatedKeyerNode case final keyer?)
                  if (!_cat.isRadio1(keyer.uuid))
                    _EquipmentTile(
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
              for (final node in nodes)
                _EquipmentTile(
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
              ListTile(
                leading: const Icon(MdiIcons.plus),
                title: Text(st.add),
                onTap: () => _addEquipment(context),
                mouseCursor: SystemMouseCursors.click,
              ),
            ],
            if (compact) _powerField(context, inset: rowInset),
            if (!compact) ...[
              const SizedBox(height: Space.xl * 2),
              // A section of its own — Space.xl of top padding from
              // SectionHeader, same as Equipment Inventory above it — rather
              // than tacking the toggle onto the equipment list it has
              // nothing to do with.
              SectionHeader(st.otherOptions),
              // What to remember about EACH QSO, rather than the station's
              // own current setup above — off by default, since most
              // operators log with one radio, one antenna and one key, and a
              // field that never changes says nothing worth reading on every
              // row.
              SwitchListTile(
                title: Text(st.trackStationInfo),
                value: services.settings.trackStationInfo,
                onChanged: (value) => unawaited(services.settings.setTrackStationInfo(value)),
                mouseCursor: SystemMouseCursors.click,
              ),
              if (services.settings.trackStationInfo) ..._stationInfoSettings(context),
            ],
          ],
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
      child: _PowerField(
        power: _cat.displayedPower,
        label: st.trackFieldPower,
        wattsLabel: st.watts,
        width: fieldWidth,
        style: style,
        onCommit: (watts) =>
            services.radio.setVfo('vfoA', power: watts, clearPower: watts == null),
      ),
    );
  }

  /// The keyer speed as a pick over the radio's own range, the way to the CW
  /// Messages dialog, and the switch that shows the logging panel's keyer
  /// area. The messages are editable with no radio at all — they are
  /// settings — but the speed is the radio's, so without one that can key
  /// the pick is disabled under a line saying why.
  ///
  /// Drawn in both layouts, directly under the key it describes.
  Widget _cwKeyerRow(BuildContext context, {required EdgeInsets inset}) {
    final st = context.t.settings.station;
    final canKey = _cat.canKeyCw;
    final range = _cat.keyerSpeedRange;
    final speed = _cat.keyerSpeed;
    final inRange = speed != null && range != null && speed >= range.min && speed <= range.max;
    return Padding(
      padding: EdgeInsets.fromLTRB(inset.left, 0, inset.right, Space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  // Keyed on the value for the same reason the main VFO
                  // dropdown is: FormFieldState reads initialValue once, and
                  // the radio's answer arrives after the first build.
                  key: ValueKey('keyerSpeed:${inRange ? speed : null}:$canKey'),
                  isExpanded: true,
                  initialValue: inRange ? speed : null,
                  icon: dropdownTrailingIcon,
                  decoration: poloFieldDecoration(context, context.t.settings.radio.keyerSpeed.title),
                  menuMaxHeight: dropdownMenuMaxHeight(context),
                  items: [
                    if (range != null)
                      for (var wpm = range.min; wpm <= range.max; wpm++)
                        DropdownMenuItem<int>(value: wpm, child: Text('$wpm ${context.t.settings.radio.keyerSpeed.unit}')),
                  ],
                  onChanged: canKey ? (wpm) => wpm == null ? null : _cat.setKeyerSpeed(wpm) : null,
                ),
              ),
              const SizedBox(width: Space.md),
              TextButton.icon(
                icon: const Icon(MdiIcons.messageBulleted),
                label: Text(st.cwMessagesButton),
                onPressed: () => showCwMessagesDialog(context, services),
              ),
              const SizedBox(width: Space.md),
              // Shows or hides the keyer area in the logging panel — the same
              // switch KEYER, the area's X and its linger move. Unlabelled:
              // the row it sits in is already the keyer's, so a caption would
              // spend the width saying what everything beside it says. The
              // name lives in Semantics, per docs/design/user-interface.md —
              // never a tooltip.
              ValueListenableBuilder<bool>(
                valueListenable: _cat.keyerAreaShown,
                builder: (context, shown, _) => Semantics(
                  label: st.cwKeyerArea,
                  child: Switch(
                    value: shown,
                    onChanged: canKey ? (on) => on ? _cat.showKeyerArea() : _cat.hideKeyerArea() : null,
                  ),
                ),
              ),
            ],
          ),
          if (!canKey)
            Padding(
              padding: const EdgeInsets.only(top: Space.xs),
              child: Text(st.cwKeyerNotAvailable, style: Theme.of(context).textTheme.bodySmall),
            ),
        ],
      ),
    );
  }

  /// The way to the Voice Messages dialog, under a line saying whose
  /// memories they are — the one thing the app has to say about a voice
  /// keyer, since the speed, the audio and the recording all live in the
  /// radio.
  Widget _voiceKeyerRow(BuildContext context, {required EdgeInsets inset}) {
    final st = context.t.settings.station;
    return Padding(
      padding: EdgeInsets.fromLTRB(inset.left, 0, inset.right, Space.md),
      child: Row(
        children: [
          Expanded(
            child: Text(
              st.voiceKeyerAvailable(count: _cat.voiceMemoryCount),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(width: Space.md),
          TextButton.icon(
            icon: const Icon(MdiIcons.microphoneMessage),
            label: Text(st.voiceMessagesButton),
            onPressed: () => showVoiceMessagesDialog(context, services),
          ),
          const SizedBox(width: Space.md),
          // The same switch the CW row carries — a voice-only radio has no
          // CW row, and F-keys PLAY, so this is its way to the area idle.
          ValueListenableBuilder<bool>(
            valueListenable: _cat.keyerAreaShown,
            builder: (context, shown, _) => Semantics(
              label: st.cwKeyerArea,
              child: Switch(
                value: shown,
                onChanged: (on) => on ? _cat.showKeyerArea() : _cat.hideKeyerArea(),
              ),
            ),
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
      destructive: TextButton(
        onPressed: onMoreSettings,
        child: Text(st.moreSettings),
      ),
      cancel: TextButton(
        onPressed: () => Navigator.of(context).maybePop(),
        child: Text(context.t.common.done),
      ),
    );
  }

  List<Widget> _stationInfoSettings(BuildContext context) {
    final st = context.t.settings.station;
    final settings = services.settings;
    final tracked = settings.stationInfoTrackedFields;
    final trackedFieldOptions = [
      {'value': 'rig', 'label': st.trackFieldRig},
      {'value': 'power', 'label': st.trackFieldPower},
      {'value': 'antenna', 'label': st.trackFieldAntenna},
      {'value': 'key', 'label': st.trackFieldKey},
    ];

    return [
      // No "Include in ADIF exports" row here: SettingsService.
      // includeStationInfoInAdif exists, but nothing in the ADIF export
      // path (extensions/core/adif) reads it yet. Showing the toggle would
      // promise a QSO field the export never carries — it comes back once
      // that wiring lands.
      //
      // Same field type, same summary-row-opens-a-dialog behavior as Bands
      // and Modes in Preferences (core_settings_groups.dart) — a short,
      // fixed vocabulary the operator picks from, not something to browse.
      // `compact` keeps the dialog narrow and its rows padded, rather than
      // the flush wide layout that suits a dozen-plus bands.
      //
      // No inset of its own: FormRenderer's rows read the ambient
      // ListTileTheme, which the settings pane's own SettingsList already
      // set to the one inset every row in the panel shares. Restating it
      // here is how a panel ends up a rung off from the one beside it.
      FormRenderer(
        formDefinition: {
          'elements': [
            {
              'type': 'field',
              'fieldType': 'multiselect',
              'key': 'trackedFields',
              'label': st.whatToTrack,
              'value': [for (final opt in trackedFieldOptions) if (tracked.contains(opt['value'])) opt['value']],
              'defaultValue': SettingsService.defaultStationInfoTrackedFields,
              'options': trackedFieldOptions,
              'compact': true,
            },
          ],
        },
        initialState: const {},
        showActions: false,
        showTitle: false,
        onChange: (fieldKey, value, state) async {
          await settings.setStationInfoTrackedFields((value as List).cast<String>().toSet());
          return null;
        },
        onSubmit: (_) {},
        onCancel: () {},
        labels: formRendererLabelsFor(context.t),
        settingsList: true,
      ),
    ];
  }
}

/// How far the equipment list has to scroll before the discovery section
/// folds away. Plain logical pixels, deliberately: every Scrollable lives
/// BELOW the app's UiScale wrapper, so `metrics.pixels` is already in the
/// same scaled space this constant is written in — multiplying by the font
/// scale would double-scale it (docs/design/ui-scaling.md). Matches the
/// threshold the Home screen's FAB collapse uses.
const _discoveryCollapseAfter = 10.0;

/// Picking what to add: every radio the app knows, filtered by a search box,
/// with whatever announced itself on the network pinned underneath.
///
/// Stateful because two things here are the dialog's own and belong to
/// nothing else — the filter text and whether the discovery section is
/// currently folded away.
class _AddEquipmentDialog extends StatefulWidget {
  final CatService cat;

  /// False when no pairing on this platform could discover anything, in
  /// which case the section is absent rather than permanently empty.
  final bool showDiscovery;

  /// Whether the operator has opted to track an antenna or a key against
  /// QSOs — see [SettingsService.stationInfoTrackedFields]. Off, the "Other
  /// Equipment" section would only ever grow a list nothing reads.
  final bool showAntennaAndKey;

  /// Whether "Other Equipment" offers a CW keyer — behind the keyer
  /// experiment, with everything that keys.
  final bool showKeyer;

  final List<EquipmentType> Function(EquipmentModel model) supportedVariants;

  const _AddEquipmentDialog({
    required this.cat,
    required this.showDiscovery,
    required this.showAntennaAndKey,
    required this.showKeyer,
    required this.supportedVariants,
  });

  @override
  State<_AddEquipmentDialog> createState() => _AddEquipmentDialogState();
}

class _AddEquipmentDialogState extends State<_AddEquipmentDialog> {
  final _searchController = TextEditingController();

  /// Closed by default — antennas and keys are the rare add, not the common
  /// one, and starting open would push the radio catalogue below the fold
  /// on every visit to this dialog.
  var _otherEquipmentExpanded = false;

  /// Folded away once the operator scrolls into the list. Starts open: with
  /// a short list nothing ever scrolls, and the section is the whole point
  /// of the dialog for a radio that announces itself.
  var _discoveryExpanded = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Decides the fold from a scrollable's current metrics.
  ///
  /// Folding gives the list the room the section was using, which can stop
  /// the list overflowing at all — so this reads `maxScrollExtent` as well as
  /// `pixels`. A list with nowhere left to scroll is not being browsed, and
  /// the operator has no way to scroll back up to ask for the section
  /// either, so it comes back.
  ///
  /// The consequence, which is the intended one: a list that overflows by
  /// less than the section gives up settles back OPEN after one frame,
  /// because folding it away bought nothing. Only a list still scrollable
  /// after the fold stays folded.
  void _applyScrollMetrics(ScrollMetrics metrics) {
    if (metrics.maxScrollExtent <= 0) return _setDiscoveryExpanded(true);
    _setDiscoveryExpanded(metrics.pixels <= _discoveryCollapseAfter);
  }

  void _setDiscoveryExpanded(bool expanded) {
    if (_discoveryExpanded == expanded) return;
    setState(() => _discoveryExpanded = expanded);
  }

  /// Matches the radio's name, its brand and the ways it can be reached, so
  /// "usb" finds every rig with a cable and "705" finds the one radio — an
  /// operator searching this list is as likely to know how a radio plugs in
  /// as what its family is called. The brand is its own clause because a
  /// model's name need not carry it: an X6100 is named for what is written
  /// on the radio, and "Xiegu" has to reach it.
  bool _matches(({EquipmentModel model, List<EquipmentType> variants, String name}) row, String query) {
    if (query.isEmpty) return true;
    if (row.name.toLowerCase().contains(query)) return true;
    if (row.model.manufacturer?.toLowerCase().contains(query) ?? false) return true;
    return row.variants.any((type) => type.transportLabel.toLowerCase().contains(query));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.cat,
      builder: (context, _) {
        final st = context.t.settings.station;
        final query = _searchController.text.trim().toLowerCase();
        // A radio whose transport can't connect on this platform at all
        // (TCP, Icom network, on web) would only fail loudly once picked —
        // no point offering it.
        // Resolved ONCE per model. Both the variants and the name cost real
        // work — `supportedVariants` scans the type list per variant, and
        // `name` is a localization lookup — and every one of them would
        // otherwise be repeated for the filter, the subtitle, the glyphs and
        // each comparison the sort makes, on every keystroke in the search box.
        // Antenna switches are left out here and listed under "Other
        // Equipment" instead: an operator searching this list is looking for
        // their radio, and a switch is station plumbing they add once.
        final rows = [
          for (final model in widget.cat.registry.models)
            if (!model.hiddenFromCatalog && model.category != kCategoryAntennaSwitch)
              if (widget.supportedVariants(model) case final variants when variants.isNotEmpty)
                (model: model, variants: variants, name: model.name),
        ]
          // Sorted HERE rather than in the registry, because a model's name is
          // read from the current locale at call time — an order fixed at
          // declaration would be alphabetical in whichever language happened
          // to be active first. Case-insensitive, so a lower-case brand name
          // doesn't sort below every capitalised one.
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        final models = [
          for (final row in rows)
            if (_matches(row, query)) row,
        ];
        // Named makes and models, unlike the antenna and key rows they sit
        // with — a switch is picked from the catalogue, it just isn't picked
        // from THAT catalogue. Sorted for the same locale reason as [rows].
        final switches = [
          for (final model in widget.cat.registry.models)
            if (!model.hiddenFromCatalog && model.category == kCategoryAntennaSwitch)
              if (widget.supportedVariants(model) case final variants when variants.isNotEmpty)
                (model: model, variants: variants, name: model.name),
        ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        final searchBorder = OutlineInputBorder(borderRadius: BorderRadius.circular(8));

        return HaloDialog(
          // Rows run edge to edge and the content scrolls itself, so the
          // shell must not also try to scroll it — halo_dialog.dart says an
          // Expanded/self-scrolling child REQUIRES scrollable: false.
          wide: true,
          scrollable: false,
          contentPadding: EdgeInsets.zero,
          title: Text(st.addTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.showDiscovery) ..._discoverySection(context),
              // The catalogue's own section header, and the field IS the
              // heading: a band saying "Equipment" with a search box under it
              // would spend a row of a dialog that has none to spare saying
              // what the hint text already says.
              _sectionBand(
                context,
                child: TextField(
                  // Per docs/design/user-interface.md: focusing a field must
                  // not select what is in it.
                  selectAllOnFocus: false,
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    isDense: true,
                    // Against the band's own tint, so the box reads as a
                    // control sitting ON the header rather than a hole in it.
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    prefixIcon: const Icon(MdiIcons.magnify, size: 18),
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            icon: Icon(MdiIcons.close, size: 18, semanticLabel: context.t.formChrome.clear),
                            onPressed: () => setState(_searchController.clear),
                          ),
                    hintText: st.searchHint,
                    border: searchBorder,
                    enabledBorder: searchBorder,
                    focusedBorder: haloFocusedBorder(searchBorder, context),
                  ),
                ),
              ),
              // BOTH scrolling regions are flex children, and that is what
              // keeps this dialog from overflowing: with `scrollable: false`
              // an inflexible child takes its full height off the top, so a
              // handful of announced radios would squeeze the catalogue to
              // nothing and one more would overflow the card outright.
              //
              // Loose flex, so neither claims room it does not want: on a tall
              // dialog each takes its natural height and the card shrink-wraps.
              // The weighting only decides who yields when there is not enough
              // — and the catalogue is what the operator came for.
              Flexible(
                flex: 4,
                // TWO listeners, and the second is not redundant. A scroll
                // position corrected during LAYOUT — the list shrinking under
                // a filter, or growing back when one is cleared, or gaining
                // the room the fold just freed — moves `pixels` without ever
                // dispatching a ScrollNotification. Only ScrollMetricsNotification
                // reports it, and it is not a ScrollNotification. Listening to
                // the first alone leaves the section folded shut with an
                // un-scrollable list under it and no gesture that reopens it.
                child: NotificationListener<ScrollMetricsNotification>(
                  onNotification: (notification) {
                    _applyScrollMetrics(notification.metrics);
                    return false;
                  },
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      _applyScrollMetrics(notification.metrics);
                      // Keep bubbling: these listeners observe, they do not consume.
                      return false;
                    },
                    child: models.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: Space.xxl, horizontal: Space.xl),
                          child: Text(st.noMatches, textAlign: TextAlign.center),
                        )
                      : ListView(
                          // Filtered per keystroke, and every row picks a
                          // model on tap (docs/quirks.md).
                          key: listContentsKey([for (final row in models) row.name]),
                          shrinkWrap: true,
                          padding: const EdgeInsets.only(bottom: Space.md),
                          children: [
                            for (final row in models)
                              ListTile(
                                leading: Icon(_iconForCategory(row.model.category)),
                                title: Text(row.name),
                                subtitle: _modelSubtitle(context, row.variants),
                                // The glyphs belong beside the radio's NAME,
                                // not halfway down the row. Material 3 centres
                                // `leading`/`trailing` against the whole tile
                                // unless told otherwise, so a row carrying an
                                // untested caveat would otherwise drop them a
                                // line — wrapping them in a shrink-wrapping
                                // Column does NOT do this, only the alignment
                                // does.
                                titleAlignment: ListTileTitleAlignment.top,
                                trailing: _TransportIcons(types: row.variants),
                                onTap: () => Navigator.of(context).pop(_AddChoice.model(row.model)),
                                mouseCursor: SystemMouseCursors.click,
                              ),
                          ],
                        ),
                  ),
                ),
              ),
              if (widget.showAntennaAndKey || widget.showKeyer || switches.isNotEmpty)
                _otherEquipmentSection(context, switches: switches),
            ],
          ),
          // "Done", not "Cancel": the "Other Equipment" section below can add
          // an antenna or key node directly, with no further pane to confirm
          // through, so closing this dialog is never discarding a choice.
          cancel: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.t.common.done),
          ),
        );
      },
    );
  }

  /// One section's header band — the same tint the "Other Equipment"
  /// accordion draws its own header in, so the dialog's three sections read
  /// as siblings rather than as one styled heading among plain ones. No
  /// arrow: neither of these two folds by hand.
  ///
  /// [title] and [child] are alternatives — a heading with an optional
  /// [trailing] control, or a control that IS the heading (the search box).
  Widget _sectionBand(BuildContext context, {String? title, Widget? trailing, Widget? child}) {
    final theme = Theme.of(context);
    final onHeaderColor = theme.colorScheme.onSurfaceVariant;
    return Material(
      color: haloDialogBandColorAt(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.xl, Space.sm, Space.lg, Space.sm),
        child: child ??
            Row(
              children: [
                Expanded(
                  child: Text(
                    title ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(color: onHeaderColor, fontWeight: FontWeight.w600),
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: Space.md), trailing],
              ],
            ),
      ),
    );
  }

  /// Antennas and keys, added by name and type rather than picked from a
  /// catalogue — there is exactly one of each, unlike the radio list above.
  /// Closed by default (see [_otherEquipmentExpanded]): visible only when
  /// [_AddEquipmentDialog.showAntennaAndKey] says the operator tracks at
  /// least one of these against a QSO, so the section never grows a list
  /// nothing reads.
  Widget _otherEquipmentSection(
    BuildContext context, {
    required List<({EquipmentModel model, List<EquipmentType> variants, String name})> switches,
  }) {
    final st = context.t.settings.station;
    final theme = Theme.of(context);
    final headerColor = haloDialogBandColorAt(context);
    final onHeaderColor = theme.colorScheme.onSurfaceVariant;

    return AccordionSection(
      title: Text(
        st.otherEquipment,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleSmall?.copyWith(color: onHeaderColor, fontWeight: FontWeight.w600),
      ),
      expanded: _otherEquipmentExpanded,
      onToggle: () => setState(() => _otherEquipmentExpanded = !_otherEquipmentExpanded),
      headerColor: headerColor,
      onHeaderColor: onHeaderColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.showAntennaAndKey) ...[
            ListTile(
              leading: const Icon(MdiIcons.antenna),
              title: Text(st.newAntenna),
              onTap: () => Navigator.of(context).pop(_AddChoice.model(antennaModel)),
              mouseCursor: SystemMouseCursors.click,
            ),
            ListTile(
              leading: const Icon(MdiIcons.key),
              title: Text(st.newKey),
              onTap: () => Navigator.of(context).pop(_AddChoice.model(keyModel)),
              mouseCursor: SystemMouseCursors.click,
            ),
          ],
          // Beside the plain key rather than in the catalogue: a keyer is
          // where an operator looks for their key, whatever its make.
          if (widget.showKeyer)
            ListTile(
              leading: const Icon(MdiIcons.keyboardVariant),
              title: Text(st.newKeyer),
              // A named make with a cable, unlike the two inert rows above
              // it: the glyph says how it plugs in, the same way it does in
              // the catalogue.
              trailing: _TransportIcons(types: widget.supportedVariants(winkeyerModel)),
              onTap: () => Navigator.of(context).pop(_AddChoice.model(winkeyerModel)),
              mouseCursor: SystemMouseCursors.click,
            ),
          // Real makes and models, so these carry the same subtitle and
          // transport glyphs their rows had in the catalogue above.
          for (final row in switches)
            ListTile(
              leading: Icon(_iconForCategory(row.model.category)),
              title: Text(row.name),
              subtitle: _modelSubtitle(context, row.variants),
              titleAlignment: ListTileTitleAlignment.top,
              trailing: _TransportIcons(types: row.variants),
              onTap: () => Navigator.of(context).pop(_AddChoice.model(row.model)),
              mouseCursor: SystemMouseCursors.click,
            ),
        ],
      ),
    );
  }

  /// What announced itself, under a title that never changes.
  ///
  /// The title is permanent on purpose: discovery runs for as long as this
  /// dialog is open, so a heading that switched between "searching" and
  /// "found" would be describing the same unfinished activity twice, and the
  /// section would jump around as radios appeared.
  ///
  /// Spread into the dialog's own Column rather than returned as one widget:
  /// the body has to be a flex sibling of the equipment list for the two to
  /// share a short dialog, and a nested Column would hide it from that.
  List<Widget> _discoverySection(BuildContext context) {
    final st = context.t.settings.station;
    final theme = Theme.of(context);
    final found = widget.cat.discovered;
    final error = widget.cat.discoveryError;

    return [
        // The spinner rides the title rather than taking a row of its own:
        // discovery runs for as long as this dialog is open, so a row that
        // exists only to say so pushed the catalogue down the whole time.
        _sectionBand(
          context,
          title: st.detectedEquipment,
          trailing: error != null
              ? null
              : const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        // AnimatedSize alone, with no controller: the collapse is a plain
        // implicit animation, the way the Home screen's FAB does it. No
        // settle-epoch guard like that one either — a RenderAnimatedSize can
        // be stranded mid-flight by a muted ticker, but this lives in a modal
        // that is rebuilt from scratch every time it opens.
        Flexible(
          flex: 1,
          child: AnimatedSize(
          duration: layoutAnimationDuration,
          curve: layoutAnimationCurve,
          // Fold upward, so the rows slide out under the title rather than
          // the title walking down the dialog.
          alignment: Alignment.topCenter,
          child: !_discoveryExpanded
              ? const SizedBox(width: double.infinity)
              : SingleChildScrollView(
                    child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (error != null)
                      ListTile(
                        leading: Icon(MdiIcons.wifiOff, color: theme.colorScheme.error),
                        title: Text(st.discoveryUnavailable(error: error)),
                      )
                    else
                      for (final device in found)
                        ListTile(
                          leading: Icon(_iconForCategory(widget.cat.registry.typeFor(device.typeKey)?.category)),
                          title: Text(device.name),
                          subtitle: device.detail == null ? null : Text(device.detail!),
                          titleAlignment: ListTileTitleAlignment.top,
                          trailing: switch (widget.cat.registry.typeFor(device.typeKey)) {
                            final type? => _TransportIcons(types: [type]),
                            _ => null,
                          },
                          onTap: () => Navigator.of(context).pop(_AddChoice.discovered(device)),
                          mouseCursor: SystemMouseCursors.click,
                        ),
                    ],
                    ),
                ),
        ),
        ),
        const Divider(height: 1),
    ];
  }
}

/// Either a device that announced itself (ready to add as-is) or a type to
/// configure by hand.
class _AddChoice {
  /// The radio, not the pairing: how it is connected is chosen in the
  /// editor, alongside the settings that choice decides.
  final EquipmentModel? model;
  final DiscoveredEquipment? discovered;

  const _AddChoice.model(this.model) : discovered = null;
  const _AddChoice.discovered(this.discovered) : model = null;
}

/// The glyph the logging panel's own Radio control falls back to when no
/// CAT radio is configured — this list is what configures one.
IconData _iconForCategory(String? category) => switch (category) {
      kCategoryTransceiver => MdiIcons.radio,
      kCategoryAntenna => MdiIcons.antenna,
      kCategoryKey => MdiIcons.key,
      kCategoryKeyer => MdiIcons.keyboardVariant,
      kCategoryAntennaSwitch => MdiIcons.directionsFork,
      _ => MdiIcons.developerBoard,
    };

/// What the Add list says under a radio's name: which of its pairings have
/// never met a radio, and nothing else.
///
/// Only the caveat, because the transports themselves are now the row's
/// trailing glyphs — naming them here as well would say the same thing twice
/// in one row. A model with every pairing untested carries the caveat whole
/// rather than per transport; a MIXED one has to name which, since the
/// IC-705's WiFi is proven on hardware and its USB side has never been
/// pointed at a radio, and one marker for the model would be wrong either
/// way round.
Widget? _modelSubtitle(BuildContext context, List<EquipmentType> variants) {
  final st = context.t.settings.station;
  final untested = [
    for (final type in variants)
      if (!type.hardwareVerified) type,
  ];
  if (untested.isEmpty) return null;
  if (untested.length == variants.length) return Text(st.unverified);
  return Text(untested.map((type) => '${type.transportLabel} (${st.unverifiedShort})').join(' · '));
}

/// How a pairing is plugged in, as a glyph — see `transportIconNameFor`.
///
/// Null when the transport has no glyph, so a caller leaves the slot empty.
/// Deliberately not defaulted to something generic: `resolveIconName` answers
/// an unknown name with a puzzle piece, and a puzzle piece next to a radio
/// says less than nothing.
IconData? _iconForTransport(EquipmentType type) {
  final name = type.transportIconName;
  return name == null ? null : resolveIconName(name);
}

/// The transport glyphs of a model's pairings, in one small row.
///
/// Size is spelled out because this is not a ListTile slot — those inherit 24
/// from the tile's own IconTheme, and this sits beside body text.
class _TransportIcons extends StatelessWidget {
  final List<EquipmentType> types;

  const _TransportIcons({required this.types});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icons = [
      for (final type in types)
        if (_iconForTransport(type) case final icon?) (icon: icon, label: type.transportLabel),
    ];
    if (icons.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // By index, not by `entry != icons.first`: these are records, which
        // compare by VALUE, so two pairings sharing a glyph and a label would
        // both count as the first and the second would lose its gap.
        for (final (index, entry) in icons.indexed) ...[
          if (index > 0) const SizedBox(width: Space.xs),
          Icon(
            entry.icon,
            size: 16,
            // The app has no hover tooltips, so this is the only place the
            // glyph is named for anyone who cannot see it.
            semanticLabel: entry.label,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ],
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

  const _PowerField({
    required this.power,
    required this.label,
    required this.wattsLabel,
    required this.width,
    required this.style,
    required this.onCommit,
  });

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

/// Picks which node of a single-designation category (antenna, key) is "in
/// use" — the same shape as the main VFO dropdown above it, minus the tune
/// button since these nodes have nothing to connect.
class _DesignationDropdown extends StatelessWidget {
  final String label;
  final List<EquipmentNode> nodes;
  final String? selected;
  final String Function(EquipmentNode node) displayName;
  final String noneLabel;
  final void Function(String? uuid) onChanged;

  const _DesignationDropdown({
    super.key,
    required this.label,
    required this.nodes,
    required this.selected,
    required this.displayName,
    required this.noneLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      isExpanded: true,
      initialValue: nodes.any((n) => n.uuid == selected) ? selected : null,
      icon: dropdownTrailingIcon,
      decoration: poloFieldDecoration(context, label),
      menuMaxHeight: dropdownMenuMaxHeight(context),
      items: [
        DropdownMenuItem<String?>(value: null, child: Text(noneLabel)),
        for (final node in nodes)
          DropdownMenuItem<String?>(value: node.uuid, child: Text(displayName(node), overflow: TextOverflow.ellipsis)),
      ],
      onChanged: onChanged,
    );
  }
}

/// The peer's radio driving `vfoA`, as a row in Equipment in Use.
///
/// Deliberately not an [_EquipmentTile]: there is no [EquipmentNode] behind
/// it and none of that row's controls apply — a peer's rig is connected,
/// edited and removed on the device it is plugged into.
class _PeerVfoTile extends StatelessWidget {
  final PeerRadioSelection selection;

  /// Whether the peer is offering it right now. False keeps the row, saying
  /// so: the pick survives the peer walking away and re-engages by itself,
  /// so a row that vanished would read as a selection that had been dropped.
  final bool available;

  const _PeerVfoTile({required this.selection, required this.available});

  @override
  Widget build(BuildContext context) {
    final st = context.t.settings.station;
    final theme = Theme.of(context);

    return ListTile(
      leading: Icon(_iconForCategory(kCategoryTransceiver)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // The same 3:2 split, name-with-pill against address, that
          // [_EquipmentTile] uses — these rows sit under one another.
          Flexible(
            flex: 3,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Falling back to the id like the dropdown does: a pick made
                // as the peer dropped is stored with empty names, and a row
                // with a blank title names nothing at all.
                Flexible(
                  child: Text(
                    selection.radioName.isEmpty ? selection.radioId : selection.radioName,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: Space.md),
                // Always: a peer selection IS the main VFO, or it would not
                // be stored at all.
                Flexible(
                  child: _Pill(
                    label: st.mainVfo,
                    background: theme.colorScheme.secondaryContainer,
                    foreground: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(left: Space.lg),
              child: Text(
                // Where it is, in the place a local row states its address:
                // for a peer's rig that is which device it is plugged into.
                st.peerRadioOnDevice(
                  device: selection.deviceName.isEmpty ? selection.deviceId : selection.deviceName,
                ),
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ),
        ],
      ),
      subtitle: available
          ? null
          : Text(
              st.peerRadioNotAvailable,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
    );
  }
}

class _EquipmentTile extends StatelessWidget {
  final EquipmentNode node;
  final EquipmentType? type;
  final EquipmentState state;
  final String displayName;

  /// This is `radio1` — the node whose VFO is the logging panel's, shown
  /// to the operator as "Main VFO".
  final bool isMainVfo;

  /// Whether to show what the driver worked out about this session. Off for
  /// everyone else: a line reading "IF mode offset 21 (learned)" is
  /// meaningless to an operator and alarming to some.
  final bool developerMode;
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
    required this.developerMode,
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
        leading: Icon(MdiIcons.helpCircleOutline, color: theme.colorScheme.error),
        title: Text(displayName),
        subtitle: Text(st.unknownType(typeKey: node.typeKey)),
        // An unrecognized type has no editor to put Remove inside, so this
        // row keeps its own — it is the only way to get rid of the record.
        trailing: IconButton(
          icon: Icon(MdiIcons.trashCanOutline, semanticLabel: st.remove),
          onPressed: onRemoveUnknown,
        ),
      );
    }

    // Equipment with nothing to connect to — an antenna, a CW key. No plug
    // toggle, no VFO reading, no status pill: every one of those describes a
    // live session, and this equipment never has one.
    //
    // Asked of the transport rather than the category. "Not a transceiver"
    // was the same question only while every other category was inert; an
    // antenna switch is not a transceiver and does connect, and reading the
    // category here would have left it with no plug to pull.
    if (resolvedType.transportKey == NoneTransport.transportKey) {
      return ListTile(
        leading: Icon(_iconForCategory(resolvedType.category)),
        title: Text(displayName),
        subtitle: Text(resolvedType.describeTarget(node.config)),
        onTap: onEdit,
        mouseCursor: SystemMouseCursors.click,
      );
    }

    // Both directions take time and both deserve the spinner: connecting
    // negotiates a handshake, disconnecting sends a goodbye that must not be
    // rushed.
    final busy = state.status == EquipmentStatus.connecting ||
        state.status == EquipmentStatus.disconnecting;
    final vfo = state.vfo;
    final reading = [
      if (vfo.mode != null) vfo.mode!,
      // To the Hz, not [fmtFreq]'s 100 Hz: this row is the app's view of
      // where the rig actually is, and Smart VFO Snap's whole effect lives in
      // the digits fmtFreq drops.
      if (vfo.freqKHz != null) fmtFreqToTheHz(vfo.freqKHz!),
    ].join('  ');
    final connected = state.status == EquipmentStatus.connected;

    // A problem is connected-but-misconfigured (a Flex pointed at a slice
    // the radio isn't running). It takes the same whole-row treatment as a
    // failure, for the same reason: a reason squeezed beside the frequency
    // it explains the absence of is not a reason.
    final trouble = state.status == EquipmentStatus.error ? state.error : state.problem;
    final failed = trouble != null;

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
                  const SizedBox(width: Space.md),
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
              padding: const EdgeInsets.only(left: Space.lg),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Flexible so the address ellipsizes instead of pushing the
                  // glyph off the row — the glyph is a fixed width competing
                  // with text that can be any length.
                  Flexible(
                    child: Text(
                      resolvedType.describeTarget(node.config),
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  // How it is plugged in, right where it says where it is.
                  _TransportIcons(types: [resolvedType]),
                ],
              ),
            ),
          ),
        ],
      ),
      subtitle: failed
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  trouble,
                  // Two lines' worth: these say what to do about it, and the
                  // useful part is rarely in the first forty characters.
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                ),
                // Under the error, not instead of it: what the driver worked
                // out is most worth reading when something has gone wrong,
                // and this is the one row state that used to hide it.
                if (developerMode && state.diagnostic != null)
                  Text(
                    state.diagnostic!,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: HaLoColors.of(context).devMode),
                  ),
              ],
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
                          : HaLoColors.of(context).onSurfaceAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (developerMode && state.diagnostic != null)
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.only(left: Space.lg),
                      child: Text(
                        state.diagnostic!,
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(color: HaLoColors.of(context).devMode),
                      ),
                    ),
                  ),
                if (connected)
                  Padding(
                    padding: const EdgeInsets.only(left: Space.lg),
                    child: _Pill(
                      // A link that is up but silent must not wear the same
                      // confident green as one that is working: the
                      // frequency shown may be minutes old.
                      label: equipmentStatusLabel(context, state),
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

/// A small rounded label. Same shape as activities_view's `ActivityRowChip` —
/// nothing pill-like is exported from halo_widgets, and that chip says the
/// same kind of thing about a row. Plain logical
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
      padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.xxs),
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
