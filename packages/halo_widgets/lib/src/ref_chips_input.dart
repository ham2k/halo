// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// UI catalog component `refList` (DESIGN.md §5): a chip list + entry field
// for activity references. The descriptor from the plugin provides refType,
// placeholder and a validation pattern; decoration (park names…) happens
// through an async callback into the plugin runtime and updates the chip
// when it lands. The widget never blocks on the plugin.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

/// Async ref decoration via the plugin runtime. Receives `{type, ref}` and
/// returns an enriched ref map; implementations must not throw.
typedef RefDecorator = Future<Map<String, dynamic>> Function(Map<String, dynamic> ref);

class RefChipsInput extends StatefulWidget {
  final String refType;
  final String label;
  final String? placeholder;

  /// Regex source from the control descriptor; input must match to be added.
  final String? pattern;
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

  Future<void> _add(String text) async {
    final refString = text.trim().toUpperCase();
    if (refString.isEmpty) return;

    final regex = _regex;
    if (regex != null && !regex.hasMatch(refString)) {
      setState(() => _error = 'Not a valid ${widget.label} reference');
      return;
    }
    if (widget.refs.any((r) => r['ref'] == refString)) {
      setState(() => _error = 'Already added');
      return;
    }

    final ref = <String, dynamic>{'type': widget.refType, 'ref': refString};
    final updated = [...widget.refs, ref];
    _controller.clear();
    setState(() => _error = null);
    _pendingBase[refString] = updated;
    widget.onChanged(updated);

    final decorate = widget.decorate;
    if (decorate != null) {
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
  }

  void _remove(Map<String, dynamic> ref) {
    widget.onChanged([...widget.refs]..removeWhere((r) => r['ref'] == ref['ref']));
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
            for (final ref in widget.refs)
              Tooltip(
                message: (ref['name'] as String?) ?? '',
                child: InputChip(
                  label: Text((ref['shortLabel'] as String?) ?? (ref['ref'] as String? ?? '?')),
                  visualDensity: VisualDensity.compact,
                  onDeleted: () => _remove(ref),
                ),
              ),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: widget.dense ? 130 : 180),
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                decoration: poloFieldDecoration(
                  context,
                  widget.label,
                  hintText: widget.placeholder,
                  errorText: _error,
                  labelColor: widget.labelColor,
                ),
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\-]'))],
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                onSubmitted: (text) {
                  _add(text);
                  _focus.requestFocus();
                },
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
