// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Peer Devices settings panel (HALO-310): the master switch, this
// device's name, whatever is on the network right now, and the devices this
// operator has allowed.
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

import '../i18n/strings.g.dart';
import '../main.dart';
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
  bool _promptOpen = false;

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

  /// Raises the pairing prompt for the peer waiting on an answer.
  ///
  /// Only from the row's Allow button — the app-wide listener in main.dart
  /// raises it automatically, wherever the operator is. Two automatic
  /// triggers would stack two dialogs for one request.
  Future<void> _maybePrompt() async {
    if (_promptOpen) return;
    final pending = _peers.pendingPairing;
    final peer = pending?.session?.peer;
    if (pending == null || peer == null) return;

    _promptOpen = true;
    try {
      final allowed = await showPeerPairingDialog(
        context,
        deviceName: peer.deviceName,
        deviceId: peer.deviceId,
      );
      // Dismissed rather than answered — leave it pending so the row stays
      // and the operator can decide later, instead of silently declining.
      if (allowed == null) return;
      if (allowed) {
        await _peers.acceptPairing(peer.deviceId);
      } else {
        await _peers.rejectPairing(peer.deviceId);
      }
    } finally {
      _promptOpen = false;
    }
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

    return ListView(
      children: [
        SwitchListTile(
          title: Text(t.enable),
          subtitle: Text(enabled ? t.enabledDescription : t.disabledDescription),
          isThreeLine: enabled,
          value: enabled,
          onChanged: (value) async {
            await settings.setPeerSyncEnabled(value);
            // The switch alone is not enough: the service also has to be told
            // which operation (if any) is open, which only HaLoServices knows.
            widget.services.updatePeerSharing();
          },
        ),
        // Its own opt-in under the master switch: Bluetooth pops an OS
        // permission prompt and holds a radio, which "share with my
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
        if (enabled)
          if (_peers.bleError case final problem?)
            ListTile(
              leading: Icon(MdiIcons.alertCircleOutline, color: Theme.of(context).colorScheme.error),
              title: Text(t.bleProblem(error: problem)),
            )
          // The positive signal. Without it a working radio and a switch
          // that silently did nothing look identical — the definitive
          // proof stays the peer appearing under Nearby, but this says
          // the looking is actually happening.
          else if (_peers.bleRunning)
            ListTile(
              leading: Icon(MdiIcons.bluetooth),
              title: Text(t.bleActive),
            ),
        // Devices connect regardless now, and an operation open on a peer
        // arrives here whatever this device has open — so this hint is only
        // about what this device SENDS, which still follows the open one.
        if (enabled && _peers.sharedOperationUuid == null)
          ListTile(
            leading: Icon(MdiIcons.informationOutline),
            title: Text(t.shareNothingOpen),
          ),
        if (_peers.error case final problem?)
          ListTile(
            leading: Icon(MdiIcons.alertCircleOutline, color: Theme.of(context).colorScheme.error),
            title: Text(t.problem(error: problem)),
          ),
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
        SectionHeader(t.pairedDevices),
        _PairedDevices(services: widget.services, onForget: _forget),
        if (_peers.peers.isNotEmpty) ...[
          SectionHeader(t.nearby),
          for (final runtime in _peers.peers.values)
            ListTile(
              leading: _statusDot(context, runtime),
              title: Text(runtime.beacon.deviceName.isEmpty
                  ? runtime.beacon.deviceId
                  : runtime.beacon.deviceName),
              subtitle: Text(_statusLabel(context, runtime)),
              trailing: runtime.session?.state == PeerSessionState.needsPairing
                  ? FilledButton(
                      onPressed: () {
                        // Clears a previous decline/forget first — otherwise
                        // pendingPairing skips this peer and the button does
                        // nothing at all.
                        _peers.offerPairingAgain(runtime.beacon.deviceId);
                        unawaited(_maybePrompt());
                      },
                      child: Text(t.allow),
                    )
                  : null,
            ),
        ],
        // Last, past Nearby: it is a section in its own right rather than a
        // sub-switch of the master one, and everything above it is about
        // reaching the other devices at all.
        if (enabled && settings.experimentEnabled('remote') /* stored key, see experiments.yaml */)
          PeerScreenSources(services: widget.services),
      ],
    );
  }

  String _statusLabel(BuildContext context, PeerRuntime runtime) {
    final t = context.t.settings.peers;
    final label = switch (runtime.session?.state) {
      PeerSessionState.live => t.connected,
      // Established, sync idle: the link is UP — reading it as "Not
      // connected" would tell the operator their working pair is broken.
      PeerSessionState.connected => t.connectedIdle,
      PeerSessionState.syncing => t.syncing,
      PeerSessionState.handshaking => t.connecting,
      PeerSessionState.needsPairing => '${runtime.beacon.deviceName} ${t.wantsToPair}',
      _ => t.notConnected,
    };
    // Which pipe carries the pair matters in the field: "connected via
    // Bluetooth" at a WiFi-less park is working as intended, the same words
    // at home mean the LAN path is broken.
    if (runtime.session?.link is PeerBleLink && runtime.session?.state != PeerSessionState.closed) {
      return '$label · ${t.viaBluetooth}';
    }
    return label;
  }

  /// The app's established "is it connected" affordance — a small filled
  /// circle with a semantics label, never a tooltip (a source-scanning test
  /// forbids those outright).
  Widget _statusDot(BuildContext context, PeerRuntime runtime) {
    final theme = Theme.of(context);
    final live = runtime.session?.state == PeerSessionState.live ||
        runtime.session?.state == PeerSessionState.connected;
    final busy = runtime.session?.state == PeerSessionState.syncing ||
        runtime.session?.state == PeerSessionState.handshaking;
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
}

/// The allowed list, straight off the trust store's own stream so a pair or
/// revoke happening anywhere (including from the prompt above) is reflected
/// without this panel having to be told.
class _PairedDevices extends StatefulWidget {
  final HaLoServices services;
  final Future<void> Function(String deviceId, String name) onForget;

  const _PairedDevices({required this.services, required this.onForget});

  @override
  State<_PairedDevices> createState() => _PairedDevicesState();
}

class _PairedDevicesState extends State<_PairedDevices> {
  /// Subscribed once, not rebuilt.
  ///
  /// A drift query stream created inside `build()` is a new subscription on
  /// every rebuild — the old one is cancelled and re-opened each time the
  /// panel repaints, which this panel does on every beacon. Besides the
  /// wasted queries, each cancel schedules drift's own teardown timer, which
  /// is enough to make a widget test fail with "A Timer is still pending".
  late final Stream<List<PeerTrustRow>> _trusted = widget.services.peerService.trust.watchAll();

  @override
  Widget build(BuildContext context) {
    final t = context.t.settings.peers;
    return StreamBuilder<List<PeerTrustRow>>(
      stream: _trusted,
      builder: (context, snapshot) {
        final rows = snapshot.data ?? const <PeerTrustRow>[];
        if (rows.isEmpty) {
          return ListTile(title: Text(t.noPairedDevices));
        }
        return Column(
          children: [
            for (final row in rows)
              ListTile(
                leading: Icon(MdiIcons.devices),
                title: Text(row.name.isEmpty ? row.peerDeviceId : row.name),
                subtitle: Text(row.peerDeviceId, style: haloMonoStyle(context, fontSize: 11)),
                trailing: IconButton(
                  icon: Icon(MdiIcons.close, semanticLabel: t.forget),
                  onPressed: () => unawaited(widget.onForget(row.peerDeviceId, row.name)),
                ),
              ),
          ],
        );
      },
    );
  }
}
