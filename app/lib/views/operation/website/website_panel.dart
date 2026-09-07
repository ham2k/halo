// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A pane showing a web page the operator chose.
//
// This is a DIFFERENT widget from the sandboxed view an extension's `html`
// panel gets (`panel_content_view.dart`), and deliberately so. That one
// forbids scripts, network and navigation because the document comes from an
// extension author. Here the URL comes from the operator, typed into this
// pane's own settings, so the trust source is different and the policy is
// too. The two must not be merged: relaxing the sandbox would hand every
// extension what only the operator is meant to have.
//
// What this pane does NOT relax:
//   - https only (website_url.dart) — scripts are on, so `javascript:` and
//     `data:` are script execution;
//   - a link the OPERATOR clicks leaves for the OS browser, rather than
//     turning the pane into a browser nobody can see the address bar of;
//     one nobody clicked is dropped instead, because raising a browser
//     without an interaction is a hijack;
//   - permission requests are denied outright, so a page cannot raise a
//     location prompt wearing HaLo's name.
//
// Cookies ARE shared with the rest of the app's web views, including account
// logins. Isolating them is not available uniformly — Android's `incognito`
// clears every cookie in the process — and sharing is what lets the pane stay
// signed in to the site it shows, which is usually the point.

import 'dart:async';
import 'dart:io' as io;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'package:halo_i18n/halo_i18n.dart';
import '../../../services/error_reporting_service.dart';
import '../../../services/website_panel_error.dart';
import '../../../services/link_opener.dart';
import '../../../services/panel_service.dart';
import '../../../services/windows_webview.dart';
import 'website_url.dart';

/// The panel id the view registers this pane under, and the descriptor half
/// of every placement id (`website#1`). Shared rather than spelled twice: the
/// dock matches placements against it, and a rename reaching only the
/// registration would route every pane to the missing-panel fallback.
const String websitePanelId = 'website';

const String websiteUrlKey = 'url';
const String websiteRefreshKey = 'refreshMinutes';
const String websiteTitleKey = 'title';

class WebsitePanel extends StatefulWidget {
  /// The PLACEMENT's id (`website#1`), never the descriptor's — it is the key
  /// this pane's config is stored under, so two panes handed the same one
  /// would show the same site.
  final String panelId;

  final PanelService panels;

  /// Names the tab after the operator's title, or the site's host.
  final ValueChanged<String?>? onTitle;

  /// Whether a QSO is being entered right now. A callback rather than a
  /// value: the pane only asks when a refresh comes due, so a draft changing
  /// costs it nothing. Null where the view cannot say.
  final bool Function()? isEnteringQso;

  /// Whether the refresh timer may run at all. Defaults off under
  /// `flutter test`, where a pending timer fails whatever test runs next. A
  /// parameter rather than an env check inside the State, so the lifecycle
  /// test can turn it ON — a timer nothing ever starts is one no test can
  /// hold to its contract.
  final bool? autoRefresh;

  /// Called whenever the pane reloads its page.
  ///
  /// A test seam, and the only one that makes the schedule observable: there
  /// is no platform web view under `flutter test`, so the controller is null
  /// and the reload itself leaves no trace. Asserting "a timer is pending"
  /// instead would pass for a schedule that reloads at the wrong moment,
  /// which is precisely the bug worth catching here.
  final VoidCallback? onReload;

  /// The clock the refresh deadline is measured against, injectable the way
  /// [CatService.now] is. The real clock, not the app's: what this measures is
  /// a wait whose remainder becomes a Timer duration, which developer time
  /// travel must not jump (docs/design/time.md). A deadline read from a clock
  /// call directly would also be untestable — `tester.pump(duration)` advances
  /// timers, not clocks — and the deadline is the whole design here.
  final DateTime Function() now;

  /// Overrides the platform probe. A test seam: `InAppWebView` asserts that a
  /// platform implementation is registered, and under `flutter test` none is,
  /// so a pane that believes it can host one cannot be built at all. Pass
  /// false to exercise everything around the web view.
  final bool? webviewSupported;

  const WebsitePanel({
    super.key,
    required this.panelId,
    required this.panels,
    this.onTitle,
    this.isEnteringQso,
    this.autoRefresh,
    this.onReload,
    this.webviewSupported,
    this.now = realNowUtc,
  });

  static bool get _refreshesByDefault => kIsWeb || !io.Platform.environment.containsKey('FLUTTER_TEST');

  @override
  State<WebsitePanel> createState() => _WebsitePanelState();
}

class _WebsitePanelState extends State<WebsitePanel> with WidgetsBindingObserver {
  InAppWebViewController? _controller;
  Timer? _timer;

  /// Whether a load THIS pane started is still settling, so the redirects it
  /// goes through are recognizable as ours rather than as a hijack.
  bool _loadInFlight = true;

  /// When the page last finished loading. The refresh deadline is measured
  /// from this rather than from when the timer was armed — see [_syncRefresh].
  DateTime? _loadedAt;

  late final bool _mayRefresh = widget.autoRefresh ?? WebsitePanel._refreshesByDefault;

  /// True outside a dock, where a built pane is a visible one.
  bool _dockVisible = true;

  /// False only while every view is hidden. Not `inactive`: on desktop that
  /// means the window merely lost focus while still on screen.
  bool _appVisible = true;

  /// Whether this platform can host a web view at all. Asking is the point:
  /// `WindowsWebView.resolved` is null until something calls `isAvailable()`,
  /// so a pane that only reads it says "unsupported" on a perfectly capable
  /// Windows machine for as long as nothing else in the session happens to
  /// ask. Starts [WebviewSupport.pending] rather than guessing — see
  /// [probeWebviewSupport].
  WebviewSupport _webviewSupported = WebviewSupport.pending;

  /// Set once [_maybeProbeWebview] has kicked off (or skipped) the probe —
  /// a pane that flips visible more than once doesn't ask again.
  bool _probed = false;

  Map<String, dynamic> _config = const {};
  int _configRevision = 0;
  int _refreshRequest = 0;

  /// The last problem the operator's URL had, or null. Shown in the pane
  /// rather than swallowed: they typed it and are looking at it, so silence
  /// reads as the pane being broken.
  WebsiteUrlProblem? _urlProblem;

  /// A page that would not load, shown over the pane until the next one does.
  /// Never a status-bar notice: a pane on a timer would raise one on every
  /// offline refresh.
  String? _loadError;

  @override
  void initState() {
    super.initState();
    final state = WidgetsBinding.instance.lifecycleState;
    _appVisible = state == null || _visibleIn(state);
    WidgetsBinding.instance.addObserver(this);
    widget.panels.addListener(_onCatalogChanged);
    _configRevision = widget.panels.configRevision(widget.panelId);
    _refreshRequest = widget.panels.refreshRequest(widget.panelId);
    // Stamped at mount, not left null: the initial navigation starts now, and
    // a null base makes every visibility flip re-measure the deadline from
    // the moment of the flip — which is exactly the always-stale bug the
    // deadline exists to avoid.
    _loadedAt = widget.now();
    // The test seam is decided now, not deferred with the real probe below:
    // it is synchronous and has no browser process to spawn.
    final forced = widget.webviewSupported;
    if (forced != null) {
      _webviewSupported = forced ? WebviewSupport.yes : WebviewSupport.no;
      _probed = true;
    }
    unawaited(_loadConfig());
  }

  /// Kicks off the real probe once this pane is actually on screen, not
  /// merely mounted — a dock group's `IndexedStack` builds every pane in it
  /// up front, and probing from `initState` would spawn the WebView2 browser
  /// process for a pane nobody has looked at yet (see map_panel.dart's
  /// identical gate). Outside a dock, `DockPaneVisibility.of` answers true
  /// immediately, so this fires on the same frame `initState` used to.
  void _maybeProbeWebview() {
    if (_probed || !_dockVisible) return;
    _probed = true;
    _webviewSupported = probeWebviewSupport((ok) {
      if (mounted) setState(() => _webviewSupported = ok ? WebviewSupport.yes : WebviewSupport.no);
    });
  }

  static bool _visibleIn(AppLifecycleState state) =>
      state == AppLifecycleState.resumed || state == AppLifecycleState.inactive;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final visible = _visibleIn(state);
    if (visible == _appVisible) return;
    _appVisible = visible;
    _syncRefresh();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _dockVisible = DockPaneVisibility.of(context);
    _maybeProbeWebview();
    _syncRefresh();
  }

  @override
  void didUpdateWidget(WebsitePanel old) {
    super.didUpdateWidget(old);
    if (old.panels != widget.panels) {
      old.panels.removeListener(_onCatalogChanged);
      widget.panels.addListener(_onCatalogChanged);
    }
    if (old.panelId != widget.panelId) {
      _configRevision = widget.panels.configRevision(widget.panelId);
      _refreshRequest = widget.panels.refreshRequest(widget.panelId);
      unawaited(_loadConfig());
    }
  }

  void _onCatalogChanged() {
    final refresh = widget.panels.refreshRequest(widget.panelId);
    if (refresh != _refreshRequest) {
      _refreshRequest = refresh;
      // The operator pressed Refresh Now. Straight to the page — this is not
      // a config change and must not re-read storage or rebuild the pane.
      _reload();
    }
    final revision = widget.panels.configRevision(widget.panelId);
    if (revision == _configRevision) return;
    _configRevision = revision;
    unawaited(_loadConfig());
  }

  Future<void> _loadConfig() async {
    final panel = widget.panels[widget.panelId];
    if (panel == null) return;
    final config = await widget.panels.configFor(panel);
    if (!mounted) return;
    final previousUrl = _url;
    setState(() {
      _config = config;
      _loadError = null;
    });

    final onTitle = widget.onTitle;
    if (onTitle != null) onTitle(_tabTitle);

    // A URL change is a fresh navigation, not a reload — reload() would
    // re-fetch the page the operator just replaced.
    if (_url != previousUrl) {
      final uri = _validUri;
      if (uri != null) {
        _loadInFlight = true;
        unawaited(_controller?.loadUrl(urlRequest: URLRequest(url: WebUri.uri(uri))));
      }
    }
    _syncRefresh();
  }

  String get _url => _config[websiteUrlKey] as String? ?? '';

  Uri? get _validUri {
    WebsiteUrlProblem? problem;
    final uri = parseWebsiteUrl(_url, problem: (p) => problem = p);
    // Assigned, not setState'd: this runs from build as well as from the
    // config load, and the value is read in the same pass either way.
    _urlProblem = problem;
    return uri;
  }

  /// The operator's own name for the pane, else the site's host. Blank rather
  /// than a placeholder when there is neither — the descriptor's title stands.
  String? get _tabTitle {
    final typed = (_config[websiteTitleKey] as String? ?? '').trim();
    if (typed.isNotEmpty) return typed;
    final host = websiteShortName(_url);
    return host.isEmpty ? null : host;
  }

  void _syncRefresh() {
    _timer?.cancel();
    _timer = null;
    final interval = websiteRefreshInterval(_config[websiteRefreshKey]);
    if (!_mayRefresh || interval == null || !_dockVisible || !_appVisible) return;
    // Nothing to reload when the pane is showing a message rather than a
    // page — and a timer running against a rejected URL would call reload on
    // every interval for the life of the pane.
    if (_validUri == null) return;

    // Measured from the last load, NOT from now. A plain periodic timer
    // restarted by this gate never reaches its interval if the operator
    // switches tabs more often than the period — and nothing looks broken,
    // the page is simply always stale.
    final due = (_loadedAt ?? widget.now()).add(interval);
    final wait = due.difference(widget.now());
    if (wait > Duration.zero) {
      _timer = Timer(wait, _refreshDue);
    } else {
      // It came due while nobody was looking, so the operator is arriving at
      // a stale page rather than waiting out another interval.
      _refreshDue();
    }
  }

  void _refreshDue() {
    // Always, not as an option: a page reloading under the operator
    // mid-exchange is never what they wanted, and nobody would go looking for
    // a setting to prevent something they have not been bitten by yet.
    //
    // Skipped, not deferred: the next tick reloads normally. A caught-up
    // reload would fire the moment the operator finishes a QSO, which is
    // exactly when they look up at the pane.
    if (widget.isEnteringQso?.call() ?? false) {
      _loadedAt = widget.now();
      _syncRefresh();
      return;
    }
    _reload();
  }

  void _reload() {
    // Stamped here rather than in `onLoadStop`, so the next deadline is
    // measured even where the load never completes — offline, or a page that
    // hangs. Without it a failed refresh re-arms with a deadline already in
    // the past and the pane reloads in a tight loop.
    _loadedAt = widget.now();
    _loadInFlight = true;
    widget.onReload?.call();
    _syncRefresh();
    final controller = _controller;
    if (controller == null) return;
    // reload(), never a new Key: re-keying tears down the platform view for a
    // cold load and a visible blank, and the controller is null until the new
    // one reports itself created.
    unawaited(controller.reload());
  }

  @override
  void dispose() {
    widget.panels.removeListener(_onCatalogChanged);
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    // The last thing this app's own code knows before the native platform
    // view underneath actually tears down (HALO-290) — a subsequent native
    // crash carries no Dart stack of its own to say so.
    ErrorReportingService.breadcrumb('website panel webview disposing', category: 'webview');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.operation.layout.panels;
    final uri = _validUri;

    if (uri == null) {
      return _message(
        switch (_urlProblem) {
          WebsiteUrlProblem.empty || null => t.websiteNoUrl,
          WebsiteUrlProblem.notAUrl => t.websiteBadUrl,
          WebsiteUrlProblem.notHttps => t.websiteNotHttps,
        },
        // Nothing to open externally when there is no usable URL.
        url: null,
      );
    }

    if (_webviewSupported == WebviewSupport.pending) {
      // Nothing to say yet. The refusal below reads as a verdict, and on
      // Windows the real answer can be half a minute away.
      return const Center(child: CircularProgressIndicator());
    }

    if (_webviewSupported == WebviewSupport.no) {
      // The layout keeps its pane and the operator still reaches the site.
      return _message(t.websiteUnsupported, url: uri.toString());
    }

    return Padding(
      padding: EdgeInsets.zero.add(PaneSafeArea.paddingOf(context)),
      child: Stack(
        children: [
          InAppWebView(
            // Null off Windows; on Windows the app's own environment, without
            // which the plugin builds a second one whose options do not match
            // ours — see WindowsWebView.
            webViewEnvironment: WindowsWebView.environment,
            initialUrlRequest: URLRequest(url: WebUri.uri(uri)),
            initialSettings: InAppWebViewSettings(
              // On, unlike the extension sandbox: most of what an operator
              // would point this at renders blank without scripts. It is also
              // why website_url.dart refuses `javascript:` and `data:`.
              javaScriptEnabled: true,
              // Never set `incognito` here: on Android it clears every cookie
              // in the PROCESS, taking the operator's account logins with it.
              useShouldOverrideUrlLoading: true,
              transparentBackground: true,
              supportZoom: true,
            ),
            onWebViewCreated: (controller) {
              ErrorReportingService.breadcrumb('website panel webview created', category: 'webview');
              _controller = controller;
            },
            shouldOverrideUrlLoading: (controller, action) async {
              final target = action.request.url?.toString();
              if (target == null) return NavigationActionPolicy.CANCEL;

              // A subframe is part of the page, not a navigation away from
              // it. Judging one against the configured URL cancels an ad slot
              // rotating its creative — and, before this guard, threw it at
              // the OS browser once per rotation.
              if (action.isForMainFrame == false) return NavigationActionPolicy.ALLOW;

              // The configured page, its canonical form, and its reloads.
              if (_isConfiguredPage(target)) return NavigationActionPolicy.ALLOW;

              // A load THIS pane asked for, still settling. A server redirect
              // — `qrz.com` to `www.qrz.com` — is a different origin and can
              // only be told from a hijack by who started it.
              if (_loadInFlight) return NavigationActionPolicy.ALLOW;

              // The operator clicked something. Off it goes, and the pane
              // stays on the page they configured.
              final byHand = action.hasGesture == true ||
                  action.navigationType == NavigationType.LINK_ACTIVATED;
              if (byHand) {
                openExternalUrl(target);
                return NavigationActionPolicy.CANCEL;
              }

              // Nobody asked for this — a `<meta refresh>`, a script
              // replacing the document. Dropped SILENTLY: raising the
              // operator's browser without an interaction is a hijack, which
              // is the same reasoning `panel_content_view` states for
              // refusing to open one.
              debugPrint('[panels] ${widget.panelId}: blocked an unrequested navigation to $target');
              return NavigationActionPolicy.CANCEL;
            },
            // Denied outright. The app holds a location entitlement, so an
            // unwired handler defaults to PROMPT and a page could raise a
            // system prompt that looks like HaLo asking.
            onPermissionRequest: (controller, request) async => PermissionResponse(
              resources: request.resources,
              action: PermissionResponseAction.DENY,
            ),
            onLoadStop: (controller, url) async {
              _loadInFlight = false;
              _loadedAt = widget.now();
              if (!mounted) return;
              if (_loadError != null) setState(() => _loadError = null);
              _syncRefresh();
            },
            onReceivedError: (controller, request, error) {
              _loadInFlight = false;
              // Only the MAIN frame. A page whose analytics script 404s is not
              // a broken pane, and reporting subresources would raise a notice
              // on most of the web.
              if (request.isForMainFrame != true) return;
              // A navigation THIS pane cancelled reports back as a failed
              // load. Without this, handing a clicked link to the browser —
              // the designed behaviour — paints an error over a working page
              // and files a report for it.
              if (error.type == WebResourceErrorType.CANCELLED) return;
              _reportLoadFailure('${error.description} (${error.type})');
            },
            onReceivedHttpError: (controller, request, response) {
              _loadInFlight = false;
              if (request.isForMainFrame != true) return;
              _reportLoadFailure('HTTP ${response.statusCode}');
            },
          ),
          if (_loadError != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Material(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(Space.md),
                  child: Text(
                    t.websiteLoadFailed(reason: _loadError!),
                    style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Whether [target] is the page this pane is configured to show.
  ///
  /// Reads the CURRENT config rather than taking the URL as an argument: the
  /// plugin freezes a web view's callbacks when the platform view is created,
  /// so a closed-over local keeps naming whatever the pane was pointed at on
  /// its first build, and editing the address would hand the new site to the
  /// browser forever.
  ///
  /// Compared by origin and path, not by whole-Uri equality. A web view
  /// canonicalizes what it is given — `https://qrz.com` becomes
  /// `https://qrz.com/` — so an exact match rejects the very page it was
  /// asked to show. Query and fragment are out for the same reason plus one
  /// more: an in-page anchor is the same document, and bouncing it to the OS
  /// browser would make a table of contents unusable.
  bool _isConfiguredPage(String target) {
    final configured = _validUri;
    if (configured == null) return false;
    final t = Uri.tryParse(target);
    if (t == null) return false;
    String path(Uri u) => u.path.isEmpty ? '/' : u.path;
    return t.origin == configured.origin && path(t) == path(configured);
  }

  /// Failures already reported this session, keyed with the offline stamp.
  ///
  /// A pane on an interval fails the same way on every retry, and each repeat
  /// carries no new information. The stamp is part of the key on purpose: a
  /// failure first seen offline is quiet (ErrorPolicy's
  /// `website-panel-offline` rule) and must not consume the budget of the
  /// same failure recurring online, where it IS evidence.
  static final _reported = <String>{};

  void _reportLoadFailure(String reason) {
    if (!mounted) return;
    setState(() => _loadError = reason);
    final error = WebsitePanelError(panelId: widget.panelId, message: reason);
    if (!_reported.add('${widget.panelId}/${error.offline}/$reason')) {
      // Still printed: a developer watching the console sees the failure
      // live, not only its first occurrence.
      debugPrint('[panels] repeat: $error');
      return;
    }
    // Through ErrorPolicy like everything else: a pane that fails for every
    // operator is what has to be visible in aggregate. The operator already
    // has the banner, so this is the diagnostic half.
    ErrorReportingService.report(error, StackTrace.current, context: 'panel:website:${widget.panelId}');
  }

  Widget _message(String text, {required String? url}) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.all(Space.xl).add(PaneSafeArea.paddingOf(context)),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (url != null) ...[
              const SizedBox(height: Space.md),
              TextButton(
                onPressed: () => openExternalUrl(url),
                child: Text(context.t.operation.layout.panels.websiteOpenExternally),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
