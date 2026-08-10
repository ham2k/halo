// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
/// The Linux "implementation" of `flutter_inappwebview` — one that
/// deliberately implements nothing. See this package's pubspec for why it
/// exists and when to retire it.
library;

/// Registers no platform implementation, on purpose.
///
/// Flutter's generated Dart plugin registrant calls [registerWith] on every
/// endorsed implementation. Leaving `InAppWebViewPlatform.instance` unset is
/// the whole contract: Linux code paths must see the same absence they see
/// when no implementation is endorsed at all. Assigning an instance here —
/// even a throwing one — would make `InAppWebViewPlatform.instance` succeed
/// and move the failure from resolution time to first use.
class LinuxInAppWebViewPlatform {
  static void registerWith() {}
}
