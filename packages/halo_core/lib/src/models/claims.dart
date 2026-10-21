// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What a `chasing` program says a contact counts toward, as the host reads it
// off the bridge (docs/design/claims.md). The SDK's `ChasingProgram`,
// `QsoClaim` and `ClaimLevel` (extensions/sdk/src/types.ts) are the other half.

import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../ham/grid.dart';
import 'models.dart';

/// Ordered: a later value outranks an earlier one in a slot.
enum ClaimLevel {
  worked,
  confirmed,
  verified;

  static ClaimLevel? tryParse(Object? value) => switch (value) {
    'worked' => worked,
    'confirmed' => confirmed,
    'verified' => verified,
    _ => null,
  };
}

enum ChasingEditions {
  lifetime,
  annual,
  event;

  static ChasingEditions? tryParse(Object? value) => switch (value) {
    'lifetime' => lifetime,
    'annual' => annual,
    'event' => event,
    _ => null,
  };
}

/// A program, as its hook's `program` member describes it.
class ChasingProgram {
  const ChasingProgram({
    required this.key,
    required this.label,
    required this.version,
    required this.editions,
    this.icon,
    this.color,
    this.supersedes = const {},
    this.imports = const [],
    String? refLabel,
  }) : refLabel = refLabel ?? label;

  final String key;
  final String label;
  final int version;
  final ChasingEditions editions;
  final String? icon;
  final String? color;

  /// What one reference of the checklist is called in notices ("New POTA
  /// Park"); the program's own label unless it says otherwise.
  final String refLabel;

  /// The scoring notice keys this program's verdicts stand in for.
  final Set<String> supersedes;

  /// The files the program can read claims from (claims.md §9).
  final List<ChasingImporter> imports;

  /// Null for anything that is not a usable description: an extension
  /// answering a malformed `program` has registered no program.
  static ChasingProgram? tryParse(String key, Object? json) {
    if (json is! Map) return null;
    final label = json['label'];
    final version = json['version'];
    final editions = ChasingEditions.tryParse(json['editions']);
    if (label is! String || label.isEmpty || version is! int || editions == null) return null;
    final icon = json['icon'];
    final color = json['color'];
    final supersedes = json['supersedes'];
    final imports = json['imports'];
    final refLabel = json['refLabel'];
    return ChasingProgram(
      key: key,
      label: label,
      version: version,
      editions: editions,
      icon: icon is String ? icon : null,
      color: color is String ? color : null,
      supersedes: {if (supersedes is List) ...supersedes.whereType<String>()},
      imports: [if (imports is List) ...imports.map(ChasingImporter.tryParse).nonNulls],
      refLabel: refLabel is String && refLabel.isNotEmpty ? refLabel : null,
    );
  }
}

/// One kind of file a program reads claims from: a sponsor's export.
class ChasingImporter {
  const ChasingImporter({required this.key, required this.label, required this.extensions});

  /// Names the import batch (§9): importing the same kind of file again
  /// replaces what the last one wrote.
  final String key;
  final String label;

  /// Lower-case file extensions, without the dot.
  final List<String> extensions;

  /// Whether a file named [fileName] is one this importer takes.
  bool takes(String fileName) {
    final dot = fileName.lastIndexOf('.');
    return dot >= 0 && extensions.contains(fileName.substring(dot + 1).toLowerCase());
  }

  /// Null for an entry missing its key, label or extensions.
  static ChasingImporter? tryParse(Object? json) {
    if (json is! Map) return null;
    final key = json['key'];
    final label = json['label'];
    final extensions = json['extensions'];
    if (key is! String || key.isEmpty || label is! String || label.isEmpty || extensions is! List) return null;
    final types = [
      for (final extension in extensions.whereType<String>())
        if (extension.isNotEmpty) extension.toLowerCase().replaceFirst(RegExp(r'^\.'), ''),
    ];
    return types.isEmpty ? null : ChasingImporter(key: key, label: label, extensions: types);
  }
}

/// One slot a contact fills, for one program.
class QsoClaim {
  const QsoClaim({
    required this.holder,
    required this.ref,
    required this.band,
    required this.mode,
    required this.level,
    this.edition = '',
    this.by,
    this.label,
    this.guess = false,
  });

  final String holder;
  final String ref;

  /// Null: any band.
  final String? band;

  /// The program's own grouping. Null: any mode.
  final String? mode;

  /// Empty for a lifetime program.
  final String edition;
  final ClaimLevel level;
  final String? by;
  final String? label;
  final bool guess;

  /// Null for an entry that is not a claim. A band or mode left out is read
  /// as null — any — the same as the SDK's type requires it be written.
  static QsoClaim? tryParse(Object? json) {
    if (json is! Map) return null;
    final holder = json['holder'];
    final ref = json['ref'];
    final band = json['band'];
    final mode = json['mode'];
    final edition = json['edition'];
    final level = ClaimLevel.tryParse(json['level']);
    if (holder is! String || holder.isEmpty || ref is! String || ref.isEmpty || level == null) return null;
    if ((band != null && band is! String) || (mode != null && mode is! String) || (edition != null && edition is! String)) return null;
    final by = json['by'];
    final label = json['label'];
    return QsoClaim(
      holder: holder,
      ref: ref,
      band: band as String?,
      mode: mode as String?,
      edition: (edition as String?) ?? '',
      level: level,
      by: by is String ? by : null,
      label: label is String ? label : null,
      guess: json['guess'] == true,
    );
  }

  /// The shape [tryParse] reads.
  Map<String, dynamic> toJson() => {
    'holder': holder,
    'ref': ref,
    'band': band,
    'mode': mode,
    if (edition.isNotEmpty) 'edition': edition,
    'level': level.name,
    'by': ?by,
    'label': ?label,
    if (guess) 'guess': true,
  };

  @override
  bool operator ==(Object other) =>
      other is QsoClaim &&
      other.holder == holder &&
      other.ref == ref &&
      other.band == band &&
      other.mode == mode &&
      other.edition == edition &&
      other.level == level &&
      other.by == by &&
      other.label == label &&
      other.guess == guess;

  @override
  int get hashCode => Object.hash(holder, ref, band, mode, edition, level, by, label, guess);

  @override
  String toString() => 'QsoClaim($holder, $ref, ${band ?? '*'}, ${mode ?? '*'}, ${edition.isEmpty ? '-' : edition}, ${level.name})';
}

/// Where a stored claim came from: the log, or one import batch (§9).
const kClaimSourceLog = 'log';

/// One record a program read from an imported file: a claim with no contact
/// behind it, and when it was earned if the file says.
class ImportedClaim {
  const ImportedClaim(this.claim, {this.atMillis});

  final QsoClaim claim;
  final int? atMillis;

  /// Null for a record that is not a claim.
  static ImportedClaim? tryParse(Object? json) {
    final claim = QsoClaim.tryParse(json);
    if (claim == null) return null;
    final at = (json as Map)['at'];
    return ImportedClaim(claim, atMillis: at is num ? at.toInt() : null);
  }
}

/// The `event` kind of a claim record (claims.md §9): an imported claim kept
/// in the log as an event row, so it syncs with the log and the claims table
/// can be rebuilt from the log alone.
const kClaimEventKind = 'claim';

/// The QSON of the claim record for [imported], read by [program]'s
/// [importer]. Its uuid is one per program, importer and slot, so importing
/// the same kind of file again rewrites the same rows. A record that does not
/// say when it was earned is dated [fallbackMillis].
Map<String, dynamic> claimEventQson({required String program, required String importer, required ImportedClaim imported, required int fallbackMillis}) {
  final claim = imported.claim;
  return {
    'uuid': claimUuid(
      program: program,
      holder: claim.holder,
      edition: claim.edition,
      ref: claim.ref,
      band: claim.band,
      mode: claim.mode,
      source: 'import:$importer',
    ),
    'band': 'event',
    // The placeholder calls every event row carries: a PoLo device syncing
    // the log keys each row on them.
    'our': {'call': 'EVENT'},
    'their': {'call': kClaimEventKind.toUpperCase()},
    'startAtMillis': imported.atMillis ?? fallbackMillis,
    'event': {
      'event': kClaimEventKind,
      'program': program,
      'importer': importer,
      'claim': {...claim.toJson(), 'at': ?imported.atMillis},
    },
  };
}

/// What the claim record [qso] says, or null for any other row. `atMillis`
/// is null when the file did not say when the slot was earned.
({String program, String importer, QsoClaim claim, int? atMillis})? claimEventOf(Map<String, dynamic> qso) {
  if (qso['band'] != 'event') return null;
  final event = qso['event'];
  if (event is! Map || event['event'] != kClaimEventKind) return null;
  final program = event['program'];
  final importer = event['importer'];
  final claim = QsoClaim.tryParse(event['claim']);
  if (program is! String || program.isEmpty || importer is! String || claim == null) return null;
  final at = (event['claim'] as Map)['at'];
  return (program: program, importer: importer, claim: claim, atMillis: at is num ? at.toInt() : null);
}

/// The namespace every slot uuid is derived under. Changing it re-keys every
/// claim on every device.
const _claimNamespace = '2a09adcc-13c1-4b3c-956e-9d6397072ff4';

/// The deterministic uuid of one source's row for one slot (claims.md §5):
/// every device computing the same slot writes the same row. The name is the
/// slot's parts as a JSON array, so no character a ref or holder may contain
/// can make two slots collide.
String claimUuid({
  required String program,
  required String holder,
  required String edition,
  required String ref,
  required String? band,
  required String? mode,
  String source = kClaimSourceLog,
}) => const Uuid().v5(_claimNamespace, jsonEncode([program, holder, edition, ref, band, mode, source]));

/// A claim as the `claims` table keeps it: one source's best for one slot.
class StoredClaim {
  const StoredClaim({
    required this.uuid,
    required this.program,
    required this.holder,
    required this.edition,
    required this.ref,
    required this.band,
    required this.mode,
    required this.source,
    required this.level,
    required this.atMillis,
    required this.qso,
    required this.version,
    required this.epoch,
    this.data = const {},
    this.deleted = false,
    this.updatedAtMillis,
  });

  /// The `log` row [claim] from contact [qso], made at [atMillis], makes.
  factory StoredClaim.fromQso({
    required String program,
    required int version,
    required QsoClaim claim,
    required String qso,
    required int? atMillis,
    int epoch = 0,
  }) => StoredClaim(
    uuid: claimUuid(program: program, holder: claim.holder, edition: claim.edition, ref: claim.ref, band: claim.band, mode: claim.mode),
    program: program,
    holder: claim.holder,
    edition: claim.edition,
    ref: claim.ref,
    band: claim.band,
    mode: claim.mode,
    source: kClaimSourceLog,
    level: claim.level,
    atMillis: atMillis,
    qso: qso,
    version: version,
    epoch: epoch,
    data: {'by': ?claim.by, 'label': ?claim.label, if (claim.guess) 'guess': true},
  );

  final String uuid;
  final String program;
  final String holder;
  final String edition;
  final String ref;
  final String? band;
  final String? mode;
  final String source;
  final ClaimLevel level;

  /// When the claiming contact happened; null when an import did not say.
  final int? atMillis;

  /// The claiming contact; null for an import that matched none.
  final String? qso;

  /// The program version that computed this row.
  final int version;

  /// Raised by a rescan; outranks the claim itself on merge (claims.md §7).
  final int epoch;

  /// `by`, `label`, `guess`, and an import's own fields.
  final Map<String, dynamic> data;
  final bool deleted;
  final int? updatedAtMillis;

  String? get by => data['by'] is String ? data['by'] as String : null;
  String? get label => data['label'] is String ? data['label'] as String : null;
  bool get guess => data['guess'] == true;

  StoredClaim copyWith({int? epoch, bool? deleted, int? updatedAtMillis}) => StoredClaim(
    uuid: uuid,
    program: program,
    holder: holder,
    edition: edition,
    ref: ref,
    band: band,
    mode: mode,
    source: source,
    level: level,
    atMillis: atMillis,
    qso: qso,
    version: version,
    epoch: epoch ?? this.epoch,
    data: data,
    deleted: deleted ?? this.deleted,
    updatedAtMillis: updatedAtMillis ?? this.updatedAtMillis,
  );

  /// Whether [other] says the same thing about the slot: the same contact at
  /// the same level, with the same details, from the same program version.
  /// Epoch and stamps are bookkeeping, not content.
  bool sameContentAs(StoredClaim other) =>
      other.uuid == uuid &&
      other.level == level &&
      other.atMillis == atMillis &&
      other.qso == qso &&
      other.version == version &&
      other.deleted == deleted &&
      jsonEncode(withSortedKeys(other.data)) == jsonEncode(withSortedKeys(data));

  /// The record shape claims travel in.
  Map<String, dynamic> toRecord() => {
    'uuid': uuid,
    'program': program,
    'holder': holder,
    'edition': edition,
    'ref': ref,
    'band': band,
    'mode': mode,
    'source': source,
    'level': level.name,
    'atMillis': atMillis,
    'qso': qso,
    'version': version,
    'epoch': epoch,
    'data': data,
    'deleted': deleted,
    'updatedAtMillis': updatedAtMillis,
  };

  /// Null for a record that is not a claim, or whose uuid is not its slot's:
  /// a row filed under the wrong uuid would sit beside the slot's real row
  /// and never be merged with it.
  static StoredClaim? tryParseRecord(Object? json) {
    if (json is! Map) return null;
    String? str(String key) => json[key] is String ? json[key] as String : null;
    int? integer(String key) => json[key] is int ? json[key] as int : (json[key] is num ? (json[key] as num).toInt() : null);
    final uuid = str('uuid'), program = str('program'), holder = str('holder'), ref = str('ref'), source = str('source');
    final edition = str('edition') ?? '';
    final band = str('band'), mode = str('mode');
    final level = ClaimLevel.tryParse(json['level']);
    final version = integer('version');
    if (uuid == null || program == null || holder == null || ref == null || source == null || level == null || version == null) return null;
    if (claimUuid(program: program, holder: holder, edition: edition, ref: ref, band: band, mode: mode, source: source) != uuid) return null;
    final data = json['data'];
    return StoredClaim(
      uuid: uuid,
      program: program,
      holder: holder,
      edition: edition,
      ref: ref,
      band: band,
      mode: mode,
      source: source,
      level: level,
      atMillis: integer('atMillis'),
      qso: str('qso'),
      version: version,
      epoch: integer('epoch') ?? 0,
      data: data is Map ? data.cast<String, dynamic>() : const {},
      deleted: json['deleted'] == true,
      updatedAtMillis: integer('updatedAtMillis'),
    );
  }

  @override
  String toString() =>
      'StoredClaim($program $holder ${edition.isEmpty ? '-' : edition} $ref ${band ?? '*'} ${mode ?? '*'} ${level.name} by $qso @$epoch${deleted ? ' deleted' : ''})';
}

/// The slot rule (claims.md §1): positive when [a] is the better claim for
/// its slot. A higher level wins even when its contact came later; within a
/// level the earlier contact wins, and a claim that does not say when loses
/// to one that does; the contact's uuid breaks what is left, so every device
/// picks the same one.
int compareClaims(StoredClaim a, StoredClaim b) {
  final level = a.level.index - b.level.index;
  if (level != 0) return level;
  final aAt = a.atMillis, bAt = b.atMillis;
  if (aAt != bAt) {
    if (aAt == null) return -1;
    if (bAt == null) return 1;
    return bAt.compareTo(aAt);
  }
  final aQso = a.qso, bQso = b.qso;
  if (aQso == bQso) return 0;
  if (aQso == null) return -1;
  if (bQso == null) return 1;
  return bQso.compareTo(aQso);
}

/// The merge rule for one slot's row (claims.md §7): positive when [a] should
/// be kept over [b]. The higher epoch wins, since only a rescan raises it and
/// that is how a deliberate downgrade gets through; at the same epoch a live
/// claim beats a withdrawn one, then the slot rule decides, then the newer
/// write (the same claim, recomputed with a new label or program version).
/// Zero only for two rows that say the same thing.
int compareClaimRows(StoredClaim a, StoredClaim b) {
  if (a.epoch != b.epoch) return a.epoch.compareTo(b.epoch);
  if (a.deleted != b.deleted) return a.deleted ? -1 : 1;
  final rule = compareClaims(a, b);
  if (rule != 0) return rule;
  return (a.updatedAtMillis ?? 0).compareTo(b.updatedAtMillis ?? 0);
}

/// [value] with every map's keys in order, for comparing content: a row that
/// went through a server can come back with the same data in another order.
Object? withSortedKeys(Object? value) => switch (value) {
  Map() => {for (final key in value.keys.map((k) => '$k').toList()..sort()) key: withSortedKeys(value[key])},
  List() => [for (final item in value) withSortedKeys(item)],
  _ => value,
};

/// The keys that say where a station was: one statement about one place
/// (docs/design/locations.md), copied together or not at all.
const _placeKeys = ['grid', 'gridSource', 'lat', 'lon'];

/// A placeholder pair ([isPlaceholderLocation]) is no place: counted as one,
/// it would keep the operation's real place off a contact that every reader
/// then finds unlocated.
bool _hasPlace(Map<String, dynamic> side) {
  final grid = side['grid'];
  return (grid is String && grid.isNotEmpty) || locationFromLatLon(side['lat'], side['lon']) != null;
}

/// [side] — a contact's `our`, or a station a program is asked about — with
/// the place [from] states, an operation's data, when it states none of its
/// own. A program whose holder is a call at a place reads it there
/// (claims.md §3), and a contact made in an operation records no place: its
/// operation does.
Map<String, dynamic> withPlaceFrom(Map<String, dynamic> side, Map<String, dynamic> from) {
  if (_hasPlace(side) || !_hasPlace(from)) return side;
  // The side's own place keys go even though it has no place: a placeholder
  // pair left beside the operation's grid would outrank it for any program
  // reading the station raw.
  return {
    for (final MapEntry(:key, :value) in side.entries)
      if (!_placeKeys.contains(key)) key: value,
    for (final key in _placeKeys)
      if (from[key] != null && from[key] != '') key: from[key],
  };
}

/// The station [operation]'s contacts are made from, as a program is asked
/// about it: its first call — the one the logging controls stamp on each
/// contact, since `stationCall` can hold several, and a holder built from
/// the whole field is one no contact claims under — at the operation's place.
Map<String, dynamic> stationOfOperation(Operation operation) => withPlaceFrom({'call': operation.stationCalls.firstOrNull ?? ''}, operation.data);
