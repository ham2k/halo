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
import '../services/peer/peer_service.dart';
import 'peer_pairing_dialog.dart';

class PeersPanel extends StatefulWidget {
  final HaLoServices services;

  const PeersPanel({super.key, required this.services});

  @override
  State<PeersPanel> createState() => _PeersPanelState();
}

class _PeersPanelState extends State<PeersPanel> {
  late final TextEditingController _nameController;
  bool _promptOpen = false;

  PeerService get _peers => widget.services.peerService;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.services.settings.peerDeviceName);
    _peers.addListener(_onPeersChanged);
    widget.services.settings.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    _peers.removeListener(_onPeersChanged);
    widget.services.settings.removeListener(_onSettingsChanged);
    _nameController.dispose();
    super.dispose();
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
        // Devices connect regardless now — this hint is about the QSO sync,
        // which still follows whichever operation is open.
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
          padding: const EdgeInsets.symmetric(horizontal: Space.xl, vertical: Space.md),
          child: TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: t.deviceName,
              helperText: t.deviceNameHint,
              helperMaxLines: 2,
              border: const OutlineInputBorder(),
            ),
            // On submit rather than on every keystroke: this name is
            // broadcast, and re-announcing on each character typed would be
            // noise on the network and a jittery name on every peer.
            onSubmitted: (value) => unawaited(settings.setPeerDeviceName(value)),
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
      ],
    );
  }

  String _statusLabel(BuildContext context, PeerRuntime runtime) {
    final t = context.t.settings.peers;
    return switch (runtime.session?.state) {
      PeerSessionState.live => t.connected,
      // Established, sync idle: the link is UP — reading it as "Not
      // connected" would tell the operator their working pair is broken.
      PeerSessionState.connected => t.connectedIdle,
      PeerSessionState.syncing => t.syncing,
      PeerSessionState.handshaking => t.connecting,
      PeerSessionState.needsPairing => '${runtime.beacon.deviceName} ${t.wantsToPair}',
      _ => t.notConnected,
    };
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
