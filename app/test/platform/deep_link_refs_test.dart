// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Turning a deep link's `pota:US-1234` into a reference the app can actually
// file a contact under: the extension-key → ref-TYPE lookup, and the rule that
// decides whether an existing operation is the one to reuse.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/deep_link_service.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:halo_extension_host/halo_extension_host.dart';

/// One activity hook's answer, in the `{key, ok, value}` shape
/// `invokeHookAll` returns.
Map<String, dynamic> _ok(String key, List<Map<String, dynamic>> controls) => {'key': key, 'ok': true, 'value': controls};

Map<String, dynamic> _refControl(String key, String refType) => {
  'key': key,
  'label': key,
  'input': {'kind': 'refList', 'refType': refType},
};

class _MockHost implements ExtensionHost {
  final Map<String, dynamic> results;
  const _MockHost(this.results);

  @override
  Future<dynamic> invokeHook(String category, {String? key, required String method, Object? args, Duration timeout = const Duration(seconds: 10)}) async =>
      results['$category:$key:$method'];

  @override
  Future<List<Map<String, dynamic>>> invokeHookAll(
    String category, {
    required String method,
    Object? args,
    Duration timeout = const Duration(seconds: 10),
    bool partialOnTimeout = false,
  }) async {
    final res = results['$category:*:$method'];
    return res == null ? const [] : (res as List).cast<Map<String, dynamic>>();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Extensions extends ExtensionService {
  final ExtensionHost mockHost;
  _Extensions(this.mockHost);

  // The getter, which is what `_collectControls` reads — overriding the
  // methods instead would make every assertion below vacuous.
  @override
  ExtensionHost? get host => mockHost;

  @override
  Future<void> start() async {}

  @override
  Future<void> setSyncCredentials({required String deviceKey, required String operatorCall}) async {}
}

void main() {
  group('activityRefTypes', () {
    test('reads activation from operation controls and hunting from logging controls', () async {
      final extensions = _Extensions(
        _MockHost({
          'activity:*:operationControls': [
            _ok('pota', [_refControl('pota/activation', 'potaActivation')]),
            _ok('sota', [_refControl('sota/activation', 'sotaActivation')]),
          ],
          'activity:*:loggingControls': [
            _ok('pota', [_refControl('pota/hunter', 'pota')]),
            _ok('sota', [_refControl('sota/hunter', 'sota')]),
          ],
        }),
      );

      final types = (await extensions.activityRefTypes()).byKey;
      expect(types['pota']?.activationType, 'potaActivation');
      expect(types['pota']?.huntingType, 'pota');
      expect(types['sota']?.activationType, 'sotaActivation');
      // The two must not be read off the same fan-out: an operation ACTIVATES
      // and a QSO HUNTS, and swapping them writes refs nothing scores.
      expect(types['sota']?.huntingType, 'sota');
    });

    test('reports an activation-only program with no hunting type', () async {
      // Castles, mills and the like have no hunting side at all, so a
      // `their.refs=bca:…` must resolve to nothing rather than to the
      // activation type.
      final extensions = _Extensions(
        _MockHost({
          'activity:*:operationControls': [
            _ok('bca', [_refControl('bca/activation', 'bcaActivation')]),
          ],
          'activity:*:loggingControls': <Map<String, dynamic>>[],
        }),
      );

      final types = (await extensions.activityRefTypes()).byKey;
      expect(types['bca']?.activationType, 'bcaActivation');
      expect(types['bca']?.huntingType, isNull);
    });

    test('ignores controls that are not reference lists', () async {
      // A contest's setup control is not a reference, and reading one as a
      // ref type would make `cqww:` resolve to something loggable.
      final extensions = _Extensions(
        _MockHost({
          'activity:*:operationControls': [
            _ok('cqww', [
              {
                'key': 'cqww/setup',
                'label': 'CQ WW',
                'input': {'kind': 'select'},
              },
            ]),
          ],
          'activity:*:loggingControls': <Map<String, dynamic>>[],
        }),
      );

      expect((await extensions.activityRefTypes()).byKey, isEmpty);
    });

    test('ignores the controls a failed hook still carried, and says it failed', () async {
      // The fixture carries BOTH `ok: false` and a payload, so the test turns
      // red if `_collectControls` ever reads a failed entry's controls — a
      // fixture with no `value` would pass on the `value is! List` branch
      // instead, and prove nothing about the `ok` guard.
      final extensions = _Extensions(
        _MockHost({
          'activity:*:operationControls': [
            {
              'key': 'pota',
              'ok': false,
              'error': 'boom',
              'value': [_refControl('pota/activation', 'potaActivation')],
            },
          ],
          'activity:*:loggingControls': <Map<String, dynamic>>[],
        }),
      );

      final result = await extensions.activityRefTypes();
      expect(result.byKey.containsKey('pota'), isFalse);
      // The whole point of the flag: "could not ask" must not reach the
      // operator as "you do not have that activity".
      expect(result.loadFailed, isTrue);
    });

    test('reports no failure when every hook answered', () async {
      final extensions = _Extensions(
        _MockHost({
          'activity:*:operationControls': [
            _ok('pota', [_refControl('pota/activation', 'potaActivation')]),
          ],
          'activity:*:loggingControls': <Map<String, dynamic>>[],
        }),
      );

      expect((await extensions.activityRefTypes()).loadFailed, isFalse);
    });
  });

  group('activationRefsMatch', () {
    final parkAndSummit = {'potaActivation:US-1234', 'sotaActivation:W6/CT-006'};

    test('reuses an operation activating exactly the requested set', () {
      expect(
        DeepLinkService.activationRefsMatch([
          {'type': 'sotaActivation', 'ref': 'W6/CT-006'},
          {'type': 'potaActivation', 'ref': 'US-1234'},
        ], parkAndSummit),
        isTrue,
        reason: 'order must not matter — this is a set comparison',
      );
    });

    test('refuses an operation activating MORE than was asked for', () {
      // A park-only link latching onto a park-and-summit operation files
      // every contact as a summit activation too.
      expect(
        DeepLinkService.activationRefsMatch(
          [
            {'type': 'potaActivation', 'ref': 'US-1234'},
            {'type': 'sotaActivation', 'ref': 'W6/CT-006'},
          ],
          {'potaActivation:US-1234'},
        ),
        isFalse,
      );
    });

    test('refuses an operation activating FEWER than was asked for', () {
      expect(
        DeepLinkService.activationRefsMatch([
          {'type': 'potaActivation', 'ref': 'US-1234'},
        ], parkAndSummit),
        isFalse,
      );
    });

    test('refuses a different reference of the same type', () {
      expect(
        DeepLinkService.activationRefsMatch(
          [
            {'type': 'potaActivation', 'ref': 'US-9999'},
          ],
          {'potaActivation:US-1234'},
        ),
        isFalse,
      );
    });

    test('reads refs written as anything at all without throwing', () {
      // An operation's `data['refs']` is untyped and crosses sync, so an
      // older build or a peer may have put something else there entirely.
      expect(DeepLinkService.refKeysOf(null), isEmpty);
      expect(DeepLinkService.refKeysOf('pota:US-1234'), isEmpty);
      expect(
        DeepLinkService.refKeysOf([
          42,
          null,
          {'type': 'potaActivation'},
          {'ref': 'US-1'},
        ]),
        isEmpty,
      );
    });
  });
}
