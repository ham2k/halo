// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:halo_i18n/halo_i18n.dart';

import 'settings_service.dart';

/// One named set of voice messages recorded on this computer
/// (docs/design/cat.md § The computer's voice keyer): eight labels under a
/// name the operator picked, the audio itself in a directory named by [id].
///
/// The id, not the name, is the identity: the recordings live under it, and
/// a rename that moved a directory would be one more thing to fail halfway.
/// The radio's own memories are not a set: whether they play or a set does
/// is [VoiceKeyingSource], picked on its own.
class VoiceMessageSet {
  final String id;
  final String name;

  /// Always [SettingsService.voiceMessageCount] long.
  final List<String> labels;

  const VoiceMessageSet({required this.id, required this.name, required this.labels});

  /// The stored keys, in the Radio group: the sets, the id of the one in
  /// use, and where phone messages come from.
  static const setsKey = 'voiceMessageSets';
  static const activeKey = 'voiceMessageSet';
  static const sourceKey = 'voiceKeying';

  /// The set every install has — "Sound files on this computer" — listed
  /// before the operator's. Neither
  /// renamed nor deleted: it is where sound files go before anyone has made
  /// a set, so its name comes from the translations, not from storage.
  static const defaultId = 'default';

  bool get isDefault => id == defaultId;

  VoiceMessageSet.empty({required this.id, required this.name}) : labels = List.filled(SettingsService.voiceMessageCount, '');

  /// Null for an entry with no id: without one there is no directory to read
  /// its recordings from.
  static VoiceMessageSet? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! String || id.isEmpty) return null;
    final name = json['name'];
    final raw = json['labels'];
    final list = raw is List ? [for (final entry in raw) entry is String ? entry : ''] : <String>[];
    return VoiceMessageSet(
      id: id,
      name: name is String && name.trim().isNotEmpty ? name : '?',
      labels: [for (var i = 0; i < SettingsService.voiceMessageCount; i++) i < list.length ? list[i] : ''],
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'labels': labels};

  String label(int n) => n >= 1 && n <= labels.length ? labels[n - 1] : '';

  VoiceMessageSet withLabel(int n, String value) =>
      VoiceMessageSet(id: id, name: name, labels: [for (var i = 0; i < labels.length; i++) i == n - 1 ? value : labels[i]]);

  VoiceMessageSet renamed(String name) => VoiceMessageSet(id: id, name: name, labels: labels);
}

/// Where phone messages come from: nowhere, the radio's own memories, or the
/// set in use on this computer. One pick for every radio, as the set is.
enum VoiceKeyingSource { none, radio, computer }

/// The voice message sets as settings — beside the type rather than in
/// settings_service.dart, which is over its size budget.
extension VoiceMessageSetSettings on SettingsService {
  /// The sets of voice messages recorded on this computer, the default one
  /// first — always, whatever was stored, with only its labels read back.
  List<VoiceMessageSet> get voiceMessageSets {
    final raw = settingValue(SettingsService.radioGroup, VoiceMessageSet.setsKey);
    final stored = [
      if (raw is List)
        for (final entry in raw)
          if (entry is Map) ?VoiceMessageSet.fromJson(entry.cast<String, dynamic>()),
    ];
    final saved = stored.where((set) => set.isDefault).firstOrNull;
    final name = t.settings.radio.voiceMessages.soundFilesSet;
    return [
      saved?.renamed(name) ?? VoiceMessageSet.empty(id: VoiceMessageSet.defaultId, name: name),
      for (final set in stored)
        if (!set.isDefault) set,
    ];
  }

  /// The radio's own memories until the operator picks otherwise: they are
  /// what a radio that has them played before this app could play anything.
  VoiceKeyingSource get voiceKeyingSource {
    final stored = settingValue(SettingsService.radioGroup, VoiceMessageSet.sourceKey);
    return VoiceKeyingSource.values.where((source) => source.name == stored).firstOrNull ?? VoiceKeyingSource.radio;
  }

  Future<void> setVoiceKeyingSource(VoiceKeyingSource source) => updateSettingsGroup(SettingsService.radioGroup, {VoiceMessageSet.sourceKey: source.name});

  /// The default set for a stored id whose set is gone, or none stored.
  String get voiceMessageSetId {
    final stored = settingValue(SettingsService.radioGroup, VoiceMessageSet.activeKey);
    return stored is String && voiceMessageSets.any((set) => set.id == stored) ? stored : VoiceMessageSet.defaultId;
  }

  VoiceMessageSet get activeVoiceMessageSet {
    final id = voiceMessageSetId;
    return voiceMessageSets.firstWhere((set) => set.id == id);
  }

  /// Writes the sets and which one is in use, in one write.
  Future<void> setVoiceMessageSets(List<VoiceMessageSet> sets, {required String active}) => updateSettingsGroup(SettingsService.radioGroup, {
    VoiceMessageSet.setsKey: [for (final set in sets) set.toJson()],
    VoiceMessageSet.activeKey: sets.any((set) => set.id == active) ? active : null,
  });
}
