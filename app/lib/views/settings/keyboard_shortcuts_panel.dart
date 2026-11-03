// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Settings → Keyboard Shortcuts (`EXP KB`): every command a key can run, the
// keys bound to it, and where two commands share one; an editor that records
// a chord, and the set in use, picked from the sets the set manager keeps
// (docs/design/keyboard-shortcuts.md).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../../services/halo_services.dart';
import '../../services/key_bindings_file.dart';
import '../../services/key_bindings_service.dart';
import '../../services/sets/keyboard_shortcut_set_category.dart';
import '../../services/midi/midi_codec.dart';
import '../../services/midi/midi_service.dart';
import '../command_engine.dart' show commandTextParts;
import '../midi_controller_pane.dart' show midiControlLabel, midiTargetLabel;
import '../../services/midi/midi_targets.dart' show midiTargetById;
import '../sets/set_picker_field.dart';
import 'settings_category.dart';

/// What [id] does, in the operator's language — a command id, or bound
/// command text, which is its own name.
String keyCommandTitle(Translations t, String id) {
  final c = t.keyboardShortcuts.command;
  if (id.startsWith(textCommandPrefix)) return id.substring(textCommandPrefix.length);
  if (id.startsWith('keyer.message')) return c.keyerMessage(n: id.substring('keyer.message'.length));
  return switch (id) {
    'app.commandDialog' => c.commandDialog,
    'app.toggleTheme' => c.toggleTheme,
    'app.toggleLanguage' => c.toggleLanguage,
    'app.fontScaleUp' => c.fontScaleUp,
    'app.fontScaleDown' => c.fontScaleDown,
    'app.fontScaleReset' => c.fontScaleReset,
    'app.densityLooser' => c.densityLooser,
    'app.densityDenser' => c.densityDenser,
    'app.densityAuto' => c.densityAuto,
    'logView.find' => c.find,
    'keyer.keyboardMode' => c.keyboardMode,
    pttCommandId => c.ptt,
    so2rStereoCommandId => c.so2rStereo,
    'logging.wipe' => c.wipe,
    _ => id,
  };
}

/// A MIDI control bound to a command, as its cap reads: `MIDI Note 60 · ch 1`.
String midiCapLabel(BuildContext context, String control) => switch (MidiControl.parse(control)) {
  final parsed? => context.t.keyboardShortcuts.editor.midiCap(control: midiControlLabel(context, parsed)),
  null => control,
};

String _contextLabel(Translations t, KeyCommandContext context) => switch (context) {
  KeyCommandContext.app => t.keyboardShortcuts.contextApp,
  KeyCommandContext.logView => t.keyboardShortcuts.contextLogView,
  KeyCommandContext.operation => t.keyboardShortcuts.contextOperation,
  KeyCommandContext.logging => t.keyboardShortcuts.contextLogging,
};

/// The keys the panel lists as fixed: each with the chords that press it,
/// written as [KeyChord.parse] reads them with `mod` for ⌘ or Ctrl.
/// [labels] stand for a run of keys no single chord names, as `A–Z` does.
List<({List<String> chords, List<String> labels, String Function(Translations t) what})> get _fixedKeys => [
  (chords: const [], labels: const ['A–Z', '0–9', ',', '.', '/', '?'], what: (t) => t.keyboardShortcuts.fixed.callsign),
  (chords: ['Escape'], labels: const [], what: (t) => t.keyboardShortcuts.fixed.escape),
  (chords: ['Enter'], labels: const [], what: (t) => t.keyboardShortcuts.fixed.enter),
  (chords: ['Space'], labels: const [], what: (t) => t.keyboardShortcuts.fixed.space),
  (chords: ['Tab', 'shift+Tab'], labels: const [], what: (t) => t.keyboardShortcuts.fixed.tab),
  (chords: ['Up', 'Down', 'Left', 'Right'], labels: const [], what: (t) => t.keyboardShortcuts.fixed.arrows),
  (
    chords: ['alt+Up', 'alt+Down', 'PageUp', 'PageDown', '${isApplePlatform() ? 'cmd' : 'meta'}+Up', '${isApplePlatform() ? 'cmd' : 'meta'}+Down'],
    labels: const [],
    what: (t) => t.keyboardShortcuts.fixed.walk,
  ),
  (chords: ['mod+Z'], labels: const [], what: (t) => t.keyboardShortcuts.fixed.undo),
];

/// Opens the editor for [id]'s keys, titled [title], and stores what it
/// answers — taking a chord or a MIDI control off any other command it is
/// moved from.
Future<void> editKeyCommand(BuildContext context, HaLoServices services, String id, String title) async {
  final service = services.keyBindingsService;
  final overrides = service.overrides;
  final bindings = overrides.resolve();
  final result = await showHaloDialog<_EditResult>(
    context: context,
    builder: (_) => _ShortcutEditor(
      id: id,
      title: title,
      chords: bindings.chordsFor(id),
      bindings: bindings,
      overrides: overrides,
      // MIDI controls are offered only with MIDI controllers on at all.
      midi: services.settings.experimentEnabled('midi') /* stored key, see experiments.yaml */ ? services.midi : null,
      keysLocked: service.onAppDefaults,
    ),
  );
  if (result == null) return;
  if (result.remove) {
    await service.setOverrides(overrides.withoutText(id.substring(textCommandPrefix.length)));
    return;
  }
  var next = _withChords(overrides, id, result.chords).withMidi(id, result.midi);
  for (final chord in result.take) {
    final current = next.resolve();
    for (final other in current.othersOn(chord, id: id)) {
      next = _withChords(next, other, [
        for (final c in current.chordsFor(other))
          if (!c.samePressAs(chord)) c,
      ]);
    }
  }
  await service.setOverrides(next);
}

KeyBindingOverrides _withChords(KeyBindingOverrides overrides, String id, List<KeyChord> chords) =>
    id.startsWith(textCommandPrefix) ? overrides.withText(id.substring(textCommandPrefix.length), chords) : overrides.withCommand(id, chords);

/// Keyer message [n]'s keys as caps, for the message editors' rows. With
/// Keyboard Shortcuts on they open the editor for those keys: the row is
/// where an operator looks for which key sends the message, so it is where
/// changing it is found.
class KeyerMessageKeys extends StatelessWidget {
  final HaLoServices services;
  final int n;

  const KeyerMessageKeys({super.key, required this.services, required this.n});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<KeyBindings>(
    valueListenable: keyBindings,
    builder: (context, bindings, _) {
      final id = 'keyer.message$n';
      final caps = _KeyCaps(chords: bindings.chordsFor(id));
      final service = services.keyBindingsService;
      if (!service.enabled) return caps;
      return InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () => editKeyCommand(context, services, id, keyCommandTitle(context.t, id)),
        child: Padding(padding: const EdgeInsets.all(Space.xs), child: caps),
      );
    },
  );
}

class KeyboardShortcutsPanel extends StatefulWidget {
  final HaLoServices services;

  const KeyboardShortcutsPanel({super.key, required this.services});

  @override
  State<KeyboardShortcutsPanel> createState() => _KeyboardShortcutsPanelState();
}

class _KeyboardShortcutsPanelState extends State<KeyboardShortcutsPanel> {
  final _search = TextEditingController();

  KeyBindingsService get _service => widget.services.keyBindingsService;

  late final _sets = KeyboardShortcutSetCategory(
    _service,
    translate: (file) => showHaloDialog<KeyBindingOverrides>(
      context: context,
      builder: (_) => _ImportDialog(file: file),
    ),
  );

  @override
  void initState() {
    super.initState();
    var searching = false;
    _search.addListener(() {
      // A new search starts with every matching category open.
      if (_searching != searching) _closedWhileSearching.clear();
      searching = _searching;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _shown(String title, String? detail, List<KeyChord> chords) {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return true;
    return title.toLowerCase().contains(query) ||
        (detail?.toLowerCase().contains(query) ?? false) ||
        chords.any((c) => c.label().toLowerCase().contains(query) || '$c'.toLowerCase().contains(query));
  }

  Future<void> _edit(String id, String title) => editKeyCommand(context, widget.services, id, title);

  Future<void> _addCommand() async {
    final text = await showHaloDialog<String>(
      context: context,
      builder: (_) => _CommandTextDialog(services: widget.services),
    );
    if (text == null || !mounted) return;
    await _edit(textCommandId(text), text);
  }

  Future<void> _resetAll() async {
    final t = context.t.keyboardShortcuts;
    final midi = _service.overrides.midiKeptWith(const {});
    final confirmed = await showHaloDialog<bool>(
      context: context,
      builder: (context) => HaloDialog(
        title: Text(t.resetAllTitle),
        content: Text(midi.isEmpty ? t.resetAllBody : '${t.resetAllBody} ${t.resetAllKeepsMidi}'),
        cancel: TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(context.t.common.cancel)),
        actions: [FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(t.reset))],
      ),
    );
    // The MIDI controls stay: they are the device's, not the set's.
    if (confirmed == true) await _service.setOverrides(KeyBindingOverrides(midi: midi));
  }

  /// The category open while nothing is searched — one at a time, as in
  /// Application Preferences.
  String? _openCategory = 'app';

  /// While a search runs every category with a match is open, save the ones
  /// closed during it.
  final _closedWhileSearching = <String>{};

  bool get _searching => _search.text.trim().isNotEmpty;

  bool _expanded(String key) => _searching ? !_closedWhileSearching.contains(key) : _openCategory == key;

  void _toggle(String key) => setState(() {
    if (_searching) {
      if (!_closedWhileSearching.remove(key)) _closedWhileSearching.add(key);
    } else {
      _openCategory = _openCategory == key ? null : key;
    }
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.services.settings, _service]),
      builder: (context, _) {
        final t = context.t.keyboardShortcuts;
        final theme = Theme.of(context);
        final overrides = _service.overrides;
        final bindings = overrides.resolve();
        final keying = widget.services.settings.experimentEnabled('keyer') /* stored key, see experiments.yaml */;
        final so2r = widget.services.settings.experimentEnabled('so2r') /* stored key, see experiments.yaml */;
        // The search bar isn't a row, so it takes the rows' own content inset
        // explicitly, as Application Preferences' does.
        final rowInset = ListTileTheme.of(context).contentPadding ?? EdgeInsets.zero;
        final searchBorder = OutlineInputBorder(borderRadius: BorderRadius.circular(8));

        Widget? row(String id, String title, {String? detail, bool code = false}) {
          final chords = bindings.chordsFor(id);
          if (!_shown(title, detail, chords)) return null;
          final conflicts = [
            for (final chord in chords)
              // Not with a command the panel does not list: a conflict that
              // cannot be seen cannot be cleared, and with SO2R off its key
              // keys nothing.
              if ([
                    for (final other in bindings.othersOn(chord, id: id))
                      if (so2r || other != so2rStereoCommandId) other,
                  ]
                  case final others when others.isNotEmpty)
                t.conflict(keys: chord.label(), commands: others.map((o) => keyCommandTitle(context.t, o)).join(', ')),
          ];
          final changed = overrides.commands.containsKey(id);
          return ListTile(
            title: Text(title, style: code ? haloMonoStyle(context) : null),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (detail != null || changed) Text([?detail, if (changed) t.changed].join(' · ')),
                for (final conflict in conflicts) Text(conflict, style: TextStyle(color: theme.colorScheme.error)),
              ],
            ),
            trailing: _KeyCaps(chords: chords, labels: [for (final c in overrides.midi[id] ?? const <String>[]) midiCapLabel(context, c)]),
            onTap: () => _edit(id, title),
            mouseCursor: SystemMouseCursors.click,
          );
        }

        /// A collapsible category band over [rows], as Application
        /// Preferences draws its own; gone while a search matches none.
        Widget category(String key, String title, List<Widget?> rows, {Widget? footer}) {
          final shown = [...rows.nonNulls, if (!_searching) ?footer];
          return settingsCategorySliver(
            context,
            title: title,
            expanded: _expanded(key),
            onToggle: () => _toggle(key),
            hidden: shown.isEmpty,
            sliver: SliverList.list(children: shown),
          );
        }

        List<Widget?> specRows(KeyCommandContext where) => [
          for (final spec in keyCommandSpecs)
            if (spec.context == where && (so2r || spec.id != so2rStereoCommandId))
              row(spec.id, keyCommandTitle(context.t, spec.id), detail: _contextLabel(context.t, spec.context)),
        ];

        final textRows = [for (final text in overrides.text.keys) row(textCommandId(text), text, code: true)];

        final mod = isApplePlatform() ? 'cmd' : 'ctrl';
        final fixedRows = [
          for (final fixed in _fixedKeys)
            if ([for (final text in fixed.chords) KeyChord.parse(text.replaceAll('mod', mod))!] case final chords
                when _shown(fixed.what(context.t), null, chords))
              ListTile(
                title: Text(fixed.what(context.t)),
                trailing: _KeyCaps(chords: chords, labels: fixed.labels),
              ),
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: rowInset.add(const EdgeInsets.only(top: Space.xl, bottom: Space.md)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SetPickerField(
                    services: widget.services,
                    category: _sets,
                    label: t.sets.label,
                    value: _sets.activeId,
                    onChanged: (id) => unawaited(_sets.use(id)),
                  ),
                  if (_service.onAppDefaults)
                    Padding(
                      padding: const EdgeInsets.only(top: Space.sm),
                      child: Text(t.sets.appDefaultsLocked, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    ),
                ],
              ),
            ),
            // Application Preferences' search strip: pinned above the scroll,
            // on a lighter wash of the category bands' ground.
            ColoredBox(
              color: Color.lerp(theme.colorScheme.surface, haloDialogBandColorAt(context), 0.5)!,
              child: Padding(
                padding: rowInset.add(const EdgeInsets.symmetric(vertical: Space.xl)),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _search,
                        decoration: InputDecoration(
                          isDense: true,
                          filled: true,
                          fillColor: theme.colorScheme.surface,
                          prefixIcon: const Icon(MdiIcons.magnify, size: 18),
                          suffixIcon: _searching
                              ? IconButton(
                                  icon: Icon(MdiIcons.close, size: 18, semanticLabel: context.t.settings.search.clear),
                                  onPressed: _search.clear,
                                )
                              : null,
                          hintText: t.search,
                          border: searchBorder,
                          focusedBorder: haloFocusedBorder(searchBorder, context),
                        ),
                      ),
                    ),
                    const SizedBox(width: Space.sm),
                    HoverLabel(
                      label: t.resetAll,
                      namesChild: false,
                      child: IconButton(
                        onPressed: _service.onAppDefaults || (overrides.commands.isEmpty && overrides.text.isEmpty) ? null : _resetAll,
                        icon: Icon(MdiIcons.restore, semanticLabel: t.resetAll),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  category('app', t.groupApp, specRows(KeyCommandContext.app)),
                  category('logging', t.groupLogging, [...specRows(KeyCommandContext.logView), ...specRows(KeyCommandContext.logging)]),
                  if (keying) category('keying', t.groupKeying, specRows(KeyCommandContext.operation)),
                  category(
                    'commands',
                    t.groupCommands,
                    textRows,
                    footer: ListTile(
                      leading: const Icon(MdiIcons.plus),
                      title: Text(t.addCommand),
                      enabled: !_service.onAppDefaults,
                      onTap: _addCommand,
                      mouseCursor: SystemMouseCursors.click,
                    ),
                  ),
                  category('fixed', t.groupFixed, fixedRows),
                  const SliverToBoxAdapter(child: SizedBox(height: Space.xl)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A command's keys as caps, or "No key".
class _KeyCaps extends StatelessWidget {
  final List<KeyChord> chords;

  /// Caps for runs of keys no chord names, after [chords].
  final List<String> labels;

  const _KeyCaps({required this.chords, this.labels = const []});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (chords.isEmpty && labels.isEmpty) {
      return Text(context.t.keyboardShortcuts.noKey, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant));
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: Space.xs,
        runSpacing: Space.xs,
        children: [
          for (final chord in chords) _KeyCap(chord: chord),
          for (final label in labels) _KeyCap.text(label),
        ],
      ),
    );
  }
}

class _KeyCap extends StatelessWidget {
  final KeyChord? chord;
  final String? text;

  const _KeyCap({required KeyChord this.chord}) : text = null;

  /// A cap reading [text], for a run of keys rather than one chord.
  const _KeyCap.text(String this.text) : chord = null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = haloMonoStyle(context, fontSize: (theme.textTheme.labelMedium?.fontSize ?? 12) + 1);
    final parts = chord?.labelParts() ?? [(text: text!, icon: null)];
    // Apple's chords run their symbols together; everyone else's join words
    // with a plus.
    final joined = !isApplePlatform();
    return Semantics(
      label: chord?.label() ?? text,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: Space.xxs),
          // Rich text rather than a Row, so a long chord in a narrow slot
          // wraps the way plain text would instead of overflowing.
          child: Text.rich(
            TextSpan(
              style: style,
              children: [
                for (final (i, part) in parts.indexed) ...[
                  if (joined && i > 0) const TextSpan(text: '+'),
                  if (part.icon case final icon?)
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Icon(icon, size: style.fontSize! + 1, color: style.color ?? DefaultTextStyle.of(context).style.color),
                    )
                  else
                    TextSpan(text: part.text),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The command's keys and the chords to take from other commands — or, for
/// command text, [remove] to take the command off the list.
typedef _EditResult = ({List<KeyChord> chords, Set<KeyChord> take, List<String> midi, bool remove});

/// One command's keys: record a new one, remove one, put the defaults back.
/// A chord another command already has is flagged, with the offer to take it
/// from that command.
class _ShortcutEditor extends StatefulWidget {
  final String id;
  final String title;
  final List<KeyChord> chords;

  /// The bindings in force as the editor opened, to find the commands a new
  /// chord would collide with.
  final KeyBindings bindings;

  /// What is stored, for the MIDI controls bound to this command and others.
  final KeyBindingOverrides overrides;

  /// Null where MIDI controllers are off: no MIDI rows, no Add MIDI Control.
  final MidiService? midi;

  /// The keys shown and not changed: App Defaults is in use. Its MIDI
  /// controls still change — they belong to the device, not to a set.
  final bool keysLocked;

  const _ShortcutEditor({
    required this.id,
    required this.title,
    required this.chords,
    required this.bindings,
    required this.overrides,
    this.midi,
    this.keysLocked = false,
  });

  @override
  State<_ShortcutEditor> createState() => _ShortcutEditorState();
}

class _ShortcutEditorState extends State<_ShortcutEditor> {
  late final List<KeyChord> _chords = [...widget.chords];
  final Set<KeyChord> _take = {};
  late final List<String> _midi = [...?widget.overrides.midi[widget.id]];
  final _listenFocus = FocusNode();
  bool _listening = false;
  bool _listeningMidi = false;

  /// Why the last chord pressed was not added, or what to know
  /// about one that was.
  String? _message;
  bool _messageIsError = false;

  @override
  void dispose() {
    keyChordRecording.value = false;
    if (_listeningMidi) widget.midi?.learnShortcut(null);
    _listenFocus.dispose();
    super.dispose();
  }

  void _listenMidi(bool on) {
    final midi = widget.midi;
    if (midi == null) return;
    final t = context.t.keyboardShortcuts.editor;
    if (on && !midi.anyConnected) {
      setState(() {
        _message = t.midiNoController;
        _messageIsError = true;
      });
      return;
    }
    setState(() {
      _listeningMidi = on;
      _message = null;
    });
    midi.learnShortcut(on ? _offerMidi : null);
  }

  /// Adds [control] unless a controller maps it or it is here already.
  void _offerMidi(MidiControl control) {
    if (!mounted) return;
    final t = context.t.keyboardShortcuts.editor;
    final key = '$control';
    String? message;
    var error = true;
    if (widget.midi?.controllerMapping(control) case (:final node, :final targetId)) {
      final target = midiTargetById(targetId);
      final where = target == null ? node.name : '${node.name} · ${midiTargetLabel(context, target)}${target.radio == null ? '' : ' ${target.radio}'}';
      message = t.midiMappedInController(controller: where);
    } else if (_midi.contains(key)) {
      message = t.midiAlready;
    } else {
      _midi.add(key);
      error = false;
      if (widget.overrides.midiCommandFor(key) case final other? when other != widget.id) message = t.midiMoves(command: keyCommandTitle(context.t, other));
    }
    setState(() {
      _listeningMidi = false;
      _message = message;
      _messageIsError = error;
    });
  }

  void _listen(bool on) {
    setState(() => _listening = on);
    keyChordRecording.value = on;
    if (on) _listenFocus.requestFocus();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!_listening) return KeyEventResult.ignored;
    if (event is! KeyDownEvent) return KeyEventResult.handled;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _listen(false);
      return KeyEventResult.handled;
    }
    // A modifier on its own is the start of a chord, not one.
    final chord = KeyChord.fromEvent(event);
    if (chord == null) return KeyEventResult.handled;
    if (_offer(chord, event.character)) _listen(false);
    return KeyEventResult.handled;
  }

  /// Adds [chord] unless it cannot be bound here; says why not, or what to
  /// know about it. True when it was added. [typed] is what the press typed,
  /// which decides whether the call field loses it.
  bool _offer(KeyChord chord, String? typed) {
    final t = context.t.keyboardShortcuts.editor;
    final keys = chord.label();
    final refusal = keyChordRefusal(chord, widget.id, typed: typed);
    String? message;
    var error = true;
    var added = false;
    if (refusal == KeyChordRefusal.fixed) {
      message = t.refusedFixed(keys: keys);
    } else if (refusal == KeyChordRefusal.callsignKey) {
      message = t.refusedCallsign(keys: keys);
    } else if (_chords.any(chord.samePressAs)) {
      message = t.already(keys: keys);
    } else {
      added = true;
      error = false;
      _chords.add(chord);
      if (widget.bindings.othersOn(chord, id: widget.id).isNotEmpty) _take.add(chord);
      if (isReservedKeyChord(chord)) {
        message = t.reserved(keys: keys);
      } else if (takesCallFieldKey(chord, typed)) {
        message = t.callField(keys: keys);
      }
    }
    setState(() {
      _message = message;
      _messageIsError = error;
    });
    return added;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.keyboardShortcuts.editor;
    final theme = Theme.of(context);
    final spec = keyCommandSpec(widget.id);
    // Rows run to the card's edges in a list dialog and inset their own
    // contents; what is not a ListTile takes the same inset from it.
    return HaloDialog(
      title: Text(widget.title),
      wide: true,
      list: true,
      content: Focus(
        focusNode: _listenFocus,
        onKeyEvent: _onKey,
        child: Builder(
          builder: (context) {
            final rowInset = ListTileTheme.of(context).contentPadding ?? EdgeInsets.zero;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_chords.isEmpty)
                  Padding(
                    padding: rowInset.add(const EdgeInsets.symmetric(vertical: Space.md)),
                    child: Text(t.noShortcuts, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ),
                for (final chord in _chords) ...[
                  ListTile(
                    title: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: _KeyCap(chord: chord),
                    ),
                    trailing: widget.keysLocked
                        ? null
                        : IconButton(
                            icon: Icon(MdiIcons.close, semanticLabel: t.remove),
                            onPressed: () => setState(() {
                              _chords.remove(chord);
                              _take.remove(chord);
                            }),
                          ),
                  ),
                  for (final other in widget.bindings.othersOn(chord, id: widget.id))
                    CheckboxListTile(
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _take.contains(chord),
                      onChanged: (take) => setState(() => take == true ? _take.add(chord) : _take.remove(chord)),
                      title: Text(t.takeIt(keys: chord.label(), command: keyCommandTitle(context.t, other))),
                    ),
                ],
                for (final control in _midi)
                  ListTile(
                    title: Align(alignment: AlignmentDirectional.centerStart, child: _KeyCap.text(midiCapLabel(context, control))),
                    trailing: IconButton(
                      icon: Icon(MdiIcons.close, semanticLabel: t.remove),
                      onPressed: () => setState(() => _midi.remove(control)),
                    ),
                  ),
                const SizedBox(height: Space.sm),
                // The add equipment dialog's band: a control sitting on the
                // dialog's width, apart from the rows it adds to.
                ColoredBox(
                  color: Color.lerp(theme.colorScheme.surface, haloDialogBandColorAt(context), 0.5)!,
                  child: Padding(
                    padding: rowInset.add(const EdgeInsets.symmetric(vertical: Space.md)),
                    child: _listening || _listeningMidi
                        ? Container(
                            padding: const EdgeInsets.all(Space.md),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              border: Border.all(color: theme.colorScheme.primary, width: 2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                Text(_listeningMidi ? t.listeningMidi : t.listening, style: theme.textTheme.titleSmall),
                                if (_listeningMidi)
                                  TextButton(onPressed: () => _listenMidi(false), child: Text(context.t.common.cancel))
                                else
                                  Text(t.listeningHint, style: theme.textTheme.bodySmall),
                              ],
                            ),
                          )
                        : Wrap(
                            spacing: Space.md,
                            runSpacing: Space.sm,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (widget.keysLocked)
                                Text(context.t.keyboardShortcuts.sets.appDefaultsLocked, style: theme.textTheme.bodySmall)
                              else
                                OutlinedButton.icon(onPressed: () => _listen(true), icon: const Icon(MdiIcons.keyboard), label: Text(t.addShortcut)),
                              if (widget.midi != null)
                                OutlinedButton.icon(onPressed: () => _listenMidi(true), icon: const Icon(MdiIcons.midi), label: Text(t.addMidi)),
                            ],
                          ),
                  ),
                ),
                if (_message case final message?)
                  Padding(
                    padding: rowInset.add(const EdgeInsets.only(top: Space.sm)),
                    child: Text(
                      message,
                      style: theme.textTheme.bodySmall?.copyWith(color: _messageIsError ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      tools: spec == null || widget.keysLocked
          ? null
          : TextButton(
              onPressed: () => setState(() {
                _chords
                  ..clear()
                  ..addAll(spec.defaultChords());
                _take.clear();
                _message = null;
              }),
              child: Text(t.resetDefault),
            ),
      destructive: widget.id.startsWith(textCommandPrefix)
          ? TextButton(
              onPressed: () => Navigator.of(context).pop<_EditResult>((chords: const [], take: const {}, midi: const [], remove: true)),
              child: Text(t.removeCommand),
            )
          : null,
      cancel: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.t.common.cancel)),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(
            context,
          ).pop<_EditResult>((chords: List.unmodifiable(_chords), take: {..._take.where(_chords.contains)}, midi: List.unmodifiable(_midi), remove: false)),
          child: Text(context.t.common.save),
        ),
      ],
    );
  }
}

/// Asks for the command text a new key will run, and checks that some
/// command reads it before handing it on.
class _CommandTextDialog extends StatefulWidget {
  final HaLoServices services;

  const _CommandTextDialog({required this.services});

  @override
  State<_CommandTextDialog> createState() => _CommandTextDialogState();
}

class _CommandTextDialogState extends State<_CommandTextDialog> {
  final _text = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final parts = commandTextParts(_text.text);
    if (parts.isEmpty) return;
    for (final part in parts) {
      final interpretation = await widget.services.extensions.interpretCommand(part, widget.services.currentOperationContext);
      if (!mounted) return;
      // A command that needs an open operation answers with its error here
      // and still reads the text — which is all a binding needs.
      if (interpretation == null) {
        setState(() => _error = context.t.keyboardShortcuts.editor.commandUnknown(text: part));
        return;
      }
    }
    Navigator.of(context).pop(parts.join('; '));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.keyboardShortcuts.editor;
    return HaloDialog(
      title: Text(context.t.keyboardShortcuts.addCommand),
      content: TextField(
        controller: _text,
        autofocus: true,
        style: haloMonoStyle(context),
        decoration: InputDecoration(labelText: t.commandLabel, helperText: t.commandHint, errorText: _error),
        onChanged: (_) => _error == null ? null : setState(() => _error = null),
        onSubmitted: (_) => _submit(),
      ),
      cancel: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.t.common.cancel)),
      actions: [FilledButton(onPressed: _submit, child: Text(t.add))],
    );
  }
}

/// Asks how a file's `cmd`, `ctrl` and `meta` read on this keyboard;
/// returns the keys the new set holds.
class _ImportDialog extends StatefulWidget {
  final KeyBindingsFile file;

  const _ImportDialog({required this.file});

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  late final Map<KeyModifier, KeyModifier?> _translation = suggestedTranslation(widget.file.overrides.platformModifiers, widget.file.platform);

  ({KeyBindingOverrides overrides, List<KeyChord> refused}) get _translated => widget.file.importable(_translation);

  KeyBindingOverrides get _result => _translated.overrides;

  String _modifierName(Translations t, KeyModifier m) => switch (m) {
    KeyModifier.cmd => t.keyboardShortcuts.modifier.cmd,
    KeyModifier.ctrl => t.keyboardShortcuts.modifier.ctrl,
    KeyModifier.meta => t.keyboardShortcuts.modifier.meta,
    KeyModifier.alt || KeyModifier.shift => m.name,
  };

  String _platformName(Translations t, String platform) => switch (platform) {
    'macos' => t.keyboardShortcuts.platform.macos,
    'ios' => t.keyboardShortcuts.platform.ios,
    'windows' => t.keyboardShortcuts.platform.windows,
    'linux' => t.keyboardShortcuts.platform.linux,
    'android' => t.keyboardShortcuts.platform.android,
    _ => platform,
  };

  @override
  Widget build(BuildContext context) {
    final t = context.t.keyboardShortcuts.file;
    final theme = Theme.of(context);
    final note = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final warning = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error);
    final platform = widget.file.platform;
    final unknown = widget.file.unknownCommands;
    final conflicts = _result.resolve().conflicts;
    final modifiers = [
      for (final m in KeyModifier.values)
        if (_translation.containsKey(m)) m,
    ];
    return HaloDialog(
      title: Text(t.importTitle),
      wide: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(platform == null ? t.writtenOnUnknown : t.writtenOn(platform: _platformName(context.t, platform))),
          if (modifiers.isNotEmpty) ...[
            const SizedBox(height: Space.md),
            Text(t.translate),
            const SizedBox(height: Space.sm),
            for (final m in modifiers)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.xs),
                child: Row(
                  children: [
                    SizedBox(width: 160, child: Text(m.name, style: haloMonoStyle(context))),
                    const Icon(MdiIcons.arrowRight, size: 16),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: DropdownButton<KeyModifier?>(
                        isExpanded: true,
                        value: _translation[m],
                        items: [
                          for (final to in localPlatformModifiers()) DropdownMenuItem(value: to, child: Text(_modifierName(context.t, to))),
                          DropdownMenuItem(child: Text(t.leaveOut)),
                        ],
                        onChanged: (to) => setState(() => _translation[m] = to),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: Space.md),
          if (unknown.isNotEmpty) Text(t.unknown(commands: unknown.join(', ')), style: note),
          if (widget.file.unreadable.isNotEmpty) Text(t.unreadableChords(chords: widget.file.unreadable.join(', ')), style: note),
          if (_translated.refused case final refused when refused.isNotEmpty)
            Text(t.refusedChords(chords: refused.map((c) => c.label()).join(', ')), style: note),
          if (conflicts.isNotEmpty) Text(t.conflicts(keys: conflicts.map((c) => c.chord.label()).join(', ')), style: warning),
        ],
      ),
      cancel: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.t.common.cancel)),
      actions: [FilledButton(onPressed: () => Navigator.of(context).pop(_result), child: Text(t.importAction))],
    );
  }
}
