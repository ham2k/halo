// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The web half of halo_windows_tls.dart's conditional export: the browser
// verifies certificates itself, so there is nothing to recover.

/// No-op on web. See recovery.dart for the contract.
void installWindowsTlsRootRecovery({
  String userAgent = 'Ham2K Logger',
  void Function(String message)? onRecovered,
  void Function(Object error, StackTrace stackTrace)? onFailure,
}) {}
