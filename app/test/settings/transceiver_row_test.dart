// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The inventory's transceiver rows: the connection glyph sits flush right,
// over the right-aligned address it belongs to.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/views/station_rows.dart';

void main() {
  Widget wrap(Widget child) => TranslationProvider(
    child: MaterialApp(
      home: Scaffold(body: SizedBox(width: 600, child: child)),
    ),
  );

  for (final (label, channel) in [('without a channel pill', null), ('with a channel pill', 'Slice A')]) {
    testWidgets('a short name leaves the glyph flush right, $label', (tester) async {
      // Traps a name that only takes a share of the slack: a short one
      // leaves the rest of its share after the glyph, and where the glyph
      // lands then depends on how long the name is.
      await tester.pumpWidget(
        wrap(TransceiverRow(name: 'Flex', channel: channel, connection: '10.0.0.1:4992', connectionIcon: MdiIcons.lan, selected: false, onSelect: () {})),
      );

      final glyphRight = tester.getTopRight(find.byIcon(MdiIcons.lan)).dx;
      final addressRight = tester.getTopRight(find.text('10.0.0.1:4992')).dx;
      expect(glyphRight, addressRight);
    });
  }
}
