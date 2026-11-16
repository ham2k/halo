// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A FlexRadio slice's receive audio, carried by the audio engine to the
// operator's ears — docs/design/audio.md § 6.
//
// Captured on a FLEX-6600 (4.3.16) with AetherSDR as the GUI client: a bound
// client's `stream create type=dax_rx dax_channel=<n>` answers with the
// stream's id, the radio sends that slice's audio to the client's `udpport`
// as VITA-49 type 3, and `stream remove <id>` ends it. The engine's socket
// claims the stream (halo_audio_net.c) and nothing of it passes through
// Dart. What happens here is the control: which DAX channel, the stream's
// life, and the route.

import 'package:halo_audio/halo_audio.dart' show AudioEndpoint, AudioSocket, HaloAudioException;
import 'package:halo_i18n/halo_i18n.dart';

import '../driver.dart' show RadioAudioLink;

/// The DAX channels a FlexRadio offers a slice.
const flexDaxChannels = [1, 2, 3, 4, 5, 6, 7, 8];

class FlexDaxReceive {
  FlexDaxReceive({required this.link, required this.slice, required this.send, required this.diagnose, this.problem});

  final RadioAudioLink link;
  final int slice;

  /// A command to the radio; [onReply] gets the answer's code and body.
  final void Function(String command, {void Function(int code, String body)? onReply}) send;

  /// Why the slice is not heard, for the CAT recording.
  final void Function(String what) diagnose;

  /// Why the slice is not heard, for the operator, on the radio's row; null
  /// once it is.
  final void Function(String? why)? problem;

  int? _streamId;
  int? _channel;

  /// The channel asked for and not yet answered.
  int? _asking;

  /// The DAX channel this stream holds or has asked for: one no other slice
  /// may be given while it does.
  int? get claimed => _channel ?? _asking;
  AudioEndpoint? _endpoint;
  bool _pending = false;
  bool _stopped = false;
  bool _gaveUp = false;

  /// Whether this put the slice on DAX, and so takes it off again.
  bool _assigned = false;

  /// Called whenever something it waits on changes: the engine's [socket]
  /// (null for one the engine does not own), whether the session has [bound]
  /// to the GUI client, the slice's DAX channel as the radio last stated it
  /// (0 for none, null before it has), and the channels [taken] by the
  /// radio's other slices.
  void update({required AudioSocket? socket, required bool bound, required int? daxChannel, required Set<int> taken}) {
    if (_stopped || _gaveUp || _pending || socket == null || !bound || daxChannel == null) return;
    if (_streamId != null) {
      if (daxChannel == _channel) return;
      _close();
      if (daxChannel == 0) {
        // Taken off DAX on the radio: the operator's choice, not to be undone.
        _assigned = false;
        _gaveUp = true;
        diagnose('the slice was taken off DAX');
        return;
      }
    }
    if (daxChannel != 0) return _create(socket, daxChannel);
    // A slice that is not on DAX gets a channel no other slice holds, and
    // gives it back when this stops. The radio's status does not always
    // echo a change to the client that made it, so the stream follows the
    // answer, not a status.
    final free = flexDaxChannels.where((c) => !taken.contains(c)).firstOrNull;
    if (free == null) {
      _gaveUp = true;
      diagnose('every DAX channel is taken');
      problem?.call(t.settings.station.audioProblemDaxChannels);
      return;
    }
    _pending = true;
    _asking = free;
    send(
      'slice set $slice dax=$free',
      onReply: (code, body) {
        _pending = false;
        _asking = null;
        if (_stopped) return;
        if (code != 0) return _refused('slice set dax=$free', code, body);
        _assigned = true;
        _create(socket, free);
      },
    );
  }

  void _create(AudioSocket socket, int channel) {
    _pending = true;
    _channel = channel;
    send(
      'stream create type=dax_rx dax_channel=$channel',
      onReply: (code, body) {
        _pending = false;
        final id = int.tryParse(body.trim().replaceFirst('0x', ''), radix: 16);
        if (_stopped) {
          if (code == 0 && id != null) send('stream remove ${_hex(id)}');
          return;
        }
        if (code != 0 || id == null) return _refused('stream create type=dax_rx', code, body);
        _streamId = id;
        final AudioEndpoint endpoint;
        try {
          endpoint = _endpoint = link.engine.addFlexDaxRx(socket, id);
        } on HaloAudioException catch (e) {
          // No room on the socket for another stream: held on the radio
          // with nothing to hear it, it would never be asked for again.
          diagnose('the engine would not take the stream: ${e.message}');
          problem?.call(t.settings.station.audioProblemEngine);
          _close();
          _gaveUp = true;
          return;
        }
        final heard = link.hear(
          endpoint,
          why: (why) {
            diagnose(why);
            problem?.call(why);
          },
        );
        if (heard == null) {
          _close();
          _gaveUp = true;
        } else {
          problem?.call(null);
        }
      },
    );
  }

  void _refused(String command, int code, String body) {
    _gaveUp = true;
    problem?.call(t.settings.station.audioProblemStream);
    diagnose('$command refused: ${code.toRadixString(16).padLeft(8, '0')} ${body.trim()}'.trim());
  }

  void _close() {
    _endpoint?.close();
    _endpoint = null;
    if (_streamId case final id?) send('stream remove ${_hex(id)}');
    _streamId = null;
    _channel = null;
  }

  /// Ends the stream and the route, and takes the slice off DAX if this put
  /// it there. Safe to call more than once.
  void stop() {
    if (_stopped) return;
    _stopped = true;
    _close();
    if (_assigned) send('slice set $slice dax=0');
    _assigned = false;
  }

  static String _hex(int id) => '0x${id.toRadixString(16).padLeft(8, '0')}';
}
