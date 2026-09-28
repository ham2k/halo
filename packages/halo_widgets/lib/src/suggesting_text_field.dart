// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A form `text` field carrying `suggestions` (docs/extensions/forms.md): the
// codes it takes, offered under the field as the operator types, and what each
// one typed stands for named beside it — flagged for a value it does not know.
// The same matching and multi-value rules as a `kind: 'options'` logging
// control (option_matching.dart), so a QSO party's county line reads the same
// in setup as it does in the entry row.
//
// Unknown values are flagged, never refused: Save writes what was typed.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'option_matching.dart';
import 'ref_text_input.dart';
import 'spacing.dart';

typedef _Suggestion = ({ExchangeOption option, String text, int cursor});

/// The field, for [FormRenderer]: it owns [controller] and [focusNode], which
/// outlive this widget, and builds the [decoration].
class SuggestingTextField extends StatelessWidget {
  const SuggestingTextField({
    super.key,
    required this.field,
    required this.controller,
    required this.focusNode,
    required this.decoration,
    required this.onSubmit,
    this.enabled = true,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
  });

  /// The form element: `suggestions`, and `multiValue` when it holds a list.
  final Map<String, dynamic> field;
  final TextEditingController controller;
  final FocusNode focusNode;
  final InputDecoration decoration;

  /// Submits the whole form.
  final VoidCallback onSubmit;
  final bool enabled;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    final raw = field['suggestions'] is List ? field['suggestions'] as List : const <Object?>[];
    final options = [
      for (final item in raw)
        if (item is Map) ?ExchangeOption.fromMap(item.cast<String, dynamic>()),
    ];
    final standalone = {
      for (final item in raw)
        if (item is Map && item['standalone'] == true && item['code'] is String) (item['code'] as String).toUpperCase(),
    };
    final multiValue = field['multiValue'] is Map ? (field['multiValue'] as Map).cast<String, dynamic>() : const <String, dynamic>{};
    final separator = multiValue['separator'] is String ? multiValue['separator'] as String : '';
    final inheritPrefix = multiValue['inheritPrefix'] is int ? multiValue['inheritPrefix'] as int : 0;
    // After the caller's own formatters (uppercase), as on a logging control:
    // a QSO party's `ALB,SCH` becomes `ALB/SCH` as it is typed.
    final transforms = [
      for (final item in field['transforms'] is List ? field['transforms'] as List : const <Object?>[])
        if (item is Map && item['pattern'] is String && item['replacement'] is String) RefTransform.fromMap(item.cast<String, dynamic>()),
    ];

    // Each suggestion carries the whole field as it would read with it
    // accepted, because that is what RawAutocomplete writes back — so
    // accepting the second county of a line keeps the first.
    Iterable<_Suggestion> suggestionsFor(TextEditingValue value) {
      final cursor = value.selection.isValid ? value.selection.baseOffset : value.text.length;
      final typed = exchangeValueAt(value.text, cursor, separator).trim();
      if (typed.isEmpty) return const [];
      final values = splitExchangeValues(value.text, separator);
      final candidate = values.length > 1 && values.last == typed ? inheritedCandidate(values.first, typed, inheritPrefix) : null;
      // Once there is a list, a code that may only stand alone is no answer.
      final inList = separator.isNotEmpty && value.text.contains(separator);
      final matches = matchExchangeOptionsInheriting(
        typed,
        candidate,
        inList
            ? [
                for (final option in options)
                  if (!standalone.contains(option.code.toUpperCase())) option,
              ]
            : options,
      );
      // Nothing to offer once the only match is what is already typed; an
      // exact `SC` still lists `SCH` and `SCO` behind it.
      final only = matches.length == 1 ? matches.single.code.toUpperCase() : null;
      if (only != null && (only == typed.toUpperCase() || only == candidate?.toUpperCase())) return const [];
      return [
        for (final option in matches)
          if (replaceExchangeValueAt(value.text, cursor, separator, option.code) case final replaced)
            (option: option, text: replaced.text, cursor: replaced.cursor),
      ];
    }

    return RawAutocomplete<_Suggestion>(
      textEditingController: controller,
      focusNode: focusNode,
      optionsBuilder: suggestionsFor,
      displayStringForOption: (suggestion) => suggestion.text,
      onSelected: (suggestion) => controller.selection = TextSelection.collapsed(offset: suggestion.cursor),
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) => ListenableBuilder(
        listenable: Listenable.merge([controller, focusNode]),
        builder: (context, _) => Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                selectAllOnFocus: false,
                enabled: enabled,
                controller: controller,
                focusNode: focusNode,
                maxLines: 1,
                keyboardType: keyboardType,
                textCapitalization: textCapitalization,
                inputFormatters: [...?inputFormatters, if (transforms.isNotEmpty) RefTransformFormatter(transforms)],
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.done,
                // Keeps the focus through Enter: the default unfocuses BEFORE
                // `onSubmitted` runs, which hides the list the Enter was meant
                // to pick from, and leaves a county line's operator clicking
                // back in to type the separator.
                onEditingComplete: () {},
                // Enter takes the highlighted suggestion, and saves when that
                // changes nothing — a code already complete, like `SC` with
                // `SCH` and `SCO` still listed behind it, or no list at all.
                onSubmitted: (_) {
                  final before = controller.value;
                  onFieldSubmitted();
                  if (controller.value == before) onSubmit();
                },
                decoration: decoration,
              ),
            ),
            const SizedBox(width: Space.lg),
            Expanded(
              flex: 3,
              child: _SuggestionNames(
                controller: controller,
                focusNode: focusNode,
                options: options,
                standalone: standalone,
                separator: separator,
                inheritPrefix: inheritPrefix,
              ),
            ),
          ],
        ),
      ),
      optionsViewBuilder: (context, onSelected, suggestions) => Align(
        alignment: AlignmentDirectional.topStart,
        child: Material(
          elevation: 4,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: suggestions.length,
              itemBuilder: (context, index) {
                final suggestion = suggestions.elementAt(index);
                final highlighted = AutocompleteHighlightedOption.of(context) == index;
                // Painted as a DropdownButton paints its selected item, text
                // colour untouched.
                return ListTile(
                  dense: true,
                  tileColor: highlighted ? Theme.of(context).focusColor : null,
                  title: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: suggestion.option.code,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (suggestion.option.name != null) TextSpan(text: '  ${suggestion.option.name}'),
                      ],
                    ),
                  ),
                  onTap: () => onSelected(suggestion),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// What each value in a `suggestions` field stands for, joined as the values
/// are. A value that is none of the codes — or a [standalone] one inside a
/// list — shows as typed with a question mark, in the error colour.
///
/// The value still being typed is held back until the operator pauses for
/// [settleDelay] or leaves the field: without the pause every half-typed code
/// would flash red on each keystroke before it is finished.
class _SuggestionNames extends StatefulWidget {
  const _SuggestionNames({
    required this.controller,
    required this.focusNode,
    required this.options,
    required this.standalone,
    required this.separator,
    required this.inheritPrefix,
  });

  static const settleDelay = Duration(seconds: 1);

  final TextEditingController controller;
  final FocusNode focusNode;
  final List<ExchangeOption> options;

  /// Upper-cased codes valid only as the whole value, never in a list.
  final Set<String> standalone;
  final String separator;
  final int inheritPrefix;

  @override
  State<_SuggestionNames> createState() => _SuggestionNamesState();
}

class _SuggestionNamesState extends State<_SuggestionNames> {
  Timer? _settle;
  bool _settled = true;
  String _lastText = '';

  @override
  void initState() {
    super.initState();
    _lastText = widget.controller.text;
    widget.controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(_SuggestionNames oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    _settle?.cancel();
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  // Text changes only: the controller also notifies on a cursor move, which
  // is not typing and must not hide a flag already shown.
  void _onChanged() {
    if (widget.controller.text == _lastText) return;
    _lastText = widget.controller.text;
    _settle?.cancel();
    if (_settled) setState(() => _settled = false);
    _settle = Timer(_SuggestionNames.settleDelay, () {
      if (mounted) setState(() => _settled = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = widget.controller;
    final byCode = {for (final option in widget.options) option.code.toUpperCase(): option};
    final typing = widget.focusNode.hasFocus && !_settled ? exchangeValueAt(controller.text, controller.selection.baseOffset, widget.separator).trim() : '';
    final values = exchangeValueCandidates(controller.text, widget.separator, inheritPrefix: widget.inheritPrefix);
    final spans = <TextSpan>[];
    for (final (value, candidate) in values) {
      var option = byCode[value.toUpperCase()] ?? (candidate == null ? null : byCode[candidate.toUpperCase()]);
      if (option != null && values.length > 1 && widget.standalone.contains(option.code.toUpperCase())) option = null;
      if (option == null && value == typing) continue;
      if (spans.isNotEmpty) spans.add(TextSpan(text: ' ${widget.separator} '));
      spans.add(
        option == null
            ? TextSpan(
                text: '$value?',
                style: TextStyle(color: theme.colorScheme.error),
              )
            : TextSpan(text: option.name ?? option.code),
      );
    }
    return Text.rich(TextSpan(children: spans), style: theme.textTheme.bodyLarge);
  }
}
