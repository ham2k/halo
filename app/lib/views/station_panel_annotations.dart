// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What the equipment editor's form says about the equipment's live state:
// which channel another client already holds, an antenna switch's current
// routing, wiring and antenna links, and where a rotator points. Labels,
// read-only rows and commands only — every value the form saves is still the
// driver's.

part of 'station_panel.dart';

extension _EditorAnnotations on StationPanel {
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
  List<Map<String, dynamic>> _annotateChannels(EquipmentType variant, EquipmentNode? node, BuildContext context) {
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
                if (byKey[option['value']] case final channel?) {...option, 'label': '${option['label']}${_describeChannel(channel, context)}'} else option,
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
  String _switchPortName(SwitchAntenna antenna) => antenna.name.isEmpty || antenna.name == antenna.key ? antenna.key : '${antenna.key} - ${antenna.name}';

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
        // The FILLED band, not the unfilled heading: these are the editor's
        // own top-level groups rather than sections inside one, and nothing
        // above them says so (docs/design/user-interface.md § Settings lists).
        'type': 'header',
        'style': 'category',
        'title': st.switchCurrentStateHeader,
        'subtitle': st.switchCurrentStateDescription,
      },
      for (final port in state.switchPorts)
        {
          'type': 'field',
          'fieldType': 'select',
          'key': switchPortRoutingFormKey(port.key),
          'label': st.switchPortLabel(port: port.label),
          'description': ?_switchPortDetail(port, st),
          // A keyed port is refused by the driver as well — this only keeps
          // the operator from being offered a control whose answer is going
          // to be "not while you are transmitting".
          if (port.transmitting) 'disabled': true,
          'options': [
            for (final antenna in choices) {'value': antenna.key, 'label': _switchAntennaLabel(node, antenna)},
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
  List<Map<String, dynamic>> _switchWiring(BuildContext context, EquipmentType type, EquipmentNode? node) {
    final st = context.t.settings.station;
    final layout = [
      for (final element in _annotateSwitchLayout(type.driver.configElements(overrides: type.overrides, restrictions: type.restrictions), node, context))
        if (element['key'] == switchLayoutConfigKey) element,
    ];
    return [
      {'type': 'header', 'style': 'category', 'title': st.switchWiringHeader},
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
  List<Map<String, dynamic>> _switchAntennaLinks(BuildContext context, EquipmentType type, EquipmentNode? node) {
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
            for (final antenna in antennas) {'value': antenna.uuid, 'label': _displayName(antenna)},
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
  List<Map<String, dynamic>> _annotateSwitchLayout(List<Map<String, dynamic>> elements, EquipmentNode? node, BuildContext context) {
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
                  switchLayoutDevicePorts => {...option, 'label': st.switchLayoutSides(antennas: antennas, radios: radios)},
                  switchLayoutAntennaPorts => {...option, 'label': st.switchLayoutSides(antennas: radios, radios: antennas)},
                  _ => option,
                },
            ],
          },
    ];
  }

  /// The Current State section for a saved rotator: where it points, a
  /// heading to turn it to, and Connect or Disconnect in the band.
  ///
  /// Unlike the switch's section it shows while disconnected too, its
  /// controls greyed: a rotator is turned from this pane, so the pane is
  /// where the operator connects it — and controls that vanish leave them
  /// nothing saying how to get them back. Connect reaches the rotator as
  /// SAVED, not as edited in the form. Unlike a switch's pickers, the readout DOES
  /// follow the rotator while the pane is open — the editor republishes its
  /// elements every [_rotatorReadoutRefresh] — because a heading is mostly
  /// watched while it changes. The target boxes are commands' arguments, not
  /// settings: their keys never reach the stored record
  /// ([isRotatorFormKey]), and Turn sends them on the spot.
  List<Map<String, dynamic>> _rotatorCurrentState(BuildContext context, EquipmentNode? node) {
    if (node == null) return const [];
    final state = _cat.stateFor(node.uuid);
    final connected = state.status == EquipmentStatus.connected;
    // A stale heading is where the antenna WAS: shown as current, it is a
    // turn the operator plans from a place the mast may have left.
    final live = connected && !state.stale;
    final st = context.t.settings.station;
    final elevation = rotatorHasElevation(node.config);
    final position = live ? state.rotator : null;
    // A phone-width pane fits four controls on one row only with the short
    // labels, and the heading in the band only with the short units.
    final short = !ShirtSize.of(context).isTwoPane;

    return [
      {
        'type': 'header',
        'style': 'category',
        'title': !connected
            ? st.rotatorCurrentStateHeader(position: st.rotatorDisconnected)
            : !live
            ? st.rotatorCurrentStateHeader(position: st.rotatorNotResponding)
            : position == null
            ? st.switchCurrentStateHeader
            : st.rotatorCurrentStateHeader(
                position: _rotatorReading(st, position, elevation: elevation, short: short),
              ),
        'action': {
          'type': 'action',
          'key': connected ? _rotatorDisconnectAction : _rotatorConnectAction,
          'label': connected ? st.disconnect : st.connect,
          'icon': connected ? 'power-plug' : 'power-plug-off',
          if (connected) 'tone': 'connected',
          'busy': state.status == EquipmentStatus.connecting || state.status == EquipmentStatus.disconnecting,
        },
      },
      // The driver's problem is the one thing that says why no heading comes:
      // a controller refusing every poll answers, so nothing else is wrong.
      if (connected && state.problem != null)
        {'type': 'markdown', 'text': state.problem!}
      else if (live && position == null)
        {'type': 'markdown', 'text': st.rotatorNoReading},
      // Here as well as on the station row: Connect pressed in this pane
      // fails where the row's own message is out of sight.
      if (!connected && state.error != null) {'type': 'markdown', 'text': state.error!},
      {
        'type': 'row',
        'elements': [
          {
            'type': 'field',
            'fieldType': 'number',
            'key': _rotatorTargetAzimuthKey,
            'label': short ? st.rotatorTargetAzimuthShort : st.rotatorTargetAzimuth,
            'disabled': !live,
          },
          if (elevation)
            {
              'type': 'field',
              'fieldType': 'number',
              'key': _rotatorTargetElevationKey,
              'label': short ? st.rotatorTargetElevationShort : st.rotatorTargetElevation,
              'disabled': !live,
            },
          {'type': 'action', 'key': _rotatorTurnAction, 'label': st.rotatorTurn, 'flex': 0, 'disabled': !live},
          {'type': 'action', 'key': _rotatorStopAction, 'label': st.rotatorStop, 'flex': 0, 'disabled': !connected},
        ],
      },
    ];
  }

  /// Runs Turn, Stop, Connect or Disconnect for [node] with the form's
  /// current [values]. Null for any other action, which is the transport's
  /// to run.
  ///
  /// The target boxes are checked here rather than by the form's validator,
  /// which runs on Save — and a heading the operator typed and never sent
  /// must not stop them saving a renamed rotator.
  FormActionResult? _runRotatorAction(BuildContext context, EquipmentNode? node, String actionKey, Map<String, dynamic> values) {
    if (node == null || !_rotatorActions.contains(actionKey)) return null;
    if (actionKey == _rotatorConnectAction) {
      unawaited(_cat.connect(node.uuid));
      return const FormActionResult();
    }
    if (actionKey == _rotatorDisconnectAction) {
      unawaited(_cat.disconnect(node.uuid));
      return const FormActionResult();
    }
    if (actionKey == _rotatorStopAction) {
      _cat.stopRotator(node.uuid);
      return const FormActionResult();
    }
    final st = context.t.settings.station;
    final azimuth = values[_rotatorTargetAzimuthKey];
    if (azimuth is! num || azimuth < 0 || azimuth > 360) return FormActionResult(message: st.rotatorAzimuthInvalid);
    final elevation = rotatorHasElevation(node.config) ? values[_rotatorTargetElevationKey] : null;
    if (elevation != null && (elevation is! num || elevation < 0 || elevation > rotatorElevationCeiling)) {
      return FormActionResult(message: st.rotatorElevationInvalid);
    }
    final target = _cat.rotateTo(node.uuid, azimuth: azimuth, elevation: elevation as num?);
    // The node's limits turn a heading past them to the nearer one; the box
    // still saying what was typed is the operator's only other account of it.
    final held =
        target != null &&
        (rotatorHeadingGap(target.azimuth, azimuth.round()) > 0 || (target.elevation != null && target.elevation != (elevation as num).round()));
    if (!held) return const FormActionResult();
    return FormActionResult(
      message: st.rotatorHeldAtLimit(heading: _rotatorReading(st, target, elevation: rotatorHasElevation(node.config), short: false)),
    );
  }
}

/// Where [position] points, as the editor's header and its messages say it.
String _rotatorReading(Translations$settings$station$en st, RotatorPosition position, {required bool elevation, required bool short}) => [
  short ? st.rotatorAzimuthReadingShort(degrees: position.azimuth) : st.rotatorAzimuthReading(degrees: position.azimuth),
  if (elevation && position.elevation != null)
    short ? st.rotatorElevationReadingShort(degrees: position.elevation!) : st.rotatorElevationReading(degrees: position.elevation!),
].join(', ');

const _rotatorTargetAzimuthKey = 'rotatorTargetAzimuth';
const _rotatorTargetElevationKey = 'rotatorTargetElevation';
const _rotatorTurnAction = 'rotatorTurn';
const _rotatorStopAction = 'rotatorStop';
const _rotatorConnectAction = 'rotatorConnect';
const _rotatorDisconnectAction = 'rotatorDisconnect';
const _rotatorActions = {_rotatorTurnAction, _rotatorStopAction, _rotatorConnectAction, _rotatorDisconnectAction};

/// How often an open rotator editor rereads the heading.
const _rotatorReadoutRefresh = Duration(seconds: 1);

/// [elements] with each address beside the setting that completes it, on
/// one row, the second the narrower: a network pairing's host and the
/// number field after it (its port, under whichever key the transport
/// keeps it), and a serial pairing's port and speed. A rotator's azimuth
/// and elevation offsets share a row too, half each, as do each axis's
/// limits. The row takes the first field's `visibleWhen`, so it hides with
/// the pairing it belongs to; a member keeps its own, so an elevation
/// offset still hides beside its azimuth one.
List<Map<String, dynamic>> _addressRows(List<Map<String, dynamic>> elements) {
  bool pairs(Map<String, dynamic> first, Map<String, dynamic> next) => switch (first['key']) {
    'host' => next['fieldType'] == 'number',
    'port' => next['key'] == 'baudRate',
    rotatorAzimuthOffsetConfigKey => next['key'] == rotatorElevationOffsetConfigKey,
    rotatorAzimuthMinConfigKey => next['key'] == rotatorAzimuthMaxConfigKey,
    rotatorElevationMinConfigKey => next['key'] == rotatorElevationMaxConfigKey,
    _ => false,
  };
  bool even(Map<String, dynamic> first) => first['key'] != 'host' && first['key'] != 'port';
  final paired = <Map<String, dynamic>>[];
  for (var index = 0; index < elements.length; index++) {
    final element = elements[index];
    final next = index + 1 < elements.length ? elements[index + 1] : null;
    if (next != null && pairs(element, next)) {
      paired.add({
        'type': 'row',
        if (element['visibleWhen'] != null) 'visibleWhen': element['visibleWhen'],
        'elements': [
          {...element, 'flex': even(element) ? 1 : 7},
          {...next, 'flex': even(element) ? 1 : 3},
        ],
      });
      index++;
    } else {
      paired.add(element);
    }
  }
  return paired;
}

/// Whether [key] is one of the rotator's command boxes rather than a
/// setting — see [_rotatorCurrentState].
bool isRotatorFormKey(String key) => key == _rotatorTargetAzimuthKey || key == _rotatorTargetElevationKey;
