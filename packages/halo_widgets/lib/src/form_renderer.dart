// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';

import 'package:collection/collection.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'category_band.dart';
import 'collapsible_section.dart';
import 'collapsing_sliver.dart';
import 'connection_toggle.dart';
import 'halo_dialog.dart';
import 'halo_markdown.dart';
import 'icon_resolver.dart';
import 'keyboard_accessory.dart';
import 'list_contents_key.dart';
import 'mdi_icons.g.dart';
import 'modal_pane.dart';
import 'row_select_field.dart';
import 'secret_text_field.dart';
import 'section_header.dart';
import 'spacing.dart';
import 'suggesting_text_field.dart';
import 'text_formatters.dart';
import 'theme.dart';
import 'text_template_editor.dart';
import 'halo_snack_bar.dart';

part 'form_renderer_choices.dart';
part 'form_renderer_elements.dart';
part 'form_renderer_list.dart';
part 'form_renderer_rows.dart';
part 'form_renderer_text.dart';

typedef FormValidator = Future<String?> Function(String fieldKey, dynamic value, Map<String, dynamic> state);
typedef FormTransformer = Future<dynamic> Function(String fieldKey, dynamic value, Map<String, dynamic> state);
typedef FormOnChange = Future<Map<String, dynamic>?> Function(String fieldKey, dynamic value, Map<String, dynamic> state);
typedef FormAction = Future<FormActionResult?> Function(String actionKey, String method, Map<String, dynamic> state);
typedef FormManageAccount = void Function(String accountKey, String? subkey);
typedef FormOpenLink = void Function(String url);
typedef FormOpenPanel = void Function(String panelKey);

/// Where a form's section folds outlast the form: the host keeps, per
/// section, whether the operator last left it open. A section is named by
/// its header's `key`, else by its title.
abstract interface class FormSectionFolds {
  /// Null for a section the operator has never folded or opened, which
  /// then takes its header's declared default.
  bool? isOpen(String section);

  void remember(String section, bool open);
}

/// What a `type: 'action'` element's handler — or, same contract, a
/// `select` option with `isAction: true` — can do: show the operator a
/// result message, hand values back to sibling fields, replace the form's
/// own element list, or any mix of the three. An action that picks
/// something on the operator's behalf (a serial port their OS just
/// granted, an OAuth-returned identifier) needs the second: a bare result
/// string, the only thing the original contract could return, has nowhere
/// to put a picked value except a message they'd have to retype into the
/// field themselves. [elements] exists for the case a picked value isn't
/// even offered yet by the CURRENT element list — a newly-granted device
/// has to become a selectable option, not just a `_values` entry with no
/// matching item in its own dropdown.
class FormActionResult {
  final String? message;
  final Map<String, dynamic>? fieldUpdates;
  final List<Map<String, dynamic>>? elements;

  const FormActionResult({this.message, this.fieldUpdates, this.elements});
}

/// Substitutes `${key}` placeholders in [template] with values from [item].
String _templateString(String template, Map<String, dynamic> item) {
  return template.replaceAllMapped(RegExp(r'\$\{([^}]+)\}'), (m) => item[m.group(1)]?.toString() ?? '');
}

/// A `select` option carrying `emphasis: true` is drawn bold — the option
/// list is saying one entry is the one to pick, not merely that it exists.
/// The serial port picker's suggestion for a radio whose bridge chip the
/// catalogue names is what this exists for; nothing about that vocabulary
/// reaches here, only the weight.
///
/// The rest of the list is then pinned to normal weight, which is the half
/// that makes it read: `DropdownButton` draws its items in `titleMedium`,
/// already w500, so bold against the default is a difference an operator
/// scanning a list of near-identical device names does not see. Only lists
/// that declare an emphasis are touched — every other dropdown in the app
/// keeps the weight it has.
TextStyle? optionEmphasisStyle(Map<String, dynamic> option, List<Map<String, dynamic>> options) {
  if (!options.any((o) => o['emphasis'] == true)) return null;
  return TextStyle(fontWeight: option['emphasis'] == true ? FontWeight.bold : FontWeight.normal);
}

/// The Defaults button every settings-field editor puts in its `secondary`
/// slot — one builder so the three dialogs can't drift on icon or wording.
/// Undo, not restore: what it undoes is the operator's own change, and the
/// two icons read as different promises when one dialog uses each.
Widget _defaultsButton({required VoidCallback? onPressed}) =>
    TextButton.icon(onPressed: onPressed, icon: const Icon(MdiIcons.undo, size: 18), label: Text(t.formChrome.defaults));

/// The Cancel/Save (+ submitting spinner) row shared by every presenter of
/// a [FormRenderer] — the renderer's own `showActions` footer,
/// [showFormDialog]'s action bar, and `showFormPane`'s pinned footer (which
/// lives in form_pane.dart, and is why this is not private). Only the row
/// lives here; each presenter keeps its own chrome (tinted container,
/// SafeArea, padding) around it, so a change to the submission UX lands in
/// all three at once. Shared no further than those files: the package export
/// hides it.
Widget formActionsRow({
  required bool isSubmitting,
  required VoidCallback? onCancel,
  required VoidCallback? onSave,
  String? saveLabel,
  ({String label, VoidCallback onPressed, Color color, IconData? icon})? destructive,
  ({String label, VoidCallback onPressed})? secondary,
}) {
  // Every label ellipsizes because this footer can carry four verbs at once
  // (the equipment editor's Cancel/Remove/Report/Save) in a language that
  // spells none of them shortly, on a pane that is the whole screen on a
  // phone. haloDialogFooterRow stacks the buttons before it comes to this,
  // and never clips Save at all; clipping a word is the last resort after
  // that, not instead of it.
  Widget label(String text) => Text(text, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis);

  // The layout itself belongs to haloDialogFooterRow, not here: a form's
  // footer and a plain dialog's are the same object to the operator, and
  // when they were two implementations they drifted — the slots below
  // existed only on this one, so plain dialogs improvised them into
  // `actions`. What stays here is what is genuinely the form's: its own
  // labels, the disable-while-submitting rule, and the spinner that replaces
  // Save mid-flight.
  return haloDialogFooterRow(
    // Destructive keeps its colour WITH the action rather than as a second
    // optional beside it: the point of this button is that a destructive verb
    // reads as destructive, and a caller that supplied one and forgot the
    // other would get a Remove button indistinguishable from Cancel.
    destructive: destructive == null
        ? null
        : destructive.icon == null
        ? TextButton(
            style: TextButton.styleFrom(foregroundColor: destructive.color),
            onPressed: isSubmitting ? null : destructive.onPressed,
            child: label(destructive.label),
          )
        : TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: destructive.color),
            onPressed: isSubmitting ? null : destructive.onPressed,
            icon: Icon(destructive.icon),
            label: label(destructive.label),
          ),
    secondary: secondary == null
        ? null
        // Disabled while submitting, like every other control on the form: it
        // opens a dialog of its own (the equipment editor's Report), and a
        // route pushed over a submitting pane is the route `Navigator.pop`
        // takes down when the submit lands — the pane stays open and its
        // values go to whatever was on top instead.
        : TextButton(onPressed: isSubmitting ? null : secondary.onPressed, child: label(secondary.label)),
    cancel: TextButton(onPressed: isSubmitting ? null : onCancel, child: label(t.common.cancel)),
    actions: [
      if (isSubmitting)
        // Occupies the primary's place rather than sitting beside it, so the
        // footer neither grows nor reflows when a submit starts.
        const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
      else
        // The one verb that never gives ground: whatever else gets clipped,
        // the form's own action stays readable.
        FilledButton(onPressed: onSave, child: label(saveLabel ?? t.common.save)),
    ],
  );
}

/// Renders a form from a dynamic JSON definition, coordinating input fields,
/// headers, section dividers, and markdown text blocks. Supports initial state,
/// actions (Submit/Cancel), and asynchronous JS-backed validation and transformation.
class FormRenderer extends StatefulWidget {
  final Map<String, dynamic> formDefinition;
  final Map<String, dynamic> initialState;
  final FormValidator? validator;
  final FormTransformer? transformer;
  final FormOnChange? onChange;
  final FormAction? onAction;

  /// An action's (or an actionable `select` option's) [FormActionResult.elements]
  /// reaching the caller — the caller owns [formDefinition], not this
  /// widget, so applying a new element list means the caller rebuilding
  /// this widget with it, not something this widget can do to itself. Null
  /// means whoever built this [FormRenderer] never wired the result up —
  /// [FormActionResult.elements] is silently dropped rather than crashing,
  /// same as an ignored [FormAction] result already does elsewhere.
  final ValueChanged<List<Map<String, dynamic>>>? onElementsChanged;

  final FormManageAccount? onManageAccount;

  /// Opens a `type: 'link'` element's URL. The renderer stays free of any
  /// url_launcher dependency — the app decides how links open.
  final FormOpenLink? onOpenLink;

  /// Opens the app screen a `type: 'link'` element names with `panel`
  /// instead of a `url`. App-side only — no extension surface wires it, so
  /// such a link is inert there.
  final FormOpenPanel? onOpenPanel;
  final void Function(Map<String, dynamic> values) onSubmit;
  final VoidCallback onCancel;
  final bool showActions;
  final bool showTitle;
  final ValueNotifier<bool>? submittingNotifier;

  /// Whether elements marked `devMode: true` in the definition are shown at
  /// all — hidden entirely (not just disabled) when false, the default.
  final bool developerMode;

  /// Renames the submit button for a form that does not save anything — the
  /// radio report sends one. The only chrome word any caller has wanted to
  /// change; everything else reads the current locale's `t` directly.
  final String? saveLabel;

  /// Whether this form IS a settings list rather than a form to fill in —
  /// the settings panels, a target-scoped settings dialog, a panel's own
  /// configuration (docs/design/user-interface.md § Settings lists).
  ///
  /// A settings list renders every field it can as a settings ROW: bold
  /// title, the description underneath, the whole row working the toggle,
  /// and a tap opening the editor for anything that isn't one. A form
  /// renders the same field as a control to type into.
  ///
  /// The distinction belongs to the SURFACE, not to the element: a settings
  /// row whose element happens to declare no icon is still a settings row,
  /// with nothing in the leading slot. Read off the element it made the row
  /// shape an accident of whoever wrote the declaration, which is how a
  /// panel of extension settings comes out looking nothing like the panel
  /// beside it.
  final bool settingsList;

  /// Whether this form renders as a SLIVER rather than a box.
  ///
  /// A section band pins — it holds the top of the viewport while its own
  /// rows scroll under it — and only a sliver can do that. A form in a
  /// [CustomScrollView] asks for this and takes the whole space of one
  /// sliver; anywhere else the box form is what fits, and its bands scroll
  /// with the rows.
  final bool sliver;

  /// Keeps each `style: 'section'` header's fold past this form. Null, a
  /// fold lasts as long as the form does.
  final FormSectionFolds? sectionFolds;

  const FormRenderer({
    super.key,
    required this.formDefinition,
    required this.initialState,
    this.validator,
    this.transformer,
    this.onChange,
    this.onAction,
    this.onElementsChanged,
    this.onManageAccount,
    this.onOpenLink,
    required this.onSubmit,
    required this.onCancel,
    this.showActions = true,
    this.showTitle = true,
    this.submittingNotifier,
    this.developerMode = false,
    this.saveLabel,
    this.settingsList = false,
    this.sliver = false,
    this.onOpenPanel,
    this.sectionFolds,
  });

  @override
  State<FormRenderer> createState() => FormRendererState();

  /// [elements] as one source's contribution to a list others add to: with a
  /// `sectionEnd` after them when they leave a band open, so whatever is
  /// appended next is not drawn under — and folded away with — their last
  /// section.
  static List<Map<String, dynamic>> closingSections(List<Map<String, dynamic>> elements) {
    final open = elements.lastWhere((el) => FormRendererState._isBand(el) || el['type'] == 'sectionEnd', orElse: () => const {});
    return FormRendererState._isBand(open)
        ? [
            ...elements,
            {'type': 'sectionEnd'},
          ]
        : elements;
  }
}

class FormRendererState extends State<FormRenderer> with _ListFields, _Elements, _RowFields, _TextFields, _ChoiceFields {
  @override
  final Map<String, dynamic> _values = {};
  @override
  final Map<String, TextEditingController> _controllers = {};
  @override
  final Map<String, FocusNode> _focusNodes = {};
  @override
  final Map<String, String> _errors = {};
  @override
  final Set<String> _runningActions = {};
  @override
  bool _isSubmitting = false;

  /// The `type: 'disclosure'` groups the operator has opened, by key. Every
  /// one starts closed: a disclosure holds what most people never need to
  /// touch, and opening it is the operator's call.
  @override
  final Set<String> _openDisclosures = {};

  /// The sections opened or shut while this form is up, by
  /// [_sectionName]. Ahead of [FormRenderer.sectionFolds], so a section
  /// opened to show an error stays open without becoming the operator's
  /// remembered choice.
  final Map<String, bool> _openSections = {};

  /// Bumped after every action runs, and folded into every `select` field's
  /// widget key. `DropdownButtonFormField` tracks which item is selected
  /// internally once built — an `isAction` option stays visually "selected"
  /// after being tapped no matter what `onChanged` does with `_values`, so
  /// the fix is forcing the field to remount from `_values` fresh rather
  /// than trying to talk it out of what it already decided.
  @override
  int _actionGeneration = 0;

  List<Map<String, dynamic>> get _elements => _shown(widget.formDefinition['elements']);

  List<Map<String, dynamic>> _shown(Object? elements) =>
      (elements as List? ?? const []).cast<Map<String, dynamic>>().where((el) => el['devMode'] != true || widget.developerMode).toList();

  /// A `type: 'disclosure'` or `type: 'row'` element's own members — the
  /// fold or the row owns them.
  @override
  List<Map<String, dynamic>> _members(Map<String, dynamic> group) => _shown(group['elements']);

  /// Whether [el] holds members of its own rather than being one. Groups
  /// nest — a row of fields inside a fold — and a field is a field at any
  /// depth ([_fieldsAmong]).
  static bool _isGroup(Map<String, dynamic> el) => el['type'] == 'disclosure' || el['type'] == 'row';

  /// The orange "dev mode" accent for an element flagged `devMode: true` —
  /// null once [_elements] has already excluded it, so no builder needs its
  /// own visibility check, only this color check.
  @override
  Color? _devModeColor(Map<String, dynamic> el) => el['devMode'] == true ? HaLoColors.of(context).devMode : null;

  /// Every row (ListTile-based or not) aligns to the SAME inset: whatever an
  /// ancestor `ListTileTheme` declares as its default `contentPadding` (e.g.
  /// settings_view.dart's wide-layout wrapper), or none at all for every
  /// other FormRenderer caller (dialogs, embedded forms), which keep the
  /// flush-left look those callers already size their own container for.
  ///
  /// None while a `row` builds its members: the row takes the inset once,
  /// around them all, and a member taking it too would open the inset's
  /// width twice over between each pair.
  @override
  EdgeInsetsGeometry get _rowContentPadding => _buildingRowMembers ? EdgeInsets.zero : ListTileTheme.of(context).contentPadding ?? EdgeInsets.zero;

  @override
  bool _buildingRowMembers = false;

  /// Every field, a group's members included: a field inside a closed fold
  /// is registered, validated and submitted like any other.
  List<Map<String, dynamic>> get _fields => _fieldsAmong(_elements);

  /// The fields among [elements], a group's at any depth: a field one group
  /// further down that went unregistered would render against no controller
  /// and drop what is typed into it.
  List<Map<String, dynamic>> _fieldsAmong(List<Map<String, dynamic>> elements) => [
    for (final el in elements)
      if (_isGroup(el)) ..._fieldsAmong(_members(el)) else if (el['type'] == 'field') el,
  ];

  /// [_elements] minus any whose `visibleWhen` predicate doesn't currently
  /// hold (docs/design/contests.md §5.4.1) — IARU HF's setup shows one of three
  /// sent-exchange fields depending on the station type chosen in the same
  /// form, which no static definition and no `onChange` closure can express
  /// across the extension bridge.
  ///
  /// **Only [build] may use this.** [_fields] — and therefore field
  /// registration, [_initializeFormState] and [submit] — stays deliberately
  /// unfiltered: [_buildField] passes `controller: _controllers[key]` with no
  /// lazy creation, so a field first initialized when it became visible would
  /// render against a null controller and silently drop everything typed into
  /// it. Registering every declared field up front is what makes that
  /// impossible.
  ///
  /// The consequence is that a hidden field still submits its value, which is
  /// the behaviour we want: type a zone, switch to HQ, switch back, and the
  /// zone is still there. A form's consumer must therefore choose by the
  /// discriminator field, never by "first non-empty".
  ///
  /// Reads [_values], so any field's `setState` re-evaluates visibility.
  ///
  /// A group shows only while at least one of its members' `visibleWhen`
  /// holds — a fold with nothing in it would open onto nothing, and an empty
  /// row would still take its gap. Its members are filtered by the same
  /// rules when it renders.
  List<Map<String, dynamic>> get _visibleElements => [
    for (final el in _elements)
      if (_visibleWhenHolds(el) && (!_isGroup(el) || _members(el).any(_visibleWhenHolds))) el,
  ];

  /// Whether [el]'s `visibleWhen` holds. `equals` may be a single value or a
  /// list meaning "any of"; a list of conditions must all hold, so a host can
  /// add its own to one a field declared without replacing it. Naming a
  /// field that doesn't exist reads as null and so hides the element — a
  /// definition that points at nothing shows nothing, rather than throwing
  /// in the middle of someone's setup dialog.
  @override
  bool _visibleWhenHolds(Map<String, dynamic> el) => _conditionHolds(el['visibleWhen']);

  bool _conditionHolds(Object? when) {
    if (when is List) return when.every(_conditionHolds);
    if (when is! Map) return true;
    final actual = _values[when['field']];
    final expected = when['equals'];
    return expected is List ? expected.contains(actual) : actual == expected;
  }

  @override
  void initState() {
    super.initState();
    _initializeFormState();
  }

  @override
  void didUpdateWidget(covariant FormRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.formDefinition, widget.formDefinition)) {
      _syncFieldValuesFromDefinition(oldWidget.formDefinition);
    }
  }

  /// Whether a `select` element's options have STRUCTURE — an identifier of
  /// their own, tags, an icon, a second line — and so are rendered as rows
  /// rather than as a dropdown's one-string items.
  static bool _isRowSelect(Map<String, dynamic> el) {
    if (el['fieldType'] != 'select' || el['options'] is! List) return false;
    return (el['options'] as List).any(
      (opt) => opt is Map && (opt['trailing'] != null || opt['tags'] != null || opt['icon'] != null || opt['subtitle'] != null),
    );
  }

  static List<Map<String, dynamic>> _fieldsIn(Map<String, dynamic> definition) => _declaredFields(definition['elements']);

  static List<Map<String, dynamic>> _declaredFields(Object? elements) => [
    for (final el in (elements as List? ?? const []).cast<Map<String, dynamic>>())
      if (_isGroup(el)) ..._declaredFields(el['elements']) else if (el['type'] == 'field') el,
  ];

  /// A field's `value` here is the source of truth — set by whatever last
  /// called [FormRenderer] with a new [formDefinition] (e.g. a settings
  /// panel re-fetching after a value changed outside this widget entirely,
  /// like a keyboard shortcut). [initState] only ever sees this once, so
  /// without this, [_values] would silently go stale on every subsequent
  /// formDefinition change. A field absent from the OLD definition (e.g.
  /// one that only appears once another field reaches some value) is never
  /// "updated" — it's brand new — so it goes through [_initializeField]
  /// instead, same as every field does on first mount; without that, it
  /// would render with no controller/focus node and silently drop input.
  /// For a field present in both, only overwrites [_values] when it still
  /// matches what the OLD definition said — a field the user has locally
  /// edited but not yet had committed back through [onChange] is left
  /// alone, since here we can't tell that apart from a real external update
  /// racing it.
  void _syncFieldValuesFromDefinition(Map<String, dynamic> oldDefinition) {
    final oldValues = {for (final f in _fieldsIn(oldDefinition)) f['key'] as String: f['value']};
    final changes = <String, dynamic>{};
    final newFields = <Map<String, dynamic>>[];
    for (final field in _fields) {
      final key = field['key'] as String;
      if (!oldValues.containsKey(key)) {
        if (!_values.containsKey(key)) newFields.add(field);
        continue;
      }
      final newVal = field['value'];
      if (newVal != oldValues[key] && _values[key] == oldValues[key]) {
        changes[key] = newVal;
      }
    }
    // A select whose OPTIONS changed under a value that is still the same —
    // the port picker refreshing while the operator holds the dropdown open
    // and pulls the cable. `DropdownButton` asserts its value is exactly one
    // of its items, so leaving it would throw where the form should simply
    // stop claiming a port that is gone. Same rule [_initializeField] applies
    // to a seeded value, for the same reason, one definition later.
    for (final field in _fields) {
      if (field['fieldType'] != 'select') continue;
      // ONLY where the control would otherwise throw. A [RowSelectField]
      // renders a value its rows no longer offer as an empty field, so
      // nulling it there would be pure loss: the port picker refreshes every
      // few seconds, and a radio switched off mid-edit would have its stored
      // port replaced by null on the next tick and written away on Save.
      if (_isRowSelect(field)) continue;
      final key = field['key'] as String;
      if (_values[key] == null || changes.containsKey(key)) continue;
      final options = (field['options'] as List?)?.cast<Map<dynamic, dynamic>>() ?? const [];
      if (options.isNotEmpty && !options.any((opt) => opt['value'] == _values[key])) {
        changes[key] = null;
      }
    }
    if (changes.isEmpty && newFields.isEmpty) return;
    setState(() {
      for (final entry in changes.entries) {
        _values[entry.key] = entry.value;
        final controller = _controllers[entry.key];
        final text = _controllerTextFor(entry.key, entry.value);
        if (controller != null && controller.text != text) {
          controller.text = text;
        }
      }
      for (final field in newFields) {
        _initializeField(field);
      }
    });
  }

  void _initializeFormState() {
    for (final field in _fields) {
      _initializeField(field);
    }
  }

  void _initializeField(Map<String, dynamic> field) {
    final key = field['key'] as String;
    final fieldType = field['fieldType'] as String;
    var val = widget.initialState[key] ?? field['value'];
    // `!_isRowSelect`, the same exemption the refresh path takes and for the
    // same reason: that control renders a value its rows do not offer rather
    // than asserting on it. Dropped here instead, an operator opening the
    // editor of a radio that is switched off — to rename it, or change its
    // baud rate — would find its port silently cleared and Save refused on a
    // field they never touched.
    if (fieldType == 'select' && val != null && !_isRowSelect(field)) {
      // The state a field is seeded from OUTLIVES the options it is offered.
      // An extension's option list can depend on the rest of the form — State
      // Parks offers Texas three power classes and Ohio two — while the value
      // persists on the ref, so switching that operation to Ohio leaves a `QRP`
      // no Ohio dropdown has an item for. `DropdownButton` asserts that its
      // value is exactly one of its items, so the form would throw instead of
      // rendering. Dropping it here also means Save clears it, rather than
      // writing back a value nothing downstream will honour.
      final options = (field['options'] as List?)?.cast<Map<dynamic, dynamic>>() ?? const [];
      if (options.isNotEmpty && !options.any((opt) => opt['value'] == val)) {
        val = options.any((opt) => opt['value'] == field['value']) ? field['value'] : null;
      }
    }
    if (val == null) {
      if (fieldType == 'checkbox') {
        val = false;
      } else if (fieldType == 'list') {
        val = <Map<String, dynamic>>[];
      } else if (fieldType == 'multiselect' || fieldType == 'checkboxGroup') {
        val = <String>[];
      } else if (['select', 'radio', 'number', 'account'].contains(fieldType)) {
        val = null;
      } else {
        val = '';
      }
    }
    _values[key] = val;

    final focusNode = FocusNode();
    _focusNodes[key] = focusNode;

    if (['text', 'multiline', 'textTemplate', 'email', 'callsign', 'number', 'secret'].contains(fieldType)) {
      // A number is SHOWN in the operator's own conventions and read back in
      // the same ones — see `_numberText`. `toString()` here would print a
      // period into a field whose decimal key types a comma, so the first
      // edit of an untouched value would make it unparseable.
      final controller = TextEditingController(text: fieldType == 'number' ? _numberText(val) : val?.toString() ?? '');
      _controllers[key] = controller;
      controller.addListener(() {
        final text = controller.text;
        dynamic parsed = text;
        if (fieldType == 'number') {
          parsed = parseLocalizedNumber(text);
        }
        if (_values[key] != parsed) {
          setState(() {
            _values[key] = parsed;
            _errors.remove(key);
          });
        }
      });

      focusNode.addListener(() {
        if (!focusNode.hasFocus) {
          _handleFieldBlurOrInteraction(key, _values[key]);
        }
      });
    } else if (fieldType == 'select') {
      focusNode.onKeyEvent = (node, event) => _handleSelectKeyEvent(key, event);
    }
  }

  /// Up/Down cycle a focused-but-closed `select` field through its options,
  /// wrapping at either end — `DropdownButtonFormField`'s own arrow-key
  /// handling only kicks in once its popup menu is open, so a field that is
  /// merely focused otherwise ignores the keys entirely.
  KeyEventResult _handleSelectKeyEvent(String key, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final logicalKey = event.logicalKey;
    if (logicalKey != LogicalKeyboardKey.arrowDown && logicalKey != LogicalKeyboardKey.arrowUp) {
      return KeyEventResult.ignored;
    }
    if (_isSubmitting) return KeyEventResult.ignored;
    final field = _fields.firstWhere((f) => f['key'] == key, orElse: () => const {});
    // Belt-and-braces: this path bypasses the button's own onChanged, so an
    // arrow key would otherwise set a value the tap handler refuses. Today a
    // disabled DropdownButtonFormField will not take focus at all, so the
    // event cannot arrive — that is asserted in form_renderer_test.dart, and
    // it is exactly the kind of thing a Flutter upgrade changes quietly.
    if (field['disabled'] == true) return KeyEventResult.ignored;
    // Actionable options are not values, so they are not part of the cycle:
    // arrowing onto the web serial transport's "Add a USB device…" would
    // write the ACTION's key into the field and commit it below, which is
    // the very thing both tap handlers take care to refuse.
    final options = ((field['options'] as List?)?.cast<Map<String, dynamic>>() ?? const <Map<String, dynamic>>[])
        .where((opt) => opt['isAction'] != true)
        .toList();
    if (options.isEmpty) return KeyEventResult.ignored;

    final delta = logicalKey == LogicalKeyboardKey.arrowDown ? 1 : -1;
    final currentIndex = options.indexWhere((opt) => opt['value'] == _values[key]);
    final nextIndex = currentIndex < 0 ? (delta > 0 ? 0 : options.length - 1) : (currentIndex + delta) % options.length;
    final nextValue = options[nextIndex]['value'];

    setState(() {
      _values[key] = nextValue;
      _errors.remove(key);
    });
    _handleFieldBlurOrInteraction(key, nextValue);
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final fn in _focusNodes.values) {
      fn.dispose();
    }
    super.dispose();
  }

  /// A `number` field's stored value as the operator would write it.
  ///
  /// Empty for null, which is what an unset field and an unparseable entry
  /// both arrive as — the field shows nothing rather than the word "null".
  static String _numberText(dynamic value) => value is num ? formatLocalizedNumber(value) : (value?.toString() ?? '');

  /// The controller text for [key]'s [value], in the operator's own number
  /// conventions when [key] is a `number` field.
  ///
  /// Writing a controller directly BYPASSES the input formatter, so the raw
  /// `toString()` a non-number field wants would put a period into a field
  /// the controller listener then reads with the comma conventions in force:
  /// a hook answering `1.5` would be stored back as 15. Every path that
  /// pushes a value into an existing controller goes through here.
  @override
  String _controllerTextFor(String key, dynamic value) {
    final field = _fields.firstWhere((f) => f['key'] == key, orElse: () => const {});
    return field['fieldType'] == 'number' ? _numberText(value) : (value?.toString() ?? '');
  }

  /// Merges externally-supplied values (an `onChange` result, an action's
  /// [FormActionResult.fieldUpdates]) into [_values], keeping any live
  /// `TextEditingController` in sync — a `select`/`checkbox`/etc. field
  /// reads `_values` directly each build, but a text-type field's on-screen
  /// text is the controller's, not `_values`', so `setState` alone would
  /// update the model without the operator seeing it change.
  @override
  void _applyFieldUpdates(Map<String, dynamic> updates) {
    if (updates.isEmpty || !mounted) return;
    setState(() {
      for (final entry in updates.entries) {
        _values[entry.key] = entry.value;
        final controller = _controllers[entry.key];
        final text = _controllerTextFor(entry.key, entry.value);
        if (controller != null && controller.text != text) {
          controller.text = text;
        }
      }
    });
  }

  @override
  Future<void> _handleFieldBlurOrInteraction(String key, dynamic value) async {
    if (widget.onChange != null) {
      try {
        final updates = await widget.onChange!(key, value, _values);
        if (updates != null) _applyFieldUpdates(updates);
      } catch (e) {
        debugPrint('Error running onChange for $key: $e');
      }
    }

    if (widget.validator != null) {
      final error = await widget.validator!(key, value, _values);
      if (!mounted) return;
      setState(() {
        if (error != null && error.isNotEmpty) {
          _errors[key] = error;
        } else {
          _errors.remove(key);
        }
      });
    }
  }

  @override
  Iterable<String>? _getAutofillHints(String key, String fieldType) {
    if (fieldType == 'email') {
      return const [AutofillHints.email];
    }
    if (fieldType == 'text') {
      final k = key.toLowerCase();
      if (k.contains('name')) {
        return const [AutofillHints.name];
      }
      if (k.contains('phone') || k.contains('tel')) {
        return const [AutofillHints.telephoneNumber];
      }
      if (k.contains('address')) {
        return const [AutofillHints.fullStreetAddress];
      }
    }
    return null;
  }

  Future<void> submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _errors.clear();
    });
    widget.submittingNotifier?.value = true;

    final errors = <String, String>{};
    final transformedValues = <String, dynamic>{..._values};

    for (final field in _fields) {
      final key = field['key'] as String;
      final val = _values[key];

      // Validate
      if (widget.validator != null) {
        try {
          final error = await widget.validator!(key, val, _values);
          if (error != null && error.isNotEmpty) {
            errors[key] = error;
          }
        } catch (e) {
          errors[key] = t.formChrome.validationError(error: e.toString());
        }
      }

      // Transform if valid
      if (errors[key] == null && widget.transformer != null) {
        try {
          final transformed = await widget.transformer!(key, val, _values);
          transformedValues[key] = transformed;
        } catch (e) {
          errors[key] = t.formChrome.transformationError(error: e.toString());
        }
      }
    }

    if (mounted) {
      setState(() {
        _isSubmitting = false;
        widget.submittingNotifier?.value = false;
        if (errors.isNotEmpty) {
          _errors.addAll(errors);

          // An error inside a closed disclosure would block the save with
          // nothing on screen saying why.
          var opened = false;
          for (final el in _elements) {
            if (el['type'] == 'disclosure' && _fieldsAmong(_members(el)).any((field) => errors.containsKey(field['key']))) {
              opened = _openDisclosures.add(el['key'] as String) || opened;
            }
          }
          for (final (:band, :rows) in _sections(_visibleElements)) {
            if (band == null || !_folds(band) || _sectionIsOpen(band)) continue;
            if (rows.any((el) => errors.containsKey(el['key']) || (_isGroup(el) && _fieldsAmong(_members(el)).any((m) => errors.containsKey(m['key']))))) {
              _openSections[_sectionName(band)] = opened = true;
            }
          }

          // Scroll first error into view
          for (final field in _fields) {
            final key = field['key'] as String;
            if (errors.containsKey(key)) {
              final node = _focusNodes[key];
              // A fold opened in this same setState still holds its fields out
              // of the focus order until it rebuilds, and a request made
              // before then is dropped, not deferred.
              if (opened) {
                WidgetsBinding.instance.addPostFrameCallback((_) => node?.requestFocus());
              } else {
                node?.requestFocus();
              }
              break;
            }
          }
        } else {
          widget.onSubmit(transformedValues);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final elements = _visibleElements;
    final child = widget.sliver ? _buildSliver(context, theme, elements) : _buildBox(context, theme, elements);
    // A settings list edits every text-like field in a dialog of its own, so
    // its group would hold no inline field — and disposing a TOPMOST
    // AutofillGroup finishes the platform-wide autofill context, which on iOS
    // closes whatever keyboard is up. A lazy list dropping an offscreen
    // settings form (as a keyboard's inset shrinks the page behind a dialog)
    // would dismiss that dialog's keyboard.
    if (widget.settingsList) return child;
    // An InheritedWidget, so it wraps a sliver as happily as a box.
    return AutofillGroup(child: child);
  }

  Widget _buildBox(BuildContext context, ThemeData theme, List<Map<String, dynamic>> elements) {
    final sections = _sections(elements);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ..._formTitle(context, theme),
        for (final (index, (:band, :rows)) in sections.indexed) ...[
          if (band == null && index > 0 && rows.isNotEmpty) const SizedBox(height: Space.xl),
          if (_spacedAbove(band, sections.take(index))) const SizedBox(height: Space.xl),
          if (band != null) _buildHeader(band, theme, folds: true),
          if (band != null && _folds(band))
            CollapsibleBody(
              expanded: _sectionIsOpen(band),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _elementRows(theme, rows)),
            )
          else
            ..._elementRows(theme, rows),
        ],
        ..._formActions(),
      ],
    );
  }

  /// The same form, as one sliver: every run of rows under a section band is
  /// a group of its own, so the band pins over ITS rows and is pushed off by
  /// the next section's — rather than over the whole form, where every band
  /// would pile up at the top.
  Widget _buildSliver(BuildContext context, ThemeData theme, List<Map<String, dynamic>> elements) {
    final slivers = <Widget>[];
    final title = _formTitle(context, theme);
    if (title.isNotEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: title),
        ),
      );
    }

    final sections = _sections(elements);
    for (final (index, (:band, :rows)) in sections.indexed) {
      if (band == null && rows.isEmpty) continue;
      if (_spacedAbove(band, sections.take(index))) slivers.add(const SliverToBoxAdapter(child: SizedBox(height: Space.xl)));
      // One box per section, not a SliverList: a lazy list builds only what
      // is on screen and DISPOSES what scrolls off it, and these rows own
      // the FocusNodes and TextEditingControllers the operator is typing
      // into — the Settings panel builds every category up front for
      // exactly that reason (settings_view.dart).
      final body = SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (band == null && index > 0) const SizedBox(height: Space.xl),
            ..._elementRows(theme, rows),
          ],
        ),
      );
      slivers.add(
        band == null
            ? body
            : SliverMainAxisGroup(
                slivers: [
                  _pinnedBand(context, band, theme),
                  if (_folds(band)) CollapsingSliver(expanded: _sectionIsOpen(band), child: body) else body,
                ],
              ),
      );
    }

    final actions = _formActions();
    if (actions.isNotEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: actions),
        ),
      );
    }
    return SliverMainAxisGroup(slivers: slivers);
  }

  /// Whether an element heads a section — either style of band. A band is a
  /// header and nothing else: a `style` that strays onto another element
  /// must not silently close the gaps around it.
  static bool _isBand(Map<String, dynamic> el) => el['type'] == 'header' && (el['style'] == 'section' || el['style'] == 'category');

  /// Whether band [el] folds the rows under it: a section does, and a
  /// category — the top of its surface, with nothing above to fold into —
  /// does not.
  static bool _folds(Map<String, dynamic> el) => el['style'] == 'section';

  /// Whether [band] stands off the rows above it. A 'category' band starts a
  /// new top-level grouping, and flush against the last field of the one
  /// before it reads as that field's caption. Outside the band's own pinned
  /// group, so the gap scrolls away with the rows above rather than riding
  /// along under the pinned band. A 'section' band keeps abutting: it is one
  /// section of a continuous list.
  static bool _spacedAbove(Map<String, dynamic>? band, Iterable<({Map<String, dynamic>? band, List<Map<String, dynamic>> rows})> above) =>
      band?['style'] == 'category' && above.any((section) => section.rows.isNotEmpty);

  /// [elements] cut at every band: the rows ahead of the first band, then
  /// each band over the rows up to the next band or `sectionEnd` — which is
  /// all a band ever owns, since the declaration is a flat list. Rows after a
  /// `sectionEnd` belong to no band.
  static List<({Map<String, dynamic>? band, List<Map<String, dynamic>> rows})> _sections(List<Map<String, dynamic>> elements) {
    final sections = [(band: null as Map<String, dynamic>?, rows: <Map<String, dynamic>>[])];
    for (final el in elements) {
      if (_isBand(el)) {
        sections.add((band: el, rows: []));
      } else if (el['type'] == 'sectionEnd') {
        sections.add((band: null, rows: []));
      } else {
        sections.last.rows.add(el);
      }
    }
    return sections;
  }

  static String _sectionName(Map<String, dynamic> band) => switch (band) {
    {'key': final String key} when key.isNotEmpty => key,
    {'title': final String title} => title,
    _ => '',
  };

  /// Open unless the operator shut it, or its header declares
  /// `collapsed: true` and the operator has not opened it.
  @override
  bool _sectionIsOpen(Map<String, dynamic> band) {
    final name = _sectionName(band);
    return _openSections[name] ?? widget.sectionFolds?.isOpen(name) ?? band['collapsed'] != true;
  }

  @override
  void _toggleSection(Map<String, dynamic> band) {
    final name = _sectionName(band);
    final open = !_sectionIsOpen(band);
    setState(() => _openSections[name] = open);
    widget.sectionFolds?.remember(name, open);
  }

  /// [el]'s band, pinned over the rows that follow it.
  Widget _pinnedBand(BuildContext context, Map<String, dynamic> el, ThemeData theme) {
    final title = el['title'] as String? ?? '';
    final color = _devModeColor(el);
    final subtitle = _headerSubtitle(el, theme);
    return el['style'] == 'category'
        ? CategoryBand(title, color: color, subtitle: subtitle, trailing: _bandAction(el)).asPinnedSliver
        : _sectionHeader(el, title, color: color, subtitle: subtitle).asPinnedSliver(context);
  }

  List<Widget> _formTitle(BuildContext context, ThemeData theme) => [
    if (widget.showTitle && widget.formDefinition['title'] != null) ...[
      Text(
        widget.formDefinition['title'] as String,
        style: theme.textTheme.headlineSmall?.copyWith(fontFamily: 'RobotoSlab', fontWeight: FontWeight.bold, color: HaLoColors.of(context).onSurfaceAccent),
      ),
      const SizedBox(height: Space.xs),
    ],
    if (widget.showTitle && widget.formDefinition['subtitle'] != null) ...[
      Text(widget.formDefinition['subtitle'] as String, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      const SizedBox(height: Space.xl),
    ],
  ];

  List<Widget> _formActions() => [
    if (widget.showActions) ...[
      const SizedBox(height: Space.xxl),
      formActionsRow(isSubmitting: _isSubmitting, onCancel: widget.onCancel, onSave: submit, saveLabel: widget.saveLabel),
    ],
  ];

  /// [elements] as rows, with the gaps between them.
  ///
  /// A section band abuts its rows on both sides: it heads the section below
  /// it, and the section above ends where the band starts. A gap either side
  /// would leave it floating between two sections, belonging to neither —
  /// and in the sliver form, where the band sticks as its rows scroll under
  /// it, a gap would be a hole dragged along with it. Hence no gap at either
  /// end of this list: a band is always what a run of rows begins after.
  @override
  List<Widget> _elementRows(ThemeData theme, List<Map<String, dynamic>> elements) => [
    for (final (index, el) in elements.indexed) ...[
      if (index > 0 && !_isBand(el) && !_isBand(elements[index - 1])) const SizedBox(height: Space.xl),
      switch (el['type'] as String?) {
        'header' => _buildHeader(el, theme),
        'divider' => _buildDivider(el, theme),
        'markdown' => _buildMarkdown(el, theme),
        'disclosure' => _buildDisclosure(el, theme),
        'row' => _buildRow(el, theme),
        'field' => NumbersRowExtraKey(extraKey: _numbersRowKeyFor(el), child: _buildField(el, theme)),
        'link' => _buildLink(el, theme),
        'action' => _buildActionElement(el, theme),
        _ => const SizedBox.shrink(),
      },
    ],
  ];

  static const _settingsRowSupportedTypes = {'text', 'multiline', 'email', 'callsign', 'number', 'secret', 'select', 'checkbox'};

  /// Field types that can take the settings-row shape (see
  /// [_buildSettingsRowField]). 'list', 'radio', 'multiselect', 'account'
  /// and 'checkboxGroup' fall back to their normal full-width rendering even
  /// on a settings list — a multi-option or multi-row control has no single
  /// control to hang off a labeled row.
  Widget _buildField(Map<String, dynamic> el, ThemeData theme) {
    final fieldType = el['fieldType'] as String?;
    if (fieldType == 'textTemplate') return _buildTextRow(el, fieldType!, theme);
    // The surface decides, with `icon` as the standing exception: a form
    // whose element asked for the row shape still gets it, which is how
    // several extension forms already read.
    if ((widget.settingsList || el['icon'] != null) && _settingsRowSupportedTypes.contains(fieldType)) {
      return _buildSettingsRowField(el, fieldType!, theme);
    }

    final key = el['key'] as String;
    final label = el['label'] as String? ?? '';
    final placeholder = el['placeholder'] as String?;
    // `options` may be an app-resolved '$name' String that a caller failed
    // to resolve — degrade to no options instead of crashing the form.
    final options = (el['options'] is List) ? (el['options'] as List).cast<Map<String, dynamic>>() : const <Map<String, dynamic>>[];
    final errorText = _errors[key];
    final devModeColor = _devModeColor(el);

    // A control the surface does NOT render as a row takes the row inset
    // here. A row-shaped field spends it through its own `contentPadding`,
    // and this is the same number from the same theme — so every field in a
    // form lines up whether it came out a row or a box, and a host padding
    // the whole form is not what holds them there. (It cannot be: a filled
    // band runs to the surface's edges, which a padded host would prevent.)
    Widget inset(Widget control) => Padding(padding: _rowContentPadding, child: control);

    switch (fieldType) {
      case 'text':
      case 'multiline':
      case 'email':
      case 'callsign':
      case 'number':
        // One parametrized TextField, same axes _buildCompactControl already
        // uses. Two type-specific behaviors: 'multiline' gets no
        // textInputAction/onSubmitted (Enter must insert a newline, not
        // submit), and 'number' keeps default capitalization — its digit
        // filter makes `uppercase: true` meaningless, and the full-width
        // layout has never honored it there.
        final multiline = fieldType == 'multiline';
        if (fieldType == 'text' && el['suggestions'] is List) {
          return inset(
            SuggestingTextField(
              field: el,
              controller: _controllers[key]!,
              focusNode: _focusNodes[key]!,
              enabled: el['disabled'] != true,
              keyboardType: _keyboardTypeFor(fieldType!),
              textCapitalization: _capitalizationFor(fieldType, el),
              inputFormatters: _inputFormattersFor(fieldType, el),
              decoration: poloFieldDecoration(context, label, hintText: placeholder, errorText: errorText, labelColor: devModeColor),
              onSubmit: submit,
            ),
          );
        }
        return inset(
          TextField(
            selectAllOnFocus: false,
            // See the checkbox's own `disabled` below: greyed rather than
            // hidden, so a field that does not apply here says so instead of
            // sending an operator hunting for it.
            //
            // `disabled` is honoured HERE, on the checkbox and on `select`,
            // and nowhere else. It is still not documented for extension
            // authors: a type that does not implement it renders fully
            // editable, which is worse than the attribute not existing.
            // Implement the type before documenting it — and every way INTO
            // that type, which for `select` is three: the inline dropdown, the
            // settings-row picker dialog, and the arrow keys on a focused one.
            enabled: el['disabled'] != true,
            controller: _controllers[key],
            focusNode: _focusNodes[key],
            maxLines: multiline ? null : 1,
            minLines: multiline ? 3 : null,
            keyboardType: _keyboardTypeFor(fieldType!),
            textCapitalization: fieldType == 'number' ? TextCapitalization.none : _capitalizationFor(fieldType, el),
            inputFormatters: _inputFormattersFor(fieldType, el),
            autofillHints: _getAutofillHints(key, fieldType),
            textInputAction: multiline ? null : TextInputAction.done,
            onSubmitted: multiline ? null : (_) => submit(),
            decoration: poloFieldDecoration(context, label, hintText: placeholder, errorText: errorText, labelColor: devModeColor),
          ),
        );
      case 'secret':
        return inset(
          SecretTextField(
            controller: _controllers[key],
            focusNode: _focusNodes[key],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => submit(),
            decoration: poloFieldDecoration(context, label, hintText: placeholder, errorText: errorText, labelColor: devModeColor),
          ),
        );
      case 'list':
        return _buildListField(el, theme);
      case 'multiselect':
        return _buildMultiselectField(el, theme);
      case 'checkboxGroup':
        // Inset here, not inside: it is a label over a Wrap of checkboxes,
        // with no row of its own to spend the inset through.
        return inset(_buildCheckboxGroupField(el, theme));
      case 'account':
        return _buildAccountField(el, theme);
      case 'select':
        // An option list whose entries have STRUCTURE — an identifier of
        // their own, short tags — cannot be said in the one string a
        // DropdownMenuItem takes. The serial port picker is the case: a
        // column of near-identical device names is unscannable inline, and
        // has to be a column. Every other select is untouched.
        if (_isRowSelect(el)) {
          return inset(
            RowSelectField(
              label: label,
              value: _values[key],
              focusNode: _focusNodes[key],
              errorText: errorText,
              placeholder: placeholder,
              labelColor: devModeColor,
              enabled: !_isSubmitting && el['disabled'] != true,
              rows: [
                for (final opt in options)
                  SelectRow(
                    value: opt['value'],
                    name: opt['label'] as String? ?? '',
                    tags: ((opt['tags'] as List?) ?? const []).cast<String>(),
                    trailing: opt['trailing'] as String?,
                    icon: opt['icon'] as String?,
                    subtitle: opt['subtitle'] as String?,
                    emphasis: opt['emphasis'] == true,
                  ),
              ],
              onChanged: (val) {
                // The same `isAction` contract the dropdown honours below: the
                // web serial transport's "Add a USB device…" lives IN the port
                // list, and picking it must run `requestPort()` rather than
                // become the field's value. Missed here, the form stores the
                // action's key as the port and Save writes that into the
                // config — and only on a browser with a device already granted,
                // since it takes one structured option to reach this branch at
                // all.
                final picked = options.firstWhere((o) => o['value'] == val, orElse: () => const {});
                if (picked['isAction'] == true) {
                  unawaited(_runAction(val as String, picked['method'] as String? ?? ''));
                  return;
                }
                setState(() {
                  _values[key] = val;
                  _errors.remove(key);
                });
                _handleFieldBlurOrInteraction(key, val);
              },
            ),
          );
        }
        return inset(
          DropdownButtonFormField<dynamic>(
            // See _actionGeneration: forces a remount from the true
            // _values[key] after any action runs, since this widget
            // otherwise keeps showing whatever item was last tapped —
            // including an isAction option that never became the value.
            key: ValueKey('$key-$_actionGeneration'),
            initialValue: _values[key],
            focusNode: _focusNodes[key],
            icon: dropdownTrailingIcon,
            menuMaxHeight: dropdownMenuMaxHeight(context),
            // Fill the field rather than taking the width of the widest OPTION,
            // which is what an unexpanded dropdown does — one long label (a
            // contest sponsor's own description of an entry category, say)
            // would overflow the whole dialog to the right, for every extension.
            isExpanded: true,
            decoration: poloFieldDecoration(context, label, hintText: placeholder, errorText: errorText, labelColor: devModeColor),
            hint: placeholder != null ? Text(placeholder) : null,
            items: [
              for (final opt in options)
                DropdownMenuItem(
                  value: opt['value'],
                  child: Text(opt['label'] as String, style: optionEmphasisStyle(opt, options)),
                ),
            ],
            // Greyed rather than hidden, same as the text field's and the
            // checkbox's — a choice that cannot be made right now should say
            // so where it is, not vanish and send the operator hunting. The
            // Antenna Genius' routing picker on a port that is transmitting is
            // the case this exists for: offering it, taking the tap and having
            // the driver refuse it puts the form's value out of step with the
            // hardware, and the refusal lands on a panel behind the pane where
            // the operator cannot see it.
            onChanged: _isSubmitting || el['disabled'] == true
                ? null
                : (val) {
                    // An `isAction` option (the web serial transport's
                    // "add a USB device", so far, sitting right in the port
                    // list rather than as a separate button) never becomes
                    // this field's value — picking it runs an action instead,
                    // same contract a `type: 'action'` element's button uses.
                    // Leaving `val` unselected here (rather than setting it
                    // then reverting it once the action resolves) means there
                    // is nothing to revert if the operator cancels the
                    // browser's own picker partway through.
                    final picked = options.firstWhere((o) => o['value'] == val, orElse: () => const {});
                    if (picked['isAction'] == true) {
                      unawaited(_runAction(val as String, picked['method'] as String? ?? ''));
                      return;
                    }
                    setState(() {
                      _values[key] = val;
                      _errors.remove(key);
                    });
                    _handleFieldBlurOrInteraction(key, val);
                  },
          ),
        );
      case 'radio':
        // Not inset whole: the options below ARE rows and spend the inset
        // through their own contentPadding. What is left — the group's
        // label, and its error — has to take it here, or it hangs off the
        // edge of the options it names.
        return Focus(
          focusNode: _focusNodes[key],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              inset(Text(label, style: theme.textTheme.labelMedium?.copyWith(color: devModeColor ?? theme.colorScheme.onSurfaceVariant))),
              const SizedBox(height: Space.xs),
              for (final opt in options)
                RadioListTile<dynamic>(
                  title: Text(opt['label'] as String),
                  value: opt['value'],
                  // Flutter 3.32 moved the group value to a RadioGroup
                  // ancestor. Migrating changes how a radio's selection is
                  // wired, which is a form-renderer change of its own, not
                  // an analyzer one — HALO-534.
                  // ignore: deprecated_member_use
                  groupValue: _values[key],
                  // ignore: deprecated_member_use
                  onChanged: _isSubmitting
                      ? null
                      : (val) {
                          setState(() {
                            _values[key] = val;
                            _errors.remove(key);
                          });
                          _handleFieldBlurOrInteraction(key, val);
                        },
                  contentPadding: _rowContentPadding,
                  dense: true,
                ),
              if (errorText != null)
                inset(
                  Padding(
                    padding: const EdgeInsets.only(top: Space.xs),
                    child: Text(errorText, style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
                  ),
                ),
            ],
          ),
        );
      case 'segmented':
        // A `radio` group laid out as one control: for a short, exclusive
        // choice (two or three words) that decides what the rest of the form
        // asks for, so the whole choice reads at a glance.
        final description = el['description'] as String?;
        return Focus(
          focusNode: _focusNodes[key],
          child: inset(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(label, style: theme.textTheme.labelMedium?.copyWith(color: devModeColor ?? theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: Space.sm),
                SegmentedButton<dynamic>(
                  segments: [for (final opt in options) ButtonSegment<dynamic>(value: opt['value'], label: Text(opt['label'] as String))],
                  selected: {if (_values[key] != null) _values[key]},
                  emptySelectionAllowed: _values[key] == null,
                  showSelectedIcon: false,
                  onSelectionChanged: _isSubmitting
                      ? null
                      : (selection) {
                          if (selection.isEmpty) return;
                          final val = selection.first;
                          setState(() {
                            _values[key] = val;
                            _errors.remove(key);
                          });
                          _handleFieldBlurOrInteraction(key, val);
                        },
                ),
                if (description != null && description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: Space.xs),
                    child: Text(description, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ),
                if (errorText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: Space.xs),
                    child: Text(errorText, style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
                  ),
              ],
            ),
          ),
        );
      case 'checkbox':
        // `disabled` shows the row greyed rather than hiding it (which is
        // what `environment` does): a toggle that vanishes in some states
        // leaves an operator hunting for a setting they remember, where a
        // greyed one with a description says why it does not apply here.
        final disabled = el['disabled'] == true;
        return Focus(
          focusNode: _focusNodes[key],
          child: CheckboxListTile(
            title: Text(label, style: devModeColor == null ? null : TextStyle(color: devModeColor)),
            value: _values[key] == true,
            onChanged: _isSubmitting || disabled
                ? null
                : (val) {
                    final finalVal = val ?? false;
                    setState(() {
                      _values[key] = finalVal;
                      _errors.remove(key);
                    });
                    _handleFieldBlurOrInteraction(key, finalVal);
                  },
            contentPadding: _rowContentPadding,
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
            subtitle: errorText != null ? Text(errorText, style: TextStyle(color: theme.colorScheme.error, fontSize: 12)) : null,
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

/// Helper function to display the FormRenderer inside an AlertDialog.
Future<Map<String, dynamic>?> showFormDialog(
  BuildContext context, {
  required Map<String, dynamic> formDefinition,
  required Map<String, dynamic> initialState,
  FormValidator? validator,
  FormTransformer? transformer,
  FormOnChange? onChange,
  FormAction? onAction,
  FormManageAccount? onManageAccount,
  FormOpenLink? onOpenLink,
  bool developerMode = false,
  String? saveLabel,
  bool settingsList = false,

  /// A destructive action for the footer's leading edge, as
  /// `showFormPane`'s: the dialog closes first, completing with null, and
  /// then the callback runs.
  ({String label, VoidCallback onPressed, Color color, IconData? icon})? destructiveAction,
}) {
  final theme = Theme.of(context);
  final formKey = GlobalKey<FormRendererState>();
  final submittingNotifier = ValueNotifier<bool>(false);

  return showHaloDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    builder: (context) => HaloDialog(
      wide: true,
      // The shell supplies the header band, its padding AND the title type
      // (the view-header style), so only the subtitle styles itself.
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(formDefinition['title'] as String? ?? t.formChrome.formTitle),
          if (formDefinition['subtitle'] != null) ...[
            const SizedBox(height: Space.xs),
            Text(formDefinition['subtitle'] as String, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ],
      ),
      // A settings list takes the shell's own list padding — rows to the
      // card's edges, contents inset — rather than a form's prose padding.
      list: settingsList,
      contentPadding: settingsList ? null : const EdgeInsets.fromLTRB(Space.xxl, Space.xl, Space.xxl, Space.xl),
      // Width comes from the shared sizing, and the shell scrolls the body.
      content: FormRenderer(
        key: formKey,
        formDefinition: formDefinition,
        initialState: initialState,
        validator: validator,
        transformer: transformer,
        onChange: onChange,
        onAction: onAction,
        onManageAccount: onManageAccount,
        onOpenLink: onOpenLink,
        developerMode: developerMode,
        settingsList: settingsList,
        showActions: false,
        showTitle: false,
        submittingNotifier: submittingNotifier,
        onSubmit: (values) => Navigator.of(context).pop(values),
        onCancel: () => Navigator.of(context).pop(null),
      ),
      // The shell's footer band supplies the background and padding.
      actions: [
        ValueListenableBuilder<bool>(
          valueListenable: submittingNotifier,
          builder: (context, isSubmitting, _) => formActionsRow(
            saveLabel: saveLabel,
            isSubmitting: isSubmitting,
            onCancel: () => Navigator.of(context).pop(null),
            onSave: () => formKey.currentState?.submit(),
            destructive: destructiveAction == null
                ? null
                : (
                    label: destructiveAction.label,
                    color: destructiveAction.color,
                    icon: destructiveAction.icon,
                    // This context is the dialog's own, so the pop is too.
                    onPressed: () {
                      Navigator.of(context).pop(null);
                      destructiveAction.onPressed();
                    },
                  ),
          ),
        ),
      ],
    ),
  );
}
