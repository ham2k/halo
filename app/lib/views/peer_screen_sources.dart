// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What this device is sharing, under the Peer Devices panel's screen-sharing
// switch (HALO-369) — the state, and the way to the picker.
//
// The choosing itself is a dialog of its own ([showScreenSharePicker]): the
// sources need pictures to be told apart, and a grid of them does not belong
// inline in a settings list between two switches.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'package:halo_i18n/halo_i18n.dart';
import '../services/halo_services.dart';
import '../services/peer/peer_screens.dart';
import '../services/screen_capture_service.dart';
import 'screen_share_picker.dart';
import 'screen_source_tile.dart';

class PeerScreenSources extends StatefulWidget {
  final HaLoServices services;

  const PeerScreenSources({super.key, required this.services});

  @override
  State<PeerScreenSources> createState() => _PeerScreenSourcesState();
}

class _PeerScreenSourcesState extends State<PeerScreenSources> {
  PeerScreens get _screens => widget.services.peerScreens;

  @override
  void initState() {
    super.initState();
    _screens.addListener(_onChanged);
    // So the summary below names what is actually being shared rather than
    // ids — the OS list is what resolves one into the other.
    unawaited(_screens.refreshSources());
  }

  @override
  void dispose() {
    _screens.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  /// Takes one source off the offer. Whoever is watching it is dropped and
  /// told, and the capture stops now rather than when they happen to close
  /// the pane — [PeerScreens.applyOffers] is what makes "stopped sharing"
  /// mean it.
  Future<void> _stopSharing(PeerScreenSource source) async {
    final settings = widget.services.settings;
    await settings.setPeerSharedScreenIds(
      settings.peerSharedScreenIds.where((id) => id != source.id).toList(),
    );
    await _screens.applyOffers();
  }

  /// Who is looking at [sourceId] right now, named. A pane on this very
  /// device counts and says so — it is watching through the same registry a
  /// peer does.
  String _watchedBy(BuildContext context, String sourceId) {
    final t = context.t.settings.peers;
    final watchers = _screens.watchersOf(sourceId);
    if (watchers.isEmpty) return t.screenSharedToNobody;
    final names = [
      for (final watcher in watchers)
        if (watcher == localViewerWatcher)
          t.screenThisDevice
        else
          widget.services.peerService.peers[watcher]?.beacon.deviceName ?? watcher,
    ]..sort();
    return t.screenSharedTo(devices: names.join(', '));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.settings.peers;
    final theme = Theme.of(context);

    final settings = widget.services.settings;
    final capable = _screens.availability == ScreenCaptureAvailability.available;
    final sharing = capable && settings.peerScreenShareEnabled;
    final offered = _screens.offeredSources;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(t.screenSources),
        // A device that cannot capture says so instead of offering a switch
        // that would do nothing — it can still SHOW a screen another device
        // shares, which is the half that matters on a phone or a tablet.
        if (!capable)
          ListTile(
            leading: Icon(MdiIcons.informationOutline),
            title: Text(
              _screens.availability == ScreenCaptureAvailability.unsupportedVersion
                  ? t.screenUnsupportedVersion
                  : t.screenUnsupportedPlatform,
            ),
          )
        else
          // Its own opt-in, on the same reasoning as Bluetooth's: sharing the
          // open operation never implied sharing whatever else is on the
          // screen, and on macOS turning this on asks the OS for a Screen
          // Recording grant that outlives the app.
          SwitchListTile(
            title: Text(t.screenEnable),
            subtitle: Text(t.screenDescription),
            isThreeLine: true,
            value: settings.peerScreenShareEnabled,
            onChanged: (value) async {
              await settings.setPeerScreenShareEnabled(value);
              widget.services.updatePeerSharing();
            },
          ),
        if (sharing) ...[
          if (_screens.permission == ScreenCapturePermission.denied)
            ListTile(
              leading: Icon(MdiIcons.lockOutline, color: theme.colorScheme.error),
              title: Text(t.screenNeedsPermission),
              // Two steps rather than one button, because there is no single
              // action that finishes this: macOS answers its own preflight
              // from a per-process cache, so however the operator answers, this
              // app keeps reporting denied until it is relaunched. A Retry
              // would be a button that cannot work.
              subtitle: Text(t.screenRelaunchAfterGranting),
              isThreeLine: true,
              trailing: FilledButton(
                onPressed: () => unawaited(_screens.requestPermission()),
                child: Text(t.screenGrantPermission),
              ),
            ),
          if (_screens.error case final problem?)
            ListTile(
              leading: Icon(MdiIcons.alertCircleOutline, color: theme.colorScheme.error),
              title: Text(t.screenProblem(error: problem)),
            ),
          // A plain row, like every other way into a sub-screen in settings
          // (HALO-364's one list vocabulary). No summary beside it: the list
          // below says what is shared, one source at a time and with who is
          // watching each, which is the part worth seeing at a glance.
          ListTile(
            leading: Icon(MdiIcons.monitorShare),
            title: Text(t.screenChooseButton),
            trailing: Icon(MdiIcons.chevronRight),
            onTap: () => unawaited(showScreenSharePicker(context, services: widget.services)),
          ),
          if (offered.isEmpty)
            ListTile(
              leading: Icon(MdiIcons.informationOutline),
              title: Text(t.screenSharedSummaryNone),
            )
          else
            // One row per shared source, saying who is looking at it. The
            // operator is entitled to know that per SOURCE rather than as a
            // count: "someone is watching" and "someone is watching my
            // banking window" are different facts.
            for (final source in offered)
              ListTile(
                leading: Icon(iconForScreenSourceKind(source.kind)),
                title: Text(source.name),
                subtitle: Text(_watchedBy(context, source.id)),
                // No confirmation: this is the reversible direction. It
                // shares LESS, takes one tap in the picker to undo, and a
                // prompt here would put friction on the safe move — the one
                // an operator may want in a hurry, with someone watching.
                trailing: IconButton(
                  icon: Icon(
                    MdiIcons.deleteOutline,
                    semanticLabel: t.screenStopSharing(name: source.name),
                  ),
                  onPressed: () => unawaited(_stopSharing(source)),
                ),
              ),
        ],
      ],
    );
  }
}
