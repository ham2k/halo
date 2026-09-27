// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The pane layout options dialog as the operator sees it
// (docs/design/user-interface.md § Settings lists).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/views/operation/pane_layout_options.dart';

void main() {
  testWidgets("the Panel Settings heading lines up with the panel's own rows", (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showPaneLayoutOptions(
                  context,
                  paneTitle: 'Spots',
                  defaultTitle: 'Spots',
                  inTabset: false,
                  developerMode: false,
                  current: PaneLayoutOptions.none,
                  onChanged: (_) {},
                  onReset: () {},
                  resetTitle: 'Reset',
                  resetBody: 'Reset?',
                  panelSettingsBuilder: (_) => const ListTile(title: Text('A Setting')),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // The rows take their inset from the SettingsList around them, and the
    // pane pads nothing: a heading outside that SettingsList has no inset to
    // read and sits at the pane's edge, left of the rows it heads.
    expect(tester.getTopLeft(find.text(t.operation.layout.panelSettingsAction)).dx, tester.getTopLeft(find.text('A Setting')).dx);
  });
}
