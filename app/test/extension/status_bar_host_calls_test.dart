// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The footer is one surface for every extension and the app, bounded as a
// whole — fifty items, fifty notices in a history every notice rewrites to
// disk — and rebuilt on every landing. Only the budget on the bridge keeps one
// extension from evicting the others' items with its own, filling the history,
// or rebuilding the footer with every chunk of a download. Each test is one of
// those, and the trap beside the coalescing: a held write that lands after its
// key was cleared or its extension replaced.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:ham2k_logger/services/extensions/extension_info.dart';
import 'package:ham2k_logger/services/status_bar_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_clock.dart';
import '../support/halo_test_support.dart';

/// The hot-swap path's two collaborators, stood in for: a host whose bundle
/// reload is instant, and a listing that needs no store behind it.
class _ReloadingHost extends FakeExtensionHost {
  @override
  Future<void> reloadBundle(ExtensionBundle bundle, {List<String>? domains, Duration timeout = const Duration(seconds: 10)}) async {}
}

class _DevReloadService extends ExtensionServiceWithFakeHost {
  _DevReloadService(super.host);

  @override
  Future<List<ExtensionInfo>> loadAvailableExtensions({Map<String, dynamic>? index, bool force = false}) async => const [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(ExtensionServiceWithFakeHost, StatusBarService)> harness() async {
    SharedPreferences.setMockInitialValues(const {});
    final statusBar = StatusBarService(await SharedPreferences.getInstance());
    return (
      ExtensionServiceWithFakeHost()
        ..statusBar = statusBar
        ..debugLoadedExtensionKeys = {'a'},
      statusBar,
    );
  }

  /// A call's params as the kernel stamps them for [ns].
  Map<String, dynamic> from(String ns, String key, [Map<String, dynamic> rest = const {}]) => {'ns': ns, 'extensionKey': ns, 'key': key, ...rest};

  test('an extension holds at most eight keys — messages, progress and notices together — and clearing one frees it', () async {
    final (extensions, statusBar) = await harness();
    runOnFakeClock((async) async {
      for (var i = 0; i < 8; i++) {
        await extensions.debugHandleHostCall('statusBarSetMessage', from('a', 'k$i', {'text': 'm$i'}));
      }
      await expectLater(extensions.debugHandleHostCall('statusBarSetMessage', from('a', 'k8', {'text': 'ninth'})), throwsA(isA<ExtensionHostException>()));
      await expectLater(extensions.debugHandleHostCall('statusBarShowNotice', from('a', 'n', {'text': 'ninth'})), throwsA(isA<ExtensionHostException>()));
      // A key it holds is its to rewrite.
      await extensions.debugHandleHostCall('statusBarSetProgress', from('a', 'k0', {'value': 0.5}));
      await extensions.debugHandleHostCall('statusBarClear', from('a', 'k1'));
      await extensions.debugHandleHostCall('statusBarShowNotice', from('a', 'n', {'text': 'eighth'}));
      await expectLater(extensions.debugHandleHostCall('statusBarSetMessage', from('a', 'k8', {'text': 'ninth'})), throwsA(isA<ExtensionHostException>()));
      await extensions.debugHandleHostCall('statusBarDismissNotice', from('a', 'n'));
      await extensions.debugHandleHostCall('statusBarSetMessage', from('a', 'k8', {'text': 'eighth'}));
      // Another extension's keys are its own.
      await extensions.debugHandleHostCall('statusBarSetMessage', from('b', 'k0', {'text': 'b'}));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(statusBar.items.where((item) => item.key.startsWith('a:')).map((item) => item.key), [
        'a:k0',
        'a:k2',
        'a:k3',
        'a:k4',
        'a:k5',
        'a:k6',
        'a:k7',
        'a:k8',
      ]);
      expect(statusBar.itemForKey('a:k0')?.progressValue, 0.5);
      expect(statusBar.itemForKey('b:k0'), isNotNull);
    });
  });

  test('a storm of progress lands once a span, the latest value winning, and a quiet key lands at once', () async {
    final (extensions, statusBar) = await harness();
    var landings = 0;
    statusBar.addListener(() => landings++);
    runOnFakeClock((async) async {
      for (var i = 0; i <= 50; i++) {
        await extensions.debugHandleHostCall('statusBarSetProgress', from('a', 'dl', {'value': i / 100}));
      }
      (double?, int) landed() => (statusBar.itemForKey('a:dl')?.progressValue, landings);
      expect(landed(), (0.0, 1), reason: 'the first lands at once; the rest wait');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(landed(), (0.5, 2), reason: 'then the latest, once');
      await extensions.debugHandleHostCall('statusBarSetProgress', from('a', 'dl', {'value': 0.51}));
      await extensions.debugHandleHostCall('statusBarSetProgress', from('a', 'dl', {'value': 0.52}));
      expect(landed(), (0.5, 2), reason: 'a storm that goes on lands once a span, not again at the edge of the last');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(landed(), (0.52, 3));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await extensions.debugHandleHostCall('statusBarSetProgress', from('a', 'dl', {'value': 0.6}));
      expect(landed(), (0.6, 4), reason: 'quiet for a span, a write lands at once again');
    });
  });

  test('a held write never lands on a key that was cleared, nor for an extension that was replaced', () async {
    final (extensions, statusBar) = await harness();
    runOnFakeClock((async) async {
      Future<void> progress(double value) => extensions.debugHandleHostCall('statusBarSetProgress', from('a', 'dl', {'value': value}));
      await progress(0.1);
      await progress(0.2);
      await extensions.debugHandleHostCall('statusBarClear', from('a', 'dl'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(statusBar.itemForKey('a:dl'), isNull, reason: 'the write held for the flush would bring the cleared item back');
      await progress(0.3);
      await progress(0.4);
      await extensions.restartRuntime();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(statusBar.itemForKey('a:dl'), isNull, reason: "the restart's sweep took the item; the held write would put it back with nobody to finish it");
    });
  });

  test('calls that name no extension share one bucket, which a restart sweeps like any other', () async {
    final (extensions, statusBar) = await harness();
    runOnFakeClock((async) async {
      Future<dynamic> message(Map<String, dynamic> params) => extensions.debugHandleHostCall('showMessage', params);
      await message({'presentation': 'status', 'text': 'one'});
      await message({'presentation': 'status', 'text': 'two'});
      final held = Completer<void>();
      final other = extensions.dialogs.run('b', () => held.future);
      var shown = false;
      // The bucket is no bundle's key, so a sweep by the dying keys alone would leave its waiter to open for a runtime that is gone.
      extensions.dialogs.show('extensions', () async => shown = true);
      await extensions.restartRuntime();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(statusBar.itemForKey('extensions:resultMessage')?.text, 'one', reason: 'the held write would land for a runtime that is gone');
      held.complete();
      await other;
      await Future<void>.delayed(const Duration(milliseconds: 1));
      expect(shown, isFalse);
    });
  });

  test('a malformed call fails at the call, not at the flush, and the writes held beside it still land', () async {
    final (extensions, statusBar) = await harness();
    runOnFakeClock((async) async {
      await extensions.debugHandleHostCall('statusBarSetProgress', from('a', 'dl', {'value': 0.1}));
      // Held for the flush: a write that reads the call's params when it lands has answered the call
      // as success by then, fails in the timer instead, and takes the writes held beside it with it.
      await expectLater(extensions.debugHandleHostCall('statusBarSetProgress', from('a', 'dl', {'value': '0.2'})), throwsA(isA<TypeError>()));
      await expectLater(extensions.debugHandleHostCall('statusBarSetMessage', from('a', 'note', {'title': 7})), throwsA(isA<TypeError>()));
      await expectLater(
        extensions.debugHandleHostCall('showMessage', {'ns': 'a', 'extensionKey': 'a', 'presentation': 'status', 'title': 7}),
        throwsA(isA<TypeError>()),
      );
      await extensions.debugHandleHostCall('statusBarSetMessage', from('a', 'note', {'text': 'ready'}));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect((statusBar.itemForKey('a:dl')?.progressValue, statusBar.itemForKey('a:note')?.text), (0.1, 'ready'));
    });
  });

  test("a hook result's status message is the latest under the extension's key, never overtaken by one held for the flush", () async {
    final (extensions, statusBar) = await harness();
    runOnFakeClock((async) async {
      Future<dynamic> message(String text) =>
          extensions.debugHandleHostCall('showMessage', {'ns': 'a', 'extensionKey': 'a', 'presentation': 'status', 'text': text});
      await message('posting');
      await message('still posting');
      // Landed directly, the hook result's message would be overwritten by the older one when the flush fires.
      await extensions.presentResultMessage({'presentation': 'status', 'text': 'posted'}, ns: 'a');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(statusBar.itemForKey('a:resultMessage')?.text, 'posted');
    });
  });

  test("every string is bounded, a notice's text and its actions' alone to 16,384 characters", () async {
    final (extensions, _) = await harness();
    Future<void> message(Map<String, dynamic> rest) => extensions.debugHandleHostCall('statusBarSetMessage', from('a', 'k', rest));
    Future<void> notice(Map<String, dynamic> rest) => extensions.debugHandleHostCall('statusBarShowNotice', from('a', 'n', rest));
    await message({'title': 'x' * 1024, 'text': 'y' * 1024});
    await expectLater(message({'title': 'x' * 1025}), throwsA(isA<ExtensionHostException>()));
    await expectLater(message({'text': 'x' * 1025}), throwsA(isA<ExtensionHostException>()));
    await notice({
      'text': 'x' * 16384,
      'actions': [
        {'type': 'dialog', 'label': 'More', 'text': 'y' * 16384},
      ],
    });
    await expectLater(notice({'text': 'x' * 16385}), throwsA(isA<ExtensionHostException>()));
    await expectLater(
      notice({
        'text': 'hi',
        'actions': [
          {'type': 'link', 'label': 'x' * 1025, 'url': 'https://example.com'},
        ],
      }),
      throwsA(isA<ExtensionHostException>()),
    );
  });

  test('ten notices a minute, each extension its own', () async {
    final (extensions, statusBar) = await harness();
    runOnFakeClock((async) async {
      Future<void> notice(String ns, String text) => extensions.debugHandleHostCall('statusBarShowNotice', from(ns, 'n', {'text': text}));
      for (var i = 0; i < 10; i++) {
        await notice('a', 'notice $i');
      }
      await expectLater(notice('a', 'eleventh'), throwsA(isA<ExtensionHostException>()));
      expect(statusBar.activeNotices.single.text, 'notice 9', reason: 'one key, re-posted: the budget counts posts, each of which rewrote the history');
      await notice('b', 'theirs');
      await Future<void>.delayed(const Duration(seconds: 61));
      await notice('a', 'again');
      expect(statusBar.activeNotices.map((n) => n.text), ['theirs', 'again']);
    });
  });

  test('a status result message is bounded, admitted and coalesced like any footer write; a dialog message is bounded like a notice', () async {
    final (extensions, statusBar) = await harness();
    Future<dynamic> message(String ns, Map<String, dynamic> rest) => extensions.debugHandleHostCall('showMessage', {'ns': ns, 'extensionKey': ns, ...rest});
    runOnFakeClock((async) async {
      await expectLater(message('a', {'presentation': 'status', 'text': 'x' * 1025}), throwsA(isA<ExtensionHostException>()));
      await expectLater(message('a', {'presentation': 'dialog', 'text': 'x' * 16385}), throwsA(isA<ExtensionHostException>()));
      var landings = 0;
      statusBar.addListener(() => landings++);
      for (var i = 0; i < 20; i++) {
        await message('c', {'presentation': 'status', 'text': 'posted $i'});
      }
      expect((statusBar.itemForKey('c:resultMessage')?.text, landings), ('posted 0', 1));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect((statusBar.itemForKey('c:resultMessage')?.text, landings), ('posted 19', 2));
      for (var i = 0; i < 8; i++) {
        await extensions.debugHandleHostCall('statusBarSetMessage', from('b', 'k$i', {'text': 'm$i'}));
      }
      await expectLater(message('b', {'presentation': 'status', 'text': 'ninth'}), throwsA(isA<ExtensionHostException>()));
    });
  });

  test('a dialog with no navigator to show it is refused, not answered as closed', () async {
    final (extensions, _) = await harness();
    await expectLater(
      extensions.debugHandleHostCall('showMessage', {'ns': 'a', 'extensionKey': 'a', 'presentation': 'dialog', 'text': 'hi'}),
      throwsStateError,
    );
  });

  test('a dev reload drops what the bridge holds for the extension it replaces', () async {
    SharedPreferences.setMockInitialValues(const {});
    final statusBar = StatusBarService(await SharedPreferences.getInstance());
    const info = ExtensionInfo(key: 'a', file: 'a.js', core: false, name: 'A', source: ExtensionSource.dev);
    final extensions = _DevReloadService(_ReloadingHost())
      ..statusBar = statusBar
      ..debugLoadedExtensionKeys = {'a'};
    // The first dev bundle for a key restarts the runtime; the second is the hot swap under test.
    await extensions.applyDevBundle('a', source: 'one', info: info);
    extensions
      ..debugHost = _ReloadingHost()
      ..debugLoadedExtensionKeys = {'a'};
    runOnFakeClock((async) async {
      Future<void> progress(double value) => extensions.debugHandleHostCall('statusBarSetProgress', from('a', 'dl', {'value': value}));
      await progress(0.1);
      await progress(0.2);
      final held = Completer<void>();
      final other = extensions.dialogs.run('b', () => held.future);
      var shown = false;
      extensions.dialogs.show('a', () async => shown = true);
      await extensions.applyDevBundle('a', source: 'two', info: info);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(statusBar.itemForKey('a:dl'), isNull, reason: "the held write would put the old code's progress bar back");
      held.complete();
      await other;
      await Future<void>.delayed(const Duration(milliseconds: 1));
      expect(shown, isFalse, reason: "the old code's dialog, waiting its turn, would open for a runtime that is gone");
    });
  });
}
