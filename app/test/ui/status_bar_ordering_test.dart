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

  // The notice stack shows the OLDEST active notice on top. A re-post that
  // went to the back of the queue would hide the notice the operator is
  // reading behind every one posted after it.
  List<String> noticeKeysOf() => statusBar.activeNotices.map((n) => n.key).toList();

  test('a notice re-posted while still up keeps its place in the queue, with the new text', () {
    statusBar.showNotice(key: 'files:a', text: 'a updated');
    statusBar.showNotice(key: 'files:b', text: 'b updated');

    statusBar.showNotice(key: 'files:a', text: 'a updated again');

    expect(noticeKeysOf(), ['files:a', 'files:b']);
    expect(statusBar.activeNotices.first.text, 'a updated again');
  });

  test('a dismissed notice posted again joins the back of the queue', () {
    statusBar.showNotice(key: 'files:a', text: 'a updated');
    statusBar.showNotice(key: 'files:b', text: 'b updated');
    statusBar.dismissNotice('files:a');

    statusBar.showNotice(key: 'files:a', text: 'a updated again');

    expect(noticeKeysOf(), ['files:b', 'files:a']);
    expect(statusBar.history.where((n) => n.key == 'files:a'), hasLength(1), reason: 'the history keeps one entry per key');
  });

  // Queued behind the notices already up, the one the operator asked for
  // would sit out of sight and the asking would look like it did nothing.
  test('a notice raised to the front goes ahead of those already showing, and stays there when re-raised', () {
    statusBar.showNotice(key: 'files:a', text: 'a updated');
    statusBar.showNotice(key: 'files:b', text: 'b updated');

    statusBar.showNotice(key: 'asked', text: 'the whole message', front: true);
    expect(noticeKeysOf(), ['asked', 'files:a', 'files:b']);

    statusBar.showNotice(key: 'files:c', text: 'c updated');
    statusBar.showNotice(key: 'asked', text: 'the whole message', front: true);
    expect(noticeKeysOf(), ['asked', 'files:a', 'files:b', 'files:c']);
  });

  // The cap trimmed by position would take the oldest ACTIVE notice — the one
  // on screen — without dismissing it, and whoever waits for its dismissal
  // would never hear of it.
  test('the history cap drops dismissed notices, never one still showing', () {
    statusBar.showNotice(key: 'on-screen', text: 'still up');
    for (var i = 0; i < 80; i++) {
      statusBar.showNotice(key: 'burst:$i', text: 'file $i');
      statusBar.dismissNotice('burst:$i');
    }

    expect(noticeKeysOf(), ['on-screen']);
    expect(statusBar.history, hasLength(50), reason: 'the cap still holds');
    expect(statusBar.history.first.key, 'burst:79', reason: 'the newest dismissed ones are kept');
  });
}
