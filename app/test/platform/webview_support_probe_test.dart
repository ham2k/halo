// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A dock group's `IndexedStack` builds every pane in it up front (see
// dock_layout.dart), so a webview-backed pane mounted HIDDEN must not build
// its real `InAppWebView` just because `WindowsWebView.resolved` happens to
// already be cached from an earlier probe this session — that races every
// other webview-backed pane in the same group doing the same on the same
// frame, which is the Intel-driver concurrent-GPU-surface-init crash class
// (flutter/flutter#187747; HALO-290/HALO-NEXT-3).

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/services/windows_webview.dart';
import 'package:ham2k_logger/views/map/webview_support_probe.dart';

/// Stands in for a created WebView2 environment, same as
/// windows_webview_test.dart's own private fake — nothing here calls into
/// the plugin's method channel, so an unimplemented shell is enough to prove
/// [WindowsWebView.resolved] gets cached.
class _FakePlatformWebViewEnvironment extends PlatformWebViewEnvironment {
  _FakePlatformWebViewEnvironment() : super.implementation(const PlatformWebViewEnvironmentCreationParams());
}

WebViewEnvironment _fakeEnvironment() => WebViewEnvironment.fromPlatform(platform: _FakePlatformWebViewEnvironment());

class _Harness extends StatefulWidget {
  const _Harness();

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> with WebviewSupportProbe<_Harness> {
  @override
  void initState() {
    super.initState();
    initWebviewSupportProbe();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    maybeProbeWebviewSupport();
  }

  @override
  Widget build(BuildContext context) => Text(webviewSupported ? 'supported' : 'not supported', textDirection: TextDirection.ltr);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => '/tmp',
    );
  });

  tearDown(WindowsWebView.debugReset);

  // debugDefaultTargetPlatformOverride is reset in a `finally`, not
  // `addTearDown`: the binding asserts every debug foundation var is back to
  // null before the next test runs, and that check fires before an
  // `addTearDown` callback would (same reason activities_map_toggle_test.dart
  // does this).

  testWidgets('a pane mounted hidden in a dock group does not build the real webview from a cached answer', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      WindowsWebView.debugCreateEnvironment = () async => _fakeEnvironment();
      // Warm the cache, as an earlier-opened pane in the same session would.
      expect(await WindowsWebView.isAvailable(), isTrue);

      await tester.pumpWidget(const MaterialApp(home: DockPaneVisibility(visible: false, child: _Harness())));
      await tester.pump();

      expect(
        find.text('not supported'),
        findsOneWidget,
        reason:
            'a hidden pane must not read the cached answer — that is what builds the real InAppWebView '
            'and races every other webview-backed pane in the same dock group',
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('the same pane picks up the cached answer once it becomes visible', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      WindowsWebView.debugCreateEnvironment = () async => _fakeEnvironment();
      expect(await WindowsWebView.isAvailable(), isTrue);

      await tester.pumpWidget(const MaterialApp(home: DockPaneVisibility(visible: false, child: _Harness())));
      await tester.pump();
      expect(find.text('not supported'), findsOneWidget);

      await tester.pumpWidget(const MaterialApp(home: DockPaneVisibility(visible: true, child: _Harness())));
      await tester.pump();

      expect(find.text('supported'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('a pane mounted visible with an already-cached answer is not held back', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      WindowsWebView.debugCreateEnvironment = () async => _fakeEnvironment();
      expect(await WindowsWebView.isAvailable(), isTrue);

      await tester.pumpWidget(const MaterialApp(home: _Harness()));
      await tester.pump();

      expect(
        find.text('supported'),
        findsOneWidget,
        reason:
            'outside a dock (or already selected within one) the cached answer must still apply '
            'immediately — this gate is about hidden panes, not about delaying every pane',
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
