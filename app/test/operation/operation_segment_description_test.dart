// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A segment row's description is polo's `describeOperation`: each ref's own
// phrase, then the square. Merging by kind (what the operation TITLE does)
// would fold two "at" refs into one phrase and lose which ref said what.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/tools/operation_title.dart';

void main() {
  test('one phrase per ref, most specific fragment first, then the square', () {
    final text = segmentDescriptionFor(
      t,
      const [
        OperationTitleSuggestion(forText: 'ARRL 10G Sep', subtitle: 'Sending FN20rm'),
        OperationTitleSuggestion(atText: 'US-1000', subtitle: 'A Park'),
      ],
      'FN20rm',
    );
    expect(text, 'for ARRL 10G Sep • at US-1000 • at FN20rm');
  });

  test('a ref with only a subtitle still says something, and no grid adds nothing', () {
    expect(segmentDescriptionFor(t, const [OperationTitleSuggestion(subtitle: 'Just this')], null), 'Just this');
    expect(segmentDescriptionFor(t, const [], null), '');
  });
}
