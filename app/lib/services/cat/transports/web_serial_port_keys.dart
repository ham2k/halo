// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The one piece of serial_transport_web.dart with no JS interop in it —
// split out, like web_preview_label_parser.dart, so it can be unit tested
// under the plain VM test runner instead of needing a browser.

/// Web Serial exposes only a USB vendor/product pair per granted port — no
/// OS device path, no serial number, nothing else to key a port by. Given
/// each granted port's pair in enumeration order, returns the keys
/// `serial_transport_web.dart` assigns them: `vendorId:productId`, with a
/// `#n` suffix the second (and later) time an identical pair appears —
/// there is nothing more specific the browser will give a page to tell two
/// identical devices apart by.
List<String> assignWebSerialPortKeys(List<(int?, int?)> vendorProductPairs) {
  final keys = <String>[];
  final seenCounts = <String, int>{};
  for (final pair in vendorProductPairs) {
    final base = '${pair.$1 ?? 0}:${pair.$2 ?? 0}';
    final occurrence = seenCounts.update(base, (n) => n + 1, ifAbsent: () => 0);
    keys.add(occurrence == 0 ? base : '$base#${occurrence + 1}');
  }
  return keys;
}

/// The port picker's label for a granted device — hex VID:PID, since that
/// numeric pair is all Web Serial will say about it (no manufacturer or
/// product name string, unlike desktop's libserialport enumeration).
String? describeWebSerialUsbId(int? vendorId, int? productId) {
  if (vendorId == null || productId == null) return null;
  String hex(int value) => value.toRadixString(16).toUpperCase().padLeft(4, '0');
  return 'USB ${hex(vendorId)}:${hex(productId)}';
}
