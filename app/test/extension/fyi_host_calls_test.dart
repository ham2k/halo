// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The FYI line is one surface for the app's own posters and every extension,
// with room for a few words each. Only the budget on the bridge keeps one
// extension from crowding the keyer line and the No Band pill out, or from
// changing the line faster than the operator reads it; and every extension
// message is the operator's to dismiss, whatever the call says. Each test is
// one of those, and the trap beside the coalescing: a held post that lands
// after its key was cleared or its extension replaced.

import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:halo_widgets/halo_widgets.dart' show MdiIcons;
import 'package:ham2k_logger/services/fyi_service.dart';

import '../support/fake_clock.dart';
import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  (ExtensionServiceWithFakeHost, FyiService) harness() {
    final fyi = FyiService();
    return (
      ExtensionServiceWithFakeHost()
        ..fyi = fyi
        ..debugLoadedExtensionKeys = {'a'},
      fyi,
    );
  }

  /// A call's params as the kernel stamps them for [ns].
  Map<String, dynamic> from(String ns, String key, [Map<String, dynamic> rest = const {}]) => {'ns': ns, 'extensionKey': ns, 'key': key, ...rest};

  /// A post of the least a call must say, plus [rest].
  Future<void> post(ExtensionServiceWithFakeHost extensions, String ns, String key, [Map<String, dynamic> rest = const {}]) =>
      extensions.debugHandleHostCall('fyiPost', from(ns, key, {'category': 'info', 'text': 't', ...rest}));

  test("a post is the message under the extension's key, every field read at the call, its action the tap's", () async {
    final (extensions, fyi) = harness();
    var opened = <String>[];
    extensions.onOpenAccount = (key, {subkey}) => opened.add('$key/$subkey');
    await post(extensions, 'a', 'kp', {
      'category': 'warning',
      'priority': 'high',
      'icon': 'antenna',
      'iconColor': '#FF8800',
      'text': 'Kp **7**',
      'textColor': '#80FF8800',
      'radio': 'B',
      'action': {'type': 'account', 'label': 'Open', 'key': 'wx', 'subkey': 'noaa'},
    });
    final message = fyi.messageFor('ext:a:kp')!;
    expect(
      (message.category, message.priority, message.icon, message.iconColor, message.text, message.textColor, message.radio),
      (FyiCategory.warning, FyiPriority.high, MdiIcons.antenna, const Color(0xFFFF8800), 'Kp **7**', const Color(0x80FF8800), 'B'),
    );
    message.onTap!();
    expect(opened, ['wx/noaa']);
  });

  test("every extension message is the operator's to dismiss, whatever the call says; what the call leaves out has its default", () async {
    final (extensions, fyi) = harness();
    await post(extensions, 'a', 'k', {'dismissible': false});
    final message = fyi.messageFor('ext:a:k')!;
    expect(
      (message.dismissible, message.priority, message.radio, message.icon, message.onTap, message.expiresIn),
      (true, FyiPriority.normal, null, MdiIcons.puzzle, null, null),
    );
  });

  test('a message with an expiry goes on its own', () async {
    final (extensions, fyi) = harness();
    runOnFakeClock((async) async {
      await post(extensions, 'a', 'k', {'expiresInSeconds': 60});
      await Future<void>.delayed(const Duration(seconds: 59));
      expect(fyi.messageFor('ext:a:k'), isNotNull);
      await Future<void>.delayed(const Duration(seconds: 1));
      expect(fyi.messageFor('ext:a:k'), isNull);
    });
  });

  test("an extension holds at most four messages; one cleared, expired or dismissed frees its key, and another extension's are its own", () async {
    final (extensions, fyi) = harness();
    runOnFakeClock((async) async {
      for (var i = 0; i < 4; i++) {
        await post(extensions, 'a', 'k$i');
      }
      await expectLater(post(extensions, 'a', 'k4'), throwsA(isA<ExtensionHostException>()));
      // Refused for the category, not the cap: the call is read whole before the budget is consulted.
      await expectLater(
        post(extensions, 'a', 'k4', {'category': 'urgent'}),
        throwsA(isA<ExtensionHostException>().having((e) => e.message, 'message', contains('category'))),
      );
      // A key it holds is its to rewrite.
      await post(extensions, 'a', 'k0', {'text': 'again'});
      await extensions.debugHandleHostCall('fyiClear', from('a', 'k1'));
      await post(extensions, 'a', 'k4');
      await post(extensions, 'b', 'k0');
      await Future<void>.delayed(const Duration(seconds: 1));
      expect(fyi.messages.where((m) => m.key.startsWith('ext:a:')).map((m) => m.key), ['ext:a:k0', 'ext:a:k2', 'ext:a:k3', 'ext:a:k4']);
      expect(fyi.messageFor('ext:a:k0')?.text, 'again');
      expect(fyi.messageFor('ext:b:k0'), isNotNull);
      // Counted from the line itself: what the operator put away is not held against the extension.
      fyi.dismiss('ext:a:k2');
      await post(extensions, 'a', 'k5');
      await Future<void>.delayed(const Duration(seconds: 1));
      expect(fyi.messages.where((m) => m.key.startsWith('ext:a:')).map((m) => m.key), ['ext:a:k0', 'ext:a:k3', 'ext:a:k4', 'ext:a:k5']);
    });
  });

  test("an extension named after one of the app's own posters reaches none of the app's messages", () async {
    final (extensions, fyi) = harness();
    fyi.post(const FyiMessage(key: 'band:A', category: FyiCategory.alert, icon: MdiIcons.puzzle, text: 'No Band'));
    await extensions.debugHandleHostCall('fyiClear', from('band', 'A'));
    await post(extensions, 'band', 'A', {'text': 'mine'});
    // Without the prefix, 'band:A' is this extension's key: its clear takes the pill down and its post rewrites it.
    expect(fyi.messageFor('band:A')?.text, 'No Band');
    expect(fyi.messageFor('ext:band:A')?.text, 'mine');
  });

  test('a storm of posts lands once a span, the latest winning, and a quiet key lands at once', () async {
    final (extensions, fyi) = harness();
    var landings = 0;
    fyi.addListener(() => landings++);
    runOnFakeClock((async) async {
      for (var i = 0; i <= 50; i++) {
        await post(extensions, 'a', 'swr', {'text': 'SWR 1.$i'});
      }
      (String?, int) landed() => (fyi.messageFor('ext:a:swr')?.text, landings);
      expect(landed(), ('SWR 1.0', 1), reason: 'the first lands at once; the rest wait');
      await Future<void>.delayed(const Duration(seconds: 1));
      expect(landed(), ('SWR 1.50', 2), reason: 'then the latest, once a second');
      await post(extensions, 'a', 'swr', {'text': 'SWR 1.51'});
      expect(landed(), ('SWR 1.50', 2), reason: 'a storm that goes on lands once a span, not again at the edge of the last');
      await Future<void>.delayed(const Duration(seconds: 1));
      expect(landed(), ('SWR 1.51', 3));
      // A span's closing flush and a wait that ends on the same tick run in the order they were set, the wait
      // first when it was set before the flush was; one span at a time keeps the test on the right side of it.
      await Future<void>.delayed(const Duration(seconds: 1));
      await post(extensions, 'a', 'swr', {'text': 'SWR 1.6'});
      expect(landed(), ('SWR 1.6', 4), reason: 'quiet for a span, a post lands at once again');
    });
  });

  test('a held post never lands on a key that was cleared, nor for an extension that was replaced', () async {
    final (extensions, fyi) = harness();
    runOnFakeClock((async) async {
      await post(extensions, 'a', 'k', {'text': 'one'});
      await post(extensions, 'a', 'k', {'text': 'two'});
      await extensions.debugHandleHostCall('fyiClear', from('a', 'k'));
      expect(fyi.messageFor('ext:a:k'), isNull, reason: 'a clear lands at once, mid-span, not with the flush');
      await Future<void>.delayed(const Duration(seconds: 2));
      expect(fyi.messageFor('ext:a:k'), isNull, reason: 'the post held for the flush would bring the cleared message back');
      await post(extensions, 'a', 'k', {'text': 'three'});
      await post(extensions, 'a', 'k', {'text': 'four'});
      await extensions.restartRuntime();
      await Future<void>.delayed(const Duration(seconds: 2));
      expect(fyi.messageFor('ext:a:k'), isNull, reason: "the restart's sweep took the message; the held post would put it back with nobody to clear it");
    });
  });

  test("every string is bounded, the text to one line of 256 characters, the action's to 1,024; each field is checked at the call", () async {
    final (extensions, fyi) = harness();
    Future<void> refused(Map<String, dynamic> rest) => expectLater(post(extensions, 'a', 'k', rest), throwsA(isA<ExtensionHostException>()));
    await post(extensions, 'a', 'ok', {
      'text': 'x' * 256,
      'icon': 'y' * 1024,
      'action': {'type': 'dialog', 'label': 'More', 'text': 'z' * 1024},
    });
    await refused({'text': 'x' * 257});
    await refused({'text': 'two\nlines'});
    await refused({'text': 'two\rlines'});
    await refused({'text': 'two\u2028lines'});
    await refused({'icon': 'y' * 1025});
    await refused({
      'action': {'type': 'dialog', 'label': 'More', 'text': 'z' * 1025},
    });
    await refused({'category': 'urgent'});
    await refused({'priority': 'top'});
    await refused({'radio': 'C'});
    await refused({'expiresInSeconds': 0});
    await refused({'expiresInSeconds': 86401});
    await refused({'iconColor': 'red'});
    await refused({'textColor': '#FFF'});
    await refused({
      'action': {'type': 'link', 'label': 'Open'},
    });
    await refused({
      'action': {'type': 'callback', 'label': 'Run'},
    });
    // Read where the call is, not in the flush: landed from a timer, a malformed post would fail where nothing awaits it.
    await expectLater(post(extensions, 'a', 'k', {'text': 7}), throwsA(isA<TypeError>()));
    expect(fyi.messages.map((m) => m.key), ['ext:a:ok'], reason: 'nothing refused reached the line');
  });
}
