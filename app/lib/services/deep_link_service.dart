// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:app_links/app_links.dart';

/// Incoming `com.ham2k*://` deep links (registered per-platform: macOS/iOS
/// Info.plist `CFBundleURLTypes`, Android manifest intent filters).
///
/// Ham2K's schema catalog (mirrors app-polo's DeepLinks.jsx):
///
///   - `com.ham2k://…` — any Ham2K app may handle the link.
///   - `com.ham2k.logger://…` / `com.ham2k.logger.<edition>://…` — HaLo
///     only (edition-specific variants for Dev/Next builds).
///   - `com.ham2k.polo://…` — PoLo's own scheme, registered here too since
///     HaLo will eventually replace PoLo.
///   - `com.ham2k.polo.auth://…` / `com.ham2k.logger.auth://…` — OAuth
///     redirect callbacks (the `.auth` suffix is what OAuth providers have
///     registered as redirect URIs); consumed by the account login flow.
///
/// Paths PoLo handles that HaLo doesn't yet (future work, documented so the
/// schemes stay reserved): `/qso` (present a QSO for logging from query
/// params).
class DeepLinkService {
  final AppLinks _appLinks = AppLinks();

  /// All incoming deep links, including the one the app was launched with.
  Stream<Uri> get links => _appLinks.uriLinkStream;

  /// Whether [uri] is an OAuth redirect callback (`com.ham2k.*.auth://…`).
  static bool isAuthCallback(Uri uri) =>
      uri.scheme.startsWith('com.ham2k') && uri.scheme.endsWith('.auth');

  /// The sync link request [uri] carries, or null when it isn't one:
  /// `com.ham2k:///link_client?id=<client uuid>&token=<challenge>`, the
  /// payload a Ham2K app puts in the QR code its "link with a QR code" flow
  /// displays (`linkClientQrUrl`). Whichever app SCANS it is the one
  /// approving, so this is the entry point to the confirming side.
  ///
  /// Both authority forms are accepted. `:///link_client` — what Ham2K apps
  /// generate — parses as an empty host and a `/link_client` path, while a
  /// hand-typed or relayed `://link_client` puts the same word in the host,
  /// and a link that doesn't open at all is indistinguishable from a broken
  /// QR code to the person holding the phone.
  static ({String clientUuid, String challengeToken})? linkClientRequest(Uri uri) {
    if (!uri.scheme.startsWith('com.ham2k')) return null;
    if (uri.path != '/link_client' && uri.host != 'link_client') return null;
    final clientUuid = uri.queryParameters['id'];
    final challengeToken = uri.queryParameters['token'];
    if (clientUuid == null || clientUuid.isEmpty) return null;
    if (challengeToken == null || challengeToken.isEmpty) return null;
    return (clientUuid: clientUuid, challengeToken: challengeToken);
  }

  /// The extension a `com.ham2k:///install_extension?url=<https url>` link
  /// asks to install, or null when [uri] isn't one (HALO-422).
  ///
  /// Both authority forms are accepted, for the same reason `link_client`
  /// accepts both: a link that silently does nothing is indistinguishable
  /// from a broken one to whoever clicked it.
  ///
  /// **https only.** A bundle is code the app will run; fetching it over a
  /// connection anyone on the path can rewrite would make the consent screen
  /// a description of whatever they substituted. Nothing is downloaded until
  /// this returns non-null, and nothing is installed until the operator has
  /// seen the source and agreed.
  static Uri? installExtensionRequest(Uri uri) {
    if (!uri.scheme.startsWith('com.ham2k')) return null;
    if (uri.path != '/install_extension' && uri.host != 'install_extension') return null;
    final raw = uri.queryParameters['url'];
    if (raw == null || raw.isEmpty) return null;
    final target = Uri.tryParse(raw);
    if (target == null || target.scheme != 'https' || target.host.isEmpty) return null;
    return target;
  }
}
