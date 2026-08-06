// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Extension point for distribution-specific OTA/code-push updates (not
// meaningful in an OSS build — updates come from the platform's app store or
// a manual download). The OSS app ships with a no-op implementation;
// `HaLoServices` accepts an override at construction time.

/// The code-push number running on top of `kBuildNumber` in this process, or
/// null when none is applied — including every build with no updater at all
/// (web, debug, plain `flutter build`).
///
/// A synchronous mirror of [UpdateService.currentPatchNumber], cached once by
/// `bootstrap()`, because the version displays that need it
/// (`views/version_label.dart`) are plain string builders reached from widgets
/// that hold no services. Safe to cache: a downloaded push applies only on the
/// next launch, so this value cannot change while the process runs.
int? currentCodePush;

abstract class UpdateService {
  /// Whether an over-the-air updater is actually present in this build. False
  /// for the no-op / OSS case and (for Shorebird) for any non-`shorebird
  /// release` build — debug, plain `flutter build`, web. UI that offers update
  /// controls should hide itself when this is false.
  bool get isAvailable;

  /// Checks for an update on the configured channel and downloads it if one is
  /// available. Returns true if an update was downloaded (it takes effect on
  /// the next restart, so the caller may want to prompt for one).
  Future<bool> checkAndApply();

  /// The patch/build number currently running, or null if none is installed or
  /// the updater is unavailable. Purely informational (e.g. Developer Settings).
  Future<int?> currentPatchNumber();
}

class NoopUpdateService implements UpdateService {
  const NoopUpdateService();

  @override
  bool get isAvailable => false;

  @override
  Future<bool> checkAndApply() async => false;

  @override
  Future<int?> currentPatchNumber() async => null;
}
