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

import 'package:halo_i18n/halo_i18n.dart';
import 'discovery.dart';
import 'driver.dart';
import 'drivers/antenna_driver.dart';
import 'drivers/antenna_genius_driver.dart';
import 'drivers/placeholder_radio_driver.dart';
import 'drivers/winkeyer_driver.dart';
import 'drivers/flexradio_driver.dart';
import 'drivers/guohetec_driver.dart';
import 'drivers/ft891_driver.dart';
import 'drivers/meter_calibration.dart';
import 'drivers/icom_civ_driver.dart';
import 'drivers/civ_codec.dart' show civVoiceMemoryCount;
import 'drivers/kenwood_cat_codec.dart' show kxVoiceMemoryCount;
import 'drivers/yaesu_cat_codec.dart' show yaesuVoiceMemoryCount;
import 'drivers/yaesu_binary_driver.dart';
import 'drivers/kenwood_driver.dart';
import 'drivers/key_driver.dart';
import 'drivers/sierra_coax_driver.dart';
import 'equipment.dart';
import 'equipment_brands.dart';
import 'equipment_bridges.dart';
import 'transport.dart';
import 'transports/placeholder_transport.dart';
import 'transports/icom_network_protocol.dart';
import 'transports/icom_network_transport.dart';
import 'transports/none_transport.dart';
import 'transports/serial_transport.dart';
import 'transports/tcp_transport.dart';

/// One way of reaching a model — everything that differs between the same
/// radio's serial and network entries.
///
/// That list is longer than it looks: for the IC-705, the driver's overrides,
/// the prefilled defaults and the troubleshooting notes all differ between
/// its two transports, and a pairing's hardware-verified status can too.
/// Hoisting any of them onto the model would be wrong for the one radio that
/// has two variants today.
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

  /// Who makes it. Null only where the model is named after a protocol or a
  /// program rather than a maker — the bridges, and the placeholder rig.
  /// Every real make declares it, family generics included:
  /// [elecraftGenericModel] rides the Kenwood driver and would otherwise
  /// file itself as a Kenwood.
  ///
  /// Read by two things, and the second is why a generic cannot leave it
  /// blank. The equipment report's prefill otherwise derives a manufacturer
  /// from the driver's name, which is right whenever the protocol family IS
  /// the brand and wrong the moment it is not — a QMX on the Kenwood driver
  /// would arrive labelled "Kenwood". The Add dialog shelves its catalogue by
  /// this value against [featuredBrands], matched EXACTLY: anything else,
  /// blank included, lands under "Other Brands".
  ///
  /// Not localized: a brand is spelled the same in every language.
  final String? manufacturer;

  /// True for a model that is a nameless category node rather than something
  /// to pick from a catalogue of makes and models — [antennaModel] and
  /// [keyModel] today. The Add dialog's searchable list excludes these; they
  /// are offered only from its "Other Equipment" rows, under whatever name
  /// the operator gives the resulting node. A real antenna switch or
  /// automatic keyer added later belongs in the searchable list like any
  /// other radio, so it leaves this false.
  final bool hiddenFromCatalog;

  /// How to record a voice memory on THIS radio, where the CAT command is
  /// only half the procedure — the FT-891 wants the operator on PTT while
  /// the DVS records, which no protocol can express and no operator can
  /// guess. Shown in the memory's dialog, beside Record. Null where the
  /// radio needs no explanation, which is most of them.
  ///
  /// On the MODEL rather than the driver: it describes a radio's front
  /// panel, and one driver serves a whole line of them. A closure for the
  /// same live-locale reason as [_nameBuilder].
  final String Function()? _recordingHelpBuilder;

  String? get recordingHelp => _recordingHelpBuilder?.call();

  /// What to call a NEW node of this model, when that is not the model's own
  /// name. Only for a model whose catalogue name is a description rather
  /// than something an operator would call their rig: the placeholder's
  /// name has to carry "(no control)" in the picker, and nobody wants that
  /// spelled across their station panel afterwards. A closure for the same
  /// live-locale reason as [_nameBuilder].
  final String Function()? _suggestedNameBuilder;

  const EquipmentModel({
    required this.key,
    required this.category,
    required String Function() name,
    required this.variants,
    String Function()? suggestedName,
    String Function()? recordingHelp,
    this.manufacturer,
    this.hiddenFromCatalog = false,
  })  : _nameBuilder = name,
        _recordingHelpBuilder = recordingHelp,
        _suggestedNameBuilder = suggestedName;

  String get name => _nameBuilder();

  /// The name a new node of this model starts with — [name] unless the model
  /// says otherwise.
  String get suggestedName => (_suggestedNameBuilder ?? _nameBuilder)();

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

  String? get manufacturer => model.manufacturer;

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

  /// Which meters a node on this pairing can show — the driver's answer for
  /// the MERGED config, so the entry's own overrides (the calibration file
  /// it names) are part of the question.
  ///
  /// Through the type rather than reaching for the driver directly: a caller
  /// holding a node has its stored config, not the merged one, and asking
  /// the driver with the stored map would leave a named radio looking like a
  /// generic one.
  Set<RadioMeter> telemetryMetersFor(Map<String, dynamic> config) =>
      driver.telemetryMetersWith(_merged(config));

  /// The meter cadence a node on this pairing falls back to — again for the
  /// MERGED config, so the speed prefilled by the entry counts even when the
  /// operator has never opened the box.
  Duration defaultTelemetryIntervalFor(Map<String, dynamic> config) =>
      driver.defaultTelemetryInterval(_merged(config));

  /// A one-line "where is it" for the equipment list.
  ///
  /// The CHANNEL is deliberately not in it — see [describeChannel]. A slice
  /// is not part of an address, and a row that ran the two together clipped
  /// to "…Slice A" in a narrow column, naming the one part the operator
  /// could have guessed.
  String describeTarget(Map<String, dynamic> config) {
    final merged = _merged(config);
    final suffix = describeChannel(config) != null ? '' : (driver.describeSuffix(merged, overrides: overrides) ?? '');
    return '${transport.describeTarget(merged)}$suffix';
  }

  /// Which channel of a multi-channel radio this node is — see
  /// [EquipmentDriver.describeChannel].
  String? describeChannel(Map<String, dynamic> config) =>
      driver.describeChannel(_merged(config), overrides: overrides);

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
    PlaceholderTransport.transportKey => labels.simulated,
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
      // Not a way of plugging anything in — the exception the rule above
      // allows for, because what this transport connects to is nothing.
      PlaceholderTransport.transportKey => 'flask-outline',
      _ => null,
    };

const _flexRadioTcpKey = 'flexradio-tcp';
const _ft891SerialKey = 'ft891-serial';
const _ft710SerialKey = 'ft710-serial';
const _ftdx10SerialKey = 'ftdx10-serial';
const _icomGenericSerialKey = 'icom-generic-serial';
const _yaesuSerialKey = 'yaesu-serial';
const _ft817SerialKey = 'ft817-serial';
const _ft857SerialKey = 'ft857-serial';
const _ft897SerialKey = 'ft897-serial';
const _q900SerialKey = 'q900-serial';
const _kenwoodSerialKey = 'kenwood-serial';
const _qmxSerialKey = 'qmx-serial';
const _fx4crSerialKey = 'fx4cr-serial';
const _elecraftSerialKey = 'elecraft-serial';
const _kx2SerialKey = 'kx2-serial';
const _kx3SerialKey = 'kx3-serial';
const _ic7300SerialKey = 'ic7300-serial';
const _ic7300mk2SerialKey = 'ic7300mk2-serial';
const _ic706mkiigSerialKey = 'ic706mkiig-serial';
const _ic7100SerialKey = 'ic7100-serial';
const _ic7610SerialKey = 'ic7610-serial';
const _ic7760SerialKey = 'ic7760-serial';
const _x6100SerialKey = 'x6100-serial';
const _ic705NetworkKey = 'ic705-network';
const _ic705SerialKey = 'ic705-serial';
const _placeholderRadioKey = 'placeholder-radio';
const _winkeyerSerialKey = 'winkeyer-serial';
const _antennaGeniusTcpKey = 'antenna-genius-tcp';
const _sierraCoaxSerialKey = 'sierra-coax-serial';

/// FlexRadio radios reachable over the SmartSDR TCP API.
///
/// Found automatically: a Flex announces itself over UDP broadcast on 4992.
/// Address and port can always be typed in as well — a radio on another
/// subnet, or behind a router that doesn't forward broadcasts, never
/// announces, and neither app-polo branch had a manual path at all.
const flexRadioModel = EquipmentModel(
  key: 'flexradio',
  manufacturer: flexBrand,
  category: kCategoryTransceiver,
  name: _flexRadioName,
  variants: [
    EquipmentVariant(
      key: _flexRadioTcpKey,
      driver: FlexRadioDriver(),
      transport: TcpTransport(),
      defaultConfig: {'port': FlexRadioDriver.defaultPort, FlexRadioDriver.sliceConfigKey: '0'},
      discoverer: FlexRadioDiscoverer(typeKey: _flexRadioTcpKey),
    ),
  ],
);

String _flexRadioName() => t.settings.station.models.flexRadio;

/// Yaesu FT-891 over its built-in USB-to-serial CAT bridge.
///
/// Baud is the operator's to set, deliberately. app-polo hardcoded 4800 with
/// no UI, which its own notes call out as a silent-failure mode: a radio
/// whose CAT menu says 38400 answers with garbage and no error at all.
const ft891Model = EquipmentModel(
  key: 'ft891',
  manufacturer: yaesuBrand,
  category: kCategoryTransceiver,
  name: _ft891Name,
  // `LM0n;` arms the DVS, but the audio comes off the microphone with the
  // operator on PTT — half the procedure is on the front panel, and nothing
  // in CAT can say so.
  recordingHelp: _ft891RecordingHelp,
  variants: [
    EquipmentVariant(
      key: _ft891SerialKey,
      driver: Ft891Driver(),
      transport: SerialTransport(),
      defaultConfig: {'baudRate': Ft891Driver.defaultBaudRate},
      // What the entry knows about the radio's keyers — the generic entry
      // asks a developer instead (keyer_config.dart). Twenty seconds a
      // memory, per the Advance Manual.
      // The meter scales, which Yaesu publishes nowhere — see
      // drivers/info/README.md. Named per ENTRY rather than per driver
      // because one driver serves the whole line and the scales do not.
      overrides: {
        cwKeyerConfigKey: true,
        voiceMemoriesConfigKey: yaesuVoiceMemoryCount,
        voiceCeilingConfigKey: 20,
        meterInfoConfigKey: 'yaesu/ft-891',
      },
      restrictions: {'port': Ft891Driver.cp2105CatPort},
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

String _ft891RecordingHelp() => t.settings.radio.voiceMessages.recordHelpFt891;
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

/// Yaesu FT-710 over its built-in USB CAT port.
///
/// [Ft891Driver] is the Yaesu CAT driver rather than an FT-891-only one (see
/// [yaesuGenericModel]), and this radio is what proves it: the 710 has been
/// run here under the FT-891's own entry. It gets a name of its own so it is
/// found by what is written on the front of the radio, and so the speed it
/// actually ships on is the one prefilled.
const ft710Model = EquipmentModel(
  key: 'ft710',
  manufacturer: yaesuBrand,
  category: kCategoryTransceiver,
  name: _ft710Name,
  recordingHelp: _yaesuDvsRecordingHelp,
  variants: [
    EquipmentVariant(
      key: _ft710SerialKey,
      driver: Ft891Driver(),
      transport: SerialTransport(),
      // The radio's own CAT RATE default, unlike the FT-891's 4800.
      defaultConfig: {'baudRate': 38400},
      overrides: {
        cwKeyerConfigKey: true,
        voiceMemoriesConfigKey: yaesuVoiceMemoryCount,
        meterInfoConfigKey: 'yaesu/ft-710',
      },
    ),
  ],
);

String _ft710Name() => t.settings.station.models.ft710;

/// Yaesu FTDX10 over its built-in USB CAT port. Same driver and the same
/// reasoning as [ft710Model].
const ftdx10Model = EquipmentModel(
  key: 'ftdx10',
  manufacturer: yaesuBrand,
  category: kCategoryTransceiver,
  name: _ftdx10Name,
  recordingHelp: _yaesuDvsRecordingHelp,
  variants: [
    EquipmentVariant(
      key: _ftdx10SerialKey,
      driver: Ft891Driver(),
      transport: SerialTransport(),
      defaultConfig: {'baudRate': 38400},
      // Ninety seconds a memory, on the SD card, per the Operation Manual.
      overrides: {
        cwKeyerConfigKey: true,
        voiceMemoriesConfigKey: yaesuVoiceMemoryCount,
        voiceCeilingConfigKey: 90,
        meterInfoConfigKey: 'yaesu/ftdx10',
      },
      restrictions: {'port': Ft891Driver.cp2105CatPort},
    ),
  ],
);

String _ftdx10Name() => t.settings.station.models.ftdx10;

/// Yaesu FT-817, FT-817ND and FT-818 over their CAT jack.
///
/// A different protocol from every other Yaesu in this catalogue
/// ([YaesuBinaryDriver]): five binary bytes per command, no framing, and no
/// auto-information, so a dial turn is only ever seen by polling. Written
/// from Yaesu's own CAT chart and run against no radio, which is what
/// [YaesuBinaryDriver.hardwareVerified] says.
///
/// One entry for all three because CAT does not distinguish them — the ND
/// and the 818 answer the same chart the original does.
const ft817Model = EquipmentModel(
  key: 'ft817',
  manufacturer: yaesuBrand,
  category: kCategoryTransceiver,
  name: _ft817Name,
  variants: [
    EquipmentVariant(
      key: _ft817SerialKey,
      driver: YaesuBinaryDriver(),
      transport: SerialTransport(),
      defaultConfig: {'baudRate': yaesuBinaryDefaultBaudRate},
      // The failure this driver produces is silence, and every cause is a
      // setting or a cable outside the app — so the editor, which is where
      // an operator with a connected row and no frequency will come
      // looking, is where it is worth saying.
      notes: _yaesuBinarySerialNotes,
    ),
  ],
);

String _ft817Name() => t.settings.station.models.ft817;

/// Yaesu FT-857 and FT-857D, on the same protocol and driver as
/// [ft817Model].
///
/// Its own entry rather than a line in the 817's notes because of
/// [yaesuBinaryNarrowFmConfigKey]: this radio takes a narrow-FM set code the
/// FT-817 has no parameter for, and a radio told to use one it does not have
/// changes mode to something nobody asked for.
const ft857Model = EquipmentModel(
  key: 'ft857',
  manufacturer: yaesuBrand,
  category: kCategoryTransceiver,
  name: _ft857Name,
  variants: [
    EquipmentVariant(
      key: _ft857SerialKey,
      driver: YaesuBinaryDriver(),
      transport: SerialTransport(),
      defaultConfig: {'baudRate': yaesuBinaryDefaultBaudRate},
      overrides: {yaesuBinaryNarrowFmConfigKey: true},
      notes: _yaesuBinarySerialNotes,
    ),
  ],
);

String _ft857Name() => t.settings.station.models.ft857;

/// Yaesu FT-897 and FT-897D. Same protocol, driver and narrow-FM code as
/// [ft857Model].
const ft897Model = EquipmentModel(
  key: 'ft897',
  manufacturer: yaesuBrand,
  category: kCategoryTransceiver,
  name: _ft897Name,
  variants: [
    EquipmentVariant(
      key: _ft897SerialKey,
      driver: YaesuBinaryDriver(),
      transport: SerialTransport(),
      defaultConfig: {'baudRate': yaesuBinaryDefaultBaudRate},
      overrides: {yaesuBinaryNarrowFmConfigKey: true},
      notes: _yaesuBinarySerialNotes,
    ),
  ],
);

String _ft897Name() => t.settings.station.models.ft897;

/// Guohetec Q900, over the USB-C cable that also carries its sound card.
///
/// Its own protocol ([GuohetecDriver]), NOT the FT-817 imitation the radio
/// also answers and its manual points people at. The imitation is
/// undocumented and partial, and it shares a port with the native protocol,
/// which is a bad place for the FT-817's unframed five-byte commands: any
/// packet the emulation does not account for desynchronises them and the
/// operator sees a connected radio with no frequency. The native protocol
/// is framed and checksummed, and answers more — both VFOs, both modes and
/// the transmit state in one exchange.
///
/// The PMR-171 speaks the same protocol and gets its own entry once someone
/// can test one; nothing here is Q900-specific except the name.
///
/// Written from the manufacturer's published protocol and run against no
/// radio, which is what [GuohetecDriver.hardwareVerified] says.
const q900Model = EquipmentModel(
  key: 'q900',
  manufacturer: 'Guohetec',
  category: kCategoryTransceiver,
  name: _q900Name,
  variants: [
    EquipmentVariant(
      key: _q900SerialKey,
      driver: GuohetecDriver(),
      transport: SerialTransport(),
      // The radio presents a USB CDC port, which ignores the rate — this
      // matters only on its RS232 jack or a Bluetooth SPP bridge.
      defaultConfig: {'baudRate': guohetecDefaultBaudRate},
      notes: _guohetecSerialNotes,
    ),
  ],
);

String _q900Name() => t.settings.station.models.q900;

List<Map<String, dynamic>> _guohetecSerialNotes() => [
      {
        'type': 'markdown',
        'collapsible': true,
        'title': t.settings.station.troubleshootingNotes,
        'text': '**${t.settings.station.guohetecTroubleshootingTitle}**\n\n'
            '${t.settings.station.guohetecTroubleshooting}',
      },
    ];

List<Map<String, dynamic>> _yaesuBinarySerialNotes() => [
      {
        'type': 'markdown',
        'collapsible': true,
        'title': t.settings.station.troubleshootingNotes,
        'text': '**${t.settings.station.yaesuBinaryTroubleshootingTitle}**\n\n'
            '${t.settings.station.yaesuBinaryTroubleshooting}',
      },
    ];

/// Shared by the FTDX10 and the FT-710: the same DVS procedure, and one
/// string rather than two copies that can drift apart in translation. The
/// FT-891's is its own — that radio wants its REC indicator counted through
/// four blinks first, where these two only wait for it to appear.
String _yaesuDvsRecordingHelp() => t.settings.radio.voiceMessages.recordHelpYaesuDvs;

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
/// wrong one for those, while the frequency stays right. The notes say so,
/// and that caveat outlives the pairing being proven: what a proven radio
/// proves is the protocol, never another radio's mode table.
const yaesuGenericModel = EquipmentModel(
  key: 'yaesu-generic',
  manufacturer: yaesuBrand,
  category: kCategoryTransceiver,
  name: _yaesuGenericName,
  variants: [
    EquipmentVariant(
      key: _yaesuSerialKey,
      driver: Ft891Driver(),
      transport: SerialTransport(),
      // The FT-891's factory rate. Every Yaesu CAT menu offers it, and it is
      // the one a radio nobody has configured is most likely already on.
      // Off until a developer says otherwise: the catalogue does not know
      // which Yaesu this is, and a rig with no keyer must not be offered
      // as one (keyer_config.dart).
      defaultConfig: {'baudRate': Ft891Driver.defaultBaudRate, cwKeyerConfigKey: false, voiceMemoriesConfigKey: 0},
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
/// equally the SDR front-ends that implement the same protocol. Elecraft is
/// named separately ([elecraftGenericModel]), because that line answers at a
/// rate this one's default would miss.
///
/// Written from published CAT references rather than from a capture, and
/// proven since against a QRP Labs QMX (see [qmxModel]) and an Elecraft KX2
/// and KX3 (see [kx2Model]) — but against no Kenwood-branded radio, which is
/// where those references still carry the risk. The one field they disagree
/// about — where the mode sits inside the `IF` status packet — is learned
/// from the radio at runtime instead of assumed, because a wrong offset would
/// report a plausible wrong mode forever rather than failing. See
/// kenwood_driver.dart.
const kenwoodGenericModel = EquipmentModel(
  key: 'kenwood-generic',
  manufacturer: kenwoodBrand,
  category: kCategoryTransceiver,
  name: _kenwoodGenericName,
  variants: [
    EquipmentVariant(
      key: _kenwoodSerialKey,
      driver: KenwoodDriver(),
      transport: SerialTransport(),
      // No keyer until a developer names a dialect: the line disagrees on
      // both (`KY` padded or not, `PB` with a list to open or not), and
      // the catalogue does not know which Kenwood this is.
      defaultConfig: {'baudRate': KenwoodDriver.defaultBaudRate, voiceMemoriesConfigKey: 0},
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

/// QRP Labs QMX, which speaks Kenwood CAT over its USB serial port.
///
/// Pins the `IF` mode offset [KenwoodDriver] would otherwise spend the first
/// seconds of every connection learning — this radio's layout is known. The
/// session still checks it against the radio, so a wrong entry here is caught
/// rather than believed.
const qmxModel = EquipmentModel(
  key: 'qmx',
  manufacturer: 'QRP Labs',
  category: kCategoryTransceiver,
  name: _qmxName,
  variants: [
    EquipmentVariant(
      key: _qmxSerialKey,
      driver: KenwoodDriver(),
      transport: SerialTransport(),
      defaultConfig: {'baudRate': KenwoodDriver.defaultBaudRate},
      overrides: {
        KenwoodDriver.ifModeOffsetKey: 27,
        // hamlib keys a QMX through the Elecraft-shaped `KY`, but no QRP
        // Labs document says so, and it has no voice memories.
        KenwoodDriver.cwDialectKey: '',
        KenwoodDriver.voiceDialectKey: '',
        KenwoodDriver.voiceMemoriesKey: 0,
      },
      notes: _kenwoodSerialNotes,
    ),
  ],
);

String _qmxName() => t.settings.station.models.qmx;

/// BG2FX FX-4CR, which speaks Kenwood CAT over its USB serial port.
///
/// Its own entry rather than a line in the Kenwood generic's notes because
/// the brand gives away the protocol no more than the QMX's does, and
/// because a hardware report would otherwise file this radio under Kenwood.
///
/// Everything but the rate is the QMX's, which is where the entry comes
/// from — operators run this radio on [qmxModel] and it answers, so the `IF`
/// layout is the one pinned there. No QRP-Labs-style keyer either: nothing
/// published names a dialect for this radio, and it has no voice memories.
///
/// The rate is the one field no report establishes: those operators were on
/// the QMX entry's 9600 unless they changed it. A mismatch here is answered
/// with silence rather than an error, which is why it sits in the prefill
/// the operator can change and not in the overrides they cannot.
const fx4crModel = EquipmentModel(
  key: 'fx4cr',
  manufacturer: 'BG2FX',
  category: kCategoryTransceiver,
  name: _fx4crName,
  variants: [
    EquipmentVariant(
      key: _fx4crSerialKey,
      driver: KenwoodDriver(),
      transport: SerialTransport(),
      defaultConfig: {'baudRate': 115200},
      overrides: {
        KenwoodDriver.ifModeOffsetKey: 27,
        KenwoodDriver.cwDialectKey: '',
        KenwoodDriver.voiceDialectKey: '',
        KenwoodDriver.voiceMemoriesKey: 0,
      },
      notes: _kenwoodSerialNotes,
    ),
  ],
);

String _fx4crName() => t.settings.station.models.fx4cr;

/// Any Elecraft transceiver over its serial port — the K3 and K4 as much as
/// the KX2 and KX3, which have entries of their own below.
///
/// Elecraft speaks Kenwood CAT, so this shares [KenwoodDriver] with
/// [kenwoodGenericModel]. It exists as its own entry because an operator
/// looks for the name on the front of their radio, and because the whole
/// line answers at 38400 rather than the Kenwood default of 9600 — a
/// mismatch there is answered with silence, not an error.
const elecraftGenericModel = EquipmentModel(
  key: 'elecraft-generic',
  manufacturer: elecraftBrand,
  category: kCategoryTransceiver,
  name: _elecraftGenericName,
  variants: [
    EquipmentVariant(
      key: _elecraftSerialKey,
      driver: KenwoodDriver(),
      transport: SerialTransport(),
      // No keyer until a developer names a dialect — a K4 plays through
      // `PB`/`DA`, a K3 with a KDVR3 through switch taps, and the entry
      // cannot tell them apart.
      defaultConfig: {'baudRate': _elecraftBaudRate, voiceMemoriesConfigKey: 0},
      notes: _elecraftSerialNotes,
    ),
  ],
);

/// Elecraft KX2 and KX3 — the two rigs the Elecraft pairing is proven
/// against, both reported working on Windows and the KX3 on macOS too.
///
/// Each pins the `IF` mode offset [KenwoodDriver] would otherwise spend the
/// first seconds of every connection learning; 27 is what both radios were
/// observed to use. The session still checks it against the radio, so a
/// wrong entry here is caught rather than believed. The generic Elecraft
/// entry pins nothing — the rest of the line has not been seen.
const kx2Model = EquipmentModel(
  key: 'kx2',
  manufacturer: elecraftBrand,
  category: kCategoryTransceiver,
  name: _kx2Name,
  variants: [
    EquipmentVariant(
      key: _kx2SerialKey,
      driver: KenwoodDriver(),
      transport: SerialTransport(),
      defaultConfig: {'baudRate': _elecraftBaudRate},
      overrides: {
        KenwoodDriver.ifModeOffsetKey: 27,
        KenwoodDriver.cwDialectKey: 'elecraft',
        KenwoodDriver.voiceDialectKey: 'kx',
        KenwoodDriver.voiceMemoriesKey: kxVoiceMemoryCount,
        // Two fifteen-second messages, per the owner's manual.
        voiceCeilingConfigKey: 15,
      },
      notes: _elecraftSerialNotes,
    ),
  ],
);

/// See [kx2Model] — the same radio family, the same settings.
const kx3Model = EquipmentModel(
  key: 'kx3',
  manufacturer: elecraftBrand,
  category: kCategoryTransceiver,
  name: _kx3Name,
  variants: [
    EquipmentVariant(
      key: _kx3SerialKey,
      driver: KenwoodDriver(),
      transport: SerialTransport(),
      defaultConfig: {'baudRate': _elecraftBaudRate},
      overrides: {
        KenwoodDriver.ifModeOffsetKey: 27,
        KenwoodDriver.cwDialectKey: 'elecraft',
        KenwoodDriver.voiceDialectKey: 'kx',
        KenwoodDriver.voiceMemoriesKey: kxVoiceMemoryCount,
        // Two fifteen-second messages, per the owner's manual.
        voiceCeilingConfigKey: 15,
      },
      notes: _elecraftSerialNotes,
    ),
  ],
);


/// How long an Icom voice memory holds — "up to 1.5 minutes" per the
/// IC-7300's manual, and the line's figure.
const _icomVoiceSeconds = 90;

/// The rate every Elecraft CAT menu ships on, and the one all three field
/// reports connected at. Not [KenwoodDriver.defaultBaudRate], which is the
/// Kenwood line's 9600.
const _elecraftBaudRate = 38400;

String _elecraftGenericName() => t.settings.station.models.elecraftGeneric;

String _kx2Name() => t.settings.station.models.kx2;

String _kx3Name() => t.settings.station.models.kx3;

List<Map<String, dynamic>> _elecraftSerialNotes() => [
      {
        'type': 'markdown',
        'collapsible': true,
        'title': t.settings.station.troubleshootingNotes,
        'text': '**${t.settings.station.elecraftTroubleshootingTitle}**\n\n'
            '${t.settings.station.elecraftTroubleshooting}',
      },
    ];

/// Where CI-V sits when an Icom presents more than one USB serial port OF ITS
/// OWN — which is what limits who may declare it.
///
/// Icom calls them Port A and Port B, ships both set to CI-V, and puts CI-V
/// on Port A — the first the OS enumerates. The picker POINTS at that port
/// and hides nothing (serial_transport_config.dart), which is what makes one
/// claim across the catalogue reasonable: a radio whose ports the platform
/// cannot split is unaffected, and a radio that turns out to differ costs a
/// bold row on the wrong one while the right one stays a tap away. It is
/// also why the operator who deliberately moved CI-V to Port B is not shut
/// out: were this a filter rather than a ranking, that operator would face a
/// picker offering only the port their radio does not answer on.
///
/// A radio with one USB port, or none at all — the IC-706MKIIG reaches CI-V
/// through a level converter — declares nothing. On those the only ports to
/// rank are the operator's own cable's, and Icom's convention says nothing
/// about which channel of somebody else's dual bridge carries CI-V; the
/// other one is usually PTT, which picks and then answers nothing.
///
/// OBSERVED on exactly one radio: an IC-705 over USB on Android, which
/// presents both ports under its own name with nothing else to tell them
/// apart. Every other model here is INFERRED from Icom's convention and
/// their shared CDC/ACM shape, where Port A is the first data interface.
/// Treat a report that contradicts it as the better evidence.
const _icomCatPort = {'index': 0};

/// Any Icom transceiver over CI-V on a serial port — the IC-705's USB
/// connection, and equally an IC-7300 or IC-9700 with a different address.
///
/// The CI-V address is configuration rather than a constant because it is
/// settable on the radio, and because a wrong one is silent: the radio
/// simply ignores frames addressed elsewhere, which looks exactly like a
/// dead cable.
///
/// Verified over the wire as well as over the network: CI-V on a serial port
/// is what an IC-7300 and an IC-706MKIIG both run on here.
const icomGenericModel = EquipmentModel(
  key: 'icom-generic',
  manufacturer: icomBrand,
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
        // Off until a developer says otherwise — see keyer_config.dart.
        cwKeyerConfigKey: false,
        voiceMemoriesConfigKey: 0,
      },
      restrictions: {'port': _icomCatPort},
      notes: _icomGenericSerialNotes,
    ),
  ],
);

String _icomGenericName() => t.settings.station.models.icomGeneric;

List<Map<String, dynamic>> _icomGenericSerialNotes({String extra = ''}) => [
      {
        'type': 'markdown',
        'collapsible': true,
        'title': t.settings.station.troubleshootingNotes,
        'text': '**${t.settings.station.icomCivTroubleshootingTitle}**\n\n'
            '${t.settings.station.icomCivTroubleshooting}$extra',
      },
    ];

/// Icom IC-7300 over its built-in USB CI-V port.
///
/// The address is a default rather than an override even though the model is
/// named: CI-V ADDRESS is in the radio's own menu, and a rig sharing a bus is
/// exactly where it gets changed. The MK2 ships on a different address and is
/// its own entry — see [ic7300mk2Model].
const ic7300Model = EquipmentModel(
  key: 'ic7300',
  manufacturer: icomBrand,
  category: kCategoryTransceiver,
  name: _ic7300Name,
  variants: [
    EquipmentVariant(
      key: _ic7300SerialKey,
      driver: IcomCivDriver(),
      transport: SerialTransport(),
      defaultConfig: {'civAddress': '94', 'baudRate': 19200},
      overrides: {cwKeyerConfigKey: true, voiceMemoriesConfigKey: civVoiceMemoryCount, voiceCeilingConfigKey: _icomVoiceSeconds},
      notes: _ic7300SerialNotes,
    ),
  ],
);

String _ic7300Name() => t.settings.station.models.ic7300;

/// The shared CI-V "it connected and says nothing" note, plus whatever this
/// radio adds to it — where to find the MK2, for the IC-7300.
List<Map<String, dynamic>> _civSerialNotes({String extra = ''}) => [
      {
        'type': 'markdown',
        'collapsible': true,
        'title': t.settings.station.troubleshootingNotes,
        'text': '**${t.settings.station.civAddressTroubleshootingTitle}**\n\n'
            '${t.settings.station.civAddressTroubleshooting}$extra',
      },
    ];

List<Map<String, dynamic>> _ic7300SerialNotes() =>
    _civSerialNotes(extra: t.settings.station.ic7300Mk2Note);

List<Map<String, dynamic>> _ic7300mk2SerialNotes() => _civSerialNotes();

/// Icom IC-7300 MK2 over its built-in USB CI-V port.
///
/// Its own model rather than a note on [ic7300Model]: an operator picks the
/// name on the front of their radio, and the whole point of a named entry is
/// that the address is already right. The two radios share a driver and
/// differ only in the address they ship on.
const ic7300mk2Model = EquipmentModel(
  key: 'ic7300mk2',
  manufacturer: icomBrand,
  category: kCategoryTransceiver,
  name: _ic7300mk2Name,
  variants: [
    EquipmentVariant(
      key: _ic7300mk2SerialKey,
      driver: IcomCivDriver(),
      transport: SerialTransport(),
      defaultConfig: {'civAddress': 'B6', 'baudRate': 19200},
      overrides: {cwKeyerConfigKey: true, voiceMemoriesConfigKey: civVoiceMemoryCount, voiceCeilingConfigKey: _icomVoiceSeconds},
      notes: _ic7300mk2SerialNotes,
    ),
  ],
);

String _ic7300mk2Name() => t.settings.station.models.ic7300mk2;

List<Map<String, dynamic>> _ic706mkiigSerialNotes() => _civSerialNotes();

/// Icom IC-706MKIIG over CI-V — an external level converter or CI-V cable,
/// since the radio has no USB of its own. Same driver as every other CI-V
/// rig; only the factory address differs.
const ic706mkiigModel = EquipmentModel(
  key: 'ic706mkiig',
  manufacturer: icomBrand,
  category: kCategoryTransceiver,
  name: _ic706mkiigName,
  variants: [
    EquipmentVariant(
      key: _ic706mkiigSerialKey,
      driver: IcomCivDriver(),
      transport: SerialTransport(),
      defaultConfig: {'civAddress': '58', 'baudRate': 19200},
      // No voice keyer, no text keying and no TX meters on this generation:
      // the driver's defaults are the modern line's, and a play or a message
      // here would show as going out while the radio silently ignored it.
      //
      // The empty meterInfo is the same statement about meters, and it has to
      // be said out loud — inheriting the driver's default would reserve
      // power, SWR and ALC slots on a panel where they can never fill. This
      // radio's CI-V table gives command 0x15 exactly two sub-commands, 01
      // squelch and 02 S-meter; the TX meters arrived a generation later.
      overrides: {cwKeyerConfigKey: false, voiceMemoriesConfigKey: 0, meterInfoConfigKey: ''},
      notes: _ic706mkiigSerialNotes,
    ),
  ],
);

String _ic706mkiigName() => t.settings.station.models.ic706mkiig;

List<Map<String, dynamic>> _ic7100SerialNotes() => _civSerialNotes();

/// Icom IC-7100 over its built-in USB CI-V port.
///
/// Keys through 0x17 like the rest of the line; its voice memories are not
/// known to be reachable over CI-V, so none are offered — a play would show
/// as going out while the radio ignored it.
const ic7100Model = EquipmentModel(
  key: 'ic7100',
  manufacturer: icomBrand,
  category: kCategoryTransceiver,
  name: _ic7100Name,
  variants: [
    EquipmentVariant(
      key: _ic7100SerialKey,
      driver: IcomCivDriver(),
      transport: SerialTransport(),
      defaultConfig: {'civAddress': '88', 'baudRate': 19200},
      overrides: {cwKeyerConfigKey: true, voiceMemoriesConfigKey: 0},
      notes: _ic7100SerialNotes,
    ),
  ],
);

String _ic7100Name() => t.settings.station.models.ic7100;

/// The address note plus the family's two-port one: this radio presents both
/// ports and now has one of them marked, so the operator gets the reason for
/// the marker and the escape hatch if it points the wrong way.
List<Map<String, dynamic>> _ic7610SerialNotes() =>
    _civSerialNotes(extra: '\n\n${t.settings.station.icomCivTroubleshooting}');

/// Icom IC-7610 over its built-in USB CI-V port.
///
/// 9600 is the radio's own default rather than the CI-V family's 19200, and a
/// speed mismatch is answered with silence — so the prefill here is the whole
/// reason the model exists. The radio will run far faster once both ends
/// agree, which is a change made in two places, not one.
const ic7610Model = EquipmentModel(
  key: 'ic7610',
  manufacturer: icomBrand,
  category: kCategoryTransceiver,
  name: _ic7610Name,
  variants: [
    EquipmentVariant(
      key: _ic7610SerialKey,
      driver: IcomCivDriver(),
      transport: SerialTransport(),
      defaultConfig: {'civAddress': '98', 'baudRate': 9600},
      overrides: {cwKeyerConfigKey: true, voiceMemoriesConfigKey: civVoiceMemoryCount, voiceCeilingConfigKey: _icomVoiceSeconds},
      restrictions: {'port': _icomCatPort},
      notes: _ic7610SerialNotes,
    ),
  ],
);

String _ic7610Name() => t.settings.station.models.ic7610;

List<Map<String, dynamic>> _ic7760SerialNotes() =>
    _civSerialNotes(extra: t.settings.station.ic7760PortNote);

/// Icom IC-7760 over CI-V.
///
/// Two serial ports appear for the one radio and only Port A carries CI-V,
/// which the OS gives no way to tell apart — so the note says which, since
/// the wrong one connects and then says nothing.
const ic7760Model = EquipmentModel(
  key: 'ic7760',
  manufacturer: icomBrand,
  category: kCategoryTransceiver,
  name: _ic7760Name,
  variants: [
    EquipmentVariant(
      key: _ic7760SerialKey,
      driver: IcomCivDriver(),
      transport: SerialTransport(),
      defaultConfig: {'civAddress': 'B2', 'baudRate': 19200},
      overrides: {cwKeyerConfigKey: true, voiceMemoriesConfigKey: civVoiceMemoryCount, voiceCeilingConfigKey: _icomVoiceSeconds},
      restrictions: {'port': _icomCatPort},
      notes: _ic7760SerialNotes,
    ),
  ],
);

String _ic7760Name() => t.settings.station.models.ic7760;

List<Map<String, dynamic>> _x6100SerialNotes() =>
    _civSerialNotes(extra: t.settings.station.x6100PortNote);

/// Xiegu X6100 — a Xiegu radio that happens to speak Icom's CI-V, not the
/// Kenwood protocol its documentation and much of the community suggest.
///
/// Named here because the protocol is not guessable from the brand: an
/// operator hunting for "Xiegu" would otherwise reach for Kenwood - Generic,
/// which connects to the radio and never gets an answer.
const x6100Model = EquipmentModel(
  key: 'x6100',
  manufacturer: 'Xiegu',
  category: kCategoryTransceiver,
  name: _x6100Name,
  variants: [
    EquipmentVariant(
      key: _x6100SerialKey,
      driver: IcomCivDriver(),
      transport: SerialTransport(),
      defaultConfig: {'civAddress': 'A4', 'baudRate': 19200},
      // Keys through 0x17 like the Icoms it imitates; whether it has voice
      // memories reachable over CI-V is undocumented, so none are offered.
      overrides: {cwKeyerConfigKey: true, voiceMemoriesConfigKey: 0},
      // CI-V is on the second of the radio's two serial ports; the picker
      // points at that one where it can, and never hides the other.
      restrictions: {'port': {'index': 1}},
      notes: _x6100SerialNotes,
    ),
  ],
);

String _x6100Name() => t.settings.station.models.x6100;

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
  manufacturer: icomBrand,
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
        // The IC-705's real ceiling (10W SSB/CW) — see _assumedMaxWatts in
        // icom_civ_driver.dart. A device fact, not something the operator
        // picked, so it's an override like the addresses above.
        'maxWatts': 10,
        // On its own battery the radio caps actual output well below the
        // SET level it keeps reporting — see civMeterDcInputVoltage.
        'batteryMaxWatts': 5,
        cwKeyerConfigKey: true,
        voiceMemoriesConfigKey: civVoiceMemoryCount,
        voiceCeilingConfigKey: _icomVoiceSeconds,
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
      // Unlike the address, the radio's own power ceiling can't change by
      // sharing a bus — a fixed fact about this model, same as the network
      // variant's override above.
      overrides: {
        'maxWatts': 10,
        'batteryMaxWatts': 5,
        cwKeyerConfigKey: true,
        voiceMemoriesConfigKey: civVoiceMemoryCount,
        voiceCeilingConfigKey: _icomVoiceSeconds,
      },
      // The radio [_icomCatPort] was actually observed on: two ports under
      // one name, nothing but their order to tell them apart.
      restrictions: {'port': _icomCatPort},
      notes: _ic705SerialNotes,
    ),
  ],
);

String _ic705Name() => t.settings.station.models.ic705;

List<Map<String, dynamic>> _ic705SerialNotes() =>
    _icomGenericSerialNotes(extra: t.settings.station.ic705PortNote);

List<Map<String, dynamic>> _ic705NetworkNotes() => [
      {
        'type': 'markdown',
        'collapsible': true,
        'title': t.settings.station.troubleshootingNotes,
        'text': '**${t.settings.station.ic705TroubleshootingTitle}**\n\n'
            '${t.settings.station.ic705Troubleshooting}',
      },
    ];

/// A radio that isn't there — see placeholder_radio_driver.dart and
/// placeholder_transport.dart for what it is for and what it deliberately isn't.
///
/// In the catalogue for every operator, in every edition. Its name says
/// "(no control)" because that is the whole warning it needs: an operator
/// who picks it gets a radio pill and a frequency to type into, and no rig
/// is ever touched.
const placeholderRadioModel = EquipmentModel(
  key: 'placeholder-radio',
  category: kCategoryTransceiver,
  name: _placeholderRadioName,
  suggestedName: _placeholderRadioNodeName,
  variants: [
    EquipmentVariant(
      key: _placeholderRadioKey,
      driver: PlaceholderRadioDriver(),
      transport: PlaceholderTransport(),
      // Every numeric knob is prefilled, not just the three that describe
      // the rig: their validators reject a blank box (placeholder_transport.dart
      // says why), so a form that opened with one empty would refuse to
      // submit until the operator typed a zero nobody asked them for.
      defaultConfig: {
        'placeholderFreq': placeholderRadioDefaultFreqKHz,
        'placeholderMode': placeholderRadioDefaultMode,
        'placeholderPower': placeholderRadioDefaultWatts,
        'placeholderSwr': placeholderRadioDefaultSwr,
        'placeholderConnectDelay': 0,
        'placeholderDropAfter': 0,
        'placeholderReplyDelay': 0,
      },
    ),
  ],
);

String _placeholderRadioName() => t.settings.station.models.placeholderRadio;

String _placeholderRadioNodeName() => t.settings.station.models.placeholderRadioNodeName;

/// A 4O3A Antenna Genius, over the TCP protocol its Genius series shares.
///
/// In the searchable catalogue rather than [EquipmentModel.hiddenFromCatalog]
/// like the generic antenna and key nodes: it is a real product with a name
/// on the front, which is the distinction that flag draws. Its own note says
/// as much — "a real antenna switch added later belongs in the searchable
/// list like any other radio".
///
/// Found automatically: it announces itself over UDP broadcast on 9007, the
/// same port number its TCP API listens on. Address and port can always be
/// typed in as well — a switch on another subnet, or behind a router that
/// does not forward broadcasts, never announces.
const antennaGeniusModel = EquipmentModel(
  key: 'antenna-genius',
  category: kCategoryAntennaSwitch,
  name: _antennaGeniusName,
  manufacturer: '4O3A',
  variants: [
    EquipmentVariant(
      key: _antennaGeniusTcpKey,
      driver: AntennaGeniusDriver(),
      transport: TcpTransport(),
      defaultConfig: {
        'port': antennaGeniusDefaultPort,
        switchLayoutConfigKey: switchLayoutDevicePorts,
      },
      discoverer: AntennaGeniusDiscoverer(typeKey: _antennaGeniusTcpKey),
    ),
  ],
);

String _antennaGeniusName() => t.settings.station.models.antennaGenius;

/// The Sierra Radio Systems CX-1 coax relay module, on the Device Control
/// Network.
///
/// No discoverer, and there cannot be one: the DCN is a serial bus with no
/// announcement of any kind. A module is found by picking its serial port
/// and telling the app which address its DIP switches are set to.
///
/// The serial port is either a USB-to-RS-485 dongle on the shared bus or the
/// module's own USB-C console jack; the addressed envelope this driver sends
/// works on both, so there is nothing to choose between them here.
const sierraCoaxModel = EquipmentModel(
  key: 'sierra-coax',
  category: kCategoryAntennaSwitch,
  name: _sierraCoaxName,
  manufacturer: 'Sierra Radio Systems',
  variants: [
    EquipmentVariant(
      key: _sierraCoaxSerialKey,
      driver: SierraCoaxDriver(),
      transport: SerialTransport(),
      // Fixed by the DCN specification, not a preference — so an override,
      // which also takes the baud picker out of the editor. Every module on
      // the bus runs at this rate and one that did not could not be on it.
      overrides: {'baudRate': sierraDcnBaudRate},
      defaultConfig: {
        sierraAddressConfigKey: sierraCoaxDefaultAddress,
        switchLayoutConfigKey: switchLayoutDevicePorts,
      },
    ),
  ],
);

String _sierraCoaxName() => t.settings.station.models.sierraCoax;

const _antennaKey = 'antenna-none';
const _keyKey = 'key-none';

/// A generic antenna node — see [EquipmentModel.hiddenFromCatalog]. Offered
/// from the Add dialog's "Other Equipment" section, never its searchable
/// catalogue.
const antennaModel = EquipmentModel(
  key: 'antenna',
  category: kCategoryAntenna,
  name: _antennaModelName,
  hiddenFromCatalog: true,
  variants: [
    EquipmentVariant(key: _antennaKey, driver: AntennaDriver(), transport: NoneTransport()),
  ],
);

String _antennaModelName() => t.settings.station.models.antenna;

/// A generic CW key node — see [EquipmentModel.hiddenFromCatalog]. Offered
/// from the Add dialog's "Other Equipment" section, never its searchable
/// catalogue.
const keyModel = EquipmentModel(
  key: 'key',
  category: kCategoryKey,
  name: _keyModelName,
  hiddenFromCatalog: true,
  variants: [
    EquipmentVariant(key: _keyKey, driver: KeyDriver(), transport: NoneTransport()),
  ],
);

String _keyModelName() => t.settings.station.models.key;

/// A K1EL Winkeyer over its own serial (USB) port — see winkeyer_driver.dart.
/// Offered from the Add dialog's "Other Equipment" rows beside a plain key,
/// which is where an operator looks for a key; its port speed is the
/// keyer's fixed 1200 baud, 2 stop bits, so neither is a field.
const winkeyerModel = EquipmentModel(
  key: 'winkeyer',
  manufacturer: 'K1EL',
  category: kCategoryKeyer,
  name: _winkeyerModelName,
  hiddenFromCatalog: true,
  variants: [
    EquipmentVariant(
      key: _winkeyerSerialKey,
      driver: WinkeyerDriver(),
      transport: SerialTransport(),
      // Overrides, not defaults: a default is only a prefill the Add form
      // may drop (1200 is not in the baud picker, and stopBits has no
      // field), while an override is merged into every target and takes
      // the baud picker off the form.
      overrides: {'baudRate': 1200, 'stopBits': 2},
      // The key port IS a prefill: the form must show the port the driver
      // will key, or the operator reads an empty picker while port 1 goes
      // out on the wire.
      defaultConfig: {winkeyerKeyPortConfigKey: '1'},
    ),
  ],
);

String _winkeyerModelName() => t.settings.station.models.winkeyer;

/// What the app can talk to, and how it gets there.
///
/// A plain Dart list today. When extensions can contribute rig definitions
/// this gains a second source and merges them, the way [SettingsView]
/// already merges Dart settings groups with extension-contributed panels.
const _defaultModels = [
  flexRadioModel,
  ft891Model,
  ft710Model,
  ftdx10Model,
  ft817Model,
  ft857Model,
  ft897Model,
  q900Model,
  yaesuGenericModel,
  ic705Model,
  ic7300Model,
  ic7300mk2Model,
  ic706mkiigModel,
  ic7100Model,
  ic7610Model,
  ic7760Model,
  x6100Model,
  icomGenericModel,
  qmxModel,
  fx4crModel,
  kx2Model,
  kx3Model,
  elecraftGenericModel,
  kenwoodGenericModel,
  rigctldModel,
  flrigModel,
  placeholderRadioModel,
  antennaGeniusModel,
  sierraCoaxModel,
  antennaModel,
  keyModel,
  winkeyerModel,
];

class EquipmentRegistry {
  final List<EquipmentModel> models;
  final Map<String, EquipmentTransport> transports;

  /// One per variant of every model, in model order — the flat view
  /// [CatService] resolves a node's stored `typeKey` against. Derived, so a
  /// model and its pairings can never disagree about which variants exist.
  final List<EquipmentType> types;

  EquipmentRegistry({List<EquipmentModel>? models, Map<String, EquipmentTransport>? transports})
      : models = models ?? _defaultModels,
        types = [
          for (final model in models ?? _defaultModels)
            for (final variant in model.variants) EquipmentType(model, variant),
        ],
        transports = transports ??
            {
              TcpTransport.transportKey: const TcpTransport(),
              SerialTransport.transportKey: const SerialTransport(),
              IcomNetworkTransport.transportKey: const IcomNetworkTransport(),
              PlaceholderTransport.transportKey: const PlaceholderTransport(),
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
