// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

part of '../operation_view.dart';

mixin _OperationKeying on State<OperationView>, LoggingViewKeying<OperationView> {
  bool get _phoneKeyingPossible {
    final services = widget.services;
    return voiceKeyingPossible || (services.settings.pttKey && services.cat.canPtt);
  }

  /// Each radio's last Enter Sends Messages CW send — see [_sendEsmMessages].
  /// One per radio: a step on one radio never waits on the other's.
  final _esmSending = <String, Future<void>>{};

  /// Which radio the PTT key keys from this view (cat_ptt.dart): the
  /// operator's — radio1, or under SO2R the radio of the set they are in —
  /// while this view is in front and the draft is in a Phone mode.
  String? _pttTarget() {
    final services = widget.services;
    if (!mounted || testerOverlayCovering.value || !(ModalRoute.of(context)?.isCurrent ?? false)) return null;
    if (!services.settings.pttKey) return null;
    if (!keyingPhone) return null;
    final cat = services.cat;
    if (!keyerOrSay(context, services, cat.operatorKeyer, () => cat.operatorKeyer.canPtt)) return null;
    return cat.operatorRadio == 'B' ? cat.radio2 : cat.localRadio1;
  }

  @override
  bool handleOperatingKey(KeyEvent event) {
    final services = widget.services;
    if (keyBindings.value.claim(so2rStereoCommandId, event) != null && services.cat.toggleSo2rStereo()) return true;
    if (keyBindings.value.claim(styleToggleCommandId, event) == null) return false;
    _toggleStyle();
    return true;
  }

  /// Run ↔ S&P for the set the operator is in. Silent: a key pressed
  /// mid-pileup puts nothing on the status bar — unless the styles are never
  /// tracked, where a change nothing shows or records would leave the key
  /// looking dead.
  void _toggleStyle() {
    final services = widget.services;
    if (!services.cat.toggleStyle(services.cat.operatorRadio)) {
      services.statusBar.showNotice(key: 'opStyle', icon: 'run', text: t.commands.opStyleTrackingOff, persist: false);
    }
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
    // through the hardware handler — an on-screen keyboard's: nothing, unless
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
    if (!cwKeyerOrSay(context, services, keyer)) return;
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
          return await sendCwMessages(templates, radio: radio, qso: qso, once: true, pressed: pressed);
        }
        // Not [once]: every thanks is the same `TU`, and the one still
        // waiting behind the last exchange belongs to the last contact.
        final after = await logged;
        if (after != null && mounted) await sendCwMessages(templates, radio: radio, qso: after.qso, next: after.next, pressed: pressed);
      } catch (e, st) {
        // Reported rather than left on the chain, where it would stop every
        // later step from keying at all.
        ErrorReportingService.report(e, st, context: 'cw:esm-send');
      }
    });
  }
}
