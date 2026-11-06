// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The last mile of RUN and SNP — `handleCommandAction`'s `setOpStyle` case:
// the operating style of the set the operator is in
// (docs/design/logging-fields.md § Operating style).
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/operating_style.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The style is how the operator is working and what the next contact
  // records: it is not ESM's, so neither ESM's experiment nor a radio that
  // can key stands in its way, and naming it never switches ESM on.
  test('sets the style with no radio and no experiment, and leaves ESM as it was', () async {
    final services = (await makeHaLoServices()).services;
    expect(await services.handleCommandAction('setOpStyle', {'opStyle': 'normal'}), isNull);
    expect(services.cat.styleOf('A'), OperatingStyle.normal);
    expect(await services.handleCommandAction('setOpStyle', {'opStyle': 'run'}), isNull);
    expect(services.cat.styleOf('A'), OperatingStyle.run);
    expect(services.cat.enterSends.value.on, isFalse);
  });

  test("under SO2R it is the style of the set the operator is in", () async {
    final services = (await makeHaLoServices()).services;
    await services.settings.setExperimentEnabled('so2r', true);
    services.cat.setStyle('A', OperatingStyle.run);
    services.cat.setStyle('B', OperatingStyle.run);
    services.cat.noteOperatorRadio('B');
    await services.handleCommandAction('setOpStyle', {'opStyle': 'normal'});
    expect((services.cat.styleOf('A'), services.cat.styleOf('B')), (OperatingStyle.run, OperatingStyle.normal));
  });

  // The trap: answering success, which leaves the hook's confirm saying a
  // style was set while every new contact goes on recording the old one.
  test('a style it does not know changes nothing, and fails aloud', () async {
    final services = (await makeHaLoServices()).services;
    services.cat.setStyle('A', OperatingStyle.run);
    final outcome = await services.handleCommandAction('setOpStyle', {'opStyle': 'S&P'});
    expect(outcome?.failed, isTrue);
    expect(outcome?.text, contains('S&P'));
    expect(services.cat.styleOf('A'), OperatingStyle.run);
  });
}
