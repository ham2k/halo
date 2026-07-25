// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Footer items hold the slot their key first claimed. This matters because
// the things that update most are progress bars, ticking several times a
// second: ordering by last-write made them leapfrog every message beside
// them, and the collapsed footer (which shows the last item) flickered
// between whichever one had just ticked.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/status_bar_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late StatusBarService statusBar;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    statusBar = StatusBarService(await SharedPreferences.getInstance());
  });

  List<String> keysOf() => statusBar.items.map((item) => item.key).toList();

  test('items come back in the order their keys were first posted', () {
    statusBar.setMessage(key: 'first', text: 'a');
    statusBar.setMessage(key: 'second', text: 'b');
    statusBar.setProgress(key: 'third', value: 0.1);

    expect(keysOf(), ['first', 'second', 'third']);
  });

  test('updating a message does not move it', () {
    statusBar.setMessage(key: 'first', text: 'a');
    statusBar.setMessage(key: 'second', text: 'b');

    statusBar.setMessage(key: 'first', text: 'a again');

    expect(keysOf(), ['first', 'second']);
    expect(statusBar.itemForKey('first')?.text, 'a again');
  });

  test('a ticking progress bar stays put — the case that regressed', () {
    statusBar.setProgress(key: 'sync', value: 0.1);
    statusBar.setMessage(key: 'note', text: 'posted after the sync started');

    for (final value in [0.2, 0.4, 0.6, 0.8]) {
      statusBar.setProgress(key: 'sync', value: value);
    }

    expect(keysOf(), ['sync', 'note']);
  });

  test('an item keeps its slot when it turns into a progress bar, and back', () {
    statusBar.setMessage(key: 'job', text: 'starting');
    statusBar.setMessage(key: 'other', text: 'b');

    statusBar.setProgress(key: 'job', value: null);
    expect(keysOf(), ['job', 'other']);

    statusBar.setProgress(key: 'job', value: 0.5);
    expect(keysOf(), ['job', 'other']);

    statusBar.setMessage(key: 'job', text: 'done');
    expect(keysOf(), ['job', 'other']);
  });

  test('createdAt is the first post; updatedAt tracks the latest', () {
    statusBar.setMessage(key: 'job', text: 'starting');
    final created = statusBar.itemForKey('job')!.createdAt;

    statusBar.setProgress(key: 'job', value: 0.5);
    final updated = statusBar.itemForKey('job')!;

    expect(updated.createdAt, created);
    expect(updated.updatedAt.isBefore(created), isFalse);
  });

  test('a cleared key that comes back is a new item, and goes last', () {
    statusBar.setMessage(key: 'first', text: 'a');
    statusBar.setMessage(key: 'second', text: 'b');

    statusBar.clear('first');
    statusBar.setMessage(key: 'first', text: 'back');

    expect(keysOf(), ['second', 'first']);
  });
}
