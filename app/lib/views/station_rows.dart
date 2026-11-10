// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The rows Station Configuration is built from — the current transceiver,
// the inventory's rows, and the small pieces they share. Split from
// station_panel.dart, which assembles them.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'equipment_glyphs.dart';
import '../services/cat/equipment.dart';
import '../services/cat/equipment_registry.dart';
import 'operation/radio/radio_faces.dart' show powerText;
import '../services/cat/drivers/icom_civ_driver.dart' show civScopeAdjustApp, civScopeAdjustConfigKey, civScopeAdjustRadio;
import '../services/cat/transports/none_transport.dart';
import '../services/cat/transports/everyware_transport.dart' show EverywareDeviceTransport;
import '../services/cat/transports/serial_transport_config.dart';
import '../services/peer/peer_station_radios.dart';
import '../services/cat/cat_service.dart';
import '../services/cat/radio_modes.dart';
import 'station_panel.dart';

/// Which of the panel's folding sections are open — the inventory's, and
/// the current transceiver's More details. Above the list rather than in each
/// header, because a [SectionHeader] must be a direct child of the
/// [SectionedListView] and so cannot hold state of its own. Everything starts
/// closed: the current transceiver above says what is in use, and the rest
/// is visited to change it.
class StationExpansionScope extends StatefulWidget {
  final Widget Function(BuildContext context, Set<String> expanded, void Function(String section) toggle) builder;

  const StationExpansionScope({super.key, required this.builder});

  @override
  State<StationExpansionScope> createState() => _StationExpansionScopeState();
}

class _StationExpansionScopeState extends State<StationExpansionScope> {
  final _expanded = <String>{};

  void _toggle(String section) => setState(() => _expanded.contains(section) ? _expanded.remove(section) : _expanded.add(section));

  @override
  Widget build(BuildContext context) => widget.builder(context, _expanded, _toggle);
}

/// The rig driving the main VFO. Two lines: its name against whether it is
/// connected, then what it is doing against where it is — in the content
/// column, led by the glyph the inventory gives it, with the picker and the
/// plug out in the margins ([CurrentRowFrame]).
class CurrentTransceiverTile extends StatelessWidget {
  final String displayName;
  final String connection;
  final EquipmentType? transportType;

  /// The way to pick a different radio — the picker's down arrow.
  final Widget? picker;
  final EquipmentState state;
  final bool unconfigured;
  final VoidCallback onEdit;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  const CurrentTransceiverTile({
    super.key,
    required this.displayName,
    required this.connection,
    this.transportType,
    this.picker,
    required this.state,
    required this.unconfigured,
    required this.onEdit,
    required this.onConnect,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final connected = state.status == EquipmentStatus.connected;
    final busy = state.status == EquipmentStatus.connecting || state.status == EquipmentStatus.disconnecting;
    final trouble = state.status == EquipmentStatus.error ? state.error : state.problem;
    final small = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    // Connected, but the radio has stopped answering: shown as the loss it
    // is — the unplugged plug, whose tap reconnects, and a red word where a
    // reading minutes old would otherwise pass for a live one.
    final lost = connected && state.stale;

    return CurrentRowFrame(
      leading: picker,
      trailing: RowPlug(busy: busy, connected: connected && !lost, onConnect: unconfigured ? null : onConnect, onDisconnect: onDisconnect),
      child: ListTile(
        leading: const TransceiverGlyph.bare(inUse: true),
        title: Row(
          children: [
            Expanded(
              child: Text(
                displayName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (transportType case final type?) ...[
              const SizedBox(width: Space.lg),
              TransportIcons(types: [type]),
            ],
          ],
        ),
        // spaceBetween with two Flexibles, not Expanded: a loose child that
        // uses less than its share leaves the slack at the END of the row,
        // which would keep the connection text off the right edge.
        subtitle: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: trouble != null
                  ? Text(
                      trouble,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                    )
                  : lost
                  ? Text(
                      context.t.settings.station.statusLost,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
                    )
                  // Not connected (or on the way there or back): the state, in
                  // the slot the reading takes, rather than a reading that is
                  // not live.
                  : !connected
                  ? Text(
                      equipmentStatusLabel(context, state),
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    )
                  : RadioReading(state: state),
            ),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(left: Space.lg),
                child: Text(
                  connection,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: unconfigured ? small?.copyWith(fontStyle: FontStyle.italic) : small,
                ),
              ),
            ),
          ],
        ),
        onTap: onEdit,
        mouseCursor: SystemMouseCursors.click,
      ),
    );
  }
}

/// One radio in the inventory: its name and where it is. The icon is the
/// main-VFO pick — lit on the radio in use, and tapping another's moves the
/// pick there. In the inventory the row ends with its plug ([plug]); in the
/// pickers, where a tap picks the radio, it does not.
class TransceiverRow extends StatelessWidget {
  final String name;
  final String connection;
  final EquipmentType? transportType;

  /// The glyph where there is no [transportType] to draw one — a peer's
  /// radio, whose connection is the other device's.
  final IconData? connectionIcon;

  /// Which channel of a multi-channel radio this node is ("Slice B"). Two
  /// slices of one Flex share a name and an address, and this is all that
  /// tells their rows apart.
  final String? channel;

  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback? onEdit;

  /// The radio's [RowPlug], on an inventory row.
  final RowPlug? plug;

  /// The radio's live state, on an inventory row: its second line is then
  /// what the radio is doing in place of [connection] — its reading while
  /// connected, why it failed or is misconfigured, that it is [unconfigured],
  /// and otherwise nothing, its name centred. The pickers, where the address
  /// tells two radios apart, pass none.
  ///
  /// The failure is the row's to say: ErrorPolicy keeps an unreachable radio
  /// off the screen because its row says so, and a connect started from this
  /// row's plug has no other place it would show.
  final EquipmentState? state;

  /// Whether the radio has nowhere to connect to yet, which is why its plug
  /// is disabled — said on the row, since a disabled control has no hover
  /// label to say it ([state] rows only).
  final bool unconfigured;

  const TransceiverRow({
    super.key,
    required this.name,
    required this.connection,
    this.transportType,
    this.channel,
    this.connectionIcon,
    required this.selected,
    required this.onSelect,
    this.onEdit,
    this.plug,
    this.state,
    this.unconfigured = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final st = context.t.settings.station;
    final inset = (ListTileTheme.of(context).contentPadding ?? EdgeInsets.zero).resolve(Directionality.of(context));
    final row = ListTile(
      // The glyph's button hangs into the margin, so the glyph sits on the
      // row's edge and the label right after it (see [TransceiverGlyph]).
      // With a plug, the trailing margin is the plug's ([PluggedRow]).
      contentPadding: inset.copyWith(left: math.max(0.0, inset.left - rowButtonOverhang), right: plug == null ? null : currentRowGutters(context).right),
      horizontalTitleGap: 0,
      leading: TransceiverGlyph(
        inUse: selected,
        semanticLabel: selected ? st.mainVfo : st.makeMainVfo(name: name),
        onPressed: selected ? null : onSelect,
      ),
      title: Row(
        children: [
          // Expanded, not a Flexible name beside a Spacer: the two would
          // split the slack, and whatever a short name leaves of its half
          // lands after the glyph, keeping it off the right edge.
          Expanded(
            child: Row(
              children: [
                Flexible(child: Text(name, overflow: TextOverflow.ellipsis)),
                if (channel case final channel?) ...[
                  const SizedBox(width: Space.md),
                  StationPill(label: channel, background: theme.colorScheme.surfaceContainerHighest, foreground: theme.colorScheme.onSurfaceVariant),
                ],
              ],
            ),
          ),
          if (transportType case final type?) ...[
            const SizedBox(width: Space.lg),
            TransportIcons(types: [type]),
          ] else if (connectionIcon case final icon?) ...[
            const SizedBox(width: Space.lg),
            Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          ],
        ],
      ),
      // None rather than an empty line ("No transceiver"), so the name
      // centres on the row.
      subtitle: switch (state) {
        final live? => switch ((live.status == EquipmentStatus.error ? live.error : null) ?? live.problem) {
          final trouble? => Text(
            trouble,
            // Two lines' worth: these say what to do about it.
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
          ),
          null when live.status == EquipmentStatus.connected => RadioReading(state: live),
          null when unconfigured => Text(
            st.notConfigured,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic),
          ),
          null => null,
        },
        null when connection.isEmpty => null,
        null => Text(
          connection,
          textAlign: TextAlign.right,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      },
      onTap: onEdit,
      mouseCursor: onEdit == null ? null : SystemMouseCursors.click,
    );
    return plug == null ? row : PluggedRow(plug: plug!, child: row);
  }
}

/// The peer's radio driving `vfoA`, heading the panel in the Current
/// Transceiver band.
///
/// Deliberately not an [EquipmentTile]: there is no [EquipmentNode] behind
/// it and none of that row's controls apply — a peer's rig is connected,
/// edited and removed on the device it is plugged into.
class PeerVfoTile extends StatelessWidget {
  final PeerRadioSelection selection;

  /// Whether the peer is offering it right now. False keeps the row, saying
  /// so: the pick survives the peer walking away and re-engages by itself,
  /// so a row that vanished would read as a selection that had been dropped.
  final bool available;

  final Widget? picker;

  /// What a tap on the row does — it has nothing here to edit.
  final VoidCallback? onTap;

  const PeerVfoTile({super.key, required this.selection, required this.available, this.picker, this.onTap});

  @override
  Widget build(BuildContext context) {
    final st = context.t.settings.station;
    final theme = Theme.of(context);

    return CurrentRowFrame(
      leading: picker,
      child: ListTile(
        leading: const TransceiverGlyph.bare(inUse: true),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // The same 3:2 split, name-with-pill against address, that
            // [EquipmentTile] uses — these rows sit under one another.
            Flexible(
              flex: 3,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Falling back to the id like the dropdown does: a pick made
                  // as the peer dropped is stored with empty names, and a row
                  // with a blank title names nothing at all.
                  Flexible(child: Text(selection.radioName.isEmpty ? selection.radioId : selection.radioName, overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: Space.md),
                  // Always: a peer selection IS the main VFO, or it would not
                  // be stored at all.
                  Flexible(
                    child: StationPill(label: st.mainVfo, background: theme.colorScheme.secondaryContainer, foreground: theme.colorScheme.onSecondaryContainer),
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
                  st.peerRadioOnDevice(device: selection.deviceName.isEmpty ? selection.deviceId : selection.deviceName),
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          ],
        ),
        onTap: onTap,
        mouseCursor: onTap == null ? null : SystemMouseCursors.click,
        subtitle: available ? null : Text(st.peerRadioNotAvailable, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ),
    );
  }
}

class EquipmentTile extends StatelessWidget {
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

  const EquipmentTile({
    super.key,
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
      final target = resolvedType.describeTarget(node.config);
      return ListTile(
        leading: Icon(iconForCategory(resolvedType.category)),
        title: Text(displayName),
        // None rather than an empty line, so the name centres on the row.
        subtitle: target.isEmpty ? null : AddressText(target),
        onTap: onEdit,
        mouseCursor: SystemMouseCursors.click,
      );
    }

    // Both directions take time and both deserve the spinner: connecting
    // negotiates a handshake, disconnecting sends a goodbye that must not be
    // rushed.
    final busy = state.status == EquipmentStatus.connecting || state.status == EquipmentStatus.disconnecting;
    final vfo = state.vfo;
    final connected = state.status == EquipmentStatus.connected;
    final unconfigured = resolvedType.isUnconfigured(node.config);

    // A problem is connected-but-misconfigured (a Flex pointed at a slice
    // the radio isn't running). It takes the same whole-row treatment as a
    // failure, for the same reason: a reason squeezed beside the frequency
    // it explains the absence of is not a reason.
    final trouble = state.status == EquipmentStatus.error ? state.error : state.problem;
    final failed = trouble != null;
    final diagnostic = developerMode ? state.diagnostic : null;
    // Whether the second line has anything on it: equipment with no reading
    // (a keyer, an antenna switch, a radio not yet connected) is one line,
    // its name centred, rather than a name over an empty line.
    final secondLine = failed || vfo.mode != null || vfo.freqKHz != null || diagnostic != null || connected;
    final inset = (ListTileTheme.of(context).contentPadding ?? EdgeInsets.zero).resolve(Directionality.of(context));

    // Two lines. The top one is identity — what it is, then where it is.
    // The bottom is what it is doing, EXCEPT when something went wrong, in
    // which case the reason takes the whole row: an explanation squeezed
    // into half a line and ellipsized is not an explanation.
    //
    // Both rows split with spaceBetween rather than a Spacer or a trailing
    // Expanded: a flex child that uses LESS than its share leaves the slack
    // at the END of the row, which keeps the right-hand items from reaching
    // the edge.
    return PluggedRow(
      // Disabled rather than hidden: the row keeps its shape, and the plug
      // says there is a connection here to make once it has somewhere to go.
      plug: RowPlug(busy: busy, connected: connected, onConnect: unconfigured ? null : onConnect, onDisconnect: onDisconnect),
      child: ListTile(
        // A device under an Everyware server sits under it, indented: it is
        // that server's, not equipment of its own standing.
        contentPadding: inset.copyWith(
          left: inset.left + (resolvedType.transportKey == EverywareDeviceTransport.transportKey ? Space.xl : 0),
          right: currentRowGutters(context).right,
        ),
        leading: Icon(iconForCategory(resolvedType.category)),
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
                  // Which channel of the radio this node is, beside its name:
                  // a shack with two Flex slices has two rows whose addresses
                  // are identical, and the slice is the only thing telling them
                  // apart. Neutral rather than accented — it names the node,
                  // it does not flag anything about it, unlike the Main VFO
                  // pill it sits next to.
                  if (resolvedType.describeChannel(node.config) case final channel?) ...[
                    const SizedBox(width: Space.md),
                    Flexible(
                      child: StationPill(label: channel, background: theme.colorScheme.surfaceContainerHighest, foreground: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                  // Beside the name: which radio drives the logging panel is
                  // part of what this equipment IS, not what it is doing.
                  if (isMainVfo) ...[
                    const SizedBox(width: Space.md),
                    // Flexible, because the pill has an intrinsic width and a
                    // non-flex child in a bounded Row overflows rather than
                    // shrinking — the name collapses to nothing and the row
                    // still blows past the edge by whatever the pill needed.
                    Flexible(
                      child: StationPill(
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
                      child: unconfigured
                          ? Text(
                              st.notConfigured,
                              textAlign: TextAlign.right,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic),
                            )
                          : AddressText(
                              resolvedType.describeTarget(node.config),
                              textAlign: TextAlign.right,
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                    ),
                    const SizedBox(width: Space.sm),
                    // How it is plugged in, right where it says where it is.
                    TransportIcons(types: [resolvedType]),
                  ],
                ),
              ),
            ),
          ],
        ),
        subtitle: !secondLine
            ? null
            : failed
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
                  // and an error is the row state that most needs it.
                  if (diagnostic != null)
                    Text(
                      diagnostic,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: HaLoColors.of(context).devMode),
                    ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: VfoReadout(
                      mode: vfo.mode,
                      freqKHz: vfo.freqKHz,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        // Dimmed once it is no longer being confirmed. The
                        // number is the last thing the radio actually said,
                        // and how old it is matters as much as what it is.
                        color: state.stale ? theme.colorScheme.onSurfaceVariant : HaLoColors.of(context).onSurfaceAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (diagnostic != null)
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.only(left: Space.lg),
                        child: Text(
                          diagnostic,
                          textAlign: TextAlign.right,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(color: HaLoColors.of(context).devMode),
                        ),
                      ),
                    ),
                  if (connected)
                    Padding(
                      padding: const EdgeInsets.only(left: Space.lg),
                      child: StationPill(
                        // A link that is up but silent must not wear the same
                        // confident green as one that is working: the
                        // frequency shown may be minutes old.
                        label: equipmentStatusLabel(context, state),
                        background: state.stale ? theme.colorScheme.error : connectedGreen(theme),
                        foreground: Colors.white,
                      ),
                    ),
                ],
              ),
        onTap: onEdit,
        mouseCursor: SystemMouseCursors.click,
      ),
    );
  }
}

/// A connected radio's reading — mode, frequency and power, as one — on the
/// current transceiver's row and the inventory's. Dimmed once the radio has
/// stopped confirming it: the number is the last thing the radio said, and
/// how old it is matters as much as what it is.
class RadioReading extends StatelessWidget {
  final EquipmentState state;

  const RadioReading({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium?.copyWith(
      color: state.stale ? theme.colorScheme.onSurfaceVariant : HaLoColors.of(context).onSurfaceAccent,
      fontWeight: FontWeight.w600,
    );
    final power = state.power;
    return Row(
      children: [
        Flexible(
          child: VfoReadout(mode: state.vfo.mode, freqKHz: state.vfo.freqKHz, style: style),
        ),
        if (power != null) ...[const SizedBox(width: Space.lg), Text('${powerText(power)} ${context.t.operation.layout.panels.radioWatts}', style: style)],
      ],
    );
  }
}

/// A rig's mode and frequency, as it reports them. The frequency holds its
/// decimals while the dial turns ([FreqDecimalsHold]): this row is the app's
/// live view of where the rig is, and must not change width at every step.
class VfoReadout extends StatefulWidget {
  final String? mode;
  final double? freqKHz;
  final TextStyle? style;

  const VfoReadout({super.key, required this.mode, required this.freqKHz, required this.style});

  @override
  State<VfoReadout> createState() => _VfoReadoutState();
}

class _VfoReadoutState extends State<VfoReadout> {
  late final _hold = FreqDecimalsHold(onSettle: () => setState(() {}));

  @override
  void initState() {
    super.initState();
    if (widget.freqKHz case final khz?) _hold.note(khz);
  }

  @override
  void didUpdateWidget(VfoReadout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.freqKHz case final khz?) _hold.note(khz);
  }

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final freqKHz = widget.freqKHz;
    return Text(
      [?widget.mode, if (freqKHz != null) fmtFreq(freqKHz, minDecimals: _hold.decimals)].join('  '),
      overflow: TextOverflow.ellipsis,
      style: widget.style,
    );
  }
}

/// A small rounded label. Same shape as activity_rows.dart's `ActivityRowChip` —
/// nothing pill-like is exported from halo_widgets, and that chip says the
/// same kind of thing about a row. Plain logical
/// pixels: the Font Scale setting scales the whole UI from one root wrapper
/// (docs/design/ui-scaling.md).
class StationPill extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;

  const StationPill({super.key, required this.label, required this.background, required this.foreground});

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
class StationConnectionToggle extends StatelessWidget {
  final bool busy;
  final bool connected;
  final VoidCallback? onConnect;
  final VoidCallback onDisconnect;

  const StationConnectionToggle({super.key, required this.busy, required this.connected, required this.onConnect, required this.onDisconnect});

  @override
  Widget build(BuildContext context) {
    final st = context.t.settings.station;
    final theme = Theme.of(context);

    if (busy) return const ConnectionBusySpinner();

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
        color: connected ? connectedGreen(theme) : theme.colorScheme.onSurfaceVariant,
      ),
      onPressed: connected ? onDisconnect : onConnect,
    );
  }
}

/// Whether HaLo adjusts [node]'s bandscope ([civScopeAdjustConfigKey]) —
/// offered for the radios in use, A and SO2R's B, where the scope is the
/// radio's own screen. [onChanged] hears only a change.
class ScopeAdjustField extends StatelessWidget {
  final EquipmentNode node;
  final String label;
  final ValueChanged<String> onChanged;

  const ScopeAdjustField({super.key, required this.node, required this.label, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final st = context.t.settings.station;
    final value = node.config[civScopeAdjustConfigKey] == civScopeAdjustRadio ? civScopeAdjustRadio : civScopeAdjustApp;
    return DropdownButtonFormField<String>(
      // Keyed on the value: FormFieldState reads initialValue once.
      key: ValueKey('civScopeAdjust:${node.uuid}:$value'),
      isExpanded: true,
      initialValue: value,
      icon: dropdownTrailingIcon,
      decoration: poloFieldDecoration(context, label),
      menuMaxHeight: dropdownMenuMaxHeight(context),
      items: [
        DropdownMenuItem(
          value: civScopeAdjustApp,
          child: Text(st.civScopeAdjustApp, overflow: TextOverflow.ellipsis),
        ),
        DropdownMenuItem(
          value: civScopeAdjustRadio,
          child: Text(st.civScopeAdjustRadio, overflow: TextOverflow.ellipsis),
        ),
      ],
      onChanged: (picked) => picked == null || picked == value ? null : onChanged(picked),
    );
  }
}

/// Picks which node of a single-designation category (antenna, key) is "in
/// use" — the same shape as the main VFO dropdown above it, minus the tune
/// button since these nodes have nothing to connect.
class DesignationDropdown extends StatelessWidget {
  final String label;
  final List<EquipmentNode> nodes;
  final String? selected;
  final String Function(EquipmentNode node) displayName;
  final String noneLabel;
  final void Function(String? uuid) onChanged;

  /// Picks that are not nodes of this station — the peer whose radio keys
  /// (HALO-585). Listed like the rest so an operator who pointed this radio
  /// at a local key has a way back to it; a menu whose default is missing
  /// from its own list is one that cannot be re-chosen.
  final List<({String value, String label})> extras;

  /// On a dialog's band, where a field takes the surface as its fill.
  final bool filled;

  const DesignationDropdown({
    super.key,
    required this.label,
    required this.nodes,
    required this.selected,
    required this.displayName,
    required this.noneLabel,
    required this.onChanged,
    this.extras = const [],
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final known = nodes.any((n) => n.uuid == selected) || extras.any((e) => e.value == selected);
    final decoration = poloFieldDecoration(context, label);
    return DropdownButtonFormField<String?>(
      isExpanded: true,
      initialValue: known ? selected : null,
      icon: dropdownTrailingIcon,
      decoration: filled ? decoration.copyWith(filled: true, fillColor: Theme.of(context).colorScheme.surface) : decoration,
      menuMaxHeight: dropdownMenuMaxHeight(context),
      items: [
        DropdownMenuItem<String?>(value: null, child: Text(noneLabel)),
        for (final node in nodes)
          DropdownMenuItem<String?>(
            value: node.uuid,
            child: Text(displayName(node), overflow: TextOverflow.ellipsis),
          ),
        for (final extra in extras)
          DropdownMenuItem<String?>(
            value: extra.value,
            child: Text(extra.label, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

/// The transceiver glyph a radio's row leads with: accented on the radio in
/// use, and on an inventory row the way to make that radio the main VFO.
///
/// The glyph sits ON the row's leading edge, and its button's touch area
/// hangs [rowButtonOverhang] into the margin before it — a row leading with the button
/// takes that much off its leading inset and puts no gap of its own before
/// the title ([TransceiverRow]). [TransceiverGlyph.bare] is the glyph alone,
/// for a row with nothing to do on it, which leaves [rowButtonOverhang] before its
/// title instead ([CurrentRowFrame]): either way the label starts the same
/// distance from the glyph.
class TransceiverGlyph extends StatelessWidget {
  final bool inUse;
  final String? semanticLabel;
  final VoidCallback? onPressed;
  final bool _bare;

  const TransceiverGlyph({super.key, required this.inUse, this.semanticLabel, this.onPressed}) : _bare = false;

  const TransceiverGlyph.bare({super.key, required this.inUse}) : semanticLabel = null, onPressed = null, _bare = true;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = Icon(
      iconForCategory(kCategoryTransceiver),
      size: _rowButtonIconSize,
      color: inUse ? scheme.primary : scheme.onSurface.withValues(alpha: 0.38),
      semanticLabel: semanticLabel,
    );
    if (_bare) return icon;
    return SizedBox(
      width: _rowButtonWidth,
      child: IconButton(icon: icon, onPressed: onPressed),
    );
  }
}

const _rowButtonIconSize = 24.0;

/// A row-edge button's width, fixed whatever the platform's density makes of
/// an IconButton, so [rowButtonOverhang] is the same on every row.
const _rowButtonWidth = kMinInteractiveDimension;

/// How far the transceiver glyph's button reaches past its icon on each side.
/// An inventory row hangs that much of the button into its leading margin, so
/// the icon itself sits on the row's edge and the touch area keeps its full
/// size ([TransceiverGlyph]).
const rowButtonOverhang = (_rowButtonWidth - _rowButtonIconSize) / 2;

/// A row's plug, at a fixed width whatever the platform's density makes of
/// an IconButton, so plugs line up down the page in the trailing margin
/// ([PluggedRow], [CurrentRowFrame]).
class RowPlug extends StatelessWidget {
  final bool busy;
  final bool connected;
  final VoidCallback? onConnect;
  final VoidCallback onDisconnect;

  const RowPlug({super.key, required this.busy, required this.connected, required this.onConnect, required this.onDisconnect});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: _rowButtonWidth,
    child: Center(
      child: StationConnectionToggle(busy: busy, connected: connected, onConnect: onConnect, onDisconnect: onDisconnect),
    ),
  );
}

/// An inventory row with its [plug] out in the trailing margin, exactly where
/// the current transceiver's sits ([currentRowGutters]), so every plug on the
/// page lines up. [child] is a [ListTile] spanning the whole row, whose
/// trailing inset is that margin ([currentRowGutters]): the plug is laid over
/// it, so the tile's hover and ink run edge to edge under the plug.
class PluggedRow extends StatelessWidget {
  final RowPlug plug;
  final Widget child;

  const PluggedRow({super.key, required this.plug, required this.child});

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      child,
      Positioned(
        right: 0,
        top: 0,
        bottom: 0,
        width: currentRowGutters(context).right,
        child: Align(alignment: Alignment.centerLeft, child: plug),
      ),
    ],
  );
}

/// Where the details under the current row start, from the leading edge:
/// a step in from its content column, so they read as the row's rather than
/// as more rows of the list.
double currentRowDetailsInset(BuildContext context) => currentRowGutters(context).left + Space.xxl;

/// How far the current row's content column sits in from each edge: the
/// row inset every other row uses, widened where it is too narrow to hold
/// the button that lives in it — the picker on the left, the plug on the
/// right. Widening narrows the content column rather than letting a button
/// overlap it.
EdgeInsets currentRowGutters(BuildContext context) {
  final inset = (ListTileTheme.of(context).contentPadding ?? EdgeInsets.zero).resolve(Directionality.of(context));
  return EdgeInsets.only(left: math.max(inset.left, transceiverPickerWidth), right: math.max(inset.right, kMinInteractiveDimension));
}

/// The current transceiver band's row: [child], a [ListTile] whose content
/// sits in the content column, with [leading] and [trailing] out in the margins
/// ([currentRowGutters]), each hugging the column's edge so they stay by the
/// row however wide a centred Settings pane makes its margins.
class CurrentRowFrame extends StatelessWidget {
  final Widget? leading;
  final Widget? trailing;
  final Widget child;

  const CurrentRowFrame({super.key, this.leading, this.trailing, required this.child});

  @override
  Widget build(BuildContext context) {
    final gutters = currentRowGutters(context);
    final inset = (ListTileTheme.of(context).contentPadding ?? EdgeInsets.zero).resolve(Directionality.of(context));
    return Stack(
      children: [
        // The tile spans the whole row, its gutters as its padding, so its
        // hover and ink run edge to edge under the buttons laid over them.
        // Its rows lead with a bare glyph: the button's overhang is the gap
        // before the title, so where the row inset is wide enough to hold the
        // buttons, labels line up with the inventory's. Where it is not, the
        // widened gutter moves this row's label in by the difference.
        ListTileTheme.merge(
          contentPadding: inset.copyWith(left: gutters.left, right: gutters.right),
          horizontalTitleGap: rowButtonOverhang,
          minLeadingWidth: 0,
          child: child,
        ),
        if (leading != null)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: gutters.left,
            child: Align(alignment: Alignment.centerRight, child: leading),
          ),
        if (trailing != null)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: gutters.right,
            child: Align(alignment: Alignment.centerLeft, child: trailing),
          ),
      ],
    );
  }
}

/// The current transceiver row's down-arrow button, fixed at this width
/// whatever the platform's visual density makes of an IconButton — the left
/// margin it sits in is widened to at least this ([currentRowGutters]).
const transceiverPickerWidth = kMinInteractiveDimension;

/// The current transceiver's picker: a menu that drops from under the row
/// and spans its width, the way the app's other dropdowns open, holding the
/// same rows the inventory draws. [builder] draws the row, handed the way to
/// open the menu; [rows] draws the menu, handed the way to close it.
class TransceiverMenu extends StatefulWidget {
  final Widget Function(BuildContext context, VoidCallback toggle) builder;
  final List<Widget> Function(BuildContext context, VoidCallback close) rows;

  const TransceiverMenu({super.key, required this.builder, required this.rows});

  @override
  State<TransceiverMenu> createState() => _TransceiverMenuState();
}

class _TransceiverMenuState extends State<TransceiverMenu> {
  final _controller = MenuController();

  /// How far the menu reaches past the content column on each side — room
  /// inside its edge before the rows' icons, which stay where the row above
  /// puts its own.
  static const _margin = Space.lg;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // The current row's content column, not the pane: its gutters (which
      // on a wide Settings pane carry the centring) are taken off both sides,
      // and the menu stands [_margin] proud of what is left. Its rows take
      // just that margin as their own inset, so their glyphs and connection
      // icons line up with the row above.
      final inset = currentRowGutters(context);
      final width = (constraints.maxWidth - inset.horizontal + _margin * 2).clamp(0.0, constraints.maxWidth);
      final left = (inset.left - _margin).clamp(0.0, constraints.maxWidth - width);
      return MenuAnchor(
        controller: _controller,
        alignmentOffset: Offset(left, 0),
        style: const MenuStyle(padding: WidgetStatePropertyAll(EdgeInsets.zero)),
        menuChildren: [
          PlatformViewShield(
            child: SizedBox(
              width: width,
              child: ListTileTheme.merge(
                contentPadding: const EdgeInsets.symmetric(horizontal: _margin),
                child: Column(mainAxisSize: MainAxisSize.min, children: widget.rows(context, _controller.close)),
              ),
            ),
          ),
        ],
        builder: (context, controller, _) => widget.builder(context, () => controller.isOpen ? controller.close() : controller.open()),
      );
    },
  );
}

/// A peer's radio has nothing to edit here — its connection and settings
/// are the other device's — so a tap says where to go instead of doing
/// nothing, which would read as a row that is broken.
Future<void> showPeerRadioElsewhere(BuildContext context, {required String radio, required String device}) {
  final st = context.t.settings.station;
  return showHaloDialog<void>(
    context: context,
    builder: (context) => HaloDialog(
      title: Text(st.peerRadioElsewhereTitle(radio: radio)),
      content: Text(st.peerRadioElsewhereMessage(device: device)),
      cancel: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.t.common.done)),
    ),
  );
}

/// Where a node is reached, as its row states it — the address, or that
/// there is none yet.
///
/// A serial port and its speed are capped at [_serialTargetMaxChars],
/// clipped from the front: a device path runs twice the length of an
/// `ip:port`, and these rows ellipsize from the END, which cuts away the tail
/// that tells two adapters apart (see [AddressText]). Only the transport's
/// half is clipped: what the driver adds after it (an Icom's " · CI-V 94")
/// would otherwise take the whole cap and leave no port at all.
String connectionTextFor(BuildContext context, EquipmentType? type, Map<String, dynamic> config) {
  if (type == null) return '';
  if (type.isUnconfigured(config)) return context.t.settings.station.notConfigured;
  final target = type.describeTarget(config);
  if (type.transport is! SerialTransportConfig) return target;
  final port = type.describeTransportTarget(config);
  if (port.length <= _serialTargetMaxChars || !target.startsWith(port)) return target;
  return '…${port.substring(port.length - _serialTargetMaxChars + 1)}${target.substring(port.length)}';
}

/// About the width of a short `ip:port` (`10.0.0.66:4992` is 16).
const _serialTargetMaxChars = 14;

/// The radio's own mode — DATA-USB, CW-R, whatever its driver can set — as
/// opposed to the contact's: picking one tells the radio and nothing else,
/// and its report decides what the logging panel shows. Offered only while
/// radio1 is this station's own and connected ([CatService.radio1SettableModes]).
class RadioModeField extends StatelessWidget {
  final CatService cat;

  const RadioModeField({super.key, required this.cat});

  @override
  Widget build(BuildContext context) {
    final modes = cat.radio1SettableModes;
    final uuid = cat.localRadio1;
    if (modes.isEmpty || uuid == null) return const SizedBox.shrink();
    final current = cat.stateFor(uuid).vfo.mode;
    final theme = Theme.of(context);
    final valueStyle = theme.textTheme.titleMedium ?? const TextStyle();
    final label = context.t.settings.station.radioMode;
    // The widest mode or the label, plus the field's content padding and the
    // dropdown's trailing icon.
    final widest = [label, ...modes].map((text) => textWidth(context, text, valueStyle)).reduce(math.max);
    return SizedBox(
      width: widest + 16 + 32,
      // Controlled by the radio's report, not by the pick: a form field would
      // keep showing a mode the radio refused, since nothing then changes to
      // rebuild it. Here the value IS the report, so a refused pick snaps back.
      child: InputDecorator(
        decoration: poloFieldDecoration(context, label),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            isDense: true,
            value: modes.contains(current) ? current : null,
            icon: dropdownTrailingIcon,
            menuMaxHeight: dropdownMenuMaxHeight(context),
            items: [for (final mode in modes) DropdownMenuItem<String>(value: mode, child: Text(mode))],
            onChanged: (mode) => mode == null ? null : cat.setRadio1Mode(mode),
          ),
        ),
      ),
    );
  }
}
