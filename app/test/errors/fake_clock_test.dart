// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import '../support/fake_clock.dart';

void main() {
  // A test that fails on the fake clock is read by its error. A second,
  // unrelated one from the helper itself ("The error handler of Future.then
  // must return a value…") sits on top of it and sends the reader after the
  // helper instead of the test.
  test('a body that fails on the fake clock is reported by its own error alone', () {
    Object? thrown;
    final stray = <Object>[];
    runZonedGuarded(() {
      try {
        runOnFakeClock((async) async {
          await Future<void>.delayed(const Duration(seconds: 1));
          throw StateError('the body failed');
        });
      } catch (e) {
        thrown = e;
      }
    }, (error, _) => stray.add(error));
    expect(thrown, isA<StateError>().having((e) => e.message, 'message', 'the body failed'));
    expect(stray, isEmpty);
  });
}
