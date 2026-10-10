// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Operation view's keyer keys: F1-F8 and ⌥1-⌥8 messages, Enter Sends
// Messages, ['] PTT, and rendering a message against the draft contact.

part of '../operation_view.dart';

mixin _OperationKeying on State<OperationView>, DockHost<OperationView> {
  /// Whether a key could transmit in a Phone mode — a function key playing a
  /// voice memory, or ['] keying PTT — so the draft is tracked for
  /// [_keyingPhone]. Read at build; the view rebuilds on the CAT service's
  /// notifications, so a radio connecting takes effect on the next one.
  bool get _phoneKeyingPossible {
    final settings = widget.services.settings;
    if (!settings.experimentEnabled('keyer') /* stored key, see experiments.yaml */ ) return false;
    return widget.services.cat.canPlayVoice || (settings.pttKey && widget.services.cat.canPtt);
  }

  /// Whether a function key would key anything — the draft is worth
  /// tracking for the messages only once one exists. Read at build, so a
  /// message typed mid-operation takes effect on the next rebuild.
  bool get _cwMessagesConfigured {
    final settings = widget.services.settings;
    if (!settings.experimentEnabled('keyer') /* stored key, see experiments.yaml */ ) return false;
    for (var n = 1; n <= SettingsService.cwMessageCount; n++) {
      if (settings.cwMessage(n).trim().isNotEmpty) return true;
    }
    return false;
  }

  /// The draft as of the last keystroke — [_draftQso] before the debounce
  /// has let it through. Read by [_sendCwMessage] and [_keyingPhone] only.
  Map<String, dynamic>? _latestDraftQso;

  /// Whether the function keys play voice memories rather than key CW:
  /// the draft's mode is Phone. From the LATEST draft, and handed to the
  /// keyer area as a value, so the keys and the strip answer from one
  /// snapshot — the strip's rebuild still waits for the debounce, but a
  /// build never disagrees with the keys about which keyer it is. Before the
  /// view has heard a draft, the radio's mode, which is what a fresh draft
  /// takes: turning PTT on mid-operation publishes nothing new to hear.
  bool get _keyingPhone => superModeForMode((_latestDraftQso?['mode'] as String?) ?? widget.services.radio.vfoA.mode) == 'Phone';

  /// Which radio ['] keys from this view (cat_ptt.dart): radio1, while this
  /// view is in front, the draft is in a Phone mode, and the field with the
  /// keyboard does not take ['] as a character.
  String? _pttTarget() {
    final services = widget.services;
    if (!mounted || testerOverlayCovering.value || !(ModalRoute.of(context)?.isCurrent ?? false)) return null;
    if (!services.settings.experimentEnabled('keyer') /* stored key, see experiments.yaml */ || !services.settings.pttKey) return null;
    if (!_keyingPhone || !services.cat.canPtt || !quoteKeysPtt(FocusManager.instance.primaryFocus?.context)) return null;
    return services.cat.localRadio1;
  }

  /// F1-F8 key the matching CW message through the key in use — or, while
  /// the draft contact is in a Phone mode, play the matching voice memory
  /// of radio1; Escape stops every message, chain and repeat. Only while
  /// this view is the front-most route — a dialog over it (the message
  /// editors included) owns the keyboard — and only with a radio that can
  /// key (or play), so on a station without one the keys stay free for
  /// whatever else wants them.
  bool _onCwKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (testerOverlayCovering.value) return false;
    if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? false)) return false;
    final services = widget.services;
    // A keypress by itself stops nothing: what a call typed over a CQ stops
    // is decided by the callsign field (LoggingSession.onCallTyped), which
    // hears every way a call is entered and not only a hardware key.
    if (!services.settings.experimentEnabled('keyer') /* stored key, see experiments.yaml */ ) return false;
    final cat = services.cat;
    final keyboard = HardwareKeyboard.instance;
    final command = keyboard.isMetaPressed || keyboard.isControlPressed;
    final alt = keyboard.isAltPressed;
    final shift = keyboard.isShiftPressed;

    // ⌥K / Alt+K turns the keyer area's keyboard mode on or off. By the
    // PHYSICAL key: on a Mac, Option turns K into '˚', and the logical key
    // a browser reports is that character. Not ⌘K, which is the command
    // dialog's (halo_app.dart).
    if (alt && !command && !shift && event.physicalKey == PhysicalKeyboardKey.keyK) {
      if (_keyingPhone || !cat.canKeyCw) return false;
      cat.toggleKeyboardMode();
      return true;
    }

    final int? n;
    if (command || alt) {
      // ⌥1-⌥8 (Alt+1-8) stand in for F1-F8 on a keyboard without them; any
      // other chord is not the keyer's. Not in free text: on a Spanish,
      // Nordic or German Mac layout ⌥2 is how '@' is typed, and ⌥5-⌥8 are
      // '[' ']' '|' '{' — a note would key a message in their place.
      n = alt && !command && !shift && !_focusInFreeText() ? cwMessageIndexForDigit(event.physicalKey) : null;
      if (n == null) return false;
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      // Stops a message from wherever focus is. NOT what keeps the logging
      // fields from also acting on the same keystroke — a handler's answer
      // here never stops the focus tree's dispatch — that is
      // LoggingSession.escapeClaimed, wired in logging_panel.dart. With
      // nothing to stop, Escape keeps its usual meaning. Ahead of the
      // capability gate below, and for either keyer whatever the mode: a CW
      // message keyed just before the draft went to SSB is still the one
      // to stop, on a station whose radio plays no voice at all.
      return cat.stopKeying();
    } else {
      n = cwMessageIndexForKey(event.logicalKey);
    }

    // The DRAFT's mode decides — [_keyingPhone], the same answer the keyer
    // area is built with: the message is for the contact being logged,
    // whatever the rig sits in.
    final phone = _keyingPhone;
    if (phone ? !cat.canPlayVoice : !cat.canKeyCw) return false;

    if (n == null) return false;
    if (phone) {
      // A key past the radio's last memory keys nothing, and stays free.
      if (n > cat.voiceMemoryCount) return false;
      // A recording is not interrupted by a play: the dialog disables its
      // buttons while one runs, and a key must not do what a button cannot
      // — on a K4 the recording would be lost unsaved.
      if (cat.voiceActivity.value?.recording ?? false) return true;
      _endChainsForKey();
      cat.playVoiceMemory(n);
      return true;
    }
    final template = services.settings.cwMessage(n);
    if (template.trim().isEmpty) return false;
    _endChainsForKey();
    unawaited(_sendCwMessage(n, template));
    return true;
  }

  /// Whether the keyboard is in a text field other than the main logging
  /// fields — notes, comments, keyboard mode's own field — where an ⌥-digit
  /// is a character the operator is typing. The call, RST and exchange
  /// fields (the entry row) never take one, so a chord there is the keyer's.
  bool _focusInFreeText() {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null || context.findAncestorWidgetOfExactType<EditableText>() == null) return false;
    return context.findAncestorWidgetOfExactType<LoggingEntryRow>() == null;
  }

  /// A message key ends whatever repeat or sequence is running: another
  /// message is the operator moving on, and F1 starts a FRESH chain with its
  /// own five minutes rather than extending the one it lands in.
  void _endChainsForKey() {
    widget.services.cat.cancelKeyerRepeat();
    widget.services.cat.cancelVoiceSequence();
  }

  /// Keys what an Enter picked (logging-fields.md § Enter Sends Messages),
  /// through the keyer the draft's mode picks, as the function keys would.
  /// A slot with nothing in it is skipped rather than refused: a set with no
  /// TU still completes the contact.
  ///
  /// In CW the thanks waits for [logged] and renders against the entry the
  /// log left behind (see [EnterSends.send]), queued behind the rest so it is
  /// still keyed last. Voice keeps one sequence at the keypress: a memory
  /// renders nothing, and a second sequence would cut the first off.
  void _sendEsmMessages(List<EsmMessage> messages, Map<String, dynamic> qso, {Future<Map<String, dynamic>?>? logged}) {
    final services = widget.services;
    final keys = [for (final message in messages) CwMessageSet.esmKeys[message]!];
    // What a key does before it sends, for an Enter that never passed
    // through [_onCwKeyEvent] — an on-screen keyboard's.
    services.cat.cancelKeyerRepeat();
    services.cat.cancelVoiceSequence();
    if (superModeForMode(qso['mode'] as String?) == 'Phone') {
      // The operator says the other station's call: no memory can hold it.
      final memories = [
        for (final n in keys)
          if (n != CwMessageSet.esmKeys[EsmMessage.hisCall] && n <= services.cat.voiceMemoryCount) n,
      ];
      if (memories.isEmpty || (services.cat.voiceActivity.value?.recording ?? false)) return;
      services.cat.playVoiceSequence(memories);
      return;
    }
    List<({int n, String template})> templatesFor(Iterable<int> keys) => [
      for (final n in keys)
        if (services.settings.cwMessage(n).trim().isNotEmpty) (n: n, template: services.settings.cwMessage(n)),
    ];
    final thanks = CwMessageSet.esmKeys[EsmMessage.thanks]!;
    final deferred = logged != null ? templatesFor(keys.where((n) => n == thanks)) : const <({int n, String template})>[];
    final now = templatesFor(keys.where((n) => logged == null || n != thanks));
    final sent = now.isEmpty ? Future.value(true) : _sendCwMessages(now, qso: qso, once: true);
    if (deferred.isEmpty) {
      unawaited(sent);
      return;
    }
    // Not [once]: every thanks is the same `TU`, and the one still waiting
    // behind the last exchange belongs to the last contact, not this one. And
    // none at all after a first part that failed — a TU to a station that
    // never heard its call or report is not an exchange.
    unawaited(() async {
      final keyed = await sent;
      final after = await logged!;
      if (!keyed || after == null || !mounted) return;
      await _sendCwMessages(deferred, qso: after);
    }());
  }

  /// The keyer area's message buttons: the same send the function keys make.
  void _sendCwMessageNumber(int n) {
    final template = widget.services.settings.cwMessage(n);
    if (template.trim().isEmpty) return;
    unawaited(_sendCwMessage(n, template));
  }

  /// A message other than 1 ends a repeat: the operator has moved on to the
  /// exchange, and message 1 is a CQ nobody wants keyed over it. Called
  /// where the keyer area's buttons arrive, since a tap reaches no key
  /// handler.
  void _sendCwMessageFromArea(int n) {
    if (n != 1) widget.services.cat.cancelKeyerRepeat();
    _sendCwMessageNumber(n);
  }

  /// Renders message [n]'s template against the operation and the draft
  /// contact (the same context a panel gets — docs/extensions/templates.md),
  /// then hands the text to the radio. A template that does not parse is
  /// the operator's own typo, shown where they will see it rather than sent
  /// as-is with the braces keyed out in Morse.
  Future<void> _sendCwMessage(int n, String template) => _sendCwMessages([(n: n, template: template)]);

  /// [_sendCwMessage] for several messages keyed as ONE — Enter Sends
  /// Messages' "his call, then the exchange" — so they go out back to back
  /// as a single entry in the queue and the keyer area, not as a message and
  /// a second one waiting behind it. [qso] is the draft to render against
  /// when the caller holds a newer one than [_latestDraftQso] (ESM's, taken
  /// at the Enter that may log and wipe it). Any template failing keys
  /// nothing at all: half an exchange is not an exchange.
  ///
  /// [once] is ESM's: a message already keying or waiting — whoever queued
  /// it — is not queued again, so a second Enter before the first CQ or AGN?
  /// has finished doesn't send it twice. A DIFFERENT message still queues.
  ///
  /// Answers false when they failed — a notice already says so — or the key
  /// did not take them, so a caller keying more after them can hold back.
  /// Rendering to nothing is not a failure: there was nothing to send.
  Future<bool> _sendCwMessages(List<({int n, String template})> messages, {Map<String, dynamic>? qso, bool once = false}) async {
    final services = widget.services;
    final ctx = panelRenderContext;
    final parts = <String>[];
    for (final (:n, :template) in messages) {
      String? text;
      String? failure;
      try {
        text = await services.extensions.renderTemplate(
          template,
          operation: ctx.operation == null ? null : operationHookArgs(ctx.operation!),
          qso: qso ?? _latestDraftQso ?? ctx.qso,
          qsoCount: ctx.qsoCount,
          keyer: {'messages': services.settings.activeCwMessageSet.messages, 'current': n},
        );
      } on TemplateError catch (e) {
        failure = e.message;
      } catch (e, st) {
        // A hook timeout or a dead runtime — reported, and ALSO said here:
        // the operator pressed a key and nothing keyed, which the console
        // alone would leave them to discover on the air.
        ErrorReportingService.report(e, st, context: 'cw:render-message');
        failure = '$e';
      }
      // Leaving the operation while the render was in flight is leaving the
      // message behind too — nothing goes on the air from a view that is gone.
      if (!mounted) {
        services.cat.cancelKeyerRepeat();
        return false;
      }
      if (failure != null) {
        services.statusBar.showNotice(
          key: 'cw-message-$n',
          icon: 'alert-circle-outline',
          text: context.t.commands.cwMessageError(n: n, error: failure),
          persist: false,
        );
        services.cat.cancelKeyerRepeat();
        return false;
      }
      if (text == null) {
        // No runtime to render with (restarting, or failed to load): a key
        // that keys nothing must not look like a key that worked.
        services.statusBar.showNotice(
          key: 'cw-message-$n',
          icon: 'alert-circle-outline',
          text: context.t.commands.cwMessageNotRendered(n: n),
          persist: false,
        );
        services.cat.cancelKeyerRepeat();
        return false;
      }
      if (text.trim().isNotEmpty) parts.add(text.trim());
    }
    final text = parts.join(' ');
    // A chain waits for the message to STOP keying before its next send, so
    // a send that keys nothing — a failed render, a dead runtime, a message
    // that sanitizes away, a radio gone between repeats — would leave it
    // armed with nothing to end it, and the keyer area showing neither
    // buttons nor a countdown.
    if (text.trim().isEmpty) {
      services.cat.cancelKeyerRepeat();
      return true;
    }
    final progress = once && services.cat.cwSending ? services.cat.cwProgress.value : null;
    final sanitized = sanitizeCwText(text);
    final queued = progress != null && (progress.text == sanitized || progress.pending.contains(sanitized));
    if (!queued) {
      final taken = services.cat.sendCw(text, hasMessageOne: messages.any((m) => m.n == 1));
      // Nothing keying after the send is a message the queue dropped (empty
      // once sanitized), a radio that went away, or a peer yet to report —
      // either way there is no end coming to start the next wait on.
      if (!services.cat.cwSending) {
        services.cat.cancelKeyerRepeat();
        return taken;
      }
    }
    // Message 1 only — see SettingsService.cwRepeatDelay. Armed after the
    // send, so the wait starts from the message ENDING rather than from the
    // keypress — and armed for one already queued too: the Enter that found
    // it there cancelled the chain it belonged to.
    final delay = services.settings.cwRepeatDelay;
    if (messages.length == 1 && messages.single.n == 1 && delay > Duration.zero) {
      services.cat.armKeyerRepeat(delay: delay, text: text, send: () => _sendCwMessageNumber(1));
    }
    return true;
  }
}
