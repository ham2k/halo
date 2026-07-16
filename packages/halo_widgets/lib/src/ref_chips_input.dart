// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// UI catalog component `refList` (DESIGN.md §5): a chip list + entry field
// for activity references. The descriptor from the plugin provides refType,
// placeholder and a validation pattern; decoration (park names…) happens
// through an async callback into the plugin runtime and updates the chip
// when it lands. The widget never blocks on the plugin.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'text_formatters.dart';
import 'theme.dart';

/// Async ref decoration via the plugin runtime. Receives `{type, ref}` and
/// returns an enriched ref map; implementations must not throw.
typedef RefDecorator = Future<Map<String, dynamic>> Function(Map<String, dynamic> ref);

/// One live-reformatting pass from a control descriptor's `input.transforms`
/// (`extensions/sdk/src/types.ts`'s `RefListInputDescriptor.transforms`): a
/// regex `pattern` + a `replacement` using braced `${1}`/`${2}`… group
/// placeholders, applied as the user types — e.g. turning "us1234" into
/// "US-1234" without a runtime round trip per keystroke. Braced, not bare
/// `$1`, because a replacement can concatenate a group directly against a
/// literal that starts with a digit (e.g. a DXCC prefix like "3D2") — bare
/// `$13` would misparse as group 13 instead of group 1 followed by "3".
class RefTransform {
  final String pattern;
  final String replacement;
  final String flags;

  const RefTransform({required this.pattern, required this.replacement, this.flags = ''});

  factory RefTransform.fromMap(Map<String, dynamic> map) => RefTransform(
        pattern: map['pattern'] as String,
        replacement: map['replacement'] as String,
        flags: (map['flags'] as String?) ?? '',
      );
}

/// References are always uppercase, live as the user types — not just at
/// submit time (`_add` already uppercased there) — since `toUpperCase()` is
/// length-preserving for the characters this field allows, the selection
/// from `newValue` carries over unchanged. Shares the package-wide
/// [UpperCaseTextFormatter] (text_formatters.dart).
const _upperCaseFormatter = UpperCaseTextFormatter();

/// Applies an ordered list of [RefTransform]s to text on every edit — the
/// native side of the extension's declarative reformatting contract.
/// Malformed transform sources (an extension bug) are skipped rather than
/// thrown, since this formatter runs on every keystroke.
class _RefTransformFormatter extends TextInputFormatter {
  final List<RefTransform> transforms;

  _RefTransformFormatter(this.transforms);

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    // Distance from the end of the field, before rewriting — the same
    // heuristic app-polo's own live-formatting inputs use ("cursorAware"):
    // an edit's distance from the *end* of the string tends to survive a
    // structural rewrite (dash/prefix insertion) better than its distance
    // from the start, since these transforms mostly touch the ref the user
    // is actively typing (near the cursor) and leave everything after it
    // untouched.
    final rawSelectionEnd = newValue.selection.end < 0 ? newValue.text.length : newValue.selection.end;
    final distanceFromEnd = newValue.text.length - rawSelectionEnd;

    var text = newValue.text;
    // Two passes: a single-character keystroke always converges in one (the
    // common case), but a multi-character paste (e.g. "us1234 us5678") can
    // need a second pass once the first has already inserted a dash/prefix
    // that a later rule in the chain depends on.
    text = _applyOnce(_applyOnce(text));

    final offset = (text.length - distanceFromEnd).clamp(0, text.length);
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: offset));
  }

  String _applyOnce(String text) {
    for (final transform in transforms) {
      RegExp regex;
      try {
        regex = RegExp(transform.pattern, caseSensitive: !transform.flags.contains('i'));
      } catch (_) {
        continue;
      }
      String expand(Match m) => transform.replacement.replaceAllMapped(RegExp(r'\$\{(\d+)\}'), (rm) {
            final index = int.parse(rm.group(1)!);
            return index <= m.groupCount ? (m.group(index) ?? '') : rm.group(0)!;
          });
      if (transform.flags.contains('g')) {
        text = text.replaceAllMapped(regex, expand);
      } else {
        final match = regex.firstMatch(text);
        if (match != null) text = text.replaceRange(match.start, match.end, expand(match));
      }
    }
    return text;
  }
}

class RefChipsInput extends StatefulWidget {
  final String refType;
  final String label;
  final String? placeholder;

  /// Regex source from the control descriptor; input must match to be added.
  final String? pattern;

  /// Live-reformatting passes from the control descriptor; see [RefTransform].
  final List<RefTransform> transforms;
  final List<Map<String, dynamic>> refs;
  final ValueChanged<List<Map<String, dynamic>>> onChanged;
  final RefDecorator? decorate;
  final bool dense;

  /// Passed straight through to poloFieldDecoration — set this when
  /// embedding on a tinted background (e.g. LoggingControls'
  /// tertiaryContainer); left null for the default, plain-background tone
  /// (e.g. the standalone Activities dialog).
  final Color? labelColor;

  const RefChipsInput({
    super.key,
    required this.refType,
    required this.label,
    required this.refs,
    required this.onChanged,
    this.placeholder,
    this.pattern,
    this.transforms = const [],
    this.decorate,
    this.dense = false,
    this.labelColor,
  });

  @override
  State<RefChipsInput> createState() => _RefChipsInputState();
}

class _RefChipsInputState extends State<RefChipsInput> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  String? _error;

  /// For each ref string we've emitted and are awaiting decoration for, the
  /// list a resolved decoration should be merged into. Starts as our own
  /// optimistic `updated` snapshot (setState schedules the parent's rebuild
  /// for the next frame, so a decoration with no real network latency
  /// typically resolves *before* the parent has rebuilt at all — the base
  /// case, not an edge case). `didUpdateWidget` is the authoritative signal
  /// for what happens after a rebuild: if the parent's new `refs` still has
  /// this ref, we switch to building on that (in case something else
  /// changed concurrently); if it doesn't, the ref was removed out from
  /// under us (a wipe, a manual chip delete) and we drop it entirely so a
  /// late decoration can't resurrect it.
  final Map<String, List<Map<String, dynamic>>> _pendingBase = {};

  RegExp? get _regex {
    final pattern = widget.pattern;
    if (pattern == null) return null;
    try {
      return RegExp('^(?:$pattern)\$', caseSensitive: false);
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    // Place the cursor at the end on focus rather than selecting the
    // existing text — matches every other logging field (LoggingControls'
    // call/sent/rcvd/frequency/time fields) and overrides the
    // desktop-platform default of selecting all text when a field gains
    // focus via keyboard (as opposed to a tap).
    _focus.addListener(() {
      if (_focus.hasFocus) {
        _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
      }
    });
  }

  @override
  void didUpdateWidget(RefChipsInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    for (final refString in [..._pendingBase.keys]) {
      if (widget.refs.any((r) => r['ref'] == refString)) {
        _pendingBase[refString] = widget.refs;
      } else {
        _pendingBase.remove(refString);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Splits [text] on commas (the field's live `transforms` are what turn a
  /// typed/pasted space into a comma — see the extension's `transforms`) so
  /// one submission can add several references at once (e.g. a POTA
  /// park-to-park boundary activation) — each becomes its OWN `Ref` entry in
  /// `widget.refs`, one-ref-per-entry, same as a single-reference submission
  /// always has been. The chips row groups same-`refType` entries into one
  /// visual chip (see `build()`), but the underlying data — and therefore
  /// duplicate detection below — stays per individual reference.
  Future<void> _add(String text) async {
    final codes = text.split(',').map((s) => s.trim().toUpperCase()).where((s) => s.isNotEmpty).toList();
    if (codes.isEmpty) return;

    final regex = _regex;
    if (regex != null && codes.any((code) => !regex.hasMatch(code))) {
      setState(() => _error = 'Not a valid ${widget.label} reference');
      return;
    }

    final existing = widget.refs.map((r) => r['ref']).toSet();
    final newCodes = <String>[];
    for (final code in codes) {
      if (existing.contains(code) || newCodes.contains(code)) continue;
      newCodes.add(code);
    }
    if (newCodes.isEmpty) {
      setState(() => _error = 'Already added');
      return;
    }

    final newRefs = [for (final code in newCodes) <String, dynamic>{'type': widget.refType, 'ref': code}];
    final updated = [...widget.refs, ...newRefs];
    _controller.clear();
    setState(() => _error = null);
    for (final ref in newRefs) {
      _pendingBase[ref['ref'] as String] = updated;
    }
    widget.onChanged(updated);

    final decorate = widget.decorate;
    if (decorate == null) return;
    for (final ref in newRefs) {
      unawaited(_decorateOne(ref, decorate));
    }
  }

  Future<void> _decorateOne(Map<String, dynamic> ref, RefDecorator decorate) async {
    final refString = ref['ref'] as String;
    final decorated = await decorate(ref);
    // didUpdateWidget already removed this entry if the parent moved on
    // (wipe, manual removal) while we were awaiting; otherwise it points
    // at the freshest list that still contains our ref.
    final base = _pendingBase.remove(refString);
    if (!mounted || base == null) return;

    final current = [...base];
    final index = current.indexWhere((r) => r['ref'] == refString);
    if (index >= 0) {
      current[index] = decorated;
      widget.onChanged(current);
    }
  }

  /// Clears every reference of this control's type — the one grouped chip
  /// (see `build()`) represents all of them as a unit, so its delete action
  /// removes the whole group rather than one reference at a time.
  void _removeAll() => widget.onChanged(const []);

  /// Types [text] at the cursor, same as an ordinary keystroke — used to
  /// override LoggingControls' panel-wide space-advances-focus shortcut (see
  /// the `CallbackShortcuts` around the field below) so a space can be a
  /// literal separator between multiple references in this field instead.
  /// Runs the same `transforms` an ordinary keystroke would, since directly
  /// assigning `controller.value` bypasses `inputFormatters`.
  void _insertAtCursor(String text) {
    final oldValue = _controller.value;
    final selection = oldValue.selection;
    final start = selection.start < 0 ? oldValue.text.length : selection.start;
    final end = selection.end < 0 ? oldValue.text.length : selection.end;
    var newValue = oldValue.copyWith(
      text: oldValue.text.replaceRange(start, end, text),
      selection: TextSelection.collapsed(offset: start + text.length),
      composing: TextRange.empty,
    );
    newValue = _upperCaseFormatter.formatEditUpdate(oldValue, newValue);
    if (widget.transforms.isNotEmpty) {
      newValue = _RefTransformFormatter(widget.transforms).formatEditUpdate(oldValue, newValue);
    }
    _controller.value = newValue;
    if (_error != null) setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // One chip for the whole group of same-`refType` references
            // (e.g. every POTA park on this QSO), not one per reference —
            // its label is the comma-joined list, and deleting it clears
            // the group as a unit (`_removeAll`). The underlying data is
            // still one `Ref` entry per reference (see `_add`).
            if (widget.refs.isNotEmpty)
              Tooltip(
                message: widget.refs.map((r) => r['name']).whereType<String>().join(' • '),
                child: InputChip(
                  label: Text(
                    widget.refs.map((r) => (r['shortLabel'] as String?) ?? (r['ref'] as String? ?? '?')).join(', '),
                  ),
                  visualDensity: VisualDensity.compact,
                  onDeleted: _removeAll,
                ),
              ),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: widget.dense ? 130 : 180),
              // LoggingControls binds Space, panel-wide, to advance focus to
              // the next field — this nested CallbackShortcuts, being closer
              // to the focused field, is consulted first and overrides that
              // here so Space types as a literal separator between multiple
              // references (e.g. a POTA park-to-park boundary activation)
              // instead.
              child: CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.space): () => _insertAtCursor(' '),
                },
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  // Desktop platforms select-all on focus by default, which
                  // runs after our own focus listener above and overwrites
                  // its cursor-at-end placement.
                  selectAllOnFocus: false,
                  decoration: poloFieldDecoration(
                    context,
                    widget.label,
                    hintText: widget.placeholder,
                    errorText: _error,
                    labelColor: widget.labelColor,
                  ),
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    // Comma and space both work as separators between
                    // multiple references in one field; the extension's
                    // `transforms` below normalize whichever one was used.
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\-, ]')),
                    // References are always uppercase — `textCapitalization`
                    // above only hints the mobile soft keyboard, it doesn't
                    // touch a hardware-keyboard keystroke or a paste, so a
                    // real uppercasing pass is still needed live (not just
                    // at submit time in `_add`) for the field to actually
                    // read as uppercase while typing.
                    _upperCaseFormatter,
                    if (widget.transforms.isNotEmpty) _RefTransformFormatter(widget.transforms),
                  ],
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  onSubmitted: (text) {
                    _add(text);
                    _focus.requestFocus();
                  },
                ),
              ),
            ),
          ],
        ),
        if (widget.refs.isNotEmpty && (widget.refs.last['name'] as String?) != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              widget.refs.map((r) => r['name']).whereType<String>().join(' • '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ),
      ],
    );
  }
}

/// A plain text field for activity references, with no chips and no
/// separate add step — the field's text IS the reference list, comma
/// separated when there's more than one. Used for LoggingControls'
/// secondary-control row, where the full chips-and-lookup `RefChipsInput`
/// (DESIGN.md §5's `refList` component) is more control than the space
/// affords.
class RefTextInput extends StatefulWidget {
  final String refType;
  final String label;
  final String? placeholder;

  /// Regex source from the control descriptor; a comma-separated segment
  /// only becomes a ref once it matches.
  final String? pattern;
  final List<RefTransform> transforms;
  final List<Map<String, dynamic>> refs;
  final ValueChanged<List<Map<String, dynamic>>> onChanged;
  final RefDecorator? decorate;
  final Color? labelColor;

  const RefTextInput({
    super.key,
    required this.refType,
    required this.label,
    required this.refs,
    required this.onChanged,
    this.placeholder,
    this.pattern,
    this.transforms = const [],
    this.decorate,
    this.labelColor,
  });

  @override
  State<RefTextInput> createState() => _RefTextInputState();
}

class _RefTextInputState extends State<RefTextInput> {
  late final _controller = TextEditingController(text: _joined(widget.refs));
  final _focus = FocusNode();

  /// Decorated ref data by code, so a code already resolved this session
  /// (including ones the parent handed us in `widget.refs`) doesn't need a
  /// fresh `decorate()` round trip just because the user edited a sibling
  /// code in the same field.
  final Map<String, Map<String, dynamic>> _decorations = {};

  String _joined(List<Map<String, dynamic>> refs) => refs.map((r) => r['ref'] as String? ?? '').join(', ');

  RegExp? get _regex {
    final pattern = widget.pattern;
    if (pattern == null) return null;
    try {
      return RegExp('^(?:$pattern)\$', caseSensitive: false);
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    for (final ref in widget.refs) {
      final code = ref['ref'] as String?;
      if (code != null) _decorations[code] = ref;
    }
    // Place the cursor at the end on focus rather than selecting the
    // existing text — matches every other logging field.
    _focus.addListener(() {
      if (_focus.hasFocus) {
        _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
      }
    });
  }

  @override
  void didUpdateWidget(RefTextInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only resync the field's text from the parent's refs while it isn't
    // focused — otherwise a decorate() round trip landing mid-keystroke
    // would fight the user's typing.
    if (!_focus.hasFocus && !identical(oldWidget.refs, widget.refs)) {
      _controller.text = _joined(widget.refs);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// The field's whole text is the source of truth: every comma-separated
  /// segment that matches the pattern becomes a ref, in order, on every
  /// keystroke — there's no separate add step to commit to.
  void _emit(String text) {
    final regex = _regex;
    final codes = text.split(',').map((s) => s.trim().toUpperCase()).where((s) => s.isNotEmpty).toList();
    final refs = [
      for (final code in codes)
        if (regex == null || regex.hasMatch(code)) _decorations[code] ?? <String, dynamic>{'type': widget.refType, 'ref': code},
    ];
    widget.onChanged(refs);

    final decorate = widget.decorate;
    if (decorate == null) return;
    for (final code in codes) {
      if (_decorations.containsKey(code)) continue;
      if (regex != null && !regex.hasMatch(code)) continue;
      unawaited(_decorateOne(code, decorate));
    }
  }

  Future<void> _decorateOne(String code, RefDecorator decorate) async {
    final decorated = await decorate({'type': widget.refType, 'ref': code});
    if (!mounted) return;
    _decorations[code] = decorated;
    _emit(_controller.text);
  }

  /// Types [text] at the cursor, same as an ordinary keystroke — used to
  /// override LoggingControls' panel-wide space-advances-focus shortcut so a
  /// space can be a literal separator between multiple references in this
  /// field instead.
  void _insertAtCursor(String text) {
    final oldValue = _controller.value;
    final selection = oldValue.selection;
    final start = selection.start < 0 ? oldValue.text.length : selection.start;
    final end = selection.end < 0 ? oldValue.text.length : selection.end;
    var newValue = oldValue.copyWith(
      text: oldValue.text.replaceRange(start, end, text),
      selection: TextSelection.collapsed(offset: start + text.length),
      composing: TextRange.empty,
    );
    newValue = _upperCaseFormatter.formatEditUpdate(oldValue, newValue);
    if (widget.transforms.isNotEmpty) {
      newValue = _RefTransformFormatter(widget.transforms).formatEditUpdate(oldValue, newValue);
    }
    _controller.value = newValue;
    _emit(newValue.text);
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): () => _insertAtCursor(' '),
      },
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        // Desktop platforms select-all on focus by default, which runs
        // after our own focus listener above and overwrites its
        // cursor-at-end placement.
        selectAllOnFocus: false,
        decoration: poloFieldDecoration(
          context,
          widget.label,
          hintText: widget.placeholder,
          labelColor: widget.labelColor,
        ),
        textCapitalization: TextCapitalization.characters,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\-, ]')),
          _upperCaseFormatter,
          if (widget.transforms.isNotEmpty) _RefTransformFormatter(widget.transforms),
        ],
        onChanged: _emit,
      ),
    );
  }
}
