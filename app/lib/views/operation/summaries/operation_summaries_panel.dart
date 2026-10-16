// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Operation Summaries pane: what the Info pane says about an operation —
// its stats, each day, every scorer's tallies — as sections the operator
// picks, orders and folds. Unlike the Info pane it never turns into Call
// Info: a running score stays on screen while the next call is typed.
//
// The picks belong to the PLACEMENT (docs/design/layouts.md), so one pane can
// carry a contest's score while another carries the states grid.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../../../services/halo_services.dart';
import '../../../services/panel_service.dart';
import '../../../tools/operation_stats.dart';
import '../../../tools/scoring_summaries.dart';
import '../information_panel.dart';

/// The panel id the view registers this pane under, and matches placements
/// against.
const String operationSummariesPanelId = 'summaries';

/// Section keys in the operator's order. Holds other operations' keys too,
/// so ordering this operation's sections leaves what another one was given
/// where it was.
const String summariesOrderKey = 'order';

/// Section keys left out of the pane, any operation's.
const String summariesHiddenKey = 'hidden';

/// Section keys folded down to their heading.
const String summariesFoldedKey = 'folded';

/// The fields this pane's config is stored under. Declared though no form
/// renders them — both routes to its settings are [OperationSummariesSettings]
/// — because `forgetInstanceConfig` forgets only DECLARED fields: an
/// undeclared order would outlive the pane that set it and be inherited by
/// whatever is placed in that slot next.
const List<Map<String, dynamic>> operationSummariesFields = [
  {'type': 'field', 'key': summariesOrderKey, 'fieldType': 'text', 'label': ''},
  {'type': 'field', 'key': summariesHiddenKey, 'fieldType': 'text', 'label': ''},
  {'type': 'field', 'key': summariesFoldedKey, 'fieldType': 'text', 'label': ''},
];

/// Stores one of this placement's config values; null forgets it.
typedef SummariesConfigWrite = Future<void> Function(String key, Object? value);

/// The writer for [panelId]'s placement — the same storage a panel's own
/// form commits to. Does not notify: the caller decides whether the pane has
/// to re-read (see [OperationSummariesSettings]) or already holds the value.
SummariesConfigWrite summariesConfigWriter(HaLoServices services, String panelId) => (key, value) async {
  final panel = services.panels[panelId];
  if (panel == null) return;
  await services.extensions.commitSettingsFieldValue(
    kind: 'simple',
    hookKey: panel.hookKey ?? panel.id,
    panelKey: panel.id,
    fieldKey: key,
    value: value,
    state: {key: value},
  );
};

List<String> summariesKeyList(Object? stored) => stored is List ? stored.whereType<String>().toList() : const [];

/// One section of an operation's summary.
class SummarySection {
  /// What the operator picks it by, the same from one operation to the next:
  /// [statsKey], [daysKey] for every day at once, or a tally's own
  /// `scorer.tally`. The Operation Postcard's section keys, word for word.
  final String key;
  final String title;

  /// An MDI icon name, as a tally carries it.
  final String? icon;
  final Color? iconColor;

  /// A tally's short figure ("72"), beside the title whenever [body] is not
  /// on screen to say it in full.
  final String? score;

  /// Null for a section that is all heading — nothing to fold.
  final List<Widget> Function(BuildContext context)? body;

  const SummarySection({required this.key, required this.title, this.icon, this.iconColor, this.score, this.body});

  static const statsKey = 'stats';
  static const daysKey = 'days';
}

/// What the Info pane shows for [operation] when no call is being logged, as
/// sections: the stats (with the duplicates count, which the Info pane puts
/// under its "Scoring" title — a title this pane has no use for, since every
/// tally heads a section of its own), each day's own tallies when there is
/// more than one day, then every scorer's tallies in `orderedScorerKeys`
/// order.
List<SummarySection> operationSummarySections(
  BuildContext context, {
  required Operation operation,
  required List<Qso> qsos,
  List<Map<String, dynamic>> activityControls = const [],
}) {
  final t = context.t;
  // Cached by the scoring service; absent until the first rescore, which
  // leaves the stats alone.
  final scoring = operation.localData['scoring'] as Map<String, dynamic>?;
  final duplicates = ((operationSummaryFor(scoring, 'core')?['qsoCount'] as Map?)?['duplicates'] as num?)?.toInt() ?? 0;
  final days = mergedDaySections(scoring);

  return [
    SummarySection(
      key: SummarySection.statsKey,
      title: t.loggingPanel.stats,
      body: (context) => [
        // The "since last" segment is now-relative — re-derived once a second,
        // as the Info pane does, so it doesn't sit stale between QSOs.
        OncePerSecond(
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (final line in operationStatsLines(context, qsos)) Text(line, style: Theme.of(context).textTheme.bodyMedium)],
          ),
        ),
        if (duplicates > 0) Text('${t.loggingPanel.duplicates}: ${formatNumber(duplicates)}'),
      ],
    ),
    if (days.length > 1)
      SummarySection(key: SummarySection.daysKey, title: t.operation.layout.panels.summariesDays, body: (context) => summaryDayBlocks(context, days)),
    for (final scorerKey in orderedScorerKeys(scoring))
      for (final (:key, :tally) in summaryTallies(operationSummaryFor(scoring, scorerKey)))
        _tallySection('$scorerKey.$key', tally, scorerIconColor(operation, scorerKey, activityControls)),
  ];
}

SummarySection _tallySection(String key, Map<dynamic, dynamic> tally, Color? iconColor) {
  final detail = tally['longSummary'];
  final score = tally['summary'];
  return SummarySection(
    key: key,
    title: tally['label'] as String,
    icon: tally['icon'] is String ? tally['icon'] as String : null,
    iconColor: iconColor,
    score: score is String && score.isNotEmpty ? score : null,
    body: detail is String && detail.isNotEmpty ? (context) => [summaryTallyDetail(context, detail, isGrid: tally['grid'] == true)] : null,
  );
}

/// [sections] in the operator's [order] — a key it does not name, a scorer
/// first seen since, goes after the ones it does, as it came — less those
/// [hidden].
List<SummarySection> summarySectionsInOrder(List<SummarySection> sections, {List<String> order = const [], Set<String> hidden = const {}}) {
  final byKey = {for (final section in sections) section.key: section};
  final keys = [
    ...order.where(byKey.containsKey),
    for (final section in sections)
      if (!order.contains(section.key)) section.key,
  ];
  return [
    for (final key in {...keys})
      if (!hidden.contains(key)) byKey[key]!,
  ];
}

class OperationSummariesPanel extends StatefulWidget {
  /// The placement's id — the key this pane's config is stored under.
  final String panelId;
  final PanelService panels;
  final Operation operation;
  final List<Qso> qsos;

  /// The active logging controls, for each scorer's accent color (see
  /// [scorerIconColor]).
  final List<Map<String, dynamic>> activityControls;
  final SummariesConfigWrite write;

  const OperationSummariesPanel({
    super.key,
    required this.panelId,
    required this.panels,
    required this.operation,
    required this.qsos,
    required this.write,
    this.activityControls = const [],
  });

  @override
  State<OperationSummariesPanel> createState() => _OperationSummariesPanelState();
}

class _OperationSummariesPanelState extends State<OperationSummariesPanel> {
  Map<String, dynamic> _config = const {};
  int _configRevision = 0;

  @override
  void initState() {
    super.initState();
    widget.panels.addListener(_onCatalogChanged);
    _configRevision = widget.panels.configRevision(widget.panelId);
    unawaited(_loadConfig());
  }

  @override
  void didUpdateWidget(OperationSummariesPanel old) {
    super.didUpdateWidget(old);
    if (old.panels != widget.panels) {
      old.panels.removeListener(_onCatalogChanged);
      widget.panels.addListener(_onCatalogChanged);
    }
    if (old.panelId != widget.panelId) {
      _configRevision = widget.panels.configRevision(widget.panelId);
      unawaited(_loadConfig());
    }
  }

  @override
  void dispose() {
    widget.panels.removeListener(_onCatalogChanged);
    super.dispose();
  }

  /// Settings bump the revision once they have written; nothing else tells this
  /// pane its picks moved.
  void _onCatalogChanged() {
    final revision = widget.panels.configRevision(widget.panelId);
    if (revision == _configRevision) return;
    _configRevision = revision;
    unawaited(_loadConfig());
  }

  Future<void> _loadConfig() async {
    final panel = widget.panels[widget.panelId];
    if (panel == null) return;
    final config = await widget.panels.configFor(panel);
    if (mounted) setState(() => _config = config);
  }

  Set<String> get _folded => summariesKeyList(_config[summariesFoldedKey]).toSet();

  void _toggleFold(String key) {
    final folded = _folded;
    if (!folded.remove(key)) folded.add(key);
    // Optimistic, and no revision bump after the write: the pane already
    // holds the value, and re-reading it would only hand back what it sent.
    setState(() => _config = {..._config, summariesFoldedKey: folded.toList()});
    unawaited(widget.write(summariesFoldedKey, folded.isEmpty ? null : folded.toList()));
  }

  @override
  Widget build(BuildContext context) {
    final sections = summarySectionsInOrder(
      operationSummarySections(context, operation: widget.operation, qsos: widget.qsos, activityControls: widget.activityControls),
      order: summariesKeyList(_config[summariesOrderKey]),
      hidden: summariesKeyList(_config[summariesHiddenKey]).toSet(),
    );
    final padding = EdgeInsets.all(Space.xl).add(PaneSafeArea.paddingOf(context));
    if (sections.isEmpty) {
      return Padding(
        padding: padding,
        child: Center(child: Text(context.t.operation.layout.panels.summariesAllHidden, textAlign: TextAlign.center)),
      );
    }
    final folded = _folded;
    return ListView(
      padding: padding,
      children: [
        for (final (index, section) in sections.indexed) ...[
          if (index > 0) const SizedBox(height: Space.xl),
          ..._section(context, section, folded: folded.contains(section.key)),
        ],
      ],
    );
  }

  List<Widget> _section(BuildContext context, SummarySection section, {required bool folded}) {
    final body = section.body;
    final heading = summaryHeading(
      context,
      title: section.title,
      icon: section.icon,
      iconColor: section.iconColor,
      score: body == null || folded ? section.score : null,
      trailing: body == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(left: Space.sm),
              child: Icon(folded ? MdiIcons.chevronRight : MdiIcons.chevronDown, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
    );
    if (body == null) return [heading];
    return [
      Semantics(
        button: true,
        expanded: !folded,
        child: InkWell(onTap: () => _toggleFold(section.key), child: heading),
      ),
      if (!folded) ...body(context),
    ];
  }
}
