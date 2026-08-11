// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';

import 'resizable_split_view.dart';

/// A hairline along the top edge of a piece of bottom chrome — the status
/// footer, the numbers row — marking where the app stops and the chrome
/// begins.
///
/// The same idiom as the split divider's hairline, and the same numbers: a
/// black line on light surfaces, a white one on dark, where a single colour
/// would vanish into one of the two. Chrome sits on the app-bar colour, which
/// is dark in BOTH themes, so this is one of the few boundaries where the dark
/// side is the one that needs the stronger line.
///
/// Painted as a FOREGROUND decoration, so it costs no layout: both users
/// publish an exact height that the window's chrome budget spends before
/// dividing what is left ([StatusBarFooter.collapsedHeightOf],
/// [NumberKeys.heightOf]), and a border that insets its child would make each
/// of them a pixel taller than the number everything else is working from.
class ChromeTopEdge extends StatelessWidget {
  final Widget child;

  const ChromeTopEdge({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: (dark ? Colors.white : theme.colorScheme.shadow).withValues(
              alpha: dark ? ResizableSplitView.dividerShadowAlphaDark : ResizableSplitView.dividerShadowAlpha,
            ),
          ),
        ),
      ),
      child: child,
    );
  }
}
