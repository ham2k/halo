// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The radios that belong to no protocol family: FlexRadio's SmartSDR API, an
// ANAN through Thetis, a SunSDR through ExpertSDR3, the Guohetec Q900's own
// protocol, a KX2/KX3 behind a SOTAcat, and the placeholder that stands in
// for a radio with no CAT at all.

import 'package:halo_i18n/halo_i18n.dart';

import 'drivers/placeholder_radio_driver.dart';
import 'drivers/flex_discovery.dart';
import 'drivers/flexradio_driver.dart';
import 'drivers/guohetec_driver.dart';
import 'drivers/rigctld_driver.dart';
import 'drivers/tci_driver.dart';
import 'drivers/thetis_driver.dart';
import 'discovery.dart';
import 'driver.dart';
import 'equipment.dart';
import 'equipment_brands.dart';
import 'equipment_registry.dart';
import 'transports/bluetooth_serial_transport.dart';
import 'transports/mdns.dart';
import 'transports/placeholder_transport.dart';
import 'transports/serial_transport.dart';
import 'transports/tcp_transport.dart';
import 'transports/websocket_transport.dart';

const _flexRadioTcpKey = 'flexradio-tcp';
const _ananThetisTciKey = 'anan-thetis-tci';
const _ananThetisTcpKey = 'anan-thetis-tcp';
const _sunSdrTciKey = 'sunsdr-tci';

/// Where the ANAN's TCI variant keeps its port: its CAT variant's `port` is
/// 13013, and the editor shows one field per key across a model's variants.
const tciPortConfigKey = 'tciPort';
const _q900SerialKey = 'q900-serial';
const _q900BluetoothKey = 'q900-bluetooth';
const _placeholderRadioKey = 'placeholder-radio';
const _sotacatTcpKey = 'sotacat-tcp';

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

/// An Apache Labs ANAN, through the Thetis program that runs it: the radio
/// has no CAT of its own, and Thetis answers for it — over TCI ([TciDriver]),
/// or over its TCP/IP CAT server ([ThetisDriver]). Any radio Thetis runs
/// answers the same way, which is why the rated output is a field rather
/// than a per-model entry.
///
/// TCI first: it pushes every change, reads the meters, and carries the IQ
/// the band scope is computed from. The CAT server stays for a Thetis older
/// than its TCI, and for an operator whose other programs already use it.
///
/// No discoverer: Thetis announces nothing. The default host is the same
/// machine, where Thetis usually runs beside the logger.
///
/// Written from Thetis's published CAT reference and the TCI spec, and run
/// against no radio.
const ananThetisModel = EquipmentModel(
  key: 'anan-thetis',
  manufacturer: apacheLabsBrand,
  category: kCategoryTransceiver,
  name: _ananThetisName,
  variants: [
    EquipmentVariant(
      key: _ananThetisTciKey,
      driver: TciDriver(),
      transport: WebSocketTransport(portConfigKey: tciPortConfigKey),
      defaultConfig: {'host': '127.0.0.1', tciPortConfigKey: TciDriver.defaultPort},
      notes: _thetisTciNotes,
    ),
    EquipmentVariant(
      key: _ananThetisTcpKey,
      driver: ThetisDriver(),
      transport: TcpTransport(),
      defaultConfig: {'host': '127.0.0.1', 'port': ThetisDriver.defaultPort},
      notes: _thetisNotes,
    ),
  ],
);

String _ananThetisName() => t.settings.station.models.ananThetis;

/// An Expert Electronics SunSDR, through ExpertSDR3, which serves TCI for
/// every radio it runs — the protocol is Expert Electronics' own. Rated
/// output is a field for the same reason it is on the ANAN.
///
/// Written from the TCI spec and run against no radio.
const sunSdrModel = EquipmentModel(
  key: 'sunsdr',
  manufacturer: expertElectronicsBrand,
  category: kCategoryTransceiver,
  name: _sunSdrName,
  variants: [
    EquipmentVariant(
      key: _sunSdrTciKey,
      driver: TciDriver(),
      transport: WebSocketTransport(),
      defaultConfig: {'host': '127.0.0.1', 'port': TciDriver.defaultPort},
      notes: _expertSdrTciNotes,
    ),
  ],
);

String _sunSdrName() => t.settings.station.models.sunSdr;

List<Map<String, dynamic>> _thetisTciNotes() => [
  {
    'type': 'markdown',
    'collapsible': true,
    'title': t.settings.station.troubleshootingNotes,
    'text':
        '**${t.settings.station.tciTroubleshootingTitle}**\n\n'
        '${t.settings.station.thetisTciTroubleshooting}\n\n'
        '${t.settings.station.tciTroubleshooting}',
  },
];

List<Map<String, dynamic>> _expertSdrTciNotes() => [
  {
    'type': 'markdown',
    'collapsible': true,
    'title': t.settings.station.troubleshootingNotes,
    'text':
        '**${t.settings.station.tciTroubleshootingTitle}**\n\n'
        '${t.settings.station.expertSdrTciTroubleshooting}\n\n'
        '${t.settings.station.tciTroubleshooting}',
  },
];

List<Map<String, dynamic>> _thetisNotes() => [
  {
    'type': 'markdown',
    'collapsible': true,
    'title': t.settings.station.troubleshootingNotes,
    'text':
        '**${t.settings.station.thetisTroubleshootingTitle}**\n\n'
        '${t.settings.station.thetisTroubleshooting}',
  },
];

/// An Elecraft KX2 or KX3 behind a SOTAcat, the ESP32 module on its ACC
/// port that serves the radio's CAT as a rigctld-compatible TCP server.
///
/// Found automatically by its `_sotacat._tcp` service record. The default
/// host is the module's own mDNS name, which is what an operator types when
/// the radio is on a phone's hotspot and its address changes every outing.
///
/// No manufacturer, like the rigctld bridge it speaks for: with one, the
/// model would offer the "no CAT" placeholder variant every transceiver
/// gains, and a SOTAcat is nothing but the CAT link. It shelves under Other
/// Brands.
const sotacatModel = EquipmentModel(
  key: 'sotacat',
  category: kCategoryTransceiver,
  name: _sotacatName,
  variants: [
    EquipmentVariant(
      key: _sotacatTcpKey,
      driver: RigctldDriver(),
      transport: TcpTransport(),
      defaultConfig: {'host': 'sotacat.local', 'port': RigctldDriver.defaultPort},
      // SOTAcat implements `send_morse`, `\stop_morse`, `KEYSPD`,
      // `send_voice_mem` and `stop_voice_mem`, which a generic rigctld cannot
      // be assumed to. The keyer range, two DVR messages and their 15 s
      // length are the KX2/KX3's, from Elecraft's manuals.
      overrides: {
        cwKeyerConfigKey: true,
        rigctldKeyerSpeedMinConfigKey: 8,
        rigctldKeyerSpeedMaxConfigKey: 50,
        voiceMemoriesConfigKey: 2,
        voiceCeilingConfigKey: 15,
      },
      discoverer: SotacatDiscoverer(typeKey: _sotacatTcpKey),
    ),
  ],
);

String _sotacatName() => t.settings.station.models.sotacat;

/// The service type a SOTAcat publishes: SRV names its rigctld port, and
/// TXT carries `id` (stable across hosts and addresses) and `fw`.
const sotacatServiceType = '_sotacat._tcp.local';

/// SOTAcats answering a browse for [sotacatServiceType].
///
/// The found config carries the unit's mDNS HOST NAME, not its address. A
/// SOTAcat goes to the field on whatever hotspot is at hand, and an address
/// stored at discovery is wrong by the next activation; the name resolves
/// over mDNS on every connect (`lookupHost`, mdns_io.dart).
class SotacatDiscoverer implements EquipmentDiscoverer {
  final String typeKey;

  /// A seam for tests, which cannot send multicast from `flutter_tester`.
  final Stream<MdnsService> Function(String serviceType) browse;

  const SotacatDiscoverer({required this.typeKey, this.browse = mdnsBrowse});

  @override
  Stream<DiscoveredEquipment> discover() => browse(sotacatServiceType).map(
    (found) => DiscoveredEquipment(
      typeKey: typeKey,
      id: found.txt['id'] ?? found.instance,
      name: found.instance,
      detail: [if (found.txt['fw'] case final fw? when fw.isNotEmpty) 'v$fw', found.host].join(' · '),
      config: {'host': found.host, 'port': found.port},
    ),
  );
}

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
    EquipmentVariant(
      key: _q900BluetoothKey,
      driver: GuohetecDriver(),
      transport: BluetoothSerialTransport(),
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
    'text':
        '**${t.settings.station.guohetecTroubleshootingTitle}**\n\n'
        '${t.settings.station.guohetecTroubleshooting}',
  },
];

/// A radio that isn't there — see placeholder_radio_driver.dart and
/// placeholder_transport.dart for what it is for and what it deliberately isn't.
///
/// The Simulated Radio: a development tool, offered only in developer mode
/// ([developmentToolModelKeys]). Its key stays `placeholder-radio`: nodes
/// are stored under it, and a new key would leave them unconnectable.
const placeholderRadioModel = EquipmentModel(
  key: 'placeholder-radio',
  category: kCategoryTransceiver,
  name: _placeholderRadioName,
  suggestedName: _placeholderRadioNodeName,
  variants: [
    EquipmentVariant(key: _placeholderRadioKey, driver: PlaceholderRadioDriver(), transport: PlaceholderTransport(), defaultConfig: _placeholderRadioDefaults),
  ],
);

String _placeholderRadioName() => t.settings.station.models.placeholderRadio;

/// Every numeric knob is prefilled, not just the three that describe the rig:
/// their validators reject a blank box (placeholder_transport.dart says why),
/// so a form that opened with one empty would refuse to submit until the
/// operator typed a zero nobody asked them for.
const _placeholderRadioDefaults = <String, dynamic>{
  'placeholderFreq': placeholderRadioDefaultFreqKHz,
  'placeholderMode': placeholderRadioDefaultMode,
  'placeholderPower': placeholderRadioDefaultWatts,
  'placeholderSwr': placeholderRadioDefaultSwr,
  'placeholderConnectDelay': 0,
  'placeholderDropAfter': 0,
  'placeholderReplyDelay': 0,
};

/// A real radio run as the placeholder: the operator's IC-705 keeps its name
/// and model while there is no cable or address for it yet, and behaves as
/// [placeholderRadioModel] does until one is chosen. Derived per model, so
/// its key is `<model>-placeholder` — stable, since a node stores it.
EquipmentVariant placeholderVariantFor(String modelKey) => _placeholderVariants.putIfAbsent(
  modelKey,
  () => EquipmentVariant(
    key: '$modelKey-placeholder',
    driver: const PlaceholderRadioDriver(),
    transport: const PlaceholderTransport(),
    defaultConfig: _placeholderRadioDefaults,
  ),
);

final _placeholderVariants = <String, EquipmentVariant>{};

String _placeholderRadioNodeName() => t.settings.station.models.placeholderRadioNodeName;
