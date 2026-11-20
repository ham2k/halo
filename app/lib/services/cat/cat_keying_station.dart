// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What keying asks of the station it runs on: the seam between CatKeying
// and the service that holds the sessions, nodes and picks.

part of 'cat_keying.dart';

/// What keying needs of the station it runs on — the equipment half of
/// `CatService`, which is where sessions, nodes and the picks live.
///
/// A seam rather than the service itself, for the reason the file exists:
/// keying is a self-contained thing that happens to need a session, and a
/// class that could reach into the registry would grow back into it.
abstract class KeyingStation {
  /// The key in use, as a node uuid — [kCategoryKey]'s designation. Null for
  /// None, and null for a peer's own keying, which is not a node here to
  /// name ([peerKeyIsInUse]).
  String? get keyInUse;

  /// Whether what keys for the radio in use is the PEER's own key: its radio
  /// fills radio1, and this operator either never chose a key for it or
  /// chose that radio itself. An explicit None means None — a default does
  /// not outrank an answer.
  bool get peerKeyIsInUse;

  /// Which radio a keying request is addressed to, or null when radio1 is
  /// not a peer's radio.
  String? get peerRadioId;

  /// Whether [node] is a key or a radio whose CAT keys.
  bool isKeyerNode(EquipmentNode node);

  /// Whether the key in use is the other SO2R set's key in use too, as one
  /// an SO2R box sends to either radio is: what it keys is one set's
  /// message at a time, the set that sent it.
  bool get keyInUseShared;

  /// Whether the key in use is shared ([keyInUseShared]) with nothing to
  /// send it to this set's radio: the box is not connected, and its output
  /// would go wherever the box's focus last was.
  bool get keyInUseUnrouted;

  /// The keyer whose message [uuid], a key, is keying: the one that last
  /// handed it one, until that message ends. One record for both sets, so
  /// a message is never both sets' or neither's.
  CatKeying? cwSenderOn(String uuid);
  void noteCwSender(String uuid, CatKeying? keyer);

  /// Whether what [uuid] keys is [keyer]'s: the message [keyer] sent it, or,
  /// sent from nowhere here, the message of a key no other set keys
  /// through. The one rule every progress report, stop and change of key
  /// asks.
  bool ownsCwOn(CatKeying keyer, String uuid);

  List<EquipmentNode> get nodes;
  EquipmentNode? nodeFor(String uuid);
  EquipmentType? typeFor(EquipmentNode node);
  EquipmentState stateFor(String uuid);

  /// Physical device identity for logical radios sharing one transmitter.
  /// Null for independent radios, whose node UUID is their identity.
  String? logicalDeviceIdFor(String uuid);

  /// [uuid]'s session, but only while that node is connected — a keyer that
  /// dropped answers null rather than throwing at whatever is keyed into it.
  EquipmentSession? connectedSession(String uuid);

  /// The local rig this keyer keys: radio1 when it is a rig of this
  /// station's own — or, for SO2R's second keyer, Radio B — and null when
  /// radio1 is a peer's or none: the memories are audio in the transceiver,
  /// and there is nothing local to play when the transceiver is somewhere
  /// else.
  String? get localKeyingRadio;

  /// SO2R's turn-taking (docs/design/cat.md § Radio B, for SO2R): whether
  /// this keyer may go on the air now. False holds the send ([CatKeying.waiting])
  /// until the other radio is quiet. [repeat] is a repeat chain's own send,
  /// which always waits its turn; an operator's may instead stop the other
  /// radio, which this does before answering true. Always true for a station
  /// with one radio.
  /// [queuedCw] can append to a shared CAT queue; voice never can.
  bool clearToSend({required bool repeat, bool queuedCw = false});

  /// SO2R's Radio B, or null — whose voice memories are named and timed
  /// apart from radio1's.
  String? get radio2;

  Future<void> updateNode(EquipmentNode node);

  /// Quiets every radio but [radio] before it transmits — one transmitter at
  /// a time (CatService.yieldTransmitter, docs/design/cat.md § PTT).
  void yieldTransmitter(String? radio);
}
