// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Spots this device makes itself, from the station the operator is working
// (docs/design/logging-fields.md § Local spots): what one is made of, and
// what it does to the other spots on the board. And the operator's band tags, which mark a
// place on the band rather than a station: band annotations of their own.

import 'package:halo_core/halo_core.dart';

import 'spot_board.dart' show addRefsOfSpot, spotCallsIn, spotMergeWindowMs;
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
/// The draft's references go along when they name one (a park, a summit);
/// a contest's received exchange, which rides the refs as values with no
/// `ref`, becomes the spot's label.
Map<String, dynamic>? localSpotFromQso(Map<String, dynamic> qso, {required int now}) {
  final call = callOfSpot(qso);
  final freq = asSpotNum(qso['freq'])?.toDouble();
  final mode = asSpotString(qso['mode']);
  final band = asSpotString(qso['band']) ?? (freq == null ? null : bandForFrequency(freq));
  if (call == null || freq == null || band == null || call.contains(',') || call.contains('//')) return null;
  if (!isLoggableCall(call)) return null;
  final superMode = superModeForMode(mode);
  if (superMode != 'Phone' && superMode != 'CW') return null;
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
    'spot': {'timeInMillis': now, 'source': localSpotSource, if (exchange.isNotEmpty) 'label': exchange.join(' ')},
    'hookKey': localSpotSource,
  };
}

/// Whether [spot] is a local one whose call names no station to look up or
/// work: a call not fully copied ("W1A?"). On the board like any spot; never
/// asked about, scored or chased, which would act on text nobody heard as a
/// callsign.
bool isLocalSpotWithoutStation(Map<String, dynamic> spot) => spot['hookKey'] == localSpotSource && !looksLikeCallsign(callOfSpot(spot) ?? '');

/// Whether [local] and [other] are one station on the board: the same call,
/// on the same band and in the same family of modes, wherever on that band
/// each puts it. A call not fully copied is no station to match: two
/// stations both copied as "W1A?" are two places on the band.
bool localSpotSameStation(Map<String, dynamic> local, Map<String, dynamic> other) {
  if (!_byStation(local) || !_byStation(other) || !_sameBandAndModes(local, other)) return false;
  final call = callOfSpot(local);
  return call != null && spotCallsIn(callOfSpot(other)).contains(call);
}

/// Whether [local] takes [other], a spot from another source, into its row
/// ([withLocalSpots]): the same station ([localSpotSameStation]), posted
/// within [spotMergeWindowMs] of it either way.
bool localSpotTakesIn(Map<String, dynamic> local, Map<String, dynamic> other) =>
    localSpotSameStation(local, other) && ((timeOfSpot(other) ?? 0) - (timeOfSpot(local) ?? 0)).abs() <= spotMergeWindowMs;

/// Whether [local] replaces [other], an older local spot: the same station
/// ([localSpotSameStation]), or any within a signal's width of it, posted no
/// later. The operator's own entries say who is on a frequency now.
bool localSpotReplaces(Map<String, dynamic> local, Map<String, dynamic> other) {
  if ((timeOfSpot(other) ?? 0) > (timeOfSpot(local) ?? 0)) return false;
  return localSpotSameStation(local, other) || (_sameBandAndModes(local, other) && _withinSignal(local, other));
}

/// Whether [local] hides [other], a spot from another source: a different
/// station within a signal's width of it, posted no later — the local spot
/// says who is on that frequency now. The same station is never hidden: it
/// is taken in ([localSpotTakesIn]) or, from another outing, left be. A spot
/// posted after the local one is news it cannot speak for.
bool localSpotHides(Map<String, dynamic> local, Map<String, dynamic> other) {
  if ((timeOfSpot(other) ?? 0) > (timeOfSpot(local) ?? 0)) return false;
  return !localSpotSameStation(local, other) && _sameBandAndModes(local, other) && _withinSignal(local, other);
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

/// [spots] with the local spots among them applied. A newer local spot
/// replaces an older one ([localSpotReplaces]). Each local spot left takes
/// in the spots of other sources for its station ([localSpotTakesIn]) as
/// one row ([_mergedStation]), and hides those of other stations near it
/// ([localSpotHides]) — unless a newer spot of its station has moved the row
/// elsewhere, where hiding them would empty a frequency the network says the
/// station has left. Nothing is dropped from where it is held — a local
/// spot taken back, or its source switched off, puts back what it hid or
/// took in.
///
/// Indexed by band and mode family, call and frequency, rather than each
/// spot against each local one: this runs on every change to the board, and
/// a contest's worth of local spots against a few thousand fetched ones
/// would otherwise be millions of comparisons at a keystroke.
List<Map<String, dynamic>> withLocalSpots(List<Map<String, dynamic>> spots) {
  final locals = [
    for (final spot in spots)
      if (spot['hookKey'] == localSpotSource) spot,
  ];
  if (locals.isEmpty) return spots;
  // Newest first, so each local spot meets only those that may replace it.
  locals.sort((a, b) => (timeOfSpot(b) ?? 0).compareTo(timeOfSpot(a) ?? 0));
  final index = _LocalSpotIndex();
  final kept = Set<Map<String, dynamic>>.identity();
  for (final local in locals) {
    if (index.replaces(local)) continue;
    index.add(local);
    kept.add(local);
  }
  final stations = [for (final spot in spots) spot['hookKey'] == localSpotSource ? null : index.stationOf(spot)];
  final takenIn = Map<Map<String, dynamic>, List<Map<String, dynamic>>>.identity();
  for (var i = 0; i < spots.length; i++) {
    if (stations[i] case final station?) takenIn.putIfAbsent(station, () => []).add(spots[i]);
  }
  final moved = Set<Map<String, dynamic>>.identity()
    ..addAll([
      for (final MapEntry(key: local, value: others) in takenIn.entries)
        if (others.any((other) => (timeOfSpot(other) ?? 0) > (timeOfSpot(local) ?? 0) && !_withinSignal(local, other))) local,
    ]);
  final shown = <Map<String, dynamic>>[];
  for (var i = 0; i < spots.length; i++) {
    final spot = spots[i];
    if (spot['hookKey'] == localSpotSource) {
      if (kept.contains(spot)) shown.add(spot);
    } else if (stations[i] == null && !index.hides(spot, except: moved)) {
      shown.add(spot);
    }
  }
  return [
    for (final spot in shown)
      if (spot['hookKey'] == localSpotSource) _mergedStation(spot, takenIn[spot] ?? const []) else spot,
  ];
}

/// One row for [local] and the [others] spots of its station: where, in
/// what mode, when and by whom from the newest of them, and the references
/// of all. The label is the newest one given — a local spot's is a contest
/// exchange at most, and the network's park line still says what the
/// station is doing — or, when none is, the reference codes, so a row the
/// local spot stands for alone still names its park. The icon too is the
/// newest one given: a local spot has none.
///
/// Spots posted at one moment are ordered the operator's first — they heard
/// it — then by source and frequency. Left to the order the sources arrive
/// in, a row would jump between frequencies as they refresh.
Map<String, dynamic> _mergedStation(Map<String, dynamic> local, List<Map<String, dynamic>> others) {
  final group = [local, ...others]..sort(_newestFirst);
  final refs = <Map<String, dynamic>>[];
  for (final spot in group) {
    addRefsOfSpot(refs, spot);
  }
  final newest = group.first;
  final label = group.map((spot) => asSpotString(asSpotMap(spot['spot'])?['label'])).firstWhere((l) => l != null && l.isNotEmpty, orElse: () => null);
  final icon = group.map((spot) => spot['icon']).firstWhere((i) => i != null, orElse: () => null);
  final codes = [for (final ref in refs) ?asSpotString(ref['ref'])];
  final ids = <String>[for (final spot in group) ...spotIdsOf(spot)];
  return {
    ...newest,
    // Every report's, as a merged row carries them: a mark on the network's
    // report has to stay on the row the operator's own spot now stands for.
    'ids': [
      ...{...ids},
    ],
    if (refs.isNotEmpty) 'refs': refs,
    'icon': ?icon,
    'spot': {...?asSpotMap(newest['spot']), 'label': ?(label ?? (codes.isEmpty ? null : codes.join(', ')))},
  };
}

int _newestFirst(Map<String, dynamic> a, Map<String, dynamic> b) {
  final byTime = (timeOfSpot(b) ?? 0).compareTo(timeOfSpot(a) ?? 0);
  if (byTime != 0) return byTime;
  final aLocal = a['hookKey'] == localSpotSource;
  if (aLocal != (b['hookKey'] == localSpotSource)) return aLocal ? -1 : 1;
  final bySource = '${a['hookKey']}'.compareTo('${b['hookKey']}');
  if (bySource != 0) return bySource;
  return (asSpotNum(a['freq']) ?? 0).compareTo(asSpotNum(b['freq']) ?? 0);
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

  /// Whether a kept local spot replaces [other], a local spot older than it.
  bool replaces(Map<String, dynamic> other) => stationOf(other, where: localSpotReplaces) != null || _near(other, localSpotReplaces);

  /// Whether a kept local spot, other than those in [except], hides [other],
  /// a spot from another source.
  bool hides(Map<String, dynamic> other, {required Set<Map<String, dynamic>> except}) =>
      _near(other, (local, spot) => !except.contains(local) && localSpotHides(local, spot));

  /// The kept local spot of [other]'s call that [where] holds for — by
  /// default, the one that takes it in — asked only of those on its band and
  /// mode with its call.
  Map<String, dynamic>? stationOf(Map<String, dynamic> other, {bool Function(Map<String, dynamic>, Map<String, dynamic>) where = localSpotTakesIn}) {
    final bucket = _buckets[_bucketOf(other)];
    if (bucket == null || !_byStation(other)) return null;
    for (final call in spotCallsIn(callOfSpot(other))) {
      for (final local in bucket.byCall[call] ?? const <Map<String, dynamic>>[]) {
        if (where(local, other)) return local;
      }
    }
    return null;
  }

  /// Whether [test] holds for [other] and a kept local spot near its
  /// frequency on its band and mode.
  bool _near(Map<String, dynamic> other, bool Function(Map<String, dynamic>, Map<String, dynamic>) test) {
    final bucket = _buckets[_bucketOf(other)];
    final freq = _freqOf(other);
    if (bucket == null || freq.isNaN) return false;
    // The widest window bounds the scan; [test] holds CW to its own.
    for (var i = _lowerBound(bucket.byFreq, freq - _phoneWindowKHz - 1e-6); i < bucket.byFreq.length; i++) {
      final local = bucket.byFreq[i];
      if (_freqOf(local) > freq + _phoneWindowKHz + 1e-6) break;
      if (test(local, other)) return true;
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

/// A logging panel's draft spot (`LoggingSession.onDraftSpot`) onto [spots]:
/// put while the draft makes one and [enabled] holds, taken off otherwise.
/// True when a spot stands under [key] afterwards.
///
/// Without [live] — no rig reporting the set's frequency — the draft's
/// frequency is whatever was last typed in, so no spot is made or moved;
/// one already up stays, since the station was there when it was made, and
/// only a retraction (a null [qso]) takes it down.
bool updateLocalSpot(SpotsService spots, String key, Map<String, dynamic>? qso, {required bool enabled, required bool live}) {
  if (qso != null && enabled && !live) return spots.hasLocalSpot(key);
  final spot = qso == null || !enabled ? null : localSpotFromQso(qso, now: nowMillis());
  spot == null ? spots.removeLocalSpot(key) : spots.putLocalSpot(key, spot);
  return spot != null;
}

/// A logging panel's band tag (`LoggingSession.onBandTag`): [text] marks
/// the band at [at] (`freq` in kHz, `band`), as the operator's own `general`
/// annotation, for as long as a local spot would stand. False when
/// [enabled] does not hold — band tags go with the local spots — or [at]
/// names no place on a band.
bool putBandTag(SpotsService spots, String text, Map<String, dynamic> at, {required bool enabled}) {
  final freq = asSpotNum(at['freq'])?.toDouble();
  final band = asSpotString(at['band']) ?? (freq == null ? null : bandForFrequency(freq));
  if (!enabled || freq == null || band == null || text.trim().isEmpty) return false;
  spots.bandAnnotations.put(userBandAnnotationSource, [
    {
      'type': 'general',
      'key': uuidGenerator.v4(),
      'fromHz': (freq * 1000).round(),
      'band': band,
      // Cut to what an annotation holds: a long paste ending in `!` is still
      // a tag, and refused whole it would escape the field's Enter.
      'label': _cutToFit(text.trim()),
      'expiresAt': nowMillis() + SpotsService.maxSpotAge.inMilliseconds,
    },
  ]);
  return true;
}

/// [text] cut to [maxBandAnnotationTextChars], never inside a character.
String _cutToFit(String text) {
  if (text.length <= maxBandAnnotationTextChars) return text;
  final cut = StringBuffer();
  for (final rune in text.runes) {
    final char = String.fromCharCode(rune);
    if (cut.length + char.length > maxBandAnnotationTextChars) break;
    cut.write(char);
  }
  return cut.toString();
}

/// A logging panel's lone `!` (`LoggingSession.onClearLocalSpots`): every
/// local spot within a signal's width of [at] on its band and family of
/// modes comes down, those hidden under the newest too, which taking only
/// that one would bring back. The band tags within it on
/// the band come down with them, whatever their mode.
void clearLocalSpotsAt(SpotsService spots, Map<String, dynamic> at) {
  final freq = asSpotNum(at['freq'])?.toDouble();
  if (freq == null) return;
  final here = {...at, 'band': asSpotString(at['band']) ?? bandForFrequency(freq)};
  spots.removeLocalSpotsWhere((spot) => _sameBandAndModes(here, spot) && _withinSignal(here, spot));
  spots.bandAnnotations.removeWhere(
    userBandAnnotationSource,
    (tag) => tag['band'] == here['band'] && _withinSignal(here, {'freq': (tag['fromHz'] as int) / 1000}),
  );
}
