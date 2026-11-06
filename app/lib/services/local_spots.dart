// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Spots this device makes itself, from the station the operator is working
// (docs/design/logging-fields.md § Local spots): what one is made of, and
// which other spots it replaces.

import 'package:halo_core/halo_core.dart';

import 'spot_board.dart' show spotCallsIn;
import 'spots_service.dart';

/// The `hookKey` the local spots are held under, beside the extensions'
/// sources — the Spots panel's source filter names it like theirs.
const localSpotSource = 'local';

/// How far from a local spot, in kHz, another spot is taken to be the same
/// signal: the width of a voice on the dial, and of a CW note.
const _phoneWindowKHz = 0.1;
const _cwWindowKHz = 0.02;

/// The spot [qso] (a logging-panel draft, in QSON) makes, posted [now], or
/// null when it makes none: a call that is neither a whole callsign nor one
/// marked not fully copied ("W1A?" — someone is there), a call stack or list
/// rather than one entry, no frequency, or a digital mode, where every
/// station in the passband shares one dial frequency and a frequency says
/// nothing about who is on it.
///
/// A [tag] marks an area of the band rather than a station ("QRM", "NET"):
/// its call is any text, the spot says it is a tag (`spot.tag`), and it is
/// spotted in a digital mode too.
///
/// The draft's references go along when they name one (a park, a summit);
/// a contest's received exchange, which rides the refs as values with no
/// `ref`, becomes the spot's label.
Map<String, dynamic>? localSpotFromQso(Map<String, dynamic> qso, {required int now, bool tag = false}) {
  final call = callOfSpot(qso);
  final freq = asSpotNum(qso['freq'])?.toDouble();
  final mode = asSpotString(qso['mode']);
  final band = asSpotString(qso['band']) ?? (freq == null ? null : bandForFrequency(freq));
  if (call == null || freq == null || band == null || call.contains(',') || call.contains('//')) return null;
  if (!tag && !isLoggableCall(call)) return null;
  final superMode = superModeForMode(mode);
  if (!tag && superMode != 'Phone' && superMode != 'CW') return null;
  final refs = <Map<String, dynamic>>[];
  final exchange = <String>[];
  for (final ref in (qso['refs'] as List?) ?? const []) {
    if (ref is! Map) continue;
    final type = asSpotString(ref['type']);
    final code = asSpotString(ref['ref']);
    if (type == null) continue;
    if (code != null && code.isNotEmpty) {
      refs.add({'type': type, 'ref': code});
    } else {
      for (final entry in ref.entries) {
        if (entry.key != 'type' && entry.value is String && (entry.value as String).trim().isNotEmpty) exchange.add((entry.value as String).trim());
      }
    }
  }
  return {
    'their': {'call': call},
    'freq': freq,
    'band': band,
    'mode': mode,
    if (refs.isNotEmpty) 'refs': refs,
    'spot': {'timeInMillis': now, 'source': localSpotSource, if (tag) 'tag': true, if (exchange.isNotEmpty) 'label': exchange.join(' ')},
    'hookKey': localSpotSource,
  };
}

/// Whether [spot] is a band tag ("QRM!" and Enter): an area of the band, not
/// a contact to log.
bool isBandTag(Map<String, dynamic> spot) => spot['hookKey'] == localSpotSource && (spot['spot'] as Map?)?['tag'] == true;

/// Whether [spot] is a local one whose call names no station to look up or
/// work: a band tag, or a call not fully copied. On the board like any spot;
/// never asked about, scored or chased, which would act on text nobody heard
/// as a callsign. A tag says so rather than being judged by its text: "Q65"
/// and "JT65" read as callsigns.
bool isLocalSpotWithoutStation(Map<String, dynamic> spot) =>
    isBandTag(spot) || (spot['hookKey'] == localSpotSource && !looksLikeCallsign(callOfSpot(spot) ?? ''));

/// Whether [local] replaces [other]: posted no later, on the same band and
/// in the same family of modes, and either the same station anywhere there
/// or any station within a signal's width of it — a local spot says who is
/// on that frequency now, and that the station is no longer where an older
/// spot put it. A tag or a call not fully copied replaces by frequency only:
/// its text names no station, and two "QRM"s, or two stations both copied
/// as "W1A?", are two places on the band.
bool localSpotReplaces(Map<String, dynamic> local, Map<String, dynamic> other) {
  if ((timeOfSpot(other) ?? 0) > (timeOfSpot(local) ?? 0)) return false;
  if (!_sameBandAndModes(local, other)) return false;
  final call = callOfSpot(local);
  if (call != null && _byStation(local) && _byStation(other) && spotCallsIn(callOfSpot(other)).contains(call)) return true;
  return _withinSignal(local, other);
}

bool _byStation(Map<String, dynamic> spot) => !isLocalSpotWithoutStation(spot);

bool _sameBandAndModes(Map<String, dynamic> a, Map<String, dynamic> b) =>
    asSpotString(a['band']) == asSpotString(b['band']) && superModeForMode(asSpotString(a['mode'])) == superModeForMode(asSpotString(b['mode']));

/// Whether [other] is within a signal's width of [at]'s frequency, by
/// [at]'s family of modes.
bool _withinSignal(Map<String, dynamic> at, Map<String, dynamic> other) {
  final freq = asSpotNum(at['freq']);
  final otherFreq = asSpotNum(other['freq']);
  if (freq == null || otherFreq == null) return false;
  final window = superModeForMode(asSpotString(at['mode'])) == 'CW' ? _cwWindowKHz : _phoneWindowKHz;
  return (freq - otherFreq).abs() <= window + 1e-9;
}

/// [spots] less every spot a local spot among them replaces
/// ([localSpotReplaces]), local spots included: a newer one on a frequency
/// takes an older one's place. Nothing is dropped from where it is held —
/// a local spot taken back, or its source switched off, puts what it
/// replaced back on the board.
///
/// Indexed by band and mode family, call and frequency, rather than each
/// spot against each local one: this runs on every change to the board, and
/// a contest's worth of local spots against a few thousand fetched ones
/// would otherwise be millions of comparisons at a keystroke.
List<Map<String, dynamic>> withoutReplacedSpots(List<Map<String, dynamic>> spots) {
  final locals = [
    for (final spot in spots)
      if (spot['hookKey'] == localSpotSource) spot,
  ];
  if (locals.isEmpty) return spots;
  // Newest first, so each local spot meets only those that may replace it.
  locals.sort((a, b) => (timeOfSpot(b) ?? 0).compareTo(timeOfSpot(a) ?? 0));
  final index = _LocalSpotIndex();
  final kept = <Map<String, dynamic>>{};
  for (final local in locals) {
    if (index.replaces(local)) continue;
    index.add(local);
    kept.add(local);
  }
  return [
    for (final spot in spots)
      if (spot['hookKey'] == localSpotSource ? kept.contains(spot) : !index.replaces(spot)) spot,
  ];
}

/// The kept local spots, by band and mode family; within one, by call and in
/// order of frequency.
class _LocalSpotIndex {
  final _buckets = <String, ({Map<String, List<Map<String, dynamic>>> byCall, List<Map<String, dynamic>> byFreq})>{};

  static String _bucketOf(Map<String, dynamic> spot) => '${asSpotString(spot['band'])}|${superModeForMode(asSpotString(spot['mode']))}';
  static double _freqOf(Map<String, dynamic> spot) => asSpotNum(spot['freq'])?.toDouble() ?? double.nan;

  void add(Map<String, dynamic> local) {
    final bucket = _buckets.putIfAbsent(_bucketOf(local), () => (byCall: {}, byFreq: []));
    final call = callOfSpot(local);
    if (call != null && _byStation(local)) bucket.byCall.putIfAbsent(call, () => []).add(local);
    final freq = _freqOf(local);
    if (freq.isNaN) return;
    bucket.byFreq.insert(_lowerBound(bucket.byFreq, freq), local);
  }

  /// Whether a kept local spot replaces [other] — asked only of those on its
  /// band and mode with its call, or near its frequency.
  bool replaces(Map<String, dynamic> other) {
    final bucket = _buckets[_bucketOf(other)];
    if (bucket == null) return false;
    if (_byStation(other)) {
      for (final call in spotCallsIn(callOfSpot(other))) {
        if (bucket.byCall[call]?.any((local) => localSpotReplaces(local, other)) ?? false) return true;
      }
    }
    final freq = _freqOf(other);
    if (freq.isNaN) return false;
    // The widest window bounds the scan; [localSpotReplaces] holds CW to its own.
    for (var i = _lowerBound(bucket.byFreq, freq - _phoneWindowKHz - 1e-6); i < bucket.byFreq.length; i++) {
      final local = bucket.byFreq[i];
      if (_freqOf(local) > freq + _phoneWindowKHz + 1e-6) break;
      if (localSpotReplaces(local, other)) return true;
    }
    return false;
  }

  static int _lowerBound(List<Map<String, dynamic>> byFreq, double freq) {
    var low = 0;
    var high = byFreq.length;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (_freqOf(byFreq[mid]) < freq) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }
}

/// A logging panel's draft spot or band tag (`LoggingSession.onDraftSpot`)
/// onto [spots]: put while the draft makes one and [enabled] holds, taken off
/// otherwise. True when a spot stands under [key] afterwards.
bool updateLocalSpot(SpotsService spots, String key, Map<String, dynamic>? qso, {required bool enabled, bool tag = false}) {
  final spot = qso == null || !enabled ? null : localSpotFromQso(qso, now: nowMillis(), tag: tag);
  spot == null ? spots.removeLocalSpot(key) : spots.putLocalSpot(key, spot);
  return spot != null;
}

/// A logging panel's lone `!` (`LoggingSession.onClearLocalSpots`): every
/// local spot within a signal's width of [at] on its band and family of
/// modes comes down — tags and stations, those hidden under the newest too,
/// which taking only that one would bring back.
void clearLocalSpotsAt(SpotsService spots, Map<String, dynamic> at) {
  final freq = asSpotNum(at['freq'])?.toDouble();
  if (freq == null) return;
  final here = {...at, 'band': asSpotString(at['band']) ?? bandForFrequency(freq)};
  spots.removeLocalSpotsWhere((spot) => _sameBandAndModes(here, spot) && _withinSignal(here, spot));
}
