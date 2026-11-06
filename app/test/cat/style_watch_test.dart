// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The FYI area's Run message (docs/design/logging-fields.md § The FYI
// area): the style that is not the default, said in each running set.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/cat/operating_style.dart';
import 'package:ham2k_logger/services/cat/style_watch.dart';
import 'package:ham2k_logger/services/fyi_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoServices services;

  setUp(() async {
    services = (await makeHaLoServices()).services;
    services.styleWatch.start();
    addTearDown(services.styleWatch.dispose);
  });

  FyiMessage? said(String radio) => services.fyi.messageFor(StyleWatch.keyFor(radio));

  test('Run is said, as a high operational message on a pill of its own colour that a tap leaves standing; normal says nothing', () {
    expect(said('A'), isNull, reason: 'normal is the default, and says nothing');
    services.cat.setStyle('A', OperatingStyle.run);
    final run = said('A')!;
    expect((run.category, run.priority, run.text, run.radio), (FyiCategory.operational, FyiPriority.high, 'Run', 'A'));
    expect(run.backgroundColor, StyleWatch.runColor, reason: 'a state, not a problem: a pill, but not in the alert colour');
    // A tap is the switch: dismissed, it would hide a run still going.
    expect(run.dismissible, isFalse);
    services.cat.setStyle('A', OperatingStyle.normal);
    expect(said('A'), isNull);
  });

  test('a tap on Run is S&P, which takes the pill down unless it is always shown', () async {
    services.cat.setStyle('A', OperatingStyle.run);
    said('A')!.onTap!();
    expect(services.cat.styleOf('A'), OperatingStyle.normal);
    expect(said('A'), isNull, reason: 'normal says nothing by default');

    await services.settings.setSettingValue(SettingsService.loggingGroup, 'alwaysShowStyle', true);
    final sp = said('A')!;
    expect((sp.text, sp.backgroundColor, sp.dismissible), ('S&P', StyleWatch.spColor, false));
    sp.onTap!();
    expect(services.cat.styleOf('A'), OperatingStyle.run);
    expect(said('A')?.text, 'Run');
  });

  // The trap: Radio B answers with Radio A's style outside SO2R, so a
  // watch asking it would say Run twice — once for a set that isn't there.
  test("under SO2R each set says its own, and Radio B's goes with SO2R", () async {
    await services.settings.setExperimentEnabled('so2r', true);
    services.cat.setStyle('A', OperatingStyle.normal);
    services.cat.setStyle('B', OperatingStyle.run);
    expect(said('A'), isNull);
    expect(said('B')?.radio, 'B');
    await services.settings.setExperimentEnabled('so2r', false);
    services.cat.setStyle('A', OperatingStyle.run);
    expect(said('A')?.radio, 'A');
    expect(said('B'), isNull);
  });
}
