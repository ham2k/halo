// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// GPS receivers as station equipment (docs/design/cat.md § GPS receivers):
// the NMEA reader, the session over a byte stream, the station's pick of
// which receiver places it, and that pick reaching the location service.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/cw_send_queue.dart';
import 'package:ham2k_logger/services/cat/drivers/nmea_codec.dart';
import 'package:ham2k_logger/services/cat/drivers/nmea_gps_driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/cat/gps_receiver_feed.dart';
import 'package:ham2k_logger/services/cat/transport.dart';
import 'package:ham2k_logger/services/location_service.dart';
import 'package:ham2k_logger/services/radio_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Checksums computed, not copied: a wrong one here would be a test of the
// rejection path passing for the wrong reason.
const _ggaFix = r'$GNGGA,183014.00,4124.89630,N,07402.12340,W,1,07,1.20,152.3,M,-34.2,M,,*74';
const _rmcFix = r'$GNRMC,183014.00,A,4124.89630,N,07402.12340,W,0.012,,151126,,,A*72';
// The next second's fix from the same spot: a few centimetres away, one more
// satellite, a hair worse HDOP, the altitude wandering.
const _ggaJitter = r'$GNGGA,183015.00,4124.89640,N,07402.12340,W,1,08,1.30,152.9,M,-34.2,M,,*76';
const _ggaNoFix = r'$GNGGA,,,,,,0,00,99.99,,,,,,*56';
const _rmcVoid = r'$GNRMC,,V,,,,,,,,,,N*4D';
const _gsv = r'$GPGSV,1,1,03,05,45,120,32,12,30,250,28,25,10,045,*46';
const _ggaSouthEast = r'$GPGGA,183014.00,3351.12000,S,15112.50000,E,2,10,0.80,20.0,M,,M,,*6C';

class _FakeSink implements EquipmentSink, GpsSink {
  final readings = <GpsReading>[];
  var alive = 0;

  @override
  void reportGps(GpsReading reading) => readings.add(reading);
  @override
  void reportAlive() => alive++;
  @override
  void send(List<int> bytes) => fail('a GPS receiver is never spoken to');
  @override
  void report(VfoReading reading) => fail('a GPS receiver has no VFO');
  @override
  void reportPower(num watts) => fail('a GPS receiver has no power');
  @override
  void reportTransmitting(bool transmitting) => fail('a GPS receiver does not transmit');
  @override
  void reportMeter(RadioMeter meter, num value) => fail('a GPS receiver has no meters');
  @override
  void reportKeyerSpeed(int wpm) => fail('a GPS receiver has no keyer');
  @override
  void reportCwProgress(CwSendProgress? progress) {}
  @override
  void reportVoiceActivity(VoiceActivity? activity) {}
  @override
  void reportVoiceMemories(List<VoiceMemory> memories) {}
  @override
  void reportDiagnostic(String? note) {}
  @override
  void reportProblem(String? message) {}
  @override
  void reportChannels(List<EquipmentChannel> channels) => fail('a GPS receiver has no channels');
  @override
  void reportSwitchState(List<SwitchAntenna> antennas, List<SwitchPort> ports) => fail('a GPS receiver routes nothing');
}

class _Connection implements EquipmentConnection {
  final _data = StreamController<Uint8List>();
  final _closed = Completer<void>();
  @override
  Stream<Uint8List> get data => _data.stream;
  @override
  Future<void> get closed => _closed.future;
  @override
  void send(List<int> bytes) {}
  @override
  Future<void> close() async {
    if (!_closed.isCompleted) _closed.complete();
    unawaited(_data.close());
  }

  void feed(String text) => _data.add(Uint8List.fromList(ascii.encode(text)));
}

class _Transport extends EquipmentTransport {
  final opened = <_Connection>[];
  @override
  String get key => 'fake';
  @override
  Future<EquipmentConnection> connect(Map<String, dynamic> target, {required CatCancelToken cancel}) async {
    final connection = _Connection();
    opened.add(connection);
    return connection;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NMEA position sentences', () {
    test('GGA and RMC read as signed decimal degrees, any talker', () {
      // GN is what a multi-constellation receiver like the UG-353's u-blox 7
      // reports its fix as; a reader that matched GP alone would see none.
      final gga = parseNmea(_ggaFix)!.reading!;
      expect(gga.latitude, closeTo(41.414938, 1e-6));
      expect(gga.longitude, closeTo(-74.035390, 1e-6), reason: 'W is negative');
      expect(gga.hdop, 1.2);
      expect(gga.satellites, 7);
      expect(gga.altitude, 152.3);

      final rmc = parseNmea(_rmcFix)!.reading!;
      expect(rmc.latitude, gga.latitude);
      expect(rmc.longitude, gga.longitude);

      final southEast = parseNmea(_ggaSouthEast)!.reading!;
      expect(southEast.latitude, closeTo(-33.852, 1e-6), reason: 'S is negative');
      expect(southEast.longitude, closeTo(151.208333, 1e-6));
    });

    test('a receiver still searching reports no position, not 0,0', () {
      // 0,0 is a real-looking coordinate that every reader would place in
      // the Gulf of Guinea; "no fix" has to be a different answer.
      expect(parseNmea(_ggaNoFix)!.reading!.hasFix, isFalse);
      expect(parseNmea(_rmcVoid)!.reading!.hasFix, isFalse);
    });

    test('a void RMC is no fix even when it carries a position', () {
      // Some receivers repeat their last fix in a V sentence after losing
      // the sky; status, not the presence of digits, decides.
      const stale = r'$GPRMC,123519,V,4807.038,N,01131.000,E,022.4,084.4,230394,003.1,W*7D';
      expect(parseNmea(stale)!.reading!.hasFix, isFalse);
    });

    test('a damaged sentence is refused rather than read', () {
      // One dropped digit moves the station hundreds of kilometres.
      final damaged = _ggaFix.replaceFirst('4124.89630', '412.89630');
      expect(parseNmea(damaged), isNull);
    });

    test('a sentence without a checksum is not taken for the receiver', () {
      // A device on the wrong port printing `$`-led lines of its own would
      // otherwise read as a receiver that is there and never gets a fix.
      final bare = _ggaFix.substring(0, _ggaFix.indexOf('*'));
      expect(parseNmea(bare), isNull);
      expect(parseNmea(r'$HELLO'), isNull);
    });

    test('a fix whose position does not read is dropped, not reported as searching', () {
      // "Searching" would send the operator outdoors for a fix the receiver
      // already has. 61 minutes is no coordinate.
      const unreadable = r'$GPGGA,123519,4861.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,*47';
      final sentence = parseNmea(unreadable);
      expect(sentence, isNotNull, reason: 'precondition: the checksum is right, so it is the receiver talking');
      expect(sentence!.reading, isNull);
    });

    test('other sentences and other text are not positions', () {
      expect(parseNmea(_gsv)!.reading, isNull);
      expect(parseNmea(_gsv)!.type, 'GSV', reason: 'still the receiver talking');
      expect(parseNmea('hello'), isNull);
      expect(parseNmea(''), isNull);
    });
  });

  group('the NMEA session', () {
    test('lines split across chunks, and a receiver sending GGA is read from GGA alone', () {
      final sink = _FakeSink();
      final session = NmeaGpsSession(sink);
      // A u-blox second: RMC first, then GGA — and the next second's RMC.
      final text = '$_rmcFix\r\n$_ggaFix\r\n$_gsv\r\n$_rmcFix\r\n';
      final bytes = Uint8List.fromList(ascii.encode(text));
      // Serial reads end anywhere, mid-sentence included.
      session.handleData(bytes.sublist(0, 20));
      session.handleData(bytes.sublist(20, 90));
      session.handleData(bytes.sublist(90));

      // The first RMC answers (nothing says GGA is coming yet); after GGA,
      // RMC is ignored. Read too, it would report twice a second, with the
      // previous second's satellites and no HDOP.
      expect(sink.readings, hasLength(2));
      expect(sink.readings[1].hdop, 1.2);
      expect(sink.readings[1].satellites, 7);
      expect(sink.alive, 4, reason: 'every sentence, the GSV included, is the receiver still there');
    });

    test('a receiver sending only RMC is read from RMC', () {
      final sink = _FakeSink();
      NmeaGpsSession(sink).handleData(Uint8List.fromList(ascii.encode('$_rmcFix\r\n$_rmcFix\r\n')));
      expect(sink.readings, hasLength(2));
      expect(sink.readings.last.hasFix, isTrue);
    });

    test('a receiver without a fix reports that it has none', () {
      final sink = _FakeSink();
      NmeaGpsSession(sink).handleData(Uint8List.fromList(ascii.encode('$_ggaNoFix\r\n')));
      expect(sink.readings.single.hasFix, isFalse);
      expect(sink.readings.single.satellites, 0);
    });
  });

  group('which readings are worth reporting', () {
    const held = GpsReading(latitude: 41.4, longitude: -74.0, hdop: 1, satellites: 8);

    test('a receiver standing still is not news', () {
      // It wanders metres a second; each report wakes every listener of the
      // station, re-runs the nearby search and goes to every paired device.
      expect(gpsReadingSupersedes(held, const GpsReading(latitude: 41.40005, longitude: -74.0, hdop: 1.1, satellites: 9, altitude: 3)), isFalse);
    });

    test('a move past the filter is', () {
      expect(gpsReadingSupersedes(held, const GpsReading(latitude: 41.401, longitude: -74.0, hdop: 1)), isTrue, reason: 'about 110 m');
    });

    test('a more accurate fix is, however close', () {
      // The setup sheet keeps the most accurate fix it sees, so a receiver
      // settling after a cold start has to be seen settling.
      expect(gpsReadingSupersedes(held, const GpsReading(latitude: 41.4, longitude: -74.0, hdop: 0.6)), isTrue);
    });

    test('losing or gaining the fix is, and a search reports its satellites', () {
      expect(gpsReadingSupersedes(held, const GpsReading(satellites: 8)), isTrue, reason: 'no fix is no fix, however close the last one was');
      expect(gpsReadingSupersedes(const GpsReading(satellites: 2), held), isTrue);
      expect(gpsReadingSupersedes(const GpsReading(satellites: 2), const GpsReading(satellites: 3)), isTrue);
      expect(gpsReadingSupersedes(const GpsReading(satellites: 3), const GpsReading(satellites: 3)), isFalse);
    });
  });

  group('the station\'s receiver', () {
    late CatService cat;
    late _Transport transport;
    late SettingsService settings;
    late RadioService radio;

    CatService launch({Duration staleAfter = catStaleAfter}) {
      final service = CatService(
        settings,
        radio: radio,
        staleAfter: staleAfter,
        registry: EquipmentRegistry(
          models: [
            EquipmentModel(
              key: 'gps',
              category: kCategoryGps,
              name: () => 'GPS',
              variants: [EquipmentVariant(key: 'gps-fake', driver: const NmeaGpsDriver(), transport: transport)],
            ),
          ],
          transports: {'fake': transport},
        ),
      );
      addTearDown(service.dispose);
      return service;
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      settings = SettingsService(prefs);
      radio = RadioService(prefs, writeDelay: Duration.zero);
      addTearDown(radio.dispose);
      transport = _Transport();
      cat = launch();
    });

    test('the first receiver locates the station until the operator says otherwise', () async {
      expect(cat.gpsReceiver, isNull, reason: 'no receiver: the operating system answers');
      final first = await cat.addNode(typeKey: 'gps-fake');
      expect(cat.gpsReceiver, first.uuid);

      await cat.setGpsSource(null);
      expect(cat.gpsReceiver, isNull, reason: 'the operating system, picked');

      // Setting up another receiver is the operator saying where the fix
      // should come from, over an earlier pick of the operating system.
      final second = await cat.addNode(typeKey: 'gps-fake');
      expect(cat.gpsReceiver, second.uuid);

      // Removing the one picked falls back to the one left, not to the OS:
      // the station still has a receiver the operator set up.
      await cat.removeNode(second.uuid);
      expect(cat.gpsReceiver, first.uuid);
    });

    test('removing the picked receiver connects the one that takes over', () async {
      final first = await cat.addNode(typeKey: 'gps-fake');
      final second = await cat.addNode(typeKey: 'gps-fake');
      await pumpEventQueue();
      expect(cat.stateFor(first.uuid).status, EquipmentStatus.disconnected, reason: 'precondition: only the picked one is connected');

      // Picked but never connected, the station would read as unlocated
      // until the next launch.
      await cat.removeNode(second.uuid);
      await pumpEventQueue();
      expect(cat.gpsReceiver, first.uuid);
      expect(cat.stateFor(first.uuid).status, EquipmentStatus.connected);
    });

    test('a new receiver is connected and takes over from the old one', () async {
      final first = await cat.addNode(typeKey: 'gps-fake');
      await pumpEventQueue();
      expect(cat.stateFor(first.uuid).status, EquipmentStatus.connected, reason: 'picked and closed, the station would be unlocated');

      final second = await cat.addNode(typeKey: 'gps-fake');
      await pumpEventQueue();
      expect(cat.gpsReceiver, second.uuid);
      expect(cat.stateFor(second.uuid).status, EquipmentStatus.connected);
      // Left open, the first holds its port — against the second, when both
      // are entries for one dongle at different speeds.
      expect(cat.stateFor(first.uuid).status, EquipmentStatus.disconnected);
    });

    test('a receiver that goes quiet takes its fix with it', () async {
      cat = launch(staleAfter: const Duration(milliseconds: 50));
      final location = LocationService();
      addTearDown(location.dispose);
      final feed = GpsReceiverFeed(cat: cat, location: location)..start();
      addTearDown(feed.dispose);
      final node = await cat.addNode(typeKey: 'gps-fake');
      await pumpEventQueue();
      transport.opened.last.feed('$_ggaFix\r\n');
      await pumpEventQueue();
      expect(location.status, LocationStatus.available, reason: 'precondition');

      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(cat.stateFor(node.uuid).stale, isTrue, reason: 'precondition');
      expect(location.receiverName, isNull, reason: 'a silent receiver hands back to the operating system');
      expect(location.position, isNull);

      // The first sentence back is not a fix. Holding the old reading, it
      // would put the place the silence began on screen as live.
      transport.opened.last.feed('$_gsv\r\n');
      await pumpEventQueue();
      expect(location.status, LocationStatus.determining);
      expect(location.position, isNull);
    });

    test('a receiver standing still does not wake the station every second', () async {
      final node = await cat.addNode(typeKey: 'gps-fake');
      await pumpEventQueue();
      transport.opened.single.feed('$_ggaFix\r\n');
      await pumpEventQueue();
      var notified = 0;
      cat.addListener(() => notified++);

      // Every listener of the station — its panel, the logging panel, the
      // peer router — would rebuild on each one.
      transport.opened.single.feed('$_ggaJitter\r\n');
      await pumpEventQueue();
      expect(notified, 0);
      expect(cat.stateFor(node.uuid).gps!.satellites, 7, reason: 'the reading held is the one last reported');
    });

    test('picking a receiver the operator disconnected connects it', () async {
      final node = await cat.addNode(typeKey: 'gps-fake');
      await pumpEventQueue();
      await cat.disconnect(node.uuid);
      await cat.setGpsSource(null);

      // Picking it is asking for it. Left off, the station would read as
      // having a receiver that never answers.
      await cat.setGpsSource(node.uuid);
      await pumpEventQueue();
      expect(cat.stateFor(node.uuid).status, EquipmentStatus.connected);
    });

    test('picking another source lets the old receiver go', () async {
      final node = await cat.addNode(typeKey: 'gps-fake');
      await pumpEventQueue();

      // Left open, it holds its serial port against gpsd or another logger.
      await cat.setGpsSource(null);
      await pumpEventQueue();
      expect(cat.stateFor(node.uuid).status, EquipmentStatus.disconnected);

      // Not as the operator's Disconnect: picking it again brings it back.
      await cat.setGpsSource(node.uuid);
      await pumpEventQueue();
      expect(cat.stateFor(node.uuid).status, EquipmentStatus.connected);
    });

    test('picking the operating system survives a relaunch', () async {
      // Unstored, the next launch would fall back to the first receiver and
      // quietly undo the operator's choice.
      await cat.addNode(typeKey: 'gps-fake');
      await cat.setGpsSource(null);
      expect(launch().gpsReceiver, isNull);
    });

    test('a fix off the wire reaches the location service, and outranks the system', () async {
      final location = LocationService();
      addTearDown(location.dispose);
      final feed = GpsReceiverFeed(cat: cat, location: location)..start();
      addTearDown(feed.dispose);

      // Connected by being set up: nothing else here connects it.
      final node = await cat.addNode(typeKey: 'gps-fake', name: 'UG-353');
      await pumpEventQueue();
      expect(location.status, LocationStatus.determining, reason: 'connected, no fix yet');

      transport.opened.single.feed('$_ggaNoFix\r\n');
      await pumpEventQueue();
      expect(location.status, LocationStatus.determining, reason: 'a receiver indoors is still searching, not broken');
      expect(location.position, isNull);

      transport.opened.single.feed('$_ggaFix\r\n');
      await pumpEventQueue();
      expect(location.status, LocationStatus.available);
      expect(location.position!.latitude, closeTo(41.414938, 1e-6));
      expect(location.position!.accuracy, 1.2 * gpsRangeErrorMetres);
      expect(location.receiverName, 'UG-353', reason: 'the Location screen names where the fix comes from');

      // Unplugged: the operating system answers again rather than leave the
      // station unlocated — on the web, after every page load, since nothing
      // reconnects there on its own. In a VM the geolocator plugin is absent,
      // so the OS reads unknown.
      await cat.disconnect(node.uuid);
      expect(location.receiverName, isNull);
      expect(location.position, isNull, reason: 'a fix from a receiver no longer there must not linger');
    });
  });
}
