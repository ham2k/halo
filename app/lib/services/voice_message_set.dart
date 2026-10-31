// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:halo_i18n/halo_i18n.dart';

import 'cat/voice_words.dart';
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

  /// What each message says when it is not a recording: a template voiced
  /// from the operator's words (docs/design/cat.md § Voiced words), empty for
  /// a message that is its recording. Always [SettingsService.voiceMessageCount] long.
  final List<String> templates;

  const VoiceMessageSet({required this.id, required this.name, required this.labels, this.templates = _noTemplates});

  static const _noTemplates = ['', '', '', '', '', '', '', ''];

  /// The stored keys, in the Radio group: the sets, the id of the one in
  /// use, and where phone messages come from.
  static const setsKey = 'voiceMessageSets';
  static const activeKey = 'voiceMessageSet';
  static const sourceKey = 'voiceKeying';

  /// [sourceKey] for [radio], `A` or `B` — Radio B's pick beside radio1's,
  /// as its labels are (SettingsService.voiceMessageLabelKey).
  static String sourceKeyFor(String radio) => radio == 'B' ? '${sourceKey}B' : sourceKey;

  /// The set every install has — "Sound files on this computer" — listed
  /// before the operator's. Neither
  /// renamed nor deleted: it is where sound files go before anyone has made
  /// a set, so its name comes from the translations, not from storage.
  static const defaultId = 'default';

  bool get isDefault => id == defaultId;

  VoiceMessageSet.empty({required this.id, required this.name}) : labels = List.filled(SettingsService.voiceMessageCount, ''), templates = _noTemplates;

  /// Null for an entry with no id: without one there is no directory to read
  /// its recordings from.
  static VoiceMessageSet? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! String || id.isEmpty) return null;
    final name = json['name'];
    List<String> strings(Object? raw) {
      final list = raw is List ? [for (final entry in raw) entry is String ? entry : ''] : <String>[];
      return [for (var i = 0; i < SettingsService.voiceMessageCount; i++) i < list.length ? list[i] : ''];
    }

    return VoiceMessageSet(
      id: id,
      name: name is String && name.trim().isNotEmpty ? name : '?',
      labels: strings(json['labels']),
      templates: strings(json['templates']),
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'labels': labels, if (templates.any((t) => t.isNotEmpty)) 'templates': templates};

  String label(int n) => n >= 1 && n <= labels.length ? labels[n - 1] : '';

  String template(int n) => n >= 1 && n <= templates.length ? templates[n - 1] : '';

  VoiceMessageSet withLabel(int n, String value) =>
      VoiceMessageSet(id: id, name: name, labels: [for (var i = 0; i < labels.length; i++) i == n - 1 ? value : labels[i]], templates: templates);

  VoiceMessageSet withTemplate(int n, String value) =>
      VoiceMessageSet(id: id, name: name, labels: labels, templates: [for (var i = 0; i < templates.length; i++) i == n - 1 ? value : templates[i]]);

  VoiceMessageSet renamed(String name) => VoiceMessageSet(id: id, name: name, labels: labels, templates: templates);
}

/// The Radio group key the word sets' phrases are kept under.
const voicePhrasesKey = 'voicePhrases';
const voicePacingKey = 'voicePacing';

/// [call] as a word set is named by — its directory and its phrases' key:
/// upper case, a slash (a portable call) made something a path can hold.
String voiceWordSetCall(String call) => call.trim().toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '_');

/// Where phone messages come from: nowhere, the radio's own memories, or the
/// set in use on this computer. One pick for every radio, as the set is.
enum VoiceKeyingSource { none, radio, computer }

/// The Radio group as the getters below last decoded it, with the stored
/// text it came from, per settings. Every message button asks for the
/// source, the set in use and a label on every rebuild, several times a
/// second; decoding the whole group for each of those reads is what this
/// keeps from happening, until the group is written.
final _decoded = Expando<({Object? stored, Map<String, dynamic> group, List<VoiceMessageSet> sets})>();

/// The voice message sets as settings — beside the type rather than in
/// settings_service.dart, which is over its size budget.
extension VoiceMessageSetSettings on SettingsService {
  ({Object? stored, Map<String, dynamic> group, List<VoiceMessageSet> sets}) get _voiceSettings {
    final stored = storedSettingsGroup(SettingsService.radioGroup);
    final memo = _decoded[this];
    if (memo != null && identical(memo.stored, stored)) return memo;
    final group = settingsGroup(SettingsService.radioGroup);
    final raw = group[VoiceMessageSet.setsKey];
    final sets = [
      if (raw is List)
        for (final entry in raw)
          if (entry is Map) ?VoiceMessageSet.fromJson(entry.cast<String, dynamic>()),
    ];
    return _decoded[this] = (stored: stored, group: group, sets: sets);
  }

  /// The sets of voice messages recorded on this computer, the default one
  /// first — always, whatever was stored, with only its labels read back.
  List<VoiceMessageSet> get voiceMessageSets {
    final stored = _voiceSettings.sets;
    final saved = stored.where((set) => set.isDefault).firstOrNull;
    final name = t.settings.radio.voiceMessages.soundFilesSet;
    return [
      saved?.renamed(name) ?? VoiceMessageSet.empty(id: VoiceMessageSet.defaultId, name: name),
      for (final set in stored)
        if (!set.isDefault) set,
    ];
  }

  /// Where radio1's phone messages come from — [voiceKeyingSourceFor] `A`.
  VoiceKeyingSource get voiceKeyingSource => voiceKeyingSourceFor('A');

  /// Where [radio]'s (`A` or `B`) phone messages come from. The radio's own
  /// memories until the operator picks otherwise: they are what a radio that
  /// has them played before this app could play anything. Per radio, like
  /// [voiceMessageLabel]: each rig has a sound card of its own, or none.
  VoiceKeyingSource voiceKeyingSourceFor(String radio) {
    final stored = _voiceSettings.group[VoiceMessageSet.sourceKeyFor(radio)];
    return VoiceKeyingSource.values.where((source) => source.name == stored).firstOrNull ?? VoiceKeyingSource.radio;
  }

  Future<void> setVoiceKeyingSource(VoiceKeyingSource source, {String radio = 'A'}) =>
      updateSettingsGroup(SettingsService.radioGroup, {VoiceMessageSet.sourceKeyFor(radio): source.name});

  /// The default set for a stored id whose set is gone, or none stored.
  String get voiceMessageSetId {
    final stored = _voiceSettings.group[VoiceMessageSet.activeKey];
    return stored is String && voiceMessageSets.any((set) => set.id == stored) ? stored : VoiceMessageSet.defaultId;
  }

  VoiceMessageSet get activeVoiceMessageSet {
    final id = voiceMessageSetId;
    return voiceMessageSets.firstWhere((set) => set.id == id);
  }

  /// The phrases of each operator's word set (docs/design/cat.md § Voiced
  /// words), by callsign as [voiceWordSetCall] spells it.
  List<VoicePhrase> voicePhrases(String call) {
    final raw = _voiceSettings.group[voicePhrasesKey];
    final list = raw is Map ? raw[voiceWordSetCall(call)] : null;
    return [
      if (list is List)
        for (final entry in list) ?VoicePhrase.fromJson(entry),
    ];
  }

  Future<void> setVoicePhrases(String call, List<VoicePhrase> phrases) {
    final raw = _voiceSettings.group[voicePhrasesKey];
    final all = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    all[voiceWordSetCall(call)] = [for (final phrase in phrases) phrase.toJson()];
    return updateSettingsGroup(SettingsService.radioGroup, {voicePhrasesKey: all});
  }

  /// How [call]'s words are spaced when a message is said with them.
  VoicedPacing voicePacing(String call) {
    final raw = _voiceSettings.group[voicePacingKey];
    return VoicedPacing.fromJson(raw is Map ? raw[voiceWordSetCall(call)] : null);
  }

  Future<void> setVoicePacing(String call, VoicedPacing spacing) {
    final raw = _voiceSettings.group[voicePacingKey];
    final all = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    all[voiceWordSetCall(call)] = spacing.toJson();
    return updateSettingsGroup(SettingsService.radioGroup, {voicePacingKey: all});
  }

  /// Writes the sets and which one is in use, in one write.
  Future<void> setVoiceMessageSets(List<VoiceMessageSet> sets, {required String active}) => updateSettingsGroup(SettingsService.radioGroup, {
    VoiceMessageSet.setsKey: [for (final set in sets) set.toJson()],
    VoiceMessageSet.activeKey: sets.any((set) => set.id == active) ? active : null,
  });
}
