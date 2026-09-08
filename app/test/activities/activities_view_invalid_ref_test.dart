// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A reference that fails its program's pattern is MARKED, never refused. The
// pattern is HaLo's idea of the program, not the program's own — a format that
// changed, or one this app has wrong, would otherwise cost the operator a
// reference they were given on the air, with the log and every export missing
// it. So the mark is the whole of the app's opinion, and the trap this file
// exists to catch is the opposite reading: a helper that answers "invalid" for
// a ref type nobody serves, or for a reference that is perfectly well formed,
// puts a red chip on rows that are fine and teaches the operator to ignore it.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/views/operation/activities_view.dart';

void main() {
  const controls = <Map<String, dynamic>>[
    {
      'key': 'pota/activation',
      'input': {'kind': 'refList', 'refType': 'potaActivation', 'pattern': r'[A-Z0-9]+-(?:[0-9]{4,5}|TEST)'},
    },
    {
      'key': 'custom/activation',
      'input': {'kind': 'form', 'refType': 'customActivation'},
    },
  ];

  test('a code its program would not recognize is marked', () {
    expect(activityRowIsInvalid(controls, const {'type': 'potaActivation', 'ref': 'NOT-A-PARK'}), isTrue);
  });

  test('a well-formed code is not, whatever case it was typed in', () {
    expect(activityRowIsInvalid(controls, const {'type': 'potaActivation', 'ref': 'US-1234'}), isFalse);
    expect(activityRowIsInvalid(controls, const {'type': 'potaActivation', 'ref': 'us-1234'}), isFalse);
  });

  test('the pattern must match the WHOLE code, not merely appear inside it', () {
    // Unanchored, "XUS-1234Y" would pass and the mark would never appear on a
    // reference with junk around it — the commonest way a bad paste arrives.
    expect(activityRowIsInvalid(controls, const {'type': 'potaActivation', 'ref': 'XUS-1234Y'}), isTrue);
  });

  test('a control that declares no pattern has nothing to fail', () {
    // A form-configured activity (a contest) has no reference code at all.
    expect(activityRowIsInvalid(controls, const {'type': 'customActivation', 'ref': 'whatever'}), isFalse);
  });

  test('a ref type no enabled extension serves is a different problem, not this one', () {
    // `isUnknownRefType` already colors that row; claiming it is also malformed
    // would say the operator typed something wrong when the truth is that an
    // extension is switched off.
    expect(activityRowIsInvalid(controls, const {'type': 'sotaActivation', 'ref': 'W6/SD-026'}), isFalse);
  });

  test('a pattern an extension got wrong disables the mark rather than throwing into the row', () {
    // This runs for every row of every build, so an unbalanced group in some
    // extension's regex would otherwise take the whole Activities sheet down.
    const broken = <Map<String, dynamic>>[
      {
        'key': 'oops/activation',
        'input': {'kind': 'refList', 'refType': 'oopsActivation', 'pattern': r'[A-Z'},
      },
    ];
    expect(activityRowIsInvalid(broken, const {'type': 'oopsActivation', 'ref': 'ANYTHING'}), isFalse);
  });

  test('an entry with no code at all is unmarked', () {
    expect(activityRowIsInvalid(controls, const {'type': 'potaActivation'}), isFalse);
    expect(activityRowIsInvalid(controls, const {'type': 'potaActivation', 'ref': '  '}), isFalse);
  });
}
