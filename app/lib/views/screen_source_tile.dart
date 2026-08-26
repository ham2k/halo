// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// One screen, app or window as a picture (HALO-369) — shared by the two
// pickers, because they are choosing between the same things for opposite
// reasons: what this device SHARES, and what a pane SHOWS.
//
// A picture rather than a name, in both. A machine offers one or two
// displays and dozens of windows, several of which are called the same thing
// ("Safari", "Untitled"), and neither decision can be made from a list of
// near-identical labels.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

class ScreenSourceTile extends StatelessWidget {
  final PeerScreenSource source;

  /// Which device it lives on, where that is not obvious — the viewer's
  /// picker lists several at once; the producer's lists only its own.
  final String? subtitle;

  final Uint8List? thumbnail;
  final bool selected;

  /// Shown where selection is a SET the operator is building (what to
  /// share). Off where the pick is one of many and closes the dialog.
  final bool showCheckbox;

  final VoidCallback onTap;

  const ScreenSourceTile({
    super.key,
    required this.source,
    required this.thumbnail,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.showCheckbox = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final image = thumbnail;
    return Semantics(
      label: subtitle == null ? source.name : '${source.name}, $subtitle',
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              // Selection is the whole tile's frame rather than only a box
              // in its corner: it has to read at a glance across a grid.
              color: selected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
              width: selected ? 3 : 1,
            ),
            color: theme.colorScheme.surfaceContainerHighest,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // No picture yet is the ordinary state for a moment —
                    // stills are fetched a few at a time — so it shows the
                    // kind's glyph rather than a spinner that would have the
                    // whole grid flickering.
                    if (image == null)
                      Center(
                        child: Icon(iconForScreenSourceKind(source.kind),
                            color: theme.colorScheme.onSurfaceVariant),
                      )
                    else
                      Image.memory(image, fit: BoxFit.contain, gaplessPlayback: true),
                    if (showCheckbox)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Checkbox(value: selected, onChanged: (_) => onTap()),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: Space.xs),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      source.name,
                      maxLines: subtitle == null ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData iconForScreenSourceKind(String kind) => switch (kind) {
      PeerScreenSourceKind.display => MdiIcons.monitor,
      PeerScreenSourceKind.app => MdiIcons.applicationOutline,
      _ => MdiIcons.windowMaximize,
    };
