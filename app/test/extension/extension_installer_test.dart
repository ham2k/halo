// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// ExtensionInstaller: the queue installs share and the footer item each one
// posts. The rules that matter are the ones a row and the footer both read —
// an install is one item from first byte to "Installed", a job that ends any
// other way leaves nothing behind, and no two installs write at once.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/services/extension_installer.dart';
import 'package:ham2k_logger/services/status_bar_service.dart';

void main() {
  late StatusBarService statusBar;
  late ExtensionInstaller installer;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    statusBar = StatusBarService(await SharedPreferences.getInstance());
    installer = ExtensionInstaller(statusBar: statusBar);
  });

  StatusBarItem? itemFor(String key) => statusBar.itemForKey(ExtensionInstaller.progressKey(key));

  test('a second install waits for the first to finish writing', () async {
    // Each install restarts the runtime. Written while the first one's
    // restart is in flight, the second bundle lands in a store the new
    // generation has already read, and the operator is told it installed
    // while nothing loads it.
    final first = Completer<void>();
    final order = <String>[];
    final a = installer.commit('a', 'A', () async {
      order.add('a:start');
      await first.future;
      order.add('a:end');
    });
    final b = installer.commit('b', 'B', () async => order.add('b:start'));
    await pumpEventQueue();
    expect(order, ['a:start']);
    // Its row and the footer say why nothing is happening yet.
    expect(itemFor('b')?.text, 'Waiting to install…');
    expect(installer.isActive('b'), isTrue);

    first.complete();
    await Future.wait([a, b]);
    expect(order, ['a:start', 'a:end', 'b:start']);
  });

  test('a failed install does not hold up the ones behind it', () async {
    // The queue is a chain of futures; a link that throws without completing
    // its own would stall every install after it for the rest of the session.
    final failed = installer.commit('a', 'A', () async => throw StateError('disk full'));
    final next = installer.commit('b', 'B', () async {});
    await expectLater(failed, throwsStateError);
    await next;
    expect(itemFor('b')?.progressValue, 1.0);
  });

  test('a finished install says so, and a job that ends any other way leaves nothing behind', () async {
    await installer.run('done', () => installer.commit('done', 'Done One', () async {}));
    expect(itemFor('done')?.text, 'Installed Done One');
    // Completed, so the footer takes it down on its own after the usual delay.
    expect(itemFor('done')?.progressValue, 1.0);
    expect(installer.isActive('done'), isFalse);

    // A download the operator then declined on the consent screen: a bar left
    // at 40% would sit in the footer with nothing ever to move it.
    await installer.run('declined', () async {
      installer.downloading('declined', 'Declined', 0.4);
      expect(installer.isActive('declined'), isTrue);
    });
    expect(itemFor('declined'), isNull);
    expect(installer.isActive('declined'), isFalse);
  });

  test('a download never reads as finished before the install has run', () async {
    // A progress item at 1.0 is a completion and dismisses itself — a
    // download reaching its last byte would otherwise vanish from the footer
    // and the row while the install it feeds has not started.
    installer.downloading('a', 'A', 1.0);
    expect(itemFor('a')!.progressValue, lessThan(1.0));
    // Unknown length is indeterminate, not zero.
    installer.downloading('b', 'B', null);
    expect(itemFor('b')!.isIndeterminateProgress, isTrue);
  });

  test('a failed install takes its bar down before the caller says so', () async {
    // The caller follows a failure with a "did not finish" dialog; a footer
    // still reading "Installing…" behind it contradicts the dialog.
    await expectLater(installer.commit('a', 'A', () async => throw StateError('disk full')), throwsStateError);
    expect(itemFor('a'), isNull);
  });

  test('waiting on the consent screen is a message, not a bar', () async {
    // A bar — even an indeterminate one — says the app is busy, while it is
    // the operator the install is waiting for.
    installer.awaitingApproval('a', 'A');
    expect(itemFor('a')?.text, 'Waiting for your approval…');
    expect(itemFor('a')?.isProgress, isFalse);
  });
}
