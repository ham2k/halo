// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The logging panel's lifecycle surfaces: the read that stands in
// for the entry row once a log is no longer being written, and the controls
// that sit beside and below it.
//
// Their own file rather than more of `logging_controls.dart`, which is at the
// size the file-size guard allows it. They earn it besides: none of this
// touches the entry row's state — it is handed what the operation says and
// calls back.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';

import 'format_utils.dart';
import 'mdi_icons.g.dart';
import 'operation_lifecycle_spec.dart';
import 'semantic_id.dart';
import 'spacing.dart';
import 'theme.dart';
import 'wall_clock.dart';

/// One transition the corner slot offers.
///
/// [key] names the control's ROLE and [label] is what a screen reader says.
/// They are separate because the semantics identifier is a hook for agent and
/// browser tooling (#236) and must not move when the app is translated — a
/// Spanish build's "Terminar" has to be found by the same id as "Done".
///
/// [prominent] draws the label rather than only announcing it. START sits in
/// a slot the operator last saw holding a wipe button, and a paused log's
/// Finish ends it for good — a bare glyph is a guess at the first and too
/// easy a press for the second. ⏸ earns it after a few quiet minutes, when
/// stepping away has become the likely next move.
typedef OperationLifecycleControl = ({String key, IconData icon, String label, bool prominent, VoidCallback onPressed});

/// What the corner slot offers right now, in order — empty when it keeps its
/// ordinary wipe/undo/delete duty.
///
/// [locked] is whether the read has taken the entry row; [labelPause] whether
/// the panel's short silence has passed; [hasComposedValues] whether there is
/// anything to wipe or a wipe waiting to be undone.
List<OperationLifecycleControl> operationLifecycleControls(
  OperationLifecycleSpec? spec, {
  required bool locked,
  required bool labelPause,
  required bool hasComposedValues,
  required bool editing,
}) {
  if (spec == null || editing) return const [];
  if (locked) {
    // A finished log has only its exports left to do; one still merely paused
    // has DONE ahead of it. Reopening is NOT here — it sits beside the read
    // itself, next to the state it undoes.
    if (spec.finished) {
      return [if (spec.onExports != null) (key: 'exports', icon: MdiIcons.trayArrowUp, label: spec.exportsLabel, prominent: true, onPressed: spec.onExports!)];
    }
    return [if (spec.onEnd != null) (key: 'end', icon: MdiIcons.stop, label: spec.endLabel, prominent: true, onPressed: spec.onEnd!)];
  }
  // START replaces the wipe button only while there is nothing to wipe: an
  // operator part-way through composing a call wants the wipe they reached
  // for, and logging that contact starts the operation anyway.
  if (spec.notStarted) {
    if (hasComposedValues || spec.onStart == null) return const [];
    return [(key: 'start', icon: MdiIcons.play, label: spec.startLabel, prominent: true, onPressed: spec.onStart!)];
  }
  // ⏸ holds the slot only while there is nothing to wipe — between contacts,
  // which is when stepping away happens — and gives it back the moment
  // anything is typed, into any field, so the wipe is there for the draft
  // being composed. An undo still waiting keeps the slot until it expires:
  // the operator who just wiped is the one most likely to want that back. Pressing it is the ONLY
  // thing here that writes a pause — the silence itself never does, because
  // an operator calling CQ into a dead band has not paused.
  if (!hasComposedValues && spec.status == OperationStatus.active && spec.onPause != null) {
    return [(key: 'pause', icon: MdiIcons.pause, label: spec.pauseLabel, prominent: labelPause, onPressed: spec.onPause!)];
  }
  return const [];
}

/// What the info area has to keep clear on the button side.
///
/// One [diameter] per icon control, so a pair does not paint over the stats
/// line — and for a labelled button, the label's own measured width
/// ([textWidth], the same measurer the QSO list and the spots panel size their
/// columns with). Sizing it to anything fixed would clip the label under a
/// long translation or a raised text scale, which is the trap that measurer
/// exists to avoid.
double operationLifecycleSlotWidth(BuildContext context, List<OperationLifecycleControl> controls, {required double diameter}) {
  if (controls.isEmpty) return diameter;
  if (controls.length == 1 && controls.first.prominent) {
    final style = Theme.of(context).textTheme.labelLarge ?? const TextStyle();
    return textWidth(context, controls.first.label, style) + _trailingIconPadding.horizontal + _labelledIconSize + _labelledIconGap;
  }
  return diameter * controls.length;
}

/// The labelled lifecycle buttons' padding, shared so the filled and the
/// outlined one are the same shape. Material's default for a trailing icon
/// puts the wider inset on the icon's side.
const _trailingIconPadding = EdgeInsetsDirectional.only(start: 24, end: 16);

/// The labelled button's icon, set rather than left to the theme so the slot
/// can reserve it: [operationLifecycleSlotWidth] sizes the slot from these,
/// and a slot narrower than the button lets it paint over the stats line.
const _labelledIconSize = 18.0;

/// The gap FilledButton.icon puts between its label and icon. Its own, not
/// settable: 8 at an unscaled text size, narrowing as the text scale rises —
/// so reserving 8 never falls short.
const _labelledIconGap = 8.0;

/// The corner slot's lifecycle controls.
class OperationLifecycleSlot extends StatelessWidget {
  final List<OperationLifecycleControl> controls;
  final ThemeData accentTheme;
  final double diameter;

  const OperationLifecycleSlot({super.key, required this.controls, required this.accentTheme, required this.diameter});

  @override
  Widget build(BuildContext context) {
    if (controls.length == 1 && controls.first.prominent) {
      final control = controls.first;
      return semanticId(
        'action.lifecycle.${control.key}',
        SizedBox(
          height: diameter,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: accentTheme.colorScheme.tertiary,
              foregroundColor: accentTheme.colorScheme.onTertiary,
              padding: _trailingIconPadding,
              iconSize: _labelledIconSize,
            ),
            onPressed: control.onPressed,
            icon: Icon(control.icon),
            iconAlignment: IconAlignment.end,
            label: Text(control.label),
          ),
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final control in controls)
          semanticId(
            'action.lifecycle.${control.key}',
            SizedBox(
              width: diameter,
              height: diameter,
              child: IconButton(
                onPressed: control.onPressed,
                // Screen-reader name only — no hover tooltip (user-interface.md).
                icon: Icon(control.icon, semanticLabel: control.label),
                color: accentTheme.colorScheme.tertiary,
                padding: EdgeInsets.zero,
                iconSize: diameter * 0.5 * 1.2,
              ),
            ),
          ),
      ],
    );
  }
}

/// What a callsign may begin with, and so what may reopen an operation by
/// being typed at its status read.
final _reopenCharacter = RegExp(r'^[A-Za-z0-9/]$');

/// The two-line read that stands in for the entry row: what state the
/// operation is in, and when it ran.
///
/// It REPLACES the row rather than dimming it: a disabled-but-present entry
/// row reads as "you may type here in a moment", which is exactly what a
/// completed log does not mean. The secondary controls above stay put and
/// dimmed, as they do for every other lock reason.
///
/// Focusable, and the ONE place in a locked form where that is true. A
/// printable character here reopens the operation and is carried into the call
/// field the reopening brings back, so an operator who simply starts typing a
/// callsign never has to find a button first. logging-fields.md §"When the
/// form is read-only" records this as the exception it is.
class OperationLifecycleRead extends StatelessWidget {
  /// What to say, and where a callsign character typed here goes: the gate
  /// reopens the operation and holds the character until the entry row the
  /// reopening brings back can take it.
  final OperationLifecycleGate gate;
  final ThemeData accentTheme;
  final double diameter;

  /// The panel's statistics for the closed log: its count over the span,
  /// shown beside the state, then its rate on the line below. A pause shows
  /// only the rate. Empty falls back to the date range.
  final List<String> summary;

  const OperationLifecycleRead({super.key, required this.gate, required this.accentTheme, required this.diameter, this.summary = const []});

  OperationLifecycleSpec? get spec => gate.spec;

  /// Only a callsign character reopens: a bare modifier, an arrow, Tab or
  /// Escape must not restart an operation the operator was only navigating
  /// past — and what lands in the call field bypasses its own
  /// `inputFormatters`, so anything they would have filtered is turned away
  /// here instead.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || spec?.onReopen == null) return KeyEventResult.ignored;
    final character = event.character;
    if (character == null || !_reopenCharacter.hasMatch(character)) return KeyEventResult.ignored;
    if (HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed || HardwareKeyboard.instance.isAltPressed) {
      return KeyEventResult.ignored;
    }
    gate.holdForReopen(character);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondLine = theme.textTheme.bodyMedium?.copyWith(color: accentTheme.colorScheme.onTertiaryContainer.withValues(alpha: 0.7));
    final title = theme.textTheme.titleMedium?.copyWith(color: accentTheme.colorScheme.onTertiaryContainer, fontWeight: FontWeight.w600);
    final pausedSince = spec?.pausedSinceAt(nowMillis());
    // Beside the title: a finished log's count, which leaves the line below
    // to the rate. A pause leaves the count out — its title already says how
    // long the log has stood still — unless there is no rate to show in its
    // place: the summary drops one that rounds to nothing, and a pause over
    // nothing at all would read as a log with nothing in it.
    final beside = pausedSince == null ? summary.firstOrNull : null;
    final below = pausedSince != null && summary.length < 2 ? summary : summary.skip(1).toList();
    final range = spec?.dateRange ?? '';
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: diameter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                // A pause says how long it has lasted rather than what it is
                // called: the question in front of a paused log is whether to
                // come back to it.
                // Flexible: a long translation, a raised text scale or a
                // narrow panel otherwise pushes the row past its edge.
                Flexible(
                  child: pausedSince == null
                      ? Text(gate.reading ?? '', style: title, maxLines: 1, overflow: TextOverflow.ellipsis)
                      : OncePerSecond(
                          builder: (context, _) => Text(
                            t.operation.lifecycle.pausedFor(time: fmtTimeBetween(pausedSince, nowMillis(), seconds: false)),
                            style: title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                ),
                if (beside != null) ...[
                  const SizedBox(width: Space.md),
                  Flexible(
                    child: Text(beside, style: secondLine, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ],
            ),
            if (below.isNotEmpty)
              for (final line in below) Text(line, style: secondLine)
            else if (summary.isEmpty && range.isNotEmpty)
              Text(range, style: secondLine),
          ],
        ),
      ),
    );
  }
}

/// The way back from a closed log: Continue a pause, Restart a finished log.
/// Both write the same `restart` row.
class OperationLifecycleReopenButton extends StatelessWidget {
  final OperationLifecycleSpec? spec;
  final ThemeData accentTheme;
  final double diameter;
  final bool paused;

  const OperationLifecycleReopenButton({super.key, required this.spec, required this.accentTheme, required this.diameter, required this.paused});

  @override
  Widget build(BuildContext context) {
    final onReopen = spec?.onReopen;
    if (onReopen == null) return const SizedBox.shrink();
    return semanticId(
      'action.lifecycle.reopen',
      SizedBox(
        height: diameter,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: accentTheme.colorScheme.tertiary,
            side: BorderSide(color: accentTheme.colorScheme.tertiary),
            padding: _trailingIconPadding,
          ),
          onPressed: onReopen,
          icon: const Icon(MdiIcons.playPause),
          iconAlignment: IconAlignment.end,
          label: Text(paused ? spec!.continueLabel : spec!.restartLabel),
        ),
      ),
    );
  }
}

/// The panel's live view of an operation's lifecycle: what the read says, and
/// whether the corner slot's ⏸ should carry its label yet.
///
/// Both answers move on their own — they are functions of a clock, not of
/// anything the operator does — so they need something watching a heartbeat.
/// That is this object rather than the panel's own `State`, so the panel keeps
/// only what it must: the lock, the row swap, and the field the held keystroke
/// lands in.
///
/// It rides the shared once-per-second clock, the same one the stats line and
/// the Time chip already run on, so no new timer exists at all. A per-second
/// tick is affordable only because [_refresh] compares and returns: it
/// notifies on the two or three transitions a session actually has, not on the
/// ticks. Anything coarser would put the ⏸ label up to a minute late on a
/// three-minute rule.
class OperationLifecycleGate extends ChangeNotifier {
  OperationLifecycleGate() {
    WallClock.seconds.addListener(_refresh);
  }

  OperationLifecycleSpec? _spec;

  /// The read to show in place of the entry row, or null while the operation
  /// is being logged into.
  String? reading;

  /// Whether the corner slot's ⏸ carries its label.
  bool labelPause = false;

  String? _pendingCharacter;
  int _pendingSince = 0;

  /// How long a character held for a reopening stays worth delivering. Long
  /// enough for the writes the reopening makes and the frames they cause; far
  /// short of anything the operator would still call "the letter I just
  /// typed".
  static const _pendingLifetime = Duration(seconds: 3);

  /// The spec the panel most recently built. Assigning re-reads the
  /// presentation immediately rather than waiting for the next tick: an export
  /// finishing promotes the operation from behind the export sheet, and the
  /// row has to be locked by the time that sheet is dismissed.
  set spec(OperationLifecycleSpec? value) {
    _spec = value;
    _read();
  }

  OperationLifecycleSpec? get spec => _spec;

  bool _disposed = false;

  /// Follows the spec the panel was just rebuilt with, and hands a held
  /// reopening character to [call] once the row the reopening brings back is
  /// there.
  ///
  /// For EVERY rebuild, not only when the spec's identity moves: the panel
  /// builds a fresh spec each time, so an identity test would always be true
  /// and say nothing. The character waits for the frame, because the call
  /// field is built by that very rebuild.
  void follow(OperationLifecycleSpec? value, TextEditingController call, FocusNode focus) {
    spec = value;
    if (takePendingCharacter() case final typed?) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) appendReopenCharacter(call, focus, typed);
      });
    }
  }

  /// Holds the character that reopened the operation until the entry row it
  /// brings back can take it.
  ///
  /// The keys typed while that reopening is still on its way join the held
  /// text rather than starting reopenings of their own: a callsign typed at
  /// speed is several keys before the first write lands, and each one
  /// reopening would overwrite the last — `K1ABC` arriving as `C` — and run
  /// the same restart several times over.
  void holdForReopen(String character) {
    final reopening = _pendingCharacter != null && nowMillis() - _pendingSince <= _pendingLifetime.inMilliseconds;
    _pendingCharacter = reopening ? _pendingCharacter! + character : character;
    _pendingSince = nowMillis();
    if (!reopening) _spec?.onReopen?.call();
  }

  /// The held characters, once the row is back — and null otherwise.
  ///
  /// Held ACROSS rebuilds rather than consumed by the first one. Reopening
  /// writes its event rows before it writes the status, and each of those
  /// wakes the operation's stream, so a frame lands with the row still
  /// replaced; a character discarded there is the operator's first keystroke
  /// vanishing. It expires instead, which also covers a reopening that was
  /// refused outright — checked BEFORE the row is asked about, so a
  /// character from a refused reopening never turns up in the call field when
  /// the row comes back for some later reason.
  String? takePendingCharacter() {
    final held = _pendingCharacter;
    if (held == null) return null;
    if (nowMillis() - _pendingSince > _pendingLifetime.inMilliseconds) {
      _pendingCharacter = null;
      return null;
    }
    if (reading != null) return null;
    _pendingCharacter = null;
    return held;
  }

  /// Whether the entry row is locked because the operation is no longer being
  /// logged into.
  ///
  /// Only while composing a NEW contact, and only while nothing has been
  /// composed yet. An existing QSO stays editable and deletable in a completed
  /// operation — locking says "you are not sitting at the radio any more", not
  /// "this log is frozen" — and the composed-values half keeps the quiet
  /// boundary from taking the row away around a call the operator is still
  /// typing, which the panel's own lock would then stop them finishing.
  bool locks({required bool editing, required bool hasComposedValues}) => reading != null && !editing && !hasComposedValues;

  /// The transitions the corner slot offers right now
  /// ([operationLifecycleControls] holds the rule).
  List<OperationLifecycleControl> controls({required bool locked, required bool hasComposedValues, required bool editing}) =>
      operationLifecycleControls(_spec, locked: locked, labelPause: labelPause, hasComposedValues: hasComposedValues, editing: editing);

  void _read() {
    final now = nowMillis();
    reading = _spec?.readingAt(now);
    labelPause = _spec?.pauseLabelledAt(now) ?? false;
  }

  void _refresh() {
    final wasReading = reading;
    final wasLabelling = labelPause;
    _read();
    if (reading != wasReading || labelPause != wasLabelling) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    WallClock.seconds.removeListener(_refresh);
    super.dispose();
  }
}

/// Puts the character that reopened an operation into the callsign field —
/// APPENDING, never replacing.
///
/// The field's controller survives the lock with whatever was in it, so an
/// operator who had `K1AB` typed when an export locked the row and then types
/// `C` means `K1ABC`; assigning would silently drop the four characters they
/// had already entered.
///
/// Upper-cased here because this write goes straight to the controller and so
/// never meets the field's own `UpperCaseTextFormatter` — without it the
/// reopening leaves one stray lowercase character in a field that upper-cases
/// everything typed after it. One assignment, text and cursor together, so the
/// controller's listeners react exactly as they do to typing.
void appendReopenCharacter(TextEditingController controller, FocusNode focus, String typed) {
  final text = controller.text + typed.toUpperCase();
  controller.value = TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: text.length),
  );
  focus.requestFocus();
}

/// What an operation marker's row in the QSO list says of itself: its [name],
/// set apart on the row, within [text], which is the name or a sentence
/// built around it. [standsAlone] when that sentence leaves nothing for the
/// row's stored description to add.
typedef OperationMarkerLabel = ({String name, String text, bool standsAlone});

/// What the log held when a `stop` row closed it: its contacts before the
/// row, and when it opened — its first contact or start marker.
typedef OperationFinishedWith = ({int contacts, int fromMillis});

/// What to call an operation marker on its row in the QSO list, or null for a
/// segment boundary, which its description names better than a word could.
///
/// The lifecycle's markers are named because they read as a timeline the
/// operator scans for where the log stopped and started. A restart says how
/// long the log sat before it — [previousAtMillis] is the row before it,
/// whether the pause that preceded it or, for a log that simply went quiet,
/// its last contact. A finish says what the log came to, from [finished].
///
/// The name is a parameter of each sentence, not its first word: a language
/// that puts it elsewhere keeps it whole, which is what lets the row find it
/// to set it apart.
OperationMarkerLabel? operationMarkerLabel(Qso qso, {int? previousAtMillis, OperationFinishedWith? finished}) {
  final lifecycle = t.operation.lifecycle;
  final at = qso.startAtMillis;
  OperationMarkerLabel named(String name, {String? text, bool standsAlone = false}) => (name: name, text: text ?? name, standsAlone: standsAlone);
  return switch (qso.eventKind) {
    'start' => named(lifecycle.started),
    'pause' => named(lifecycle.paused),
    'restart' => switch ((previousAtMillis, at)) {
      (final int from, final int to) when to > from => named(
        lifecycle.restarted,
        text: lifecycle.restartedAfter(name: lifecycle.restarted, time: fmtTimeBetween(from, to)),
      ),
      _ => named(lifecycle.restarted),
    },
    'stop' || 'end' => switch ((finished, at)) {
      ((:final contacts, :final fromMillis), final int to) when to >= fromMillis => named(
        lifecycle.finished,
        text: lifecycle.finishedWith(
          name: lifecycle.finished,
          qsos: contacts == 1 ? t.loggingControls.info.qsoCountOne : t.loggingControls.info.qsoCountOther(count: formatNumber(contacts)),
          time: fmtTimeBetween(fromMillis, to, seconds: false),
        ),
        standsAlone: true,
      ),
      _ => named(lifecycle.finished),
    },
    _ => null,
  };
}
