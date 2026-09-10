// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A connection to nothing, for exercising everything that sits above a
// driver without a radio on the bench — see placeholder_radio_driver.dart
// for the half that holds the state.
//
// It exists because of the platform table in docs/design/cat.md § Platforms:
// TCP and the Icom network have no web implementation, so on a web build the
// only rig that connects at all is one on a USB serial port. Anything gated
// on a connected radio — the Station panel, Smart VFO Snap, zero beat, the
// radio1/radio2 assignment, power — is unreachable in the build that gets
// handed round for checking. This transport has no I/O of any kind, so it
// connects everywhere, in every edition.
//
// Not conditionally exported like the socket transports: there is nothing
// platform-specific to stub out.

import 'dart:async';
import 'dart:typed_data';

import 'package:halo_i18n/halo_i18n.dart';
import '../transport.dart';
import 'config_field_helpers.dart';

/// Thrown by a [PlaceholderTransport] the operator asked to fail. Tagged
/// [CatUnreachable] so it takes the same path a rig that is switched off
/// takes — silent, retried — which is the path being exercised.
class PlaceholderUnreachable implements CatUnreachable {
  const PlaceholderUnreachable();

  @override
  String toString() => t.settings.station.placeholderConnectFailure;
}

class _PlaceholderConnection implements EquipmentConnection {
  /// Never emits: the placeholder radio's state lives in its session, not on a
  /// wire. Present because [EquipmentConnection] promises a stream and
  /// `CatService` subscribes to it.
  final _data = StreamController<Uint8List>();
  final _closed = Completer<void>();
  Timer? _dropTimer;

  _PlaceholderConnection({required Duration? dropAfter}) {
    if (dropAfter != null) _dropTimer = Timer(dropAfter, close);
  }

  @override
  Stream<Uint8List> get data => _data.stream;

  @override
  Future<void> get closed => _closed.future;

  @override
  void send(List<int> bytes) {}

  @override
  Future<void> close() async {
    _dropTimer?.cancel();
    if (!_closed.isCompleted) _closed.complete();
    unawaited(_data.close());
  }
}

/// Reaches a radio that isn't there. Every field is a knob for the failure
/// this transport is standing in for, not a connection parameter — there is
/// nothing to address.
class PlaceholderTransport extends EquipmentTransport {
  static const transportKey = 'placeholder';

  const PlaceholderTransport();

  @override
  String get key => transportKey;

  @override
  Future<EquipmentConnection> connect(Map<String, dynamic> target, {required CatCancelToken cancel}) async {
    final delay = Duration(milliseconds: numberFromConfig(target, 'placeholderConnectDelay', 0));
    if (delay > Duration.zero) {
      // Raced rather than awaited, so a superseded attempt releases at once
      // instead of holding the slot for the whole simulated handshake —
      // the behaviour every real transport here has, and the reason
      // CatCancelToken is in the signature at all.
      await Future.any([Future<void>.delayed(delay), cancel.whenCancelled]);
    }
    if (cancel.isCancelled) throw const CatCancelledException();
    if (target['placeholderFailConnect'] == true) throw const PlaceholderUnreachable();
    final dropAfter = numberFromConfig(target, 'placeholderDropAfter', 0);
    return _PlaceholderConnection(dropAfter: dropAfter > 0 ? Duration(seconds: dropAfter) : null);
  }

  @override
  List<Map<String, dynamic>> configElements({
    Map<String, dynamic> overrides = const {},
    Map<String, dynamic> restrictions = const {},
  }) =>
      [
        // Developer mode only, like the driver's own knobs: these shape a
        // SIMULATED link, and an operator using this entry to name their rig
        // has no link to shape.
        if (!overrides.containsKey('placeholderConnectDelay'))
          {
            'type': 'field',
            'fieldType': 'number',
            'key': 'placeholderConnectDelay',
            'label': t.settings.station.placeholderConnectDelay,
            'description': t.settings.station.placeholderConnectDelayDescription,
            'devMode': true,
          },
        if (!overrides.containsKey('placeholderDropAfter'))
          {
            'type': 'field',
            'fieldType': 'number',
            'key': 'placeholderDropAfter',
            'label': t.settings.station.placeholderDropAfter,
            'description': t.settings.station.placeholderDropAfterDescription,
            'devMode': true,
          },
        if (!overrides.containsKey('placeholderFailConnect'))
          {
            'type': 'field',
            'fieldType': 'checkbox',
            'key': 'placeholderFailConnect',
            'label': t.settings.station.placeholderFailConnect,
            'devMode': true,
          },
      ];

  @override
  String? validateField(String key, dynamic value, Map<String, dynamic> config) {
    switch (key) {
      case 'placeholderConnectDelay':
      case 'placeholderDropAfter':
        // Blank is NOT waved through, though 0 is what both fields usually
        // hold. A `number` field hands over `num.tryParse(text)`, so an
        // entry the formatter allows but no parse accepts — `1.5.0`, `3-`,
        // a lone `-` — arrives as the same null a cleared box does.
        // Accepting null would take a knob the operator set, ignore it, and
        // look exactly like one they left alone: the failure these knobs
        // exist to make visible, made invisible. Rejecting it costs nothing,
        // because defaultConfig prefills every one of them — the same call
        // TcpTransportConfig makes for `port`.
        //
        // Parsed by the reader [connect] itself uses rather than by a second
        // `tryParse` written here, so a value that validates is the value
        // that gets read. -1 is a sentinel no valid entry can produce.
        return numberFromConfig({...config, key: value}, key, -1) < 0
            ? t.settings.station.placeholderWholeNumberInvalid
            : null;
      default:
        return null;
    }
  }
}
