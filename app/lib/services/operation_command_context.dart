// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:halo_widgets/halo_widgets.dart' show CommandActionsDispatcher;

/// One open Operation View's contribution to the ⌘K dialog's context — see
/// `HaLoServices.openOperationContext`.
class OperationCommandContext {
  OperationCommandContext(this.uuid);

  final String uuid;

  /// The operation QSON with `uuid` folded in, once it has loaded.
  Map<String, dynamic>? operation;

  /// Who is operating it from this device (`operatorCallFor`), which the
  /// QSON alone cannot say: a multi-op position lives in `localData`.
  String? operatorCall;

  /// This operation's logging panel dispatcher, while one is mounted.
  CommandActionsDispatcher? dispatch;

  /// Puts a QSON-shaped suggestion into this operation's logging fields — the
  /// same prefill a tapped spot performs (`OperationView`'s `_suggestQso`).
  ///
  /// Here rather than as a [CommandActionsDispatcher] action because a
  /// suggestion is not a command: it arrives from outside the operation
  /// entirely (a `/qso` deep link), carries refs and radio state together, and
  /// must reach the view even when no logging panel is mounted to dispatch
  /// through — which is exactly when [dispatch] is null.
  void Function(Map<String, dynamic> qso)? suggestQso;

  /// Whether this operation is the route the operator is actually looking at.
  /// False with Settings, or a nested operation, pushed over it — where a
  /// suggestion still lands correctly but nothing on screen shows it.
  bool Function()? isVisible;
}
