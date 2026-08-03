// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A password/secret text field with a show/hide toggle.
// Secret fields (extension settings passwords/API keys, the login dialog's
// password) obscure their text by default; this adds the conventional eye
// button so the operator can check what they typed — important on a phone
// keyboard where a mistyped API key is otherwise invisible until a lookup
// silently fails.

import 'package:flutter/material.dart';

/// An obscured [TextField] that reveals its text when the eye button in its
/// suffix is tapped. The obscured state is held internally, so a call site
/// swaps its `obscureText: true` `TextField` for this and passes the same
/// decoration/controller it already had — the show/hide button is injected as
/// the decoration's `suffixIcon` (replacing any the caller set).
class SecretTextField extends StatefulWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;

  /// The field decoration to render; the show/hide button becomes its
  /// `suffixIcon`.
  final InputDecoration decoration;

  final bool autofocus;
  final TextAlign textAlign;
  final TextStyle? style;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;

  /// Defaults to [AutofillHints.password] so a password manager still offers to
  /// fill/save, exactly as the plain obscured field did.
  final Iterable<String>? autofillHints;

  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  const SecretTextField({
    super.key,
    required this.decoration,
    this.controller,
    this.focusNode,
    this.autofocus = false,
    this.textAlign = TextAlign.start,
    this.style,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints = const [AutofillHints.password],
    this.onChanged,
    this.onSubmitted,
  });

  @override
  State<SecretTextField> createState() => _SecretTextFieldState();
}

class _SecretTextFieldState extends State<SecretTextField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    // Kept compact (small icon, tight constraints) so it fits an `isDense`
    // field and the icon-row layout's narrow secondary-control width without
    // forcing the row taller — a default IconButton's 48px target would.
    final toggle = IconButton(
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
      iconSize: 20,
      // Obscured → an eye (tap to show); revealed → eye-with-slash (tap to
      // hide). No hover tooltip (user-interface.md); the label is for screen
      // readers only, and flips with the icon.
      icon: Icon(
        _obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        semanticLabel: _obscured ? 'Show' : 'Hide',
      ),
      onPressed: () => setState(() => _obscured = !_obscured),
    );
    return TextField(
      selectAllOnFocus: false,
      controller: widget.controller,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      obscureText: _obscured,
      // A secret stays a secret whether hidden or revealed: obscureText forces
      // these off while hidden, but once the eye reveals the text they'd revert
      // to on — autocorrecting a password/API key, or leaking it into the soft
      // keyboard's suggestion strip and learned dictionary. Keep them off in
      // both states.
      autocorrect: false,
      enableSuggestions: false,
      smartDashesType: SmartDashesType.disabled,
      smartQuotesType: SmartQuotesType.disabled,
      textAlign: widget.textAlign,
      style: widget.style,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      decoration: widget.decoration.copyWith(suffixIcon: toggle),
    );
  }
}
