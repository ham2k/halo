// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Renders what an extension panel returns (docs/extensions/hooks.md, `panel`).
// An extension contributes a DOCUMENT, never widgets — the core decides how
// it looks, which is the same UI-catalog seam every other declarative hook
// sits behind (DESIGN.md §5).
//
// Markdown is the kind to prefer and the one to reach for first: it inherits
// the app's typography, theme, font scale and density for free, and costs no
// web view. SVG is a vector image, drawn with the app's own painter. HTML is
// the escape hatch, and it runs under the sandbox below.

import 'dart:convert';

import 'panel_scene/scene_model.dart';
import 'panel_scene/scene_spectrum.dart';
import 'panel_scene/scene_view.dart';

import 'package:flutter/foundation.dart' show kIsWeb, listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'package:halo_i18n/halo_i18n.dart';
import '../../services/error_reporting_service.dart';
import '../../services/link_opener.dart';
import '../../services/panel_content_budgets.dart';
import '../../services/windows_webview.dart';

/// One rendered document from a panel's `render`.
class PanelContent {
  /// 'markdown' | 'svg' | 'html' | 'scene' — an unknown kind renders as an error
  /// rather than silently blank, since a blank pane looks like a panel that
  /// simply has nothing to say.
  final String kind;
  final String content;
  final PanelScene? scene;

  /// A tab label for this rendering, overriding the descriptor's title.
  /// Optional, and the reason it exists is panels an operator may place more
  /// than once: three panes all labelled "Custom Text" tell them nothing,
  /// and the operator's own heading is a better label than an ordinal.
  final String? title;

  /// What THIS placement asks to be re-rendered on, added to whatever its
  /// descriptor declared (`PanelDefinition.triggers`).
  ///
  /// A descriptor's triggers are per panel KIND and so are paid by every
  /// placement of it; these are per instance. That distinction exists for
  /// panels whose content is written by the operator: a custom-text pane
  /// showing a band plan must not put every other custom-text pane on the
  /// typing path just because one of them names the callsign being entered.
  ///
  /// Unknown names are dropped by [PanelService.declareTriggers] — a panel
  /// cannot invent a signal the host doesn't fire.
  final List<String> triggers;

  const PanelContent({required this.kind, required this.content, this.title, this.triggers = const [], this.scene});

  /// THROWS for a `scene` whose document does not validate, rather than
  /// answering null: the FormatException names the layer, tag or value at
  /// fault, and the caller's render `catch` is what carries it to the console
  /// and the dev client. Swallowed here, the author sees only "could not be
  /// displayed". A document over a budget (panel_content_budgets.dart) throws
  /// the same way, as a [PanelContentRefusal] the caller can name to the
  /// operator — refused whole, never trimmed or drawn in part.
  ///
  /// [previous] is what the pane is showing. A ticking scene panel returns the
  /// same document most of the time, and validating it walks every layer's
  /// artwork again — so an unchanged document keeps the scene it has.
  static PanelContent? fromJson(Object? json, {PanelContent? previous}) {
    if (json is! Map) return null;
    // `svgScene` is the same kind under its name through SDK 0.9, which published
    // packages still send.
    final kind = json['kind'] == 'svgScene' ? 'scene' : json['kind'];
    final Object? content;
    PanelScene? scene;
    if (kind == 'scene') {
      final document = json['scene'];
      if (document is! Map) throw const FormatException('A scene render result needs a scene document');
      try {
        content = jsonEncode(document);
      } on JsonUnsupportedObjectError catch (e) {
        throw FormatException('The scene document is not JSON: ${e.cause ?? e.unsupportedObject}');
      }
      scene = previous?.kind == kind && previous?.content == content ? previous?.scene : null;
      scene ??= PanelScene(document);
    } else {
      content = json['content'];
      // The same document again — a ticking panel's, most renders — was
      // judged when it first arrived.
      if (kind is String && content is String && !(previous?.kind == kind && previous?.content == content)) {
        final refusal = panelDocumentRefusal(kind, content);
        if (refusal != null) throw refusal;
      }
    }
    if (kind is! String || content is! String) return null;
    final title = json['title'];
    // Blank is not a label — a panel that computes its title from empty
    // config would otherwise leave a nameless tab.
    final trimmed = title is String ? title.trim() : '';
    final triggers = json['triggers'];
    return PanelContent(
      kind: kind,
      content: content,
      scene: scene,
      title: trimmed.isEmpty ? null : trimmed,
      triggers: triggers is List ? triggers.whereType<String>().toList() : const [],
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PanelContent && other.kind == kind && other.content == content && other.title == title && listEquals(other.triggers, triggers);

  @override
  int get hashCode => Object.hash(kind, content, title, Object.hashAll(triggers));
}

class PanelContentView extends StatelessWidget {
  /// Null while the first render is still in flight — a panel that has never
  /// answered shows a spinner, not an empty pane.
  final PanelContent? content;

  /// Set when the extension's own render threw or timed out. Shown in the
  /// pane rather than swallowed: a panel the operator put in their layout
  /// and that then says nothing is worse than one that says it broke.
  final String? error;

  /// Asks the panel again. Offered beside [error] because a pane can
  /// otherwise be stuck for the session: one that declares no triggers has
  /// nothing that would ever ask on its own, and a failure during a runtime
  /// restart is exactly the case that would succeed a moment later.
  final VoidCallback? onRetry;
  final SceneEventHandler? onSceneEvent;
  final SceneSpectrumSource? spectrum;

  const PanelContentView({super.key, required this.content, this.error, this.onRetry, this.onSceneEvent, this.spectrum});

  @override
  Widget build(BuildContext context) {
    if (error != null) return _message(context, error!, isError: true, onRetry: onRetry);
    final content = this.content;
    if (content == null) return const Center(child: CircularProgressIndicator());
    switch (content.kind) {
      case 'scene' when content.scene != null:
        return PanelSceneView(scene: content.scene!, onEvent: onSceneEvent, spectrum: spectrum);
      case 'markdown':
        return SingleChildScrollView(
          padding: const EdgeInsets.all(Space.lg),
          child: HaloMarkdown(
            data: content.content,
            selectable: true,
            // The same link policy as a status-bar notice's: http(s) and
            // mailto leave for the OS browser, anything else is ignored.
            onTapLink: (text, href, title) {
              if (href != null) openExternalUrl(href);
            },
          ),
        );
      case 'svg':
        return Padding(
          padding: const EdgeInsets.all(Space.lg),
          // A panel's SVG is a diagram, not an icon: fit it to the pane and
          // let it keep its own aspect ratio.
          child: SvgPicture.string(
            content.content,
            fit: BoxFit.contain,
            // An SVG that fails to parse throws inside the painter, where
            // nothing above can catch it — this keeps a malformed document
            // to its own pane.
            errorBuilder: (context, error, stackTrace) => _message(context, '$error', isError: true),
          ),
        );
      case 'html':
        // The web has a web view — an iframe — and that is precisely why it
        // is refused here rather than routed to [_HtmlPanelView].
        //
        // NOT for the missing network block on its own: Windows lacks that
        // too (`blockNetworkLoads`/`blockNetworkImage`/`contentBlockers` have
        // no Windows implementation either) and still renders panels, which
        // is the case the sandbox comment below calls a rule your panel must
        // follow rather than one it is held to.
        //
        // What is web-only is the NAVIGATION half, and it is the half
        // [_SandboxedHtmlView] relies on most. `flutter_inappwebview_web`
        // honours `javaScriptEnabled: false` by dropping `allow-scripts`, but
        // the sandbox it then applies is every OTHER token — including
        // `allow-top-navigation`, `allow-popups` and `allow-same-origin`. So
        // an extension's document could navigate the whole app away or open
        // windows, and `shouldOverrideUrlLoading` is not a reliable veto over
        // an iframe's own top-level navigation the way it is over a native
        // web view's. That is strictly worse than any platform we do render
        // on, and it is a hijack rather than a leak.
        if (kIsWeb) return _message(context, context.t.operation.layout.htmlPanelUnsupportedOnWeb);
        // Behind a platform gate, and a stateful one because the Windows half
        // of the answer arrives late — see [_HtmlPanelView].
        return _HtmlPanelView(html: content.content);
      default:
        return _message(context, 'Unsupported panel content: ${content.kind}', isError: true);
    }
  }
}

/// The pane's plain-text fallback: a failure, a retry offer, or the reason
/// there is no document to draw. Top-level rather than a method, because the
/// platform gate below says its piece from a widget of its own and the two
/// must render identically.
Widget _message(BuildContext context, String text, {bool isError = false, VoidCallback? onRetry}) {
  final theme = Theme.of(context);
  return Padding(
    padding: const EdgeInsets.all(Space.xl),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: isError ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant),
          ),
          if (onRetry != null) ...[const SizedBox(height: Space.md), TextButton(onPressed: onRetry, child: Text(context.t.operation.layout.panelRenderRetry))],
        ],
      ),
    ),
  );
}

/// An extension's HTML, or the reason this machine cannot show it.
///
/// Every other webview in this app checks first, and for two different
/// reasons: Linux registers no web view implementation at all, so
/// `InAppWebViewPlatform.instance` is null and building the widget dies on its
/// null check — an assertion in debug, a `TypeError` in release, never a
/// MissingPluginException, because no method channel is reached (see
/// docs/quirks.md). And a Windows machine that cannot create a WebView2
/// environment renders a permanently blank one — see map_panel.dart, which
/// keeps a fallback map for exactly that. A panel has no fallback, so it says
/// so instead.
///
/// Stateful for Windows alone: [WindowsWebView] resolves once per session and
/// the first answer costs a cold browser-process spawn, so it lands after this
/// pane is on screen and has to reach `setState`. Reading
/// `WindowsWebView.resolved` without ever asking [WindowsWebView.isAvailable]
/// leaves a panel claiming "unsupported" on a machine WebView2 runs fine on,
/// for as long as no map pane and no login happen to ask first.
///
/// `defaultTargetPlatform`, not `dart:io`'s Platform: this file is compiled
/// into the web build too, and the platform check that works on every target
/// is the one that doesn't ask the host OS.
///
/// The web never arrives here — it is refused at the `case 'html'` above, for
/// a reason that is about the sandbox rather than about whether a web view
/// exists. Do not fold that check into [probeWebviewSupport]: the Web Site
/// pane shares that probe and legitimately runs on the web, because it loads
/// the OPERATOR's own URL under no sandbox at all.
class _HtmlPanelView extends StatefulWidget {
  final String html;

  const _HtmlPanelView({required this.html});

  @override
  State<_HtmlPanelView> createState() => _HtmlPanelViewState();
}

class _HtmlPanelViewState extends State<_HtmlPanelView> {
  /// Whether this platform can host a web view at all. Never optimistic: a web
  /// view built where the platform cannot host one takes the pane — and on
  /// Linux the app — down, so [WebviewSupport.pending] waits rather than
  /// guessing in either direction.
  WebviewSupport _support = WebviewSupport.pending;

  @override
  void initState() {
    super.initState();
    _support = probeWebviewSupport((ok) {
      if (mounted) setState(() => _support = ok ? WebviewSupport.yes : WebviewSupport.no);
    });
  }

  @override
  void dispose() {
    // The last thing this app's own code knows before the native platform
    // view underneath actually tears down (HALO-290) — a subsequent native
    // crash carries no Dart stack of its own to say so. Gated on _support:
    // an unsupported/pending pane never built _SandboxedHtmlView, and a
    // breadcrumb claiming otherwise would misinform the very crash trail
    // this exists to keep trustworthy.
    if (_support == WebviewSupport.yes) {
      ErrorReportingService.breadcrumb('html extension panel webview disposing', category: 'webview');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (_support) {
      // The same spinner an unanswered panel shows, and for the same reason:
      // the pane has nothing to say yet. Saying "unsupported" here instead
      // would be a verdict delivered before the question was answered, and on
      // Windows the answer can be half a minute away.
      case WebviewSupport.pending:
        return const Center(child: CircularProgressIndicator());
      case WebviewSupport.no:
        return _message(context, context.t.operation.layout.htmlPanelUnsupported);
      case WebviewSupport.yes:
        return _SandboxedHtmlView(html: widget.html);
    }
  }
}

/// An extension's HTML, in a web view that is deliberately not a browser.
///
/// The policy, and why each piece is load-bearing:
///
/// - **No JavaScript.** A panel contributes a document; anything that needs
///   to compute belongs in the extension's own bundle, which already runs
///   under the kernel's limits and its `domains` allowlist. Scripts here
///   would run outside all of that.
/// - **No network.** Every subresource — image, stylesheet, font — is
///   blocked, so a panel cannot beacon the operator's IP or pull content
///   past the allowlist. Anything it wants to show travels inside the
///   document as a `data:` URI. Enforced by content blockers on Apple
///   platforms and by `blockNetworkLoads` on Android; a platform whose web
///   view honours neither still gets no scripts and no navigation.
/// - **No navigation.** Every load attempt after the initial document is
///   cancelled. An `http`/`https`/`mailto` link opens in the OS browser
///   instead — the same scheme list a status-bar notice's link action
///   allows; every other scheme is dropped.
class _SandboxedHtmlView extends StatelessWidget {
  final String html;

  const _SandboxedHtmlView({required this.html});

  static final _blockEverything = [
    ContentBlocker(
      trigger: ContentBlockerTrigger(urlFilter: '.*'),
      action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      // Null off Windows; on Windows the app's own environment, without
      // which the plugin builds one next to the exe — which fails where that
      // isn't writable, and where it succeeds gives WebView2 a second
      // environment whose options don't match ours (see WindowsWebView).
      webViewEnvironment: WindowsWebView.environment,
      // No baseUrl: the document loads from an opaque origin, so even a
      // relative URL has nothing to resolve against.
      initialData: InAppWebViewInitialData(data: html),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: false,
        transparentBackground: true,
        supportZoom: false,
        blockNetworkLoads: true,
        blockNetworkImage: true,
        contentBlockers: _blockEverything,
      ),
      onWebViewCreated: (controller) => ErrorReportingService.breadcrumb('html extension panel webview created', category: 'webview'),
      shouldOverrideUrlLoading: (controller, action) async {
        // Only a navigation the OPERATOR started leaves for the browser.
        // Scripts are off, but `<meta http-equiv="refresh">` is still a
        // main-frame navigation: without this a panel document could pop the
        // default browser at an arbitrary URL with no interaction, which is
        // both a hijack and the IP beacon the no-network rule exists to
        // prevent.
        final byHand = action.hasGesture == true || action.navigationType == NavigationType.LINK_ACTIVATED;
        final url = action.request.url?.toString();
        if (byHand && url != null) {
          openExternalUrl(url);
        } else if (url != null) {
          debugPrint('[panels] blocked an unrequested navigation to $url');
        }
        return NavigationActionPolicy.CANCEL;
      },
    );
  }
}
