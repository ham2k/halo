// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The keyer line's voice message: the memory playing or recording in the
// message's place (keyer_area.dart). A part of keyer_area.dart, sharing its
// bar's geometry.

part of 'keyer_area.dart';

/// The memory playing or recording, in the message's place, under a bar:
/// tapping it stops it (Esc's other form). A MEASURED memory paces its own bar
/// (CatService times every play — settings_service.dart's
/// `voiceMessageDuration`); an unmeasured one shows an indeterminate bar
/// instead, which says "still going" without claiming to know how far
/// along. A memory measures itself the first time it is played, so the
/// second play is the one that gets the real bar. A message made from the
/// operator's words is measured as it is made, and its activity carries the
/// length ([VoiceActivity.lengthMs]): its bar is real from the first play.
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
    // memory or take, or a play becoming a recording, starts one afresh.
    // A message made from words learns its length as it starts.
    if (old.activity.memory != widget.activity.memory ||
        old.activity.recording != widget.activity.recording ||
        old.activity.lengthMs != widget.activity.lengthMs ||
        old.activity.take != widget.activity.take ||
        !identical(old.activity.script, widget.activity.script)) {
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
    final millis = widget.activity.lengthMs ?? widget.keyer.voiceMessageDuration(widget.activity.memory);
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
    // The label alone, with "Message 3" for a memory that has none: the
    // play icon and the bar already say it is going out, and a bare "M3"
    // under a bar reads as a code. A recording keeps its word — it is the
    // one state here that puts nothing on the air.
    final label = voiceMessageLabelFor(keyer, activity.memory, m.message(n: activity.memory));
    // Doubt is not shown here. It is a real state — the radio answered
    // "idle" before ever answering "going" — but a question mark on the
    // strip asks the operator something they cannot answer while the memory
    // is going out; the Phone Keyer dialog is where it is explained.
    // A message made from words shows its words in place of its label,
    // said ones set apart from the rest as a CW message's sent characters are.
    final script = activity.recording ? null : activity.script;
    final text = activity.recording ? m.recordingMemory(label: label) : script?.text ?? label;
    final color = style.color ?? theme.colorScheme.onSurface;
    final controller = _controller;
    final bold = style.copyWith(fontWeight: FontWeight.bold);
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(activity.recording ? MdiIcons.recordCircleOutline : MdiIcons.play, size: 16, color: activity.recording ? theme.colorScheme.error : style.color),
        const SizedBox(width: Space.xs),
        Flexible(
          child: script == null || controller == null
              ? Text(text, style: bold, maxLines: 1, overflow: TextOverflow.ellipsis, softWrap: false)
              : AnimatedBuilder(
                  animation: controller,
                  builder: (context, _) {
                    final said = script.saidAt(controller.value * controller.duration!.inMilliseconds).clamp(0, text.length);
                    return Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: text.substring(0, said), style: bold),
                          TextSpan(
                            text: text.substring(said),
                            style: style.copyWith(color: color.withValues(alpha: 0.55)),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                    );
                  },
                ),
        ),
        // Armed, not merely configured: this says THIS memory goes again.
        if (keyer.keyerRepeating && !activity.recording) ...[
          const SizedBox(width: Space.xs),
          Icon(MdiIcons.repeat, size: 14, color: color.withValues(alpha: 0.55)),
        ],
      ],
    );
    final current = Semantics(
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
    // What waits behind it follows in the row, outside the bar, as a CW
    // message's queue does: the bar paces THIS memory. Tapping one drops it.
    return ValueListenableBuilder<List<int>>(
      valueListenable: keyer.voiceQueue,
      builder: (context, queued, _) => queued.isEmpty || activity.recording
          ? current
          : Row(
              children: [
                Flexible(child: current),
                Flexible(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: _barBelowText),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final (index, n) in queued.indexed)
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => keyer.dropQueuedVoice(index),
                              child: Text(
                                ' · ${voiceMessageLabelFor(keyer, n, m.message(n: n))}',
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
            ),
    );
  }
}
