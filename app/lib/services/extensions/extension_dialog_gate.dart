// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The one dialog surface every extension's `showForm` and `showMessage` open
// on, held to a budget: one extension's dialogs on screen at a time, a few of
// them one over the other, the other extensions' waiting their turn, and none
// opened in a loop. A form dialog is not barrier-dismissible and never times
// out, so without this a hook stacks modals the operator cannot get out from
// under, and two extensions prompting at once leave a pile to answer in an
// order neither meant.

import 'dart:async';
import 'dart:collection';

import 'package:halo_extension_host/halo_extension_host.dart';

class ExtensionDialogGate {
  /// How many dialogs one extension may have open at once, one over the
  /// other; how many of its opens may wait for another extension's to close —
  /// each of them one it will then have open, so no more than that; and how
  /// many it may open in a minute.
  static const maxOpen = 3, maxWaiting = 3, maxOpensPerMinute = 10;

  /// The extension whose dialogs are on screen, or whose turn it is.
  String? _owner;

  /// How many of [_owner]'s are open, the ones handed the surface and not yet
  /// resumed included.
  int _open = 0;

  /// The opens waiting for the surface, in the order they asked.
  final Queue<({String ns, Completer<void> turn})> _waiting = Queue();
  final Map<String, int> _waitingBy = {};
  final Map<String, RateWindow> _opens = {};

  /// Opens [ns]'s dialog through [open] — at once while no dialog is up or
  /// its own are, once theirs close while another extension's are — and
  /// completes with the dialog's answer when it closes. Refused with an
  /// [ExtensionHostException] past any budget, thrown at the call before
  /// anything is queued, so the extension sees why even where nobody awaits
  /// the dialog ([show]) and nothing it never asked for is queued on its
  /// behalf.
  Future<T> run<T>(String ns, Future<T> Function() open) {
    final waits = _owner != null && _owner != ns;
    if (waits && (_waitingBy[ns] ?? 0) >= maxWaiting) {
      throw ExtensionHostException("dialog refused: extension '$ns' already has $maxWaiting dialogs waiting for another extension's to close");
    }
    if (!waits && _open >= maxOpen) throw ExtensionHostException("dialog refused: extension '$ns' already has $maxOpen dialogs open");
    final opens = _opens[ns] ??= RateWindow(maxOpensPerMinute, const Duration(minutes: 1));
    if (!opens.admit()) throw ExtensionHostException("dialog refused: extension '$ns' has opened $maxOpensPerMinute dialogs in the last minute");
    return _run(ns, open, waits: waits);
  }

  /// [run] for a dialog nobody awaits: refused at the call the same way,
  /// opened when its turn comes, and never opened for an extension replaced
  /// while it waited — the call it answered is long gone, so nobody is told.
  void show(String ns, Future<void> Function() open) => unawaited(run(ns, open).catchError((_) {}, test: (error) => error is _Dropped));

  Future<T> _run<T>(String ns, Future<T> Function() open, {required bool waits}) async {
    if (waits) {
      final turn = Completer<void>();
      _waiting.add((ns: ns, turn: turn));
      _waitingBy[ns] = (_waitingBy[ns] ?? 0) + 1;
      // Counted among the open ones by the hand-off, before this resumes.
      await turn.future;
    } else {
      _owner = ns;
      _open++;
    }
    try {
      return await open();
    } finally {
      _open--;
      if (_open == 0) _free();
    }
  }

  /// Fails the opens waiting for [namespaces], whose extensions are being
  /// replaced: resumed later, one would put a dialog on screen for a runtime
  /// that no longer exists, its answer going to nobody.
  void drop(Iterable<String> namespaces) {
    final gone = namespaces.toSet();
    for (final entry in _waiting.where((entry) => gone.contains(entry.ns)).toList()) {
      entry.turn.completeError(_Dropped(entry.ns));
    }
    _waiting.removeWhere((entry) => gone.contains(entry.ns));
    for (final ns in gone) {
      _waitingBy.remove(ns);
    }
  }

  /// Hands the surface to the extension that has waited longest — every one
  /// of its waiting opens at once, as the dialogs it would have nested — or
  /// to nobody. Named and counted here, before any of them resumes, so a call
  /// of its own arriving in between is held to the same bound as theirs.
  void _free() {
    _owner = null;
    if (_waiting.isEmpty) return;
    final next = _waiting.first.ns;
    final turns = [
      for (final entry in _waiting)
        if (entry.ns == next) entry.turn,
    ];
    _waiting.removeWhere((entry) => entry.ns == next);
    _waitingBy.remove(next);
    _owner = next;
    _open = turns.length;
    for (final turn in turns) {
      turn.complete();
    }
  }
}

/// What [ExtensionDialogGate.drop] fails a waiting open with: the refusal a
/// call awaiting a form is answered, and what [ExtensionDialogGate.show]
/// keeps to itself.
class _Dropped extends ExtensionHostException {
  _Dropped(String ns) : super("dialog dropped: extension '$ns' was replaced while waiting for another extension's dialogs to close");
}
