// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The logging panel's Space — the hardware shortcut and the on-screen
// keyboard's — and the mobile numbers row it publishes over the keyboard.
// Its own file for size alone; it is part of the panel's library and
// reaches its state directly.

part of 'logging_controls.dart';

extension _SpaceAndNumbers on _LoggingControlsState {
  /// The exit when iOS turned the operator's second space into a period. Puts
  /// the field back to [baseText] — the value before the gesture began —
  /// rather than editing whatever is there now: iOS applies BOTH halves of the
  /// shortcut before this runs, so "strip the trailing space" would leave the
  /// period sitting on the end of the value.
  void _exitOnPeriodShortcut(String baseText) {
    _callController.value = TextEditingValue(
      text: baseText,
      selection: TextSelection.collapsed(offset: baseText.length),
      composing: TextRange.empty,
    );
    _ladder.advancePrimaryFocus();
  }

  // ---- Command shortcuts ----
  //
  // Space in the call field first tries the text as an extension command
  // (band/frequency/mode shortcuts live in the `radio-commands` extension;
  // see docs/extensions/hooks.md's `command` category). This is a real bridge
  // round-trip, not a Dart regex — command matching and frequency parsing
  // are extension/domain-library territory, not core UI territory.

  Future<void> _handleSpace() async {
    if (_callFocus.hasFocus) {
      // A field that accepts literal spaces stays escapable by the
      // double-space, and the test is the SAME one that decides the field
      // accepts them at all (see the call field's inputFormatters) — not the
      // interpretation's flags. There is a third way into free-text mode:
      // the expects-params rule's second arm, text that already holds a space.
      // A complete command reached that way ("EXP LA") carries neither
      // `expectsParams` nor `mixedCase`, so keying the exit to those flags
      // advanced focus while leaving the trailing space in the value.
      //
      // Ahead of the interpret round-trip below because the answer never
      // depended on it, and leaving a field shouldn't wait on a bridge call.
      if (_command.fieldAcceptsSpaces && _atTrailingSpace(_callController)) {
        _removeTrailingSpace(_callController);
        _ladder.advancePrimaryFocus();
        return;
      }
      final call = _call;
      // An empty call can't be a command — nothing to interpret, just
      // advance like every other field does when it's empty.
      if (call.isNotEmpty) {
        // While a recognized command prefix is waiting on its parameters
        // (e.g. "RELOAD"), space is a literal character to type, not the
        // advance-focus shortcut — see the `expectsParams` field on
        // CommandInterpretation. Ask the same question _log() asks on Enter,
        // synchronously (awaited) rather than trusting whatever the debounced
        // describe-preview last resolved to: that state can lag up to 150ms
        // behind the latest keystroke, so typing "RELOAD" and hitting space
        // in one fluent motion could otherwise still see the pre-keystroke
        // (stale, not-yet-a-command) interpretation and silently swallow the
        // space by advancing focus instead of inserting it. Reuses the
        // answer the debounce already resolved for this exact text, so this
        // only adds a round trip when genuinely needed.
        if (widget.session.editingQso == null && widget.commands.interpretCommand != null) {
          final (interpretation: result, :stale) = await _command.interpretNow(applyToDisplay: true);
          if (stale || !mounted) return; // stale — the call changed while awaiting
          // A complete mixedCase command (e.g. "NOTE Hello") also keeps
          // space literal — its free-prose parameter is still being typed.
          if (result != null && (result['expectsParams'] == true || result['mixedCase'] == true)) {
            // The exit gesture was already handled above; anywhere else in the
            // value a space is a literal parameter character.
            _insertAtCursor(_callController, ' ');
            return;
          }
        }
      }

      _ladder.advancePrimaryFocus();
    } else if (_radio.freqFocus.hasFocus) {
      _callFocus.requestFocus();
    } else if (widget.so2r?.link.radioB?.freqFocus.hasFocus ?? false) {
      widget.so2r!.link.focusSet('B');
    } else if (_ladder.primaryFocusOrder.any((node) => node.hasFocus)) {
      // An options field accepts the highlighted suggestion first, then advances
      // like everything else. The advance is unconditional either way: it is what
      // an operator's hands expect, and losing it to a field that happens to be
      // searchable would be worse than never suggesting at all.
      //
      // Having walked the highlight with the arrow keys IS a choice, so Space
      // then takes that row as-is; an untouched highlight is still the app
      // guessing, and stays held to the prefix rule.
      _exchange.acceptOnLeave();
      // Every primary field advances on Space, contest exchanges included —
      // asked against the same list the advance walks, so a newly added kind of
      // primary field can never end up in one and not the other. (Call and Freq
      // are caught above; neither is reachable here.)
      _ladder.advancePrimaryFocus();
    } else if (_spotting.commentFocus.hasFocus) {
      // Free prose, like NOTE's parameter: Space types a literal space —
      // the panel-wide shortcut would otherwise swallow it.
      _insertAtCursor(_spotting.commentController, ' ');
    } else if (_notesFocus.hasFocus) {
      // A note is a sentence, so the same applies with more force: without
      // this the panel's Space binding eats every word break and the operator
      // types "Ran5Wtoawire". Unlike the call field there is no advance
      // gesture to preserve — Notes is a secondary control, and the keyboard
      // leaves it by Tab, the arrows or Enter.
      _insertAtCursor(_notesController, ' ');
      _onNotesChanged(_notesController.text);
    }
    // Space is inert in any other field with no override of its own.
    // RefTextInput is the one exception — it binds Space locally to type a
    // literal separator instead, taking priority over this panel-wide
    // shortcut.
  }

  /// Whether the caret sits at the end of a value that already ends in a space
  /// — the double-space that exits a field which otherwise accepts spaces (see
  /// `_handleSpace`'s free-text branch and [VirtualSpaceFormatter]).
  static bool _atTrailingSpace(TextEditingController controller) {
    final selection = controller.selection;
    return controller.text.endsWith(' ') && selection.isCollapsed && selection.baseOffset == controller.text.length;
  }

  /// Drops the space [_atTrailingSpace] found, so the value the operator leaves
  /// behind carries neither it nor the one they just typed to get out.
  static void _removeTrailingSpace(TextEditingController controller) {
    final text = controller.text.substring(0, controller.text.length - 1);
    controller.value = controller.value.copyWith(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
      composing: TextRange.empty,
    );
  }

  /// Synthesizes typing [text] at the cursor — used for the literal space in
  /// _handleSpace's expectsParams branch, since that space is consumed by a
  /// CallbackShortcuts binding and never reaches the field as an ordinary
  /// keystroke. `composing` is deliberately reset to empty: this only runs
  /// while ASCII command text (a space) is being inserted, so there's no
  /// in-progress IME composition of our own to preserve, but explicitly
  /// clearing it (rather than leaving whatever the platform last reported)
  /// avoids carrying over a stale composing range from unrelated typing.
  void _insertAtCursor(TextEditingController controller, String text) {
    controller.value = _typedAtCursor(controller.value, text);
  }

  /// [value] with [text] replacing its selection, the caret after it.
  static TextEditingValue _typedAtCursor(TextEditingValue value, String text) {
    final selection = value.selection;
    final start = selection.start < 0 ? value.text.length : selection.start;
    final end = selection.end < 0 ? value.text.length : selection.end;
    return value.copyWith(
      text: value.text.replaceRange(start, end, text),
      selection: TextSelection.collapsed(offset: start + text.length),
      composing: TextRange.empty,
    );
  }

  /// The field the numbers row types into: whichever editable text field
  /// inside this panel holds the focus — the main fields, the exchange, and
  /// every secondary control's (Freq, Time, Notes, refs, the event text…) —
  /// or, while the More pane is open, inside the pane. Null when focus is
  /// elsewhere or on a read-only field, which is also the gate for showing
  /// the row at all.
  EditableTextState? get _focusedNumberField {
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null || !(_editPaneOpen || primary.ancestors.contains(_focusBackstop.panelScope))) return null;
    final field = primary.context?.findAncestorStateOfType<EditableTextState>();
    return field == null || field.widget.readOnly ? null : field;
  }

  /// The contextual extra key: whatever the focused field declares through
  /// [NumbersRowExtraKey] (the call field's "/" while it holds a partial
  /// callsign, the Freq field's [frequencyMark]), the operator's own decimal
  /// separator in every other field — offered even where a field's filter
  /// drops it (Time, the reports, a numeric exchange). Null when the extra key
  /// is turned off.
  ///
  /// The fallback is the device's mark, not the frequency one: an extension
  /// reads its own fields with the device's separators, so a fixed "." under
  /// comma conventions types grouping, and `0.5` reaches it as 5.
  String? get _numbersRowExtraKey {
    if (!widget.prefs.showExtraInNumbersRow) return null;
    final field = _focusedNumberField;
    return (field == null ? null : NumbersRowExtraKey.of(field.context)) ?? NumberFormatting.instance.decimalSeparator;
  }

  /// How much to reserve below the fields: the bottom safe area (home
  /// indicator), or 0 off mobile / on a device without one (see the spacer in
  /// build).
  ///
  /// Deliberately NOT the keyboard: reserving that is [StatusBarOverlay]'s job,
  /// so the status footer can ride above the keyboard instead of hiding behind
  /// it. Reserving it here too would hold the same strip back twice and leave
  /// the fields floating in the gap.
  ///
  /// And nothing at all while the keyboard is up — the keyboard covers the home
  /// indicator, so the strip the overlay is already holding back IS that space.
  /// The keyboard question goes to the raw view because the overlay consumes
  /// that inset on the way down, leaving MediaQuery unable to tell the two
  /// states apart.
  ///
  /// The strip itself comes from MediaQuery, which is what a host that draws
  /// its own chrome over the bottom edge — the app's status footer, holding
  /// the safe area with a `SafeArea` of its own — takes it out of, so this
  /// panel does not reserve the same space a second time.
  double get _bottomReserve {
    if (!isMobilePlatform || widget.prefs.aboveLog) return 0;
    if (View.of(context).viewInsets.bottom > 0) return 0;
    return MediaQuery.paddingOf(context).bottom;
  }

  /// Whether to show the mobile numbers row right now — the setting is on,
  /// we're on a phone/tablet, the QSO isn't a read-only (staged/already
  /// deleted) view, the on-screen keyboard is up, and one of our logging
  /// fields actually holds the focus (issue #27).
  bool _shouldShowNumbersRow(BuildContext context) {
    return widget.prefs.showNumbersRow &&
        isMobilePlatform &&
        !_fieldsLocked &&
        // Focus is not enough: this panel keeps focus when it is tabbed away
        // from behind a keep-alive, and the row is drawn outside the tab
        // view, so it would hang over whatever replaced it.
        KeyboardAccessoryVisibility.of(context) &&
        virtualKeyboardIsUp(context) &&
        _focusedNumberField != null;
  }

  /// Publishes (or withdraws) the numbers row for this build. Called from
  /// `build` but never mutates during it — the notifier is only written after
  /// the frame, since the overlay that listens sits above this widget and
  /// rebuilding it mid-build would throw.
  ///
  /// The extra key is resolved after the frame too: the focused field's
  /// [NumbersRowExtraKey] sits below this widget (or in the More pane's
  /// route), so during this build it still holds the previous keystroke's
  /// answer.
  void _syncNumbersRow(BuildContext context, ThemeData theme) {
    final accessory = widget.prefs.keyboardAccessory;
    if (accessory == null) return;
    final show = _shouldShowNumbersRow(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!show) {
        accessory.clearIfOwner(this);
        return;
      }
      accessory.publish(
        this,
        KeyboardAccessorySpec(
          onKey: _handleNumberKey,
          extraKey: _numbersRowExtraKey,
          vibrate: widget.prefs.vibrateNumbersRow,
          // The AppBar/footer colour — the app's chrome — deliberately NOT
          // the editing-swappable tertiary/secondary accent, so the row
          // reads as chrome in every mode. (appBarTheme isn't remapped by
          // the editing accent, so `theme` here being the accent theme is
          // fine.)
          backgroundColor: (theme.appBarTheme.backgroundColor ?? theme.colorScheme.primary).toARGB32(),
          foregroundColor: (theme.appBarTheme.foregroundColor ?? theme.colorScheme.onPrimary).toARGB32(),
        ),
      );
    });
  }
}
