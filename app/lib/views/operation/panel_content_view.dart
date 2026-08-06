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

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../../i18n/strings.g.dart';
import '../../services/link_opener.dart';
import '../../services/windows_webview.dart';

/// One rendered document from a panel's `render`.
class PanelContent {
  /// 'markdown' | 'svg' | 'html' — an unknown kind renders as an error
  /// rather than silently blank, since a blank pane looks like a panel that
  /// simply has nothing to say.
  final String kind;
  final String content;

  const PanelContent({required this.kind, required this.content});

  static PanelContent? fromJson(Object? json) {
    if (json is! Map) return null;
    final kind = json['kind'];
    final content = json['content'];
    if (kind is! String || content is! String) return null;
    return PanelContent(kind: kind, content: content);
  }

  @override
  bool operator ==(Object other) => other is PanelContent && other.kind == kind && other.content == content;

  @override
  int get hashCode => Object.hash(kind, content);
}

/// Whether an HTML panel can be shown here at all. Linux has no webview
/// implementation; Windows needs a WebView2 environment, which
/// [WindowsWebView] creates once and caches for the whole session — read
/// here rather than probed again, and pessimistic until it has answered.
/// `defaultTargetPlatform`, not `dart:io`'s Platform: this file is compiled
/// into the web build too, and the platform check that works on every
/// target is the one that doesn't ask the host OS.
bool get _htmlPanelsSupported {
  if (kIsWeb) return true;
  switch (defaultTargetPlatform) {
    case TargetPlatform.linux:
      return false;
    case TargetPlatform.windows:
      return WindowsWebView.resolved ?? false;
    default:
      return true;
  }
}

class PanelContentView extends StatelessWidget {
  /// Null while the first render is still in flight — a panel that has never
  /// answered shows a spinner, not an empty pane.
  final PanelContent? content;

  /// Set when the extension's own render threw or timed out. Shown in the
  /// pane rather than swallowed: a panel the operator put in their layout
  /// and that then says nothing is worse than one that says it broke.
  final String? error;

  const PanelContentView({super.key, required this.content, this.error});

  @override
  Widget build(BuildContext context) {
    if (error != null) return _message(context, error!, isError: true);
    final content = this.content;
    if (content == null) return const Center(child: CircularProgressIndicator());
    switch (content.kind) {
      case 'markdown':
        return SingleChildScrollView(
          padding: const EdgeInsets.all(Space.lg),
          child: MarkdownBody(
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
        // Every other webview in this app checks first, and for two
        // different reasons: flutter_inappwebview ships no Linux
        // implementation at all (the platform view would throw a
        // MissingPluginException out of build), and a Windows machine that
        // cannot create a WebView2 environment renders a permanently blank
        // one — see map_panel.dart, which keeps a fallback map for exactly
        // that. A panel has no fallback, so it says so instead.
        if (!_htmlPanelsSupported) {
          return _message(context, context.t.operation.layout.htmlPanelUnsupported);
        }
        return _SandboxedHtmlView(html: content.content);
      default:
        return _message(context, 'Unsupported panel content: ${content.kind}', isError: true);
    }
  }

  Widget _message(BuildContext context, String text, {bool isError = false}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(Space.xl),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isError ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
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
