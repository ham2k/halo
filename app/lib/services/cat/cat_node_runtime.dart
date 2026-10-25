// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What CatService keeps for each node while it is connected.

part of 'cat_service.dart';

class _NodeRuntime {
  final String uuid;

  _NodeRuntime(this.uuid);

  EquipmentState state = const EquipmentState();
  EquipmentConnection? connection;
  EquipmentSession? session;
  StreamSubscription<Uint8List>? subscription;
  CatCancelToken? cancel;

  /// Raw commands awaiting their reply ([_RadioControls.sendNodeRaw]): each
  /// sees every chunk received, before the driver does.
  final rawTaps = <void Function(Uint8List chunk)>{};

  void heard(Uint8List chunk) {
    if (rawTaps.isEmpty) return;
    for (final tap in [...rawTaps]) {
      tap(chunk);
    }
  }

  /// The last value moved between this node and the app's VFO, in either
  /// direction — the echo guard. Without it an app→radio tune and the
  /// radio's confirmation of it keep re-triggering each other.
  VfoReading? lastSent;

  /// What this connection has heard the radio itself say ([RadioProofWatch]).
  final proof = RadioProofWatch();

  /// A band picked by name that this radio is on its way to
  /// (`cat_band_pick.dart`).
  String? bandPick;
  Timer? bandPickTimer;

  /// Whether the radio reported another band while [bandPick] waited.
  bool bandPickHeldReport = false;

  /// The frequency this radio was last heard on, by band and
  /// [bandModeFamily] ([bandMemoryKey]): where a band pick sends it. Kept
  /// across reconnects, like a radio's own band stack.
  final lastFreqByBand = <String, double>{};

  /// [lastSent]'s counterpart for transmit power, which travels on its own
  /// commands rather than inside a [VfoReading].
  num? lastSentPower;

  /// Per-node, deliberately: two overlapping connects to the SAME node race
  /// to own it, and the loser must not install its connection.
  int attemptSeq = 0;

  /// Watches for a connection that is up but saying nothing — see
  /// [EquipmentState.stale].
  Timer? staleTimer;

  /// The operator pressed Disconnect. Distinct from every other route to
  /// `disconnected`, and the distinction is the whole safety of the idle
  /// retry: without it, "off because I said so" and "off because the radio
  /// vanished" are the same state, and a retry loop would keep switching the
  /// radio back on under the operator. app-polo's auto-reconnect did exactly
  /// that. Cleared by [connect], so asking for it again resumes retrying.
  bool userDisconnected = false;

  /// The last attempt opened the port and refused it over its control lines
  /// ([SerialFailure.lines]) — hardware flow control another program left
  /// on, which lasts until the cable is replugged. Retrying on its own would
  /// only open the port again, and opening raises RTS: on a Digirig, a key-up
  /// per retry for the rest of the session. Cleared by [connect], the
  /// operator's own try after replugging.
  bool linesRefused = false;

  /// See [CatService.spectrumFrames]. Created by the first display to ask.
  StreamController<SpectrumFrame>? spectrum;

  /// Whether this connection's scope was started — what a demand changes.
  bool spectrumStarted = false;

  /// The width in Hz each display drawing this scope shows, by display: see
  /// [CatService.wantSpectrumWidth].
  final spectrumWidths = <Object, int>{};

  /// The span last asked of this scope since it started, for those widths:
  /// what the radio reports lags the ask, and a start re-reports the last
  /// session's, so neither says whether this one was asked.
  int? spectrumSpanAsked;

  /// The operator pressed Connect on this SDR: it stays connected with no
  /// display drawing it, until they press Disconnect.
  bool sdrPinned = false;

  /// Connects, disconnects and edits of this SDR under way. While any is,
  /// nothing else starts one — two connects to a one-client server
  /// supersede each other — and each settles the SDR again as it ends.
  int sdrBusy = 0;

  /// An SDR's pending idle release, and its next try at connecting while a
  /// display waits — see [CatServiceSpectrum._settleSdr].
  Timer? sdrRelease;
  Timer? sdrRetry;

  void cancelSdrTimers() {
    sdrRelease?.cancel();
    sdrRelease = null;
    sdrRetry?.cancel();
    sdrRetry = null;
  }

  /// The transmission under way: SWR readings taken with RF out.
  double _swrSum = 0;
  int _swrCount = 0;

  /// The last SWR read with RF out while the radio did not yet say it was
  /// transmitting.
  ({num value, int atMillis})? _swrBeforeKeying;
  ({double? swrAverage, int endedAtMillis})? lastTransmission;

  /// An SWR reading. Counted only while RF is out: between words on SSB a
  /// radio reads SWR 1.0 at no power, which would flatter every average.
  void noteSwr(num value, {required num? powerOut, required bool? transmitting}) {
    if ((powerOut ?? 0) <= 0) return;
    if (transmitting == true) {
      _swrSum += value;
      _swrCount++;
    } else {
      _swrBeforeKeying = (value: value, atMillis: realNowMillis());
    }
  }

  /// A key-down this soon after the last key-up continues that transmission
  /// rather than starting one: CW break-in unkeys between characters, and
  /// averaging each element alone leaves a reading or two per average.
  static const _breakInMillis = 500;

  /// A polled driver reports the first meters of a transmission just BEFORE
  /// the transmission itself — its poller reads on the transition — so a
  /// reading from the second before keying belongs to this one.
  void startTransmission() {
    final now = realNowMillis(), last = lastTransmission;
    if (last == null || now - last.endedAtMillis > _breakInMillis) {
      _swrSum = 0;
      _swrCount = 0;
    }
    final early = _swrBeforeKeying;
    if (early != null && now - early.atMillis <= 1000) {
      _swrSum += early.value;
      _swrCount++;
    }
    _swrBeforeKeying = null;
  }

  /// The transmission under way's average so far; null before a reading with RF out.
  double? get swrRunning => _swrCount == 0 ? null : _swrSum / _swrCount;

  void endTransmission() {
    lastTransmission = (swrAverage: _swrCount == 0 ? null : _swrSum / _swrCount, endedAtMillis: realNowMillis());
  }
}

class _MeterReadings extends ChangeNotifier {
  void notify() => notifyListeners();
}
