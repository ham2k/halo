// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// A rebuild requested from a notification that can arrive mid-build — a
/// focus change lands in a microtask, and on the first frame it comes from
/// autofocus while that frame is still building, where a `setState` is an
/// error.
///
/// Deferred only from INSIDE a build, the one phase that cannot take a
/// `setState`, rather than from every phase but idle: pushing a rebuild that
/// was safe now to the next frame makes the caller wait on a frame boundary
/// for nothing. The same rule the dock host and the status bar overlay
/// apply to their own late notifications.
mixin RebuildsBetweenFrames<T extends StatefulWidget> on State<T> {
  void rebuildBetweenFrames() {
    if (!mounted) return;
    if (WidgetsBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
      return;
    }
    setState(() {});
  }
}
