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
// Wire format, per frame: `magic(1) type(1) length(4 LE) payload`, the
// stream sliced into packets of at most the negotiated chunk size. Frames
// need not align to packets.
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
const int bleFrameTypeMsg = 0x02;
const int bleFrameTypeAck = 0x03;

/// Keepalive. BLE has no TCP-style death signal — a peer whose app-level
/// link died can leave a GATT connection idling indefinitely — so the link
/// pings and times out on silence. Receivers skip the frame like any
/// unknown type; arrival alone resets their idle clock.
const int bleFrameTypePing = 0x04;

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
  Uint8List? _helloFrame;
  int _helloOffset = 0;

  /// ACK frames waiting to go out. Kept apart from the MSG stream because
  /// they bypass the window. Queues (and the running byte counter below)
  /// rather than plain lists: the send path runs per packet on the UI
  /// isolate, and a backed-up queue must not turn every enqueue and
  /// dequeue into a walk or a shift of everything behind it.
  final Queue<Uint8List> _ackQueue = ListQueue();

  /// The MSG frame stream: encoded frames not yet fully emitted.
  final Queue<Uint8List> _msgQueue = ListQueue();
  int _msgQueueOffset = 0;
  int _pendingOutboundBytes = 0;

  int _sentMsgBytes = 0;
  int _peerAckedBytes = 0;

  /// Both HELLOs have crossed — MSG traffic may flow.
  bool get ready => _helloFrame != null && _helloOffset >= _helloFrame!.length && _peerChunk != null;

  /// The two views behind the effective packet size, for the ready-time log
  /// line — a side that silently fell back to the ATT floor drags BOTH
  /// directions to 20-byte packets, and these are the only evidence.
  int? get localChunkLimit => _localChunk;
  int? get peerChunkLimit => _peerChunk;

  /// MSG-stream bytes accepted but not yet emitted as packets — the link's
  /// stuck-peer cap reads this before every send.
  int get pendingOutboundBytes => _pendingOutboundBytes;

  /// Starts the handshake. [chunkLimit] is this side's view of the largest
  /// packet the link carries — from the negotiated MTU, clamped to sane
  /// bounds here so a lying platform value cannot pick 0 or 4096.
  void sendHello(int chunkLimit) {
    if (_helloFrame != null || _failed) return;
    _localChunk = chunkLimit.clamp(bleSafeChunk, bleMaxChunk);
    final payload = utf8.encode(jsonEncode({'v': 1, 'chunk': _localChunk}));
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
    final frame = _encodeFrame(bleFrameTypeMsg, message);
    _msgQueue.add(frame);
    _pendingOutboundBytes += frame.length;
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

    if (_msgQueue.isEmpty) return null;
    if (_sentMsgBytes - _peerAckedBytes >= windowBytes) return null;
    final frame = _msgQueue.first;
    final end = (_msgQueueOffset + chunk).clamp(0, frame.length);
    final packet = Uint8List.sublistView(frame, _msgQueueOffset, end);
    _msgQueueOffset = end;
    if (_msgQueueOffset >= frame.length) {
      _msgQueue.removeFirst();
      _msgQueueOffset = 0;
    }
    _sentMsgBytes += packet.length;
    _pendingOutboundBytes -= packet.length;
    return packet;
  }

  // ---- inbound ----

  final BytesBuilder _inBuffer = BytesBuilder(copy: true);
  int _inOffset = 0;
  int? _pendingType;
  int _pendingLength = 0;
  final BytesBuilder _pendingPayload = BytesBuilder(copy: true);

  int _recvMsgBytes = 0;
  int _lastAckedBytes = 0;

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
        final length = bytes[_inOffset + 2] |
            (bytes[_inOffset + 3] << 8) |
            (bytes[_inOffset + 4] << 16) |
            (bytes[_inOffset + 5] << 24);
        if (length < 0 || length > maxMessageBytes) {
          _fail('frame length $length exceeds the $maxMessageBytes cap');
          return;
        }
        _inOffset += _headerBytes;
        _pendingType = type;
        _pendingLength = length;
        if (type == bleFrameTypeMsg) _recvMsgBytes += _headerBytes;
      } else {
        final want = _pendingLength - _pendingPayload.length;
        final available = bytes.length - _inOffset;
        final take = want < available ? want : available;
        if (take > 0) {
          _pendingPayload.add(Uint8List.sublistView(bytes, _inOffset, _inOffset + take));
          _inOffset += take;
          if (_pendingType == bleFrameTypeMsg) _recvMsgBytes += take;
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
        try {
          final decoded = jsonDecode(utf8.decode(payload));
          chunk = decoded is Map<String, dynamic> ? (decoded['chunk'] as num?)?.toInt() : null;
        } catch (_) {
          _fail('malformed hello');
          return;
        }
        if (chunk == null) {
          _fail('hello carries no chunk size');
          return;
        }
        final hadPeer = _peerChunk != null;
        _peerChunk = chunk.clamp(bleSafeChunk, bleMaxChunk);
        if (!hadPeer) onSendable();
      case bleFrameTypeAck:
        if (payload.length < 8) return; // short ack: ignore, the next one carries the count
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
      case bleFrameTypeMsg:
        onMessage(payload);
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
