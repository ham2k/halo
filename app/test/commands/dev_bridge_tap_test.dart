// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart' show semanticId;
import 'package:ham2k_logger/config/dev_bridge.dart';

void main() {
  late List<String> pressed;

  Future<void> pumpButtons(WidgetTester tester) async {
    pressed = [];
    Widget button(String label) => ElevatedButton(onPressed: () => pressed.add(label), child: Text(label));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              semanticId('action.save', button('Save')),
              button('Save draft'),
              button('Cancel'),
              button('Close'),
              // Mounted and in the semantics tree, but not on screen: a
              // collapsed section's contents (clipped to nothing, the way
              // ExpansionTile collapses), a list row past the viewport
              // (built ahead in the scroll cache) and a control squeezed to
              // no size at all. A script must never press what the operator
              // cannot.
              SizedBox.shrink(child: button('Squeezed')),
              ClipRect(
                child: Align(alignment: Alignment.topCenter, heightFactor: 0, child: button('Collapsed')),
              ),
              SizedBox(height: 60, child: ListView(children: [button('Row 1'), const SizedBox(height: 100), button('Row 2')])),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('a stable identifier taps its control even when another label contains its text', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpButtons(tester);

    expect(await DevBridge.instance.tap('action.save'), {
      'tapped': {'identifier': 'action.save', 'label': 'Save'},
    });
    expect(pressed, ['Save']);
    semantics.dispose();
  });

  testWidgets('an exact label wins over labels that merely contain it', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpButtons(tester);

    // "save" is contained in two labels, but only one IS it: without the
    // exact rule ahead of the contains rule this would refuse as ambiguous.
    await DevBridge.instance.tap('save');
    await DevBridge.instance.tap('DRAFT');
    expect(pressed, ['Save', 'Save draft']);
    semantics.dispose();
  });

  testWidgets('an ambiguous target taps nothing and names the candidates', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpButtons(tester);

    final result = await DevBridge.instance.tap('c');
    expect(result['error'], contains('matches 2 controls'));
    expect([for (final match in result['matches'] as List) (match as Map)['label']], ['Cancel', 'Close']);
    expect(pressed, isEmpty);
    semantics.dispose();
  });

  testWidgets('a control that is not on screen is never a target', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpButtons(tester);

    expect((await DevBridge.instance.tap('Collapsed'))['error'], contains('nothing on screen'));
    expect((await DevBridge.instance.tap('Row 2'))['error'], contains('nothing on screen'));
    expect((await DevBridge.instance.tap('Squeezed'))['error'], contains('nothing on screen'));
    expect([for (final target in await DevBridge.instance.targets()) target['label']], ['Save', 'Save draft', 'Cancel', 'Close', 'Row 1']);
    expect(pressed, isEmpty);
    semantics.dispose();
  });

  testWidgets('log and wipe go to the logging screen, not the semantics tree', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpButtons(tester);
    // With no logging screen, "log" must not fall through to label matching,
    // where it would press whatever single control's label contains it.
    DevBridge.instance.actionHandler = null;
    expect((await DevBridge.instance.tap('log'))['error'], contains('no logging screen'));

    final actions = <String>[];
    DevBridge.instance.actionHandler = actions.add;
    addTearDown(() => DevBridge.instance.actionHandler = null);

    expect(await DevBridge.instance.tap('log'), {'tapped': 'log'});
    expect(actions, ['log']);
    semantics.dispose();
  });

  test('runCommand answers an error, not a hang, before the app shell mounts', () async {
    DevBridge.instance.runCommandHandler = null;
    expect(await DevBridge.instance.runCommand('SEED'), contains('error'));
  });
}
