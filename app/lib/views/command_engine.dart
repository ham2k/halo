// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The lookup-and-command engine behind the two places a user can type a
// callsign or a command outside the logging panel: the Home view's Quick
// Lookup bar (`HomeQuickLookup`) and the ⌘K command dialog
// (`CommandDialog`). Both need the same non-obvious behavior — the debounce
// split (150ms describe preview vs 300ms lookup), the second `execute: true`
// interpret call before dispatch (so a hook like SEED builds its real
// commands instead of a stale cheap preview), the error-vs-confirm message
// states, and the input rules in [commandFieldFormatters]. A second copy
// would drift.
//
// Beyond those formatters this owns state and timing only. Both callers
// render it themselves: the Home bar shows a single message line, the dialog
// a list of results.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../main.dart';

/// What the two command fields do to each keystroke.
///
/// Positional, never interpreted: nothing here may wait on `interpret`. Its
/// answer arrives up to 150ms after the keystroke and — because the describe
/// debounce restarts on every one — never arrives at all while someone types
/// steadily. A rule gated on an interpretation therefore runs on the PREVIOUS
/// command's answer, or on none: it eats the space in "NOTE hello" typed in
/// one motion, and files "REPORT crash on save" shouting. The logging panel's
/// call field can afford to ask, because there Space is a keystroke it
/// handles and can await an answer for (`logging_controls.dart`'s
/// `_handleSpace`); here a space is just text.
///
/// Order matters: [CollapseWhitespaceFormatter] runs first so the rest see
/// normalized text. [MobileDotToSlashFormatter] tests the START of the value,
/// so a leading space it hasn't dropped yet hides the callsign from it and
/// " k1abc.p" keeps a dot no operator meant.
///
/// Built per call rather than held in a top-level `final`: a cached list
/// would fix [isMobilePlatform] at whatever the platform was the first time
/// anything read it, which under test is decided by the order the cases run
/// in.
List<TextInputFormatter> get commandFieldFormatters => <TextInputFormatter>[
      const CollapseWhitespaceFormatter(),
      if (isMobilePlatform) MobileDotToSlashFormatter(),
      const CommandWordCaseFormatter(),
    ];

/// Reduces every run of whitespace to one plain space, and drops one with
/// nothing yet to separate.
///
/// ALL whitespace, not just the space key. A single-line `TextField` filters
/// out `\n` and nothing else (`EditableText` installs
/// `FilteringTextInputFormatter.singleLineFormatter`, which denies exactly
/// that one character), so a tab, a CR from a Windows paste, and the
/// non-breaking space macOS makes from Option-Space all reach this field.
/// Left alone they read as a space to the eye and as a different character
/// to every pattern, and [CommandWordCaseFormatter] — which stops at the
/// first whitespace — would find one at index 0 and uppercase nothing at all.
///
/// Spaces themselves are free here: at the ends because both `interpret` and
/// the callsign lookup read the field through [CommandEngine.trimmedText],
/// and in the middle as a deliberate trade — a space cannot be stripped on
/// the way in without also eating the one in "NOTE hello", so "W1 AW" stays
/// as typed and simply matches nothing: no lookup, no command, and no
/// message saying why. That is the price of the parameter space, and a
/// mis-typed call is the rarer of the two.
class CollapseWhitespaceFormatter extends TextInputFormatter {
  const CollapseWhitespaceFormatter();

  static final _whitespace = RegExp(r'\s');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;

    final kept = StringBuffer();
    String? previous;
    final base = newValue.selection.baseOffset;
    final extent = newValue.selection.extentOffset;
    var droppedBeforeBase = 0;
    var droppedBeforeExtent = 0;
    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      if (_whitespace.hasMatch(char)) {
        if (previous == null || previous == ' ') {
          // Each drop shifts every caret offset that sat after it — a paste
          // lands mid-value, so the cursor is not always at the end.
          if (base > i) droppedBeforeBase++;
          if (extent > i) droppedBeforeExtent++;
          continue;
        }
        // Same length, so only the drops above move the caret.
        kept.write(' ');
        previous = ' ';
        continue;
      }
      kept.write(char);
      previous = char;
    }

    final result = kept.toString();
    // Nothing to normalize — hand the edit straight back rather than
    // resetting a composing region an IME still has open.
    if (result == text) return newValue;

    final newBase = base < 0 ? base : base - droppedBeforeBase;
    final newExtent = extent < 0 ? extent : extent - droppedBeforeExtent;
    // Not a clamp: a caret past the end is this loop having miscounted, and
    // silently moving it somewhere plausible is how that stays unnoticed.
    assert(newBase <= result.length && newExtent <= result.length,
        'whitespace collapse miscounted: $base/$extent -> $newBase/$newExtent in "$result"');
    return TextEditingValue(
      text: result,
      selection: newValue.selection.copyWith(baseOffset: newBase, extentOffset: newExtent),
      // The composing region indexes the text just rewritten.
      composing: TextRange.empty,
    );
  }
}

/// Uppercases the command word — everything up to the first whitespace — and
/// leaves what follows exactly as typed.
///
/// Positional, because the alternative is to ask. Whether a parameter is
/// prose is only known from `interpret`'s `mixedCase`, and see
/// [commandFieldFormatters] for why that answer is not available in time.
///
/// A callsign holds no whitespace and so is still uppercased whole, which is
/// the rule these fields exist to keep. Everything past the first space is a
/// parameter: command patterns match case-insensitively, and a hook that
/// needs its token uppercase uppercases it itself (radio-commands does).
///
/// [upcaseParams] lists the commands whose parameter is uppercased along
/// with the word: those whose parameter is a name the field shows as an
/// uppercase token everywhere else (an experiment key), never one that could
/// be prose. Static because a rule here cannot consult the catalog either —
/// the Home bar never loads it.
class CommandWordCaseFormatter extends TextInputFormatter {
  const CommandWordCaseFormatter();

  static final _whitespace = RegExp(r'\s');

  static const upcaseParams = {'EXP'};

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    final end = text.indexOf(_whitespace);
    if (end < 0) return newValue.copyWith(text: text.toUpperCase());
    final word = text.substring(0, end).toUpperCase();
    if (upcaseParams.contains(word)) return newValue.copyWith(text: text.toUpperCase());
    return newValue.copyWith(text: word + text.substring(end));
  }
}

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

  /// A command that RAN and reported that it did not work — an action's own
  /// bad news (`updateSetting` rejecting a value, a spot a source refused).
  ///
  /// Kept apart from [error], which is a command that never ran at all and
  /// leaves the operator's text in the field to be fixed. This one is a
  /// RESPONSE: the field is empty behind it, it reads in the error style, and
  /// it lives on the same five-second clock as a [confirmation].
  failure,
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
  /// decides there whether to stay up for the response; the Home bar does
  /// nothing.
  final void Function()? onExecuted;

  /// Invoked when a just-run command's response has had its five seconds and
  /// cleared itself. The ⌘K dialog dismisses itself here — the response is
  /// what kept it open.
  ///
  /// Fires from the clock alone, never from the other paths that clear the
  /// message, so a keystroke — which cancels that clock ([_onTextChanged]) —
  /// stops the dismissal. That is NOT the same as "the field is empty when
  /// this fires": the stale-submit path in [_submit] starts a confirmation's
  /// clock over text the operator typed during the round trip. A listener
  /// that closes a surface here has to check the field itself.
  final void Function()? onResponseExpired;

  /// Whether this bar can actually be READ right now — not merely alive.
  ///
  /// [showResponse] is the destination `runCommandAction` prefers over the
  /// status bar, and it only earns that on the strength of being visible. The
  /// Home bar's engine outlives its visibility by a long way: HomeView stays
  /// mounted underneath every pushed route, so a command run there and
  /// answered after the operator opened an operation would paint its failure
  /// onto a bar buried two screens down and report success doing it. Null
  /// means "always readable".
  final bool Function()? canShowResponse;

  /// Whether Enter on text that matched no command should wipe the field.
  ///
  /// True for the Home bar, where Enter reads as "clear this search". False
  /// for the ⌘K dialog, where the text is usually a callsign whose lookup is
  /// on screen — clearing it there throws away the very thing the user just
  /// asked for, and drops the palette back to its suggestions.
  final bool clearOnNoMatch;

  /// Runs one dispatched `CommandAction` — the app-wide `runCommandAction`
  /// for both bars; a callback so tests can stand in for it. Where whatever
  /// it has to say ENDS UP is not this callback's business: an action
  /// dispatched by the logging panel never passes through here at all, so the
  /// destination is decided by `HaLoServices.commandResponseSink`, which
  /// [_submit] holds open across the whole batch.
  final Future<void> Function(String action, Map<String, dynamic>? params) runAction;

  CommandEngine({
    required this.services,
    required this.operationContext,
    required this.runAction,
    this.onExecuted,
    this.onResponseExpired,
    this.canShowResponse,
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
  CallLookupStage _lookupStage = CallLookupStage.none;
  Map<String, dynamic>? _lookupGuess;
  List<Map<String, dynamic>> _lookupRecords = const [];
  List<int>? _workedBefore;

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

  /// Whether [message] should read as bad news — either a command that could
  /// not run, or one that ran and failed.
  bool get isError =>
      _message != null &&
      (_messageKind == CommandMessageKind.error || _messageKind == CommandMessageKind.failure);

  /// Whether [message] is a just-executed command's confirmation.
  bool get isConfirmation => _message != null && _messageKind == CommandMessageKind.confirmation;

  /// Whether [message] is a finished command's ANSWER — what it did, or why it
  /// could not. Both kinds sit over an emptied field and share the clock; only
  /// their styling differs.
  bool get isResponse =>
      _message != null &&
      (_messageKind == CommandMessageKind.confirmation || _messageKind == CommandMessageKind.failure);

  /// Whether an interpretation of the CURRENT text is still on its way —
  /// true from the keystroke until its debounced `interpret` answers.
  ///
  /// [message] is cleared synchronously on every keystroke and only refilled
  /// when that answer arrives, so for ~150ms plus a bridge round trip the
  /// engine truthfully has nothing to say about text that a hook is about to
  /// explain. A caller that shows its own "nothing matches" fallback needs to
  /// know the difference, or it paints that fallback in the gap between every
  /// keystroke and the describe that replaces it — which reads as two
  /// messages fighting over the same line.
  bool get interpretationPending => _interpreting;

  bool _interpreting = false;

  /// Bumped on every keystroke that starts an interpretation, so a call can
  /// tell whether it is still the current one.
  ///
  /// Comparing the field's TEXT instead is not enough: type "SET", backspace
  /// to "SE", and the older in-flight "SE" call sees its own text back in the
  /// field and clears the flag, even though the newer "SE" debounce has not
  /// fired. The card then reads "not pending, no message" and paints its
  /// generic fallback — the exact flicker the flag exists to stop.
  int _interpretGeneration = 0;

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

  /// True while an execute-time interpret is in flight. A command's execute
  /// call may be a non-idempotent network write (REPORT files a CaBo card), so
  /// a second Enter during the round trip would file it twice.
  bool _submitting = false;

  String get _text => _controller?.text ?? '';

  String get trimmedText => _text.trim();

  StreamSubscription<Map<String, dynamic>>? _interpretationUpdatesSub;

  /// Starts listening to [controller]. Call once, from the caller's
  /// `initState`.
  void attach(TextEditingController controller) {
    _controller?.removeListener(_onTextChanged);
    _controller = controller;
    controller.addListener(_onTextChanged);
    _interpretationUpdatesSub ??=
        services.extensions.commandInterpretationUpdates.listen(_onInterpretationUpdate);
  }

  /// A `command` hook pushing a later interpretation for an input it has
  /// already answered — SOLAR/WEATHER's background fetch landing after the
  /// "Fetching…" preview their own interpret call returned (see
  /// `host.updateInterpretation`'s SDK doc).
  ///
  /// The reading has to replace that preview everywhere it shows, which is why
  /// this sets [currentInterpretation] and not just the message: in the ⌘K
  /// dialog the preview is the "run what's typed" row's subtitle, and a row
  /// still reading "Fetching…" a second after the fetch answered is the thing
  /// this exists to fix.
  ///
  /// Never dispatches `commands`, whatever the push carries — only Enter runs
  /// anything.
  void _onInterpretationUpdate(Map<String, dynamic> event) {
    final text = trimmedText;
    // The push names the input it answers, and the field has usually moved on.
    if (text.isEmpty || event['input'] != text) return;
    // A command that just ran owns the line for its five seconds: its
    // execute-time answer is the newer news, and a push landing behind it
    // would replace that answer with a preview of the same command.
    if (isResponse) return;
    // The host fills a missing interpretation in as `{}` before it gets
    // here, and an empty one is a hook RETRACTING its preview — which is null
    // internally. Left as `{}` it reads as a recognized command, and Enter
    // stops clearing the Home bar's search for that text.
    final pushed = (event['interpretation'] as Map?)?.cast<String, dynamic>();
    _applyInterpretation(pushed == null || pushed.isEmpty ? null : pushed);
    notifyListeners();
  }

  /// Records an interpretation and derives the message line from it. Callers
  /// notify.
  void _applyInterpretation(Map<String, dynamic>? result) {
    _currentInterpretation = result;
    if (result != null && result['error'] is String) {
      _setMessage(result['error'] as String, CommandMessageKind.error);
    } else if (result != null && result['describe'] is String) {
      _setMessage(result['describe'] as String, CommandMessageKind.describe);
    } else {
      _setMessage(null, CommandMessageKind.describe);
    }
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
    unawaited(_interpretationUpdatesSub?.cancel());
    _commandDescribeDebounce?.cancel();
    _executeMessageTimer?.cancel();
    _lookupDebounce?.cancel();
    super.dispose();
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
    _lookupGuess = null;
    _lookupRecords = const [];
    _workedBefore = null;
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
      _interpreting = false;
      notifyListeners();
      return;
    }

    // The previous message deliberately STAYS until this keystroke's own
    // interpretation answers, ~150ms later. Clearing it here leaves the ⌘K
    // card with no result, no message and no fallback for that gap, so the
    // whole card unmounts and remounts on every character — a worse flicker
    // than the stale line it was meant to avoid. One keystroke of lag is what
    // a debounced preview is.
    _interpreting = services.extensions.ready;
    if (!_interpreting) _setMessage(null, CommandMessageKind.describe);
    final generation = ++_interpretGeneration;
    notifyListeners();

    if (services.extensions.ready) {
      _commandDescribeDebounce = Timer(const Duration(milliseconds: 150), () async {
        // `whenComplete`, not a catch: an exception `interpretCommand` didn't
        // expect is a real defect and belongs to ErrorPolicy, which decides
        // what escaped exceptions deserve in ONE place (.agents/AGENTS.md).
        // Swallowing it here would make it invisible in the field. All this
        // needs is that [_interpreting] not stay true if one escapes — and
        // only when this call is still the current one, since a newer
        // keystroke has already claimed the flag.
        final result = await services.extensions
            .interpretCommand(text, operationContext())
            .whenComplete(() {
          if (generation != _interpretGeneration) return;
          _interpreting = false;
          // Notified here as well as below, because an exception on the way
          // out skips everything below and would otherwise drop the flag
          // without a rebuild.
          notifyListeners();
        });
        // Stale — a newer keystroke started while this was awaiting, and owns
        // everything below.
        if (generation != _interpretGeneration) return;
        _applyInterpretation(result);
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
    _workedBefore = null;
    _lookupStage = CallLookupStage.searching;
    notifyListeners();

    _lookupDebounce = Timer(const Duration(milliseconds: 300), () async {
      // No in-progress QSO on these bars — QSO-scoped lookup hooks (e.g.
      // POTA) simply find nothing to do.
      final operation = operationContext() ?? const <String, dynamic>{};

      // The log's own answer, for the summary's worked-before pill, runs
      // beside the callbook passes rather than ahead of them: awaited here, a
      // failing query would leave the lookup stuck in `searching`.
      unawaited(_loadWorkedBefore(text));

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

  /// When this station was worked before. No QSO is open on these bars, so
  /// nothing to exclude. A failure is not caught: it reaches ErrorPolicy like
  /// any other escaped exception, and the pill simply stays absent.
  Future<void> _loadWorkedBefore(String text) async {
    final times = await services.qsos.historyStartTimesForCall(text);
    // `_disposed` as well as the stale check: `dispose` cancels the debounce
    // but not a query the fired timer already launched, and notifying a
    // disposed ChangeNotifier asserts — closing the dialog mid-read is
    // exactly that window.
    if (_disposed || trimmedText != text) return;
    _workedBefore = times;
    notifyListeners();
  }

  /// Folds one lookup pass's result in. A null result only advances the
  /// stage: an online pass that finds nothing (no sources configured, or
  /// offline) must not wipe out what the offline pass already found.
  void _applyLookup(String call, Map<String, dynamic>? result, CallLookupStage stage) {
    if (result != null) {
      _lookupGuess = (result['guess'] as Map?)?.cast<String, dynamic>();
      final records = result['lookups'];
      _lookupRecords = records is List
          ? records.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList()
          : const [];
    }
    _lookupFor = call;
    _lookupStage = stage;
  }

  /// The current callsign lookup as the shared [CallInfoSummary] and
  /// [CallInfoPanel] both take it, or null when there isn't one for the text
  /// as it stands.
  ///
  /// No scoring keys: scoring is an operation's verdict on a QSO, and a
  /// surface running this engine may have neither.
  CallInfoData? get callInfo {
    final call = lookupCall;
    if (call == null || _lookupFor != trimmedText) return null;
    // Only once a pass has actually ANSWERED. `searching` clears the guess but
    // keeps the call, so a second callsign typed over a resolved one sits here
    // with nothing in it — and a surface that took that for an answer would
    // paint an empty info area and open an empty panel over the previous
    // call's residue.
    //
    // A pass that answered with no guess still counts: the callsign is known,
    // and the QSO history the detail panel loads for it is exactly what an
    // operator with no callbook subscription is asking for.
    if (_lookupStage == CallLookupStage.searching) return null;
    return CallInfoData(call: call, guess: _lookupGuess, lookups: _lookupRecords, workedBefore: _workedBefore);
  }

  /// Line 1 of the compact call-info, where no operation supplies a reference
  /// point to measure a distance from: where the station is, and nothing more.
  ///
  /// The name and any callsign note are deliberately absent — the summary
  /// widget gives those their own line, and repeating them here would show
  /// each twice.
  String? get lookupLocationLine {
    final guess = _lookupGuess;
    if (guess == null || _lookupFor != trimmedText) return null;
    final parts = [
      guess['location'],
      guess['country'],
      // The locator the lookup's own coordinate justifies, where it reported
      // one — the merge derives `guess.grid` from it at six characters, which
      // is coarser than what was actually known.
      gridForDisplay(
        lat: locationFromGuess(guess)?.latitude,
        lon: locationFromGuess(guess)?.longitude,
        grid: asQsonString(guess['grid']),
      ),
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

  /// What a command ACTION had to say about what it did — dispatched app-side
  /// (`runCommandAction`), so it lands after the hook's optimistic `confirm`
  /// and outranks it: the action is the one that knows whether the write
  /// actually happened. Same line, same five seconds, and the clock restarts
  /// so a slow action's news isn't half-expired by the time it arrives.
  ///
  /// Returns whether it was actually shown. This is reached through
  /// `HaLoServices.commandResponseSink`, from code that has no idea whether
  /// this engine's surface is still there — and a caller told "shown" for a
  /// message nobody can see has no reason to fall back to the status bar, so
  /// the false here is what keeps an action's failure from vanishing.
  ///
  /// Deliberately does NOT start the clock, even though this is a finished
  /// action's word: this runs from INSIDE [_submit]'s dispatch, where a later
  /// action in the same batch may still be running. [_submit] arms it once the
  /// whole batch has settled.
  bool showResponse(String message, {bool failed = false}) {
    if (_disposed || !(canShowResponse?.call() ?? true)) return false;
    // Within one batch the WORST news wins, not the last: an action that
    // failed followed by one that succeeded must not end up reading as
    // success. Claimed as shown either way — the failure already on the line
    // is this batch's answer, and sending the success on to the status bar
    // would just contradict it somewhere else.
    if (!failed && _messageKind == CommandMessageKind.failure) return true;
    _setMessage(message, failed ? CommandMessageKind.failure : CommandMessageKind.confirmation);
    _executeMessageTimer?.cancel();
    notifyListeners();
    return true;
  }

  /// Puts a command's confirmation on the field's message line. Does NOT start
  /// its five seconds — see [_armResponseClock]. Callers notify.
  void _setConfirmation(String confirm) {
    _executeMessageTimer?.cancel();
    _setMessage(confirm, CommandMessageKind.confirmation);
  }

  /// Starts (or restarts) the five seconds a response stays up, and with it
  /// the ⌘K palette's own dismissal.
  ///
  /// Armed once the command has actually finished, never when its optimistic
  /// `confirm` is first shown: `syncAll` resyncs a whole account and a
  /// settings write can wait on an extension validator for thirty seconds, so
  /// a clock started at the confirm expires mid-flight — closing the surface
  /// that the action's own word, the one that knows whether the write
  /// happened, was about to be delivered to.
  void _armResponseClock() {
    if (!isResponse) return;
    _executeMessageTimer?.cancel();
    _executeMessageTimer = Timer(const Duration(seconds: 5), () {
      _setMessage(null, CommandMessageKind.describe);
      notifyListeners();
      onResponseExpired?.call();
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
          _setConfirmation(confirm);
          // Nothing is dispatched down this path, so the clock starts here.
          // It is the one place a confirmation's five seconds run with text
          // already in the field — see [onResponseExpired].
          _armResponseClock();
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
      if (confirm != null) {
        _setConfirmation(confirm);
      } else {
        _setMessage(null, CommandMessageKind.describe);
      }
      notifyListeners();

      final commands = executable['commands'];
      if (commands is List) {
        // Every action's message arrives inside this awaited window — the
        // logging panel's dispatcher awaits each `onCommandAction` in turn —
        // so this is exactly how long the sink needs to exist, and holding it
        // any longer catches messages belonging to commands typed elsewhere
        // (see `HaLoServices.commandResponseSink`). Restored rather than
        // nulled: a command run from the ⌘K palette over an operation reaches
        // here through the palette's engine while the Home bar's engine may
        // have its own claim standing.
        final outer = services.commandResponseSink;
        services.commandResponseSink = showResponse;
        try {
          await dispatchActions(commands, skipOnlineLookup: executable['skipOnlineLookup'] == true);
        } finally {
          if (services.commandResponseSink == showResponse) services.commandResponseSink = outer;
        }
      }
      // Only now, with the batch settled and any action's word already on the
      // line, does the response start counting down — and only if there is
      // still a surface to count down for. Dispatch can outlive this engine
      // (the operator dismisses the ⌘K palette while a sync runs), and a clock
      // armed past that fires `notifyListeners` on a disposed ChangeNotifier.
      if (!_disposed) {
        _armResponseClock();
        notifyListeners();
        onExecuted?.call();
      }
      return true;
    } else if (interpretation == null && clearOnNoMatch) {
      // Nothing matched — the Home bar treats Enter as "clear this search".
      // Clearing the controller runs _onTextChanged, which resets the lookup
      // state; don't also reset it by hand here — a partial copy leaves the
      // stage stale (an empty field still showing "Looking up callsign…").
      _controller?.clear();
      _setMessage(null, CommandMessageKind.describe);
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
      } else if (map['purgeTests'] is Map) {
        await runAction('purgeTests', (map['purgeTests'] as Map).cast<String, dynamic>());
      } else if (map['devNotice'] is Map) {
        await runAction('devNotice', (map['devNotice'] as Map).cast<String, dynamic>());
      } else if (map['devStatus'] is Map) {
        await runAction('devStatus', (map['devStatus'] as Map).cast<String, dynamic>());
      } else if (map['devProgress'] is Map) {
        await runAction('devProgress', (map['devProgress'] as Map).cast<String, dynamic>());
      } else if (map['devHammer'] is Map) {
        await runAction('devHammer', (map['devHammer'] as Map).cast<String, dynamic>());
      } else if (map['devSplash'] is Map) {
        await runAction('devSplash', null);
      } else if (map['devOnboard'] is Map) {
        await runAction('devOnboard', null);
      } else if (map['devTester'] is Map) {
        await runAction('devTester', null);
      } else if (map['devPopup'] is Map) {
        await runAction('devPopup', null);
      } else if (map['devTimeTravel'] is Map) {
        await runAction('devTimeTravel', (map['devTimeTravel'] as Map).cast<String, dynamic>());
      } else if (map['reloadDataFiles'] is Map) {
        await runAction('reloadDataFiles', (map['reloadDataFiles'] as Map).cast<String, dynamic>());
      } else if (map['toggleExperiment'] is Map) {
        await runAction('toggleExperiment', (map['toggleExperiment'] as Map).cast<String, dynamic>());
      } else if (map['updateSetting'] is Map) {
        await runAction('updateSetting', (map['updateSetting'] as Map).cast<String, dynamic>());
      } else if (map['openSettings'] is Map) {
        await runAction('openSettings', (map['openSettings'] as Map).cast<String, dynamic>());
      } else if (map['updateOperation'] is Map) {
        // App-scoped like setPower below — the logging panel only contributes
        // the uuid, which the open operation's own context has too. Without
        // this branch OPER/POSITION run from the ⌘K dialog while no logging
        // panel is mounted would show their "Operator: KI2D" confirmation and
        // write nothing. With no operation open there is no uuid, and the
        // action reports that rather than going quiet.
        await runAction('updateOperation', {
          ...(map['updateOperation'] as Map).cast<String, dynamic>(),
          if (services.currentOperationContext?['uuid'] case final String uuid) 'uuid': uuid,
        });
      } else if (map['setPower'] is Map) {
        // Not QSO-scoped, unlike the actions this fallback path can't serve
        // (addQso, updateQso, setCallField — see the comment below) — so,
        // unlike those, it runs here whether or not a logging panel is live.
        await runAction('setPower', (map['setPower'] as Map).cast<String, dynamic>());
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
