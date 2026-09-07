// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// First-run onboarding, shown over the app until the operator has a
// callsign. ONBOARD_AS skips it for dev runs; DEVONBOARD forces it back.

import 'dart:async';

import 'package:flutter/material.dart';

import '../onboarding_overlay.dart';
import '../../config/dev_flags.dart';
import '../../config/release_notes.dart';
import '../../config/version.dart';

import '../../services/settings_service.dart';

import '../../services/halo_services.dart';

/// Debug-only shortcut for skipping the onboarding flow: set
/// `ONBOARD_AS=CALL,activity,...` — e.g. `ONBOARD_AS=KI2D,pota,sota` — as a
/// `--dart-define` or an environment variable, and a first run applies that
/// operator callsign and enables the listed activity extensions instead of
/// showing onboarding. The first comma-separated token is the callsign; the
/// rest are extension keys to enable. Empty (and inert) in release builds.
String get _onboardAsConfig => debugEnvFlag(const String.fromEnvironment('ONBOARD_AS'), 'ONBOARD_AS');

/// Whether onboarding is about to show for [services]: the default profile
/// has never had a callsign set, and no ONBOARD_AS debug override is
/// skipping the flow instead. Shared by `_OnboardingGateState.initState`
/// (which decides whether to actually show it) and `_BootGateState` (which
/// decides whether to wait for its photo before switching off the splash)
/// so the two can't silently drift apart into two different answers.
bool onboardingWillShow(HaLoServices services) =>
    !services.settings.defaultProfileCallsignDefined && _onboardAsConfig.isEmpty;

/// Applies an `ONBOARD_AS=CALL,activity,...` spec (see [_onboardAsConfig]):
/// sets the operator callsign and enables the listed activity extensions.
/// Writing the callsign marks onboarding answered, so the flow never shows.
/// The first comma-separated token is the callsign; the rest are extension
/// keys to enable. A no-op for a blank/empty spec.
@visibleForTesting
Future<void> applyOnboardAsSpec(HaLoServices services, String spec) async {
  final parts = spec.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  if (parts.isEmpty) return;
  final call = parts.first.toUpperCase();
  final activities = parts.skip(1).map((s) => s.toLowerCase()).toList();
  debugPrint('[onboarding] ONBOARD_AS: callsign=$call activities=$activities');
  await services.setOperatorCall(call);
  if (activities.isNotEmpty) {
    await services.extensions.setExtensionsEnabled({for (final a in activities) a: true});
  }
}

/// First-run onboarding: wraps the release overlay gate so the
/// onboarding paints on top of everything, whenever the default profile has
/// NEVER had a callsign set — undefined, not '' (an explicit empty from a
/// previous Skip counts as answered). Unlike the release overlay/About photo
/// modal, always full screen — even on wide layouts — rather than
/// `wideModalChrome`'s centered card: this is a first impression, and the
/// release photo should fill the whole window rather than float over a
/// blurred backdrop. No barrier dismissal either way; the flow's own
/// Skip/Done are the exits.
class OnboardingGate extends StatefulWidget {
  final HaLoServices services;
  final Widget child;

  const OnboardingGate({super.key, required this.services, required this.child});

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  bool _pending = false;
  ReleaseNotesEntry? _release;

  /// Whether the current showing is the organic first run (vs a DEVONBOARD
  /// re-show) — only the first run stamps the release notes as seen.
  bool _firstRun = false;

  @override
  void initState() {
    super.initState();
    if (onboardingWillShow(widget.services)) {
      _firstRun = true;
      // 'shown' the moment the organic flow is decided, not when it's
      // dismissed — this is a display count, and DEVONBOARD re-shows
      // (the only other caller of _show()) must not bump it.
      unawaited(widget.services.settings.recordOnboardingShown(OnboardingFlows.firstUse));
      _show();
    } else if (!widget.services.settings.defaultProfileCallsignDefined) {
      // Debug-only: ONBOARD_AS is set — apply it and skip the onboarding
      // flow entirely.
      unawaited(applyOnboardAsSpec(widget.services, _onboardAsConfig));
    }
    widget.services.devOnboardTrigger.addListener(_show);
  }

  @override
  void dispose() {
    widget.services.devOnboardTrigger.removeListener(_show);
    super.dispose();
  }

  /// First run, or DEVONBOARD (which bypasses the callsign-undefined gate
  /// for iterating on the flow — and is real: its Done writes settings).
  /// Re-triggering during the dismissal fade re-arms the overlay.
  void _show() {
    if (!mounted) return;
    setState(() {
      _pending = true;
      _dismissing = false;
    });
    // The background photo is the newest release's — same imagery as the
    // release overlay. Onboarding must never be stuck waiting on it (this is
    // a first run — the flow has to appear right away), so it's fine to
    // arrive late (or never); OnboardingOverlayView itself crossfades the
    // photo in once it's actually finished downloading rather than popping
    // it in, so a late arrival still doesn't look broken.
    loadReleaseNotes().then((notes) {
      if (mounted && notes.isNotEmpty) setState(() => _release = notes.first);
    }).catchError((Object error, StackTrace stackTrace) {
      // Same tolerance as above: a broken/missing release-notes asset just
      // means no photo, not a broken onboarding flow — but still needs a
      // handler, or this becomes an unhandled rejection.
      debugPrint('[onboarding] release notes unavailable: $error\n$stackTrace');
    });
  }

  /// True while the finished overlay dissolves into the home screen —
  /// removed from the tree only once the fade completes.
  bool _dismissing = false;

  void _dismiss() {
    if (_dismissing) return;
    // A fresh install doesn't need "what's new" for the version it just
    // installed — mark it seen so the release overlay doesn't follow the
    // onboarding (its own gate also skips while onboarding is pending).
    // NOT on DEVONBOARD re-shows: those never displayed any notes, and
    // stamping would suppress a pending release overlay.
    if (_firstRun) widget.services.settings.setLastSeenReleaseVersion(kPublicVersion);
    setState(() => _dismissing = true);
  }

  void _finalizeDismiss() {
    if (!mounted || !_dismissing) return;
    setState(() {
      _pending = false;
      _dismissing = false;
      _firstRun = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget? overlay;
    if (_pending) {
      // Always full screen — see this class's doc comment — so no
      // wideModalChrome wrap on wide layouts, unlike the release overlay.
      final view = OnboardingOverlayView(
        // Re-inflates the whole subtree per showing, so the content's State is
        // fresh (matters for DEVONBOARD re-shows — step position and toggles
        // reset). This widget holds no state of its own.
        key: ValueKey('onboarding-$_firstRun-$_pending'),
        services: widget.services,
        release: _release,
        onDone: _dismiss,
      );
      // The onboarding subtree mounts inside its OWN Overlay (Overlay.wrap):
      // this gate sits in MaterialApp.builder, above the Navigator, and the
      // callsign step's TextField requires an Overlay ancestor. Done/Skip
      // dissolve the whole overlay (chrome included) into the home screen
      // rather than cutting away.
      overlay = Positioned.fill(
        child: AnimatedOpacity(
          opacity: _dismissing ? 0 : 1,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
          onEnd: _finalizeDismiss,
          child: IgnorePointer(ignoring: _dismissing, child: Overlay.wrap(child: view)),
        ),
      );
    }
    return Stack(
      children: [
        widget.child,
        if (overlay != null) overlay,
      ],
    );
  }
}
