// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Icom's network CAT protocol — how an IC-705 exposes CI-V over WiFi, and
// what the RS-BA1 software speaks. Pure: builders and parsers, no sockets.
//
// PROVENANCE. Packet layouts originate with kappanhang
// (https://github.com/nonoo/kappanhang), MIT, © 2020 Norbert Varga HA2NON
// and Akos Marton ES1AKOS, via app-polo's MPL-2.0 port. The corrections
// below were established by observing the WIRE — capturing the traffic a
// working client exchanges with the radio, which is a fact about the radio
// and not anyone's copyrightable expression. wfview's SOURCE was not read
// and must not be: it is GPLv3 and this codebase is MPL-2.0.
//
// Five things app-polo got wrong here, each of which cost it the feature:
//
//   1. The 0x90 stream request must name OUR OWN local ports, not
//      50002/50003. polo sent the radio's own port numbers back at it,
//      which told the radio to send CI-V to itself — the whole of the
//      "serial stream alive, no payload" symptom.
//   2. The audio fields cannot be zeroed. A real bound port and a real
//      sample rate are required or the radio rejects the request, answering
//      0x50 with 0xffff at offset 56 instead of echoing its ports.
//   3. The answer to that request is an 0x50, not a 0x90. The radio sends a
//      0x90 too, but afterwards and unprompted.
//   4. The CI-V controller address on the network side is 0xE1, not the
//      0xE0 a PC conventionally uses on a wire.
//   5. The serial-open magic byte is 0x04, not 0x05.
//
// And the session-release bug that made polo's attempt look random: a 0x40
// auth packet with magic 0x01 — a LOGOUT — must go out before the
// disconnect, or the radio keeps the login alive and refuses every later
// one. polo built a disconnect it never called and had no logout at all.


/// The three UDP ports the radio listens on. Audio is never read; a socket
/// is bound for it only because the stream request must name a real port.
const icomControlPort = 50001;
const icomSerialPort = 50002;
const icomAudioPort = 50003;

const icomDeviceId = 'icom-pc';

/// The controller address the radio answers on the NETWORK side.
const icomNetworkControllerAddress = 0xE1;

/// Opens the serial stream. Established from a capture; polo used 0x05.
const icomSerialOpenMagic = 0x04;

/// Rejecting a zeroed audio request, the radio wants a real rate.
const icomAudioSampleRate = 48000;
const icomTxBufferMs = 150;

const _substitutionTable = <int, int>{
  32: 0x47, 33: 0x5d, 34: 0x4c, 35: 0x42, 36: 0x66, 37: 0x20, 38: 0x23, 39: 0x46,
  40: 0x4e, 41: 0x57, 42: 0x45, 43: 0x3d, 44: 0x67, 45: 0x76, 46: 0x60, 47: 0x41,
  48: 0x62, 49: 0x39, 50: 0x59, 51: 0x2d, 52: 0x68, 53: 0x7e, 54: 0x7c, 55: 0x65,
  56: 0x7d, 57: 0x49, 58: 0x29, 59: 0x72, 60: 0x73, 61: 0x78, 62: 0x21, 63: 0x6e,
  64: 0x5a, 65: 0x5e, 66: 0x4a, 67: 0x3e, 68: 0x71, 69: 0x2c, 70: 0x2a, 71: 0x54,
  72: 0x3c, 73: 0x3a, 74: 0x63, 75: 0x4f, 76: 0x43, 77: 0x75, 78: 0x27, 79: 0x79,
  80: 0x5b, 81: 0x35, 82: 0x70, 83: 0x48, 84: 0x6b, 85: 0x56, 86: 0x6f, 87: 0x34,
  88: 0x32, 89: 0x6c, 90: 0x30, 91: 0x61, 92: 0x6d, 93: 0x7b, 94: 0x2f, 95: 0x4b,
  96: 0x64, 97: 0x38, 98: 0x2b, 99: 0x2e, 100: 0x50, 101: 0x40, 102: 0x3f, 103: 0x55,
  104: 0x33, 105: 0x37, 106: 0x25, 107: 0x77, 108: 0x24, 109: 0x26, 110: 0x74, 111: 0x6a,
  112: 0x28, 113: 0x53, 114: 0x4d, 115: 0x69, 116: 0x22, 117: 0x5c, 118: 0x44, 119: 0x31,
  120: 0x36, 121: 0x58, 122: 0x3b, 123: 0x7a, 124: 0x51, 125: 0x5f, 126: 0x52,
};

List<int> passcode(String text) {
  final out = List<int>.filled(16, 0);
  for (var i = 0; i < text.length && i < out.length; i++) {
    var p = text.codeUnitAt(i) + i;
    if (p > 126) p = 32 + (p % 127);
    out[i] = _substitutionTable[p] ?? 0;
  }
  return out;
}

List<int> be32(int n) => [(n >> 24) & 0xFF, (n >> 16) & 0xFF, (n >> 8) & 0xFF, n & 0xFF];
List<int> le16(int n) => [n & 0xFF, (n >> 8) & 0xFF];
List<int> le32(int n) => [n & 0xFF, (n >> 8) & 0xFF, (n >> 16) & 0xFF, (n >> 24) & 0xFF];
int readBe32(List<int> b, int o) =>
    ((b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3]) & 0xFFFFFFFF;
List<int> zeros(int n) => List<int>.filled(n, 0);

/// Whether [bytes] begins with [prefix] — how every packet type is
/// recognised, since the type lives in the first few header bytes.
bool icomPrefixIs(List<int> bytes, List<int> prefix) {
  if (bytes.length < prefix.length) return false;
  for (var i = 0; i < prefix.length; i++) {
    if (bytes[i] != prefix[i]) return false;
  }
  return true;
}

List<int> buildPkt3(int local, int remote) =>
    [0x10, 0, 0, 0, 0x03, 0, 0, 0, ...be32(local), ...be32(remote)];

List<int> buildPkt6(int local, int remote) =>
    [0x10, 0, 0, 0, 0x06, 0, 0x01, 0, ...be32(local), ...be32(remote)];

List<int> buildIdle(int local, int remote, int seq) =>
    [0x10, 0, 0, 0, 0, 0, ...le16(seq), ...be32(local), ...be32(remote)];

List<int> buildDisconnect(int local, int remote) =>
    [0x10, 0, 0, 0, 0x05, 0, 0, 0, ...be32(local), ...be32(remote)];

/// Our own outgoing ping. polo only ever built the *reply* to the radio's.
List<int> buildPing(int local, int remote, int seq, List<int> payload) =>
    [0x15, 0, 0, 0, 0x07, 0, ...le16(seq), ...be32(local), ...be32(remote), 0x00, ...payload];

List<int> buildPingReply(int local, int remote, int seq, List<int> payload) =>
    [0x15, 0, 0, 0, 0x07, 0, ...le16(seq), ...be32(local), ...be32(remote), 0x01, ...payload];

List<int> buildLogin({
  required int local,
  required int remote,
  required int innerSeq,
  required List<int> authStartId,
  required String username,
  required String password,
}) =>
    [
      0x80, 0, 0, 0, 0, 0, 0, 0,
      ...be32(local), ...be32(remote),
      0, 0, 0, 0x70, 0x01, 0, 0, ...le16(innerSeq), 0,
      authStartId[0], authStartId[1],
      ...zeros(4),
      ...zeros(32),
      ...passcode(username),
      ...passcode(password),
      ...icomDeviceId.codeUnits, 0,
      ...zeros(24),
    ];

List<int> buildAuth({
  required int local,
  required int remote,
  required int innerSeq,
  required int magic,
  required List<int> authId,
}) =>
    [
      0x40, 0, 0, 0, 0, 0, 0, 0,
      ...be32(local), ...be32(remote),
      0, 0, 0, 0x30, 0x01, magic, 0, ...le16(innerSeq), 0,
      ...authId,
      ...zeros(32),
    ];

/// [ourSerialPort] and [ourAudioPort] are the ports the RADIO should send
/// those streams to — i.e. the local ports our own sockets are bound to.
///
/// This is what a wfview capture settled: it names its own ephemeral ports
/// here (0xe2ed, 0xe0be), not 50002/50003. app-polo sent the radio's own
/// port numbers back at it, which told the radio to send CI-V to itself —
/// exactly the "serial stream alive, no payload" symptom both it and this
/// spike hit.
List<int> buildRequestStreams({
  required int local,
  required int remote,
  required int innerSeq,
  required List<int> authId,
  required List<int> a8ReplyId,
  required String username,
  required int ourSerialPort,
  required int ourAudioPort,
  required int audioSampleRate,
  required int txBufferMs,
  String deviceName = 'IC-705',
}) {
  final name = deviceName.codeUnits;
  return [
    0x90, 0, 0, 0, 0, 0, 0, 0,
    ...be32(local), ...be32(remote),
    0, 0, 0, 0x80, 0x01, 0x03, 0, ...le16(innerSeq), 0,
    ...authId,
    ...a8ReplyId,
    ...zeros(16),
    ...name, ...zeros(8 - name.length),
    ...zeros(24),
    ...passcode(username),
    0x01, 0x01, 0x04, 0x04,
    0, 0, (audioSampleRate >> 8) & 0xFF, audioSampleRate & 0xFF,
    0, 0, (audioSampleRate >> 8) & 0xFF, audioSampleRate & 0xFF,
    0, 0, (ourSerialPort >> 8) & 0xFF, ourSerialPort & 0xFF,
    0, 0, (ourAudioPort >> 8) & 0xFF, ourAudioPort & 0xFF, 0, 0,
    (txBufferMs >> 8) & 0xFF, txBufferMs & 0xFF, 0x01, 0, 0, 0, 0, 0, 0, 0,
  ];
}

/// The last byte is the "magic" that opens the stream. app-polo's removal
/// commit credits a WRONG one as a bug it found on hardware and then lost
/// with the deletion, so it is swept rather than assumed.
List<int> buildSerialOpen(int local, int remote, int innerSeq, {int magic = 0x05}) => [
      0x16, 0, 0, 0, 0, 0, 0, 0,
      ...be32(local), ...be32(remote),
      0xc0, 0x01, 0, (innerSeq >> 8) & 0xFF, innerSeq & 0xFF, magic,
    ];

/// The datagram length is a full LE32 and the CI-V length an LE16; both used
/// to be written as a single byte with the high bytes hardcoded to zero. That
/// is byte-identical for every frame we send today — the driver's longest is
/// about 11 bytes — and silently corrupts the first frame past 234 (a 0x1A 05
/// settings block, memory contents), which would land as a wrong length the
/// radio cannot parse. Fixed while it costs nothing rather than when it does.
List<int> buildCivData(int local, int remote, int innerSeq, List<int> civ) => [
      ...le32(0x15 + civ.length),
      0, 0, 0, 0,
      ...be32(local), ...be32(remote),
      0xc1, ...le16(civ.length), (innerSeq >> 8) & 0xFF, innerSeq & 0xFF,
      ...civ,
    ];

bool isCivData(List<int> b) => b.length >= 22 && b[16] == 0xc1 && ((b[0] - 0x15) & 0xFF) == b[17];
List<int> unwrapCiv(List<int> b) => b.sublist(21);

/// The radio refusing to open the streams we asked for.
///
/// The 0x50 answer echoes the two stream ports at offsets 66 and 70 — an
/// accepted answer reads 0xc352 (50002) and 0xc353 (50003) there. Offsets
/// 56..57, which this used to read, are constant zero in an accepted answer,
/// so the old guard could never fire and a refusal passed as success.
bool isStreamRefused(List<int> b) =>
    b.length >= 72 &&
    ((b[66] == 0xff && b[67] == 0xff) || (b[70] == 0xff && b[71] == 0xff));

/// The radio's answer to our login.
///
/// Six bytes of prefix, NOT eight. Bytes 6..7 are the sender's outer sequence
/// number, and on a radio->client packet that is the RADIO's monotonic counter.
/// Pinning it to 0x0001 held only while the radio answered the login before
/// its first idle; every login answer in the reference capture arrives as
/// 0x0002. Length 96 plus the type identifies the packet uniquely, so the
/// sequence field adds no discrimination and only fragility.
/// See docs/design/ic705-teardown.md.
bool isLoginAnswer(List<int> b) => b.length == 96 && icomPrefixIs(b, [0x60, 0, 0, 0, 0, 0]);

/// The radio confirming it released our login.
///
/// Same 64-byte auth shape we send to *ask* for the logout — the reply is
/// distinguished only by `0x02` at offset 20 where the request carries `0x01`.
/// Both directions are otherwise identical, so a predicate that ignores byte
/// 20 would match our own outgoing packet. See docs/design/ic705-teardown.md.
bool isLogoutAck(List<int> b) =>
    b.length == 64 && icomPrefixIs(b, [0x40, 0, 0, 0, 0, 0]) && b[20] == 0x02;
