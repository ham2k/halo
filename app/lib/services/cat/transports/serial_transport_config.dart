// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The port/baud-rate config section, identical on every platform — only
// `availableSerialPorts()` and `connect()` differ between
// serial_transport_io.dart and serial_transport_unsupported.dart, so this is the
// one place the rest of that logic lives.

import 'package:flutter/foundation.dart';

import 'package:halo_i18n/halo_i18n.dart';
import '../transport.dart';
import 'config_field_helpers.dart';
import 'serial_port_sightings.dart';

/// What the radio's CAT menu offers. Anything the port doesn't support
/// fails at open rather than silently misbehaving.
const supportedBaudRates = [4800, 9600, 19200, 38400, 57600, 115200];

class SerialPortOption {
  final String name;
  final String? description;
  final String? manufacturer;
  final String? productName;
  final String? serialNumber;
  final int? vendorId;
  final int? productId;

  /// Where this port sits among its device's serial ports, and how many
  /// the device has — set only where the platform can tell (Android),
  /// and only for a device presenting more than one. Null means the OS
  /// already gave the port its own name and nothing here knows its
  /// siblings.
  final int? portIndex;
  final int? portCount;

  const SerialPortOption({
    required this.name,
    this.description,
    this.manufacturer,
    this.productName,
    this.serialNumber,
    this.vendorId,
    this.productId,
    this.portIndex,
    this.portCount,
  });

  /// The whole port on ONE LINE — `CP2105 Dual USB to UART
  /// (cu.usbserial-00F8E1EB0)`. Not what the picker draws: that has columns,
  /// and takes [PortChoice.hardware] and [shortName] separately. This is for
  /// the places that have only a line — an equipment report's "what the app
  /// was set up with", and the order the picker sorts in.
  ///
  /// WINDOWS PUTS THE NAME FIRST. `COM3` is the identifier there — it is
  /// what the operator sets in every other program on the machine — so it is
  /// not a detail to park in parentheses. That inversion is what makes the
  /// sort read the COM number first, and so order by it.
  ///
  /// Where [portIndex] is known the label says "port N of M" as well;
  /// [bareLabel] leaves that off, for a list that has already picked the
  /// port.
  String get label => _label(withPort: true);

  String get bareLabel => _label(withPort: false);

  /// The device node with the parts that say nothing taken off: the `/dev/`
  /// every Unix node starts with, and macOS' `cu.` call-out prefix, which is
  /// on every port that platform lists. What is left is the part that
  /// actually differs between two ports of the same bridge, which is all the
  /// operator has to tell them apart.
  String get shortName {
    var short = name;
    if (short.startsWith('/dev/')) short = short.substring('/dev/'.length);
    if (short.startsWith('cu.')) short = short.substring('cu.'.length);
    return short;
  }

  /// The same port, told where it sits among its device's ports.
  SerialPortOption at({required int index, required int count}) => SerialPortOption(
    name: name,
    description: description,
    manufacturer: manufacturer,
    productName: productName,
    serialNumber: serialNumber,
    vendorId: vendorId,
    productId: productId,
    portIndex: index,
    portCount: count,
  );

  /// What the descriptors say this is, with no device node — empty when they
  /// said nothing.
  String hardware({required bool withPort}) => [
    if (description != null) description! else ...[?manufacturer, ?productName],
    if (withPort && portIndex != null && portCount != null) '(${t.settings.station.serialPortOrdinal(n: portIndex! + 1, total: portCount!)})',
  ].join(' ');

  String _label({required bool withPort}) {
    final detail = hardware(withPort: withPort);
    if (detail.isEmpty) return shortName;
    if (defaultTargetPlatform == TargetPlatform.windows) return '$name — $detail';
    return '$detail ($shortName)';
  }
}

/// One entry in the port picker: what gets stored, what gets shown, and the
/// two things the list has to say about a port beyond its name.
class PortChoice {
  final String name;

  /// The whole thing on one line — what an equipment report quotes, and the
  /// key this list is sorted on. The picker itself draws [hardware] and
  /// [device] in columns of their own and never shows this.
  final String label;

  /// What the descriptors call the hardware, with no device node and no
  /// marker: the left column of the picker's row.
  final String hardware;

  /// The device node, short: the right column.
  final String device;

  /// The radio's definition claims this port carries its CAT.
  final bool suggested;

  /// First seen within [SerialPortSightings.recentWindow], and not every
  /// port is.
  final bool justNow;

  const PortChoice({required this.name, required this.label, required this.hardware, required this.device, this.suggested = false, this.justNow = false});

  PortChoice withHardware(String hardware) => PortChoice(name: name, label: label, hardware: hardware, device: device, suggested: suggested, justNow: justNow);

  /// Whether [pickerLabel] was made from the device node rather than read
  /// off the hardware — which is what says the node has nothing to add
  /// beside it.
  bool get isDerivedName => hardware.isEmpty || hardware == device;

  /// The hardware's own name, which leads the row.
  ///
  /// A port whose descriptors said nothing, or whose description is only its
  /// own node again (macOS answers that for
  /// `Bluetooth-Incoming-Port` and `debug-console`) gets one made from the
  /// node: dashes out, words capitalised. It says no more than the node did,
  /// but it says it in the shape of every other row instead of leaving a
  /// column blank, and the raw node is still there on the right to be typed
  /// into anything else.
  String get pickerLabel => isDerivedName ? _titleCase(device) : hardware;

  /// Only an all-lowercase word is capitalised. A node that already carries
  /// case is a name somebody chose — Linux's `ttyUSB0`, macOS'
  /// `Bluetooth-Incoming-Port` — and titling it produces `TtyUSB0`, which is
  /// no longer the string the operator can look for in `dmesg` or type into
  /// another program.
  static String _titleCase(String device) => [
    for (final word in device.split(_separators))
      if (word.isNotEmpty) word == word.toLowerCase() ? '${word[0].toUpperCase()}${word.substring(1)}' : word,
  ].join(' ');

  static final _separators = RegExp(r'[-_\s]+');

  /// The glyph in front of the row: what kind of thing this is at a glance,
  /// and for the port that has just appeared, that it is new before a word
  /// of it is read.
  String get pickerIcon => justNow ? 'new-box' : 'usb';

  /// The short markers between the name and the device node.
  List<String> get pickerTags => [if (suggested) t.settings.station.serialPortSuggested];

  /// The line under the name, for a port that was not there a moment ago —
  /// a sentence rather than a pill, because it is the row's own news and not
  /// a category the port belongs to.
  String? get pickerSubtitle => justNow ? t.settings.station.serialPortJustNow : null;
}

mixin SerialTransportConfig implements EquipmentTransport {
  /// Ports the app could open, enumerated fresh — a USB adapter can appear
  /// or vanish between one look and the next, so this must never be cached.
  List<SerialPortOption> get availablePorts;

  /// Ports this transport ranks first on its own account, before any
  /// catalogue restriction has its say — see BluetoothSerialTransport.
  bool prefersPort(SerialPortOption port) => false;

  @override
  List<Map<String, dynamic>> configElements({Map<String, dynamic> overrides = const {}, Map<String, dynamic> restrictions = const {}}) => [
    if (!overrides.containsKey('port'))
      {
        'type': 'field',
        'fieldType': 'select',
        'key': 'port',
        'label': t.settings.station.serialPort,
        'description': t.settings.station.serialPortDescription,
        'options': [
          for (final choice in portChoices(restrictions['port']))
            {
              'value': choice.name,
              'label': choice.pickerLabel,
              'tags': choice.pickerTags,
              'subtitle': ?choice.pickerSubtitle,
              'icon': choice.pickerIcon,
              // Only where the name came from the DESCRIPTORS. A name
              // this code derived from the node says nothing the node did
              // not, so printing both is one row saying one thing twice.
              if (!choice.isDerivedName) 'trailing': choice.device,
              if (choice.suggested) 'emphasis': true,
            },
        ],
      },
    if (!overrides.containsKey('baudRate'))
      {
        'type': 'field',
        'fieldType': 'select',
        'key': 'baudRate',
        'label': t.settings.station.baudRate,
        'description': t.settings.station.baudRateDescription,
        'options': [
          for (final rate in _allowedBaudRates(restrictions)) {'value': rate, 'label': '$rate'},
        ],
      },
  ];

  /// The ports as enumerated, with a macOS multi-port bridge's siblings
  /// recognised as such.
  ///
  /// That platform names each port after the DEVICE's serial number with the
  /// port index appended — a CP2105 presents `cu.usbserial-00F8E1EB0` and
  /// `cu.usbserial-00F8E1EB1` — so two names differing only in a final digit,
  /// under one description, are two ports of one device. Nothing else on
  /// desktop knows that: `vendorId`/`productId` do not read there, and the OS
  /// named the ports separately, so without this a radio that knows its CAT
  /// is on the first port has nothing to say it to.
  ///
  /// macOS ONLY, deliberately. Linux's `ttyUSB0`/`ttyUSB1` have the same
  /// shape and are usually two SEPARATE adapters, so the same inference there
  /// would invent a bridge and mislabel both — and it is not needed, because
  /// that platform reads the USB ids that say what is really one device.
  static List<SerialPortOption> withInferredSiblings(List<SerialPortOption> ports) {
    if (defaultTargetPlatform != TargetPlatform.macOS) return ports;

    // Keyed by everything the two names share, so ports of different devices
    // — or of one device that says different things about them — never pair.
    final groups = <String, List<SerialPortOption>>{};
    for (final port in ports) {
      if (port.portIndex != null) continue;
      if (!_endsInDigit(port.name)) continue;
      groups.putIfAbsent(_siblingKey(port), () => []).add(port);
    }

    final assigned = <String, SerialPortOption>{};
    for (final group in groups.values) {
      if (group.length < 2) continue;
      group.sort((a, b) => a.name.compareTo(b.name));
      for (final (index, port) in group.indexed) {
        assigned[port.name] = port.at(index: index, count: group.length);
      }
    }
    return [for (final port in ports) assigned[port.name] ?? port];
  }

  static bool _endsInDigit(String name) => name.isNotEmpty && _digits.hasMatch(name[name.length - 1]);

  static final _digits = RegExp(r'[0-9]');

  /// The name without its final digit, plus everything the descriptors said
  /// — two ports of one bridge agree on all of it.
  ///
  /// `serialNumber` is in there as the one field that can DISPROVE a pairing:
  /// libserialport reads it off the USB device, so one device's ports share
  /// it and two adapters never do. Where it reads, two identical cables whose
  /// serials differ only in the last character — which is what a two-pack off
  /// one production run looks like — are kept apart. Where it does not, the
  /// name is all there is and that pair would still be read as one bridge:
  /// the residual risk this inference carries, and the reason it only ever
  /// suggests a port rather than hiding its sibling.
  static String _siblingKey(SerialPortOption port) =>
      [port.name.substring(0, port.name.length - 1), port.description, port.manufacturer, port.productName, port.serialNumber].join('\u0000');

  /// The picker's entries once a `port` restriction has had its say.
  ///
  /// `{'index': n}` says which of a multi-port device's serial ports the
  /// radio's CAT is on, counted from 0 in descriptor order — the X6100's
  /// CI-V is on 1, a Yaesu's on its CP2105's 0.
  ///
  /// **It RANKS, it does not hide.** That port sorts first, renders bold and
  /// is tagged; every other port stays in the list. What the catalogue knows
  /// is where CAT usually is, not where it must be: both ports of an IC-705
  /// leave the factory set to CI-V and either can be switched, the same
  /// radio reached through somebody else's two-port cable has a different
  /// answer again, and an operator who moved CI-V deliberately would
  /// otherwise face a picker with no way to say so and nothing on screen
  /// explaining the absence. A wrong guess costs a bold row; a wrong
  /// exclusion costs the radio.
  ///
  /// With `'vendorId'` the claim applies only to that maker's bridges, so a
  /// radio reached through some other adapter's two ports is left unranked
  /// rather than pointed at the wrong one. A device the platform could not
  /// split, or with fewer ports than the index names, is simply not ranked.
  ///
  /// `'suggest'` ranks rather than narrows — see [portSuggests]. A
  /// suggested port sorts first, renders bold and is tagged; a port that
  /// first appeared in the last few minutes is tagged too ([justNow]).
  /// Within each group the order is alphabetical, so a list nobody has
  /// anything to say about is stable between one refresh and the next.
  List<PortChoice> portChoices(Object? restriction) {
    final ports = withInferredSiblings(availablePorts);
    // Every enumeration is a sighting: what the machine has is not what this
    // one radio may pick, and a port's age is a fact about the machine.
    SerialPortSightings.observe([for (final port in ports) port.name]);
    // "Just now" points one port out of several. With a single port there is
    // nothing to point away from, and a sparkle on the only option is noise.
    // Nothing else needs suppressing: the sightings' baseline already means
    // the ports that were there at launch are never "just now", however
    // recently the app first looked at them.
    final recent = {
      for (final port in ports)
        if (SerialPortSightings.isRecent(port.name)) port.name,
    };
    final markRecent = ports.length > 1;

    final choices = <PortChoice>[
      for (final port in ports)
        PortChoice(
          name: port.name,
          label: port.label,
          hardware: port.hardware(withPort: true),
          device: port.shortName,
          suggested: portSuggests(restriction, port) || prefersPort(port),
          justNow: markRecent && recent.contains(port.name),
        ),
    ];
    choices.sort((a, b) {
      // Suggested outranks just-now: what the radio's own definition knows
      // beats what happened to be plugged in last.
      if (a.suggested != b.suggested) return a.suggested ? -1 : 1;
      if (a.justNow != b.justNow) return a.justNow ? -1 : 1;
      final order = _naturalCompare(a.label, b.label);
      // The device breaks a tie between the two ports of one bridge, which
      // share every word of their label. `List.sort` is not stable, so
      // without this the numbering below could swap #1 and #2 between two
      // refreshes of a list nothing happened to.
      return order != 0 ? order : _naturalCompare(a.device, b.device);
    });
    return _numberDuplicates(choices);
  }

  /// A bridge presents its ports under one description — a CP2105's two read
  /// `CP2105 Dual USB to UART Bridge Controller` each — so the name column
  /// alone cannot tell them apart, and macOS reads no USB ids to break the
  /// tie with, so the operator has only the node to go on. Numbering them in
  /// the order they are shown gives that column something to say.
  ///
  /// Only where a name actually repeats: a `#1` with no `#2` anywhere is a
  /// question about what it counts.
  static List<PortChoice> _numberDuplicates(List<PortChoice> choices) {
    final counts = <String, int>{};
    for (final choice in choices) {
      if (choice.hardware.isEmpty) continue;
      counts[choice.hardware] = (counts[choice.hardware] ?? 0) + 1;
    }
    final seen = <String, int>{};
    return [
      for (final choice in choices)
        if ((counts[choice.hardware] ?? 0) < 2)
          choice
        else
          choice.withHardware('${choice.hardware} #${seen[choice.hardware] = (seen[choice.hardware] ?? 0) + 1}'),
    ];
  }

  /// Whether a `port` restriction's `'suggest'` clause claims [port] as the
  /// one carrying this radio's CAT.
  ///
  ///     'suggest': {
  ///       'match': [r'CP2105'],                                 // regexps
  ///       'usb': [{'vendorId': 0x10C4, 'productId': 0xEA70}],   // exact
  ///     }
  ///
  /// Both clauses are optional and either one matching is enough, which is
  /// what makes the pair worth declaring: on macOS libserialport cannot read
  /// `vendorId`/`productId` at all (they throw per port, per field) but
  /// answers `description` normally, so the pattern is the clause that bites
  /// there and the exact ids are the one that bites everywhere else. The
  /// regexps run case-insensitively over the whole label — description,
  /// manufacturer and product name included, not just the device node.
  ///
  /// A malformed clause suggests nothing rather than throwing: this is
  /// catalogue data rendering a picker, and a bad pattern must not take the
  /// equipment editor down with it. A registry self-check pins the shape so
  /// a typo is caught in the suite instead.
  static bool portSuggests(Object? restriction, SerialPortOption port) {
    if (restriction is! Map) return false;
    final suggest = restriction['suggest'];

    // A declared index narrows the suggestion to ONE port of a bridge whose
    // siblings are known. Without this the whole chip is suggested — both
    // ports of a CP2105 match its pattern equally — which points the operator
    // at a pair, one of which is the PTT line that looks like a dead cable.
    final index = restriction['index'];
    final vendorId = restriction['vendorId'];
    if (index is int && port.portIndex != null && port.portIndex != index) return false;

    // An index ALONE is a claim — the case where nothing else can tell two
    // ports apart. The IC-705 presents both of its under one name, with no
    // descriptor, USB id or pattern that differs between them; its position
    // is the entire distinguishing fact, so requiring a `suggest` clause
    // beside it would leave that radio unable to say the one thing it knows.
    //
    // `vendorId` scopes THIS claim and nothing else. It must not gate the
    // clauses below: macOS reads no USB ids at all, so a vendor test there
    // fails for every port, and gating `match` on it would switch off the
    // one clause that works on that platform — see the pattern's own note.
    if (suggest is! Map) {
      return index is int && index >= 0 && port.portIndex != null && index < (port.portCount ?? 0) && (vendorId == null || port.vendorId == vendorId);
    }

    final usb = suggest['usb'];
    if (usb is List) {
      for (final entry in usb) {
        if (entry is! Map) continue;
        if (port.vendorId == null || entry['vendorId'] != port.vendorId) continue;
        // A vendor id alone is a legitimate claim — one maker's bridge,
        // whatever the model — so a missing product id matches any.
        if (entry['productId'] == null || entry['productId'] == port.productId) return true;
      }
    }

    final match = suggest['match'];
    if (match is List) {
      for (final pattern in match) {
        if (pattern is! String) continue;
        // containsKey, not `??=`: a pattern that would not compile stores
        // null, and `??=` reads that as "not cached yet" and throws and
        // catches again for every port, on every refresh.
        if (!_suggestionPatterns.containsKey(pattern)) _suggestionPatterns[pattern] = _compile(pattern);
        final regexp = _suggestionPatterns[pattern];
        if (regexp != null && regexp.hasMatch(port.label)) return true;
      }
    }
    return false;
  }

  /// Alphabetical, except that a run of digits compares as a number: plain
  /// string order puts COM10 before COM3, which is the order the picker
  /// would show a Windows operator with more than nine ports.
  static final _chunks = RegExp(r'\d+|\D+');

  static int _naturalCompare(String a, String b) {
    final left = _chunks.allMatches(a.toLowerCase()).map((m) => m[0]!).toList();
    final right = _chunks.allMatches(b.toLowerCase()).map((m) => m[0]!).toList();
    for (var i = 0; i < left.length && i < right.length; i++) {
      final l = int.tryParse(left[i]);
      final r = int.tryParse(right[i]);
      final order = l != null && r != null ? l.compareTo(r) : left[i].compareTo(right[i]);
      if (order != 0) return order;
    }
    return left.length.compareTo(right.length);
  }

  /// Compiled once per pattern: `portChoices` runs on every keystroke-free
  /// refresh of an open picker, and these come from a fixed catalogue.
  static final Map<String, RegExp?> _suggestionPatterns = {};

  static RegExp? _compile(String pattern) {
    try {
      return RegExp(pattern, caseSensitive: false);
    } on FormatException {
      return null;
    }
  }

  static List<int> _allowedBaudRates(Map<String, dynamic> restrictions) {
    final allowed = restrictions['baudRate'];
    if (allowed is! List) return supportedBaudRates;
    return supportedBaudRates.where(allowed.contains).toList();
  }

  /// A static literal, deliberately not derived from [configElements] the
  /// way the base [EquipmentTransport.recognizedConfigKeys] default is:
  /// that default calls [configElements], which for this transport means
  /// [availablePorts] — a live hardware enumeration. `validate()` calls
  /// this on every connect and every unattended reconnect retry, and it
  /// has no business scanning serial hardware just to learn a field's key.
  /// `stopBits` is never a field: a driver whose device needs two (the
  /// WinKeyer) pins it in its model's `overrides`.
  @override
  Set<String> get recognizedConfigKeys => const {'port', 'baudRate', 'stopBits'};

  @override
  String? validateField(String key, dynamic value, Map<String, dynamic> config) {
    if (key != 'port') return null;
    return serialPort({...config, 'port': value}).isEmpty ? t.settings.station.serialPortRequired : null;
  }

  @override
  Map<String, dynamic> targetFor(Map<String, dynamic> config) => {
    'port': serialPort(config),
    'baudRate': serialBaudRate(config),
    'stopBits': serialStopBits(config),
  };

  @override
  bool isUnconfigured(Map<String, dynamic> config) => blankInConfig(config, 'port');

  @override
  String describeTarget(Map<String, dynamic> config) => '${serialPort(config)} @ ${serialBaudRate(config)}';

  static String serialPort(Map<String, dynamic> config) => stringFromConfig(config, 'port').trim();

  static int serialBaudRate(Map<String, dynamic> config) => numberFromConfig(config, 'baudRate', supportedBaudRates.first);

  /// 1 unless the model says 2; nothing here uses 1.5.
  static int serialStopBits(Map<String, dynamic> config) => numberFromConfig(config, 'stopBits', 1) == 2 ? 2 : 1;
}
