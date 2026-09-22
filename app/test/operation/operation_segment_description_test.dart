// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A segment row's description is the operation's own generated title — the
// same "for X at Y" the header shows, so the row that opened a stretch reads
// like the operation did during it — with the square appended to the places,
// and worded for what the row marks: a start states, a break says what is
// now true.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/tools/operation_title.dart';

void main() {
  const suggestions = [
    OperationTitleSuggestion(forText: 'NJQP: MORR', subtitle: 'Morris'),
    OperationTitleSuggestion(atText: 'US-1234', subtitle: 'A Park'),
    OperationTitleSuggestion(atText: 'KFF-1234', subtitle: 'A Flora'),
  ];

  test('a start states the stretch like the title, square among the places', () {
    // Merged by kind as the title is — two "at" refs join into one place list
    // — rather than one phrase per ref; the square joins that list rather
    // than getting an "at" of its own.
    expect(segmentDescriptionFor(t, suggestions, 'FN21rq', kind: 'start'), 'For NJQP: MORR at US-1234, KFF-1234, FN21rq');
  });

  test('a break says what is now true', () {
    expect(segmentDescriptionFor(t, suggestions, 'FN21rq', kind: 'break'), 'Now for NJQP: MORR at US-1234, KFF-1234, FN21rq');
  });

  test('a square alone is still a place, and nothing at all is nothing', () {
    expect(segmentDescriptionFor(t, const [], 'FN20rm', kind: 'start'), 'At FN20rm');
    // A subtitle is detail under the title, never part of it — the row reads
    // the same as a header with that subtitle would.
    expect(segmentDescriptionFor(t, const [OperationTitleSuggestion(subtitle: 'Just this')], null, kind: 'break'), '');
  });
}
