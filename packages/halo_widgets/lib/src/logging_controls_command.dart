// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The call field doubles as a command line: "14285 ", "20m ", "cw ", "NOTE
// Called Bob", "//KEY". What the panel knows about the command being typed —
// the debounced describe preview, the interpretation retained for the
// field's input mode, the message the info area shows and the timer that
// clears a confirmation — lives here. Running a command is the panel's:
// `LoggingControls._log` dispatches the actions, and reports back through
// [CommandInterpretationModel.showError] and [commandExecuted].

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:halo_core/halo_core.dart';

import 'call_field_text.dart';
import 'logging_controls_types.dart';
import 'panel_model.dart';

/// What the model reads from the panel's live configuration — re-read on
/// every use rather than copied in, because the hook, the edited QSO and the
/// operation all change under a mounted panel.
typedef CommandConfig = ({
  CommandInterpreter? interpretCommand,
  Qso? editingQso,
  Map<String, dynamic> Function() operationData,
  ValueChanged<String?>? onMessageChanged,
});

/// The command being typed into the call field. See the file comment.
class CommandInterpretationModel extends ChangeNotifier with PanelModel {
  CommandInterpretationModel({
    required this.config,
    required this.callText,
    required this.qsoData,
  });

  /// The panel's configuration as it stands right now.
  final CommandConfig Function() config;

  /// The call field as the panel reads it, taken fresh on every read.
  final CallFieldText Function() callText;

  /// The QSO being composed, as the hooks see it.
  final Map<String, dynamic> Function() qsoData;

  /// The latest interpret() result for the live text, for the describe
  /// preview and the submit button. Reset synchronously on every keystroke.
  Map<String, dynamic>? _current;

  /// The last interpret() result retained for the call field's INPUT MODE —
  /// deliberately a separate field from [_current], which resets
  /// synchronously on every keystroke (for the describe-message UI): the
  /// field's formatters/capitalization must not flicker back to
  /// uppercase-only between keystrokes while a command's parameters are
  /// still being typed. Updated only through [_retain]; reset when the field
  /// empties, on log/wipe, and whenever a QSO context is populated (spot tap,
  /// edit selection, undo restore). One retained map instead of parallel
  /// per-flag booleans, so a reset site can't clear one flag and miss
  /// another.
  Map<String, dynamic>? _retained;

  /// The message the info area shows for the command — a describe preview,
  /// an error, or a confirmation that clears itself.
  String? _message;

  Timer? _describeDebounce;
  Timer? _messageTimer;
  StreamSubscription<Map<String, dynamic>>? _updatesSub;

  /// The mid-stack expansion input ("//W1AW") already spent on the draft
  /// being composed — a key expands AT MOST ONCE per entry.
  ///
  /// The escape hatch for a note key that is also a real callsign, the
  /// common case for a stacked segment: without it, restoring the segment
  /// to the key (deleting what the expansion added) and pressing Enter just
  /// expands it again, so that station could never be logged on its own. A
  /// whole-field "//KEY" needs no such hatch and doesn't consult this —
  /// there the "//" is the operator explicitly asking to expand, where in a
  /// stack it's only the separator between calls.
  ///
  /// Reset wherever the draft itself is (log/wipe, the field emptying, a QSO
  /// context being populated), so the same key expands freely on the next
  /// entry — never on a mere keystroke, which would defeat the hatch by
  /// forgetting the expansion the operator just undid.
  String? _lastExpandedInput;

  /// The panel expanded [input] into the draft — see [_lastExpandedInput].
  void markExpanded(String input) => _lastExpandedInput = input;

  /// The command input that would expand [stack]'s cursor segment, or null
  /// — see [CallFieldText.expansionInputFor]; this is the one place that
  /// knows which key the draft has already spent.
  String? expansionInputFor(StackSegments stack) =>
      callText().expansionInputFor(stack, alreadyExpanded: _lastExpandedInput);

  /// The command input that would expand the stacked segment under the
  /// cursor right now, or null when the field isn't a stack, no command
  /// hooks are wired, the operator is editing, or the cursor sits on an
  /// empty segment.
  String? get stackExpansionInput {
    final cfg = config();
    if (cfg.editingQso != null || cfg.interpretCommand == null) return null;
    final text = callText();
    if (!text.isStack) return null;
    return expansionInputFor(text.stackSegments());
  }

  /// The last message pushed to the host, so the callback only fires on a
  /// real change. Firing `null` unconditionally per keystroke makes the
  /// parent (LoggingPanel) answer with a setState that rebuilds the whole
  /// QsoList — day-bucketing, per-column TextPainter measurement, the scores
  /// map, all O(n) over the log, per keystroke. Starts null, matching the
  /// parent's own initial "no message" state, so a redundant null is a no-op.
  String? _lastSentMessage;

  /// Matches text the callsign-mode formatters would pass through except
  /// for case — see [_retain].
  static final _callsignModeSafeText = RegExp('^[$callsignCharacters]*\$');


  // ---- What the panel reads ----

  Map<String, dynamic>? get current => _current;
  String? get message => _message;

  /// Whether the call field is in command free-text mode — space is a
  /// literal character and the callsign character filter is lifted, but
  /// input stays uppercase-only unless [mixedCase] also holds. Two ways in,
  /// both requiring a retained command:
  /// - the command is a recognized prefix still awaiting its parameters
  ///   ("RELOAD" before its target — `expectsParams`), or
  /// - the text already holds characters the callsign formatters would
  ///   destroy (a space, mid-parameter). Without this, a typing pause after
  ///   "EXP L" lets the debounced interpret retain a COMPLETE
  ///   interpretation (token "L"), and the returning callsign filter would
  ///   rewrite the whole field on the very next keystroke — "EXP LA"
  ///   snapping to "EXPLA". Same guard [_retain] applies to the null-result
  ///   path, for the same reason.
  bool get expectsParams =>
      _retained != null && (_retained!['expectsParams'] == true || !_callsignModeSafeText.hasMatch(callText().text));

  /// Whether the retained command declared `mixedCase: true` — only such
  /// commands (e.g. NOTE, whose parameter is free prose) release the call
  /// field from its uppercase-only rule. Extensions return it on BOTH the
  /// bare-prefix and complete results (see CommandInterpretation in the SDK
  /// types), so it stays in effect while "NOTE Hello…" keeps being typed.
  bool get mixedCase => _retained?['mixedCase'] == true;

  /// Whether the call field is currently taking spaces as literal characters
  /// rather than as "next field". The single source of truth for that
  /// question: the field's `inputFormatters` pick the space-accepting
  /// interceptor on exactly this condition, and the panel's Space handler
  /// decides the double-space exit on it, so the two can't drift into
  /// disagreeing about which mode the field is in.
  bool get fieldAcceptsSpaces => mixedCase || expectsParams;

  /// Whether the call field holds a recognized command that the log path
  /// would act on — as opposed to a callsign, an incomplete command still
  /// awaiting its parameters (`expectsParams`), or plain text. Drives the
  /// submit button so it accepts a command the same way Enter already does.
  /// The button is otherwise gated on the panel's `_canLog`, which is false
  /// for a command because a command isn't a valid callsign — so on mobile,
  /// where this button is the primary submit affordance, a command could
  /// only be run from the on-screen keyboard's return key.
  ///
  /// Reads the same interpretation state the describe-message UI does, so the
  /// button enables in step with the command preview appearing. The log path
  /// re-interprets the live text when actually run, so a momentarily stale
  /// retained value here at worst enables the button for an
  /// interpret-and-fall-through no-op, never a wrong action.
  bool get hasExecutableCommand {
    final cfg = config();
    if (cfg.editingQso != null || cfg.interpretCommand == null || callText().call.isEmpty) {
      return false;
    }
    final interpretation = _current ?? _retained;
    return interpretation != null && interpretation['expectsParams'] != true;
  }

  /// The replacement text an interpretation's `setCallField` action carries,
  /// or null for anything else. Only that one action can be spliced into a
  /// single stacked segment; every other action is field-wide (or has
  /// nothing to do with the call field at all) and stays the whole-field
  /// command path's business.
  static String? expandedCallText(Map<String, dynamic>? interpretation) {
    if (interpretation == null || interpretation['error'] is String) return null;
    final commands = interpretation['commands'];
    if (commands is! List || commands.length != 1) return null;
    final action = commands.single;
    if (action is! Map || action['setCallField'] is! Map) return null;
    final text = (action['setCallField'] as Map)['text'];
    return (text is String && text.trim().isNotEmpty) ? text : null;
  }

  // ---- Lifecycle ----

  /// Subscribes to [updates] — a command hook pushing a later interpretation
  /// for an input it was already asked about (issue #189).
  void bind(Stream<Map<String, dynamic>>? updates) {
    _updatesSub = updates?.listen(_onUpdate);
  }

  @override
  void dispose() {
    _describeDebounce?.cancel();
    _messageTimer?.cancel();
    _updatesSub?.cancel();
    super.dispose();
  }

  /// Pushes a command message to the parent, but only when it actually
  /// changed — see [_lastSentMessage].
  void _notifyMessage(String? message) {
    if (_lastSentMessage == message) return;
    _lastSentMessage = message;
    config().onMessageChanged?.call(message);
  }

  // ---- Forgetting ----

  /// The operator typed: whatever was shown for the previous text is gone,
  /// the preview in flight is cancelled, and the host hears the message is
  /// empty. The retained input mode stands — see [_retained]. Mutates only;
  /// the call-field listener rebuilds on its own account.
  void keystroke() {
    _describeDebounce?.cancel();
    _messageTimer?.cancel();
    _current = null;
    _message = null;
    _notifyMessage(null);
  }

  /// The field emptied: the input mode and the spent expansion go with the
  /// draft. The caller owns the rebuild.
  bool get hasRetained => _retained != null;
  void forgetRetained() {
    _retained = null;
    _lastExpandedInput = null;
  }

  /// Everything the draft accumulated: a wipe, a log, a QSO context being
  /// populated. Command state must never survive into a freshly populated
  /// QSO context — a preview still in flight for the old text, or a
  /// confirmation's clear timer, included. The caller owns the rebuild.
  void reset() {
    _describeDebounce?.cancel();
    _messageTimer?.cancel();
    _message = null;
    _current = null;
    _retained = null;
    _lastExpandedInput = null;
  }

  // ---- Interpreting ----

  /// Folds a fresh interpret() result into [_retained]. A non-null result
  /// always replaces the previous one. A null result (the text no longer
  /// matches any command) only clears it when the current text would survive
  /// the returning callsign formatters: those rewrite the ENTIRE field on the
  /// next keystroke, so snapping back while it holds free prose ("NOT Called
  /// Bob" after backspacing a typo in "NOTE") would irrecoverably strip every
  /// space. Uppercasing alone is the field's normal behavior, so case
  /// differences don't block the reset — only characters the filter would
  /// delete do. The retained mode then clears via the empty-field/log/wipe/
  /// populate resets instead.
  void _retain(Map<String, dynamic>? result) {
    if (result != null) {
      _retained = result;
    } else if (_callsignModeSafeText.hasMatch(callText().text)) {
      _retained = null;
    }
  }

  /// Applies an interpret() result (or an [_onUpdate] push) to the
  /// retained/displayed state — describe preview or error only, never
  /// `commands`: dispatching those is the log path's job alone, gated on the
  /// user actually pressing Enter, not on a command merely being interpreted.
  void apply(Map<String, dynamic>? result) {
    _current = result;
    _retain(result);
    if (result != null && result['describe'] is String) {
      _message = result['describe'] as String;
    } else if (result != null && result['error'] is String) {
      _message = result['error'] as String;
    } else {
      _message = null;
    }
    notify();
    _notifyMessage(_message);
  }

  /// A command hook pushed a later interpretation for an input it was
  /// already asked to interpret (issue #189) — see `LoggingControls.
  /// interpretationUpdates`'s doc. Applied only while `input` still matches
  /// the live call field; a push for input the user has since typed past is
  /// silently dropped, same staleness idiom the describe debounce uses for
  /// its awaited result.
  void _onUpdate(Map<String, dynamic> event) {
    if (isDisposed || config().editingQso != null) return;
    if (event['input'] != callText().commandInput) return;
    final interpretation = (event['interpretation'] as Map?)?.cast<String, dynamic>();
    apply(interpretation);
  }

  /// Asks the hook about [input] as it stands — a preview, or with [execute]
  /// the interpretation whose `commands` are the real ones (see
  /// CommandHook.interpret's `execute` doc). The one place the hook's
  /// argument list is assembled.
  Future<Map<String, dynamic>?> interpret(String input, {bool execute = false}) {
    final cfg = config();
    return cfg.interpretCommand!(input, cfg.operationData(), qsoData(), execute);
  }

  /// Schedules the describe preview for the text as it stands — command
  /// shortcuts only apply while composing a new QSO, so this is a no-op
  /// while editing, or with no hook wired.
  void scheduleDescribe() {
    final cfg = config();
    if (cfg.editingQso != null || cfg.interpretCommand == null) return;
    final text = callText();
    final call = text.call;
    final rawInput = text.commandInput;
    final expansionInput = stackExpansionInput;
    // One preview in flight at a time: a second arming would leave the
    // first timer's handle unreachable, and its answer racing this one's.
    _describeDebounce?.cancel();
    _describeDebounce = Timer(const Duration(milliseconds: 150), () async {
      final result = await interpret(rawInput);
      if (isDisposed || callText().call != call) return;
      apply(result);
      // A key stacked alongside other calls ("KI2D//1AB") is never a
      // command in its own right, so the whole-field interpretation above
      // came back null — preview what Enter would expand the segment
      // under the cursor to (see the panel's `_expandStackedNote`). Only the
      // describe MESSAGE is adopted, never the interpretation itself: the
      // log path executes a retained interpretation against the whole
      // field, which would replace the entire stack instead of the one
      // segment.
      if (result != null || expansionInput == null) return;
      final expansion = await interpret(expansionInput);
      if (isDisposed || callText().call != call || stackExpansionInput != expansionInput) return;
      if (expandedCallText(expansion) == null) return;
      _message = expansion!['describe'] as String?;
      notify();
      _notifyMessage(_message);
    });
  }

  /// The interpretation Space and Enter act on — synchronously (awaited)
  /// rather than trusting whatever the debounced describe-preview last
  /// resolved to: that state can lag up to 150ms behind the latest
  /// keystroke, so typing "RELOAD" and hitting space in one fluent motion
  /// could otherwise still see the pre-keystroke (stale, not-yet-a-command)
  /// interpretation. Reuses [current] when the debounce already resolved for
  /// this exact text, so this only adds a round trip when genuinely needed.
  ///
  /// `stale` is true when the call changed while awaiting — the caller
  /// abandons whatever it was doing. [applyToDisplay] shows the fresh
  /// answer as the preview would have (Space); Enter leaves the display
  /// alone, since it is about to act on the answer.
  Future<({Map<String, dynamic>? interpretation, bool stale})> interpretNow({required bool applyToDisplay}) async {
    // Cancelled before the cache is consulted: an answer the debounce would
    // land a moment later must not overwrite what the caller is about to
    // show for the same text.
    _describeDebounce?.cancel();
    var result = _current;
    if (result != null) return (interpretation: result, stale: false);
    final call = callText().call;
    result = await interpret(callText().commandInput);
    if (isDisposed || callText().call != call) return (interpretation: null, stale: true);
    if (applyToDisplay) apply(result);
    return (interpretation: result, stale: false);
  }

  /// Interprets for execution — the debounce-time preview's `commands` a hook
  /// like SEED deliberately leaves cheap/empty (see CommandHook.interpret's
  /// `execute` doc), so the log path re-interprets with `execute: true` now
  /// that it is actually about to run them.
  Future<Map<String, dynamic>?> interpretForExecution() => interpret(callText().commandInput, execute: true);

  // ---- What running a command reports back ----

  /// A recognized command that can't run (its `error` is set — see
  /// CommandInterpretation): the message is shown and the typed input kept
  /// for editing. A confirm-clear timer from a previous command would wipe
  /// this message moments after it appears — the error owns the slot now.
  void showError(String error) {
    _messageTimer?.cancel();
    _message = error;
    notify();
    _notifyMessage(_message);
  }

  /// The command ran. Its `confirm` markdown, when it carries one, shows for
  /// five seconds; otherwise the message clears.
  void commandExecuted({required Object? confirm}) {
    _current = null;
    _messageTimer?.cancel();
    if (confirm is String) {
      _message = confirm;
      _messageTimer = Timer(const Duration(seconds: 5), () {
        if (isDisposed) return;
        _message = null;
        notify();
        _notifyMessage(null);
      });
    } else {
      _message = null;
    }
    notify();
    _notifyMessage(_message);
  }
}
