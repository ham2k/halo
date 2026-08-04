// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The catalogue of equipment the app knows how to talk to, and the
// transports it can reach them over.
//
// The authoring unit is an [EquipmentModel] — one radio, named once, holding
// an [EquipmentVariant] per transport it can be reached over. That is what
// the operator picks first ("Icom IC-705"), before choosing how it is
// connected ("WiFi", "USB serial"); a model with one variant skips the
// question entirely.
//
// The *resolved* unit is still an [EquipmentType], the (model × transport)
// pair, because that pair is what decides the connection settings and what a
// configured node is actually bound to. The registry derives one per variant
// rather than having them authored by hand. See docs/design/cat.md.
//
// The connection form is assembled from three sources —
// [EquipmentTransport.configElements] (how the bytes get there),
// [EquipmentDriver.configElements] (the protocol's own settings, e.g. a
// CI-V bus address), and the variant's own [EquipmentVariant.notes] — so a
// new radio never needs to re-declare a serial port picker or re-parse a hex
// address.

import '../../i18n/strings.g.dart';
import 'discovery.dart';
import 'driver.dart';
import 'drivers/flexradio_driver.dart';
import 'drivers/flrig_driver.dart';
import 'drivers/ft891_driver.dart';
import 'drivers/icom_civ_driver.dart';
import 'drivers/kenwood_driver.dart';
import 'drivers/rigctld_driver.dart';
import 'equipment.dart';
import 'transport.dart';
import 'transports/icom_network_protocol.dart';
import 'transports/icom_network_transport.dart';
import 'transports/serial_transport.dart';
import 'transports/tcp_transport.dart';

/// One way of reaching a model — everything that differs between the same
/// radio's serial and network entries.
///
/// That list is longer than it looks: for the IC-705, the driver's overrides,
/// the prefilled defaults, the hardware-verified status and the
/// troubleshooting notes ALL differ between its two transports. Hoisting any
/// of them onto the model would be wrong for the one radio that has two
/// variants today.
class EquipmentVariant {
  /// Stable id, stored in [EquipmentNode.typeKey]. Never change it once
  /// shipped — a user's configured node is looked up by this.
  ///
  /// Declared rather than derived from `model.key` + `transport.key`: the
  /// keys predate models, and a derivation that happened to disagree with
  /// one of them would silently orphan every node already configured
  /// against it.
  final String key;

  final EquipmentDriver driver;
  final EquipmentTransport transport;

  /// Sensible starting values for a new node on this transport — pure
  /// prefill, used once when the Add form opens. Unlike [overrides] the user
  /// can freely change these afterward.
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

  /// Extra FormRenderer elements appended after the transport's and
  /// driver's own fields — how-to-configure notes, common troubleshooting.
  /// A closure rather than plain data: `t.xxx` reads the CURRENT locale at
  /// call time, so baking the value into a field here would freeze whatever
  /// language was active the first time this catalogue entry got touched.
  /// Plain data (`divider`/`markdown` elements) once called: a radio's own
  /// entry never contains code, only a translated-text lookup.
  final List<Map<String, dynamic>> Function()? _notesBuilder;

  const EquipmentVariant({
    required this.key,
    required this.driver,
    required this.transport,
    this.defaultConfig = const {},
    this.overrides = const {},
    this.restrictions = const {},
    this.hardwareVerifiedOverride,
    this.discoverer,
    this.extraValidate,
    List<Map<String, dynamic>> Function()? notes,
  }) : _notesBuilder = notes;

  List<Map<String, dynamic>> get notes => _notesBuilder?.call() ?? const [];

  String get transportKey => transport.key;
}

/// One piece of equipment as the operator thinks of it: a radio, named once,
/// however many ways there are to reach it.
class EquipmentModel {
  /// Stable id. Not persisted — [EquipmentVariant.key] is what a node
  /// stores — so this one is free to change, unlike a variant's.
  final String key;

  /// General characteristics, per data-model.md — `transceiver` today.
  final String category;

  /// At least one. Order is what the transport picker offers.
  final List<EquipmentVariant> variants;

  /// The radio's own name, with nothing about how it is connected —
  /// "Icom IC-705", not "Icom IC-705 — WiFi". [EquipmentType.name] adds the
  /// transport. A closure for the same live-locale reason as
  /// [EquipmentVariant.notes].
  final String Function() _nameBuilder;

  const EquipmentModel({
    required this.key,
    required this.category,
    required String Function() name,
    required this.variants,
  }) : _nameBuilder = name;

  String get name => _nameBuilder();

  EquipmentVariant? variantForTransport(String? transportKey) {
    for (final variant in variants) {
      if (variant.transportKey == transportKey) return variant;
    }
    return null;
  }
}

/// A model bound to one of its transports — what a configured node points at,
/// and the whole of what [CatService] and the Station panel need to connect,
/// render an editor, or describe a row.
class EquipmentType {
  final EquipmentModel model;
  final EquipmentVariant variant;

  const EquipmentType(this.model, this.variant);

  String get key => variant.key;

  String get category => model.category;

  EquipmentDriver get driver => variant.driver;

  EquipmentTransport get transport => variant.transport;

  Map<String, dynamic> get defaultConfig => variant.defaultConfig;

  Map<String, dynamic> get overrides => variant.overrides;

  Map<String, dynamic> get restrictions => variant.restrictions;

  EquipmentDiscoverer? get discoverer => variant.discoverer;

  List<Map<String, dynamic>> get notes => variant.notes;

  String get transportKey => variant.transportKey;

  /// What the operator picked, spelled out in full: the radio and how it is
  /// reached. Composed rather than written per pairing, so adding a
  /// transport to a radio doesn't mean writing its name out again in every
  /// language.
  String get name => '${model.name} — $transportLabel';

  /// How this transport is described to the operator — "USB serial", not
  /// `serial`. Falls back to the raw key for a transport with no label,
  /// which is visible enough to get fixed rather than silently blank.
  String get transportLabel => transportLabelFor(transportKey) ?? transportKey;

  /// See [transportIconNameFor]. Null for a transport with no glyph, so the
  /// UI can leave the slot empty rather than draw a wrong one.
  String? get transportIconName => transportIconNameFor(transportKey);

  bool get hardwareVerified => variant.hardwareVerifiedOverride ?? driver.hardwareVerified;

  /// False for a pairing whose transport can't connect on this platform at
  /// all (TCP and Icom-network on web) — used to keep the Add dialog from
  /// offering a radio that would only fail loudly once picked.
  bool get isSupportedOnThisPlatform => transport.isSupportedOnThisPlatform;

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
    return variant.extraValidate?.call(config);
  }

  /// Null for equipment that doesn't announce itself.
  Stream<DiscoveredEquipment>? discover() => discoverer?.discover();

  /// Routes a `type: 'action'` element's press to the transport that
  /// declared it — see [EquipmentTransport.runAction]. Nothing here reads
  /// or applies [overrides] to the result: an action-driven field update
  /// (a newly-granted device's port) is exactly the kind of thing the
  /// operator just did, so it's never something a radio definition would
  /// want to override out from under them.
  Future<EquipmentActionResult?> runAction(String actionKey, String method, Map<String, dynamic> state) =>
      transport.runAction(actionKey, method, state);
}

/// The operator-facing name of a transport, by key. Kept here rather than on
/// [EquipmentTransport] because every transport is split across an io/stub
/// (and for serial, web) pair, and a display string is the one thing that
/// genuinely does not vary between them.
///
/// Null for an unregistered key rather than a guess — see
/// [EquipmentType.transportLabel].
String? transportLabelFor(String transportKey) {
  final labels = t.settings.station.transports;
  return switch (transportKey) {
    TcpTransport.transportKey => labels.network,
    SerialTransport.transportKey => labels.usbSerial,
    IcomNetworkTransport.transportKey => labels.wifi,
    _ => null,
  };
}

/// The glyph for a transport, as a kebab-case name for `resolveIconName` —
/// a plain string, so this layer still holds no Flutter types, the same way
/// `configElements` describes fields without importing halo_widgets.
///
/// One concept per kind of connection rather than one per transport: two
/// transports reaching the same radio over the same wire should look alike,
/// because what the operator is choosing between is how it is *plugged in*,
/// not which protocol is spoken over it. A Bluetooth transport would add a
/// third here; there is no case for one until there is a transport.
///
/// The names must exist in halo_widgets' generated codepoint table:
/// `resolveIconName` answers an unknown name with a puzzle-piece glyph and
/// no error at all, so a typo here ships silently.
String? transportIconNameFor(String transportKey) => switch (transportKey) {
      SerialTransport.transportKey => 'usb-port',
      TcpTransport.transportKey || IcomNetworkTransport.transportKey => 'wifi',
      _ => null,
    };

const _flexRadioTcpKey = 'flexradio-tcp';
const _flrigTcpKey = 'flrig-tcp';
const _rigctldTcpKey = 'rigctld-tcp';
const _ft891SerialKey = 'ft891-serial';
const _icomGenericSerialKey = 'icom-generic-serial';
const _yaesuSerialKey = 'yaesu-serial';
const _kenwoodSerialKey = 'kenwood-serial';
const _ic705NetworkKey = 'ic705-network';
const _ic705SerialKey = 'ic705-serial';

/// FlexRadio radios reachable over the SmartSDR TCP API.
///
/// Found automatically: a Flex announces itself over UDP broadcast on 4992.
/// Address and port can always be typed in as well — a radio on another
/// subnet, or behind a router that doesn't forward broadcasts, never
/// announces, and neither app-polo branch had a manual path at all.
const flexRadioModel = EquipmentModel(
  key: 'flexradio',
  category: kCategoryTransceiver,
  name: _flexRadioName,
  variants: [
    EquipmentVariant(
      key: _flexRadioTcpKey,
      driver: FlexRadioDriver(),
      transport: TcpTransport(),
      defaultConfig: {'port': FlexRadioDriver.defaultPort},
      discoverer: FlexRadioDiscoverer(typeKey: _flexRadioTcpKey),
    ),
  ],
);

String _flexRadioName() => t.settings.station.models.flexRadio;

/// Any radio Hamlib has a backend for, through a `rigctld` daemon the
/// operator already runs — the app connects to the daemon, never to the
/// radio. No discoverer: rigctld announces nothing, so it is always typed
/// in by address, defaulting to the same machine.
const rigctldModel = EquipmentModel(
  key: 'rigctld',
  category: kCategoryTransceiver,
  name: _rigctldName,
  variants: [
    EquipmentVariant(
      key: _rigctldTcpKey,
      driver: RigctldDriver(),
      transport: TcpTransport(),
      defaultConfig: {'host': '127.0.0.1', 'port': RigctldDriver.defaultPort},
      // The failure this pairing actually produces is a refused or
      // unanswered connection, and every cause lives outside the app: the
      // daemon isn't running, is listening only on localhost, or is on
      // another port.
      notes: _rigctldTcpNotes,
    ),
  ],
);

String _rigctldName() => t.settings.station.models.rigctld;

List<Map<String, dynamic>> _rigctldTcpNotes() => [
      {
        'type': 'markdown',
        'collapsible': true,
        'title': t.settings.station.troubleshootingNotes,
        'text': '**${t.settings.station.rigctldTroubleshootingTitle}**\n\n'
            '${t.settings.station.rigctldTroubleshooting}',
      },
    ];

/// Any radio flrig has a definition for, through an flrig instance the
/// operator already runs — the app connects to flrig's XML-RPC server,
/// never to the radio. No discoverer: flrig announces nothing, so it is
/// always typed in by address, defaulting to the same machine.
const flrigModel = EquipmentModel(
  key: 'flrig',
  category: kCategoryTransceiver,
  name: _flrigName,
  variants: [
    EquipmentVariant(
      key: _flrigTcpKey,
      driver: FlrigDriver(),
      transport: TcpTransport(),
      defaultConfig: {'host': '127.0.0.1', 'port': FlrigDriver.defaultPort},
      // The failure this pairing actually produces is a refused or
      // unanswered connection, and every cause lives outside the app: flrig
      // isn't running, its server is on another port, or it can't reach the
      // radio.
      notes: _flrigTcpNotes,
    ),
  ],
);

String _flrigName() => t.settings.station.models.flrig;

List<Map<String, dynamic>> _flrigTcpNotes() => [
      {
        'type': 'markdown',
        'collapsible': true,
        'title': t.settings.station.troubleshootingNotes,
        'text': '**${t.settings.station.flrigTroubleshootingTitle}**\n\n'
            '${t.settings.station.flrigTroubleshooting}',
      },
    ];

/// Yaesu FT-891 over its built-in USB-to-serial CAT bridge.
///
/// Baud is the operator's to set, deliberately. app-polo hardcoded 4800 with
/// no UI, which its own notes call out as a silent-failure mode: a radio
/// whose CAT menu says 38400 answers with garbage and no error at all.
const ft891Model = EquipmentModel(
  key: 'ft891',
  category: kCategoryTransceiver,
  name: _ft891Name,
  variants: [
    EquipmentVariant(
      key: _ft891SerialKey,
      driver: Ft891Driver(),
      transport: SerialTransport(),
      defaultConfig: {'baudRate': Ft891Driver.defaultBaudRate},
      // The failure this driver actually produces is silence: the commands
      // go out, nothing comes back, and nothing anywhere reports an error.
      // Every cause is a setting the operator has to change on the radio or
      // elsewhere on the machine, so the editor is where it is worth saying
      // — by the time the row says "Connected" with no frequency, this form
      // is exactly where they will come looking.
      notes: _ft891SerialNotes,
    ),
  ],
);

String _ft891Name() => t.settings.station.models.ft891;

List<Map<String, dynamic>> _ft891SerialNotes() => [
      {
        'type': 'markdown',
        'collapsible': true,
        'title': t.settings.station.troubleshootingNotes,
        'text': '**${t.settings.station.troubleshootingTitle}**\n\n'
            '${t.settings.station.ft891Troubleshooting}',
      },
    ];

/// Any Yaesu speaking CAT over a serial port — the entry for a radio with no
/// definition of its own.
///
/// Shares [Ft891Driver], and that is the honest arrangement rather than a
/// shortcut: Yaesu CAT is one ASCII protocol across the line, the codec was
/// always generic (`yaesu_cat_codec.dart`), and the class is named after the
/// single radio it has been proven against, not after what it can talk to.
///
/// The one place the line genuinely diverges is the MODE table, which is the
/// FT-891's — so a radio numbering its modes differently reports and sets the
/// wrong one for those, while the frequency stays right. That is what the
/// notes say, and it is why this pairing ships unverified even though the
/// driver under it is not.
const yaesuGenericModel = EquipmentModel(
  key: 'yaesu-generic',
  category: kCategoryTransceiver,
  name: _yaesuGenericName,
  variants: [
    EquipmentVariant(
      key: _yaesuSerialKey,
      driver: Ft891Driver(),
      transport: SerialTransport(),
      // The FT-891's factory rate. Every Yaesu CAT menu offers it, and it is
      // the one a radio nobody has configured is most likely already on.
      defaultConfig: {'baudRate': Ft891Driver.defaultBaudRate},
      hardwareVerifiedOverride: false,
      notes: _yaesuSerialNotes,
    ),
  ],
);

String _yaesuGenericName() => t.settings.station.models.yaesuGeneric;

List<Map<String, dynamic>> _yaesuSerialNotes() => [
      {
        'type': 'markdown',
        'collapsible': true,
        'title': t.settings.station.troubleshootingNotes,
        'text': '**${t.settings.station.yaesuTroubleshootingTitle}**\n\n'
            '${t.settings.station.yaesuTroubleshooting}',
      },
    ];

/// Any radio speaking Kenwood CAT over a serial port — the Kenwood line, and
/// equally the Elecraft rigs and SDR front-ends that implement the same
/// protocol.
///
/// NEVER RUN AGAINST A RADIO: written from published CAT references rather
/// than a capture, which is exactly what `hardwareVerified: false` is for.
/// The one field those references disagree about — where the mode sits inside
/// the `IF` status packet — is learned from the radio at runtime instead of
/// assumed, because a wrong offset would report a plausible wrong mode
/// forever rather than failing. See kenwood_driver.dart.
const kenwoodGenericModel = EquipmentModel(
  key: 'kenwood-generic',
  category: kCategoryTransceiver,
  name: _kenwoodGenericName,
  variants: [
    EquipmentVariant(
      key: _kenwoodSerialKey,
      driver: KenwoodDriver(),
      transport: SerialTransport(),
      defaultConfig: {'baudRate': KenwoodDriver.defaultBaudRate},
      notes: _kenwoodSerialNotes,
    ),
  ],
);

String _kenwoodGenericName() => t.settings.station.models.kenwoodGeneric;

List<Map<String, dynamic>> _kenwoodSerialNotes() => [
      {
        'type': 'markdown',
        'collapsible': true,
        'title': t.settings.station.troubleshootingNotes,
        'text': '**${t.settings.station.kenwoodTroubleshootingTitle}**\n\n'
            '${t.settings.station.kenwoodTroubleshooting}',
      },
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
/// exactly what [EquipmentVariant.hardwareVerifiedOverride] is for.
const icomGenericModel = EquipmentModel(
  key: 'icom-generic',
  category: kCategoryTransceiver,
  name: _icomGenericName,
  variants: [
    EquipmentVariant(
      key: _icomGenericSerialKey,
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
      notes: _icomGenericSerialNotes,
    ),
  ],
);

String _icomGenericName() => t.settings.station.models.icomGeneric;

List<Map<String, dynamic>> _icomGenericSerialNotes() => [
      {
        'type': 'markdown',
        'collapsible': true,
        'title': t.settings.station.troubleshootingNotes,
        'text': '**${t.settings.station.icomCivTroubleshootingTitle}**\n\n'
            '${t.settings.station.icomCivTroubleshooting}',
      },
    ];

/// An IC-705 over WiFi, using Icom's RS-BA1 network protocol.
///
/// Both the CI-V address and the controller address are hardcoded rather
/// than asked for: RS-BA1 only ever talks to the one radio it's paired
/// with, at the IC-705's factory address, and the controller side of a
/// network CI-V exchange is always 0xE1 — a fact about the transport, not a
/// setting, so it never becomes a question in the editor.
///
/// Over USB it is a generic CI-V rig, and [icomGenericModel] would connect it —
/// but only for an operator who already knows their radio speaks CI-V. Named
/// here too, it is found the way it is looked for: by the name on the front
/// of the radio, with the cable as the second question.
const ic705Model = EquipmentModel(
  key: 'ic705',
  category: kCategoryTransceiver,
  name: _ic705Name,
  // WiFi first: the editor opens on a model's first variant, and this is the
  // one proven against a real radio.
  variants: [
    EquipmentVariant(
      key: _ic705NetworkKey,
      driver: IcomCivDriver(),
      transport: IcomNetworkTransport(),
      overrides: {
        'civAddress': 'A4',
        'civControllerAddress': icomNetworkControllerAddress,
      },
      // The failure this transport actually produces is silence: the
      // handshake succeeds and the login is ignored, so a busy radio and a
      // refusal are indistinguishable from here. Every remedy is something
      // the operator does at the radio or to another program.
      notes: _ic705NetworkNotes,
    ),
    EquipmentVariant(
      key: _ic705SerialKey,
      driver: IcomCivDriver(),
      transport: SerialTransport(),
      // The address is the radio's factory setting rather than a fixed fact
      // about it — CI-V ADDRESS is in the IC-705's own menu, and a radio
      // sharing a bus is exactly where it gets changed. So a default here,
      // unlike the network variant's override, where the RS-BA1 protocol
      // really does fix it.
      defaultConfig: {'civAddress': 'A4', 'baudRate': 19200},
      // Same driver, same transport, same untested pairing as the generic
      // CI-V serial entry.
      hardwareVerifiedOverride: false,
      notes: _icomGenericSerialNotes,
    ),
  ],
);

String _ic705Name() => t.settings.station.models.ic705;

List<Map<String, dynamic>> _ic705NetworkNotes() => [
      {
        'type': 'markdown',
        'collapsible': true,
        'title': t.settings.station.troubleshootingNotes,
        'text': '**${t.settings.station.ic705TroubleshootingTitle}**\n\n'
            '${t.settings.station.ic705Troubleshooting}',
      },
    ];

/// What the app can talk to, and how it gets there.
///
/// A plain Dart list today. When extensions can contribute rig definitions
/// this gains a second source and merges them, the way [SettingsView]
/// already merges Dart settings groups with extension-contributed panels.
class EquipmentRegistry {
  final List<EquipmentModel> models;
  final Map<String, EquipmentTransport> transports;

  /// One per variant of every model, in model order — the flat view
  /// [CatService] resolves a node's stored `typeKey` against. Derived, so a
  /// model and its pairings can never disagree about which variants exist.
  final List<EquipmentType> types;

  EquipmentRegistry({List<EquipmentModel>? models, Map<String, EquipmentTransport>? transports})
      : models = models ?? const [
          flexRadioModel,
          ft891Model,
          yaesuGenericModel,
          ic705Model,
          icomGenericModel,
          kenwoodGenericModel,
          rigctldModel,
          flrigModel,
        ],
        types = [
          for (final model
              in models ?? const [
          flexRadioModel,
          ft891Model,
          yaesuGenericModel,
          ic705Model,
          icomGenericModel,
          kenwoodGenericModel,
          rigctldModel,
          flrigModel,
        ])
            for (final variant in model.variants) EquipmentType(model, variant),
        ],
        transports = transports ??
            {
              TcpTransport.transportKey: const TcpTransport(),
              SerialTransport.transportKey: const SerialTransport(),
              IcomNetworkTransport.transportKey: const IcomNetworkTransport(),
            };

  /// Every config key that is a credential for ANY pairing in the catalogue.
  ///
  /// "May this value go in the plain prefs blob?" has to be asked of the whole
  /// catalogue rather than of the node's own pairing, because the editor
  /// renders every variant's fields at once: a node bound to a transport with
  /// no secrets of its own can still be handed the password belonging to the
  /// transport beside it, and scoping the check to its own pairing writes that
  /// password to disk in clear.
  ///
  /// The opposite question — "what does THIS connection need?" — is still the
  /// pairing's, and [EquipmentType.secretFields] answers it.
  late final Set<String> allSecretFields = {
    for (final type in types) ...type.secretFields,
  };

  EquipmentType? typeFor(String? key) {
    for (final type in types) {
      if (type.key == key) return type;
    }
    return null;
  }

  EquipmentModel? modelFor(String? key) {
    for (final model in models) {
      if (model.key == key) return model;
    }
    return null;
  }

  /// The resolved pairing for one of [model]'s own variants. Null when the
  /// model has no variant on that transport — the editor's transport picker
  /// only ever offers transports the model declares, so this is a
  /// programming error rather than a user-reachable state.
  EquipmentType? typeForModelTransport(EquipmentModel model, String transportKey) {
    final variant = model.variantForTransport(transportKey);
    return variant == null ? null : typeFor(variant.key);
  }

  EquipmentTransport? transportFor(String? key) => key == null ? null : transports[key];
}
