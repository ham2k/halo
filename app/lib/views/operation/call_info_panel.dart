// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Call Info detail panel — the richer view of the callsign
// currently being logged, modeled on app-polo's CallInfoPanel. Shown as the
// Info tab's content on wide layouts, and as a modal (`showModalPane`) when the
// compact call-info area is tapped on a narrow layout.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:intl/intl.dart';

import 'package:halo_i18n/halo_i18n.dart';
import '../../services/halo_services.dart';
import '../../services/link_opener.dart';
import '../../services/settings_service.dart';
import '../../tools/distance_format.dart';
import '../../tools/scoring_labels.dart';

/// How many "other operations" QSOs to list before the "… and N more" line.
const _otherOpsToShow = 3;

/// The thumbnail's box in the header. Plain logical pixels — the Font Scale
/// wrapper scales the whole UI, so nothing here multiplies by it
/// (docs/design/ui-scaling.md). Tap it for the photo at full size.
const _thumbnailMaxWidth = 200.0;
const _thumbnailMaxHeight = 160.0;

/// The operation a [CallInfoPanel] outside the Operation view measures
/// against: whichever operation is open behind the surface, or an empty one
/// when none is.
///
/// An empty operation is a real answer, not a placeholder — the panel reads it
/// for a location to measure a distance from and a uuid to split the QSO
/// history by, and with neither it simply shows no distance and no "this
/// operation" section. Shared by the ⌘K dialog and Home's Quick Lookup so the
/// two cannot answer the question differently.
Operation operationForCallInfo(HaLoServices services) {
  final context = services.currentOperationContext;
  if (context == null) return const Operation(uuid: '', data: {});
  final uuid = context['uuid'];
  // Read, not cast: a wrong-typed value in the operation context would throw
  // from inside a build, and an unsplit QSO history is a far better answer
  // than a crashed panel.
  return Operation(uuid: uuid is String ? uuid : '', data: context);
}

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

  /// The other operations the history's QSOs were logged in, by uuid — for
  /// the "from US-1234 North Lake SP" line under each. Loaded after the
  /// history, so the rows appear first and their origins fill in.
  Map<String, Operation> _historyOperations = const {};

  /// The URL whose failure has already been reported — see
  /// [_reportImageFailure]. Also what makes the thumbnail inert: a placeholder
  /// that opened a full-window copy of itself is a dead end.
  String? _failedImageUrl;

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
      // Per call, not for the panel's lifetime: without this a URL that fails
      // for one callsign silences the report for a different callsign's photo
      // that fails later, and leaves that one's thumbnail inert.
      _failedImageUrl = null;
      _loadHistory();
    }
  }

  Future<void> _loadHistory() async {
    final call = widget.call;
    final history = await widget.services.qsos.historyForCall(call);
    if (!mounted || widget.call != call) return;
    setState(() {
      _history = history;
      _historyOperations = const {};
    });

    // Only the operations whose rows are shown: the current one needs no
    // "from" (the operator is in it), and past the "… and N more" cut nothing
    // is rendered.
    final uuids = <String>{
      for (final q in history)
        if (q.operationUuid != widget.operation.uuid) q.operationUuid,
    }.take(_otherOpsToShow);
    final operations = <String, Operation>{};
    for (final uuid in uuids) {
      final operation = await widget.services.operations.get(uuid);
      if (operation != null) operations[uuid] = operation;
    }
    if (!mounted || widget.call != call) return;
    setState(() => _historyOperations = operations);
  }

  /// Where a past QSO was made from: the activation references of the
  /// operation it belongs to — "US-1234 North Lake SP", joined when the
  /// operation activated several — or null for an operation without one.
  /// Read off the operation's refs rather than its cached title fragments,
  /// which exist only on the device that computed them.
  String? _fromLine(Qso qso) {
    final operation = _historyOperations[qso.operationUuid];
    if (operation == null) return null;
    final places = [
      for (final ref in operation.refs)
        // An operation's refs are its activations and the contest it is
        // running; only the activations are places. An activation ref type
        // is the program name suffixed with "Activation" (`potaActivation`,
        // `sotaActivation`, …) — app-polo's QSON convention, which every
        // `ref:<type>` handler follows (docs/extensions/hooks.md §ref:<type>)
        // and which a contest's own type (`arrlDx`) cannot collide with.
        if ((asQsonString(ref['type']) ?? '').endsWith('Activation'))
          [asQsonString(ref['ref']), asQsonString(ref['name'])]
              .where((s) => s != null && s.trim().isNotEmpty)
              .join(' '),
    ].where((s) => s.isNotEmpty).toList();
    if (places.isEmpty) return null;
    return context.t.callInfo.fromOperation(where: places.join(', '));
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
      // A blank entry would render as an unexplained gap between notes.
      if (ns is List) notes.addAll(ns.whereType<String>().where((n) => n.trim().isNotEmpty));
    }
    if (notes.isEmpty) {
      final note = _s('note');
      if (note != null) notes.add(note);
    }
    return notes;
  }

  String? _distanceLine(BuildContext context) {
    final t = context.t.callInfo;
    final ourLoc = widget.operation.location;
    final resolved = locationForQsoInfoWithSource(
      exact: locationFromGuess(widget.guess),
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
    final approximate = resolved.source.isApproximate;
    final km = distanceOnEarthKm(resolved.location, ourLoc);
    var distStr = fmtDistance(approximate ? approxRoundedKm(km, miles: miles) : km, miles: miles);
    if (approximate) distStr = '~$distStr';
    final bearing = widget.services.settings.showBearing ? bearingOnEarthDeg(ourLoc, resolved.location).round() : null;
    // The great-circle bearing back to us — not bearing + 180° on a long path.
    final reverse = bearing != null && widget.services.settings.showReverseBearing
        ? bearingOnEarthDeg(resolved.location, ourLoc).round()
        : null;

    // Point "to" the guess's location (city/state, or the more specific
    // portable location — e.g. a hunted POTA park — when there is one; see
    // the compact call-info line in logging_panel.dart), falling back to the
    // country/entity name (same precedence as the header above) when there's
    // no location — e.g. a DXCC-prefix-only guess with no callbook hit. Falls
    // back to "away" only when neither is known.
    final label = _s('location') ?? _s('entityName') ?? _s('country');
    if (label != null) {
      final phrase = bearing == null
          ? t.distanceTo(distance: distStr)
          : reverse == null
              ? t.distanceBearingTo(distance: distStr, bearing: bearing)
              : t.distanceBearingsTo(distance: distStr, bearing: bearing, reverse: reverse);
      return '$phrase $label';
    }
    return bearing == null
        ? t.distanceAway(distance: distStr)
        : reverse == null
            ? t.distanceBearingAway(distance: distStr, bearing: bearing)
            : t.distanceBearingsAway(distance: distStr, bearing: bearing, reverse: reverse);
  }

  String _fmtHistoryTime(int? millis) {
    if (millis == null) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
    final time = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}z';
    final date = DateFormat.MMMd(LocaleSettings.currentLocale.languageCode).format(dt);
    return '$time $date';
  }

  void _openQrz() => openExternalUrl('https://qrz.com/db/${widget.call}');

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
      padding: const EdgeInsets.all(Space.xl),
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
                      padding: const EdgeInsets.only(top: Space.xs),
                      child: Text(name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    ),
                  if (city != null || state != null)
                    Padding(
                      padding: const EdgeInsets.only(top: Space.xs),
                      child: Text([city, state].whereType<String>().join(', '), style: theme.textTheme.bodyLarge),
                    ),
                  if (country != null)
                    Padding(
                      padding: const EdgeInsets.only(top: Space.xs),
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
                                  flagSpan(
                                    flag,
                                    style: theme.textTheme.bodyLarge ?? const TextStyle(fontSize: 16),
                                    shadows: glyphGlow(theme),
                                  ),
                                  TextSpan(text: ' $country', style: theme.textTheme.bodyLarge),
                                ],
                              ),
                            ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: Space.xl),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (image != null) _buildImage(theme, image),
                ActionChip(
                  avatar: const Icon(MdiIcons.earth, size: 18),
                  label: Text(t.qrz),
                  onPressed: _openQrz,
                ),
              ],
            ),
          ],
        ),

        if (distance != null)
          Padding(
            padding: const EdgeInsets.only(top: Space.xl),
            child: Text(distance, style: theme.textTheme.bodyLarge),
          ),

        // Scoring pills, above Notes.
        if (_pills(context).isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: Space.xl),
            child: Wrap(spacing: 6, runSpacing: 6, children: _pills(context)),
          ),

        if (notes.isNotEmpty) ...[
          _sectionTitle(theme, t.notes),
          for (final (i, note) in notes.indexed) _noteRow(theme, note, first: i == 0),
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
              padding: const EdgeInsets.only(top: Space.xs),
              child: Text(t.andMore(count: otherOps.length - _otherOpsToShow), style: theme.textTheme.bodyMedium),
            ),
        ],
      ],
    );
  }

  Widget _buildImage(ThemeData theme, String image) {
    if (!_showImage) {
      return Padding(
        padding: const EdgeInsets.only(bottom: Space.md),
        child: ActionChip(
          avatar: const Icon(MdiIcons.eye, size: 18),
          label: Text(context.t.callInfo.showImage),
          onPressed: () => setState(() => _showImage = true),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _thumbnailMaxWidth, maxHeight: _thumbnailMaxHeight),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: InkWell(
                // Null once the load has failed: there is nothing to enlarge,
                // and a tap that opened the same placeholder full-window would
                // be a dead end with its own close button.
                onTap: _failedImageUrl == image ? null : () => _openImageViewer(image),
                child: Image.network(
                  image,
                  fit: BoxFit.cover,
                  semanticLabel: context.t.callInfo.photo,
                  // A failed load is SAID, not swallowed: shrinking to nothing
                  // renders a 404, a blocked request and a callsign with no
                  // photo at all as the same absence, which is unanswerable
                  // from a bug report.
                  errorBuilder: (context, error, stack) {
                    _reportImageFailure(image, error);
                    return _imageUnavailable(theme);
                  },
                  loadingBuilder: (context, child, progress) =>
                      progress == null ? child : const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: IconButton.filledTonal(
                icon: const Icon(MdiIcons.eyeOff, size: 18),
                onPressed: () => setState(() => _showImage = false),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// What a broken photo looks like: the same box the image would have filled,
  /// so the layout doesn't move, saying which of "no photo" and "the photo
  /// didn't load" happened.
  Widget _imageUnavailable(ThemeData theme) => Container(
        width: _thumbnailMaxWidth,
        height: _thumbnailMaxHeight,
        color: theme.colorScheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(MdiIcons.imageOff, size: 28, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: Space.xs),
            Text(
              context.t.callInfo.imageUnavailable,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );

  /// Once per URL, not once per build: `errorBuilder` runs on every rebuild of
  /// a failed image, and this panel rebuilds on every keystroke in the call
  /// field.
  void _reportImageFailure(String url, Object error) {
    if (_failedImageUrl == url) return;
    debugPrint('[call-info] photo failed to load: $url — $error');
    // After the frame: `errorBuilder` runs DURING build, and the tap target
    // below is what this changes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _failedImageUrl != url) setState(() => _failedImageUrl = url);
    });
  }

  /// The photo at full size. A Modal Pane, like the app's other panes — full
  /// screen on narrow, a centered card on wide. Not scrollable: the body sizes
  /// the image itself, and a pane's own scroll view would hand it unbounded
  /// height (docs/design/layouts.md).
  Future<void> _openImageViewer(String image) => showModalPane<void>(
        context,
        title: widget.call,
        closeLabel: context.t.common.close,
        scrollable: false,
        builder: (context) => Center(
          child: InteractiveViewer(
            child: Image.network(
              image,
              fit: BoxFit.contain,
              semanticLabel: context.t.callInfo.photo,
              // Reported here too: a photo whose thumbnail loaded and whose
              // full-size fetch does not is the same unanswerable bug report
              // the thumbnail's own handler exists to prevent.
              errorBuilder: (context, error, stack) {
                _reportImageFailure(image, error);
                return _imageUnavailable(Theme.of(context));
              },
            ),
          ),
        ),
      );

  List<Widget> _pills(BuildContext context) {
    final theme = Theme.of(context);
    Widget pill(String key, {required bool alert}) {
      final bg = alert ? theme.colorScheme.error : const Color(0xFF2E7D32);
      final fg = alert ? theme.colorScheme.onError : Colors.white;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: Space.xxs),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(3)),
        child: Text(
          scoreNoticeLabel(context, key),
          style: theme.textTheme.labelSmall?.copyWith(color: fg),
        ),
      );
    }

    return [
      for (final key in widget.alertKeys) pill(key, alert: true),
      for (final key in widget.noticeKeys) pill(key, alert: false),
    ];
  }

  /// One note: its marker glowed as its own glyph, like the logging panel's
  /// call info line, with the prose beside it. A note without a marker is
  /// the prose alone, indented by nothing — the marker is part of the note,
  /// not a bullet.
  ///
  /// Inline markdown, not a block: with the marker split off, the prose is
  /// the START of what the parser sees, and a block renderer would turn
  /// `⚠️ - never before 10z` into a bullet and `🎉 # 50 years` into a
  /// heading. A note is one line from the notes file; the logging panel's
  /// line renders it the same way.
  Widget _noteRow(ThemeData theme, String note, {required bool first}) {
    final parts = splitNoteMarker(note);
    final style = theme.textTheme.bodyMedium?.copyWith(fontFamilyFallback: const [emojiFontFamily]);
    final body = InlineMarkdownText(
      parts.rest,
      style: style,
      codeStyle: haloMonoStyle(context, fontSize: (style?.fontSize ?? flagGlyphDefaultFontSize) * 0.85),
      onOpenLink: openExternalUrl,
      overflow: TextOverflow.clip,
    );
    return Padding(
      // A blank line's worth between notes, so two notes never read as one.
      padding: EdgeInsets.only(top: first ? 0 : Space.sm),
      child: parts.marker == null
          ? body
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                flagGlyph(
                  parts.marker!,
                  fontSize: theme.textTheme.bodyMedium?.fontSize ?? flagGlyphDefaultFontSize,
                  shadows: glyphGlow(theme),
                ),
                const SizedBox(width: Space.xs),
                Expanded(child: body),
              ],
            ),
    );
  }

  Widget _sectionTitle(ThemeData theme, String text) => Padding(
        padding: const EdgeInsets.only(top: Space.xl, bottom: Space.xs),
        child: Text(text, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      );

  Widget _historyRow(ThemeData theme, Qso qso) {
    final ourCall = qso.ourCall;
    // Against every callsign the operation runs under, not the field: one
    // operation can hold several, and a contact carries exactly one of them,
    // so a field-vs-call comparison marks every row of a multi-call operation
    // as made under some other station.
    final withCall = (ourCall.isNotEmpty && !widget.operation.stationCalls.contains(ourCall))
        ? context.t.callInfo.withCall(call: ourCall)
        : null;
    final parts = [
      if (qso.band != null) qso.band!,
      // The sideband belongs to where you are — see [displayMode]. This line
      // has no per-part styling, so an unexpected one is spelled out plainly
      // rather than colored.
      ?displayMode(qso.mode, freqKHz: qso.freq, band: qso.band),
      _fmtHistoryTime(qso.startAtMillis),
      ?withCall,
    ].where((s) => s.isNotEmpty);
    final from = _fromLine(qso);
    return Padding(
      padding: const EdgeInsets.only(top: Space.xxs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(parts.join('  '), style: theme.textTheme.bodyMedium),
          if (from != null)
            Padding(
              padding: const EdgeInsets.only(left: Space.lg),
              child: Text(from, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ),
        ],
      ),
    );
  }
}
