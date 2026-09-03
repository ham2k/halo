// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Peer Devices settings panel as a modal pane, for the status bar's peer
// status — the same panel Settings shows, not a compact copy of it: what the
// operator wants after tapping "3 of 5 linked" is the device list, and every
// control around it (the name, the switches) is what they go on to reach for.
//
// Its own file rather than main.dart's, following station_config_dialog.dart:
// `scrollable` below is not a default but what this panel needs, and a copy
// of these arguments at a second call site drifts silently.

import 'package:flutter/material.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../i18n/strings.g.dart';
import '../main.dart';
import 'peers_panel.dart';

Future<void> showPeersDialog(BuildContext context, HaLoServices services) => showModalPane<void>(
  context,
  title: context.t.settings.peers.title,
  closeLabel: context.t.common.close,
  // PeersPanel is its own scrolling ListView — the pane must not also wrap it
  // in a SingleChildScrollView.
  scrollable: false,
  builder: (context) => PeersPanel(services: services),
);
