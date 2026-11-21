// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:halo_i18n/halo_i18n.dart';

/// One device-wide setting, drawn from the K4's confirmed readback.
class K4DiversityControl extends StatelessWidget {
  const K4DiversityControl({super.key, required this.enabled, required this.onChanged, required this.inset});

  final bool enabled;
  final ValueChanged<bool> onChanged;
  final EdgeInsets inset;

  @override
  Widget build(BuildContext context) {
    final st = context.t.settings.station;
    return Material(
      type: MaterialType.transparency,
      child: SwitchListTile(
        contentPadding: inset,
        title: Text(st.k4Diversity),
        subtitle: Text(enabled ? st.k4DiversityFollowing : st.k4DiversityIndependent),
        value: enabled,
        onChanged: onChanged,
      ),
    );
  }
}
