// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What every operating position sharing an operation is composing right now
// (HALO-395) — one entry per device, this one included.
//
// Latest-value-wins and lossy, like the rest of the ephemeral channel: a
// missed draft costs nothing, because the next one supersedes it and a
// newly established session is sent a snapshot.

import 'package:flutter/foundation.dart';
import 'package:halo_core/halo_core.dart';

import 'ble/peer_ble_transport.dart';
import 'peer_service.dart';

/// The device id this device's OWN block is filed under. Not a real peer id
/// and never on the wire — a peer's ids come from its beacon, and `local` is
/// not a shape those take.
const String localDraftPeerId = 'local';

/// One operating position's block, ready to render.
class PeerDraftBlock {
  /// The peer this came from, or [localDraftPeerId] for this device.
  final String deviceId;

  /// What that device calls itself — the last resort for a block that has
  /// neither a position nor an operator to lead with.
  final String deviceName;

  final PeerQsoDraftPayload draft;

  const PeerDraftBlock({
    required this.deviceId,
    required this.deviceName,
    required this.draft,
  });

  bool get isThisDevice => deviceId == localDraftPeerId;

  /// The multi-station number as an int, or null when this position has
  /// none — what [PeerDrafts.blocksFor] orders on.
  int? get positionNumber => int.tryParse(draft.position);
}

class PeerDrafts extends ChangeNotifier {
  PeerDrafts({required this.peers});

  final PeerService peers;

  /// Keyed by peer device id. A peer's draft stands until its session goes
  /// away: a position that has stopped typing is still at that frequency,
  /// and blanking it on silence would say otherwise.
  final Map<String, PeerQsoDraftPayload> _drafts = {};

  PeerQsoDraftPayload? _local;

  /// This device's own draft, as its peers were last told it.
  PeerQsoDraftPayload? get localDraft => _local;

  /// Publishes this device's draft to every LAN peer, and files it as this
  /// device's own block.
  ///
  /// LAN only, and deliberately: [PeerService.broadcastEphemeral] would
  /// include a BLE session, where a few hundred bytes per keystroke sit
  /// behind a 32 KiB credit window and put every GPS fix and tune request
  /// behind tens of seconds of head-of-line blocking. That is the same
  /// reason screen sharing is LAN-only, and a draft is a stream in the same
  /// sense — a contact being typed is not worth delaying a tune request for.
  void publishLocal(PeerQsoDraftPayload draft) {
    _local = draft;
    final message = _messageFor(draft);
    for (final deviceId in peers.peers.keys.toList()) {
      peers.sendEphemeralTo(deviceId, message);
    }
    notifyListeners();
  }

  static PeerMessage _messageFor(PeerQsoDraftPayload draft) => PeerMessage.qsoDraft(
        qso: draft.qso,
        operationUuid: draft.operationUuid,
        fields: draft.fields,
        position: draft.position,
        operatorCall: draft.operatorCall,
      );

  /// This device has stopped sharing, so it has no block and nothing to say
  /// about anyone else's — the drafts it holds were all read against an
  /// operation it is no longer in.
  void clearLocal() {
    if (_local == null && _drafts.isEmpty) return;
    _local = null;
    _drafts.clear();
    notifyListeners();
  }

  /// This device has left [operationUuid], so it is no longer a position in
  /// it. Peers are told by the same empty draft a wipe sends.
  ///
  /// A no-op unless the block on file is actually that operation's: opening B
  /// from inside A and popping back leaves A's view disposing AFTER B's has
  /// published, and clearing unconditionally there would retract a block that
  /// is currently correct.
  ///
  /// Without this the block never goes away — [snapshotTo] keeps seeding a
  /// half-typed contact to every peer that connects afterwards, which is the
  /// same "still working that station" lie [forgetPeer] exists to prevent, on
  /// the one device that cannot be told by a session dropping.
  void clearLocalFor(String operationUuid) {
    final draft = _local;
    if (draft == null || draft.operationUuid != operationUuid) return;
    _local = null;
    final message = PeerMessage.qsoDraft(qso: const {}, operationUuid: operationUuid, left: true);
    for (final deviceId in peers.peers.keys.toList()) {
      peers.sendEphemeralTo(deviceId, message);
    }
    notifyListeners();
  }

  /// A peer's latest draft.
  void onDraft(String peerDeviceId, PeerQsoDraftPayload draft) {
    _drafts[peerDeviceId] = draft;
    notifyListeners();
  }

  /// A peer went away. Unlike a screen view, a draft leaves nothing behind:
  /// a contact half-typed on a device that is no longer here is not a state
  /// anyone can act on, and leaving it up reads as a position still working
  /// that station.
  void forgetPeer(String peerDeviceId) {
    if (_drafts.remove(peerDeviceId) == null) return;
    notifyListeners();
  }

  /// Re-sends this device's block to a peer that has just established — the
  /// establish-time snapshot every ephemeral type gets, since a peer arriving
  /// between two keystrokes would otherwise see nothing until the next one.
  ///
  /// Takes the SESSION rather than a device id, like the GPS and CAT
  /// snapshots beside it: at the moment a session establishes it is not yet
  /// reachable through [PeerService.peers], so an id-keyed send finds nothing
  /// and the arriving position sits blank until someone types.
  ///
  /// The LAN-only rule from [publishLocal] still applies, checked on the link
  /// here since there is no id to ask [PeerService.sendEphemeralTo] about.
  void snapshotTo(PeerSession session) {
    final draft = _local;
    if (draft == null || session.link is PeerBleLink) return;
    session.sendEphemeral(_messageFor(draft));
  }

  /// Every position working [operationUuid], in the order the panel shows
  /// them: numbered positions ascending, then everything without a number.
  ///
  /// Filtered on the operation the DRAFT names rather than on what the
  /// session is sharing — a session outlives an operation change, so the
  /// draft is the only thing that says which operation its contact belongs
  /// to (see [PeerQsoDraftPayload.operationUuid]).
  List<PeerDraftBlock> blocksFor(String operationUuid) {
    final blocks = <PeerDraftBlock>[
      if (_local != null && _local!.operationUuid == operationUuid)
        PeerDraftBlock(deviceId: localDraftPeerId, deviceName: '', draft: _local!),
      for (final entry in _drafts.entries)
        if (entry.value.operationUuid == operationUuid)
          PeerDraftBlock(
            deviceId: entry.key,
            deviceName: peers.peers[entry.key]?.beacon.deviceName ?? '',
            draft: entry.value,
          ),
    ];
    blocks.sort((a, b) {
      final byPosition = _comparePositions(a.positionNumber, b.positionNumber);
      if (byPosition != 0) return byPosition;
      // A stable tiebreak so two unnumbered positions do not swap places on
      // every rebuild — the panel would flicker between them as drafts land.
      return a.deviceId.compareTo(b.deviceId);
    });
    return blocks;
  }

  /// Numbered positions first and in order; an unnumbered one sorts last
  /// rather than as zero, which would put it ahead of position 1.
  static int _comparePositions(int? a, int? b) {
    if (a == b) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return a.compareTo(b);
  }
}
