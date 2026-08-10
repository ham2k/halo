// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The in-panel "the map could not load" banner, shared by the MapLibre GL
// backends. Shown when the shared script's style watchdog fires
// ('style-timeout' — see map_gl_script.dart) and cleared on its 'recovered'
// signal: without this, a style that never loads is indistinguishable from
// an operation with no locatable QSOs, because the pane behind it is
// simply empty.

import 'package:flutter/material.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../../i18n/strings.g.dart';

class MapLoadNotice extends StatelessWidget {
  const MapLoadNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        // Clears the projection toggle's row on narrow panes.
        padding: EdgeInsets.only(top: Space.sm + PaneSafeArea.topOf(context), left: Space.sm, right: Space.sm),
        child: Material(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(MdiIcons.alertCircleOutline, size: 18, color: theme.colorScheme.error),
                const SizedBox(width: Space.sm),
                Flexible(
                  child: Text(
                    context.t.map.loadFailed,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
