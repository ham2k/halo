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

/// Distinguishes "argument not passed" from "explicitly passed null" in
/// [PaneLayoutOptions.copyWith] — every field there is nullable, so a plain
/// `null` default can't tell "keep the current value" from "clear it".
const _unset = Object();

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
  ///
  /// Null is "no opinion", and the VIEW decides (see
  /// `DockHost.defaultHeaderlessModules`) — the Operation view's panes are
  /// headed by default and Home's are not. Tri-state rather than a bool
  /// defaulting to true, because on a view whose default is headerless a
  /// stored `true` is the operator asking for a header, and a bool could not
  /// tell that apart from never having been asked.
  final bool? showHeader;

  /// Overrides for this pane alone, by enum name; null inherits the app's own
  /// setting. Held as names rather than enums so the whole object round-trips
  /// through JSON without a codec.
  final String? fontScale;
  final String? density;

  /// The pane's theme override: `'light'`, `'dark'`, or null to inherit the
  /// app's own [SettingsService.themeMode]. Not the full [ThemeMode] range —
  /// a per-pane "system" would only ever mean the same thing `null` already
  /// does.
  final String? themeMode;

  const PaneLayoutOptions({this.title, this.showHeader, this.fontScale, this.density, this.themeMode});

  static const none = PaneLayoutOptions();

  bool get isEmpty =>
      (title == null || title!.isEmpty) &&
      showHeader == null &&
      fontScale == null &&
      density == null &&
      themeMode == null;

  /// Whether this pane shows its header, given what the VIEW does by default
  /// for panes nobody has expressed an opinion about.
  bool showsHeader({required bool byDefault}) => showHeader ?? byDefault;

  PaneLayoutOptions copyWith({
    Object? title = _unset,
    // On the sentinel like the rest, because [showHeader] is tri-state: a
    // plain `bool?` cannot tell "leave it alone" from "clear the opinion",
    // and clearing is what Reset does to a pane on a headerless view.
    Object? showHeader = _unset,
    Object? fontScale = _unset,
    Object? density = _unset,
    Object? themeMode = _unset,
  }) => PaneLayoutOptions(
    title: title == _unset ? this.title : title as String?,
    showHeader: showHeader == _unset ? this.showHeader : showHeader as bool?,
    fontScale: fontScale == _unset ? this.fontScale : fontScale as String?,
    density: density == _unset ? this.density : density as String?,
    themeMode: themeMode == _unset ? this.themeMode : themeMode as String?,
  );

  /// The override as a [FontScale], or null to inherit. An unknown name — a
  /// layout written by a newer build, or hand-edited — inherits rather than
  /// throwing: a pane at the app's own size is a far better failure than a
  /// view that will not open.
  FontScale? get fontScaleValue => _byName(FontScale.values, fontScale);

  DensityPreference? get densityValue => _byName(DensityPreference.values, density);

  /// The override as a [Brightness], or null to inherit — same "degrade
  /// rather than throw" rule as [fontScaleValue].
  Brightness? get themeBrightness => switch (themeMode) {
    'light' => Brightness.light,
    'dark' => Brightness.dark,
    _ => null,
  };

  static T? _byName<T extends Enum>(List<T> values, String? name) {
    if (name == null) return null;
    for (final value in values) {
      if (value.name == name) return value;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    if (title != null && title!.isNotEmpty) 'title': title,
    if (showHeader != null) 'showHeader': showHeader,
    if (fontScale != null) 'fontScale': fontScale,
    if (density != null) 'density': density,
    if (themeMode != null) 'themeMode': themeMode,
  };

  static PaneLayoutOptions fromJson(Object? json) {
    if (json is! Map) return none;
    final title = json['title'];
    final fontScale = json['fontScale'];
    final density = json['density'];
    final themeMode = json['themeMode'];
    // Typed, not cast: a stored value of the wrong TYPE has to inherit for
    // the same reason an unknown name does. These are read from a `late`
    // field inside `build`, so a cast that throws is an Operation View that
    // shows an error tile on every launch, with the options dialog that
    // would repair it behind the view that will not open.
    return PaneLayoutOptions(
      title: title is String && title.trim().isNotEmpty ? title.trim() : null,
      showHeader: json['showHeader'] is bool ? json['showHeader'] as bool : null,
      fontScale: fontScale is String ? fontScale : null,
      density: density is String ? density : null,
      themeMode: themeMode is String ? themeMode : null,
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
  bool headerByDefault = true,
  bool titleEnabled = true,
  /// False where the three size overrides would be stored and never read — a
  /// nested container, whose subtree the dock renders itself rather than
  /// through the host's per-pane wrapper. A select that writes a setting
  /// nothing applies is worse than an absent one: the operator sets it, sees
  /// nothing, and stops trusting the other two.
  bool showSizeFields = true,
  /// The PANEL's own settings, embedded under a "Panel Settings" heading —
  /// a different thing from the rest of this dialog, which is about the
  /// pane's PLACE in the layout. Offered here because hiding a pane's header
  /// takes away the tab action that is otherwise the only way in, and an
  /// operator who cannot reach a panel's settings cannot undo whatever it is
  /// set to. Built fresh on every call (not a widget instance) so the
  /// caller's closure can capture whatever config it just read; null for a
  /// panel with no settings of its own.
  WidgetBuilder? panelSettingsBuilder,
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
    // The footer band below carries Done, which is the way out — see
    // haloDialogFooterBand.
    closeButton: false,
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
      headerByDefault: headerByDefault,
      titleEnabled: titleEnabled,
      showSizeFields: showSizeFields,
      panelSettingsBuilder: panelSettingsBuilder,
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

  /// What the checkbox reads when the operator has never expressed an opinion
  /// — this VIEW's default (see `DockHost.defaultHeaderlessModules`). Without
  /// it a tri-state `showHeader` of null renders as an unchecked box on a view
  /// whose panes are headed, and ticking it would look like a no-op.
  final bool headerByDefault;
  final bool titleEnabled;
  final bool showSizeFields;
  final WidgetBuilder? panelSettingsBuilder;
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
    required this.headerByDefault,
    required this.titleEnabled,
    required this.showSizeFields,
    this.panelSettingsBuilder,
    this.onDelete,
  });

  @override
  State<_PaneLayoutOptionsBody> createState() => _PaneLayoutOptionsBodyState();
}

class _PaneLayoutOptionsBodyState extends State<_PaneLayoutOptionsBody> {
  late PaneLayoutOptions _options = widget.current;
  late final TextEditingController _titleController = TextEditingController(text: _options.title ?? '');

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

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
      _titleController.text = '';
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.t.operation.layout;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Flexible, and scrollable on its own: title, header toggle and the
        // three overrides are a small, constant size at the app's own scale,
        // so ordinarily they just sit above Panel Settings without using
        // this scroll at all — but a large font scale or a short window
        // (docs/design/ui-scaling.md's tightest geometry) can grow them past
        // what's left after the header and footer, and this is what keeps
        // that case scrolling instead of overflowing off the pane.
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Space.xxl, Space.lg, Space.xxl, Space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
              // Show Header rides beside Title rather than below it: the two
              // are both about the pane's header (what it says, whether
              // it's there at all), and the row reads as one decision
              // instead of two.
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _titleController,
                      // Greyed rather than hidden for a built-in view: an
                      // operator looking for the setting finds it and is
                      // told it does not apply, instead of hunting for
                      // something that was never there.
                      enabled: widget.titleEnabled,
                      decoration: poloFieldDecoration(context, t.paneTitle, hintText: widget.defaultTitle),
                      onChanged: (value) =>
                          _apply(_options.copyWith(title: value.trim().isEmpty ? null : value.trim())),
                    ),
                  ),
                  if (widget.showHeaderField) ...[
                    const SizedBox(width: Space.lg),
                    // Flexible rather than natural width: Spanish's
                    // "Mostrar encabezado" (and any label, at a high font
                    // scale) can outgrow what Title leaves it in a
                    // maxDialogWidth-capped pane, and the label ellipsizes
                    // rather than forcing the row to overflow.
                    Flexible(
                      child: Opacity(
                        // Greyed rather than hidden while the pane shares a
                        // group: the header is the tab strip then, and
                        // hiding it would strand the other panes.
                        opacity: widget.inTabset ? 0.38 : 1,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              // Resolved against the VIEW's default, because
                              // `showHeader` is tri-state: a pane nobody has
                              // expressed an opinion about is shown as the
                              // view will actually draw it — checked on the
                              // Operation view, unchecked on Home — rather
                              // than as an assumed `true` the pane contradicts.
                              value: _options.showsHeader(byDefault: widget.headerByDefault),
                              onChanged: widget.inTabset
                                  ? null
                                  : (value) =>
                                        _apply(_options.copyWith(showHeader: value ?? widget.headerByDefault)),
                            ),
                            Flexible(
                              child: Text(t.paneShowHeader, maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              // A greyed control with no reason reads as broken, not
              // unavailable — the same failure mode Show Header's own
              // tabset case would be without this.
              if (!widget.titleEnabled || (widget.showHeaderField && widget.inTabset))
                Padding(
                  padding: const EdgeInsets.only(top: Space.xs),
                  child: Text(
                    !widget.titleEnabled ? t.viewTitleBuiltIn : t.paneShowHeaderTabset,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              if (widget.showSizeFields) ...[
              const SizedBox(height: Space.xl),
              // Font Scale, Layout Density and Theme, side by side — three
              // per-pane overrides an operator reaches for together, not three
              // separate decisions.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _overrideSelect(
                    label: context.t.settings.fontScale,
                    // The resolved enum's own name, not the raw stored
                    // string: fontScaleValue already applies the
                    // unrecognized-degrades-to-inherit rule, so the select
                    // doesn't have to re-derive it.
                    value: _options.fontScaleValue?.name,
                    options: [
                      for (final scale in FontScale.selectableValues)
                        (value: scale.name, label: context.t['settings.fontScaleOpts.${scale.name}'] as String),
                    ],
                    onChanged: (value) => _apply(_options.copyWith(fontScale: value)),
                  )),
                  const SizedBox(width: Space.md),
                  Expanded(child: _overrideSelect(
                    label: context.t.settings.layoutDensity,
                    value: _options.densityValue?.name,
                    options: [
                      for (final preference in DensityPreference.selectableValues)
                        (
                          value: preference.name,
                          label: context.t['settings.layoutDensityOpts.${preference.name}'] as String,
                        ),
                    ],
                    onChanged: (value) => _apply(_options.copyWith(density: value)),
                  )),
                  const SizedBox(width: Space.md),
                  Expanded(child: _overrideSelect(
                    label: context.t.settings.theme.title,
                    // themeBrightness is null for anything but exactly
                    // 'light'/'dark', so a non-null result means themeMode
                    // is already one of this select's own options.
                    value: _options.themeBrightness == null ? null : _options.themeMode,
                    options: [
                      (value: 'light', label: context.t.settings.theme.light),
                      (value: 'dark', label: context.t.settings.theme.dark),
                    ],
                    onChanged: (value) => _apply(_options.copyWith(themeMode: value)),
                  )),
                ],
              ),
              ],
              ],
            ),
          ),
        ),
        if (widget.panelSettingsBuilder case final builder?)
          // Flexible, not Expanded: a short embedded form (a handful of
          // extension-panel fields) sizes to its own content, leaving the
          // footer directly beneath it. Only a form taller than the space
          // left over — the logging/map settings, wide enough on scale to
          // reach it — clips and scrolls, instead of pushing the footer (or
          // Title, above) off screen.
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionHeader(t.panelSettingsAction),
                // Flexible with no scrollview of its own: every
                // panelSettingsBuilder result scrolls itself internally
                // given a bounded height (_TargetSettingsForm's own
                // Flexible+SingleChildScrollView; EmbeddedPanelSettingsForm's
                // below) — wrapping it in a SECOND SingleChildScrollView here
                // would hand it UNBOUNDED height instead, which is exactly
                // what breaks a Flexible nested inside one.
                Flexible(
                  child: Padding(
                    // Vertical only: these are settings rows, and a row that
                    // spans the pane is what makes its background and the
                    // band above it reach the same edge.
                    padding: const EdgeInsets.only(top: Space.md, bottom: Space.lg),
                    child: SettingsList(child: Builder(builder: builder)),
                  ),
                ),
              ],
            ),
          ),
        // The shared modal-pane footer band: everything that DOES something
        // has already happened by the time it is pressed, so Done is a way
        // OUT and sits in the cancel slot rather than reading as a confirm.
        haloDialogFooterBand(
          context,
          // The footer's leading slot, which is where a control that
          // takes something away belongs — as far from Done as the row
          // goes. Remove leads: it is the single-pane act, an operator
          // reaches for it first, and Restore Defaults (the
          // whole-arrangement act) trails it. Two controls in a slot
          // the footer sizes to its natural width (no Flexible of its
          // own), so they have to be able to give way — a long pair of
          // labels in another language, or a resize to a narrow pane
          // while this is open, would starve Done and overflow the row.
          destructive: Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                Flexible(
                  child: TextButton.icon(
                    // Not error-colored, unlike Remove: this puts
                    // things BACK to what they were, it doesn't destroy
                    // anything new — the same reason it carries an undo
                    // glyph rather than a warning one.
                    onPressed: () => unawaited(_confirmReset()),
                    icon: const Icon(MdiIcons.undo, size: 18),
                    label: Text(
                      context.t.operation.layout.resetOptions,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
          cancel: TextButton(
            // maybePop, matching the pane's barrier.
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text(context.t.common.done),
          ),
        ),
      ],
    );
  }

  /// One "inherit or override" select, shared by the Font Scale, Layout
  /// Density and Theme fields — same options shape, same "Same as the app"
  /// first row, same null-means-inherit contract as [PaneLayoutOptions].
  ///
  /// [value] must already be `null` or one of [options]' own values —
  /// [PaneLayoutOptions]' fontScaleValue/densityValue/themeBrightness
  /// getters are what decide whether a stored override is recognized (an
  /// unrecognized one degrades to null rather than throwing), so callers
  /// pass the RESOLVED value through those, not the raw stored string. This
  /// widget only has to trust the answer, not re-derive it — a second
  /// "is this valid" check here could drift from what those getters decide.
  Widget _overrideSelect({
    required String label,
    required String? value,
    required List<({String value, String label})> options,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value ?? _inherit,
      isExpanded: true,
      icon: dropdownTrailingIcon,
      decoration: poloFieldDecoration(context, label),
      items: [
        DropdownMenuItem(value: _inherit, child: Text(context.t.operation.layout.paneInherit)),
        for (final option in options) DropdownMenuItem(value: option.value, child: Text(option.label)),
      ],
      onChanged: (picked) => onChanged(picked == _inherit ? null : picked),
    );
  }
}

/// A plain-form panel's own settings — its [PanelDefinition.formFields] —
/// as a [showPaneLayoutOptions] `panelSettingsBuilder`. For a native panel
/// whose settings are more than a plain form (logging, map), build
/// `settingsFormForTarget` (settings_target_dialog.dart) instead; there is
/// no `formFields` list for this widget to render.
///
/// The caller filters out any `type: 'action'` element before handing
/// [fields] over: an action here would have no route of its own to close on
/// completion, unlike the same field rendered in the panel's own standalone
/// dialog (`showPanelSettings`), and a disabled/inert button reads as broken
/// rather than as "not offered here".
///
/// A widget of its own, not inline in the caller, because it owns running
/// form state (`_values`) across rebuilds the same way [FormRenderer]
/// itself does for a whole dialog — a plain builder closure would rebuild
/// that state from [initial] on every parent `setState`, discarding
/// whatever the operator just typed.
class EmbeddedPanelSettingsForm extends StatefulWidget {
  final List<Map<String, dynamic>> fields;
  final Map<String, dynamic> initial;
  final bool developerMode;

  /// Commits one field, autosaving the same way the layout options around it
  /// do. `state` is this form's values as of the change, for callers that
  /// persist a whole config rather than one field at a time.
  final Future<void> Function(String key, dynamic value, Map<String, dynamic> state) onFieldChange;

  const EmbeddedPanelSettingsForm({
    super.key,
    required this.fields,
    required this.initial,
    required this.developerMode,
    required this.onFieldChange,
  });

  @override
  State<EmbeddedPanelSettingsForm> createState() => _EmbeddedPanelSettingsFormState();
}

class _EmbeddedPanelSettingsFormState extends State<EmbeddedPanelSettingsForm> {
  late final Map<String, dynamic> _values = Map.of(widget.initial);

  /// Returns null: nothing here rewrites the form's own state, it only
  /// mirrors the change into `_values` and carries it out to whatever
  /// persists the panel's config.
  Future<Map<String, dynamic>?> _onChange(String key, dynamic value, Map<String, dynamic> state) async {
    _values[key] = value;
    await widget.onFieldChange(key, value, state);
    return null;
  }

  // Scrolls itself, matching the contract every panelSettingsBuilder result
  // holds to: the caller (pane_layout_options.dart) hands it a bounded
  // Flexible and nothing else, so a panel with more fields than fit has to
  // clip and scroll on its own rather than overflow.
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: FormRenderer(
      formDefinition: {'elements': widget.fields},
      initialState: _values,
      showActions: false,
      showTitle: false,
      developerMode: widget.developerMode,
      labels: formRendererLabelsFor(context.t),
      settingsList: true,
      onChange: _onChange,
      onSubmit: (_) {},
      onCancel: () {},
    ),
  );
}
