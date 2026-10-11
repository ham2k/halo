// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

part of 'spots_panel.dart';

/// The narrowest left-column width that fits every currently-visible spot's
/// frequency and mode without clipping — measured with the same text styles
/// [_SpotTile] renders (RobotoMono is tabular, so `'0'`s stand in for any
/// digits). HF-only lists come out much tighter than the fixed width the
/// widest microwave frequency would need, while every row's right-aligned
/// frequency still lines up. Shared across tiles, recomputed per rebuild.
double _spotLeftColumnWidth(BuildContext context, List<Map<String, dynamic>> spots, int hzDigits) {
  final mono = haloMonoStyle(context, fontSize: 14);
  final boldMono = haloMonoStyle(context, fontSize: 14, fontWeight: FontWeight.w700);
  final hzMono = haloMonoStyle(context, fontSize: 14 * 0.8);
  final modeStyle = Theme.of(context).textTheme.bodySmall ?? const TextStyle();

  var maxMhzLen = 0;
  final modes = <String>{};
  for (final spot in spots) {
    final freq = _freqOf(spot);
    if (freq != null) {
      final len = freqDisplayParts(freq, hzDigits: hzDigits).mhz.length;
      if (len > maxMhzLen) maxMhzLen = len;
    }
    // The DISPLAYED mode — measuring the stored `LSB` for a row that renders
    // `SSB` reserves a width no row uses.
    final mode = displayMode(_modeOf(spot), freqKHz: freq, band: _bandOf(spot));
    if (mode != null && mode.isNotEmpty) modes.add(mode);
  }

  var width = 0.0;
  if (maxMhzLen > 0) {
    // Mirror _SpotTile's freqField piece by piece — a Row of separate Texts:
    // bold MHz, '.', a 3-digit kHz, and (when shown) '.' + a 0.8×-size Hz
    // segment — each measured the way a Text lays it out (see [textWidth], which
    // folds in the ambient DefaultTextStyle's letter-spacing and text scaler so
    // the cell isn't a hair too tight).
    width = textWidth(context, '0' * maxMhzLen, boldMono) + textWidth(context, '.', mono) + textWidth(context, '000', mono);
    if (hzDigits > 0) {
      width += textWidth(context, '.', mono) + textWidth(context, '0' * hzDigits, hzMono);
    }
  }
  // The mode sits below the frequency in the same column, so it can't clip either.
  for (final mode in modes) {
    final w = textWidth(context, mode, modeStyle);
    if (w > width) width = w;
  }
  return width.ceilToDouble();
}

/// Narrow freq/band/mode column on the left, wide call/notes/refs column on
/// the right — a deliberately different shape from `qso_list.dart`'s
/// column-per-field row (spots carry a variable-length reference label
/// that a fixed column grid can't accommodate), but reusing that row's
/// frequency styling (bold MHz, dot-separated kHz/Hz) so the two lists
/// still read as the same visual language.
class _SpotTile extends StatelessWidget {
  final Map<String, dynamic> spot;
  final String? noteEmoji;
  final int hzDigits;

  /// Width of the fixed left column (freq over mode), sized by the panel to
  /// the widest frequency/mode currently on screen and shared across tiles so
  /// their right-aligned frequencies line up.
  final double leftWidth;

  /// When sorting by age, the age (top-right of the row) is drawn bold so the
  /// value you're ordering by stands out.
  final bool sortByAge;
  final List<Map<String, dynamic>> activityControls;
  final VoidCallback? onTap;

  /// This spot reads as worked: either every operator on it has already been
  /// worked on this band and mode — the `duplicate` alert from [SpotsPanel]'s
  /// candidate scoring — or the operator slid it aside. Dimmed, per app-polo's
  /// SpotItem `type: 'duplicate'`.
  final bool worked;

  /// [spotDisplayFlags]'s `worked`: every operator on this spot is already in
  /// the log for this band and mode and no scorer raised a notice about it —
  /// a notice deliberately un-strikes a duplicate, since it says there is
  /// something here worth working anyway. Struck through, and NOTHING else
  /// strikes a row: the strikethrough answers "have I worked this call", so a
  /// spot merely set aside must not borrow it, and a slide that puts a
  /// duplicate back on the board must not take it away.
  final bool logged;

  /// This spot is OUR station's own — tinted and dimmed rather than struck,
  /// since it isn't a contact to make (app-polo's `type: 'self'`).
  final bool isSelf;

  /// Scoring notices for this spot's operators, merged across every scorer.
  /// Only `newBand`, `newMode`, `newDay`, `newRef` and `newMult` are drawn —
  /// each accents the field it speaks about (see `build`). The core scorer's
  /// `newDXCC`/`newState`/`newProvince` arrive here too and are deliberately
  /// ignored: they belong to the call you are typing, and on a whole board they
  /// would accent most rows most of the time.
  final Set<String> notices;

  /// Fill for the row of the QSO being logged right now
  /// ([currentQsoHighlight]), null for every other row. Painted behind the
  /// content rather than folded into the text styles like [worked] and
  /// [isSelf]: those say something about the spot, this says which row the
  /// operator's own attention is on.
  final Color? highlight;

  const _SpotTile({
    super.key,
    required this.spot,
    this.noteEmoji,
    this.hzDigits = 0,
    this.leftWidth = 120,
    this.sortByAge = false,
    this.activityControls = const [],
    this.onTap,
    this.worked = false,
    this.logged = false,
    this.isSelf = false,
    this.notices = const {},
    this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final haloColors = HaLoColors.of(context);
    final metrics = LayoutDensity.metricsOf(context);

    // The row-wide accents, applied by folding them into the two base styles
    // every field below derives from. app-polo's SpotItem spreads a
    // `commonStyle` across each of its Texts for the same effect.
    // The dim is folded into every colour rather than wrapped around the row in
    // an `Opacity`: that widget forces a saveLayer per row, and on a board where
    // most spots are worked that is a compositing layer for every visible row on
    // every frame of a scroll. EVERY colour the row paints has to go through
    // [faded] for that to hold — one that skips it is a part of the row that
    // does not dim, and wrapping the row to catch it dims everything twice.
    final dim = worked ? 0.6 : (isSelf ? 0.7 : 1.0);
    Color faded(Color color) => dim == 1.0 ? color : color.withValues(alpha: color.a * dim);

    final baseColor = faded(isSelf ? theme.colorScheme.tertiary : theme.colorScheme.onSurface);
    final decoration = logged ? TextDecoration.lineThrough : null;

    final mono = haloMonoStyle(context, fontSize: 14, color: baseColor).copyWith(decoration: decoration, decorationColor: baseColor);
    // Band/mode and the reference label are names, not structured data —
    // proportional, like everywhere else names/labels appear (e.g. the DX
    // flag/state field in qso_list.dart), unlike the monospace fields
    // (freq, callsign) they sit next to.
    final outlineColor = faded(theme.colorScheme.outline);
    final proportional = theme.textTheme.bodySmall
        ?.copyWith(color: isSelf ? baseColor : outlineColor)
        .copyWith(decoration: decoration, decorationColor: baseColor);

    // Per-notice accents, ported from app-polo's SpotItem. Applied in its
    // order, so `newMult` wins the callsign and reference label from the
    // others — a fresh multiplier is the one worth breaking a run for.
    //
    // `newBand` accents the FREQUENCY rather than a band field: this row shows
    // the frequency and lets it imply the band, where app-polo's shows both.
    final important = faded(haloColors.important);
    final multiplier = faded(haloColors.spotMultiplier);
    final freqAccent = notices.contains('newBand') ? important : null;
    final modeAccent = notices.contains('newMode') ? important : null;
    final callAccent = notices.contains('newMult') ? multiplier : null;
    final refAccent = notices.contains('newMult') ? multiplier : (notices.contains('newDay') || notices.contains('newRef') ? important : null);
    // An accented field is bold as well as colored — color alone is not a
    // signal an operator can rely on (docs/design/user-interface.md), and at
    // spot-row size the weight is what actually catches the eye.
    TextStyle? accented(TextStyle? style, Color? accent) => accent == null ? style : style?.copyWith(color: accent, fontWeight: FontWeight.w700);

    final freqKHz = _freqOf(spot);
    final spotBand = _bandOf(spot);
    final spotMode = _modeOf(spot);
    final modeUnexpected = isUnexpectedSideband(spotMode, freqKHz: freqKHz, band: spotBand);
    final Widget freqField;
    if (freqKHz == null) {
      // No frequency to show on the top line — the mode still shows below it.
      freqField = const SizedBox.shrink();
    } else {
      final parts = freqDisplayParts(freqKHz, hzDigits: hzDigits);
      final freqStyle = accented(mono, freqAccent) ?? mono;
      freqField = Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          // A kHz reading, the same as the QSO list's — thousands mark
          // between MHz and kHz, decimal point before the Hz digits, both in
          // the operator's own conventions. Below 1 MHz (630m, 2200m) there
          // is no thousands group at all, and `0,472` is not a reading anyone
          // writes.
          if (int.parse(parts.mhz) > 0) ...[
            Text(groupDigits(parts.mhz), style: freqStyle.copyWith(fontWeight: FontWeight.w700)),
            Text(NumberFormatting.instance.groupingSeparator, style: freqStyle),
            Text(parts.khz, style: freqStyle),
          ] else
            Text(int.parse(parts.khz).toString(), style: freqStyle.copyWith(fontWeight: FontWeight.w700)),
          if (parts.hz != null) ...[
            Text(NumberFormatting.instance.decimalSeparator, style: freqStyle),
            Text(parts.hz!, style: freqStyle.copyWith(fontSize: (freqStyle.fontSize ?? 14) * 0.8)),
          ],
        ],
      );
    }

    final refs = _refsOf(spot);
    final refType = refs.isEmpty ? null : asSpotString(refs.first['type']);
    final refIcon = iconForRefType(activityControls, refType) ?? _iconOf(spot) ?? 'radio-tower';
    // The extension's declared accent tints its icon (the same tint the
    // Activities picker and the logging pills use), so a POTA row reads as
    // POTA at a glance. The notice accents stay on the label text: the icon
    // says WHAT the ref is, the text says why this row matters.
    final extensionColor = colorForRefType(activityControls, refType);
    final refIconColor = extensionColor != null ? faded(extensionColor) : (refAccent ?? (isSelf ? baseColor : outlineColor));

    // Age sits at the top-right of the row, right-aligned, bold when it's the
    // sort key. Re-derived once a second (scoped to this label via the shared
    // wall-clock heartbeat) so ages don't sit stale between spot refetches —
    // every visible row's label updates in the same frame.
    final ageField = OncePerSecond(
      builder: (_, _) => Text(_timeAgo(_timeOf(spot)), style: proportional?.copyWith(fontWeight: sortByAge ? FontWeight.w700 : null)),
    );

    // One row line: the fixed-width left column (right-aligned, sized by the
    // panel to the widest freq/mode on screen) beside the expanded right
    // column, baseline-aligned so the freq/mode text sits on the same baseline
    // as the call/label across the gap.
    Widget line(Widget left, Widget right) => Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        SizedBox(
          width: leftWidth,
          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [left]),
        ),
        const SizedBox(width: Space.xl),
        Expanded(child: right),
      ],
    );

    final callLine = Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  _callOf(spot) ?? '?',
                  style: (accented(mono, callAccent) ?? mono).copyWith(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              if (noteEmoji != null) ...[
                const SizedBox(width: Space.xs),
                // The one thing on the row a colour cannot dim: an emoji is
                // painted by the font, not by its style. So it gets the layer
                // the rest of the row deliberately avoids — and only rows that
                // actually carry a note pay for it, which is a small minority
                // rather than every visible row of a scroll.
                dim == 1.0
                    ? flagGlyph(noteEmoji!, shadows: glyphGlow(theme))
                    : Opacity(
                        opacity: dim,
                        child: flagGlyph(noteEmoji!, shadows: glyphGlow(theme)),
                      ),
              ],
            ],
          ),
        ),
        const SizedBox(width: Space.md),
        ageField,
      ],
    );

    final labelLine = _labelOf(spot) == null
        ? const SizedBox.shrink()
        : Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Icon(resolveIconName(refIcon), size: mono.fontSize, color: refIconColor),
              const SizedBox(width: Space.xs),
              Expanded(
                child: Text(
                  _labelOf(spot)!,
                  style: (accented(proportional, refAccent) ?? proportional)?.copyWith(fontSize: mono.fontSize),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          );

    final tile = Padding(
      // Rows render edge-to-edge (the ink below spans the full width); the
      // content inset grows by the split's grab-strip clearance on the left
      // and the real device inset on both edges
      // so nothing interactive sits under the divider overlay or a cutout.
      padding: PaneSafeArea.symmetricOf(context, horizontal: 12, vertical: metrics.spotTilePaddingV),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          line(freqField, callLine),
          SizedBox(height: metrics.spotTileLineGap),
          line(
            Text(
              displayMode(spotMode, freqKHz: freqKHz, band: spotBand) ?? '',
              // The error color outranks the `newMode` accent: a sideband this
              // band doesn't run is a reason not to tap the spot, where a new
              // mode is a reason to.
              style: accented(proportional, modeUnexpected ? faded(theme.colorScheme.error) : modeAccent) ?? proportional,
            ),
            labelLine,
          ),
        ],
      ),
    );

    final row = onTap == null
        ? tile
        : Material(
            color: Colors.transparent,
            child: InkWell(onTap: onTap, child: tile),
          );
    // The divider and the slide both live in the panel's `_SlidableSpotRow`
    // wrapper, not here: a tile's KEY changes as it becomes the current row,
    // which discards this subtree, and a gesture cannot survive inside
    // something that gets discarded mid-drag.
    return highlight == null ? row : ColoredBox(color: highlight!, child: row);
  }
}
