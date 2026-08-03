// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:math';

/// Capped exponential backoff: doubles per attempt, capped at [cap]. Shared
/// by every reconnect/restart loop in the app (PusherService, ExtensionService)
/// so a retuned cap or clamp doesn't have to be remembered and re-applied in
/// more than one place. `attempt` is clamped before shifting — an uncapped
/// attempt counter would otherwise overflow `1 << attempt` into a negative
/// number well before it would ever matter for the delay itself.
Duration exponentialBackoff(int attempt, {required Duration cap}) {
  final seconds = 1 << attempt.clamp(0, 30);
  return Duration(seconds: min(cap.inSeconds, seconds));
}
