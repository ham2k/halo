// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

part of 'spots_panel.dart';

class _SpotsFilterPill extends StatelessWidget {
  final String bandLabel;
  final String modeLabel;
  final int ageMinutes;
  final int filteredCount;
  final int totalCount;
  final VoidCallback onTap;
  final VoidCallback onRefresh;
  final bool refreshing;

  /// Whether the initial spots fetch is still in flight — shows the
  /// progress bar reserved at the bottom of this pill's own background.
  final bool loading;

  const _SpotsFilterPill({
    required this.bandLabel,
    required this.modeLabel,
    required this.ageMinutes,
    required this.filteredCount,
    required this.totalCount,
    required this.onTap,
    required this.onRefresh,
    required this.refreshing,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    final countLabel = filteredCount == totalCount
        ? t.operation.spots.spotsCount(count: totalCount)
        : t.operation.spots.spotsCountFiltered(count: filteredCount, total: totalCount);

    return Container(
      // Same background as the main logging control area (logging_controls.dart's
      // outer `Material`), so this toggle row reads as the same kind of UI chrome.
      color: theme.colorScheme.tertiaryContainer,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            // Left/right clear the real device inset
            // — the row's own content is centered, but a wide enough pane on a
            // device with a landscape cutout could still push a pill under it.
            padding: PaneSafeArea.symmetricOf(context, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Extra breathing room above and below the pill row.
                Padding(
                  padding: EdgeInsets.symmetric(vertical: LayoutDensity.metricsOf(context).spotTilePaddingV),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Desktop-only manual refresh — mobile refreshes by
                      // pull-to-refresh instead (RefreshIndicator on the list below).
                      if (!isMobilePlatform) ...[
                        _FilterInfoPill(icon: 'refresh', loading: refreshing, onTap: refreshing ? null : onRefresh),
                        const SizedBox(width: Space.sm),
                      ],
                      // The only pill that can grow; flex it so it ellipsizes on a
                      // narrow panel rather than overflowing the row.
                      Flexible(
                        child: _FilterInfoPill(icon: 'radio', label: '$bandLabel • $modeLabel', onTap: onTap),
                      ),
                      const SizedBox(width: Space.sm),
                      _FilterInfoPill(icon: 'clock', label: '${ageMinutes}m', onTap: onTap),
                      const SizedBox(width: Space.sm),
                      _FilterInfoPill(icon: 'tune', onTap: onTap),
                    ],
                  ),
                ),
                Text(
                  countLabel,
                  // Two points larger than the default caption so the spot count
                  // reads clearly under the pills.
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onTertiaryContainer,
                    fontSize: (theme.textTheme.bodySmall?.fontSize ?? 12) + 2,
                  ),
                ),
              ],
            ),
          ),
          // Reserved whether or not the initial fetch is in flight —
          // lives at the bottom of THIS pill's own (salmon/tertiaryContainer)
          // background, flush with its lower edge, rather than floating on
          // the plain scaffold background below the whole filter area.
          SizedBox(
            height: _spotsProgressHeight,
            child: loading ? const LinearProgressIndicator(minHeight: _spotsProgressHeight) : null,
          ),
        ],
      ),
    );
  }
}

/// A small icon (+ optional text) pill — the band/mode/age filter summaries
/// shown next to the tune button, and (icon-only, tappable) the tune button
/// itself.
class _FilterInfoPill extends StatelessWidget {
  final String icon;
  final String? label;
  final VoidCallback? onTap;

  /// Swaps the icon for a spinner (same footprint) — used by the refresh
  /// button while a fetch is in flight.
  final bool loading;

  const _FilterInfoPill({required this.icon, this.label, this.onTap, this.loading = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final poloColors = HaLoColors.of(context);
    final effectiveColor = theme.colorScheme.onTertiaryContainer;

    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
      decoration: BoxDecoration(color: poloColors.tertiaryLight, borderRadius: BorderRadius.circular(8)),
      // Fixed height regardless of whether `label` is present, so the
      // icon-only tune pill matches the icon+text filter-summary pills
      // instead of coming out shorter.
      child: SizedBox(
        height: 20,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (loading)
              SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: effectiveColor))
            else
              Icon(resolveIconName(icon), size: 14, color: effectiveColor),
            if (label != null) ...[
              const SizedBox(width: Space.xs),
              // Same size as the secondary logging controls' own pills
              // (SecondaryControlRow's Chip, which uses the ambient
              // ChipTheme's default labelLarge — no explicit style of its
              // own to match against). Flexible + ellipsis so a long label
              // (e.g. "All Bands • All Modes") shrinks instead of overflowing
              // when the pill is width-constrained on a narrow panel.
              Flexible(
                child: Text(
                  label!,
                  style: theme.textTheme.labelLarge?.copyWith(color: effectiveColor),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (onTap == null) return pill;
    return Material(
      color: Colors.transparent,
      child: InkWell(borderRadius: BorderRadius.circular(8), onTap: onTap, child: pill),
    );
  }
}

/// Continent codes in the order they're offered — @ham2k/lib-dxcc-data's
/// `CONTINENTS` insertion order, ported by hand since that table lives in
/// the JS extension runtime, not halo_core.
const _continentCodes = ['AF', 'AS', 'EU', 'NA', 'OC', 'SA', 'AN'];

/// Top-level (not a `_SpotsFilterDialogState` method) so `_SpotsFilterPill` can
/// use the exact same wording for its collapsed summary — "Auto (20m)"/"All
/// Bands", never a bare "auto"/"any".
String _bandOptionLabel(Translations t, String option, String? autoBand) => switch (option) {
  'auto' => autoBand != null ? t.operation.spots.autoValue(value: autoBand) : t.operation.spots.auto,
  'any' => t.operation.spots.allBands,
  _ => option,
};

/// `autoMode` is the VFO's current *super* mode (Phone/CW/Digital), so "Auto"
/// reads "Auto (Phone)" — the running band/super-mode the filter follows.
String _modeOptionLabel(Translations t, String option, String? autoMode) => switch (option) {
  'auto' => autoMode != null ? t.operation.spots.autoValue(value: autoMode) : t.operation.spots.auto,
  'any' => t.operation.spots.allModes,
  phoneCwModeFilter => t.operation.spots.phoneAndCw,
  _ => option,
};

/// The band/mode summary for the collapsed filter pill: the RESOLVED value
/// first, tagged as followed (e.g. "20m (Auto)", "Phone (Auto)") — the
/// value is what the operator scans for, the tag says it will move with the
/// VFO. (The filter dialog's dropdowns spell it out the other way round via
/// [_bandOptionLabel]/[_modeOptionLabel].) 'auto' with no resolved band/mode
/// falls back to the all-bands/all-modes label. Public for unit testing.
String spotsFilterBandPillLabel(Translations t, String option, String? autoBand) => switch (option) {
  'auto' => autoBand != null ? t.operation.spots.valueAuto(value: autoBand) : t.operation.spots.allBands,
  'any' => t.operation.spots.allBands,
  _ => option,
};

String spotsFilterModePillLabel(Translations t, String option, String? autoMode) => switch (option) {
  'auto' => autoMode != null ? t.operation.spots.valueAuto(value: autoMode) : t.operation.spots.allModes,
  'any' => t.operation.spots.allModes,
  phoneCwModeFilter => t.operation.spots.phoneAndCw,
  _ => option,
};

/// Shared width for the band/mode/age dropdowns so all three line up — 2/3
/// of the dialog's own content width (400), unlike the sorting
/// SegmentedButton which spans it fully.
const double _dropdownWidth = 400 * 2 / 3;

/// The spots filter dialog. Keeps its own local copy of the filter values so
/// widgets that don't self-manage their displayed state (`Switch`) still
/// update live while the dialog is open — a dialog route's content lives in
/// the Navigator's overlay, not as a descendant of `SpotsPanel`, so
/// `_SpotsPanelState.setState` alone wouldn't rebuild it. Every local change
/// is also immediately forwarded to the corresponding `on*Changed` callback
/// so `SpotsPanel`'s own filtering stays in sync without waiting for the
/// dialog to close.
class _SpotsFilterDialog extends StatefulWidget {
  final String bandFilter;
  final String modeFilter;
  final int ageMinutes;
  final String? autoBand;
  final String? autoMode;

  /// The operator's enabled bands, which decide the Band dropdown's entries
  /// (see [spotsFilterBandOptions]).
  final Set<String> enabledBands;
  final int totalSpotCount;
  final Map<String, int> bandSpotCounts;
  final Map<String, int> modeSpotCounts;
  final Map<int, int> ageSpotCounts;
  final String sortBy;
  final bool groupByBand;
  final bool groupCallsWithNotes;
  final List<String> sources;
  final Map<String, String> sourceNames;
  final Map<String, int> sourceSpotCounts;

  /// Sources that never answered the last fetch, and those that answered with
  /// an error. Both show in place of a spot count, which for either of them
  /// would read "0 spots" — indistinguishable from a quiet band.
  final Set<String> unavailableSources;
  final Set<String> failedSources;
  final Set<String> disabledSources;
  final Map<String, int> continentSpotCounts;
  final Set<String> disabledContinents;
  final ValueChanged<String> onBandChanged;
  final ValueChanged<String> onModeChanged;
  final ValueChanged<int> onAgeChanged;
  final ValueChanged<String> onSortByChanged;
  final ValueChanged<bool> onGroupByBandChanged;
  final ValueChanged<bool> onGroupCallsWithNotesChanged;
  final ValueChanged<String> onToggleSource;
  final ValueChanged<String> onToggleContinent;

  const _SpotsFilterDialog({
    required this.bandFilter,
    required this.modeFilter,
    required this.ageMinutes,
    required this.autoBand,
    required this.autoMode,
    required this.enabledBands,
    required this.totalSpotCount,
    required this.bandSpotCounts,
    required this.modeSpotCounts,
    required this.ageSpotCounts,
    required this.sortBy,
    required this.groupByBand,
    required this.groupCallsWithNotes,
    required this.sources,
    required this.sourceNames,
    required this.sourceSpotCounts,
    required this.unavailableSources,
    required this.failedSources,
    required this.disabledSources,
    required this.continentSpotCounts,
    required this.disabledContinents,
    required this.onBandChanged,
    required this.onModeChanged,
    required this.onAgeChanged,
    required this.onSortByChanged,
    required this.onGroupByBandChanged,
    required this.onGroupCallsWithNotesChanged,
    required this.onToggleSource,
    required this.onToggleContinent,
  });

  @override
  State<_SpotsFilterDialog> createState() => _SpotsFilterDialogState();
}

class _SpotsFilterDialogState extends State<_SpotsFilterDialog> {
  late String _bandFilter = widget.bandFilter;
  late String _modeFilter = widget.modeFilter;
  late int _ageMinutes = widget.ageMinutes;
  late String _sortBy = widget.sortBy;
  late bool _groupByBand = widget.groupByBand;
  late bool _groupCallsWithNotes = widget.groupCallsWithNotes;
  late final Set<String> _disabledSources = {...widget.disabledSources};
  late final Set<String> _disabledContinents = {...widget.disabledContinents};

  /// A source row's trailing label: its spot count, or why it hasn't got one.
  /// A source in trouble contributes no spots at all, so the plain count
  /// would say "0 spots" — the same thing a healthy source on a dead band
  /// says, and the confusion this whole distinction exists to end.
  Widget _sourceStatus(String source) {
    final t = context.t;
    final theme = Theme.of(context);
    final trouble = widget.unavailableSources.contains(source) || widget.failedSources.contains(source);
    return Text(
      widget.unavailableSources.contains(source)
          ? t.operation.spots.filters.sourceNoReply
          : widget.failedSources.contains(source)
          ? t.operation.spots.filters.sourceError
          : t.operation.spots.spotsCount(count: widget.sourceSpotCounts[source] ?? 0),
      style: trouble ? TextStyle(color: theme.colorScheme.error) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    // 'auto' first (it's the default and tracks the live VFO), then 'any'.
    final bandOptions = [
      'auto',
      'any',
      ...spotsFilterBandOptions(enabledBands: widget.enabledBands, bandSpotCounts: widget.bandSpotCounts, selected: _bandFilter),
    ];
    final modeOptions = ['auto', 'any', phoneCwModeFilter, ...spotSuperModes];

    return HaloDialog(
      wide: true,
      // A list of filters, not a form: rows and section bands run to the
      // card's edges and inset their contents instead (SettingsList).
      list: true,
      // The body scrolls ITSELF, because its bands pin — a section band that
      // holds the top while its own rows scroll under it needs a sliver
      // viewport, which the shell's plain scroll view is not.
      scrollable: false,
      title: Text(t.operation.spots.filters.title),
      content: CustomScrollView(
        shrinkWrap: true,
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _filterDropdown(
                  label: t.operation.spots.filters.band,
                  initialSelection: _bandFilter,
                  entries: [for (final option in bandOptions) DropdownMenuEntry(value: option, label: _bandEntryLabel(t, option))],
                  onSelected: (value) {
                    if (value == null) return;
                    setState(() => _bandFilter = value);
                    widget.onBandChanged(value);
                  },
                ),
                _filterDropdown(
                  label: t.operation.spots.filters.mode,
                  initialSelection: _modeFilter,
                  entries: [for (final option in modeOptions) DropdownMenuEntry(value: option, label: _modeEntryLabel(t, option))],
                  onSelected: (value) {
                    if (value == null) return;
                    setState(() => _modeFilter = value);
                    widget.onModeChanged(value);
                  },
                ),
                _filterDropdown<int>(
                  label: t.operation.spots.filters.age,
                  initialSelection: _ageMinutes,
                  entries: [
                    for (final minutes in spotAgeOptionsInMinutes)
                      DropdownMenuEntry(
                        value: minutes,
                        label: '${t.operation.spots.ageMinutes(minutes: minutes)} (${widget.ageSpotCounts[minutes] ?? 0})',
                      ),
                  ],
                  onSelected: (value) {
                    if (value == null) return;
                    setState(() => _ageMinutes = value);
                    widget.onAgeChanged(value);
                  },
                ),
              ],
            ),
          ),
          SectionHeader.section(
            context,
            t.operation.spots.filters.sorting,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: settingsRowInset, vertical: Space.sm),
                child: SegmentedButton<String>(
                  // MDI-only UI: skip the framework's Material check on the
                  // selected segment (same as settings_view).
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: 'frequency', label: Text(t.operation.spots.filters.sortByFrequency)),
                    ButtonSegment(value: 'time', label: Text(t.operation.spots.filters.sortByTime)),
                  ],
                  selected: {_sortBy},
                  onSelectionChanged: (selection) {
                    setState(() => _sortBy = selection.first);
                    widget.onSortByChanged(selection.first);
                  },
                ),
              ),
              _toggleRow(
                title: t.operation.spots.filters.groupByBand,
                value: _groupByBand,
                // Grouping by band is meaningless once the Band filter has
                // already narrowed to one band — every spot would land in
                // the same single section anyway.
                onChanged: _isSingleBandFilter
                    ? null
                    : (value) {
                        setState(() => _groupByBand = value);
                        widget.onGroupByBandChanged(value);
                      },
              ),
              _toggleRow(
                title: t.operation.spots.filters.groupCallsWithNotes,
                value: _groupCallsWithNotes,
                onChanged: (value) {
                  setState(() => _groupCallsWithNotes = value);
                  widget.onGroupCallsWithNotesChanged(value);
                },
              ),
            ],
          ),
          if (widget.sources.isNotEmpty)
            SectionHeader.section(
              context,
              t.operation.spots.filters.sources,
              children: [
                for (final source in widget.sources)
                  _toggleRow(
                    title: widget.sourceNames[source] ?? source,
                    value: !_disabledSources.contains(source),
                    trailing: _sourceStatus(source),
                    onChanged: (_) {
                      setState(() => _disabledSources.contains(source) ? _disabledSources.remove(source) : _disabledSources.add(source));
                      widget.onToggleSource(source);
                    },
                  ),
              ],
            ),
          SectionHeader.section(
            context,
            t.operation.spots.filters.continent,
            children: [
              for (final code in _continentCodes)
                _toggleRow(
                  title: _continentLabel(t, code),
                  value: !_disabledContinents.contains(code),
                  trailing: Text(t.operation.spots.spotsCount(count: widget.continentSpotCounts[code] ?? 0)),
                  onChanged: (_) {
                    setState(() => _disabledContinents.contains(code) ? _disabledContinents.remove(code) : _disabledContinents.add(code));
                    widget.onToggleContinent(code);
                  },
                ),
            ],
          ),
        ],
      ),

      // Done, not Apply: every toggle above has already taken effect on the
      // spots list behind this dialog, so there is nothing left for a button
      // to apply. In the `cancel` slot rather than `actions` because it is a
      // way out, not a confirm — see user-interface.md §Dialogs.
      cancel: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(t.common.done)),
    );
  }

  /// A filter row, in the shape every settings row in the app takes: bold
  /// title, whatever the row has to report about itself, and a switch the
  /// WHOLE row works — a title that looks like the rest of the list and does
  /// nothing reads as a broken row.
  Widget _toggleRow({required String title, required bool value, required ValueChanged<bool>? onChanged, Widget? trailing}) {
    final theme = Theme.of(context);
    return ListTile(
      title: Text(title, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing != null) ...[trailing, const SizedBox(width: Space.md)],
          Switch(value: value, onChanged: onChanged),
        ],
      ),
      enabled: onChanged != null,
      onTap: onChanged == null ? null : () => onChanged(!value),
      mouseCursor: onChanged == null ? null : SystemMouseCursors.click,
    );
  }

  /// One of the three pickers above the sections. Fixed-width and centred:
  /// a dropdown stretched to a wide dialog's full width would put its label
  /// and its value at opposite ends of the card.
  Widget _filterDropdown<T>({
    required String label,
    required T? initialSelection,
    required List<DropdownMenuEntry<T>> entries,
    required ValueChanged<T?> onSelected,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Space.sm),
    child: DropdownMenu<T>(
      trailingIcon: dropdownTrailingIcon,
      selectedTrailingIcon: dropdownSelectedTrailingIcon,
      initialSelection: initialSelection,
      width: _dropdownWidth,
      menuHeight: dropdownMenuMaxHeight(context),
      // Pick-only; search's rebuild-time scrollToHighlight would snap the
      // open menu back to the selection whenever spots stream in.
      enableSearch: false,
      label: Text(label),
      dropdownMenuEntries: entries,
      onSelected: onSelected,
    ),
  );

  /// Whether the Band filter has narrowed to one specific band ('auto' and
  /// 'any' both leave multiple bands possible).
  bool get _isSingleBandFilter => _bandFilter != 'auto' && _bandFilter != 'any';

  /// `_bandOptionLabel` plus a "(N)" spot count — every option except
  /// "auto", which has no fixed count to show (it tracks the live VFO).
  String _bandEntryLabel(Translations t, String option) {
    final label = _bandOptionLabel(t, option, widget.autoBand);
    if (option == 'auto') return label;
    final count = option == 'any' ? widget.totalSpotCount : (widget.bandSpotCounts[option] ?? 0);
    return '$label ($count)';
  }

  String _modeEntryLabel(Translations t, String option) {
    final label = _modeOptionLabel(t, option, widget.autoMode);
    if (option == 'auto') return label;
    final count = option == 'any' ? widget.totalSpotCount : (widget.modeSpotCounts[option] ?? 0);
    return '$label ($count)';
  }

  String _continentLabel(Translations t, String code) => switch (code) {
    'AF' => t.operation.spots.continents.af,
    'AS' => t.operation.spots.continents.as,
    'EU' => t.operation.spots.continents.eu,
    'NA' => t.operation.spots.continents.na,
    'OC' => t.operation.spots.continents.oc,
    'SA' => t.operation.spots.continents.sa,
    'AN' => t.operation.spots.continents.an,
    _ => code,
  };
}
