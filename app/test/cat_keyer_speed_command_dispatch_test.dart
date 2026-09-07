// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The last mile of the WPM command ("20WPM" typed into the call field) —
// `handleCommandAction`'s `setKeyerSpeed` case, the counterpart of
// cat_power_command_dispatch_test.dart. Unlike power there is no app-side
// value to land in: the keyer is the radio's, so what this pins is that
// the action FAILS OUT LOUD with nothing connected rather than confirming.
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';

import 'support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<HaLoServices> buildServices() async {
    return (await makeHaLoServices()).services;
  }

  test('with no radio that can key, setKeyerSpeed reports failure instead of confirming', () async {
    final services = await buildServices();
    await services.settings.setExperimentEnabled('keyer', true);
    final outcome = await services.handleCommandAction('setKeyerSpeed', {'wpm': 20});
    expect(outcome, isNotNull, reason: 'null would let the hook\'s "Keyer speed set" confirm stand');
    expect(outcome!.failed, isTrue);
    expect(outcome.text, 'No connected radio can key CW');
  });

  test('with the keyer experiment off, both actions refuse rather than reach the radio', () async {
    // The hooks decline while it is off; this pins the dispatcher's own guard
    // for an action arriving anyway (a stale interpretation, an extension).
    final services = await buildServices();
    final node = await services.cat.addNode(
      typeKey: 'placeholder-radio',
      name: 'Bench Rig',
      config: placeholderRadioModel.variants.single.defaultConfig,
    );
    await services.cat.connect(node.uuid);
    addTearDown(() => services.cat.disconnect(node.uuid));
    final context = services.openOperationContext('op-1');
    addTearDown(() => services.closeOperationContext(context));
    context.operation = {'uuid': 'op-1'};

    expect((await services.handleCommandAction('setKeyerSpeed', {'wpm': 20}))?.text, contains('EXP KEYER'));
    expect(services.cat.canKeyCw, isFalse, reason: 'without the experiment nothing is even the key in use');
    expect((await services.handleCommandAction('showKeyer'))?.text, contains('EXP KEYER'));
    expect(services.cat.keyerAreaShown.value, isFalse);
  });

  test('showKeyer fails out loud with nothing that can key, and bumps the area request otherwise', () async {
    final services = await buildServices();
    await services.settings.setExperimentEnabled('keyer', true);
    expect((await services.handleCommandAction('showKeyer'))?.failed, isTrue);
    final node = await services.cat.addNode(
      typeKey: 'placeholder-radio',
      name: 'Bench Rig',
      config: placeholderRadioModel.variants.single.defaultConfig,
    );
    await services.cat.connect(node.uuid);
    addTearDown(() => services.cat.disconnect(node.uuid));
    expect(services.cat.keyerAreaShown.value, isFalse);
    // From Home there is no logging panel to hold the area: refused, not
    // confirmed.
    expect((await services.handleCommandAction('showKeyer'))?.text, 'Open an operation to use the CW keyer');
    expect(services.cat.keyerAreaShown.value, isFalse);

    final context = services.openOperationContext('op-1');
    addTearDown(() => services.closeOperationContext(context));
    // The view fills this in once its operation loads; here that is the test.
    context.operation = {'uuid': 'op-1'};
    expect(await services.handleCommandAction('showKeyer'), isNull);
    expect(services.cat.keyerAreaShown.value, isTrue);
  });

  test('with a keyer-capable radio connected, the speed reaches it and the hook\'s confirm stands', () async {
    final services = await buildServices();
    await services.settings.setExperimentEnabled('keyer', true);
    final node = await services.cat.addNode(
        typeKey: 'placeholder-radio',
        name: 'Bench Rig',
        // The Add dialog prefills these; a bare node fails its own validators.
        config: placeholderRadioModel.variants.single.defaultConfig,
      );
    await services.cat.connect(node.uuid);
    addTearDown(() => services.cat.disconnect(node.uuid));

    final outcome = await services.handleCommandAction('setKeyerSpeed', {'wpm': 20});
    expect(outcome, isNull);
    expect(services.cat.keyerSpeed, 20);
  });
}
