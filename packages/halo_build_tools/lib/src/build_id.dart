// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

/// The canonical, strictly-increasing build id: `YYMM·MMDD·S`.
///
/// See docs/releases.md §2.2. `YYMM` is the *version's* year+target month,
/// `MMDD` is the *build date* (which may fall in an earlier month than the
/// version, since a line is branded for the coming month), and `S` is a
/// single sequence digit for multiple builds on the same day.
class BuildId {
  final int versionYear;
  final int versionMonth;
  final int buildMonth;
  final int buildDay;
  final int sequence;

  const BuildId({
    required this.versionYear,
    required this.versionMonth,
    required this.buildMonth,
    required this.buildDay,
    required this.sequence,
  }) : assert(
         versionYear >= 10 && versionYear <= 99,
         'versionYear must be a two-digit YY, was $versionYear',
       ),
       assert(
         versionMonth >= 1 && versionMonth <= 12,
         'versionMonth must be 1-12, was $versionMonth',
       ),
       assert(
         buildMonth >= 1 && buildMonth <= 12,
         'buildMonth must be 1-12, was $buildMonth',
       ),
       assert(
         buildDay >= 1 && buildDay <= 31,
         'buildDay must be 1-31, was $buildDay',
       ),
       assert(
         sequence >= 1 && sequence <= 9,
         'sequence must be a single digit 1-9, was $sequence',
       );

  static String _pad2(int n) => n.toString().padLeft(2, '0');

  /// The 9-digit canonical build id, e.g. `260807291`.
  int get value => int.parse(
    '${_pad2(versionYear)}${_pad2(versionMonth)}'
    '${_pad2(buildMonth)}${_pad2(buildDay)}'
    '$sequence',
  );

  /// The Windows/Linux build part `MMDD·10 + S`, e.g. `7291` — max `12319`
  /// (Dec 31, seq 9), safely under the 65,535 per-part limit those platforms
  /// impose.
  int get windowsLinuxPart => (buildMonth * 100 + buildDay) * 10 + sequence;

  @override
  String toString() => value.toString();
}
