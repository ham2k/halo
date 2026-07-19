// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The REAL startup splash — the first Flutter frame, shown immediately on
// launch before `bootstrap()`'s async services are ready (see main.dart's
// `_BootGate`). NOT to be confused with the "version splash" modal
// (release_overlay.dart's photo/wordmark overlay: brand mark + credits +
// version, shown on release notes and from the About logo) — this one is
// deliberately minimal and carries NO version info. See docs/design/
// user-interface.md "Splash screens".
//
// It can't depend on SettingsService (theme mode, font scale) or anything else
// bootstrap produces. Background matches the empty-operations-list state it
// hands off to (surfaceContainerHighest) rather than a fixed color, so there's
// no visible color change if bootstrap() resolves straight into an empty list.
// Follows the system's light/dark setting (not the in-app override, which lives
// in SettingsService and isn't available yet) via PlatformDispatcher directly.
// Its logo, background, and centering mirror web/index.html's `#startup-splash`
// pixel-for-pixel so the HTML→Flutter handoff is a visual no-op.

import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'ham2k_logo.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // `buildHaLoTheme` only needs a Brightness, not SettingsService/theme
    // context, so it's safe to call before bootstrap() — same as
    // BootErrorScreen below. Reading the color from it directly (rather
    // than a hardcoded literal) means there's one fewer copy of it to keep
    // in sync with halo_widgets/theme.dart.
    final isDark = PlatformDispatcher.instance.platformBrightness == Brightness.dark;
    final theme = buildHaLoTheme(isDark ? Brightness.dark : Brightness.light);
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      // Mirror web/index.html's `#startup-splash` exactly: the per-edition Ham2K
      // square logo dead-centered, with the loading spinner's footprint reserved
      // below as an empty placeholder (Flutter is already painting, so there's
      // no spinner). The 64px above the logo balances that footprint — matching
      // the HTML's `img { margin-top: 64px }` — so the logo lands at the same
      // point in both. The logo art is the build edition's (Dev/Next/Regular);
      // no version info appears here. The web splash swaps to the matching
      // per-edition art via scripts/apply-web-edition.sh.
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 64),
            SvgPicture.asset(ham2kSquareLogoAsset, width: 180, height: 180),
            const SizedBox(height: 32), // the HTML spinner's margin-top
            const SizedBox(height: 32), // placeholder: the HTML spinner's height
          ],
        ),
      ),
    );
  }
}

/// Shown in place of the splash if `bootstrap()` fails — a boot failure
/// (DB open error, corrupted settings, etc.) must be visible, not leave the
/// user staring at the splash forever (see main.dart's `_BootGateState`).
class BootErrorScreen extends StatelessWidget {
  final Object error;

  const BootErrorScreen({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: buildHaLoTheme(Brightness.light).colorScheme.primary,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error, color: Colors.white, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Ham2K Logger failed to start',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '$error',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
