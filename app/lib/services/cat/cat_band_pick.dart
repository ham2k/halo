// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A band picked by name, with no frequency, sends the radio driving that
// VFO — radio1, or SO2R's Radio B — to that band (docs/design/cat.md
// § Picking a band).

part of 'cat_service.dart';

/// How long a band pick holds off the radio's reports from other bands. Long
/// enough for the tune to land and be read back ([ReadBackSession]); a radio
/// that has said it is somewhere else by then is taken at its word, so a pick
/// the radio refused cannot leave the app showing a band the radio is not on.
const catBandPickGrace = Duration(seconds: 3);

extension _BandPick on CatService {
  /// Sends [uuid]'s radio to the band [vfo] — its [vfoKey] — names when it
  /// names a band and no frequency, answering whether it did. False leaves
  /// the write to [tuneNode], as for any other.
  ///
  /// Where this radio was last heard on that band in the app's mode family,
  /// failing that the start of the mode's segment for where the operator is
  /// licensed ([defaultFrequencyForBand]), tuned in the app's mode as a typed
  /// frequency is. Not the radio's own band stack, even where it has one
  /// (docs/design/cat.md § Picking a band says why).
  ///
  /// [heading] is the band of a pick this one replaces, which the radio may
  /// still be on its way to.
  bool _pickBand(String uuid, String vfoKey, Vfo vfo, {String? heading}) {
    final band = vfo.band;
    if (vfo.freq != null || band == null) return false;
    final runtime = _runtimes[uuid];
    if (runtime == null || runtime.session is! TransceiverSession) return false;
    // Already there — the operator emptied the frequency field, or picked the
    // band the radio is on — and the radio's next report fills the frequency
    // back in. Not while an earlier pick is on its way: the radio's last
    // report is where it is leaving.
    final radioFreq = runtime.state.vfo.freqKHz;
    if (heading == null && radioFreq != null && bandForFrequency(radioFreq) == band) return false;

    final freqKHz =
        runtime.lastFreqByBand[bandMemoryKey(band, vfo.mode)] ??
        defaultFrequencyForBand(band, vfo.mode, ituRegion: _radio?.ourItuRegion, countryCode: _radio?.ourCountryCode);
    if (freqKHz == null) return false;
    // A report from the band an earlier pick was leaving is what [tuneNode]
    // measures against now; kept, a pick back to that band would send
    // nothing while the radio carries on to the other one.
    if (heading != null) runtime.lastSent = null;
    // A write like any typed frequency, so the tune takes the cross-band
    // route; it comes back through [_onVfoChanged], which cancels any pick
    // still waiting, so the wait is armed only after it.
    _radio?.setVfo(vfoKey, freq: freqKHz);
    _awaitBand(uuid, runtime, band);
    if (runtime.session case final ReadBackSession session) {
      try {
        session.readBack();
      } catch (e, st) {
        ErrorReportingService.report(e, st, context: 'cat:read-back');
      }
    }
    return true;
  }

  void _awaitBand(String uuid, _NodeRuntime runtime, String band) {
    _cancelBandPick(runtime);
    runtime.bandPick = band;
    runtime.bandPickTimer = Timer(catBandPickGrace, () {
      runtime.bandPickTimer = null;
      if (_disposed || runtime.bandPick == null) return;
      runtime.bandPick = null;
      // Where the radio said it was while the pick held its reports back. A
      // radio that has said nothing yet is not refusing, only slow, and its
      // next report is followed as any is.
      final reported = runtime.state.vfo;
      final vfoKey = _vfoKeyOf(uuid);
      if (runtime.bandPickHeldReport && vfoKey != null && reported.freqKHz != null) _followRadio(vfoKey, reported);
    });
  }

  void _cancelBandPick(_NodeRuntime runtime) {
    runtime.bandPick = null;
    runtime.bandPickHeldReport = false;
    runtime.bandPickTimer?.cancel();
    runtime.bandPickTimer = null;
  }

  /// Whether [reading] — as the radio sent it, not completed from what it was
  /// told — must not reach the app because a band pick is still on its way.
  /// Until the radio reports the picked band, what it says is where it is
  /// coming FROM — a poll answered from the old band — and passing that on
  /// would put the app back where it was.
  bool _heldByBandPick(_NodeRuntime runtime, VfoReading reading) {
    final band = runtime.bandPick;
    if (band == null) return false;
    final freqKHz = reading.freqKHz;
    if (freqKHz == null) return true;
    if (bandForFrequency(freqKHz) != band) {
      runtime.bandPickHeldReport = true;
      return true;
    }
    _cancelBandPick(runtime);
    return false;
  }
}

/// The key a radio's last frequency on [band] is remembered under: by band
/// and [bandModeFamily], so CW on 40 m does not send phone to 7030.
String bandMemoryKey(String band, String? mode) => '$band ${bandModeFamily(mode)}';
