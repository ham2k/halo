// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// NMEA 0183, the text every USB and serial GPS receiver speaks: one
// `$<talker><type>,<fields>*<checksum>` sentence per line. Only the two
// sentences that carry a position are read — GGA and RMC — and only the
// fields of them a location needs (docs/design/cat.md § GPS receivers).
//
// Pure: strings in, readings out, no sockets and no timers.

import '../equipment.dart' show GpsReading;

/// One well-formed sentence: its [type] (`GGA`, `RMC`, `GSV`…) and, for the
/// two that carry a position, what it said — a [GpsReading] with no
/// coordinate while the receiver has no fix, which it reports every second
/// until it has one. Null [reading] for every other type.
typedef NmeaSentence = ({String type, GpsReading? reading});

/// [line] as an NMEA sentence, or null when it is not one: no `$`, or a
/// checksum missing or wrong. Every sentence it does return is the receiver
/// talking, the ones without a position included — a receiver without a fix
/// still fills its second with GSV and GSA.
///
/// Any talker: `GP` (GPS), `GN` (combined), `GL`, `GA`, `BD`/`GB` — a
/// multi-constellation receiver like the u-blox 7 reports its combined fix as
/// `GN`, and a reader that matched `GP` alone would see no position from it.
///
/// The checksum must be there and match: a byte dropped on the wire turns
/// `4124.8963` into `412.8963` and the station into the sea. The standard
/// lets a sentence leave it out, but every receiver sends it with GGA, RMC
/// and GSV, and a device on the wrong port printing `$`-led lines of its own
/// must not pass for a receiver.
NmeaSentence? parseNmea(String line) {
  final body = _checkedBody(line.trim());
  if (body == null) return null;
  final fields = body.split(',');
  final address = fields.first;
  final type = address.length == 5 ? address.substring(2) : address;
  return (
    type: type,
    reading: switch (type) {
      'GGA' => _gga(fields),
      'RMC' => _rmc(fields),
      _ => null,
    },
  );
}

/// The sentence between `$` and `*`, or null when [line] is not one or its
/// checksum does not match.
String? _checkedBody(String line) {
  if (!line.startsWith(r'$')) return null;
  final star = line.lastIndexOf('*');
  if (star < 0) return null;
  final body = line.substring(1, star);
  final stated = int.tryParse(line.substring(star + 1), radix: 16);
  if (stated == null) return null;
  var sum = 0;
  for (final unit in body.codeUnits) {
    sum ^= unit;
  }
  return sum == stated ? body : null;
}

/// `$--GGA,time,lat,N/S,lon,E/W,quality,sats,hdop,alt,M,…`. Quality 0 is no
/// fix; any other value (GPS, DGPS, RTK, dead reckoning…) is a position.
///
/// A fix whose position does not read is no reading at all, rather than one
/// with no fix: reported as "searching", it would send the operator
/// outdoors to wait for a fix the receiver already has.
GpsReading? _gga(List<String> f) {
  if (f.length < 10) return null;
  final quality = int.tryParse(f[6]);
  if (quality == null) return null;
  final satellites = int.tryParse(f[7]);
  final hdop = double.tryParse(f[8]);
  final altitude = double.tryParse(f[9]);
  final position = quality == 0 ? null : _position(f[2], f[3], f[4], f[5]);
  if (quality != 0 && position == null) return null;
  return GpsReading(latitude: position?.$1, longitude: position?.$2, hdop: hdop, satellites: satellites, altitude: altitude);
}

/// `$--RMC,time,status,lat,N/S,lon,E/W,…`. Status `A` is a fix; `V` is the
/// receiver saying the position fields are not to be trusted, which some
/// fill with the last fix they had.
GpsReading? _rmc(List<String> f) {
  if (f.length < 7) return null;
  final valid = f[2] == 'A';
  final position = valid ? _position(f[3], f[4], f[5], f[6]) : null;
  // As GGA's: a fix that does not read is dropped, not reported as none.
  if (valid && position == null) return null;
  return GpsReading(latitude: position?.$1, longitude: position?.$2);
}

/// NMEA's `ddmm.mmmm,N` and `dddmm.mmmm,E` as signed decimal degrees, or
/// null when either half is blank or malformed — a receiver mid-search
/// leaves them empty.
(double, double)? _position(String lat, String ns, String lon, String ew) {
  final latitude = _degrees(lat, 2, ns, 'N', 'S');
  final longitude = _degrees(lon, 3, ew, 'E', 'W');
  if (latitude == null || longitude == null) return null;
  if (latitude.abs() > 90 || longitude.abs() > 180) return null;
  return (latitude, longitude);
}

double? _degrees(String value, int degreeDigits, String hemisphere, String positive, String negative) {
  if (value.length <= degreeDigits || (hemisphere != positive && hemisphere != negative)) return null;
  final degrees = int.tryParse(value.substring(0, degreeDigits));
  final minutes = double.tryParse(value.substring(degreeDigits));
  if (degrees == null || minutes == null || minutes >= 60) return null;
  final decimal = degrees + minutes / 60;
  return hemisphere == negative ? -decimal : decimal;
}
