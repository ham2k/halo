// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Text entry: the text-like row and the dialog it edits in, and what every
// text field's keyboard, capitalization and input filters are.

part of 'form_renderer.dart';

/// [FormRendererState]'s text entry. The members declared abstract below are
/// the state's own, which every field type shares.
mixin _TextFields on State<FormRenderer> {
  Map<String, dynamic> get _values;
  Map<String, String> get _errors;
  Map<String, TextEditingController> get _controllers;
  bool get _isSubmitting;
  EdgeInsetsGeometry get _rowContentPadding;
  Color? _devModeColor(Map<String, dynamic> el);
  Future<void> _handleFieldBlurOrInteraction(String key, dynamic value);
  Iterable<String>? _getAutofillHints(String key, String fieldType);
  String _controllerTextFor(String key, dynamic value);

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
  /// as a fixed-length mask, or as its `storedText` when it declares one:
  /// settings panels are read over shoulders and on shared screens, and even
  /// the LENGTH of a password is more than the row needs to say to confirm
  /// one is stored.
  String _displayValue(Map<String, dynamic> el, String fieldType) {
    // Through the same helper the dialog seeds from, or the row and the
    // editor it opens show one value two ways, a tap apart.
    final raw = _controllerTextFor(el['key'] as String, _values[el['key']]);
    if (raw.isEmpty) return '';
    if (fieldType != 'secret') return raw;
    final stored = el['storedText'];
    return stored is String && stored.isNotEmpty ? stored : '••••••••';
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
      builder: (dialogContext) => NumbersRowExtraKey(
        extraKey: _numbersRowKeyFor(el),
        child: _TextEditDialog(
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

  /// Digits, a sign, and every mark a keyboard might offer as a decimal
  /// point — [LocalizedDecimalMarkFormatter] normalizes whichever arrives.
  static RegExp _numberFieldCharacters() {
    final marks = {'.', ',', NumberFormatting.instance.decimalSeparator};
    return RegExp('[0-9-${marks.map(RegExp.escape).join()}]');
  }

  /// The mobile numbers row's extra key for [el] (see [NumbersRowExtraKey]):
  /// the field's own `numbersRowKey`, else "/" in a callsign field and the
  /// row's decimal default elsewhere. The dialog editor gets it too — it is a
  /// route of its own, outside the field's ancestors.
  ///
  /// Not in the SDK's `FormField`: the row only shows over the logging panel
  /// and its More pane, and no extension form opens there.
  String? _numbersRowKeyFor(Map<String, dynamic> el) => NumbersRowExtraKey.declared(el['numbersRowKey']) ?? (el['fieldType'] == 'callsign' ? '/' : null);

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
