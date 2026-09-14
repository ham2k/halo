// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What an extension's hooks are turned into for the details dialog. The
// vocabulary is written for the app's own plumbing, and read out loud it says
// nothing to the operator — so the mapping is the whole feature, and the
// cases below are the ones where an easier rule gets it wrong.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/views/extension_install_flow.dart';

List<String> labels(List<String> hooks) => extensionHookLabels(hooks, t.extensionsPanel);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the plumbing hooks are dropped, not printed', () {
    // `activity` and the ADIF pair are how an extension attaches to the app.
    // Shown, they are three identifiers in a list of plain-language phrases,
    // which reads as a defect rather than as information.
    expect(labels(const ['activity', 'adifFields', 'adifImport', 'export']), ['Export']);
  });

  test('a hook nobody has given words to is dropped as well', () {
    // The default has to be silence: a hook added later would otherwise
    // appear in the operator's list as its camelCase name, in a release
    // nobody thought about it in.
    expect(labels(const ['recentContextLookup', 'settingsPanel', 'scoring']), ['Scoring']);
  });

  test('a program with both sides is hunted and activated, in that order', () {
    expect(
      labels(const ['ref:wwff', 'ref:wwffActivation']),
      ['Hunting WWFF', 'Activating WWFF'],
    );
  });

  test('a reference with no activation twin is named, never called hunting', () {
    // A contest declares the plain form alone. Reading every bare `ref:` as
    // hunting would have the CQ WW extension offer "Hunting CQWW", which is
    // not a thing anyone does.
    expect(labels(const ['ref:cqww']), ['CQWW']);
  });

  test('an activation-only program is not also hunted', () {
    // WCA is activate-only, and the twin rule is one-directional: the plain
    // form implies nothing about the activation form, or this list would
    // claim a side of the program the extension does not handle.
    expect(labels(const ['ref:wcaActivation']), ['Activating WCA']);
  });

  test('a hyphenated reference type reads as the program, not as the hook', () {
    expect(labels(const ['ref:arrl-dx']), ['ARRL DX']);
  });

  test('a qualified claim is dropped, not printed as a path', () {
    // `ref:qp/ny` is how the New York QSO Party reaches back for references
    // logged when fifty parties shared one extension — a matching rule, not
    // something anybody chose the extension for. Printed, it reads `QP/NY`
    // next to plain-language phrases, and its own plain claim is right there
    // saying what the extension is.
    expect(labels(const ['activity', 'ref:ny-qso-party', 'ref:qp/ny']), ['NY QSO PARTY']);
  });

  test('an extension of nothing but plumbing offers an empty list', () {
    // Which is what lets the dialog leave the whole section out rather than
    // print a heading over nothing.
    expect(labels(const ['activity', 'adifFields']), isEmpty);
  });
}
