// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Every extension's forms and message dialogs open on one surface, and the
// gate on it is all that stands between a loop of `showForm` calls and an
// operator buried under modals with no barrier and no timeout. Each test is a
// mutation of the gate: a second extension's dialog over the first's, a fourth
// over three, a queue without a bound, a loop without a rate — and, through
// the host calls, a form or a message dialog that reaches the screen without
// passing it.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:ham2k_logger/config/navigation.dart';
import 'package:ham2k_logger/services/extensions/extension_dialog_gate.dart';
import 'package:ham2k_logger/services/status_bar_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_clock.dart';
import '../support/halo_test_support.dart';

/// Dialogs the test opens and closes by name: [run] asks the gate for one,
/// [opened] lists them as they open, and each stays open until [close].
class _Surface {
  final gate = ExtensionDialogGate();
  final opened = <String>[];
  final _closers = <String, Completer<String>>{};

  Future<String> run(String ns, String name) => gate.run(ns, () {
    opened.add(name);
    return (_closers[name] = Completer<String>()).future;
  });

  void close(String name) => _closers[name]!.complete(name);
}

void main() {
  test("another extension's dialog waits for the one on screen, in the order asked", () async {
    final s = _Surface();
    final a1 = s.run('a', 'a1'), b1 = s.run('b', 'b1'), c1 = s.run('c', 'c1');
    await pumpEventQueue();
    expect(s.opened, ['a1']);
    s.close('a1');
    await pumpEventQueue();
    expect(s.opened, ['a1', 'b1']);
    s.close('b1');
    await pumpEventQueue();
    expect(s.opened, ['a1', 'b1', 'c1']);
    s.close('c1');
    expect(await Future.wait([a1, b1, c1]), ['a1', 'b1', 'c1']);
  });

  test('an extension nests three of its own, and its fourth is refused until one closes', () async {
    final s = _Surface();
    final open = [for (var i = 1; i <= ExtensionDialogGate.maxOpen; i++) s.run('a', 'a$i')];
    expect(s.opened, ['a1', 'a2', 'a3']);
    expect(() => s.run('a', 'a4'), throwsA(isA<ExtensionHostException>()));
    s.close('a3');
    await open[2];
    final a5 = s.run('a', 'a5');
    expect(s.opened.last, 'a5');
    for (final name in ['a1', 'a2', 'a5']) {
      s.close(name);
    }
    await Future.wait([...open.take(2), a5]);
  });

  test("waiting is bounded per extension, and the next extension's every waiting open runs when the surface frees", () async {
    final s = _Surface();
    final a1 = s.run('a', 'a1');
    final b = [for (var i = 1; i <= ExtensionDialogGate.maxWaiting; i++) s.run('b', 'b$i')];
    expect(() => s.run('b', 'b4'), throwsA(isA<ExtensionHostException>()));
    final c1 = s.run('c', 'c1');
    await pumpEventQueue();
    expect(s.opened, ['a1']);
    s.close('a1');
    await pumpEventQueue();
    // All of b's at once, one over the other, as it would have nested them; c's still waits.
    expect(s.opened, ['a1', 'b1', 'b2', 'b3']);
    for (final name in ['b1', 'b2', 'b3']) {
      s.close(name);
    }
    await pumpEventQueue();
    expect(s.opened.last, 'c1');
    s.close('c1');
    await Future.wait([a1, ...b, c1]);
  });

  test('ten opens a minute, each extension its own', () {
    runOnFakeClock((async) async {
      final s = _Surface();
      for (var i = 0; i < ExtensionDialogGate.maxOpensPerMinute; i++) {
        final open = s.run('a', 'a$i');
        s.close('a$i');
        await open;
      }
      expect(() => s.run('a', 'late'), throwsA(isA<ExtensionHostException>()));
      final b1 = s.run('b', 'b1');
      s.close('b1');
      expect(await b1, 'b1');
      await Future<void>.delayed(const Duration(seconds: 61));
      final again = s.run('a', 'again');
      s.close('again');
      expect(await again, 'again');
    });
  });

  test('an open that throws leaves the surface free', () async {
    final s = _Surface();
    await expectLater(s.gate.run<void>('a', () => throw StateError('no navigator')), throwsStateError);
    final b1 = s.run('b', 'b1');
    expect(s.opened, ['b1']);
    s.close('b1');
    await b1;
  });

  test('the surface handed over counts the woken opens before they resume', () async {
    // Between the hand-off and the woken opens resuming, a call of the next extension's own
    // would otherwise see nothing open and be admitted as a fourth.
    final s = _Surface();
    final a1 = s.run('a', 'a1');
    final b = [for (var i = 1; i <= ExtensionDialogGate.maxWaiting; i++) s.run('b', 'b$i')];
    s.close('a1');
    Future<String>? fourth;
    scheduleMicrotask(() => fourth = Future.sync(() => s.run('b', 'b4')).then((name) => name, onError: (Object _) => 'refused'));
    await pumpEventQueue();
    expect(s.opened, ['a1', 'b1', 'b2', 'b3']);
    expect(await fourth!, 'refused');
    for (final name in ['b1', 'b2', 'b3']) {
      s.close(name);
    }
    await Future.wait([a1, ...b]);
  });

  test('an extension replaced while waiting is refused, and the queue moves on without it', () async {
    final s = _Surface();
    final a1 = s.run('a', 'a1'), b1 = s.run('b', 'b1'), c1 = s.run('c', 'c1');
    final refused = expectLater(b1, throwsA(isA<ExtensionHostException>()));
    s.gate.drop(['b']);
    s.close('a1');
    await pumpEventQueue();
    expect(s.opened, ['a1', 'c1']);
    await refused;
    s.close('c1');
    await Future.wait([a1, c1]);
  });

  test('a dialog nobody awaits is refused at the call, opens when its turn comes, and is dropped without a word', () async {
    final s = _Surface();
    final a1 = s.run('a', 'a1');
    var shown = 0;
    Future<void> open() async => shown++;
    for (var i = 0; i < ExtensionDialogGate.maxWaiting; i++) {
      s.gate.show('b', open);
    }
    expect(() => s.gate.show('b', open), throwsA(isA<ExtensionHostException>()), reason: 'the budget is the call\'s to see, though it never awaits the dialog');
    s.gate.show('c', open);
    s.gate.drop(['c']);
    s.close('a1');
    await pumpEventQueue();
    // Dropped with a word, c's would fail this test as an error nobody handled.
    expect(shown, ExtensionDialogGate.maxWaiting, reason: "b's three opened together; c's, replaced while it waited, never");
    await a1;
  });

  testWidgets('a form and a message dialog go through the gate; a status message does not', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: SizedBox()),
      ),
    );
    SharedPreferences.setMockInitialValues(const {});
    final statusBar = StatusBarService(await SharedPreferences.getInstance());
    final extensions = ExtensionServiceWithFakeHost()..statusBar = statusBar;
    Future<dynamic> message(String ns, String title, {String presentation = 'dialog'}) =>
        extensions.debugHandleHostCall('showMessage', {'ns': ns, 'extensionKey': ns, 'presentation': presentation, 'title': title, 'text': 'body'});
    expect(await message('a', 'A one'), isNull, reason: 'the call answers at once: a hook awaiting it could not wait for the operator');
    expect(await message('a', 'A two'), isNull);
    await tester.pumpAndSettle();
    expect(find.text('A one'), findsOneWidget);
    expect(find.text('A two'), findsOneWidget);
    final form = extensions.debugHandleHostCall('showForm', {
      'ns': 'b',
      'extensionKey': 'b',
      'formId': 'b-form',
      'form': {'title': 'B form', 'elements': <Object>[]},
      'state': <String, Object>{},
    });
    await tester.pumpAndSettle();
    expect(find.text('B form'), findsNothing, reason: "b's form waits for a's dialogs to close");
    expect(await message('b', 'posted', presentation: 'status'), isNull);
    await tester.pump();
    expect(statusBar.itemForKey('b:resultMessage')?.title, 'posted', reason: 'a status message is posted and done, never waits');
    await tester.tap(find.text('Done').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('A two'), findsNothing);
    expect(find.text('B form'), findsNothing, reason: "a's first dialog is still up");
    await tester.tap(find.text('Done').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('B form'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await form, isNull);
  });
}
