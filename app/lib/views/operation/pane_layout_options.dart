// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What an operator can set about a pane's PLACE in the layout, as opposed to
// what the pane itself does (docs/design/layouts.md). Every pane has these,
// whichever panel is in it and whoever wrote it — they are the dock's
// business, not the panel's, which is why they live here rather than in a
// panel's own settings form.
//
// Reached from the pane's own header while the layout is being edited, and
// nowhere else: outside edit mode there is no layout to have options about.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../../i18n/strings.g.dart';
import '../../services/settings_service.dart';
import '../../tools/form_chrome_labels.dart';

/// One pane's layout options. Immutable, and [isEmpty] when it says nothing —
/// an empty entry is dropped rather than stored, so a layout carries options
/// only for the panes that actually have any.
class PaneLayoutOptions {
  /// The operator's own name for this pane, beating both the panel's
  /// descriptor title and any title the panel supplies from its render.
  /// Blank means "no opinion", which is not the same as an empty tab.
  final String? title;

  /// Whether the pane shows its header when it is ALONE in its group. A pane
  /// sharing a group with others always shows it — the header is the tab
  /// strip, and without it there would be no way to reach the other panes.
  final bool showHeader;

  /// Overrides for this pane alone, by enum name; null inherits the app's own
  /// setting. Held as names rather than enums so the whole object round-trips
  /// through JSON without a codec.
  final String? fontScale;
  final String? density;

  const PaneLayoutOptions({this.title, this.showHeader = true, this.fontScale, this.density});

  static const none = PaneLayoutOptions();

  bool get isEmpty => (title == null || title!.isEmpty) && showHeader && fontScale == null && density == null;

  /// The override as a [FontScale], or null to inherit. An unknown name — a
  /// layout written by a newer build, or hand-edited — inherits rather than
  /// throwing: a pane at the app's own size is a far better failure than a
  /// view that will not open.
  FontScale? get fontScaleValue => _byName(FontScale.values, fontScale);

  DensityPreference? get densityValue => _byName(DensityPreference.values, density);

  static T? _byName<T extends Enum>(List<T> values, String? name) {
    if (name == null) return null;
    for (final value in values) {
      if (value.name == name) return value;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    if (title != null && title!.isNotEmpty) 'title': title,
    if (!showHeader) 'showHeader': false,
    if (fontScale != null) 'fontScale': fontScale,
    if (density != null) 'density': density,
  };

  static PaneLayoutOptions fromJson(Object? json) {
    if (json is! Map) return none;
    final title = json['title'];
    final fontScale = json['fontScale'];
    final density = json['density'];
    // Typed, not cast: a stored value of the wrong TYPE has to inherit for
    // the same reason an unknown name does. These are read from a `late`
    // field inside `build`, so a cast that throws is an Operation View that
    // shows an error tile on every launch, with the options dialog that
    // would repair it behind the view that will not open.
    return PaneLayoutOptions(
      title: title is String && title.trim().isNotEmpty ? title.trim() : null,
      showHeader: json['showHeader'] != false,
      fontScale: fontScale is String ? fontScale : null,
      density: density is String ? density : null,
    );
  }

  /// The whole map, keyed by module id. Both directions skip empties, so a
  /// layout nobody has configured stores nothing at all.
  ///
  /// Always a fresh MUTABLE map, including for the nothing-saved case: the
  /// caller owns this and edits it in place, and a `const {}` handed back on
  /// the commonest path of all would throw on the first pane configured.
  static Map<String, PaneLayoutOptions> mapFromJson(Object? json) {
    final result = <String, PaneLayoutOptions>{};
    if (json is! Map) return result;
    for (final entry in json.entries) {
      final key = entry.key;
      if (key is! String) continue;
      final options = fromJson(entry.value);
      if (!options.isEmpty) result[key] = options;
    }
    return result;
  }

  static Map<String, dynamic> mapToJson(Map<String, PaneLayoutOptions> options) => {
    for (final entry in options.entries)
      if (!entry.value.isEmpty) entry.key: entry.value.toJson(),
  };
}

/// One pane's layout options, as a modal pane over the pane it belongs to.
///
/// Autosaving, with no accept button: every change is reported through
/// [onChanged] as it happens. That is not a shortcut — these options are part
/// of the layout DRAFT, and the draft already has exactly one commit and one
/// cancel, up in the header. A second Save inside this dialog would be a
/// second promise about the same edit.
Future<void> showPaneLayoutOptions(
  BuildContext context, {
  required String paneTitle,
  required String defaultTitle,
  required bool inTabset,
  required bool developerMode,
  required PaneLayoutOptions current,
  required ValueChanged<PaneLayoutOptions> onChanged,
  /// Puts everything this dialog governs back to the defaults — for a pane
  /// that is its own entry, for the view its own AND every pane's. Called
  /// only after the operator has confirmed, and the caller owns the whole
  /// clearing: the dialog resets what it is SHOWING and nothing else.
  required VoidCallback onReset,
  /// What the confirmation says is about to be thrown away. Supplied rather
  /// than derived, because the two cases differ by more than a noun.
  required String resetTitle,
  required String resetBody,
  /// False for a VIEW's own options: a view has no header of its own to hide,
  /// and its name is the app's rather than the operator's until there are
  /// views they made themselves.
  bool showHeaderField = true,
  bool titleEnabled = true,
  /// Opens the PANEL's own settings — a different thing from this dialog,
  /// which is about the pane's place in the layout. Offered here because
  /// hiding a pane's header takes away the tab action that is otherwise the
  /// only way in, and an operator who cannot reach a panel's form cannot
  /// undo whatever it is set to. Null for a panel with no form of its own.
  VoidCallback? onPanelSettings,
  /// Takes the pane out of the arrangement, and closes this dialog with it —
  /// there is nothing left to have options about. Null for the view's own
  /// options, and for the last pane standing, which the dock refuses to
  /// remove.
  ///
  /// The drag onto the delete target remains the way this is USUALLY done.
  /// This is the same act reached by pointer-free means: a drag cannot be
  /// made with a keyboard or a screen reader, and the only alternative would
  /// be Reset Layout — the whole arrangement thrown away to drop one pane.
  VoidCallback? onDelete,
}) {
  return showModalPane<void>(
    context,
    title: context.t.operation.layout.paneOptionsTitle(panel: paneTitle),
    closeLabel: context.t.common.close,
    scrollable: false,
    builder: (paneContext) => _PaneLayoutOptionsBody(
      defaultTitle: defaultTitle,
      inTabset: inTabset,
      developerMode: developerMode,
      current: current,
      onChanged: onChanged,
      onReset: onReset,
      resetTitle: resetTitle,
      resetBody: resetBody,
      showHeaderField: showHeaderField,
      titleEnabled: titleEnabled,
      onPanelSettings: onPanelSettings,
      onDelete: onDelete,
    ),
  );
}

class _PaneLayoutOptionsBody extends StatefulWidget {
  final String defaultTitle;
  final bool inTabset;
  final bool developerMode;
  final PaneLayoutOptions current;
  final ValueChanged<PaneLayoutOptions> onChanged;
  final VoidCallback onReset;
  final String resetTitle;
  final String resetBody;
  final bool showHeaderField;
  final bool titleEnabled;
  final VoidCallback? onPanelSettings;
  final VoidCallback? onDelete;

  const _PaneLayoutOptionsBody({
    required this.defaultTitle,
    required this.inTabset,
    required this.developerMode,
    required this.current,
    required this.onChanged,
    required this.onReset,
    required this.resetTitle,
    required this.resetBody,
    required this.showHeaderField,
    required this.titleEnabled,
    this.onPanelSettings,
    this.onDelete,
  });

  @override
  State<_PaneLayoutOptionsBody> createState() => _PaneLayoutOptionsBodyState();
}

class _PaneLayoutOptionsBodyState extends State<_PaneLayoutOptionsBody> {
  /// The advanced fields are spliced into the SAME element list rather than
  /// rendered by a second FormRenderer — the same idiom (and the same reason)
  /// as the settings target dialog's "show more": one renderer means one
  /// piece of form state, and the hidden fields are genuinely absent from the
  /// tree until asked for.
  bool _showAdvanced = false;

  late PaneLayoutOptions _options = widget.current;

  /// Bumped by a reset, and part of the FormRenderer's key. The renderer
  /// reads `initialState` once, at construction — without a new key it would
  /// go on showing the values that were just thrown away.
  int _resetGeneration = 0;

  Future<void> _confirmReset() async {
    final confirmed = await showHaloDialog<bool>(
      context: context,
      builder: (dialogContext) => HaloDialog(
        title: Text(widget.resetTitle),
        content: Text(widget.resetBody),
        cancel: TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(context.t.common.cancel),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.t.operation.layout.resetOptions),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _options = PaneLayoutOptions.none;
      _resetGeneration++;
    });
    // The caller owns the model: for a pane that is one entry, for the view
    // its own and every pane's.
    widget.onReset();
  }

  /// Inheriting is a VALUE here, not the absence of one: a picker whose
  /// "same as the app" row is missing leaves an operator who overrode
  /// something with no way back to the default.
  static const _inherit = 'inherit';

  void _apply(PaneLayoutOptions next) {
    setState(() => _options = next);
    widget.onChanged(next);
  }

  List<Map<String, dynamic>> get _baseElements => [
    {
      'type': 'field',
      'key': 'title',
      'fieldType': 'text',
      'label': context.t.operation.layout.paneTitle,
      // The name it would have anyway, so an operator can see what they are
      // replacing before they replace it.
      'placeholder': widget.defaultTitle,
      // Greyed rather than hidden for a built-in view: an operator looking
      // for the setting finds it and is told it does not apply, instead of
      // hunting for something that was never there.
      'disabled': !widget.titleEnabled,
      'description': widget.titleEnabled
          ? context.t.operation.layout.paneTitleDescription
          : context.t.operation.layout.viewTitleBuiltIn,
    },
    if (widget.showHeaderField)
      {
        'type': 'field',
        'key': 'showHeader',
        'fieldType': 'checkbox',
        'label': context.t.operation.layout.paneShowHeader,
        // Greyed rather than hidden while the pane shares a group: the header
        // is the tab strip then, and hiding it would strand the other panes.
        'disabled': widget.inTabset,
        'description': widget.inTabset
            ? context.t.operation.layout.paneShowHeaderTabset
            : context.t.operation.layout.paneShowHeaderDescription,
      },
  ];

  List<Map<String, dynamic>> get _advancedElements => [
    {'type': 'header', 'label': context.t.operation.layout.paneAdvanced},
    {
      'type': 'field',
      'key': 'fontScale',
      'fieldType': 'select',
      'label': context.t.settings.fontScale,
      'description': context.t.operation.layout.paneOverrideDescription,
      'options': [
        {'label': context.t.operation.layout.paneInherit, 'value': _inherit},
        for (final scale in FontScale.selectableValues)
          {'label': context.t['settings.fontScaleOpts.${scale.name}'] as String, 'value': scale.name},
      ],
    },
    {
      'type': 'field',
      'key': 'density',
      'fieldType': 'select',
      'label': context.t.settings.layoutDensity,
      'description': context.t.operation.layout.paneOverrideDescription,
      'options': [
        {'label': context.t.operation.layout.paneInherit, 'value': _inherit},
        for (final preference in DensityPreference.selectableValues)
          {'label': context.t['settings.layoutDensityOpts.${preference.name}'] as String, 'value': preference.name},
      ],
    },
  ];

  Map<String, dynamic> get _state => {
    'title': _options.title ?? '',
    'showHeader': _options.showHeader,
    'fontScale': _options.fontScale ?? _inherit,
    'density': _options.density ?? _inherit,
  };

  /// Returns null: nothing here rewrites the form's own state, it only
  /// carries the change out to the draft.
  Future<Map<String, dynamic>?> _onChange(String key, dynamic value, Map<String, dynamic> _) async {
    String? pick(dynamic v) => v == _inherit || v == null ? null : v as String;
    _apply(switch (key) {
      'title' => PaneLayoutOptions(
        title: (value as String?)?.trim().isEmpty ?? true ? null : (value as String).trim(),
        showHeader: _options.showHeader,
        fontScale: _options.fontScale,
        density: _options.density,
      ),
      'showHeader' => PaneLayoutOptions(
        title: _options.title,
        showHeader: value == true,
        fontScale: _options.fontScale,
        density: _options.density,
      ),
      'fontScale' => PaneLayoutOptions(
        title: _options.title,
        showHeader: _options.showHeader,
        fontScale: pick(value),
        density: _options.density,
      ),
      'density' => PaneLayoutOptions(
        title: _options.title,
        showHeader: _options.showHeader,
        fontScale: _options.fontScale,
        density: pick(value),
      ),
      _ => _options,
    });
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _buildBody(context, theme);
  }

  Widget _buildBody(BuildContext context, ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: SingleChildScrollView(
            // The same inset showFormDialog gives a FormRenderer, which is
            // what every other form in the app is shown at. FormRenderer's
            // own rows take their horizontal padding from the ambient
            // ListTileTheme and have none otherwise — so the ListTileTheme
            // covers the ListTile-shaped fields (checkbox, select) and this
            // covers the rest.
            padding: const EdgeInsets.fromLTRB(Space.xxl, Space.lg, Space.xxl, Space.lg),
            child: ListTileTheme(
              data: const ListTileThemeData(contentPadding: EdgeInsets.zero),
              child: Padding(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeInOut,
                      alignment: Alignment.topCenter,
                      child: FormRenderer(
                        // Keyed on the disclosure, so growing the list rebuilds
                        // the renderer's own state from `_state` rather than
                        // leaving the new fields seeded from nothing.
                        key: ValueKey('$_showAdvanced-$_resetGeneration'),
                        formDefinition: {
                          'elements': [..._baseElements, if (_showAdvanced) ..._advancedElements],
                        },
                        initialState: _state,
                        showActions: false,
                        showTitle: false,
                        developerMode: widget.developerMode,
                        labels: formRendererLabelsFor(context.t),
                        onChange: _onChange,
                        onSubmit: (_) {},
                        onCancel: () {},
                      ),
                    ),
                    if (widget.onPanelSettings case final open?)
                      Padding(
                        padding: const EdgeInsets.only(top: Space.md),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton.icon(
                            onPressed: open,
                            icon: const Icon(MdiIcons.tune, size: 18),
                            label: Text(context.t.operation.layout.panelSettingsAction),
                          ),
                        ),
                      ),
                    if (!_showAdvanced)
                      Padding(
                        padding: const EdgeInsets.only(top: Space.md),
                        child: TextButton(
                          onPressed: () => setState(() => _showAdvanced = true),
                          child: Text(context.t.operation.layout.paneAdvanced),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // The export panel's footer, which is the app's answer for exactly
        // this shape of pane: everything that DOES something has already
        // happened by the time it is pressed, so Done is a way OUT and sits
        // in the cancel slot rather than reading as a confirm.
        Container(
          decoration: BoxDecoration(
            color: HaLoColors.of(context).onSurfaceAccent.withValues(alpha: 0.08),
            border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5))),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.xxl, vertical: Space.lg),
              child: haloDialogFooterRow(
                // The footer's leading slot, which is where a control that
                // takes something away belongs — as far from Done as the row
                // goes. It asks first: unlike every other control here, this
                // one is not a change the operator can simply make again.
                // Two controls in a slot the footer sizes to its natural
                // width (no Flexible of its own), so they have to be able to
                // give way — a long pair of labels in another language, or a
                // resize to a narrow pane while this is open, would starve
                // Done and overflow the row.
                destructive: Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: TextButton(
                          style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
                          onPressed: () => unawaited(_confirmReset()),
                          child: Text(
                            context.t.operation.layout.resetOptions,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      if (widget.onDelete case final remove?)
                        Flexible(
                          child: TextButton.icon(
                            style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
                            // No confirmation, unlike Restore Defaults beside
                            // it: this drops ONE pane, it is part of the
                            // draft, and discard puts it back with what was
                            // in it. The other asks because it takes the whole
                            // arrangement.
                            onPressed: () {
                              Navigator.of(context).pop();
                              remove();
                            },
                            icon: const Icon(MdiIcons.trashCanOutline, size: 18),
                            label: Text(
                              context.t.operation.layout.removePane,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                cancel: TextButton(
                  // maybePop, matching the pane's own close button and barrier.
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: Text(context.t.common.done),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
