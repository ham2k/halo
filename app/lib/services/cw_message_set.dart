// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart' show EsmMessage;

import 'settings_service.dart';

/// One named set of CW messages: eight templates and eight labels, the same
/// eight function keys under a name the operator picked. Sets are the
/// STORAGE — `SettingsService.cwMessage` reads the active one, so every
/// surface that names a message by its key (Settings, SET) moves with
/// the set in use rather than addressing a ninth, hidden copy.
///
/// The [id], not the name, is the identity: it is what the set in use is
/// stored as, and where the set is filed (`SetTree`), so a rename moves
/// neither.
///
/// Immutable: the messages dialog's Revert puts back a copy of each set
/// taken before its first edit, and a set that could be mutated in place
/// would change that copy along with it.
class CwMessageSet {
  final String id;
  final String name;

  /// Always [SettingsService.cwMessageCount] long — [fromJson] pads a short
  /// list rather than leaving a key with nothing to read.
  final List<String> messages;
  final List<String> labels;

  const CwMessageSet({required this.id, required this.name, required this.messages, required this.labels});

  /// The stored keys, in the Radio group: the sets, the id of the one in use,
  /// and the folders they are filed in.
  static const setsKey = 'cwMessageSets';
  static const activeKey = 'cwMessageSet';
  static const treeKey = 'cwMessageSetTree';

  static List<String> _padded(dynamic value) {
    final list = value is List ? [for (final entry in value) entry is String ? entry : ''] : <String>[];
    return [for (var i = 0; i < SettingsService.cwMessageCount; i++) i < list.length ? list[i] : ''];
  }

  /// A set stored before sets had ids takes its name as one: names were
  /// unique then, and the set in use was stored by name — so that stored
  /// name still finds it, with nothing to migrate.
  factory CwMessageSet.fromJson(Map<String, dynamic> json) {
    final name = (json['name'] as String?)?.trim().isNotEmpty == true ? json['name'] as String : '?';
    final id = json['id'];
    return CwMessageSet(id: id is String && id.isNotEmpty ? id : name, name: name, messages: _padded(json['messages']), labels: _padded(json['labels']));
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'messages': messages, 'labels': labels};

  String message(int n) => n >= 1 && n <= messages.length ? messages[n - 1] : '';

  String label(int n) => n >= 1 && n <= labels.length ? labels[n - 1] : '';

  CwMessageSet withMessage(int n, String value) =>
      CwMessageSet(id: id, name: name, messages: [for (var i = 0; i < messages.length; i++) i == n - 1 ? value : messages[i]], labels: labels);

  CwMessageSet withLabel(int n, String value) =>
      CwMessageSet(id: id, name: name, messages: messages, labels: [for (var i = 0; i < labels.length; i++) i == n - 1 ? value : labels[i]]);

  CwMessageSet renamed(String value) => CwMessageSet(id: id, name: value, messages: messages, labels: labels);

  /// The same messages under another identity — a duplicate, or an import.
  CwMessageSet copiedAs({required String id, required String name}) => CwMessageSet(id: id, name: name, messages: messages, labels: labels);

  /// The function key each Enter Sends Messages message lives on — N1MM's
  /// layout, which [esm] follows.
  static const esmKeys = {EsmMessage.cq: 1, EsmMessage.exchange: 2, EsmMessage.thanks: 3, EsmMessage.myCall: 4, EsmMessage.hisCall: 5, EsmMessage.again: 8};

  /// The set Enter Sends Messages is offered with, laid out as N1MM lays out
  /// its keys — F1 CQ, F2 exchange, F3 thanks, F4 my call, F5 their call, F8
  /// again — because ESM reads messages by position
  /// ([esmKeys]), and every contest operator already
  /// has those positions in their fingers. A set of its own rather than the
  /// seeds' layout: the Default's F2 answers a caller in one key, which is
  /// what an operator keying by hand wants and what ESM's split would break.
  static CwMessageSet esm() {
    List<String> pad(Map<int, String> entries) => [for (var n = 1; n <= SettingsService.cwMessageCount; n++) entries[n] ?? ''];
    return CwMessageSet(
      id: 'esm',
      name: t.settings.radio.cwMessages.setEsm,
      messages: pad({1: 'CQ DE {{op.call}} K', 2: '5NN', 3: 'TU', 4: '{{op.call}}', 5: '{{qso.call}}', 8: 'AGN?'}),
      labels: pad({1: 'CQ', 2: '5NN', 3: 'TU', 4: '{{op.call}}', 5: '{{qso.call}}', 8: 'AGN?'}),
    );
  }

  /// What an install with nothing stored is offered: a Default worth keying
  /// as it stands, and a POTA that differs from it only in the CQ — which is
  /// what duplicating a set produces, and the shape the operator will make
  /// the next one in. [saved] is the pre-sets F1-F8 where there were any; it
  /// goes FIRST and is therefore the active one, so an upgrade changes
  /// nothing about what the function keys send.
  static List<CwMessageSet> seeded(CwMessageSet? saved) {
    final m = t.settings.radio.cwMessages;
    List<String> pad(Map<int, String> entries) => [for (var n = 1; n <= SettingsService.cwMessageCount; n++) entries[n] ?? ''];
    final defaults = CwMessageSet(
      id: 'default',
      name: m.setDefault,
      messages: pad({1: 'CQ DE {{op.call}} K', 2: '{{qso.call}} UR 5NN TU', 4: '{{op.call}}'}),
      labels: pad({1: 'CQ', 2: '5NN', 4: '{{op.call}}'}),
    );
    return [
      ?saved,
      defaults,
      CwMessageSet(id: 'pota', name: m.setPota, messages: defaults.withMessage(1, 'CQ POTA DE {{op.call}} K').messages, labels: defaults.labels),
    ];
  }
}

/// The CW message sets as settings — beside the type rather than in
/// settings_service.dart, which is over its size budget.
extension CwMessageSetSettings on SettingsService {
  /// Every set the operator has, in the order they are offered. Never empty:
  /// an install with nothing stored is answered with the seeds, and one whose
  /// F1-F8 were written before sets existed keeps them as a set of their own
  /// ([CwMessageSet.seeded]) rather than losing them to the seeds.
  ///
  /// Derived rather than persisted at startup: a getter that seeds and a
  /// setter that writes cannot disagree, while a migration that runs once at
  /// launch fails silently on the install where it threw.
  List<CwMessageSet> get cwMessageSets {
    final stored = settingValue(SettingsService.radioGroup, CwMessageSet.setsKey);
    if (stored is List && stored.isNotEmpty) {
      final sets = [
        for (final entry in stored)
          if (entry is Map) CwMessageSet.fromJson(entry.cast<String, dynamic>()),
      ];
      if (sets.isNotEmpty) return sets;
    }
    return CwMessageSet.seeded(_legacyCwMessageSet());
  }

  /// The pre-sets messages as a set, or null when there were none — every
  /// field empty is an install that never wrote one, not a set of blanks.
  CwMessageSet? _legacyCwMessageSet() {
    String read(String key) => (settingValue(SettingsService.radioGroup, key) as String?) ?? '';
    final messages = [for (var n = 1; n <= SettingsService.cwMessageCount; n++) read(SettingsService.cwMessageKey(n))];
    final labels = [for (var n = 1; n <= SettingsService.cwMessageCount; n++) read(SettingsService.cwMessageLabelKey(n))];
    if (messages.every((text) => text.trim().isEmpty)) return null;
    return CwMessageSet(id: 'saved', name: t.settings.radio.cwMessages.setSaved, messages: messages, labels: labels);
  }

  /// The id of the set F1-F8 key. Falls back to the first set rather than
  /// to an id: a stored id whose set was deleted would otherwise leave the
  /// keys with nothing to send.
  String get cwMessageSetId {
    final sets = cwMessageSets;
    final stored = settingValue(SettingsService.radioGroup, CwMessageSet.activeKey);
    if (stored is String && sets.any((set) => set.id == stored)) return stored;
    return sets.first.id;
  }

  CwMessageSet get activeCwMessageSet {
    final id = cwMessageSetId;
    final sets = cwMessageSets;
    return sets.firstWhere((set) => set.id == id, orElse: () => sets.first);
  }

  /// Writes the sets and, when given, which one is in use — one write, so a
  /// pick that arrives with edits cannot land half-applied.
  Future<void> setCwMessageSets(List<CwMessageSet> sets, {String? active}) async {
    if (sets.isEmpty) return;
    final id = active != null && sets.any((set) => set.id == active) ? active : sets.first.id;
    await updateSettingsGroup(SettingsService.radioGroup, {
      CwMessageSet.setsKey: [for (final set in sets) set.toJson()],
      CwMessageSet.activeKey: id,
    });
  }

  Future<void> editActiveCwMessageSet(CwMessageSet Function(CwMessageSet) edit) {
    final id = cwMessageSetId;
    final sets = [for (final set in cwMessageSets) set.id == id ? edit(set) : set];
    return setCwMessageSets(sets, active: id);
  }
}
