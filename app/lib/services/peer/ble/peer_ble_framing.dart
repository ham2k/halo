// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The byte layer of the BLE peer transport (HALO-342): whole `PeerLink`
// messages on one side, MTU-sized GATT packets on the other. Pure Dart on
// purpose — everything protocol-shaped lives here where a unit test can
// reach it, and nothing here knows a plugin exists.
//
// `PeerLink`'s contract makes the transport own framing ("one complete
// message per element"), and ATT gives it a reliable ordered byte stream to
// build on: notifications and writes-without-response are delivered in
// order, without loss, for the life of the connection. The two loss modes
// left are a local stack overrun and a disconnect — the window below
// prevents the first, and the session's own cursors already absorb the
// second.
//
// Wire format, per frame: `magic(1) type(1) length(4 LE) payload`. Against
// a version 2 peer, a MSG larger than the negotiated packet size is split
// into MSGPART frames followed by a final MSG, each one whole inside a
// single packet, so that **no frame the peer can interleave ever splits
// another**. That is the invariant, not an optimization: ACK and PING
// bypass the window and can be queued at any moment, and a frame spliced
// into a half-emitted MSG is read as its payload — the receiver then
// parses the remainder as a header and desyncs, killing a link that was
// working. The reassembler still tolerates a frame arriving across
// packets, which is what the HELLO does (nothing else may be sent until it
// is out) and what a version 1 peer needs (it skips MSGPART as an unknown
// type, so it gets the old spliceable stream — the fault it already has).
//
// The HELLO frame carries each side's view of the usable packet size, and
// both sides send at the MIN of the two views. This is not politeness:
// CoreBluetooth's `maximumWriteValueLength` historically over-reports, and
// an oversized write-without-response is silently truncated — the peer's
// honest number is the only defense. Until the peer's HELLO arrives nothing
// but our own HELLO is sent, sliced at [bleSafeChunk], which every ATT link
// accepts by spec.
//
// Flow control: the plugin completes central→peripheral writes only when
// the stack accepted them, but the peripheral→central notify path has no
// backpressure at all (`updateValue`'s queue-full result is ignored on
// Darwin, and Android never waits for `onNotificationSent`) — so the frame
// layer carries its own credit window. A sender may have [windowBytes] of
// MSG-stream bytes unacknowledged; the receiver ACKs its cumulative count
// every [ackStrideBytes]. ACK counting is byte-granular, not
// frame-granular, so a frame larger than the window still drains instead
// of deadlocking. HELLO and ACK frames bypass the window — a blocked
// window must never block the ACK that would open the peer's.

import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

/// First byte of every frame. A packet stream that stops producing this is
/// desynced, and the only resync is dropping the connection.
const int bleFrameMagic = 0xB7;

const int bleFrameTypeHello = 0x01;

/// This build's protocol version, announced in the HELLO. Version 2 reads
/// and writes MSGPART; version 1 (shipped builds) does not, and is sent the
/// unfragmented stream instead.
const int bleProtocolVersion = 2;

/// A whole message, or the LAST fragment of one — either way, what
/// completes it and hands it up.
const int bleFrameTypeMsg = 0x02;

const int bleFrameTypeAck = 0x03;

/// Keepalive. BLE has no TCP-style death signal — a peer whose app-level
/// link died can leave a GATT connection idling indefinitely — so the link
/// pings and times out on silence. Receivers skip the frame like any
/// unknown type; arrival alone resets their idle clock.
const int bleFrameTypePing = 0x04;

/// A non-final fragment of a message: its payload is appended to the
/// reassembly buffer and nothing is delivered until the closing MSG.
const int bleFrameTypeMsgPart = 0x05;

/// ATT's floor: MTU 23 minus the 3-byte header. Every link accepts this,
/// which is what makes it safe for the HELLO sent before sizes are known.
const int bleSafeChunk = 20;

/// ATT's ceiling (MTU 517 minus header, rounded to the attribute max).
const int bleMaxChunk = 512;

const int _headerBytes = 6;

class BleFrameConduit {
  BleFrameConduit({
    required this.onMessage,
    required this.onSendable,
    required this.onError,
    this.windowBytes = 32 * 1024,
    this.ackStrideBytes = 8 * 1024,
    this.maxMessageBytes = 1024 * 1024,
  });

  /// One complete MSG payload — a whole `PeerLink` message.
  final void Function(Uint8List message) onMessage;

  /// [nextPacket] may now return something after having returned null —
  /// a message was enqueued, an ACK arrived, or the handshake completed.
  /// May fire spuriously; the caller's loop just polls again.
  final void Function() onSendable;

  /// The stream is broken beyond recovery (bad magic, insane length,
  /// malformed HELLO). The caller drops the connection; there is no
  /// in-stream resync.
  final void Function(String problem) onError;

  final int windowBytes;
  final int ackStrideBytes;
  final int maxMessageBytes;

  bool _failed = false;

  // ---- outbound ----

  int? _localChunk;
  int? _peerChunk;

  /// The peer's protocol version, latched from its FIRST hello — absent
  /// means version 1, a build that predates the field and MSGPART with it.
  /// Latched, not re-read: a peer keeps retransmitting its hello until its
  /// own ready, which can outlast ours, and a version that changed under a
  /// half-emitted message would reinterpret the offset (payload-relative
  /// on one branch, frame-relative on the other) and cut the stream mid
  /// header.
  int _peerVersion = 1;

  /// The current message pre-encoded as one spanning frame, for a version 1
  /// peer. Held across packets because that stream is sliced, not framed.
  Uint8List? _legacyFrame;
  Uint8List? _helloFrame;
  int _helloOffset = 0;

  /// ACK frames waiting to go out. Kept apart from the MSG stream because
  /// they bypass the window. Queues (and the running byte counter below)
  /// rather than plain lists: the send path runs per packet on the UI
  /// isolate, and a backed-up queue must not turn every enqueue and
  /// dequeue into a walk or a shift of everything behind it.
  final Queue<Uint8List> _ackQueue = ListQueue();

  /// Messages accepted but not yet fully framed out, held RAW: the frames
  /// are cut at send time, because the packet size they must fit is not
  /// known until the peer's hello lands.
  final Queue<Uint8List> _msgQueue = ListQueue();
  int _msgQueueOffset = 0;
  int _pendingOutboundBytes = 0;

  int _sentMsgBytes = 0;
  int _peerAckedBytes = 0;

  /// The peer confirmed receiving our HELLO (any ACK frame is the
  /// confirmation — one is queued immediately on receiving a hello).
  /// Load-bearing on macOS peripherals: `updateValue` silently DROPS
  /// notifies fired in the first moments after a central subscribes, so
  /// "our hello was handed to the platform" is not "our hello arrived" —
  /// treating it as such strands the far side waiting forever.
  bool _helloAcked = false;

  /// Both HELLOs have crossed AND ours was acknowledged — MSG traffic may
  /// flow, and the link may be handed to a session.
  bool get ready => _helloFrame != null && _helloOffset >= _helloFrame!.length && _peerChunk != null && _helloAcked;

  /// Replays our HELLO from the start. Called on a timer while [ready] is
  /// false: the receiver tolerates duplicate hellos, and retransmission is
  /// the only recovery for a hello the peer's platform ate.
  void resendHello() {
    if (_failed || ready) return;
    final hello = _helloFrame;
    if (hello == null || _helloOffset < hello.length) return;
    _helloOffset = 0;
    onSendable();
  }

  /// The two views behind the effective packet size, for the ready-time log
  /// line — a side that silently fell back to the ATT floor drags BOTH
  /// directions to 20-byte packets, and these are the only evidence.
  int? get localChunkLimit => _localChunk;
  int? get peerChunkLimit => _peerChunk;

  /// The framing the peer announced, for the same log line. A link that
  /// fell back to version 1 carries the spliceable stream, and during a
  /// rollout that is the difference between "the fix did not work" and
  /// "this peer has not shipped it yet".
  int get peerProtocolVersion => _peerVersion;

  /// MSG-stream bytes accepted but not yet emitted as packets — the link's
  /// stuck-peer cap reads this before every send.
  int get pendingOutboundBytes => _pendingOutboundBytes;

  /// Starts the handshake. [chunkLimit] is this side's view of the largest
  /// packet the link carries — from the negotiated MTU, clamped to sane
  /// bounds here so a lying platform value cannot pick 0 or 4096.
  void sendHello(int chunkLimit) {
    if (_helloFrame != null || _failed) return;
    _localChunk = chunkLimit.clamp(bleSafeChunk, bleMaxChunk);
    final payload = utf8.encode(jsonEncode({'v': bleProtocolVersion, 'chunk': _localChunk}));
    _helloFrame = _encodeFrame(bleFrameTypeHello, payload);
    onSendable();
  }

  /// Accepts one whole message for the MSG stream. Never throws — a message
  /// over [maxMessageBytes] is a caller bug reported through [onError],
  /// because nothing at the receiving end could accept it either.
  void enqueueMessage(List<int> message) {
    if (_failed) return;
    if (message.length > maxMessageBytes) {
      _fail('outbound message of ${message.length} bytes exceeds the $maxMessageBytes cap');
      return;
    }
    final copy = Uint8List.fromList(message);
    _msgQueue.add(copy);
    _pendingOutboundBytes += copy.length;
    onSendable();
  }

  /// Queues a keepalive frame. Rides the ACK queue: it bypasses the window
  /// (a blocked window is exactly when proof-of-life matters most) and is
  /// held with everything else until the handshake completes.
  void sendPing() {
    if (_failed) return;
    _ackQueue.add(_encodeFrame(bleFrameTypePing, const []));
    onSendable();
  }

  /// The next packet to put on the air, or null when nothing may be sent —
  /// the queues are empty, the handshake is incomplete, or the window is
  /// closed. The caller sends packets strictly in the order handed out.
  Uint8List? nextPacket() {
    if (_failed) return null;
    final hello = _helloFrame;
    if (hello == null) return null;

    // The HELLO goes first, whole, at the always-safe size — the peer's
    // receive capacity is exactly what it is about to tell us.
    if (_helloOffset < hello.length) {
      final end = (_helloOffset + bleSafeChunk).clamp(0, hello.length);
      final packet = Uint8List.sublistView(hello, _helloOffset, end);
      _helloOffset = end;
      return packet;
    }

    final peerChunk = _peerChunk;
    if (peerChunk == null) return null;
    final chunk = _localChunk! < peerChunk ? _localChunk! : peerChunk;

    if (_ackQueue.isNotEmpty) return _ackQueue.removeFirst();

    // MSG only once fully ready — not merely once sizes are known. This is
    // what makes a hello replay structurally unable to splice into a
    // half-emitted MSG frame: no MSG bytes exist before ready, and ready is
    // monotonic, after which resendHello never fires again.
    if (!ready) return null;
    if (_msgQueue.isEmpty) return null;
    if (_sentMsgBytes - _peerAckedBytes >= windowBytes) return null;
    final message = _msgQueue.first;
    final Uint8List packet;
    final bool isLast;
    if (_peerVersion >= 2) {
      // One frame per packet, header and all: a fragment that spilled into
      // the next packet would let the ACK above split it. The floor chunk
      // of 20 still leaves 14 payload bytes, so this always advances.
      final end = (_msgQueueOffset + chunk - _headerBytes).clamp(0, message.length);
      isLast = end >= message.length;
      packet = _encodeFrame(isLast ? bleFrameTypeMsg : bleFrameTypeMsgPart, Uint8List.sublistView(message, _msgQueueOffset, end));
      _pendingOutboundBytes -= end - _msgQueueOffset;
      _msgQueueOffset = end;
    } else {
      // Version 1: one frame sliced across packets, which an ACK can split.
      // The peer cannot parse fragments, so this is the only stream it
      // takes — and it is no worse than what it does with its own builds.
      final frame = _legacyFrame ??= _encodeFrame(bleFrameTypeMsg, message);
      final end = (_msgQueueOffset + chunk).clamp(0, frame.length);
      isLast = end >= frame.length;
      packet = Uint8List.sublistView(frame, _msgQueueOffset, end);
      // Payload bytes only: the counter tracks messages accepted but not
      // yet on the air, and the header is not part of the message.
      _pendingOutboundBytes -= (end - _headerBytes).clamp(0, message.length) - (_msgQueueOffset - _headerBytes).clamp(0, message.length);
      _msgQueueOffset = end;
    }
    if (isLast) {
      _msgQueue.removeFirst();
      _msgQueueOffset = 0;
      _legacyFrame = null;
    }
    _sentMsgBytes += packet.length;
    return packet;
  }

  // ---- inbound ----

  final BytesBuilder _inBuffer = BytesBuilder(copy: true);
  int _inOffset = 0;
  int? _pendingType;
  int _pendingLength = 0;
  final BytesBuilder _pendingPayload = BytesBuilder(copy: true);

  /// Fragments of the message being reassembled — MSGPART payloads waiting
  /// for the MSG that closes them.
  final BytesBuilder _messageBuffer = BytesBuilder(copy: true);

  int _recvMsgBytes = 0;
  int _lastAckedBytes = 0;

  static bool _isMsgFrame(int type) => type == bleFrameTypeMsg || type == bleFrameTypeMsgPart;

  /// Feeds one received packet (a notification or a write) into the
  /// reassembler.
  void feed(Uint8List packet) {
    if (_failed) return;
    _inBuffer.add(packet);
    _drain();
  }

  void _drain() {
    var bytes = _inBuffer.toBytes();
    while (!_failed) {
      if (_pendingType == null) {
        if (bytes.length - _inOffset < _headerBytes) break;
        if (bytes[_inOffset] != bleFrameMagic) {
          _fail('stream desync (magic 0x${bytes[_inOffset].toRadixString(16)})');
          return;
        }
        final type = bytes[_inOffset + 1];
        final length = bytes[_inOffset + 2] | (bytes[_inOffset + 3] << 8) | (bytes[_inOffset + 4] << 16) | (bytes[_inOffset + 5] << 24);
        if (length < 0 || length > maxMessageBytes) {
          _fail('frame length $length exceeds the $maxMessageBytes cap');
          return;
        }
        // The cap covers the REASSEMBLED message, not just this fragment:
        // a peer sending MSGPARTs and never closing them would otherwise
        // grow the buffer without bound, each frame legal on its own.
        if (_isMsgFrame(type) && _messageBuffer.length + length > maxMessageBytes) {
          _fail('reassembled message exceeds the $maxMessageBytes cap');
          return;
        }
        _inOffset += _headerBytes;
        _pendingType = type;
        _pendingLength = length;
        if (_isMsgFrame(type)) _recvMsgBytes += _headerBytes;
      } else {
        final want = _pendingLength - _pendingPayload.length;
        final available = bytes.length - _inOffset;
        final take = want < available ? want : available;
        if (take > 0) {
          _pendingPayload.add(Uint8List.sublistView(bytes, _inOffset, _inOffset + take));
          _inOffset += take;
          if (_isMsgFrame(_pendingType!)) _recvMsgBytes += take;
        }
        if (_pendingPayload.length < _pendingLength) break;
        final payload = _pendingPayload.takeBytes();
        final type = _pendingType!;
        _pendingType = null;
        _pendingLength = 0;
        _dispatch(type, payload);
      }
    }
    _maybeAck();
    // Compact: everything before _inOffset is consumed. Rebuilding the
    // buffer per feed keeps the parser O(bytes), not O(bytes²).
    if (_inOffset > 0) {
      final remainder = Uint8List.sublistView(_inBuffer.takeBytes(), _inOffset);
      _inOffset = 0;
      if (remainder.isNotEmpty) _inBuffer.add(remainder);
    }
  }

  void _dispatch(int type, Uint8List payload) {
    switch (type) {
      case bleFrameTypeHello:
        final int? chunk;
        final int version;
        try {
          final decoded = jsonDecode(utf8.decode(payload));
          final hello = decoded is Map<String, dynamic> ? decoded : null;
          chunk = (hello?['chunk'] as num?)?.toInt();
          version = (hello?['v'] as num?)?.toInt() ?? 1;
        } catch (_) {
          _fail('malformed hello');
          return;
        }
        if (chunk == null) {
          _fail('hello carries no chunk size');
          return;
        }
        if (_peerChunk == null) _peerVersion = version;
        _peerChunk = chunk.clamp(bleSafeChunk, bleMaxChunk);
        // Every hello — including a retransmitted duplicate — is answered
        // with an ACK carrying the current count: the ACK is the sender's
        // only proof its hello survived the radio, and the answer itself
        // can be eaten by the same drop window, so each retry earns a
        // fresh one.
        final ackPayload = ByteData(8)
          ..setUint32(0, _recvMsgBytes % 0x100000000, Endian.little)
          ..setUint32(4, _recvMsgBytes ~/ 0x100000000, Endian.little);
        _ackQueue.add(_encodeFrame(bleFrameTypeAck, ackPayload.buffer.asUint8List()));
        onSendable();
      case bleFrameTypeAck:
        if (payload.length < 8) return; // short ack: ignore, the next one carries the count
        // ANY ack, whatever it counts, proves the peer heard our hello —
        // the hello-ack carries 0, which the cumulative guard below
        // rightly ignores for the window.
        final wasAcked = _helloAcked;
        _helloAcked = true;
        if (!wasAcked) onSendable();
        // Two 32-bit halves, joined by multiplication: Uint64 accessors are
        // unsupported under dart2js, and shifts past 32 bits wrap there —
        // this compiles into the web build even though BLE never runs on it.
        final data = ByteData.sublistView(payload);
        final acked = data.getUint32(0, Endian.little) + data.getUint32(4, Endian.little) * 0x100000000;
        // Cumulative — an ACK overtaken in our own queue must not move the
        // window backwards.
        if (acked > _peerAckedBytes) {
          _peerAckedBytes = acked;
          onSendable();
        }
      case bleFrameTypeMsgPart:
        _messageBuffer.add(payload);
      case bleFrameTypeMsg:
        if (_messageBuffer.isEmpty) {
          onMessage(payload);
        } else {
          _messageBuffer.add(payload);
          onMessage(_messageBuffer.takeBytes());
        }
      default:
        // Unknown type from a newer build: skipping the frame whole is the
        // forward-compatible move; failing would make any addition a
        // version bump.
        break;
    }
  }

  void _maybeAck() {
    if (_recvMsgBytes - _lastAckedBytes < ackStrideBytes) return;
    _lastAckedBytes = _recvMsgBytes;
    // Split with %/~/ rather than masks or shifts — see the decode side.
    final payload = ByteData(8)
      ..setUint32(0, _recvMsgBytes % 0x100000000, Endian.little)
      ..setUint32(4, _recvMsgBytes ~/ 0x100000000, Endian.little);
    _ackQueue.add(_encodeFrame(bleFrameTypeAck, payload.buffer.asUint8List()));
    onSendable();
  }

  void _fail(String problem) {
    if (_failed) return;
    _failed = true;
    onError(problem);
  }

  static Uint8List _encodeFrame(int type, List<int> payload) {
    final frame = Uint8List(_headerBytes + payload.length);
    frame[0] = bleFrameMagic;
    frame[1] = type;
    frame[2] = payload.length & 0xFF;
    frame[3] = (payload.length >> 8) & 0xFF;
    frame[4] = (payload.length >> 16) & 0xFF;
    frame[5] = (payload.length >> 24) & 0xFF;
    frame.setRange(_headerBytes, frame.length, payload);
    return frame;
  }
}
