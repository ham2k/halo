// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The OAuth login leg for platforms with no in-app webview — Linux, today
// (ham2k/app-halo-dist#430).
//
// Everywhere else `_doOAuth` (settings_view.dart) pushes an `InAppWebView` and
// watches its navigations for the provider's redirect. `flutter_inappwebview`
// declares android/ios/macos/web/windows and NO linux, so on Linux building that
// widget dereferences a null platform instance: an assertion in debug, a
// TypeError in release, before the login page can render at all. Pressing
// Connect on a SOTA account there crashed rather than logging in.
//
// So on Linux the login happens in the operator's own browser, and this page
// waits for the redirect. IT LEADS WITH THE PASTE BOX, deliberately: the
// redirect is a `com.ham2k.logger.<edition>.auth://` URL, and on Linux TODAY
// nothing can deliver it back to the app —
//
//   * `app/linux/ham2k-logger.desktop.in` declares no
//     `MimeType=x-scheme-handler/…`, and its `Exec` has no `%u` (#260), and the
//     shipped artifacts are an AppImage and a portable tarball, which only get
//     `.desktop` integration if the user runs appimaged themselves;
//   * `app_links` on Linux is driven entirely by the `gtk` plugin's GApplication
//     `command-line`/`open` signals, and our runner overrides
//     `local_command_line` to call `g_application_activate` directly, so those
//     signals never fire (`app/linux/runner/my_application.cc`);
//   * the runner registers `G_APPLICATION_NON_UNIQUE`, so even a registered
//     handler would start a second process rather than reach this one.
//
// Fixing that is #260 plus a runner change, and this page keeps working when it
// lands — `_doOAuth`'s deep-link listener still pops this route with the code if
// the URL ever does arrive. Until then, pasting the link is the only way home,
// which is why the copy says so plainly instead of promising the app will come
// back on its own.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import '../i18n/strings.g.dart';

/// Whether this platform has to send the operator to their own browser rather
/// than logging in inside an in-app webview.
///
/// [isWeb] and [platform] are injectable so both answers are testable. The web
/// check is not decoration: on Flutter web `defaultTargetPlatform` reports the
/// HOST — a browser on a Linux desktop answers `TargetPlatform.linux` — so
/// without it every Linux web user would be sent down a flow they don't need,
/// and the plugin does support web.
///
/// Reads `defaultTargetPlatform`, not `dart:io`'s `Platform.isLinux`, for one
/// concrete reason: the former is overridable with
/// `debugDefaultTargetPlatformOverride`, so this decision — and the page below —
/// can be tested from any dev machine. `Platform.isLinux` is a Linux-only branch
/// that no test on this project's macOS and Ubuntu runners could ever enter
/// (`flutter test` reports `android` regardless of host).
///
/// Written as the list of platforms the webview plugin DOES support, so a
/// platform nobody has thought about yet gets the browser rather than a crash.
bool oauthNeedsSystemBrowser({TargetPlatform? platform, bool? isWeb}) {
  if (isWeb ?? kIsWeb) return false;
  const supported = {
    TargetPlatform.android,
    TargetPlatform.iOS,
    TargetPlatform.macOS,
    TargetPlatform.windows,
  };
  return !supported.contains(platform ?? defaultTargetPlatform);
}

/// Why a pasted link couldn't be used, or [PastedLinkProblem.none] when it can.
///
/// A reason rather than a message: this stays free of `BuildContext` so it can be
/// unit-tested, and the page maps each case to its own translated string.
enum PastedLinkProblem { none, notARedirect, malformed, wrongLogin, noCode }

/// The outcome of reading a link the operator pasted.
@immutable
class PastedLink {
  final PastedLinkProblem problem;

  /// The authorization code, when there is one.
  final String? code;

  /// The provider's own error, when the redirect carries one — a denied consent
  /// arrives as a perfectly well-formed redirect with `error` instead of `code`.
  final String? error;

  const PastedLink._(this.problem, {this.code, this.error});

  bool get isUsable => problem == PastedLinkProblem.none;
}

/// Reads the redirect [text] the operator pasted, against the [redirectUrl] this
/// login asked for and the [expectedState] it generated.
///
/// The state check is the same one the webview and deep-link paths make
/// (settings_view.dart), and it is what stops a link from another login attempt —
/// or from anywhere else — being fed into this one's token exchange.
PastedLink readPastedRedirect(String text, {required String redirectUrl, required String expectedState}) {
  final uri = Uri.tryParse(text.trim());
  final expected = Uri.tryParse(redirectUrl);
  if (uri == null || expected == null) return const PastedLink._(PastedLinkProblem.notARedirect);
  // Scheme and authority, not a string prefix: prefix-matching
  // `com.ham2k.logger.next.auth://sota` also accepts `…://sota.example.com`,
  // and while the state check below is what actually protects the exchange,
  // there is no reason to accept a redirect addressed somewhere else. The path
  // is deliberately not compared — the provider is free to add one. `Uri`
  // lowercases scheme and host itself; the rest of the authority is folded here.
  if (uri.scheme.toLowerCase() != expected.scheme.toLowerCase() ||
      uri.authority.toLowerCase() != expected.authority.toLowerCase()) {
    return const PastedLink._(PastedLinkProblem.notARedirect);
  }
  // A paste can be truncated mid percent-escape, or carry an escape that is
  // valid hex but not valid UTF-8 — a localized provider error, cut between the
  // two bytes of one character. `Uri.tryParse` accepts those happily and
  // `queryParameters` throws while decoding them, which escaped this function
  // entirely: the button reported nothing and did nothing. Classifying it is the
  // whole job of this function (Rule 12).
  final Map<String, String> params;
  try {
    params = uri.queryParameters;
  } on FormatException {
    return const PastedLink._(PastedLinkProblem.malformed);
  }
  if (params['state'] != expectedState) {
    return const PastedLink._(PastedLinkProblem.wrongLogin);
  }
  final error = params['error_description'] ?? params['error'];
  final code = params['code'];
  if (code == null || code.isEmpty) {
    // A redirect naming an error is usable — it ends the login with the
    // provider's own reason, which beats "no code" as far as the operator is
    // concerned.
    if (error != null) return PastedLink._(PastedLinkProblem.none, error: error);
    return const PastedLink._(PastedLinkProblem.noCode);
  }
  return PastedLink._(PastedLinkProblem.none, code: code, error: error);
}

/// The waiting page: launches [authUri] in the system browser and takes the
/// redirect back by paste.
///
/// Pops with the authorization code, or with null when the operator gives up.
/// [onError] carries a provider error out the same way the webview route's
/// listener does, since a redirect that says "access_denied" has no code to pop.
class OAuthBrowserLoginPage extends StatefulWidget {
  final String accountLabel;
  final Uri authUri;
  final String redirectUrl;
  final String expectedState;
  final void Function(String error)? onError;

  /// Overridden in tests, where launching a browser is neither possible nor the
  /// point. Answers whether the browser was opened.
  final Future<bool> Function(Uri uri)? launcher;

  const OAuthBrowserLoginPage({
    super.key,
    required this.accountLabel,
    required this.authUri,
    required this.redirectUrl,
    required this.expectedState,
    this.onError,
    this.launcher,
  });

  @override
  State<OAuthBrowserLoginPage> createState() => _OAuthBrowserLoginPageState();
}

class _OAuthBrowserLoginPageState extends State<OAuthBrowserLoginPage> {
  final _pasteController = TextEditingController();
  String? _pasteError;

  /// Set when the browser could not be opened at all. The old patch launched the
  /// URL unawaited, which left a waiting page with no browser behind it and no
  /// way to tell — the operator's next move (copy the login link and open it
  /// themselves) needs to be offered, not guessed at.
  bool _launchFailed = false;

  @override
  void initState() {
    super.initState();
    _openBrowser();
  }

  @override
  void dispose() {
    _pasteController.dispose();
    super.dispose();
  }

  Future<void> _openBrowser() async {
    final launcher = widget.launcher ?? (uri) => launchUrl(uri, mode: LaunchMode.externalApplication);
    var opened = false;
    try {
      opened = await launcher(widget.authUri);
    } catch (_) {
      opened = false;
    }
    if (mounted) setState(() => _launchFailed = !opened);
  }

  String? _messageFor(PastedLinkProblem problem) {
    final t = context.t.settings.accounts;
    switch (problem) {
      case PastedLinkProblem.none:
        return null;
      case PastedLinkProblem.notARedirect:
        return t.pastedLinkNotARedirect(prefix: widget.redirectUrl);
      case PastedLinkProblem.malformed:
        return t.pastedLinkMalformed;
      case PastedLinkProblem.wrongLogin:
        return t.pastedLinkWrongLogin;
      case PastedLinkProblem.noCode:
        return t.pastedLinkNoCode;
    }
  }

  void _submitPastedLink() {
    final result = readPastedRedirect(
      _pasteController.text,
      redirectUrl: widget.redirectUrl,
      expectedState: widget.expectedState,
    );
    if (!result.isUsable) {
      setState(() => _pasteError = _messageFor(result.problem));
      return;
    }
    if (result.error != null) widget.onError?.call(result.error!);
    Navigator.of(context).pop(result.code);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.settings.accounts;
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: windowHeaderGestureArea(),
        title: Text(t.connectTo(label: widget.accountLabel)),
        actions: [
          TextButton(
            onPressed: _openBrowser,
            child: Text(t.openInBrowser),
          ),
          windowsCaptionSpacer(context),
        ],
        leadingWidth: macOSAwareLeadingWidth(context),
        leading: isMacOSChromelessWindow
            ? Padding(
                padding: EdgeInsets.only(left: macOSTrafficLightClearance(context)),
                child: CloseButton(onPressed: () => Navigator.of(context).pop()),
              )
            : CloseButton(onPressed: () => Navigator.of(context).pop()),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(t.browserLoginTitle, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Text(
                  _launchFailed
                      ? t.browserLoginNotOpened(prefix: widget.redirectUrl)
                      : t.browserLoginSteps(prefix: widget.redirectUrl),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.copy, size: 18),
                    label: Text(t.copyLoginLink),
                    onPressed: () => Clipboard.setData(ClipboardData(text: widget.authUri.toString())),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _pasteController,
                  autofocus: true,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: t.pastedLinkLabel,
                    border: const OutlineInputBorder(),
                    errorText: _pasteError,
                    errorMaxLines: 3,
                  ),
                  // Clears as they correct it: the red message under the field
                  // otherwise describes the paste before last.
                  onChanged: (_) {
                    if (_pasteError != null) setState(() => _pasteError = null);
                  },
                  onSubmitted: (_) => _submitPastedLink(),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _submitPastedLink,
                  child: Text(t.finishLogin),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
