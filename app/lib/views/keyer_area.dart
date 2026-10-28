// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The keyer's two surfaces (docs/design/cat.md § CW keying).
//
// The keyer line (KeyerArea), at the bottom of a set's info area under the
// stats or the call info: while that set's radio keys for the app, the
// keyer's icon, the message going out with the characters already sent set
// apart and a bar under it pacing through the message's estimated duration,
// then whatever waits behind it. Estimated — the radio reports nothing about
// its progress — so this shows the same arithmetic the send queue paces by,
// and is right to the extent that is. In a Phone mode — the draft contact's
// — it is the memory playing (or recording) in the message's place
// (docs/design/cat.md § Voice keying). The line slides down while anything
// goes out — a message, a memory, a repeat's wait, what waits for the other
// SO2R radio, keyboard mode — and away a second after nothing does; a stop
// takes it away at once.
//
// The keyer control (keyerHostControl, KeyerControls), one of the logging
// panel's secondary controls: its chip reads the speed or "Voice", and its
// panel holds what starts a message — ESM, a button per message, keyboard
// mode's field in their place while it is on, the repeat and the messages'
// settings.
//
// Driven by AnimationControllers rather than a clock: the bar advances per
// frame for a few seconds and stops with the message, which is neither a
// per-second UI (WallClock's job) nor anything time travel should move.

import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'package:halo_i18n/halo_i18n.dart';
import '../services/halo_services.dart';
import 'cw_messages_dialog.dart';
import 'cw_typing_field.dart';
import 'voice_messages_dialog.dart';
import '../services/cat/cat_service.dart';
import '../services/cat/cw_live_typing.dart';
import '../services/cat/driver.dart' show VoiceActivity;
import '../services/error_reporting_service.dart';
import '../services/cat/drivers/cw_send_queue.dart';
import '../services/settings_service.dart';
import 'operation/extension_panel.dart' show PanelRenderContext, operationHookArgs;

/// The room under a line of text for its bar ([Space.xxs] tall): the bar
/// and a pixel between it and the text.
const _barBelowText = Space.xxs + 1;

/// The slide in and out.
const _revealDuration = Duration(milliseconds: 250);

class KeyerArea extends StatefulWidget {
  final CatService cat;

  /// For the voice memories' labels and the repeat's message.
  final HaLoServices services;

  /// The SO2R radio whose info area this is: the line shows that radio's
  /// keyer ([CatService.keyer]) — `A` alone outside SO2R.
  final String radio;

  /// Whether the line is the voice keyer's: the draft contact's mode is
  /// Phone. Decided by the operation view, which routes F1-F8 by the same
  /// answer — decided ONCE, so the keys and the line never disagree about
  /// which keyer this is. The draft's mode, not the radio's: the messages
  /// are for the contact being logged, and a rig sitting in USB while the
  /// operator logs CW keys CW.
  final bool phone;

  /// True while the logging panel is editing a logged QSO: the area slides
  /// out and stays out until editing ends, then comes back if something is
  /// still keying. Messages are for the contact in progress, not for one
  /// being corrected.
  final bool suppressed;

  const KeyerArea({super.key, required this.cat, required this.services, this.radio = 'A', this.phone = false, this.suppressed = false});

  @override
  State<KeyerArea> createState() => _KeyerAreaState();
}

class _KeyerAreaState extends State<KeyerArea> with TickerProviderStateMixin {
  // Created in initState, never lazily: a `late` controller first touched
  // by dispose() would look TickerMode up on a context that is already gone.
  late final AnimationController _reveal;

  /// Whether the line is (or is sliding) in — from something going out until
  /// it has lingered and slid away.
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _reveal = AnimationController(vsync: this, duration: _revealDuration);
    _listen(widget.cat, widget.radio);
    _onProgress();
  }

  /// This line's radio's keyer.
  RadioKeyer get _k => widget.cat.keyer(widget.radio);

  void _listen(CatService cat, String radio) {
    final k = cat.keyer(radio);
    for (final listenable in [k.cwProgress, k.voiceActivity, k.keyerRepeatActive, k.waiting, k.cwTyping]) {
      listenable.addListener(_onProgress);
    }
    k.cwStops.addListener(_onStopped);
    cat.addListener(_onCatChanged);
  }

  void _unlisten(CatService cat, String radio) {
    final k = cat.keyer(radio);
    for (final listenable in [k.cwProgress, k.voiceActivity, k.keyerRepeatActive, k.waiting, k.cwTyping]) {
      listenable.removeListener(_onProgress);
    }
    k.cwStops.removeListener(_onStopped);
    cat.removeListener(_onCatChanged);
  }

  void _show() {
    if (widget.suppressed) return;
    if (!_visible) setState(() => _visible = true);
    _reveal.forward();
  }

  @override
  void didUpdateWidget(KeyerArea old) {
    super.didUpdateWidget(old);
    if (old.cat != widget.cat || old.radio != widget.radio) {
      _unlisten(old.cat, old.radio);
      _listen(widget.cat, widget.radio);
    }
    // Keyboard mode is the CW keyer's; the draft going to Phone ends it the
    // way Enter would.
    if (widget.phone && !old.phone) _k.cwTyping.value?.finish();
    _onProgress();
  }

  @override
  void dispose() {
    _unlisten(widget.cat, widget.radio);
    // What was typed still goes out — the line going away is not an Escape.
    _k.cwTyping.value?.finish();
    _linger.dispose();
    _reveal.dispose();
    super.dispose();
  }

  /// The key going away ends keyboard mode: `sendCw` is a no-op without
  /// one, and the field would go on bolding words as sent that went nowhere.
  void _onCatChanged() {
    if (!_k.canKeyCw) _k.cwTyping.value?.cancel();
  }

  /// How long the line stays once nothing is going out: a radio reports a
  /// memory ended a little before its audio does, and a line gone before the
  /// last word reads as the message cut short.
  static const _lingerFor = Duration(seconds: 1);

  /// Runs while the line lingers, and slides it away when it runs out. An
  /// animation rather than a timer, like the slide: it keeps to the frames
  /// the line is drawn by, and says it ran out in the frame it does.
  late final AnimationController _linger = AnimationController(vsync: this, duration: _lingerFor)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) _close();
    });

  void _stopLinger() => _linger.stop();

  /// What the line last showed, for it to go on showing while it lingers.
  CwSendProgress? _heldProgress;
  VoiceActivity? _heldVoice;

  /// Shows the line while something is going out — a message, a voice
  /// memory, the wait in a repeat or for the other SO2R radio, or keyboard
  /// mode — and slides it away
  /// [_lingerFor] after nothing is. The controls that start one are the
  /// keyer control's, in the strip of secondary controls ([KeyerControls]).
  void _onProgress() {
    if (!mounted) return;
    final k = _k;
    if (widget.suppressed) {
      _stopLinger();
      _close();
      return;
    }
    final active =
        k.cwProgress.value != null || k.voiceActivity.value != null || k.keyerRepeatActive.value || k.waiting.value.isNotEmpty || k.cwTyping.value != null;
    if (active) {
      _stopLinger();
      // Something new going out is no longer what was stopped.
      final progress = k.cwProgress.value;
      if (_stopped && (k.voiceActivity.value != null || (progress != null && progress.id != _stoppedId))) _stopped = false;
      if (!_stopped) _heldProgress = progress;
      _heldVoice = k.voiceActivity.value;
      _show();
    } else if (_stopped) {
      _stopped = false;
      _stopLinger();
      _close();
    } else if (_visible && !_linger.isAnimating) {
      _linger.forward(from: 0);
    }
  }

  /// A stop is not a message finishing: what was cut short is not shown
  /// going on as if it had gone out, so the line drops it and leaves at once
  /// once nothing else is going out. Counted before the message clears, so
  /// it is remembered for the moment it does.
  bool _stopped = false;
  int? _stoppedId;

  void _onStopped() {
    _heldProgress = null;
    _stopped = true;
    _stoppedId = _k.cwProgress.value?.id;
    _onProgress();
  }

  /// Slides the line away. A message still keying keeps going; its next
  /// report brings the line back.
  void _close() {
    if (!mounted || !_visible) return;
    // What was typed still goes out.
    _k.cwTyping.value?.finish();
    _reveal.reverse().whenComplete(() {
      if (mounted && _reveal.isDismissed) {
        setState(() {
          _visible = false;
          _heldProgress = null;
          _heldVoice = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    // Grows from the top edge down, and the content rides in with it — so
    // the line reads as sliding down out of the content above it, and back
    // up into it, rather than fading in place.
    return SizeTransition(
      sizeFactor: _reveal,
      // The start edge on both axes — what axisAlignment -1 meant before
      // SizeTransition took a full alignment.
      alignment: AlignmentDirectional.topStart,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(_reveal),
        child: Padding(
          // Inside the slide, so a hidden line costs nothing.
          padding: const EdgeInsets.only(top: Space.xxs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // The keyer's icon, where the info area's other lines carry
              // theirs (infoIconRows): the key for CW, the microphone for
              // voice.
              Icon(widget.phone ? MdiIcons.microphone : MdiIcons.key, size: 16, color: Theme.of(context).colorScheme.tertiary),
              const SizedBox(width: Space.sm),
              Flexible(
                // Keyboard mode puts its field BESIDE the message rather than
                // in its place: the operator typing ahead of the keyer needs
                // to see where it has got to. The message stays the first
                // child in both modes, so the mode coming or going leaves its
                // progress view where it is — a view that moved would be a
                // new one, whose bar starts over and reads as the message
                // going out again.
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: ListenableBuilder(
                        listenable: Listenable.merge([_k.cwProgress, _k.voiceActivity, _k.keyerRepeat, _k.keyerRepeatActive, _k.waiting]),
                        builder: (context, _) {
                          // While lingering, what was last going out.
                          final progress = _k.cwProgress.value ?? (_linger.isAnimating ? _heldProgress : null);
                          final voice = _k.voiceActivity.value ?? (_linger.isAnimating ? _heldVoice : null);
                          // What waits for the other SO2R radio to fall quiet.
                          final held = _k.waiting.value;
                          return Stack(
                            alignment: AlignmentDirectional.centerStart,
                            children: [
                              // Keyed on the message's id, so a new one restarts the
                              // animation from its own beginning — while a re-report of
                              // the SAME message (the queue behind it changed) keeps the
                              // animation where it is.
                              if (progress != null) _CwProgressView(key: ValueKey(progress.id), progress: progress, keyer: _k),
                              if (voice != null && progress == null) _VoiceActivityView(activity: voice, keyer: _k, services: widget.services),
                              // A send waiting its turn: this radio's own wait is
                              // over, and the other radio is still on the air.
                              if (progress == null && voice == null && held.isNotEmpty) _WaitingView(send: held.first, keyer: _k),
                              // The wait between a repeat and the next send. Only
                              // while nothing is keying: the moment the message
                              // goes again its own bar takes the slot back.
                              if (progress == null && voice == null && held.isEmpty)
                                ValueListenableBuilder<KeyerRepeatWait?>(
                                  valueListenable: _k.keyerRepeat,
                                  builder: (context, wait, _) => wait == null
                                      ? const SizedBox.shrink()
                                      : _CwRepeatView(key: ValueKey(wait), wait: wait, keyer: _k, services: widget.services),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The keyer as one of the logging panel's secondary controls: its chip
/// says which keyer by its icon and how fast ("25 WPM", "Voice"); its panel
/// holds what starts a message — ESM, a button per message (keyboard mode's
/// field in their place while it is on), keyboard mode, the repeat and the
/// messages' settings. One strip for both SO2R radios, so it is the keyer of
/// the set the operator is in ([CatService.operatorKeyer]). What is going
/// out shows in each radio's [KeyerArea], in its info area.
HostControl keyerHostControl({
  required HaLoServices services,
  required bool phone,
  void Function(int n, String radio)? onSendMessage,
  PanelRenderContext? templateContext,
  bool enterSends = false,
  Map<String, ValueListenable<EsmFacts?>>? esmFacts,
}) {
  final cat = services.cat;
  String summary() {
    final k = t.settings.radio.keyerControl;
    if (phone) return k.voice;
    final speed = cat.operatorKeyer.keyerSpeed;
    return speed == null ? k.cw : k.cwSpeed(wpm: speed);
  }

  return HostControl(
    key: keyerControlKey,
    icon: MdiIcons.key,
    label: t.settings.radio.keyerControl.label,
    // KEYER, or keyboard mode starting on either radio: its field is here.
    openRequests: Listenable.merge([
      cat.keyerOpenRequests,
      for (final radio in ['A', 'B']) cat.keyer(radio).keyboardModeRequests,
    ]),
    spec: () => SecondaryControlSpec(
      key: keyerControlKey,
      icon: phone ? MdiIcons.microphone : MdiIcons.key,
      summary: summary(),
      liveSummary: summary,
      expandedBuilder: (context) => KeyerControls(
        services: services,
        phone: phone,
        onSendMessage: onSendMessage,
        templateContext: templateContext,
        enterSends: enterSends,
        esmFacts: esmFacts,
      ),
    ),
  );
}

const keyerControlKey = 'keyer';

/// The keyer control's panel — see [keyerHostControl]. On the strip's
/// accent ground, so the buttons outlined in the accent take its contrast
/// colour instead.
class KeyerControls extends StatelessWidget {
  final HaLoServices services;
  final bool phone;
  final void Function(int n, String radio)? onSendMessage;
  final PanelRenderContext? templateContext;
  final bool enterSends;
  final Map<String, ValueListenable<EsmFacts?>>? esmFacts;

  const KeyerControls({
    super.key,
    required this.services,
    required this.phone,
    this.onSendMessage,
    this.templateContext,
    this.enterSends = false,
    this.esmFacts,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cat = services.cat;
    // Rebuilt as the operator moves between SO2R sets: the panel is that
    // set's radio's.
    return ListenableBuilder(
      listenable: cat,
      builder: (context, _) {
        final keyer = cat.operatorKeyer;
        final radio = keyer.radio;
        final facts = enterSends ? (esmFacts?[radio]) : null;
        final send = onSendMessage;
        return Theme(
          data: theme.copyWith(
            colorScheme: scheme.copyWith(tertiary: scheme.onTertiary, onSurface: scheme.onTertiary),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (enterSends) ...[_EnterSendsPill(cat: cat, radio: radio), const SizedBox(width: Space.md)],
              Flexible(
                child: phone
                    ? _VoiceButtons(services: services, keyer: keyer, esmFacts: facts)
                    // Keyboard mode's field over the buttons, at their width,
                    // so the buttons after them stay where they are.
                    : ValueListenableBuilder<CwLiveTyping?>(
                        valueListenable: keyer.cwTyping,
                        builder: (context, typing, buttons) => typing == null
                            ? buttons!
                            : Stack(
                                children: [
                                  Visibility(visible: false, maintainSize: true, maintainAnimation: true, maintainState: true, child: buttons!),
                                  // Short of the last button's gap to what follows.
                                  Positioned.fill(
                                    right: Space.sm,
                                    child: Theme(
                                      data: theme,
                                      child: CwTypingField(key: ObjectKey(typing), typing: typing),
                                    ),
                                  ),
                                ],
                              ),
                        child: _MessageButtons(
                          services: services,
                          keyer: keyer,
                          onSendMessage: send == null ? null : (n) => send(n, radio),
                          templateContext: templateContext,
                          esmFacts: facts,
                        ),
                      ),
              ),
              // Outside the scrolling row, so they stay in reach however many
              // messages there are.
              if (!phone)
                ValueListenableBuilder<CwLiveTyping?>(
                  valueListenable: keyer.cwTyping,
                  builder: (context, current, _) {
                    final typing = current != null;
                    return IconButton(
                      icon: Icon(
                        typing ? MdiIcons.keyboard : MdiIcons.keyboardOutline,
                        size: 18,
                        color: scheme.onTertiary,
                        semanticLabel: context.t.settings.radio.cwMessages.keyboard,
                      ),
                      isSelected: typing,
                      visualDensity: VisualDensity.compact,
                      onPressed: !keyer.canKeyCw && !typing
                          ? null
                          : () {
                              if (typing || keyerOrSay(context, services, keyer, () => keyer.canKeyCw)) keyer.toggleKeyboardMode();
                            },
                    );
                  },
                ),
              _RepeatButton(services: services, phone: phone),
              IconButton(
                icon: Icon(
                  MdiIcons.tune,
                  size: 18,
                  color: scheme.onTertiary,
                  semanticLabel: phone ? context.t.settings.radio.voiceMessages.title : context.t.settings.radio.cwMessages.title,
                ),
                visualDensity: VisualDensity.compact,
                onPressed: () => phone ? showVoiceMessagesDialog(context, services, radio: radio) : showCwMessagesDialog(context, services, radio: radio),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// How long after the last draft change a templated label is re-rendered.
/// On top of the draft's own debounce upstream, so a keystroke burst costs
/// the bridge one render per label, not one per letter.
const cwLabelRenderDelay = Duration(milliseconds: 300);

/// The messages the next Enter keys, by number — none while ESM is off or
/// that Enter keys nothing (docs/design/logging-fields.md § Enter Sends
/// Messages) — and [logs], the last of them when that Enter also logs the
/// contact. [phone] leaves out their call, which no memory holds.
({Set<int> keys, int? logs}) _esmNext(CatService cat, String radio, EsmFacts? facts, {bool phone = false}) {
  final esm = (on: cat.enterSends.value.on, running: cat.isRunning(radio));
  final step = facts == null || !esm.on ? null : esmStepFor(facts, running: esm.running);
  if (step == null) return (keys: const {}, logs: null);
  final keys = [
    for (final message in step.send)
      if (!phone || message != EsmMessage.hisCall) CwMessageSet.esmKeys[message]!,
  ];
  return (keys: keys.toSet(), logs: step.then == EsmThen.log ? keys.lastOrNull : null);
}

/// While nothing is keying: one outlined button per message that has text,
/// its key's number and its label (the key itself when there is none) —
/// the function keys for a mouse or a finger. A label written as a template
/// renders like the message would, against the draft contact, so
/// `{{ qso.call }} 5NN` reads as the call in the field.
class _MessageButtons extends StatefulWidget {
  final HaLoServices services;
  final RadioKeyer keyer;
  final void Function(int n)? onSendMessage;
  final PanelRenderContext? templateContext;
  final ValueListenable<EsmFacts?>? esmFacts;

  const _MessageButtons({required this.services, required this.keyer, required this.onSendMessage, required this.templateContext, required this.esmFacts});

  @override
  State<_MessageButtons> createState() => _MessageButtonsState();
}

class _MessageButtonsState extends State<_MessageButtons> {
  /// Rendered label text by message, with the template it was rendered from
  /// ([_labelKey]), and the draft it was rendered against. Shared by every
  /// mount of the buttons: the keyer control's panel mounts them each time it
  /// opens, and a render per open would cross the bridge again for a draft
  /// that has not moved.
  static final _rendered = <int, ({String key, String text})>{};
  static PanelRenderContext? _renderedFor;
  Timer? _debounce;
  int _renderGeneration = 0;

  /// Only a label with an expression in it is rendered; any other reads as
  /// written.
  static bool _isTemplate(String label) => label.contains('{{');

  /// The operator's own label for message [n], as written — empty for none.
  static String _labelTemplate(SettingsService settings, int n) => settings.cwMessageLabel(n).trim();

  /// What a rendered label is cached against: its template, and for one that
  /// names `keyer` the messages too. The template stays the same when a
  /// message it includes is edited, and the key would go on reading the old
  /// one.
  static String _labelKey(SettingsService settings, int n) {
    final label = _labelTemplate(settings, n);
    return label.contains('keyer.') ? [label, ...settings.activeCwMessageSet.messages].join('\u0000') : label;
  }

  /// The 16 message/label values as last rendered against — settings notify
  /// for a theme change too, and that is no reason to cross the bridge.
  String _fingerprint = '';

  String _currentFingerprint() {
    final settings = widget.services.settings;
    return [
      for (var n = 1; n <= SettingsService.cwMessageCount; n++) ...[settings.cwMessage(n), settings.cwMessageLabel(n)],
    ].join('\u0000');
  }

  void _onSettings() {
    final now = _currentFingerprint();
    if (now == _fingerprint) return;
    _fingerprint = now;
    _scheduleRender();
  }

  @override
  void initState() {
    super.initState();
    _fingerprint = _currentFingerprint();
    widget.services.settings.addListener(_onSettings);
    // At once rather than after the debounce: the buttons wait for it.
    if (!_rendersCurrent || !_sameContext(_renderedFor, widget.templateContext)) unawaited(_render());
  }

  /// Whether every templated label has a render of its current template —
  /// for some draft, if not this one: until then the buttons stay hidden,
  /// rather than showing a template and then what it says.
  bool get _rendersCurrent {
    final settings = widget.services.settings;
    for (var n = 1; n <= SettingsService.cwMessageCount; n++) {
      if (!_isTemplate(_labelTemplate(settings, n))) continue;
      if (_rendered[n]?.key != _labelKey(settings, n)) return false;
    }
    return true;
  }

  @override
  void didUpdateWidget(_MessageButtons old) {
    super.didUpdateWidget(old);
    if (!_sameContext(old.templateContext, widget.templateContext)) _scheduleRender();
  }

  /// PanelRenderContext is rebuilt on every view build and has no equality
  /// of its own, so this looks at what a label could actually read: the
  /// draft (one object per debounced draft change) and the operation.
  static bool _sameContext(PanelRenderContext? a, PanelRenderContext? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    return identical(a.qso, b.qso) && identical(a.operation, b.operation) && a.qsoCount == b.qsoCount;
  }

  @override
  void dispose() {
    widget.services.settings.removeListener(_onSettings);
    _debounce?.cancel();
    super.dispose();
  }

  void _scheduleRender() {
    _debounce?.cancel();
    _debounce = Timer(cwLabelRenderDelay, _render);
  }

  Future<void> _render() async {
    final ctx = widget.templateContext;
    if (ctx == null) return;
    final settings = widget.services.settings;
    final generation = ++_renderGeneration;
    // Every templated label in ONE crossing of the bridge, not one each.
    final numbers = <int>[];
    final labels = <String>[];
    final keys = <String>[];
    for (var n = 1; n <= SettingsService.cwMessageCount; n++) {
      final label = _labelTemplate(settings, n);
      if (!_isTemplate(label)) continue;
      numbers.add(n);
      labels.add(label);
      keys.add(_labelKey(settings, n));
    }
    if (labels.isEmpty) return;
    List<({String? text, String? error})>? rendered;
    try {
      rendered = await widget.services.extensions.renderTemplates(
        labels,
        operation: ctx.operation == null ? null : operationHookArgs(ctx.operation!),
        qso: ctx.qso,
        qsoCount: ctx.qsoCount,
        keyer: {'messages': settings.activeCwMessageSet.messages},
      );
    } catch (e, st) {
      // A hook timeout or a dead runtime: the labels show as written until
      // the next draft pause tries again.
      ErrorReportingService.report(e, st, context: 'cw:render-labels');
    }
    // A newer render was scheduled while this one was on the bridge; its
    // answers are for a draft that has moved on.
    if (!mounted || generation != _renderGeneration) return;
    final results = <int, ({String key, String text})>{};
    for (var i = 0; i < numbers.length; i++) {
      // A label that does not parse (`error`) shows as written — the
      // operator's own typo, visible where they will fix it.
      final text = rendered != null && i < rendered.length ? rendered[i].text : null;
      results[numbers[i]] = (key: keys[i], text: (text ?? labels[i]).trim());
    }
    setState(() {
      _rendered
        ..clear()
        ..addAll(results);
      _renderedFor = ctx;
    });
  }

  /// The operator's label as it reads — rendered, for a template — and
  /// empty for none, or one that renders to nothing.
  String _shownLabel(int n) {
    final settings = widget.services.settings;
    final label = _labelTemplate(settings, n);
    if (!_isTemplate(label)) return label;
    final rendered = _rendered[n];
    return rendered != null && rendered.key == _labelKey(settings, n) ? rendered.text : '';
  }

  /// [_shownLabel]; [key] for a message with none; nothing for no message
  /// and no label.
  String _labelFor(int n, String key) {
    final label = _shownLabel(n);
    if (label.isNotEmpty) return label;
    return widget.services.settings.cwMessage(n).trim().isEmpty ? '' : key;
  }

  @override
  Widget build(BuildContext context) {
    final services = widget.services;
    final settings = services.settings;
    final m = context.t.settings.radio.cwMessages;
    return ListenableBuilder(
      listenable: Listenable.merge([settings, services.cat, services.cat.enterSends, services.cat.runningB, ?widget.esmFacts]),
      builder: (context, _) {
        // Nothing to key CW with at all, connected or not — say so where the
        // buttons would be, rather than drawing buttons that can never work.
        if (!widget.keyer.designatedKeyIsKeyer) return _NotSupported(text: context.t.settings.station.keyerNotSupported);
        final enabled = widget.keyer.canKeyCw && widget.onSendMessage != null;
        final next = enabled ? _esmNext(services.cat, widget.keyer.radio, widget.esmFacts?.value) : (keys: const <int>{}, logs: null);
        // Hidden, at its size, until the templated labels are rendered: which
        // buttons show, and what they say, waits on what the labels read.
        return Visibility(
          visible: widget.templateContext == null || _rendersCurrent,
          maintainSize: true,
          maintainAnimation: true,
          maintainState: true,
          child: _ButtonScroll(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Up to the last message with anything in it, one with nothing
                // to send disabled: a gap that closed up would move every
                // button after it as it was written.
                for (
                  var n = 1;
                  n <= _lastDefined(SettingsService.cwMessageCount, (n) => settings.cwMessage(n).trim().isNotEmpty || _shownLabel(n).isNotEmpty);
                  n++
                )
                  _MessageButton(
                    n: n,
                    label: _labelFor(n, m.key(n: n)),
                    enabled: enabled && settings.cwMessage(n).trim().isNotEmpty,
                    next: next,
                    repeats: n == 1 && settings.cwRepeatDelay > Duration.zero,
                    onTap: () => widget.onSendMessage!(n),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// One message's button: its number, the repeat mark on message 1, its
/// label, and the submit icon when the next Enter logs after it. Outlined
/// in the chips' accent rather than filled — these ACT, the pill only shows
/// — with the label in the text colour other buttons use. What the next
/// Enter keys gets a faint wash of the accent and a heavier outline.
class _MessageButton extends StatelessWidget {
  final int n;
  final String label;
  final bool enabled;
  final ({Set<int> keys, int? logs}) next;
  final bool repeats;
  final VoidCallback onTap;

  const _MessageButton({required this.n, required this.label, required this.enabled, required this.next, required this.repeats, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    var color = theme.colorScheme.tertiary;
    var textColor = theme.colorScheme.onSurface;
    if (!enabled) {
      color = color.withValues(alpha: 0.5);
      textColor = textColor.withValues(alpha: 0.5);
    }
    final borderRadius = BorderRadius.circular(8);
    final esm = enabled && next.keys.contains(n);
    return Padding(
      padding: const EdgeInsets.only(right: Space.sm),
      child: Material(
        color: esm ? theme.colorScheme.tertiary.withValues(alpha: 0.18) : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius,
          side: BorderSide(color: color, width: esm ? 2 : 1),
        ),
        child: InkWell(
          borderRadius: borderRadius,
          onTap: enabled ? onTap : null,
          mouseCursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(cwMessageNumberIcons[n - 1], size: 14, color: textColor),
                // Only on 1, because only 1 repeats — the icon beside its
                // number is where an operator sees that a CQ they press will
                // keep going.
                if (repeats) ...[const SizedBox(width: Space.xxs), Icon(MdiIcons.repeat, size: 14, color: textColor)],
                if (label.isNotEmpty) ...[
                  const SizedBox(width: Space.xs),
                  Text(
                    label,
                    style: TextStyle(fontFamily: 'RobotoCondensed', fontSize: 12, fontWeight: FontWeight.w500, color: textColor),
                  ),
                ],
                // The submit button's icon: this Enter logs too.
                if (enabled && next.logs == n) ...[const SizedBox(width: Space.xs), Icon(MdiIcons.upload, size: 14, color: textColor)],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A row of message buttons, scrolled sideways by dragging it with a mouse
/// as well as a finger or trackpad: the strip's chips scroll the same way,
/// and a desk without a horizontal wheel has no other way along the row.
class _ButtonScroll extends StatelessWidget {
  final Widget child;

  const _ButtonScroll({required this.child});

  @override
  Widget build(BuildContext context) => ScrollConfiguration(
    behavior: ScrollConfiguration.of(context).copyWith(dragDevices: PointerDeviceKind.values.toSet(), scrollbars: false),
    child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: child),
  );
}

/// The highest of 1..[count] that [defined], 0 for none.
int _lastDefined(int count, bool Function(int n) defined) {
  for (var n = count; n >= 1; n--) {
    if (defined(n)) return n;
  }
  return 0;
}

/// Message 1's repeat, on or off — the keyer's own, CW's or Phone's. Lit
/// while on; the cooldown is set in the messages dialog.
class _RepeatButton extends StatelessWidget {
  final HaLoServices services;
  final bool phone;

  const _RepeatButton({required this.services, required this.phone});

  @override
  Widget build(BuildContext context) {
    final settings = services.settings;
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final on = phone ? settings.voiceRepeat : settings.cwRepeat;
        return IconButton(
          icon: Icon(
            on ? MdiIcons.repeat : MdiIcons.repeatOff,
            size: 18,
            color: theme.colorScheme.onSurface,
            semanticLabel: context.t.settings.radio.cwMessages.repeat,
          ),
          isSelected: on,
          visualDensity: VisualDensity.compact,
          onPressed: () {
            // Off ends a chain already counting down.
            if (on) {
              for (final radio in ['A', 'B']) {
                services.cat.keyer(radio).cancelKeyerRepeat();
              }
            }
            unawaited(phone ? settings.setVoiceRepeat(!on) : settings.setCwRepeat(!on));
          },
        );
      },
    );
  }
}

/// Whether memory [n] holds audio, as far as the app can tell: a recording
/// on this computer, or a memory the radio lists, has a length; a radio that
/// says nothing about its memories may hold any of them.
bool _voiceRecorded(RadioKeyer keyer, int n) => !(keyer.voiceMessagesFromComputer || keyer.voiceMessagesNamedOnRadio) || keyer.voiceMessageDuration(n) > 0;

/// Memory [n]'s label; [key] for one recorded with none; nothing for neither.
String _voiceLabel(RadioKeyer keyer, int n, String key) {
  final label = keyer.voiceMessageLabel(n).trim();
  if (label.isNotEmpty) return label;
  return _voiceRecorded(keyer, n) ? key : '';
}

/// Where the message buttons would be, when the radio in use cannot send
/// them: in the buttons' own dimmed accent, so it reads as their absence.
class _NotSupported extends StatelessWidget {
  final String text;

  const _NotSupported({required this.text});

  @override
  Widget build(BuildContext context) => Text(
    text,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(fontFamily: 'RobotoCondensed', fontSize: 12, color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.5)),
  );
}

/// While nothing is playing, in a Phone mode: one outlined button per voice
/// memory of the radio — the function keys for a mouse or a finger — with
/// its label, or its key when it has none. Without a radio that can play,
/// the memories that have a label, disabled: the names the operator set are
/// worth seeing before the rig is on.
class _VoiceButtons extends StatelessWidget {
  final HaLoServices services;
  final RadioKeyer keyer;
  final ValueListenable<EsmFacts?>? esmFacts;

  const _VoiceButtons({required this.services, required this.keyer, required this.esmFacts});

  @override
  Widget build(BuildContext context) {
    final settings = services.settings;
    final cat = services.cat;
    final m = context.t.settings.radio.voiceMessages;
    return ListenableBuilder(
      listenable: Listenable.merge([settings, cat, cat.enterSends, cat.runningB, ?esmFacts]),
      builder: (context, _) {
        // A radio with no voice memories to play — see the CW buttons.
        if (!keyer.radio1HasVoiceMemories) {
          return _NotSupported(text: keyer.phoneKeyingOff ? context.t.settings.station.phoneKeyingOff : context.t.settings.station.keyerNotSupported);
        }
        final enabled = keyer.canPlayVoice;
        final next = enabled ? _esmNext(cat, keyer.radio, esmFacts?.value, phone: true) : (keys: const <int>{}, logs: null);
        final count = enabled ? keyer.voiceMemoryCount : SettingsService.voiceMessageCount;
        return _ButtonScroll(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Up to the last memory recorded or named, one with nothing
              // recorded disabled — see the CW buttons.
              for (var n = 1; n <= _lastDefined(count, (n) => _voiceRecorded(keyer, n) || keyer.voiceMessageLabel(n).trim().isNotEmpty); n++)
                _MessageButton(
                  n: n,
                  label: _voiceLabel(keyer, n, m.key(n: n)),
                  enabled: enabled && _voiceRecorded(keyer, n),
                  next: next,
                  repeats: n == 1 && settings.voiceRepeatDelay > Duration.zero,
                  onTap: () {
                    if (keyerOrSay(context, services, keyer, () => keyer.canPlayVoice)) keyer.playVoiceMemory(n);
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The memory playing or recording, in the message's place: tapping it
/// stops it (Esc's other form). No bar — no radio here reports how far
/// along a memory is, and a bar pacing nothing would be a guess dressed as
/// a measurement.
/// The memory going out, under a bar. A MEASURED memory paces its own bar
/// (CatService times every play — settings_service.dart's
/// `voiceMessageDuration`); an unmeasured one shows an indeterminate bar
/// instead, which says "still going" without claiming to know how far
/// along. A memory measures itself the first time it is played, so the
/// second play is the one that gets the real bar.
class _VoiceActivityView extends StatefulWidget {
  final VoiceActivity activity;
  final RadioKeyer keyer;
  final HaLoServices services;

  const _VoiceActivityView({required this.activity, required this.keyer, required this.services});

  @override
  State<_VoiceActivityView> createState() => _VoiceActivityViewState();
}

/// [TickerProviderStateMixin], not the Single one: one activity replaces
/// another in the same State — a second memory played while the line is up —
/// and each length gets a controller of its own.
class _VoiceActivityViewState extends State<_VoiceActivityView> with TickerProviderStateMixin {
  /// Null while the memory's length is unknown, which is what draws the
  /// indeterminate bar.
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    _pace();
  }

  @override
  void didUpdateWidget(_VoiceActivityView old) {
    super.didUpdateWidget(old);
    // A re-report of the SAME memory keeps the bar where it is; another
    // memory, or a play becoming a recording, starts one afresh.
    if (old.activity.memory != widget.activity.memory || old.activity.recording != widget.activity.recording) {
      _pace();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /// Built HERE rather than in build: a controller is a side effect with a
  /// ticker attached, and building one per rebuild is what exhausts a
  /// ticker provider.
  void _pace() {
    _controller?.dispose();
    _controller = null;
    // A recording has no length to pace: it lasts as long as the operator
    // holds it, which is what the indeterminate bar says.
    if (widget.activity.recording) return;
    final millis = widget.keyer.voiceMessageDuration(widget.activity.memory);
    if (millis <= 0) return;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: millis),
    )..forward();
  }

  @override
  Widget build(BuildContext context) {
    final activity = widget.activity;
    final keyer = widget.keyer;
    final m = context.t.settings.radio.voiceMessages;
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium ?? const TextStyle();
    final label = voiceMessageLabelFor(keyer, activity.memory, m.key(n: activity.memory));
    // Doubt is not shown here. It is a real state — the radio answered
    // "idle" before ever answering "going" — but a question mark on the
    // strip asks the operator something they cannot answer while the memory
    // is going out; the Phone Keyer dialog is where it is explained.
    final text = activity.recording ? m.recordingMemory(label: label) : m.playingMemory(label: label);
    final color = style.color ?? theme.colorScheme.onSurface;
    final controller = _controller;
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(activity.recording ? MdiIcons.recordCircleOutline : MdiIcons.play, size: 16, color: activity.recording ? theme.colorScheme.error : style.color),
        const SizedBox(width: Space.xs),
        Flexible(
          child: Text(
            text,
            style: style.copyWith(fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
        ),
        // Armed, not merely configured: this says THIS memory goes again.
        if (keyer.keyerRepeating && !activity.recording) ...[
          const SizedBox(width: Space.xs),
          Icon(MdiIcons.repeat, size: 14, color: color.withValues(alpha: 0.55)),
        ],
      ],
    );
    return Semantics(
      label: text,
      liveRegion: true,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: keyer.stopVoice,
          // The bar is as wide as the text above it and no wider, the same
          // way the CW message's is — the stack takes its width from the row.
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: _barBelowText),
                child: row,
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: Space.xxs,
                child: controller == null
                    ? LinearProgressIndicator(minHeight: Space.xxs, backgroundColor: color.withValues(alpha: 0.25), color: color)
                    : AnimatedBuilder(
                        animation: controller,
                        builder: (context, _) => Stack(
                          children: [
                            Container(color: color.withValues(alpha: 0.25)),
                            FractionallySizedBox(
                              widthFactor: controller.value,
                              child: Container(color: color),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Enter Sends Messages, and which side of the exchange it plays: a tap
/// steps Off → Run → S&P → Off, the three states an operator moves between
/// mid-contest without looking away from the call field for long. Shown for
/// either keyer — ESM plays voice memories in Phone the way it keys messages
/// in CW (docs/design/logging-fields.md § Enter Sends Messages). Under SO2R
/// its Run / S&P is the radio of the set the operator is in.
class _EnterSendsPill extends StatelessWidget {
  final CatService cat;

  /// Whose Run / S&P it steps, `A` or `B`.
  final String radio;

  const _EnterSendsPill({required this.cat, required this.radio});

  void _step() {
    final esm = cat.enterSends.value;
    if (!esm.on) {
      cat.setEnterSends(on: true);
      cat.setRunning(radio, true);
    } else if (cat.isRunning(radio)) {
      cat.setRunning(radio, false);
    } else {
      cat.setEnterSends(on: false);
      cat.setRunning(radio, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final poloColors = HaLoColors.of(context);
    final borderRadius = BorderRadius.circular(8);
    final strings = context.t.settings.radio.enterSends;
    return ListenableBuilder(
      listenable: Listenable.merge([cat.enterSends, cat.runningB]),
      builder: (context, _) {
        final esm = cat.enterSends.value;
        final label = !esm.on
            ? strings.pillOff
            : cat.isRunning(radio)
            ? strings.pillRun
            : strings.pillSp;
        var foreground = theme.colorScheme.onTertiaryContainer;
        var background = poloColors.tertiaryLight;
        if (!esm.on) {
          foreground = foreground.withValues(alpha: 0.5);
          background = background.withValues(alpha: 0.5);
        }
        return Semantics(
          button: true,
          label: strings.semantics(state: label),
          excludeSemantics: true,
          child: Material(
            color: background,
            borderRadius: borderRadius,
            child: InkWell(
              borderRadius: borderRadius,
              onTap: _step,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.xs),
                child: Text(
                  label,
                  style: TextStyle(fontFamily: 'RobotoCondensed', fontSize: 12, fontWeight: FontWeight.w500, color: foreground),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CwProgressView extends StatefulWidget {
  final CwSendProgress progress;
  final RadioKeyer keyer;

  const _CwProgressView({super.key, required this.progress, required this.keyer});

  @override
  State<_CwProgressView> createState() => _CwProgressViewState();
}

class _CwProgressViewState extends State<_CwProgressView> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      // A message with nothing timed (empty) would give the controller a
      // zero duration, which it refuses; the queue never reports one, but
      // the widget must not be the thing that throws if it did.
      duration: widget.progress.total > Duration.zero ? widget.progress.total : const Duration(milliseconds: 1),
    );
    // A keyer that reports what it keyed needs no estimate running.
    if (widget.progress.sentCount == null) _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.progress;
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium ?? const TextStyle();
    final color = style.color ?? theme.colorScheme.onSurface;
    return Semantics(
      label: context.t.commands.cwSending(text: progress.text),
      liveRegion: true,
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            // What the keyer reported when it reports (a Winkeyer echoes each
            // character), the estimate otherwise.
            final reported = progress.sentCount;
            final sent = reported ?? progress.sentAt(progress.total * _controller.value);
            final fraction = reported == null ? _controller.value : (progress.text.isEmpty ? 1.0 : reported / progress.text.length);
            // The text sizes the stack, and the bar is positioned across
            // its full width — so the bar is exactly as wide as the message
            // above it, and no wider under a short one. (An IntrinsicWidth
            // cannot do this: the bar's fill has no intrinsic width at all.)
            // What waits behind it follows in the row, outside the bar: the
            // bar paces THIS message, and a queued one has no timeline yet.
            final current = Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: _barBelowText),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        // Sent characters at full weight, the rest faded: the
                        // boundary between them is the cursor.
                        TextSpan(
                          text: progress.text.substring(0, sent),
                          style: style.copyWith(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text: progress.text.substring(sent),
                          style: style.copyWith(color: color.withValues(alpha: 0.55)),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: Space.xxs,
                  child: Stack(
                    children: [
                      Container(color: color.withValues(alpha: 0.25)),
                      FractionallySizedBox(
                        widthFactor: fraction,
                        child: Container(color: color),
                      ),
                    ],
                  ),
                ),
              ],
            );
            // Tapping the message keying stops it and everything behind it
            // (Esc's other form); tapping a queued one drops only that one.
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: widget.keyer.stopCw, child: current),
                ),
                // Outside `current`, like the queue behind it and for the
                // same reason: the bar is as wide as the message it paces,
                // and an icon inside that stack would stretch it past the
                // text. Armed, not merely configured — this says THIS
                // message goes again, which is only ever message 1.
                if (widget.keyer.keyerRepeating)
                  Padding(
                    padding: const EdgeInsets.only(left: Space.xs, bottom: _barBelowText),
                    child: Icon(MdiIcons.repeat, size: 14, color: color.withValues(alpha: 0.55)),
                  ),
                if (progress.pending.isNotEmpty)
                  Flexible(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: _barBelowText),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final (index, text) in progress.pending.indexed)
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => widget.keyer.dropQueuedCw(progress.pendingIds[index]),
                                child: Text(' · $text', style: style.copyWith(color: color.withValues(alpha: 0.4)), maxLines: 1, softWrap: false),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The countdown to message 1 going again: the message that will be keyed,
/// the repeat icon beside it, and nothing else — the buttons stand down for
/// the wait the same way they do for a message on the air — under a bar
/// that EMPTIES rather than fills — the wait is running out,
/// not building up, and the two read differently at a glance. Tapping it
/// ends the repeats, the same way tapping a message keying stops it.
class _CwRepeatView extends StatefulWidget {
  final KeyerRepeatWait wait;
  final RadioKeyer keyer;
  final HaLoServices services;

  const _CwRepeatView({super.key, required this.wait, required this.keyer, required this.services});

  @override
  State<_CwRepeatView> createState() => _CwRepeatViewState();
}

class _CwRepeatViewState extends State<_CwRepeatView> with SingleTickerProviderStateMixin {
  /// What is waiting to go again: the message for CW, the memory's label for
  /// voice — resolved here rather than stored on the wait, since a label the
  /// operator renames mid-chain should read as its new name.
  String _label(BuildContext context) {
    final memory = widget.wait.memory;
    if (memory == null) return widget.wait.text;
    final m = context.t.settings.radio.voiceMessages;
    return voiceMessageLabelFor(widget.keyer, memory, m.key(n: memory));
  }

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.wait.delay)..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium ?? const TextStyle();
    final color = style.color ?? theme.colorScheme.onSurface;
    return Semantics(
      label: context.t.settings.radio.cwMessages.repeatWait,
      liveRegion: true,
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Row(
            children: [
              Flexible(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.keyer.cancelKeyerRepeat,
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: _barBelowText),
                        child: Text(
                          _label(context),
                          style: style.copyWith(color: color.withValues(alpha: 0.55)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: Space.xxs,
                        child: Stack(
                          children: [
                            Container(color: color.withValues(alpha: 0.25)),
                            FractionallySizedBox(
                              widthFactor: 1 - _controller.value,
                              child: Container(color: color.withValues(alpha: 0.55)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Beside the message rather than inside its stack, so the bar
              // stays as wide as the text it counts down (the same reason
              // the keying view puts it here). At full strength while the
              // message itself is faded: nothing is on the air, and the icon
              // is the one thing on the line still saying what happens next.
              Padding(
                padding: const EdgeInsets.only(left: Space.xs, bottom: _barBelowText),
                child: Icon(MdiIcons.repeat, size: 14, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Whether [keyer] can do what [can] asks — saying so when SO2R's Radio B's
/// cannot: a key from set B never falls back to radio A, and its refusal is
/// not the silence of a station with no keyer at all, so a key handler
/// claims the key exactly when [RadioKeyer.radio] is `B`.
bool keyerOrSay(BuildContext context, HaLoServices services, RadioKeyer keyer, bool Function() can) {
  if (can()) return true;
  if (keyer.radio == 'B') {
    services.statusBar.showNotice(
      key: 'so2r-cannot-key',
      icon: 'alert-circle-outline',
      text: services.cat.radio2 == null ? context.t.commands.so2rNoRadioB : context.t.commands.so2rRadioCannotKey(radio: 'B'),
      persist: false,
    );
  }
  return false;
}

/// A message or memory waiting for the other SO2R radio to fall quiet
/// ([RadioKeyer.waiting]), in the message's place: under an indeterminate
/// bar, since how long the other radio has left to send is not something
/// this one can know — unlike a repeat's own wait, which counts down.
class _WaitingView extends StatelessWidget {
  final WaitingSend send;
  final RadioKeyer keyer;

  const _WaitingView({required this.send, required this.keyer});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium ?? const TextStyle();
    final color = style.color ?? theme.colorScheme.onSurface;
    final memory = send.memory;
    final text = memory == null ? send.text ?? '' : voiceMessageLabelFor(keyer, memory, context.t.settings.radio.voiceMessages.key(n: memory));
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: _barBelowText),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  text,
                  style: style.copyWith(fontWeight: FontWeight.bold, color: color.withValues(alpha: 0.7)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
              ),
              if (send.repeat) ...[const SizedBox(width: Space.xs), Icon(MdiIcons.repeat, size: 14, color: color.withValues(alpha: 0.55))],
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: Space.xxs,
          child: LinearProgressIndicator(minHeight: Space.xxs, backgroundColor: color.withValues(alpha: 0.25), color: color),
        ),
      ],
    );
  }
}
