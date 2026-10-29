// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The elements that are not a value's own field: headers, dividers, markdown,
// disclosures, side-by-side rows, links, the account row and actions.

part of 'form_renderer.dart';

/// [FormRendererState]'s non-value elements. The members declared abstract
/// below are the state's own, which every element shares.
mixin _Elements on State<FormRenderer> {
  Map<String, dynamic> get _values;
  Set<String> get _runningActions;
  Set<String> get _openDisclosures;
  int get _actionGeneration;
  set _actionGeneration(int value);
  EdgeInsetsGeometry get _rowContentPadding;
  set _buildingRowMembers(bool value);
  Color? _devModeColor(Map<String, dynamic> el);
  List<Map<String, dynamic>> _members(Map<String, dynamic> group);
  bool _visibleWhenHolds(Map<String, dynamic> el);
  List<Widget> _elementRows(ThemeData theme, List<Map<String, dynamic>> elements);
  void _applyFieldUpdates(Map<String, dynamic> updates);
  bool _sectionIsOpen(Map<String, dynamic> band);
  void _toggleSection(Map<String, dynamic> band);

  /// A `style: 'section'` header, folding the rows under it.
  SectionHeader _sectionHeader(Map<String, dynamic> el, String title, {Color? color, Widget? subtitle}) =>
      SectionHeader(title, color: color, subtitle: subtitle, expanded: _sectionIsOpen(el), onTap: () => _toggleSection(el));

  /// A header's second line, in the ordinary body face — null where the
  /// element declares none. Read by the pinned band too, which builds no
  /// header widget of its own.
  Widget? _headerSubtitle(Map<String, dynamic> el, ThemeData theme) {
    final subtitle = el['subtitle'] as String?;
    if (subtitle == null || subtitle.isEmpty) return null;
    return Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: _devModeColor(el) ?? theme.colorScheme.onSurfaceVariant));
  }

  /// `style: 'section'` renders the settings-panel section band: smaller
  /// type than a form's own title, on the same ground the Operation Setup
  /// sheet's sections take. Opt-in, not the default, because `_buildHeader`
  /// renders `type: 'header'` elements for every FormRenderer caller, not
  /// just settings panels — an ad hoc extension form's own section headers
  /// keep the plain unbanded look unless they explicitly ask for this one.
  /// The band takes its own inset from the ambient ListTileTheme, which is
  /// the same one every row in this form reads, so the section branch skips
  /// [_rowContentPadding] rather than adding a second one on top.
  ///
  /// A section folds only where it heads the form's own rows ([folds]); one
  /// among a disclosure's members has no rows of its own to fold, and a caret
  /// there would turn without hiding anything.
  Widget _buildHeader(Map<String, dynamic> el, ThemeData theme, {bool folds = false}) {
    final title = el['title'] as String? ?? '';
    final devModeColor = _devModeColor(el);
    final isSection = el['style'] == 'section';
    // Text on the surface, not a fill — HaLoColors.onSurfaceAccent, not
    // colorScheme.primary directly.
    final onSurfaceAccent = (theme.extension<HaLoColors>() ?? HaLoColors.light).onSurfaceAccent;
    final subtitleWidget = _headerSubtitle(el, theme);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(fontFamily: 'RobotoSlab', fontWeight: FontWeight.w900, color: devModeColor ?? onSurfaceAccent),
        ),
        if (subtitleWidget != null) ...[const SizedBox(height: Space.xs), subtitleWidget],
      ],
    );
    if (el['style'] == 'category') return CategoryBand(title, color: devModeColor, subtitle: subtitleWidget, trailing: _bandAction(el));
    if (!isSection) return Padding(padding: _rowContentPadding, child: content);
    return folds
        ? _sectionHeader(el, title, color: devModeColor, subtitle: subtitleWidget)
        : SectionHeader(title, color: devModeColor, subtitle: subtitleWidget);
  }

  Widget _buildDivider(Map<String, dynamic> el, ThemeData theme) {
    final title = el['title'] as String?;
    if (title == null || title.isEmpty) {
      return const Divider();
    }
    final devModeColor = _devModeColor(el);
    final onSurfaceAccent = (theme.extension<HaLoColors>() ?? HaLoColors.light).onSurfaceAccent;
    return Padding(
      padding: _rowContentPadding,
      child: Row(
        children: [
          // Flexible, not bare: the title is a full sentence in some forms
          // ("If two serial ports show up for the same radio"), and an
          // unbounded Text beside an Expanded divider overflows the row in a
          // narrow pane rather than wrapping.
          Flexible(
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(color: devModeColor ?? onSurfaceAccent, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: Space.md),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }

  Widget _buildMarkdown(Map<String, dynamic> el, ThemeData theme) {
    final text = el['text'] as String? ?? '';
    final devModeColor = _devModeColor(el);
    // The dev-mode tint recolors the paragraph text only.
    final style = devModeColor == null ? null : (MarkdownStyleSheet base) => base.copyWith(p: base.p?.copyWith(color: devModeColor));
    if (el['collapsible'] == true) {
      return _CollapsibleMarkdown(
        title: el['title'] as String? ?? '',
        color: devModeColor,
        child: Padding(
          padding: _rowContentPadding,
          child: HaloMarkdown(data: text, style: style),
        ),
      );
    }
    return Padding(
      padding: _rowContentPadding,
      child: HaloMarkdown(data: text, style: style),
    );
  }

  /// A fold over its own `elements` — the same row-style section a
  /// collapsible markdown note is, holding the visible members as rows.
  Widget _buildDisclosure(Map<String, dynamic> el, ThemeData theme) {
    final key = el['key'] as String;
    final open = _openDisclosures.contains(key);
    return CollapsibleSection.row(
      key: ValueKey('disclosure:$key'),
      title: el['title'] as String? ?? '',
      color: _devModeColor(el),
      expanded: open,
      onToggle: () => setState(() => open ? _openDisclosures.remove(key) : _openDisclosures.add(key)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: Space.xl),
          ..._elementRows(theme, _members(el).where(_visibleWhenHolds).toList()),
        ],
      ),
    );
  }

  /// `{type: 'row', elements}` — its visible members side by side, each
  /// taking its `flex` (1 when absent) share of the width, or with `flex: 0`
  /// its natural width — which is for a button: a text box has none, and
  /// throws. Aligned on the text baseline, so a box and a button beside it
  /// line up on what they say, and an error opening under one box does not
  /// shift its neighbours.
  ///
  /// A button pads its label less here: at phone width, beside two boxes,
  /// the default padding is room a box needs for its label.
  Widget _buildRow(Map<String, dynamic> el, ThemeData theme) {
    final members = _members(el).where(_visibleWhenHolds).toList();
    final inset = _rowContentPadding;
    final List<Widget> built;
    _buildingRowMembers = true;
    try {
      built = [
        for (final member in members) _elementRows(theme, [member]).single,
      ];
    } finally {
      _buildingRowMembers = false;
    }
    return Padding(
      padding: inset,
      child: OutlinedButtonTheme(
        data: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: Space.md)).merge(theme.outlinedButtonTheme.style),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            for (final (index, member) in members.indexed) ...[
              if (index > 0) const SizedBox(width: Space.md),
              switch (member['flex'] as int? ?? 1) {
                0 => built[index],
                final flex => Expanded(flex: flex, child: built[index]),
              },
            ],
          ],
        ),
      ),
    );
  }

  /// `{type: 'link', label, url | panel, icon?, description?}` — an
  /// icon-row-styled tile that hands its URL to [FormRenderer.onOpenLink], or
  /// its `panel` key to [FormRenderer.onOpenPanel] (no-op when the presenter
  /// didn't wire the one it needs). A panel link stays inside the app, so it
  /// wears a chevron rather than the open-in-new button.
  Widget _buildLink(Map<String, dynamic> el, ThemeData theme) {
    final label = el['label'] as String? ?? '';
    final description = el['description'] as String?;
    final icon = el['icon'] as String?;
    final url = el['url'] as String? ?? '';
    final panel = el['panel'] as String?;
    final devModeColor = _devModeColor(el);

    final VoidCallback? open;
    if (panel != null) {
      open = widget.onOpenPanel == null ? null : () => widget.onOpenPanel!(panel);
    } else {
      open = url.isEmpty || widget.onOpenLink == null ? null : () => widget.onOpenLink!(url);
    }
    return ListTile(
      contentPadding: _rowContentPadding,
      leading: icon != null ? Icon(resolveIconName(icon), color: devModeColor) : null,
      title: Text(
        label,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: devModeColor),
      ),
      subtitle: description != null && description.isNotEmpty ? Text(description, style: TextStyle(color: devModeColor)) : null,
      trailing: panel != null
          ? Icon(MdiIcons.chevronRight, color: devModeColor)
          : IconButton(
              icon: Icon(MdiIcons.openInNew, size: 22, color: devModeColor, semanticLabel: t.formChrome.openPage),
              onPressed: open,
            ),
      onTap: open,
      mouseCursor: SystemMouseCursors.click,
    );
  }

  /// A `fieldType: 'account'` field: a read-only reference into the
  /// separate `account` hook system (see docs/extensions/settings.md's
  /// "account field type") — never defines or stores account data itself.
  /// Status is whatever the caller put in the field's `value`, shaped
  /// `{connected: bool, label: String?}`; tapping Manage/Connect calls
  /// [FormManageAccount] with the field's `account.key`/`account.subkey`,
  /// which is expected to open that account's own standalone dialog.
  Widget _buildAccountField(Map<String, dynamic> el, ThemeData theme) {
    final key = el['key'] as String;
    final label = el['label'] as String? ?? '';
    final account = (el['account'] as Map?)?.cast<String, dynamic>();
    final accountKey = account?['key'] as String?;
    final subkey = account?['subkey'] as String?;
    final status = (_values[key] is Map) ? (_values[key] as Map).cast<String, dynamic>() : const <String, dynamic>{};
    final connected = status['connected'] == true;
    // The account hook reports this when the credential store threw: the app
    // could not look, which is not the same as a signed-out account, and a
    // Connect button here would walk the operator into a save that fails.
    final unavailable = status['unavailable'] == true;
    final statusLabel = status['label'] as String?;
    final devModeColor = _devModeColor(el);

    return ListTile(
      contentPadding: _rowContentPadding,
      leading: Icon(
        unavailable ? MdiIcons.keyRemove : (connected ? MdiIcons.checkCircle : MdiIcons.radioboxBlank),
        color: devModeColor ?? (connected ? (theme.extension<HaLoColors>() ?? HaLoColors.light).onSurfaceAccent : theme.colorScheme.onSurfaceVariant),
      ),
      title: Text(label, style: devModeColor == null ? null : TextStyle(color: devModeColor)),
      subtitle: Text(
        unavailable
            ? t.formChrome.storageUnavailable
            : connected
            ? (statusLabel ?? t.formChrome.connected)
            : t.formChrome.notConnected,
        style: devModeColor == null ? null : TextStyle(color: devModeColor),
      ),
      trailing: TextButton(
        onPressed: accountKey == null || widget.onManageAccount == null || unavailable ? null : () => widget.onManageAccount!(accountKey, subkey),
        child: Text(connected ? t.formChrome.manage : t.formChrome.connect),
      ),
    );
  }

  /// Runs [FormAction] for [actionKey]/[method] and applies whatever comes
  /// back — [FormActionResult.fieldUpdates] to the fields they belong to,
  /// [FormActionResult.elements] handed up to whoever owns this form's
  /// definition (see [FormRenderer.onElementsChanged]), and
  /// [FormActionResult.message] as a result banner. Shared by the `action`
  /// element's button and a `select` field's `isAction` option — an
  /// option that grants access to something (a serial port the OS just
  /// authorized) is the same shape of operation as a button that does,
  /// just triggered by a different gesture.
  Future<void> _runAction(String actionKey, String method) async {
    if (widget.onAction == null) return;
    setState(() => _runningActions.add(actionKey));
    FormActionResult? result;
    try {
      result = await widget.onAction!(actionKey, method, _values);
    } catch (e) {
      result = FormActionResult(message: t.formChrome.actionError(error: e.toString()));
    }
    if (!mounted) return;
    setState(() {
      _runningActions.remove(actionKey);
      _actionGeneration++;
    });
    final updates = result?.fieldUpdates;
    if (updates != null) _applyFieldUpdates(updates);
    final elements = result?.elements;
    if (elements != null) widget.onElementsChanged?.call(elements);
    final message = result?.message;
    if (message != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(haloSnackBar(message));
    }
  }

  /// A category band's `action` — an action element's own map — as a button
  /// at the band's trailing edge: a control acting on the whole section,
  /// opposite its title, the way [CategoryBand.trailing] describes. With an
  /// `icon` it is the icon alone, its `label` the accessible name only.
  Widget? _bandAction(Map<String, dynamic> band) => switch (band['action']) {
    final Map<String, dynamic> action when action['icon'] is String => _iconActionButton(action),
    final Map<String, dynamic> action => _actionButton(action),
    _ => null,
  };

  /// An icon-only action, as the station rows draw their connection toggle.
  /// `tone: 'connected'` draws the icon in [connectedGreen]; `busy: true`
  /// shows the spinner the row does while a connection is changing, where
  /// a tap could only queue a second change behind the first.
  Widget _iconActionButton(Map<String, dynamic> el) {
    final actionKey = el['key'] as String? ?? '';
    if (_runningActions.contains(actionKey) || el['busy'] == true) return const ConnectionBusySpinner();
    final theme = Theme.of(context);
    return IconButton(
      icon: Icon(
        resolveIconName(el['icon'] as String),
        // The app has no hover tooltips, so the accessible name is the only
        // place this control is named.
        semanticLabel: el['label'] as String?,
        color: _devModeColor(el) ?? (el['tone'] == 'connected' ? connectedGreen(theme) : theme.colorScheme.onSurfaceVariant),
      ),
      onPressed: widget.onAction == null || el['disabled'] == true ? null : () => _runAction(actionKey, el['method'] as String? ?? ''),
    );
  }

  /// A `type: 'action'` element: a button that runs [_runAction].
  /// A bare button, so it takes the row inset here — a form that pads
  /// around its rows is not what holds the others in line (see the `inset`
  /// helper in [_buildField]).
  Widget _buildActionElement(Map<String, dynamic> el, ThemeData theme) {
    final actionKey = el['key'] as String? ?? '';
    final label = el['label'] as String? ?? '';
    final method = el['method'] as String? ?? '';
    final isRunning = _runningActions.contains(actionKey);
    final devModeColor = _devModeColor(el);
    if (el['style'] == 'row') {
      // The same bold title as the rows that open a picker or a panel: a row
      // that opens a dialog is one more field of the form, not a caption.
      return ListTile(
        contentPadding: _rowContentPadding,
        leading: Icon(resolveIconName(el['icon'] as String? ?? 'cog-outline'), color: devModeColor),
        title: Text(
          label,
          style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: devModeColor),
        ),
        subtitle: el['description'] is String ? Text(el['description'] as String) : null,
        trailing: Icon(MdiIcons.chevronRight, color: devModeColor),
        onTap: widget.onAction == null || isRunning ? null : () => _runAction(actionKey, method),
      );
    }

    return Padding(padding: _rowContentPadding, child: _actionButton(el));
  }

  /// An action's bare button, with no inset of its own. `disabled: true`
  /// greys it, for an action that does not apply right now but is still
  /// where the operator will look for it.
  Widget _actionButton(Map<String, dynamic> el) {
    final actionKey = el['key'] as String? ?? '';
    final method = el['method'] as String? ?? '';
    final isRunning = _runningActions.contains(actionKey);
    final devModeColor = _devModeColor(el);
    return OutlinedButton(
      style: devModeColor == null
          ? null
          : OutlinedButton.styleFrom(
              foregroundColor: devModeColor,
              side: BorderSide(color: devModeColor),
            ),
      onPressed: widget.onAction == null || isRunning || el['disabled'] == true ? null : () => _runAction(actionKey, method),
      child: isRunning ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Text(el['label'] as String? ?? ''),
    );
  }
}

/// A collapsible markdown section — a row-style [CollapsibleSection] holding
/// its own open state, which a markdown element has no key to keep in the
/// form's.
class _CollapsibleMarkdown extends StatefulWidget {
  final String title;
  final Color? color;
  final Widget child;

  const _CollapsibleMarkdown({required this.title, required this.color, required this.child});

  @override
  State<_CollapsibleMarkdown> createState() => _CollapsibleMarkdownState();
}

class _CollapsibleMarkdownState extends State<_CollapsibleMarkdown> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) => CollapsibleSection.row(
    title: widget.title,
    color: widget.color,
    expanded: _expanded,
    onToggle: () => setState(() => _expanded = !_expanded),
    child: Align(alignment: Alignment.centerLeft, child: widget.child),
  );
}
