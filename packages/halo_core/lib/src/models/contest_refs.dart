// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What tells an extension a contest's operation from an activity's: each ref
// a running `contest` extension handles carries `contest: true` (`Ref.contest`,
// extensions/sdk/src/types.ts). The app and halo-ext both mark what they hand
// an extension through these, so the two cannot answer differently.

import '../hook_names.dart';

/// The one of [running], in its order, whose declared hooks handle ref
/// [type]: `ref:<type>`, or a `ref:<type>/…` one. Null for a type no running
/// extension handles.
T? refTypeOwner<T>(Iterable<T> running, Iterable<String> Function(T extension) hooksOf, Object? type) {
  if (type is! String) return null;
  bool declares(String hook) {
    final declared = Hooks.refTypeOf(hook);
    return declared == type || (declared?.startsWith('$type/') ?? false);
  }

  for (final extension in running) {
    if (hooksOf(extension).any(declares)) return extension;
  }
  return null;
}

/// [operation] with each ref whose type [isContest] says is a contest's
/// marked `contest: true`, and no other: a mark a record kept from before its
/// contest extension stopped is taken away. [operation] itself when every
/// ref is already as it should be.
Map<String, dynamic> contestMarkedOperation(Map<String, dynamic> operation, bool Function(Object? type) isContest) {
  final refs = operation['refs'];
  if (refs is! List) return operation;
  bool misread(Object? ref) => ref is Map && (ref['contest'] == true) != isContest(ref['type']);
  if (!refs.any(misread)) return operation;
  return {
    ...operation,
    'refs': [
      for (final ref in refs)
        if (!misread(ref)) ref else if (isContest((ref as Map)['type'])) {...ref, 'contest': true} else Map.of(ref)..remove('contest'),
    ],
  };
}

/// A hook call's [args] with the refs of their `operation`, and of each of
/// their `segments`' operations, marked as [contestMarkedOperation] marks
/// them. [args] itself when nothing changes, which is every call that hands
/// over no contest: the filter runs on every hook call, a batch of lookups
/// hundreds of times over.
Map<String, dynamic> contestMarkedArgs(Map<String, dynamic> args, bool Function(Object? type) isContest) {
  // A cast is a new wrapper, never the map itself, and an operation marked
  // nowhere must come back as the same object.
  Object? marked(Object? operation) {
    if (operation is Map<String, dynamic>) return contestMarkedOperation(operation, isContest);
    if (operation is! Map) return operation;
    final cast = operation.cast<String, dynamic>();
    final result = contestMarkedOperation(cast, isContest);
    return identical(result, cast) ? operation : result;
  }

  final operation = args['operation'];
  final markedOperation = marked(operation);
  final segments = args['segments'];
  List<Object?>? markedSegments;
  if (segments is List) {
    var any = false;
    final each = <Object?>[];
    for (final segment in segments) {
      final segmentOperation = segment is Map ? segment['operation'] : null;
      final markedSegment = marked(segmentOperation);
      if (segment is Map && !identical(markedSegment, segmentOperation)) {
        each.add({...segment, 'operation': markedSegment});
        any = true;
      } else {
        each.add(segment);
      }
    }
    if (any) markedSegments = each;
  }
  if (identical(markedOperation, operation) && markedSegments == null) return args;
  return {...args, if (!identical(markedOperation, operation)) 'operation': markedOperation, 'segments': ?markedSegments};
}
