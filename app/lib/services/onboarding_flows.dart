// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'settings_service.dart';

/// Flow ids for [SettingsService.onboardingShownCount] /
/// [SettingsService.recordOnboardingShown].
abstract final class OnboardingFlows {
  /// The app's first-run overlay.
  static const firstUse = 'first-use';

  /// The operation sheet, auto-opened once for a user who's never seen it —
  /// independent of (and in addition to) the existing new-operation auto-open.
  static const operationSheet = 'operation-sheet';

  /// Not an overlay: counts new operations opened, so the home FAB's nudge
  /// (see `_NewOperationNudge`) knows when to stop.
  static const newOperation = 'new-operation';

  /// Not an overlay either: counts ⌘K command-dialog opens, so the dialog
  /// knows when to stop offering sample commands on an empty field (see
  /// `CommandDialog._suggestionsThreshold`). Someone who has opened it a
  /// dozen times knows what's in there.
  static const commandDialog = 'command-dialog';

  /// The Cloud Sync question, asked on its own of an install whose sync is
  /// off without the operator having chosen it (see
  /// [SettingsService.cloudSyncPromptDue]). Non-zero once it is answered —
  /// the question dismissed, or a sync toggle made anywhere — and then it is
  /// never asked again; written only while zero, so it reads 0 or 1.
  static const cloudSync = 'cloud-sync';
}
