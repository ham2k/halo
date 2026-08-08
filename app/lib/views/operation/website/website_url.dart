// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What the Web Site pane will and won't load, and what it calls itself.
//
// Pure — no widget, no web view — so the scheme rules are testable directly.
// They have to be tested somewhere: `pattern` is inert on a panel form
// (`showPanelSettings` passes no validator), so this is the ONLY gate between
// what the operator types and what the web view is handed.

/// The one scheme the pane will load.
///
/// Not [link_opener]'s `{http, https, mailto}`: that set is for handing a URL
/// to the OS, where `mailto:` is meaningful and `http:` is the browser's
/// problem. Here the string becomes a page rendered inside the app, and each
/// exclusion is load-bearing:
///
/// - `http:` is blocked by ATS on Apple and by cleartext policy on Android
///   anyway, so accepting it would mean a URL that works on Windows and fails
///   silently everywhere else. Lifting that needs a GLOBAL relaxation for all
///   web content in the app, which is not this pane's call to make.
/// - `javascript:` executes in whatever origin the pane last held, and scripts
///   are on.
/// - `data:` is the sandboxed panel view's own asset transport, where it is
///   harmless because scripts are off. Here it is a script-execution
///   primitive.
/// - `file:` reads the operator's disk.
const String websiteScheme = 'https';

/// Why a URL was refused, or null if it wasn't. The pane shows this — unlike
/// [openExternalUrl], which drops junk silently because its callers are taps
/// on text the operator did not write. This one the operator typed and is
/// looking at, so silence would read as the pane being broken.
enum WebsiteUrlProblem {
  /// Nothing typed yet — the pane's initial state, not an error.
  empty,

  /// Not parseable, or no scheme at all (`qrz.com` alone). Deliberately not
  /// auto-prefixed with `https://`: a guess that silently loads somewhere the
  /// operator did not name is worse than a message.
  notAUrl,

  /// Parseable, but a scheme this pane will not load.
  notHttps,
}

/// [raw] as something the pane may load, or null with a [problem].
Uri? parseWebsiteUrl(String raw, {required void Function(WebsiteUrlProblem) problem}) {
  final text = raw.trim();
  if (text.isEmpty) {
    problem(WebsiteUrlProblem.empty);
    return null;
  }
  final uri = Uri.tryParse(text);
  // `Uri.tryParse('qrz.com')` SUCCEEDS — it reads as a relative path with no
  // scheme. So a null check is not the test; having the scheme is.
  if (uri == null || !uri.hasScheme) {
    problem(WebsiteUrlProblem.notAUrl);
    return null;
  }
  // The scheme is judged BEFORE the host, and the order is the message rather
  // than the outcome: `javascript:alert(1)`, `data:…` and `file:///…` all have
  // an empty host, so a host check placed first refuses them — correctly — as
  // "not a URL", which is both untrue and no help in fixing it.
  // No case-folding needed: `Uri` normalizes the scheme to lower case while
  // parsing, so `JavaScript:` arrives here as `javascript`.
  if (uri.scheme != websiteScheme) {
    problem(WebsiteUrlProblem.notHttps);
    return null;
  }
  if (uri.host.isEmpty) {
    problem(WebsiteUrlProblem.notAUrl);
    return null;
  }
  return uri;
}

/// What the tab calls this pane when the operator has not named it: the host,
/// less a leading `www.`. Two panes pointed at different sites have to be
/// tellable apart, and the full URL does not fit on a tab.
String websiteShortName(String raw) {
  final uri = Uri.tryParse(raw.trim());
  final host = uri?.host ?? '';
  if (host.isEmpty) return '';
  return host.startsWith('www.') ? host.substring(4) : host;
}

/// The refresh intervals the form offers, in minutes. `0` is never.
///
/// Stored as `int` rather than a string because config round-trips through
/// `jsonEncode`/`jsonDecode`, so an int survives as an int and matches the
/// dropdown's `value ==` comparison. `0` rather than null for "never": a
/// null-valued select cannot tell "dismissed" from "picked null".
const List<int> websiteRefreshChoices = [0, 1, 5, 15];

/// [minutes] as a duration, or null for never (and for anything not on the
/// list — a stored value from a build that offered different choices must not
/// resolve to a refresh nobody can see configured).
Duration? websiteRefreshInterval(Object? minutes) {
  if (minutes is! int || !websiteRefreshChoices.contains(minutes) || minutes <= 0) return null;
  return Duration(minutes: minutes);
}
