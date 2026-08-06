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

  group('instances', () {
    Future<PanelService> withPanel({required bool multiple}) async {
      final service = PanelService(_FakeExtensions(entries: [
        {'hookKey': 'notes', 'key': 'text', 'title': 'Custom Text', 'multiple': multiple},
      ]));
      await service.refreshExtensionPanels();
      return service;
    }

    test('an instance id resolves to its descriptor but keeps its own id', () async {
      final service = await withPanel(multiple: true);
      final instance = service['ext:notes:text#2'];

      expect(instance, isNotNull);
      // The routing keys are the descriptor's — that is what makes the
      // render reach the same hook for every placement.
      expect(instance!.hookKey, 'notes');
      expect(instance.panelKey, 'text');
      // But the id is the INSTANCE's, because config is stored under it. If
      // this returned the descriptor's id, two panes would share one set of
      // values and editing either would rewrite both.
      expect(instance.id, 'ext:notes:text#2');
    });

    test('a panel that did not opt in has no instances', () async {
      final service = await withPanel(multiple: false);
      // A suffix on a panel that is meant to exist once is a layout naming
      // something the catalog cannot explain — the pane says so, which beats
      // silently handing back the descriptor and letting the placements
      // share a config.
      expect(service['ext:notes:text#2'], isNull);
      expect(service['ext:notes:text'], isNotNull);
    });

    test('an id with no suffix is its own descriptor', () async {
      // Every arrangement saved before instances existed is full of these.
      expect(PanelDefinition.descriptorIdOf('ext:notes:text'), 'ext:notes:text');
      expect(PanelDefinition.descriptorIdOf('ext:notes:text#3'), 'ext:notes:text');
      expect(PanelDefinition.descriptorIdOf('logging'), 'logging');
    });

    test('a key containing # is refused, not read as an instance', () async {
      final service = PanelService(_FakeExtensions(entries: [
        {'hookKey': 'notes', 'key': 'text#2', 'title': 'Sneaky'},
        {'hookKey': 'notes', 'key': 'text', 'title': 'Custom Text', 'multiple': true},
      ]));
      await service.refreshExtensionPanels();

      // `#` is what separates a descriptor from a placement of it, so a key
      // carrying one would be resolved as an instance of a shorter
      // descriptor — here, silently answering for `ext:notes:text#2`, the
      // second pane of a different panel entirely.
      expect(service.catalog.map((p) => p.id), ['ext:notes:text']);
      expect(service['ext:notes:text#2']?.title, 'Custom Text', reason: 'the real panel, not the sneaky one');
    });

    test('removing an instance forgets what it held; removing a panel does not', () async {
      final extensions = _FakeExtensions(entries: [
        {
          'hookKey': 'notes',
          'key': 'text',
          'title': 'Custom Text',
          'multiple': true,
          'form': [
            {'key': 'content', 'fieldType': 'multiline'},
          ],
        },
        {
          'hookKey': 'wx',
          'key': 'forecast',
          'title': 'Weather',
          'form': [
            {'key': 'location', 'fieldType': 'text'},
          ],
        },
      ]);
      final service = PanelService(extensions);
      await service.refreshExtensionPanels();

      // An instance id is an anonymous slot — `nextInstanceId` hands `#1` to
      // whoever asks next — so one pane's notes would otherwise reappear
      // inside the next pane the operator adds.
      await service.forgetInstanceConfig('ext:notes:text#1');
      expect(extensions.forgotten, ['ext:notes:text#1']);

      // A panel placed once is the opposite: its location is the PANEL's
      // configuration, not that pane's, and removing the pane to put it back
      // must not throw the operator's setup away.
      await service.forgetInstanceConfig('ext:wx:forecast');
      expect(extensions.forgotten, ['ext:notes:text#1'], reason: 'a panel is not a placement');
    });

    test('a panel whose extension is disabled still forgets its placement', () async {
      final extensions = _FakeExtensions(entries: [
        {
          'hookKey': 'notes',
          'key': 'text',
          'title': 'Custom Text',
          'multiple': true,
          'form': [
            {'key': 'content', 'fieldType': 'multiline'},
          ],
        },
      ]);
      final service = PanelService(extensions);
      await service.refreshExtensionPanels();

      // Resolving the INSTANCE is what fails while an extension is disabled
      // or has stopped offering instances — and a pane removed in that state
      // would leave its contents for the next `#1` to inherit, which is the
      // one outcome this whole rule exists to prevent. So the descriptor is
      // what gets looked up.
      await service.forgetInstanceConfig('ext:notes:text#3');
      expect(extensions.forgotten, ['ext:notes:text#3']);
    });

    test('a new instance never collides with one already placed', () {
      const id = 'ext:notes:text';
      expect(PanelService.nextInstanceId(id, const []), 'ext:notes:text#1');
      expect(PanelService.nextInstanceId(id, const ['ext:notes:text#1']), 'ext:notes:text#2');
      // Gaps are reused rather than counted past: removing #1 and adding
      // another must not walk the numbering upward forever.
      expect(PanelService.nextInstanceId(id, const ['ext:notes:text#2']), 'ext:notes:text#1');
      // Other panels' placements are not this panel's business.
      expect(PanelService.nextInstanceId(id, const ['ext:other:thing#1']), 'ext:notes:text#1');
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

  /// What the catalog asked to be forgotten, so a test can assert on the
  /// distinction between a placement and a panel.
  final forgotten = <String>[];

  @override
  Future<void> forgetPanelConfig({
    required String panelKey,
    required List<Map<String, dynamic>> fields,
  }) async => forgotten.add(panelKey);
}
