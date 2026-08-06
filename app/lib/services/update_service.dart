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
///
/// Null alone is ambiguous — read [currentCodePushResolved] before drawing any
/// conclusion from it.
int? currentCodePush;

/// Whether [currentCodePush] is an ANSWER rather than an absence of one: true
/// once the read completed, including when it completed with "no push applied".
/// False when it threw or timed out.
///
/// The distinction only matters to the code-push floor
/// (`services/staleness.dart`), and it matters a lot there: treating an
/// unreadable number as zero nags an operator who is already up to date, and
/// no action available to them would make it stop. Everywhere else — the
/// version label, the notice environment — unknown and none render the same,
/// because neither can name a push number.
bool currentCodePushResolved = false;

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

  /// The code-push number currently running, paired with whether the read
  /// ANSWERED at all.
  ///
  /// The pair is the whole point: `resolved: true, number: null` means "no push
  /// applied", while `resolved: false` means "we could not tell". Returning a
  /// bare null for both — which a swallowed read exception does — collapses
  /// them, and the code-push floor then nags an operator who is fully up to
  /// date, with no action available that would make it stop
  /// (services/staleness.dart).
  Future<({bool resolved, int? number})> currentPatchNumber();
}

class NoopUpdateService implements UpdateService {
  const NoopUpdateService();

  @override
  bool get isAvailable => false;

  @override
  Future<bool> checkAndApply() async => false;

  @override
  // Resolved, and the answer is "none": a build with no updater has no code
  // push, which is a fact rather than a failure to establish one.
  Future<({bool resolved, int? number})> currentPatchNumber() async => (resolved: true, number: null);
}
