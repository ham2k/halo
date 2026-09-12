// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// DEVHAMMER: status-bar churn on demand, for provoking the web engine's
// focus blur (ViewFocusGuard) when no real data-file sync will.

import 'package:halo_core/halo_core.dart' show realNowUtc;

import 'status_bar_service.dart';

class StatusBarHammer {
  final StatusBarService statusBar;

  StatusBarHammer(this.statusBar);

  /// How long DEVHAMMER churns for when the command doesn't say.
  static const defaultSeconds = 15;

  /// Set while a run is in flight, so a second DEVHAMMER doesn't interleave
  /// with the first — two runs share the same four keys, and the first to
  /// finish would clear the other's items out from under it.
  bool _running = false;

  /// Whether a run is in flight right now.
  bool get running => _running;

  /// Reproduces a data-file sync's churn on demand (DEVHAMMER): several items
  /// appearing, ticking and clearing, the way `DataFileManager` does one
  /// entry per file.
  ///
  /// This exists because that churn is what provokes the web engine into
  /// blurring the focused text field (see `ViewFocusGuard`), and the real
  /// thing only happens on a cold profile — once the files are cached a
  /// RELOAD finishes without churning at all, so there is nothing left to
  /// test a fix against. What matters is items COMING AND GOING: a single
  /// progress bar ticking on a stable key changes a label and provokes
  /// nothing.
  ///
  /// Returns false when a run is already in flight, so the caller can say so
  /// rather than echo a confirmation over nothing happening.
  Future<bool> run(int seconds) async {
    if (_running) return false;
    _running = true;
    try {
      // A beat before the first item, deliberately: the interesting case is
      // typing INTO the churn, and without this the tester is still reaching
      // for the keyboard while it runs.
      await Future<void>.delayed(const Duration(seconds: 1));
      const slots = 4;
      const tick = Duration(milliseconds: 120);
      // Real time: DEVHAMMER's point is to churn the UI for that many real
      // seconds while a tester types into it.
      final until = realNowUtc().add(Duration(seconds: seconds));
      var step = 0;
      while (realNowUtc().isBefore(until)) {
        final slot = step % slots;
        statusBar.setProgress(
          key: _key(slot),
          icon: 'progress-download',
          title: 'Hammer $slot',
          text: 'file $step',
          value: (step % 10) / 10,
        );
        // Retire a DIFFERENT slot: the one written two ticks ago, so frames
        // have gone by between its last write and its removal. Clearing the
        // slot just set, in the same breath and with no frame between, only
        // undoes the write — no item ever appears, so none ever leaves, and
        // leaving is the half that provokes anything. Offsetting by two also
        // takes every slot in turn; keying the clear off `step % 10` reached
        // only the odd ones.
        if (step >= slots) statusBar.clear(_key((slot + 2) % slots));
        step++;
        await Future<void>.delayed(tick);
      }
      for (var slot = 0; slot < slots; slot++) {
        statusBar.clear(_key(slot));
      }
      return true;
    } finally {
      _running = false;
    }
  }

  static String _key(int slot) => 'command:devHammer:$slot';
}
