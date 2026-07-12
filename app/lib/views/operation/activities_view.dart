// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Full-screen Activities view (replaces the old _editActivities AlertDialog):
// three accordion sections — "Current Activities" (title shows the count;
// one row per ref, tap to edit, delete button to remove; open by default),
// "Suggestions & Search" (the search field itself is the header; open by
// default and expands to fill the remaining space) and "All Options" (every
// active activity type, for adding one manually; closed by default).
// Start/break/end events are deferred — this view is activities-only for
// now.
//
// A plain ExpansionTile can't "fill the remaining space" (it always sizes
// to its content inside a scrollable list), so the accordion here is a
// small custom widget instead: each section is either content-sized or,
// when marked `fill`, wrapped in Expanded with its own internally
// scrollable body.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../../main.dart';
import '../operation_dialogs.dart';
import '../../i18n/strings.g.dart';

/// Shifts [base] toward green, pulls its saturation down, and darkens it
/// slightly — used for the accordion headers here so they read as a soft
/// green rather than the app's primaryContainer (which leans cyan/blue),
/// without a global theme change.
Color _greenerDesaturated(Color base) {
  final hsl = HSLColor.fromColor(base);
  return hsl.withHue((hsl.hue - 15) % 360).withSaturation(0.4).withLightness(0.8).toColor();
}

class ActivitiesView extends StatefulWidget {
  final HaLoServices services;
  final Operation operation;

  const ActivitiesView({super.key, required this.services, required this.operation});

  @override
  State<ActivitiesView> createState() => _ActivitiesViewState();
}

class _ActivitiesViewState extends State<ActivitiesView> {
  late Operation _operation;
  List<Map<String, dynamic>> _controls = const [];

  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  Timer? _debounce;
  List<Map<String, dynamic>> _suggestions = const [];
  bool _loadingSuggestions = true;
  // Guards against a slower, earlier-fired search resolving after a faster,
  // more recent one and clobbering its results — only the response whose
  // id still matches the latest request gets applied.
  int _searchRequestId = 0;

  bool _activitiesExpanded = true;
  bool _searchExpanded = true;
  bool _allOptionsExpanded = false;

  @override
  void initState() {
    super.initState();
    _operation = widget.operation;
    _loadControls();
    _search('');
    // Focusing the search field always reveals its results, even if the
    // user (or a previous collapse) had left the accordion closed.
    _searchFocusNode.addListener(() {
      if (_searchFocusNode.hasFocus && !_searchExpanded) {
        setState(() => _searchExpanded = true);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadControls() async {
    final controls = await widget.services.extensions.operationControls(_operation.data);
    if (mounted) setState(() => _controls = controls);
  }

  /// The `operationControls` entry (icon, pattern, …) for a ref/suggestion
  /// type, or null for a type with no active control.
  Map<String, dynamic>? _controlForType(String? refType) {
    for (final control in _controls) {
      final input = control['input'] as Map?;
      if (input?['refType'] == refType) return control;
    }
    return null;
  }

  /// Icon name for a ref/suggestion type, falling back to a generic marker
  /// for types with no active control.
  String? _iconForType(String? refType) => _controlForType(refType)?['icon'] as String?;

  bool _matchesPattern(String? pattern, String code) =>
      pattern == null || RegExp('^(?:$pattern)\$', caseSensitive: false).hasMatch(code);

  bool _isDuplicateRef(String type, String code, {int? excludingIndex}) {
    final refs = _operation.refs;
    for (var i = 0; i < refs.length; i++) {
      if (i == excludingIndex) continue;
      if (refs[i]['type'] == type && refs[i]['ref'] == code) return true;
    }
    return false;
  }

  Future<void> _saveRefs(List<Map<String, dynamic>> refs) async {
    final updated = Operation(
      uuid: _operation.uuid,
      data: {..._operation.data, 'refs': refs},
      qsoCount: _operation.qsoCount,
      startAtMillisMin: _operation.startAtMillisMin,
      startAtMillisMax: _operation.startAtMillisMax,
      localData: _operation.localData,
    );
    await widget.services.operations.saveData(updated);
    if (mounted) setState(() => _operation = updated);
  }

  Future<void> _editRef(Map<String, dynamic> ref) async {
    final t = context.t.activitiesView;
    final code = await editOneFieldDialog(
      context,
      title: t.editActivity,
      fieldLabel: t.reference,
      fieldInitial: (ref['ref'] as String?) ?? '',
      fieldCapitalization: TextCapitalization.characters,
      saveLabel: context.t.common.save,
    );
    if (code == null || !mounted) return;

    final trimmed = code.trim().toUpperCase();
    if (trimmed.isEmpty) return;

    final type = ref['type'] as String?;
    final pattern = (_controlForType(type)?['input'] as Map?)?['pattern'] as String?;
    if (!_matchesPattern(pattern, trimmed)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.invalidReference)));
      return;
    }

    final refs = _operation.refs;
    final index = refs.indexWhere((r) => r['type'] == ref['type'] && r['ref'] == ref['ref']);
    if (index < 0) return;

    if (_isDuplicateRef(type ?? '', trimmed, excludingIndex: index)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.duplicateReference)));
      return;
    }

    final decorated = await widget.services.extensions.decorateRef({...ref, 'ref': trimmed});
    await _saveRefs([...refs]..[index] = decorated);
  }

  Future<void> _deleteRef(Map<String, dynamic> ref) async {
    final refs = _operation.refs.where((r) => !(r['type'] == ref['type'] && r['ref'] == ref['ref'])).toList();
    await _saveRefs(refs);
    if (!mounted) return;
    // Removing an activity is often a mistake to undo, so surface it back as
    // a suggestion — but only until the next search resolves (or this view
    // closes), rather than sticking around as stale state.
    final alreadySuggested = _suggestions.any((s) => s['type'] == ref['type'] && s['ref'] == ref['ref']);
    if (!alreadySuggested) {
      setState(() => _suggestions = [ref, ..._suggestions]);
    }
  }

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(text));
  }

  Future<void> _search(String term) async {
    final requestId = ++_searchRequestId;
    setState(() => _loadingSuggestions = true);
    final trimmed = term.trim();
    final results = await widget.services.extensions.suggestActivities(
      _operation.data,
      searchTerm: trimmed.isEmpty ? null : trimmed,
    );
    // A newer search may have fired (and even resolved) while this one was
    // in flight — only the still-current request gets to apply its results.
    if (mounted && requestId == _searchRequestId) {
      setState(() {
        _suggestions = results;
        _loadingSuggestions = false;
      });
    }
  }

  Future<void> _addSuggestion(Map<String, dynamic> suggestion) async {
    final type = suggestion['type'] as String?;
    final code = suggestion['ref'] as String?;
    if (type != null && code != null && _isDuplicateRef(type, code)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.t.activitiesView.duplicateReference)));
      return;
    }
    await _saveRefs([..._operation.refs, suggestion]);
  }

  Future<void> _addManually(Map<String, dynamic> control) async {
    final t = context.t.activitiesView;
    final input = (control['input'] as Map?) ?? const {};
    final refType = input['refType'] as String?;
    if (refType == null) return;

    final code = await editOneFieldDialog(
      context,
      title: (control['label'] as String?) ?? t.addActivity,
      fieldLabel: t.reference,
      fieldInitial: '',
      fieldCapitalization: TextCapitalization.characters,
    );
    if (code == null || code.trim().isEmpty || !mounted) return;

    final trimmed = code.trim().toUpperCase();
    if (!_matchesPattern(input['pattern'] as String?, trimmed)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.invalidReference)));
      return;
    }
    if (_isDuplicateRef(refType, trimmed)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.duplicateReference)));
      return;
    }

    final ref = <String, dynamic>{'type': refType, 'ref': trimmed};
    final decorated = await widget.services.extensions.decorateRef(ref);
    await _saveRefs([..._operation.refs, decorated]);
  }

  String _activitiesTitle(int count) {
    final t = context.t.activitiesView;
    if (count == 0) return t.activitiesCountZero;
    if (count == 1) return t.activitiesCountOne;
    return t.activitiesCountOther(count: count);
  }

  /// Builds a section's body from a list of (already opaquely white) rows:
  /// content-sized when [fill] is false, or a scrollable list when [fill]
  /// is true — the leftover space below the last row then shows the
  /// Scaffold's own gray background straight through, since neither
  /// ListView nor its rows' surrounding space paint anything there. [fill]
  /// varies at runtime (Current Activities only fills when Search is
  /// collapsed), so this shape has to be chosen here rather than baked
  /// into a fixed widget tree.
  Widget _sectionBody({required bool fill, required List<Widget> rows, required Widget emptyPlaceholder}) {
    if (rows.isEmpty) return emptyPlaceholder;
    if (!fill) return Column(mainAxisSize: MainAxisSize.min, children: rows);
    return ListView(children: rows);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.activitiesView;
    final theme = Theme.of(context);
    final refs = _operation.refs;
    final accordionColor = _greenerDesaturated(theme.colorScheme.primaryContainer);
    final onAccordionColor = theme.colorScheme.onPrimaryContainer;
    // Rows paint an opaque white so they read distinctly from the view's
    // gray background (Scaffold.backgroundColor below), which otherwise
    // shows straight through wherever a filling section has no row to draw.
    final rowColor = theme.colorScheme.surface;
    // Current Activities only takes the flexible remaining space when
    // Search isn't there to claim it.
    final activitiesFill = !_searchExpanded;

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      appBar: AppBar(
        leadingWidth: macOSAwareLeadingWidth,
        leading: macOSAwareBackButton(),
        title: Text(t.title),
      ),
      body: Column(
        children: [
          _AccordionSection(
            title: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                _activitiesTitle(refs.length),
                style: theme.textTheme.titleMedium?.copyWith(color: onAccordionColor, fontWeight: FontWeight.w600),
              ),
            ),
            expanded: _activitiesExpanded,
            fill: activitiesFill,
            onToggle: () => setState(() => _activitiesExpanded = !_activitiesExpanded),
            headerColor: accordionColor,
            onHeaderColor: onAccordionColor,
            child: _sectionBody(
              fill: activitiesFill,
              emptyPlaceholder: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(t.empty, style: TextStyle(color: theme.colorScheme.outline)),
              ),
              rows: [
                for (final ref in refs)
                  ListTile(
                    tileColor: rowColor,
                    // Right padding matches the accordion header's own
                    // horizontal inset, so this trailing icon button lines
                    // up under the search row's options button — same
                    // IconButton defaults (no custom size/padding) too.
                    contentPadding: const EdgeInsets.only(left: 16, right: 4),
                    leading: Icon(resolveIconName(_iconForType(ref['type'] as String?))),
                    title: Text((ref['shortLabel'] ?? ref['ref'] ?? '?') as String),
                    subtitle: (ref['name'] as String?) != null ? Text(ref['name'] as String) : null,
                    onTap: () => _editRef(ref),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: t.removeActivity,
                      onPressed: () => _deleteRef(ref),
                    ),
                  ),
              ],
            ),
          ),
          _AccordionSection(
            title: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: t.searchHint,
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Color.alphaBlend(onAccordionColor.withValues(alpha: 0.06), accordionColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: onAccordionColor.withValues(alpha: 0.25)),
                ),
                isDense: true,
              ),
              onChanged: _onSearchChanged,
            ),
            titleIsInteractive: true,
            trailing: IconButton(
              // Disabled for now — will drive filtering/sorting options for
              // the suggestions list once that's wired up.
              icon: Icon(Icons.tune, color: onAccordionColor.withValues(alpha: 0.38)),
              tooltip: t.searchOptions,
              onPressed: null,
            ),
            expanded: _searchExpanded,
            fill: true,
            onToggle: () => setState(() => _searchExpanded = !_searchExpanded),
            headerColor: accordionColor,
            onHeaderColor: onAccordionColor,
            child: Column(
              children: [
                if (_loadingSuggestions) const LinearProgressIndicator(),
                Expanded(
                  child: _sectionBody(
                    fill: true,
                    emptyPlaceholder: _loadingSuggestions
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Text(t.noSuggestions, style: TextStyle(color: theme.colorScheme.outline)),
                          ),
                    rows: [
                      for (final suggestion in _suggestions)
                        ListTile(
                          tileColor: rowColor,
                          leading: Icon(resolveIconName(_iconForType(suggestion['type'] as String?))),
                          title: Text((suggestion['shortLabel'] ?? suggestion['ref'] ?? '?') as String),
                          subtitle: Text(
                            [suggestion['name'], suggestion['location']]
                                .whereType<String>()
                                .where((s) => s.isNotEmpty)
                                .join(' • '),
                          ),
                          onTap: () => _addSuggestion(suggestion),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _AccordionSection(
            title: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                t.allOptions,
                style: theme.textTheme.titleMedium?.copyWith(color: onAccordionColor, fontWeight: FontWeight.w600),
              ),
            ),
            expanded: _allOptionsExpanded,
            onToggle: () => setState(() => _allOptionsExpanded = !_allOptionsExpanded),
            headerColor: accordionColor,
            onHeaderColor: onAccordionColor,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final control in _controls)
                  if ((control['input'] as Map?)?['kind'] == 'refList')
                    ListTile(
                      tileColor: rowColor,
                      leading: Icon(resolveIconName(control['icon'] as String?)),
                      title: Text((control['label'] as String?) ?? ''),
                      onTap: () => _addManually(control),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One collapsible section. The tinted header always shows, arrow on the
/// left; the body appears below it only while expanded, using the default
/// (untinted) background. When [fill] and expanded, the whole section
/// (header + body) is wrapped in [Expanded] so it consumes whatever
/// vertical space its siblings don't need — [child] must then provide its
/// own bounded/scrollable content (see the Suggestions & Search section's
/// `ListView`).
///
/// The arrow rotates and (for non-[fill] sections) the body cross-fades and
/// resizes smoothly. A [fill] section's own Expanded/flex toggle stays
/// instant — animating who claims leftover flex space between sibling
/// sections isn't something Flutter's implicit animations do — but its
/// arrow still animates like every other section's.
class _AccordionSection extends StatelessWidget {
  final Widget title;
  final bool expanded;
  final VoidCallback onToggle;
  final Color headerColor;
  final Color onHeaderColor;
  final Widget child;
  final bool fill;

  /// True when [title] is itself an interactive control (the search field)
  /// that shouldn't also toggle expand/collapse on tap — only the arrow
  /// button does, in that case.
  final bool titleIsInteractive;

  /// An optional extra control at the far right of the header, after
  /// [title] (e.g. the search section's options button).
  final Widget? trailing;

  const _AccordionSection({
    required this.title,
    required this.expanded,
    required this.onToggle,
    required this.headerColor,
    required this.onHeaderColor,
    required this.child,
    this.fill = false,
    this.titleIsInteractive = false,
    this.trailing,
  });

  static const _duration = Duration(milliseconds: 200);

  @override
  Widget build(BuildContext context) {
    final arrow = IconButton(
      icon: AnimatedRotation(
        turns: expanded ? 0.5 : 0,
        duration: _duration,
        curve: Curves.easeInOut,
        child: Icon(Icons.expand_more, color: onHeaderColor),
      ),
      onPressed: onToggle,
    );

    final headerRow = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(children: [arrow, Expanded(child: title), ?trailing]),
    );

    final header = Material(
      color: headerColor,
      child: titleIsInteractive ? headerRow : InkWell(onTap: onToggle, child: headerRow),
    );

    if (fill) {
      if (!expanded) return header;
      // The Expanded/flex allocation itself can't be smoothly animated
      // (space redistribution between flex siblings isn't something
      // Flutter's layout interpolates, and attempting it risks overflow
      // mid-animation) — fading the newly-revealed content in is the safe
      // way to still give this section a visible reveal animation. Same
      // widget position across rebuilds (e.g. every search keystroke) keeps
      // the fade's AnimationController alive, so it only actually plays
      // once, right when the section opens.
      return Expanded(
        child: Column(
          children: [
            header,
            Expanded(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: _duration,
                curve: Curves.easeIn,
                builder: (context, opacity, child) => Opacity(opacity: opacity, child: child),
                child: child,
              ),
            ),
          ],
        ),
      );
    }

    final body = AnimatedCrossFade(
      firstChild: child,
      secondChild: const SizedBox(width: double.infinity),
      crossFadeState: expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
      duration: _duration,
      sizeCurve: Curves.easeInOut,
    );
    return Column(mainAxisSize: MainAxisSize.min, children: [header, body]);
  }
}
