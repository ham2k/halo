// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart' show compileRefPattern;

import 'extensions/extension_service.dart';
import 'halo_services.dart' show CommandActionOutcome, HaLoServices;
import 'hook_payloads.dart';

extension OperationSetupActions on HaLoServices {
  Future<CommandActionOutcome?> updateOperationSetup(String uuid, Map<String, dynamic> patch) =>
      OperationSetupService(operations: operations, extensions: extensions).apply(uuid, patch);
}

class OperationSetupService {
  const OperationSetupService({required this.operations, required this.extensions});

  final OperationsRepository operations;
  final ExtensionService extensions;

  /// The target comes from the host's command or panel context. Resolve the
  /// extension's references before entering the write transaction, then merge
  /// into the row as it stands at the save.
  Future<CommandActionOutcome?> apply(String uuid, Map<String, dynamic> patch) async {
    final operation = uuid.isEmpty ? null : await operations.get(uuid);
    if (operation == null || operation.deleted) return (text: t.commands.noOperationOpen, failed: true);

    try {
      final fields = _fields(patch);
      final requests = _activationRequests(patch);
      final refs = requests.isEmpty ? const <_ActivationRef>[] : await extensions.whenSettled(() => _resolveRefs(operationPayloadFor(operation), requests));
      final rawPosition = patch['multiIdentifier']?.toString();
      final position = rawPosition == null ? null : normalizedMultiIdentifier(rawPosition);
      final operatorCall = patch['operatorCall']?.toString().trim().toUpperCase();

      final found = await operations.patchData(uuid, (current) {
        final data = {...fields};
        final localData = <String, dynamic>{};
        if (refs.isNotEmpty) {
          _addRefs(current, refs, data);
        }
        final currentPosition = multiIdentifierFor(current);
        if (position != null && position != currentPosition) {
          localData[multiIdentifierKey] = position;
        }
        if (operatorCall != null) {
          // The destination seat's call is the one this patch sets, even when
          // the same patch moves the local position there.
          final key = operatorCallKeyFor(position ?? currentPosition);
          if (operatorCall != (asQsonString(current.data[key]) ?? '').trim()) data[key] = operatorCall;
        }
        data.removeWhere((key, value) => current.data[key] == value);
        return (data: data, localData: localData);
      });
      return found ? null : (text: t.commands.noOperationOpen, failed: true);
    } on _PatchRefused catch (failure) {
      return (text: failure.message, failed: true);
    } on WriteRefused catch (failure) {
      return (text: failure.reason, failed: true);
    }
  }

  static Map<String, dynamic> _fields(Map<String, dynamic> patch) {
    final data = <String, dynamic>{};
    _readString(patch, data, 'userTitle');
    _readString(patch, data, 'notes');
    if (!patch.containsKey('location')) return data;
    final raw = patch['location'];
    if (raw is! Map) throw _PatchRefused(t.operationSetupAction.invalidLocation);

    final GridLocation? location;
    final String grid;
    if (raw.containsKey('grid')) {
      final stated = raw['grid'];
      if (stated is! String || raw.containsKey('latitude') || raw.containsKey('longitude')) {
        throw _PatchRefused(t.operationSetupAction.invalidLocation);
      }
      grid = normalizeGrid(stated.trim());
      location = isWellFormedGrid(grid) ? locationForStatedGrid(grid) : null;
      if (location == null) throw _PatchRefused(t.operationSetupAction.invalidGrid(grid: grid));
    } else {
      location = locationFromLatLon(raw['latitude'], raw['longitude']);
      if (location == null) throw _PatchRefused(t.operationSetupAction.invalidCoordinates);
      grid = locationToGrid8(location.latitude, location.longitude);
    }

    _readString(raw, data, 'state');
    _readString(raw, data, 'county');
    if (data['state'] case final String state when _stateAbbreviation.hasMatch(state)) {
      data['state'] = state.toUpperCase();
    }
    return {...data, 'grid': grid, 'gridSource': 'manual', 'lat': location.latitude, 'lon': location.longitude};
  }

  static final _stateAbbreviation = RegExp(r'^[a-zA-Z]{2}$');

  static void _readString(Map<dynamic, dynamic> source, Map<String, dynamic> data, String field) {
    if (!source.containsKey(field)) return;
    final value = source[field];
    if (value is! String) throw _PatchRefused(t.operationSetupAction.invalidField(field: field));
    data[field] = value.trim();
  }

  static List<_ActivationRequest> _activationRequests(Map<String, dynamic> patch) {
    if (!patch.containsKey('addActivationRefs')) return const [];
    final raw = patch['addActivationRefs'];
    if (raw is! List) throw _PatchRefused(t.operationSetupAction.invalidField(field: 'addActivationRefs'));
    return [
      for (final (index, item) in raw.indexed)
        if (item case {'activityKey': final String key, 'ref': final String code} when key.trim().isNotEmpty && code.trim().isNotEmpty)
          (key: key.trim().toLowerCase(), code: code.trim())
        else
          throw _PatchRefused(t.operationSetupAction.invalidRefEntry(index: index + 1)),
    ];
  }

  Future<List<_ActivationRef>> _resolveRefs(Map<String, dynamic> operation, List<_ActivationRequest> requests) async {
    final controls = (await extensions.activationRefControls(operation)).byKey;
    final candidates = <Map<String, dynamic>>[];
    for (final request in requests) {
      final activity = controls[request.key];
      final input = activity?.control['input'];
      if (activity == null || input is! Map || input['kind'] != 'refList') {
        throw _PatchRefused(t.operationSetupAction.unavailableReference(reference: _name(request)));
      }
      candidates.add({'type': activity.type, 'ref': request.code});
    }
    final validations = await extensions.refHookAnswers(candidates, RefMethod.validateRef);
    final normalized = <Map<String, dynamic>>[];
    for (final (index, request) in requests.indexed) {
      final answer = validations[index];
      final activity = controls[request.key]!;
      final String code;
      if (answer.noHandler) {
        // Validation is optional. A descriptor may be the only place an
        // extension declares the format, just as it does for typed input.
        code = request.code.toUpperCase();
        final input = activity.control['input'] as Map;
        final pattern = input['pattern'];
        if (pattern is String && compileRefPattern(pattern)?.hasMatch(code) == false) {
          throw _PatchRefused(t.operationSetupAction.invalidReference(reference: _name(request)));
        }
      } else {
        final validation = answer.value;
        if (!answer.ok || validation is! Map || validation['valid'] is! bool) {
          throw _PatchRefused(t.operationSetupAction.unavailableReference(reference: _name(request)));
        }
        final value = validation['normalized'] ?? request.code;
        if (validation['valid'] == false || value is! String || value.trim().isEmpty) {
          throw _PatchRefused(t.operationSetupAction.invalidReference(reference: _name(request)));
        }
        code = value.trim();
      }
      normalized.add({'type': activity.type, 'ref': code});
    }

    // Decoration supplies labels and the place a ref can bring to an
    // operation. Validation owns the identity, even if decoration is absent
    // or returns a different code.
    final decorated = await extensions.decorateRefs(normalized);
    return [
      for (final (index, request) in requests.indexed)
        (request: request, data: {...decorated[index], ...normalized[index]}, allowsMultiple: controls[request.key]!.control['allowsMultiple'] == true),
    ];
  }

  static String _name(_ActivationRequest request) => '${request.key}:${request.code}';

  static void _addRefs(Operation operation, List<_ActivationRef> additions, Map<String, dynamic> data) {
    final existing = operation.refs;
    final added = <Map<String, dynamic>>[];
    for (final addition in additions) {
      final type = addition.data['type'];
      final code = (addition.data['ref'] as String).toUpperCase();
      final sameType = [...existing, ...added].where((ref) => ref['type'] == type);
      if (sameType.any((ref) => asQsonString(ref['ref'])?.trim().toUpperCase() == code)) continue;
      if (!addition.allowsMultiple && sameType.isNotEmpty) {
        final reference = _name(addition.request);
        final existing = asQsonString(sameType.first['ref']) ?? '';
        throw _PatchRefused(t.operationSetupAction.conflictingReference(reference: reference, existing: existing));
      }
      added.add(addition.data);
    }
    if (added.isNotEmpty) data['refs'] = [...?asQsonList(operation.data['refs']), ...added];
  }
}

typedef _ActivationRequest = ({String key, String code});
typedef _ActivationRef = ({_ActivationRequest request, Map<String, dynamic> data, bool allowsMultiple});

class _PatchRefused implements Exception {
  const _PatchRefused(this.message);
  final String message;
}
