// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/echocat_driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/cat/spectrum.dart';
import 'package:ham2k_logger/services/cat/transport.dart';
import 'package:ham2k_logger/services/cat/transports/echocat_transport.dart';

const _initialStatus = {
  'type': 'status',
  'catConnected': true,
  'freq': 14074125,
  'mode': 'PKTUSB',
  'txState': true,
  'smeter': 120,
  'smeterDbm': -91.5,
  'swr': 120,
  'swrRatio': 1.4,
  'power': 45,
  'txpower': 45,
};

class _Sink implements EquipmentSink, BinaryFramesSink, SpectrumSink {
  final EquipmentConnection connection;
  final reading = Completer<VfoReading>();
  final sweep = Completer<SpectrumFrame>();
  final meters = <(RadioMeter, num)>[];

  _Sink(this.connection);

  @override
  Stream<Uint8List>? get binaryFrames => (connection as BinaryFramesConnection).binaryFrames;

  @override
  void send(List<int> bytes) => connection.send(bytes);

  @override
  void report(VfoReading value) => reading.complete(value);

  @override
  void reportMeter(RadioMeter meter, num value) => meters.add((meter, value));

  @override
  void reportSpectrum(SpectrumFrame frame) => sweep.complete(frame);

  @override
  void reportTransmitting(bool transmitting) {}

  @override
  void reportPower(num watts) {}

  @override
  void reportProblem(String? message) {}

  @override
  void reportAlive() {}

  @override
  void reportSpectrumProblem(String? message) {}

  @override
  void reportSpectrumSettings(SpectrumSettings settings) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

String _link(Map<String, String> params) => Uri(scheme: 'potacat', host: 'pair', queryParameters: params).toString();

void main() {
  test('keeps the private pin and uses CA validation only for the public Tailscale leg', () {
    final pin = List.filled(32, 'AA').join(':');
    final parsed = parseEchocatPairingLink(
      _link({'host': 'wss://192.0.2.5:7360', 'token': 'one-time', 'fp': pin, 'tsHost': 'rig.test.ts.net', 'tsCertPublic': '1'}),
    )!;
    expect(parsed.endpoints.map((e) => e.uri.toString()), ['wss://192.0.2.5:7360/', 'wss://rig.test.ts.net:7360/']);
    expect(parsed.endpoints.map((e) => e.fingerprint), [pin.replaceAll(':', '').toLowerCase(), null]);
    expect(parseEchocatPairingLink(_link({'host': 'wss://192.0.2.5:7360', 'token': 'one-time'})), isNull);
    expect(parseEchocatPairingLink(_link({'host': 'ws://192.0.2.5:7360', 'token': 'one-time', 'fp': pin})), isNull);
  });

  group('paired equipment connection', () {
    late HttpServer server;
    late String endpoint;
    late String pin;
    late List<Object?> posts;
    late List<Map<String, dynamic>> frames;
    late Completer<void> tuned;
    late Completer<void> unsubscribed;
    WebSocket? serverSocket;
    late bool redirectUpgrade;
    late List<String> upgradePaths;

    setUp(() async {
      posts = [];
      redirectUpgrade = false;
      upgradePaths = [];
      frames = [];
      tuned = Completer<void>();
      unsubscribed = Completer<void>();
      final keys = SecurityContext()
        ..useCertificateChainBytes(utf8.encode(_testCertificate))
        ..usePrivateKeyBytes(utf8.encode(_testKey));
      final der = base64.decode(_testCertificate.split('\n').where((line) => line.isNotEmpty && !line.startsWith('-----')).join());
      pin = sha256.convert(der).toString();
      server = await HttpServer.bindSecure(InternetAddress.loopbackIPv4, 0, keys);
      endpoint = 'wss://127.0.0.1:${server.port}';
      server.listen((request) async {
        if (request.uri.path == '/api/pair' && request.method == 'POST') {
          posts.add(jsonDecode(await utf8.decoder.bind(request).join()));
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({'deviceToken': 'paired-device'}));
          await request.response.close();
          return;
        }
        upgradePaths.add(request.uri.path);
        if (redirectUpgrade && request.uri.path == '/') {
          request.response
            ..statusCode = HttpStatus.found
            ..headers.set(HttpHeaders.locationHeader, '/different-station');
          await request.response.close();
          return;
        }
        final socket = serverSocket = await WebSocketTransformer.upgrade(request);
        socket.add(jsonEncode({'type': 'auth-mode', 'mode': 'token'}));
        socket.listen((frame) {
          final message = jsonDecode(frame as String) as Map<String, dynamic>;
          frames.add(message);
          switch (message) {
            case {'type': 'auth', 'token': 'paired-device'}:
              socket.add(jsonEncode({'type': 'auth-ok'}));
              socket.add(jsonEncode({'type': 'session-contacts', 'secret': 'unrelated-data'}));
              socket.add(jsonEncode(_initialStatus));
            case {'type': 'scope-subscribe', 'on': true}:
              socket.add(
                jsonEncode({
                  'type': 'scope-state',
                  'status': 'live',
                  'available': true,
                  'axis': {'known': true, 'startHz': 14024000, 'endHz': 14124000, 'anchor': 'pan'},
                  'levelScale': {'min': -130, 'max': -50},
                  'spans': [100000, 200000],
                }),
              );
              socket.add(
                jsonEncode({
                  'type': 'scope-frame',
                  'bins': [0, 255],
                }),
              );
            case {'type': 'scope-subscribe', 'on': false}:
              unsubscribed.complete();
            case {'type': 'tune', 'freqKhz': '14075.250'}:
              tuned.complete();
          }
        });
      });
    });

    tearDown(() async {
      await serverSocket?.close();
      serverSocket = null;
      await server.close(force: true);
    });

    test('pairs over TLS, authenticates with the saved token, and feeds the waterfall', () async {
      final equipment = EquipmentRegistry().typeFor('potacat-echocat')!;
      final transport = EquipmentRegistry().transportFor(equipment.transportKey) as EchocatTransportConfig;
      final pairing = await transport.pair(_link({'host': endpoint, 'token': 'one-time', 'fp': pin}));
      expect(posts.single, containsPair('pairingToken', 'one-time'));
      expect(pairing.encode(), isNot(contains('one-time')));

      final config = {echocatAddressKey: pairing.address, echocatPairingKey: pairing.encode()};
      final connection = await transport.connect(equipment.targetFor(config), cancel: CatCancelToken());
      addTearDown(connection.close);
      final sink = _Sink(connection);
      final session = equipment.driver.createSession(sink, const {}) as EchocatSession;
      addTearDown(session.teardown);
      final visibleTraffic = <Object?>[];
      final traffic = connection.data.listen((data) {
        visibleTraffic.add(jsonDecode(utf8.decode(data)));
        session.handleData(data);
      });
      addTearDown(traffic.cancel);

      session.startUpdates();
      expect(await sink.reading.future, const VfoReading(freqKHz: 14074.125, mode: 'DATA-USB'));
      expect(sink.meters, [(RadioMeter.signalDbm, -91.5), (RadioMeter.swr, 1.4)]);
      session.setFrequency(14075.250);
      await tuned.future;

      session.startSpectrum();
      final sweep = await sink.sweep.future;
      expect((sweep.lowHz, sweep.highHz), (14024000, 14124000));
      expect(sweep.levels, [-130, -50]);
      expect(session.spectrumCapabilities.spansHz, [50000, 100000]);
      session.stopSpectrum();
      await unsubscribed.future;

      expect(visibleTraffic, [_initialStatus]);
      expect(frames.where((frame) => frame['type'] == 'auth').single['token'], 'paired-device');

      serverSocket!.add(jsonEncode({'type': 'kicked'}));
      await connection.closed;
      expect((connection as RequiresManualReconnect).manualReconnectReason, isNotNull);
    });

    test('an upgraded session stays on the paired address even when it redirects', () async {
      const transport = EchocatTransport();
      final pairing = await transport.pair(_link({'host': endpoint, 'token': 'one-time', 'fp': pin}));
      redirectUpgrade = true;
      await expectLater(transport.connect({echocatPairingKey: pairing.encode()}, cancel: CatCancelToken()), throwsA(isA<EchocatFailure>()));
      expect(upgradePaths, ['/']);
      expect(frames, isEmpty);
    });

    test('a mismatched TLS certificate never receives the pairing token', () async {
      const transport = EchocatTransport();
      final link = _link({'host': endpoint, 'token': 'one-time', 'fp': List.filled(64, '0').join()});
      await expectLater(transport.pair(link), throwsA(isA<EchocatFailure>()));
      expect(posts, isEmpty);
      expect(frames, isEmpty);
    });
  });
}

// A self-signed certificate and private key for this loopback fixture only.
const _testCertificate = '''
-----BEGIN CERTIFICATE-----
MIICpjCCAY4CCQD2w/JFuXY2xDANBgkqhkiG9w0BAQsFADAUMRIwEAYDVQQDDAls
b2NhbGhvc3QwIBcNMjYxMTE4MjIzMTMxWhgPMjEyNjEwMjUyMjMxMzFaMBQxEjAQ
BgNVBAMMCWxvY2FsaG9zdDCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEB
ALcA7V6CKWkvo9aVgt8ivtDLyMWD2ppu3aC9a4nnOzd9Ks3kmmRhIyO4DHIQ4//6
1imqdHX2HhNRcLcpOy8oqF+nYuUM4xIwWk/JGlt5INe4fZZ6blPNXTdVP6wjunn+
Pw3rSd172rz6YjKbnqrrjPHYmIhgUzGvLLOqE95q4Z5WT6zpxuef2vRR5zcNpJJ6
lWR0bE3h/En8cVXZSIk1wQaGlfad9H/q5EgnbJk6thcRttex50rW64gDj1C3tbbR
HN9uHTKLp2Z8OB3gPyby7oFXHedS57ZFVvXgrVsONh+EiLI/cLTXALyhrLEAexPh
rKo2gfAaQTpP07Gs1CWJCN0CAwEAATANBgkqhkiG9w0BAQsFAAOCAQEAI9e6xJvh
PSGkSEjTnk8XP0JVkdQzprl1oNRotK4zSbQCXPEcImEGjo8HbpNFWnpIIun9EfWN
LHYbvQG9uE3PajbdFmPVEdwpl3WzD3i5VmC6dVQ52cbfbRI6wz+Aj1oKjvgrYcsb
T2eN0Ft72Tjxv36Mn/u5YO/t7/+me8w+TMjomzch77oXaw+4Dwfc7V+8Nvq0MIlE
axJjHX+wQ1Tg9FTd8X1heRxn07NCjTAgDK4GNL5HSsOXXw6f/g5ulwvbhh56/RUI
2ACEuiwF/EY2UjpdwGpgS0UfZLp6SbZTBitQOoylSGg15N5/RqoelBVv8tIn1FFJ
sr9WpCVISkmTTg==
-----END CERTIFICATE-----
''';
const _testKey = '''
-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC3AO1egilpL6PW
lYLfIr7Qy8jFg9qabt2gvWuJ5zs3fSrN5JpkYSMjuAxyEOP/+tYpqnR19h4TUXC3
KTsvKKhfp2LlDOMSMFpPyRpbeSDXuH2Wem5TzV03VT+sI7p5/j8N60nde9q8+mIy
m56q64zx2JiIYFMxryyzqhPeauGeVk+s6cbnn9r0Uec3DaSSepVkdGxN4fxJ/HFV
2UiJNcEGhpX2nfR/6uRIJ2yZOrYXEbbXsedK1uuIA49Qt7W20Rzfbh0yi6dmfDgd
4D8m8u6BVx3nUue2RVb14K1bDjYfhIiyP3C01wC8oayxAHsT4ayqNoHwGkE6T9Ox
rNQliQjdAgMBAAECggEAUWRcLlh9yoahu+KrXkq5y2uXVCGcrGr6r28P0TnCoJ9O
1lwCPvrlAhHtlx3kCgmqDsX9HinknnruQshXxlWy7TgpR+4/X+uZfzrWOjDZZphr
Yu34+9SuzNlhhFIvsepeaPZo19UqKDrESfXkz+gLu9S1opIU7lgW7aGLTLUEu8Kv
C5xADiyA22i6vhduQbrGGMZqipgSmFnDsUZSUnATfIoA6HXCMA9qhFVdKzQxnJ5V
z4FrlXxoTwEb6xCzNotesIB6qqmnngvO5zqD63NfgxKfk1yiGw3yAm4ZZJus3+pU
PmxiCSDTlj81KAcu1urygT48ZcYOxHOK9PI5xTc4gQKBgQDZkaUbohyhPUkC+IPf
FRZ79Y0iXJNhpOszrY1i9X2gW/pSuC/iIGryCO36zMq/rh0TngdhGFiJNvZJif49
lhCOW+PLt1oZHcLLNffjatydKW8/37emQjq7tniERuwqEA3MtEeib36szS/6H7dc
zU/LBg2rWAZq5xWiVrvvUHvnxQKBgQDXVEHKjVDJJ+WZ4dfmXL7GLTQyXF0RUFP9
TkXkljFHGBvLotii2eHeeGs2SBYyDi1sVZogQaud+WwrxxsCGB9UVoJ0y6QQIY7o
k16v7TTkEHctwoB5EYiTufFrRuNTPVEbiruNTN+Bgil5K4sIuMzjm17I/41Qzhhv
4lxe/OGWOQKBgQC1tj7/5VWkFVt1b7o0B5jPzzYhDNDLLMKEVt9PV1mlJSzdCZh0
dD7eBzc70O9FSFZgnAvtvDe14oGwyd/d8AfD3ltTOb+2WnTm5Bw1hHrdiE2yO1dX
NNl5Dd16HQIB34anAasSr6xNBtKbRQIQMCoElvmzscEqZ/ZZr7cnGUFjQQKBgE4o
eyj2WlhpbuGIJEGtcGGmjseo1u8t5Q6QlrX9/iz8BzrHBTM3OtDxjJjLWaMZmks0
VxlWPOC+ZBEP2DHOZ7DJJdkXAZoJVEH/G+Nnikct4tRtQQyw3I4idAqoVGMmYoZI
uQL04Du17y/YKkMkMNp8zs7OU5D8/cm+tCCWUZuhAoGASS1KaMrCLiKubrtACNyR
6mABJk8L1GpA2Bv6AWUbjtMKdCefWjLqzfoVN8jt0EiL93F1QSUk3AkM2c/VaHcR
0hLLjseu6O+Kc/berykLMeuUSui7l8kzmNjF1HlrMLmAyQYITWoy181J1hND92ox
5wsuYBNYTxRrJbmmswEaVmE=
-----END PRIVATE KEY-----
''';
