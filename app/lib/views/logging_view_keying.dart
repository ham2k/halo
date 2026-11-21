// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HardwareKeyboard, KeyDownEvent, KeyEvent, LogicalKeyboardKey;
import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../services/cat/cat_service.dart' show CatService, RadioKeyer;
import '../services/cat/computer_voice_keyer.dart' show ComputerVoiceProblem, VoicedMessageRefused;
import '../services/cat/drivers/cw_send_queue.dart' show sanitizeCwText;
import '../services/cat/voiced_words.dart' show VoiceTemplateRender;
import '../services/error_reporting_service.dart';
import '../services/extensions/extension_service.dart' show TemplateError;
import '../services/panel_service.dart' show operationHookArgs;
import '../services/settings_service.dart';
import 'app_shell/system_back.dart';
import 'dock_host.dart';
import 'keyer_area.dart' show cwKeyerOrSay, keyerOrSay;
import 'tester_overlay.dart' show testerOverlayCovering;
import 'voice_messages_dialog.dart' show computerVoiceProblemText;

/// Manual CW and voice memories for a logging view. The view supplies the
/// active draft and pairs its input handlers with its own visibility lifecycle.
mixin LoggingViewKeying<T extends StatefulWidget> on State<T>, DockHost<T> {
  String get keyingRadio => dockServices.cat.operatorRadio;

  /// Chasing can leave the home rail without being disposed.
  bool get keyingVisible => true;

  bool get keyingInFront => mounted && keyingVisible && !testerOverlayCovering.value && (ModalRoute.of(context)?.isCurrent ?? false);

  bool canFinishCwKeying(String radio) => mounted && keyingVisible;

  int _keyingSession = 0;

  void startKeyingInput() {
    HardwareKeyboard.instance.addHandler(_onKeyingEvent);
    systemBack.addHandler(_onSystemBack);
    dockServices.cat.messageKeyRequests.addListener(_onMessageKeyRequest);
    dockServices.cat.keyer('A').voicedWords?.attach(_voiceRender, operatorCall: _voiceOperatorCall, refused: _voiceRefused);
  }

  void stopKeyingInput() {
    _keyingSession++;
    HardwareKeyboard.instance.removeHandler(_onKeyingEvent);
    systemBack.removeHandler(_onSystemBack);
    dockServices.cat.messageKeyRequests.removeListener(_onMessageKeyRequest);
    dockServices.cat.keyer('A').voicedWords?.detach(_voiceRender);
  }

  /// Shortcuts that belong to an operation rather than to the keyer.
  bool handleOperatingKey(KeyEvent event) => false;

  bool get voiceKeyingPossible => dockServices.cat.keyer(keyingRadio).canPlayVoice;

  /// Whether a function key would key anything — the draft is worth
  /// tracking for the messages only with a keyer ([CatService.hasKeyer]) and
  /// a message to key. Not a radio that can key right now: one dropping for a
  /// moment would leave the draft unpublished, and the next message keyed
  /// against the contact before it. Read at build, so a message typed
  /// mid-operation takes effect on the next rebuild.
  bool get cwMessagesConfigured {
    if (!dockServices.cat.hasKeyer) return false;
    final settings = dockServices.settings;
    for (var n = 1; n <= SettingsService.cwMessageCount; n++) {
      if (settings.cwMessage(n).trim().isNotEmpty) return true;
    }
    return false;
  }

  /// The latest published draft, before any debounce for panel updates.
  Map<String, dynamic>? latestKeyingDraft;

  /// Whether the function keys play voice memories rather than key CW:
  /// the draft's mode is Phone. From the LATEST draft, and handed to the
  /// keyer area as a value, so the keys and the strip answer from one
  /// snapshot — the strip's rebuild still waits for the debounce, but a
  /// build never disagrees with the keys about which keyer it is. Before the
  /// view has heard a draft, the operator's radio's mode, which is what a
  /// fresh draft takes: turning PTT on mid-operation publishes nothing new to
  /// hear.
  bool get keyingPhone => keyingSuperMode == 'Phone';

  /// The draft's super-mode, from the same snapshot: the logging panel reads
  /// Phone from it as these keys do, and Digital to disable the keyer's pill.
  String? get keyingSuperMode {
    final vfo = dockServices.radio.vfo('vfo$keyingRadio');
    return superModeForMode((latestKeyingDraft?['mode'] as String?) ?? vfo.mode);
  }

  /// The message keys (F1-F8 and ⌥1-⌥8 unless rebound) key the matching CW
  /// message through the operator's radio's key — or, while
  /// the draft contact is in a Phone mode, play the matching voice memory
  /// of that radio; Escape stops every message, chain and repeat. Only while
  /// this view is visible on the front-most route — a dialog over it (the message
  /// editors included) owns the keyboard — and only with a radio that can
  /// key (or play), so on a station without one the keys stay free for
  /// whatever else wants them.
  bool _onKeyingEvent(KeyEvent event) {
    if (event is! KeyDownEvent || !keyingInFront) return false;
    if (handleOperatingKey(event)) return true;
    final services = dockServices;
    // A keypress by itself stops nothing: what a call typed over a CQ stops
    // is decided by the callsign field (LoggingSession.onCallTyped), which
    // hears every way a call is entered and not only a hardware key.
    final cat = services.cat;
    // Under SO2R, the radio of the set the operator is in.
    final keyer = cat.keyer(keyingRadio);
    final bindings = keyBindings.value;

    // Keyboard mode on or off. Not ⌘K by default, which is the command
    // dialog's (halo_app.dart).
    if (bindings.claim('keyer.keyboardMode', event) != null) {
      // The CW keyer's alone: nothing keys in a Digital mode either.
      if (keyingPhone || keyingSuperMode == 'Digital') return false;
      if (!cwKeyerOrSay(context, services, keyer)) return keyer.radio == 'B';
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
      return _stopKeying();
    }
    // Escape's job, on a key of the operator's choosing. Unlike Escape it is
    // taken even with nothing to stop: it has no other meaning to fall back to.
    if (bindings.claim(keyerStopCommandId, event) != null) {
      _stopKeying();
      return true;
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
    return _keyMessage(n);
  }

  /// A system back stops what Escape stops before it leaves this view: many
  /// tablet keyboards send Back from their Escape key, and the Navigator's
  /// answer to it is closing this view with the message still keying. With
  /// nothing to stop, the back goes on to the Navigator.
  bool _onSystemBack() {
    return keyingInFront && _stopKeying();
  }

  bool _stopKeying() {
    _keyingSession++;
    return dockServices.cat.stopKeying();
  }

  /// Message [n] from a function key that is not the keyboard's — a MIDI
  /// controller's (CatKeying.messageKeyRequests). Only while this view is in
  /// front, as the keyboard's F-keys are: the message renders against ITS
  /// draft.
  void _onMessageKeyRequest() {
    final request = dockServices.cat.messageKeyRequests.value;
    if (request == null || !keyingInFront) return;
    _keyMessage(request.message);
  }

  /// What a message key [n] does, wherever it was pressed; whether it claimed
  /// the key.
  bool _keyMessage(int n) {
    final services = dockServices;
    final cat = services.cat;
    final keyer = cat.keyer(keyingRadio);
    // Nothing keys in a Digital mode, where the keyer's pill is disabled too:
    // the key stays free, as one past the radio's last memory does.
    if (keyingSuperMode == 'Digital') return false;
    // The DRAFT's mode decides — [keyingPhone], the same answer the keyer
    // area is built with: the message is for the contact being logged,
    // whatever the rig sits in. Under SO2R, on the radio of the set the
    // operator is in, which takes its turn on the air with the other one
    // (docs/design/cat.md § Radio B, for SO2R).
    final phone = keyingPhone;
    if (phone) {
      // A recording is not interrupted by a play: the dialog disables its
      // buttons while one runs, and a key must not do what a button cannot
      // — on a K4 the recording would be lost unsaved.
      if (keyer.voiceActivity.value?.recording ?? false) return true;
      // A key past the radio's last memory keys nothing, and stays free.
      if (keyer.canPlayVoice && n > keyer.voiceMemoryCount) return false;
      if (!keyerOrSay(context, services, keyer, () => keyer.canPlayVoice)) return keyer.radio == 'B';
      // Behind what the radio is playing, as CW queues on the key.
      keyer.cancelKeyerRepeat();
      keyer.queueVoiceMemory(n);
      return true;
    }
    final template = services.settings.cwMessage(n);
    if (template.trim().isEmpty) return false;
    if (!cwKeyerOrSay(context, services, keyer)) return keyer.radio == 'B';
    _endChainsForKey(keyer);
    unawaited(sendCwMessages([(n: n, template: template)], radio: keyer.radio, pressed: services.cat.keyMark));
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

  /// The keyer area's message buttons: the same send the function keys make,
  /// on [radio]. [repeat] is a repeat chain's own send — see
  /// [sendCwMessages].
  void _sendCwMessageNumber(int n, {required String radio, VoidCallback? repeatingSend}) {
    final template = dockServices.settings.cwMessage(n);
    if (template.trim().isEmpty) {
      if (repeatingSend != null) dockServices.cat.keyer(radio).cancelKeyerRepeat();
      return;
    }
    unawaited(sendCwMessages([(n: n, template: template)], radio: radio, repeatingSend: repeatingSend, pressed: dockServices.cat.keyMark));
  }

  /// A message other than 1 ends a repeat: the operator has moved on to the
  /// exchange, and message 1 is a CQ nobody wants keyed over it. Called
  /// where a keyer area's buttons arrive, since a tap reaches no key
  /// handler — on that area's radio.
  void sendCwMessageFromArea(int n, String radio) {
    if (!keyingInFront || keyingPhone || keyingSuperMode == 'Digital') return;
    if (dockServices.settings.cwMessage(n).trim().isEmpty) return;
    final keyer = dockServices.cat.keyer(radio);
    if (!cwKeyerOrSay(context, dockServices, keyer)) return;
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
  /// when the caller holds a newer one than [latestKeyingDraft] (ESM's, taken
  /// at the Enter that may log and wipe it, or the contact just logged).
  /// [next] is the entry up next, only beside a [qso] already logged — see
  /// [EnterSends.send]. Any template failing keys nothing at all: half an
  /// exchange is not an exchange.
  ///
  /// [once] is ESM's: a message already keying or waiting — whoever queued
  /// it — is not queued again, so a second Enter before the first CQ or AGN?
  /// has finished doesn't send it twice. A DIFFERENT message still queues.
  ///
  /// [repeatingSend] identifies the repeat chain, which keys nothing if it
  /// ended while it rendered: an Escape, a tap or a QSY landing in that gap
  /// would otherwise key the CQ anyway and arm a fresh chain behind it.
  ///
  /// [pressed] is [CatService.keyMark] at the keypress: an operator's
  /// message the other SO2R radio was keyed over since keys nothing
  /// ([CatService.keyedOverSince]).
  Future<void> sendCwMessages(
    List<({int n, String template})> messages, {
    required String radio,
    required int pressed,
    Map<String, dynamic>? qso,
    Map<String, dynamic>? next,
    bool once = false,
    VoidCallback? repeatingSend,
  }) async {
    if (!canFinishCwKeying(radio)) return;
    final services = dockServices;
    final keyer = services.cat.keyer(radio);
    final repeat = repeatingSend != null;
    final ctx = panelRenderContext;
    final draft = qso ?? latestKeyingDraft ?? ctx.qso;
    final session = _keyingSession;
    bool canStillSend() => session == _keyingSession && canFinishCwKeying(radio);
    final parts = <String>[];
    for (final (:n, :template) in messages) {
      String? text;
      String? failure;
      try {
        text = await services.extensions.renderTemplate(
          template,
          operation: ctx.operation == null ? null : operationHookArgs(ctx.operation!),
          qso: draft,
          next: next,
          qsoCount: ctx.qsoCount,
          keyer: {'messages': services.settings.activeCwMessageSet.messages, 'current': n, 'opStyle': ?services.cat.trackedStyleOf(radio)?.value},
        );
      } on TemplateError catch (e) {
        failure = e.message;
      } catch (e, st) {
        // A hook timeout or a dead runtime — reported, and ALSO said here:
        // the operator pressed a key and nothing keyed, which the console
        // alone would leave them to discover on the air.
        // Told only while mounted: nothing awaits between here and the check
        // below that returns before the notice when the view is gone.
        ErrorReportingService.report(e, st, context: 'cw:render-message', told: canStillSend());
        failure = ErrorReportingService.messageOf(e);
      }
      // A view that was left while a template rendered cannot put it on the air.
      if (!mounted || !canStillSend()) {
        if (repeatingSend != null && keyer.keyerRepeatingWith(repeatingSend)) keyer.cancelKeyerRepeat();
        return;
      }
      if (repeatingSend != null && !keyer.keyerRepeatingWith(repeatingSend)) return;
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
      void sendAgain() {
        if (!canStillSend()) {
          keyer.cancelKeyerRepeat();
          return;
        }
        _sendCwMessageNumber(1, radio: radio, repeatingSend: sendAgain);
      }

      keyer.armKeyerRepeat(delay: delay, text: text, send: sendAgain);
    }
    return;
  }

  /// Renders a phone message's template for voiced words (voiced_words.dart):
  /// against the draft, as a CW message is ([sendCwMessages]). Held once so
  /// detaching finds the same function attaching handed over.
  late final VoiceTemplateRender _voiceRender = _renderVoiceTemplate;

  Future<({String text, String operatorCall})> _renderVoiceTemplate(String template, int n) async {
    final session = _keyingSession;
    final services = dockServices;
    final ctx = panelRenderContext;
    String? text;
    try {
      text = await services.extensions.renderTemplate(
        template,
        operation: ctx.operation == null ? null : operationHookArgs(ctx.operation!),
        qso: latestKeyingDraft ?? ctx.qso,
        qsoCount: ctx.qsoCount,
        // The operator's set: the one whose voice keyer plays it.
        keyer: {'messages': services.settings.activeCwMessageSet.messages, 'current': n, 'opStyle': ?services.cat.trackedStyleOf(keyingRadio)?.value},
      );
    } on TemplateError catch (e) {
      throw VoicedMessageRefused(ComputerVoiceProblem.templateFailed, e.message);
    } catch (e, st) {
      // A hook timeout or a dead runtime: carried on the refusal, and
      // reported where it is said — [_voiceRefused], or the message editor.
      throw VoicedMessageRefused(ComputerVoiceProblem.templateFailed, ErrorReportingService.messageOf(e), e, st);
    }
    if (!mounted || !keyingVisible || session != _keyingSession) throw const VoicedMessageRefused(ComputerVoiceProblem.noOperation);
    if (text == null) throw VoicedMessageRefused(ComputerVoiceProblem.templateFailed, t.commands.voiceMessageNotRendered);
    return (text: text, operatorCall: _voiceOperatorCall());
  }

  /// Whose words this operation's messages are said in: its operator, else
  /// its station.
  String _voiceOperatorCall() {
    final operation = panelRenderContext.operation;
    if (operation == null) return '';
    final operator = operatorCallFor(operation);
    return operator.isNotEmpty ? operator : operation.stationCall;
  }

  void _voiceRefused(int n, VoicedMessageRefused refusal) {
    if (!mounted) {
      if (refusal.cause != null) ErrorReportingService.report(refusal.cause!, refusal.causeStack, context: 'voice:render-message');
      return;
    }
    final key = 'voice-message-$n', icon = 'alert-circle-outline';
    final text = context.t.commands.voiceMessageError(
      n: n,
      error: computerVoiceProblemText(context, refusal.problem, detail: refusal.detail),
    );
    if (refusal.cause != null) {
      // The notice IS the report's: said once, in these words.
      ErrorReportingService.report(
        refusal.cause!,
        refusal.causeStack,
        context: 'voice:render-message',
        notice: ErrorNotice(dockServices.statusBar, key: key, text: text, icon: icon, persist: false),
      );
    } else {
      dockServices.statusBar.showNotice(key: key, icon: icon, text: text, persist: false);
    }
  }
}
