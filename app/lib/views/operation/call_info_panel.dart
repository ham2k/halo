// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Call Info detail panel (issue #40) — the richer view of the callsign
// currently being logged, modeled on app-polo's CallInfoPanel. Shown as the
// Info tab's content on wide layouts, and as a modal (`showModalPane`) when the
// compact call-info area is tapped on a narrow layout.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../i18n/strings.g.dart';
import '../../main.dart';
import '../../services/settings_service.dart';
import '../../tools/distance_format.dart';
import '../../tools/scoring_labels.dart';

/// How many "other operations" QSOs to list before the "… and N more" line.
const _otherOpsToShow = 3;

class CallInfoPanel extends StatefulWidget {
  final Operation operation;
  final HaLoServices services;

  /// The call whose info this shows (the single call at the cursor).
  final String call;

  /// The merged lookup guess — name/city/state/country/flag/grid/image, etc.
  final Map<String, dynamic>? guess;

  /// The individual lookup results, for data the merge doesn't fold into
  /// `guess` — notably the call-notes `notes` array (every note).
  final List<Map<String, dynamic>> lookups;

  /// Scoring keys from the live scoreQso pass, rendered as pills above Notes.
  final List<String> alertKeys;
  final List<String> noticeKeys;

  /// The operation's own DXCC entity — the contact's country is a header line
  /// only for DX (never our own).
  final String? ourEntityPrefix;

  /// Sizes the panel to its content instead of filling the space it's given.
  /// The Call Info pane wants the default (fill); the ⌘K dialog's card wants
  /// this, so a short lookup doesn't stretch the card down the window.
  final bool shrinkWrap;

  const CallInfoPanel({
    super.key,
    required this.operation,
    required this.services,
    required this.call,
    required this.guess,
    this.lookups = const [],
    this.alertKeys = const [],
    this.noticeKeys = const [],
    this.ourEntityPrefix,
    this.shrinkWrap = false,
  });

  @override
  State<CallInfoPanel> createState() => _CallInfoPanelState();
}

class _CallInfoPanelState extends State<CallInfoPanel> {
  bool _showImage = true;
  List<Qso>? _history;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void didUpdateWidget(CallInfoPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.call != widget.call) {
      _history = null;
      _loadHistory();
    }
  }

  Future<void> _loadHistory() async {
    final call = widget.call;
    final history = await widget.services.qsos.historyForCall(call);
    if (!mounted || widget.call != call) return;
    setState(() => _history = history);
  }

  String? _s(String key) {
    final v = widget.guess?[key];
    return (v is String && v.trim().isNotEmpty) ? v.trim() : null;
  }

  /// Every note for the call — from the call-notes lookup's `notes` array
  /// (the merge doesn't fold it into `guess`); falls back to the compact
  /// combined `note` for older cached data.
  List<String> get _allNotes {
    final notes = <String>[];
    for (final lookup in widget.lookups) {
      final ns = lookup['notes'];
      if (ns is List) notes.addAll(ns.whereType<String>());
    }
    if (notes.isEmpty) {
      final note = _s('note');
      if (note != null) notes.add(note);
    }
    return notes;
  }

  String? _distanceLine(BuildContext context) {
    final t = context.t.callInfo;
    final ourGrid = widget.operation.grid;
    final ourLoc = ourGrid == null ? null : gridToLocation(ourGrid);
    final resolved = locationForQsoInfoWithSource(
      grid: _s('grid'),
      entityPrefix: _s('entityPrefix'),
      state: _s('state'),
    );
    if (ourLoc == null || resolved == null) return null;
    // Suppress an entity-centroid distance for the largest countries — matches
    // the compact call-info line.
    if (resolved.source == QsoLocationSource.entity && kLargeEntities.contains(_s('entityPrefix'))) {
      return null;
    }
    final miles = widget.services.settings.distanceUnits == DistanceUnits.miles;
    final approximate = resolved.source != QsoLocationSource.grid;
    final km = distanceOnEarthKm(resolved.location, ourLoc);
    var distStr = fmtDistance(approximate ? approxRoundedKm(km, miles: miles) : km, miles: miles);
    if (approximate) distStr = '~$distStr';
    final bearing = widget.services.settings.showBearing ? bearingOnEarthDeg(ourLoc, resolved.location).round() : null;
    return bearing != null ? t.distanceBearingAway(distance: distStr, bearing: bearing) : t.distanceAway(distance: distStr);
  }

  String _fmtHistoryTime(int? millis) {
    if (millis == null) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
    final time = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}z';
    final date = DateFormat.MMMd(LocaleSettings.currentLocale.languageCode).format(dt);
    return '$time $date';
  }

  Future<void> _openQrz() =>
      launchUrl(Uri.parse('https://qrz.com/db/${widget.call}'), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.t.callInfo;

    final name = _s('name');
    final city = _s('city');
    final state = _s('state');
    final country = _s('entityName') ?? _s('country');
    final flag = _s('flag');
    final image = _s('image');
    final notes = _allNotes;
    final distance = _distanceLine(context);

    final history = _history ?? const <Qso>[];
    final thisOp = [for (final q in history) if (q.operationUuid == widget.operation.uuid) q];
    final otherOps = [for (final q in history) if (q.operationUuid != widget.operation.uuid) q];

    return ListView(
      shrinkWrap: widget.shrinkWrap,
      padding: const EdgeInsets.all(16),
      children: [
        // Header: identity on the left, QSL image + QRZ on the right.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.call, style: theme.textTheme.headlineSmall),
                  if (name != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    ),
                  if (city != null || state != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text([city, state].whereType<String>().join(', '), style: theme.textTheme.bodyLarge),
                    ),
                  if (country != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      // The flag needs its own span in emojiStyle()'s font —
                      // a plain Text in bodyLarge (Roboto) never renders it
                      // at all, since Flutter doesn't fall back to the OS's
                      // color-emoji font (see theme.dart's emojiFontFamily
                      // doc comment).
                      child: flag == null
                          ? Text(country, style: theme.textTheme.bodyLarge)
                          : Text.rich(
                              TextSpan(
                                children: [
                                  flagSpan(flag, style: theme.textTheme.bodyLarge ?? const TextStyle(fontSize: 16)),
                                  TextSpan(text: ' $country', style: theme.textTheme.bodyLarge),
                                ],
                              ),
                            ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (image != null) _buildImage(theme, image),
                ActionChip(
                  avatar: const Icon(Icons.public, size: 18),
                  label: Text(t.qrz),
                  onPressed: _openQrz,
                ),
              ],
            ),
          ],
        ),

        if (distance != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(distance, style: theme.textTheme.bodyLarge),
          ),

        // Scoring pills, above Notes.
        if (_pills(context).isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Wrap(spacing: 6, runSpacing: 6, children: _pills(context)),
          ),

        if (notes.isNotEmpty) ...[
          _sectionTitle(theme, t.notes),
          MarkdownBody(
            data: flagsInMarkdown(notes.join('\n\n'), fontSize: theme.textTheme.bodyMedium?.fontSize ?? 14),
            sizedImageBuilder: flagMarkdownImageBuilder,
            styleSheet: MarkdownStyleSheet.fromTheme(theme),
          ),
        ],

        if (thisOp.isNotEmpty) ...[
          _sectionTitle(theme, thisOp.length == 1 ? t.thisOpCountOne : t.thisOpCountOther(count: thisOp.length)),
          for (final q in thisOp) _historyRow(theme, q),
        ],

        if (otherOps.isNotEmpty) ...[
          _sectionTitle(theme, otherOps.length == 1 ? t.otherOpsCountOne : t.otherOpsCountOther(count: otherOps.length)),
          for (final q in otherOps.take(_otherOpsToShow)) _historyRow(theme, q),
          if (otherOps.length > _otherOpsToShow)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(t.andMore(count: otherOps.length - _otherOpsToShow), style: theme.textTheme.bodyMedium),
            ),
        ],
      ],
    );
  }

  Widget _buildImage(ThemeData theme, String image) {
    if (!_showImage) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: ActionChip(
          avatar: const Icon(Icons.visibility, size: 18),
          label: Text(context.t.callInfo.showImage),
          onPressed: () => setState(() => _showImage = true),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 200, maxHeight: 160),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                image,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => const SizedBox.shrink(),
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: IconButton.filledTonal(
                icon: const Icon(Icons.visibility_off, size: 18),
                onPressed: () => setState(() => _showImage = false),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _pills(BuildContext context) {
    final theme = Theme.of(context);
    Widget pill(String key, {required bool alert}) {
      final bg = alert ? theme.colorScheme.error : const Color(0xFF2E7D32);
      final fg = alert ? theme.colorScheme.onError : Colors.white;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(3)),
        child: Text(
          scoreNoticeLabel(context, key),
          style: theme.textTheme.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w600),
        ),
      );
    }

    return [
      for (final key in widget.alertKeys) pill(key, alert: true),
      for (final key in widget.noticeKeys) pill(key, alert: false),
    ];
  }

  Widget _sectionTitle(ThemeData theme, String text) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 4),
        child: Text(text, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      );

  Widget _historyRow(ThemeData theme, Qso qso) {
    final ourCall = qso.ourCall;
    final withCall = (ourCall.isNotEmpty && ourCall != widget.operation.stationCall)
        ? context.t.callInfo.withCall(call: ourCall)
        : null;
    final parts = [
      if (qso.band != null) qso.band!,
      if (qso.mode != null) qso.mode!,
      _fmtHistoryTime(qso.startAtMillis),
      if (withCall != null) withCall,
    ].where((s) => s.isNotEmpty);
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(parts.join('  '), style: theme.textTheme.bodyMedium),
    );
  }
}
