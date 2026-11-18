// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The operations open in a view: what the command palette, deep links and
// extensions reach the operation in front through, which are open, and
// where a command's answer is said.

part of 'halo_services.dart';

mixin _OperationStack {
  StatusBarService get statusBar;
  CatService get cat;
  void updatePeerSharing();

  /// One open Operation View's command context, for the ⌘K dialog: the
  /// operation as command hooks expect it, plus the logging panel's action
  /// dispatcher while one is mounted.
  ///
  /// These live on a STACK rather than in a single slot, because open
  /// operations nest — the palette can open operation B from inside operation
  /// A. A slot cleared on dispose leaves A silently context-less after B pops,
  /// even though A's logging panel is still mounted and visible; a stack
  /// simply reveals A's entry again. Entries are removed by identity, so the
  /// same operation opened twice is two independent entries.
  final List<OperationCommandContext> _operationStack = [];

  /// The front-most open operation, as the `{...operation.data, 'uuid': …}`
  /// map command hooks expect (the uuid is what lets them reach
  /// `ctx.getOperation` / `ctx.getQsos`; see `logging_controls_fields.dart`'s
  /// `_operationDataForCommands`). Null wherever no operation is open: Home,
  /// Settings.
  ///
  /// The ⌘K command dialog reads this so operation-scoped commands (SEED,
  /// NOTE, SPOT) run against the open operation instead of coming back with
  /// their "needs an open operation" error. It exists because the operation is
  /// otherwise route-local state inside `OperationView`, which a global
  /// keyboard shortcut has no path to. When the app grows real multi-window
  /// support (docs/design/user-interface.md, "Future directions"), this
  /// becomes per-window rather than app-wide.
  Map<String, dynamic>? get currentOperationContext => _operationStack.isEmpty ? null : _operationStack.last.operation;

  /// The front-most logging panel's `CommandAction` dispatcher, or null when
  /// no operation is open.
  ///
  /// The QSO-scoped actions — `setVfo`, `addQso`, `updateQso`,
  /// `setCallField`, `sendSpots`, `autoRespot` — can only be applied by the widget that owns
  /// the in-progress QSO and its controllers. Without this a "20M" run from
  /// the ⌘K dialog interprets fine, returns `setVfo`, and then silently does
  /// nothing. Routing the whole batch through here instead makes a command
  /// from the palette behave exactly as if it had been typed into the call
  /// field — `LoggingControls`' dispatcher handles the app-scoped actions too.
  CommandActionsDispatcher? get currentCommandDispatch => _operationStack.isEmpty ? null : _operationStack.last.dispatch;

  /// The front-most open operation's stack entry, or null when none is open.
  ///
  /// How a `/qso` deep link reaches the operation the operator is already in
  /// rather than pushing a second copy of it. The whole entry, not just its
  /// `suggestQso`, because the caller also has to ask whether that operation
  /// is the visible route before deciding what to tell the operator. Same
  /// stack, same reasoning as [currentCommandDispatch].
  OperationCommandContext? get frontOperationContext => _operationStack.isEmpty ? null : _operationStack.last;

  /// The uuids of the operations open in a view, the front one last.
  List<String> get openOperationUuids => [for (final entry in _operationStack) entry.uuid];

  /// Where a command action's message goes: the command bar that is running a
  /// command right now, on its own response line, rather than the status bar
  /// (see [runCommandAction]). Returns whether it could show it.
  ///
  /// A sink here rather than a parameter because a command bar does NOT
  /// dispatch most commands itself: with an operation open the whole action
  /// batch goes to the front-most logging panel ([currentCommandDispatch]),
  /// whose own handler is the one that ends up calling [runCommandAction]. So
  /// the message comes back through code the bar never touches, and this is
  /// the only thing they share.
  ///
  /// Set for the duration of ONE command's dispatch by `CommandEngine`, not
  /// for a bar's lifetime: every action's message arrives inside that awaited
  /// window, and a slot held open longer catches messages from commands typed
  /// somewhere else entirely — a SPOT started in the call field, answering
  /// seconds later on a palette that has since opened, blanking the card and
  /// dismissing itself over a command the operator never typed there.
  bool Function(String message, {bool failed})? commandResponseSink;

  /// Says [outcome] where `runCommandAction` says an action's answer: the
  /// command bar waiting on it ([commandResponseSink]), else the status bar —
  /// also for an action a logging panel runs itself.
  void reportCommandOutcome(CommandActionOutcome outcome) {
    final sink = commandResponseSink;
    if (sink == null || !sink(outcome.text, failed: outcome.failed)) statusBar.setMessage(key: 'commandAction', text: outcome.text);
  }

  /// The last command response a ⌘K palette showed, and when that palette
  /// closed — what reopening it soon after puts back (command_dialog.dart).
  /// Kept here because every open is a fresh State.
  ({String text, bool failed})? lastPaletteResponse;
  int? lastPaletteClosedAt;

  /// Registers a newly opened Operation View and returns its entry, which the
  /// caller fills in as its operation loads and must pass back to
  /// [closeOperationContext] on dispose.
  OperationCommandContext openOperationContext(String uuid) {
    final entry = OperationCommandContext(uuid);
    _operationStack.add(entry);
    cat.frontOperation = uuid;
    updatePeerSharing();
    return entry;
  }

  /// Removes [entry] by identity, so a disposing view can never take a
  /// still-live one's place with it.
  void closeOperationContext(OperationCommandContext entry) {
    _operationStack.remove(entry);
    cat.frontOperation = _operationStack.lastOrNull?.uuid;
    updatePeerSharing();
  }
}
