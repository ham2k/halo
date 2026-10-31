// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A FlexRadio slice's audio, switched for SO2R when both SO2R radios are
// slices of one Flex — docs/design/cat.md § The SO2R switcher. Focus mutes
// the other slice; stereo pans A hard left and B hard right. What the
// operator had the slice at is put back when the switching stops.

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../so2r_audio.dart';

/// A slice's `audio_pan` (0 left, 100 right) and `audio_mute`, null where
/// unknown or left alone.
typedef FlexSliceAudio = ({int? pan, bool? mute});

/// What a slice owes the operator: their own audio, and — when a session
/// closed with the slice switched — what it left the slice at, which a later
/// session puts back only if the slice is still there.
typedef _Owed = ({FlexSliceAudio operator, FlexSliceAudio? leftAt});

class FlexSo2rAudio {
  FlexSo2rAudio({required this.slice, required this.host, required this.send});

  final int slice;

  /// The radio's address; null when the session has none.
  final String? Function() host;
  final void Function(String command) send;

  /// What the operator had each slice at before the first switch, by radio
  /// and slice, until it is sent back. Kept for the launch rather than by
  /// the session, so a link that drops while a slice is muted hands the
  /// restore to the next session on that slice rather than leaving that
  /// radio silent.
  static final _owed = <String, _Owed>{};

  @visibleForTesting
  static void forget() => _owed.clear();

  String get _key => '${host() ?? identityHashCode(this)}/$slice';

  So2rEar? _ear;

  /// A change not yet sent: set by [set], and at the start, for a restore a
  /// closed session left owing. Sent at the slice's first status, which
  /// says what the operator had it at, and never again until the next
  /// change — so a pan or mute the operator moves on the radio while one is
  /// set stays where they put it.
  bool _pending = true;

  /// What this session last switched the slice to.
  FlexSliceAudio? _switched;

  /// What the operator had the slice at, once sent back by this session,
  /// while the slice still reads as switched — the base for a switch taken
  /// up again before the radio has caught up with the restore. Dropped once
  /// it reads as anything else: from then on the slice's status is the
  /// operator's own.
  FlexSliceAudio? _restored;

  /// Switches the slice to [ear], or back to the operator's audio for null.
  /// [current] is the slice as last reported.
  void set(So2rEar? ear, FlexSliceAudio current) {
    if (ear == _ear) return;
    _ear = ear;
    _pending = true;
    apply(current);
  }

  /// Sends what is pending, once the slice has said anything: called on a
  /// change and on each of the slice's status pushes.
  void apply(FlexSliceAudio current) {
    if (_restored != null && !_reads(current, _switched)) _restored = null;
    if (!_pending) return;
    // Nothing yet to take the operator's audio from — or a slice that is gone.
    if (current.pan == null && current.mute == null) return;
    _pending = false;
    final ear = _ear;
    if (ear == null) {
      final owed = _owed.remove(_key);
      // A session that closed switched left the slice as [leftAt]; a slice
      // reading otherwise now was put back, or set by the operator since.
      if (owed == null || (owed.leftAt != null && !_reads(current, owed.leftAt))) return;
      _restored = owed.operator;
      _send(owed.operator);
      return;
    }
    // Owed from here on by this session, which knows what it set: a closed
    // session's [leftAt] says nothing about the slice once this one switches it.
    _owed[_key] = (operator: _owed[_key]?.operator ?? _restored ?? current, leftAt: null);
    final want = switch (ear) {
      So2rEar.both => (pan: 50, mute: false),
      So2rEar.left => (pan: 0, mute: false),
      So2rEar.right => (pan: 100, mute: false),
      // The pan is left where it is: only the mute says this slice is not
      // the one in focus.
      So2rEar.muted => (pan: null, mute: true),
    };
    _switched = want;
    _send(want);
  }

  /// Whether [current] reads as [audio], in every field [audio] sets.
  static bool _reads(FlexSliceAudio current, FlexSliceAudio? audio) =>
      audio != null && (audio.pan == null || audio.pan == current.pan) && (audio.mute == null || audio.mute == current.mute);

  /// Every field [want] sets, whatever the slice last reported: a radio
  /// that does not report its own audio back, or reports it late, would
  /// otherwise read as already there, and the change would never be sent.
  void _send(FlexSliceAudio want) {
    if (want.pan case final pan?) send('slice set $slice audio_pan=$pan');
    if (want.mute case final mute?) send('slice set $slice audio_mute=${mute ? 1 : 0}');
  }

  /// The session closing: the operator's audio goes back while the link
  /// still carries it, and stays owed to the next session on the slice in
  /// case the closing link did not deliver it.
  void teardown(FlexSliceAudio current) {
    final owed = _owed[_key];
    final leftAt = _ear == null ? null : _switched;
    set(null, current);
    if (owed != null && leftAt != null) _owed[_key] = (operator: owed.operator, leftAt: leftAt);
  }
}
