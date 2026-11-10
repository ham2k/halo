// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

part of 'station_panel.dart';

/// The Power field's own text state, kept in a controller rather than
/// [TextFormField]'s bare `initialValue` — the field's value has TWO writers
/// (the operator typing, and a live CAT reading arriving from the radio) and
/// only a controller can tell "external update" apart from "an edit in
/// progress" rather than clobbering focus/cursor on every keystroke the way
/// a value-keyed `initialValue` field would.
///
/// Commits (to [SettingsService.currentPower] and the radio) on submit or on
/// losing focus, never per keystroke — the same reason the VFO frequency
/// sync dedupes against `lastSent` (docs/design/cat.md): a command per digit
/// would briefly send the radio through every intermediate value.
class _PowerField extends StatefulWidget {
  final num? power;
  final String label;
  final String wattsLabel;
  final double width;
  final TextStyle style;
  final ValueChanged<num?> onCommit;

  const _PowerField({required this.power, required this.label, required this.wattsLabel, required this.width, required this.style, required this.onCommit});

  @override
  State<_PowerField> createState() => _PowerFieldState();
}

class _PowerFieldState extends State<_PowerField> {
  late final TextEditingController _controller = TextEditingController(text: _textFor(widget.power));
  final FocusNode _focusNode = FocusNode();

  static String _textFor(num? power) => power?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) _commit();
  }

  @override
  void didUpdateWidget(_PowerField old) {
    super.didUpdateWidget(old);
    // A live CAT reading arriving behind this field's back must not
    // clobber what the operator is mid-typing — only take it while the
    // field isn't focused, the same rule the VFO frequency field follows
    // (docs/design/cat.md, "Never over the operator").
    if (!_focusNode.hasFocus && widget.power != old.power) {
      _controller.text = _textFor(widget.power);
    }
  }

  void _commit() => widget.onCommit(num.tryParse(_controller.text));

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocusChange)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        SizedBox(
          width: widget.width,
          child: TextFormField(
            controller: _controller,
            focusNode: _focusNode,
            keyboardType: const TextInputType.numberWithOptions(decimal: false),
            decoration: poloFieldDecoration(context, widget.label),
            onFieldSubmitted: (_) => _commit(),
          ),
        ),
        const SizedBox(width: Space.md),
        Text(widget.wattsLabel, style: widget.style),
      ],
    );
  }
}
