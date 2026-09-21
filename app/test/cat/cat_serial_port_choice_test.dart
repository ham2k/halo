// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A radio that knows which of its bridge's ports carries CAT picks it for
// the operator, where the platform can tell the ports apart.
//
// Choosing wrong looks exactly like a dead cable: the port opens, the
// commands go out, nothing answers. The X6100's CI-V is on the second of
// its two ports; a Yaesu's is on the first of its CP2105's. Offering both
// and a note is what the operator gets on desktop, where the OS named the
// ports and nothing here knows they are siblings — so the restriction must
// only ever act on ports this transport itself split.

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/drivers/ft891_driver.dart';
import 'package:ham2k_logger/services/cat/equipment_brands.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/cat/transport.dart';
import 'package:ham2k_logger/services/cat/transports/serial_port_sightings.dart';
import 'package:ham2k_logger/services/cat/transports/serial_transport.dart';

class _Ports extends EquipmentTransport with SerialTransportConfig {
  @override
  List<SerialPortOption> availablePorts;

  _Ports(this.availablePorts);

  @override
  String get key => 'serial';

  @override
  Future<EquipmentConnection> connect(Map<String, dynamic> target, {required CatCancelToken cancel}) =>
      throw UnimplementedError();
}

/// An Android device split into [count] ports, the way serial_transport_io
/// builds them.
List<SerialPortOption> split(String device, int count, {int? vendorId, String? productName}) => [
      for (var i = 0; i < count; i++)
        SerialPortOption(name: '$device#$i', productName: productName, vendorId: vendorId, portIndex: i, portCount: count),
    ];

void main() {
  const x6100 = '/dev/bus/usb/001/004';
  const cp2105 = '/dev/bus/usb/001/007';
  const ft2232 = '/dev/bus/usb/001/009';
  final ports = _Ports([
    const SerialPortOption(name: '/dev/bus/usb/001/002', productName: 'CP2102', vendorId: 0x10C4),
    ...split(x6100, 2, productName: 'X6100'),
    ...split(cp2105, 2, vendorId: 0x10C4, productName: 'CP2105'),
    ...split(ft2232, 2, vendorId: 0x0403, productName: 'FT2232'),
  ]);

  List<String> names(Object? restriction) => [for (final c in ports.portChoices(restriction)) c.name];

  test('with no restriction every port is offered, split ones saying which they are', () {
    // Alphabetical by what the operator READS, which now leads with the
    // hardware rather than the device node — so the CP2102 comes before the
    // X6100 whatever order the OS enumerated them in.
    expect(names(null), ['/dev/bus/usb/001/002', '$cp2105#0', '$cp2105#1', '$ft2232#0', '$ft2232#1', '$x6100#0', '$x6100#1']);
    expect(ports.portChoices(null).last.label, contains('port 2 of 2'));
    // The device node trails in parentheses, with no `/dev/`.
    expect(ports.portChoices(null).first.label, 'CP2102 (bus/usb/001/002)');
  });

  test('an index points at that port of every split device WITHOUT hiding its siblings', () {
    // The X6100's rule: CI-V on the second port, whatever the bridge. It is
    // a claim about where CAT usually is, not about where it may be — both
    // ports of an IC-705 leave the factory set to CI-V and either can be
    // switched, so an operator who moved it must still be able to pick the
    // other one. Every port stays; the claimed ones lead.
    final choices = ports.portChoices({'index': 1});
    expect([for (final c in choices) c.name],
        ['$cp2105#1', '$ft2232#1', '$x6100#1', '/dev/bus/usb/001/002', '$cp2105#0', '$ft2232#0', '$x6100#0']);
    expect([for (final c in choices) if (c.suggested) c.name], ['$cp2105#1', '$ft2232#1', '$x6100#1']);
    // The ordinal STAYS, unlike when this rule hid the sibling: with both on
    // screen under one description, "port 2 of 2" is the only thing telling
    // the operator which row they are looking at.
    expect(choices.first.label, contains('port 2 of 2'));
  });

  test('a vendor id confines the claim to that maker, so another adapter is pointed at nothing', () {
    // A Yaesu reached through its own CP2105 gets the Enhanced port marked;
    // the same radio on an FTDI cable is somebody else's wiring, and a
    // confident guess about hardware this definition has never seen is worse
    // than no guess. Every port is still listed either way.
    final choices = ports.portChoices(Ft891Driver.cp2105CatPort);
    expect([for (final c in choices) if (c.suggested) c.name], ['$cp2105#0']);
    expect([for (final c in choices) c.name], hasLength(7));
  });

  test('an index the device does not have points at nothing rather than at the wrong port', () {
    // Either side of the range: a too-large index matches no port, and a
    // negative one would match none while claiming every device.
    for (final restriction in [
      {'index': 3},
      {'index': -1},
    ]) {
      expect(names(restriction), names(null), reason: '$restriction');
      expect([for (final c in ports.portChoices(restriction)) if (c.suggested) c.name], isEmpty,
          reason: '$restriction');
    }
  });

  test('a restriction that is not a map, or an index that is not a number, claims nothing', () {
    for (final restriction in ['second', {'index': '1'}]) {
      expect(names(restriction), names(null), reason: '$restriction');
      expect([for (final c in ports.portChoices(restriction)) if (c.suggested) c.name], isEmpty,
          reason: '$restriction');
    }
  });

  test('the port field the editor renders is built from these choices, not the raw port list', () {
    // The seam: with this line reverted to `availablePorts`, every test
    // above still passes and no radio ever points at its port.
    final field = ports.configElements(restrictions: {
      'port': {'index': 1},
    }).firstWhere((e) => e['key'] == 'port');
    final options = (field['options'] as List).cast<Map<String, dynamic>>();
    expect([for (final o in options) o['value']],
        ['$cp2105#1', '$ft2232#1', '$x6100#1', '/dev/bus/usb/001/002', '$cp2105#0', '$ft2232#0', '$x6100#0']);
    // And the claim survives into the form as emphasis, or the row leads the
    // list looking exactly like the six below it.
    expect(options.first['emphasis'], isTrue);
  });

  group('a radio that names its bridge gets it offered first, in bold, and tagged', () {
    setUp(SerialPortSightings.resetForTest);

    const suggest = {
      'suggest': {
        'usb': [
          {'vendorId': 0x10C4, 'productId': 0xEA70},
        ],
        'match': [r'CP2105'],
      },
    };

    test('a USB pair the catalogue names marks that port and no other', () {
      final choices = ports.portChoices(suggest);
      // First, whatever order the OS enumerated them in — and the CP2105's
      // sibling (same chip, same ids) is suggested too: the index clause is
      // what tells those two apart, and this list declares none.
      expect(choices.first.suggested, isTrue);
      expect([for (final c in choices) if (c.suggested) c.name], ['$cp2105#0', '$cp2105#1']);
      // The tags are their own column now, not part of the name.
      expect(choices.first.pickerTags, contains('suggested'));
    });

    test('the pattern matches the label, which is what carries macOS', () {
      // No vendor id at all, the way libserialport answers on macOS — where
      // the description DOES read back, so the regexp is the clause that
      // bites and the USB pair matches nothing.
      final macos = _Ports([
        const SerialPortOption(name: '/dev/cu.usbserial-A1', description: 'CP2105 Dual USB to UART'),
        const SerialPortOption(name: '/dev/cu.usbserial-B2', description: 'FT232R USB UART'),
      ]);
      final choices = macos.portChoices(suggest);
      expect(choices.first.name, '/dev/cu.usbserial-A1');
      expect(choices.first.suggested, isTrue);
      expect(choices.last.suggested, isFalse);
    });

    test('a malformed suggest clause suggests nothing rather than throwing', () {
      // Catalogue data renders this picker; a bad pattern must not take the
      // equipment editor down with it.
      for (final broken in [
        {'suggest': 'CP2105'},
        {'suggest': {'match': [r'CP2105(']}},
        {'suggest': {'match': [42]}},
        {'suggest': {'usb': ['10C4']}},
      ]) {
        expect([for (final c in ports.portChoices(broken)) if (c.suggested) c.name], isEmpty, reason: '$broken');
      }
    });

    test('the option the form renders carries the emphasis the bold comes from', () {
      // The seam: without this, the label says [suggested] in plain text and
      // the picker looks the same as before.
      final field = ports.configElements(restrictions: {'port': suggest}).firstWhere((e) => e['key'] == 'port');
      final options = (field['options'] as List).cast<Map<String, dynamic>>();
      expect(options.first['emphasis'], isTrue);
      expect(options.last.containsKey('emphasis'), isFalse);
    });
  });

  group('a port that has just appeared says so', () {
    setUp(SerialPortSightings.resetForTest);

    test('a port present at the first look is never new, however recently the app looked', () {
      // App start stamps every port at once. Marking them all says nothing,
      // and would put a sparkle on a cable that has been plugged in for a
      // week. Suppressing them by the clock instead would ALSO silence the
      // five minutes after launch, which is when a cable really does get
      // plugged in — so the baseline, not the window, is what does it.
      expect([for (final c in ports.portChoices(null)) c.justNow], everyElement(isFalse));

      SerialPortSightings.resetForTest();
      final live = _Ports([const SerialPortOption(name: 'COM3')]);
      live.portChoices(null);
      live.availablePorts = [const SerialPortOption(name: 'COM3'), const SerialPortOption(name: 'COM9')];
      expect(live.portChoices(null).first.justNow, isTrue);
    });

    test('a port that appears after the first look is marked and sorts to the top', () {
      SerialPortSightings.resetForTest();
      final live = _Ports([
        const SerialPortOption(name: 'COM3'),
        const SerialPortOption(name: 'COM4'),
      ]);
      live.portChoices(null);
      live.availablePorts = [
        const SerialPortOption(name: 'COM3'),
        const SerialPortOption(name: 'COM4'),
        const SerialPortOption(name: 'COM9'),
      ];
      final choices = live.portChoices(null);
      expect(choices.first.name, 'COM9');
      expect(choices.first.justNow, isTrue);
      // The sparkle became a glyph in its own column, so the name is just
      // the name again.
      expect(choices.first.pickerIcon, 'new-box');
      // Not a pill: a port that was not there a moment ago is this row's own
      // news, said in a sentence under the name.
      expect(choices.first.pickerSubtitle, 'Recently connected');
      expect(choices.first.pickerTags, isNot(contains('just now')));
      expect([for (final c in choices.skip(1)) c.justNow], everyElement(isFalse));
    });

    test('a port unplugged and plugged back in reads as new again', () {
      // The sighting is FORGOTTEN when the port goes, rather than aged out:
      // a remembered stamp would bring the port back silently, which is the
      // moment the operator most wants pointed at.
      SerialPortSightings.resetForTest();
      final live = _Ports([
        const SerialPortOption(name: 'COM3'),
        const SerialPortOption(name: 'COM4'),
      ]);
      live.portChoices(null);
      live.availablePorts = [const SerialPortOption(name: 'COM3')];
      live.portChoices(null);
      live.availablePorts = [
        const SerialPortOption(name: 'COM3'),
        const SerialPortOption(name: 'COM4'),
      ];
      final choices = live.portChoices(null);
      expect(choices.first.name, 'COM4');
      expect(choices.first.justNow, isTrue);
    });

    test('a suggested port outranks a new one, and a port that is both says both', () {
      SerialPortSightings.resetForTest();
      final live = _Ports([const SerialPortOption(name: 'COM3', description: 'CP2105')]);
      live.portChoices(null);
      live.availablePorts = [
        const SerialPortOption(name: 'COM3', description: 'CP2105'),
        const SerialPortOption(name: 'COM9', description: 'FT232R'),
      ];
      const suggest = {
        'suggest': {'match': [r'CP2105']},
      };
      final choices = live.portChoices(suggest);
      // What the radio's own definition knows beats what was plugged in last.
      expect(choices.first.name, 'COM3');
      expect(choices[1].name, 'COM9');

      live.availablePorts = [
        const SerialPortOption(name: 'COM3', description: 'FT232R'),
        const SerialPortOption(name: 'COM9', description: 'CP2105'),
      ];
      final both = live.portChoices(suggest).first;
      expect(both.name, 'COM9');
      expect(both.pickerTags, ['suggested']);
      expect(both.pickerSubtitle, 'Recently connected');
    });
  });

  test('Windows leads with the COM number, which is the identifier there', () {
    // Every other program on that machine asks the operator for COM3; a
    // label that parks it in parentheses is answering a different question.
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(
      const SerialPortOption(name: 'COM3', description: 'Silicon Labs CP2105').label,
      'COM3 — Silicon Labs CP2105',
    );
  });

  test('a port whose descriptors are unreadable shows its bare node', () {
    // A port that answers nothing at all — no description anywhere — still
    // has to be pickable.
    // `/dev/` and macOS' `cu.` both come off: neither says anything, and
    // together they push the part that differs off a narrow row.
    expect(const SerialPortOption(name: '/dev/cu.usbserial-00F8E1EB0').label, 'usbserial-00F8E1EB0');
  });

  test('the picker row splits into a name, its tags and the device node', () {
    SerialPortSightings.resetForTest();
    // Three columns, not one string: a list of near-identical device nodes is
    // only scannable when the node has a column of its own.
    final field = ports.configElements(restrictions: {'port': Ft891Driver.cp2105CatPort})
        .firstWhere((e) => e['key'] == 'port');
    final first = (field['options'] as List).cast<Map<String, dynamic>>().first;
    // The ordinal is part of the NAME now that the sibling is never hidden:
    // both rows read `CP2105` otherwise, and the suggested one has to say
    // which of the two it is.
    expect(first['label'], 'CP2105 (port 1 of 2)');
    expect(first['tags'], ['suggested']);
    expect(first['icon'], 'usb');
    expect(first['trailing'], 'bus/usb/001/007#0');
  });

  test('a name derived from the node leaves the node column empty, saying it once', () {
    SerialPortSightings.resetForTest();
    final bare = _Ports([
      const SerialPortOption(name: '/dev/cu.usbserial-A1'),
      const SerialPortOption(name: 'COM3'),
      // The one with a real description keeps its node, which is the only
      // row where that column says something the name did not.
      const SerialPortOption(name: 'COM4', description: 'Silicon Labs CP2102'),
    ]);
    final options = (bare.configElements().firstWhere((e) => e['key'] == 'port')['options'] as List).cast<Map>();
    expect(options[0]['label'], 'COM3');
    expect(options[0].containsKey('trailing'), isFalse);
    expect(options[1]['label'], 'Silicon Labs CP2102');
    expect(options[1]['trailing'], 'COM4');
    expect(options[2]['label'], 'Usbserial A1');
    expect(options[2].containsKey('trailing'), isFalse);
  });

  group('macOS names a bridge\'s ports after the device, so its siblings can be recognised', () {
    setUp(() {
      SerialPortSightings.resetForTest();
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    });
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    const cp2105 = [
      SerialPortOption(name: '/dev/cu.usbserial-00F8E1EB0', description: 'CP2105 Dual USB to UART'),
      SerialPortOption(name: '/dev/cu.usbserial-00F8E1EB1', description: 'CP2105 Dual USB to UART'),
    ];

    test('two names differing only in a final digit, under one description, are one device', () {
      // The serial number with the port index appended is the only thing on
      // that platform that says these two are siblings: no USB ids read, and
      // the OS named them separately.
      final choices = _Ports(cp2105).portChoices(null);
      expect(choices[0].label, contains('port 1 of 2'));
      expect(choices[1].label, contains('port 2 of 2'));
    });

    test('a radio that knows its CAT port suggests only that one', () {
      // Both ports carry the same description, so the pattern alone matches
      // the pair — and the one it does not want is the PTT line, which looks
      // exactly like a dead cable when picked.
      final choices = _Ports(cp2105).portChoices(Ft891Driver.cp2105CatPort);
      expect([for (final c in choices) c.suggested], [true, false]);
      expect(choices.first.name, '/dev/cu.usbserial-00F8E1EB0');
    });

    test('the sibling is still OFFERED, never hidden: nothing here proved it is that radio', () {
      // The restriction's vendor gate cannot be checked on macOS, and the OS
      // named both ports itself. Suggesting is a claim that can be ignored;
      // hiding is not.
      expect(_Ports(cp2105).portChoices(Ft891Driver.cp2105CatPort).length, 2);
    });

    test('two adapters that merely look alike are not paired into one device', () {
      // Different descriptions, so nothing says they are one device — and
      // pairing them would put "port 1 of 2" on two unrelated cables.
      final pair = _Ports(const [
        SerialPortOption(name: '/dev/cu.usbserial-A0', description: 'FT232R'),
        SerialPortOption(name: '/dev/cu.usbserial-A1', description: 'CH340'),
      ]);
      expect([for (final c in pair.portChoices(null)) c.label], isNot(contains(contains('port'))));
    });

    test('a lone port with a digit on the end is not half a bridge', () {
      final one = _Ports(const [SerialPortOption(name: '/dev/cu.usbserial-A0', description: 'FT232R')]);
      expect(one.portChoices(null).single.label, isNot(contains('port')));
    });

    test('two adapters whose serial numbers differ are never one bridge', () {
      // A two-pack off one production run: identical cables, identical
      // description, serials differing in the last character. Read as one
      // bridge, a radio's declared index would confidently point at whichever
      // sorts first — possibly the cable going to a different radio.
      final twoCables = _Ports(const [
        SerialPortOption(name: '/dev/cu.usbserial-A50285B0', description: 'FT232R', serialNumber: 'A50285B0'),
        SerialPortOption(name: '/dev/cu.usbserial-A50285B1', description: 'FT232R', serialNumber: 'A50285B1'),
      ]);
      expect([for (final c in twoCables.portChoices(null)) c.label], isNot(contains(contains('port'))));
    });

    test('one bridge whose ports share a serial number still pairs', () {
      // The same field read the other way: libserialport takes it off the USB
      // DEVICE, so a bridge's ports agree on it.
      final bridge = _Ports(const [
        SerialPortOption(name: '/dev/cu.usbserial-00F8E1EB0', description: 'CP2105', serialNumber: '00F8E1EB'),
        SerialPortOption(name: '/dev/cu.usbserial-00F8E1EB1', description: 'CP2105', serialNumber: '00F8E1EB'),
      ]);
      expect(bridge.portChoices(null).first.label, contains('port 1 of 2'));
    });

    test('a node that already carries case is not retitled into something unsearchable', () {
      // `TtyUSB0` is not the string in dmesg, and since a derived name drops
      // the node column, mangling it would leave the real path nowhere.
      final linuxish = _Ports(const [SerialPortOption(name: '/dev/ttyUSB0')]);
      expect(linuxish.portChoices(null).single.pickerLabel, 'ttyUSB0');
    });
  });

  test('Linux and Windows do not guess: ttyUSB0 and ttyUSB1 are usually two adapters', () {
    // Same shape as the macOS case and the opposite meaning — and no guess is
    // needed there, because those platforms read the USB ids that say what is
    // really one device.
    SerialPortSightings.resetForTest();
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final linux = _Ports(const [
      SerialPortOption(name: '/dev/ttyUSB0', description: 'FT232R USB UART'),
      SerialPortOption(name: '/dev/ttyUSB1', description: 'FT232R USB UART'),
    ]);
    expect([for (final c in linux.portChoices(null)) c.label], isNot(contains(contains('port'))));
  });

  test('two ports of one bridge are numbered, because their description is identical', () {
    // The macOS CP2105: both ports answer with the same description and
    // there is nothing else readable, so the name column says nothing at all
    // about which is which without this.
    SerialPortSightings.resetForTest();
    final bridge = _Ports([
      const SerialPortOption(name: '/dev/cu.usbserial-00F8E1EB1', description: 'CP2105 Dual USB to UART'),
      const SerialPortOption(name: '/dev/cu.usbserial-00F8E1EB0', description: 'CP2105 Dual USB to UART'),
      const SerialPortOption(name: '/dev/cu.debug-console', description: 'CP2102 Single'),
    ]);
    final choices = bridge.portChoices(null);
    // Numbered in the order shown, which the device breaks the tie on — so a
    // refresh that changed nothing cannot swap #1 and #2.
    expect([for (final c in choices) c.hardware], [
      'CP2102 Single',
      'CP2105 Dual USB to UART #1',
      'CP2105 Dual USB to UART #2',
    ]);
    expect([for (final c in choices) c.device], ['debug-console', 'usbserial-00F8E1EB0', 'usbserial-00F8E1EB1']);
  });

  test('a port with nothing but its node gets a description made from it', () {
    // macOS answers `Bluetooth-Incoming-Port` as the description of the port
    // it named `Bluetooth-Incoming-Port` — the same string in both columns,
    // which reads as a bug. Titling the node says no more than the node did,
    // but it says it in the shape of every other row, and the raw node stays
    // on the right to be typed into anything else.
    SerialPortSightings.resetForTest();
    final macos = _Ports([
      const SerialPortOption(name: '/dev/cu.Bluetooth-Incoming-Port', description: 'Bluetooth-Incoming-Port'),
      const SerialPortOption(name: '/dev/cu.debug-console'),
    ]);
    final options = (macos.configElements().firstWhere((e) => e['key'] == 'port')['options'] as List).cast<Map>();
    expect(options[0]['label'], 'Bluetooth Incoming Port');
    expect(options[1]['label'], 'Debug Console');
    // Derived from the node, so the node column stays out of it: the two
    // would say the same thing, one of them with the dashes back in.
    expect(options[0].containsKey('trailing'), isFalse);
    expect(options[1].containsKey('trailing'), isFalse);
  });

  test('Windows orders COM ports by their number, so COM11 comes after COM2', () {
    // The identifier the operator knows is the number, and plain string order
    // reads it as text: COM11 lands between COM1 and COM2, which on a machine
    // with a handful of adapters looks like the list is unsorted.
    SerialPortSightings.resetForTest();
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final windows = _Ports(const [
      SerialPortOption(name: 'COM11', description: 'Silicon Labs CP2105'),
      SerialPortOption(name: 'COM2', description: 'FTDI FT232R'),
      SerialPortOption(name: 'COM1', description: 'Communications Port'),
      SerialPortOption(name: 'COM9', description: 'Prolific PL2303'),
    ]);
    // Sorted on the label, which on Windows leads with the number — so this
    // exercises the real string, not a bare device name.
    expect([for (final c in windows.portChoices(null)) c.name], ['COM1', 'COM2', 'COM9', 'COM11']);
  });

  test('ports sort by number where they have one, not by digit', () {
    SerialPortSightings.resetForTest();
    // COM10 before COM3 is what plain string order gives a Windows operator
    // with more than nine ports.
    final windows = _Ports([
      const SerialPortOption(name: 'COM10'),
      const SerialPortOption(name: 'COM3'),
      const SerialPortOption(name: 'COM9'),
    ]);
    expect([for (final c in windows.portChoices(null)) c.name], ['COM3', 'COM9', 'COM10']);
  });

  group('the registry declares the CAT port for the radios whose bridge is known', () {
    final registry = EquipmentRegistry();

    test('every port restriction has the shape portChoices reads, so a typo inside it cannot narrow nothing', () {
      // The registry self-check only sees the outer key; `{'idx': 1}` or a
      // string vendor id would pass it and silently switch the rule off.
      for (final type in registry.types) {
        final port = type.restrictions['port'];
        if (port == null) continue;
        expect(port, isA<Map>(), reason: type.key);
        expect((port as Map)['index'], isA<int>(), reason: type.key);
        expect(port['index'] as int, isNonNegative, reason: type.key);
        expect(port['vendorId'], anyOf(isNull, isA<int>()), reason: type.key);
        expect(port.keys.toSet().difference({'index', 'vendorId', 'suggest'}), isEmpty, reason: type.key);
        final suggest = port['suggest'];
        if (suggest == null) continue;
        // Same reasoning as the index above, one level down: `{'matches':
        // […]}` or a pattern that is not a String reads as "suggest
        // nothing", which looks exactly like a radio that declared none.
        expect(suggest, isA<Map>(), reason: type.key);
        expect((suggest as Map).keys.toSet().difference({'usb', 'match'}), isEmpty, reason: type.key);
        for (final entry in (suggest['usb'] as List? ?? const [])) {
          expect(entry, isA<Map>(), reason: type.key);
          expect((entry as Map)['vendorId'], isA<int>(), reason: type.key);
          expect(entry['productId'], anyOf(isNull, isA<int>()), reason: type.key);
        }
        for (final pattern in (suggest['match'] as List? ?? const [])) {
          expect(pattern, isA<String>(), reason: type.key);
          expect(() => RegExp(pattern as String), returnsNormally, reason: type.key);
        }
      }
    });

    test('the X6100 speaks CI-V on the second of its two ports', () {
      expect(registry.typeFor('x6100-serial')!.restrictions['port'], {'index': 1});
    });

    // Which Icoms claim Port A, named rather than derived. A filter on the
    // manufacturer would let an entry drop out of the set silently — renamed
    // brand string, re-keyed variant — and a guard that shrinks to nothing
    // still passes.
    const claimsPortA = {'icom-generic-serial', 'ic705-serial', 'ic7610-serial', 'ic7760-serial'};
    const noPortOfItsOwn = {'ic7300-serial', 'ic7300mk2-serial', 'ic706mkiig-serial', 'ic7100-serial'};

    test('the Icoms with two USB ports of their own claim the first', () {
      for (final key in claimsPortA) {
        final port = registry.typeFor(key)?.restrictions['port'] as Map?;
        // The INDEX, not the whole map: an Icom shipped behind a known
        // bridge may legitimately add a `suggest` clause the way the CP2105
        // Yaesus do below, and deep equality would fail it for being more
        // specific. The map's shape is pinned by the self-check above.
        expect(port?['index'], 0, reason: key);
      }
    });

    test('a radio whose ports are the operator\'s cable claims nothing', () {
      // The IC-706MKIIG reaches CI-V through a level converter, and the
      // two IC-7300s and the IC-7100 present one port each, so the only
      // ports these could ever rank belong to somebody else's bridge — whose second channel is
      // usually PTT, which picks and then answers nothing. Icom's Port A
      // convention is about Icom's own USB and says nothing about that.
      for (final key in noPortOfItsOwn) {
        expect(registry.typeFor(key)!.restrictions.containsKey('port'), isFalse, reason: key);
      }
    });

    test('every Icom serial pairing is accounted for, one way or the other', () {
      // The trap: a new Icom added to the catalogue reaching neither list,
      // so nobody decided whether it points at Port A. Both sets above pass
      // happily while saying nothing about it.
      final icoms = {
        for (final type in registry.types)
          if (type.model.manufacturer == icomBrand && type.transportKey == 'serial') type.key,
      };
      expect(icoms, claimsPortA.union(noPortOfItsOwn));
    });

    test('the claim is unscoped, so it survives a radio the platform reads no ids for', () {
      // macOS reads no vendorId at all. A vendor gate here would switch the
      // claim off on the platform whose device nodes are the hardest to tell
      // apart, which is where it is worth most.
      final port = registry.typeFor('ic705-serial')!.restrictions['port'] as Map;
      expect(port.containsKey('vendorId'), isFalse);
    });

    test('the CP2105 Yaesus speak CAT on the Enhanced port, the first, and only on a Silicon Labs bridge', () {
      for (final key in ['ft891-serial', 'ftdx10-serial']) {
        final port = registry.typeFor(key)!.restrictions['port'] as Map;
        expect(port['index'], 0, reason: key);
        expect(port['vendorId'], 0x10C4, reason: key);
        // Desktop has no siblings to narrow, so the same chip has to be
        // named for the suggestion to have anything to say there.
        expect(port['suggest'], isNotNull, reason: key);
      }
    });

    test('the other generics declare nothing: their adapter is whatever the operator plugged in', () {
      // Icom's generic is the exception and earns it: that maker puts CI-V
      // on Port A across the line, and the entry's own troubleshooting note
      // already tells the operator so. The three below have no such
      // convention, so a claim about their port would be invention.
      for (final key in ['yaesu-serial', 'kenwood-serial', 'elecraft-serial']) {
        expect(registry.typeFor(key)!.restrictions.containsKey('port'), isFalse, reason: key);
      }
    });
  });
}
