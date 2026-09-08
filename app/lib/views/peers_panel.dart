// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Peer Devices settings panel (HALO-310): this device's name, the
// switches that decide whether it goes anywhere, and one list of every
// device this operator can reach — linked or merely on the network.
//
// Its own panel rather than rows inside Sync: that one is entirely about the
// LoFi cloud account (email identity, server-side counts, connection
// requests), and "device" there means a client registered to an account.
// Here it means a box on this network. Conflating the two would make both
// harder to reason about.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'package:halo_i18n/halo_i18n.dart';
import '../services/halo_services.dart';
import '../services/error_reporting_service.dart';
import '../services/peer/ble/peer_ble_transport.dart';
import '../services/peer/peer_service.dart';
import 'peer_pairing_dialog.dart';
import 'peer_screen_sources.dart';

class PeersPanel extends StatefulWidget {
  final HaLoServices services;

  const PeersPanel({super.key, required this.services});

  @override
  State<PeersPanel> createState() => _PeersPanelState();
}

class _PeersPanelState extends State<PeersPanel> {
  late final TextEditingController _nameController;
  late final FocusNode _nameFocus;
  PeerService get _peers => widget.services.peerService;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.services.settings.peerDeviceName);
    // Committing on focus loss as well as on submit: a name typed and then
    // tapped away from would otherwise be discarded without a word, which
    // reads as the field not persisting at all.
    _nameFocus = FocusNode()
      ..addListener(() {
        if (!_nameFocus.hasFocus) _commitName(_nameController.text);
      });
    _peers.addListener(_onPeersChanged);
    widget.services.settings.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    _peers.removeListener(_onPeersChanged);
    widget.services.settings.removeListener(_onSettingsChanged);
    _nameFocus.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _commitName(String value) {
    final settings = widget.services.settings;
    final trimmed = value.trim();
    if (trimmed == settings.peerDeviceName) return;
    unawaited(settings.setPeerDeviceName(trimmed).then((_) {
      // A cleared field falls back to the derived default name — put that
      // name INTO the field, or it would sit blank while the network
      // broadcasts the fallback, and every later blur would re-commit ''
      // forever (empty never compares equal to the computed getter).
      if (trimmed.isEmpty && mounted) {
        _nameController.text = settings.peerDeviceName;
      }
      // Re-applies the name to the running service — beacons and future
      // sessions carry it from here; without this the network keeps the old
      // name until something else happens to reconcile.
      widget.services.updatePeerSharing();
    }));
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  void _onPeersChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _forget(String deviceId, String name) async {
    final t = context.t.settings.peers;
    final confirmed = await showHaloDialog<bool>(
      context: context,
      builder: (dialogContext) => HaloDialog(
        title: Text(t.forgetTitle(name: name)),
        content: Text(t.forgetBody),
        cancel: TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(dialogContext.t.common.cancel),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(t.forget),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _peers.revokeTrust(deviceId);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.settings.peers;
    final settings = widget.services.settings;
    final enabled = settings.peerSyncEnabled;

    return SectionedListView(
      children: [
        // The name leads: it is what every other device calls this one, so
        // it is the first thing worth getting right — the switches below it
        // only decide whether that name goes anywhere.
        SectionHeader(t.thisDevice),
        Padding(
          // The list's OWN inset, read from the ambient ListTileTheme rather
          // than guessed at — a hard-coded number drifts out of line with
          // every row around it the moment the theme's changes.
          padding: (ListTileTheme.of(context).contentPadding ?? EdgeInsets.zero)
              .add(const EdgeInsets.symmetric(vertical: Space.md)),
          child: TextField(
            controller: _nameController,
            focusNode: _nameFocus,
            decoration: InputDecoration(
              labelText: t.deviceName,
              helperText: t.deviceNameHint,
              helperMaxLines: 2,
              border: const OutlineInputBorder(),
            ),
            // On submit and focus loss rather than on every keystroke: this
            // name is broadcast, and re-announcing on each character typed
            // would be noise on the network and a jittery name on every
            // peer.
            onSubmitted: _commitName,
          ),
        ),
        SwitchListTile(
          title: Text(t.enable),
          subtitle: Text(t.enableDescription),
          value: enabled,
          onChanged: (value) async {
            await settings.setPeerSyncEnabled(value);
            // The switch alone is not enough: the service also has to be told
            // which operation (if any) is open, which only HaLoServices knows.
            widget.services.updatePeerSharing();
          },
        ),
        // Its own opt-in under the master switch: Bluetooth pops an OS
        // permission prompt and holds a radio, which "connect to other
        // devices" alone never implied. Absent entirely where no BLE
        // transport exists (web) — a switch that silently does nothing
        // would read as the feature being broken.
        if (enabled && _peers.bleAvailable)
          SwitchListTile(
            title: Text(t.bleEnable),
            subtitle: Text(t.bleDescription),
            value: settings.peerBleEnabled,
            onChanged: (value) async {
              await settings.setPeerBleEnabled(value);
              widget.services.updatePeerSharing();
            },
          ),
        // Only the negative. A radio that is doing its job says so by peers
        // appearing in the list below; a row confirming it is on adds a line
        // to every healthy panel to tell the operator nothing is wrong.
        if (enabled)
          if (_peers.bleError case final problem?)
            ListTile(
              leading: Icon(MdiIcons.alertCircleOutline, color: Theme.of(context).colorScheme.error),
              title: Text(t.bleProblem(error: problem)),
            ),
        if (_peers.error case final problem?)
          ListTile(
            leading: Icon(MdiIcons.alertCircleOutline, color: Theme.of(context).colorScheme.error),
            title: Text(t.problem(error: problem)),
          ),
        // The Paired Devices band belongs to [_DeviceList] along with the
        // Nearby one: both name rows the stream decides, and a band pins
        // only over rows its own list holds. Which makes it slivers, so the
        // list above is told rather than left to guess.
        SectionedSlivers(slivers: [
          _DeviceList(
          services: widget.services,
          onForget: _forget,
          // Clears a previous decline or forget and dials if there is no
          // session; the prompt itself is raised by the app-wide listener in
          // main.dart, which fires on the notification this causes. Raising
          // one here too would stack two dialogs over one request, and
          // answering them differently would record trust and then refuse it.
            onAllow: _peers.offerPairingAgain,
          ),
        ]),
        // Last, past the devices: it is a section in its own right rather
        // than a sub-switch of the master one, and everything above it is
        // about reaching the other devices at all.
        if (enabled && settings.experimentEnabled('remote') /* stored key, see experiments.yaml */)
          SectionedSlivers(slivers: [PeerScreenSources(services: widget.services)]),
      ],
    );
  }
}

/// What a list shows when the trust store itself could not be read.
///
/// Never the empty-state text: "no devices linked yet" is a positive claim,
/// and telling an operator whose devices ARE linked to go and link them —
/// over a database fault nothing reported — sends them to fix the wrong
/// thing.
Widget _listProblem(BuildContext context, Object problem) => ListTile(
      leading: Icon(MdiIcons.alertCircleOutline, color: Theme.of(context).colorScheme.error),
      title: Text(context.t.settings.peers.deviceListProblem(error: '$problem')),
    );

/// The trust store's rows, with a failure reported once when it happens.
///
/// The report belongs here rather than in the builder that renders it: a
/// StreamBuilder holds an error snapshot until the next event, and these
/// panels rebuild on every beacon — reporting from `build` would upload the
/// same fault several times a second.
Stream<List<PeerTrustRow>> _reportingTrustStream(PeerService peers) =>
    peers.trust.watchAll().transform(StreamTransformer.fromHandlers(
      handleError: (error, stack, sink) {
        ErrorReportingService.report(error, stack, context: 'PeersPanel:trustStream');
        sink.addError(error, stack);
      },
    ));

/// A present device's own beacon wins; the trust row is the fallback for one
/// that is not on the network.
///
/// The trust row's name is written at pairing and refreshed only on a
/// re-pair (`PeerTrustStore.trust`), whose stated point is that a renamed
/// device must not show under its old name forever — preferring it would
/// pin the stale name until the operator happens to re-pair.
String peerDisplayName(PeerTrustRow? row, PeerRuntime? runtime, String deviceId) {
  final beaconName = runtime?.beacon.deviceName ?? '';
  if (beaconName.isNotEmpty) return beaconName;
  if (row != null && row.name.isNotEmpty) return row.name;
  return shortPeerDeviceId(deviceId);
}

/// The devices on the network that this operator has not linked.
///
/// A linked device that is also beaconing belongs to the linked group, which
/// carries its live status — listing it here as well would show one box as
/// two, which is what having a Nearby section beside an Allowed Devices one
/// did.
List<String> unlinkedPeerDeviceIds(Set<String> linked, Iterable<String> present) =>
    [for (final id in present) if (!linked.contains(id)) id];

String _statusLabel(BuildContext context, PeerRuntime? runtime) {
  final t = context.t.settings.peers;
  final label = switch (runtime?.session?.state) {
    // Live and established-but-idle read the same: the link is UP either
    // way, and reading the idle one as "Not connected" would tell the
    // operator their working pair is broken. Whether the two ends have the
    // same operation open is the operation's business, not this list's.
    PeerSessionState.live || PeerSessionState.connected => t.connected,
    PeerSessionState.syncing => t.syncing,
    PeerSessionState.handshaking => t.connecting,
    // Answered on this side, still `needsPairing` because the far device's
    // operator has not confirmed — saying it "wants to share" again would
    // read as this operator's own answer having been lost.
    PeerSessionState.needsPairing => runtime?.session?.localTrusts == true
        ? t.waitingForThem
        : '${runtime?.beacon.deviceName ?? ''} ${t.wantsToPair}'.trim(),
    _ => t.notConnected,
  };
  // Which pipe carries the pair matters in the field: "connected via
  // Bluetooth" at a WiFi-less park is working as intended, the same words
  // at home mean the LAN path is broken.
  if (runtime?.session?.link is PeerBleLink && runtime?.session?.state != PeerSessionState.closed) {
    return '$label · ${t.viaBluetooth}';
  }
  return label;
}

/// The app's established "is it connected" affordance — a small filled
/// circle with a semantics label, never a tooltip (a source-scanning test
/// forbids those outright).
Widget _statusDot(BuildContext context, PeerRuntime? runtime) {
  final theme = Theme.of(context);
  final live = runtime?.session?.state == PeerSessionState.live ||
      runtime?.session?.state == PeerSessionState.connected;
  final busy = runtime?.session?.state == PeerSessionState.syncing ||
      runtime?.session?.state == PeerSessionState.handshaking;
  final color = live
      ? Colors.green
      : busy
          ? theme.colorScheme.tertiary
          : theme.disabledColor;
  return Semantics(
    label: _statusLabel(context, runtime),
    child: Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    ),
  );
}

/// One list for every device this operator has a relationship with — the
/// ones they have linked, and the ones on the network right now.
///
/// Two sections would put a linked device that is also present into both,
/// with nothing saying they are the same box; the operator's question is
/// "which of my devices can I reach", and that is one question.
///
/// The trusted half comes straight off the trust store's own stream so a
/// link or a forget happening anywhere (including from the prompt above) is
/// reflected without this panel having to be told.
class _DeviceList extends StatefulWidget {
  final HaLoServices services;
  final Future<void> Function(String deviceId, String name) onForget;
  final void Function(String deviceId) onAllow;

  const _DeviceList({required this.services, required this.onForget, required this.onAllow});

  @override
  State<_DeviceList> createState() => _DeviceListState();
}

class _DeviceListState extends State<_DeviceList> {
  /// Subscribed once, not rebuilt.
  ///
  /// A drift query stream created inside `build()` is a new subscription on
  /// every rebuild — the old one is cancelled and re-opened each time the
  /// panel repaints, which this panel does on every beacon. Besides the
  /// wasted queries, each cancel schedules drift's own teardown timer, which
  /// is enough to make a widget test fail with "A Timer is still pending".
  late final Stream<List<PeerTrustRow>> _trusted = _reportingTrustStream(widget.services.peerService);

  @override
  Widget build(BuildContext context) {
    final t = context.t.settings.peers;
    return StreamBuilder<List<PeerTrustRow>>(
      stream: _trusted,
      builder: (context, snapshot) {
        final trusted = {
          for (final row in snapshot.data ?? const <PeerTrustRow>[]) row.peerDeviceId: row,
        };
        final peers = widget.services.peerService.peers;
        final nearby = unlinkedPeerDeviceIds(trusted.keys.toSet(), peers.keys);
        // Its own sections, cut here rather than by the list above: the
        // Nearby band names rows this widget builds, and a band the host
        // cannot see would leave them under the band before it.
        return SliverMainAxisGroup(
          slivers: sectionSlivers(context, [
            SectionHeader(t.pairedDevices),
            // Above the rows, not instead of them: a trust-store fault must
            // not take away the Allow button that answers a device asking
            // right now.
            if (snapshot.error case final problem?) _listProblem(context, problem),
            // Keyed on the trusted rows alone. A stranger beaconing nearby is
            // not evidence that this operator has linked anything, and
            // hiding the guidance because one appeared leaves them with no
            // way to find out how.
            if (trusted.isEmpty)
              // Not while the first query is still in flight: "no devices
              // linked yet" is a positive claim, and devices that ARE linked
              // would carry it for the first frames.
              if (snapshot.connectionState != ConnectionState.waiting)
                ListTile(title: Text(t.noPairedDevices))
              else
                const SizedBox.shrink(),
            for (final row in trusted.values)
              _DeviceRow(
                deviceId: row.peerDeviceId,
                name: peerDisplayName(row, peers[row.peerDeviceId], row.peerDeviceId),
                runtime: peers[row.peerDeviceId],
                linked: true,
                onForget: widget.onForget,
                onAllow: widget.onAllow,
              ),
            if (nearby.isNotEmpty) ...[
              SectionHeader(t.nearby),
              for (final id in nearby)
                _DeviceRow(
                  deviceId: id,
                  name: peerDisplayName(null, peers[id], id),
                  runtime: peers[id],
                  linked: false,
                  onForget: widget.onForget,
                  onAllow: widget.onAllow,
                ),
            ],
          ]),
        );
      },
    );
  }

}

/// One device's row. Both actions are optional: read-only surfaces outside
/// Settings show the same device in the same shape, and a Forget button on a
/// list embedded in the logging screen would put a destructive action a
/// mis-tap away from the log.
class _DeviceRow extends StatelessWidget {
  final String deviceId;
  final String name;
  final PeerRuntime? runtime;
  final bool linked;
  final Future<void> Function(String deviceId, String name)? onForget;
  final void Function(String deviceId)? onAllow;

  const _DeviceRow({
    required this.deviceId,
    required this.name,
    required this.runtime,
    required this.linked,
    this.onForget,
    this.onAllow,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.t.settings.peers;
    // Asking us right now, and this operator has not answered.
    final wantsPairing = onAllow != null &&
        runtime?.session?.state == PeerSessionState.needsPairing &&
        runtime?.session?.localTrusts != true;
    // Present but not linked, with no request in flight — the operator
    // starts one. Without this a device forgotten while it keeps beaconing
    // is an inert row forever: nothing re-dials a peer that has not moved,
    // nothing sweeps one still being heard, and the Allow button needs a
    // session that no longer exists.
    final canLink = onAllow != null && !linked && !wantsPairing && runtime != null;
    return ListTile(
      leading: _statusDot(context, runtime),
      title: Row(
        children: [
          Expanded(child: Text(name, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: Space.md),
          // Right-aligned on the name's own line rather than under it: it is
          // an identifier to check at a glance, not a second label, and a
          // column of ids reads as a column.
          Text(
            shortPeerDeviceId(deviceId),
            style: haloMonoStyle(context, fontSize: 11)
                .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
      subtitle: Text(_statusLabel(context, runtime)),
      trailing: wantsPairing
          ? FilledButton(onPressed: () => onAllow!(deviceId), child: Text(t.allow))
          : canLink
              ? TextButton(onPressed: () => onAllow!(deviceId), child: Text(t.link))
              : (linked && onForget != null)
              ? IconButton(
                  icon: Icon(MdiIcons.close, semanticLabel: t.forget),
                  onPressed: () => unawaited(onForget!(deviceId, name)),
                )
              : null,
    );
  }
}

/// The linked devices and how each is doing, read-only, for surfaces outside
/// the Settings panel.
///
/// Linked only, unlike the panel's list: this answers "are my own devices
/// with me", which is a question an operator asks mid-operation. Offering
/// to link a stranger's beacon is a decision that belongs to Settings, where
/// the warning about who can ask is on screen.
class LinkedDevicesList extends StatefulWidget {
  final HaLoServices services;

  const LinkedDevicesList({super.key, required this.services});

  @override
  State<LinkedDevicesList> createState() => _LinkedDevicesListState();
}

class _LinkedDevicesListState extends State<LinkedDevicesList> {
  /// Subscribed once — see [_DeviceListState._trusted] for why a drift stream
  /// must not be created inside `build()`.
  late final Stream<List<PeerTrustRow>> _trusted = _reportingTrustStream(widget.services.peerService);

  PeerService get _peers => widget.services.peerService;

  @override
  void initState() {
    super.initState();
    // Its own listener: this list is built inside a dialog, so no parent
    // rebuild reaches it when a peer connects or drops.
    _peers.addListener(_onPeersChanged);
  }

  @override
  void dispose() {
    _peers.removeListener(_onPeersChanged);
    super.dispose();
  }

  void _onPeersChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.settings.peers;
    return StreamBuilder<List<PeerTrustRow>>(
      stream: _trusted,
      builder: (context, snapshot) {
        final rows = snapshot.data ?? const <PeerTrustRow>[];
        final peers = _peers.peers;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (snapshot.error case final problem?) _listProblem(context, problem),
            if (rows.isEmpty && snapshot.connectionState != ConnectionState.waiting)
              ListTile(title: Text(t.noPairedDevices)),
            for (final row in rows)
              _DeviceRow(
                deviceId: row.peerDeviceId,
                name: peerDisplayName(row, peers[row.peerDeviceId], row.peerDeviceId),
                runtime: peers[row.peerDeviceId],
                linked: true,
              ),
          ],
        );
      },
    );
  }
}
