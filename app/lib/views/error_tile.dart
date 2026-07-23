// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Replacement for Flutter's built-in ErrorWidget (the release-mode grey box /
// debug red screen): a compact tile shown in place of the one widget whose
// build threw, so a bad cell in a panel doesn't take the session down with it
// (#76). Installed globally by ErrorReportingService._installLocalHooks().
//
// Built from primitives only (no Material/Theme lookups): this renders at
// arbitrary — possibly broken — points in the tree, where Theme.of or
// Directionality may be unavailable, so everything it needs is local.
// Colors are fixed mid-tones that read on both light and dark surfaces.

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class HaLoErrorTile extends StatelessWidget {
  final FlutterErrorDetails details;

  const HaLoErrorTile({super.key, required this.details});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0x14B3261E),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0x66B3261E)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '⚠︎ Something went wrong here',
              style: TextStyle(color: Color(0xFFB3261E), fontSize: 12, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
            // The exception itself is only useful (and only safe to show)
            // during development; release users get the neutral label plus
            // the StatusBar notice's "Copy details" for support.
            if (kDebugMode)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  details.exceptionAsString(),
                  style: const TextStyle(color: Color(0xFFB3261E), fontSize: 10),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
