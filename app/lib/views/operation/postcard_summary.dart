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

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show precisionErrorTolerance;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:markdown/markdown.dart' as md;

import '../../tools/operation_stats.dart';
import '../../tools/scoring_summaries.dart';
import 'information_panel.dart' show scorerIconColor, summaryTallies;
import 'operation_postcard.dart' show PostcardOverlay, PostcardShape, PostcardText, postcardFooterRoom;

typedef PostcardRunStyle = ({bool bold, bool italic, bool struck, bool code});

const _plain = (bold: false, italic: false, struck: false, code: false);
const _code = (bold: false, italic: false, struck: false, code: true);

/// A stretch of summary text in one style.
typedef PostcardRun = ({String text, PostcardRunStyle style});

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

  /// A heading inside a tally's detail, of any level.
  subheading,
}

final class PostcardParagraph extends PostcardBlock {
  final List<PostcardRun> runs;
  final PostcardTextKind kind;

  const PostcardParagraph(this.runs, {this.kind = PostcardTextKind.body});

  PostcardParagraph.plain(String text) : this([(text: text, style: _plain)]);
}

/// A Markdown table, laid out as the Info pane lays one out: each column as
/// wide as its content, the columns narrowed toward their longest words where
/// together they would overrun the text's width, no rules, a cell's lines
/// aligned to the top of its row, in body text even in a grid tally's detail. A page breaks
/// it between rows, never after the header alone, and heads each page it runs
/// on to with the header again.
final class PostcardTable extends PostcardBlock {
  /// The header row first. A cell is its runs.
  final List<List<List<PostcardRun>>> rows;

  /// Each column's `:--:` alignment.
  final List<TextAlign> aligns;

  const PostcardTable(this.rows, {required this.aligns});
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

List<PostcardBlock> _tallyDetail(Map<dynamic, dynamic> tally) {
  final detail = tally['longSummary'];
  return detail is String ? postcardBlocks(detail, grid: tally['grid'] == true) : const [];
}

/// [markdown] read as the Info pane's MarkdownBody reads it — flutter_markdown's
/// own parser, GitHub-flavored, with a line break wherever the source breaks
/// a line (the pane's `softLineBreak`) — as blocks a page can measure and
/// split. A heading of any level is a subheading; a list is one paragraph,
/// an item to a line; a code block is a paragraph in the mono face; a quote
/// is the blocks inside it; a rule is nothing. A picture has no link to tap
/// and loads no image: a link is its words, and an image is left out.
List<PostcardBlock> postcardBlocks(String markdown, {bool grid = false}) {
  final kind = grid ? PostcardTextKind.grid : PostcardTextKind.body;
  final blocks = <PostcardBlock>[];
  void paragraph(List<PostcardRun> runs, PostcardTextKind kind) {
    if (runs.isNotEmpty) blocks.add(PostcardParagraph(runs, kind: kind));
  }

  void block(md.Node node) {
    if (node is md.Text) return paragraph(_runs([node]), kind);
    if (node is! md.Element) return;
    switch (node.tag) {
      case 'p':
        paragraph(_runs(node.children, within: 'p'), kind);
      case 'h1' || 'h2' || 'h3' || 'h4' || 'h5' || 'h6':
        paragraph(_runs(node.children), PostcardTextKind.subheading);
      case 'ul' || 'ol':
        paragraph(_listRuns(node, 0), kind);
      case 'pre':
        final code = node.textContent.replaceFirst(RegExp(r'\n$'), '');
        if (code.isNotEmpty) paragraph([(text: code, style: _code)], kind);
      case 'table':
        blocks.add(_table(node));
      case 'hr':
        break;
      default:
        node.children?.forEach(block);
    }
  }

  // Text at the document's own level is an HTML block, which the pane's
  // builder draws nothing for.
  md.Document(extensionSet: md.ExtensionSet.gitHubFlavored, encodeHtml: false).parse(markdown).whereType<md.Element>().forEach(block);
  return blocks;
}

/// The tags flutter_markdown's builder drops a text's leading spaces after,
/// entering or leaving one: the start of a paragraph or a list item, and
/// the line after a hard break.
const _trimsAfter = {'p', 'li', 'ul', 'ol', 'br'};

/// [nodes]' inline Markdown as runs, one to each change of style. [within]
/// is the block they sit in, the tag the pane's builder last visited before
/// them.
List<PostcardRun> _runs(Iterable<md.Node>? nodes, {String? within}) {
  final runs = <PostcardRun>[];
  var last = within;
  void add(String text, PostcardRunStyle style) {
    if (text.isEmpty) return;
    if (runs.isNotEmpty && runs.last.style == style) {
      runs.last = (text: runs.last.text + text, style: style);
    } else {
      runs.add((text: text, style: style));
    }
  }

  void walk(md.Node node, PostcardRunStyle style) {
    if (node is md.Text) {
      add(_trimsAfter.contains(last) ? node.text.replaceFirst(RegExp('^ +'), '') : node.text, style);
      last = null;
      return;
    }
    if (node is! md.Element) return;
    last = node.tag;
    switch (node.tag) {
      case 'br':
        add('\n', style);
      case 'code':
        add(node.textContent, (bold: style.bold, italic: style.italic, struck: style.struck, code: true));
      default:
        final inner = (
          bold: style.bold || node.tag == 'strong',
          italic: style.italic || node.tag == 'em',
          struck: style.struck || node.tag == 'del',
          code: style.code,
        );
        for (final child in node.children ?? const <md.Node>[]) {
          walk(child, inner);
        }
    }
    last = node.tag;
  }

  for (final node in nodes ?? const <md.Node>[]) {
    walk(node, _plain);
  }
  return runs;
}

/// A list's items, a line each under its bullet, number or task box, a list
/// inside an item indented under it, and a loose item's paragraphs a line
/// each.
List<PostcardRun> _listRuns(md.Element list, int depth) {
  final runs = <PostcardRun>[];
  var number = int.tryParse(list.attributes['start'] ?? '') ?? 1;
  for (final item in list.children?.whereType<md.Element>() ?? const <md.Element>[]) {
    final inline = <md.Node>[], nested = <md.Element>[];
    String? box;
    for (final child in item.children ?? const <md.Node>[]) {
      if (child is md.Element && (child.tag == 'ul' || child.tag == 'ol')) {
        nested.add(child);
      } else if (child is md.Element && child.tag == 'p') {
        if (inline.isNotEmpty) inline.add(md.Element.empty('br'));
        inline.addAll(child.children ?? const []);
      } else if (child is md.Element && child.tag == 'input') {
        // Emoji, which the emoji fallback draws on every platform: Roboto
        // has no ballot box.
        box = child.attributes['checked'] == 'true' ? '✅ ' : '⬜ ';
      } else {
        inline.add(child);
      }
    }
    // A boxed item still takes its number, as the pane counts it.
    final index = number++;
    final marker = box ?? (list.tag == 'ol' ? '$index. ' : '• ');
    runs.addAll([
      if (runs.isNotEmpty) (text: '\n', style: _plain),
      (text: '${' ' * (4 * depth)}$marker', style: _plain),
      ..._runs(inline, within: 'li'),
      for (final list in nested) ...[(text: '\n', style: _plain), ..._listRuns(list, depth + 1)],
    ]);
  }
  return runs;
}

PostcardTable _table(md.Element table) {
  final rows = [
    for (final part in table.children?.whereType<md.Element>() ?? const <md.Element>[])
      for (final row in part.children?.whereType<md.Element>() ?? const <md.Element>[])
        [for (final cell in row.children?.whereType<md.Element>() ?? const <md.Element>[]) cell],
  ];
  return PostcardTable(
    [
      for (final row in rows) [for (final cell in row) _runs(cell.children)],
    ],
    // The pane's house table sets a header as its column does, and a column
    // with no `:--:` of its own to the left.
    aligns: [
      for (final cell in rows.isEmpty ? const <md.Element>[] : rows.first)
        switch (cell.attributes['align']) {
          'center' => TextAlign.center,
          'right' => TextAlign.right,
          _ => TextAlign.left,
        },
    ],
  );
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

  TextSpan span(PostcardParagraph paragraph) => _span(paragraph.runs, this.paragraph(paragraph.kind), paragraph.kind);

  /// The house table's cell padding, as the Info pane's.
  static const cellPadding = EdgeInsets.symmetric(horizontal: Space.xs, vertical: Space.xxs);

  /// Each of [table]'s columns' width, padding included, by the rule
  /// HaloMarkdown's house table sets the Info pane's by (its
  /// `_ContentColumnWidth`, under [Table]'s own narrowing): its widest cell's;
  /// and where together they overrun [width], each narrowed by an even share
  /// of the excess, none below its longest word — nor held above an even
  /// share of [width] for one, so a word too long to fit breaks rather than
  /// running off the picture.
  List<double> columnWidths(PostcardTable table, double width) {
    final columns = table.aligns.length;
    final widths = List.filled(columns, 0.0), least = List.filled(columns, 0.0);
    for (var row = 0; row < table.rows.length; row++) {
      for (var column = 0; column < columns; column++) {
        final painter = _Measurer._painter(cell(table, row, column), double.infinity);
        widths[column] = math.max(widths[column], painter.maxIntrinsicWidth + cellPadding.horizontal);
        least[column] = math.max(least[column], painter.minIntrinsicWidth + cellPadding.horizontal);
        painter.dispose();
      }
    }
    for (var column = 0; column < columns; column++) {
      least[column] = math.min(least[column], width / columns);
    }
    var excess = widths.fold(0.0, (sum, w) => sum + w) - width;
    while (excess > precisionErrorTolerance) {
      final open = [
        for (var column = 0; column < columns; column++)
          if (widths[column] > least[column]) column,
      ];
      if (open.isEmpty) break;
      final share = excess / open.length;
      for (final column in open) {
        final cut = math.min(share, widths[column] - least[column]);
        widths[column] -= cut;
        excess -= cut;
      }
    }
    return widths;
  }

  /// A short row's missing cell is an empty one.
  TextSpan cell(PostcardTable table, int row, int column) => _span(
    column < table.rows[row].length ? table.rows[row][column] : const [],
    // The header a weight up, as the pane's house table sets it.
    row == 0 ? paragraph(PostcardTextKind.body).copyWith(fontWeight: FontWeight.w600) : paragraph(PostcardTextKind.body),
    PostcardTextKind.body,
  );

  TextSpan _span(List<PostcardRun> runs, TextStyle style, PostcardTextKind kind) => TextSpan(
    style: style,
    children: [for (final run in runs) TextSpan(text: run.text, style: _run(run, kind))],
  );

  TextStyle? _run(PostcardRun run, PostcardTextKind kind) {
    final style = run.style;
    if (style == _plain) return null;
    // A worked code, set back to full strength.
    final worked = style.struck && kind == PostcardTextKind.grid;
    return TextStyle(
      color: worked ? ink : null,
      fontFamily: style.code ? 'RobotoMono' : null,
      fontWeight: style.bold || worked ? FontWeight.w700 : null,
      fontStyle: style.italic ? FontStyle.italic : null,
      decoration: style.struck ? TextDecoration.lineThrough : null,
    );
  }
}

/// A block's place on one page: [top] and [height] in the page's content box
/// — see [PostcardSummaryLayout.content] — and, for a paragraph or a table,
/// how far down its own lines or rows the piece begins: [from] is 0 but where
/// one runs on from the page before. A table's piece that does runs its
/// header row over them, in its [height].
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
/// as many more as it takes, breaking between lines or a table's rows under
/// its heading retitled by [continued]. A tally's heading inside a section is
/// kept with the first line under it, or a table's header and first row.
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
        final next = i + 1 < body.length ? _gapBefore(body[i + 1].block) + body[i + 1].tops[body[i + 1].firstLines] : 0.0;
        if (!fits(gap + b.height + next) && !headingAlone()) runOn();
        put(b.block, gap, b.height);
        continue;
      }
      final table = b.block is PostcardTable;
      var from = 0;
      while (from < b.lineCount) {
        // A table's header again, over the rows a page picks up.
        final repeated = table && from > 0 ? b.tops[1] : 0.0;
        final least = from == 0 ? b.firstLines : from + 1;
        var to = from;
        while (to < b.lineCount && fits(gap + repeated + b.tops[to + 1] - b.tops[from])) {
          to++;
        }
        if (to < least) {
          if (!headingAlone()) {
            runOn();
            continue;
          }
          // A line taller than a page, drawn cut off rather than never.
          to = least;
        }
        put(b.block, gap, repeated + b.tops[to] - b.tops[from], from: b.tops[from]);
        from = to;
        if (from < b.lineCount) runOn();
      }
    }
  }
  if (pages.last.isEmpty) pages.removeLast();
  return PostcardSummaryLayout(content: content, pages: pages);
}

/// A block's height, and the tops of a paragraph's lines or a table's rows:
/// [tops] runs from 0 to the block's height, one entry per line or row and
/// one more for its foot.
typedef _Measured = ({PostcardBlock block, double height, List<double> tops});

extension on _Measured {
  int get lineCount => tops.length - 1;

  /// The lines a page may not end before: the first — or a table's header
  /// and its first row, as a header alone at a page's foot heads nothing.
  int get firstLines {
    final least = block is PostcardTable ? 2 : 1;
    return lineCount < least ? lineCount : least;
  }
}

class _Measurer {
  final double width;

  _Measurer(this.width);

  static const _type = _Type(Color(0xFF000000));

  _Measured call(PostcardBlock block) => switch (block) {
    final PostcardHeading heading => _heading(heading),
    final PostcardParagraph paragraph => _paragraph(paragraph),
    final PostcardTable table => _table(table),
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

  /// A table's row is a line: a page breaks it between rows.
  _Measured _table(PostcardTable table) {
    final widths = _type.columnWidths(table, width);
    final tops = <double>[0];
    for (var row = 0; row < table.rows.length; row++) {
      var tallest = 0.0;
      for (var column = 0; column < table.aligns.length; column++) {
        final painter = _painter(_type.cell(table, row, column), math.max(0, widths[column] - _Type.cellPadding.horizontal));
        if (painter.height > tallest) tallest = painter.height;
        painter.dispose();
      }
      tops.add(tops.last + tallest + _Type.cellPadding.vertical);
    }
    return (block: table, height: tops.last, tops: tops);
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
                      // The block whole, as the layout measured it, slid up to
                      // this piece's first line and cut off below its last.
                      final PostcardParagraph paragraph => _Slid(
                        from: piece.from,
                        child: RichText(text: type.span(paragraph)),
                      ),
                      final PostcardTable table when piece.from == 0 => _Slid(
                        from: 0,
                        child: _TableRows(table: table, type: type, width: layout.content.width),
                      ),
                      final PostcardTable table => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _TableRows(table: table, type: type, width: layout.content.width, headerOnly: true),
                          Expanded(
                            child: _Slid(
                              from: piece.from,
                              child: _TableRows(table: table, type: type, width: layout.content.width),
                            ),
                          ),
                        ],
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

class _Slid extends StatelessWidget {
  final double from;
  final Widget child;

  const _Slid({required this.from, required this.child});

  @override
  Widget build(BuildContext context) => ClipRect(
    child: Stack(
      children: [Positioned(left: 0, right: 0, top: -from, child: child)],
    ),
  );
}

/// Laid out to the numbers [_Measurer] measures it by: each column
/// [_Type.columnWidths] wide at the content's [width], a row as tall as its
/// tallest cell.
class _TableRows extends StatelessWidget {
  final PostcardTable table;
  final _Type type;
  final double width;
  final bool headerOnly;

  const _TableRows({required this.table, required this.type, required this.width, this.headerOnly = false});

  @override
  Widget build(BuildContext context) {
    final widths = type.columnWidths(table, width);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var row = 0; row < (headerOnly ? 1 : table.rows.length); row++)
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var column = 0; column < table.aligns.length; column++)
                SizedBox(
                  width: widths[column],
                  child: Padding(
                    padding: _Type.cellPadding,
                    child: RichText(text: type.cell(table, row, column), textAlign: table.aligns[column]),
                  ),
                ),
            ],
          ),
      ],
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
