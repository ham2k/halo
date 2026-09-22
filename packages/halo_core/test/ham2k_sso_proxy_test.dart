// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Which SOTA SSO calls a web build sends through services.ham2k.net.
//
// The rule this pins: no SSO traffic transits Ham2K infrastructure except the
// two paths below, on web, where a browser leaves no alternative. Proxying is
// what puts SOTA access and refresh tokens through a Ham2K host, so every
// case here is a way that boundary could widen without anyone deciding it
// should.

import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

const _token = 'https://sso.sota.org.uk/auth/realms/SOTA/protocol/openid-connect/token';
const _account = 'https://sso.sota.org.uk/auth/realms/SOTA/account';
const _discovery = 'https://sso.sota.org.uk/auth/realms/SOTA/.well-known/openid-configuration';

void main() {
  group('ham2kSsoFetchUri', () {
    test('a native build never proxies, not even the two web-proxied paths', () {
      // The whole cost of this feature is tokens transiting a Ham2K host, and
      // a native build has no reason to pay it: dart:io enforces no CORS.
      for (final url in [_token, _account, _discovery]) {
        expect(ham2kSsoFetchUri(Uri.parse(url), onWeb: false).toString(), url);
      }
    });

    test('a web build proxies the token exchange and the account check', () {
      expect(
        ham2kSsoFetchUri(Uri.parse(_token), onWeb: true).toString(),
        'https://services.ham2k.net/sso.sota.org.uk/auth/realms/SOTA/protocol/openid-connect/token',
      );
      expect(ham2kSsoFetchUri(Uri.parse(_account), onWeb: true).toString(), 'https://services.ham2k.net/sso.sota.org.uk/auth/realms/SOTA/account');
    });

    test('the discovery document is fetched from SOTA even on web', () {
      // It is CORS-open at the source, so proxying it would widen the
      // surface for nothing — and services.ham2k.net does not route it, so a
      // build that sent it there would 404 before the login even began.
      expect(ham2kSsoFetchUri(Uri.parse(_discovery), onWeb: true).toString(), _discovery);
    });

    test('an SSO path nobody registered stays direct rather than being proxied blind', () {
      // Routing is per-path, never per-host. `logout` and `userinfo` are real
      // Keycloak endpoints here: a host-wide rule would hand the Worker
      // traffic it has no entry for, and would let a future endpoint join the
      // proxied set without anyone choosing that.
      for (final path in ['/auth/realms/SOTA/protocol/openid-connect/logout', '/auth/realms/SOTA/protocol/openid-connect/userinfo']) {
        final url = 'https://sso.sota.org.uk$path';
        expect(ham2kSsoFetchUri(Uri.parse(url), onWeb: true).toString(), url);
      }
    });

    test('a lookalike host is not proxied, whichever way it is shaped', () {
      // Exact-host, and each fixture defeats a DIFFERENT sloppy check, which
      // is why one is not enough: an attacker who can stand up any of these
      // hostnames would otherwise have their traffic routed through — and
      // CORS-blessed by — a Ham2K origin.
      const lookalikes = [
        // beats `endsWith`
        'https://evil.sso.sota.org.uk/auth/realms/SOTA/account',
        // beats `startsWith`
        'https://sso.sota.org.uk.evil.example.com/auth/realms/SOTA/account',
        // beats `contains`
        'https://evil-sso.sota.org.uk.example.com/auth/realms/SOTA/account',
      ];
      for (final url in lookalikes) {
        expect(ham2kSsoFetchUri(Uri.parse(url), onWeb: true).toString(), url, reason: url);
      }
    });

    test('a query string survives the rewrite', () {
      expect(
        ham2kSsoFetchUri(Uri.parse('$_account?foo=bar%20baz'), onWeb: true).toString(),
        'https://services.ham2k.net/sso.sota.org.uk/auth/realms/SOTA/account?foo=bar%20baz',
      );
    });
  });
}
