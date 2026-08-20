// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Self-dismissing footer items. The trap in every case is the dismiss timer's
// ownership: a timer belongs to the POSTING that scheduled it, not to the key.
// A guard any looser than identity lets the timer of one completion clear the
// NEXT completion on the same key — two quick back-to-back ADIF imports would
// show the second "Imported N contacts" for close to zero seconds.

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/status_bar_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late StatusBarService statusBar;

  final pastDelay = StatusBarService.completedDismissDelay + const Duration(seconds: 1);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    statusBar = StatusBarService(await SharedPreferences.getInstance());
  });

  test('a message with dismissAfter clears itself; one without stays', () {
    fakeAsync((async) {
      statusBar.setMessage(key: 'done', text: 'imported', dismissAfter: StatusBarService.completedDismissDelay);
      statusBar.setMessage(key: 'sticky', text: 'still here');

      async.elapse(pastDelay);

      expect(statusBar.itemForKey('done'), isNull);
      expect(statusBar.itemForKey('sticky'), isNotNull);
    });
  });

  test('a stale dismiss timer does not clear the message that replaced its own', () {
    fakeAsync((async) {
      statusBar.setMessage(key: 'import', text: 'first', dismissAfter: StatusBarService.completedDismissDelay);
      async.elapse(const Duration(seconds: 3));
      statusBar.setMessage(key: 'import', text: 'second', dismissAfter: StatusBarService.completedDismissDelay);

      // Past the first posting's deadline, before the second's: only the
      // second posting's own timer may clear it.
      async.elapse(const Duration(seconds: 3));
      expect(statusBar.itemForKey('import')?.text, 'second');

      async.elapse(pastDelay);
      expect(statusBar.itemForKey('import'), isNull);
    });
  });

  test('a completed progress item clears itself, on its own timer only', () {
    fakeAsync((async) {
      statusBar.setProgress(key: 'sync', value: 1.0);
      async.elapse(const Duration(seconds: 3));
      statusBar.setProgress(key: 'sync', text: 'imported', value: 1.0);

      async.elapse(const Duration(seconds: 3));
      expect(statusBar.itemForKey('sync')?.text, 'imported');

      async.elapse(pastDelay);
      expect(statusBar.itemForKey('sync'), isNull);
    });
  });

  test('a completed item replaced by a fresh indeterminate run is left alone', () {
    fakeAsync((async) {
      statusBar.setProgress(key: 'sync', value: 1.0);
      statusBar.setProgress(key: 'sync', value: null);

      async.elapse(pastDelay);

      expect(statusBar.itemForKey('sync'), isNotNull);
    });
  });
}
