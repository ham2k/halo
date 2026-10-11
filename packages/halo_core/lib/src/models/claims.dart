// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What a `chasing` program says a contact counts toward, as the host reads it
// off the bridge (docs/design/claims.md). The SDK's `ChasingProgram`,
// `QsoClaim` and `ClaimLevel` (extensions/sdk/src/types.ts) are the other half.

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
  const ChasingProgram({required this.key, required this.label, required this.version, required this.editions, this.icon, this.color});

  final String key;
  final String label;
  final int version;
  final ChasingEditions editions;
  final String? icon;
  final String? color;

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
    return ChasingProgram(
      key: key,
      label: label,
      version: version,
      editions: editions,
      icon: icon is String ? icon : null,
      color: color is String ? color : null,
    );
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
