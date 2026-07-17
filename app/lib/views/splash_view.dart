// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Shown immediately on launch, before `bootstrap()`'s async services are
// ready (see main.dart's `_BootGate`) — so it can't depend on SettingsService
// (theme mode, font scale) or anything else bootstrap produces. Background
// matches the empty-operations-list state it hands off to (surfaceContainer-
// Highest) rather than a fixed color, so there's no visible color change if
// bootstrap() resolves straight into an empty list. Follows the system's
// light/dark setting (not the in-app override, which lives in
// SettingsService and isn't available yet) via PlatformDispatcher directly.
// Also matches web/index.html's `#startup-splash`, which follows
// `prefers-color-scheme` for the same reason.

import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:halo_widgets/halo_widgets.dart';

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
    return ColoredBox(
      color: buildHaLoTheme(isDark ? Brightness.dark : Brightness.light).colorScheme.surfaceContainerHighest,
      child: Center(
        child: SizedBox(
          width: 180,
          height: 180,
          child: SvgPicture.asset('assets/images/ham2k-wordmark.svg'),
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
              const Icon(Icons.error_outline, color: Colors.white, size: 48),
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
