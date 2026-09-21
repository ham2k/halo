// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The ESM Messages set (docs/design/cat.md § CW keying): what turning Enter
// Sends Messages on does to the operator's message sets, and what it must
// leave alone.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/settings_service.dart';

import '../support/halo_test_support.dart';

void main() {
  late SettingsService settings;

  setUp(() async {
    settings = (await makeHaLoServices()).settings;
  });

  List<String> names() => [for (final set in settings.cwMessageSets) set.name];

  test('the seeds stay laid out for keying by hand', () {
    // ESM's layout is a set of its own: the Default's F2 answers a caller in
    // one key, and splitting it for ESM would take that from every operator
    // who never turns ESM on.
    expect(names(), ['Default', 'POTA']);
    expect(settings.cwMessage(2), '{{qso.call}} UR 5NN TU');
  });

  test('turning ESM on adds ESM Messages, in N1MM order, and puts it in use', () async {
    await settings.setExperimentEnabled('esm', true);
    expect(names(), ['Default', 'POTA', 'ESM Messages']);
    expect(settings.cwMessageSetName, 'ESM Messages', reason: 'ESM keys by position; the Default is not laid out for it');
    expect([for (var n = 1; n <= 8; n++) settings.cwMessage(n)],
        ['CQ DE {{op.call}} K', '5NN', 'TU', '{{op.call}}', '{{qso.call}}', '', '', 'AGN?']);
  });

  test('sets the operator already has are kept, and in order', () async {
    final mine = settings.cwMessageSets.first.renamed('Mine').withMessage(1, 'CQ TEST {{op.call}}');
    await settings.setCwMessageSets([mine], active: 'Mine');
    await settings.setExperimentEnabled('esm', true);
    expect(names(), ['Mine', 'ESM Messages']);
    expect(settings.cwMessageSets.first.message(1), 'CQ TEST {{op.call}}');
  });

  test('it is added once, ever — a deleted set stays deleted', () async {
    await settings.setExperimentEnabled('esm', true);
    final kept = [for (final set in settings.cwMessageSets) if (set.name != 'ESM Messages') set];
    await settings.setCwMessageSets(kept, active: 'Default');

    await settings.setExperimentEnabled('esm', false);
    await settings.setExperimentEnabled('esm', true);
    expect(names(), ['Default', 'POTA']);
    expect(settings.cwMessageSetName, 'Default', reason: 'the operator chose a set since; re-enabling must not take it back');
  });

  test('turning on any other experiment adds nothing', () async {
    await settings.setExperimentEnabled('keyer', true);
    expect(names(), ['Default', 'POTA']);
  });
}
