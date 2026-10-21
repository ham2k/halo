// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Which characteristics carry the bytes on a Bluetooth LE serial bridge. BLE
// has no serial profile of its own: every UART-over-BLE module invents one —
// a service holding a characteristic to write to and one that notifies — and
// a handful of those inventions are what nearly every bridge ships. They are
// listed here, and anything else gets one chance by shape (see
// [pickBleSerialProfile]).
//
// Pure: no plugin, no platform. See docs/design/cat.md § Bluetooth LE serial.

/// What a discovered characteristic can do, as far as choosing a pipe needs.
class BleSerialCharacteristic {
  const BleSerialCharacteristic(this.uuid, {this.write = false, this.writeWithoutResponse = false, this.notify = false, this.indicate = false});

  /// Lower-case, full 128-bit form.
  final String uuid;
  final bool write;
  final bool writeWithoutResponse;
  final bool notify;
  final bool indicate;

  bool get writable => write || writeWithoutResponse;
  bool get readable => notify || indicate;
}

class BleSerialService {
  const BleSerialService(this.uuid, this.characteristics);

  /// Lower-case, full 128-bit form.
  final String uuid;
  final List<BleSerialCharacteristic> characteristics;

  BleSerialCharacteristic? characteristic(String uuid) => characteristics.where((c) => c.uuid == uuid).firstOrNull;
}

/// A known bridge layout. [rx] is written to, [tx] notifies — named from the
/// module's side, as every vendor names them.
class BleSerialProfile {
  const BleSerialProfile({required this.name, required this.service, required this.rx, required this.tx, this.maxWrite});

  final String name;
  final String service;
  final String rx;
  final String tx;

  /// The most a single write may carry, where the module drops anything
  /// longer whatever the negotiated MTU says. Null takes the MTU's word.
  final int? maxWrite;
}

String _sig(String short) => '0000$short-0000-1000-8000-00805f9b34fb';

/// Nordic's UART Service: nRF modules, ESP32 sketches, most hobby bridges.
const nordicUartProfile = BleSerialProfile(
  name: 'Nordic UART',
  service: '6e400001-b5a3-f393-e0a9-e50e24dcca9e',
  rx: '6e400002-b5a3-f393-e0a9-e50e24dcca9e',
  tx: '6e400003-b5a3-f393-e0a9-e50e24dcca9e',
);

/// The TI CC254x layout of HM-10, JDY-08 and their clones: one
/// characteristic both ways. Writes past 20 bytes are dropped by the module,
/// not refused, so this one is paced at 20 whatever the MTU.
final hm10Profile = BleSerialProfile(name: 'HM-10', service: _sig('ffe0'), rx: _sig('ffe1'), tx: _sig('ffe1'), maxWrite: 20);

/// Microchip's Transparent UART: RN4870/71, BM70/71.
const microchipUartProfile = BleSerialProfile(
  name: 'Microchip Transparent UART',
  service: '49535343-fe7d-4ae5-8fa9-9fafd205e455',
  rx: '49535343-8841-43f4-a8d4-ecbe34729bb3',
  tx: '49535343-1e4d-4bd9-ba61-23c647249616',
);

final knownBleSerialProfiles = [nordicUartProfile, hm10Profile, microchipUartProfile];

/// Services every BLE device carries and no bridge puts its pipe in: GAP,
/// GATT, Device Information, Battery. Left out of the by-shape guess, where a
/// writable, notifying characteristic in one of them would otherwise count.
final _standardServices = {_sig('1800'), _sig('1801'), _sig('180a'), _sig('180f')};

/// The pipe a connection uses: which characteristic to write, which to
/// subscribe to, and how.
class BleSerialPipe {
  const BleSerialPipe({
    required this.name,
    required this.service,
    required this.rx,
    required this.tx,
    required this.withoutResponse,
    required this.indicate,
    this.maxWrite,
  });

  /// The profile's name, or `'by shape'` for a guessed one — said in the
  /// diagnostic, so a field report names what was used.
  final String name;
  final String service;
  final String rx;
  final String tx;

  /// Writes go without response wherever [rx] allows it: a response per
  /// write halves throughput, and a CAT poll is many small writes.
  final bool withoutResponse;

  /// [tx] only indicates — subscribed as an indication rather than a notify.
  final bool indicate;

  final int? maxWrite;
}

/// The pipe in [services], or null when there is none to be found or more
/// than one to choose from.
///
/// A known profile wins, in [knownBleSerialProfiles]' order. Failing that, a
/// layout is accepted by shape only when it is the ONLY candidate: exactly
/// one non-standard service with exactly one writable and one notifying
/// characteristic (the same one, HM-10 style, or two). Where some candidates
/// are among the services the device [advertised], only those count: a
/// bridge advertises the service it is meant to be found by — Lab599's own
/// guidance for the LiNK500MP — while an update or settings service beside
/// it goes unannounced. Several candidates still return null rather than a
/// guess — writing CAT into the wrong vendor characteristic could do
/// anything, and the failure names what was found.
BleSerialPipe? pickBleSerialProfile(List<BleSerialService> services, {Iterable<String> advertised = const []}) {
  for (final profile in knownBleSerialProfiles) {
    final service = services.where((s) => s.uuid == profile.service).firstOrNull;
    final rx = service?.characteristic(profile.rx);
    final tx = service?.characteristic(profile.tx);
    if (rx == null || tx == null || !rx.writable || !tx.readable) continue;
    return _pipe(profile.name, profile.service, rx, tx, maxWrite: profile.maxWrite);
  }

  final candidates = [
    for (final service in services)
      if (!_standardServices.contains(service.uuid) && service.characteristics.any((c) => c.writable) && service.characteristics.any((c) => c.readable))
        service,
  ];
  final announced = {for (final uuid in advertised) uuid.toLowerCase()};
  final preferred = candidates.where((s) => announced.contains(s.uuid)).toList();
  final pool = preferred.isEmpty ? candidates : preferred;
  if (pool.length != 1) return null;
  final service = pool.single;
  final writable = service.characteristics.where((c) => c.writable).toList();
  final readable = service.characteristics.where((c) => c.readable).toList();
  if (writable.length != 1 || readable.length != 1) return null;
  return _pipe('by shape', service.uuid, writable.single, readable.single);
}

BleSerialPipe _pipe(String name, String service, BleSerialCharacteristic rx, BleSerialCharacteristic tx, {int? maxWrite}) =>
    BleSerialPipe(name: name, service: service, rx: rx.uuid, tx: tx.uuid, withoutResponse: rx.writeWithoutResponse, indicate: !tx.notify, maxWrite: maxWrite);

/// Whether a scan result advertises a known profile's service — the picker
/// lists those first. Most bridges advertise their service; one that does
/// not still connects, it just sorts with everything else.
bool advertisesBleSerial(Iterable<String> serviceUuids) => serviceUuids.any((uuid) => knownBleSerialProfiles.any((p) => p.service == uuid));

/// A GATT table as one line, for the failure that found no pipe: the one
/// thing an operator can send that lets a bridge be added to the list.
String describeBleServices(List<BleSerialService> services) => [
  for (final service in services)
    if (!_standardServices.contains(service.uuid)) '${service.uuid} [${[for (final c in service.characteristics) '${c.uuid} ${_flags(c)}'].join(', ')}]',
].join('; ');

String _flags(BleSerialCharacteristic c) => [if (c.write) 'w', if (c.writeWithoutResponse) 'wnr', if (c.notify) 'n', if (c.indicate) 'i'].join('/');
