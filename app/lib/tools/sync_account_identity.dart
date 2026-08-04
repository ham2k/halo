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
/// Settings sync group, from the whole `getAccountData` payload: the email
/// followed by the account's short id when an email identifies the account,
/// the bare anonymous label (which already carries that id) for an
/// email-less account, or "Not linked yet" when there is no account data at
/// all. The id belongs on the row because it is what support asks for; no
/// "Linked as" prefix — the row is already titled "Account".
///
/// A pending email folds the id into the one parenthesis it already carries —
/// "(pending confirmation - #XXXXXXXX)" — rather than trailing a second set
/// after the first.
String syncAccountLabel(Object? accountData) {
  final current = accountData is Map ? accountData['current_account'] : null;
  final account = current is Map ? current : null;
  final id = _shortId(account);

  final pending = _pendingEmail(account);
  if (pending != null) {
    return id == null
        ? t.syncAccount.pendingConfirmation(email: pending)
        : t.syncAccount.pendingConfirmationWithId(email: pending, id: id);
  }

  final email = _field(account, 'email');
  if (email != null) {
    return id == null ? email : t.settings.syncPanel.linkedAccount(account: email, id: id);
  }
  return _anonymousIdentity(account) ?? t.settings.syncPanel.notLinked;
}

String? _emailIdentity(Map? account, {required bool includePending}) {
  if (includePending) {
    final pending = _pendingEmail(account);
    if (pending != null) return t.syncAccount.pendingConfirmation(email: pending);
  }
  return _field(account, 'email');
}

/// The address awaiting confirmation, or null when there is none — a
/// `pending_email` equal to the confirmed one is not a change in flight.
String? _pendingEmail(Map? account) {
  final pending = _field(account, 'pending_email');
  return pending == _field(account, 'email') ? null : pending;
}

String? _anonymousIdentity(Map? account) {
  final id = _shortId(account);
  if (id == null) return null;
  return t.syncAccount.anonymous(id: id);
}

/// The uuid's first 8 characters, upper-cased — app-polo's convention, and
/// short enough to read aloud to support.
String? _shortId(Map? account) {
  final uuid = _field(account, 'uuid');
  if (uuid == null) return null;
  return (uuid.length > 8 ? uuid.substring(0, 8) : uuid).toUpperCase();
}

String? _field(Map? account, String key) {
  final value = account?[key];
  return value is String && value.isNotEmpty ? value : null;
}
