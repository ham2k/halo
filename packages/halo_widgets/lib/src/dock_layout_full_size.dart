// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The dock's side of a pane shown full size (docs/design/layouts.md, "Full
// size"): which pane, its GlobalKey, the double tap on a tab, and the
// keyboard. The card itself is [DockFullSizeView], in dock_full_size.dart.

part of 'dock_layout.dart';

mixin _DockFullSize on State<DockLayoutView> {
  // The dock's own, read here.
  DockNode get _spec;
  List<String> get modules;
  Widget _missingPane(String id);

  @override
  void dispose() {
    _tapWindow?.cancel();
    _fullSizeScope.dispose();
    // A host that swaps docks (at the two-pane boundary) disposes one with a
    // pane full size, and has to hear it went: its header stays under the
    // barrier otherwise. After the frame — the host's own rebuild is not
    // below this dock.
    if (_fullSize != null) {
      final changed = widget.onFullSizeChanged;
      WidgetsBinding.instance.addPostFrameCallback((_) => changed?.call(null));
    }
    super.dispose();
  }

  /// One GlobalKey per module, around its pane wherever it is drawn. It is
  /// what carries a pane's State into the full-size card and back.
  final Map<String, GlobalKey> _paneKeys = {};

  GlobalKey _paneKey(String id) => _paneKeys.putIfAbsent(id, () => GlobalKey(debugLabel: 'dock pane $id'));

  /// The module showing full size, which its slot leaves empty while the
  /// card holds it. One build draws the pane in one place or the other,
  /// never both, which is what lets its GlobalKey move between them.
  String? _fullSize;

  /// The card's keyboard, and what had it before the card opened.
  final _fullSizeScope = FocusScopeNode(debugLabel: 'full-size pane');
  FocusNode? _focusBeforeFullSize;

  /// The module showing full size, if any.
  String? get fullSizeModule => _fullSize;

  /// The tab tapped last, while a second tap on it would make a double tap.
  /// Counted from the tab's own tap rather than from pointers: see
  /// [DockTab.onDoubleTap]. Selecting stays immediate — the first tap has
  /// already selected by the time the second arrives.
  String? _tappedTab;
  Timer? _tapWindow;

  void _countTabTap(String id) {
    final second = _tappedTab == id && _tapWindow != null;
    _tapWindow?.cancel();
    _tapWindow = null;
    _tappedTab = null;
    if (second) return showFullSize(id);
    _tappedTab = id;
    _tapWindow = Timer(kDoubleTapTimeout, () {
      _tapWindow = null;
      _tappedTab = null;
    });
  }

  /// Whether a double tap on [id]'s title may show it full size: outside
  /// edit mode, and not a panel that opted out. [showFullSize] also refuses
  /// a container tab, which costs a walk of the tree and so is not asked
  /// per tab per build.
  bool _mayShowFullSize(String id) => !widget.editing && !widget.unexpandableModules.contains(id);

  bool _isContainer(String id) {
    bool holds(DockNode node) => switch (node) {
      DockGroup() => node.nested.containsKey(id) || node.nested.values.any(holds),
      DockSplit() => node.children.any(holds),
    };
    return holds(_spec);
  }

  /// Shows [id] full size: the pane MOVES into a card over the dock, State
  /// and all, and comes back to its slot when the card closes. One pane, not
  /// a second copy — a copy would start over (a map's zoom, a list's scroll,
  /// a half-typed field), and two of an extension panel would both cross the
  /// bridge.
  void showFullSize(String id) {
    if (_fullSize != null || !_mayShowFullSize(id) || !modules.contains(id) || _isContainer(id)) return;
    _focusBeforeFullSize = FocusManager.instance.primaryFocus;
    setState(() => _fullSize = id);
    widget.onFullSizeChanged?.call(id);
    // The card takes the keyboard outright: left where it was, it would stay
    // in a field behind the barrier, taking every keystroke — Escape
    // included — while the operator looks at the card. Focus already inside
    // the pane that moved (a full-size logging pane) stays put. After the
    // frame, once the pane is in the card.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _fullSize == id && !_fullSizeScope.hasFocus) _fullSizeScope.requestFocus();
    });
  }

  /// Puts the full-size pane back in its slot.
  void closeFullSize() {
    if (_fullSize == null) return;
    _releaseFullSizeFocus();
    setState(() => _fullSize = null);
    widget.onFullSizeChanged?.call(null);
  }

  /// Where the keyboard goes when the card closes. Somewhere in the pane, it
  /// stays there: the pane goes back with it, and the operator may have
  /// moved on from the field they started in. On the card itself, it goes
  /// back to what had it before the card opened — usually a logging field —
  /// rather than nowhere, where the next keystroke would follow it.
  void _releaseFullSizeFocus() {
    final before = _focusBeforeFullSize;
    _focusBeforeFullSize = null;
    final inPane = _fullSizeScope.hasFocus && !_fullSizeScope.hasPrimaryFocus;
    if (inPane || before == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (before.context != null && before.canRequestFocus) before.requestFocus();
    });
  }

  Widget _buildFullSize(String id) => BlockSemantics(
    // Over the panes, in the same Stack: without this a screen reader — and
    // with the web's accessibility DOM on, a click — reaches the buttons of
    // the panes under the barrier.
    child: DockFullSizeView(
      title: widget.titles[id] ?? id,
      action: widget.tabActions?[id]?.call(context),
      pane: KeyedSubtree(key: _paneKey(id), child: widget.children[id] ?? _missingPane(id)),
      closeLabel: widget.fullSizeCloseLabel,
      onClose: closeFullSize,
      scope: _fullSizeScope,
      escapeClaimed: widget.fullSizeEscapeClaimed,
    ),
  );

  /// Each dock build, before anything is drawn: forgets the keys of panes
  /// that have left, and puts back a full-size pane whose module has left
  /// the arrangement, whose layout is being edited, or whose dock has been
  /// put away (TickerMode off: a Home destination the operator has left,
  /// whose card would otherwise go on taking the back press and keeping the
  /// header mask hidden) — now, in this build, so the slot and the card
  /// agree on where the pane is.
  void _settleFullSize() {
    final inSpec = modules.toSet();
    _paneKeys.removeWhere((id, _) => !inSpec.contains(id));
    final hidden = !TickerMode.valuesOf(context).enabled;
    if (_fullSize case final id? when widget.editing || hidden || !inSpec.contains(id)) {
      _releaseFullSizeFocus();
      _fullSize = null;
      // After the build: what the host does with it rebuilds things that are
      // not below this dock.
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onFullSizeChanged?.call(null));
    }
  }
}
