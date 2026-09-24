// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../services/cat/cw_live_typing.dart';

/// Keyboard mode's field, beside the message going out: what is typed keys
/// as it is typed (cw_live_typing.dart). What the keyer already has is bold and
/// cannot be edited; the rest is the operator's until it is handed over.
/// Enter ends the mode and lets it all go out; Escape ends it and stops
/// what is keying.
class CwTypingField extends StatefulWidget {
  final CwLiveTyping typing;

  const CwTypingField({super.key, required this.typing});

  @override
  State<CwTypingField> createState() => _CwTypingFieldState();
}

class _CwTypingFieldState extends State<CwTypingField> {
  late final _controller = _HandedOffController(widget.typing);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Asked for, not `autofocus`: the call field holds the focus when the
    // button is pressed, and autofocus only takes it from nobody.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Refuses an edit into what the keyer has, and keeps the text to what
  /// the keyer can send.
  TextEditingValue _format(TextEditingValue old, TextEditingValue next) {
    if (!widget.typing.update(next.text)) return old;
    final text = widget.typing.text;
    // Uppercasing moves nothing, so the edit keeps its caret and its IME
    // composing region (the house UpperCaseTextFormatter does the same — an
    // Android keyboard whose composing is reset repeats letters). A dropped
    // character shifts what follows it, so then the caret goes to the end.
    if (next.text.length == text.length) return next.copyWith(text: text);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  /// Space between words. The logging panel binds Space to "next field"
  /// (logging_controls.dart), which would take the keyboard out of this
  /// field instead — the refs field answers the same binding the same way.
  void _insertSpace() {
    final value = _controller.value;
    final selection = value.selection.isValid ? value.selection : TextSelection.collapsed(offset: value.text.length);
    final next = TextEditingValue(
      text: value.text.replaceRange(selection.start, selection.end, ' '),
      selection: TextSelection.collapsed(offset: selection.start + 1),
    );
    _controller.value = _format(value, next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium ?? const TextStyle();
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: theme.colorScheme.tertiary),
    );
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
          widget.typing.cancel();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.space): _insertSpace},
        child: TextField(
          controller: _controller,
          focusNode: _focus,
          style: style,
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.send,
          inputFormatters: [TextInputFormatter.withFunction(_format)],
          // Outlined like the message buttons, with their corners and
          // colour.
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
            border: border,
            enabledBorder: border,
            focusedBorder: border.copyWith(borderSide: BorderSide(color: theme.colorScheme.tertiary, width: 2)),
            hintText: context.t.settings.radio.cwMessages.keyboardField,
            hintStyle: style.copyWith(color: style.color?.withValues(alpha: 0.38)),
          ),
          onSubmitted: (_) => widget.typing.finish(),
        ),
      ),
    );
  }
}

/// Bolds what the keyer already has — the part no edit reaches.
class _HandedOffController extends TextEditingController {
  final CwLiveTyping typing;

  _HandedOffController(this.typing) : _clears = typing.clears {
    typing.addListener(_onTyping);
  }

  int _clears;
  bool _disposed = false;

  /// A hand-off restyles the text without changing it; a stop empties it.
  /// Told apart by [CwLiveTyping.clears], never by comparing texts. The
  /// field's own formatter makes [typing] notify mid-keystroke, while this
  /// controller still holds the text from BEFORE the keystroke — and any
  /// notification then, a restyle included, has the field send that old
  /// value to the platform, clearing the keyboard's composing word (an
  /// Android keyboard then repeats letters). So a restyle waits for the
  /// keystroke to land.
  void _onTyping() {
    if (typing.clears == _clears) {
      scheduleMicrotask(() {
        if (!_disposed) notifyListeners();
      });
      return;
    }
    _clears = typing.clears;
    value = TextEditingValue(
      text: typing.text,
      selection: TextSelection.collapsed(offset: typing.text.length),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    typing.removeListener(_onTyping);
    super.dispose();
  }

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final split = typing.handedOff.clamp(0, text.length);
    return TextSpan(
      style: style,
      children: [
        TextSpan(
          text: text.substring(0, split),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        TextSpan(text: text.substring(split)),
      ],
    );
  }
}
