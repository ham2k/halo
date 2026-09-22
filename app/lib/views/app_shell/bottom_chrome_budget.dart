// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:math' as math;

import 'package:halo_widgets/halo_widgets.dart';

/// How much room each growable piece of the bottom chrome may take.
///
/// The bottom of the window is shared four ways: the notice stack and the
/// status footer can both grow, the numbers row is a fixed height whenever a
/// focused field publishes one, and the keyboard strip takes whatever the
/// keyboard is using. The app gets what is left — and must not be squeezed to
/// nothing, which is what happens when each of these sizes itself against the
/// whole window on its own and their sum quietly exceeds the strip they share.
///
/// So the sum is bounded here, once, rather than each piece guessing.
///
/// Two of the four pieces do not negotiate: the numbers row is a fixed
/// [NumberKeys.height] whenever a field publishes one, and the footer takes
/// [StatusBarFooter.collapsedHeight] whenever it has anything to say. Those
/// come off the top; what remains is split between the growable chrome and
/// the app, so the app keeps `1 - _chromeShare` of it no matter what.
///
/// "No matter what" only holds if every cap here is one the consumer cannot
/// exceed, so both are TOTALS — the whole stack including its band, the whole
/// expanded footer including its collapsed height. Handing
/// [NoticeStack] a cap for the card alone and paying for the band here lets
/// the stack overrun a tight budget by the whole band (measured at 3pt on a
/// 375pt landscape phone at Largest+ and 5pt at Largest++ with a 210pt
/// keyboard). Chrome a widget adds on its own account has to be that widget's
/// arithmetic.
///
/// Getting this wrong is not hypothetical, and it is not visible in portrait:
/// `UiScale` implements the Font Scale setting by dividing the window AND the
/// insets it hands down (docs/design/ui-scaling.md), while the fixed 52 and 28
/// above stay put. On a landscape phone with the keyboard up, that fixed 80
/// grows from 42% of the space above the keyboard at Normal to all of it at
/// Largest++ — which is how the sum can run past the window and drive the
/// app to zero height.
class BottomChromeBudget {
  /// The cap for the whole notice stack, its band included — the total, which
  /// is what [NoticeStack.maxHeight] means.
  final double noticeMax;

  /// The cap for the whole expanded footer, collapsed height included.
  final double footerMax;

  /// Whether the notice stack got at least the row it needs to be readable.
  ///
  /// False only where the window cannot seat one at all — every other piece
  /// has already yielded by then. The notice is not dropped in that case (it
  /// is where ErrorPolicy puts what the operator must read, so a missing one
  /// is worse than a cramped one); it is reported instead, because an error
  /// raised into a box too small to read is an error nobody was told.
  final bool seatsNotice;

  /// Whether the footer is drawn at all, and whether the numbers row is.
  ///
  /// False where the band cannot fit above the keyboard however the growable
  /// pieces are capped: the field being typed into and the keyboard itself
  /// already take the window between them. Something has to give, and these
  /// two give in this order — status first, then the row — because both come
  /// straight back when the keyboard goes away, and the field does not.
  final bool showFooter;
  final bool showNumbersRow;

  const BottomChromeBudget({required this.noticeMax, required this.footerMax, this.showFooter = true, this.showNumbersRow = true, this.seatsNotice = true});

  /// The most of the negotiable space the growable chrome may take between
  /// them, so the app always keeps the rest.
  static const double _chromeShare = 0.6;

  /// How that share splits. The notice carries prose and wants the larger part;
  /// the footer's rows are short and it scrolls past its cap anyway. The
  /// footer's part stays reserved while it is collapsed — it can be expanded
  /// by a tap at any time, and a budget that only holds until the user touches
  /// something is not a budget.
  static const double _noticeShare = 0.7;

  /// [numbersRowHeight] and [footerHeight] are passed in rather than read
  /// from the widgets: both are density-resolved now, and this is a plain
  /// factory with no context. Passing them also keeps the arithmetic
  /// testable against any pair of values, which is what the device matrix in
  /// status_bar_keyboard_test does.
  factory BottomChromeBudget.of({
    required double windowHeight,
    required double keyboardInset,
    required bool hasNumbersRow,
    required bool hasStatusItems,
    required double numbersRowHeight,
    required double footerHeight,
    double homeChromeHeight = 0,
    double noticeFloor = 0,
  }) {
    // Only what is actually on screen is charged: the footer collapses to
    // nothing when the caller says it has no band to draw (over a keyboard,
    // with nothing to say), exactly as the row is absent without a spec.
    // [homeChromeHeight] is what the home layer needs for chrome of its OWN —
    // Quick Lookup, which Home draws inside itself — and zero when a view that
    // owns the window has replaced it. It is not part of this band, but it
    // comes out of the same window: a budget blind to it hands the notice and
    // the footer room Home has already spent, and Home overflows rather than
    // the band.
    // What is left once the one piece that cannot yield has taken its share:
    // Quick Lookup is the field the keyboard is up FOR, and dropping it would
    // take away what the operator is typing into.
    final unyielding = windowHeight - keyboardInset - homeChromeHeight;
    // Then status, then the row — dropped rather than overflowing the window,
    // and only with the keyboard up. With it down there is always room, and
    // chrome that came and went on a desktop window would be a flicker with no
    // cause the operator can see. Reachable on a landscape phone at a large
    // Font Scale, where `UiScale` divides the window while the row's and the
    // field's tap-target floors stay put (docs/design/ui-scaling.md): at 1.90
    // the field, its row and the keyboard alone want 16pt more than the window
    // has.
    final tight = keyboardInset > 0;
    final wantedRow = hasNumbersRow ? numbersRowHeight : 0.0;
    final showFooter = !tight || unyielding - wantedRow >= footerHeight;
    final showNumbersRow = !tight || unyielding >= wantedRow;
    final row = showNumbersRow ? wantedRow : 0.0;
    final collapsedFooter = hasStatusItems && showFooter ? footerHeight : 0.0;
    final negotiable = math.max(0.0, unyielding - row - collapsedFooter);
    final chrome = negotiable * _chromeShare;
    // The notice takes its share, or [noticeFloor] — one readable row —
    // whichever is larger. The difference comes out of the FOOTER's share and
    // never out of the app's: the whole point of [_chromeShare] is that the
    // app keeps the rest no matter what, and a floor that borrowed past it
    // would drive the app toward zero to seat a notice, which is the failure
    // this class exists to prevent. Between the two of them the footer is the
    // one that can give — it scrolls past its cap, and its rows are short.
    final noticeMax = math.min(chrome, math.max(chrome * _noticeShare, noticeFloor));
    final footerMax = collapsedFooter + math.max(0.0, chrome - noticeMax);
    return BottomChromeBudget(
      noticeMax: noticeMax,
      footerMax: footerMax,
      showFooter: showFooter,
      showNumbersRow: showNumbersRow,
      seatsNotice: noticeMax >= noticeFloor,
    );
  }
}
