// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

part of 'activities_view.dart';

/// The operation pills' own geometry — shared by the rows that lay them out and
/// by the width arithmetic that decides how many pills there are, which only
/// agrees with the layout while these are the same numbers.
const _pillSpacing = 8.0;
const _pillRunSpacing = 4.0;
const _pillPadding = Space.md;
const _pillIconSize = 16.0;

/// The narrowest an icon-only pill gets (pills carrying a value take exactly
/// the width their value needs).
const _pillMinWidth = 40.0;

/// A free-text operation title ellipsizes here rather than pushing the
/// callsign pills aside — room for a couple of words, no more: the whole title
/// is one tap away in the details editor.
const _titlePillMaxWidth = 140.0;

/// One operation pill, with the width it will take once laid out and how
/// eagerly it is dropped when the group would otherwise run past
/// [_maxPillLines]: the lowest non-zero [dropOrder] goes first, and 0 never
/// goes.
class _HeaderPill {
  final Widget widget;
  final double width;
  final int dropOrder;

  /// Whether this pill gives up the difference when its run is laid out in
  /// less width than it needs — `Flexible`, so the run never overflows. Only
  /// the identity run can be in that position (its pills never shed), and only
  /// its station pill carries this.
  final bool absorbsShortfall;

  const _HeaderPill(this.widget, this.width, {this.dropOrder = 0, this.absorbsShortfall = false});
}

/// What the header row keeps for its "N Activities Selected" title and
/// subtitle before the operation pills are allowed to wrap: enough for the
/// title at its usual length, plus the [Space.xl] gutter it holds against the
/// pills. Wide enough to matter, narrow enough that the pills stay on one
/// line in every layout they fit.
const _headerTitleMinWidth = 200.0;

mixin _ActivitiesHeader on State<OperationSheet> {
  Operation get _operation;
  List<Map<String, dynamic>> get _controls;

  String _activitiesTitle(int count) {
    final t = context.t.activitiesView;
    if (count == 0) return t.activitiesCountZero;
    if (count == 1) return t.activitiesCountOne;
    return t.activitiesCountOther(count: count);
  }

  String _groupedActivitiesSubtitle(List<Map<String, dynamic>> refs) {
    final types = refs.map((r) => r['type'] as String?).whereType<String>().where((t) => t.isNotEmpty).toList();
    final counts = <String, int>{};
    for (final type in types) {
      counts[type] = (counts[type] ?? 0) + 1;
    }
    final parts = <String>[];
    for (final entry in counts.entries) {
      final shortName = _shortNameForType(entry.key);
      if (entry.value > 1) {
        parts.add('$shortName×${entry.value}');
      } else {
        parts.add(shortName);
      }
    }
    return parts.join(', ');
  }

  String _shortNameForType(String type) {
    final control = controlForRefType(_controls, type);
    if (control != null) {
      final controlKey = control['key'] as String? ?? '';
      final extensionKey = controlKey.split('/').first;
      final extension = widget.services.extensions.availableExtensions.cast<ExtensionInfo?>().firstWhere(
        (info) => info?.key == extensionKey,
        orElse: () => null,
      );
      final label = extension?.effectiveShortName ?? (control['label'] as String?) ?? '';
      if (label.isNotEmpty) return label;
    }
    return type.toUpperCase();
  }

  /// The operation's own identity — Station/Op callsign chips, the free-text
  /// title, a notes marker and the pencil that advertises the whole group is
  /// tappable — shown at the far right of the always-visible header row,
  /// wrapping onto at most [_maxPillLines] runs within [availableWidth] and dropping
  /// its least informative members rather than take a third. Tapping any of it
  /// opens the details editor (see [OperationSheet.onEditDetails]).
  Widget _operationPills(ThemeData theme, double availableWidth) {
    final stationCall = _operation.stationCall;
    final operatorCall = operatorCallFor(_operation);
    final operationTitle = _operation.userTitle;
    final notes = asQsonString(_operation.data['notes']) ?? '';
    final multiIdentifier = asQsonString(_operation.localData['multiIdentifier']) ?? '';

    // Only the station chip carries the full teal; its companions are the
    // same hue a step lighter, so the station callsign reads first.
    final chipColor = theme.appBarTheme.backgroundColor ?? theme.colorScheme.primary;
    final lightChipColor = Color.lerp(chipColor, Colors.white, 0.25)!;
    // Carried on the spans themselves rather than left to the chip's
    // DefaultTextStyle: the measuring below has to see the very style the
    // pill renders at, or the line count it predicts is not the one the Wrap
    // produces.
    final pillTextStyle = theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.bold);
    // [minWidth] is for the icon-only pills, whose glyph alone reads as a blob
    // rather than as one of the row's chips. A pill carrying a value is never
    // padded out past it: the callsigns' widths are information.
    Widget chip(Widget child, {bool light = false, double? minWidth, bool ellipsize = true}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: _pillPadding, vertical: Space.xs),
      // Constraints only, never `alignment`: a Container with an alignment
      // takes ALL the width it is offered instead of hugging its child, so
      // the floor would become the whole row. The centering that goes with
      // it rides on the text style below.
      constraints: minWidth == null ? null : BoxConstraints(minWidth: minWidth),
      decoration: BoxDecoration(color: light ? lightChipColor : chipColor, borderRadius: BorderRadius.circular(12)),
      // A pill is one line, always: a callsign broken across two lines
      // inside a rounded chip reads as damage, so a squeezed pill
      // ellipsizes instead (and the whole group sheds pills before it
      // gets that tight — see below). Where [ellipsize] is off the text
      // runs past the chip rather than lose a character — a half-read
      // callsign is worse than an untidy one.
      child: DefaultTextStyle.merge(
        style: pillTextStyle,
        textAlign: TextAlign.center,
        softWrap: false,
        maxLines: 1,
        overflow: ellipsize ? TextOverflow.ellipsis : TextOverflow.visible,
        child: child,
      ),
    );

    // The glyph rides inside a Text so the chip takes its height from the
    // same line box as its text-bearing siblings, rather than from the
    // glyph. Nudged up 1px: the glyph's own bearing sits it slightly low
    // against the text line box that PlaceholderAlignment.middle centers on.
    Widget iconPill(IconData icon, {String? semanticLabel, double? minWidth = _pillMinWidth}) => chip(
      light: true,
      minWidth: minWidth,
      Text.rich(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Transform.translate(
            offset: const Offset(0, -1),
            child: Icon(icon, size: _pillIconSize, color: theme.colorScheme.onPrimary, semanticLabel: semanticLabel),
          ),
        ),
      ),
    );

    // The shared measurer: it folds in the ambient DefaultTextStyle the chip
    // renders through and disposes its painter, both of which a hand-rolled
    // TextPainter here would get wrong.
    // Rounded UP: a paragraph lays out a hair wider than its measured width,
    // and a prediction that lands a tenth of a pixel short is still a row
    // overflow.
    double measure(List<InlineSpan> spans) => (spansWidth(context, spans, pillTextStyle) + _pillPadding * 2).ceilToDouble();

    // An icon inside a WidgetSpan is scaled by the text scaler like the text
    // around it, so the icon pills' widths cannot be constants — a declared
    // width that lags the rendered one is how the two-run cap silently
    // becomes three.
    final scaledIcon = MediaQuery.textScalerOf(context).scale(_pillIconSize);
    final iconPillNaturalWidth = scaledIcon + _pillPadding * 2;
    final iconPillWidth = math.max(_pillMinWidth, iconPillNaturalWidth);

    const callStyle = TextStyle(fontFamily: 'RobotoMono');
    final stationSpans = [const TextSpan(text: 'Station: '), TextSpan(text: stationCall, style: callStyle)];
    final operatorSpans = [const TextSpan(text: 'Op: '), TextSpan(text: operatorCall, style: callStyle)];
    // Shown to anyone who has a position set, developer mode or not: the
    // identifier keeps suffixing this device's spots (`K2SUL/OP2`) after
    // developer mode goes off, and this pill is the only thing on the sheet
    // that explains where that came from.
    final positionSpans = [const TextSpan(text: 'Pos: '), TextSpan(text: multiIdentifier, style: callStyle)];

    // What the pills may take before they start shedding: the title keeps
    // _headerTitleMinWidth of the row for its count and subtitle. They can
    // still end up wider than this — the station callsign and the pencil never
    // go — but only after everything sheddable has gone.
    final pillBudget = math.max(0.0, availableWidth - _headerTitleMinWidth);
    final stationWidth = measure(stationSpans);

    // The operation's identity — always the top line, in this order.
    final identity = <_HeaderPill>[
      if (multiIdentifier.isNotEmpty)
        _HeaderPill(
          chip(light: true, Text.rich(TextSpan(children: positionSpans))),
          measure(positionSpans),
          // Last of the droppable pills to go: it is short, and losing it
          // leaves the row saying nothing about a call that goes out modified.
          dropOrder: 4,
        ),
      if (operatorCall.isNotEmpty) _HeaderPill(chip(light: true, Text.rich(TextSpan(children: operatorSpans))), measure(operatorSpans), dropOrder: 2),
      // The station callsign is the one value the header exists to show, so it
      // never truncates and never goes.
      _HeaderPill(chip(Text.rich(TextSpan(children: stationSpans)), ellipsize: false), stationWidth, absorbsShortfall: true),
      // The affordance for what the whole group already does: the pencil
      // carries no tap of its own, so it can't drift from the pills'. Sized to
      // its glyph and nothing more — it is furniture, not a value. It rides
      // with the identity so the row always advertises the tap, whatever else
      // the width forces out.
      _HeaderPill(iconPill(MdiIcons.pencil, semanticLabel: context.t.activitiesView.operationDetails, minWidth: null), iconPillNaturalWidth),
    ];

    // What the operation says about itself beyond its callsigns — the second
    // line when there has to be one.
    final extras = <_HeaderPill>[
      // Notes have no useful short form, so this chip only says that there
      // ARE notes — the details are one tap away, in the same
      // operation-details dialog. Last to go: it is the only place the sheet
      // admits the notes exist at all, where every other pill's value is also
      // spelled out inside the editor.
      if (notes.trim().isNotEmpty) _HeaderPill(iconPill(MdiIcons.fileDocument, semanticLabel: context.t.dialogs.notes), iconPillWidth, dropOrder: 3),
      // A title is free text and can run long — it ellipsizes rather than
      // pushing the callsign chips aside, and it is the first pill to go.
      if (operationTitle.isNotEmpty)
        _HeaderPill(
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _titlePillMaxWidth),
            child: chip(light: true, Text(operationTitle, maxLines: 1, overflow: TextOverflow.ellipsis)),
          ),
          math.min(measure([TextSpan(text: operationTitle)]), _titlePillMaxWidth),
          dropOrder: 1,
        ),
    ];

    // What a shed pill leaves behind: one marker per run, standing where the
    // first of them sat. Without it the row can't be told apart from an
    // operation that simply has no title, no notes and no separate operator —
    // and there would be nothing to say the details editor holds more.
    final ellipsisPill = _HeaderPill(
      chip(light: true, minWidth: _pillMinWidth, const Text('…')),
      math.max(_pillMinWidth, measure([const TextSpan(text: '…')])),
    );

    double runWidth(List<_HeaderPill> run) => run.fold(0.0, (total, pill) => total + pill.width) + math.max(0, run.length - 1) * _pillSpacing;

    /// [run] narrowed to [budget] by shedding its least informative pills
    /// (lowest non-zero [_HeaderPill.dropOrder] first; 0 never goes), with what
    /// went alongside what stayed.
    (List<_HeaderPill>, List<_HeaderPill>) fitRun(List<_HeaderPill> run, double budget) {
      final kept = run.toList();
      final shed = <_HeaderPill>[];
      while (runWidth(kept) > budget) {
        final droppable = kept.where((pill) => pill.dropOrder > 0).toList()..sort((a, b) => a.dropOrder.compareTo(b.dropOrder));
        if (droppable.isEmpty) break;
        kept.remove(droppable.first);
        shed.add(droppable.first);
      }
      return (kept, shed);
    }

    /// [fitRun] for a run whose shed pills are gone for good: one
    /// [ellipsisPill] takes the first one's place, and since the marker is
    /// itself part of what has to fit, making room for it can cost one more.
    List<_HeaderPill> fitAndMark(List<_HeaderPill> run, double budget) {
      final (kept, shed) = fitRun(run, budget);
      if (shed.isEmpty) return kept;
      kept.insert(run.indexOf(shed.first).clamp(0, kept.length), ellipsisPill);
      return fitRun(kept, budget).$1;
    }

    // One line while everything fits on one; otherwise exactly two, identity on
    // top. Never three: a third run reads as a wall across the header. Each run
    // is fitted on its own — a pill the identity line has no room for becomes a
    // "…" there rather than moving down to the extras, because the callsigns
    // and the pencil are what the top line is FOR, and a reader looking for the
    // operator should not have to find it on another line.
    final oneLine = [...extras, ...identity];
    final runs = runWidth(oneLine) <= pillBudget
        ? [oneLine]
        : [fitAndMark(identity, pillBudget), fitAndMark(extras, pillBudget)].where((run) => run.isNotEmpty).toList();

    // The box is sized to the widest run rather than to the budget: sized any
    // narrower, a run that outgrew the budget (the station callsign and the
    // pencil, which never shed) would lay out in less room than it occupies
    // and paint over itself. The title keeps whatever is left — down to
    // nothing in that same extreme, which beats overlapping text.
    final pillsWidth = math.min(availableWidth, runs.map(runWidth).reduce(math.max));

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: pillsWidth),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        // Opaque: a tap in the gaps between chips still opens the editor
        // rather than falling through to anything behind the pills.
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onEditDetails,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            spacing: _pillRunSpacing,
            children: [
              for (final run in runs)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: _pillSpacing,
                  children: [for (final pill in run) pill.absorbsShortfall ? Flexible(child: pill.widget) : pill.widget],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerBand(ThemeData theme, List<Map<String, dynamic>> refs, Color accordionColor, Color onAccordionColor) {
    // The operation's own header row — always visible, no accordion:
    // the activities count and subtitle at left, the operation pills
    // at right. The pills measure first, at their natural width, and
    // the title takes everything they leave — a flex share instead
    // would ellipsize the title while the pills sat in space they
    // never asked for. The cap is what keeps that honest in the other
    // direction: past it the pills wrap onto a second line rather than
    // squeezing the title away, and it is also what makes an
    // inflexible Row child measurable at all (it is handed unbounded
    // width otherwise, and an unbounded Wrap never wraps).
    return Material(
      color: accordionColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.xl, Space.md, Space.lg, Space.md),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: Space.xl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _activitiesTitle(refs.map((r) => r['type'] as String?).whereType<String>().where((t) => t.isNotEmpty).toSet().length),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(color: onAccordionColor, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: Space.xxs),
                        Text(
                          refs.isEmpty ? context.t.activitiesView.emptySheet : _groupedActivitiesSubtitle(refs),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
                        ),
                      ],
                    ),
                  ),
                ),
                _operationPills(theme, constraints.maxWidth),
              ],
            );
          },
        ),
      ),
    );
  }
}
