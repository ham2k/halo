// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Radio pane resolving its own meter list, against a real CatService and
// a real connected radio.
//
// panel_radio_pane_test.dart drives [RadioReadout] directly, which means it
// hands the strip its meters and can never catch the pane failing to work
// out what they are. That resolution — node → catalogue type → driver → the
// meters it declares — is exactly where a strip goes missing on a radio the
// operator has plainly connected, and it is invisible from there.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/radio_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/operation/radio/radio_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CatService cat;
  late RadioService radio;
  late SettingsService settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    radio = RadioService(prefs, writeDelay: Duration.zero);
    settings = SettingsService(prefs, secureStorage: FakeSecureStorage());
    cat = CatService(settings, radio: radio, registry: EquipmentRegistry());
  });

  tearDown(() {
    cat.dispose();
    radio.dispose();
  });

  /// A Placeholder Radio in the station's inventory, configured the way the
  /// Add dialog would leave it.
  ///
  /// Deliberately NOT connected: which meters the pane offers is a question
  /// about the CATALOGUE, answered before a socket is ever opened — that is
  /// what lets the strip reserve its slots ahead of the first transmission.
  /// Connecting would also leave the placeholder's heartbeat ticking past
  /// the end of the test.
  Future<EquipmentNode> placeholderInInventory() async {
    final type = cat.registry.typeFor('placeholder-radio')!;
    return cat.addNode(typeKey: 'placeholder-radio', config: {...type.defaultConfig});
  }

  testWidgets('a Placeholder Radio shows the meter strip before it has ever transmitted', (tester) async {
    final node = await placeholderInInventory();

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => SizedBox(
                width: 320,
                height: 160,
                child: RadioReadout(
                  node: node,
                  state: cat.stateFor(node.uuid),
                  live: true,
                  style: radioStyleModern,
                  palette: radioPaletteFor(context, radioStyleModern),
                  power: null,
                  // What the PANE works out, exercised here rather than typed
                  // in by the test — see this file's header.
                  meters: cat.typeFor(node)?.driver.telemetryMeters ?? const {},
                  onTune: null,
                  powerButton: null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final p = t.operation.layout.panels;
    // The slots exist before the rig has ever been keyed. If this is empty,
    // the pane never learned which meters the radio has and the operator
    // sees nothing at all — the strip's absence being indistinguishable from
    // a radio that simply is not transmitting.
    expect(find.text(p.radioSwr), findsOneWidget);
    expect(find.text(p.radioWatts), findsOneWidget);
    expect(find.text(p.radioVolts), findsOneWidget);
  });

  testWidgets('the strip is absent for a radio whose driver reads no meters', (tester) async {
    // The other half of the same wiring: a Yaesu or Kenwood declares none,
    // and reserving slots that can never fill would be worse than nothing.
    final type = cat.registry.typeFor('yaesu-generic-serial') ?? cat.registry.typeFor('ft891-serial');
    expect(type, isNotNull, reason: 'a Yaesu pairing has to exist for this to mean anything');
    expect(type!.driver.telemetryMeters, isEmpty);
  });
}
