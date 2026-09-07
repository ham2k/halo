// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Splash until bootstrap() resolves, then the app — crossfaded, and held a
// moment longer when onboarding is about to show so its photo is warm.

import 'dart:async';

import 'package:flutter/material.dart';

import '../splash_view.dart';
import '../../config/release_notes.dart';

import '../../services/error_reporting_service.dart';

import '../../services/halo_services.dart';
import 'halo_app.dart';
import 'onboarding_gate.dart';

/// Shows `SplashScreen` on the very first frame — before `bootstrap()`'s
/// async services are ready — then fades into the real `HaLoApp` once they
/// resolve. Nothing is interactive during the splash (no routes have been
/// pushed yet), so swapping to a second, fully-formed `MaterialApp` instance
/// for the real app is safe: there's no Navigator state to lose.
///
/// Deliberately NOT `AnimatedSwitcher`: its default transition fades the
/// outgoing screen out at the same time as it fades the incoming one in, so
/// for the middle third of the transition both are semi-transparent at once
/// — the splash's logo shows through, ghosted, on top of the home screen's
/// background, and the double-transparency washes the whole frame out
/// (reported as "flashing"). Keeping the outgoing screen fully opaque and
/// only fading the incoming one in on top removes both the ghosting and the
/// wash-out: at every point during the transition there's exactly one
/// opaque screen plus one partially-visible screen layered on it, not two.
@visibleForTesting
class BootGate extends StatefulWidget {
  final Future<HaLoServices> servicesFuture;

  const BootGate({super.key, required this.servicesFuture});

  @override
  State<BootGate> createState() => _BootGateState();
}

class _BootGateState extends State<BootGate> with SingleTickerProviderStateMixin {
  static const _transitionDuration = Duration(milliseconds: 200);

  late final AnimationController _fadeController = AnimationController(vsync: this, duration: _transitionDuration)..value = 1;

  Widget _currentChild = const MaterialApp(
    key: ValueKey('splash'),
    debugShowCheckedModeBanner: false,
    home: SplashScreen(),
  );
  Widget? _previousChild;

  /// Bounds how long [initState] waits for the onboarding photo (see below)
  /// before giving up and switching off the splash without it.
  static const _onboardingPhotoTimeout = Duration(seconds: 5);

  /// Warms the image cache with onboarding's full-bleed release photo (a
  /// JPEG several hundred KB — real weight on web) so that by the time
  /// `OnboardingGate` mounts moments after this resolves, `Image.asset`
  /// paints it immediately instead of a frame (or several, on a slow
  /// connection) behind — the whole point of waiting here instead of
  /// switching off the splash first. Takes the already-started
  /// [releaseNotes] future rather than loading it itself, since [initState]
  /// kicks that off before `servicesFuture` resolves. `context` is fine to
  /// use for `precacheImage` despite no `MaterialApp`/`MediaQuery` ancestor
  /// existing yet (see this class's own build() comment): the release photo
  /// has no resolution-variant assets declared, so its cache key doesn't
  /// depend on the devicePixelRatio that'd otherwise come from one.
  Future<void> _prepareOnboardingPhoto(Future<List<ReleaseNotesEntry>> releaseNotes) async {
    final notes = await releaseNotes;
    if (notes.isEmpty || !mounted) return;
    await precacheImage(AssetImage(notes.first.imageAssetPath), context);
  }

  @override
  void initState() {
    super.initState();
    // Started here, not inside the `.then` below: loading the release notes
    // has no actual dependency on `services` — only the decision to wait on
    // it (below) does — so this overlaps with bootstrap() instead of being
    // serialized behind it. Cheap regardless of whether onboarding ends up
    // showing: `loadReleaseNotes` caches its result, and the release-overlay
    // gate reads the same asset unconditionally on every boot anyway.
    final releaseNotes = loadReleaseNotes();
    widget.servicesFuture.then((services) async {
      if (!mounted) return;
      if (onboardingWillShow(services)) {
        try {
          await _prepareOnboardingPhoto(releaseNotes).timeout(_onboardingPhotoTimeout, onTimeout: () {});
        } catch (error, stackTrace) {
          // Best-effort, same "fine to arrive late, or never" tolerance as
          // _OnboardingGateState._show() itself — a broken/missing
          // release-notes asset or photo must not block boot. Caught here
          // rather than left to the `.catchError` below, which would
          // otherwise mislabel it as `bootstrap()` failing and take down
          // the whole app instead of just onboarding's photo.
          debugPrint('[boot] onboarding photo prep failed (not a bootstrap() failure): $error\n$stackTrace');
        }
      }
      if (!mounted) return;
      // Wrapped separately from the `.catchError` below: that one exists to
      // catch `bootstrap()` itself failing, and without this try/catch it
      // would also swallow an unrelated error thrown by `_switchTo` here,
      // mislabeling it as a boot failure in the debug log.
      try {
        _switchTo(HaLoApp(key: const ValueKey('app'), services: services));
      } catch (error, stackTrace) {
        debugPrint('[boot] unexpected error building HaLoApp (not a bootstrap() failure): $error\n$stackTrace');
        ErrorReportingService.report(error, stackTrace, context: 'boot:build-app');
        _switchTo(MaterialApp(
          key: const ValueKey('boot-error'),
          debugShowCheckedModeBanner: false,
          home: BootErrorScreen(error: error),
        ));
      }
    }).catchError((Object error, StackTrace stackTrace) {
      // Fail loud: runApp() happens before bootstrap() resolves, so an
      // unhandled rejection here would strand the user
      // on the splash screen forever with no visible error.
      debugPrint('[boot] bootstrap() failed: $error\n$stackTrace');
      ErrorReportingService.report(error, stackTrace, context: 'boot:bootstrap');
      if (mounted) {
        _switchTo(MaterialApp(
          key: const ValueKey('boot-error'),
          debugShowCheckedModeBanner: false,
          home: BootErrorScreen(error: error),
        ));
      }
    });
  }

  void _switchTo(Widget next) {
    setState(() {
      _previousChild = _currentChild;
      _currentChild = next;
    });
    _fadeController.value = 0;
    _fadeController.forward().whenCompleteOrCancel(() {
      if (mounted) setState(() => _previousChild = null);
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // `BootGate` sits above `TranslationProvider`/`MaterialApp`, so there's
    // no `Directionality` ancestor yet — `Stack`'s default alignment
    // (`AlignmentDirectional.topStart`) needs one; `Alignment.topLeft`
    // doesn't, since it's not text-direction-relative.
    //
    // `StackFit.expand`, NOT the default `loose`: this Stack is the app's
    // root, and loose constraints silently break the font scale ABOVE 1.0.
    // UiScale's FittedBox needs tight constraints to scale up to — given
    // loose ones it just shrink-wraps its (smaller-than-window) child and
    // paints at natural size, so the UI reflows to the narrower logical
    // width without ever being magnified. Scaling DOWN kept working, which
    // is why this hid: an oversized child still gets clamped to the max.
    return Stack(
      alignment: Alignment.topLeft,
      fit: StackFit.expand,
      children: [
        ?_previousChild,
        FadeTransition(opacity: _fadeController, child: _currentChild),
      ],
    );
  }
}
