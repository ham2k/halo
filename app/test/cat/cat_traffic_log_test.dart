// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// DEVLOGCAT: the recording an operator sends us when their rig misbehaves in
// a way nobody here can reproduce. What these pin is what that diagnosis
// reads — both directions of traffic, the moments the app decided something
// about the link — and the rules that keep a recording from outliving its
// purpose.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:ham2k_logger/services/cat/cat_traffic_log.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/cat/transport.dart';
import 'package:ham2k_logger/services/cat/transports/ble_serial_transport.dart';
import 'package:ham2k_logger/services/cat/transports/serial_transport_io.dart';
import 'package:ham2k_logger/services/radio_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/error_reporting_fakes.dart';
import '../support/halo_harness.dart';

/// Files in memory, by path — what survives a "restart" is whatever a path
/// still holds.
class _Disk {
  final files = <String, StringBuffer>{};
  final opened = <String?>[];
  var _next = 0;

  /// How many opens fail before one succeeds — a full disk, a folder the app
  /// may not write.
  var failOpens = 0;
  var failClose = false;
  var failRead = false;

  Future<CatTrafficFile?> open({String? resumePath}) async {
    opened.add(resumePath);
    if (failOpens > 0) {
      failOpens--;
      throw const FileSystemException('No space left on device');
    }
    final path = resumePath != null && files.containsKey(resumePath) ? resumePath : '/logs/cat-traffic-${_next++}.log';
    final buffer = files.putIfAbsent(path, StringBuffer.new);
    return _MemoryFile(this, path, buffer, utf8.encode(buffer.toString()).length);
  }

  Future<Uint8List?> read(String path) async => failRead
      ? throw const FileSystemException('Permission denied')
      : files[path] == null
      ? null
      : Uint8List.fromList(utf8.encode(files[path].toString()));

  /// [build] names the launch doing the recording.
  CatTrafficLog log({int maxBytes = catTrafficMaxBytes, String build = '26.9.0+171 next'}) =>
      CatTrafficLog(open: open, read: read, now: () => DateTime.utc(2026, 9, 24, 12, 0, 0, 123), maxBytes: maxBytes, build: build);
}

class _MemoryFile implements CatTrafficFile {
  final _Disk _disk;
  @override
  final String path;
  final StringBuffer _buffer;

  @override
  final int length;

  _MemoryFile(this._disk, this.path, this._buffer, this.length);

  @override
  void write(String text) => _buffer.write(text);

  @override
  Future<Uint8List> close() async =>
      _disk.failClose ? throw const FileSystemException('Input/output error') : Uint8List.fromList(utf8.encode(_buffer.toString()));
}

class _Connection implements EquipmentConnection, ExplainsClose {
  final _data = StreamController<Uint8List>();
  final _closed = Completer<void>();

  @override
  String? closeReason;

  /// The link going down on its own, for [reason].
  void drop(String reason) {
    closeReason = reason;
    if (!_closed.isCompleted) _closed.complete();
  }

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

  void push(List<int> bytes) => _data.add(Uint8List.fromList(bytes));
}

class _Transport extends EquipmentTransport {
  /// The latest connection made — one per connect, as a real port gives.
  var connection = _Connection();

  /// Thrown by every connect while set.
  Object? failWith;

  @override
  String get key => 'fake';
  @override
  Future<EquipmentConnection> connect(Map<String, dynamic> target, {required CatCancelToken cancel}) async {
    if (failWith case final error?) throw error;
    return connection = _Connection();
  }
}

/// A serial open failure as both serial transports word one: naming the port,
/// whose path carries the adapter's serial number.
class _PortNamingFailure implements CatUnreachable {
  @override
  String toString() => 'Could not open /dev/cu.usbserial-FTB6SPL3: Resource busy';
}

/// Asks once on start; reports a frequency for any chunk at all, and a
/// driver's own diagnostic for a chunk starting 0xDD.
class _Session implements TransceiverSession {
  final EquipmentSink sink;
  _Session(this.sink);

  @override
  void handleData(Uint8List chunk) {
    if (chunk.first == 0xDD) return sink.reportDiagnostic('radio refused the DATA read');
    sink.report(const VfoReading(freqKHz: 14074));
  }

  @override
  void startUpdates() => sink.send(const [0xFE, 0xFE, 0x94, 0xE0, 0x03, 0xFD]);
  @override
  void stopUpdates() {}
  @override
  void setFrequency(double freqKHz) {}
  @override
  void setMode(String mode) {}
  @override
  void setPower(num watts) {}
  @override
  Duration? get expectedUpdateInterval => null;
  @override
  void teardown() {}
}

class _Driver extends EquipmentDriver {
  @override
  String get key => 'fake-driver';
  @override
  String get name => 'Fake Radio';
  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) => _Session(sink);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('formatCatTraffic', () {
    test('shows the bytes as hex AND as text, so one log serves CI-V and the text protocols', () {
      // A CI-V frame is unreadable as text and a Kenwood command is tedious
      // as hex; the line that drops either column loses half the radios.
      final at = DateTime.utc(2026, 9, 24, 12, 0, 0, 123);
      expect(
        formatCatTraffic(at, 'ic7300-serial', '>', const [0xFE, 0xFE, 0x94, 0xE0, 0x03, 0xFD]),
        '2026-09-24T12:00:00.123Z ic7300-serial > FE FE 94 E0 03 FD |......|',
      );
      expect(
        formatCatTraffic(at, 'ft891-serial', '<', utf8.encode('FA014074000;')),
        '2026-09-24T12:00:00.123Z ft891-serial < 46 41 30 31 34 30 37 34 30 30 30 3B |FA014074000;|',
      );
    });
  });

  group('CatTrafficLog', () {
    test('writes nothing and opens nothing until started, and nothing after it stops', () async {
      // CatService hands it every chunk of every session whether or not
      // anyone asked — a log that wrote while off would be recording every
      // operator's radio, all the time.
      final disk = _Disk();
      final log = disk.log()..sent('r', const [1]);
      expect(disk.opened, isEmpty);

      await log.start();
      log.sent('r', const [2]);
      final recorded = await log.stop();
      log.sent('r', const [3]);

      final text = utf8.decode(recorded!.bytes);
      expect(text, contains('r > 02'));
      expect(text, isNot(contains('r > 01')));
      expect(disk.files[recorded.path].toString(), isNot(contains('r > 03')));
    });

    test('two starts in a row open one file', () async {
      // Two quick DEVLOGCATs, or one racing the launch-time resume, must not
      // open two files and leave one recording into nothing.
      final disk = _Disk();
      final log = disk.log();
      final paths = await Future.wait([log.start(), log.start()]);
      expect(paths.toSet(), hasLength(1));
      expect(disk.opened, hasLength(1));
    });

    test('a failed open does not stop the next start from trying again', () async {
      // Kept after a failure, the one open would hand its error to every
      // start for the rest of the session — the operator frees the disk and
      // DEVLOGCAT still refuses.
      final disk = _Disk()..failOpens = 1;
      final log = disk.log();
      await expectLater(log.start(), throwsA(isA<FileSystemException>()));
      expect(await log.start(), isNotNull);
      expect(log.active, isTrue);
    });

    test('the size limit covers the whole recording, not each launch of it', () async {
      // Counted from zero at every resume, a recording carried across a
      // restart could reach twice the limit the upload was sized for.
      final disk = _Disk();
      final before = disk.log(maxBytes: 300);
      await before.start();
      for (var i = 0; i < 3; i++) {
        before.received('r', const [0xFE, 0xFE, 0xE0, 0x94, 0x00, 0xFD]);
      }
      final path = (await before.stop())!.path;
      final after = disk.log(maxBytes: 300);
      await after.start(resumePath: path);
      after.received('r', const [0xFE, 0xFE, 0xE0, 0x94, 0x00, 0xFD]);
      expect(disk.files[path].toString(), contains('size limit reached'));
    });

    test('says "resumed" only when there was an earlier half to resume', () async {
      final disk = _Disk();
      final log = disk.log();
      await log.start(resumePath: '/gone/cat-traffic.log');
      expect(utf8.decode((await log.stop())!.bytes), contains('recording started by'));
    });

    test('stops growing at its size limit, and says so once', () async {
      // A recording forgotten on a chatty rig must not fill the disk, and a
      // log that ends without saying why reads as the radio going quiet.
      final disk = _Disk();
      final log = disk.log(maxBytes: 200);
      await log.start();
      for (var i = 0; i < 20; i++) {
        log.received('r', const [0xFE, 0xFE, 0xE0, 0x94, 0x00, 0x00, 0x40, 0x07, 0x14, 0x00, 0xFD]);
      }
      final text = utf8.decode((await log.stop())!.bytes);
      expect('size limit reached'.allMatches(text), hasLength(1));
      expect(text.length, lessThan(400));
    });
  });

  test('the real file keeps what was written before a restart', () async {
    // Opened without append, the relaunch would truncate the half of the
    // recording that caught the problem.
    final dir = await Directory.systemTemp.createTemp('cat-traffic');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/cat-traffic.log';
    await File(path).writeAsString('before\n');

    final file = (await openCatTrafficFile(resumePath: path))!..write('after\n');
    expect(utf8.decode(await file.close()), 'before\nafter\n');
    expect(utf8.decode((await readCatTrafficFile(path))!), 'before\nafter\n');
  });

  group('CatService feeds the log', () {
    late CatService cat;
    late _Transport transport;
    late CatTrafficLog log;
    late _Disk disk;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final radio = RadioService(prefs, writeDelay: Duration.zero);
      addTearDown(radio.dispose);
      transport = _Transport();
      cat = CatService(
        SettingsService(prefs),
        radio: radio,
        registry: EquipmentRegistry(
          models: [
            EquipmentModel(
              key: 'fake',
              category: kCategoryTransceiver,
              name: () => 'Fake Radio',
              variants: [EquipmentVariant(key: 'fake-type', driver: _Driver(), transport: transport)],
            ),
          ],
          transports: {'fake': transport},
        ),
        staleAfter: const Duration(milliseconds: 20),
      );
      addTearDown(cat.dispose);
      disk = _Disk();
      log = disk.log();
      cat.trafficLog = log;
    });

    Future<String> recorded() async => utf8.decode((await log.stop())!.bytes);

    String label(EquipmentNode node) => 'fake-type#${node.uuid.substring(0, 4)}';

    /// A timer fires late, never early, so this waits for what the log says
    /// rather than for a guess at how long the silence watch takes.
    Future<void> until(String text) async {
      for (var i = 0; i < 500 && !disk.files.values.single.toString().contains(text); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    }

    test('records what went out, what came back, and when the app gave up on the radio', () async {
      // The field question is exactly this sequence: did our polls go out,
      // did the radio answer, and what did the app conclude from the
      // silence. Losing any one of the four makes the other three unreadable.
      await log.start();
      final node = await cat.addNode(typeKey: 'fake-type', config: {'baudRate': 19200});
      await cat.connect(node.uuid);
      await until('marked not responding');
      transport.connection.push(const [0xFE, 0xFE, 0xE0, 0x94, 0x03, 0xFD]);
      await until('answering again');

      final text = await recorded();
      final radio = label(node);
      expect(text.indexOf('$radio -- connecting'), lessThan(text.indexOf('$radio -- connected at 19200 baud')));
      expect(text, contains('$radio > FE FE 94 E0 03 FD'));
      expect(text, contains('$radio -- nothing heard for'));
      expect(text, contains('$radio < FE FE E0 94 03 FD'));
      expect(text.indexOf('marked not responding'), lessThan(text.indexOf('answering again')));
    });

    test('says why the transport closed, which is what tells the phone\'s network from the radio', () async {
      // Whether the radio went quiet or this device's own network vanished
      // is the whole diagnosis, and only the transport knows which: a log
      // that drops its reason shows a healthy link and then a bare "closed".
      await log.start();
      final node = await cat.addNode(typeKey: 'fake-type', config: {});
      await cat.connect(node.uuid);
      transport.connection.drop('socket error: Network is unreachable (errno 101), on the control channel');
      await until('closed by the transport');

      expect(
        await recorded(),
        contains('${label(node)} -- connection closed by the transport: socket error: Network is unreachable (errno 101), on the control channel'),
      );
    });

    test('a failed connect carries the OS\'s own words, and never the address or the port path', () async {
      // "Network is unreachable" is what says this device has no network at
      // all, where the exception type alone says nothing. The rest of the
      // error stays out: the log leaves the device, a SocketException names
      // the address, and a serial error names the adapter.
      await log.start();
      final node = await cat.addNode(typeKey: 'fake-type', config: {});
      transport.failWith = SocketException(
        'Connection failed',
        osError: const OSError('Network is unreachable', 101),
        address: InternetAddress('192.0.2.17'),
        port: 50001,
      );
      await cat.connect(node.uuid);
      transport.failWith = _PortNamingFailure();
      await cat.connect(node.uuid);
      transport.failWith = const SerialPortUnavailable('/dev/cu.usbserial-FTB6SPL3', 'Input/output error', osError: OSError('Input/output error', 5));
      await cat.connect(node.uuid);

      final text = await recorded();
      expect(text, contains('${label(node)} -- connect failed: network (SocketException: Network is unreachable (errno 101))'));
      expect(text, contains('${label(node)} -- connect failed: other (_PortNamingFailure)'));
      expect(text, contains('${label(node)} -- connect failed: serial:other (SerialPortUnavailable: Input/output error (errno 5))'));
      expect(text, isNot(contains('192.0.2.17')));
      expect(text, isNot(contains('50001')));
      expect(text, isNot(contains('usbserial')));
    });

    test('two radios of the same model are told apart', () async {
      // An SO2R shack's two IC-7300s would otherwise interleave on one
      // label, and the log could not say which rig went quiet.
      await log.start();
      final left = await cat.addNode(typeKey: 'fake-type', config: {});
      final right = await cat.addNode(typeKey: 'fake-type', config: {});
      await cat.connect(left.uuid);
      await cat.connect(right.uuid);
      final text = await recorded();
      expect(label(left), isNot(label(right)));
      expect(text, contains('${label(left)} -- connected'));
      expect(text, contains('${label(right)} -- connected'));
    });

    test('carries what the driver says about the radio', () async {
      // The screen shows a driver's diagnostics only in developer mode, and
      // the operators running DEVLOGCAT are not in it.
      await log.start();
      final node = await cat.addNode(typeKey: 'fake-type', config: {});
      await cat.connect(node.uuid);
      transport.connection.push(const [0xDD]);
      await pumpEventQueue();
      expect(await recorded(), contains('${label(node)} -- driver: radio refused the DATA read'));
    });
  });

  group('DEVLOGCAT', () {
    test('a recording carries across ONE restart, and the launch after that sends it', () async {
      // Carried, because a rig that only misbehaves after a relaunch is the
      // one an operator restarts to show us. Ended, because an operator who
      // forgets it would otherwise record forever — and ended by SENDING, or
      // the forgotten recording is lost exactly when it has the most in it.
      final backend = FakeErrorReportingBackend();
      await withErrorHooks(backend: backend, () async {
        final disk = _Disk();

        final first = (await makeHaLoServices(catTrafficLog: disk.log())).services;
        await first.settings.setSettingValue(SettingsService.privacyGroup, 'consentAppData', true);
        final started = await first.handleCommandAction('devLogCat');
        expect(started!.failed, isFalse);
        first.catTrafficLog.note('radio', 'before the restart');

        final second = (await makeHaLoServices(prefs: null, catTrafficLog: disk.log(build: '26.9.0+172 next'))).services;
        await second.catTraffic.resume();
        expect(second.catTrafficLog.active, isTrue);
        expect(disk.opened.last, '/logs/cat-traffic-0.log', reason: 'the restart appends to the same file');
        expect(backend.diagnostics, isEmpty);

        final third = (await makeHaLoServices(prefs: null, catTrafficLog: disk.log())).services;
        await third.catTraffic.resume();
        expect(third.catTrafficLog.active, isFalse);
        expect(backend.diagnostics.single.$1, 'DEVLOGCAT');
        final uploaded = utf8.decode(backend.diagnosticAttachments.single!.bytes);
        expect(uploaded, contains('before the restart'));
        // An update between the two launches is only visible here.
        expect(uploaded, contains('recording started by 26.9.0+171 next'));
        expect(uploaded, contains('recording resumed after a restart by 26.9.0+172 next'));

        final fourth = (await makeHaLoServices(prefs: null, catTrafficLog: disk.log())).services;
        await fourth.catTraffic.resume();
        expect(backend.diagnostics, hasLength(1), reason: 'sent once, not at every launch after');
      });
    });

    test('a recording carries what the Bluetooth LE transport noted', () async {
      // The transport is const and reaches the recording only through this
      // wiring: without it, a field recording of a bridge nobody here has met
      // holds the bytes and none of the GATT table that explains them.
      final disk = _Disk();
      final services = (await makeHaLoServices(catTrafficLog: disk.log())).services;
      addTearDown(() => BleSerialTransport.onNote = null);
      await services.handleCommandAction('devLogCat');
      BleSerialTransport.onNote?.call('services: 12345678-0000-0000-0000-000000000000');
      expect(disk.files.values.single.toString(), allOf(contains('ble'), contains('12345678-0000-0000-0000-000000000000')));
    });

    test('a spent recording is NOT sent at launch without consent to share app data', () async {
      // The launch-time send is the app's own initiative and carries the
      // radios' setup — the adapter's serial number among it — so it asks
      // what the first-success radio report asks.
      final backend = FakeErrorReportingBackend();
      await withErrorHooks(backend: backend, () async {
        final disk = _Disk();
        final first = (await makeHaLoServices(catTrafficLog: disk.log())).services;
        await first.handleCommandAction('devLogCat');
        await (await makeHaLoServices(prefs: null, catTrafficLog: disk.log())).services.catTraffic.resume();

        final last = (await makeHaLoServices(prefs: null, catTrafficLog: disk.log())).services;
        await last.catTraffic.resume();
        expect(backend.diagnostics, isEmpty);
        expect(last.statusBar.activeNotices.singleWhere((n) => n.key == 'devlogcat').text, contains('/logs/cat-traffic-0.log'));
      });
    });

    test('a recording that cannot be read at launch ends once, and says where it is', () async {
      // The notice is the operator's only pointer to the file once the
      // carry is gone; left standing, the carry would fail and report at
      // every launch.
      final backend = FakeErrorReportingBackend();
      await withErrorHooks(backend: backend, () async {
        final disk = _Disk();
        final first = (await makeHaLoServices(catTrafficLog: disk.log())).services;
        await first.settings.setSettingValue(SettingsService.privacyGroup, 'consentAppData', true);
        await first.handleCommandAction('devLogCat');
        await (await makeHaLoServices(prefs: null, catTrafficLog: disk.log())).services.catTraffic.resume();

        disk.failRead = true;
        final last = (await makeHaLoServices(prefs: null, catTrafficLog: disk.log())).services;
        await last.catTraffic.resume();
        expect(last.statusBar.activeNotices.singleWhere((n) => n.key == 'devlogcat').text, contains('/logs/cat-traffic-0.log'));
        expect(last.settings.catTrafficLogCarry, isNull);
        expect(backend.diagnostics, isEmpty);
      });
    });

    test('a recording that cannot be read when stopped is left for the next launch to send', () async {
      final backend = FakeErrorReportingBackend();
      await withErrorHooks(backend: backend, () async {
        final disk = _Disk();
        final services = (await makeHaLoServices(catTrafficLog: disk.log())).services;
        await services.settings.setSettingValue(SettingsService.privacyGroup, 'consentAppData', true);
        await services.handleCommandAction('devLogCat');
        disk.failClose = true;
        final stopped = await services.handleCommandAction('devLogCat');
        expect(stopped!.failed, isTrue);
        expect(stopped.text, contains('/logs/cat-traffic-0.log'));

        disk.failClose = false;
        final next = (await makeHaLoServices(prefs: null, catTrafficLog: disk.log())).services;
        await next.catTraffic.resume();
        expect(next.catTrafficLog.active, isFalse, reason: 'sent, not resumed');
        expect(backend.diagnostics.single.$1, 'DEVLOGCAT');
      });
    });

    test('running it again stops the recording and sends it at once', () async {
      final backend = FakeErrorReportingBackend();
      await withErrorHooks(backend: backend, () async {
        final disk = _Disk();
        final services = (await makeHaLoServices(catTrafficLog: disk.log())).services;
        await services.handleCommandAction('devLogCat');
        final stopped = await services.handleCommandAction('devLogCat');

        expect(services.catTrafficLog.active, isFalse);
        expect(stopped!.text, contains('/logs/cat-traffic-0.log'));
        expect(backend.diagnosticAttachments.single!.filename, 'cat-traffic-0.log');

        final next = (await makeHaLoServices(prefs: null, catTrafficLog: disk.log())).services;
        await next.catTraffic.resume();
        expect(next.catTrafficLog.active, isFalse, reason: 'a stopped recording does not come back at the next launch');
        expect(backend.diagnostics, hasLength(1));
      });
    });
  });
}
