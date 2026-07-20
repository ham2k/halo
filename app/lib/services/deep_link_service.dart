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
/// params) and `/link_client` (sync client linking).
class DeepLinkService {
  final AppLinks _appLinks = AppLinks();

  /// All incoming deep links, including the one the app was launched with.
  Stream<Uri> get links => _appLinks.uriLinkStream;

  /// Whether [uri] is an OAuth redirect callback (`com.ham2k.*.auth://…`).
  static bool isAuthCallback(Uri uri) =>
      uri.scheme.startsWith('com.ham2k') && uri.scheme.endsWith('.auth');
}
