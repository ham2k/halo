// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

/// Fixed diagnostic codes, never peer text, hostnames, identities or key bytes.
/// A failed handshake can mean authentication, version or cipher mismatch;
/// callers must not describe every handshake failure as an incorrect password.
class PskTlsException implements Exception {
  final String code;
  const PskTlsException(this.code);
  @override
  String toString() => 'TLS-PSK: $code';
}

class PskTlsCancelledException extends PskTlsException {
  const PskTlsCancelledException() : super('cancelled');
}
