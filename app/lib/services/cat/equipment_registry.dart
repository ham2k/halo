// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The catalogue of equipment the app knows how to talk to, and the
// transports it can reach them over.
//
// An [EquipmentType] is a (model × transport) pair — "FlexRadio over the
// network", "Yaesu FT-891 over USB serial" — because that pair is what
// decides the connection settings the user has to fill in. It is one
// concrete, data-driven class: a catalogue entry is a plain instance, not a
// subclass. The connection form itself is assembled from three sources —
// [EquipmentTransport.configElements] (how the bytes get there),
// [EquipmentDriver.configElements] (the protocol's own settings, e.g. a
// CI-V bus address), and this instance's own [notes] — so a new radio never
// needs to re-declare a serial port picker or re-parse a hex address. See
// docs/design/cat.md.

import '../../i18n/strings.g.dart';
import 'discovery.dart';
import 'driver.dart';
import 'drivers/flexradio_driver.dart';
import 'drivers/ft891_driver.dart';
import 'drivers/icom_civ_driver.dart';
import 'equipment.dart';
import 'transport.dart';
import 'transports/icom_network_protocol.dart';
import 'transports/icom_network_transport.dart';
import 'transports/serial_transport.dart';
import 'transports/tcp_transport.dart';

class EquipmentType {
  /// Stable id, stored in [EquipmentNode.typeKey]. Never change it once
  /// shipped — a user's configured node is looked up by this.
  final String key;

  /// General characteristics, per data-model.md — `transceiver` today.
  final String category;

  final EquipmentDriver driver;
  final EquipmentTransport transport;

  /// Sensible starting values for a new node of this type — pure prefill,
  /// used once when the Add form opens. Unlike [overrides] the user can
  /// freely change these afterward.
  final Map<String, dynamic> defaultConfig;

  /// Fixed values this pairing hardcodes rather than asking the user for —
  /// e.g. the IC-705's network transport always talks to CI-V address A4,
  /// so there is nothing to pick. [EquipmentTransport.configElements] and
  /// [EquipmentDriver.configElements] skip a field entirely once its key is
  /// here. Merged into the config fresh at every connect/render — never
  /// written into the node's stored config, so a later change to this value
  /// reaches every node using it instead of freezing whatever was true when
  /// the node was added.
  final Map<String, dynamic> overrides;

  /// Per-field hints that narrow what a transport's or driver's own field
  /// would otherwise offer — e.g. a radio whose CAT menu only supports a
  /// handful of baud rates. Never adds an option the transport/driver
  /// didn't already have.
  final Map<String, dynamic> restrictions;

  /// Overrides [driver.hardwareVerified] when this specific pairing's
  /// hardware status differs from the driver's own — the Icom CI-V driver
  /// is proven over the network, but that says nothing about the same
  /// driver over a USB serial port, which has never met a radio.
  final bool? hardwareVerifiedOverride;

  /// Set when this pairing's equipment announces itself on the network.
  final EquipmentDiscoverer? discoverer;

  /// An escape hatch for a validation rule specific to just this one
  /// pairing — not shareable with other radios on the same transport or
  /// driver, so it doesn't belong in either's shared `validateField`. Null
  /// for every radio today; exists so the next one that needs it doesn't
  /// have to contaminate a shared transport/driver with per-radio
  /// knowledge to get it.
  final String? Function(Map<String, dynamic> config)? extraValidate;

  /// What the user picks from the type list. A closure rather than a plain
  /// string: `t.xxx` reads the CURRENT locale at call time, so baking the
  /// value into a field here would freeze whatever language was active the
  /// first time this catalogue entry got touched.
  final String Function() _nameBuilder;

  /// Extra FormRenderer elements appended after the transport's and
  /// driver's own fields — how-to-configure notes, common troubleshooting.
  /// Same live-locale reasoning as [_nameBuilder]. Plain data
  /// (`divider`/`markdown` elements) once called: a radio's own entry never
  /// contains code, only a translated-text lookup.
  final List<Map<String, dynamic>> Function()? _notesBuilder;

  const EquipmentType({
    required this.key,
    required this.category,
    required String Function() name,
    required this.driver,
    required this.transport,
    this.defaultConfig = const {},
    this.overrides = const {},
    this.restrictions = const {},
    this.hardwareVerifiedOverride,
    this.discoverer,
    this.extraValidate,
    List<Map<String, dynamic>> Function()? notes,
  })  : _nameBuilder = name,
        _notesBuilder = notes;

  String get name => _nameBuilder();

  List<Map<String, dynamic>> get notes => _notesBuilder?.call() ?? const [];

  String get transportKey => transport.key;

  bool get hardwareVerified => hardwareVerifiedOverride ?? driver.hardwareVerified;

  /// Config keys whose values are credentials, kept in the platform
  /// keychain instead of the SharedPreferences blob the rest of the config
  /// lives in ([CatService] moves them on save). Always the transport's —
  /// a driver never opens a connection of its own to authenticate.
  Set<String> get secretFields => transport.secretFields;

  /// FormRenderer elements for the connection parameters and any
  /// device-specific settings: transport section, then driver section,
  /// then this pairing's own notes.
  List<Map<String, dynamic>> configElements() => [
        ...transport.configElements(overrides: overrides, restrictions: restrictions),
        ...driver.configElements(overrides: overrides, restrictions: restrictions),
        ...notes,
      ];

  Map<String, dynamic> _merged(Map<String, dynamic> config) => {...config, ...overrides};

  /// Turns the user's configuration into what the transport connects with.
  Map<String, dynamic> targetFor(Map<String, dynamic> config) => transport.targetFor(_merged(config));

  /// The configuration the DRIVER sees — the merged config, overrides
  /// included, since a driver reads whatever keys it needs straight out of
  /// the map rather than through a narrowed shape like [targetFor].
  Map<String, dynamic> driverConfig(Map<String, dynamic> config) => _merged(config);

  /// A one-line "where is it" for the equipment list.
  String describeTarget(Map<String, dynamic> config) {
    final merged = _merged(config);
    final suffix = driver.describeSuffix(merged, overrides: overrides) ?? '';
    return '${transport.describeTarget(merged)}$suffix';
  }

  /// Per-field version, for the editor: FormRenderer validates one field at
  /// a time and anchors the message on that field. Tries the transport
  /// first, then the driver — each recognizes only the keys it declared in
  /// [configElements], so there's nothing to route explicitly.
  String? validateField(String key, dynamic value, Map<String, dynamic> config) =>
      transport.validateField(key, value, config) ?? driver.validateField(key, value, config);

  /// Null when the whole configuration is usable, otherwise why it isn't —
  /// the check [CatService] runs before it bothers opening a socket. Walks
  /// [EquipmentTransport.recognizedConfigKeys]/[EquipmentDriver.recognizedConfigKeys]
  /// rather than [configElements] deliberately: the latter, for a serial
  /// pairing, enumerates real hardware to build the port picker's option
  /// list — work [CatService]'s idle-retry loop would otherwise repeat on
  /// every reconnect attempt of a disconnected radio, purely to learn a
  /// field's key. An overridden key is skipped: it's never the user's to
  /// get wrong.
  String? validate(Map<String, dynamic> config) {
    for (final key in {...transport.recognizedConfigKeys, ...driver.recognizedConfigKeys}) {
      if (overrides.containsKey(key)) continue;
      final error = validateField(key, config[key], config);
      if (error != null) return error;
    }
    return extraValidate?.call(config);
  }

  /// Null for equipment that doesn't announce itself.
  Stream<DiscoveredEquipment>? discover() => discoverer?.discover();
}

const _flexRadioTcpKey = 'flexradio-tcp';
const _ft891SerialKey = 'ft891-serial';
const _icomCivSerialKey = 'icom-civ-serial';
const _ic705NetworkKey = 'ic705-network';

/// FlexRadio radios reachable over the SmartSDR TCP API.
///
/// Found automatically: a Flex announces itself over UDP broadcast on 4992.
/// Address and port can always be typed in as well — a radio on another
/// subnet, or behind a router that doesn't forward broadcasts, never
/// announces, and neither app-polo branch had a manual path at all.
const flexRadioTcpType = EquipmentType(
  key: _flexRadioTcpKey,
  category: kCategoryTransceiver,
  name: _flexRadioTcpName,
  driver: FlexRadioDriver(),
  transport: TcpTransport(),
  defaultConfig: {'port': FlexRadioDriver.defaultPort},
  discoverer: FlexRadioDiscoverer(typeKey: _flexRadioTcpKey),
);

String _flexRadioTcpName() => t.settings.station.types.flexRadioTcp;

/// Yaesu FT-891 over its built-in USB-to-serial CAT bridge.
///
/// Baud is the operator's to set, deliberately. app-polo hardcoded 4800 with
/// no UI, which its own notes call out as a silent-failure mode: a radio
/// whose CAT menu says 38400 answers with garbage and no error at all.
const ft891SerialType = EquipmentType(
  key: _ft891SerialKey,
  category: kCategoryTransceiver,
  name: _ft891SerialName,
  driver: Ft891Driver(),
  transport: SerialTransport(),
  defaultConfig: {'baudRate': Ft891Driver.defaultBaudRate},
  // The failure this driver actually produces is silence: the commands go
  // out, nothing comes back, and nothing anywhere reports an error. Every
  // cause is a setting the operator has to change on the radio or elsewhere
  // on the machine, so the editor is where it is worth saying — by the time
  // the row says "Connected" with no frequency, this form is exactly where
  // they will come looking.
  notes: _ft891SerialNotes,
);

String _ft891SerialName() => t.settings.station.types.ft891Serial;

List<Map<String, dynamic>> _ft891SerialNotes() => [
      {'type': 'divider', 'title': t.settings.station.troubleshootingTitle},
      {'type': 'markdown', 'text': t.settings.station.ft891Troubleshooting},
    ];

/// Any Icom transceiver over CI-V on a serial port — the IC-705's USB
/// connection, and equally an IC-7300 or IC-9700 with a different address.
///
/// The CI-V address is configuration rather than a constant because it is
/// settable on the radio, and because a wrong one is silent: the radio
/// simply ignores frames addressed elsewhere, which looks exactly like a
/// dead cable.
///
/// The DRIVER is verified (a ten-minute IC-705 session over WiFi), but this
/// pairing has never been pointed at a radio. The serial transport itself
/// is proven by the FT-891, so this is likely fine — "likely fine" being
/// exactly what [EquipmentType.hardwareVerifiedOverride] is for.
const icomCivSerialType = EquipmentType(
  key: _icomCivSerialKey,
  category: kCategoryTransceiver,
  name: _icomCivSerialName,
  driver: IcomCivDriver(),
  transport: SerialTransport(),
  defaultConfig: {
    // The IC-705's factory address, and the most likely radio here.
    'civAddress': 'A4',
    // Icom's CI-V default. The radio can also be set to Auto, which
    // negotiates nothing and simply follows the host.
    'baudRate': 19200,
  },
  hardwareVerifiedOverride: false,
);

String _icomCivSerialName() => t.settings.station.types.icomCivSerial;

/// An IC-705 over WiFi, using Icom's RS-BA1 network protocol.
///
/// Both the CI-V address and the controller address are hardcoded rather
/// than asked for: RS-BA1 only ever talks to the one radio it's paired
/// with, at the IC-705's factory address, and the controller side of a
/// network CI-V exchange is always 0xE1 — a fact about the transport, not a
/// setting, so it never becomes a question in the editor.
const ic705NetworkType = EquipmentType(
  key: _ic705NetworkKey,
  category: kCategoryTransceiver,
  name: _ic705NetworkName,
  driver: IcomCivDriver(),
  transport: IcomNetworkTransport(),
  overrides: {
    'civAddress': 'A4',
    'civControllerAddress': icomNetworkControllerAddress,
  },
  // The failure this transport actually produces is silence: the handshake
  // succeeds and the login is ignored, so a busy radio and a refusal are
  // indistinguishable from here. Every remedy is something the operator
  // does at the radio or to another program.
  notes: _ic705NetworkNotes,
);

String _ic705NetworkName() => t.settings.station.types.ic705Network;

List<Map<String, dynamic>> _ic705NetworkNotes() => [
      {'type': 'divider', 'title': t.settings.station.ic705TroubleshootingTitle},
      {'type': 'markdown', 'text': t.settings.station.ic705Troubleshooting},
    ];

/// What the app can talk to, and how it gets there.
///
/// A plain Dart list today. When extensions can contribute rig definitions
/// this gains a second source and merges them, the way [SettingsView]
/// already merges Dart settings groups with extension-contributed panels.
class EquipmentRegistry {
  final List<EquipmentType> types;
  final Map<String, EquipmentTransport> transports;

  EquipmentRegistry({List<EquipmentType>? types, Map<String, EquipmentTransport>? transports})
      : types = types ?? const [flexRadioTcpType, ft891SerialType, icomCivSerialType, ic705NetworkType],
        transports = transports ??
            {
              TcpTransport.transportKey: const TcpTransport(),
              SerialTransport.transportKey: const SerialTransport(),
              IcomNetworkTransport.transportKey: const IcomNetworkTransport(),
            };

  EquipmentType? typeFor(String? key) {
    for (final type in types) {
      if (type.key == key) return type;
    }
    return null;
  }

  EquipmentTransport? transportFor(String? key) => key == null ? null : transports[key];
}
