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
/// The command is the URL PATH, so a Ham2K app writes three slashes
/// (`com.ham2k:///qso?…`). A hand-typed or relayed two-slash form puts the
/// same word in the host instead, and every parser below accepts both: a link
/// that silently does nothing is indistinguishable from a broken one to
/// whoever clicked it.
///
/// Values carrying reserved characters are percent-encoded by the sender —
/// notably the `/` in a SOTA summit (`W6%2FCT-006`) and in a portable
/// callsign. [Uri.queryParameters] decodes them before any parser here sees
/// them, so nothing below re-decodes.
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

  /// Whether [uri] is a Ham2K link naming [command] (`'qso'`, `'vfo'`, …).
  static bool _isCommand(Uri uri, String command) =>
      uri.scheme.startsWith('com.ham2k') && (uri.path == '/$command' || uri.host == command);

  /// The radio state a `/vfo` link carries — where the operator's radio
  /// actually is, per a companion app that already knows (SOTAcat, SOTAmat).
  /// Null when [uri] isn't a `/vfo` link, or names no part of a VFO at all.
  ///
  /// `com.ham2k:///vfo?frequency=14250000&mode=SSB`
  ///
  /// A bare `SSB` here is not a sideband, and [RadioService.setVfo] resolves
  /// it against the band it settles on — so this passes the mode through as
  /// written rather than guessing one.
  static ({double? freqKHz, String? band, String? mode})? vfoRequest(Uri uri) {
    if (!_isCommand(uri, 'vfo')) return null;
    final radio = _radioStateIn(uri.queryParameters);
    if (radio.freqKHz == null && radio.band == null && radio.mode == null) return null;
    return radio;
  }

  /// The QSO a `/qso` link proposes — the station being worked, where, and
  /// (for a multi-operator activation) who else is on the frequency. Null
  /// when [uri] isn't a `/qso` link, or names no station.
  ///
  /// `com.ham2k:///qso?their.call=N0CALL&frequency=7200000&mode=CW`
  ///
  /// The radio state travels with it because a companion app sending a QSO is
  /// reporting where the radio IS, not merely where a contact might be — so
  /// unlike a spot tap (`suggestedQsoFromSpot`, which deliberately leaves the
  /// VFO alone) this one is authoritative and the caller writes it through.
  ///
  /// `returnpath` is accepted and ignored, as it is in app-polo: it is
  /// reserved for telling the calling app we are done, which nothing does yet.
  static ({
    List<String> calls,
    double? freqKHz,
    String? band,
    String? mode,
    int? startAtMillis,
    List<({String key, String ref})> theirRefs,
  })? qsoRequest(Uri uri) {
    if (!_isCommand(uri, 'qso')) return null;
    final params = uri.queryParameters;
    // A comma-joined list is a multi-operator activation — several operators
    // on one frequency. The caller puts it back into the call field comma-
    // joined, where HaLo's comma-list syntax logs ONE QSO PER CALL
    // (logging-fields.md §"three multi-call syntaxes"), which is what
    // app-polo's own comma handling does with the same string. NOT `//`
    // stacking, which queues stations to be logged one Enter at a time.
    //
    // Split here anyway, so an empty or punctuation-only list is caught
    // before it reaches the field, and each call arrives trimmed.
    final calls = (params['their.call'] ?? '')
        .split(',')
        .map((c) => c.trim().toUpperCase())
        .where((c) => c.isNotEmpty)
        .toList();
    if (calls.isEmpty) return null;
    final radio = _radioStateIn(params);
    return (
      calls: calls,
      freqKHz: radio.freqKHz,
      band: radio.band,
      mode: radio.mode,
      startAtMillis: int.tryParse(params['startAtMillis'] ?? ''),
      theirRefs: refPairsIn(params['their.refs']),
    );
  }

  /// The references an `/operation` link asks to activate, as `key:ref` pairs
  /// awaiting a ref TYPE the extension host has to supply (`pota` names the
  /// extension; `potaActivation` is the type an operation carries). Null when
  /// [uri] isn't an `/operation` link, or names no usable reference.
  ///
  /// `com.ham2k:///operation?our.refs=pota:US-1234,sota:W6%2FCT-006`
  static List<({String key, String ref})>? operationRequest(Uri uri) {
    if (!_isCommand(uri, 'operation')) return null;
    final refs = refPairsIn(uri.queryParameters['our.refs']);
    return refs.isEmpty ? null : refs;
  }

  /// `type:ref` pairs from a comma-separated list, in the order written and
  /// with unusable entries dropped.
  ///
  /// The FIRST colon separates, because a reference may contain one of its
  /// own; the key is lowercased to match an extension key, and the reference
  /// is left exactly as sent — normalizing a summit or a park code is the
  /// owning extension's `validateRef`, not this parser's guess.
  ///
  /// Public for `deep_link_service_test.dart`.
  static List<({String key, String ref})> refPairsIn(String? list) {
    if (list == null || list.isEmpty) return const [];
    final pairs = <({String key, String ref})>[];
    for (final part in list.split(',')) {
      final trimmed = part.trim();
      final colon = trimmed.indexOf(':');
      if (colon < 1) continue;
      final key = trimmed.substring(0, colon).toLowerCase();
      final ref = trimmed.substring(colon + 1).trim();
      if (ref.isEmpty) continue;
      pairs.add((key: key, ref: ref));
    }
    return pairs;
  }

  /// The `type:ref` keys in a QSON `refs` list, ignoring entries missing
  /// either half. Accepts [Object?] because it reads an operation's untyped
  /// `data['refs']`, which a sync peer or an older build may have written as
  /// anything at all.
  static Set<String> refKeysOf(Object? refs) {
    if (refs is! List) return const {};
    final keys = <String>{};
    for (final ref in refs) {
      if (ref is! Map) continue;
      final type = ref['type'];
      final value = ref['ref'];
      if (type is String && value is String && type.isNotEmpty && value.isNotEmpty) keys.add('$type:$value');
    }
    return keys;
  }

  /// Whether an operation carrying [refs] is the one an `/operation` link
  /// asking for [wanted] should reuse.
  ///
  /// An EXACT set match, as in app-polo: a park-only request must not latch
  /// onto a park-and-summit operation, and a park-and-summit request must not
  /// reuse a park-only one. Those are distinct activations, and reusing one
  /// for the other files every contact under an award it was not made for.
  static bool activationRefsMatch(Object? refs, Set<String> wanted) {
    final present = refKeysOf(refs);
    return present.length == wanted.length && present.containsAll(wanted);
  }

  /// Frequency, band and mode as `/qso` and `/vfo` both spell them.
  ///
  /// `freq` (kHz) is read BEFORE `frequency` (Hz), matching what app-polo's
  /// `buildSuggestedQSO` actually does — its own doc comment claims the
  /// reverse, and the code is what the companion apps were built against.
  /// A link carrying either one names the band on its own, so an explicit
  /// `band` is only consulted when neither is present.
  static ({double? freqKHz, String? band, String? mode}) _radioStateIn(Map<String, String> params) {
    final freqKHz = double.tryParse(params['freq'] ?? '') ??
        switch (double.tryParse(params['frequency'] ?? '')) { final hz? => hz / 1000, null => null };
    final mode = params['mode']?.trim().toUpperCase();
    return (
      freqKHz: freqKHz,
      band: freqKHz != null ? null : params['band']?.trim(),
      mode: (mode == null || mode.isEmpty) ? null : mode,
    );
  }
}
