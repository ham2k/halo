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
/// Immutable: the messages dialog edits a draft list and writes it whole on
/// Save, and a set that could be mutated in place would let a Cancel leave
/// half its edits behind.
class CwMessageSet {
  final String name;

  /// Always [SettingsService.cwMessageCount] long — [fromJson] pads a short
  /// list rather than leaving a key with nothing to read.
  final List<String> messages;
  final List<String> labels;

  const CwMessageSet({required this.name, required this.messages, required this.labels});

  static List<String> _padded(dynamic value) {
    final list = value is List ? [for (final entry in value) entry is String ? entry : ''] : <String>[];
    return [for (var i = 0; i < SettingsService.cwMessageCount; i++) i < list.length ? list[i] : ''];
  }

  factory CwMessageSet.fromJson(Map<String, dynamic> json) => CwMessageSet(
    name: (json['name'] as String?)?.trim().isNotEmpty == true ? json['name'] as String : '?',
    messages: _padded(json['messages']),
    labels: _padded(json['labels']),
  );

  Map<String, dynamic> toJson() => {'name': name, 'messages': messages, 'labels': labels};

  String message(int n) => n >= 1 && n <= messages.length ? messages[n - 1] : '';

  String label(int n) => n >= 1 && n <= labels.length ? labels[n - 1] : '';

  CwMessageSet withMessage(int n, String value) =>
      CwMessageSet(name: name, messages: [for (var i = 0; i < messages.length; i++) i == n - 1 ? value : messages[i]], labels: labels);

  CwMessageSet withLabel(int n, String value) =>
      CwMessageSet(name: name, messages: messages, labels: [for (var i = 0; i < labels.length; i++) i == n - 1 ? value : labels[i]]);

  CwMessageSet renamed(String value) => CwMessageSet(name: value, messages: messages, labels: labels);

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
      name: m.setDefault,
      messages: pad({1: 'CQ DE {{op.call}} K', 2: '{{qso.call}} UR 5NN TU', 4: '{{op.call}}'}),
      labels: pad({1: 'CQ', 2: '5NN', 4: '{{op.call}}'}),
    );
    return [?saved, defaults, CwMessageSet(name: m.setPota, messages: defaults.withMessage(1, 'CQ POTA DE {{op.call}} K').messages, labels: defaults.labels)];
  }
}
