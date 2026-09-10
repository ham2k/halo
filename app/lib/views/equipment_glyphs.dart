// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// How an equipment type shows itself in a row: the glyph for what it IS, the
// glyphs for the ways it plugs in, and where it is. Shared by the Station panel's
// equipment tiles and the Add Equipment dialog's catalogue, which draw the
// same row from different lists.

import 'package:flutter/material.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../services/cat/equipment.dart';
import '../services/cat/equipment_registry.dart';

/// The glyph the logging panel's own Radio control falls back to when no
/// CAT radio is configured — this list is what configures one.
IconData iconForCategory(String? category) => switch (category) {
      kCategoryTransceiver => MdiIcons.radio,
      kCategoryAntenna => MdiIcons.antenna,
      kCategoryKey => MdiIcons.key,
      kCategoryKeyer => MdiIcons.keyboardVariant,
      kCategoryAntennaSwitch => MdiIcons.directionsFork,
      _ => MdiIcons.developerBoard,
    };

/// How a pairing is plugged in, as a glyph — see `transportIconNameFor`.
///
/// Null when the transport has no glyph, so a caller leaves the slot empty.
/// Deliberately not defaulted to something generic: `resolveIconName` answers
/// an unknown name with a puzzle piece, and a puzzle piece next to a radio
/// says less than nothing.
IconData? _iconForTransport(EquipmentType type) {
  final name = type.transportIconName;
  return name == null ? null : resolveIconName(name);
}

/// The transport glyphs of a model's pairings, in one small row.
///
/// Size is spelled out because this is not a ListTile slot — those inherit 24
/// from the tile's own IconTheme, and this sits beside body text.
class TransportIcons extends StatelessWidget {
  final List<EquipmentType> types;

  const TransportIcons({
    super.key,required this.types});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icons = [
      for (final type in types)
        if (_iconForTransport(type) case final icon?) (icon: icon, label: type.transportLabel),
    ];
    if (icons.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // By index, not by `entry != icons.first`: these are records, which
        // compare by VALUE, so two pairings sharing a glyph and a label would
        // both count as the first and the second would lose its gap.
        for (final (index, entry) in icons.indexed) ...[
          if (index > 0) const SizedBox(width: Space.xs),
          Icon(
            entry.icon,
            size: 16,
            // The app has no hover tooltips, so this is the only place the
            // glyph is named for anyone who cannot see it.
            semanticLabel: entry.label,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ],
    );
  }
}

/// Where a piece of equipment is — an address or a serial port path — clipped
/// from the FRONT when it does not fit.
///
/// Trailing ellipsis is wrong for these: what distinguishes one of a shack's
/// devices from another is the end of the string, not the start.
/// `/dev/cu.usbserial-FTB6SPL3` and `/dev/cu.usbserial-00F8E1EB0` share
/// eighteen characters and differ in the last nine, so a row cut to fit says
/// `/dev/cu.usbse…` for both. Cut from the front it says `…rial-FTB6SPL3`,
/// which names the one the operator is looking at.
///
/// Measured rather than guessed at a character count: the string is
/// proportional text under a font scale the operator sets, so how much fits
/// is not knowable from its length ([textWidth] folds in the ambient style
/// and text scaler, per docs/design/ui-scaling.md).
class AddressText extends StatelessWidget {
  final String address;
  final TextStyle? style;
  final TextAlign? textAlign;

  const AddressText(this.address, {super.key, this.style, this.textAlign});

  @override
  Widget build(BuildContext context) {
    final resolved = style ?? DefaultTextStyle.of(context).style;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Unbounded means no measurement is possible, and the Text below then
        // clips its TAIL — the one thing this widget exists to prevent, and
        // invisibly. A non-flex child of a Row gets exactly that
        // (docs/quirks.md), so it fails here rather than degrading there.
        assert(constraints.maxWidth.isFinite, 'AddressText needs a bounded width to clip against');
        final width = constraints.maxWidth;
        var text = address;
        if (width.isFinite && textWidth(context, text, resolved) > width) {
          // The longest TAIL that fits, found by walking the cut forward: the
          // strings are short enough that this costs less than the layout it
          // is deciding, and a binary search over a proportional font can
          // overshoot on a run of narrow characters.
          //
          // Seeded with the ellipsis alone, not the empty string: a column too
          // narrow for even one character would otherwise paint NOTHING where
          // an address should be, which reads as a row that has no address
          // rather than one whose address did not fit.
          text = '…';
          for (var i = address.length; i > 0; i--) {
            final candidate = '…${address.substring(i - 1)}';
            if (textWidth(context, candidate, resolved) > width) break;
            text = candidate;
          }
        }
        // The WHOLE address stays in the semantics tree however little of it
        // is painted: the clip is a fit problem, and a screen reader has no
        // width to run out of.
        return Text(
          text,
          style: style,
          textAlign: textAlign,
          maxLines: 1,
          softWrap: false,
          semanticsLabel: text == address ? null : address,
        );
      },
    );
  }
}
