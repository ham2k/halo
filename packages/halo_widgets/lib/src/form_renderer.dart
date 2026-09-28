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
import 'halo_dialog.dart';
import 'icon_resolver.dart';
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

typedef FormValidator = Future<String?> Function(String fieldKey, dynamic value, Map<String, dynamic> state);
typedef FormTransformer = Future<dynamic> Function(String fieldKey, dynamic value, Map<String, dynamic> state);
typedef FormOnChange = Future<Map<String, dynamic>?> Function(String fieldKey, dynamic value, Map<String, dynamic> state);
typedef FormAction = Future<FormActionResult?> Function(String actionKey, String method, Map<String, dynamic> state);
typedef FormManageAccount = void Function(String accountKey, String? subkey);
typedef FormOpenLink = void Function(String url);
typedef FormOpenPanel = void Function(String panelKey);

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

/// The three callbacks a `fieldType: 'list'` editor needs — built by
/// `_FormRendererState._listFieldActions`, shared by both presentations
/// (`_buildInlineListField`'s inline rows and `_openListEditor`'s dialog).
class _ListFieldActions {
  final Future<void> Function(int? index) editItem;
  final void Function(int index) deleteItem;
  final void Function(int oldIndex, int newIndex) reorder;

  const _ListFieldActions({required this.editItem, required this.deleteItem, required this.reorder});
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
  });

  @override
  State<FormRenderer> createState() => FormRendererState();
}

class FormRendererState extends State<FormRenderer> {
  final Map<String, dynamic> _values = {};
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  final Map<String, String> _errors = {};
  final Set<String> _runningActions = {};
  bool _isSubmitting = false;

  /// Bumped after every action runs, and folded into every `select` field's
  /// widget key. `DropdownButtonFormField` tracks which item is selected
  /// internally once built — an `isAction` option stays visually "selected"
  /// after being tapped no matter what `onChanged` does with `_values`, so
  /// the fix is forcing the field to remount from `_values` fresh rather
  /// than trying to talk it out of what it already decided.
  int _actionGeneration = 0;

  List<Map<String, dynamic>> get _elements => (widget.formDefinition['elements'] as List? ?? const [])
      .cast<Map<String, dynamic>>()
      .where((el) => el['devMode'] != true || widget.developerMode)
      .toList();

  /// The orange "dev mode" accent for an element flagged `devMode: true` —
  /// null once [_elements] has already excluded it, so no builder needs its
  /// own visibility check, only this color check.
  Color? _devModeColor(Map<String, dynamic> el) => el['devMode'] == true ? HaLoColors.of(context).devMode : null;

  /// Every row (ListTile-based or not) aligns to the SAME inset: whatever an
  /// ancestor `ListTileTheme` declares as its default `contentPadding` (e.g.
  /// settings_view.dart's wide-layout wrapper), or none at all for every
  /// other FormRenderer caller (dialogs, embedded forms), which keep the
  /// flush-left look those callers already size their own container for.
  EdgeInsetsGeometry get _rowContentPadding => ListTileTheme.of(context).contentPadding ?? EdgeInsets.zero;

  List<Map<String, dynamic>> get _fields => _elements.where((el) => el['type'] == 'field').toList();

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
  List<Map<String, dynamic>> get _visibleElements => _elements.where(_isVisible).toList();

  /// Whether [el]'s `visibleWhen` holds. `equals` may be a single value or a
  /// list meaning "any of". Naming a field that doesn't exist reads as null and
  /// so hides the element — a definition that points at nothing shows nothing,
  /// rather than throwing in the middle of someone's setup dialog.
  bool _isVisible(Map<String, dynamic> el) {
    final when = el['visibleWhen'];
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

  static List<Map<String, dynamic>> _fieldsIn(Map<String, dynamic> definition) =>
      (definition['elements'] as List? ?? const []).cast<Map<String, dynamic>>().where((el) => el['type'] == 'field').toList();

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

  /// Merges externally-supplied values (an `onChange` result, an action's
  /// [FormActionResult.fieldUpdates]) into [_values], keeping any live
  /// `TextEditingController` in sync — a `select`/`checkbox`/etc. field
  /// reads `_values` directly each build, but a text-type field's on-screen
  /// text is the controller's, not `_values`', so `setState` alone would
  /// update the model without the operator seeing it change.
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

          // Scroll first error into view
          for (final field in _fields) {
            final key = field['key'] as String;
            if (errors.containsKey(key)) {
              _focusNodes[key]?.requestFocus();
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

  Widget _buildBox(BuildContext context, ThemeData theme, List<Map<String, dynamic>> elements) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [..._formTitle(context, theme), ..._elementRows(theme, elements), ..._formActions()],
  );

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

    var section = <Map<String, dynamic>>[];
    Map<String, dynamic>? band;
    void flush() {
      if (section.isEmpty && band == null) return;
      // One box per section, not a SliverList: a lazy list builds only what
      // is on screen and DISPOSES what scrolls off it, and these rows own
      // the FocusNodes and TextEditingControllers the operator is typing
      // into — the Settings panel builds every category up front for
      // exactly that reason (settings_view.dart).
      final rows = SliverToBoxAdapter(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _elementRows(theme, section)),
      );
      slivers.add(band == null ? rows : SliverMainAxisGroup(slivers: [_pinnedBand(context, band!, theme), rows]));
      section = [];
      band = null;
    }

    for (final el in elements) {
      if (_isBand(el)) {
        flush();
        band = el;
      } else {
        section.add(el);
      }
    }
    flush();

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

  /// [el]'s band, pinned over the rows that follow it.
  Widget _pinnedBand(BuildContext context, Map<String, dynamic> el, ThemeData theme) {
    final title = el['title'] as String? ?? '';
    final color = _devModeColor(el);
    final subtitle = _headerSubtitle(el, theme);
    return el['style'] == 'category'
        ? CategoryBand(title, color: color, subtitle: subtitle).asPinnedSliver
        : SectionHeader.pinned(context, title, color: color, subtitle: subtitle);
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
  List<Widget> _elementRows(ThemeData theme, List<Map<String, dynamic>> elements) => [
    for (final (index, el) in elements.indexed) ...[
      if (index > 0 && !_isBand(el) && !_isBand(elements[index - 1])) const SizedBox(height: Space.xl),
      switch (el['type'] as String?) {
        'header' => _buildHeader(el, theme),
        'divider' => _buildDivider(el, theme),
        'markdown' => _buildMarkdown(el, theme),
        'field' => _buildField(el, theme),
        'link' => _buildLink(el, theme),
        'action' => _buildActionElement(el, theme),
        _ => const SizedBox.shrink(),
      },
    ],
  ];

  /// `style: 'section'` renders the settings-panel section band: smaller
  /// type than a form's own title, on the same ground the Operation Setup
  /// sheet's sections take. Opt-in, not the default, because `_buildHeader`
  /// renders `type: 'header'` elements for every FormRenderer caller, not
  /// just settings panels — an ad hoc extension form's own section headers
  /// keep the plain unbanded look unless they explicitly ask for this one.
  /// The band takes its own inset from the ambient ListTileTheme, which is
  /// the same one every row in this form reads, so the section branch skips
  /// [_rowContentPadding] rather than adding a second one on top.
  /// A header's second line, in the ordinary body face — null where the
  /// element declares none. Read by the pinned band too, which builds no
  /// header widget of its own.
  Widget? _headerSubtitle(Map<String, dynamic> el, ThemeData theme) {
    final subtitle = el['subtitle'] as String?;
    if (subtitle == null || subtitle.isEmpty) return null;
    return Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: _devModeColor(el) ?? theme.colorScheme.onSurfaceVariant));
  }

  Widget _buildHeader(Map<String, dynamic> el, ThemeData theme) {
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
    if (el['style'] == 'category') return CategoryBand(title, color: devModeColor, subtitle: subtitleWidget);
    if (!isSection) return Padding(padding: _rowContentPadding, child: content);
    return SectionHeader(title, color: devModeColor, subtitle: subtitleWidget);
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
    // Extension-authored copy, so it needs the emoji font; the dev-mode tint
    // keeps the bare sheet it always used, with only the fallback added.
    final styleSheet = withEmojiFallback(devModeColor == null ? MarkdownStyleSheet.fromTheme(theme) : MarkdownStyleSheet(p: TextStyle(color: devModeColor)));
    if (el['collapsible'] == true) {
      return Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: _CollapsibleMarkdown(
          title: Text(
            el['title'] as String? ?? '',
            style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: devModeColor),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: MarkdownBody(data: text, styleSheet: styleSheet),
          ),
        ),
      );
    }
    return Padding(
      padding: _rowContentPadding,
      child: MarkdownBody(data: text, styleSheet: styleSheet),
    );
  }

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

  /// A text-like icon-row field (`text`/`multiline`/`email`/`callsign`/
  /// `number`/`secret`): a tappable row whose subtitle is what the setting is
  /// currently SET TO, edited in [_openTextDialog] rather than in an inline
  /// input under the title.
  ///
  /// The value leads, not prose about the setting: a settings panel is read
  /// by scanning what everything is set to, and a description restating the
  /// label pushes that off the row. [el]'s `description` fills in only when
  /// there is no value and no placeholder to show — otherwise it belongs in
  /// the editor dialog, where the operator is deciding what to type.
  Widget _buildTextRow(Map<String, dynamic> el, String fieldType, ThemeData theme) {
    final key = el['key'] as String;
    final label = el['label'] as String? ?? '';
    final icon = el['icon'] as String?;
    final errorText = _errors[key];
    final devModeColor = _devModeColor(el);
    final disabled = el['disabled'] == true;

    Widget? subtitle;
    if (errorText != null) {
      subtitle = Text(errorText, style: TextStyle(color: theme.colorScheme.error, fontSize: 12));
    } else {
      final value = _displayValue(el, fieldType);
      final shown = value.isNotEmpty ? value : (el['placeholder'] as String? ?? el['description'] as String? ?? '');
      if (shown.isNotEmpty) {
        subtitle = Text(
          shown,
          style: TextStyle(color: devModeColor),
          // A pasted note or a URL would otherwise grow the row without
          // limit; the dialog is where the whole value is readable.
          maxLines: fieldType == 'multiline' ? 2 : 1,
          overflow: TextOverflow.ellipsis,
        );
      }
    }

    return ListTile(
      contentPadding: _rowContentPadding,
      leading: icon != null ? Icon(resolveIconName(icon), color: devModeColor) : null,
      title: Text(
        label,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: devModeColor),
      ),
      subtitle: fieldType == 'textTemplate'
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ?subtitle,
                TemplateSamplePreview(field: el, value: _displayValue(el, fieldType)),
              ],
            )
          : subtitle,
      trailing: Icon(MdiIcons.chevronRight, color: devModeColor ?? theme.colorScheme.onSurfaceVariant),
      // Greyed rather than hidden, exactly as the inline field was — see the
      // `disabled` note on the text branch of [_buildField].
      enabled: !disabled && !_isSubmitting,
      onTap: () => _openTextDialog(el, fieldType),
      mouseCursor: SystemMouseCursors.click,
    );
  }

  /// What [_buildTextRow] shows for [el]'s current value. A secret is shown
  /// as a fixed-length mask: settings panels are read over shoulders and on
  /// shared screens, and even the LENGTH of a password is more than the row
  /// needs to say to confirm one is stored.
  String _displayValue(Map<String, dynamic> el, String fieldType) {
    // Through the same helper the dialog seeds from, or the row and the
    // editor it opens show one value two ways, a tap apart.
    final raw = _controllerTextFor(el['key'] as String, _values[el['key']]);
    if (raw.isEmpty) return '';
    return fieldType == 'secret' ? '••••••••' : raw;
  }

  /// Opens the editor dialog for a text-like icon-row field and commits what
  /// it comes back with.
  ///
  /// The dialog edits a COPY of the value ([_TextEditDialog] owns its own
  /// controller) and reports it as the dialog closes — by Done, by Escape, or
  /// by a tap outside, since a settings editor has no Cancel to mean
  /// otherwise. It writes back through the live controller, so the listener
  /// that parses and stores the value is the same one inline typing went
  /// through; typing straight into that controller instead would commit every
  /// keystroke to the settings store.
  Future<void> _openTextDialog(Map<String, dynamic> el, String fieldType) async {
    final key = el['key'] as String;
    if (fieldType == 'textTemplate') {
      final text = await showTextTemplateEditor(context, field: el, value: _controllerTextFor(key, _values[key]));
      if (text != null && mounted) _commitTextEdit(el, fieldType, text);
      return;
    }

    await showHaloDialog<void>(
      context: context,
      builder: (dialogContext) => _TextEditDialog(
        label: el['label'] as String? ?? '',
        placeholder: el['placeholder'] as String?,
        fieldType: fieldType,
        initialText: _controllerTextFor(key, _values[key]),
        // Localized like every other text this dialog shows: the Defaults
        // button assigns straight to the controller, bypassing the input
        // formatter, so a raw `1.5` under comma conventions would be read
        // back as 15.
        defaultText: el.containsKey('defaultValue') ? _controllerTextFor(key, el['defaultValue']) : null,
        keyboardType: _keyboardTypeFor(fieldType),
        textCapitalization: fieldType == 'number' ? TextCapitalization.none : _capitalizationFor(fieldType, el),
        inputFormatters: _inputFormattersFor(fieldType, el),
        autofillHints: _getAutofillHints(key, fieldType),
        onClosed: (text) => _commitTextEdit(el, fieldType, text),
      ),
    );
  }

  void _commitTextEdit(Map<String, dynamic> el, String fieldType, String text) {
    final key = el['key'] as String;
    if (!mounted) return;
    final live = _controllers[key];
    if (live != null) {
      live.text = text;
    } else {
      setState(() {
        _values[key] = fieldType == 'number' ? parseLocalizedNumber(text) : text;
        _errors.remove(key);
      });
    }
    unawaited(_handleFieldBlurOrInteraction(key, _values[key]));
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

  /// Digits, a sign, and every mark a keyboard might offer as a decimal
  /// point — [LocalizedDecimalMarkFormatter] normalizes whichever arrives.
  static RegExp _numberFieldCharacters() {
    final marks = {'.', ',', NumberFormatting.instance.decimalSeparator};
    return RegExp('[0-9-${marks.map(RegExp.escape).join()}]');
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
  String _controllerTextFor(String key, dynamic value) {
    final field = _fields.firstWhere((f) => f['key'] == key, orElse: () => const {});
    return field['fieldType'] == 'number' ? _numberText(value) : (value?.toString() ?? '');
  }

  TextInputType? _keyboardTypeFor(String fieldType) => switch (fieldType) {
    'email' => TextInputType.emailAddress,
    'number' => const TextInputType.numberWithOptions(decimal: true, signed: true),
    _ => null,
  };

  /// The one predicate for "does this field force uppercase?": callsign
  /// fields always do; any other text-like field opts in with
  /// `uppercase: true` in its definition (see FormField in the SDK's
  /// types.ts). Both the standard builders (_buildField's text/multiline/
  /// email/callsign cases) and the compact icon-row path derive BOTH
  /// capitalization and formatters from this, so the two layouts can't
  /// disagree on a field's casing.
  bool _isUppercase(String fieldType, Map<String, dynamic> el) => fieldType == 'callsign' || el['uppercase'] == true;

  /// `capitalize: true` — free prose that still starts with a capital, the
  /// middle setting between [_isUppercase]'s whole-field uppercasing and a
  /// field that takes exactly what is typed. Ignored where `uppercase` is
  /// also set: uppercasing has already capitalized the first letter.
  bool _isCapitalized(Map<String, dynamic> el) => el['capitalize'] == true;

  /// The on-screen keyboard's own shift state. A HINT only — no desktop or
  /// web keyboard reads it — which is why the formatters below carry the
  /// same intent as a rule the field actually enforces.
  TextCapitalization _capitalizationFor(String fieldType, Map<String, dynamic> el) => _isUppercase(fieldType, el)
      ? TextCapitalization.characters
      : _isCapitalized(el)
      ? TextCapitalization.sentences
      : TextCapitalization.none;

  List<TextInputFormatter>? _inputFormattersFor(String fieldType, Map<String, dynamic> el) => switch (fieldType) {
    // BOTH marks are admitted and then normalized, rather than a filter
    // built from the configured one. A filter admitting a single mark
    // silently drops the other, and which key the operator's keyboard
    // actually emits is not something this setting controls: a Spanish
    // phone puts a comma on the numeric decimal key whatever the app is
    // set to, and a macOS numpad emits a period regardless of region. So
    // the failure was never "the wrong mark is configured", it was "a
    // keypress vanishes" — and admitting one mark just moves who it
    // happens to.
    //
    // Rewriting rather than accepting both at parse time is what keeps it
    // unambiguous: the field can then only ever contain the configured
    // decimal, so nothing downstream has to guess whether a lone mark in
    // `14.285` was a decimal point or a thousands separator.
    'number' => [FilteringTextInputFormatter.allow(_numberFieldCharacters()), const LocalizedDecimalMarkFormatter()],
    _ =>
      _isUppercase(fieldType, el)
          ? const [UpperCaseTextFormatter()]
          : _isCapitalized(el)
          ? const [CapitalizeFirstLetterTextFormatter()]
          : null,
  };

  /// Sets a `checkbox` field, from the row or from its own Switch.
  void _setToggle(String key, bool value) {
    setState(() {
      _values[key] = value;
      _errors.remove(key);
    });
    _handleFieldBlurOrInteraction(key, value);
  }

  String _listItemTitle(Map<String, dynamic> el, Map<String, dynamic> item) {
    final template = el['itemTitle'] as String?;
    return template != null
        ? _templateString(template, item)
        : item.values.firstWhere((v) => v != null && v.toString().isNotEmpty, orElse: () => '').toString();
  }

  /// A `fieldType: 'list'` field. `inline: true` renders the item rows (with
  /// a reorder handle/delete button per row, and an Add row) directly here
  /// — see [_buildInlineListField]. Otherwise: a single row summarizing the
  /// current items as a comma-separated list; tapping it opens
  /// [_openListEditor]'s dialog where the actual add/edit/delete/reorder
  /// happens.
  Widget _buildListField(Map<String, dynamic> el, ThemeData theme) {
    if (el['inline'] == true) return _buildInlineListField(el, theme);

    final key = el['key'] as String;
    final label = el['label'] as String? ?? '';
    final description = el['description'] as String?;
    final icon = el['icon'] as String?;
    final errorText = _errors[key];
    final items = ((_values[key] as List?) ?? const []).cast<Map<String, dynamic>>();
    final devModeColor = _devModeColor(el);
    final summary = [
      for (final item in items)
        if (_listItemTitle(el, item).isNotEmpty) _listItemTitle(el, item),
    ].join(', ');

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
      onTap: _isSubmitting ? null : () => _openListEditor(el),
      mouseCursor: SystemMouseCursors.click,
    );
  }

  /// `inline: true`'s rendering: the same add/edit/delete/reorder behavior
  /// as [_openListEditor] (both built from [_listFieldActions]), just laid
  /// out directly in the form instead of behind a summary row that opens a
  /// dialog — for a list that IS the section's content (e.g. call-notes'
  /// custom files), not one field among several. Tapping a row (or Add)
  /// still opens the `itemFields` editor dialog; only the outer
  /// reorder/delete/add wrapper is inline instead of a second, nested
  /// dialog.
  Widget _buildInlineListField(Map<String, dynamic> el, ThemeData theme) {
    final key = el['key'] as String;
    final label = el['label'] as String? ?? '';
    final itemLabel = el['itemLabel'] as String? ?? label;
    final orderable = el['orderable'] == true;
    final errorText = _errors[key];
    final items = ((_values[key] as List?) ?? const []).cast<Map<String, dynamic>>();
    final actions = _listFieldActions(context: context, key: key, el: el, items: items, itemLabel: itemLabel);

    Widget rowFor(int index) {
      final title = _listItemTitle(el, items[index]);
      return ListTile(
        key: ValueKey('$key-item-$index'),
        contentPadding: _rowContentPadding,
        // Leading, not trailing (unlike the dialog editor's drag handle) —
        // the drag gesture is scoped to just this icon via the listener
        // below, so it can't be confused with the row's own onTap.
        leading: orderable ? ReorderableDragStartListener(index: index, child: const Icon(MdiIcons.dragHorizontalVariant)) : null,
        title: Text(title.isEmpty ? t.formChrome.untitled : title),
        onTap: _isSubmitting ? null : () => actions.editItem(index),
        trailing: IconButton(
          icon: Icon(MdiIcons.delete, size: 20, semanticLabel: t.formChrome.removeItem),
          onPressed: _isSubmitting ? null : () => actions.deleteItem(index),
        ),
        mouseCursor: SystemMouseCursors.click,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (errorText != null)
          Padding(
            padding: _rowContentPadding,
            child: Text(errorText, style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
          ),
        if (orderable)
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            // onReorderItem hands over already-adjusted indices, so the
            // move-down compensation in `actions.reorder` has to change with
            // the callback — a behaviour change that belongs to HALO-534.
            // ignore: deprecated_member_use
            onReorder: actions.reorder,
            // Otherwise, on a desktop/web (mouse) platform, the framework
            // auto-adds its OWN trailing drag handle to every row — landing
            // right on top of the delete IconButton above. rowFor already
            // wires up its own leading handle via ReorderableDragStartListener.
            buildDefaultDragHandles: false,
            children: [for (var i = 0; i < items.length; i++) rowFor(i)],
          )
        else
          for (var i = 0; i < items.length; i++) rowFor(i),
        Padding(
          padding: _rowContentPadding,
          child: TextButton.icon(
            onPressed: _isSubmitting ? null : () => actions.editItem(null),
            icon: const Icon(MdiIcons.plus, size: 18),
            label: Text(t.formChrome.addItem(label: itemLabel)),
          ),
        ),
      ],
    );
  }

  /// The add/edit/delete/reorder behavior shared by [_buildInlineListField]
  /// and [_openListEditor] — the only thing that differs between the two
  /// presentations is the surrounding chrome (an inline `Column` vs a
  /// `HaloDialog`) and each row's own layout, both of which stay with their
  /// respective callers. [items] is the current value list at the moment
  /// of the call — both callers already re-derive it from `_values[key]`
  /// on every rebuild they care about (the inline field's own `build`, or
  /// the dialog's `StatefulBuilder`), so a plain list is enough; nothing
  /// here needs to re-read it later. [afterCommit], when given, runs right
  /// after a commit's `setState` — only the dialog needs it, to also
  /// refresh its own `StatefulBuilder` (the inline field's `build` already
  /// covers that).
  _ListFieldActions _listFieldActions({
    required BuildContext context,
    required String key,
    required Map<String, dynamic> el,
    required List<Map<String, dynamic>> items,
    required String itemLabel,
    VoidCallback? afterCommit,
  }) {
    final itemFields = (el['itemFields'] as List? ?? const []).cast<Map<String, dynamic>>();

    Future<void> commit(List<Map<String, dynamic>> newItems) async {
      setState(() {
        _values[key] = newItems;
        _errors.remove(key);
      });
      afterCommit?.call();
      await _handleFieldBlurOrInteraction(key, newItems);
    }

    Future<void> editItem(int? index) async {
      final itemPath = '$key[${index ?? items.length}]';
      final initial = index != null ? Map<String, dynamic>.from(items[index]) : <String, dynamic>{};
      final result = await showFormDialog(
        context,
        formDefinition: {
          'title': index != null ? t.formChrome.editItem(label: itemLabel) : t.formChrome.addItem(label: itemLabel),
          'elements': itemFields,
        },
        initialState: initial,
        validator: widget.validator == null ? null : (fieldKey, value, state) => widget.validator!('$itemPath.$fieldKey', value, state),
        transformer: widget.transformer == null ? null : (fieldKey, value, state) => widget.transformer!('$itemPath.$fieldKey', value, state),
        developerMode: widget.developerMode,
      );
      if (result == null) return;
      final newItems = List<Map<String, dynamic>>.from(items);
      if (index != null) {
        newItems[index] = result;
      } else {
        newItems.add(result);
      }
      await commit(newItems);
    }

    void deleteItem(int index) {
      final newItems = List<Map<String, dynamic>>.from(items)..removeAt(index);
      commit(newItems);
    }

    void reorder(int oldIndex, int newIndex) {
      final newItems = List<Map<String, dynamic>>.from(items);
      if (newIndex > oldIndex) newIndex -= 1;
      newItems.insert(newIndex, newItems.removeAt(oldIndex));
      commit(newItems);
    }

    return _ListFieldActions(editItem: editItem, deleteItem: deleteItem, reorder: reorder);
  }

  /// The list field's editor dialog: a summary row per item plus an "Add"
  /// row. Every mutation commits immediately (autosave, like every other
  /// field) — Done just closes. Editing or adding an item reopens the same
  /// form renderer recursively (via [showFormDialog]) scoped to
  /// `itemFields`, so there's no separate "list item editor" widget — just
  /// a smaller [FormDefinition].
  Future<void> _openListEditor(Map<String, dynamic> el) async {
    final key = el['key'] as String;
    final label = el['label'] as String? ?? '';
    // Matches _buildInlineListField's own fallback — without it, a non-inline
    // list field that declares itemLabel had it silently ignored here,
    // showing the plural container label in the Add/Edit dialog and button
    // instead.
    final itemLabel = el['itemLabel'] as String? ?? label;
    final orderable = el['orderable'] == true;

    await showHaloDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          // Read through _values each build so both this dialog and the
          // summary row behind it stay live.
          final items = ((_values[key] as List?) ?? const []).cast<Map<String, dynamic>>();
          final actions = _listFieldActions(
            context: dialogContext,
            key: key,
            el: el,
            items: items,
            itemLabel: itemLabel,
            // The inline field's own `build` already picks up a commit via
            // the outer setState; this dialog is a separate overlay that
            // needs telling explicitly to redraw with the new items.
            afterCommit: () => setDialogState(() {}),
          );

          Widget rowFor(int index) {
            final title = _listItemTitle(el, items[index]);
            return ListTile(
              key: ValueKey('$key-item-$index'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(title.isEmpty ? t.formChrome.untitled : title),
              onTap: _isSubmitting ? null : () => actions.editItem(index),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // A real drag listener, not decoration — with the
                  // framework's auto handle off below, this icon IS the
                  // drag affordance (same wiring as the inline editor's
                  // leading handle).
                  if (orderable) ReorderableDragStartListener(index: index, child: const Icon(MdiIcons.dragHorizontalVariant, size: 20)),
                  IconButton(
                    icon: Icon(MdiIcons.delete, size: 20, semanticLabel: t.formChrome.removeItem),
                    onPressed: _isSubmitting ? null : () => actions.deleteItem(index),
                  ),
                ],
              ),
            );
          }

          return HaloDialog(
            wide: true,
            title: Text(label),
            // Rows run edge to edge; the shell's own scroll view is off because
            // this content scrolls itself, and its width comes from the shared
            // sizing.
            contentPadding: EdgeInsets.zero,
            scrollable: false,
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (orderable)
                    ReorderableListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      // Same as the inline editor: on mouse platforms the
                      // framework auto-adds its own trailing handle to
                      // every row, doubling the row's own — the trailing
                      // icon above carries the ReorderableDragStartListener
                      // instead.
                      buildDefaultDragHandles: false,
                      // See the ReorderableListView above — HALO-534.
                      // ignore: deprecated_member_use
                      onReorder: actions.reorder,
                      children: [for (var i = 0; i < items.length; i++) rowFor(i)],
                    )
                  else
                    for (var i = 0; i < items.length; i++) rowFor(i),
                  TextButton.icon(
                    onPressed: _isSubmitting ? null : () => actions.editItem(null),
                    icon: const Icon(MdiIcons.plus, size: 18),
                    label: Text(t.formChrome.addItem(label: itemLabel)),
                  ),
                ],
              ),
            ),
            cancel: TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(t.common.done)),
          );
        },
      ),
    );
  }

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
                      if (((opt['label'] as String?) ?? opt['value'].toString()).toLowerCase().contains(query)) opt,
                  ]
                : [
                    for (final opt in options)
                      if (tierOf(opt) <= level || pinned.contains(opt['value'])) opt,
                  ],
            ...filtering ? unknownRows.where((r) => (r['label'] as String).toLowerCase().contains(query)) : unknownRows,
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

    return Padding(
      padding: _rowContentPadding,
      child: OutlinedButton(
        style: devModeColor == null
            ? null
            : OutlinedButton.styleFrom(
                foregroundColor: devModeColor,
                side: BorderSide(color: devModeColor),
              ),
        onPressed: widget.onAction == null || isRunning ? null : () => _runAction(actionKey, method),
        child: isRunning ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Text(label),
      ),
    );
  }
}

/// A collapsible markdown section: an [ExpansionTile] with an MDI chevron
/// (the framework's default trailing is a Material glyph in an MDI app).
/// A widget of its own because the chevron has to flip with the tile's
/// open/closed state — ExpansionTile rotates only its default trailing; a
/// custom one is never rotated for us.
class _CollapsibleMarkdown extends StatefulWidget {
  final Widget title;
  final Widget child;

  const _CollapsibleMarkdown({required this.title, required this.child});

  @override
  State<_CollapsibleMarkdown> createState() => _CollapsibleMarkdownState();
}

class _CollapsibleMarkdownState extends State<_CollapsibleMarkdown> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final padding = ListTileTheme.of(context).contentPadding ?? EdgeInsets.zero;
    return ExpansionTile(
      tilePadding: padding,
      childrenPadding: padding,
      trailing: Icon(_expanded ? MdiIcons.chevronUp : MdiIcons.chevronDown),
      onExpansionChanged: (open) => setState(() => _expanded = open),
      title: widget.title,
      children: [widget.child],
    );
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
  /// [_FormRendererState._openMultiselectEditor] uses. Some vocabularies run
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
              if (((opt['label'] as String?) ?? '').toLowerCase().contains(query)) opt,
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

/// The editor behind a text-like icon-row row ([FormRendererState._buildTextRow]).
///
/// Owns the controller rather than borrowing the form's: the value it edits
/// must not reach [FormRendererState._values] on every keystroke, and
/// disposing a controller the moment the dialog pops would tear it out from
/// under the route's own exit animation, which is still building the field.
class _TextEditDialog extends StatefulWidget {
  final String label;
  final String? placeholder;
  final String fieldType;
  final String initialText;

  /// The field's declared `defaultValue` as text, or null when it declares
  /// none — which is what decides whether the Defaults button is offered.
  final String? defaultText;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;

  /// The edited text, handed back as the dialog closes — by any route out of
  /// it, which is why this is a callback rather than the dialog's pop result:
  /// Escape and a barrier tap pop with no result, and there is no verb here
  /// that means discard the edit. Called at most once (see [_commitOnce]),
  /// and not at all when nothing was typed.
  final ValueChanged<String> onClosed;

  const _TextEditDialog({
    required this.label,
    required this.placeholder,
    required this.fieldType,
    required this.initialText,
    required this.defaultText,
    required this.keyboardType,
    required this.textCapitalization,
    required this.inputFormatters,
    required this.autofillHints,
    required this.onClosed,
  });

  @override
  State<_TextEditDialog> createState() => _TextEditDialogState();
}

class _TextEditDialogState extends State<_TextEditDialog> {
  late final TextEditingController _controller = TextEditingController(text: widget.initialText);
  bool _committed = false;

  /// Hands the edit back, once. Guarded because the two ways this dialog can
  /// end overlap: a pop runs [PopScope]'s callback and then disposes, while a
  /// route REMOVED rather than popped (its Navigator torn down, an ancestor
  /// taking the pane down) only ever disposes — and an edit that reached
  /// neither would vanish with the operator believing it saved, since closing
  /// is this dialog's commit gesture.
  ///
  /// An untouched value is not a commit: opening a setting and pressing
  /// Escape must not write it, and `onChange` is a real write with whatever
  /// the presenter hung off it.
  void _commitOnce() {
    if (_committed || _controller.text == widget.initialText) return;
    _committed = true;
    widget.onClosed(_controller.text);
  }

  @override
  void dispose() {
    _commitOnce();
    _controller.dispose();
    super.dispose();
  }

  /// Guarded on being the current route: two closes landing in the same frame
  /// — a repeated Enter, or Enter racing a tap on Done — would otherwise pop
  /// this dialog and then the pane underneath it.
  void _close() {
    if (ModalRoute.of(context)?.isCurrent ?? false) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final multiline = widget.fieldType == 'multiline';
    // No label: the dialog's own title already names the field, and a second
    // copy of the same words inside the box says nothing. The placeholder
    // stays — it is the only thing that says what a value here looks like.
    final decoration = poloFieldDecoration(context, widget.label, hintText: widget.placeholder, showLabel: false);

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _commitOnce();
      },
      child: HaloDialog(
        wide: true,
        title: Text(widget.label),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.fieldType == 'secret')
              SecretTextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _close(),
                decoration: decoration,
              )
            else
              TextField(
                selectAllOnFocus: false,
                autofocus: true,
                controller: _controller,
                maxLines: multiline ? null : 1,
                minLines: multiline ? 3 : null,
                keyboardType: widget.keyboardType,
                textCapitalization: widget.textCapitalization,
                inputFormatters: widget.inputFormatters,
                autofillHints: widget.autofillHints,
                // Enter inserts a newline in a multiline value; everywhere else
                // it closes the dialog, which is what commits.
                textInputAction: multiline ? null : TextInputAction.done,
                onSubmitted: multiline ? null : (_) => _close(),
                decoration: decoration,
              ),
          ],
        ),
        // Done and Defaults, like every other settings-field editor: there is
        // no Save because closing is what commits, and so no Cancel either —
        // a way out that discarded the edit would be the only one in Settings
        // that did.
        secondary: widget.defaultText == null
            ? null
            : _defaultsButton(
                onPressed: () {
                  _controller.text = widget.defaultText!;
                  _close();
                },
              ),
        cancel: TextButton(onPressed: _close, child: Text(t.common.done)),
      ),
    );
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
          ),
        ),
      ],
    ),
  );
}
