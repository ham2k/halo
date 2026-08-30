// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Export flow: the extension runtime generates each file's content (export
// hooks are extension territory, one `suggestExportOptions` call lists what's
// available, one `generateExport` call per selection produces it), the core
// owns file I/O and the save dialog/share sheet. One coarse bridge call per
// hook carries the whole operation.

import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Rect;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:halo_core/halo_core.dart';

import 'android_file_save.dart';
import 'extension_service.dart';
import 'settings_service.dart';
import 'web_download.dart';

class ExportException implements Exception {
  final String message;
  ExportException(this.message);

  @override
  String toString() => message;
}

class ExportService {
  final ExtensionService extensions;
  final QsosRepository qsos;
  final SettingsService settings;

  /// Android's save flow, injectable so tests can drive it without a platform
  /// channel.
  final AndroidFileSave androidFileSave;

  ExportService({
    required this.extensions,
    required this.qsos,
    required this.settings,
    this.androidFileSave = const AndroidFileSave(),
  });

  /// Raw QSON dump (the same payload every hook receives), offered only in
  /// developer mode — same as app-polo's devMode extension. Generated here in
  /// Dart, no extension involved.
  static const _qsonHookKey = 'core-devmode';
  static const _qsonExportType = 'devmode-qson';

  /// Whether [option] is that dump. Public because the panel marks it in the
  /// dev-mode accent, which is a theme colour rather than the hex string an
  /// extension declares — so the option map can't carry it.
  bool isQsonOption(Map<String, dynamic> option) =>
      option['hookKey'] == _qsonHookKey && option['exportType'] == _qsonExportType;

  Map<String, dynamic> _qsonOptionFor(Operation operation) {
    final date = (operation.startAtMax ?? nowUtc()).toIso8601String().substring(0, 10);
    // The FIRST call, not the raw `stationCall` field: a multi-operator
    // operation holds "N0CALL, W1AW" there, and the comma and space would
    // land verbatim in the filename.
    final call = operation.stationCalls.first.replaceAll('/', '-');
    final shortUuid = operation.uuid.split('-').first;
    // The two forms the extension SDK's `exportFilename` produces, spelled
    // out here because this option never crosses the bridge. The uuid stays
    // in both: two dumps of the same operation on the same day are exactly
    // what a developer comparing them needs to tell apart.
    final filename = settings.useCompactFileNames
        ? '$call-${date.replaceAll('-', '')}-$shortUuid.qson'
        : '$date $call $shortUuid.qson';
    return {
      'hookKey': _qsonHookKey,
      'exportType': _qsonExportType,
      // Tagged with a callsign like every other option, even though the dump
      // itself is the whole operation. Untagged, it lands in a group of its
      // own keyed '' — which makes a perfectly ordinary single-station
      // operation look multi-station to the panel the moment developer mode
      // is on: callsign headers appear, the batch button moves, and the dump
      // gets a header of its own titled "Export".
      'stationCall': operation.stationCalls.first,
      'label': 'Developer Mode: QSON Export',
      'filename': filename,
      'icon': 'briefcase-upload',
      'priority': -100,
      'selectedByDefault': false,
    };
  }

  /// The operation's contacts, and its segments.
  ///
  /// The segments are resolved from the FULL list, because the `break`/`start`
  /// event rows carrying the overrides are exactly what the contact list
  /// filters out (docs/design/contests.md §5.1.3) — the same trap
  /// `ScoringService.rescoreOperation` documents.
  Future<({List<Qso> qsos, SegmentedOperation segmented})> _logFor(Operation operation) async {
    final log = await _logOrNothing(operation);
    if (log == null) {
      throw ExportException('Nothing to export: this operation has no QSOs.');
    }
    return log;
  }

  /// The same log, with an empty one reported as null rather than thrown.
  ///
  /// Asking what an operation COULD export is a question an empty log
  /// answers — with nothing — where actually exporting one is a request it
  /// has to refuse. Thrown for both, the panel greets an operator whose only
  /// mistake was opening it before their first contact with "Export failed".
  Future<({List<Qso> qsos, SegmentedOperation segmented})?> _logOrNothing(Operation operation) async {
    final all = await qsos.watchForOperation(operation.uuid).first;
    final qsoList = all.where((q) => !q.isEvent).toList();
    if (qsoList.isEmpty) return null;
    return (qsos: qsoList, segmented: SegmentedOperation.from(operation: operation.data, qsos: all));
  }

  /// The QSOs one export is responsible for.
  ///
  /// An option naming a `refType` covers only the stretches where that activity
  /// was actually running — the segments carrying a ref of that type (§5.1.4).
  /// A contest that started at a break would otherwise put the whole operation
  /// into its Cabrillo, including the contacts made before it began: a false
  /// claim in a submitted file, and the same mistake the scorer made before
  /// §5.1.3 gated it.
  ///
  /// An option with no `refType` — the full ADIF — takes the whole log. So does
  /// an unsegmented operation, where every QSO is in the one segment and this
  /// is identity.
  ///
  /// Several refs of one type (two parks) union rather than picking one: until
  /// a per-REFERENCE export exists (§5.1.4's other half, which nothing yet
  /// needs), one export covers the type, and quietly dropping half the log
  /// would be worse than covering both.
  List<Qso> _qsosForOption(
    Map<String, dynamic> option,
    List<Qso> qsoList,
    SegmentedOperation segmented,
  ) {
    final refType = option['refType'];
    if (refType is! String || refType.isEmpty) return qsoList;

    final refs = segmented.allRefs.where((ref) => ref['type'] == refType).toList();
    // Offered for an operation that doesn't carry the ref at all: leave the log
    // alone rather than writing an empty file over a hook's own judgement.
    if (refs.isEmpty) return qsoList;

    final keep = <String>{
      for (final ref in refs)
        for (final qso in segmented.qsosFor(qsoList, ref)) qso.uuid,
    };
    final scoped = [
      for (final qso in qsoList)
        if (keep.contains(qso.uuid)) qso,
    ];

    // Same promise as the bail-out above, and it has to be made here too: a ref
    // can be on the operation while every segment override omits it, and then
    // the slice comes back EMPTY rather than absent.
    //
    // That state means the segments and the operation disagree, and today it
    // comes from HaLo itself — the Activities view writes `operation.refs` with
    // no segment bookkeeping, because there is no segment UI yet (§5.1.3), so
    // turning an activity on for a polo-synced log produces exactly it. An
    // empty submission file is the worse failure of the two: the operator gets
    // a Cabrillo with no QSOs in it and no indication why, while an over-broad
    // one is visible in the file and can be pruned. So the whole log wins until
    // segments are something the app maintains rather than only imports.
    return scoped.isEmpty ? qsoList : scoped;
  }

  /// The log as ONE station callsign sees it.
  ///
  /// A multi-operator operation is logged once and owes each callsign its own
  /// submission, so every QSO is claimed by whichever call is exporting —
  /// `our.call` is rewritten rather than filtered, which is what app-polo does
  /// (`generateExports.js:26`) and the only reading that produces a complete
  /// log per operator.
  ///
  /// The exception is the two of them working each other: after the rewrite
  /// that QSO says N0DEV worked N0DEV, which no program will accept and which
  /// polo drops for the same reason.
  List<Map<String, dynamic>> _qsosAs(String stationCall, List<Qso> qsoList) {
    return [
      for (final qso in qsoList)
        () {
          final data = {...qso.data};
          final our = {...?asQsonMap(data['our'])};
          final theirCall = asQsonString(asQsonMap(data['their'])?['call'])?.toUpperCase();
          our['call'] = stationCall;
          data['our'] = our;
          return theirCall == stationCall.toUpperCase() ? null : data;
        }(),
    ].whereType<Map<String, dynamic>>().toList();
  }

  /// The QSON payload for one station callsign.
  ///
  /// With ONE callsign — the overwhelming case — this is exactly
  /// [qsonPayloadFor] and nothing else: the log is already that station's, so
  /// there is nothing to reassign and nothing to leave out. Claiming and
  /// filtering here would mean a QSO the operator made with their own other
  /// rig silently vanishing from every file, the whole-log backup included.
  ///
  /// With SEVERAL, the operation is cloned to carry only the one call so the
  /// hooks see a single-station operation — every filename, ADIF
  /// `STATION_CALLSIGN` and Cabrillo `CALLSIGN` then names the call whose
  /// file it is, and none of them need to know about the fan-out.
  Map<String, dynamic> _payloadAs(
    String stationCall,
    Operation operation,
    List<Qso> qsoList,
  ) {
    final payload = qsonPayloadFor(operation: operation, qsos: qsoList);
    if (operation.stationCalls.length < 2) return payload;
    (payload['operation'] as Map<String, dynamic>)['stationCall'] = stationCall;
    payload['qsos'] = _qsosAs(stationCall, qsoList);
    return payload;
  }

  /// Every export option offered by every extension for this operation, for
  /// the Exports Panel's checkbox list.
  ///
  /// Asked once PER STATION CALLSIGN ([Operation.stationCalls]), because each
  /// call owes its own set of files; every option is tagged with the call it
  /// belongs to so the panel can group them and `generateExports` can rebuild
  /// the same payload.
  Future<List<Map<String, dynamic>>> getExportOptions(Operation operation) async {
    final log = await _logOrNothing(operation);
    // GROWABLE, not `const []`: the panel sorts what it gets by priority, and
    // `sort` on an unmodifiable list throws whatever its length — turning the
    // empty answer this exists to give into a worse failure than the one it
    // replaced.
    if (log == null) return <Map<String, dynamic>>[];
    final calls = operation.stationCalls;

    final perCall = await Future.wait(calls.map((call) async {
      final payload = _payloadAs(call, operation, log.qsos);

      // Hooks are asked about every ref ANY segment carries, not just the base's.
      // Each contest's `suggestExportOptions` opens with
      // `if (!refOfType(args.operation, TYPE)) return []`, so a contest that
      // ended at a break — its ref living on in the segments while the operation
      // has moved on — would otherwise be offered no Cabrillo at all, for a log
      // that is half contest QSOs.
      //
      // The same asymmetry `ScoringService` fixed for scorers by handing
      // `scorersFor` the segments (§5.1.3): an operation is scored as a contest
      // it can no longer be exported as, which is worse than either alone.
      if (log.segmented.isSegmented) {
        (payload['operation'] as Map<String, dynamic>)['refs'] = log.segmented.allRefs;
      }

      final options = await extensions.getExportOptions({
        ...payload,
        'compactFilenames': settings.useCompactFileNames,
      });
      return [
        for (final option in options) {...option, 'stationCall': call},
      ];
    }));

    final options = [for (final group in perCall) ...group];
    if (settings.developerMode) {
      // ONE dump for the whole operation, not one per call: it exists to show
      // what the hooks were given, and the fan-out is exactly what it would
      // hide by splitting.
      return [...options, _qsonOptionFor(operation)];
    }
    return options;
  }

  /// Generates file content for the given (previously listed) options.
  /// Returns one `{filename, mimeType, content}` map per option, in the same
  /// order.
  Future<List<Map<String, dynamic>>> generateExports(
    Operation operation,
    List<Map<String, dynamic>> selectedOptions,
  ) async {
    final host = extensions.host;
    if (host == null && selectedOptions.any((o) => !isQsonOption(o))) {
      throw ExportException('Extension runtime is not ready yet — try again in a moment.');
    }
    final log = await _logFor(operation);
    // The developer QSON dump is the raw log, deliberately unsliced — it exists
    // to show what the hooks were given for the operation as a whole.
    final payload = qsonPayloadFor(operation: operation, qsos: log.qsos);

    // Independent per-option calls (each produces its own file) — no
    // ordering dependency, so run them concurrently rather than paying for
    // N sequential bridge round-trips.
    final results = await Future.wait(selectedOptions.map((option) async {
      if (isQsonOption(option)) {
        return {
          'filename': _qsonOptionFor(operation)['filename'],
          'mimeType': 'application/json',
          'content': jsonEncode(payload),
        };
      }
      final scoped = _qsosForOption(option, log.qsos, log.segmented);
      // Rebuilt for the SAME call the option was listed under, so the file
      // matches what the panel offered. Falling back to the operation's first
      // call covers an option that predates the fan-out (or a caller passing
      // one by hand, as the tests do).
      final call = option['stationCall'] as String? ?? operation.stationCalls.first;
      final args = _payloadAs(call, operation, scoped);
      // Same reason `getExportOptions` patches the refs above: a hook offered an
      // option off a ref that lives only in a segment has to be able to READ
      // that ref when it writes the file. Without it the two halves of one
      // contract see different operations — the option is offered, then
      // generated against a base operation that no longer carries the activity.
      // For a contest that produced a file with no content and no name; for
      // `activityExportHook`, which throws when it can't find the reference its
      // exportType names, it produces an outright export failure.
      //
      // NARROWER than the options call, deliberately. That one has to show every
      // hook every ref, since it is asking who has anything to offer. Here the
      // option has already named the type it covers, so only that type's segment
      // refs are added, on top of the operation's own. Swapping in the whole set
      // would hand a plain ADIF — no refType at all — every segment's refs, and
      // `adifFields` would stamp a later segment's park onto every earlier QSO.
      final optionRefType = option['refType'];
      if (log.segmented.isSegmented && optionRefType is String && optionRefType.isNotEmpty) {
        final refs = [...?(args['operation'] as Map<String, dynamic>)['refs'] as List?];
        final present = {
          for (final ref in refs)
            if (ref is Map) '${ref['type']}\u0000${ref['ref']}',
        };
        for (final ref in log.segmented.allRefs.where((r) => r['type'] == optionRefType)) {
          if (present.add('${ref['type']}\u0000${ref['ref']}')) refs.add(ref);
        }
        (args['operation'] as Map<String, dynamic>)['refs'] = refs;
      }
      final result = await host!.invokeHook(
        'export',
        key: option['hookKey'] as String?,
        method: 'generateExport',
        args: {
          ...args,
          'exportType': option['exportType'],
          'compactFilenames': settings.useCompactFileNames,
          // The whole-log backup opts out of the setting entirely (it is the
          // copy the operator keeps); everything else — the files that get
          // uploaded — respects it.
          'includePrivateData':
              option['alwaysIncludePrivateData'] == true || settings.includePrivateData,
        },
        timeout: const Duration(seconds: 30),
      ) as Map;
      final file = result.cast<String, dynamic>();

      // The panel already showed the operator a filename — the one the option
      // carried — so that is the name the file gets. A hook recomputing it
      // sees a DIFFERENT input: `generateExport` is handed only the QSOs its
      // refType covers, so a park activated after a break dates its file from
      // the first contact after the break, while the listing dated it from the
      // start of the log. Both are defensible; disagreeing in front of the
      // user is not.
      final offered = option['filename'];
      if (offered is String && offered.isNotEmpty) {
        return {...file, 'filename': offered};
      }
      return file;
    }));
    return results;
  }

  /// Disambiguates filenames that collide (two selected results sharing a
  /// name, or both missing one) before writing — a later hook's export
  /// would otherwise silently overwrite an earlier one on disk.
  List<String> _uniqueFilenames(List<Map<String, dynamic>> files) {
    final seen = <String, int>{};
    return [
      for (final file in files)
        () {
          final base = (file['filename'] as String?)?.isNotEmpty == true ? file['filename'] as String : 'export.txt';
          final count = seen.update(base, (n) => n + 1, ifAbsent: () => 1);
          if (count == 1) return base;
          final ext = p.extension(base);
          final stem = base.substring(0, base.length - ext.length);
          return '$stem-$count$ext';
        }(),
    ];
  }

  /// Save flow: on desktop a single file opens a save dialog for that file and
  /// multiple files open a directory picker; on Android every file gets its own
  /// dialog (see below). Returns where the files went — a path, a directory,
  /// or the names Android reported — with HOW MANY actually landed, or null if
  /// the operator saved nothing.
  ///
  /// The count comes from here rather than from the caller's list because only
  /// this knows: Android's per-file dialogs can be cancelled partway, and a
  /// caller announcing "4 files saved" over two filenames sends the operator
  /// looking for two that do not exist.
  ///
  /// `namesFiles` says what `location` IS. Android's SAF never tells the app
  /// where the operator put anything, so there it is the list of FILENAMES —
  /// and a caller phrasing that as a destination says the files went to their
  /// own names. Everywhere else it is a path or a directory.
  Future<({String location, int count, bool namesFiles})?> saveToDisk(
      List<Map<String, dynamic>> files) async {
    if (files.isEmpty) return null;

    // Android has no `file_selector` save at all — `getSaveLocation` throws
    // `UnimplementedError` there, and the raw path its directory picker
    // returns is not writable under scoped storage — so the flow goes through
    // the Storage Access Framework instead ([AndroidFileSave]).
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return _saveOnAndroid(files);
    }

    if (files.length == 1) {
      final file = files.first;
      final filename = file['filename'] as String? ?? 'export.txt';
      final location = await getSaveLocation(
        suggestedName: filename,
        acceptedTypeGroups: [
          XTypeGroup(label: filename, extensions: [p.extension(filename).replaceFirst('.', '')]),
        ],
      );
      if (location == null) return null;
      // Translated the way the Android loop translates its own: a full disk or
      // a read-only folder is an answer the platform gave, which the caller
      // reports and spends. Left raw it is an unclassified FileSystemException,
      // which ErrorPolicy uploads as a crash on every retry.
      try {
        await File(location.path).writeAsString(file['content'] as String);
      } catch (e) {
        throw ExportException('$e');
      }
      return (location: location.path, count: 1, namesFiles: false);
    }

    final directory = await getDirectoryPath();
    if (directory == null) return null;
    final filenames = _uniqueFilenames(files);
    final written = <String>[];
    for (var i = 0; i < files.length; i++) {
      try {
        await File(p.join(directory, filenames[i])).writeAsString(files[i]['content'] as String);
      } catch (e) {
        // Names what already landed, as the Android loop does: a failure on
        // the third of four leaves two on disk, and an error mentioning only
        // the third sends the operator looking for files they already have.
        throw ExportException(
          written.isEmpty ? '$e' : '$e — ${written.join(', ')} had already been saved',
        );
      }
      written.add(filenames[i]);
    }
    return (location: directory, count: files.length, namesFiles: false);
  }

  /// One "create document" dialog per file, in order — app-polo's Save loop
  /// (`OperationDataScreen.jsx`), and the only shape the SAF offers that lets
  /// the operator save straight into Downloads: `ACTION_OPEN_DOCUMENT_TREE`
  /// refuses to grant that folder from Android 12 on, so a single folder
  /// picker would make them create a subfolder to get there.
  ///
  /// Reports only what actually landed. Cancelling the third of four dialogs
  /// saved three files, and a write that fails on the third leaves two on
  /// disk — the operator has to be told which, in both cases, or they go
  /// looking for files that aren't there and re-export ones that are.
  Future<({String location, int count, bool namesFiles})?> _saveOnAndroid(
      List<Map<String, dynamic>> files) async {
    final names = _uniqueFilenames(files);
    final saved = <String>[];
    for (var i = 0; i < files.length; i++) {
      final String? name;
      try {
        name = await androidFileSave.saveFile(
          filename: names[i],
          content: files[i]['content'] as String,
        );
      } catch (e) {
        throw ExportException(
          saved.isEmpty ? '$e' : '$e — ${saved.join(', ')} had already been saved',
        );
      }
      // Cancelling one dialog abandons the files still to come, rather than
      // asking again for every one of them.
      if (name == null) break;
      saved.add(name);
    }
    return saved.isEmpty ? null : (location: saved.join(', '), count: saved.length, namesFiles: true);
  }

  /// Web download flow: hands each file to the browser as its own download.
  ///
  /// Nothing here touches `dart:io` or `path_provider`, neither of which
  /// works on web — which is why this can't reuse [saveToDisk] or
  /// [shareFiles]: on web those either throw (one file: `File('')` on the
  /// dummy location `file_selector_web` returns) or silently do nothing at
  /// all (several: a null directory, which reads as a user cancel).
  ///
  /// One download per file rather than a zip: a browser will ask about the
  /// second and subsequent downloads from a page, which is a prompt the
  /// operator can answer, whereas an archive is a step they'd have to undo.
  Future<void> downloadFiles(List<Map<String, dynamic>> files) async {
    if (files.isEmpty) return;
    final filenames = _uniqueFilenames(files);
    for (var i = 0; i < files.length; i++) {
      downloadFile(
        filename: filenames[i],
        content: files[i]['content'] as String,
        mimeType: files[i]['mimeType'] as String?,
      );
    }
  }

  /// Mobile share flow: writes every file to a temp directory, then opens
  /// the native share sheet with all of them at once.
  ///
  /// Returns whether the operator actually shared. `dismissed` is the one
  /// answer that means they didn't — `unavailable` is what Android returns
  /// when the share succeeded but the chosen target can't be named, so it
  /// counts as success rather than as a failure to report.
  ///
  /// [sharePositionOrigin] anchors the share sheet, which on iPadOS is a
  /// popover: without an anchor rect, share_plus throws a PlatformException
  /// there instead of presenting anything. Other platforms ignore it.
  Future<bool> shareFiles(List<Map<String, dynamic>> files, {Rect? sharePositionOrigin}) async {
    if (files.isEmpty) return false;
    final tempDir = await getTemporaryDirectory();
    final filenames = _uniqueFilenames(files);
    final paths = <XFile>[];
    for (var i = 0; i < files.length; i++) {
      final path = p.join(tempDir.path, filenames[i]);
      await File(path).writeAsString(files[i]['content'] as String);
      paths.add(XFile(path, mimeType: files[i]['mimeType'] as String?));
    }
    final result = await SharePlus.instance.share(
      ShareParams(files: paths, sharePositionOrigin: sharePositionOrigin),
    );
    return result.status != ShareResultStatus.dismissed;
  }
}
