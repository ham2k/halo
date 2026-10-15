// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The few Multicast DNS (RFC 6762) packets the app sends and reads: one-shot
// queries for an address or a service, and the records that answer them.
// Pure bytes, no sockets — the I/O is mdns_io.dart.
//
// Only what a one-shot querier needs. No probing, no announcing, no known-
// answer suppression: the app never claims a name, and it never holds a
// cache long enough for suppression to matter.

import 'dart:convert';
import 'dart:typed_data';

const mdnsGroup = '224.0.0.251';
const mdnsPort = 5353;

const mdnsTypeA = 1;
const mdnsTypePtr = 12;
const mdnsTypeTxt = 16;
const mdnsTypeSrv = 33;

/// Whether [host] is a name only Multicast DNS answers for (RFC 6762 §3).
bool isMdnsHost(String host) {
  final name = normalizeMdnsName(host);
  return name.endsWith('.local') && name.length > '.local'.length;
}

/// Names compare case-insensitively and with or without the root dot, and
/// a responder is free to answer in either form.
String normalizeMdnsName(String name) {
  final lower = name.toLowerCase();
  return lower.endsWith('.') ? lower.substring(0, lower.length - 1) : lower;
}

/// One resource record from a response. Only the fields its [type] carries
/// are set: [address] on A, [target] on PTR and SRV, [port] on SRV, [txt]
/// on TXT.
///
/// [name] is normalized for matching; [target] keeps the case it was
/// published in, since a PTR's target is the instance name the operator
/// sees.
class MdnsRecord {
  final String name;
  final int type;
  final String? address;
  final String? target;
  final int? port;
  final Map<String, String>? txt;

  const MdnsRecord({required this.name, required this.type, this.address, this.target, this.port, this.txt});

  @override
  String toString() => 'MdnsRecord($name type=$type ${address ?? target ?? txt ?? ''}${port == null ? '' : ':$port'})';
}

/// A query asking each of [questions] at once, as IN-class with the
/// unicast-response bit set.
///
/// Sent from an ephemeral port this is a one-shot query (§5.1): the
/// responder replies by unicast to that port, so the querier needs neither
/// port 5353 — which the OS's own responder already holds on macOS and
/// Windows — nor a multicast membership, which Android only grants under a
/// Wi-Fi multicast lock. The QU bit asks for the same thing explicitly, for
/// a responder that keys on it rather than on the source port.
Uint8List buildMdnsQuery(List<({String name, int type})> questions) {
  final bytes = BytesBuilder();
  bytes.add([0, 0, 0, 0, questions.length >> 8, questions.length & 0xff, 0, 0, 0, 0, 0, 0]);
  for (final question in questions) {
    for (final label in normalizeMdnsName(question.name).split('.')) {
      final encoded = utf8.encode(label);
      bytes.addByte(encoded.length);
      bytes.add(encoded);
    }
    bytes.add([0, question.type >> 8, question.type & 0xff, 0x80, 0x01]);
  }
  return bytes.toBytes();
}

/// Every A, PTR, SRV and TXT record in a response's answer, authority and
/// additional sections — a responder puts the SRV, TXT and address of a
/// service it answers for in "additional", and those are the records that
/// make one round trip enough.
///
/// Empty for a query (another querier's, heard on the same port), and for a
/// packet that does not parse: a malformed datagram from some device on the
/// LAN is noise, not an error worth surfacing.
List<MdnsRecord> parseMdnsResponse(Uint8List packet) {
  try {
    return _parse(packet);
  } on RangeError {
    return const [];
  } on FormatException {
    return const [];
  }
}

List<MdnsRecord> _parse(Uint8List packet) {
  final data = ByteData.sublistView(packet);
  if ((data.getUint16(2) & 0x8000) == 0) return const [];
  final questions = data.getUint16(4);
  final records = data.getUint16(6) + data.getUint16(8) + data.getUint16(10);

  var offset = 12;
  for (var i = 0; i < questions; i++) {
    offset = _readName(packet, offset).end + 4;
  }

  final found = <MdnsRecord>[];
  for (var i = 0; i < records; i++) {
    final name = _readName(packet, offset);
    offset = name.end;
    final type = data.getUint16(offset);
    final length = data.getUint16(offset + 8);
    final start = offset + 10;
    final end = start + length;
    if (end > packet.length) throw RangeError('record overruns packet');
    switch (type) {
      case mdnsTypeA when length == 4:
        found.add(MdnsRecord(name: normalizeMdnsName(name.value), type: type, address: packet.sublist(start, end).join('.')));
      case mdnsTypePtr:
        found.add(MdnsRecord(name: normalizeMdnsName(name.value), type: type, target: _readName(packet, start).value));
      case mdnsTypeSrv:
        found.add(MdnsRecord(name: normalizeMdnsName(name.value), type: type, port: data.getUint16(start + 4), target: _readName(packet, start + 6).value));
      case mdnsTypeTxt:
        found.add(MdnsRecord(name: normalizeMdnsName(name.value), type: type, txt: _readTxt(packet, start, end)));
    }
    offset = end;
  }
  return found;
}

/// A name at [offset], following compression pointers (RFC 1035 §4.1.4).
/// [end] is where the name's bytes stop in place, not where a pointer led.
({String value, int end}) _readName(Uint8List packet, int offset) {
  final labels = <String>[];
  int? end;
  var position = offset;
  // The hop bound is what guarantees an end: a loop can run backwards
  // through earlier labels to the same pointer again. A forward pointer is
  // malformed outright (RFC 1035 points at a PRIOR occurrence), and is
  // rejected without walking it.
  for (var hops = 0; hops <= packet.length; hops++) {
    final length = packet[position];
    if (length == 0) {
      return (value: labels.join('.'), end: end ?? position + 1);
    }
    if (length & 0xc0 == 0xc0) {
      end ??= position + 2;
      final pointer = ((length & 0x3f) << 8) | packet[position + 1];
      if (pointer >= position) throw const FormatException('forward compression pointer');
      position = pointer;
      continue;
    }
    labels.add(utf8.decode(packet.sublist(position + 1, position + 1 + length), allowMalformed: true));
    position += 1 + length;
  }
  throw const FormatException('compression loop');
}

/// TXT strings as `key=value` pairs (RFC 6763 §6). A bare key reads as an
/// empty value, and keys are case-insensitive.
Map<String, String> _readTxt(Uint8List packet, int start, int end) {
  final txt = <String, String>{};
  var position = start;
  while (position < end) {
    final length = packet[position];
    final entry = utf8.decode(packet.sublist(position + 1, position + 1 + length), allowMalformed: true);
    position += 1 + length;
    if (entry.isEmpty) continue;
    final split = entry.indexOf('=');
    final key = (split < 0 ? entry : entry.substring(0, split)).toLowerCase();
    txt.putIfAbsent(key, () => split < 0 ? '' : entry.substring(split + 1));
  }
  return txt;
}

/// A service instance put together from the records gathered so far.
class MdnsService {
  /// The instance's own label — `SOTAcat-1234` in
  /// `SOTAcat-1234._sotacat._tcp.local` — which is the name it shows as.
  final String instance;
  final String host;
  final int port;
  final Map<String, String> txt;

  const MdnsService({required this.instance, required this.host, required this.port, required this.txt});
}

/// What [records] say about instances of [serviceType]
/// (`_sotacat._tcp.local`), keyed by full instance name.
///
/// An instance is left out until both its SRV and its TXT are in: without
/// the SRV its port is unknown, and offering it before the TXT would key it
/// by instance name now and by its TXT `id` a moment later — two rows for
/// one unit. Every DNS-SD service has a TXT, even an empty one (RFC 6763
/// §6), so waiting for it never hides a service. [mdnsFollowUpQuestions]
/// asks for whichever is missing.
Map<String, MdnsService> mdnsServicesIn(Iterable<MdnsRecord> records, String serviceType) {
  final type = normalizeMdnsName(serviceType);
  final srv = <String, MdnsRecord>{};
  final txt = <String, Map<String, String>>{};
  final instances = <String, String>{};
  for (final record in records) {
    switch (record.type) {
      case mdnsTypePtr when record.name == type:
        instances[normalizeMdnsName(record.target!)] = record.target!;
      case mdnsTypeSrv:
        srv[record.name] = record;
      case mdnsTypeTxt:
        txt[record.name] = record.txt!;
    }
  }

  return {
    for (final MapEntry(key: name, value: published) in instances.entries)
      if ((srv[name], txt[name]) case (final record?, final values?))
        name: MdnsService(
          instance: name.endsWith('.$type') ? published.substring(0, published.length - type.length - 1) : published,
          host: normalizeMdnsName(record.target!),
          port: record.port!,
          txt: values,
        ),
  };
}

/// The questions a browse for [serviceType] asks: the PTR every time, plus
/// the SRV or TXT of any instance whose responder answered the PTR without
/// it. A responder is allowed to (the additional section is a courtesy),
/// and without the follow-up such an instance would never be offered.
List<({String name, int type})> mdnsFollowUpQuestions(Iterable<MdnsRecord> records, String serviceType) {
  final type = normalizeMdnsName(serviceType);
  final known = {for (final record in records) (record.name, record.type)};
  final instances = {
    for (final record in records)
      if (record.type == mdnsTypePtr && record.name == type) normalizeMdnsName(record.target!),
  };
  return [
    (name: type, type: mdnsTypePtr),
    for (final name in instances)
      for (final wanted in const [mdnsTypeSrv, mdnsTypeTxt])
        if (!known.contains((name, wanted))) (name: name, type: wanted),
  ];
}
