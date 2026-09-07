// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Radio control's quick-access dialog: the current configuration and the
// current rig only, not the full Station Configuration page — that is one tap
// away via the pane's own More Settings.
//
// Its own file rather than either caller's, because there are two of them (the
// logging panel's Radio control and the status bar's radio status) and a
// second copy of a modal pane's arguments drifts silently: `scrollable` and
// `closeButton` below are not defaults, they are what this panel needs, and a
// copy that forgets one wraps a ListView in a scroll view.
//
// Not in station_panel.dart either: that file deliberately does not import
// settings_view.dart — the two already cross-import for the reverse embedding
// — which is why `onMoreSettings` is a callback in the first place. This is
// where that callback is supplied, so the push lives here.

import 'package:flutter/material.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../i18n/strings.g.dart';
import '../services/halo_services.dart';
import 'settings_view.dart';
import 'station_panel.dart';

Future<void> showStationConfigDialog(BuildContext context, HaLoServices services) {
  // The keyer row shows a value the radio never volunteers — see
  // CatService.refreshKeyerSpeed. Asked as the dialog opens, so the answer
  // is on screen by the time the operator reads the row.
  services.cat.refreshKeyerSpeed();
  return showModalPane<void>(
  context,
  title: context.t.settings.station.title,
  closeLabel: context.t.common.close,
  // StationPanel is its own scrolling ListView — the pane must not also wrap
  // it in a SingleChildScrollView.
  scrollable: false,
  // The compact panel ends in a footer band whose Done is the way out.
  closeButton: false,
  builder: (context) => StationPanel(
    services: services,
    compact: true,
    onMoreSettings: () {
      final navigator = Navigator.of(context);
      navigator.pop();
      navigator.push(MaterialPageRoute<void>(
        builder: (_) => SettingsView(services: services, initialPanel: 'station'),
      ));
    },
  ),
);
}
