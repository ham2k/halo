// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

/// There is no document off web. False, so every caller reads "the page does
/// not hold focus" and takes the do-nothing branch.
bool documentHasFocus() => false;
