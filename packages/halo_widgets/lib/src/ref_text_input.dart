// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// UI catalog component `refList` (DESIGN.md §5): a text entry field for
// activity references. The descriptor from the plugin provides refType,
// placeholder and a validation pattern; decoration (park names…) happens
// through an async callback into the plugin runtime and updates the field's
// caption when it lands. The widget never blocks on the plugin.

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
/// Compiles a descriptor's `pattern` the way every control kind must: anchored
/// to the whole value, case-insensitive (logging input is uppercased anyway),
/// and returning null rather than throwing on a malformed regex — an extension
/// typo should disable validation, not crash the logging panel.
///
/// Shared so `refList` and `text` can't drift apart: the same pattern string
/// has to mean the same thing whichever kind an extension puts it on.
RegExp? compileRefPattern(String? pattern) {
  if (pattern == null) return null;
  try {
    return RegExp('^(?:$pattern)\$', caseSensitive: false);
  } catch (e) {
    // Null disables validation for this control — every consumer reads it as
    // "nothing to check", so the field never marks and neither does the
    // activity row. That is the right answer for the operator and the wrong one
    // to keep to ourselves: silently, permanently, no reference of that program
    // is ever checked again. Once per distinct pattern, since this compiles on
    // every keystroke and every row of every build.
    if (_reportedBadPatterns.add(pattern)) {
      debugPrint('[extensions] unusable reference pattern, validation disabled: $pattern ($e)');
    }
    return null;
  }
}

/// Patterns already named by [compileRefPattern], so a broken one is reported
/// once rather than per keystroke.
final Set<String> _reportedBadPatterns = {};

/// Whether any of [refs] carries a code [pattern] rejects.
///
/// The one question the reference field, the activity chip that summarizes it
/// and the Activities view's rows all ask — kept here, beside
/// [compileRefPattern], so the three can never answer it differently about the
/// same reference. An absent or unusable pattern has nothing to reject.
bool anyRefFailsPattern(Iterable<Map<String, dynamic>> refs, String? pattern) {
  final regex = compileRefPattern(pattern);
  if (regex == null) return false;
  return refs.any((ref) {
    final code = (ref['ref'] as String?)?.trim() ?? '';
    return code.isNotEmpty && !regex.hasMatch(code);
  });
}

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

/// References are always uppercase, live as the user types — since
/// `toUpperCase()` is length-preserving for the characters this field
/// allows, the selection from `newValue` carries over unchanged. Shares the
/// package-wide [UpperCaseTextFormatter] (text_formatters.dart).
const _upperCaseFormatter = UpperCaseTextFormatter();

/// Builds the [TextEditingValue] that typing [text] at the cursor of
/// [oldValue] would produce — the selection replaced, the cursor collapsed
/// after the inserted text — then runs the same uppercase + [transforms]
/// formatters an ordinary keystroke would, since directly assigning
/// `controller.value` bypasses `inputFormatters`.
TextEditingValue _typedAtCursor(TextEditingValue oldValue, String text, List<RefTransform> transforms) {
  final selection = oldValue.selection;
  final start = selection.start < 0 ? oldValue.text.length : selection.start;
  final end = selection.end < 0 ? oldValue.text.length : selection.end;
  var newValue = oldValue.copyWith(
    text: oldValue.text.replaceRange(start, end, text),
    selection: TextSelection.collapsed(offset: start + text.length),
    composing: TextRange.empty,
  );
  newValue = _upperCaseFormatter.formatEditUpdate(oldValue, newValue);
  if (transforms.isNotEmpty) {
    newValue = RefTransformFormatter(transforms).formatEditUpdate(oldValue, newValue);
  }
  return newValue;
}

/// Applies an ordered list of [RefTransform]s to text on every edit — the
/// native side of the extension's declarative reformatting contract.
/// Malformed transform sources (an extension bug) are skipped rather than
/// thrown, since this formatter runs on every keystroke.
class RefTransformFormatter extends TextInputFormatter {
  final List<RefTransform> transforms;

  RefTransformFormatter(this.transforms);

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

/// A plain text field for activity references, with no chips and no
/// separate add step — the field's text IS the reference list, comma
/// separated when there's more than one. Used for LoggingControls'
/// secondary-control row (DESIGN.md §5's `refList` component).
class RefTextInput extends StatefulWidget {
  final String refType;
  final String label;
  final String? placeholder;

  /// Regex source from the control descriptor. Every comma-separated segment
  /// becomes a ref whether or not it matches; the pattern only decides whether
  /// the field marks itself (see [_emit]).
  final String? pattern;
  final List<RefTransform> transforms;
  final List<Map<String, dynamic>> refs;
  final ValueChanged<List<Map<String, dynamic>>> onChanged;
  final RefDecorator? decorate;
  final Color? labelColor;

  /// A caller-owned focus node, for a caller that needs to move focus HERE
  /// on its own schedule — the secondary control row focuses this field when
  /// its chip is tapped. Left null, the field owns (and disposes) its own;
  /// a supplied one belongs to the caller and outlives this widget, so it is
  /// deliberately not disposed here.
  final FocusNode? focusNode;

  /// A caller-owned text controller, for a caller that needs to read the
  /// caret position — the panel's cursor-key field-hopping checks whether
  /// it sits at an edge before crossing to a neighbouring control. Same
  /// ownership rule as [focusNode]: left null, the field owns (and disposes)
  /// its own.
  final TextEditingController? controller;

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
    this.focusNode,
    this.controller,
  });

  @override
  State<RefTextInput> createState() => _RefTextInputState();
}

class _RefTextInputState extends State<RefTextInput> {
  /// Only set when no [RefTextInput.controller] was supplied — the field's
  /// own controller, and the only one it may dispose.
  TextEditingController? _ownController;

  TextEditingController get _controller =>
      widget.controller ?? (_ownController ??= TextEditingController(text: _joined(widget.refs)));

  /// Only set when no [RefTextInput.focusNode] was supplied — the field's own
  /// node, and the only one it may dispose.
  FocusNode? _ownFocus;

  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  /// Decorated ref data by code, so a code already resolved this session
  /// (including ones the parent handed us in `widget.refs`) doesn't need a
  /// fresh `decorate()` round trip just because the user edited a sibling
  /// code in the same field.
  final Map<String, Map<String, dynamic>> _decorations = {};

  String _joined(List<Map<String, dynamic>> refs) => refs.map((r) => r['ref'] as String? ?? '').join(', ');

  RegExp? get _regex => compileRefPattern(widget.pattern);

  /// Whether any segment currently in the field fails [RefTextInput.pattern],
  /// which the field reports by tinting its underline. Kept in state rather
  /// than read off the controller during build: nothing guarantees the parent
  /// rebuilds this widget on every keystroke, so the tint has to ask for its
  /// own frame.
  bool _hasInvalid = false;

  /// The comma-separated segments of [text], trimmed and uppercased — what
  /// both the emitted refs and the validity check are built from, so they can
  /// never disagree about where one reference ends and the next begins.
  List<String> _codesIn(String text) =>
      text.split(',').map((s) => s.trim().toUpperCase()).where((s) => s.isNotEmpty).toList();

  bool _anyInvalid(List<String> codes) {
    final regex = _regex;
    return regex != null && codes.any((code) => !regex.hasMatch(code));
  }

  @override
  void initState() {
    super.initState();
    for (final ref in widget.refs) {
      final code = ref['ref'] as String?;
      if (code != null) _decorations[code] = ref;
    }
    // A caller-supplied controller (unlike the lazily-created own one) isn't
    // constructed with the refs' text baked in, so seed it here — the same
    // text `didUpdateWidget` below keeps it in sync with afterwards.
    if (widget.controller != null && widget.controller!.text != _joined(widget.refs)) {
      widget.controller!.text = _joined(widget.refs);
    }
    // A ref that came in already invalid — a QSO opened for editing, or one an
    // ADIF import kept the raw text of — wears the tint from the first frame,
    // without waiting for a keystroke to recompute it.
    _hasInvalid = _anyInvalid(_codesIn(_controller.text));
    _focus.addListener(_onFocusChange);
  }

  /// Places the cursor at the end on focus rather than selecting the existing
  /// text — matches every other logging field.
  void _onFocusChange() {
    if (_focus.hasFocus) {
      _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
    }
  }

  @override
  void didUpdateWidget(RefTextInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The node can change under a REUSED State: the expanded panel is one
    // widget position, so switching from one activity control's chip to
    // another's rebuilds this widget with a different caller-owned node
    // instead of building a fresh State. Left unhandled, the listener would
    // stay on the old node — which outlives this widget in the caller's map —
    // and fire against a controller this State later disposes.
    if (widget.focusNode != oldWidget.focusNode) {
      (oldWidget.focusNode ?? _ownFocus)?.removeListener(_onFocusChange);
      _focus.addListener(_onFocusChange);
    }
    // Only resync the field's text from the parent's refs while it isn't
    // focused — otherwise a decorate() round trip landing mid-keystroke
    // would fight the user's typing.
    if (!_focus.hasFocus && !identical(oldWidget.refs, widget.refs)) {
      _controller.text = _joined(widget.refs);
    }
    // Both inputs to the tint can change without a keystroke: the text just
    // above, and the pattern itself when the expanded panel is reused for a
    // different activity's control (see the focus node above).
    // A plain assignment, not a setState: the build that follows this callback
    // is the one that will paint it.
    _hasInvalid = _anyInvalid(_codesIn(_controller.text));
  }

  @override
  void dispose() {
    // A caller-supplied controller outlives this widget, same as a
    // caller-supplied focus node — only what we own gets disposed here.
    _ownController?.dispose();
    _focus.removeListener(_onFocusChange);
    _ownFocus?.dispose();
    super.dispose();
  }

  /// The field's whole text is the source of truth: every comma-separated
  /// segment becomes a ref, in order, on every keystroke — there's no separate
  /// add step to commit to.
  ///
  /// A segment that fails the pattern is kept, not dropped. The operator typed
  /// it, and a program's pattern is this app's idea of the program rather than
  /// the program's own — a reference format that changed, or one HaLo simply
  /// has wrong, must not cost the operator the code they were given. The field
  /// says so with [haloInvalidInputBorder]; the ref reaches the QSO, the log
  /// and the exports either way.
  void _emit(String text) {
    final regex = _regex;
    final codes = _codesIn(text);
    final refs = [
      for (final code in codes) _decorations[code] ?? <String, dynamic>{'type': widget.refType, 'ref': code},
    ];
    widget.onChanged(refs);

    final hasInvalid = _anyInvalid(codes);
    if (hasInvalid != _hasInvalid) setState(() => _hasInvalid = hasInvalid);

    final decorate = widget.decorate;
    if (decorate == null) return;
    for (final code in codes) {
      if (_decorations.containsKey(code)) continue;
      // A code that cannot be a reference of this type has nothing to look up:
      // the round trip would answer "unknown" at best, once per keystroke.
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
    final newValue = _typedAtCursor(_controller.value, text, widget.transforms);
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
        ).copyWith(
          enabledBorder: _hasInvalid ? haloInvalidInputBorder(context, width: 1) : null,
          focusedBorder: _hasInvalid ? haloInvalidInputBorder(context, width: 2) : null,
        ),
        textCapitalization: TextCapitalization.characters,
        // References (e.g. "US-1234") are codes, not prose: no autocorrect /
        // suggestions / spell-check / smart punctuation (which would turn
        // the "-" into an en-dash). autocorrect:false also disables iOS
        // spell check.
        autocorrect: false,
        enableSuggestions: false,
        smartDashesType: SmartDashesType.disabled,
        smartQuotesType: SmartQuotesType.disabled,
        inputFormatters: [
          // The slash is a reference character, not punctuation: SOTA's
          // `W6/SD-026`, and GMA's, ZLOTA's and WWBOTA's codes, are built from
          // it. Filtering it out does not merely make those awkward to type —
          // since a segment is kept whether or not it matches the pattern, a
          // stripped slash is stored and exported as the operator's own code.
          // SOTA gets away without it only because its `transforms` put the
          // slash back; the fourteen programs built on `referenceActivity`
          // declare no transforms at all.
          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\-/, ]')),
          _upperCaseFormatter,
          if (widget.transforms.isNotEmpty) RefTransformFormatter(widget.transforms),
        ],
        onChanged: _emit,
      ),
    );
  }
}
