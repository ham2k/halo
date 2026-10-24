// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Radio control: the frequency, band and mode an entry is composed at,
// the Band and Mode dropdowns' type-to-filter and commit machinery, and the
// mirror between those fields and the device VFO (`VfoStore`) — following a
// connected rig, and pushing the operator's own edits back to it.
//
// [RadioControlModel] holds that state on behalf of `LoggingControls`, which
// still decides WHEN the model moves (a QSO opened for editing, a command, a
// wipe) and what else moves with it (a rescore, the power field). The model
// notifies on every change the panel has to repaint for, and never touches a
// field that is not its own. [RadioControlFields] draws the control's
// expanded row from it.
//
// The Power control lives here too — its field on the model, and
// [PowerControlFields] / [powerControlSpec] beside the Radio ones — because
// its value lives on the same VFO (`Vfo.power`) the Radio control mirrors:
// seeded from it while composing, pushed back on commit, and never touched
// by an edit, under the same rule as the frequency.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';

import 'density.dart';
import 'keyboard_accessory.dart' show NumbersRowExtraKey;
import 'logging_controls_draft.dart';
import 'logging_controls_metrics.dart';
import 'logging_controls_types.dart';
import 'mdi_icons.g.dart';
import 'panel_model.dart';
import 'secondary_control_row.dart' show SecondaryControlSpec, SummaryPart;
import 'spacing.dart';
import 'theme.dart';
import 'platform_view_shield.dart';

part 'logging_controls_radio_fields.dart';

/// What the model reads from the panel's live configuration — re-read on
/// every use rather than copied in, because each of these can change under a
/// mounted panel (`didUpdateWidget`), and a copy would go stale with nothing
/// to refresh it.
typedef RadioControlConfig = ({
  /// The rig as the app wired the panel up with — taken whole rather than
  /// restated field by field, so a new rig input reaches the model by being
  /// added to [RadioHookup] and nowhere else. Anything about the RIG belongs
  /// there; anything about the widgets' own plumbing (formatters, keyboard,
  /// callbacks) is a parameter of the chip and row builders, and what is
  /// neither is a field of this record.
  ///
  /// The chip and the expanded row read the rig from here rather than taking
  /// it themselves, so nothing can disagree with the model about the radio.
  RadioHookup radio,

  /// Whether power is part of the entry by the panel's own rule — the Power
  /// control is in the row, or the app is tracking it with the rest of the
  /// station info. Only then is the field seeded from the VFO. The record's
  /// own power is the draft's ([QsoDraft.powerOnRecord]). A function:
  /// answering it walks the control catalog, and most reads of this
  /// configuration never ask.
  bool Function() powerInPlay,
  Qso? editingQso,
});

/// The Radio control's state: frequency, band and mode, the two dropdowns,
/// and the VFO mirror. See the file comment.
///
/// Every rule about "editing an existing QSO" runs on the same premise: an
/// edit applies changes to the QSO, never to the VFO — only a new (composing)
/// QSO's Radio control mirrors and edits the VFO.
class RadioControlModel extends ChangeNotifier with PanelModel {
  RadioControlModel({required this.config, required this.draft, required this.onRescore}) {
    bandFocus = _dropdownCommitFocusNode(commit: commitBandText, clearFilter: () => _bandFilter = '', menu: bandMenu, frame: bandFrame, step: stepBand);
    modeFocus = _dropdownCommitFocusNode(commit: commitModeText, clearFilter: () => _modeFilter = '', menu: modeMenu, frame: modeFrame, step: stepMode);
  }

  /// The panel's configuration as it stands right now.
  final RadioControlConfig Function() config;

  /// The draft the panel composes — read for [QsoDraft.isPopulating]: a
  /// programmatic write to the frequency field is never the operator's own
  /// edit, and never a push back to the radio.
  final QsoDraft draft;

  /// Asks the panel to rescore the candidate contact: the dupe, New Band and
  /// New Mode notices are scored against band and mode.
  final VoidCallback onRescore;

  final freqController = TextEditingController();
  final freqFocus = FocusNode();

  /// The Power control's watts. Mirrors the VFO's power while composing
  /// ([seedPowerFromVfo]) and the QSO's own while editing one, exactly as
  /// the frequency field mirrors [Vfo.freq].
  final powerController = TextEditingController();
  final powerFocus = FocusNode();

  // The Band/Mode dropdown text. Owned here (not left to DropdownMenu's
  // internal controller) so typed text can drive the entry filter and be
  // committed to the first match — see [commitBandText] / [commitModeText].
  final bandController = TextEditingController();
  final modeController = TextEditingController();
  final bandMenu = MenuController();
  final modeMenu = MenuController();
  late final FocusNode bandFocus;
  late final FocusNode modeFocus;

  // A focus node around each whole dropdown — never focusable or a Tab stop
  // itself (the Focus widget that mounts it says so), so the focus ladder
  // (docs/design/logging-fields.md) sees only the field. Its `hasFocus`
  // covers every node inside: the field, the node of DropdownMenu's own
  // that takes focus when its arrow opens the menu, and the menu overlay
  // itself. Focus leaving the FRAME is what ends an interaction with the
  // dropdown — see [_dropdownCommitFocusNode].
  final bandFrame = FocusNode(debugLabel: 'Band dropdown');
  final modeFrame = FocusNode(debugLabel: 'Mode dropdown');

  // The active menu filter — what the user actually typed — kept separate
  // from the field's display text, which arrow navigation overwrites with
  // full option labels. Reset when a field gains focus, so each fresh
  // interaction starts unfiltered.
  String _bandFilter = '';
  String _modeFilter = '';
  // True while an arrow key is stepping/walking the selection, so the
  // resulting display-text write (ours when the menu is closed,
  // DropdownMenu's own when it's open) is not mistaken for typed input and
  // does not clobber the filter.
  bool _navigatingDropdown = false;

  /// What gets LOGGED. Assigned raw by the panel when a record is loaded
  /// (a stored mode is already resolved); every REQUEST for a mode goes
  /// through [resolveMode] first — see [setMode].
  String mode = 'SSB';

  /// Band set via a "20m " command when no frequency is entered.
  String? manualBand;

  /// The band of the most recent non-empty frequency, remembered so that
  /// clearing the frequency field keeps that band ([_onFreqChanged]) rather
  /// than dropping to no band.
  String? _lastBandFromFreq;

  /// The operator has typed a frequency the VFO hasn't been told about
  /// yet, so their intent is newer than anything the VFO reports. Set on a
  /// real edit, cleared whenever the field and the VFO are back in sync
  /// (pushed to it, or seeded from it).
  ///
  /// Deliberately not a focus check: the panel focuses the frequency field
  /// when the Radio control is expanded, so refusing to follow while focused
  /// would refuse exactly when the operator is watching the radio.
  bool _freqTouched = false;

  /// `mode` as it stood before the current frequency-typing session
  /// started, snapshotted once on the session's first keystroke ([_freqTouched]
  /// transitioning false→true) — the band-plan guess in [_onFreqChanged]
  /// falls back to this when the fully-typed frequency has no guess of its
  /// own (HALO-32). Without it, a transient mid-typing prefix that DOES
  /// match a segment (e.g. "1800" while typing "18001", a real gap between
  /// 160m and 17m) would leave `mode` stuck on that guess instead of
  /// restoring what the operator had before they started editing.
  String? _modeBeforeFreqEdit;

  /// The frequency text as of the last notification — the baseline that
  /// tells a real edit from a bare cursor move. Same idiom, and the same
  /// reason, as the Time control's `TimeControlModel._lastText`.
  String _lastFreqText = '';

  /// The frequency text when the field last gained focus — what
  /// [commitBandTypedIntoFreqField] compares against to tell the operator's
  /// text from a reading the field merely displayed.
  String _freqTextOnFocus = '';

  /// Pending push of a manually-typed frequency to the VFO — see
  /// [_onFreqChanged] and [pushVfo].
  Timer? _vfoDebounce;

  /// The chip's decimals while the frequency moves — see [FreqDecimalsHold].
  late final _freqDecimals = FreqDecimalsHold(onSettle: notify);

  bool _bound = false;

  // ---- What the panel reads ----

  double? get freq => parseFreq(freqController.text);
  String? get band => freq != null ? bandForFrequency(freq!) : manualBand;

  /// See [_freqTouched].
  bool get freqTouched => _freqTouched;

  /// Whether the band plan puts the frequency in the field outside the
  /// operator's own allocation — scoped by their region/country, so it stays
  /// false while we don't know where they are (see [isOutOfBandFrequency]).
  /// Only a typed/tuned frequency can be out of band: a manually picked band
  /// names no one point to check.
  bool get outOfBand {
    final freq = this.freq;
    final cfg = config();
    return freq != null && isOutOfBandFrequency(freq, ituRegion: cfg.radio.ourItuRegion, countryCode: cfg.radio.ourCountryCode);
  }

  /// `mode` as the Mode dropdown and the Radio chip show it, per
  /// docs/design/cat.md's "Showing it back". What gets LOGGED is [mode].
  String get displayedMode => displayMode(mode, freqKHz: freq, band: band) ?? mode;

  /// [displayedMode] for a pane that WRITES the mode back, except where
  /// nothing was stated to collapse against — there the collapse cannot be
  /// undone on the way in, so an untouched save would swap a stored sideband
  /// for a generic `SSB` the select does not even offer back.
  String get modeForEditing => expectedSideband(freqKHz: freq, band: band) == null ? mode : displayedMode;

  /// [mode] with a generic `SSB` resolved against where the fields stand — the
  /// panel's own copy of what `RadioService.setVfo` does, because a pick made
  /// while editing an existing QSO never reaches the VFO.
  ///
  /// Guarded on the CONVENTION, not on the fields: nothing stated is the only
  /// case with no answer, and [resolveMode] must answer regardless.
  String resolveMode(String requested) =>
      expectedSideband(freqKHz: freq, band: band) == null ? requested : (resolveSideband(requested, freq, band: band) ?? requested);

  /// Nothing has ever been stored in the VFO: no band *and* no frequency, or
  /// no mode. This is the fresh-install state — `RadioService` persists the
  /// VFO device-wide, so once the operator answers it is false forever after.
  ///
  /// Mode counts even though [mode] itself always has a value: it falls back
  /// to a hardcoded 'SSB' the operator never chose, and `vfoA.mode` being null
  /// is what distinguishes "defaulted" from "confirmed".
  bool get vfoIsUnset {
    final vfo = config().radio.radioService?.vfoA;
    if (vfo == null) return false; // no radio state at all to be missing
    return (vfo.freq == null && vfo.band == null) || vfo.mode == null;
  }

  /// The Radio chip's summary as plain text, for the `summary` every spec must
  /// carry. Built from [summaryParts] so the two cannot disagree.
  String get summary => summaryParts().map((p) => p.text).join();

  /// The same summary as colored runs, so the chip can spell one part of it
  /// wrong without repainting the whole chip. Null [errorColor] (the
  /// plain-text caller above) leaves every run uncolored.
  List<SummaryPart> summaryParts({Color? errorColor}) {
    final freq = this.freq;
    final band = this.band;
    final outOfBand = this.outOfBand;
    final head = freq != null ? fmtFreq(freq, minDecimals: _freqDecimals.decimals) : (band ?? 'Band???');
    // Out of band takes the mode's place rather than sitting beside it: the
    // pill is the whole warning on a collapsed row, and "not allowed to
    // transmit here" outranks which mode the log will record. `mode` itself
    // is untouched — [outOfBandMode] is never a value it can take.
    //
    // [displayMode]'s rule, in the error color — suppressed wherever the chip
    // itself alerts, whose condition this must MATCH (see its `alert:`): error
    // text on the errorContainer ground is faint, and on a selected chip's
    // solid error fill invisible. A frequency in a gap between bands alerts
    // (no band) and still has an expected sideband, so neither half implies
    // the other.
    final unexpected = !outOfBand && band != null && isUnexpectedSideband(mode, freqKHz: freq, band: band);
    return [
      (text: head, color: null),
      (text: ' • ', color: null),
      (text: outOfBand ? outOfBandMode : (displayMode(mode, freqKHz: freq, band: band) ?? mode), color: unexpected ? errorColor : null),
    ];
  }

  // ---- Lifecycle ----

  /// Attaches the field listeners. Separate from construction so the panel
  /// can seed the fields first without the seed reading as an edit: a write
  /// that lands before this notifies nobody, so the baseline is taken here,
  /// from whatever the fields hold — an out-of-date one reads the first
  /// cursor move as an edit and switches live follow off. A second call is
  /// a no-op: listeners attached twice would run every rule twice.
  void bind() {
    if (_bound) return;
    _bound = true;
    freqController.addListener(_onFreqChanged);
    bandController.addListener(_onBandTextChanged);
    modeController.addListener(_onModeTextChanged);
    // Every keystroke repaints: the chip's summary reads the field rather
    // than the VFO (blur is what commits one to the other), and the panel's
    // second action button re-reads whether the entry differs from the
    // record, which the field's watts are part of.
    powerController.addListener(notify);
    powerFocus.addListener(_onPowerFocusChanged);
    recordFreqText();
  }

  /// The chip's glyph — a transceiver should look like one thing throughout
  /// the row, so the settings dialog's entry reads this too.
  IconData get chipIcon => config().radio.hasConfiguredRadio ? MdiIcons.cat : MdiIcons.radio;

  /// Whether the radio is on the air — the chip shows a red dot in place of
  /// its glyph, in the same slot so the row does not shift under it.
  bool get transmitting => config().radio.radioTransmitting;

  /// The chip's icon colour for the rig's state — null when there is no
  /// radio to report on. [selected] is the pill's own; see [radioStatusColor].
  Color? statusColor(ThemeData theme, {required bool selected}) {
    final config = this.config();
    return radioStatusColor(theme, hasConfiguredRadio: config.radio.hasConfiguredRadio, connected: config.radio.radioConnected, selected: selected);
  }

  @override
  void dispose() {
    _vfoDebounce?.cancel();
    _freqDecimals.dispose();
    freqController.dispose();
    bandController.dispose();
    modeController.dispose();
    bandFocus.dispose();
    modeFocus.dispose();
    bandFrame.dispose();
    modeFrame.dispose();
    freqFocus.dispose();
    powerController.dispose();
    powerFocus.dispose();
    super.dispose();
  }

  // ---- Writes the panel makes ----

  /// Puts a frequency in the field, in full precision and ungrouped, so
  /// [parseFreq] reads it back unchanged: selecting a QSO must not flag it as
  /// changed. A frequency names its own band, so the manual one goes.
  void setFrequency(double freq) {
    freqController.text = fmtFreqInput(freq);
    manualBand = null;
  }

  /// Empties the frequency field and takes [band] as the manual one — the
  /// shape a "20m" command, a band-only record, or a pane that cleared the
  /// frequency leaves the control in. Null is a record with neither.
  ///
  /// Assigned AFTER the clear: clearing the field notifies the frequency
  /// listener synchronously, and its empty-field branch falls back to the
  /// band of the last frequency — so a null [band] assigned first would be
  /// refilled, and a record with no band would read as on the band the
  /// operator last typed. Every caller writes a record or a command result
  /// while the panel is populating, so the listener pushes nothing to the
  /// rig in between; a composing-time caller would have to settle that push
  /// itself, as [applyBandPick] does.
  void setBand(String? band) {
    freqController.clear();
    manualBand = band;
  }

  /// Sets `mode` to a band-plan guess (HALO-32) — shared by [_onFreqChanged]
  /// and the frequency-command branch of the panel's `_dispatchActions`, both
  /// of which need exactly this and nothing more: unlike [setMode], no
  /// immediate radio push (the caller's own debounce, or its own batched push
  /// alongside freq/band, handles that) and no rescore (the caller already
  /// schedules one for the frequency/band change this guess rides along
  /// with). Callers wrap this in their own rebuild. A no-op when [mode]
  /// already matches, so callers can call it unconditionally once they have a
  /// non-null guess.
  void applyModeGuess(String guess) {
    // The band plan says "SSB"; which sideband that is belongs to the band.
    // Resolved here rather than left to the caller's push because editing an
    // existing QSO makes no push at all.
    final resolved = resolveMode(guess);
    if (resolved == mode) return;
    mode = resolved;
  }

  /// Puts the Band and Mode fields back in step with [band]/[mode] after
  /// something other than the dropdowns themselves moved them — a connected
  /// rig, a spot the operator tapped, a QSO opened for editing.
  ///
  /// A filter the operator had typed is dropped rather than kept. It was an
  /// in-progress edit of a value that has since moved, so keeping it leaves
  /// the field describing a mode that no longer applies — and the commit on
  /// the way out then pushes that stale text back over the change, taking a
  /// rig that just reported CW and retuning it to FT8 on the strength of a
  /// keystroke that predates the report.
  ///
  /// Writing the controllers here rather than leaving it to
  /// `DropdownMenu.initialSelection` is the point: that sync fires only when
  /// the new value is among the entries the menu was last given, so a
  /// filtered menu — the only state this method has to repair — is exactly
  /// the state it skips.
  ///
  /// Callers must have established that the value actually changed: an
  /// unconditional call from a path a connected radio drives (a VFO
  /// notification restating the mode it is already on) would wipe whatever
  /// the operator is typing at the time. The command paths need none of
  /// this — a command is typed into the call field, so no dropdown holds a
  /// filter when one lands.
  void resyncDropdownFields() {
    _bandFilter = '';
    _modeFilter = '';
    bandController.text = band ?? '';
    modeController.text = displayedMode;
  }

  /// Takes the picked mode, resolved to a sideband ([resolveMode]).
  /// `RadioService.setVfo` resolves it too, but an edit of an existing QSO
  /// never reaches the VFO, and until the rig's own reading came back the
  /// field held a mode no radio can be in.
  void setMode(String picked) {
    mode = resolveMode(picked);
    notify();
    final cfg = config();
    if (cfg.editingQso == null) cfg.radio.radioService?.setVfo('vfoA', mode: mode);
    // New Mode / New Band notices depend on the mode — rescore the candidate.
    onRescore();
  }

  /// Seeds freq/band/mode from the operation's `vfoA` — the operation's
  /// last-known radio state, rather than a hardcoded default. Never called
  /// while editing an existing *contact*, whose own recorded freq/band/mode
  /// always takes priority; an event's freq/mode are sentinels instead of a
  /// record, so the panel seeds one anyway, same as composing.
  /// [skipFrequency] leaves the frequency field (and its band) alone while
  /// taking the mode: a pending edit is the operator's and newer, but only
  /// as far as the field they are actually typing in.
  ///
  /// The Power field is seeded with it, under its own rule
  /// ([seedPowerFromVfo]).
  void seedFromVfo({bool skipFrequency = false}) {
    final vfo = config().radio.radioService?.vfoA;
    if (vfo == null) return;
    if (!skipFrequency) {
      final freq = vfo.freq;
      final text = freq != null ? fmtFreqInput(freq) : '';
      // Only when it differs: assigning `text` collapses the selection, so an
      // unconditional write would move the caret every time a connected radio
      // restated the frequency it is already on.
      if (freqController.text != text) freqController.text = text;
      recordFreqText();
      manualBand = freq == null ? vfo.band : null;
      _freqTouched = false;
    }
    if (vfo.mode != null && vfo.mode != mode) {
      mode = vfo.mode!;
    }
    seedPowerFromVfo();
  }

  // ---- Power ----

  /// Whether power is part of the entry — see [RadioControlConfig.powerInPlay].
  bool get powerInPlay => config().powerInPlay();

  /// The watts in the Power field, or null when it is empty (or holds
  /// something that is not a number).
  num? get powerWatts => num.tryParse(powerController.text.trim());

  /// The chip's summary: the field's watts, or a dash.
  String get powerSummary {
    final watts = powerWatts;
    return watts == null ? '—' : '$watts ${t.loggingControls.powerUnit}';
  }

  /// Seeds the Power field from the VFO, only while power is in play — never
  /// over the operator's own typing, and never over a QSO already logged: an
  /// existing record's power is its own ([QsoDraft.applyData] seeds it), not
  /// whatever the rig happens to be set to now. Called on its own when power
  /// has just come into play, and by [seedFromVfo] with the rest.
  void seedPowerFromVfo() {
    final config = this.config();
    if (!config.powerInPlay() || config.editingQso != null || powerFocus.hasFocus) return;
    final power = config.radio.radioService?.vfoA.power;
    final text = power == null ? '' : '$power';
    if (powerController.text != text) powerController.text = text;
  }

  /// Pushes the field to the VFO, which is where every power surface reads
  /// it from and how a connected radio hears about it (CAT forwards it the
  /// way it forwards a typed frequency). Never while editing an existing
  /// QSO: that applies changes to the QSO, never the VFO — the same rule the
  /// frequency follows. Its own call, apart from [pushVfo]: a debounced
  /// frequency push must not commit a power still being typed.
  void commitPower() {
    final config = this.config();
    if (config.editingQso != null) return;
    final watts = powerWatts;
    config.radio.radioService?.setVfo('vfoA', power: watts, clearPower: watts == null);
  }

  /// Committed on blur rather than on every keystroke: typing "100" passes
  /// through 1 and 10, and each would be a power command sent to the radio.
  /// Blur covers Enter too — it closes the control and takes the focus with
  /// it.
  void _onPowerFocusChanged() {
    if (!powerFocus.hasFocus) commitPower();
  }

  /// Takes power back out of the entry: the field, and the record's own
  /// value. Whatever the field holds belonged to the QSO just closed, and
  /// [seedPowerFromVfo] only refills it while power is in play.
  void clearPowerEntry() {
    draft.powerOnRecord = false;
    powerController.clear();
  }

  /// Ends a pending frequency edit at a QSO boundary — logging, wiping, or
  /// an editing session closing.
  ///
  /// `_freqTouched` switches live radio follow off, and nothing else resets
  /// it: a partial entry of three characters or fewer arms no debounce, so
  /// without this the Radio control stops following the rig for the rest of
  /// the session. A push that is still pending is flushed rather than
  /// dropped — the operator typed it, and the field still shows it.
  ///
  /// [flush] is false on the one caller that runs inside `didUpdateWidget`:
  /// `setVfo` notifies, and a listener calling `setState` during the build
  /// phase errors. That caller is discarding the composing form, so the
  /// pending push is dropped with it rather than left armed to tune the rig
  /// to a frequency the reset just threw away.
  void settlePendingFreqEdit({bool flush = true}) {
    if (flush && (_vfoDebounce?.isActive ?? false)) {
      _vfoDebounce!.cancel();
      pushVfo();
      return;
    }
    _vfoDebounce?.cancel();
    _freqTouched = false;
    recordFreqText();
  }

  /// Drops a pending push without sending it. The push a debounce was armed
  /// for belongs to an entry that is being discarded.
  void cancelPendingPush() => _vfoDebounce?.cancel();

  /// Flushes a pending push before a log, so a frequency typed just before
  /// Enter reaches both the VFO and the QSO rather than only landing after
  /// the fact. Keyed on the timer's existence, not its liveness: a push
  /// that already went out is repeated, which the store's value equality
  /// makes a no-op, and that is cheaper than a frequency that never reaches
  /// the record.
  void flushPendingPush() {
    if (_vfoDebounce == null) return;
    _vfoDebounce!.cancel();
    _vfoDebounce = null;
    pushVfo();
  }

  /// Pushes the current freq/band/mode to the VFO as `vfoA`.
  void pushVfo() {
    config().radio.radioService?.setVfo('vfoA', freq: freq, band: band, mode: mode);
    // The field and the VFO agree again: not a pending edit, and the
    // baseline moves with it.
    _freqTouched = false;
    recordFreqText();
  }

  /// Re-baselines the frequency edit detector. Call wherever the field is
  /// written by something other than the operator, or the next bare cursor
  /// move is misread as an edit and live follow switches itself off.
  void recordFreqText() => _lastFreqText = freqController.text;

  /// The panel's focus listener for the frequency field hands its focus
  /// changes here. Gaining focus snapshots the text, for
  /// [commitBandTypedIntoFreqField]; losing it commits a band typed into the
  /// field and flushes a pending push immediately, rather than making the
  /// operator wait out the rest of the 5s window. Never pushes while editing
  /// an existing QSO — see [_onFreqChanged].
  void onFreqFocusChanged({required bool hasFocus}) {
    if (hasFocus) {
      _freqTextOnFocus = freqController.text;
      return;
    }
    // Ahead of the flush below: a band empties the field, and a push
    // carrying the band the operator just named beats one carrying the
    // digits they named it with.
    commitBandTypedIntoFreqField();
    _vfoDebounce?.cancel();
    if (config().editingQso == null && freqController.text.trim().length > 3) {
      pushVfo();
    }
  }

  // ---- The frequency field ----

  void _onFreqChanged() {
    final freq = this.freq;
    if (freq != null) {
      manualBand = null;
      // Remember the band so clearing the frequency can fall back to it.
      _lastBandFromFreq = bandForFrequency(freq);
    } else if (freqController.text.trim().isEmpty) {
      // Frequency cleared: stay on the band it was last, rather than dropping
      // to no band. Deferential (`??=`) so a band the user set by hand wins.
      manualBand ??= _lastBandFromFreq;
    }
    if (freq != null) _freqDecimals.note(freq);
    notify();
    final populating = draft.isPopulating;
    // Band (derived from frequency) drives the New Band notice — rescore.
    if (!populating) onRescore();
    // Editing an existing QSO applies changes to the QSO, never the VFO —
    // only a new (composing) QSO's Radio control mirrors/edits the VFO.
    // A TextEditingController notifies on SELECTION changes too, and
    // expanding the Radio control focuses this field, which moves the
    // cursor. Without this guard merely opening the control would look like
    // an edit: live follow would switch itself off, and a pointless push to
    // the radio would be armed. Same trap, and the same fix, as the Time
    // control's field listener.
    //
    // The baseline moves BEFORE the guards below — exactly as
    // `TimeControlModel` does it, and for the same reason. A
    // programmatic write (a suggestion, an editing session ending) runs
    // under `isPopulating`; if the baseline didn't move with it, the next
    // bare cursor click would compare against a stale value, read as an
    // edit, and silently switch live follow off.
    final text = freqController.text;
    final changed = text != _lastFreqText;
    _lastFreqText = text;
    final cfg = config();
    if (populating || cfg.editingQso != null) return;
    if (!changed) return;
    // The session's first keystroke: snapshot the mode as it stood before
    // this edit, for the band-plan guess below to fall back to. Guarded on
    // `!_freqTouched` so it captures once per session, not on every
    // keystroke — otherwise it would just track whatever the guess itself
    // last set `mode` to.
    if (!_freqTouched) _modeBeforeFreqEdit = mode;
    // The operator's own edit — newer than whatever the VFO says, so live
    // follow must leave it alone until it's been pushed.
    _freqTouched = true;
    // HALO-32: a frequency the operator typed themselves — guess its mode
    // from the band plan, same as a radio-driven change ([seedFromVfo]) or a
    // suggested QSO already set `mode` from their own source. Falls back to
    // `_modeBeforeFreqEdit` (not left at whatever the previous keystroke's
    // guess happened to be) when this keystroke's frequency has no band-plan
    // opinion — typing digit by digit can pass through a prefix that does
    // match before landing on a final value that doesn't (e.g. "1800", a
    // real match, mid-typing "18001", a real gap between 160m and 17m).
    if (freq != null) {
      final guess = modeForFrequency(freq, ituRegion: cfg.radio.ourItuRegion, countryCode: cfg.radio.ourCountryCode) ?? _modeBeforeFreqEdit;
      // Compared RESOLVED: a generic `SSB` guess against a generic `SSB` mode
      // is not a no-op once there is a frequency to resolve against, so the
      // raw comparison blocked it — and dropping the comparison altogether
      // rebuilt the whole panel on every keystroke, since a guess almost
      // always exists.
      if (guess != null && resolveMode(guess) != mode) {
        applyModeGuess(guess);
        notify();
      }
    }
    // Only push once there's enough digits to plausibly be a real
    // frequency (mirrors the frequency command's own `length < 3` reject),
    // debounced so we're not writing to the operation on every keystroke.
    _vfoDebounce?.cancel();
    if (freqController.text.trim().length > 3) {
      _vfoDebounce = Timer(const Duration(seconds: 5), pushVfo);
    } else if (freqController.text.trim().isEmpty) {
      // Clearing the field is unambiguous — push it immediately rather than
      // debouncing, so dependents reading radioService.vfoA (e.g. the
      // Spotting control) drop the stale frequency right away.
      cfg.radio.radioService?.setVfo('vfoA', clearFreq: true, band: manualBand, mode: mode);
      _freqTouched = false;
    }
  }

  /// HALO-158: the frequency field also takes a band — "20", "20m", "70cm".
  /// Resolved when the operator is done with the field (blur, which Space and
  /// Enter both reach) rather than per keystroke, so a frequency typed digit
  /// by digit never flickers through a band on its way: "20" en route to
  /// "20450" is a prefix, not a request for 20m.
  ///
  /// A frequency wins whenever the text names one, so this can only claim
  /// numbers no band covers — see [parseBandInput] for why that leaves the
  /// bare-number form unambiguous.
  ///
  /// Only text the operator changed while the field held focus is eligible.
  /// The band numbers are all outside the amateur bands, but a general-
  /// coverage rig reports whatever it is tuned to: parked on WWVB at 60 kHz,
  /// the field reads "60", and merely opening the Radio control (which focuses
  /// this field) and leaving it would otherwise swallow the reading and push
  /// 60m back at the rig. `_freqTouched` can't serve as the gate — it is never
  /// set while editing an existing QSO, which is a case this must still work
  /// in.
  void commitBandTypedIntoFreqField() {
    final text = freqController.text;
    if (text == _freqTextOnFocus) return;
    final freq = parseFreq(text);
    if (freq != null && bandForFrequency(freq) != null) return;
    final band = parseBandInput(text);
    // Unconditional even when the band is already selected: the field still
    // holds the text that named it, and clearing that is half of the point.
    if (band != null) applyBandPick(band);
  }

  // ---- The Band and Mode dropdowns ----

  /// The Band dropdown's options: the enabled list (`enabledBands`), the
  /// common tier when that's empty, the full catalog when null — with the
  /// current value appended when it's not in the list (see the panel field's
  /// doc for why each fallback exists).
  List<String> bandOptions() {
    final enabled = config().radio.enabledBands;
    final options = enabled == null
        ? [for (final b in bands) b.name]
        : enabled.isEmpty
        ? popularBands
        : enabled;
    final band = this.band;
    return [...options, if (band != null && !options.contains(band)) band];
  }

  List<String> modeOptions() {
    final enabled = config().radio.enabledModes;
    final options = enabled == null
        ? modes
        : enabled.isEmpty
        ? mainModes
        : enabled;
    return [...options, if (!options.contains(displayedMode)) displayedMode];
  }

  /// Menu entries for the active [filter]: a case-insensitive match at a
  /// word start ([matchesWordStart]). An empty filter (nothing typed, or cleared on focus) and a
  /// filter matching nothing both mean "no filter" — the latter so a typo
  /// shows the full menu rather than an empty one. The filter only ever
  /// holds genuinely typed text (see [_onDropdownTextChanged]), so typing a
  /// complete short name like "2m" narrows to it rather than showing all.
  List<String> _filteredOptions(List<String> options, String filter) {
    final typed = filter.trim();
    if (typed.isEmpty) return options;
    final matches = [
      for (final o in options)
        if (matchesWordStart(o, typed)) o,
    ];
    return matches.isEmpty ? options : matches;
  }

  /// An exact (case-insensitive) match wins over the first word-start match,
  /// so e.g. "2m" can never resolve to another band that merely starts with
  /// it.
  String? _firstMatch(List<String> options, String text) {
    final q = text.toLowerCase();
    for (final o in options) {
      if (o.toLowerCase() == q) return o;
    }
    for (final o in options) {
      if (matchesWordStart(o, text)) return o;
    }
    return null;
  }

  // The menu-entry lists are memoized on the joined option values and reused
  // while unchanged: DropdownMenu compares entries by LIST IDENTITY in
  // didUpdateWidget and resets its highlight state on any change, so passing
  // a freshly built list on every rebuild (the panel rebuilds each second
  // for the clock alone) would break walking the open menu with the arrow
  // keys. Keyed on the values rather than deep-compared, so re-deriving the
  // entries costs one join, not an element-wise scan.
  String? _bandMenuKey;
  String? _modeMenuKey;
  List<DropdownMenuEntry<String>> _bandMenuEntries = const [];
  List<DropdownMenuEntry<String>> _modeMenuEntries = const [];

  /// The Band menu's entries under the current filter — the same list
  /// instance as last time while nothing changed (see above).
  List<DropdownMenuEntry<String>> get bandMenuEntries {
    _bandMenuEntries = _memoEntries(_bandMenuKey, _bandMenuEntries, _filteredOptions(bandOptions(), _bandFilter), (k) => _bandMenuKey = k);
    return _bandMenuEntries;
  }

  List<DropdownMenuEntry<String>> get modeMenuEntries {
    _modeMenuEntries = _memoEntries(_modeMenuKey, _modeMenuEntries, _filteredOptions(modeOptions(), _modeFilter), (k) => _modeMenuKey = k);
    return _modeMenuEntries;
  }

  /// Returns [cache] unchanged when [values] matches [cacheKey], else
  /// rebuilds the entries and updates [cacheKey] via [setKey]. `\x00`
  /// joins the values — a separator that can't appear in a band/mode name,
  /// so distinct value lists never collide on the same key.
  List<DropdownMenuEntry<String>> _memoEntries(String? cacheKey, List<DropdownMenuEntry<String>> cache, List<String> values, void Function(String key) setKey) {
    final key = values.join('\x00');
    if (key == cacheKey) return cache;
    setKey(key);
    return [for (final v in values) DropdownMenuEntry(value: v, label: v, labelWidget: _ShieldedEntryLabel(v), style: _shieldedEntryStyle)];
  }

  void _onBandTextChanged() => _onDropdownTextChanged((f) => _bandFilter = f, bandController.text, band ?? '');

  /// Both spellings of the selection count as one: a pick writes the option's
  /// own label, which for a sideband this band runs is not what the field then
  /// displays — and the displayed spelling alone captured a picked `USB` as
  /// filter text, narrowing the menu to that entry.
  void _onModeTextChanged() {
    final text = modeController.text;
    _onDropdownTextChanged((f) => _modeFilter = f, text, text == mode ? mode : displayedMode);
  }

  /// Captures genuinely typed text as the menu [filter] and rebuilds so the
  /// menu re-filters. Two kinds of controller write must NOT become a
  /// filter: arrow navigation ([_navigatingDropdown]), and the full-label
  /// writes a pick / external selection change / commit push through the
  /// controller — those equal the current [selection], and treating them as
  /// a filter would narrow the menu down to just the selected entry (and,
  /// for the arrow-step's rebuild-time [DropdownMenu.initialSelection] sync,
  /// strand the stepping on a single entry). The rebuild is deferred when
  /// the change lands during build — DropdownMenu writes to the controller
  /// from its own initState/didUpdateWidget, where a synchronous setState
  /// would throw.
  void _onDropdownTextChanged(ValueChanged<String> setFilter, String text, String selection) {
    if (isDisposed) return;
    if (!_navigatingDropdown && text != selection) setFilter(text);
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => notify());
    } else {
      notify();
    }
  }

  /// Applies typed-but-not-picked Band text: the first matching option
  /// becomes the selection, exactly as if picked from the menu; no match
  /// reverts the text to the current selection. Runs on Enter (before the
  /// root CallbackShortcuts logs the QSO, so the QSO gets the new band) and
  /// when focus leaves the dropdown. The disposed guard matters because
  /// this is invoked from a `scheduleMicrotask` in the blur handler, which
  /// can outlive the panel (e.g. the operation view closing while a
  /// dropdown holds focus) — notifying a disposed model would throw.
  void commitBandText() {
    if (isDisposed) return;
    final text = bandController.text.trim();
    if (text.isNotEmpty && text != (band ?? '')) {
      final match = _firstMatch(bandOptions(), text);
      if (match != null && match != band) applyBandPick(match);
    }
    _bandFilter = '';
    bandController.text = band ?? '';
  }

  void commitModeText() {
    if (isDisposed) return;
    final text = modeController.text.trim();
    if (text.isNotEmpty && text != displayedMode) {
      final match = _firstMatch(modeOptions(), text);
      if (match != null && match != displayedMode) setMode(match);
    }
    _modeFilter = '';
    modeController.text = displayedMode;
  }

  /// A dropdown field's focus node, wired to [commit] typed text on Enter
  /// (letting the event continue toward the root Enter-logs-the-QSO
  /// shortcut, so a logged QSO gets the just-committed value) and when
  /// focus leaves [frame] — the whole dropdown, not just the field: an
  /// arrow-opened menu holds focus on a node of DropdownMenu's own, and a
  /// Tab from there is as much a departure as one from the field. Focus
  /// handed to another node (Tab, a command moving focus) also closes
  /// [menu], so the overlay doesn't linger; a pointer down elsewhere closes
  /// it through the menu's own tap region. The focus-loss commit is deferred
  /// a microtask: a pick from the menu can move focus out before onSelected
  /// fires, and the pick must win over the typed text. The field gaining
  /// focus [clearFilter]s, so each fresh interaction starts unfiltered.
  ///
  /// Arrow keys with the menu CLOSED [step] the actual selection directly;
  /// with the menu open they're left to DropdownMenu's own shortcuts, which
  /// walk the highlight and write each entry into the field. Either way the
  /// stepping stays within the current filter — [_navigatingDropdown]
  /// guards the resulting text write from resetting it.
  FocusNode _dropdownCommitFocusNode({
    required VoidCallback commit,
    required VoidCallback clearFilter,
    required MenuController menu,
    required FocusNode frame,
    required void Function(int delta) step,
  }) {
    final node = FocusNode();
    node.addListener(() {
      if (node.hasFocus) clearFilter();
    });
    // Listened on the frame, not the field: `hasFocus` here stays true while
    // focus moves between the field and the dropdown's own nodes, and turns
    // false only when focus leaves the dropdown altogether.
    frame.addListener(() {
      if (frame.hasFocus) return;
      // Closed only when focus went to another NODE (Tab, a command moving
      // focus) — nothing else takes an overlay down for those. A blur that
      // merely drops focus to the scope is a desktop pointer DOWN outside
      // the text field, and a click on one of the menu's own entries is
      // exactly that: closing here would remove the entry before the
      // pointer up can select it, and the pick is lost. The menu's own tap
      // region already closes it for a pointer down anywhere else.
      final open = menu.isOpen;
      final left = FocusManager.instance.primaryFocus is! FocusScopeNode;
      if (open && left) menu.close();
      // A menu that stays open past the blur is that pointer down on an
      // entry, and the click finishes the interaction: a pick reaches
      // onSelected, which supersedes any typed text. Committing here instead
      // would clear the filter and re-expand the menu under the pressed
      // pointer, so the release lands on a different entry, or on none and
      // leaves the menu up. A press released off the entry leaves the typed
      // text to [_onMenuTapOutside]. Decided from what was asked, not from
      // `isOpen` after the close: the menu stays open for the length of
      // its closing animation, and still reads as open here.
      if (!open || left) scheduleMicrotask(commit);
    });
    node.onKeyEvent = (n, event) {
      if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
        commit();
        return KeyEventResult.ignored;
      }
      if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.arrowUp) {
        // The upcoming display-text write — ours below, or DropdownMenu's
        // own when the menu is open — must not be read back as a new
        // filter. Cleared next microtask, once this event is fully handled.
        _navigatingDropdown = true;
        scheduleMicrotask(() => _navigatingDropdown = false);
        if (!menu.isOpen) {
          step(key == LogicalKeyboardKey.arrowDown ? 1 : -1);
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };
    return node;
  }

  /// A pointer down anywhere outside the Band/Mode field and its menu. The
  /// one that matters lands with the field unfocused and typed text still
  /// in it, and closes the menu: the blur held the commit back while the
  /// menu was open (see [_dropdownCommitFocusNode]), the press ended
  /// without a pick, and nothing else is left to commit the text.
  void onBandMenuTapOutside() => _onMenuTapOutside(bandFocus, bandController, band ?? '', commitBandText);

  void onModeMenuTapOutside() => _onMenuTapOutside(modeFocus, modeController, displayedMode, commitModeText);

  /// Guarded on the text, not on the menu: the text is what says whether
  /// there is anything to commit. The microtask orders the commit after the
  /// menu's own close, whichever tap region the surface calls first.
  void _onMenuTapOutside(FocusNode node, TextEditingController controller, String selection, VoidCallback commit) {
    if (node.hasFocus || controller.text.trim() == selection) return;
    scheduleMicrotask(commit);
  }

  /// The Band dropdown's onSelected effect, shared with the typed-text
  /// commit and the arrow-key step: picking a band directly is mutually
  /// exclusive with a manual frequency, since [band] prefers the
  /// freq-derived value whenever [freq] is set (matches the
  /// `setVfo{band: ...}` command action's convention). Only while composing
  /// — editing an existing QSO applies changes to the QSO, never the VFO.
  void applyBandPick(String value) {
    final cfg = config();
    // A stored sideband was derived from the band being left, so a MOVE
    // re-derives it — `setVfo`'s own condition, for its reason: re-picking the
    // band you are on must not discard a deliberate far sideband. Editing an
    // existing QSO reaches no VFO to do this for it. Compared against the
    // VFO's band, not [band], which [commitBandTypedIntoFreqField] has
    // already blanked by replacing the text that named the old band.
    //
    // Computed BEFORE the field writes: clearing the frequency field notifies
    // `_onFreqChanged` synchronously, and its empty-field branch pushes the
    // VFO stating the mode — pinning the old band's sideband onto the new band
    // at the rig while the panel holds the new one, until the next wipe
    // reseeds the panel from the rig.
    final leavingBand = cfg.editingQso == null ? (cfg.radio.radioService?.vfoA.band ?? band) : band;
    final resolved = (value != leavingBand && isSidebandMode(mode)) ? (resolveSideband('SSB', null, band: value) ?? mode) : mode;
    mode = resolved;
    manualBand = value;
    freqController.clear();
    notify();
    if (cfg.editingQso == null) cfg.radio.radioService?.setVfo('vfoA', band: value);
  }

  /// A pick from the Band menu. A pick is a selection, never a filter.
  /// DropdownMenu writes the picked label into the controller BEFORE
  /// onSelected fires, while [band] still holds the old value, so
  /// [_onDropdownTextChanged]'s `text != selection` test reads that write
  /// as typed text. Left set, the filter narrows the menu to the entry just
  /// picked — and, worse, DropdownMenu only syncs the field to a changed
  /// `initialSelection` when that value is among the entries it was given,
  /// so the field then can't follow a later band-plan or radio change and
  /// strands a stale value that the next commit pushes back over the real
  /// one. Cleared on the strength of [applyBandPick] notifying
  /// unconditionally — a guard added there would leave the menu narrowed
  /// with nothing to repaint it.
  ///
  /// A discrete dropdown pick, not a keystroke — pushed to the VFO
  /// immediately rather than debounced like frequency typing.
  void pickBand(String value) {
    _bandFilter = '';
    applyBandPick(value);
  }

  /// Same clear, same reason, and the same dependency on [setMode]
  /// notifying unconditionally, as [pickBand].
  void pickMode(String value) {
    _modeFilter = '';
    setMode(value);
  }

  void stepBand(int delta) {
    final next = _steppedOption(_filteredOptions(bandOptions(), _bandFilter), band, delta);
    if (next == null) return;
    applyBandPick(next);
    bandController.text = next;
  }

  void stepMode(int delta) {
    final options = _filteredOptions(modeOptions(), _modeFilter);
    // Stepped from the STORED mode wherever the list offers it: from the
    // displayed one the walk strands on the sideband this band runs, because
    // the field reads `SSB` again and the next step recomputes from its index.
    final next = _steppedOption(options, options.contains(mode) ? mode : displayedMode, delta);
    if (next == null) return;
    setMode(next);
    modeController.text = displayedMode;
  }

  /// The option [delta] steps away from [current], wrapping like the open
  /// menu's own highlight does. No current value: down starts at the first
  /// option, up at the last.
  String? _steppedOption(List<String> options, String? current, int delta) {
    if (options.isEmpty) return null;
    final i = current == null ? -1 : options.indexOf(current);
    if (i < 0) return delta > 0 ? options.first : options.last;
    return options[(i + delta) % options.length];
  }
}
