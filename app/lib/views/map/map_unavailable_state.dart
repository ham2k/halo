// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The empty state a MapLibre GL backend paints over itself once it has
// given up loading: the pane behind it is blank, and a blank pane is
// indistinguishable from an operation with no locatable QSOs.
//
// It states the condition and nothing else. The causes reaching it
// ('style-timeout', 'never-ready', a page or WebGL failure) are evidence for
// ErrorPolicy, not for the operator: they name machinery no operator can act
// on. It names no remedy either, the connection least of all — a device that
// is offline stamps its MapErrors offline (ConnectivityService, read by
// ErrorPolicy's map-offline rule), so what reaches this state is the failures
// a working connection still produces.
//
// Not for the OSM backend: its tiles fail one at a time and flutter_map still
// draws the QSO circles and lines over grey, so that pane is never blank and
// covering it would take away a working map — on Linux, the only one there is.
//
// Opaque and full-pane, and drawn OVER a still-mounted backend rather than
// replacing it: the map's own recovery signals ('recovered', a late ready)
// clear this, which a torn-down webview could never send.

import 'package:flutter/material.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../../i18n/strings.g.dart';

class MapUnavailableState extends StatelessWidget {
  const MapUnavailableState({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(Space.xxl),
          child: Text(
            context.t.map.unavailable,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}
