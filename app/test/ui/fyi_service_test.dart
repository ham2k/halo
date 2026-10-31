// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The FYI area's message store (docs/design/logging-fields.md § The FYI
// area): keyed posts, which set each message reaches, and what a dismissal
// holds back.

import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart' show MdiIcons;
import 'package:ham2k_logger/services/fyi_service.dart';

import '../support/fake_clock.dart';

FyiMessage message(
  String key, {
  FyiCategory category = FyiCategory.warning,
  FyiPriority priority = FyiPriority.normal,
  String text = 'text',
  String? radio,
  Duration? expiresIn,
}) => FyiMessage(key: key, category: category, priority: priority, icon: MdiIcons.antenna, text: text, radio: radio, expiresIn: expiresIn);

void main() {
  late FyiService fyi;
  late int notified;

  setUp(() {
    fyi = FyiService();
    notified = 0;
    fyi.addListener(() => notified++);
    addTearDown(fyi.dispose);
  });

  List<String> keysFor(String radio) => fyi.messagesFor(radio).map((m) => m.key).toList();

  test("a post replaces the message under its key where it stood, and a set reads its radio's and the station's", () {
    fyi.post(message('swr', radio: 'A'));
    fyi.post(message('storm'));
    fyi.post(message('swr', radio: 'A', text: 'again'));
    fyi.post(message('other', radio: 'B'));
    // The trap: a re-post moving to the end, so a meter ticking under a key
    // shuffles the line every time.
    expect(keysFor('A'), ['swr', 'storm']);
    expect(keysFor('B'), ['storm', 'other']);
    expect(fyi.messageFor('swr')?.text, 'again');
  });

  test('a message restated as it was is not news; one that reads differently is', () {
    fyi.post(message('swr', text: 'SWR 1.7'));
    expect(notified, 1);
    fyi.post(message('swr', text: 'SWR 1.7'));
    expect(notified, 1, reason: 'a meter re-reading the same number must not rebuild the line');
    fyi.post(message('swr', text: 'SWR 1.8'));
    expect(notified, 2);
    fyi.post(message('swr', text: 'SWR 1.8', category: FyiCategory.alert));
    expect(notified, 3, reason: 'a change of category draws differently');
  });

  test('a poster clearing its message leaves nothing behind: the same key posts again at once', () {
    fyi.post(message('swr'));
    fyi.clear('swr');
    expect(fyi.messages, isEmpty);
    expect(fyi.post(message('swr')), isTrue);
    expect(keysFor('A'), ['swr']);
  });

  test("a poster's clear does not end the operator's dismissal", () {
    fyi.post(message('swr'));
    fyi.dismiss('swr');
    fyi.clear('swr');
    // The trap: a condition flapping about its threshold — cleared on a
    // good over, back on the next — nagging through the three minutes.
    expect(fyi.post(message('swr')), isFalse);
  });

  test('a dismissed key stays down for three minutes unless it comes back more severe', () {
    followFakeClock();
    fakeAsync((async) {
      fyi.post(message('swr', category: FyiCategory.warning, text: 'SWR 1.7'));
      fyi.dismiss('swr');
      expect(fyi.messages, isEmpty);
      // The trap: a condition that persists re-posting on every reading,
      // so the operator's dismissal lasts one meter tick.
      expect(
        fyi.post(message('swr', category: FyiCategory.warning, text: 'SWR 1.8')),
        isFalse,
        reason: 'a changed text is the same nag',
      );
      expect(fyi.post(message('swr', category: FyiCategory.info)), isFalse, reason: 'less severe, still the same key');
      async.elapse(const Duration(minutes: 2, seconds: 59));
      expect(fyi.post(message('swr', category: FyiCategory.warning)), isFalse);
      async.elapse(const Duration(seconds: 2));
      expect(fyi.post(message('swr', category: FyiCategory.warning)), isTrue, reason: 'the cooldown is over');
    });
  });

  test('a dismissed warning that turns into an alert shows inside the cooldown', () {
    followFakeClock();
    fakeAsync((async) {
      fyi.post(message('swr', category: FyiCategory.warning));
      fyi.dismiss('swr');
      expect(fyi.post(message('swr', category: FyiCategory.alert)), isTrue, reason: 'an escalation is news the dismissal did not cover');
      expect(fyi.messageFor('swr')?.category, FyiCategory.alert);
      // Dismissing the alert starts a cooldown of its own, at its level.
      fyi.dismiss('swr');
      expect(fyi.post(message('swr', category: FyiCategory.alert)), isFalse);
    });
  });

  test('a message with an expiry takes itself down, and a re-post restarts the clock', () {
    fakeAsync((async) {
      fyi.post(message('kp', expiresIn: const Duration(seconds: 30)));
      async.elapse(const Duration(seconds: 20));
      fyi.post(message('kp', expiresIn: const Duration(seconds: 30)));
      async.elapse(const Duration(seconds: 20));
      expect(fyi.messages, hasLength(1), reason: 'the first expiry was replaced with the message');
      async.elapse(const Duration(seconds: 11));
      expect(fyi.messages, isEmpty);
      expect(fyi.post(message('kp')), isTrue, reason: 'an expiry is not a dismissal');
    });
  });

  test('clearing a message cancels its expiry rather than letting it take down a later post', () {
    fakeAsync((async) {
      fyi.post(message('kp', expiresIn: const Duration(seconds: 10)));
      fyi.clear('kp');
      fyi.post(message('kp'));
      async.elapse(const Duration(seconds: 11));
      expect(fyi.messages, hasLength(1));
    });
  });

  test('looksLike reads the drawn fields only', () {
    final a = FyiMessage(key: 'k', category: FyiCategory.info, icon: MdiIcons.antenna, text: 't', onTap: () {});
    const b = FyiMessage(key: 'k', category: FyiCategory.info, icon: MdiIcons.antenna, text: 't');
    expect(a.looksLike(b), isTrue, reason: 'a fresh closure is not a change the operator can see');
    expect(a.looksLike(FyiMessage(key: 'k', category: FyiCategory.info, icon: MdiIcons.antenna, text: 't', iconColor: Colors.red)), isFalse);
  });

  group('priority', () {
    test('ranks a message above the ones of its category posted before it', () {
      // The line draws a category in the order the service hands it over, so
      // a high-priority alert posted last would otherwise take the last seat.
      fyi.post(message('late', category: FyiCategory.alert, priority: FyiPriority.low));
      fyi.post(message('plain', category: FyiCategory.alert));
      fyi.post(message('urgent', category: FyiCategory.alert, priority: FyiPriority.high));
      fyi.post(message('info', category: FyiCategory.info, priority: FyiPriority.high));

      expect(keysFor('A'), ['urgent', 'info', 'plain', 'late'], reason: 'by priority, then the order first posted');
    });

    test('a re-post that raises the priority is news, one that restates it is not', () {
      fyi.post(message('swr', category: FyiCategory.alert));
      notified = 0;
      fyi.post(message('swr', category: FyiCategory.alert));
      expect(notified, 0);
      fyi.post(message('swr', category: FyiCategory.alert, priority: FyiPriority.high));
      expect(notified, 1);
    });

    test('raising the priority of a dismissed message gets past the cooldown, restating it does not', () {
      followFakeClock();
      fakeAsync((async) {
        fyi.post(message('swr', category: FyiCategory.alert));
        fyi.dismiss('swr');
        async.elapse(const Duration(minutes: 1));

        expect(fyi.post(message('swr', category: FyiCategory.alert)), isFalse);
        expect(
          fyi.post(message('swr', category: FyiCategory.alert, priority: FyiPriority.high)),
          isTrue,
          reason: 'more severe than what was put away',
        );
      });
    });
  });
}
