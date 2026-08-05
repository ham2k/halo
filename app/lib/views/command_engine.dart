// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The lookup-and-command engine behind the two places a user can type a
// callsign or a command outside the logging panel: the Home view's Quick
// Lookup bar (`HomeQuickLookup`) and the ⌘K command dialog
// (`CommandDialog`). Both need the same non-obvious behavior — the debounce
// split (150ms describe preview vs 300ms lookup), the retained
// interpretation that keeps spaces legal mid-command,
// `expectsParams`/`mixedCase`, the second `execute: true` interpret call
// before dispatch (so a hook like SEED builds its real commands instead of a
// stale cheap preview), and the error-vs-confirm message states. A second
// copy would drift.
//
// This owns state and timing only. Both callers render it themselves: the
// Home bar shows a single message line, the dialog a list of results.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';

import '../main.dart';

/// How far the callsign lookup has got. The dialog shows each stage: a
/// "looking up" line the moment the text reads as a callsign, then whatever
/// the offline pass found, then the full online result.
enum CallLookupStage {
  /// The text isn't a callsign, so nothing is being looked up.
  none,

  /// Recognized as a callsign; nothing has come back yet.
  searching,

  /// The offline pass answered — local data files, back in milliseconds.
  /// Usually a country and maybe a name; worth showing while the network
  /// sources are still in flight.
  offline,

  /// The online pass answered too. Nothing more is coming.
  complete,
}

/// How the current [CommandEngine.message] should read.
enum CommandMessageKind {
  /// A live `describe` preview of what the typed command would do.
  describe,

  /// A recognized command that can't run in the current context (an
  /// operation-scoped one with no operation open). Never executed; the typed
  /// input stays for editing.
  error,

  /// A `confirm` from a command that just ran. Clears itself after 5s.
  confirmation,
}

/// Drives callsign lookup and command interpretation for one text field.
///
/// Attach it to a [TextEditingController] with [attach]; it listens for
/// changes itself. Call [submit] on Enter. Listeners are notified whenever
/// anything a caller renders changes.
class CommandEngine extends ChangeNotifier {
  final HaLoServices services;

  /// The operation the typed command should run against, as
  /// `{...operation.data, 'uuid': operation.uuid}` — the same shape
  /// `logging_controls.dart` passes, which command hooks need to reach
  /// `ctx.getOperation`/`ctx.getQsos` (dev-commands' SEED reads the log
  /// through it). Null on the Home screen, where no operation is open:
  /// operation-scoped hooks then answer with their `error` instead of
  /// pretending to succeed.
  ///
  /// A callback, not a value, because the dialog reads the *current*
  /// operation at the moment a command runs.
  final Map<String, dynamic>? Function() operationContext;

  /// Invoked after a command's actions have been dispatched. The dialog
  /// closes itself here; the Home bar does nothing.
  final void Function()? onExecuted;

  /// Whether Enter on text that matched no command should wipe the field.
  ///
  /// True for the Home bar, where Enter reads as "clear this search". False
  /// for the ⌘K dialog, where the text is usually a callsign whose lookup is
  /// on screen — clearing it there throws away the very thing the user just
  /// asked for, and drops the palette back to its suggestions.
  final bool clearOnNoMatch;

  /// Runs one dispatched `CommandAction`. Defaults to the app-wide
  /// [runCommandAction], which needs a `State` for its mounted check —
  /// callers pass their own so a message lands on the right widget.
  final Future<void> Function(String action, Map<String, dynamic>? params) runAction;

  CommandEngine({
    required this.services,
    required this.operationContext,
    required this.runAction,
    this.onExecuted,
    this.clearOnNoMatch = true,
  });

  TextEditingController? _controller;

  String? _message;
  CommandMessageKind _messageKind = CommandMessageKind.describe;

  Map<String, dynamic>? _currentInterpretation;
  Timer? _commandDescribeDebounce;
  Timer? _executeMessageTimer;
  Timer? _lookupDebounce;

  String? _lookupFor;
  Map<String, dynamic>? _lookupResult;
  CallLookupStage _lookupStage = CallLookupStage.none;
  Map<String, dynamic>? _lookupGuess;
  List<Map<String, dynamic>> _lookupRecords = const [];

  /// The last interpret() result retained for the field's space-restriction
  /// — deliberately separate from [_currentInterpretation], which resets
  /// synchronously on every keystroke (for the describe-message UI): the
  /// field's formatter must not snap back to denying spaces mid-command.
  /// Same "retained interpretation" pattern as
  /// `logging_controls.dart`'s call field, scoped down to just spaces since
  /// these fields otherwise accept any character.
  Map<String, dynamic>? _retainedInterpretation;

  /// Matches text the space-denying formatter would leave untouched — see
  /// [_retainInterpretation].
  static final _noSpaceSafeText = RegExp(r'^\S*$');

  /// The raw field text this engine last reacted to. A
  /// [TextEditingController] notifies its listeners for SELECTION changes as
  /// well as text changes, so without this every caret move — a tap into the
  /// field, an arrow key, a click to reposition — would re-run the whole
  /// interpret-and-lookup cycle for text that had not changed at all.
  String _lastText = '';

  /// The message to show right now, or null for none.
  String? get message => _message;

  /// How [message] should read.
  CommandMessageKind get messageKind => _messageKind;

  /// Whether [message] is a recognized-but-unrunnable command's error.
  bool get isError => _message != null && _messageKind == CommandMessageKind.error;

  /// Whether [message] is a just-executed command's confirmation.
  bool get isConfirmation => _message != null && _messageKind == CommandMessageKind.confirmation;

  /// The live interpretation of what's typed, or null when nothing matched.
  Map<String, dynamic>? get currentInterpretation => _currentInterpretation;

  /// How far the callsign lookup has got — see [CallLookupStage].
  CallLookupStage get lookupStage => _lookupStage;

  /// The callsign currently being looked up, or null when the text isn't one.
  String? get lookupCall => _lookupStage == CallLookupStage.none ? null : _lookupFor;

  /// The merged lookup guess, for `CallInfoPanel`. Null until something
  /// answers.
  Map<String, dynamic>? get lookupGuess => _lookupGuess;

  /// The individual lookup records, for data the merge doesn't fold into the
  /// guess — notably call-notes' `notes` array. Also for `CallInfoPanel`.
  List<Map<String, dynamic>> get lookupRecords => _lookupRecords;

  /// Whether the field is mid-command free-text entry — spaces stay
  /// allowed. Two ways in, both requiring a retained command: it's still
  /// awaiting its parameters (`expectsParams`), or the text already holds a
  /// space the formatter would otherwise delete on the next keystroke.
  bool get commandExpectsParams {
    final retained = _retainedInterpretation;
    if (retained == null) return false;
    // Tied to the command word, for the reason spelled out on
    // [commandMixedCase]: the retained map outlives the command it came from
    // whenever someone types steadily. Without this, selecting all after a
    // RELOAD and typing a callsign keeps `expectsParams` true for every
    // character, and a space lands in the middle of the call.
    if (retained['expectsParams'] == true && _commandWord(_text) == _retainedCommandWord) return true;
    // Not command-identity-dependent: a space already in the field is a fact
    // about the text, and the formatter would eat it on the next keystroke.
    return !_noSpaceSafeText.hasMatch(_text);
  }

  /// True while an execute-time interpret is in flight. A command's execute
  /// call may be a non-idempotent network write (REPORT files a CaBo card), so
  /// a second Enter during the round trip would file it twice.
  bool _submitting = false;

  /// Whether the retained command declared `mixedCase: true` (e.g. NOTE,
  /// whose parameter is free prose) — also keeps spaces allowed.
  ///
  /// Tied to the command word it was retained for. The retained interpretation
  /// is only revised inside the describe debounce, which restarts on every
  /// keystroke and so never fires while someone types steadily — so after a
  /// NOTE, selecting all and typing a callsign straight through would keep the
  /// stale flag for every character and leave the call in lower case, with no
  /// uppercase pass left to correct it.
  bool get commandMixedCase =>
      _retainedInterpretation?['mixedCase'] == true && _commandWord(_text) == _retainedCommandWord;

  /// The leading word, which is what identifies a command ("NOTE hello" ->
  /// "NOTE"). Case-insensitive: the field may or may not have uppercased it
  /// yet, depending on the very flag this feeds.
  ///
  /// Any whitespace ends the word, not just a space: a command taking free
  /// text matches on `\s+` (REPORT's pattern does, and it exists to accept
  /// pasted multi-line descriptions), so splitting on a literal space alone
  /// would read a newline-led description as part of the command word and
  /// revoke the very flag that keeps the paste unshouted.
  static String _commandWord(String text) {
    final trimmed = text.trimLeft();
    final end = trimmed.indexOf(RegExp(r'\s'));
    return (end < 0 ? trimmed : trimmed.substring(0, end)).toUpperCase();
  }

  /// The command word [_retainedInterpretation] was retained for.
  String? _retainedCommandWord;

  String get _text => _controller?.text ?? '';

  String get trimmedText => _text.trim();

  /// Starts listening to [controller]. Call once, from the caller's
  /// `initState`.
  void attach(TextEditingController controller) {
    _controller?.removeListener(_onTextChanged);
    _controller = controller;
    controller.addListener(_onTextChanged);
  }

  /// Set before anything else in [dispose] so an in-flight [_submit] can tell
  /// that its field and listeners are gone. An execute-time interpret gets a
  /// 30-second timeout, and the ⌘K dialog can be closed at any point inside it
  /// (Esc, or a barrier tap — neither gated on the submit); resuming into
  /// `_controller.clear()` or `notifyListeners()` afterwards trips
  /// ChangeNotifier's use-after-dispose assert.
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _controller?.removeListener(_onTextChanged);
    _commandDescribeDebounce?.cancel();
    _executeMessageTimer?.cancel();
    _lookupDebounce?.cancel();
    super.dispose();
  }

  /// Folds a fresh interpret() result into [_retainedInterpretation]. A
  /// non-null result always replaces the previous one. A null result only
  /// clears it when the current text has no space the formatter would
  /// otherwise strip on the next keystroke — mirrors
  /// `logging_controls.dart`'s `_retainInterpretation`.
  void _retainInterpretation(Map<String, dynamic>? result) {
    if (result != null) {
      _retainedInterpretation = result;
      _retainedCommandWord = _commandWord(_text);
    } else if (_noSpaceSafeText.hasMatch(_text)) {
      _retainedInterpretation = null;
      _retainedCommandWord = null;
    }
  }

  /// Forgets everything about the current callsign lookup, in one place.
  ///
  /// There are two paths that must forget one — the field going empty, and
  /// the text ceasing to look like a callsign — and both must clear the
  /// RESULT and the STAGE together: clearing only the result leaves the UI
  /// stuck in `searching` while the in-flight lookup aborts on its own
  /// stale-text guard and never replaces it.
  void _resetLookup() {
    _lookupFor = null;
    _lookupResult = null;
    _lookupGuess = null;
    _lookupRecords = const [];
    _lookupStage = CallLookupStage.none;
  }

  void _setMessage(String? text, CommandMessageKind kind) {
    _message = text;
    _messageKind = kind;
  }

  void _onTextChanged() {
    final raw = _text;

    // Selection-only notification — a cursor move, not an edit. Bail before
    // cancelling any timers: restarting the debounces here would make the
    // results re-resolve, and visibly re-render, every time the caret moves.
    if (raw == _lastText) return;

    _lastText = raw;

    final text = trimmedText;

    _lookupDebounce?.cancel();
    _commandDescribeDebounce?.cancel();
    _executeMessageTimer?.cancel();
    _currentInterpretation = null;

    if (text.isEmpty) {
      _resetLookup();
      _setMessage(null, CommandMessageKind.describe);
      _retainedInterpretation = null;
      notifyListeners();
      return;
    }

    _setMessage(null, CommandMessageKind.describe);
    notifyListeners();

    if (services.extensions.ready) {
      _commandDescribeDebounce = Timer(const Duration(milliseconds: 150), () async {
        final result = await services.extensions.interpretCommand(text, operationContext());
        if (trimmedText != text) return; // stale — the field changed while awaiting
        _currentInterpretation = result;
        _retainInterpretation(result);
        if (result != null && result['error'] is String) {
          _setMessage(result['error'] as String, CommandMessageKind.error);
        } else if (result != null && result['describe'] is String) {
          _setMessage(result['describe'] as String, CommandMessageKind.describe);
        } else {
          _setMessage(null, CommandMessageKind.describe);
        }
        notifyListeners();
      });
    }

    if (!looksLikeCallsign(text)) {
      _resetLookup();
      notifyListeners();
      return;
    }

    // Announced immediately, before any debounce: the user has typed
    // something that reads as a callsign and should be told it's being looked
    // up, rather than watching an empty panel while the network works.
    _lookupFor = text;
    _lookupGuess = null;
    _lookupRecords = const [];
    _lookupStage = CallLookupStage.searching;
    notifyListeners();

    _lookupDebounce = Timer(const Duration(milliseconds: 300), () async {
      // No in-progress QSO on these bars — QSO-scoped lookup hooks (e.g.
      // POTA) simply find nothing to do.
      final operation = operationContext() ?? const <String, dynamic>{};

      // Offline first. Local data files answer in milliseconds, so a name
      // and country land while the online sources are still in flight;
      // the online pass then fills in everything else.
      final offline = await services.extensions.lookupCall(text, qso: const {}, operation: operation, online: false);
      if (trimmedText != text) return; // stale — the field moved on
      _applyLookup(text, offline, CallLookupStage.offline);
      notifyListeners();

      final online = await services.extensions.lookupCall(text, qso: const {}, operation: operation);
      if (trimmedText != text) return;
      _applyLookup(text, online, CallLookupStage.complete);
      notifyListeners();
    });
  }

  /// Folds one lookup pass's result in. A null result only advances the
  /// stage: an online pass that finds nothing (no sources configured, or
  /// offline) must not wipe out what the offline pass already found.
  void _applyLookup(String call, Map<String, dynamic>? result, CallLookupStage stage) {
    if (result != null) {
      _lookupResult = result;
      _lookupGuess = (result['guess'] as Map?)?.cast<String, dynamic>();
      final records = result['lookups'];
      _lookupRecords = records is List
          ? records.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList()
          : const [];
    }
    _lookupFor = call;
    _lookupStage = stage;
  }

  /// The one-line summary of the current callsign lookup, or null when there
  /// isn't one for the text as it stands.
  String? get lookupLine {
    final result = _lookupResult;
    if (result == null || _lookupFor != trimmedText) return null;
    final guess = result['guess'] as Map<String, dynamic>? ?? const {};
    // A callsign note takes the name's slot outright rather
    // than joining it — same rule as the logging panel's _lookupLine
    // (packages/halo_widgets/lib/src/logging_controls.dart).
    final note = guess['note'] as String?;
    final parts = [
      (note != null && note.isNotEmpty) ? note : guess['name'],
      guess['location'],
      guess['country'],
      guess['grid'],
    ].whereType<String>().where((s) => s.isNotEmpty).toList();
    return parts.isEmpty ? null : parts.join(' • ');
  }

  /// Runs whatever is typed. Returns true when a command actually executed —
  /// the dialog closes on that, and stays open otherwise so the user can fix
  /// an error or keep typing parameters.
  Future<bool> submit() async {
    final text = trimmedText;
    if (text.isEmpty) return false;
    if (_submitting) return false;
    _submitting = true;
    try {
      return await _submit(text);
    } finally {
      _submitting = false;
    }
  }

  /// The command's own confirmation on the field's message line, self-clearing
  /// after five seconds the same way a describe does. Callers notify.
  void _showConfirmationMessage(String confirm) {
    _executeMessageTimer?.cancel();
    _setMessage(confirm, CommandMessageKind.confirmation);
    _executeMessageTimer = Timer(const Duration(seconds: 5), () {
      _setMessage(null, CommandMessageKind.describe);
      notifyListeners();
    });
  }

  Future<bool> _submit(String text) async {
    final operation = operationContext();

    var interpretation = _currentInterpretation;
    if (interpretation == null) {
      interpretation = await services.extensions.interpretCommand(text, operation);
      if (_disposed) return false; // the surface is gone; nothing ran yet either
      if (trimmedText != text) return false; // stale — the field changed while awaiting
    }

    // A recognized command that can't run in this context (e.g. SEED with
    // no open operation) — present its error and keep the typed input for
    // editing; there's nothing to execute.
    if (interpretation != null && interpretation['error'] is String) {
      _setMessage(interpretation['error'] as String, CommandMessageKind.error);
      notifyListeners();
      return false;
    }

    // A command still awaiting parameters (expectsParams) isn't complete —
    // leave the field as-is so the user can keep typing, rather than
    // treating it as executable (mirrors logging_controls.dart's _log()).
    if (interpretation != null && interpretation['expectsParams'] != true) {
      // The interpretation above may just be the debounce-time preview,
      // whose `commands` a hook like SEED deliberately left cheap/empty
      // (see CommandHook.interpret's `execute` doc) — re-interpret with
      // execute:true now that we're actually about to run it, so those
      // hooks generate the real commands instead of a stale preview's.
      final executable = await services.extensions.interpretCommand(text, operation, null, true);
      if (executable == null) return false;
      if (_disposed) return false; // the surface is gone; everything below is field state
      final confirmValue = executable['confirm'];
      final confirm = confirmValue is String && confirmValue.isNotEmpty ? confirmValue : null;
      // Before the staleness bail: by this point the command has already RUN,
      // and an execute call can be a non-idempotent network write. A
      // confirmation dropped because the operator touched the field mid-flight
      // reads as "nothing happened" and invites them to run it again — REPORT
      // would file a second card, since the POST carries no idempotency key.
      // The field is not ours to clear once it has moved on, so the message
      // line is all we get, and it has to carry the outcome.
      if (trimmedText != text) {
        if (confirm != null) {
          _showConfirmationMessage(confirm);
          notifyListeners();
        }
        return false; // stale — the field changed while awaiting
      }

      // A command can also fail at execute time (mirrors _log() in
      // logging_controls.dart) — show the message and keep the typed input
      // instead of clearing the field as if it had succeeded.
      if (executable['error'] is String) {
        _executeMessageTimer?.cancel();
        _setMessage(executable['error'] as String, CommandMessageKind.error);
        notifyListeners();
        return false;
      }

      _controller?.clear();
      _commandDescribeDebounce?.cancel();
      _executeMessageTimer?.cancel();

      _currentInterpretation = null;
      _retainedInterpretation = null;
      _retainedCommandWord = null;
      if (confirm != null) {
        _showConfirmationMessage(confirm);
      } else {
        _setMessage(null, CommandMessageKind.describe);
      }
      notifyListeners();

      final commands = executable['commands'];
      if (commands is List) {
        await dispatchActions(commands, skipOnlineLookup: executable['skipOnlineLookup'] == true);
      }
      onExecuted?.call();
      return true;
    } else if (interpretation == null && clearOnNoMatch) {
      // Nothing matched — the Home bar treats Enter as "clear this search".
      // Clearing the controller runs _onTextChanged, which resets the lookup
      // state; don't also reset it by hand here — a partial copy leaves the
      // stage stale (an empty field still showing "Looking up callsign…").
      _controller?.clear();
      _setMessage(null, CommandMessageKind.describe);
      _retainedInterpretation = null;
      notifyListeners();
    }
    return false;
  }

  /// Applies a command's returned `CommandAction`s.
  ///
  /// When a logging panel is live it gets the WHOLE batch: only it can apply
  /// the QSO-scoped fields (`setVfo`, `addQso`, `updateQso`, `setCallField`,
  /// `sendSpots`), which need the in-progress QSO and its controllers, and it
  /// handles the app-scoped ones too — so routing everything there makes a
  /// command run from the ⌘K dialog behave exactly as if it had been typed
  /// into the call field, ordering included. Splitting the batch would break
  /// commands that return several actions at once (SAT returns `setVfo` +
  /// `updateQso`).
  ///
  /// The local branches below are the no-operation-open case (the Home bar,
  /// or the dialog with nothing open), where only app-scoped actions can
  /// possibly apply.
  Future<void> dispatchActions(List<dynamic> actions, {bool skipOnlineLookup = false}) async {
    final dispatch = services.currentCommandDispatch;
    if (dispatch != null) {
      await dispatch(actions, skipOnlineLookup: skipOnlineLookup);
      return;
    }

    for (final action in actions) {
      if (action is! Map) continue;
      final map = action.cast<String, dynamic>();
      if (map.containsKey('updateSettings')) {
        final params = (map['updateSettings'] as Map).cast<String, dynamic>();
        if (params.containsKey('developerMode')) {
          await services.settings.setDeveloperMode(params['developerMode'] as bool);
        }
      } else if (map.containsKey('syncAll')) {
        await runAction('syncAll', null);
      } else if (map['devNotice'] is Map) {
        await runAction('devNotice', (map['devNotice'] as Map).cast<String, dynamic>());
      } else if (map['devStatus'] is Map) {
        await runAction('devStatus', (map['devStatus'] as Map).cast<String, dynamic>());
      } else if (map['devProgress'] is Map) {
        await runAction('devProgress', (map['devProgress'] as Map).cast<String, dynamic>());
      } else if (map['devSplash'] is Map) {
        await runAction('devSplash', null);
      } else if (map['devOnboard'] is Map) {
        await runAction('devOnboard', null);
      } else if (map['devTester'] is Map) {
        await runAction('devTester', null);
      } else if (map['reloadDataFiles'] is Map) {
        await runAction('reloadDataFiles', (map['reloadDataFiles'] as Map).cast<String, dynamic>());
      } else if (map['toggleExperiment'] is Map) {
        await runAction('toggleExperiment', (map['toggleExperiment'] as Map).cast<String, dynamic>());
      } else {
        // Nothing above recognized this action's key(s) — most likely a
        // command that's scoped to the logging panel (addQso, updateQso,
        // sendSpots, setCallField) matched here where no QSO is in
        // progress, or a new CommandAction field with no matching branch
        // here yet. Either way this must not fail silently: see
        // logging_controls.dart's own _dispatchActions and its regression
        // test for `reloadDataFiles` shipping without this branch.
        debugPrint('[extensions] no dispatch branch for command action: ${map.keys}');
      }
    }
  }
}
