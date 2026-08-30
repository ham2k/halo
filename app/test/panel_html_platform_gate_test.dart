// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The platform gates in front of the panes that host a web view: an
// extension's `html` panel (`panel_content_view.dart`), the operator's Web
// Site pane (`website_panel.dart`), and the Map tab's backend routing
// (`map_panel.dart`).
//
// One gate, three panes, one crash — which is why they are held to the
// contract in the same file. The widgets themselves cannot be merged: their
// sandbox policies come from different trust sources (see website_panel.dart),
// and the Map tab answers the question with a different backend rather than a
// message. So each carries its own copy of the same platform check, and a copy
// is exactly the thing that goes stale without anything noticing.
//
// That check is the only thing standing between a Linux operator and a crash:
// with no web view implementation registered there,
// `InAppWebViewPlatform.instance` is null and building an `InAppWebView`
// throws out of `build()` — an assertion in debug, a `TypeError` in release
// (see docs/quirks.md). Delete the gate and nothing else notices: the suite
// runs on one platform, `flutter analyze` sees a valid widget, and the Linux
// AppImage is only ever built by a tag-triggered release.
//
// `defaultTargetPlatform` is what makes this testable at all —
// `Platform.isLinux` is not overridable, and `flutter test` reports a host
// platform of its own choosing regardless of what it runs on.
//
// The web is the one platform NOT held here. `kIsWeb` is a compile-time
// constant, so its branch is compiled away on the host VM and no override
// reaches it — a web case added here would assert the NATIVE branch while
// reading as coverage of both. A browser test is the only thing that could
// cover it, and one cannot currently be written: a `--platform chrome` test
// that imports panel_content_view.dart hangs at load — bisected, but not
// yet explained; see docs/quirks.md. The gate is real (the `kIsWeb` check at
// `case 'html'`); its coverage is not.
//
// There is no platform implementation under `flutter test` either, so the
// permitted case necessarily throws. That is not an obstacle to testing it:
// the throw IS the observable difference between a gate that diverted and one
// that let the pane through to a real web view.
//
// The Map tab is the third copy, and the one whose failure is quietest: it
// diverts Linux to the OSM backend, which is a real map, so widening its
// webview branch swaps a working map for a blank pane rather than for an error
// message (docs/backlog.md). Its guards are written against
// `defaultTargetPlatform` so that exclusion is a rule a test can hold down.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/services/panel_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/services/windows_webview.dart';
import 'package:ham2k_logger/views/map/mapbox_webview_map_view.dart';
import 'package:ham2k_logger/views/map/osm_map_view.dart';
import 'package:ham2k_logger/views/operation/map_panel.dart';
import 'package:ham2k_logger/views/operation/panel_content_view.dart';
import 'package:ham2k_logger/views/operation/website/website_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_panel_extensions.dart';

/// A Windows probe that answers, and answers no.
///
/// Two things make this the right harness rather than a convenience. The probe
/// caches for the whole session, so "before it answers" only exists while
/// nothing has asked — hence the reset on both sides. And
/// `WindowsWebView.isAvailable()` otherwise short-circuits on
/// `Platform.isWindows`, the HOST, which no override reaches: it would resolve
/// true off Windows and, on a Windows host, spawn a real browser process.
/// Supplying the environment factory bypasses that short-circuit, so the same
/// answer arrives on every machine the suite runs on.
void _failingWindowsProbe() {
  WindowsWebView.debugReset();
  addTearDown(WindowsWebView.debugReset);
  WindowsWebView.debugCreateEnvironment = () async => throw StateError('no WebView2 environment in tests');
}

/// Stands in for a created WebView2 environment, same shell as
/// windows_webview_test.dart's — nothing here calls into the real plugin.
class _FakePlatformWebViewEnvironment extends PlatformWebViewEnvironment {
  _FakePlatformWebViewEnvironment() : super.implementation(const PlatformWebViewEnvironmentCreationParams());
}

/// A Windows probe that answers, and answers yes.
void _succeedingWindowsProbe() {
  WindowsWebView.debugReset();
  addTearDown(WindowsWebView.debugReset);
  WindowsWebView.debugCreateEnvironment =
      () async => WebViewEnvironment.fromPlatform(platform: _FakePlatformWebViewEnvironment());
}

PanelService _websiteService() {
  final service = PanelService(FakePanelExtensions(configs: {
    'website#1': {websiteUrlKey: 'https://example.com'},
  }));
  service.registerNative(const PanelDefinition(
    id: websitePanelId,
    title: 'Web Site',
    source: PanelSource.native,
    multiple: true,
    formFields: [
      {'type': 'field', 'key': websiteUrlKey, 'fieldType': 'text'},
    ],
  ));
  return service;
}

Future<void> _pumpWebsitePanel(WidgetTester tester, PanelService service, {bool dockVisible = true}) async {
  await tester.pumpWidget(TranslationProvider(
    child: MaterialApp(
      home: Scaffold(
        body: DockPaneVisibility(
          visible: dockVisible,
          child: WebsitePanel(panelId: 'website#1', panels: service, autoRefresh: false),
        ),
      ),
    ),
  ));
}

Future<void> _pumpHtmlPanel(WidgetTester tester) async {
  await tester.pumpWidget(
    TranslationProvider(
      child: const MaterialApp(
        home: Scaffold(
          body: PanelContentView(content: PanelContent(kind: 'html', content: '<p>hello</p>')),
        ),
      ),
    ),
  );
}

/// Settings for a Map tab whose routing actually reaches a platform branch.
Future<SettingsService> _mapSettings() async {
  SharedPreferences.setMockInitialValues({});
  return SettingsService(await SharedPreferences.getInstance());
}

Future<void> _pumpMapPanel(WidgetTester tester, SettingsService settings, {bool dockVisible = true}) async {
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        home: Scaffold(
          body: DockPaneVisibility(
            visible: dockVisible,
            child: MapPanel(
              // The operation's grid is what puts a marker on the map: with none
              // at all the panel renders its empty state and the backend routing
              // is never reached.
              operation: Operation(uuid: 'op-map-gate', data: const {'grid': 'FN31pr'}),
              qsos: const [],
              settings: settings,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  /// Runs [body] with the platform overridden.
  ///
  /// `debugDefaultTargetPlatformOverride` must be back to null before the test
  /// body returns — the framework's foundation-invariant check runs right
  /// after, ahead of any tearDown/addTearDown callback — hence try/finally
  /// rather than a shared setUp/tearDown (same reasoning as
  /// window_chrome_service_test.dart).
  ///
  /// The `finally` is doing the other half of the work: a restore written as
  /// the last statement of a body is skipped by a failing expectation, and
  /// every later test in the isolate then runs as this one's platform and
  /// reports a second, unrelated failure that hides which assertion broke.
  Future<void> on(TargetPlatform platform, Future<void> Function() body) async {
    debugDefaultTargetPlatformOverride = platform;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  testWidgets('Linux is diverted before any web view is built', (tester) async {
    await on(TargetPlatform.linux, () async {
      await _pumpHtmlPanel(tester);

      expect(find.text(t.operation.layout.htmlPanelUnsupported), findsOneWidget);
      // The message alone would also appear if the pane had tried and failed.
      // Nothing thrown is what says it never reached a web view at all — which
      // is the crash this gate exists to prevent.
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('a web-view platform is NOT diverted', (tester) async {
    // The counterpart matters as much: a gate that refused everywhere would
    // pass the test above while silently removing HTML panels from macOS,
    // Windows, iOS and Android too.
    await on(TargetPlatform.macOS, () async {
      await _pumpHtmlPanel(tester);

      expect(find.text(t.operation.layout.htmlPanelUnsupported), findsNothing);
      // SOMETHING threw, and that is the whole contract: the pane got as far
      // as constructing a web view, which is what a gate that let this
      // platform through looks like under `flutter test`.
      //
      // Deliberately not a type. The throw comes from inside
      // `flutter_inappwebview`'s own null check on
      // `InAppWebViewPlatform.instance`, so its shape belongs to the
      // dependency rather than to this gate — already an assertion in debug
      // and a `TypeError` in release, and free to become something else on
      // the next bump or re-vendor of the plugin family
      // (packages/flutter_inappwebview_macos_patched/PATCH.md). Pinning the
      // type here goes red on a gate that is perfectly correct.
      expect(tester.takeException(), isNotNull);
    });
  });

  testWidgets('Windows shows nothing until the WebView2 probe has answered', (tester) async {
    // Windows is the branch that cannot be settled from the platform alone: a
    // machine that fails to create a WebView2 environment renders a
    // permanently blank web view, so the pane must stay on the unsupported
    // message until [WindowsWebView] says otherwise. A bare `true` here is
    // the regression this half catches.
    _failingWindowsProbe();

    await on(TargetPlatform.windows, () async {
      await _pumpHtmlPanel(tester);

      // While the probe is out the pane says nothing — no web view, and no
      // verdict either. Asserting "unsupported" here would be the regression:
      // the first probe of a session spawns a browser process and is allowed
      // 30 seconds, and an operator reading a definite refusal for that long
      // closes the pane rather than waiting out an answer that was going to
      // be yes.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(t.operation.layout.htmlPanelUnsupported), findsNothing);
      expect(tester.takeException(), isNull);

      // ASKED, not merely read. `WindowsWebView.resolved` stays null until
      // something calls `isAvailable()`, so a pane that only reads it never
      // leaves the frame above. The transition IS the proof: a pane that
      // never asks has nothing to transition on and sits on the spinner.
      await tester.pump();
      expect(
        WindowsWebView.resolved,
        isNotNull,
        reason: 'the pane has to ask, not just read the cached answer, or a capable '
            'Windows machine sits here until some other pane happens to probe first',
      );
      // The probe said no, so now — and only now — the refusal is earned. A
      // real Windows outcome rather than a harness artefact: an environment
      // that cannot be created is the case WindowsWebView exists to detect.
      expect(find.text(t.operation.layout.htmlPanelUnsupported), findsOneWidget);
    });
  });

  testWidgets('the Web Site pane asks the WebView2 probe too', (tester) async {
    // The Web Site pane carries its own copy of the same probe, so it needs
    // its own copy of the same assertion: a copy is exactly what goes stale.
    _failingWindowsProbe();
    final service = _websiteService();

    await on(TargetPlatform.windows, () async {
      await _pumpWebsitePanel(tester, service);
      await tester.pump();

      expect(WindowsWebView.resolved, isNotNull, reason: 'reading the cached answer without ever asking for it '
          'leaves the pane refusing a web view this machine can host');
      expect(find.text(t.operation.layout.panels.websiteUnsupported), findsOneWidget);
    });
  });

  testWidgets('the Web Site pane refuses Linux through its own probe', (tester) async {
    // Deliberately NOT passing `webviewSupported: false`. That seam is how the
    // refresh-schedule tests avoid a web view, but passing it here would test
    // the seam instead of the probe — and the probe is the Linux guard.
    final service = _websiteService();

    await on(TargetPlatform.linux, () async {
      await _pumpWebsitePanel(tester, service);
      // The config read is async, and `build` checks the URL before the
      // platform: without this the pane is still on "no address yet" and the
      // assertion below would pass or fail for the wrong reason.
      await tester.pump();

      expect(find.text(t.operation.layout.panels.websiteUnsupported), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('the Map tab keeps Linux on the OSM backend', (tester) async {
    // Two things keep Linux off the webview, and this asserts the outcome
    // rather than either one: the branch names macOS and Windows, and
    // `_webviewSupported` is only ever set for those two platforms. Adding
    // Linux to the branch alone leaves this green — and leaves the app
    // correct — because the second exclusion still holds.
    final settings = await _mapSettings();

    await on(TargetPlatform.linux, () async {
      await _pumpMapPanel(tester, settings);

      expect(find.byType(MapboxWebviewMapView), findsNothing,
          reason: 'no web view implementation is registered on Linux, so this branch is a blank pane, not a map');
      expect(find.byType(OsmMapView), findsOneWidget, reason: 'OSM is the real Linux map, not a degraded fallback');
      // Nothing thrown says the routing decided against the web view rather
      // than reaching one and failing.
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('the Map tab routes macOS to the webview backend', (tester) async {
    // The counterpart carries the weight of the test above: an exclusion that
    // caught every desktop platform would satisfy it while taking the map
    // away from macOS and Windows.
    final settings = await _mapSettings();

    await on(TargetPlatform.macOS, () async {
      await _pumpMapPanel(tester, settings);

      expect(find.byType(MapboxWebviewMapView), findsOneWidget);
      expect(find.byType(OsmMapView), findsNothing);
      // As with the html panel above: with no platform implementation under
      // `flutter test`, building a real web view is observable as a throw, and
      // the throw's type belongs to the dependency rather than to this gate.
      expect(tester.takeException(), isNotNull);
    });
  });

  testWidgets('the Map tab routes iOS to the webview backend, not a native SDK', (tester) async {
    // Mobile has no native map SDK to fall back to anymore — a regression
    // that routed iOS/Android through OsmMapView (or dropped them into the
    // desktop `_webviewSupported` branch, which is never set for mobile and
    // would silently do the same) leaves the Map tab without a globe on
    // every phone and tablet.
    final settings = await _mapSettings();

    await on(TargetPlatform.iOS, () async {
      await _pumpMapPanel(tester, settings);

      expect(find.byType(MapboxWebviewMapView), findsOneWidget);
      expect(find.byType(OsmMapView), findsNothing);
      expect(tester.takeException(), isNotNull);
    });
  });

  testWidgets('the Map tab does not spawn WebView2 for a pane hidden in a dock group', (tester) async {
    // HALO-260: a dock group's IndexedStack builds every pane in it up front,
    // so probing from initState spawns the WebView2 browser process for a Map
    // tab nobody has looked at — a plausible trigger for the native crashes
    // Sentry reports there. Deferring the probe to visibility is the fix.
    _failingWindowsProbe();
    final settings = await _mapSettings();

    await on(TargetPlatform.windows, () async {
      await _pumpMapPanel(tester, settings, dockVisible: false);
      await tester.pump();

      expect(WindowsWebView.resolved, isNull,
          reason: 'a pane behind another tab in its dock group must not spawn the WebView2 process');

      // The dock selects this pane's tab — same pane, now on screen.
      await _pumpMapPanel(tester, settings, dockVisible: true);
      await tester.pump();

      expect(WindowsWebView.resolved, isNotNull,
          reason: 'once actually on screen the pane must still ask, or a capable Windows machine never gets its map');
    });
  });

  testWidgets('the Map tab is not stranded on OSM once WebView2 resolves while it was hidden', (tester) async {
    // Regression in the fix above: `initState` still stamps the pessimistic
    // Windows default into `_webviewSupported` while hidden, so the pane must
    // re-ask on reveal even if `WindowsWebView.resolved` is already set —
    // some other pane (Web Site, an extension's html panel, account login)
    // can resolve it first while the Map tab sits behind another tab. Bailing
    // out early just because `resolved != null` leaves that stale `false`
    // in place forever.
    _succeedingWindowsProbe();
    final settings = await _mapSettings();

    await on(TargetPlatform.windows, () async {
      await _pumpMapPanel(tester, settings, dockVisible: false);
      await tester.pump();

      // Someone else resolves availability while this pane is still hidden.
      expect(await WindowsWebView.isAvailable(), isTrue);

      // The dock selects this pane's tab — same pane, now on screen.
      await _pumpMapPanel(tester, settings, dockVisible: true);
      await tester.pump();

      expect(
        find.byType(MapboxWebviewMapView),
        findsOneWidget,
        reason: 'an answer resolved elsewhere must still reach this pane on reveal, or a capable '
            'Windows machine is stuck on OSM for the rest of the session',
      );
      expect(find.byType(OsmMapView), findsNothing);
      // As with the platform-routing tests above: with no platform
      // implementation under `flutter test`, reaching a real web view is
      // observable as a throw from inside `flutter_inappwebview`'s own null
      // check, which belongs to the dependency rather than to this gate.
      expect(tester.takeException(), isNotNull);
    });
  });

  testWidgets('the Web Site pane does not spawn WebView2 for a pane hidden in a dock group', (tester) async {
    // Same trigger and same fix as the Map tab above, for the other real
    // (placeable) pane that probes eagerly.
    _failingWindowsProbe();
    final service = _websiteService();

    await on(TargetPlatform.windows, () async {
      await _pumpWebsitePanel(tester, service, dockVisible: false);
      await tester.pump();

      expect(WindowsWebView.resolved, isNull,
          reason: 'a pane behind another tab in its dock group must not spawn the WebView2 process');

      await _pumpWebsitePanel(tester, service, dockVisible: true);
      await tester.pump();

      expect(
        WindowsWebView.resolved,
        isNotNull,
        reason: 'once actually on screen the pane must still ask, or a capable Windows machine never gets its web view',
      );
    });
  });
}
