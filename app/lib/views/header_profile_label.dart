// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';

import '../services/settings_service.dart';

/// The active profile's operator callsign, shown at the right edge of a
/// window-top header (the home screen and Settings). Rebuilds when the
/// callsign/profile changes, and renders nothing while no callsign is set
/// (e.g. onboarding was skipped). Rendered in the app's monospace callsign
/// face, tinted to read on the header background.
class HeaderProfileLabel extends StatelessWidget {
  final SettingsService settings;

  const HeaderProfileLabel({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final call = settings.activeProfile.operatorCall;
        if (call.isEmpty) return const SizedBox.shrink();
        final theme = Theme.of(context);
        // AppBar actions are already vertically centered by their Row, so a
        // padded Text is all that's needed here.
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            call,
            style: TextStyle(
              fontFamily: 'RobotoMono',
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: theme.appBarTheme.foregroundColor ?? theme.colorScheme.onPrimary,
            ),
          ),
        );
      },
    );
  }
}
