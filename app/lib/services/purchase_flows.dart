// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The purchase flows the UI starts: identifying the purchaser, presenting a
// paywall, and handing a sync purchase to the sync server. Kept out of the
// widgets because three surfaces start them (the Sync panel, the supporter
// row in Settings, a server notice's `donate` action) and must agree on who
// the purchaser is.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../config/navigation.dart';
import '../tools/sync_account_identity.dart';
import '../views/notice_actions.dart';
import 'halo_services.dart';
import 'purchase_service.dart';

/// The entitlement a sync subscription grants, and the offering that sells
/// it — the names app-polo's purchases already use, so one purchase counts
/// in both apps.
const syncEntitlement = 'lofi_2025';
const syncOffering = 'lofi_offering';

/// Binds purchases to this device's sync account. Returns false when there
/// is nothing to bind to — purchasing unavailable in this build, or no
/// account the server will name (it can't be reached) — and the caller must
/// then not offer a purchase: one made with no account behind it could not
/// be seen from any other device.
Future<bool> identifyPurchaser(HaLoServices services) async {
  if (!services.purchases.isAvailable) return false;
  var uuid = syncAccountUuid(services.settings.syncState['accountData']);
  uuid ??= syncAccountUuid(await services.extensions.syncAccountData());
  if (uuid == null) return false;
  await services.purchases.identify(uuid);
  return true;
}

/// Presents [offering]'s paywall for the identified sync account, and hands
/// a completed sync purchase to the sync server.
Future<PurchaseResult> presentPaywall(HaLoServices services, {String? offering}) async {
  if (!await identifyPurchaser(services)) return PurchaseResult.unavailable;
  final result = await services.purchases.presentPaywall(offering: offering);
  if (result == PurchaseResult.purchased) await attachSyncPurchase(services);
  return result;
}

/// Hands sync purchases to the sync server for the app's lifetime: on every
/// entitlement change ([attachSyncPurchase]), and by identifying the
/// purchaser now when this device already knows its account. A checkout
/// finishes in a browser, with no paywall call left to return it and
/// Settings likely closed, so without this it would wait for the Sync panel.
void watchSyncPurchases(HaLoServices services) {
  if (!services.purchases.isAvailable) return;
  services.purchases.entitlements.addListener(() => unawaited(attachSyncPurchase(services)));
  if (syncAccountUuid(services.settings.syncState['accountData']) != null) unawaited(identifyPurchaser(services));
}

/// Tells the sync server about an active sync entitlement its account
/// doesn't yet reflect, then refreshes the account data. Runs after every
/// purchase and whenever the entitlements change: a purchase finished in a
/// browser, or on another device, or one whose hand-off failed, reaches the
/// server only this way.
///
/// Identifies the purchaser first: after an account switch the store still
/// answers for the previous account, whose purchase must not be handed to
/// the new one.
///
/// Returns the server's result (an `error` entry when it refused the
/// purchase — attached to another account, say), or null when there was
/// nothing to attach or the server couldn't be reached.
///
/// A call made while one is in flight shares its result: both would find the
/// account not yet subscribed, and send the purchase twice.
Future<Map<String, dynamic>?> attachSyncPurchase(HaLoServices services) => _attaching ??= _attachSyncPurchase(services).whenComplete(() => _attaching = null);

Future<Map<String, dynamic>?>? _attaching;

Future<Map<String, dynamic>?> _attachSyncPurchase(HaLoServices services) async {
  final purchases = services.purchases;
  if (!await identifyPurchaser(services)) return null;
  if (!purchases.entitlements.value.contains(syncEntitlement)) return null;
  if (syncAccountSubscribed(services.settings.syncState['accountData'])) return null;
  final reference = purchases.channelReference(syncEntitlement);
  if (reference == null) return null;
  final result = await services.extensions.syncCreateSubscription(reference);
  await services.extensions.syncAccountData();
  return result;
}

/// The server-notice action handler for [services]: a `donate` button opens
/// the supporter paywall where this build can take purchases.
void Function(String noticeKey, Map<String, dynamic> action) noticeActionHandler(HaLoServices services) =>
    (noticeKey, action) => handleNoticeAction(noticeKey, action, donate: services.purchases.isAvailable ? () => unawaited(_donate(services)) : null);

/// A notice has no screen of its own to answer on, so a paywall that can't
/// open says so over whatever is showing.
Future<void> _donate(HaLoServices services) async {
  if (await presentPaywall(services) != PurchaseResult.unavailable) return;
  final context = navigatorKey.currentContext;
  if (context == null || !context.mounted) return;
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(haloSnackBar(t.settings.syncPanel.purchaseUnavailable));
}
