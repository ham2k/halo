// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import '../i18n/strings.g.dart';

/// The user-facing identity of a LoFi account map (`current_account` or an
/// entry in `accounts`): the email IS the identity — callsigns describe
/// operators, not accounts, and several operators can share one account.
/// A server-side `pending_email` (not yet confirmed) shows first, marked as
/// pending — unless [includePending] is false, for rows whose tap acts on
/// the confirmed email and must not display an address the action won't
/// use. An account with no email at all is "Anonymous Account (#XXXXXXXX)"
/// with the uuid's first 8 characters, the same convention app-polo uses.
/// Returns null when the map carries none of those (an empty placeholder
/// while account data is still loading, or a failed fetch).
String? syncAccountIdentity(Map? account, {bool includePending = true}) =>
    _emailIdentity(account, includePending: includePending) ?? _anonymousIdentity(account);

/// The one-line account description shared by the Sync panel and the All
/// Settings sync group, from the whole `getAccountData` payload: "Linked as
/// <email>" when an email identifies the account, the bare anonymous label
/// for an email-less account (the auto-created account every device gets is
/// not presented as "linked" — app-polo shows the same bare title), or
/// "Not linked yet" when there is no account data at all.
String syncAccountLabel(Object? accountData) {
  final current = accountData is Map ? accountData['current_account'] : null;
  final account = current is Map ? current : null;
  final email = _emailIdentity(account, includePending: true);
  if (email != null) return t.settings.syncPanel.linkedAs(account: email);
  return _anonymousIdentity(account) ?? t.settings.syncPanel.notLinked;
}

String? _emailIdentity(Map? account, {required bool includePending}) {
  final email = _field(account, 'email');
  if (includePending) {
    final pending = _field(account, 'pending_email');
    if (pending != null && pending != email) return t.syncAccount.pendingConfirmation(email: pending);
  }
  return email;
}

String? _anonymousIdentity(Map? account) {
  final uuid = _field(account, 'uuid');
  if (uuid == null) return null;
  final id = uuid.length > 8 ? uuid.substring(0, 8) : uuid;
  return t.syncAccount.anonymous(id: id.toUpperCase());
}

String? _field(Map? account, String key) {
  final value = account?[key];
  return value is String && value.isNotEmpty ? value : null;
}
