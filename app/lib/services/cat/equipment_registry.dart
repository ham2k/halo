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
// The models themselves live one file per protocol family
// (`equipment_models_*.dart`, and `equipment_bridges.dart` for the programs
// that stand in front of a radio), re-exported from here so a caller needs
// only this import. A new radio goes in its family's file and in
// [_defaultModels].
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
import 'equipment.dart';
import 'equipment_brands.dart';
import 'equipment_bridges.dart';
import 'equipment_k4.dart';
import 'equipment_models_accessories.dart';
import 'equipment_models_icom.dart';
import 'equipment_models_kenwood.dart';
import 'equipment_models_other_radios.dart';
import 'equipment_models_sdr.dart';
import 'equipment_models_tentec.dart';
import 'equipment_models_yaesu.dart';
import 'transport.dart';
import 'transports/ble_serial_transport.dart';
import 'transports/bluetooth_serial_transport.dart';
import 'transports/placeholder_transport.dart';
import 'transports/icom_network_transport.dart';
import 'transports/serial_transport.dart';
import 'transports/tcp_transport.dart';
import 'transports/k4_remote_transport.dart';

export 'equipment_models_accessories.dart';
export 'equipment_models_icom.dart';
export 'equipment_models_kenwood.dart';
export 'equipment_models_other_radios.dart';
export 'equipment_models_sdr.dart';
export 'equipment_models_yaesu.dart';

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

  /// At least one. Order is what the transport picker offers, then the
  /// derived variants: Bluetooth LE for a model with a serial one, and the
  /// placeholder last for a model that [offersPlaceholder].
  final List<EquipmentVariant> _variants;

  List<EquipmentVariant> get variants {
    if (!offersPlaceholder) return _variants;
    final ble = bleSerialVariantFor(this);
    return [..._variants, ?ble, placeholderVariantFor(key)];
  }

  /// Every real transceiver can be run as the placeholder radio. Not the
  /// placeholder itself, and not a bridge: neither has a maker, and a program
  /// standing in front of a radio has no cable to be waiting for.
  bool get offersPlaceholder => category == kCategoryTransceiver && manufacturer != null;

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
    required this._variants,
    String Function()? suggestedName,
    String Function()? recordingHelp,
    this.manufacturer,
    this.hiddenFromCatalog = false,
  }) : _nameBuilder = name,
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

/// A real transceiver's serial pairing, reached through a Bluetooth LE serial
/// bridge instead of a cable: the same driver, and the driver's own pins and
/// prefills, without the serial port's — no port to pick, and no baud field,
/// since the bridge holds the rate. The radio's serial default is pinned as
/// [bleSerialLinkBaudKey] instead: with no baud at all a driver budgets as
/// for a network link, and would offer an Icom's scope and the fast telemetry
/// floor over the 9600 or 19200 wire behind the bridge. Null for a model with
/// no serial variant. Derived like the
/// placeholder, so its key is `<model>-ble` — stable, since a node stores it.
///
/// Every model rather than a chosen few: a bridge carries any radio's serial
/// CAT, and which bridge is on the operator's radio is not the catalogue's
/// to know.
EquipmentVariant? bleSerialVariantFor(EquipmentModel model) => _bleSerialVariants.putIfAbsent(model.key, () {
  final serial = model._variants.where((v) => v.transportKey == SerialTransport.transportKey).firstOrNull;
  if (serial == null) return null;
  final driverKeys = serial.driver.recognizedConfigKeys;
  Map<String, dynamic> driverOnly(Map<String, dynamic> config) => {
    for (final entry in config.entries)
      if (driverKeys.contains(entry.key)) entry.key: entry.value,
  };
  return EquipmentVariant(
    key: '${model.key}-ble',
    driver: serial.driver,
    transport: const BleSerialTransport(),
    defaultConfig: driverOnly(serial.defaultConfig),
    overrides: {...driverOnly(serial.overrides), bleSerialLinkBaudKey: serial.defaultConfig['baudRate'] ?? 9600},
    restrictions: driverOnly(serial.restrictions),
    extraValidate: serial.extraValidate,
    notes: () => serial.notes,
  );
});

final _bleSerialVariants = <String, EquipmentVariant?>{};

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

  /// See [EquipmentTransport.isUnconfigured]. Overrides count: a pairing
  /// that pins its own port is never missing one.
  bool isUnconfigured(Map<String, dynamic> config) => transport.isUnconfigured(_merged(config));

  /// What the editor asks of a field. An unconfigured pairing skips the
  /// transport's checks — they all describe the connection the operator has
  /// chosen not to fill in yet — and keeps the driver's.
  String? validateEditorField(String key, dynamic value, Map<String, dynamic> config) =>
      isUnconfigured(config) ? driver.validateField(key, value, config) : validateField(key, value, config);

  /// Turns the user's configuration into what the transport connects with.
  Map<String, dynamic> targetFor(Map<String, dynamic> config) => transport.targetFor(_merged(config));

  /// The configuration the DRIVER sees — the merged config, overrides
  /// included, since a driver reads whatever keys it needs straight out of
  /// the map rather than through a narrowed shape like [targetFor].
  ///
  /// Less a baud rate the transport has no field for: a node switched from
  /// serial to the network keeps the one it had, and a driver that budgets
  /// by baud would pace a WiFi link like a 19200 cable — and refuse a scope
  /// as too slow for it.
  Map<String, dynamic> driverConfig(Map<String, dynamic> config) => {
    ..._merged(config),
    if (!transport.recognizedConfigKeys.contains('baudRate') && !overrides.containsKey('baudRate')) 'baudRate': null,
  };

  /// Which meters a node on this pairing can show — the driver's answer for
  /// the MERGED config, so the entry's own overrides (the calibration file
  /// it names) are part of the question.
  ///
  /// Through the type rather than reaching for the driver directly: a caller
  /// holding a node has its stored config, not the merged one, and asking
  /// the driver with the stored map would leave a named radio looking like a
  /// generic one.
  Set<RadioMeter> telemetryMetersFor(Map<String, dynamic> config) => driver.telemetryMetersWith(_merged(config));

  /// The meter cadence a node on this pairing falls back to — again for the
  /// MERGED config, so the speed prefilled by the entry counts even when the
  /// operator has never opened the box.
  Duration defaultTelemetryIntervalFor(Map<String, dynamic> config) => driver.defaultTelemetryInterval(_merged(config));

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
  String? describeChannel(Map<String, dynamic> config) => driver.describeChannel(_merged(config), overrides: overrides);

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
  ///
  /// A field the action sets brings its [fieldChanged] companions with it,
  /// as if the operator had picked it: the editor applies an action's
  /// updates without reporting them as changes.
  Future<EquipmentActionResult?> runAction(String actionKey, String method, Map<String, dynamic> state) async {
    final result = await transport.runAction(actionKey, method, state);
    final updates = result?.fieldUpdates;
    if (result == null || updates == null) return result;
    return EquipmentActionResult(
      message: result.message,
      fieldUpdates: {for (final entry in updates.entries) ...?fieldChanged(entry.key, entry.value), ...updates},
    );
  }

  /// See [EquipmentTransport.fieldChanged]. Never a field this pairing
  /// fixes: the editor renders none for it.
  Map<String, dynamic>? fieldChanged(String key, dynamic value) {
    final updates = transport.fieldChanged(key, value, restrictions: restrictions);
    return updates == null
        ? null
        : {
            for (final entry in updates.entries)
              if (!overrides.containsKey(entry.key)) entry.key: entry.value,
          };
  }
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
    K4RemoteTransport.transportKey => labels.secureNetwork,
    SerialTransport.transportKey => labels.usbSerial,
    BluetoothSerialTransport.transportKey => labels.bluetoothSerial,
    BleSerialTransport.transportKey => labels.bleSerial,
    IcomNetworkTransport.transportKey => labels.wifi,
    PlaceholderTransport.transportKey => labels.placeholder,
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
/// not which protocol is spoken over it.
///
/// The names must exist in halo_widgets' generated codepoint table:
/// `resolveIconName` answers an unknown name with a puzzle-piece glyph and
/// no error at all, so a typo here ships silently.
String? transportIconNameFor(String transportKey) => switch (transportKey) {
  SerialTransport.transportKey => 'usb-port',
  BluetoothSerialTransport.transportKey || BleSerialTransport.transportKey => 'bluetooth',
  TcpTransport.transportKey || IcomNetworkTransport.transportKey || K4RemoteTransport.transportKey => 'wifi',
  // Not a way of plugging anything in — the exception the rule above
  // allows for, because what this transport connects to is nothing.
  PlaceholderTransport.transportKey => 'flask-outline',
  _ => null,
};

/// What the app can talk to, and how it gets there.
///
/// A plain Dart list today. When extensions can contribute rig definitions
/// this gains a second source and merges them, the way [SettingsView]
/// already merges Dart settings groups with extension-contributed panels.
const _defaultModels = [
  flexRadioModel,
  ft891Model,
  ft991aModel,
  ft710Model,
  ftdx10Model,
  ftx1Model,
  ft450Model,
  ft817Model,
  ft857Model,
  ft897Model,
  q900Model,
  sotacatModel,
  yaesuGenericModel,
  ic705Model,
  ic7300Model,
  ic7300mk2Model,
  ic706mkiigModel,
  ic7100Model,
  ic7610Model,
  ic7760Model,
  ic9700Model,
  ic905Model,
  ic7850Model,
  ic7851Model,
  x6100Model,
  g90Model,
  icomGenericModel,
  qmxModel,
  fx4crModel,
  qcxModel,
  kx2Model,
  kx3Model,
  k4Model,
  elecraftGenericModel,
  ts590sgModel,
  ts480Model,
  kenwoodGenericModel,
  tx500Model,
  tx500mpModel,
  tenTecEagleModel,
  tenTecOrionModel,
  tenTecOrionIIModel,
  rigctldModel,
  flrigModel,
  hrdModel,
  n3fjpModel,
  commanderModel,
  placeholderRadioModel,
  antennaGeniusModel,
  sierraCoaxModel,
  antennaModel,
  keyModel,
  winkeyerModel,
  ...sdrModels,
];

/// What `EXP 500MP` holds back from the catalogue: the Lab599 radios, and
/// the Bluetooth LE pairing every serial radio derives — neither has met
/// hardware yet. Only the OFFER: a node already on one keeps connecting with
/// the experiment off, so turning it off never strands a working radio.
bool isBehindTx500Experiment(EquipmentType type) => type.model.manufacturer == lab599Brand || type.transportKey == BleSerialTransport.transportKey;

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
      transports =
          transports ??
          {
            TcpTransport.transportKey: const TcpTransport(),
            K4RemoteTransport.transportKey: const K4RemoteTransport(),
            SerialTransport.transportKey: const SerialTransport(),
            BluetoothSerialTransport.transportKey: const BluetoothSerialTransport(),
            BleSerialTransport.transportKey: const BleSerialTransport(),
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
  late final Set<String> allSecretFields = {for (final type in types) ...type.secretFields};

  /// The pairings of [model] the catalogue offers on this platform — web has
  /// no raw sockets and no serial, so a model can be reachable everywhere
  /// but here — less what `EXP 500MP` holds back ([isBehindTx500Experiment])
  /// while [tx500Experiment] is off, and never less [current]: the node being
  /// edited keeps its own pairing in the choice.
  List<EquipmentType> offeredVariants(EquipmentModel model, {required bool tx500Experiment, EquipmentType? current}) => [
    for (final variant in model.variants)
      if (typeFor(variant.key) case final type?)
        if (type.isSupportedOnThisPlatform && (tx500Experiment || type == current || !isBehindTx500Experiment(type))) type,
  ];

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
