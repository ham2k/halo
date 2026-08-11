// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

/// Raised when the bottom chrome cannot all be seated above the on-screen
/// keyboard and something had to give — the status footer first, then the
/// numbers row, and in the worst case a notice with less room than it needs to
/// be read (`BottomChromeBudget`).
///
/// An exception rather than a `debugPrint` because this is a disposition, and
/// dispositions are decided in ONE place (docs/design/error-reporting.md). Its
/// rule is `bottom-chrome-squeezed`, at `logOnly`: there is nothing the
/// operator can do about a window this short mid-contact, and a notice about
/// the notice not fitting would be its own joke. What it buys is a console
/// line, so "the numbers row doesn't work on my phone" has evidence behind it
/// rather than being unreproducible on anyone else's screen.
class BottomChromeSqueezed implements Exception {
  /// What gave way, already worded for the console.
  final String detail;

  const BottomChromeSqueezed(this.detail);

  @override
  String toString() => 'BottomChromeSqueezed: $detail';
}
