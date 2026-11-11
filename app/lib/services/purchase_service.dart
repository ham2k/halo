// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Extension point for distribution-specific in-app purchases (store
// entitlements aren't meaningful in an OSS build with no listing). The OSS
// app ships with a no-op implementation; `HaLoServices` accepts an override
// at construction time. The app names offerings and entitlements; how a
// paywall is shown and where a purchase is made is the implementation's
// business.

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show ImageProvider;

abstract class PurchaseService {
  /// Whether purchasing is available at all in this build (false for the
  /// OSS no-op implementation).
  bool get isAvailable;

  /// The entitlement ids active for the identified user — empty until
  /// [identify] has run, and whenever the store can't be reached.
  ValueListenable<Set<String>> get entitlements;

  /// Binds purchases to [appUserId], the sync account's uuid. The same id on
  /// every device and platform is what lets a purchase made in one place
  /// unlock the others; an implementation must not fall back to an
  /// anonymous store id, whose purchases no other device could see.
  Future<void> identify(String appUserId);

  /// Re-reads [entitlements] from the store.
  Future<void> refreshEntitlements();

  /// Shows the paywall for [offering] (the store's default when null).
  /// [PurchaseResult.pending] means the purchase continues outside the app
  /// (a browser checkout); [entitlements] updates when it lands.
  Future<PurchaseResult> presentPaywall({String? offering});

  /// Opens the store's subscription management for the identified user.
  /// False when there is none to open: no subscription the store knows of,
  /// or its details not loaded.
  Future<bool> manageSubscriptions();

  /// How the sync server names a purchase of [entitlement] for the
  /// identified user, so it can verify it with the store itself. Null
  /// before [identify].
  String? channelReference(String entitlement);

  /// The supporter row's artwork. Null in a build that sells no support,
  /// and the row is then not shown.
  SupporterArt? get supporterArt;
}

/// A supporter badge, earned by the entitlement [key] or by a grant of the
/// same key in the operator's `badges` flag.
typedef SupporterBadgeArt = ({String key, int year, ImageProvider image});

/// The supporter row's artwork. It is not the public app's to carry, so the
/// distribution build supplies it.
class SupporterArt {
  /// Oldest first; the last is the current year's.
  final List<SupporterBadgeArt> badges;

  /// The contribute button, before and after the current year's badge is
  /// earned.
  final ImageProvider contributeNow;
  final ImageProvider contributeMore;

  const SupporterArt({required this.badges, required this.contributeNow, required this.contributeMore});
}

enum PurchaseResult { purchased, pending, cancelled, unavailable, failed }

class NoopPurchaseService implements PurchaseService {
  const NoopPurchaseService();

  static final ValueListenable<Set<String>> _none = ValueNotifier(const {});

  @override
  bool get isAvailable => false;

  @override
  ValueListenable<Set<String>> get entitlements => _none;

  @override
  Future<void> identify(String appUserId) async {}

  @override
  Future<void> refreshEntitlements() async {}

  @override
  Future<PurchaseResult> presentPaywall({String? offering}) async => PurchaseResult.unavailable;

  @override
  Future<bool> manageSubscriptions() async => false;

  @override
  String? channelReference(String entitlement) => null;

  @override
  SupporterArt? get supporterArt => null;
}
