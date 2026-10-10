// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

part of 'activities_view.dart';

/// The map pin drawn inline in the "no location" hint, sized to match the
/// search band's own pin so the two read as the same object. The band's comes
/// from M3's button-icon default, which this tracks by hand: a `WidgetSpan`
/// inside a `Text` has no button style to inherit it from.
const _locationPinSize = 18.0;

mixin _ActivitiesEmptyStates on State<OperationSheet>, _ActivitiesRefs, _ActivitiesExtensions {
  bool get _hasOperationGrid;
  Future<void> _editLocation();

  /// The empty state for the Suggestions & Search section.
  ///
  /// ONE decision, deliberately: a second getter answering "is this a location
  /// problem?" alongside this one drifts the moment a guard is added to only
  /// one of them, and the result is a red headline over "No suggestions", or a
  /// bare reason line with no headline — the two failures this notice exists
  /// to prevent.
  ///
  /// An empty-state message whose headline and body are one string, split on
  /// its own FIRST newline — so which words lead is the translator's call and
  /// not a second key to keep aligned. A message with no newline is all
  /// headline, which is right for the one-liners.
  ///
  /// Only for the single-key messages. Where the two halves are already
  /// separate keys, pass them separately: joining them to re-split here would
  /// give `\n` two meanings at once, and a translator wrapping a long title —
  /// which this very file's messages already do — would silently demote the
  /// tail of their headline into the muted body.
  Widget _emptyStateFromMessage(ThemeData theme, String message) {
    final split = message.indexOf('\n');
    return _emptyStateMessage(theme, title: split < 0 ? message : message.substring(0, split), body: split < 0 ? '' : message.substring(split + 1));
  }

  /// An empty-state message: [title] bold and in [titleColor], [body] muted
  /// under it, centred.
  Widget _emptyStateMessage(ThemeData theme, {required String title, required String body, Color? titleColor}) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: title,
            style: TextStyle(color: titleColor ?? theme.colorScheme.onSurface, fontWeight: FontWeight.bold),
          ),
          if (body.isNotEmpty)
            TextSpan(
              text: '\n$body',
              style: TextStyle(color: theme.colorScheme.outline),
            ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }

  /// Why the refs below are showing without their activities' controls.
  ///
  /// Says the refs are safe on purpose: the rows lose their icons, labels and
  /// tap targets all at once, which reads like the operation lost the refs
  /// themselves. Retry re-runs the fan-out — a hook that timed out on a cold
  /// cache usually answers the second time.
  Widget _controlsFailedNotice(ThemeData theme) {
    final t = context.t.activitiesView;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.xl, Space.md, Space.xl, Space.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _emptyStateMessage(theme, title: t.controlsUnavailableTitle, body: t.controlsUnavailableReason, titleColor: theme.colorScheme.error),
          ),
          TextButton(
            onPressed: () {
              setState(() => _controlsState = ControlsLoadState.loading);
              _loadControls();
            },
            child: Text(t.controlsUnavailableRetry),
          ),
        ],
      ),
    );
  }

  /// The padding every empty state stands in, so the loud one and the quiet
  /// ones sit at the same height under the search band rather than the notice
  /// looking like a different kind of thing.
  Widget _emptyStatePadding({required Widget child}) => Padding(
    padding: const EdgeInsets.only(top: Space.xl, bottom: Space.md),
    child: child,
  );

  /// What to do about a location the OS is withholding, or null when the OS
  /// isn't the thing in the way (no GPS at all, or a fix still coming).
  VoidCallback? get _locationPermissionAction => switch (widget.services.location.status) {
    LocationStatus.permissionDenied => () => unawaited(_grantLocationPermission()),
    LocationStatus.permissionBlocked => () => unawaited(_openLocationSettings()),
    _ => null,
  };

  /// Sends the operator to the OS settings page, or tells them where to go
  /// when the platform has none — a button that silently does nothing is the
  /// worst of the three outcomes.
  Future<void> _openLocationSettings() async {
    final opened = await widget.services.location.openSystemSettings();
    if (opened || !mounted) return;
    widget.services.statusBar.setMessage(key: 'activities:location-permission', text: context.t.activitiesView.locationSettingsUnavailable);
  }

  /// Asks the OS again, and says so when the answer is still no — a button
  /// that appears to do nothing is worse than no button, and "denied again"
  /// and "denied forever" look identical from here.
  Future<void> _grantLocationPermission() async {
    final granted = await widget.services.location.requestPermissionAgain();
    if (!mounted) return;
    if (granted) {
      // The fix that just arrived is what nearby suggestions are computed
      // from; nothing else re-runs the search for a permission grant.
      unawaited(_searchState.search(_searchController.text));
    } else {
      widget.services.statusBar.setMessage(key: 'activities:location-permission', text: context.t.activitiesView.locationGrantRefused);
    }
  }

  /// A location problem gets the loud treatment: a red headline, and the way
  /// out spelled with the very pin that opens the location editor. Muted grey
  /// saying nothing is nearby reads as "there is nothing nearby" — the
  /// opposite of what it means, and the operator stops looking. Every other
  /// empty state is the same shape without the red or the way out.
  Widget _suggestionsEmptyContent(ThemeData theme) {
    final t = context.t.activitiesView;

    // A bare "no suggestions" here would contradict the enable row sitting in
    // the expanded section below: the activity they searched for does exist.
    // Ahead of the failure state below, because that row comes from extension
    // metadata rather than from the hooks — it is a real answer even when
    // every hook is broken.
    if (_disabledMatches.isNotEmpty || _catalogTier.matches.isNotEmpty) {
      // Three sentences, because the remedies differ: a switch for what is
      // installed and off, the Extensions panel for what is on and still not
      // running (there is no switch to flip), and a download and a consent
      // screen for what is not installed.
      final extensions = widget.services.extensions;
      final only = _disabledMatches.isEmpty
          ? t.onlyCatalogMatches
          : _disabledMatches.every(extensions.isExtensionSwitchedOn)
          ? t.onlyNotRunningMatches
          : t.onlyDisabledMatches;
      return _emptyStatePadding(child: _emptyStateFromMessage(theme, only));
    }
    // Nobody could answer, which is not the same as nobody having anything —
    // and telling the operator "no suggestions" for it sends them looking for
    // a reference that may well be there.
    if (_searchState.failed) {
      return _emptyStatePadding(
        child: _emptyStateMessage(theme, title: t.searchUnavailableTitle, body: t.searchUnavailableReason, titleColor: theme.colorScheme.error),
      );
    }
    // A typed search, or a location the search could actually use, was
    // answerable — it simply found nothing, and location has no part in that.
    // The device's own last fix counts even under a bad status: it is never
    // cleared, so `suggestActivities` searched WITH it, and blaming the
    // location for an empty answer it had nothing to do with sends the
    // operator to type a grid that will change none of it.
    if (_searchController.text.trim().isNotEmpty || _hasOperationGrid || widget.services.location.position != null) {
      return _emptyStatePadding(
        child: _emptyStateMessage(theme, title: t.noSuggestions, body: '${t.noSuggestionsHint}\n${t.noSuggestionsExample}'),
      );
    }

    // Denied permission and a location the device can't produce are named
    // apart: only one of them is the operator's to grant.
    final (String? title, String plain) = switch (widget.services.location.status) {
      LocationStatus.permissionDenied => (t.locationDeniedTitle, t.noNearbyReason),
      LocationStatus.permissionBlocked => (t.locationBlockedTitle, t.noNearbyReason),
      LocationStatus.unavailable => (t.locationUnavailableTitle, t.noNearbyReason),
      LocationStatus.unknown || LocationStatus.determining => (null, t.determiningLocation),
      LocationStatus.available => (null, t.noSuggestions),
    };
    if (title == null) return _emptyStatePadding(child: _emptyStateFromMessage(theme, plain));

    final muted = TextStyle(color: theme.colorScheme.outline);

    // The hint's pin is a placeholder in the translation rather than a fixed
    // position, so a language that needs the icon elsewhere in the sentence can
    // put it there. U+FFFC is the character that exists to stand in for an
    // embedded object, written as an escape because it renders as nothing in a
    // source file and cannot be reviewed. Every segment is rendered and every
    // seam gets a pin: a translation is free to use the placeholder twice, or
    // not at all, and must not lose the words between them either way.
    const iconMark = '\u{FFFC}';
    final hint = t.locationManualHint(icon: iconMark).split(iconMark);

    // The ink layer must be the notice itself. Taken from the sheet's root
    // Material instead, the highlight paints outside this viewport's clip and
    // keeps drawing over the pinned search band as the list scrolls under it.
    return Material(
      type: MaterialType.transparency,
      // A paragraph that happens to be tappable announces itself as prose: the
      // one operator who most needs the way out spelled aloud is told there
      // isn't one.
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: _editLocation,
          child: _emptyStatePadding(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _emptyStateMessage(theme, title: title, body: plain, titleColor: theme.colorScheme.error),
                // The fix the OS will actually accept, when there is one: a
                // permission the app may ask for again is a button that asks,
                // and one the operator has already refused for good is a button
                // that opens the settings page where it can be undone. Offering
                // either in the other's place wastes the tap.
                if (_locationPermissionAction != null) ...[
                  const SizedBox(height: Space.lg),
                  FilledButton(
                    onPressed: _locationPermissionAction,
                    child: Text(widget.services.location.status == LocationStatus.permissionDenied ? t.locationGrantAction : t.locationSettingsAction),
                  ),
                ],
                // What to do about it is its own paragraph, not a third line of
                // the diagnosis.
                const SizedBox(height: Space.lg),
                Text.rich(
                  TextSpan(
                    children: [
                      for (var i = 0; i < hint.length; i++) ...[
                        if (i > 0)
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Icon(MdiIcons.mapMarkerOff, size: _locationPinSize, color: theme.colorScheme.error),
                          ),
                        TextSpan(text: hint[i], style: muted),
                      ],
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
