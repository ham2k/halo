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
                set: _setOf(node.uuid),
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

  /// Set B's own antenna or key, from [nodes]: the picks are per radio, and
  /// a contact logged on Radio B, or a message keyed from its set, uses
  /// these.
  Widget _radio2PickRow(BuildContext context, String category, List<EquipmentNode> nodes, {required EdgeInsets inset}) {
    final st = context.t.settings.station;
    final radio2 = _cat.radio2!;
    final isKey = category == kCategoryKey;
    return Padding(
      padding: EdgeInsets.fromLTRB(inset.left, 0, inset.right, Space.md),
      child: DesignationDropdown(
        key: ValueKey('radio2:$category:${_cat.designatedFor(category, radio: radio2)}'),
        label: isKey ? st.keyInUse : st.antennaInUse,
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
    return [
      for (final slice in slices)
        TransceiverRow(
          name: _displayName(listed),
          channel: _cat.flexSliceName(device, slice.key),
          connection: connectionTextFor(context, _cat.typeFor(listed), listed.config),
          transportType: _cat.typeFor(listed),
          selected: false,
          onSelect: () => add(slice.key),
          onEdit: () => add(slice.key),
        ),
    ];
  }

  /// The logging set [uuid] is the radio of, for a picker's row to say so.
  String? _setOf(String uuid) => _cat.isRadio1(uuid)
      ? kSetA
      : _cat.isRadio2(uuid)
      ? kSetB
      : null;
}
