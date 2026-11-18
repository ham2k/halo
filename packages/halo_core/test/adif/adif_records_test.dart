// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A pushed record's hash decides whether it is sent again
// (docs/design/transfer.md §5): the same contact must render the same, the
// header must never reach a record, and an omitted field must leave no trace.

import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

void main() {
  const file =
      'ADIF export for N0DEV\n<ADIF_VER:5>3.1.5\n<CREATED_TIMESTAMP:15>20261116 120000\n<EOH>\n\n'
      '<CALL:4>W1AW <BAND:3>20m <NOTES:5>hello <APP_HAM2K_X:1>y <EOR>\n'
      '<CALL:5>K1ABC <BAND:3>40m <EOR>\n';

  test('one record each, without the header and its timestamp', () {
    expect(adifRecordsOf(file), ['<CALL:4>W1AW <BAND:3>20m <NOTES:5>hello <APP_HAM2K_X:1>y <EOR>', '<CALL:5>K1ABC <BAND:3>40m <EOR>']);
  });

  test('an omitted field is gone, by name or by prefix, in any case', () {
    expect(adifRecordsOf(file, omit: ['notes', 'app_*']).first, '<CALL:4>W1AW <BAND:3>20m <EOR>');
  });

  test('a length counts bytes, so a non-ASCII value keeps its record readable', () {
    expect(adifRecordsOf('<NAME:5>José <EOR>'), ['<NAME:5>José <EOR>']);
  });
}
