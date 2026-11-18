// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The panadapters HaLo makes on its own station on a Flex: one with each
// slice the operator opens, and one for each sweep a display wants at a span
// of its own — docs/design/cat.md § HaLo's own station on a Flex, § Spectrum.

part of 'flexradio_driver.dart';

extension _OwnSlices on FlexRadio {
  /// Opens a slice on HaLo's station, with the panadapter every slice comes
  /// with, and answers its letter: null when the radio refused or never
  /// said, or this is not HaLo's station.
  ///
  /// Asked right after the station's connection came up, it waits for the
  /// radio's handshake first: sent before it, the radio refuses it.
  Future<String?> openSlice() async {
    if (!gui) return null;
    if (!_handshakeDone) await _handshaken.future.timeout(_sliceOpenWait, onTimeout: () {});
    if (!_handshakeDone || _stationRefused) return null;
    final opened = Completer<String?>();
    _sendCommand(
      'display pan create x=$_panPixels y=$_panRows',
      onReply: (code, body) {
        final pan = body.split(',').first.trim().toLowerCase();
        if (code != 0 || pan.isEmpty) {
          _broadcast((sink) => sink.reportDiagnostic('Flex refused a new slice: 0x${code.toRadixString(16).toUpperCase()}'));
          if (!opened.isCompleted) opened.complete(null);
          return;
        }
        if (_sliceOnPan(pan) case final letter?) return opened.complete(letter);
        _openingSlices[pan] = opened;
      },
    );
    return opened.future.timeout(
      _sliceOpenWait,
      onTimeout: () {
        // Not left waiting: a slice the radio opens later is one the picker
        // offers to add, not one added here behind the operator's back.
        _openingSlices.removeWhere((_, waiting) => identical(waiting, opened));
        return null;
      },
    );
  }

  /// Closes HaLo's slice [letter] on the radio, and the panadapter it came
  /// with; the radio removes the slice with its panadapter. Whether the
  /// radio did: false, with nothing sent, for a slice it has not described.
  Future<bool> closeSlice(String letter) {
    final index = _ownedIndex(letter);
    if (index == null) return Future.value(false);
    final closed = Completer<bool>();
    final command = switch (_slices[index]?.pan) {
      final pan? => 'display pan remove $pan',
      null => 'slice remove $index',
    };
    _sendCommand(command, onReply: (code, _) => closed.complete(code == 0));
    return closed.future.timeout(_sliceOpenWait, onTimeout: () => false);
  }

  String? _sliceOnPan(String pan) {
    for (final status in _slices.values) {
      if (status.pan?.toLowerCase() == pan && status.clientHandle?.toLowerCase() == _handle) return status.label;
    }
    return null;
  }
}

/// The pans HaLo makes for a sweep of their own ([FlexRadioSession.openScope]).
///
/// The radio opens a slice with each, as it does for "New Slice". That slice
/// is removed, since the pan and its FFT outlive it (RadioRoom, 4.3.16), and
/// kept it would take one of the radio's few receivers for every such
/// display. Until it is gone it is none of HaLo's lettered slices: a node of
/// HaLo's whose slice is missing would otherwise take it for its own.
///
/// The pans made are kept with the radio's settings until the radio says
/// each is removed: it keeps a GUI client's pans for its next connection,
/// and a sweep's pan left by a connection that dropped would come back at
/// every connect.
class _FlexSweepPans {
  final FlexRadio _radio;
  _FlexSweepPans(this._radio) : _left = {..._radio.sweepPans};

  /// Pans an earlier connection made, until this one's station is registered.
  final Set<String> _left;

  /// Each pan made, and whether the slice it came with was asked removed.
  final _made = <String, bool>{};

  /// Pans being asked for, and the pans the radio had said of before the
  /// first of them: the radio may describe a new pan's slice before it
  /// answers which pan is new.
  int _making = 0;
  Set<String> _before = const {};

  /// Pans asked for before the station's registration is answered, asked for
  /// once it is: the radio brings back the station's own slices before it
  /// answers, and a pan asked for meanwhile would hold them all back.
  bool _registered = false;
  int? _refusal;
  final _waiting = <({String command, void Function(int code, String body)? onReply})>[];

  void _keep() => _radio.onSweepPans?.call([..._left, ..._made.keys]);

  bool _ours(_SliceStatus status) => status.clientHandle?.toLowerCase() == _radio._handle;

  /// Whether [status] is the slice a sweep's pan came with.
  bool holds(_SliceStatus status) {
    if (!_ours(status)) return false;
    final pan = status.pan?.toLowerCase();
    return _made.containsKey(pan) || (_making > 0 && !_before.contains(pan));
  }

  /// Sends a sweep's `display pan create`, answering [onReply] once the pan
  /// it made is known for one.
  void make(String command, {void Function(int code, String body)? onReply}) {
    if (_refusal case final code?) return onReply?.call(code, '');
    if (!_registered) return _waiting.add((command: command, onReply: onReply));
    if (_making++ == 0) _before = {..._radio._pans.keys};
    _radio._sendForSpectrum(
      command,
      onReply: (code, body) {
        // `0x40000003,0x42000003`: the pan, then its waterfall.
        final pan = body.split(',').first.trim().toLowerCase();
        if (code == 0 && pan.startsWith('0x')) {
          _made[pan] = false;
          _keep();
        }
        if (--_making == 0) _released();
        for (final index in _radio._slices.keys.toList()) {
          sliceHeard(index);
        }
        onReply?.call(code, body);
      },
    );
  }

  /// The slices held back while pans were made that were none of theirs,
  /// offered again and told to their nodes, which heard nothing of them.
  void _released() {
    _radio._publishChannels();
    for (final session in _radio._sessions.toList()) {
      final pan = _radio._slices[session.slice]?.pan?.toLowerCase();
      if (session._active && pan != null && !_before.contains(pan) && !_made.containsKey(pan)) session._sliceChanged(whole: true);
    }
  }

  void sliceHeard(int index) {
    final status = _radio._slices[index];
    final pan = status?.pan?.toLowerCase();
    if (status == null || status.inUse == false || !_ours(status) || _made[pan] != false) return;
    _made[pan!] = true;
    _radio._sendCommand(
      'slice remove $index',
      onReply: (code, _) {
        if (code != 0) _radio._broadcast((sink) => sink.reportDiagnostic("Flex kept a sweep's slice: 0x${code.toRadixString(16).toUpperCase()}"));
      },
    );
  }

  /// A pan the radio says is gone, the radio telling the client that removed
  /// it too: its id may next be another's.
  void panRemoved(String pan) {
    if (_made.remove(pan) != null) _keep();
  }

  /// The pans an earlier connection left, removed once the radio has brought
  /// back what HaLo's station had: it describes them before it answers the
  /// registration. Their ids may since have gone to other pans, so only one
  /// of this station's with no slice on it is a sweep's.
  void registered() {
    _registered = true;
    for (final pan in _left) {
      final ours = _radio._pans[pan]?['client_handle']?.toLowerCase() == _radio._handle;
      final held = _radio._slices.values.any((slice) => slice.inUse != false && slice.pan?.toLowerCase() == pan);
      if (ours && !held) _radio._sendCommand('display pan remove $pan');
    }
    if (_left.isNotEmpty) {
      _left.clear();
      _keep();
    }
    for (final waiting in _drained()) {
      make(waiting.command, onReply: waiting.onReply);
    }
  }

  /// A station the radio refused makes no pans: each asked for is told so.
  void refused(int code) {
    _refusal = code;
    for (final waiting in _drained()) {
      waiting.onReply?.call(code, '');
    }
  }

  List<({String command, void Function(int code, String body)? onReply})> _drained() {
    final waiting = [..._waiting];
    _waiting.clear();
    return waiting;
  }
}
