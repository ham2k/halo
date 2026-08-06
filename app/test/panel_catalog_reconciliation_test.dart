// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The rules that keep a saved dock arrangement alive across a launch. The
// extensions are asked for their panels asynchronously, so for the first
// frames of every launch the catalog holds only the native panels — and an
// arrangement holding an extension panel must survive that gap rather than
// being judged unbuildable, replaced, and then overwritten by the first tab
// tap. These pin the two halves of that: the catalog knows the difference
// between "no panels" and "could not ask", and a trigger nobody fires is
// rejected where it can still be reported.

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/panel_service.dart';

void main() {
  group('reading the catalog', () {
    test('a read that could not ask keeps what the catalog had', () async {
      final extensions = _FakeExtensions(entries: [
        {'hookKey': 'wx', 'key': 'forecast', 'title': 'Forecast'},
      ]);
      final service = PanelService(extensions);
      await service.refreshExtensionPanels();
      expect(service['ext:wx:forecast'], isNotNull);

      // The runtime went away. Publishing an empty catalog would turn every
      // extension pane in every saved arrangement into a "missing extension"
      // placeholder on the strength of an answer nobody gave.
      extensions.entries = null;
      await service.refreshExtensionPanels();
      expect(service['ext:wx:forecast'], isNotNull);
    });

    test('a catalog that genuinely holds no panels is published as empty', () async {
      final service = PanelService(_FakeExtensions(entries: const []));
      await service.refreshExtensionPanels();
      // Distinct from the case above, and the distinction is the whole point.
      expect(service.catalog, isEmpty);
    });

    test('panels from a successful read reach the catalog', () async {
      final service = PanelService(_FakeExtensions(entries: [
        {'hookKey': 'wx', 'key': 'forecast', 'title': 'Forecast'},
      ]));
      await service.refreshExtensionPanels();
      expect(service['ext:wx:forecast']?.title, 'Forecast');
    });
  });

  group('runtime restarts', () {
    test('a fresh runtime is re-read without anyone asking', () async {
      final extensions = _FakeExtensions(entries: const []);
      final service = PanelService(extensions);
      await service.refreshExtensionPanels();
      expect(service.catalog, isEmpty);

      // Enabling an extension in Settings restarts the runtime. An Operation
      // view stays mounted across that trip, so if the catalog only re-reads
      // when something happens to ask, the newly enabled extension's panels
      // are missing from Layout Setup until it is closed and reopened.
      extensions.entries = [
        {'hookKey': 'wx', 'key': 'forecast', 'title': 'Forecast'},
      ];
      extensions.runtimeGeneration.value++;
      await pumpEventQueue();

      expect(service['ext:wx:forecast']?.title, 'Forecast');
    });

    test('a catalog asked before the runtime was up settles when it comes up', () async {
      final extensions = _FakeExtensions(entries: null);
      final service = PanelService(extensions);
      await service.refreshExtensionPanels();
      expect(service.catalog, isEmpty);

      // Boot order: the app builds its first Operation view well before the
      // JS runtime finishes starting. Without the restart subscription that
      // first failed read is the only one of the session, and every saved
      // arrangement holding an extension panel stays in limbo.
      extensions.entries = [
        {'hookKey': 'wx', 'key': 'forecast', 'title': 'Forecast'},
      ];
      extensions.runtimeGeneration.value++;
      await pumpEventQueue();

      expect(service['ext:wx:forecast'], isNotNull);
    });

    test('a slower read cannot install its answer over a newer one', () async {
      // Two restarts in quick succession — a toggle landing on top of a crash
      // recovery. Both reads are in flight at once on a call that can take ten
      // seconds, and if the older one wins, generation N-1's panel list stands
      // for the rest of the session: a disabled extension's panel still
      // listed, or a newly enabled one's missing, with nothing said anywhere.
      final extensions = _FakeExtensions(entries: const [], delay: const Duration(milliseconds: 50));
      final service = PanelService(extensions);
      final slow = service.refreshExtensionPanels();

      extensions.entries = [
        {'hookKey': 'wx', 'key': 'forecast', 'title': 'Forecast'},
      ];
      extensions.delay = Duration.zero;
      await service.refreshExtensionPanels();
      expect(service['ext:wx:forecast'], isNotNull);

      await slow;
      expect(service['ext:wx:forecast'], isNotNull, reason: 'the stale read must not have won');
    });

    test('a disposed catalog stops listening to the runtime', () async {
      final extensions = _FakeExtensions(entries: const []);
      final service = PanelService(extensions);
      service.dispose();

      // notifyListeners() on a disposed ChangeNotifier throws, and this one
      // would be reached from an unawaited refresh — so a leaked
      // subscription surfaces as an unhandled error out of the next runtime
      // restart, not as a wasted bridge call. The app's own PanelService
      // lives as long as the app and is never disposed, so this pairing
      // exists for the sake of tests like these, which build their own.
      extensions.runtimeGeneration.value++;
      await pumpEventQueue();
    });
  });

  group('triggers', () {
    test('only names the host actually fires are accepted', () {
      for (final t in ['operation', 'qso', 'qsoLogged', 'lookup', 'spots', 'tick:5', 'tick:3600']) {
        expect(isKnownPanelTrigger(t), isTrue, reason: '$t is documented in hooks.md');
      }
      // A panel that renders once and never again is indistinguishable from
      // one that meant to, so a name nothing fires is rejected where it can
      // still be reported rather than sitting in the descriptor looking live.
      for (final t in ['qso_logged', 'qsoAdded', 'tick:', 'tick:30s', 'tick:0', 'tick:-5']) {
        expect(isKnownPanelTrigger(t), isFalse, reason: '$t fires nothing');
      }
    });

    test('an unrecognized trigger is dropped from the descriptor, not carried', () {
      final panel = PanelDefinition.fromExtensionEntry({
        'hookKey': 'wx',
        'key': 'forecast',
        'title': 'Forecast',
        'on': ['operation', 'qso_logged', 'tick:30'],
      })!;
      expect(panel.triggers, ['operation', 'tick:30']);
    });
  });

  test('a config field with no key never reaches the form', () {
    // It would render a control the operator can fill in, which is then
    // never persisted and never handed back as `config` — the panel appears
    // to ignore its own settings.
    final panel = PanelDefinition.fromExtensionEntry({
      'hookKey': 'wx',
      'key': 'forecast',
      'title': 'Forecast',
      'form': [
        {'key': 'units', 'fieldType': 'select'},
        {'fieldType': 'text', 'label': 'Nameless'},
      ],
    })!;
    expect(panel.formFields.map((f) => f['key']), ['units']);
  });

  test('editing a config bumps the revision the live panel watches', () {
    final service = PanelService(_FakeExtensions(entries: const []));
    var notifications = 0;
    service.addListener(() => notifications++);

    expect(service.configRevision('ext:wx:forecast'), 0);
    service.markConfigChanged('ext:wx:forecast');
    // A panel with no triggers would otherwise show content rendered against
    // the old config forever.
    expect(service.configRevision('ext:wx:forecast'), 1);
    expect(notifications, 1);
    expect(service.configRevision('ext:other:panel'), 0, reason: 'one panel\'s config is not another\'s');
  });
}

/// Answers the one call the catalog makes. `entries: null` is the host
/// saying "could not ask" — no runtime, or the call failed.
class _FakeExtensions implements PanelExtensionSource {
  /// Mutable: a runtime restart is the one thing that can change what the
  /// extensions offer without the catalog being asked to look.
  List<Map<String, dynamic>>? entries;

  /// How long this read takes to answer, so two passes can be in flight at
  /// once — the race a real 10-second bridge call makes ordinary.
  Duration delay;

  _FakeExtensions({required this.entries, this.delay = Duration.zero});

  /// Bumping this stands in for a runtime restart — an extension being
  /// enabled or disabled.
  @override
  final ValueNotifier<int> runtimeGeneration = ValueNotifier(0);

  @override
  Future<List<Map<String, dynamic>>?> getExtensionPanels() async {
    final answer = entries;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    return answer;
  }

  @override
  Future<Map<String, dynamic>?> renderPanel({
    required String hookKey,
    required String panelKey,
    required Map<String, dynamic> args,
  }) async => null;

  @override
  Future<Map<String, dynamic>> readPanelConfig({
    required String panelKey,
    required List<Map<String, dynamic>> fields,
  }) async => const {};
}
