// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The keyer area: the strip between the logging panel's call-info area and its entry row
// while the radio keys for the app: a pill with the keyer speed (tap to
// change it), then the message going out with the characters already sent
// set apart and a bar under it pacing through the message's estimated
// duration, then whatever waits behind it. Estimated — the radio reports
// nothing about its progress (docs/design/cat.md § CW keying) — so this
// shows the same arithmetic the send queue paces by, and is right to the
// extent that is.
//
// The strip slides down into place with the first message, or on KEYER /
// the Station dialog's Show, and while nothing is keying offers a button
// per message. In a Phone mode — the draft contact's — the strip is the
// voice keyer's instead: a voice pill in place of the speed, a button per
// voice memory of the radio, and the memory playing (or recording) in
// place of the message going out (docs/design/cat.md § Voice keying). A
// message leaves
// it the moment it ends — finished or stopped, what went out is not worth
// re-reading — and the pill stays for [cwSendingLingers] after the last one,
// which is when a speed change is most often wanted, before the strip slides
// back up — or the X at its end sends it away sooner.
//
// Driven by AnimationControllers rather than a clock: the bar advances per
// frame for a few seconds and stops with the message, which is neither a
// per-second UI (WallClock's job) nor anything time travel should move.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../i18n/strings.g.dart';
import '../main.dart';
import 'cw_messages_dialog.dart';
import 'voice_messages_dialog.dart';
import '../services/cat/cat_service.dart';
import '../services/cat/driver.dart' show VoiceActivity;
import '../services/error_reporting_service.dart';
import '../services/cat/drivers/cw_send_queue.dart';
import '../services/settings_service.dart';
import 'operation/extension_panel.dart' show PanelRenderContext, operationHookArgs;

/// How long the strip stays after the last message ends.
const cwSendingLingers = Duration(seconds: 60);

/// The slide in and out.
const _revealDuration = Duration(milliseconds: 250);

class KeyerArea extends StatefulWidget {
  final CatService cat;

  /// For the way from the speed dialog to the message editor
  /// (`showCwMessagesDialog`), which takes the whole services object, and
  /// for the messages the idle buttons offer.
  final HaLoServices services;

  /// Keys message [n] — what the idle buttons do. Null leaves them disabled
  /// (a host with no draft contact to render against).
  final void Function(int n)? onSendMessage;

  /// What the message buttons' labels render against, for a label written
  /// as a template (`{{ qso.call }} 5NN`). Null renders nothing: labels show
  /// as written.
  final PanelRenderContext? templateContext;

  /// Whether the strip is the voice keyer's: the draft contact's mode is
  /// Phone. Decided by the operation view, which routes F1-F8 by the same
  /// answer — decided ONCE, so the keys and the strip never disagree about
  /// which keyer this is. The draft's mode, not the radio's: the messages
  /// are for the contact being logged, and a rig sitting in USB while the
  /// operator logs CW keys CW.
  final bool phone;

  /// True while the logging panel is editing a logged QSO: the area slides
  /// out and stays out until editing ends, then comes back if something is
  /// still keying. Messages are for the contact in progress, not for one
  /// being corrected.
  final bool suppressed;

  const KeyerArea({
    super.key,
    required this.cat,
    required this.services,
    this.onSendMessage,
    this.templateContext,
    this.phone = false,
    this.suppressed = false,
  });

  @override
  State<KeyerArea> createState() => _KeyerAreaState();
}

class _KeyerAreaState extends State<KeyerArea> with SingleTickerProviderStateMixin {
  // Created in initState, never lazily: a `late` controller first touched
  // by dispose() would look TickerMode up on a context that is already gone.
  late final AnimationController _reveal;

  /// Whether the strip is (or is sliding) in — from the first message until
  /// [_hide] fires after the last.
  bool _visible = false;

  Timer? _hide;

  @override
  void initState() {
    super.initState();
    _reveal = AnimationController(vsync: this, duration: _revealDuration);
    widget.cat.cwProgress.addListener(_onProgress);
    widget.cat.voiceActivity.addListener(_onProgress);
    widget.cat.keyerAreaShown.addListener(_onShownChanged);
    widget.cat.keyerShowRequests.addListener(_onShowRequested);
    _onProgress();
    _onShownChanged();
  }

  /// An explicit ask (KEYER, the toggle) while already shown: the flag does
  /// not move, but a linger in progress must not carry the area away.
  void _onShowRequested() => _show();

  /// `CatService.keyerAreaShown` is the one switch: KEYER, the Station
  /// dialog's toggle and a message starting set it; the X, the linger and
  /// the toggle clear it. This only follows it in and out.
  void _onShownChanged() {
    if (widget.cat.keyerAreaShown.value) {
      _show();
    } else {
      _close();
    }
  }

  void _show() {
    if (widget.suppressed) return;
    _hide?.cancel();
    _hide = null;
    if (!_visible) setState(() => _visible = true);
    _reveal.forward();
  }

  @override
  void didUpdateWidget(KeyerArea old) {
    super.didUpdateWidget(old);
    if (old.cat != widget.cat) {
      old.cat.cwProgress.removeListener(_onProgress);
      old.cat.voiceActivity.removeListener(_onProgress);
      old.cat.keyerAreaShown.removeListener(_onShownChanged);
      old.cat.keyerShowRequests.removeListener(_onShowRequested);
      widget.cat.cwProgress.addListener(_onProgress);
      widget.cat.voiceActivity.addListener(_onProgress);
      widget.cat.keyerAreaShown.addListener(_onShownChanged);
      widget.cat.keyerShowRequests.addListener(_onShowRequested);
      _onProgress();
      _onShownChanged();
    }
    if (widget.suppressed && !old.suppressed) _close();
    if (!widget.suppressed && old.suppressed) {
      // Shown first, then the progress: a message that ended meanwhile arms
      // the linger, which a show would otherwise cancel.
      _onShownChanged();
      _onProgress();
    }
  }

  @override
  void dispose() {
    widget.cat.cwProgress.removeListener(_onProgress);
    widget.cat.voiceActivity.removeListener(_onProgress);
    widget.cat.keyerAreaShown.removeListener(_onShownChanged);
    widget.cat.keyerShowRequests.removeListener(_onShowRequested);
    _hide?.cancel();
    _reveal.dispose();
    super.dispose();
  }

  /// The message whose start last showed the area — a Winkeyer re-reports
  /// the same message on every echo, and each of those must not undo an X.
  int? _shownForMessage;

  /// The voice activity that last showed it, the same way.
  VoiceActivity? _shownForVoice;

  void _onProgress() {
    if (widget.suppressed) return;
    final progress = widget.cat.cwProgress.value;
    final voice = widget.cat.voiceActivity.value;
    if (progress != null || voice != null) {
      _hide?.cancel();
      _hide = null;
      if (progress != null && _shownForMessage != progress.id) {
        _shownForMessage = progress.id;
        // A message starting shows the area through the flag, so the
        // Station dialog's toggle agrees.
        widget.cat.showKeyerArea();
      }
      if (voice != null && _shownForVoice != voice) {
        _shownForVoice = voice;
        widget.cat.showKeyerArea();
      }
      return;
    }
    _shownForMessage = null;
    _shownForVoice = null;
    if (!_visible) return;
    _hide?.cancel();
    _hide = Timer(cwSendingLingers, () {
      _hide = null;
      widget.cat.hideKeyerArea();
      // Directly as well: when the X went first the flag is already off and
      // changes nothing, and nothing else would slide the area away.
      _close();
    });
  }

  /// Slides the area away. A message still keying keeps going; its next
  /// report brings the area back.
  void _close() {
    if (!mounted) return;
    _hide?.cancel();
    _hide = null;
    _reveal.reverse().whenComplete(() {
      if (mounted && _hide == null && !widget.cat.keyerAreaShown.value) setState(() => _visible = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    // Grows from the top edge down, and the content rides in with it — so
    // the strip reads as sliding down out of the call-info area, and back up
    // into it, rather than fading in place.
    return SizeTransition(
      sizeFactor: _reveal,
      axisAlignment: -1,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(_reveal),
        child: Padding(
          // Both insets inside the slide, so a hidden strip costs nothing.
          padding: const EdgeInsets.only(top: Space.md, bottom: Space.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (widget.phone)
                _VoicePill(cat: widget.cat, services: widget.services)
              else
                _KeyerSpeedPill(cat: widget.cat, services: widget.services),
              const SizedBox(width: Space.md),
              Expanded(
                child: ListenableBuilder(
                  listenable: Listenable.merge([widget.cat.cwProgress, widget.cat.voiceActivity]),
                  builder: (context, _) {
                    final progress = widget.cat.cwProgress.value;
                    final voice = widget.cat.voiceActivity.value;
                    return Stack(
                      alignment: AlignmentDirectional.centerStart,
                      children: [
                        // Kept mounted under the message, not rebuilt after each
                        // one: the buttons hold rendered labels, and a remount
                        // would show raw templates and cross the bridge again
                        // for a draft that has not moved. Two siblings rather
                        // than one slot swapping types: a mode flip must not
                        // remount them either.
                        Visibility(
                          visible: !widget.phone && progress == null && voice == null,
                          maintainState: true,
                          child: _MessageButtons(
                            services: widget.services,
                            onSendMessage: widget.onSendMessage,
                            templateContext: widget.templateContext,
                          ),
                        ),
                        Visibility(
                          visible: widget.phone && progress == null && voice == null,
                          child: _VoiceButtons(services: widget.services),
                        ),
                        // Keyed on the message's id, so a new one restarts the
                        // animation from its own beginning — while a re-report of
                        // the SAME message (the queue behind it changed) keeps the
                        // animation where it is.
                        if (progress != null)
                          _CwProgressView(key: ValueKey(progress.id), progress: progress, cat: widget.cat),
                        if (voice != null && progress == null)
                          _VoiceActivityView(activity: voice, cat: widget.cat, services: widget.services),
                      ],
                    );
                  },
                ),
              ),
              IconButton(
                // No hover tooltips (docs/design/user-interface.md), so the
                // accessible name is the only place this button is named.
                icon: Icon(MdiIcons.close, size: 16, semanticLabel: context.t.settings.radio.cwMessages.closeArea),
                visualDensity: VisualDensity.compact,
                onPressed: widget.cat.hideKeyerArea,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// How long after the last draft change a templated label is re-rendered.
/// On top of the draft's own debounce upstream, so a keystroke burst costs
/// the bridge one render per label, not one per letter.
const cwLabelRenderDelay = Duration(milliseconds: 300);

/// While nothing is keying: one outlined button per message that has text,
/// its key's number and its label (the key itself when there is none) —
/// the function keys for a mouse or a finger. A label written as a template
/// renders like the message would, against the draft contact, so
/// `{{ qso.call }} 5NN` reads as the call in the field.
class _MessageButtons extends StatefulWidget {
  final HaLoServices services;
  final void Function(int n)? onSendMessage;
  final PanelRenderContext? templateContext;

  const _MessageButtons({required this.services, required this.onSendMessage, required this.templateContext});

  @override
  State<_MessageButtons> createState() => _MessageButtonsState();
}

class _MessageButtonsState extends State<_MessageButtons> {
  /// Rendered label text by message, with the template it came from — a
  /// label edited since is shown as written until its own render lands.
  final _rendered = <int, ({String template, String text})>{};
  Timer? _debounce;
  int _renderGeneration = 0;

  static bool _isTemplate(String label) => label.contains('{{') || label.contains('{%');

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
    _scheduleRender();
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
    for (var n = 1; n <= SettingsService.cwMessageCount; n++) {
      if (settings.cwMessage(n).trim().isEmpty) continue;
      final label = settings.cwMessageLabel(n).trim();
      if (!_isTemplate(label)) continue;
      numbers.add(n);
      labels.add(label);
    }
    if (labels.isEmpty) return;
    List<({String? text, String? error})>? rendered;
    try {
      rendered = await widget.services.extensions.renderTemplates(
        labels,
        operation: ctx.operation == null ? null : operationHookArgs(ctx.operation!),
        qso: ctx.qso,
        qsoCount: ctx.qsoCount,
      );
    } catch (e, st) {
      // A hook timeout or a dead runtime: the labels keep what they last
      // showed, and the next draft pause tries again.
      ErrorReportingService.report(e, st, context: 'cw:render-labels');
      return;
    }
    // A newer render was scheduled while this one was on the bridge; its
    // answers are for a draft that has moved on.
    if (!mounted || generation != _renderGeneration || rendered == null) return;
    final results = <int, ({String template, String text})>{};
    for (var i = 0; i < numbers.length && i < rendered.length; i++) {
      // A label that does not parse (`error`) shows as written — the
      // operator's own typo, visible where they will fix it.
      final text = rendered[i].text;
      if (text != null) results[numbers[i]] = (template: labels[i], text: text.trim());
    }
    setState(() => _rendered
      ..clear()
      ..addAll(results));
  }

  String _labelFor(int n, String key) {
    final label = widget.services.settings.cwMessageLabel(n).trim();
    if (label.isEmpty) return key;
    final rendered = _rendered[n];
    if (rendered != null && rendered.template == label && rendered.text.isNotEmpty) return rendered.text;
    return label;
  }

  @override
  Widget build(BuildContext context) {
    final services = widget.services;
    final settings = services.settings;
    final m = context.t.settings.radio.cwMessages;
    return ListenableBuilder(
      listenable: Listenable.merge([settings, services.cat]),
      builder: (context, _) {
        final enabled = services.cat.canKeyCw && widget.onSendMessage != null;
        final theme = Theme.of(context);
        // The pill's geometry and type, outlined in the chips' accent
        // rather than filled: these ACT, the pill only shows.
        var color = theme.colorScheme.tertiary;
        if (!enabled) color = color.withValues(alpha: 0.5);
        final borderRadius = BorderRadius.circular(8);
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var n = 1; n <= SettingsService.cwMessageCount; n++)
                if (settings.cwMessage(n).trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: Space.sm),
                    child: Material(
                      color: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: borderRadius, side: BorderSide(color: color)),
                      child: InkWell(
                        borderRadius: borderRadius,
                        onTap: enabled ? () => widget.onSendMessage!(n) : null,
                        mouseCursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.xs),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(cwMessageNumberIcons[n - 1], size: 14, color: color),
                              const SizedBox(width: Space.xs),
                              Text(
                                _labelFor(n, m.key(n: n)),
                                style: TextStyle(
                                  fontFamily: 'RobotoCondensed',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }
}

/// While nothing is playing, in a Phone mode: one outlined button per voice
/// memory of the radio — the function keys for a mouse or a finger — with
/// its label, or its key when it has none. Without a radio that can play,
/// the memories that have a label, disabled: the names the operator set are
/// worth seeing before the rig is on.
class _VoiceButtons extends StatelessWidget {
  final HaLoServices services;

  const _VoiceButtons({required this.services});

  @override
  Widget build(BuildContext context) {
    final settings = services.settings;
    final cat = services.cat;
    final m = context.t.settings.radio.voiceMessages;
    return ListenableBuilder(
      listenable: Listenable.merge([settings, cat]),
      builder: (context, _) {
        final enabled = cat.canPlayVoice;
        final count = enabled ? cat.voiceMemoryCount : SettingsService.voiceMessageCount;
        final theme = Theme.of(context);
        var color = theme.colorScheme.tertiary;
        if (!enabled) color = color.withValues(alpha: 0.5);
        final borderRadius = BorderRadius.circular(8);
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var n = 1; n <= count; n++)
                if (enabled || settings.voiceMessageLabel(n).trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: Space.sm),
                    child: Material(
                      color: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: borderRadius, side: BorderSide(color: color)),
                      child: InkWell(
                        borderRadius: borderRadius,
                        onTap: enabled ? () => cat.playVoiceMemory(n) : null,
                        mouseCursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.xs),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(cwMessageNumberIcons[n - 1], size: 14, color: color),
                              const SizedBox(width: Space.xs),
                              Text(
                                voiceMessageLabelFor(settings, n, m.key(n: n)),
                                style: TextStyle(
                                  fontFamily: 'RobotoCondensed',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
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
class _VoiceActivityView extends StatelessWidget {
  final VoiceActivity activity;
  final CatService cat;
  final HaLoServices services;

  const _VoiceActivityView({required this.activity, required this.cat, required this.services});

  @override
  Widget build(BuildContext context) {
    final m = context.t.settings.radio.voiceMessages;
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium ?? const TextStyle();
    final label = voiceMessageLabelFor(services.settings, activity.memory, m.key(n: activity.memory));
    // Doubtful — the radio said "not going" before ever saying "going" —
    // asks rather than states: an empty memory must not read as a short one.
    final text = switch ((activity.recording, activity.doubtful)) {
      (true, false) => m.recordingMemory(label: label),
      (true, true) => m.recordingDoubtful(label: label),
      (false, false) => m.playingMemory(label: label),
      (false, true) => m.playingDoubtful(label: label),
    };
    return Semantics(
      label: text,
      liveRegion: true,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: cat.stopVoice,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                activity.recording ? MdiIcons.recordCircleOutline : MdiIcons.play,
                size: 16,
                color: activity.recording ? theme.colorScheme.error : style.color,
              ),
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
            ],
          ),
        ),
      ),
    );
  }
}

/// The speed pill's place in a Phone mode: says the strip is the voice
/// keyer's, and opens the Voice Messages dialog — where a memory is named,
/// played to check, or recorded — the way the speed pill opens the keyer's.
/// Faded the same way when nothing can play.
class _VoicePill extends StatelessWidget {
  final CatService cat;
  final HaLoServices services;

  const _VoicePill({required this.cat, required this.services});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final poloColors = HaLoColors.of(context);
    final borderRadius = BorderRadius.circular(8);
    return ListenableBuilder(
      listenable: cat,
      builder: (context, _) {
        final enabled = cat.canPlayVoice;
        var foreground = theme.colorScheme.onTertiaryContainer;
        var background = poloColors.tertiaryLight;
        if (!enabled) {
          foreground = foreground.withValues(alpha: 0.5);
          background = background.withValues(alpha: 0.5);
        }
        return Material(
          color: background,
          borderRadius: borderRadius,
          child: InkWell(
            borderRadius: borderRadius,
            onTap: () => showVoiceMessagesDialog(context, services),
            mouseCursor: SystemMouseCursors.click,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.xs),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(MdiIcons.microphone, size: 14, color: foreground),
                  const SizedBox(width: Space.xs),
                  Text(
                    context.t.settings.radio.voiceMessages.pill,
                    style: TextStyle(
                      fontFamily: 'RobotoCondensed',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: foreground,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The keyer speed as the radio reports it; tapping opens [showKeyerSpeedDialog].
///
/// Dressed like an unselected secondary-control chip (secondary_control_row.dart's
/// `_ControlChip`: tertiaryLight fill, onTertiaryContainer text, the boxy
/// 8 px corners) so it reads as one of the logging panel's own controls —
/// in smaller, condensed type, since it sits beside a message rather than
/// in the chip strip, and faded the way a disabled chip is when nothing
/// can key.
class _KeyerSpeedPill extends StatelessWidget {
  final CatService cat;
  final HaLoServices services;

  const _KeyerSpeedPill({required this.cat, required this.services});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final poloColors = HaLoColors.of(context);
    final borderRadius = BorderRadius.circular(8);
    return ListenableBuilder(
      listenable: cat,
      builder: (context, _) {
        final speed = cat.keyerSpeed;
        final enabled = cat.canKeyCw;
        final label = speed == null
            ? context.t.settings.radio.keyerSpeed.pillUnknown
            : context.t.settings.radio.keyerSpeed.pill(wpm: speed);
        var foreground = theme.colorScheme.onTertiaryContainer;
        var background = poloColors.tertiaryLight;
        if (!enabled) {
          foreground = foreground.withValues(alpha: 0.5);
          background = background.withValues(alpha: 0.5);
        }
        return Material(
          color: background,
          borderRadius: borderRadius,
          child: InkWell(
            borderRadius: borderRadius,
            onTap: enabled ? () => showKeyerSpeedDialog(context, cat, services: services) : null,
            mouseCursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.xs),
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'RobotoCondensed',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: foreground,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The keyer, mid-QSO: the speed (Enter or Save applies it and closes),
/// a way to the message editor, and a free-text message that goes straight
/// to the queue — as typed, no template — with Enter or Send, which closes
/// the dialog too: the keyer area is where the message is then watched. The speed is clamped to what radio1's
/// keyer accepts, and what shows afterwards is what the radio reports back,
/// never the typed value assumed.
Future<void> showKeyerSpeedDialog(BuildContext context, CatService cat, {required HaLoServices services}) =>
    showHaloDialog<void>(
      context: context,
      builder: (context) => _KeyerSpeedDialog(cat: cat, services: services),
    );

class _KeyerSpeedDialog extends StatefulWidget {
  final CatService cat;
  final HaLoServices services;

  const _KeyerSpeedDialog({required this.cat, required this.services});

  @override
  State<_KeyerSpeedDialog> createState() => _KeyerSpeedDialogState();
}

class _KeyerSpeedDialogState extends State<_KeyerSpeedDialog> {
  late final _speed = TextEditingController(text: widget.cat.keyerSpeed?.toString() ?? '');
  final _message = TextEditingController();

  @override
  void dispose() {
    _speed.dispose();
    _message.dispose();
    super.dispose();
  }

  void _applySpeed() {
    final wpm = int.tryParse(_speed.text.trim());
    final range = widget.cat.keyerSpeedRange;
    if (wpm != null && range != null) widget.cat.setKeyerSpeed(wpm.clamp(range.min, range.max));
  }

  void _save() {
    _applySpeed();
    Navigator.of(context).pop();
  }

  /// Queues the text and closes: the message is on its way, and the keyer
  /// area shows it going out.
  void _send() {
    final text = _message.text.trim();
    if (text.isEmpty) return;
    widget.cat.sendCw(text);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.t.settings.radio.keyerSpeed;
    final m = context.t.settings.radio.cwMessages;
    // The dialog's own content inset is dropped so the section band runs
    // edge to edge, the way it does on the settings screens; the rows take
    // the inset the dialog would have given them (halo_dialog.dart's
    // default) themselves.
    const rowInset = EdgeInsets.symmetric(horizontal: Space.xxl);
    return HaloDialog(
      title: Text(context.t.settings.radio.cwKeying),
      contentPadding: EdgeInsets.zero,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: rowInset.copyWith(top: Space.xl, bottom: Space.xl),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _speed,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: poloFieldDecoration(context, s.unit),
                    onSubmitted: (_) => _save(),
                  ),
                ),
                const SizedBox(width: Space.md),
                IconButton(
                  // No hover tooltips (docs/design/user-interface.md), so the
                  // accessible name is the only place this button is named.
                  icon: Icon(MdiIcons.messageBulleted, semanticLabel: m.title),
                  onPressed: () => showCwMessagesDialog(context, widget.services),
                ),
              ],
            ),
          ),
          SectionHeader(m.custom),
          Padding(
            padding: rowInset.copyWith(top: Space.lg, bottom: Space.xl),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _message,
                    // Uppercase as typed — Morse has no case, and the queue
                    // would uppercase anyway; seeing it while typing says so.
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [UpperCaseTextFormatter()],
                    decoration: poloFieldDecoration(context, m.customField),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: Space.md),
                FilledButton.tonal(onPressed: _send, child: Text(m.send)),
              ],
            ),
          ),
        ],
      ),
      cancel: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.t.common.cancel)),
      actions: [
        FilledButton(onPressed: _save, child: Text(context.t.common.save)),
      ],
    );
  }
}

class _CwProgressView extends StatefulWidget {
  final CwSendProgress progress;
  final CatService cat;

  const _CwProgressView({super.key, required this.progress, required this.cat});

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
            final fraction = reported == null
                ? _controller.value
                : (progress.text.isEmpty ? 1.0 : reported / progress.text.length);
            // The text sizes the stack, and the bar is positioned across
            // its full width — so the bar is exactly as wide as the message
            // above it, and no wider under a short one. (An IntrinsicWidth
            // cannot do this: the bar's fill has no intrinsic width at all.)
            // What waits behind it follows in the row, outside the bar: the
            // bar paces THIS message, and a queued one has no timeline yet.
            final current = Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.xxs * 2),
                  child: Text.rich(
                    TextSpan(children: [
                      // Sent characters at full weight, the rest faded: the
                      // boundary between them is the cursor.
                      TextSpan(text: progress.text.substring(0, sent), style: style.copyWith(fontWeight: FontWeight.bold)),
                      TextSpan(
                        text: progress.text.substring(sent),
                        style: style.copyWith(color: color.withValues(alpha: 0.55)),
                      ),
                    ]),
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
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.cat.stopCw,
                    child: current,
                  ),
                ),
                if (progress.pending.isNotEmpty)
                  Flexible(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: Space.xxs * 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final (index, text) in progress.pending.indexed)
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => widget.cat.dropQueuedCw(progress.pendingIds[index]),
                                child: Text(
                                  ' · $text',
                                  style: style.copyWith(color: color.withValues(alpha: 0.4)),
                                  maxLines: 1,
                                  softWrap: false,
                                ),
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
