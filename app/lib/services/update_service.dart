// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Extension point for distribution-specific OTA/code-push updates (not
// meaningful in an OSS build — updates come from the platform's app store or
// a manual download). The OSS app ships with a no-op implementation;
// `HaLoServices` accepts an override at construction time.

abstract class UpdateService {
  /// Checks for an update and applies it if one is available. Returns true
  /// if an update was applied (the caller may want to prompt for a restart).
  Future<bool> checkAndApply();
}

class NoopUpdateService implements UpdateService {
  const NoopUpdateService();

  @override
  Future<bool> checkAndApply() async => false;
}
