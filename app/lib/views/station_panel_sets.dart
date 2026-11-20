// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Current Configuration band's rows for each logging set and for the
// operator under both (docs/design/station-model.md § 6): set B's radio and
// picks, a set's folded details, where a radio's spectrum comes from, and
// the SO2R lines.

part of 'station_panel.dart';

extension _SetRows on StationPanel {
  /// A set's details, folded under their heading on the rig's ground,
  /// indented under the rig. The gap under the heading is the column's, and
  /// every row brings only the gap below it.
  List<Widget> _foldedDetails(
    BuildContext context,
    List<Widget> rows, {
    required String section,
    required EdgeInsets rowInset,
    required EdgeInsets detailsInset,
    required Color ground,
    required Set<String> expanded,
    required void Function(String section) toggle,
  }) {
    return [
      SectionHeader(
        context.t.settings.station.configurationSection,
        indent: detailsInset.left - rowInset.left,
        background: ground,
        expanded: expanded.contains(section),
        onTap: () => toggle(section),
      ),
      ColoredBox(
        color: ground,
        child: Padding(
          padding: const EdgeInsets.only(top: Space.md),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
        ),
      ),
    ];
  }

  /// SO2R's Radio B, under the Main VFO's row: the same row, picked from this
  /// station's own transceivers. The Main VFO's is offered too, and picking
  /// it takes it from set A ([CatService.setRadio2]).
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
            if (_cat.typeFor(node)?.category == kCategoryTransceiver) ...[
              TransceiverRow(
                name: _displayName(node),
                channel: _cat.channelNameFor(node),
                connection: connectionTextFor(context, _cat.typeFor(node), node.config),
                transportType: _cat.typeFor(node),
                selected: _cat.isRadio2(node.uuid),
                set: _cat.setOfRadio(node.uuid),
                connected: _cat.stateFor(node.uuid).status == EquipmentStatus.connected,
                onSelect: () => pick(node.uuid),
                onEdit: () => pick(node.uuid),
              ),
              ..._flexSliceRows(context, node, pick),
            ],
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
          channel: _cat.channelNameFor(node),
          onCloseChannel: _cat.canCloseFlexSlice(node.uuid) ? () => _closeFlexSlice(context, node.uuid) : null,
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
          key: ValueKey('so2rSwitch:${_cat.so2rSwitch}:${radio?.uuid}:${_cat.so2rComputerSwitches}'),
          label: st.so2rSwitch,
          nodes: _cat.so2rSwitchNodes,
          selected: _cat.so2rSwitch,
          displayName: _displayName,
          noneLabel: st.noneSelected,
          extras: [
            if (radio != null) (value: so2rSwitchRadios, label: st.so2rSwitchBuiltIn(radio: _displayName(radio))),
            if (_cat.so2rComputerSwitches) (value: so2rSwitchComputer, label: st.so2rSwitchComputer),
          ],
          onChanged: (pick) => unawaited(_cat.setSo2rSwitch(pick)),
        ),
        controls: [
          IconButton(
            icon: Icon(MdiIcons.tune, semanticLabel: st.so2rSwitchSettings),
            // Not for a pick the dropdown cannot show: the radios no longer
            // slices of one, or no longer both heard here, which reads as
            // None.
            onPressed:
                _cat.so2rSwitch == null ||
                    (_cat.so2rSwitch == so2rSwitchRadios && radio == null) ||
                    (_cat.so2rSwitch == so2rSwitchComputer && !_cat.so2rComputerSwitches)
                ? null
                : () => showSo2rSwitchSettingsDialog(context, services.settings),
          ),
        ],
      ),
    );
  }

  /// Where the station's position comes from: one of its GPS receivers, or
  /// the operating system's own location service, named as the operator
  /// knows it on this platform (docs/design/cat.md § GPS receivers). The
  /// radio row's shape — picker, glyph, the receiver, its plug — since a
  /// receiver is equipment the operator connects like a radio.
  Widget _gpsSourceRow(BuildContext context) {
    final st = context.t.settings.station;
    final system = switch (defaultTargetPlatform) {
      _ when kIsWeb => st.systemLocation.browser,
      TargetPlatform.windows => st.systemLocation.windows,
      TargetPlatform.macOS => st.systemLocation.macos,
      TargetPlatform.linux => st.systemLocation.linux,
      _ => st.systemLocation.device,
    };
    return TransceiverMenu(
      rows: (context, close) {
        void pick(String? uuid) {
          close();
          unawaited(_cat.setGpsSource(uuid));
        }

        return [
          for (final node in _cat.gpsReceiverNodes)
            TransceiverRow(
              name: _displayName(node),
              connection: connectionTextFor(context, _cat.typeFor(node), node.config),
              transportType: _cat.typeFor(node),
              category: kCategoryGps,
              glyphLabel: st.locationFromThis(name: _displayName(node)),
              selected: _cat.gpsReceiver == node.uuid,
              connected: _cat.stateFor(node.uuid).status == EquipmentStatus.connected,
              onSelect: () => pick(node.uuid),
              onEdit: () => pick(node.uuid),
            ),
          TransceiverRow(
            name: system,
            connection: '',
            category: kCategoryGps,
            glyphLabel: st.locationFromThis(name: system),
            selected: _cat.gpsReceiver == null,
            onSelect: () => pick(null),
            onEdit: () => pick(null),
          ),
        ];
      },
      builder: (context, toggle) {
        final picker = SizedBox.square(
          dimension: transceiverPickerWidth,
          child: IconButton(
            icon: Icon(MdiIcons.menuDown, semanticLabel: st.chooseLocationSource),
            onPressed: toggle,
          ),
        );
        final uuid = _cat.gpsReceiver;
        final node = uuid == null ? null : _cat.nodeFor(uuid);
        if (node == null) {
          return CurrentRowFrame(
            leading: picker,
            child: ListTile(
              leading: const TransceiverGlyph.bare(inUse: true, category: kCategoryGps),
              title: Text(system, style: const TextStyle(fontWeight: FontWeight.bold)),
              onTap: toggle,
              mouseCursor: SystemMouseCursors.click,
            ),
          );
        }
        final state = _cat.stateFor(node.uuid);
        return CurrentTransceiverTile(
          displayName: _displayName(node),
          connection: connectionTextFor(context, _cat.typeFor(node), node.config),
          transportType: _cat.typeFor(node),
          category: kCategoryGps,
          state: state,
          // No reading at all is not a search: a receiver without a fix
          // still reports one every second, so nothing yet is nothing heard —
          // a firewall, a sender aimed elsewhere, a port that is not NMEA.
          reading: switch (state.gps) {
            final gps? => _gpsReading(context, gps),
            null => st.gpsWaiting,
          },
          unconfigured: _cat.typeFor(node)?.isUnconfigured(node.config) ?? false,
          onEdit: () => _editEquipment(context, node),
          onConnect: () => _cat.connect(node.uuid),
          onDisconnect: () => _cat.disconnect(node.uuid),
          picker: picker,
        );
      },
    );
  }

  /// Set B's own antenna, logged key or CW keying, from [nodes]: the picks
  /// are per radio, and a contact logged on Radio B, or a message keyed from
  /// its set, uses these.
  Widget _radio2PickRow(BuildContext context, String category, List<EquipmentNode> nodes, {required EdgeInsets inset}) {
    final st = context.t.settings.station;
    final radio2 = _cat.radio2!;
    final isKey = category == kCategoryKey;
    return Padding(
      padding: EdgeInsets.fromLTRB(inset.left, 0, inset.right, Space.md),
      child: DesignationDropdown(
        key: ValueKey('radio2:$category:${_cat.designatedFor(category, radio: radio2)}'),
        label: switch (category) {
          kCategoryKey => st.keyInUse,
          kDesignationLoggedKey => st.loggedKey,
          _ => st.antennaInUse,
        },
        nodes: isKey
            // Never set A's key: one key keys one radio's messages.
            ? [
                for (final node in nodes)
                  if (node.uuid != _cat.designatedFor(kCategoryKey)) node,
              ]
            : nodes,
        selected: _cat.designatedFor(category, radio: radio2),
        displayName: isKey
            ? (node) => _cat.typeFor(node)?.category == kCategoryTransceiver ? st.keyViaRadio(radio: _displayName(node)) : _displayName(node)
            : _displayName,
        noneLabel: st.noneSelected,
        onChanged: (uuid) => unawaited(_cat.setDesignated(category, uuid, radio: radio2)),
      ),
    );
  }

  /// Where [uuid]'s spectrum comes from: its own scope, or an SDR. Only for
  /// a radio of this station's, and only while SDR receivers are on and the
  /// station has one. [radio] names it as `CatService.designatedFor` does:
  /// null for set A's.
  Widget? _scopeRow(BuildContext context, String? uuid, {required String? radio, required EdgeInsets inset}) {
    if (uuid == null || !services.settings.experimentEnabled('fall') /* stored key, see experiments.yaml */ ) return null;
    final sdrs = [
      for (final node in _cat.nodes)
        // Never set A's for set B: an SDR follows one radio's dial.
        if (_cat.typeFor(node)?.category == kCategorySdr && (radio == null || node.uuid != _cat.designatedFor(kCapabilityScope))) node,
    ];
    if (sdrs.isEmpty) return null;
    final st = context.t.settings.station;
    final picked = _cat.designatedFor(kCapabilityScope, radio: radio);
    return Padding(
      padding: EdgeInsets.fromLTRB(inset.left, 0, inset.right, Space.md),
      child: DesignationDropdown(
        key: ValueKey('scope:$uuid:$picked'),
        label: st.scopeInUse,
        nodes: sdrs,
        selected: picked,
        displayName: _displayName,
        noneLabel: st.scopeRadiosOwn,
        onChanged: (pick) => unawaited(_cat.setDesignated(kCapabilityScope, pick, radio: radio)),
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
    final parts = phoneKeyingParts(context, services, radio: radio, namesRadio: false);
    return _keyingLine(picker: parts.picker, controls: parts.controls);
  }

  /// After the last of a Flex's entries, a row for each slice open on the
  /// radio that has none yet: picking it adds it ([CatService.addFlexSlice])
  /// and picks it. Where the radio's slices are held by more than one
  /// station, each says whose it is ([CatDevices.flexSliceName]).
  List<Widget> _flexSliceRows(BuildContext context, EquipmentNode node, void Function(String uuid) pick) {
    final device = _cat.deviceEntryFor(node.uuid);
    final listed = _cat.nodeFor(device);
    if (listed == null || _cat.entriesOf(device).last != node.uuid) return const [];
    final slices = _cat.flexSlicesToAdd(device);
    void add(String key) => unawaited(
      _cat.addFlexSlice(device, key).then((id) {
        if (id != null) pick(id);
      }),
    );
    // A slice of HaLo's own: HaLo becomes a station on the radio for it,
    // which only a radio with a slice free can take.
    final refused = context.t.settings.station.flexNewSliceRefused;
    void open() => unawaited(
      _cat.openFlexSlice(device).then((id) {
        if (id == null) return _flexSliceNotice(refused);
        pick(id);
      }),
    );
    final connection = connectionTextFor(context, _cat.typeFor(listed), listed.config);
    return [
      for (final slice in slices)
        TransceiverRow(
          name: _displayName(listed),
          channel: _cat.flexSliceName(device, slice.key),
          connection: connection,
          transportType: _cat.typeFor(listed),
          selected: false,
          onSelect: () => add(slice.key),
          onEdit: () => add(slice.key),
        ),
      if ((_cat.flexFreeSlices(device) ?? 0) > 0)
        TransceiverRow(
          name: _displayName(listed),
          channel: context.t.settings.station.flexNewSlice,
          connection: connection,
          transportType: _cat.typeFor(listed),
          selected: false,
          onSelect: open,
          onEdit: open,
        ),
    ];
  }

  /// What SmartSDR and the radio's other stations call HaLo's own station
  /// on a Flex: this computer's name unless the operator names it.
  List<Map<String, dynamic>> _flexStationNameElements(BuildContext context, EquipmentModel model) {
    if (!model.variants.any((variant) => variant.driver is FlexRadioDriver)) return const [];
    final st = context.t.settings.station;
    return [
      {
        'type': 'field',
        'fieldType': 'text',
        'key': flexStationNameConfigKey,
        'label': isMobilePlatform ? st.flexStationNameDevice : st.flexStationNameComputer,
        'description': st.flexStationNameDescription,
        if (resolvedDeviceIdentity?.name case final name? when name.isNotEmpty) 'placeholder': name,
      },
    ];
  }

  /// Closes HaLo's own slice [uuid] on the radio, from the X on its pill,
  /// and says so when the radio did not.
  void _closeFlexSlice(BuildContext context, String uuid) {
    final refused = context.t.settings.station.flexCloseSliceRefused;
    unawaited(
      _cat.closeFlexSlice(uuid).then((closed) {
        if (!closed) _flexSliceNotice(refused);
      }),
    );
  }

  /// A slice HaLo asked the radio to open or close, and the radio did not:
  /// said once, as it happens, with nothing on any row to show for it.
  void _flexSliceNotice(String text) => services.statusBar.showNotice(key: 'flex:slice', icon: 'radio', text: text, persist: false);

  /// Where the set's radio is heard, and where its microphone is: in HaLo,
  /// or on the radio itself. Chosen per set's radio, since a slice of a
  /// Flex is a receiver the radio's editor does not reach.
  Widget? _radioAudioRow(BuildContext context, String? uuid, {required EdgeInsets inset}) {
    if (uuid == null) return null;
    final st = context.t.settings.station;
    final here = isMobilePlatform ? st.audioOnThisDevice : st.audioOnThisComputer;
    const onRadio = 'radio', onHere = 'here', cardPrefix = 'card:';
    // On the radio, through the radio's own audio, or through one of this
    // computer's sound cards (a radio on a USB codec): a card picked that is
    // not listed now stays shown by its name, rather than reading as None.
    Widget choice(
      String label, {
      required bool own,
      required bool ownPicked,
      required List<Capability> cards,
      required ({String? id, String? name})? picked,
      required Future<void> Function(bool on) setOwn,
      required Future<void> Function(AudioDevice card) setCard,
    }) {
      final value = switch (picked) {
        (:final id, name: _)? => '$cardPrefix$id',
        null => ownPicked ? onHere : onRadio,
      };
      final listed = {for (final card in cards) card.key};
      return DropdownButtonFormField<String>(
        key: ValueKey('$label:$uuid:$value'),
        isExpanded: true,
        initialValue: value,
        icon: dropdownTrailingIcon,
        decoration: poloFieldDecoration(context, label),
        menuMaxHeight: dropdownMenuMaxHeight(context),
        items: [
          if (own || ownPicked)
            DropdownMenuItem(
              value: onHere,
              child: Text(here, overflow: TextOverflow.ellipsis),
            ),
          for (final card in cards)
            DropdownMenuItem(
              value: '$cardPrefix${card.key}',
              child: Text(st.audioThroughCard(name: card.name ?? card.key), overflow: TextOverflow.ellipsis),
            ),
          if (picked case (:final id, :final name)? when !listed.contains(id))
            DropdownMenuItem(
              value: value,
              child: Text(st.audioThroughCard(name: name ?? id ?? ''), overflow: TextOverflow.ellipsis),
            ),
          DropdownMenuItem(
            value: onRadio,
            child: Text(st.audioOnTheRadio, overflow: TextOverflow.ellipsis),
          ),
        ],
        onChanged: (pick) {
          if (pick == null || pick == value) return;
          if (pick.startsWith(cardPrefix)) {
            for (final card in cards) {
              if ('$cardPrefix${card.key}' == pick) unawaited(setCard(AudioDevice(id: card.key, name: card.name ?? card.key)));
            }
          } else {
            unawaited(setOwn(pick == onHere));
          }
        },
      );
    }

    final heardCards = _cat.computerCards(input: true);
    final talkCards = _cat.takesCardMicrophone(uuid) ? _cat.computerCards(input: false) : const <Capability>[];
    final heard = _cat.heardCard(uuid), talked = _cat.talkCard(uuid);
    final choices = [
      if (_cat.offersReceiveAudio(uuid) || heardCards.isNotEmpty || heard != null)
        choice(
          st.listenToAudio,
          own: _cat.offersReceiveAudio(uuid),
          ownPicked: _cat.hearsInHalo(uuid),
          cards: heardCards,
          picked: heard,
          setOwn: (on) => _cat.setHearsInHalo(uuid, on),
          setCard: (card) => _cat.setHeardCard(uuid, card),
        ),
      if (_cat.offersTalkAudio(uuid) || talkCards.isNotEmpty || talked != null)
        choice(
          st.microphone,
          own: _cat.offersTalkAudio(uuid),
          ownPicked: _cat.talksThroughHalo(uuid),
          cards: talkCards,
          picked: talked,
          setOwn: (on) => _cat.setTalksThroughHalo(uuid, on),
          setCard: (card) => _cat.setTalkCard(uuid, card),
        ),
    ];
    if (choices.isEmpty) return null;
    return Padding(
      padding: EdgeInsets.fromLTRB(inset.left, 0, inset.right, Space.md),
      child: Row(
        spacing: Space.md,
        children: [for (final choice in choices) Expanded(child: choice)],
      ),
    );
  }
}
