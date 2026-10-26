// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A field rendered as a settings row: the label with its control at the row's
// end, the `select` row's picker dialog, and a checkbox row's toggle.

part of 'form_renderer.dart';

/// [FormRendererState]'s row-shaped fields. The members declared abstract
/// below are the state's own, which every field type shares, or another
/// part's.
mixin _RowFields on State<FormRenderer> {
  Map<String, dynamic> get _values;
  Map<String, String> get _errors;
  bool get _isSubmitting;
  EdgeInsetsGeometry get _rowContentPadding;
  Color? _devModeColor(Map<String, dynamic> el);
  Future<void> _handleFieldBlurOrInteraction(String key, dynamic value);
  Widget _buildTextRow(Map<String, dynamic> el, String fieldType, ThemeData theme);

  /// The settings-panel row shape: an optional leading icon, bold title, an
  /// optional description underneath (or the validation error, in its
  /// place). The
  /// trailing/stacked control depends on the field type:
  ///  - a toggle (checkbox) keeps its Switch trailing on the right, and the
  ///    whole row works it;
  ///  - a `select` becomes a tap-to-open picker dialog; the row shows the
  ///    field's description (written to explain the current value — see the
  ///    settings definitions), not the raw value on its own (see
  ///    [_buildSelectRow]);
  ///  - every other (text-like) field becomes a tap-to-open editor dialog
  ///    showing its current value (see [_buildTextRow]).
  Widget _buildSettingsRowField(Map<String, dynamic> el, String fieldType, ThemeData theme) {
    if (fieldType == 'select') {
      return _buildSelectRow(el, theme);
    }
    if (fieldType != 'checkbox') {
      return _buildTextRow(el, fieldType, theme);
    }

    final key = el['key'] as String;
    final label = el['label'] as String? ?? '';
    final description = el['description'] as String?;
    final icon = el['icon'] as String?;
    final errorText = _errors[key];
    final devModeColor = _devModeColor(el);

    Widget? subtitle;
    if (errorText != null) {
      subtitle = Text(errorText, style: TextStyle(color: theme.colorScheme.error, fontSize: 12));
    } else if (description != null && description.isNotEmpty) {
      subtitle = Text(description, style: TextStyle(color: devModeColor));
    }

    final leading = icon != null ? Icon(resolveIconName(icon), color: devModeColor) : null;
    final title = Text(
      label,
      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: devModeColor),
    );

    final disabled = el['disabled'] == true;
    final toggle = _isSubmitting || disabled ? null : () => _setToggle(key, _values[key] != true);

    return ListTile(
      contentPadding: _rowContentPadding,
      leading: leading,
      title: title,
      subtitle: subtitle,
      trailing: Switch(value: _values[key] == true, onChanged: toggle == null ? null : (val) => _setToggle(key, val)),
      // The whole row works the switch, not just the switch itself: a
      // settings row IS its setting, and a title and description that look
      // like the rest of the list but do nothing read as a broken row.
      enabled: toggle != null,
      onTap: toggle,
      mouseCursor: toggle == null ? null : SystemMouseCursors.click,
    );
  }

  /// A `fieldType: 'select'` icon-row field: a tappable row showing the
  /// field's own description as the subtitle (that description is written to
  /// explain the current value — see the settings definitions), with the
  /// options picked in a dialog ([_openSelectDialog]) rather than an inline
  /// dropdown. The raw value is not shown on its own line.
  Widget _buildSelectRow(Map<String, dynamic> el, ThemeData theme) {
    final key = el['key'] as String;
    final label = el['label'] as String? ?? '';
    final desc = el['description'] as String? ?? '';
    final icon = el['icon'] as String?;
    final errorText = _errors[key];
    final devModeColor = _devModeColor(el);

    // The row shows the setting's own description, which is written to
    // explain the current value (see the settings definitions); the raw
    // value is not repeated as a separate line.
    Widget? subtitle;
    if (errorText != null) {
      subtitle = Text(errorText, style: TextStyle(color: theme.colorScheme.error, fontSize: 12));
    } else if (desc.isNotEmpty) {
      subtitle = Text(desc, style: TextStyle(color: devModeColor));
    } else {
      // A field whose value IS its own explanation — a time zone, a callsign
      // — has no description to write, and a row with neither says nothing
      // at all: the operator has to open the dialog to find out what they
      // picked last time.
      final options = (el['options'] is List) ? (el['options'] as List).cast<Map<String, dynamic>>() : const <Map<String, dynamic>>[];
      final current = options.where((o) => o['value'] == _values[key]).firstOrNull;
      final shown = current?['label'] as String? ?? el['placeholder'] as String?;
      if (shown != null && shown.isNotEmpty) subtitle = Text(shown, style: TextStyle(color: devModeColor));
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
      // Same rule as the inline control and the arrow keys: all three ways
      // into a select have to agree, or `disabled` means "disabled unless you
      // reach it the other way".
      onTap: _isSubmitting || el['disabled'] == true ? null : () => _openSelectDialog(el),
      mouseCursor: SystemMouseCursors.click,
    );
  }

  /// The picker dialog for a `select` icon-row field: one row per option,
  /// checked against the current value; tapping one commits it (exactly as
  /// the inline control did) and closes.
  ///
  /// It carries a footer even though every row is already an action, unlike
  /// the plain option menus §Dialogs excuses from one: a settings field's
  /// editors are read as one family, and a picker that closes only by tapping
  /// an option — beside a bands editor that has Done and Defaults — reads as
  /// a dialog missing its buttons.
  Future<void> _openSelectDialog(Map<String, dynamic> el) async {
    final key = el['key'] as String;
    final label = el['label'] as String? ?? '';
    final options = (el['options'] is List) ? (el['options'] as List).cast<Map<String, dynamic>>() : const <Map<String, dynamic>>[];
    final current = _values[key];
    final hasDefault = el.containsKey('defaultValue');

    // Wrap the chosen value in a one-element list so a dismissed dialog
    // (null) is distinguishable from picking an option whose value is null.
    final picked = await showHaloDialog<List<dynamic>>(
      context: context,
      builder: (dialogContext) => HaloDialog(
        title: Text(label),
        // Edge to edge, matching SimpleDialog's child layout.
        contentPadding: EdgeInsets.zero,
        // The body scrolls itself; two scrollables on one axis fail to lay
        // out.
        scrollable: false,
        content: _SelectDialogBody(options: options, current: current, searchHint: t.formChrome.search, clearLabel: t.formChrome.clear),
        secondary: hasDefault ? _defaultsButton(onPressed: _isSubmitting ? null : () => Navigator.of(dialogContext).pop([el['defaultValue']])) : null,
        cancel: TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(t.common.done)),
      ),
    );
    if (picked == null || !mounted) return;
    final val = picked.first;
    setState(() {
      _values[key] = val;
      _errors.remove(key);
    });
    unawaited(_handleFieldBlurOrInteraction(key, val));
  }

  /// Sets a `checkbox` field, from the row or from its own Switch.
  void _setToggle(String key, bool value) {
    setState(() {
      _values[key] = value;
      _errors.remove(key);
    });
    _handleFieldBlurOrInteraction(key, value);
  }
}

/// The body of a `select` icon-row field's picker dialog: the options, and a
/// search field once there are too many to browse.
///
/// A widget rather than a `StatefulBuilder` because it owns a
/// [TextEditingController], and that has to outlive the dialog's POP
/// animation — the field rebuilds all the way through it, so disposing when
/// `showHaloDialog` returns throws "used after being disposed". An element's
/// own `dispose` runs at the right moment; nothing shorter-lived does.
class _SelectDialogBody extends StatefulWidget {
  final List<Map<String, dynamic>> options;
  final Object? current;
  final String searchHint;
  final String clearLabel;

  const _SelectDialogBody({required this.options, required this.current, required this.searchHint, required this.clearLabel});

  @override
  State<_SelectDialogBody> createState() => _SelectDialogBodyState();
}

class _SelectDialogBodyState extends State<_SelectDialogBody> {
  /// Past browsing size the list earns a search field, at the same threshold
  /// [_ChoiceFields._openMultiselectEditor] uses. Some vocabularies run
  /// to hundreds of rows — every IANA zone is 341 — and scrolling one to
  /// reach a name you already know is not a picker.
  late final bool _searchable = widget.options.length > 20;
  late final TextEditingController? _search = _searchable ? TextEditingController() : null;

  @override
  void dispose() {
    _search?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search?.text.trim().toLowerCase() ?? '';
    final visible = query.isEmpty
        ? widget.options
        : [
            for (final opt in widget.options)
              if (matchesWordStart((opt['label'] as String?) ?? '', query)) opt,
          ];
    final searchBorder = OutlineInputBorder(borderRadius: BorderRadius.circular(8));
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          // Lazy, unlike the Column this replaces: a full zone vocabulary
          // built 341 ListTiles to show ten of them, on every keystroke.
          child: ListView.builder(
            // A mis-hit here silently picks the wrong value (docs/quirks.md).
            key: listContentsKey([for (final opt in visible) opt['value']]),
            shrinkWrap: true,
            itemCount: visible.length,
            itemBuilder: (context, i) {
              final opt = visible[i];
              return ListTile(
                title: Text(opt['label'] as String, style: optionEmphasisStyle(opt, widget.options)),
                trailing: opt['value'] == widget.current ? const Icon(MdiIcons.check) : null,
                onTap: () => Navigator.pop(context, [opt['value']]),
                mouseCursor: SystemMouseCursors.click,
              );
            },
          ),
        ),
        if (_searchable)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.lg).copyWith(top: Space.md),
            child: TextField(
              selectAllOnFocus: false,
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(MdiIcons.magnify, size: 18),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        icon: Icon(MdiIcons.close, size: 18, semanticLabel: widget.clearLabel),
                        onPressed: () => setState(() => _search!.clear()),
                      ),
                hintText: widget.searchHint,
                border: searchBorder,
                focusedBorder: haloFocusedBorder(searchBorder, context),
              ),
            ),
          ),
      ],
    );
  }
}
