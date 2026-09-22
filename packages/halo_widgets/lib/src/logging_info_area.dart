// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The logging panel's information area — the strip between the secondary
// controls and the main fields that tells the operator about the station
// being worked, or the operation when no station is (issue #40). Pure
// presentation: the panel decides WHAT it shows (which call, which message,
// what is missing) and hands it over; nothing here reads a controller.

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import 'call_info_summary.dart';
import 'mdi_icons.g.dart';
import 'spacing.dart';
import 'theme.dart';
import 'wall_clock.dart';

/// The info area's content, in priority order: a command message (markdown)
/// takes priority; otherwise the call-info panel for the call in hand;
/// otherwise a grid alone, when one is typed with no call; otherwise the
/// operation-statistics default.
///
/// The `options` exchange suggestions are deliberately NOT here: a line in
/// this area would cost the call-info panel — the DUPE warning with it — its
/// space for as long as an exchange field had focus. They are a menu floating
/// over the fields instead.
class LoggingInfoArea extends StatelessWidget {
  const LoggingInfoArea({
    super.key,
    required this.theme,
    required this.warnings,
    required this.message,
    required this.callInfo,
    required this.locationLine,
    required this.gridOnlyLine,
    required this.statsLines,
    required this.noticeLabel,
    required this.workedBeforeLabel,
    required this.onCallInfoTap,
    required this.onOperationInfoTap,
    required this.onOpenLink,
  });

  /// The panel's accent theme — the area sits on its tertiaryContainer fill.
  final ThemeData theme;

  /// What the contact in hand is missing from the radio state every QSO
  /// needs — "No Band", "No Mode". Ride ABOVE everything else the area can
  /// show, including a command's message: a band that was never set is wrong
  /// before there is anything to work, and the operator has to see it then,
  /// not on the submit the log-time refusal finally blocks. Above the message
  /// in particular because that message OUTLIVES the condition that wrote it
  /// — the refusal is cleared by a call-field keystroke, not by the band pick
  /// that answers it — so a warning underneath it would go quiet exactly
  /// while the operator was fixing the problem, and stay quiet about anything
  /// still missing. Not folded into the call-info pills for the opposite
  /// reason: those belong to the station in the field, and this one doesn't.
  final List<String> warnings;

  /// A command's describe preview, error or confirmation, as markdown.
  final String? message;

  /// The station being worked, or null while the call-info panel is not
  /// showing — fewer than three characters typed, or an event row, whose
  /// `their.call` ("NOTE") is a sentinel rather than a callsign.
  final CallInfoData? callInfo;

  /// The distance line for [callInfo]. Only the app layer knows the
  /// operation's own location and the locale, so the panel composes it.
  final String? locationLine;

  /// With no callsign in the field but a grid typed — a microwave operator
  /// lining up a dish on a square before the other station is even named —
  /// the grid alone is enough to show the distance and bearing to it.
  final String? gridOnlyLine;

  /// Operation statistics (QSO count, rates), re-derived once per second:
  /// the rate lines are time-relative, and the tick is scoped to this row
  /// via [OncePerSecond] rather than ticking the whole panel.
  final List<String> Function()? statsLines;

  final String Function(String key)? noticeLabel;
  final String? Function(List<int> startTimes)? workedBeforeLabel;

  /// The whole area is one tap target, the way the QSO list's day headers
  /// are: while the call-info content is on show a press opens that station's
  /// detail; with anything else — the statistics, a grid alone, a command's
  /// message, even over a call in hand — it opens the operation's own info.
  /// Routed by what is ON SCREEN, not by whether a call is typed: the host's
  /// copy of the call info is null while a message has the space, so a call
  /// tap from under a message would reach a host with no call to open, and
  /// on a layout with no Info pane do nothing at all. The warning pills are part
  /// of the target too: they ride above the content wherever it stands, and a
  /// press that landed on one and did nothing would read as a dead area, not
  /// as a distinction.
  final VoidCallback? onCallInfoTap;
  final VoidCallback? onOperationInfoTap;
  final void Function(String url)? onOpenLink;

  @override
  Widget build(BuildContext context) {
    final onTap = message == null && callInfo != null ? onCallInfoTap : onOperationInfoTap;
    if (onTap == null) return _body();
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: _body());
  }

  Widget _body() {
    if (warnings.isEmpty) return _content();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Wraps rather than a plain Row: two pills in a locale that spells
        // them long ("Sin Banda" + "Sin Modo") reach the width this area has
        // left after the edit button's reserve at the tightest supported
        // geometry, and a non-flex Row child would overflow rather than move
        // to a second line.
        Wrap(
          spacing: Space.xs,
          runSpacing: Space.xxs,
          children: [for (final warning in warnings) noticePill(theme, warning, level: NoticeLevel.alert)],
        ),
        const SizedBox(height: Space.xxs),
        _content(),
      ],
    );
  }

  Widget _content() {
    final message = this.message;
    if (message != null) {
      return MarkdownBody(
        data: message,
        styleSheet: withEmojiFallback(
          MarkdownStyleSheet.fromTheme(theme).copyWith(
            p: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onTertiaryContainer, fontWeight: FontWeight.w500),
          ),
        ),
      );
    }
    final callInfo = this.callInfo;
    if (callInfo != null) {
      // Rendered by the shared [CallInfoSummary], the same widget Home's
      // Quick Lookup bar uses, so a change to either lands on both.
      return CallInfoSummary(
        data: callInfo,
        locationLine: locationLine,
        noticeLabel: noticeLabel,
        workedBeforeLabel: workedBeforeLabel,
        // The panel's own tertiaryContainer fill, and the accent the main
        // buttons use (tertiary, or secondary while editing).
        foregroundColor: theme.colorScheme.onTertiaryContainer,
        iconColor: theme.colorScheme.tertiary,
        onOpenLink: onOpenLink,
      );
    }
    if (gridOnlyLine case final line?) {
      // The same shape as the call-info panel, minus everything that needs a
      // callsign: no lookup and no scoring pills.
      return CallInfoSummary(
        data: const CallInfoData(call: ''),
        locationLine: line,
        foregroundColor: theme.colorScheme.onTertiaryContainer,
        iconColor: theme.colorScheme.tertiary,
      );
    }
    return OncePerSecond(
      builder: (context, _) {
        final lines = statsLines?.call() ?? const <String>[];
        if (lines.isEmpty) return const SizedBox.shrink();
        return infoIconRows(
          theme,
          // Filled icon in the same accent as the main buttons (tertiary, or
          // secondary while editing).
          icon: MdiIcons.timerOutline,
          iconColor: theme.colorScheme.tertiary,
          children: [
            for (final line in lines)
              Text(
                line,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onTertiaryContainer),
              ),
          ],
        );
      },
    );
  }
}

/// The read-only warning shown in place of the info area while the form is
/// locked — a staged delete, an already-deleted QSO, or an operation this
/// device may not write to (ham2k/halo-dist#59).
class LockedFormWarning extends StatelessWidget {
  const LockedFormWarning({super.key, required this.theme, required this.text});

  final ThemeData theme;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(MdiIcons.alert, size: 16, color: theme.colorScheme.error),
      const SizedBox(width: Space.xs),
      Expanded(
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error, fontWeight: FontWeight.w500),
        ),
      ),
    ],
  );
}
