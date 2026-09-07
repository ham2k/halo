// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';

/// A bare `notifyListeners()` signal for the dev commands that force-show a
/// startup overlay: `devSplashTrigger` (DEVSPLASH → release overlay),
/// `devOnboardTrigger` (DEVONBOARD → onboarding overlay) and
/// `devTesterTrigger` (DEVTESTER → tester overlay). Carries no state of its
/// own.
class DevOverlayTrigger extends ChangeNotifier {
  void trigger() => notifyListeners();
}
