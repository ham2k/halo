// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Extension point for distribution-specific in-app purchases (store
// entitlements aren't meaningful in an OSS build with no listing). The OSS
// app ships with a no-op implementation; `HaLoServices` accepts an override
// at construction time.

abstract class PurchaseService {
  /// Whether purchasing is available at all in this build (false for the
  /// OSS no-op implementation).
  bool get isAvailable;

  /// Whether the given entitlement (e.g. a product/SKU id) is currently
  /// unlocked for this user.
  Future<bool> isEntitled(String entitlementId);

  Future<PurchaseResult> purchase(String entitlementId);

  Future<void> restorePurchases();
}

enum PurchaseResult { success, cancelled, unavailable, failed }

class NoopPurchaseService implements PurchaseService {
  const NoopPurchaseService();

  @override
  bool get isAvailable => false;

  @override
  Future<bool> isEntitled(String entitlementId) async => false;

  @override
  Future<PurchaseResult> purchase(String entitlementId) async => PurchaseResult.unavailable;

  @override
  Future<void> restorePurchases() async {}
}
