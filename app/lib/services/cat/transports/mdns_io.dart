// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// One-shot Multicast DNS over sockets: resolving a `.local` host, and
// browsing for a service type while the Add dialog is open.
//
// The OS resolver handles `.local` on macOS, iOS and Windows, but not on
// Android, nor on a Linux without nss-mdns — and on those a rig typed in
// as `sotacat.local` simply fails to resolve. [lookupHost] asks both, and
// the first answer wins. Windows is asked too: its resolver misses `.local`
// names often enough to matter.
//
// On macOS and iOS, mDNSResponder IS the OS resolver, so a lookup asks it
// alone rather than binding a socket per interface on every connect.
//
// iOS is the exception for browsing too: it refuses to SEND multicast without
// `com.apple.developer.networking.multicast`, a restricted entitlement the
// app does not hold (docs/design/cat.md § Entitlements). There the OS
// resolver alone answers a lookup, and a browse goes through the native
// NetServiceBrowser behind the `ham2k/bonjour` channel, which needs only
// the type listed under NSBonjourServices.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../error_reporting_service.dart';

import 'mdns_codec.dart';

export 'mdns_codec.dart' show MdnsService, isMdnsHost;

/// The first IPv4 address for [host], racing the OS resolver against a
/// one-shot mDNS query when [host] is a `.local` name.
///
/// A failure to resolve throws the OS resolver's own error, so a name that
/// neither side knows fails the way any unresolvable name does.
Future<InternetAddress> lookupHost(String host) {
  final system = InternetAddress.lookup(host, type: InternetAddressType.IPv4).then((addresses) => addresses.first);
  if (!isMdnsHost(host) || _osResolvesMdns) return system;
  return firstLookupAnswer(system, mdnsLookupIPv4(host), host: host);
}

bool get _osResolvesMdns => Platform.isIOS || Platform.isMacOS;

/// What `Socket.connect` should dial for [host]: the name itself whenever
/// the OS resolver knows it, or the address mDNS found when only mDNS does.
///
/// The name rather than [lookupHost]'s one address because connect tries
/// every address a name has, in order — and a Mac running flrig answers
/// `shack.local` with a Thunderbolt-bridge link-local address first.
Future<Object> connectTarget(String host) {
  if (!isMdnsHost(host) || _osResolvesMdns) return Future.value(host);
  final system = InternetAddress.lookup(host).then<Object>((_) => host);
  return firstLookupAnswer<Object>(system, mdnsLookupIPv4(host), host: host);
}

/// The first of [system] and [mdns] to find an answer.
///
/// NOT `Future.any`: that settles on the first future to finish, and the OS
/// resolver on Android FAILS a `.local` name quickly — exactly the case the
/// mDNS answer arriving a moment later is for.
@visibleForTesting
Future<T> firstLookupAnswer<T extends Object>(Future<T> system, Future<T?> mdns, {required String host}) {
  final winner = Completer<T>();
  Object? systemError;
  StackTrace? systemStack;
  var pending = 2;
  void lost() {
    pending -= 1;
    if (pending > 0 || winner.isCompleted) return;
    winner.completeError(systemError ?? SocketException('No mDNS answer for $host'), systemStack);
  }

  void won(T? answer) {
    if (answer == null) return lost();
    if (!winner.isCompleted) winner.complete(answer);
  }

  unawaited(
    system.then(
      won,
      onError: (Object e, StackTrace st) {
        systemError = e;
        systemStack = st;
        lost();
      },
    ),
  );
  // [mdnsLookupIPv4] turns every expected failure into null, so an error
  // here is a defect — and on Android, where the OS never resolves `.local`,
  // the OS resolver's "not found" would otherwise be all anyone sees of it.
  unawaited(
    mdns.then(
      won,
      onError: (Object e, StackTrace st) {
        ErrorReportingService.report(e, st, context: 'cat:mdns-lookup');
        lost();
      },
    ),
  );
  return winner.future;
}

/// [host]'s IPv4 address by one-shot mDNS, or null when nothing answered
/// within [timeout].
///
/// Asked twice, a second apart: a responder on a sleepy ESP32 Wi-Fi radio
/// misses the first datagram often enough to matter.
Future<InternetAddress?> mdnsLookupIPv4(String host, {Duration timeout = const Duration(seconds: 3)}) async {
  final name = normalizeMdnsName(host);
  final question = [(name: name, type: mdnsTypeA)];
  final querier = _MdnsQuerier();
  final retry = Timer(const Duration(seconds: 1), () => querier.ask(question));
  try {
    await querier.refresh();
    if (querier.isEmpty) return null;
    querier.ask(question);
    final answer = await querier.records.firstWhere((record) => record.type == mdnsTypeA && record.name == name).timeout(timeout);
    return InternetAddress(answer.address!);
  } on TimeoutException {
    return null;
  } finally {
    retry.cancel();
    querier.close();
  }
}

/// Instances of [serviceType] (`_sotacat._tcp.local`) as they answer,
/// asking again every [interval] for as long as the subscription lives.
///
/// Every answer re-emits what is known so far: like a Flex's broadcast, the
/// consumer keys findings by id, and re-emitting is what lets a unit that
/// moved to a new host update in place.
///
/// No network is "nothing found", never an error: an operator opening the
/// Add dialog before joining the SOTAcat's own access point is the ordinary
/// case, not a fault. Each tick binds any interface that came up since the
/// last, so joining that network while the dialog is open is noticed.
Stream<MdnsService> mdnsBrowse(String serviceType, {Duration interval = const Duration(seconds: 3)}) {
  if (Platform.isIOS) return _bonjourBrowse(serviceType);

  final querier = _MdnsQuerier();
  Timer? timer;
  final seen = <String, MdnsRecord>{};
  late final StreamController<MdnsService> controller;

  // Each tick schedules the next once it is done, so a slow interface
  // listing never overlaps the one after it.
  Future<void> tick() async {
    await querier.refresh();
    if (querier.isClosed) return;
    querier.ask(mdnsFollowUpQuestions(seen.values, serviceType));
    timer = Timer(interval, () => unawaited(tick()));
  }

  controller = StreamController<MdnsService>(
    onListen: () {
      querier.responses.listen((records) {
        for (final record in records) {
          seen['${record.name}|${record.type}|${record.type == mdnsTypePtr ? record.target : ''}'] = record;
        }
        if (controller.isClosed) return;
        mdnsServicesIn(seen.values, serviceType).values.forEach(controller.add);
      });
      unawaited(tick());
    },
    onCancel: () {
      timer?.cancel();
      querier.close();
    },
  );
  return controller.stream;
}

/// One socket per IPv4 interface address, each bound to an ephemeral port.
///
/// One per interface because a multicast datagram leaves by ONE interface,
/// whichever the routing table picks: a laptop on Ethernet and on the
/// SOTAcat's own access point would otherwise ask only the Ethernet side.
class _MdnsQuerier {
  final _live = <String, RawDatagramSocket>{};
  final _responses = StreamController<List<MdnsRecord>>.broadcast();
  var _closed = false;

  bool get isClosed => _closed;

  /// No interface would bind — no network at all, or every interface
  /// refusing — which every caller treats as nothing found.
  bool get isEmpty => _live.isEmpty;

  Stream<List<MdnsRecord>> get responses => _responses.stream;

  Stream<MdnsRecord> get records => _responses.stream.expand((records) => records);

  /// Binds every IPv4 interface address not already bound. A network joined
  /// since the last call gains its socket here; one that went away lost its
  /// socket when a send to it failed.
  Future<void> refresh() async {
    final List<NetworkInterface> interfaces;
    try {
      interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
    } on SocketException catch (e) {
      debugPrint('[mdns] cannot list interfaces: $e');
      return;
    }
    for (final address in interfaces.expand((interface) => interface.addresses)) {
      if (_closed) return;
      if (_live.containsKey(address.address)) continue;
      RawDatagramSocket? socket;
      // A VPN tunnel or a link still coming up refuses the bind or the
      // option; the other interfaces are still worth asking. The option is
      // set by a native call that throws OSError, not SocketException.
      try {
        socket = await RawDatagramSocket.bind(address, 0);
        socket.setRawOption(RawSocketOption(RawSocketOption.levelIPv4, RawSocketOption.IPv4MulticastInterface, address.rawAddress));
      } on SocketException catch (e) {
        socket?.close();
        debugPrint('[mdns] skipping ${address.address}: $e');
        continue;
      } on OSError catch (e) {
        socket?.close();
        debugPrint('[mdns] skipping ${address.address}: $e');
        continue;
      }
      // Closed while the bind was in flight: nothing else will close it.
      if (_closed) {
        socket.close();
        return;
      }
      _listen(address.address, socket);
    }
  }

  void _listen(String key, RawDatagramSocket socket) {
    _live[key] = socket;
    void drop() {
      if (identical(_live[key], socket)) _live.remove(key);
    }

    socket.listen(
      (event) {
        if (event != RawSocketEvent.read) return;
        final datagram = socket.receive();
        if (datagram == null || _responses.isClosed) return;
        final records = parseMdnsResponse(datagram.data);
        if (records.isNotEmpty) _responses.add(records);
      },
      // A failed send or receive arrives here, never at the call — and the
      // VM has already closed the socket by then. An interface that went
      // away, or a Local Network grant the OS refuses, ends up here.
      onError: (Object e) {
        debugPrint('[mdns] socket on $key closed: $e');
        drop();
      },
      onDone: drop,
    );
  }

  void ask(List<({String name, int type})> questions) {
    final packet = buildMdnsQuery(questions);
    final group = InternetAddress(mdnsGroup);
    for (final socket in [..._live.values]) {
      socket.send(packet, group, mdnsPort);
    }
  }

  void close() {
    _closed = true;
    for (final socket in [..._live.values]) {
      socket.close();
    }
    _live.clear();
    unawaited(_responses.close());
  }
}

const _bonjourChannel = MethodChannel('ham2k/bonjour');

/// [mdnsBrowse] on iOS, through NetServiceBrowser (AppDelegate.swift).
/// One browse at a time: the channel carries no browse id, and only the
/// Add dialog browses.
Stream<MdnsService> _bonjourBrowse(String serviceType) {
  late final StreamController<MdnsService> controller;
  controller = StreamController<MdnsService>(
    onListen: () async {
      _bonjourChannel.setMethodCallHandler((call) async {
        if (call.method != 'found' || controller.isClosed) return;
        // Swift's invokeMethod has no result callback, so a throw here would
        // vanish into the channel's error envelope; on the stream it
        // reaches the dialog's discoveryError and the error report.
        try {
          final found = Map<String, dynamic>.from(call.arguments as Map);
          controller.add(
            MdnsService(
              instance: found['name'] as String,
              host: normalizeMdnsName(found['host'] as String),
              port: found['port'] as int,
              txt: {for (final entry in (found['txt'] as Map).entries) (entry.key as String).toLowerCase(): entry.value as String},
            ),
          );
        } catch (e, st) {
          controller.addError(e, st);
        }
      });
      try {
        // NetServiceBrowser wants the type without the domain, and the
        // domain on its own.
        final type = normalizeMdnsName(serviceType).replaceFirst(RegExp(r'\.local$'), '');
        await _bonjourChannel.invokeMethod<void>('start', {'type': '$type.'});
      } on PlatformException catch (e, st) {
        controller.addError(e, st);
      }
    },
    onCancel: () async {
      _bonjourChannel.setMethodCallHandler(null);
      await _bonjourChannel.invokeMethod<void>('stop');
    },
  );
  return controller.stream;
}
