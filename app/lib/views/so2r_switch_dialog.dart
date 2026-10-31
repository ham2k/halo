// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The SO2R switcher's settings, opened from beside its pick in Station
// Configuration — docs/design/cat.md § The SO2R switcher. They apply as
// they change.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../services/settings_service.dart';

Future<void> showSo2rSwitchSettingsDialog(BuildContext context, SettingsService settings) => showHaloDialog<void>(
  context: context,
  builder: (context) {
    final st = context.t.settings.station;
    Widget toggle(String label, bool Function() value, Future<void> Function(bool) onChanged) =>
        SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(label), value: value(), onChanged: (on) => unawaited(onChanged(on)));
    return HaloDialog(
      title: Text(st.so2rSwitchSettings),
      content: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            toggle(st.so2rStereo, () => settings.so2rStereo, settings.setSo2rStereo),
            toggle(st.so2rListenWhileTransmitting, () => settings.so2rListenWhileTransmitting, settings.setSo2rListenWhileTransmitting),
          ],
        ),
      ),
      cancel: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.t.common.done)),
    );
  },
);
