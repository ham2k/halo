// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What every operating position sharing this operation is logging right now
// (HALO-395) — one block per position, this device included.
//
// READ-ONLY, deliberately. Nothing here writes to a peer's draft, and a tap
// changes nothing: several operators watching one screen is a very different
// feature from several operators editing one contact, and the ephemeral
// channel this rides (latest-value-wins, lossy) answers none of the questions
// the second one would raise.

import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../../i18n/strings.g.dart';
import '../../services/peer/peer_drafts.dart';
import '../../tools/call_location_line.dart';

class PositionsPanel extends StatefulWidget {
  const PositionsPanel({
    super.key,
    required this.drafts,
    required this.operation,
    required this.miles,
    required this.showBearing,
    this.showReverseBearing = false,
    this.ourEntityPrefix,
  });

  final PeerDrafts drafts;

  /// The operation this pane is showing. A block appears only for a position
  /// whose draft names this same operation — see [PeerDrafts.blocksFor].
  final Operation operation;

  /// This READER's own distance preferences. Not the sender's: the line is
  /// composed here precisely so a distance is to wherever this device is.
  final bool miles;
  final bool showBearing;
  final bool showReverseBearing;
  final String? ourEntityPrefix;

  @override
  State<PositionsPanel> createState() => _PositionsPanelState();
}

class _PositionsPanelState extends State<PositionsPanel> {
  @override
  void initState() {
    super.initState();
    widget.drafts.addListener(_onDraftsChanged);
  }

  @override
  void didUpdateWidget(PositionsPanel old) {
    super.didUpdateWidget(old);
    if (old.drafts != widget.drafts) {
      old.drafts.removeListener(_onDraftsChanged);
      widget.drafts.addListener(_onDraftsChanged);
    }
  }

  @override
  void dispose() {
    widget.drafts.removeListener(_onDraftsChanged);
    super.dispose();
  }

  void _onDraftsChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final blocks = widget.drafts.blocksFor(widget.operation.uuid);
    if (blocks.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(Space.xl),
        child: Text(
          context.t.operation.positions.nobodyYet,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(Space.lg),
      itemCount: blocks.length,
      separatorBuilder: (_, _) => const SizedBox(height: Space.xl),
      itemBuilder: (context, index) => PositionBlockView(
        block: blocks[index],
        operation: widget.operation,
        miles: widget.miles,
        showBearing: widget.showBearing,
        showReverseBearing: widget.showReverseBearing,
        ourEntityPrefix: widget.ourEntityPrefix,
      ),
    );
  }
}

/// One position's block. Public so it can be rendered against a hand-built
/// [PeerDraftBlock] — every rule this panel has about what reads as the
/// operator's answer lives in here, and reaching it through a live
/// [PeerService] would test the sockets instead.
class PositionBlockView extends StatelessWidget {
  const PositionBlockView({
    super.key,
    required this.block,
    required this.operation,
    required this.miles,
    required this.showBearing,
    this.showReverseBearing = false,
    this.ourEntityPrefix,
  });

  final PeerDraftBlock block;
  final Operation operation;
  final bool miles;
  final bool showBearing;
  final bool showReverseBearing;
  final String? ourEntityPrefix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.t.operation.positions;
    final draft = block.draft;
    final their = _mapAt(draft.qso, 'their');
    final guess = _mapAt(their, 'guess');

    // Entered reads black (the body colour), a suggestion gray. The whole
    // point of the block is telling the operator's own answers from the
    // app's, so these must not be a subtle difference.
    final entered = theme.textTheme.bodyMedium;
    final suggested = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
    );

    // The sender's own row, in the sender's own order — labels and all, so a
    // contest exchange renders under the name its extension gave it even on a
    // build that has no such extension. Which of `value`/`hint` is populated
    // is what says whether the operator answered or the app did.
    final fields = <TextSpan>[
      for (final field in draft.fields)
        if (field.value.isNotEmpty)
          TextSpan(text: field.value, style: entered)
        else if ((field.hint ?? '').isNotEmpty)
          TextSpan(text: field.hint, style: suggested),
    ];

    /// Line 3's name: the operator's own override where there is one, else the
    /// lookup's answer. Not a row control — it lives behind the More pane — so
    /// it is read off the draft rather than the field row.
    TextSpan? nameSpan() {
      final own = asQsonString(their['name'])?.trim();
      if (own != null && own.isNotEmpty) return TextSpan(text: own, style: entered);
      final guessed = asQsonString(guess['name'])?.trim();
      if (guessed != null && guessed.isNotEmpty) return TextSpan(text: guessed, style: suggested);
      return null;
    }

    final name = nameSpan();
    final place = callLocationLine(
      context,
      guess,
      // The reader's own operation and units — a distance is to wherever THIS
      // device is, which is why the draft carries no rendered line.
      ourLocation: operation.location,
      miles: miles,
      showBearing: showBearing,
      showReverseBearing: showReverseBearing,
      ourEntityPrefix: ourEntityPrefix,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _header(context, block),
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: Space.xxs),
        Text(_vfoLine(draft.qso), style: theme.textTheme.bodyMedium),
        if (fields.isNotEmpty)
          Text.rich(TextSpan(children: _spaced(fields)), maxLines: 1, overflow: TextOverflow.ellipsis),
        if (name != null || (place != null && place.isNotEmpty))
          Text.rich(
            TextSpan(children: [
              ?name,
              if (name != null && place != null && place.isNotEmpty) TextSpan(text: t.nameIn, style: suggested),
              if (place != null && place.isNotEmpty) TextSpan(text: place, style: suggested),
            ]),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }

  /// `Pos: 2 - Op: KI2D`, falling back through what is actually known: the
  /// operator alone with no position, and the device's own name when it has
  /// neither. A block always says whose it is — two unlabelled ones would be
  /// indistinguishable, which is the one thing this panel cannot afford.
  static String _header(BuildContext context, PeerDraftBlock block) {
    final t = context.t.operation.positions;
    final parts = [
      if (block.draft.position.isNotEmpty) t.positionLabel(number: block.draft.position),
      if (block.draft.operatorCall.isNotEmpty) t.operatorLabel(call: block.draft.operatorCall),
    ];
    if (parts.isEmpty) {
      // This device's own block has no beacon name to fall back on, and
      // "Another position" would be a lie about the one block the operator
      // is definitely sitting at.
      if (block.isThisDevice) return t.thisDevice;
      final name = block.deviceName.trim();
      return name.isEmpty ? t.unnamedPosition : name;
    }
    return parts.join(' - ');
  }

  /// `20m CW 14,025` — whatever of the three the position has. A radio that
  /// has not answered yet leaves this blank rather than inventing a band.
  static String _vfoLine(Map<String, dynamic> qso) {
    final freq = qso['freq'];
    return [
      ?asQsonString(qso['band'])?.trim(),
      ?asQsonString(qso['mode'])?.trim(),
      if (freq is num && freq > 0) fmtFreq(freq.toDouble()),
    ].join(' ');
  }

  static List<TextSpan> _spaced(List<TextSpan> spans) => [
        for (var i = 0; i < spans.length; i++) ...[
          if (i > 0) const TextSpan(text: ' '),
          spans[i],
        ],
      ];

  static Map<String, dynamic> _mapAt(Map<String, dynamic> from, String key) {
    final value = from[key];
    return value is Map ? value.cast<String, dynamic>() : const {};
  }

}
