// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Operation view's keyer keys: the messages (F1-F8 and ⌥1-⌥8 unless
// rebound), Enter Sends Messages, PTT, and rendering a message against the draft contact.

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

  /// Each radio's last Enter Sends Messages CW send — see [_sendEsmMessages].
  /// One per radio: a step on one radio never waits on the other's.
  final _esmSending = <String, Future<void>>{};

  /// Whether the function keys play voice memories rather than key CW:
  /// the draft's mode is Phone. From the LATEST draft, and handed to the
  /// keyer area as a value, so the keys and the strip answer from one
  /// snapshot — the strip's rebuild still waits for the debounce, but a
  /// build never disagrees with the keys about which keyer it is. Before the
  /// view has heard a draft, the operator's radio's mode, which is what a
  /// fresh draft takes: turning PTT on mid-operation publishes nothing new to
  /// hear.
  bool get _keyingPhone {
    final vfo = widget.services.radio.vfo(widget.services.cat.operatorRadio == 'B' ? 'vfoB' : 'vfoA');
    return superModeForMode((_latestDraftQso?['mode'] as String?) ?? vfo.mode) == 'Phone';
  }

  /// Which radio the PTT key keys from this view (cat_ptt.dart): the
  /// operator's — radio1, or under SO2R the radio of the set they are in —
  /// while this view is in front and the draft is in a Phone mode.
  String? _pttTarget() {
    final services = widget.services;
    if (!mounted || testerOverlayCovering.value || !(ModalRoute.of(context)?.isCurrent ?? false)) return null;
    if (!services.settings.experimentEnabled('keyer') /* stored key, see experiments.yaml */ || !services.settings.pttKey) return null;
    if (!_keyingPhone) return null;
    final cat = services.cat;
    if (!keyerOrSay(context, services, cat.operatorKeyer, () => cat.operatorKeyer.canPtt)) return null;
    return cat.operatorRadio == 'B' ? cat.radio2 : cat.localRadio1;
  }

  /// The message keys (F1-F8 and ⌥1-⌥8 unless rebound) key the matching CW
  /// message through the operator's radio's key — or, while
  /// the draft contact is in a Phone mode, play the matching voice memory
  /// of that radio; Escape stops every message, chain and repeat. Only while
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
    // Under SO2R, the radio of the set the operator is in.
    final keyer = cat.operatorKeyer;
    final bindings = keyBindings.value;

    // Keyboard mode on or off. Not ⌘K by default, which is the command
    // dialog's (halo_app.dart).
    if (bindings.claim('keyer.keyboardMode', event) != null) {
      if (_keyingPhone) return false;
      if (!keyerOrSay(context, services, keyer, () => keyer.canKeyCw)) return keyer.radio == 'B';
      keyer.toggleKeyboardMode();
      return true;
    }

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      final keyboard = HardwareKeyboard.instance;
      if (keyboard.isMetaPressed || keyboard.isControlPressed || keyboard.isAltPressed) return false;
      // Stops a message from wherever focus is. NOT what keeps the logging
      // fields from also acting on the same keystroke — a handler's answer
      // here never stops the focus tree's dispatch — that is
      // LoggingSession.escapeClaimed, wired in logging_panel.dart. With
      // nothing to stop, Escape keeps its usual meaning. Ahead of the
      // capability gate below, and for either keyer whatever the mode: a CW
      // message keyed just before the draft went to SSB is still the one
      // to stop, on a station whose radio plays no voice at all.
      return cat.stopKeying();
    }

    int? n;
    for (var i = 1; i <= SettingsService.cwMessageCount; i++) {
      final chord = bindings.match('keyer.message$i', event);
      if (chord == null) continue;
      // Not where a field takes the character: on a Spanish, Nordic or German
      // Mac layout ⌥2 is how '@' is typed, and ⌥5-⌥8 are '[' ']' '|' '{' — a
      // note would key a message in their place.
      if (bindings.yieldsToField('keyer.message$i', chord, event)) return false;
      n = i;
      break;
    }

    if (n == null) return false;
    // The DRAFT's mode decides — [_keyingPhone], the same answer the keyer
    // area is built with: the message is for the contact being logged,
    // whatever the rig sits in. Under SO2R, on the radio of the set the
    // operator is in, which takes its turn on the air with the other one
    // (docs/design/cat.md § Radio B, for SO2R).
    final phone = _keyingPhone;
    if (phone) {
      // A recording is not interrupted by a play: the dialog disables its
      // buttons while one runs, and a key must not do what a button cannot
      // — on a K4 the recording would be lost unsaved.
      if (keyer.voiceActivity.value?.recording ?? false) return true;
      // A key past the radio's last memory keys nothing, and stays free.
      if (keyer.canPlayVoice && n > keyer.voiceMemoryCount) return false;
      if (!keyerOrSay(context, services, keyer, () => keyer.canPlayVoice)) return keyer.radio == 'B';
      _endChainsForKey(keyer);
      keyer.playVoiceMemory(n);
      return true;
    }
    final template = services.settings.cwMessage(n);
    if (template.trim().isEmpty) return false;
    if (!keyerOrSay(context, services, keyer, () => keyer.canKeyCw)) return keyer.radio == 'B';
    _endChainsForKey(keyer);
    unawaited(_sendCwMessages([(n: n, template: template)], radio: keyer.radio, pressed: services.cat.keyMark));
    return true;
  }

  /// A message key ends whatever repeat or sequence is running on its radio:
  /// another message is the operator moving on, and F1 starts a FRESH chain
  /// with its own five minutes rather than extending the one it lands in.
  /// The other SO2R radio's repeat is left to the turns
  /// ([KeyingStation.clearToSend]).
  void _endChainsForKey(RadioKeyer keyer) {
    keyer.cancelKeyerRepeat();
    keyer.cancelVoiceSequence();
  }

  /// Keys what an Enter picked (logging-fields.md § Enter Sends Messages),
  /// through the keyer the draft's mode picks, as the function keys would.
  /// A slot with nothing in it is skipped rather than refused: a set with no
  /// TU still completes the contact.
  ///
  /// In CW each step keys after the one before it, and a thanks waits for
  /// [logged] too, rendering against the contact as saved, with the entry the
  /// log left behind as `next` (see [EnterSends.send]). Voice keeps one sequence at the keypress: a memory
  /// renders nothing, and a second sequence would cut the first off.
  void _sendEsmMessages(String radio, List<EsmMessage> messages, Map<String, dynamic> qso, {Future<EsmLogged?>? logged}) {
    final services = widget.services;
    final keyer = services.cat.keyer(radio);
    final keys = [for (final message in messages) CwMessageSet.esmKeys[message]!];
    // The operator says the other station's call: no memory can hold it.
    List<int> memories() => [
      for (final n in keys)
        if (n != CwMessageSet.esmKeys[EsmMessage.hisCall] && n <= keyer.voiceMemoryCount) n,
    ];
    final templates = [
      for (final n in keys)
        if (services.settings.cwMessage(n).trim().isNotEmpty) (n: n, template: services.settings.cwMessage(n)),
    ];
    // What a key does before it sends, for an Enter that never passed
    // through [_onCwKeyEvent] — an on-screen keyboard's: nothing, unless
    // there is something to send on the radio.
    if (superModeForMode(qso['mode'] as String?) == 'Phone') {
      if (keyer.voiceActivity.value?.recording ?? false) return;
      if (!keyerOrSay(context, services, keyer, () => keyer.canPlayVoice && memories().isNotEmpty)) return;
      keyer.cancelKeyerRepeat();
      keyer.cancelVoiceSequence();
      keyer.playVoiceSequence(memories());
      return;
    }
    if (templates.isEmpty) return;
    if (!keyerOrSay(context, services, keyer, () => keyer.canKeyCw)) return;
    keyer.cancelKeyerRepeat();
    keyer.cancelVoiceSequence();
    final pressed = services.cat.keyMark;
    // Each step renders its messages one by one, so two Enters close
    // together would otherwise race: a TU rendered while the answer before
    // it is still rendering keys first. A step that logs and thanks is the
    // thanks alone (esmStep); S&P's exchange logs too, but keys unwaited.
    _esmSending[radio] = (_esmSending[radio] ?? Future.value()).then((_) async {
      try {
        if (logged == null || !messages.contains(EsmMessage.thanks)) {
          return await _sendCwMessages(templates, radio: radio, qso: qso, once: true, pressed: pressed);
        }
        // Not [once]: every thanks is the same `TU`, and the one still
        // waiting behind the last exchange belongs to the last contact.
        final after = await logged;
        if (after != null && mounted) await _sendCwMessages(templates, radio: radio, qso: after.qso, next: after.next, pressed: pressed);
      } catch (e, st) {
        // Reported rather than left on the chain, where it would stop every
        // later step from keying at all.
        ErrorReportingService.report(e, st, context: 'cw:esm-send');
      }
    });
  }

  /// The keyer area's message buttons: the same send the function keys make,
  /// on [radio]. [repeat] is a repeat chain's own send — see
  /// [_sendCwMessages].
  void _sendCwMessageNumber(int n, {required String radio, bool repeat = false}) {
    final template = widget.services.settings.cwMessage(n);
    if (template.trim().isEmpty) return;
    unawaited(_sendCwMessages([(n: n, template: template)], radio: radio, repeat: repeat, pressed: widget.services.cat.keyMark));
  }

  /// A message other than 1 ends a repeat: the operator has moved on to the
  /// exchange, and message 1 is a CQ nobody wants keyed over it. Called
  /// where a keyer area's buttons arrive, since a tap reaches no key
  /// handler — on that area's radio.
  void _sendCwMessageFromArea(int n, String radio) {
    if (widget.services.settings.cwMessage(n).trim().isEmpty) return;
    final keyer = widget.services.cat.keyer(radio);
    if (!keyerOrSay(context, widget.services, keyer, () => keyer.canKeyCw)) return;
    if (n != 1) keyer.cancelKeyerRepeat();
    _sendCwMessageNumber(n, radio: radio);
  }

  /// Renders each message's template against the operation and the draft
  /// contact (the same context a panel gets — docs/extensions/templates.md),
  /// then hands the text to [radio]'s keyer. A template that does not parse
  /// is the operator's own typo, shown where they will see it rather than
  /// sent as-is with the braces keyed out in Morse.
  ///
  /// Several messages are keyed as ONE — Enter Sends Messages' "his call,
  /// then the exchange" — so they go out back to back
  /// as a single entry in the queue and the keyer area, not as a message and
  /// a second one waiting behind it. [qso] is the draft to render against
  /// when the caller holds a newer one than [_latestDraftQso] (ESM's, taken
  /// at the Enter that may log and wipe it, or the contact just logged).
  /// [next] is the entry up next, only beside a [qso] already logged — see
  /// [EnterSends.send]. Any template failing keys nothing at all: half an
  /// exchange is not an exchange.
  ///
  /// [once] is ESM's: a message already keying or waiting — whoever queued
  /// it — is not queued again, so a second Enter before the first CQ or AGN?
  /// has finished doesn't send it twice. A DIFFERENT message still queues.
  ///
  /// [repeat] is a repeat chain's own send, which keys nothing if the chain
  /// ended while it rendered: an Escape, a tap or a QSY landing in that gap
  /// would otherwise key the CQ anyway and arm a fresh chain behind it.
  ///
  /// [pressed] is [CatService.keyMark] at the keypress: an operator's
  /// message the other SO2R radio was keyed over since keys nothing
  /// ([CatService.keyedOverSince]).
  Future<void> _sendCwMessages(
    List<({int n, String template})> messages, {
    required String radio,
    required int pressed,
    Map<String, dynamic>? qso,
    Map<String, dynamic>? next,
    bool once = false,
    bool repeat = false,
  }) async {
    final services = widget.services;
    final keyer = services.cat.keyer(radio);
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
          next: next,
          qsoCount: ctx.qsoCount,
          keyer: {'messages': services.settings.activeCwMessageSet.messages, 'current': n},
        );
      } on TemplateError catch (e) {
        failure = e.message;
      } catch (e, st) {
        // A hook timeout or a dead runtime — reported, and ALSO said here:
        // the operator pressed a key and nothing keyed, which the console
        // alone would leave them to discover on the air.
        // Told only while mounted: nothing awaits between here and the check
        // below that returns before the notice when the view is gone.
        ErrorReportingService.report(e, st, context: 'cw:render-message', told: mounted);
        failure = ErrorReportingService.messageOf(e);
      }
      // Leaving the operation while the render was in flight is leaving the
      // message behind too — nothing goes on the air from a view that is gone.
      if (!mounted) {
        keyer.cancelKeyerRepeat();
        return;
      }
      if (failure != null) {
        services.statusBar.showNotice(
          key: 'cw-message-$n',
          icon: 'alert-circle-outline',
          text: context.t.commands.cwMessageError(n: n, error: failure),
          persist: false,
        );
        keyer.cancelKeyerRepeat();
        return;
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
        keyer.cancelKeyerRepeat();
        return;
      }
      if (text.trim().isNotEmpty) parts.add(text.trim());
    }
    if (repeat && !keyer.keyerRepeating) return;
    if (!repeat && services.cat.keyedOverSince(radio, pressed)) return;
    final text = parts.join(' ');
    // A chain waits for the message to STOP keying before its next send, so
    // a send that keys nothing — a failed render, a dead runtime, a message
    // that sanitizes away, a radio gone between repeats — would leave it
    // armed with nothing to end it, and the keyer area showing neither
    // buttons nor a countdown.
    if (text.trim().isEmpty) {
      keyer.cancelKeyerRepeat();
      return;
    }
    final progress = once && keyer.cwSending ? keyer.cwProgress.value : null;
    final sanitized = sanitizeCwText(text);
    final queued = progress != null && (progress.text == sanitized || progress.pending.contains(sanitized));
    if (!queued) {
      final sent = keyer.sendCw(text, hasMessageOne: messages.any((m) => m.n == 1), repeat: repeat);
      // Radio B gone between the key and the send: the key keyed nothing,
      // which must not look like a key that worked — as [keyerOrSay] says at
      // the key.
      if (!sent && radio == 'B' && mounted) {
        services.statusBar.showNotice(
          key: 'so2r-cannot-key',
          icon: 'alert-circle-outline',
          text: context.t.commands.so2rRadioCannotKey(radio: 'B'),
          persist: false,
        );
      }
      // Nothing keying or waiting its turn after the send is a message the
      // queue dropped (empty once sanitized), a radio that went away, or a
      // peer yet to report — either way there is no end coming to start the
      // next wait on.
      if (!keyer.cwSending && !keyer.waiting.value.any((send) => send.memory == null)) {
        keyer.cancelKeyerRepeat();
        return;
      }
    }
    // Message 1 only — see SettingsService.cwRepeatDelay. Armed after the
    // send, so the wait starts from the message ENDING rather than from the
    // keypress — and armed for one already queued too: the Enter that found
    // it there cancelled the chain it belonged to.
    final delay = services.settings.cwRepeatDelay;
    if (messages.length == 1 && messages.single.n == 1 && delay > Duration.zero) {
      keyer.armKeyerRepeat(
        delay: delay,
        text: text,
        send: () => _sendCwMessageNumber(1, radio: radio, repeat: true),
      );
    }
    return;
  }
}
