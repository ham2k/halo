// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The fields that pick among options: the checkbox group, and the multiselect
// with its editor.

part of 'form_renderer.dart';

/// [FormRendererState]'s option-picking fields. The members declared abstract
/// below are the state's own, which every field type shares.
mixin _ChoiceFields on State<FormRenderer> {
  Map<String, dynamic> get _values;
  Map<String, String> get _errors;
  Map<String, FocusNode> get _focusNodes;
  bool get _isSubmitting;
  EdgeInsetsGeometry get _rowContentPadding;
  Color? _devModeColor(Map<String, dynamic> el);
  Future<void> _handleFieldBlurOrInteraction(String key, dynamic value);

  /// A `fieldType: 'checkboxGroup'` field: every option checked or unchecked
  /// inline, in one wrapping row — unlike `multiselect`, there is no summary
  /// row and no dialog, because the vocabulary this is for (a station's own
  /// enabled bands, say) is short enough to show whole. The dialect: `value`
  /// is a plain string list; `options` is `[{label, value}]`. Selection
  /// order always follows the canonical `options` order, same as
  /// `multiselect`.
  Widget _buildCheckboxGroupField(Map<String, dynamic> el, ThemeData theme) {
    final key = el['key'] as String;
    final label = el['label'] as String? ?? '';
    final description = el['description'] as String?;
    final options = (el['options'] is List) ? (el['options'] as List).cast<Map<String, dynamic>>() : const <Map<String, dynamic>>[];
    final errorText = _errors[key];
    final devModeColor = _devModeColor(el);
    final selected = ((_values[key] as List?) ?? const []).toSet();

    void toggle(dynamic value, bool on) {
      final newSelected = {...selected};
      if (on) {
        newSelected.add(value);
      } else {
        newSelected.remove(value);
      }
      // Canonical order, same as multiselect's commit — the selection never
      // depends on the order options happened to be tapped in.
      final newValue = [
        for (final opt in options)
          if (newSelected.contains(opt['value'])) opt['value'],
      ];
      setState(() {
        _values[key] = newValue;
        _errors.remove(key);
      });
      _handleFieldBlurOrInteraction(key, newValue);
    }

    return Focus(
      focusNode: _focusNodes[key],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelMedium?.copyWith(color: devModeColor ?? theme.colorScheme.onSurfaceVariant)),
          if (description != null && description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: Space.xxs),
              child: Text(description, style: theme.textTheme.bodySmall?.copyWith(color: devModeColor)),
            ),
          Wrap(
            children: [
              for (final opt in options)
                // Each option is its own tap target — a Checkbox alone
                // hit-tests only the box, and the label beside it would do
                // nothing when tapped.
                InkWell(
                  onTap: _isSubmitting ? null : () => toggle(opt['value'], !selected.contains(opt['value'])),
                  child: Padding(
                    padding: const EdgeInsets.only(right: Space.sm),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(value: selected.contains(opt['value']), onChanged: _isSubmitting ? null : (val) => toggle(opt['value'], val ?? false)),
                        Text(opt['label'] as String),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          if (errorText != null)
            Padding(
              padding: const EdgeInsets.only(top: Space.xs, left: Space.xs),
              child: Text(errorText, style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  /// A `fieldType: 'multiselect'` field: pick several values from a fixed
  /// vocabulary — a single row summarizing the selection as a
  /// comma-separated list, tapping opens [_openMultiselectEditor]. The
  /// dialect: `value` is a plain string list; `options` is
  /// `[{label, value, common?}]` (or an app-resolved `"$system.list"`
  /// name — an unresolved string renders as no options). Options flagged
  /// `common: true` show upfront; the rest sit behind "Show all". The
  /// selection always keeps the canonical order of `options` (`orderable`
  /// is reserved for a future manual-ordering variant).
  Widget _buildMultiselectField(Map<String, dynamic> el, ThemeData theme) {
    final key = el['key'] as String;
    final label = el['label'] as String? ?? '';
    final description = el['description'] as String?;
    final icon = el['icon'] as String?;
    final errorText = _errors[key];
    final devModeColor = _devModeColor(el);
    final options = (el['options'] is List) ? (el['options'] as List).cast<Map<String, dynamic>>() : const <Map<String, dynamic>>[];
    final selected = ((_values[key] as List?) ?? const []).cast<String>();
    final labelFor = {for (final opt in options) opt['value']: opt['label'] as String?};
    final summary = [for (final v in selected) labelFor[v] ?? v].join(', ');

    Widget? subtitle;
    if (errorText != null) {
      subtitle = Text(errorText, style: TextStyle(color: theme.colorScheme.error, fontSize: 12));
    } else if (summary.isNotEmpty) {
      subtitle = Text(summary, style: TextStyle(color: devModeColor));
    } else if (description != null && description.isNotEmpty) {
      subtitle = Text(description, style: TextStyle(color: devModeColor));
    }

    return ListTile(
      contentPadding: _rowContentPadding,
      leading: icon != null ? Icon(resolveIconName(icon), color: devModeColor) : null,
      title: Text(
        label,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: devModeColor),
      ),
      subtitle: subtitle,
      trailing: Icon(MdiIcons.chevronRight, color: devModeColor ?? theme.colorScheme.onSurfaceVariant),
      onTap: _isSubmitting || options.isEmpty ? null : () => _openMultiselectEditor(el, options),
      mouseCursor: SystemMouseCursors.click,
    );
  }

  /// The multiselect editor dialog: a switch per option, common ones
  /// upfront, the rest behind a disclosure toggle on the action row (two-
  /// or three-tier — see `tierOf` below). Toggles commit immediately in
  /// canonical `options` order; Done just closes.
  Future<void> _openMultiselectEditor(Map<String, dynamic> el, List<Map<String, dynamic>> options) async {
    final key = el['key'] as String;
    final label = el['label'] as String? ?? '';
    final defaultValue = el['defaultValue'] is List ? (el['defaultValue'] as List).toSet() : null;

    // A short, fixed vocabulary (four QSO fields to track, say) reads as
    // sparse and edge-to-edge in the same wide, flush layout that suits
    // Bands or Modes — dozens of options, searched and disclosed in tiers.
    // `compact` opts out of both: the dialog takes only `compactDialogWidth`,
    // and each row keeps its own ListTile inset instead of running flush.
    final compact = el['compact'] == true;

    // Three disclosure tiers: `common: true` options at level 0, unflagged
    // at level 1, `uncommon: true` at level 2. With no uncommon options the
    // toggle is two-state (Show all / Show fewer); with them it cycles
    // Show more → Show all → Show fewer. A vocabulary with no common
    // options at all opens fully expanded with no toggle — collapsing it
    // would leave an empty list.
    int tierOf(Map<String, dynamic> opt) => opt['common'] == true ? 0 : (opt['uncommon'] == true ? 2 : 1);
    final hasCommon = options.any((opt) => tierOf(opt) == 0);
    final hasUncommon = options.any((opt) => tierOf(opt) == 2);
    final hasDisclosure = hasCommon && options.any((opt) => tierOf(opt) > 0);
    var level = hasCommon ? 0 : 2;

    // Vocabularies past browsing size get a search field pinned under the
    // list. While a query is active it matches the ENTIRE vocabulary
    // (ignoring disclosure tiers — that's the point of searching).
    final searchable = options.length > 20;
    final searchController = searchable ? TextEditingController() : null;

    // Uncommon values that earned a place in the common-only view: selected
    // when the dialog opened, or selected at any point while it's open.
    // They stay visible (even deselected, even after "Show fewer") for the
    // dialog's lifetime, so a just-toggled row can't vanish mid-interaction.
    final pinned = ((_values[key] as List?) ?? const []).toSet();

    await showHaloDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final theme = Theme.of(dialogContext);
          final searchBorder = OutlineInputBorder(borderRadius: BorderRadius.circular(8));
          // Values are treated as opaque (FormFieldOption.value is `any` in
          // the SDK) — membership by equality, never a String cast.
          final currentValue = ((_values[key] as List?) ?? const []);
          final selected = currentValue.toSet();

          // Stored values outside the vocabulary (written by another build,
          // or synced from an app with a newer band/mode table) must
          // neither disappear from the editor nor be silently dropped from
          // the committed value — they render as synthesized rows and are
          // preserved until the user explicitly toggles them off.
          final optionValues = {for (final opt in options) opt['value']};
          List<dynamic> unknownIn(Set<dynamic> values) => [
            for (final v in currentValue)
              if (values.contains(v) && !optionValues.contains(v)) v,
          ];

          Future<void> commit(Set<dynamic> newSelected) async {
            // Canonical order: filter the vocabulary, don't append; unknown
            // selected values keep their stored order at the end.
            final newValue = [
              for (final opt in options)
                if (newSelected.contains(opt['value'])) opt['value'],
              ...unknownIn(newSelected),
            ];
            setState(() {
              _values[key] = newValue;
              _errors.remove(key);
            });
            setDialogState(() {});
            await _handleFieldBlurOrInteraction(key, newValue);
          }

          Future<void> toggle(dynamic value, bool on) {
            final newSelected = {...selected};
            if (on) {
              newSelected.add(value);
              pinned.add(value);
            } else {
              newSelected.remove(value);
            }
            return commit(newSelected);
          }

          final query = searchController?.text.trim().toLowerCase() ?? '';
          final filtering = query.isNotEmpty;
          final unknownRows = [
            for (final v in currentValue)
              if (!optionValues.contains(v)) {'label': v.toString(), 'value': v},
          ];
          final visible = [
            ...filtering
                ? [
                    for (final opt in options)
                      if (matchesWordStart((opt['label'] as String?) ?? opt['value'].toString(), query)) opt,
                  ]
                : [
                    for (final opt in options)
                      if (tierOf(opt) <= level || pinned.contains(opt['value'])) opt,
                  ],
            ...filtering ? unknownRows.where((r) => matchesWordStart(r['label'] as String, query)) : unknownRows,
          ];
          return HaloDialog(
            wide: !compact,
            title: Text(label),
            // The shell's own scroll view is off because this content scrolls
            // itself; its inset is HaloDialog's own either way, with the rows
            // dropping their ListTile padding below so the two don't stack.
            scrollable: false,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final opt in visible)
                          SwitchListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            // Selected values read bold, unselected ones
                            // greyed, so the states scan apart without
                            // hunting for the switch thumbs.
                            title: Text(
                              (opt['label'] as String?) ?? opt['value'].toString(),
                              style: selected.contains(opt['value']) ? const TextStyle(fontWeight: FontWeight.bold) : TextStyle(color: theme.disabledColor),
                            ),
                            value: selected.contains(opt['value']),
                            onChanged: _isSubmitting ? null : (on) => toggle(opt['value'], on),
                          ),
                      ],
                    ),
                  ),
                ),
                // The filter status sits between the list and the search
                // field it describes. Both slots carry keys: when the
                // status row pops in/out the field shifts index, and
                // without a key Flutter would remold the field's element
                // into the status row and recreate the field — dropping
                // its focus mid-typing.
                if (filtering)
                  Padding(
                    key: const ValueKey('multiselect-status'),
                    padding: const EdgeInsets.only(top: Space.md),
                    child: Text(
                      t.formChrome.multiselectStatus(shown: visible.length, total: options.length, selected: selected.length),
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                // A view control over the list, not a verb applied to the
                // selection — so it sits with the search field rather than
                // in the footer, whose slots are for what the dialog DOES
                // (docs/design/user-interface.md §Dialogs). Meaningless
                // while a query overrides the tiers, so it goes then.
                if (searchable || (hasDisclosure && !filtering))
                  Padding(
                    key: const ValueKey('multiselect-search'),
                    padding: const EdgeInsets.only(top: Space.md),
                    child: Row(
                      children: [
                        if (searchable)
                          Expanded(
                            child: TextField(
                              selectAllOnFocus: false,
                              controller: searchController,
                              onChanged: (_) => setDialogState(() {}),
                              decoration: InputDecoration(
                                isDense: true,
                                prefixIcon: const Icon(MdiIcons.magnify, size: 18),
                                suffixIcon: !filtering
                                    ? null
                                    : IconButton(
                                        icon: Icon(MdiIcons.close, size: 18, semanticLabel: t.formChrome.clear),
                                        onPressed: () => setDialogState(() => searchController!.clear()),
                                      ),
                                hintText: t.formChrome.search,
                                border: searchBorder,
                                focusedBorder: haloFocusedBorder(searchBorder, dialogContext),
                              ),
                            ),
                          )
                        else
                          const Spacer(),
                        if (hasDisclosure && !filtering)
                          TextButton.icon(
                            onPressed: () => setDialogState(() {
                              level = switch (level) {
                                0 => hasUncommon ? 1 : 2,
                                1 => 2,
                                _ => 0,
                              };
                            }),
                            icon: Icon(level >= 2 ? MdiIcons.unfoldLessHorizontal : MdiIcons.unfoldMoreHorizontal, size: 18),
                            label: Text(switch (level) {
                              0 when hasUncommon => t.formChrome.showMore,
                              0 => t.formChrome.showAll,
                              1 => t.formChrome.showAll,
                              _ => t.formChrome.showFewer,
                            }),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
            // Restoring defaults is something else to DO with the selection,
            // so it takes the `secondary` slot; Done is the way out and takes
            // `cancel`. Neither may be improvised into `actions:` — a Row of
            // buttons handed to one trailing slot also defeats the footer's
            // stacking, which measures its children one by one.
            secondary: defaultValue == null
                ? null
                // Restored defaults pin so uncommon ones stay visible.
                // Deliberately drops any out-of-vocabulary stored values —
                // Defaults means the declared set.
                : _defaultsButton(
                    onPressed: _isSubmitting
                        ? null
                        : () {
                            pinned.addAll(defaultValue);
                            commit({...defaultValue});
                          },
                  ),
            cancel: TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(t.common.done)),
          );
        },
      ),
    );
    searchController?.dispose();
  }
}
