// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Multicast DNS as the app uses it: the one-shot query it sends, the
// responses it reads, the race that resolves a `.local` host, and a SOTAcat
// found by its service record.
//
// No real multicast here: `flutter_tester` holds no Local Network grant on
// macOS, so a datagram to 224.0.0.251 never leaves the machine.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/discovery.dart';
import 'package:ham2k_logger/services/cat/equipment_models_other_radios.dart';
import 'package:ham2k_logger/services/cat/transports/mdns_codec.dart';
import 'package:ham2k_logger/services/cat/transports/mdns_io.dart' show firstLookupAnswer;

List<int> _name(String name) => [
  for (final label in name.split('.')) ...[label.length, ...utf8.encode(label)],
  0,
];

List<int> _u16(int value) => [value >> 8, value & 0xff];

List<int> _record(List<int> name, int type, List<int> data) => [...name, ..._u16(type), 0x80, 0x01, 0, 0, 0x11, 0x94, ..._u16(data.length), ...data];

/// A response the way an ESP-IDF responder shapes one to a one-shot PTR
/// query: the question echoed back, the PTR as the only answer, and SRV, TXT
/// and A in "additional" — with the SRV's target and the A's owner written
/// as a compression pointer back to one copy of the host name.
Uint8List _sotacatResponse({bool withSrv = true, bool withTxt = true}) {
  final bytes = <int>[];
  final additional = withSrv ? (withTxt ? 3 : 2) : 0;
  bytes.addAll([0, 0, 0x84, 0x00, ..._u16(1), ..._u16(1), ..._u16(0), ..._u16(additional)]);
  bytes.addAll([..._name('_sotacat._tcp.local'), ..._u16(mdnsTypePtr), 0x00, 0x01]);
  bytes.addAll(_record(_name('_sotacat._tcp.local'), mdnsTypePtr, _name('SOTAcat-AB6D._sotacat._tcp.local')));
  if (withSrv) {
    final hostOffset = bytes.length + _name('SOTAcat-AB6D._sotacat._tcp.local').length + 10 + 6;
    bytes.addAll(_record(_name('SOTAcat-AB6D._sotacat._tcp.local'), mdnsTypeSrv, [0, 0, 0, 0, ..._u16(4532), ..._name('sotacat.local')]));
    final txt = [
      for (final entry in ['id=3c84279a1b2c', 'FW=2.4.1', 'beta']) ...[entry.length, ...utf8.encode(entry)],
    ];
    if (withTxt) bytes.addAll(_record(_name('SOTAcat-AB6D._sotacat._tcp.local'), mdnsTypeTxt, txt));
    bytes.addAll(_record([0xc0 | (hostOffset >> 8), hostOffset & 0xff], mdnsTypeA, [192, 168, 4, 1]));
  }
  return Uint8List.fromList(bytes);
}

void main() {
  group('the one-shot query', () {
    test('asks for a unicast reply on every question', () {
      final packet = buildMdnsQuery([(name: 'SOTAcat.local.', type: mdnsTypeA)]);
      // Without QU (the top bit of the class) and an ephemeral source port, a
      // responder answers to the multicast group — which Android delivers
      // only under a Wi-Fi multicast lock the app does not hold.
      expect(packet.sublist(packet.length - 2), [0x80, 0x01]);
      // The name is lower-cased and loses its root dot: responders answer
      // in whatever case they like, and the reply is matched against this.
      expect(packet.sublist(12, packet.length - 4), _name('sotacat.local'));
      expect(packet.sublist(4, 6), [0, 1]);
    });

    test('only .local names are mDNS hosts', () {
      expect(isMdnsHost('sotacat.local'), isTrue);
      expect(isMdnsHost('SOTAcat.LOCAL.'), isTrue);
      expect(isMdnsHost('.local'), isFalse);
      expect(isMdnsHost('192.168.4.1'), isFalse);
      expect(isMdnsHost('rig.example.com'), isFalse);
      expect(isMdnsHost('notlocal'), isFalse);
    });
  });

  group('reading a response', () {
    test('finds the service from one round trip, through compression pointers', () {
      final records = parseMdnsResponse(_sotacatResponse());
      expect(records.firstWhere((r) => r.type == mdnsTypeA).name, 'sotacat.local');
      expect(records.firstWhere((r) => r.type == mdnsTypeA).address, '192.168.4.1');

      final services = mdnsServicesIn(records, '_sotacat._tcp.local');
      final found = services['sotacat-ab6d._sotacat._tcp.local']!;
      // Matched case-insensitively, shown as published.
      expect(found.instance, 'SOTAcat-AB6D');
      expect(found.host, 'sotacat.local');
      expect(found.port, 4532);
      // Keys are case-insensitive (RFC 6763 §6.4) and a bare key is present
      // with no value — a parser that splits naively drops or crashes on it.
      expect(found.txt, {'id': '3c84279a1b2c', 'fw': '2.4.1', 'beta': ''});
    });

    test('an instance answered without its SRV is asked about again, not dropped', () {
      final records = parseMdnsResponse(_sotacatResponse(withSrv: false));
      expect(mdnsServicesIn(records, '_sotacat._tcp.local'), isEmpty);
      expect(mdnsFollowUpQuestions(records, '_sotacat._tcp.local'), [
        (name: '_sotacat._tcp.local', type: mdnsTypePtr),
        (name: 'sotacat-ab6d._sotacat._tcp.local', type: mdnsTypeSrv),
        (name: 'sotacat-ab6d._sotacat._tcp.local', type: mdnsTypeTxt),
      ]);
    });

    test('an instance answered without its TXT waits for it, so its id never changes under it', () {
      // Offered now it would be keyed by instance name, and by its TXT `id`
      // once the TXT arrived — the dialog listing one SOTAcat twice.
      final records = parseMdnsResponse(_sotacatResponse(withTxt: false));
      expect(mdnsServicesIn(records, '_sotacat._tcp.local'), isEmpty);
      expect(mdnsFollowUpQuestions(records, '_sotacat._tcp.local'), [
        (name: '_sotacat._tcp.local', type: mdnsTypePtr),
        (name: 'sotacat-ab6d._sotacat._tcp.local', type: mdnsTypeTxt),
      ]);
    });

    test('another querier\'s question heard on the wire is not an answer', () {
      expect(parseMdnsResponse(buildMdnsQuery([(name: 'sotacat.local', type: mdnsTypeA)])), isEmpty);
    });

    test('a truncated or looping packet is noise, not a crash', () {
      final good = _sotacatResponse();
      expect(parseMdnsResponse(Uint8List.sublistView(good, 0, good.length - 3)), isEmpty);
      final selfPointer = Uint8List.fromList([0, 0, 0x84, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0xc0, 12, 0, 1, 0, 1, 0, 0, 0, 0, 0, 4, 1, 2, 3, 4]);
      expect(parseMdnsResponse(selfPointer), isEmpty);
      // Every pointer here points backwards, yet the walk never ends: label
      // `a`, then a pointer back to that label. Only the hop bound stops it.
      final backwardsLoop = Uint8List.fromList([0, 0, 0x84, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0x61, 0xc0, 12, 0, 1, 0, 1, 0, 0, 0, 0, 0, 4, 1, 2, 3, 4]);
      expect(parseMdnsResponse(backwardsLoop), isEmpty);
    });
  });

  group('resolving a .local host', () {
    final answer = InternetAddress('192.168.4.1');

    test('an mDNS answer after the OS resolver has already failed still wins', () async {
      // The Android case, and the one `Future.any` gets wrong: the OS fails
      // a .local name fast, and settling on that first outcome throws away
      // the answer that was on its way.
      final mdns = Completer<InternetAddress?>();
      final result = firstLookupAnswer(Future<InternetAddress>.error(const SocketException('Failed host lookup')), mdns.future, host: 'sotacat.local');
      await Future<void>.delayed(Duration.zero);
      mdns.complete(answer);
      expect(await result, answer);
    });

    test('the OS answer wins when mDNS finds nothing', () async {
      expect(await firstLookupAnswer(Future.value(answer), Future.value(null), host: 'sotacat.local'), answer);
    });

    test('the first answer wins without waiting on a slow loser', () async {
      final never = Completer<InternetAddress>();
      expect(await firstLookupAnswer(never.future, Future.value(answer), host: 'sotacat.local'), answer);
    });

    test('when neither answers, the failure is the OS resolver\'s own', () async {
      // The connect-failure classifier keys on SocketException; an error of
      // mDNS's own making would read as something other than "not found".
      final result = firstLookupAnswer(Future<InternetAddress>.error(const SocketException('Failed host lookup')), Future.value(null), host: 'sotacat.local');
      await expectLater(result, throwsA(isA<SocketException>().having((e) => e.message, 'message', 'Failed host lookup')));
    });
  });

  group('a SOTAcat found by its service record', () {
    Future<List<DiscoveredEquipment>> discover(List<MdnsService> services) {
      final discoverer = SotacatDiscoverer(typeKey: 'sotacat-tcp', browse: (_) => Stream.fromIterable(services));
      return discoverer.discover().toList();
    }

    test('is stored by host name, not by the address it answered from', () async {
      final found = await discover([
        const MdnsService(instance: 'SOTAcat-AB6D', host: 'sotacat.local', port: 4532, txt: {'id': '3c84279a1b2c', 'fw': '2.4.1'}),
      ]);
      final equipment = found.single;
      // An address stored now is wrong at the next activation, on the next
      // hotspot; the name resolves wherever the unit is.
      expect(equipment.config, {'host': 'sotacat.local', 'port': 4532});
      expect(equipment.id, '3c84279a1b2c');
      expect(equipment.name, 'SOTAcat-AB6D');
      expect(equipment.detail, 'v2.4.1 · sotacat.local');
    });

    test('without an id, is keyed by instance so re-answers update in place', () async {
      final found = await discover([
        const MdnsService(instance: 'SOTAcat-AB6D', host: 'sotacat.local', port: 4532, txt: {}),
        const MdnsService(instance: 'SOTAcat-AB6D', host: 'sotacat-2.local', port: 4532, txt: {}),
      ]);
      expect(found.map((e) => e.id).toSet(), {'SOTAcat-AB6D'});
      expect(found.first.detail, 'sotacat.local');
    });
  });
}
