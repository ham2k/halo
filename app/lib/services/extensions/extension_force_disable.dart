// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Extensions the flags server force-disables (docs/design/extension-install.md,
// "Pulling an extension") — the fast way to stop an installed extension
// running, for one version or for every one, without waiting on a catalog
// deploy or the once-a-day update check.
//
// Two reads, because the full refresh arrives only after the runtime is up.
// Before the first start, the boot takes the list the last complete refresh
// kept and adds whatever `defaults.json` says now ([forceDisabledBeforeStart]);
// the start waits for it, so an extension that breaks the start can be
// stopped on the very launch it would break. Then a COMPLETE refresh
// ([applyForceDisabledFlags]) replaces the list, and a key that leaves it runs
// again. Only a complete one: an entry lives in whichever file names it, and
// a round missing a file cannot tell a lifted entry from one it did not read.

import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:halo_i18n/halo_i18n.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'extension_info.dart';
import '../settings_service.dart';
import '../status_bar_service.dart';

/// The flags key, in `defaults.json` or any per-entity or per-call file: a
/// list of `{key, versions?, note?}`.
const kForceDisabledFlag = 'halo-extensions-disabled';

/// Where the kept list lives (`SettingsService.extensionForceDisabled`) —
/// named here because the boot reads it before SettingsService exists.
const kForceDisabledPrefsKey = 'extensionForceDisabled';

/// One key the flags force-disable. [versions] null is every version.
class ExtensionForceDisable {
  final Set<String>? versions;
  final String note;

  const ExtensionForceDisable({this.versions, this.note = ''});

  /// Whether this covers [version]. An extension with no version is covered
  /// only by an entry naming none: there is nothing to match a list against.
  bool covers(String? version) => versions == null || (version != null && versions!.contains(version));

  Map<String, dynamic> toJson() => {'note': note, 'versions': ?versions?.toList()};

  /// Null for an entry it cannot read — including a `versions` that is there
  /// and not a list. Read as absent, `"versions": "1.2.3"` would stop every
  /// version where its author meant one.
  static ExtensionForceDisable? fromJson(Object? json) {
    if (json is! Map) return null;
    final versions = json['versions'];
    if (versions != null && versions is! List) return null;
    return ExtensionForceDisable(
      versions: versions is List ? {...versions.whereType<String>()} : null,
      note: json['note'] is String ? json['note'] as String : '',
    );
  }

  /// Both at once: an entry naming no versions covers them all, whatever the
  /// other lists, and the first note that says anything is the one kept.
  ExtensionForceDisable combinedWith(ExtensionForceDisable other) => ExtensionForceDisable(
    versions: versions == null || other.versions == null ? null : {...versions!, ...other.versions!},
    note: note.isNotEmpty ? note : other.note,
  );

  @override
  bool operator ==(Object other) => other is ExtensionForceDisable && other.note == note && _sameVersions(other.versions, versions);

  @override
  int get hashCode => Object.hash(note, versions == null ? null : Object.hashAllUnordered(versions!));

  static bool _sameVersions(Set<String>? a, Set<String>? b) => a == null || b == null ? a == b : a.length == b.length && a.containsAll(b);
}

/// The flags' list, by key. Lenient per entry: one it cannot read is dropped
/// rather than costing the others.
///
/// Several entries for one key combine — the merged flags concatenate lists,
/// so `defaults.json` and a per-call file can each name the same key.
Map<String, ExtensionForceDisable> parseForceDisabled(Object? raw) {
  final result = <String, ExtensionForceDisable>{};
  if (raw is! List) return result;
  for (final item in raw) {
    if (item is! Map || item['key'] is! String || (item['key'] as String).isEmpty) continue;
    final entry = ExtensionForceDisable.fromJson(item);
    if (entry == null) continue;
    final key = item['key'] as String;
    result[key] = result[key]?.combinedWith(entry) ?? entry;
  }
  return result;
}

/// Every key either list names, combined where both do.
Map<String, ExtensionForceDisable> combineForceDisabled(Map<String, ExtensionForceDisable> a, Map<String, ExtensionForceDisable> b) => {
  ...a,
  for (final MapEntry(:key, :value) in b.entries) key: a[key]?.combinedWith(value) ?? value,
};

/// The kept list as stored under [kForceDisabledPrefsKey]; anything
/// unreadable reads as empty.
Map<String, ExtensionForceDisable> forceDisabledFromJson(Map<String, dynamic> json) => {
  for (final e in json.entries) e.key: ?ExtensionForceDisable.fromJson(e.value),
};

/// What the flags force-disable as the boot knows it before the first runtime
/// start: the kept list, with whatever [fetchDefaults] — `defaults.json`, on a
/// short timeout — says now. Never throws: a boot that cannot read either
/// still starts, on what it could.
Future<Map<String, ExtensionForceDisable>> forceDisabledBeforeStart({required Future<Map<String, dynamic>?> Function() fetchDefaults}) async {
  var kept = const <String, ExtensionForceDisable>{};
  try {
    final raw = (await SharedPreferences.getInstance()).getString(kForceDisabledPrefsKey);
    final decoded = raw == null ? null : jsonDecode(raw);
    if (decoded is Map<String, dynamic>) kept = forceDisabledFromJson(decoded);
  } catch (e) {
    debugPrint('[extensions] kept force-disable list unreadable: $e');
  }
  final fetched = await fetchDefaults();
  return fetched == null ? kept : combineForceDisabled(kept, parseForceDisabled(fetched[kForceDisabledFlag]));
}

/// Whether the INSTALLED [info] is one the flags force-disable — in the kept
/// list, or in [early], what the boot read before settings were wired in. A
/// core extension never is: it is the app's own code, and a release or a code
/// push is what fixes it.
bool isBundleForceDisabled(SettingsService? settings, ExtensionInfo info, {Map<String, ExtensionForceDisable> early = const {}}) {
  if (!info.isInstalled) return false;
  return (settings?.extensionForceDisabled[info.key]?.covers(info.version) ?? false) || (early[info.key]?.covers(info.version) ?? false);
}

/// The status-bar notice saying [key] was force-disabled.
String forceDisabledNoticeKey(String key) => 'extensions:forceDisabled:$key';

/// Adds what the boot read before the first start to the kept list, so an
/// offline launch after one that crashed still has it. Never lifts anything,
/// and tells nobody: the list of what is installed is not read yet, and the
/// complete refresh that follows does both.
Future<void> keepForceDisabledFromBoot(SettingsService settings, Map<String, ExtensionForceDisable> early) async {
  final kept = settings.extensionForceDisabled;
  final merged = combineForceDisabled(kept, early);
  if (!_sameList(merged, kept)) await settings.setExtensionForceDisabled(merged);
}

/// Replaces the kept list with what a COMPLETE refresh's [flags] force-disable,
/// tells the operator once for each installed extension it stops, and
/// re-applies which extensions load when the list changed.
///
/// Who has been told is a record of its own
/// (`SettingsService.extensionForceDisabledTold`), not a difference between
/// the old list and the new one: the boot's read can put an entry on the list
/// before anything knows what is installed, and an extension installed later
/// is told about on the next refresh. An extension the operator had already
/// switched off is told all the same, and would otherwise never hear why its
/// switch has gone.
Future<void> applyForceDisabledFlags({
  required Map<String, dynamic> flags,
  required SettingsService settings,
  required StatusBarService statusBar,
  required List<ExtensionInfo> available,
  required Future<void> Function() applyAvailability,
}) async {
  final next = parseForceDisabled(flags[kForceDisabledFlag]);
  final changed = !_sameList(next, settings.extensionForceDisabled);
  if (changed) await settings.setExtensionForceDisabled(next);

  final stopped = {
    for (final info in available)
      if (info.isInstalled && (next[info.key]?.covers(info.version) ?? false)) info.key: info,
  };
  final told = settings.extensionForceDisabledTold;
  final locale = LocaleSettings.currentLocale.languageCode;
  for (final info in stopped.values) {
    if (told.contains(info.key)) continue;
    final note = next[info.key]!.note;
    statusBar.showNotice(
      key: forceDisabledNoticeKey(info.key),
      icon: 'alert',
      title: t.extensionsPanel.forceDisabledTitle(name: info.nameFor(locale)),
      text: [t.extensionsPanel.forceDisabledBody, if (note.isNotEmpty) note].join(' '),
    );
  }
  for (final key in told) {
    if (!stopped.containsKey(key)) statusBar.dismissNotice(forceDisabledNoticeKey(key));
  }
  if (told.length != stopped.length || !told.containsAll(stopped.keys)) await settings.setExtensionForceDisabledTold(stopped.keys.toSet());

  if (changed) await applyAvailability();
}

bool _sameList(Map<String, ExtensionForceDisable> a, Map<String, ExtensionForceDisable> b) =>
    a.length == b.length && a.entries.every((e) => b[e.key] == e.value);
