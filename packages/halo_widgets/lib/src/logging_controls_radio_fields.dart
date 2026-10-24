// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What the Radio and Power controls draw: their expanded rows, their chips'
// summaries, and the status colour the Radio chip shares with the spotting
// control. Every decision about what the fields hold is [RadioControlModel]'s.

part of 'logging_controls_radio.dart';

/// Red (configured but not connected) or green (connected) — the same
/// red/green convention `CallInfoSummary`'s notice pills use. Null when
/// there's no radio to report on, so a caller can fall back to the theme
/// default.
///
/// [selected] is the pill's own — the SAME `iconColor` renders on two
/// different fills: `colorScheme.tertiary` when the Radio control is
/// selected/expanded (also the expanded button's own background), and the
/// lighter `HaLoColors.tertiaryLight` when it's a plain unselected chip.
/// Which of those two is the DARKER one flips between light and dark mode
/// (light mode: tertiary is a dark amber, tertiaryLight a light tan; dark
/// mode: tertiary is a light-ish amber, tertiaryLight a near-black brown)
/// — so which color pair reads well flips with `selected`, not just with
/// the theme.
Color? radioStatusColor(ThemeData theme, {required bool hasConfiguredRadio, required bool connected, required bool selected}) {
  if (!hasConfiguredRadio) return null;
  final dark = theme.brightness == Brightness.dark;
  if (dark != selected) {
    // light+selected or dark+unselected: sitting on the darker fill —
    // needs a light pastel pair.
    return connected ? const Color(0xFF81C784) : const Color(0xFFFF8A80);
  }
  if (dark) {
    // dark+selected: sitting on dark mode's `colorScheme.tertiary`
    // (#D9904C), a LIGHT amber — so this branch needs a dark pair, like
    // light+unselected below, not the light pastels above. Notably neither
    // `colorScheme.error` (dark mode's is a pale #F79797: 1.23:1 on that
    // amber, and it simply vanishes) nor the shared [positiveGreen], which
    // is tuned for its own dark fills and lands at 1.97:1 here.
    //
    // The amber is not the only fill this cell paints on: editing a logged
    // QSO swaps the panel's accent to `secondary` (#5B9EDE), where the same
    // pair reads 2.96:1 and 3.00:1 — at the threshold rather than above it.
    // Retuning `secondary` is what would push it under.
    //
    // Both are FULLY SATURATED at the darkness the amber forces, rather
    // than the muddier tones a burgundy/forest pair would use: 3:1 caps
    // luminance at 0.083 on this fill, and spending all of that on one
    // channel is what keeps them reading as red and green rather than as
    // two dark browns. 3.2:1 both.
    return connected ? const Color(0xFF005A00) : const Color(0xFFA00000);
  }
  // light+unselected: tertiaryLight is a fairly bright tan — needs a
  // properly dark pair to clear 3:1.
  return connected ? const Color(0xFF1B5E20) : const Color(0xFFB71C1C);
}

/// The Radio control's expanded row: Band, Frequency, Mode, and the Station
/// Configuration button. Draws from [model]; every decision about what the
/// fields hold is the model's.
class RadioControlFields extends StatelessWidget {
  const RadioControlFields({
    super.key,
    required this.model,
    required this.theme,
    required this.freqInputFormatters,
    required this.freqKeyboardType,
    required this.onFreqSubmitted,
    required this.onPicked,
  });

  final RadioControlModel model;

  /// The panel's accent theme — the row is painted on it, and the fields
  /// have to be built against it rather than against `Theme.of(context)`.
  final ThemeData theme;

  /// The panel's own formatters for the frequency field — the Space-to-advance
  /// formatter is the panel's, since Space's meaning is the panel's contract.
  final List<TextInputFormatter> freqInputFormatters;
  final TextInputType? freqKeyboardType;

  /// Enter in the frequency field closes the control rather than logging
  /// (APP-19) — the same thing the panel's expanded-control key handler does
  /// with the raw key, for the platforms where the engine turns Enter into a
  /// text-input action before the framework sees it.
  final VoidCallback onFreqSubmitted;

  /// A pick from either menu is done with the control — the panel puts the
  /// keyboard back where it belongs.
  final VoidCallback onPicked;

  /// The Station Configuration button's color: [radioStatusColor] on the
  /// expanded panel's fill (the button only ever renders selected), or — a
  /// radio that isn't configured at all barely registers — a lighter tint of
  /// that same fill. Dimmed further while editing a logged QSO, when the
  /// button is disabled.
  Color _stationConfigIconColor({required bool editing}) {
    final status = model.statusColor(theme, selected: true) ?? Color.lerp(theme.colorScheme.tertiary, Colors.white, 0.4)!;
    return editing ? status.withValues(alpha: 0.38) : status;
  }

  /// The same density-resolved pair poloFieldDecoration gives the sibling
  /// Frequency field. A `DropdownMenu` takes an inputDecorationTheme rather
  /// than an InputDecoration, so it cannot share that helper and has to
  /// restate the values — held together by the "same height as its siblings"
  /// test. A const here froze both dropdowns at one height while the field
  /// beside them ran 46 to 65 across the ladder.
  InputDecorationTheme _dropdownDecorationTheme(BuildContext context) {
    // `dropdownTextScale` is the OS accessibility scaler, not the app font
    // scale (UiScale already handles that one) — the same treatment
    // poloFieldDecoration gives its own padding, so the two stay the same
    // height under OS text scaling as well as under density.
    final dropdownMetrics = LayoutDensity.metricsOf(context);
    final dropdownTextScale = MediaQuery.textScalerOf(context).scale(1.0);
    return InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: theme.colorScheme.surface,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      floatingLabelStyle: TextStyle(fontSize: 14, color: theme.colorScheme.onTertiaryContainer),
      contentPadding: EdgeInsets.fromLTRB(
        Space.xs,
        dropdownMetrics.fieldPaddingTop * dropdownTextScale,
        Space.xs,
        dropdownMetrics.fieldPaddingBottom * dropdownTextScale,
      ),
      // Without this the trailing arrow's 48px min tap target makes the
      // field taller (56px) than the sibling poloFieldDecoration TextFields
      // (53px); the whole field is tappable, so the shrunken icon target
      // costs nothing.
      suffixIconConstraints: const BoxConstraints(maxHeight: 38, maxWidth: 24),
      // This theme replaces the app's rather than extending it, so the
      // focus indicator has to be restated too — otherwise this field
      // focuses `primary` while the Frequency field beside it focuses
      // white. Underline is already the shape here (no `border` is set), so
      // this recolors without reshaping.
      focusedBorder: haloFocusedInputBorder(theme.brightness == Brightness.dark),
    );
  }

  @override
  Widget build(BuildContext context) {
    // One read of the model's configuration per build, so the row can never
    // disagree with the model — or with itself — about the rig and which QSO
    // this is. Editing an existing QSO: the Station Configuration button is
    // disabled, since retuning the shack shouldn't read as an action on a
    // QSO that's already in the log.
    final config = model.config();
    final editing = config.editingQso != null;
    final decorationTheme = _dropdownDecorationTheme(context);
    final textStyle = haloMonoStyle(context, fontSize: 15, fontWeight: FontWeight.w500);
    // DropdownMenu treats an explicit focusNode's canRequestFocus as
    // overriding its per-platform requestFocusOnTap default, so restore
    // that default here: type-to-filter is a keyboard (desktop) affordance;
    // on touch platforms tapping stays a plain pick, without popping the
    // on-screen keyboard.
    final typeable = switch (Theme.of(context).platform) {
      TargetPlatform.iOS || TargetPlatform.android || TargetPlatform.fuchsia => false,
      _ => true,
    };
    model.bandFocus.canRequestFocus = typeable;
    model.modeFocus.canRequestFocus = typeable;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The frame: see [RadioControlModel.bandFrame]. Not a Tab stop and
        // never focused itself; it only marks which nodes are the dropdown's.
        Focus(
          focusNode: model.bandFrame,
          canRequestFocus: false,
          skipTraversal: true,
          includeSemantics: false,
          // Same tap-region group as the menu itself (MenuAnchor keys it on
          // the MenuController), so this fires for the pointer downs that
          // close the menu from outside and for no other — see
          // [RadioControlModel.onBandMenuTapOutside].
          child: TapRegion(
            groupId: model.bandMenu,
            onTapOutside: (_) => model.onBandMenuTapOutside(),
            // DropdownMenu's own trailing arrow is a plain, unstyled IconButton
            // (see dropdown_menu.dart) — with no style of its own it picks up
            // Material 3's default toggle-button treatment, which paints a
            // filled circle behind the glyph even when the menu is closed.
            child: IconButtonTheme(
              data: dropdownArrowTheme,
              child: DropdownMenu<String>(
                trailingIcon: dropdownTrailingIcon,
                selectedTrailingIcon: dropdownSelectedTrailingIcon,
                controller: model.bandController,
                focusNode: model.bandFocus,
                menuController: model.bandMenu,
                initialSelection: model.band,
                label: Text(t.qsoEditForm.band),
                width: 86,
                menuHeight: dropdownMenuMaxHeight(context),
                // Pick-only menus. With search on (the default), every rebuild
                // whose field text matches an entry re-runs scrollToHighlight —
                // and this row rebuilds every second (the Time chip's clock), so
                // an open menu kept snapping back to the selected item while the
                // user scrolled.
                enableSearch: false,
                menuStyle: _shieldedMenuStyle,
                textStyle: textStyle,
                inputDecorationTheme: decorationTheme,
                dropdownMenuEntries: model.bandMenuEntries,
                onSelected: (value) {
                  if (value == null) return;
                  model.pickBand(value);
                  onPicked();
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: Space.sm),
        SizedBox(
          width: 90,
          // The notation's mark on every device. The device's own works too —
          // `parseFreq` reads a comma as a period — but would show a mark the
          // field's own value never carries.
          child: NumbersRowExtraKey(
            extraKey: frequencyMark,
            child: TextField(
              controller: model.freqController,
              focusNode: model.freqFocus,
              selectAllOnFocus: false,
              style: textStyle,
              decoration: poloFieldDecoration(context, t.loggingControls.frequency, labelColor: Theme.of(context).colorScheme.onTertiaryContainer),
              keyboardType: freqKeyboardType,
              // No autocorrect/suggestions/smart punctuation — see Sent.
              autocorrect: false,
              enableSuggestions: false,
              smartDashesType: SmartDashesType.disabled,
              smartQuotesType: SmartQuotesType.disabled,
              inputFormatters: [
                ...freqInputFormatters,
                // `m`/`c` are here for the band forms the field also takes
                // ("20m", "70cm" — see [RadioControlModel.commitBandTypedIntoFreqField]),
                // not for frequencies. A letter left in a frequency makes
                // `parseFreq` return null, and the field says nothing about
                // it: the value simply doesn't reach the QSO or the VFO, the
                // same as any other text this field can't read.
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,mMcC]')),
              ],
              onSubmitted: (_) => onFreqSubmitted(),
            ),
          ),
        ),
        const SizedBox(width: Space.sm),
        // Same three wrappers, for the same reasons, as the Band dropdown above.
        Focus(
          focusNode: model.modeFrame,
          canRequestFocus: false,
          skipTraversal: true,
          includeSemantics: false,
          child: TapRegion(
            groupId: model.modeMenu,
            onTapOutside: (_) => model.onModeMenuTapOutside(),
            child: IconButtonTheme(
              data: dropdownArrowTheme,
              child: DropdownMenu<String>(
                trailingIcon: dropdownTrailingIcon,
                selectedTrailingIcon: dropdownSelectedTrailingIcon,
                controller: model.modeController,
                focusNode: model.modeFocus,
                menuController: model.modeMenu,
                initialSelection: model.displayedMode,
                label: Text(t.loggingControls.mode),
                width: 86,
                menuHeight: dropdownMenuMaxHeight(context),
                // See the Band dropdown: search off so rebuilds don't re-scroll
                // the open menu to the selection.
                enableSearch: false,
                menuStyle: _shieldedMenuStyle,
                textStyle: textStyle,
                inputDecorationTheme: decorationTheme,
                dropdownMenuEntries: model.modeMenuEntries,
                onSelected: (value) {
                  if (value == null) return;
                  model.pickMode(value);
                  onPicked();
                },
              ),
            ),
          ),
        ),
        if (config.radio.onOpenStationConfig case final onOpenStationConfig?) ...[
          const SizedBox(width: Space.sm),
          // Flexible, so the radio's name under the icons takes whatever the
          // row has left rather than a fixed few icons' width. The panel
          // hands this row a bounded width (it is Aligned inside the panel).
          Flexible(
            child: Semantics(
              identifier: 'action.stationConfig',
              // The button is icon-only and the app shows no hover tooltips,
              // so this label is the ONLY accessible name it has.
              label: t.settings.station.title,
              button: true,
              enabled: !editing,
              child: InkWell(
                key: const ValueKey('stationConfigButton'),
                // Not one of Radio's fields (docs/design/logging-fields.md
                // names exactly Band, Frequency, Mode) — the ancestor Focus
                // that intercepts Tab for this control only knows about those
                // three, so a mouse click's default focus grab here would make
                // Tab compute currentIndex == -1 and jump backward to Band
                // instead of exhausting the control and crossing to the next
                // pill.
                canRequestFocus: false,
                onTap: editing ? null : onOpenStationConfig,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  // Left-aligned so the icon and the (usually wider) name both
                  // start flush against the Mode dropdown beside them.
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ExcludeSemantics(
                          child: Icon(
                            MdiIcons.cat,
                            size: stationConfigIconSize,
                            color: _stationConfigIconColor(editing: editing),
                          ),
                        ),
                        // The way to connect a radio that is down, beside the
                        // cat whose red says so. A control of its own inside
                        // this one: its tap connects rather than opening the
                        // dialog, and its own node carries its name.
                        if (config.radio.onConnectRadio case final onConnectRadio?) ...[
                          const SizedBox(width: Space.md),
                          Semantics(
                            container: true,
                            identifier: 'action.connectRadio',
                            label: t.settings.station.connect,
                            button: true,
                            enabled: !editing,
                            child: InkWell(
                              key: const ValueKey('connectRadioButton'),
                              // Not one of Radio's fields, same as the button
                              // around it.
                              canRequestFocus: false,
                              onTap: editing ? null : onConnectRadio,
                              child: ExcludeSemantics(
                                child: Icon(
                                  MdiIcons.powerPlugOff,
                                  size: stationConfigIconSize,
                                  color: _stationConfigIconColor(editing: editing),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (config.radio.radioName case final radioName?)
                      ExcludeSemantics(
                        child: Text(
                          radioName,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(fontSize: 11, color: theme.colorScheme.onTertiary.withValues(alpha: editing ? 0.38 : 1)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// The Radio chip and its expanded fields, read from [model]. [selected] is
/// whether this chip is the one expanded right now, which tints its icon.
SecondaryControlSpec radioControlSpec(
  RadioControlModel model,
  ThemeData theme, {
  required bool selected,
  required List<TextInputFormatter> freqInputFormatters,
  required TextInputType freqKeyboardType,
  required VoidCallback onFreqSubmitted,
  required VoidCallback onPicked,
}) => SecondaryControlSpec(
  key: 'radio',
  icon: model.transmitting ? MdiIcons.circle : model.chipIcon,
  iconColor: model.transmitting ? theme.colorScheme.error : model.statusColor(theme, selected: selected),
  // `band` is null both when nothing is tuned at all and when the
  // frequency in the field falls outside every ham band; `outOfBand`
  // catches the case a band name can't — a frequency inside a ham band
  // that the operator's own region or country doesn't allocate to
  // amateurs (e.g. 7250 kHz in ITU Region 1).
  alert: model.band == null || model.outOfBand,
  summary: model.summary,
  summaryParts: model.summaryParts(errorColor: theme.colorScheme.error),
  expandedBuilder: (context) => RadioControlFields(
    model: model,
    theme: theme,
    freqInputFormatters: freqInputFormatters,
    freqKeyboardType: freqKeyboardType,
    onFreqSubmitted: onFreqSubmitted,
    onPicked: onPicked,
  ),
);

/// The Power control's expanded field: watts, four digits wide, read from
/// [model], which seeds it from the VFO and pushes it back on submit or
/// blur.
class PowerControlFields extends StatelessWidget {
  const PowerControlFields({super.key, required this.model, required this.keyboardType});

  final RadioControlModel model;
  final TextInputType keyboardType;

  @override
  Widget build(BuildContext context) {
    final labelColor = Theme.of(context).colorScheme.onTertiaryContainer;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          // Four digits is every legal amateur power, the same width the
          // Station Configuration field is sized to.
          width: 72,
          child: TextField(
            controller: model.powerController,
            focusNode: model.powerFocus,
            selectAllOnFocus: false,
            style: haloMonoStyle(context, fontSize: 15, fontWeight: FontWeight.w500),
            decoration: poloFieldDecoration(context, t.loggingControls.power, labelColor: labelColor),
            keyboardType: keyboardType,
            autocorrect: false,
            enableSuggestions: false,
            smartDashesType: SmartDashesType.disabled,
            smartQuotesType: SmartQuotesType.disabled,
            // A decimal point earns its place at the QRPp end (0.5 W);
            // everything else a keyboard can offer here is noise.
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            onSubmitted: (_) => model.commitPower(),
          ),
        ),
        const SizedBox(width: Space.sm),
        Text(t.loggingControls.powerUnit, style: TextStyle(color: labelColor)),
      ],
    );
  }
}

/// The Power chip's glyph — the settings dialog's entry reads this too.
const powerChipIcon = MdiIcons.flash;

/// The Power chip and its expanded field, read from [model].
SecondaryControlSpec powerControlSpec(RadioControlModel model, {required TextInputType keyboardType}) => SecondaryControlSpec(
  key: 'power',
  icon: powerChipIcon,
  summary: model.powerSummary,
  expandedBuilder: (context) => PowerControlFields(model: model, keyboardType: keyboardType),
);

/// A Band or Mode menu entry's own padding, moved inside its label — see
/// [_ShieldedEntryLabel].
final _shieldedEntryStyle = MenuItemButton.styleFrom(padding: EdgeInsets.zero);

/// The Band and Mode menus' panel, with no padding of its own outside the
/// entries' shields — see [_ShieldedEntryLabel].
const _shieldedMenuStyle = MenuStyle(padding: WidgetStatePropertyAll(EdgeInsets.zero));

/// A Band or Mode menu entry's label, spanning its row and shielded: the menu
/// is an overlay of the field's own, and a map beneath it would otherwise take
/// its clicks on the web (platform_view_shield.dart). The row's height and its
/// padding are the menu item's own, held by the label instead.
class _ShieldedEntryLabel extends StatelessWidget {
  final String label;

  const _ShieldedEntryLabel(this.label);

  @override
  Widget build(BuildContext context) => PlatformViewShield(
    child: SizedBox(
      width: double.infinity,
      // A menu item's own least height (48), as its density adjusts it.
      height: 48 + Theme.of(context).visualDensity.baseSizeAdjustment.dy,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.lg),
        child: Align(alignment: AlignmentDirectional.centerStart, child: Text(label)),
      ),
    ),
  );
}
