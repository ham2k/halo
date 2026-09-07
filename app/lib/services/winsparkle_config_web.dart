// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The web half of winsparkle_config.dart's conditional export: no `dart:ffi`,
// no WinSparkle, nothing to configure. Required as the export's default —
// see serial_transport_unsupported.dart for the same role.

/// No-op on web. See the io implementation for the contract.
bool configureWinSparkleBeforeInit({
  required String buildVersion,
  required int checkIntervalSeconds,
  required bool automaticChecks,
}) =>
    false;
