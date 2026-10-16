// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Operation Postcard's summary pages: what the Operation View's Info pane
// says about an operation, set on as many postcards as it takes, behind the
// map postcard's own header and footer and over its map, veiled. A section
// goes to a new page when it no longer fits on the one before; a section
// taller than a page runs on to the next under its heading again, marked as
// continued.
//
// Laid out by TextPainter rather than measured from built widgets: every page
// is known before any is built, which the carousel's page count and an export
// of pages never shown both need. A page then draws the same spans at the same
// width, each piece held to the height the layout gave it.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../tools/operation_stats.dart';
import '../../tools/scoring_summaries.dart';
import 'information_panel.dart' show scorerIconColor, summaryTallies;
import 'operation_postcard.dart' show PostcardOverlay, PostcardShape, PostcardText, postcardFooterRoom;

/// A stretch of summary text in one weight.
typedef PostcardRun = ({String text, bool bold, bool struck});

sealed class PostcardBlock {
  const PostcardBlock();
}

/// A heading row: an icon, the words, and a figure at the end of the line. A
/// [major] one heads a section; a minor one, a tally inside a day's section.
final class PostcardHeading extends PostcardBlock {
  final String title;

  /// An MDI icon name, as a tally carries it.
  final String? icon;

  /// The icon's color; null is the ink's.
  final Color? iconColor;
  final String? trailing;
  final bool major;

  const PostcardHeading(this.title, {this.icon, this.iconColor, this.trailing, this.major = true});

  PostcardHeading retitled(String title) => PostcardHeading(title, icon: icon, iconColor: iconColor, trailing: trailing, major: major);
}

enum PostcardTextKind {
  body,

  /// A tally's `grid: true` checklist: monospace, the codes still open dimmed
  /// and the worked ones struck through at full strength.
  grid,

  /// A `#` heading inside a tally's detail.
  subheading,
}

final class PostcardParagraph extends PostcardBlock {
  final List<PostcardRun> runs;
  final PostcardTextKind kind;

  const PostcardParagraph(this.runs, {this.kind = PostcardTextKind.body});

  PostcardParagraph.plain(String text) : this([(text: text, bold: false, struck: false)]);
}

class PostcardSummarySection {
  /// What the operator picks it by, the same from one operation to the next:
  /// [statsKey], [daysKey] for every day's section, or a tally's own
  /// `scorer.tally`.
  final String key;
  final PostcardHeading heading;
  final List<PostcardBlock> body;

  const PostcardSummarySection(this.heading, this.body, {this.key = ''});

  static const statsKey = 'stats';
  static const daysKey = 'days';
}

/// The order to keep after the operator orders one operation's sections as
/// [picked]: [stored] with those sections — the keys [here] — put in their
/// new order in the places they held, and every other operation's keys left
/// where they were among them. A section new to [stored] goes after.
List<String> postcardSectionsOrder(List<String> stored, List<String> picked, {required Set<String> here}) {
  final next = [...picked];
  return [
    for (final key in stored)
      if (!here.contains(key)) key else if (next.isNotEmpty) next.removeAt(0),
    ...next,
  ];
}

/// [sections] in the operator's [order] — a key it does not name, a scorer
/// first seen since, goes after the ones it does, as it came — less those
/// [hidden]. The days, one key among them, move and go together.
List<PostcardSummarySection> postcardSectionsPicked(List<PostcardSummarySection> sections, {List<String> order = const [], Set<String> hidden = const {}}) {
  final keys = <String>[
    for (final key in order)
      if (sections.any((s) => s.key == key)) key,
  ];
  for (final section in sections) {
    if (!keys.contains(section.key)) keys.add(section.key);
  }
  return [
    for (final key in keys)
      if (!hidden.contains(key))
        for (final section in sections)
          if (section.key == key) section,
  ];
}

/// What the Info pane (InformationPanel) shows for [operation], as sections:
/// the stats, then each day's own tallies when there is more than one day,
/// then every scorer's tallies, one section each.
///
/// Three things differ from the pane. The now-relative "since last" is left
/// out: a picture is looked at long after it was made. The duplicates count
/// joins the stats. And the pane's "Scoring" title over the tallies is
/// dropped: every tally has a heading of its own, and alone at the top of a
/// page it would head nothing.
List<PostcardSummarySection> postcardSummarySections(
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
  final dayFormat = DateFormat.yMMMMEEEEd(Localizations.localeOf(context).toLanguageTag());
  final info = t.loggingControls.info;

  PostcardSummarySection day(Map<String, dynamic> section) {
    final scores = (section['scores'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final count = ((scores['core.qsoCount'] as Map?)?['count'] as num?)?.toInt() ?? 0;
    // A day's own tallies only — the ones carried across the operation are
    // in its totals, and would repeat unchanged under every day.
    final tallies = {
      for (final entry in scores.entries)
        if (entry.value case final Map<dynamic, dynamic> tally when tally['key'] != 'qsoCount' && tally['for'] == 'day') entry.key: tally,
    };
    return PostcardSummarySection(
      PostcardHeading(
        dayFormat.format(DateTime.fromMillisecondsSinceEpoch((section['day'] as num).toInt(), isUtc: true)),
        trailing: count == 1 ? info.qsoCountOne : info.qsoCountOther(count: count),
      ),
      [
        for (final (key: _, :tally) in summaryTallies(tallies)) ...[_tallyHeading(tally, major: false), ..._tallyDetail(tally)],
      ],
      key: PostcardSummarySection.daysKey,
    );
  }

  return [
    PostcardSummarySection(PostcardHeading(t.loggingPanel.stats), [
      for (final line in operationStatsLines(context, qsos, sinceLast: false)) PostcardParagraph.plain(line),
      if (duplicates > 0) PostcardParagraph.plain('${t.loggingPanel.duplicates}: ${formatNumber(duplicates)}'),
    ], key: PostcardSummarySection.statsKey),
    if (days.length > 1)
      for (final section in days) day(section),
    for (final scorerKey in orderedScorerKeys(scoring))
      for (final (:key, :tally) in summaryTallies(operationSummaryFor(scoring, scorerKey)))
        PostcardSummarySection(
          _tallyHeading(tally, color: scorerIconColor(operation, scorerKey, activityControls)),
          _tallyDetail(tally),
          key: '$scorerKey.$key',
        ),
  ];
}

/// A tally's short `summary` only stands beside it when there is no detail
/// to say it in full.
PostcardHeading _tallyHeading(Map<dynamic, dynamic> tally, {Color? color, bool major = true}) {
  final detail = tally['longSummary'];
  final score = detail is String && detail.isNotEmpty ? null : tally['summary'];
  return PostcardHeading(
    tally['label'] as String,
    icon: tally['icon'] is String ? tally['icon'] as String : null,
    iconColor: color,
    trailing: score is String && score.isNotEmpty ? score : null,
    major: major,
  );
}

List<PostcardParagraph> _tallyDetail(Map<dynamic, dynamic> tally) {
  final detail = tally['longSummary'];
  return detail is String ? postcardParagraphs(detail, grid: tally['grid'] == true) : const [];
}

final _headingLine = RegExp(r'^ {0,3}#{1,6}\s+(.*?)(\s+#+)?\s*$');

/// [markdown] as the Info pane's MarkdownBody shows it, in the part of
/// Markdown the scorers write: `**strong**`, `~~struck~~`, `#` headings on
/// lines of their own, a line break wherever the source breaks a line (the
/// pane's `softLineBreak`), and a blank line between paragraphs. Anything
/// else stays the text it is.
List<PostcardParagraph> postcardParagraphs(String markdown, {bool grid = false}) {
  final paragraphs = <PostcardParagraph>[];
  final lines = <String>[];
  void flush() {
    if (lines.isEmpty) return;
    paragraphs.add(PostcardParagraph(_runs(lines.join('\n')), kind: grid ? PostcardTextKind.grid : PostcardTextKind.body));
    lines.clear();
  }

  for (final line in markdown.split('\n')) {
    final heading = _headingLine.firstMatch(line);
    if (line.trim().isEmpty) {
      flush();
    } else if (heading != null) {
      flush();
      paragraphs.add(PostcardParagraph(_runs(heading[1]!), kind: PostcardTextKind.subheading));
    } else {
      lines.add(line);
    }
  }
  flush();
  return paragraphs;
}

List<PostcardRun> _runs(String text) {
  final runs = <PostcardRun>[];
  final buffer = StringBuffer();
  var bold = false, struck = false;
  void emit() {
    if (buffer.isNotEmpty) runs.add((text: buffer.toString(), bold: bold, struck: struck));
    buffer.clear();
  }

  for (var i = 0; i < text.length; i++) {
    if (text.startsWith('**', i)) {
      emit();
      bold = !bold;
      i++;
    } else if (text.startsWith('~~', i)) {
      emit();
      struck = !struck;
      i++;
    } else {
      buffer.write(text[i]);
    }
  }
  emit();
  return runs;
}

/// The summary pages' type and its geometry, in the picture's own ink (see
/// [PostcardOverlay]). The layout measures in one ink and a page draws in
/// another, which moves no line.
class _Type {
  final Color ink;

  const _Type(this.ink);

  static const _fallback = [emojiFontFamily];

  /// Centered in their lines, whatever their size, so a heading and the figure
  /// beside it share a middle.
  static const _even = TextLeadingDistribution.even;

  static const iconGap = Space.sm;
  static const trailingGap = Space.md;

  static double headingLine(bool major) => major ? 31 : 26;
  static double iconSize(bool major) => major ? 24 : 20;
  static double iconTop(bool major) => (headingLine(major) - iconSize(major)) / 2;

  TextStyle heading(bool major) => TextStyle(
    fontFamily: major ? 'RobotoSlab' : 'Roboto',
    fontWeight: major ? FontWeight.w800 : FontWeight.w700,
    fontSize: major ? 24 : 20,
    height: headingLine(major) / (major ? 24 : 20),
    leadingDistribution: _even,
    color: ink,
    fontFamilyFallback: _fallback,
  );

  TextStyle trailing(bool major) => TextStyle(
    fontFamily: 'RobotoMono',
    fontWeight: FontWeight.w500,
    fontSize: major ? 22 : 18,
    height: headingLine(major) / (major ? 22 : 18),
    leadingDistribution: _even,
    color: ink,
    fontFamilyFallback: _fallback,
  );

  TextStyle paragraph(PostcardTextKind kind) => switch (kind) {
    PostcardTextKind.body => TextStyle(fontFamily: 'Roboto', fontSize: 20, height: 1.35, color: ink, fontFamilyFallback: _fallback),
    PostcardTextKind.subheading => TextStyle(
      fontFamily: 'Roboto',
      fontWeight: FontWeight.w700,
      fontSize: 20,
      height: 1.35,
      color: ink,
      fontFamilyFallback: _fallback,
    ),
    // Dimmer than the text around it: a code still open should all but
    // recede beside a worked one, as it does in the Info pane.
    PostcardTextKind.grid => TextStyle(fontFamily: 'RobotoMono', fontSize: 17, height: 1.45, color: ink.withValues(alpha: 0.5), fontFamilyFallback: _fallback),
  };

  TextSpan span(PostcardParagraph paragraph) => TextSpan(
    style: this.paragraph(paragraph.kind),
    children: [for (final run in paragraph.runs) TextSpan(text: run.text, style: _run(run, paragraph.kind))],
  );

  TextStyle? _run(PostcardRun run, PostcardTextKind kind) {
    // A worked code, set back to full strength.
    if (run.struck && kind == PostcardTextKind.grid) return TextStyle(color: ink, fontWeight: FontWeight.w700, decoration: TextDecoration.lineThrough);
    if (!run.bold && !run.struck) return null;
    return TextStyle(fontWeight: run.bold ? FontWeight.w700 : null, decoration: run.struck ? TextDecoration.lineThrough : null);
  }
}

/// A block's place on one page: [top] and [height] in the page's content box
/// — see [PostcardSummaryLayout.content] — and, for a paragraph, how far down
/// its own lines the piece begins: [from] is 0 but where a paragraph runs on
/// from the page before.
class PostcardPiece {
  final PostcardBlock block;
  final double top;
  final double height;
  final double from;

  const PostcardPiece({required this.block, required this.top, required this.height, this.from = 0});
}

class PostcardSummaryLayout {
  /// Where the pieces go on a page: under the header, above the footer, in
  /// the page's logical pixels.
  final Rect content;
  final List<List<PostcardPiece>> pages;

  const PostcardSummaryLayout({required this.content, required this.pages});
}

const _sectionGap = Space.xxl;

double _gapBefore(PostcardBlock block) => block is PostcardHeading ? Space.lg : Space.sm;

/// [sections] laid out on pages of [page] size under a header [header] pixels
/// tall. A section starts a new page when it does not fit on what is left of
/// the current one, and one taller than a page starts one and runs on across
/// as many more as it takes, breaking between lines under its heading
/// retitled by [continued]. A tally's heading inside a section is kept with
/// the first line under it.
PostcardSummaryLayout postcardSummaryLayout(
  List<PostcardSummarySection> sections, {
  required Size page,
  required double header,
  required String Function(String title) continued,
}) {
  final content = Rect.fromLTRB(Space.xxl, header + Space.xl, page.width - Space.xxl, page.height - postcardFooterRoom);
  final measure = _Measurer(content.width);
  final pages = <List<PostcardPiece>>[[]];
  var y = 0.0;

  // A hair of slack: a page whose content exactly fills it must not lose its
  // last line to rounding.
  bool fits(double height) => y + height <= content.height + 0.01;
  void newPage() {
    pages.add([]);
    y = 0;
  }

  void put(PostcardBlock block, double gap, double height, {double from = 0}) {
    pages.last.add(PostcardPiece(block: block, top: y + gap, height: height, from: from));
    y += gap + height;
  }

  // Nothing is gained from a new page when this one holds only a heading:
  // what does not fit under it is taller than any page.
  bool headingAlone() => pages.last.length == 1 && pages.last.single.block is PostcardHeading;

  for (final section in sections) {
    final head = measure(section.heading);
    final body = [for (final block in section.body) measure(block)];
    final whole = body.fold(head.height, (sum, b) => sum + _gapBefore(b.block) + b.height);
    if (pages.last.isNotEmpty && !fits(_sectionGap + whole)) newPage();
    put(section.heading, pages.last.isEmpty ? 0 : _sectionGap, head.height);

    void runOn() {
      newPage();
      final again = section.heading.retitled(continued(section.heading.title));
      put(again, 0, measure(again).height);
    }

    for (var i = 0; i < body.length; i++) {
      final b = body[i];
      final gap = _gapBefore(b.block);
      if (b.block is PostcardHeading) {
        final next = i + 1 < body.length ? _gapBefore(body[i + 1].block) + body[i + 1].firstLine : 0.0;
        if (!fits(gap + b.height + next) && !headingAlone()) runOn();
        put(b.block, gap, b.height);
        continue;
      }
      var from = 0;
      while (from < b.lineCount) {
        var to = from;
        while (to < b.lineCount && fits(gap + b.tops[to + 1] - b.tops[from])) {
          to++;
        }
        if (to == from) {
          if (!headingAlone()) {
            runOn();
            continue;
          }
          // A line taller than a page, drawn cut off rather than never.
          to = from + 1;
        }
        put(b.block, gap, b.tops[to] - b.tops[from], from: b.tops[from]);
        from = to;
        if (from < b.lineCount) runOn();
      }
    }
  }
  if (pages.last.isEmpty) pages.removeLast();
  return PostcardSummaryLayout(content: content, pages: pages);
}

/// A block's height, and a paragraph's line tops: [tops] runs from 0 to the
/// paragraph's height, one entry per line and one more for its foot.
typedef _Measured = ({PostcardBlock block, double height, List<double> tops});

extension on _Measured {
  int get lineCount => tops.length - 1;
  double get firstLine => tops.length > 1 ? tops[1] : height;
}

class _Measurer {
  final double width;

  _Measurer(this.width);

  static const _type = _Type(Color(0xFF000000));

  _Measured call(PostcardBlock block) => switch (block) {
    final PostcardHeading heading => _heading(heading),
    final PostcardParagraph paragraph => _paragraph(paragraph),
  };

  _Measured _heading(PostcardHeading heading) {
    final major = heading.major;
    final trailing = heading.trailing == null ? null : _painter(TextSpan(text: heading.trailing, style: _type.trailing(major)), double.infinity);
    final title = _painter(TextSpan(text: heading.title, style: _type.heading(major)), _titleWidth(heading, width, trailing?.width));
    var height = title.height;
    if (trailing != null) height = height > trailing.height ? height : trailing.height;
    if (heading.icon != null) {
      final icon = _Type.iconTop(major) + _Type.iconSize(major);
      if (icon > height) height = icon;
    }
    title.dispose();
    trailing?.dispose();
    return (block: heading, height: height, tops: [0, height]);
  }

  _Measured _paragraph(PostcardParagraph paragraph) {
    final painter = _painter(_type.span(paragraph), width);
    final tops = <double>[0];
    for (final line in painter.computeLineMetrics()) {
      tops.add(tops.last + line.height);
    }
    // The paragraph's own foot, which the lines' heights round to.
    tops[tops.length - 1] = painter.height;
    final height = painter.height;
    painter.dispose();
    return (block: paragraph, height: height, tops: tops);
  }

  static TextPainter _painter(TextSpan text, double maxWidth) => TextPainter(text: text, textDirection: TextDirection.ltr)..layout(maxWidth: maxWidth);
}

/// The width a heading's title wraps in: what the icon and the figure leave
/// of [width]. [_HeadingRow] lays itself out to the same numbers.
double _titleWidth(PostcardHeading heading, double width, double? trailingWidth) {
  var left = width;
  if (heading.icon != null) left -= _Type.iconSize(heading.major) + _Type.iconGap;
  if (trailingWidth != null) left -= trailingWidth + _Type.trailingGap;
  return left > 0 ? left : 0;
}

/// One summary page at the postcard's logical size: [map] veiled, the
/// pieces of [page] on it, and the map postcard's header and footer on top.
class PostcardSummaryPage extends StatelessWidget {
  final PostcardShape shape;
  final PostcardText text;
  final String attribution;
  final bool isDark;
  final PostcardSummaryLayout layout;
  final int page;

  /// Laid under the veil, filling the page; null draws the veil's tone alone,
  /// as a preview does until the map's picture is ready.
  final Widget? map;

  const PostcardSummaryPage({
    super.key,
    required this.shape,
    required this.text,
    required this.attribution,
    required this.isDark,
    required this.layout,
    required this.page,
    this.map,
  });

  /// Enough of the map through it to say where the operation was, and not so
  /// much that it competes with the text.
  static const _veil = 0.78;

  @override
  Widget build(BuildContext context) {
    final band = PostcardOverlay.bandColor(isDark);
    final type = _Type(PostcardOverlay.inkColor(isDark));
    return SizedBox.fromSize(
      size: shape.logicalSize,
      child: Stack(
        children: [
          Positioned.fill(child: ColoredBox(color: band.withValues(alpha: 1))),
          if (map case final map?) Positioned.fill(child: map),
          Positioned.fill(
            child: ColoredBox(color: band.withValues(alpha: _veil)),
          ),
          Positioned.fromRect(
            rect: layout.content,
            child: Stack(
              children: [
                for (final piece in layout.pages[page])
                  Positioned(
                    left: 0,
                    right: 0,
                    top: piece.top,
                    height: piece.height,
                    child: switch (piece.block) {
                      final PostcardHeading heading => _HeadingRow(heading: heading, type: type),
                      // The paragraph whole, as the layout measured it, slid up to
                      // this piece's first line and cut off below its last.
                      final PostcardParagraph paragraph => ClipRect(
                        child: Stack(
                          children: [
                            Positioned(
                              left: 0,
                              right: 0,
                              top: -piece.from,
                              child: RichText(text: type.span(paragraph)),
                            ),
                          ],
                        ),
                      ),
                    },
                  ),
              ],
            ),
          ),
          Positioned.fill(
            child: PostcardOverlay(shape: shape, text: text, attribution: attribution, isDark: isDark),
          ),
        ],
      ),
    );
  }
}

class _HeadingRow extends StatelessWidget {
  final PostcardHeading heading;
  final _Type type;

  const _HeadingRow({required this.heading, required this.type});

  @override
  Widget build(BuildContext context) {
    final major = heading.major;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (heading.icon case final icon?) ...[
          Padding(
            padding: EdgeInsets.only(top: _Type.iconTop(major)),
            child: Icon(resolveIconName(icon), size: _Type.iconSize(major), color: heading.iconColor ?? type.ink),
          ),
          const SizedBox(width: _Type.iconGap),
        ],
        Expanded(
          child: RichText(
            text: TextSpan(text: heading.title, style: type.heading(major)),
          ),
        ),
        if (heading.trailing case final trailing?) ...[
          const SizedBox(width: _Type.trailingGap),
          RichText(
            text: TextSpan(text: trailing, style: type.trailing(major)),
          ),
        ],
      ],
    );
  }
}

/// [page] drawn outside the widget tree at [size] logical pixels, as an
/// image of [pixelRatio] physical pixels to each — for the pages an export
/// takes that the carousel has not built. [page] must draw in one pass:
/// nothing here waits for an image to load or rebuilds for one.
Future<ui.Image> paintOffscreen(Widget page, {required Size size, required double pixelRatio, required ui.FlutterView view}) async {
  final boundary = RenderRepaintBoundary();
  final renderView = RenderView(
    view: view,
    configuration: ViewConfiguration(
      logicalConstraints: BoxConstraints.tight(size),
      physicalConstraints: BoxConstraints.tight(size * pixelRatio),
      devicePixelRatio: pixelRatio,
    ),
    child: boundary,
  );
  final pipeline = PipelineOwner()..rootNode = renderView;
  renderView.prepareInitialFrame();
  final focus = FocusManager();
  final builder = BuildOwner(focusManager: focus);
  final root = RenderObjectToWidgetAdapter<RenderBox>(
    container: boundary,
    child: MediaQuery(
      data: MediaQueryData(size: size, devicePixelRatio: pixelRatio),
      child: Directionality(textDirection: TextDirection.ltr, child: page),
    ),
  ).attachToRenderTree(builder);
  try {
    builder.buildScope(root);
    builder.finalizeTree();
    pipeline.flushLayout();
    pipeline.flushCompositingBits();
    pipeline.flushPaint();
    return await boundary.toImage(pixelRatio: pixelRatio);
  } finally {
    // Unmounted, so the widgets' render objects are disposed with them.
    RenderObjectToWidgetAdapter<RenderBox>(container: boundary).attachToRenderTree(builder, root);
    builder.finalizeTree();
    pipeline.rootNode = null;
    boundary.dispose();
    renderView.dispose();
    pipeline.dispose();
    focus.dispose();
  }
}
