// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Domain models are thin typed views over QSON maps — the JSON stays the
// source of truth (it is what syncs and what plugins see), the getters just
// give the core and UI a safe way in.

/// A logging session: one station, one setup, one stretch of time.
class Operation {
  final String uuid;
  final Map<String, dynamic> data;
  final int qsoCount;
  final int? startAtMillisMin;
  final int? startAtMillisMax;

  const Operation({
    required this.uuid,
    required this.data,
    this.qsoCount = 0,
    this.startAtMillisMin,
    this.startAtMillisMax,
  });

  String get stationCall => (data['stationCall'] as String?) ?? '';
  String get title => (data['title'] as String?) ?? '';
  String? get grid => data['grid'] as String?;

  DateTime? get startAtMax =>
      startAtMillisMax == null ? null : DateTime.fromMillisecondsSinceEpoch(startAtMillisMax!, isUtc: true);
}

/// One contact. QSON shape (same as app-polo):
/// `{our: {call, sent}, their: {call, sent}, freq, band, mode,
///   startAtMillis, notes, refs: [...]}`
class Qso {
  final String uuid;
  final String operationUuid;
  final Map<String, dynamic> data;

  const Qso({required this.uuid, required this.operationUuid, required this.data});

  Map<String, dynamic> get _our => (data['our'] as Map<String, dynamic>?) ?? const {};
  Map<String, dynamic> get _their => (data['their'] as Map<String, dynamic>?) ?? const {};

  String get ourCall => (_our['call'] as String?) ?? '';
  String get theirCall => (_their['call'] as String?) ?? '';
  String? get theirName => _their['name'] as String?;
  String? get sentRST => _our['sent'] as String?;
  String? get receivedRST => _their['sent'] as String?;

  double? get freq => (data['freq'] as num?)?.toDouble();
  String? get band => data['band'] as String?;
  String? get mode => data['mode'] as String?;
  String? get notes => data['notes'] as String?;

  int? get startAtMillis => (data['startAtMillis'] as num?)?.toInt();
  DateTime? get startAt =>
      startAtMillis == null ? null : DateTime.fromMillisecondsSinceEpoch(startAtMillis!, isUtc: true);

  List<Map<String, dynamic>> get refs =>
      ((data['refs'] as List?) ?? const []).whereType<Map<String, dynamic>>().toList();
}
