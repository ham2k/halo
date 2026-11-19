// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:intl/intl.dart';

import 'package:halo_i18n/halo_i18n.dart';
import '../../services/chase_service.dart' show ChaseSummary;
import '../../services/halo_services.dart';
import '../../tools/scoring_summaries.dart';
import 'call_info_panel.dart';
import '../extension_markdown_images.dart';
import '../../services/extensions/extension_service.dart' show ExtensionService;
import 'operation_lifecycle_presentation.dart';
import 'summaries/operation_summaries_panel.dart' show summariesKeyList;
import 'panel_scene/scene_world.dart' show MapPalette;
import 'postcard_summary.dart' show postcardSectionsOrder;
import '../../services/panel_service.dart';

/// The Operation View's "Info" pane on two-pane layouts (see
/// docs/design/layouts.md): basic operation statistics, then the score
/// summaries. When a call is being logged it becomes the Call Info detail.
/// Each Summaries pane is one of these that is never handed a call.
///
/// Each section folds down to its heading and drags to another place; the
/// placement's settings pick the pane's theme and which sections it shows
/// ([InformationPanelSettings]).
class InformationPanel extends StatefulWidget {
  final Operation operation;
  final List<Qso> qsos;

  /// When set, the pane shows the Call Info detail instead of the operation
  /// stats — the current call being logged.
  final CallInfoData? callInfo;
  final HaLoServices? services;
  final String? ourEntityPrefix;

  /// The active extension logging controls (same list `QsoList` uses) — a
  /// scorer summary's tally icons are tinted with its own control's accent
  /// color, same as the QSO rows' ref icons would be if they used one.
  final List<Map<String, dynamic>> activityControls;

  /// The stats' heading, when the log is not an operation's — the Chasing
  /// view's names its period. Null reads "Operation Stats".
  final String? statsTitle;

  /// Each chasing goal's checklist, the Chasing view's — shown above the
  /// period's own scoring.
  final List<ChaseSummary> chaseSummaries;

  /// The placement whose config holds the pane's theme, section order,
  /// hidden sections and folds. Null keeps them for as long as the pane
  /// lives.
  final String? panelId;

  /// Where [panelId]'s config is kept; [services]' own when null.
  final PanelService? panels;

  const InformationPanel({
    super.key,
    required this.operation,
    required this.qsos,
    this.callInfo,
    this.services,
    this.ourEntityPrefix,
    this.activityControls = const [],
    this.statsTitle,
    this.chaseSummaries = const [],
    this.panelId,
    this.panels,
  });

  @override
  State<InformationPanel> createState() => _InformationPanelState();
}

/// The width of the column the fold arrows stand in, left of every heading.
const _foldSlot = 16.0 + Space.xs;

/// How far every section's contents sit in from the arrows' column: half a
/// heading icon's indent, so they stand clear of the headings without
/// spending a whole icon's width.
const _contentsIndent = summaryIconIndent / 2;

/// One of the Info pane's sections: a heading that folds its [body] away,
/// and drags the section to another place in the pane. [key] is what the
/// operator's order, folds and hidden sections name it by, the same from
/// one operation to the next: the Summaries pane's section keys. [score]
/// stands beside the title while the body is on screen, [foldedScore] while
/// it is folded away and cannot say it.
typedef InfoSection = ({String key, String title, String? icon, Color? iconColor, String? score, String? foldedScore, List<Widget> body});

/// The keys an Info pane placement's config is kept under, each a list of
/// section keys but [infoThemeKey].
const infoOrderKey = 'order';
const infoHiddenKey = 'hidden';
const infoFoldedKey = 'folded';

/// The face the pane is drawn on: one of [infoThemes], or none for the
/// app's own.
const infoThemeKey = 'theme';

/// How a checklist marks its codes: [infoHighlightWorked] draws those worked
/// at full strength, anything else (none stored, too) those still open.
const infoChecklistStyleKey = 'checklistStyle';
const infoHighlightPending = 'pending';
const infoHighlightWorked = 'worked';

/// The theme picker's value for the app's own face, which is stored as none.
const infoAppTheme = 'app';

/// The faces an Info pane can be drawn on: the panel scenes' palettes'
/// (`MapPalette`), so a pane can match the dashboard panels beside it.
const infoThemes = ['gray', 'muted', 'contrast', 'teal'];

/// Declared so the dock offers the pane's settings, and so
/// `forgetInstanceConfig` forgets them with the placement: no form renders
/// them, [InformationPanelSettings] does.
const List<Map<String, dynamic>> informationPanelFields = [
  {'type': 'field', 'key': infoOrderKey, 'fieldType': 'text', 'label': ''},
  {'type': 'field', 'key': infoHiddenKey, 'fieldType': 'text', 'label': ''},
  {'type': 'field', 'key': infoFoldedKey, 'fieldType': 'text', 'label': ''},
  {'type': 'field', 'key': infoThemeKey, 'fieldType': 'text', 'label': ''},
  {'type': 'field', 'key': infoChecklistStyleKey, 'fieldType': 'text', 'label': ''},
];

/// [base] redrawn on the face of the theme named [name], or null for the
/// app's own. Text and icons take the face's own contrast, so a dark face in
/// a light app reads light and a light one (Teal, in both app themes) dark.
ThemeData? informationPaneTheme(ThemeData base, String? name) {
  if (name == null || !infoThemes.contains(name)) return null;
  final face = MapPalette.named(name).backgroundFor(base.brightness == Brightness.dark);
  final scheme = ColorScheme.fromSeed(seedColor: face, brightness: ThemeData.estimateBrightnessForColor(face)).copyWith(surface: face);
  return base.copyWith(
    colorScheme: scheme,
    // A dragged section floats on a canvas Material: without these it would
    // carry the face's text over the app's own background.
    canvasColor: face,
    cardColor: face,
    textTheme: base.textTheme.apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface),
    iconTheme: base.iconTheme.copyWith(color: scheme.onSurfaceVariant),
  );
}

/// [sections] in [order]; one the order does not name yet (a scorer first
/// seen since) goes after those it does, as it came. Those [hidden] are left
/// out.
List<InfoSection> infoSectionsInOrder(List<InfoSection> sections, {List<String> order = const [], Set<String> hidden = const {}}) {
  final byKey = {for (final section in sections) section.key: section};
  return [
    for (final key in {...order.where(byKey.containsKey), ...byKey.keys})
      if (!hidden.contains(key)) byKey[key]!,
  ];
}

/// The order to store once a drag leaves the sections listed as [here] in
/// [picked] order: [stored] with those keys reordered in their own places,
/// so the keys not listed (another operation's scorers) keep theirs. An
/// order that only restates how [plain] comes is no order at all; stored, it
/// would pin a scorer first seen tomorrow after all of today's, so then only
/// the keys [plain] does not name are kept. The pane and its settings store
/// the same order for the same drag.
List<String> infoOrderAfterDrag(List<String> stored, List<String> picked, {required Set<String> here, required List<String> plain}) {
  final order = postcardSectionsOrder(stored, picked, here: here);
  final plainOrder = [
    ...{...order.where(plain.contains), ...plain},
  ];
  return listEquals(plainOrder, plain) ? [...stored.where((key) => !plain.contains(key))] : order;
}

class _InformationPanelState extends State<InformationPanel> {
  Map<String, dynamic> _config = const {};
  int _configRevision = 0;

  /// Until the stored picks have loaded, a fold or a drag would be computed
  /// from none and overwrite them all, so neither is taken.
  bool _loaded = false;

  /// Picks written but not yet stored. A reload that finishes meanwhile read
  /// the config from before them, and would otherwise undo them on screen.
  final _unsaved = <String, Object?>{};

  /// The last face built, by its name and the app theme it was built on:
  /// seeding a color scheme is not free, and the pane rebuilds with every
  /// keystroke in the call field.
  (String?, ThemeData, ThemeData?)? _faceCache;

  PanelService? get _panels => widget.panelId == null ? null : widget.panels ?? widget.services?.panels;

  @override
  void initState() {
    super.initState();
    _panels?.addListener(_onPanelsChanged);
    _configRevision = _panels?.configRevision(widget.panelId!) ?? 0;
    unawaited(_loadConfig());
  }

  @override
  void didUpdateWidget(InformationPanel old) {
    super.didUpdateWidget(old);
    final oldPanels = old.panelId == null ? null : old.panels ?? old.services?.panels;
    if (oldPanels != _panels) {
      oldPanels?.removeListener(_onPanelsChanged);
      _panels?.addListener(_onPanelsChanged);
    }
    if (old.panelId != widget.panelId) {
      _configRevision = _panels?.configRevision(widget.panelId!) ?? 0;
      // Another placement's picks, not this one's.
      _config = const {};
      _unsaved.clear();
      _loaded = false;
      unawaited(_loadConfig());
    }
  }

  @override
  void dispose() {
    _panels?.removeListener(_onPanelsChanged);
    super.dispose();
  }

  /// Its settings bump the revision once they have written; nothing else
  /// tells the pane its picks moved.
  void _onPanelsChanged() {
    final revision = _panels?.configRevision(widget.panelId!) ?? 0;
    if (revision == _configRevision) return;
    _configRevision = revision;
    unawaited(_loadConfig());
  }

  Future<void> _loadConfig() async {
    final panels = _panels;
    final panel = panels?[widget.panelId!];
    if (panels == null || panel == null) {
      if (!_loaded) setState(() => _loaded = true);
      return;
    }
    final id = widget.panelId;
    final config = await panels.configFor(panel);
    // A load for the placement this pane showed before is not this one's.
    if (!mounted || id != widget.panelId) return;
    setState(() {
      _config = {...config, ..._unsaved};
      _loaded = true;
    });
  }

  List<String> get _order => summariesKeyList(_config[infoOrderKey]);
  Set<String> get _folded => summariesKeyList(_config[infoFoldedKey]).toSet();

  /// Optimistic, and no revision bump after the write: the pane already
  /// holds the value, and re-reading it would only hand back what it sent.
  /// Without a placement (a bare test harness) the picks last as long as the
  /// pane.
  void _store(String key, List<String> value) {
    setState(() => _config = {..._config, key: value});
    final panels = _panels;
    final panel = panels?[widget.panelId!];
    if (panels == null || panel == null) return;
    final stored = value.isEmpty ? null : value;
    _unsaved[key] = stored;
    unawaited(
      panels
          .writeConfig(panel, {key: stored}, notify: false)
          .then(
            (_) {
              // A later pick of the same key is still on its way.
              if (identical(_unsaved[key], stored)) _unsaved.remove(key);
            },
            onError: (Object error, StackTrace stack) {
              if (identical(_unsaved[key], stored)) _unsaved.remove(key);
              // Back to what is stored, rather than going on showing a pick
              // that never was; the error itself is ErrorPolicy's to report.
              if (mounted) unawaited(_loadConfig());
              Error.throwWithStackTrace(error, stack);
            },
          ),
    );
  }

  void _toggleFold(String key) {
    if (!_loaded) return;
    final folded = _folded;
    if (!folded.remove(key)) folded.add(key);
    _store(infoFoldedKey, folded.toList());
  }

  void _move(List<InfoSection> shown, List<InfoSection> plain, int from, int to) {
    if (!_loaded) return;
    final keys = [for (final section in shown) section.key];
    final picked = [...keys];
    picked.insert(to, picked.removeAt(from));
    _store(infoOrderKey, infoOrderAfterDrag(_order, picked, here: {...keys}, plain: [for (final section in plain) section.key]));
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final name = _config[infoThemeKey] as String?;
    final cache = _faceCache;
    final theme = cache != null && cache.$1 == name && identical(cache.$2, base) ? cache.$3 : informationPaneTheme(base, name);
    _faceCache = (name, base, theme);
    final pane = _pane(context);
    if (theme == null) return pane;
    // A Material, not a bare color: the headings' ink paints on the nearest
    // Material, and the app's own, beneath the face, would hide it.
    return Theme(
      data: theme,
      child: Material(color: theme.colorScheme.surface, child: pane),
    );
  }

  Widget _pane(BuildContext context) {
    final info = widget.callInfo;
    final services = widget.services;
    if (info != null && services != null) {
      return Padding(
        padding: PaneSafeArea.paddingOf(context),
        child: CallInfoPanel(
          operation: widget.operation,
          services: services,
          call: info.call,
          guess: info.guess,
          lookups: info.lookups,
          alertKeys: info.alertKeys,
          noticeKeys: info.noticeKeys,
          scoreSources: info.scoreSources,
          ourEntityPrefix: widget.ourEntityPrefix,
        ),
      );
    }
    // Built under the pane's own theme, so the stats and every section take
    // its face's colors.
    return Builder(
      builder: (context) {
        final plain = informationSections(
          context,
          operation: widget.operation,
          qsos: widget.qsos,
          services: services,
          activityControls: widget.activityControls,
          statsTitle: widget.statsTitle,
          chaseSummaries: widget.chaseSummaries,
          highlightPending: _config[infoChecklistStyleKey] != infoHighlightWorked,
        );
        final sections = infoSectionsInOrder(plain, order: _order, hidden: summariesKeyList(_config[infoHiddenKey]).toSet());
        if (sections.isEmpty) {
          return Padding(
            padding: EdgeInsets.all(Space.xl) + PaneSafeArea.paddingOf(context),
            child: Center(child: Text(context.t.operation.layout.panels.summariesAllHidden, textAlign: TextAlign.center)),
          );
        }
        final folded = _folded;
        return ReorderableListView(
          // No inset on the left: the fold arrows' column is that margin.
          // Extra inset on every edge that's a divider grab strip or a real
          // device safe area.
          padding: const EdgeInsets.fromLTRB(0, Space.md, Space.xl, Space.xl) + PaneSafeArea.paddingOf(context),
          // The heading is the handle, not a grip icon of its own.
          buildDefaultDragHandles: false,
          onReorderItem: (from, to) => _move(sections, plain, from, to),
          children: [
            for (final (index, section) in sections.indexed)
              Padding(
                key: ValueKey(section.key),
                padding: const EdgeInsets.only(bottom: Space.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _section(context, section, index: index, folded: folded.contains(section.key)),
                ),
              ),
          ],
        );
      },
    );
  }

  List<Widget> _section(BuildContext context, InfoSection section, {required int index, required bool folded}) {
    final foldable = section.body.isNotEmpty;
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: _foldSlot,
          child: foldable
              ? Padding(
                  padding: const EdgeInsets.only(top: Space.xxs),
                  child: Icon(folded ? MdiIcons.chevronRight : MdiIcons.chevronDown, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                )
              : null,
        ),
        Expanded(
          child: summaryHeading(
            context,
            title: section.title,
            icon: section.icon,
            iconColor: section.iconColor,
            score: folded ? section.foldedScore : section.score,
          ),
        ),
      ],
    );
    final heading = foldable
        ? Semantics(
            button: true,
            expanded: !folded,
            child: InkWell(onTap: () => _toggleFold(section.key), child: row),
          )
        : row;
    // On a touch screen a press on the heading has to hold before it drags,
    // or a swipe that starts there would move the section instead of
    // scrolling the pane.
    final touch = switch (Theme.of(context).platform) {
      TargetPlatform.android || TargetPlatform.iOS => true,
      _ => false,
    };
    return [
      touch ? ReorderableDelayedDragStartListener(index: index, child: heading) : ReorderableDragStartListener(index: index, child: heading),
      if (foldable && !folded)
        for (final child in section.body)
          Padding(
            padding: const EdgeInsets.only(left: _foldSlot + _contentsIndent),
            child: child,
          ),
    ];
  }
}

/// What the Info pane shows for [operation] when no call is being logged,
/// as sections, in the order they come: the stats, the Chasing view's
/// checklists, each day when there is more than one, then every scorer's
/// tallies. The pane and its settings both list these.
List<InfoSection> informationSections(
  BuildContext context, {
  required Operation operation,
  required List<Qso> qsos,
  HaLoServices? services,
  List<Map<String, dynamic>> activityControls = const [],
  String? statsTitle,
  List<ChaseSummary> chaseSummaries = const [],

  /// Checklists draw the codes still open at full strength, rather than
  /// those worked.
  bool highlightPending = false,
}) {
  // Cached by `ScoringService.rescoreOperation` into `Operations.localData`
  // (never synced — DESIGN.md §4) each time this operation is (re)scored;
  // absent until the first rescore completes.
  final scoring = operation.localData['scoring'] as Map<String, dynamic>?;
  final scorerKeys = orderedScorerKeys(scoring);
  final duplicateCount = ((operationSummaryFor(scoring, 'core')?['qsoCount'] as Map?)?['duplicates'] as num?)?.toInt() ?? 0;
  // A single-day operation's per-day breakdown would just restate the
  // totals below it — the split only earns its place once there's more
  // than one day to tell apart.
  final daySections = mergedDaySections(scoring);
  // Contests first, then activities (parks and the like), then core's own
  // DXCC/states/bands bookkeeping last — the order `orderedScorerKeys`
  // returns. Each tally's own label is its section's title; there is no
  // heading over them, per scorer or for the lot.
  final scoringSections = [
    for (final scorerKey in scorerKeys)
      ..._scorerSections(
        context,
        scorerKey,
        scoring,
        operation: operation,
        services: services,
        activityControls: activityControls,
        highlightPending: highlightPending,
      ),
  ];

  final theme = Theme.of(context);
  // The logging panel's reading of the lifecycle, from the record alone.
  // The panel also counts the contacts it logged itself, so while an old
  // log is being typed in, this pane can call it quiet a while before the
  // panel does. None when chasing: that log is no operation of its own, and
  // has no uuid.
  final lifecycle = services != null && operation.uuid.isNotEmpty ? operationLifecycleSpec(context, services, operation) : null;
  final statsLines = operationStatsLinesFor(context, lifecycle);
  return [
    (
      key: 'stats',
      title: statsTitle ?? context.t.loggingPanel.stats,
      icon: null,
      iconColor: null,
      score: null,
      foldedScore: null,
      body: [
        // The "since last" segment is now-relative — re-derived once a
        // second (scoped to these lines) so it doesn't sit stale between
        // QSO stream updates.
        OncePerSecond(
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final line in statsLines(qsos)) Text(line, style: theme.textTheme.bodyMedium),
              if (duplicateCount > 0) Text('${context.t.loggingPanel.duplicates}: ${formatNumber(duplicateCount)}', style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    ),
    if (chaseSummaries.isNotEmpty)
      (
        key: 'checklists',
        title: context.t.chase.checklists,
        icon: null,
        iconColor: null,
        score: null,
        foldedScore: null,
        body: [
          for (final summary in chaseSummaries)
            ..._checklistRows(context, summary.tallies, resolveExtensionColor(summary.program.color) ?? theme.colorScheme.onSurfaceVariant),
        ],
      ),
    if (daySections.length > 1)
      (
        key: 'days',
        title: context.t.operation.layout.panels.summariesDays,
        icon: null,
        iconColor: null,
        score: null,
        foldedScore: null,
        body: summaryDayBlocks(context, daySections, extensions: services?.extensions, highlightPending: highlightPending),
      ),
    ...scoringSections,
  ];
}

/// One scorer's tallies, a section each — no heading of its own; each
/// tally's `label` IS its section's title, so a scorer with several tallies
/// (core's DXCC/states/bands) reads as several titled sections in a row
/// rather than one heading followed by an undifferentiated list.
List<InfoSection> _scorerSections(
  BuildContext context,
  String scorerKey,
  Map<String, dynamic>? scoring, {
  required Operation operation,
  required HaLoServices? services,
  required List<Map<String, dynamic>> activityControls,
  required bool highlightPending,
}) {
  final summary = operationSummaryFor(scoring, scorerKey);
  if (summary == null || summary.isEmpty) return const [];
  final theme = Theme.of(context);
  final iconColor = scorerIconColor(operation, scorerKey, activityControls) ?? theme.colorScheme.onSurfaceVariant;
  final images = extensionImagesFor(services?.extensions, scorerKey);
  return [
    for (final (:key, :tally) in summaryTallies(summary))
      (
        key: '$scorerKey.$key',
        title: tally['label'] as String,
        icon: tally['icon'] is String ? tally['icon'] as String : null,
        iconColor: iconColor,
        score: tallyScore(tally),
        // Folded, the short summary stands beside the title even where the
        // detail would otherwise carry it: the detail is out of sight.
        foldedScore: tally['summary'] is String ? tally['summary'] as String : null,
        body: [
          if (tally['longSummary'] is String && (tally['longSummary'] as String).isNotEmpty)
            summaryTallyDetail(context, tally['longSummary'] as String, isGrid: tally['grid'] == true, images: images, highlightPending: highlightPending),
        ],
      ),
  ];
}

/// A chasing program's tallies, each one sentence of body text beside its
/// icon: "2 DXCC Entities, 0 confirmed". Scoring's two-column treatment
/// lines a number up for comparing against the next period; a checklist
/// has no period, and its `summary` reads as the rest of the sentence.
List<Widget> _checklistRows(BuildContext context, Map<String, dynamic> tallies, Color iconColor) {
  final theme = Theme.of(context);
  return [
    for (final tally in tallies.values)
      if (tally is Map && tally['label'] is String && (tally['label'] as String).isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: Space.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (tally['icon'] is String) ...[
                Padding(
                  padding: const EdgeInsets.only(top: Space.xxs),
                  child: Icon(resolveIconName(tally['icon'] as String), size: 16, color: iconColor),
                ),
                const SizedBox(width: Space.sm),
              ],
              Expanded(
                child: Text(
                  [tally['label'], if (tally['summary'] is String && (tally['summary'] as String).isNotEmpty) tally['summary']].join(', '),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
  ];
}

/// One block per calendar day the operation spans: the date, that day's QSO
/// count, then each scorer's DAY-scoped tallies (`for: 'day'`) — an
/// activity's activation progress resets with the day it's scoped to, while
/// carry-over tallies like DXCC or bands/modes stay in the operation totals
/// below rather than repeating unchanged under every day.
///
/// A day's tallies are keyed `<scorerKey>.<tallyKey>`, so each draws the
/// images of the extension behind its scorer, from [extensions].
List<Widget> summaryDayBlocks(BuildContext context, List<Map<String, dynamic>> daySections, {ExtensionService? extensions, bool highlightPending = false}) {
  final theme = Theme.of(context);
  final t = context.t.loggingControls.info;
  // Per-locale, not a bare `DateFormat(...)`: weekday/month names are
  // locale text (halo_widgets' DayHeaderRow localizes the same day-header
  // vocabulary the same way).
  final dayFormat = DateFormat.yMMMMEEEEd(Localizations.localeOf(context).toLanguageTag());
  final widgets = <Widget>[];
  for (final section in daySections) {
    final dayMillis = (section['day'] as num).toInt();
    final scores = (section['scores'] as Map?)?.cast<String, dynamic>() ?? const {};
    final count = ((scores['core.qsoCount'] as Map?)?['count'] as num?)?.toInt() ?? 0;

    widgets.add(
      Padding(
        padding: const EdgeInsets.only(top: Space.xl, bottom: Space.sm),
        child: Text.rich(
          TextSpan(
            style: theme.textTheme.bodyMedium,
            children: [
              TextSpan(
                text: '${dayFormat.format(DateTime.fromMillisecondsSinceEpoch(dayMillis, isUtc: true))}: ',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(text: count == 1 ? t.qsoCountOne : t.qsoCountOther(count: count)),
            ],
          ),
        ),
      ),
    );

    final dayTallies = Map<String, dynamic>.fromEntries(
      scores.entries.where((entry) {
        final tally = entry.value;
        return tally is Map && tally['key'] != 'qsoCount' && tally['for'] == 'day';
      }),
    );
    widgets.addAll(
      summaryTallyRows(
        context,
        dayTallies,
        theme.colorScheme.onSurfaceVariant,
        imagesFor: (key) => extensionImagesFor(extensions, scorerKeyOfDayTally(key)),
        highlightPending: highlightPending,
      ),
    );
  }
  return widgets;
}

/// The scorer a merged day tally belongs to, from its `<scorerKey>.<tallyKey>`
/// key: before the first dot, since a scorer's key has none and a tally's
/// may.
String scorerKeyOfDayTally(String key) {
  final dot = key.indexOf('.');
  return dot < 0 ? key : key.substring(0, dot);
}

/// The tallies a summary lists: every one with a label but the QSO count,
/// which the stats already give.
Iterable<({String key, Map<dynamic, dynamic> tally})> summaryTallies(Map<String, dynamic>? summary) sync* {
  for (final MapEntry(:key, :value) in (summary ?? const <String, dynamic>{}).entries) {
    if (key == 'qsoCount' || value is! Map) continue;
    final label = value['label'];
    if (label is String && label.isNotEmpty) yield (key: key, tally: value);
  }
}

/// One titled section per tally: its icon, label (as the section's own
/// heading) and score, then its `longSummary` markdown in full underneath
/// — each day's tallies, under its date ([summaryDayBlocks]), with plain
/// `onSurfaceVariant` icons. `qsoCount` is always skipped: its count is
/// already the day's "N QSOs" line.
///
/// [imagesFor] says how a tally's `longSummary` draws its images, by the
/// tally's key: its scorer's extension's own. Null draws each as alt text.
List<Widget> summaryTallyRows(
  BuildContext context,
  Map<String, dynamic> summary,
  Color iconColor, {
  MarkdownSizedImageBuilder? Function(String key)? imagesFor,
  bool highlightPending = false,
}) {
  final widgets = <Widget>[];
  for (final (:key, :tally) in summaryTallies(summary)) {
    final label = tally['label'] as String;
    final longSummary = tally['longSummary'];
    final detail = longSummary is String ? longSummary : null;
    final score = tallyScore(tally);

    widgets.add(summaryHeading(context, title: label, icon: tally['icon'] is String ? tally['icon'] as String : null, iconColor: iconColor, score: score));

    if (detail != null && detail.isNotEmpty) {
      widgets.add(
        summaryTallyDetail(
          context,
          detail,
          isGrid: tally['grid'] == true,
          images: imagesFor?.call(key),
          indented: tally['icon'] is String,
          highlightPending: highlightPending,
        ),
      );
    }
    // Breathing room after the section, not just before the next one's
    // title — otherwise the last section in a list runs straight into
    // whatever follows it (the duplicates line, the next day, the end of
    // the pane).
    widgets.add(const SizedBox(height: Space.xl));
  }
  return widgets;
}

/// The short `summary` to stand beside a tally's label, or null. It usually
/// restates what `longSummary` already says in full ("5" beside "5 DXCC
/// Entities" whose flags list is right below it), so it only gets its own
/// column when there's no detail to carry it — or when the tally sets
/// `summaryWithDetail`, for a figure the label and detail don't spell out
/// (a points total above the breakdown that earned it).
String? tallyScore(Map<dynamic, dynamic> tally) {
  final score = tally['summary'];
  if (score is! String || score.isEmpty) return null;
  final detail = tally['longSummary'];
  final hasDetail = detail is String && detail.isNotEmpty;
  return !hasDetail || tally['summaryWithDetail'] == true ? score : null;
}

/// The size of a summary section's icon, in its heading.
const summaryIconSize = 16.0;

/// How far a section's contents sit in from its heading's icon: the icon and
/// the gap after it, so the contents line up under the title.
const summaryIconIndent = summaryIconSize + Space.sm;

/// A summary section's title row: the tally's icon, its label, and a score
/// at the end of the line.
Widget summaryHeading(BuildContext context, {required String title, String? icon, Color? iconColor, String? score}) {
  final theme = Theme.of(context);
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (icon != null) ...[
        // `titleSmall`'s cap-height sits a couple of pixels below the
        // icon's own top edge — nudged down so the icon's optical center
        // lines up with the title's baseline instead of its bounding box.
        Padding(
          padding: const EdgeInsets.only(top: Space.xxs),
          child: Icon(resolveIconName(icon), size: summaryIconSize, color: iconColor ?? theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(width: summaryIconIndent - summaryIconSize),
      ],
      Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
      if (score != null && score.isNotEmpty) Text(score, style: theme.textTheme.titleMedium?.copyWith(fontFamily: 'RobotoMono')),
    ],
  );
}

/// A tally's `longSummary` markdown — a DXCC entities list or a band
/// breakdown reads as prose, in the pane's ordinary proportional font. A
/// tally that opts in with `grid: true` (any scorer's own fixed-set
/// checklist — states/provinces today, a contest's multiplier list or an
/// activity's award grid tomorrow) gets the monospace checklist treatment
/// instead. Rows are separated by single newlines, which Markdown would
/// otherwise fold into one run-on paragraph.
///
/// [images] draws its images: the scorer's extension's own. Null draws each
/// as its alt text. [indented] lines it up under the title of a heading that
/// has an icon.
Widget summaryTallyDetail(
  BuildContext context,
  String detail, {
  required bool isGrid,
  MarkdownSizedImageBuilder? images,
  bool indented = false,
  bool highlightPending = false,
}) {
  final theme = Theme.of(context);
  final bodyStyle = theme.textTheme.bodyMedium ?? const TextStyle(fontSize: 14);
  final grid = bodyStyle.copyWith(fontFamily: 'RobotoMono', fontSize: 12);
  // One of the two at full strength and bold, the other dimmer than
  // onSurfaceVariant alone, so it all but recedes: the grid reads at a
  // glance as done versus still needed rather than everything competing at
  // the same weight. Worked codes by default; [highlightPending] turns it
  // around for an operator hunting what is left.
  final highlighted = grid.copyWith(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w700);
  final receding = grid.copyWith(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5));
  MarkdownStyleSheet style(MarkdownStyleSheet base) => base.copyWith(
    // The codes still open are the paragraph; a worked one is struck
    // through as well.
    p: isGrid ? (highlightPending ? highlighted : receding) : bodyStyle,
    // `null` when not a grid leaves the theme's own `del` style alone
    // (`copyWith`'s `del ?? this.del`).
    del: isGrid ? (highlightPending ? receding : highlighted).copyWith(decoration: TextDecoration.lineThrough) : null,
  );
  return Padding(
    padding: EdgeInsets.only(top: Space.xs, left: indented ? summaryIconIndent : 0),
    child: HaloMarkdown(data: detail, softLineBreak: true, style: style, sizedImageBuilder: images),
  );
}

/// The accent a scorer's tallies wear: its extension's own declared color,
/// the same one its references' icons are tinted with — or null when it
/// declares none. Shared with the Operation Postcard's summary pages.
Color? scorerIconColor(Operation operation, String scorerKey, List<Map<String, dynamic>> activityControls) {
  // A contest's ref type IS its scorer key, but an activity's is the key plus
  // a suffix (`pota` scores an operation whose ref type is `potaActivation`),
  // so an exact match alone would leave every activity's icons uncolored.
  // Ref types are namespaced by extension key, which is what makes the prefix
  // fallback safe.
  //
  // An operation that only HUNTS a program carries no ref for it at all
  // (docs/design/activities.md §4) and still scores, so fall back to the
  // hunting control's own accent.
  final refs = operation.refs.cast<Map<String, dynamic>?>();
  final ref =
      refs.firstWhere((r) => r?['type'] == scorerKey, orElse: () => null) ??
      refs.firstWhere((r) => (r?['type'] as String?)?.startsWith(scorerKey) ?? false, orElse: () => null);
  // Each extension's own declared accent (same color `activityRefIcon`
  // tints its icon with) rather than one shared tertiary for every
  // scorer.
  // Falling back to the scorer key whenever the ref's own type misses, not
  // only when there is no ref: a control declares the HUNTING type
  // ('pota'), while an activating operation's ref carries the activation one
  // ('potaActivation'), so the commoner case would otherwise be the grey one.
  return colorForRefType(activityControls, ref?['type'] as String?, code: ref == null ? null : refCodeOf(ref)) ?? colorForRefType(activityControls, scorerKey);
}
