// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Everything in the catalogue that is not a transceiver: antenna switches,
// rotators, a plain antenna and key, and the WinKeyer.

import 'package:halo_i18n/halo_i18n.dart';

import 'drivers/antenna_driver.dart';
import 'drivers/antenna_genius_driver.dart';
import 'drivers/gs232_driver.dart';
import 'drivers/winkeyer_driver.dart';
import 'drivers/key_driver.dart';
import 'drivers/sierra_coax_driver.dart';
import 'equipment.dart';
import 'equipment_registry.dart';
import 'transports/none_transport.dart';
import 'transports/serial_transport.dart';
import 'transports/tcp_transport.dart';

const _winkeyerSerialKey = 'winkeyer-serial';
const _antennaGeniusTcpKey = 'antenna-genius-tcp';
const _sierraCoaxSerialKey = 'sierra-coax-serial';
const _gs232aSerialKey = 'gs232a-serial';
const _gs232aTcpKey = 'gs232a-tcp';

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
      defaultConfig: {'port': antennaGeniusDefaultPort, switchLayoutConfigKey: switchLayoutDevicePorts},
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
      defaultConfig: {sierraAddressConfigKey: sierraCoaxDefaultAddress, switchLayoutConfigKey: switchLayoutDevicePorts},
    ),
  ],
);

String _sierraCoaxName() => t.settings.station.models.sierraCoax;

/// A Yaesu GS-232A rotator interface — or any controller that emulates
/// one, which is most of them.
///
/// Over its own serial port, or over the network through a serial-to-TCP
/// bridge (ser2net, a remote station's port server): the protocol is the
/// same bytes either way, and a bridge has no standard port, so there is
/// nothing to prefill for it.
///
/// 9600 is a prefill rather than an override: the interface's speed is set
/// by DIP switch, anywhere from 150 to 9600 baud, and 9600 is what the
/// GS-232B and the emulators ship at.
const gs232aModel = EquipmentModel(
  key: 'gs232a',
  category: kCategoryRotator,
  name: _gs232aName,
  manufacturer: 'Yaesu',
  variants: [
    EquipmentVariant(
      key: _gs232aSerialKey,
      driver: Gs232Driver(),
      transport: SerialTransport(),
      defaultConfig: {'baudRate': 9600, rotatorAxesConfigKey: rotatorAxesAzimuth},
    ),
    EquipmentVariant(
      key: _gs232aTcpKey,
      driver: Gs232Driver(),
      // Its own key for the TCP port: the serial variant beside it has a
      // `port` too — the serial port's name, in a picker — and the editor
      // renders both variants' fields over one set of values.
      transport: TcpTransport(portConfigKey: 'tcpPort'),
      defaultConfig: {rotatorAxesConfigKey: rotatorAxesAzimuth},
    ),
  ],
);

String _gs232aName() => t.settings.station.models.gs232a;

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
  variants: [EquipmentVariant(key: _antennaKey, driver: AntennaDriver(), transport: NoneTransport())],
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
  variants: [EquipmentVariant(key: _keyKey, driver: KeyDriver(), transport: NoneTransport())],
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
