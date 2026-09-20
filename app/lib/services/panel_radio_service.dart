// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
import 'dart:async';
import 'package:halo_core/halo_core.dart' show realNowMillis, nowMillis;
import 'cat/cat_service.dart';
import 'cat/equipment.dart';
import 'radio_service.dart';

/// Narrow extension adapter. CAT retains sessions, telemetry and echo handling.
class PanelRadioService {
  final CatService cat;
  final RadioService radio;
  Future<void> _tail = Future.value();
  int _lastCommand = 0;
  PanelRadioService(this.cat, this.radio);

  List<Map<String, dynamic>> list() => [
    for (final node in cat.nodes)
      if (cat.typeFor(node)?.category == kCategoryTransceiver) read(node.uuid),
  ];

  Map<String, dynamic> read([String? selection]) {
    final id =
        selection ??
        switch (cat.radio1) {
          LocalRadio(:final uuid) => uuid,
          _ => null,
        };
    final candidate = id == null ? null : cat.nodeFor(id);
    final node = selection != null && candidate != null && cat.typeFor(candidate)?.category != kCategoryTransceiver
        ? null
        : candidate;
    // From the NODE, not the id: a selection naming an antenna switch or a
    // keyer has no node here, and must not answer with that device's status,
    // problem text or frequency under a capability that reads radios.
    final state = node == null ? const EquipmentState() : cat.stateFor(node.uuid);
    final live = node != null && state.status == EquipmentStatus.connected && !state.stale && state.problem == null;
    final telemetry = state.telemetry;
    return {
      'id': node?.uuid,
      'name': node == null ? null : cat.displayNameFor(node),
      'status': state.status.name,
      'stale': state.stale,
      'problem': state.problem ?? state.error,
      'frequencyHz': state.vfo.freqKHz == null ? null : (state.vfo.freqKHz! * 1000).round(),
      'mode': state.vfo.mode,
      'powerWatts': live ? state.power : null,
      'transmitting': live ? telemetry.transmitting : null,
      'meters': {
        if (live)
          for (final meter in RadioMeter.values)
            if (telemetry.fresh(
                  meter,
                  nowMillis(),
                  linger: meter == RadioMeter.signalDbm ? const Duration(seconds: 2) : meterLinger,
                )
                case final reading?)
              meter.name: reading.value,
      },
      'canTune': live && state.vfo.freqKHz != null,
    };
  }

  Map<String, dynamic> setConnection(Map<String, dynamic> args) {
    final state = read(args['selection'] as String?);
    if (args['id'] == null || args['id'] != state['id']) {
      return {'accepted': false, 'reason': 'changed', 'state': state};
    }
    if (args['connected'] is! bool) {
      return {'accepted': false, 'reason': 'invalid', 'state': state};
    }
    final id = state['id'] as String;
    if (args['connected'] == true) {
      unawaited(cat.connect(id));
    } else {
      unawaited(cat.disconnect(id));
    }
    return {'accepted': true, 'state': read(args['selection'] as String?)};
  }

  Future<Map<String, dynamic>> tune(Map<String, dynamic> args) async {
    final previous = _tail;
    final done = _perform(previous, args);
    _tail = done.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return done;
  }

  Future<Map<String, dynamic>> _perform(Future<void> previous, Map<String, dynamic> args) async {
    await previous;
    final delay = 250 - (realNowMillis() - _lastCommand);
    if (delay > 0) await Future<void>.delayed(Duration(milliseconds: delay));
    final selection = args['selection'] as String?;
    final state = read(selection);
    String? reason;
    final frequency = args['frequencyHz'];
    final mode = args['mode'];
    if (args['id'] == null || args['id'] != state['id']) {
      reason = 'changed';
    } else if (state['canTune'] != true) {
      reason = 'disconnected';
    } else if (state['transmitting'] == true) {
      reason = 'transmitting';
    } else if ((frequency == null && mode == null) ||
        (frequency != null && (frequency is! num || !frequency.isFinite || frequency <= 0 || frequency > 1e12)) ||
        (mode != null && !['LSB', 'USB', 'CW', 'AM', 'FM'].contains(mode))) {
      reason = 'invalid';
    }
    if (reason != null) return {'accepted': false, 'reason': reason, 'state': state};
    _lastCommand = realNowMillis();
    final freqKHz = frequency == null ? null : (frequency as num).toDouble() / 1000;
    if (cat.isRadio1(state['id'] as String)) {
      radio.setVfo('vfoA', freq: freqKHz, mode: mode as String?);
    } else {
      cat.tuneNode(state['id'] as String, VfoReading(freqKHz: freqKHz, mode: mode as String?));
    }
    // Acceptance is not an acknowledgement: read() contains only radio reports.
    return {'accepted': true, 'state': read(selection)};
  }
}
