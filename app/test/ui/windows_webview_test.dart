// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Windows webview gate. Nothing here can run against a real WebView2
// runtime — the suite runs on macOS and Linux — so these tests stand in for
// the one machine we can't reach: a Windows install whose exe sits somewhere
// the process may not write, where the runtime is present and registered but
// the environment still refuses to be created.
//
// That is the case the operator reported and the reason this class exists.
// Everything below is about what must happen when creation fails, because
// what happens when it succeeds is what every developer machine already
// shows us.

import 'dart:async';
import 'dart:io' show Directory;

import 'package:flutter/services.dart' show MethodChannel, PlatformException;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/app_storage.dart' show windowsDataFolderName;
import 'package:ham2k_logger/services/windows_webview.dart';
import 'package:path/path.dart' as p;

/// Stands in for a created WebView2 environment. The plugin's real one needs
/// a Windows method channel; nothing here calls into it, so an unimplemented
/// shell is enough to prove the reference is kept and handed out.
class _FakePlatformWebViewEnvironment extends PlatformWebViewEnvironment {
  _FakePlatformWebViewEnvironment() : super.implementation(const PlatformWebViewEnvironmentCreationParams());
}

WebViewEnvironment _fakeEnvironment() => WebViewEnvironment.fromPlatform(platform: _FakePlatformWebViewEnvironment());

void main() {
  // The %LOCALAPPDATA%-less fallback asks path_provider where the app's own
  // files are, and there is no plugin behind that channel in a test.
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => Directory.systemTemp.path,
    );
  });

  tearDown(WindowsWebView.debugReset);

  test('a failure to create the environment resolves to unavailable, not an escaping exception', () async {
    // The plugin calls initialize() fire-and-forget from initState, so an
    // exception that gets this far reaches PlatformDispatcher.onError as a
    // fatal report and the view stays blank. Rethrowing here, or letting the
    // future complete with an error, puts that bug straight back.
    WindowsWebView.debugCreateEnvironment = () async => throw PlatformException(code: '0', message: 'Cannot create WebViewEnvironment: Access is denied.');

    expect(await WindowsWebView.isAvailable(), isFalse);
    expect(WindowsWebView.resolved, isFalse);
    // Null, so a caller that builds an InAppWebView anyway doesn't hand the
    // plugin a half-made environment.
    expect(WindowsWebView.environment, isNull);
  });

  test('a created environment is the one callers are given', () async {
    final created = _fakeEnvironment();
    WindowsWebView.debugCreateEnvironment = () async => created;

    expect(await WindowsWebView.isAvailable(), isTrue);
    // Identity, not just non-null: an InAppWebView built from a *different*
    // environment than the one that was created is the null-user-data-folder
    // bug again, wearing a passing test.
    expect(WindowsWebView.environment, same(created));
  });

  test('the environment is created once, however many views ask for it', () async {
    // WebView2 shares one browser process between webviews and fails a second
    // environment whose options don't match the running one
    // (ERROR_INVALID_STATE) — so the map panel and the account login asking
    // independently must not each make one.
    var creations = 0;
    WindowsWebView.debugCreateEnvironment = () async {
      creations++;
      return _fakeEnvironment();
    };

    await Future.wait([WindowsWebView.isAvailable(), WindowsWebView.isAvailable()]);
    await WindowsWebView.isAvailable();

    expect(creations, 1);
  });

  test('a browser process that never comes up is a failure, not a hang', () async {
    // Without a deadline the memoized future never settles: every later
    // caller awaits the same dead one, the Connect button does nothing for
    // the rest of the session, and nothing is logged, reported or shown —
    // strictly worse than the blank pane this class replaced.
    WindowsWebView.debugCreateEnvironment = () => Completer<WebViewEnvironment>().future;

    expect(await WindowsWebView.isAvailable(), isFalse);
  }, timeout: const Timeout(Duration(minutes: 2)));

  group('the user data folder', () {
    // This path IS the fix. WebView2's own default lands next to the exe and
    // fails where that isn't writable, so a silent regression here — to the
    // default, or to the Documents folder OneDrive syncs — brings the whole
    // bug back with every test above still green.
    test('sits under %LOCALAPPDATA%, per edition', () async {
      final path = await WindowsWebView.userDataFolderPath(environment: {'LOCALAPPDATA': r'C:\Users\n0dev\AppData\Local'});

      expect(path, p.join(r'C:\Users\n0dev\AppData\Local', windowsDataFolderName, kWebView2DataDirName));
    });

    test("an unset %LOCALAPPDATA% falls back to the app's own directory, never to the plugin's default", () async {
      // Absent and empty both mean "not set" — an empty value would otherwise
      // build a relative path, which WebView2 resolves against the exe: the
      // very folder this exists to avoid.
      for (final environment in [
        <String, String>{},
        {'LOCALAPPDATA': ''},
      ]) {
        final path = await WindowsWebView.userDataFolderPath(environment: environment);

        expect(p.basename(path), kWebView2DataDirName);
        expect(p.isAbsolute(path), isTrue, reason: 'a relative folder resolves against the exe');
      }
    });
  });

  test('the environment disables the compositor, not GPU rendering outright', () {
    final settings = WindowsWebView.debugEnvironmentSettings(r'C:\Users\n0dev\AppData\Local\Ham2K\WebView2');

    expect(settings.additionalBrowserArguments, '--disable-gpu-compositing');
  });

  test('a failure is remembered, so a blank map never becomes a retry loop', () async {
    var creations = 0;
    WindowsWebView.debugCreateEnvironment = () async {
      creations++;
      throw PlatformException(code: '0', message: 'Cannot create WebViewEnvironment: Access is denied.');
    };

    expect(await WindowsWebView.isAvailable(), isFalse);
    expect(await WindowsWebView.isAvailable(), isFalse);

    expect(creations, 1);
  });
}
