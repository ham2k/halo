// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The keyer sets extensions offer (docs/extensions/commands.md § keyerSets):
// CW and voice message sets the operator picks as they pick their own, and
// never changes — a copy of one is theirs to edit. Listed under an
// Extensions folder, one folder per extension, that no stored tree holds
// (SetTree.withOffered).
//
// Kept in a device pref rather than a setting: they are what this device's
// extensions said, and a synced copy would list on another device sets no
// extension there offers. Kept at all, rather than only in memory, so the
// function keys send the picked set from launch, before the extensions have
// activated and said it again.

import 'dart:convert';

import '../settings_service.dart';
import 'set_tree.dart';

export 'set_tree.dart' show OfferedSetPlace, isOfferedSetId, offeredSetIdPrefix;

/// One set an extension offers, with the extension it is listed under.
typedef OfferedSet<T> = ({T set, String owner, String ownerName});

/// Every set the extensions offer, by kind.
class OfferedKeyerSets {
  final List<OfferedSet<CwMessageSet>> cw;
  final List<OfferedSet<VoiceMessageSet>> voice;

  const OfferedKeyerSets({this.cw = const [], this.voice = const []});

  /// Reads what [toJson] wrote; an entry it cannot read is left out.
  factory OfferedKeyerSets.fromJson(Map<String, dynamic> json) {
    final cw = <OfferedSet<CwMessageSet>>[];
    final voice = <OfferedSet<VoiceMessageSet>>[];
    if (json['sets'] case final List<dynamic> entries) {
      for (final entry in entries) {
        if (entry is! Map) continue;
        final map = entry.cast<String, dynamic>();
        final (owner, ownerName, id, name) = (map['owner'], map['ownerName'], map['id'], map['name']);
        if (owner is! String || ownerName is! String || id is! String || !isOfferedSetId(id) || name is! String) continue;
        switch (map['kind']) {
          case 'cw':
            cw.add((set: CwMessageSet.fromJson(map), owner: owner, ownerName: ownerName));
          case 'voice':
            if (VoiceMessageSet.fromJson(map) case final set?) voice.add((set: set, owner: owner, ownerName: ownerName));
        }
      }
    }
    return OfferedKeyerSets(cw: cw, voice: voice);
  }

  Map<String, dynamic> toJson() => {
    'sets': [
      for (final (:set, :owner, :ownerName) in cw) {'kind': 'cw', 'owner': owner, 'ownerName': ownerName, ...set.toJson()},
      for (final (:set, :owner, :ownerName) in voice) {'kind': 'voice', 'owner': owner, 'ownerName': ownerName, ...set.toJson()},
    ],
  };

  /// [hookKey]'s answer [item] as an offered set, under extension [owner]
  /// named [ownerName]. Its id is put under [hookKey], so two extensions'
  /// `contest` sets are two sets. Throws [FormatException] for anything
  /// that is not a set (KeyerSet, extensions/sdk/src/types.ts).
  static ({CwMessageSet? cw, VoiceMessageSet? voice}) parse(Map<String, dynamic> item, {required String hookKey}) {
    final (kind, id, name) = (item['kind'], item['id'], item['name']);
    if (id is! String || id.trim().isEmpty) throw const FormatException('a set with no id');
    // The last ':' of an offered id is where the hook key ends.
    if (id.contains(':')) throw FormatException('set "$id": an id holds no ":"');
    if (name is! String || name.trim().isEmpty) throw FormatException('set "$id" has no name');
    List<String> strings(String field, {required bool required}) {
      final value = item[field];
      if (value == null && !required) return const [];
      if (value is! List || value.any((entry) => entry is! String)) throw FormatException('set "$id": $field is not a list of strings');
      if (value.length > SettingsService.cwMessageCount) throw FormatException('set "$id": more than ${SettingsService.cwMessageCount} $field');
      return value.cast<String>();
    }

    final fullId = '$offeredSetIdPrefix$hookKey:$id';
    final labels = strings('labels', required: false);
    return switch (kind) {
      'cw' => (cw: CwMessageSet.fromJson({'id': fullId, 'name': name, 'messages': strings('messages', required: true), 'labels': labels}), voice: null),
      'voice' => (cw: null, voice: VoiceMessageSet.fromJson({'id': fullId, 'name': name, 'labels': labels, 'templates': strings('templates', required: true)})),
      _ => throw FormatException('set "$id": kind is not "cw" or "voice"'),
    };
  }
}

/// [OfferedKeyerSets] as last read, with the stored text it came from: the
/// set in use is asked for on every keyer button's rebuild, and decoding the
/// pref for each read is what this keeps from happening.
final _decoded = Expando<({String? stored, OfferedKeyerSets sets})>();

extension OfferedKeyerSetsSettings on SettingsService {
  static const prefsKey = 'offeredKeyerSets';

  OfferedKeyerSets get offeredKeyerSets {
    final stored = _stored;
    final memo = _decoded[this];
    if (memo != null && memo.stored == stored) return memo.sets;
    final sets = OfferedKeyerSets.fromJson(jsonMapPref(prefsKey));
    _decoded[this] = (stored: stored, sets: sets);
    return sets;
  }

  /// Writes [sets] — only where they differ, so the extensions activating
  /// with what they offered last time rebuilds nothing.
  Future<void> setOfferedKeyerSets(OfferedKeyerSets sets) async {
    final json = sets.toJson();
    if (_stored == jsonEncode(json)) return;
    await setJsonMapPref(prefsKey, json);
  }

  /// The pref's text; something else under the key reads as nothing
  /// offered, as jsonMapPref reads it.
  String? get _stored {
    try {
      return prefs.getString(prefsKey);
    } catch (_) {
      return null;
    }
  }

  CwMessageSet? offeredCwMessageSet(String id) => isOfferedSetId(id) ? offeredKeyerSets.cw.where((o) => o.set.id == id).firstOrNull?.set : null;

  VoiceMessageSet? offeredVoiceMessageSet(String id) => isOfferedSetId(id) ? offeredKeyerSets.voice.where((o) => o.set.id == id).firstOrNull?.set : null;
}
