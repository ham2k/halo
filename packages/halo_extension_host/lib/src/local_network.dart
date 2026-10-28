// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What "the local network" means to the host, for both of its network
// capabilities: the one place `host.webSocket` accepts plain `ws://` to, and
// the one place `host.fetch` never reaches on a wildcard grant.

/// Whether [host] (a `Uri.host`, so an IPv6 literal carries no brackets) is on
/// the device itself or the local network: loopback, RFC 1918, the shared
/// address space of carrier NAT and overlay networks (100.64/10, where a
/// tailnet's peers live), link-local, IPv6 unique-local, an IPv4 address seen
/// through IPv6 (`::ffff:a.b.c.d`), the unspecified addresses (`0.0.0.0` and
/// `::`, which reach the device itself as a destination), the blocks reserved
/// for local protocol use and benchmarking, and the `localhost` / mDNS
/// `.local` names.
///
/// A NAME is judged by its spelling, not by what it resolves to — resolving
/// it here would not bind the connection to that answer, and a browser offers
/// no resolver at all. Where the platform does bind one (fetch_client_io.dart)
/// the resolved address is judged again, by this same rule.
bool isLocalNetworkHost(String host) {
  final name = host.toLowerCase();
  if (name == 'localhost' || name.endsWith('.localhost') || name.endsWith('.local')) return true;
  bool v4(List<int> b) =>
      b[0] == 0 ||
      b[0] == 127 ||
      b[0] == 10 ||
      (b[0] == 100 && (b[1] & 0xc0) == 64) ||
      (b[0] == 172 && b[1] >= 16 && b[1] <= 31) ||
      (b[0] == 192 && (b[1] == 168 || (b[1] == 0 && b[2] == 0))) ||
      (b[0] == 198 && (b[1] & 0xfe) == 18) ||
      (b[0] == 169 && b[1] == 254);
  try {
    return v4(Uri.parseIPv4Address(name));
  } on FormatException {
    // Not an IPv4 literal.
  }
  try {
    // A link-local literal may carry a zone id — `fe80::1%en0`, or `%25en0`
    // after a trip through a URL — which no address parser reads.
    final zone = name.indexOf('%');
    final b = Uri.parseIPv6Address(zone < 0 ? name : name.substring(0, zone));
    final leadingZero = b.take(10).every((byte) => byte == 0);
    // `::ffff:a.b.c.d` IS the IPv4 address, spelled for an IPv6 socket; a
    // check on the v4 form alone would wave it through.
    if (leadingZero && b[10] == 0xff && b[11] == 0xff) return v4(b.sublist(12));
    // `::` and `::1`.
    if (leadingZero && b[10] == 0 && b[11] == 0 && b[12] == 0 && b[13] == 0 && b[14] == 0 && b[15] <= 1) return true;
    return (b[0] & 0xfe) == 0xfc || (b[0] == 0xfe && (b[1] & 0xc0) == 0x80);
  } on FormatException {
    return false;
  }
}
