// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The radios that belong to no protocol family: FlexRadio's SmartSDR API, the
// Guohetec Q900's own protocol, and the placeholder that stands in for a
// radio with no CAT at all.

import 'package:halo_i18n/halo_i18n.dart';

import 'drivers/placeholder_radio_driver.dart';
import 'drivers/flexradio_driver.dart';
import 'drivers/guohetec_driver.dart';
import 'equipment.dart';
import 'equipment_brands.dart';
import 'equipment_registry.dart';
import 'transports/bluetooth_serial_transport.dart';
import 'transports/placeholder_transport.dart';
import 'transports/serial_transport.dart';
import 'transports/tcp_transport.dart';

const _flexRadioTcpKey = 'flexradio-tcp';
const _q900SerialKey = 'q900-serial';
const _q900BluetoothKey = 'q900-bluetooth';
const _placeholderRadioKey = 'placeholder-radio';

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
