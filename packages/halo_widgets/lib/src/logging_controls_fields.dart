// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The logging panel's entry row as the rest of it reads it: which fields are
// on the row and in what order, the call field's reading, the reports and
// their defaults, and the keyboards the numeric fields ask for. Its own file
// for size alone; it is part of the panel's library and reaches its state
// directly.

part of 'logging_controls.dart';

extension _EntryFields on _LoggingControlsState {
  /// The operation resolved into its segments. `widget.log.qsos` is the whole log,
  /// which is what carries the `break`/`start` event rows; an unsegmented
  /// operation resolves to a single segment that is its own data, unchanged.
  SegmentedOperation get _segmented => SegmentedOperation.from(operation: widget.log.operation.data, qsos: widget.log.qsos);

  /// Ref types the operation is actually running right now.
  ///
  /// This is the gate on PRIMARY field real estate (see `_textControls`).
  /// Secondary chips deliberately don't consult it: an extension can offer one
  /// from any operation — POTA's hunter control is the case that matters, since
  /// you chase a park from whatever you happen to be running.
  ///
  /// Reads the CURRENT segment, not the base operation: a QSO being typed now
  /// belongs to whatever the last `break`/`start` established, so a contest
  /// that ended at a break stops claiming the entry row and a park entered at
  /// one starts claiming it (docs/design/contests.md §5.1.3).
  Set<String> get _activeRefTypes {
    final current = _segmented.current;
    return {
      for (final ref in ((current['refs'] as List?) ?? const []).whereType<Map<dynamic, dynamic>>())
        if (ref['type'] case final String type) type,
    };
  }

  /// Every typed-exchange activity control currently contributed — `text` and
  /// `serial` alike, since both render the same way and differ only in who
  /// supplies the value.
  ///
  /// These render as PRIMARY fields, inline after Sent/Rcvd — not as secondary
  /// control chips like `refList`. A contest exchange is typed on every single
  /// QSO, hundreds of times an hour, so it belongs in the entry row next to the
  /// callsign; a chip that has to be expanded first is unusable at that rate.
  /// app-polo lays them out in the same place, between the RSTs and Grid/State.
  ///
  /// Precisely because that row is the scarcest space in the app, a control only
  /// earns a place in it if the operation is RUNNING that activity
  /// ([_activeRefTypes]) — every enabled contest extension is asked for logging
  /// controls, but merely having one installed must not put its exchange in
  /// front of someone logging an ordinary QSO. Enforced here rather than left to
  /// each extension: this is the core's rule about its own entry row, and the
  /// consequences of an extension forgetting it are severe — a stray `serial`
  /// field would hand out numbers from a series nobody is keeping.
  ///
  /// A control with no `refType` can never match, which is the intended
  /// reading: a primary field writes to a ref, so one that names no ref has
  /// nothing to attach itself to.
  Iterable<Map<String, dynamic>> get _textControls {
    final active = _activeRefTypes;
    return _refs.controls.where((c) {
      final input = c['input'] as Map?;
      final kind = input?['kind'];
      // `options` rides the same pipeline as `text`: it is a typed exchange
      // field that happens to search a known set, so save, restore, focus
      // cycling, the suggestion rule and the explicit-blank rule all come free
      // by joining here rather than by reimplementing any of them.
      if (kind != 'text' && kind != 'serial' && kind != 'options') return false;
      return active.contains(input?['refType']);
    });
  }

  /// Keyboard for the numeric-leaning primary fields (RST, frequency) on iOS.
  /// `numberWithOptions(signed: true)` selects iOS's NumbersAndPunctuation
  /// keyboard: numbers up front, but WITH a space bar (so Space still rotates
  /// focus — see [VirtualSpaceFormatter]) and the symbols these fields use —
  /// an RST like "5NN"/"59A" reaches letters via its ABC key, and +/- and the
  /// frequency separators sit on the primary page. Without it these fields get
  /// the letter-first default keyboard, which buries digits behind the "123"
  /// key for input that's mostly numeric.
  ///
  /// Null off iOS: Android's default keyboard already has both letters and a
  /// space bar, and a signed-number type there would instead drop to a numeric
  /// pad that loses the letters RSTs occasionally need — so each field keeps
  /// its existing keyboard on other platforms.
  TextInputType? get _numbersAndPunctuationOnIOS => isIOSPlatform ? const TextInputType.numberWithOptions(signed: true) : null;

  /// The keyboard for the frequency and power fields: iOS's
  /// NumbersAndPunctuation (the decimal separators, the symbols, and a space
  /// bar for Space-to-advance), the decimal pad elsewhere. Not the entry
  /// row's: there a null deliberately keeps the RST fields' letter-bearing
  /// default keyboard.
  TextInputType get _decimalKeyboardType => _numbersAndPunctuationOnIOS ?? const TextInputType.numberWithOptions(decimal: true);

  /// The call field as the panel reads it — see [CallFieldText] for the
  /// rules. A fresh snapshot of the text and the cursor on every read, so a
  /// rule never sees a cursor that moved after the text it was paired with.
  CallFieldText get _callText => CallFieldText(_callController.text, cursor: _callController.selection.baseOffset, stacking: widget.session.editingQso == null);

  String get _call => _callText.call;
  List<String> get _callList => _callText.callList;
  bool get _isCallStackField => _callText.isStack;
  Iterable<String> get _callsInField => _callText.callsInField;
  String get _callAtCursor => _callText.callAtCursor;

  /// The operation QSON with `uuid` folded in — same shape as the Dart
  /// side's `qsonPayloadFor` gives every coarse hook call. Command hooks
  /// need the uuid to fetch log data through the runtime's
  /// `ctx.getOperation`/`ctx.getQsos` (e.g. dev-commands' SEED reading the
  /// existing log's time range); the QSON alone doesn't carry it.
  Map<String, dynamic> get _operationDataForCommands => {...widget.log.operation.data, 'uuid': widget.log.operation.uuid};

  bool get _canLog {
    // Call stacking (issue #7): "//" takes priority over a comma-separated
    // list — "//"-separated calls/fragments aren't a single valid callsign,
    // but log is still possible as long as one of the stacked segments is —
    // see [CallFieldText.pickStackedCall]. Only while composing a new QSO.
    if (_isCallStackField) {
      return _callText.pickStackedCall() != null;
    }
    return _callList.isNotEmpty && _callList.every(isLoggableCall);
  }

  /// `jumpAfterRST`: move on the moment a report reaches [rstLengthFor],
  /// so a full exchange costs no Spaces.
  ///
  /// Deliberately fires on the **upward crossing** only, not on every keystroke
  /// at or above the length: correcting a report that is already complete —
  /// one just typed, or one loaded from a saved QSO — must not throw the
  /// operator out of the field on their first character.
  ///
  /// Hung off the controller because the report fields carry no `onChanged`.
  /// `hasFocus` is what keeps this to real typing: every programmatic write
  /// (a wipe, a suggestion, the blur-time [expandRST]) happens to a field the
  /// operator is not in.
  void _maybeJumpAfterRST(FocusNode focus, TextEditingController controller) {
    final length = controller.text.trim().length;
    final previous = _rstLengthSeen[focus] ?? 0;
    _rstLengthSeen[focus] = length;
    if (!widget.prefs.jumpAfterRST || _draft.isPopulating || !focus.hasFocus) return;
    // Null on the FT modes, whose report has no fixed length — there is no
    // moment to call "done", so the setting simply doesn't apply.
    final full = rstLengthFor(_radio.mode);
    if (full == null) return;
    if (previous < full && length >= full) _ladder.advancePrimaryFocus();
  }

  void _clearRSTs() {
    _sentController.clear();
    _rcvdController.clear();
  }

  /// The report a blank Sent/Rcvd stands for, shown as a faint placeholder
  /// while the field is empty rather than pre-filled as a real value — the
  /// same "a default is not something the operator typed" rule the Grid and
  /// State guesses follow, so overtyping it never means clearing it first.
  ///
  /// Null while editing a saved record: there a blank field is stored data,
  /// not a stand-in, and filling it in would rewrite a QSO the operator only
  /// opened to look at. [_rstPlaceholder] and [_rstOrDefault] read the same
  /// condition on purpose — a hint that promised a value the save didn't
  /// write would be worse than no hint.
  String? get _rstPlaceholder => widget.session.editingQso == null ? _defaultRST : null;

  String get _defaultRST => defaultRSTFor(_radio.mode, phone: widget.prefs.defaultReport, cw: widget.prefs.defaultReportCW, snr: widget.prefs.defaultReportFT8);

  /// Where a report becomes what actually gets stored: the placeholder if the
  /// field is blank, otherwise the operator's own shorthand completed by
  /// [expandRST] (`5` → `55`, `57` → `579` on CW). Every consumer — the log,
  /// scoring, dupe checks, spotting, export — reads the RSTs through here.
  ///
  /// The expansion has to happen here as well as on losing focus: Enter never
  /// blurs (§ "Enter and focus"), so the field the operator logs from is one
  /// that never left focus, and a bare `5` would otherwise reach the record.
  String _rstOrDefault(String text) => text.isEmpty ? (_rstPlaceholder ?? '') : expandRST(text, _radio.mode);

  /// The two report fields in display order, which `switchSentRcvd` reverses.
  ///
  /// Every surface that shows both reads the order from here — the main row,
  /// the keyboard's path through it, and the More pane — so the row can never
  /// disagree with the order Space and Tab actually walk. Which controller is
  /// Sent and which is Rcvd never changes; only where each is drawn does.
  List<RstFieldSlot> get _rstPair {
    final pair = [
      (focus: _sentFocus, controller: _sentController, label: t.loggingControls.sent),
      (focus: _rcvdFocus, controller: _rcvdController, label: t.loggingControls.rcvd),
    ];
    return widget.prefs.switchSentRcvd ? pair.reversed.toList() : pair;
  }

  /// The More pane's own report fields, keyed by the form's field names rather
  /// than by controller — the pane round-trips values through a `Map`, not
  /// through [_rstPair]'s controllers, so it needs the order in its own terms.
  List<String> get _rstPaneKeyOrder => widget.prefs.switchSentRcvd ? const ['rcvd', 'sent'] : const ['sent', 'rcvd'];

  /// An exchange field's focus node fired: the ladder notes it, and a gain of
  /// focus lands the caret — the same cursor-at-end-on-focus rule the fixed
  /// primary fields get in initState. An exchange field is a main logging
  /// field too, and `selectAllOnFocus: false` alone only stops the
  /// select-all; it leaves the caret wherever it happened to be last.
  void _onExchangeFocusChanged(FocusNode node, TextEditingController controller) {
    _ladder.notePrimaryFocus(node);
    if (node.hasFocus) {
      controller.selection = TextSelection.collapsed(offset: _ladder.takePendingCaretOffset(node, controller) ?? controller.text.length);
    }
  }

  /// The primary fields currently on screen, in the left-to-right order
  /// they're laid out in — Call, Sent/Rcvd (when RST is on), the contest
  /// exchanges, then State/Grid (when their "..." menu toggles are on).
  ///
  /// The single source of truth for what "a primary field" means to the
  /// keyboard: [LoggingFocusLadder.advancePrimaryFocus] walks it, `_handleSpace`
  /// asks it whether Space should advance, and
  /// [LoggingFocusLadder.onPrimaryFieldKeyEvent] reads it for Tab's
  /// walk and the arrow keys' end-of-value traversal. Any new kind of
  /// primary field is in all of them the moment it appears here — an exchange
  /// field that cycled on Tab but sat inert on Space (because only Space's
  /// caller had a hardcoded list) is exactly the drift this prevents.
  ///
  /// Paired with each field's controller, since Tab and the arrows have to read
  /// the caret and the value, not just move focus.
  ///
  /// Rebuilt on every call: `showRSTFields`/`showStateField`/`showGridField`
  /// change at runtime, and so does the set of contest controls.
  List<PrimaryField> get _primaryFields => [
    (key: 'call', label: t.loggingControls.theirCall, focus: _callFocus, controller: _callController, hint: null, skipFocus: false),
    // Display order, not Sent-then-Rcvd: the keyboard walks the row the
    // operator is looking at (see [_rstPair]).
    if (widget.prefs.showRSTFields)
      for (final field in _rstPair)
        (
          key: identical(field.controller, _sentController) ? 'sent' : 'rcvd',
          label: field.label,
          focus: field.focus,
          controller: field.controller,
          hint: _rstPlaceholder,
          skipFocus: false,
        ),
    // Only nodes already attached to a built field: creating one here for a
    // control whose widget hasn't been built leaves an orphan with no
    // context, which Flutter's focus traversal null-checks while sorting —
    // taking down the whole frame rather than just misordering focus.
    for (final control in _textControls)
      if (_exchange.attachedFocusFor(control['key'] as String) case final focus?)
        (
          key: control['key'] as String,
          label: (control['label'] as String?) ?? control['key'] as String,
          focus: focus,
          controller: _exchange.controllerFor(control['key'] as String),
          hint: (control['input'] as Map?)?['placeholder'] as String?,
          skipFocus: control['skipFocus'] == true,
        ),
    if (widget.prefs.showStateField)
      (key: 'state', label: t.qsoEditForm.theirState, focus: _stateFocus, controller: _stateController, hint: _guessStateHint, skipFocus: false),
    if (widget.prefs.showGridField)
      (key: 'grid', label: t.qsoEditForm.theirGrid, focus: _gridFocus, controller: _gridController, hint: _guessGridHint, skipFocus: false),
  ];

  /// The Grid field's hint — see [guessGridDisplay], which the More pane's
  /// own Grid field hints through too so the two can never show different
  /// squares for one station.
  String? get _guessGridHint => guessGridDisplay(_currentGuess);

  /// The guessed state (e.g. from a callsign lookup), shown as a faint
  /// placeholder while the State field is empty — never pre-filled as a
  /// real value.
  String? get _guessStateHint => asQsonString(_currentGuess?['state']);
}
