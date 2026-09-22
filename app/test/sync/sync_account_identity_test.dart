// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The account identity shown in Settings is the EMAIL, never the callsign
// (HALO-81): callsigns describe operators, and several operators can share
// one account. These tests pin the precedence — a server-side pending email
// outranks the confirmed one, and an email-less account must still be
// identifiable ("Anonymous Account (#…)", app-polo's convention) rather
// than falling back to the callsign or showing nothing.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/tools/sync_account_identity.dart';

void main() {
  test('the email is the identity, even when a callsign is present', () {
    expect(syncAccountIdentity({'uuid': 'abc', 'call': 'N0CALL', 'email': 'me@example.com'}), 'me@example.com');
  });

  test('a pending email outranks the confirmed one, marked as pending', () {
    expect(syncAccountIdentity({'email': 'old@example.com', 'pending_email': 'new@example.com'}), 'new@example.com (pending confirmation)');
  });

  test('a pending email equal to the confirmed one is not pending at all', () {
    expect(syncAccountIdentity({'email': 'me@example.com', 'pending_email': 'me@example.com'}), 'me@example.com');
  });

  test('no email: anonymous, identified by the uuid prefix — not the callsign', () {
    expect(syncAccountIdentity({'uuid': '0a1b2c3d-4e5f-6789-abcd-ef0123456789', 'call': 'N0CALL'}), 'Anonymous Account (#0A1B2C3D)');
  });

  test('no identity material at all returns null for the caller to fall back', () {
    expect(syncAccountIdentity(const {}), isNull);
    expect(syncAccountIdentity(null), isNull);
  });

  test('includePending: false yields the confirmed email — for rows whose tap acts on it', () {
    expect(syncAccountIdentity({'email': 'old@example.com', 'pending_email': 'new@example.com'}, includePending: false), 'old@example.com');
  });

  // No "Linked as" prefix: the row is already titled "Account". The short id
  // rides along because it is what support asks for.
  test('label: an email-identified account is the email plus the short id', () {
    expect(
      syncAccountLabel({
        'current_account': {'uuid': '0a1b2c3d-4e5f', 'email': 'me@example.com'},
      }),
      'me@example.com (#0A1B2C3D)',
    );
  });

  // One parenthesis, not two back to back: the id joins the note the label
  // already carries rather than trailing its own "(#…)" after it.
  test('label: a pending email folds the short id into its own parenthesis', () {
    expect(
      syncAccountLabel({
        'current_account': {'uuid': '0a1b2c3d-4e5f', 'email': 'old@example.com', 'pending_email': 'new@example.com'},
      }),
      'new@example.com (pending confirmation - #0A1B2C3D)',
    );
  });

  test('label: a pending email with no uuid keeps the plain pending note', () {
    expect(
      syncAccountLabel({
        'current_account': {'email': 'old@example.com', 'pending_email': 'new@example.com'},
      }),
      'new@example.com (pending confirmation)',
    );
  });

  test('label: a pending email equal to the confirmed one is not pending', () {
    expect(
      syncAccountLabel({
        'current_account': {'uuid': '0a1b2c3d-4e5f', 'email': 'me@example.com', 'pending_email': 'me@example.com'},
      }),
      'me@example.com (#0A1B2C3D)',
    );
  });

  test('label: an email with no uuid to pair it with degrades to the bare email', () {
    expect(
      syncAccountLabel({
        'current_account': {'email': 'me@example.com'},
      }),
      'me@example.com',
    );
  });

  test('label: an anonymous account is NOT presented as linked — bare title, no prefix', () {
    expect(
      syncAccountLabel({
        'current_account': {'uuid': '0a1b2c3d-4e5f-6789-abcd-ef0123456789', 'call': 'N0CALL'},
      }),
      'Anonymous Account (#0A1B2C3D)',
    );
  });

  test('label: missing or malformed account data degrades to "Not linked yet", never throws', () {
    expect(syncAccountLabel(null), 'Not linked yet');
    expect(syncAccountLabel(const {}), 'Not linked yet');
    expect(syncAccountLabel({'current_account': 'garbage'}), 'Not linked yet');
  });
}
