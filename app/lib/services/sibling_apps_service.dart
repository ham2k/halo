// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The other Ham2K loggers installed on this device: PoLo, or a
// HaLo edition other than the running one. Onboarding and Settings › Switch
// Accounts use the answer to offer linking straight across — the same
// orphaned-permission deep link the QR flow paints, handed to the sibling
// app instead of to a camera.
//
// Only mobile has siblings: PoLo runs nowhere else, and two desktop editions
// share nothing a deep link could reach. Everywhere else (web, desktop, the
// test binding) the channel has no handler and [list] answers empty, which
// is the current onboarding, unchanged.
//
// Detection differs per platform, and the difference is the whole design:
//  - Android asks `PackageManager` about a PACKAGE ID — exact, and unaffected
//    by the sibling's age. The link then goes out as an explicit Intent with
//    `setPackage`, so the URL keeps the public `com.ham2k` scheme and no
//    chooser ever appears.
//  - iOS can only ask `canOpenURL` about a SCHEME, and a scheme names an app
//    only while exactly one app claims it. The probes are `com.ham2k.polo`
//    and the ALIAS family `com.ham2k.halo.<edition>` — never
//    `com.ham2k.logger.<edition>`, which every build older than HALO-526
//    claims for all three editions at once (deep_link_service.dart's header
//    is the spec). The link then goes out ON the probe scheme, since on iOS
//    the scheme is the only targeting there is.
//
// The running edition claims its own scheme and its own package always
// resolves, so it is dropped HERE, by [filterSiblings], on both platforms:
// the native halves answer only "is it installed", and neither the manifest
// nor the plist can express "except me".

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../config/version.dart';
import 'error_reporting_service.dart';

/// One other Ham2K logger this build knows how to look for.
class SiblingApp {
  /// What the native side probes and opens: an Android package id, or an
  /// iOS URL scheme.
  final String id;

  /// The name the offer shows. Brand names, deliberately untranslated.
  final String name;

  /// The HaLo edition this entry names, or null for PoLo.
  final Edition? edition;

  const SiblingApp({required this.id, required this.name, this.edition});

  @override
  bool operator ==(Object other) => other is SiblingApp && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'SiblingApp($id)';
}

const _poloName = 'Ham2K Portable Logger';

/// Every sibling an Android build looks for — the six `<package>` entries in
/// the manifest's `<queries>` block, which is what makes them visible to
/// `getPackageInfo` at all (url_scheme_claims_test pins that list).
const androidSiblingCatalog = <SiblingApp>[
  SiblingApp(id: 'com.ham2k.polo.prod', name: _poloName),
  SiblingApp(id: 'com.ham2k.polo.beta', name: '$_poloName (Beta)'),
  SiblingApp(id: 'com.ham2k.polo.alpha', name: '$_poloName (Alpha)'),
  SiblingApp(id: 'com.ham2k.logger.prod', name: 'Ham2K Logger', edition: Edition.prod),
  SiblingApp(id: 'com.ham2k.logger.next', name: 'Ham2K Logger (Next Edition)', edition: Edition.next),
  SiblingApp(id: 'com.ham2k.logger.dev', name: 'Ham2K Logger (Dev Edition)', edition: Edition.dev),
];

/// Every sibling an iOS build looks for — each a scheme in the plist's
/// `LSApplicationQueriesSchemes`. One PoLo entry: its three flavors all
/// claim the same scheme, so iOS cannot tell them apart. The HaLo entries
/// are the `halo` ALIAS family, never `logger` — see the header.
const iosSiblingCatalog = <SiblingApp>[
  SiblingApp(id: 'com.ham2k.polo', name: _poloName),
  SiblingApp(id: 'com.ham2k.halo.prod', name: 'Ham2K Logger', edition: Edition.prod),
  SiblingApp(id: 'com.ham2k.halo.next', name: 'Ham2K Logger (Next Edition)', edition: Edition.next),
  SiblingApp(id: 'com.ham2k.halo.dev', name: 'Ham2K Logger (Dev Edition)', edition: Edition.dev),
];

/// [catalog] minus the entry naming [running] — a build must never offer to
/// link with itself, and the native probes cannot tell "me" from "another
/// copy of me".
List<SiblingApp> filterSiblings(Iterable<SiblingApp> catalog, {required Edition running}) => catalog.where((app) => app.edition != running).toList();

/// Whether exactly one PoLo is among [found] — the case an offer may call
/// "the older version" without saying which; two flavors must be named.
bool onlyPolo(Iterable<SiblingApp> found) => found.where((app) => app.edition == null).length == 1;

/// The catalog for the platform this build runs on, already filtered.
List<SiblingApp> siblingCandidates({TargetPlatform? platform, Edition? running}) {
  if (kIsWeb) return const [];
  final catalog = switch (platform ?? defaultTargetPlatform) {
    TargetPlatform.android => androidSiblingCatalog,
    TargetPlatform.iOS => iosSiblingCatalog,
    _ => const <SiblingApp>[],
  };
  return filterSiblings(catalog, running: running ?? kEdition);
}

/// The link handed to [SiblingAppsService.open], on the wire the sibling
/// will actually answer: on iOS the probe scheme replaces `com.ham2k`, since
/// the scheme is the targeting; on Android the explicit package is, and the
/// public scheme stays.
String siblingLinkUrl(SiblingApp app, String url, {TargetPlatform? platform}) {
  if ((platform ?? defaultTargetPlatform) != TargetPlatform.iOS) return url;
  return Uri.parse(url).replace(scheme: app.id).toString();
}

class SiblingAppsService {
  static const _channel = MethodChannel('ham2k/sibling_apps');

  /// The siblings actually installed, in catalog order. Empty wherever the
  /// channel has no native half.
  Future<List<SiblingApp>> list() async {
    final candidates = siblingCandidates();
    if (candidates.isEmpty) return const [];
    try {
      final installed = await _channel.invokeListMethod<String>('list', {
        'ids': [for (final app in candidates) app.id],
      });
      if (installed == null) return const [];
      return candidates.where((app) => installed.contains(app.id)).toList();
    } on MissingPluginException {
      // The test binding on a mobile TargetPlatform lands here too, so this
      // stays quiet; a mobile build whose channel registration is lost
      // reads as "nothing installed", which only a device test can see.
      return const [];
    } on PlatformException catch (e, st) {
      // Both native halves are in this repo and throw nothing expected, so
      // this is a defect every time — and the offer simply not appearing is
      // all the operator would ever see of it. Reported, then the current
      // onboarding.
      ErrorReportingService.report(e, st, context: 'sibling-apps:list');
      return const [];
    }
  }

  /// Hands [url] to [app]. False when the platform could not open it —
  /// the app was uninstalled since [list], or refused the link. A
  /// [PlatformException] is a native defect (a throw the Kotlin side did
  /// not expect, a malformed call) and PROPAGATES: false is the expected
  /// answer's spelling, and the caller's catch is where a defect gets
  /// reported rather than painted as "could not open".
  Future<bool> open(SiblingApp app, String url) async {
    try {
      final ok = await _channel.invokeMethod<bool>('open', {'id': app.id, 'url': siblingLinkUrl(app, url)});
      return ok ?? false;
    } on MissingPluginException {
      return false;
    }
  }
}
