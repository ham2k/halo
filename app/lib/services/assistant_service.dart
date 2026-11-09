// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Extension assistants (docs/extensions/assistants.md): hooks that watch what
// the operator does in every open operation and answer through the host —
// the FYI line, notices, band annotations, the radio — with nothing on
// screen of their own.
//
// They wake on the panel triggers, from the same [PanelRenderContext] a view
// hands its panes, but nothing here depends on a pane being placed, visible
// or on a selected tab: that dependence is exactly what a panel cannot shed,
// and what an assistant exists without.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:halo_core/halo_core.dart';

import '../views/operation/panel_scene/cat_spectrum_source.dart';
import 'cat/cat_service.dart';
import 'error_reporting_service.dart';
import 'panel_service.dart';
import 'settings_service.dart';

/// One assistant an extension offers, as `getAssistants` described it.
@immutable
class AssistantDefinition {
  final String hookKey;
  final String key;
  final String title;
  final String? description;
  final String? icon;
  final List<String> triggers;
  final List<Map<String, dynamic>> formFields;
  final bool enabledByDefault;

  const AssistantDefinition({
    required this.hookKey,
    required this.key,
    required this.title,
    this.description,
    this.icon,
    this.triggers = const [],
    this.formFields = const [],
    this.enabledByDefault = true,
  });

  /// Where its switch and its settings are stored. Renaming the hook key or
  /// the assistant key loses both, as renaming a panel loses its placements.
  String get id => 'assistant:$hookKey:$key';

  /// One `getAssistants` entry, tagged with its `hookKey`. Null for an entry
  /// without a key or a title — the caller says so in the console. Unknown
  /// trigger names are dropped here, with a line, as a panel's are.
  static AssistantDefinition? fromEntry(Map<String, dynamic> entry) {
    final hookKey = entry['hookKey'], key = entry['key'], title = entry['title'];
    if (hookKey is! String || key is! String || key.isEmpty || title is! String || title.isEmpty) return null;
    final declared = (entry['on'] as List?)?.whereType<String>() ?? const <String>[];
    final triggers = <String>[];
    for (final trigger in declared) {
      if (isKnownPanelTrigger(trigger)) {
        triggers.add(trigger);
      } else {
        debugPrint('[assistants] "$hookKey:$key" declares an unrecognized trigger ($trigger); it will never fire');
      }
    }
    return AssistantDefinition(
      hookKey: hookKey,
      key: key,
      title: title,
      description: entry['description'] as String?,
      icon: entry['icon'] as String?,
      triggers: triggers,
      formFields: [
        for (final field in (entry['form'] as List?) ?? const [])
          if (field is Map) field.cast<String, dynamic>(),
      ],
      enabledByDefault: entry['enabledByDefault'] != false,
    );
  }
}

/// The slice of [ExtensionService] the assistants use, named so their rules
/// can be tested without a JS runtime.
abstract interface class AssistantExtensionSource {
  /// Ticks after every runtime (re)start: the assistants a runtime offers are
  /// only knowable by asking it.
  Listenable get runtimeGeneration;

  /// Null when the runtime could not be asked.
  Future<List<Map<String, dynamic>>?> getExtensionAssistants();

  /// Throws when the hook does; false when there was no runtime to call.
  Future<bool> observe({required String hookKey, required String assistantKey, required Map<String, dynamic> args});

  Future<Map<String, dynamic>> readPanelConfig({required String panelKey, required List<Map<String, dynamic>> fields});

  /// Whether [hookKey]'s extension may read the radio (`requiresRadioRead`):
  /// the `radio` trigger fires for no one else.
  bool canReadRadio(String? hookKey);

  /// Takes the spot marks off every extension that offers assistants
  /// ([offered], by hook key) and has none of them on ([on]): one switched
  /// off is never called again to take back what it hid or picked.
  void releaseSpotMarks({required Set<String> offered, required Set<String> on});
}

/// Where the operator's on/off switch for each assistant is kept.
abstract interface class AssistantSwitches {
  bool? read(String id);
  Future<void> write(String id, bool enabled);
}

/// What the `radio` trigger compares: the dial of every radio, never a meter.
/// The same reading a panel's `radio` trigger takes.
typedef AssistantRadioDial = ({Listenable changes, List<Object?> Function() state});

/// One open operation, as a view feeds it to the assistants. A view opens one
/// on mount, hands it every [PanelRenderContext] it builds, and closes it on
/// dispose.
class AssistantFeed {
  final AssistantService _service;
  PanelRenderContext _context = const PanelRenderContext();

  /// Whether the assistants have been told about this feed's operation yet.
  /// The first context carrying one is `open` rather than a change.
  bool _opened = false;
  bool _closed = false;

  AssistantFeed._(this._service);

  PanelRenderContext get context => _context;

  void update(PanelRenderContext next) {
    if (_closed) return;
    final previous = _context;
    _context = next;
    if (next.operation == null) return;
    if (!_opened || previous.operation?.uuid != next.operation?.uuid) {
      _opened = true;
      _service._openFeed(this);
      return;
    }
    final changes = next.changesFrom(previous);
    if (changes.isNotEmpty) _service._feedChanged(this, changes);
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _service._closeFeed(this);
  }
}

/// One assistant's calls about one feed: at most one in flight, the triggers
/// that arrived meanwhile folded into the next, and [panelRenderThrottle]
/// of idle between them.
class _Slot {
  /// Replaced in place when the runtime re-offers it, so a call still out
  /// keeps pacing the next one.
  AssistantDefinition assistant;
  final AssistantFeed feed;
  final Set<String> pending = {};
  bool running = false;

  /// Switched off while a call was out: kept until that call ends, so one
  /// switched back on meanwhile waits for it rather than running beside it.
  bool retired = false;
  DateTime? lastEndedAt;
  Timer? wait;

  _Slot(this.assistant, this.feed);

  void cancel() {
    wait?.cancel();
    wait = null;
    pending.clear();
  }
}

class AssistantService extends ChangeNotifier {
  final AssistantExtensionSource extensions;
  final AssistantSwitches switches;
  final AssistantRadioDial? radio;

  /// The app's: switches in its prefs, the radio's dial from its CAT
  /// connections. Asks the extensions at once; the first operation view to
  /// open hears `open` when they answer.
  factory AssistantService.forApp(AssistantExtensionSource extensions, {required SettingsService settings, required CatService cat}) {
    final dial = CatSpectrumSource(cat, settings: settings);
    final service = AssistantService(extensions, switches: _PrefsAssistantSwitches(settings), radio: (changes: dial.readingChanges, state: dial.dialState));
    unawaited(service.refresh());
    return service;
  }

  AssistantService(this.extensions, {required this.switches, this.radio}) {
    extensions.runtimeGeneration.addListener(_onRuntimeReplaced);
    AppClock.instance.addListener(_onClockTravel);
    radio?.changes.addListener(_onRadio);
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    extensions.runtimeGeneration.removeListener(_onRuntimeReplaced);
    AppClock.instance.removeListener(_onClockTravel);
    radio?.changes.removeListener(_onRadio);
    for (final timer in _ticks.values) {
      timer.cancel();
    }
    _ticks.clear();
    for (final slot in _slots.values) {
      slot.cancel();
    }
    _slots.clear();
    super.dispose();
  }

  List<AssistantDefinition> _catalog = const [];
  int _refreshSeq = 0;

  /// Every assistant the extensions offer, on or off.
  List<AssistantDefinition> get catalog => _catalog;

  bool isEnabled(AssistantDefinition assistant) => switches.read(assistant.id) ?? assistant.enabledByDefault;

  Iterable<AssistantDefinition> get _enabled => _catalog.where(isEnabled);

  /// Whether an assistant that is on declared [trigger]. A view producing a
  /// signal only for those who asked (the draft per keystroke, the spots
  /// revision) asks this beside its panes.
  bool wants(String trigger) => _enabled.any((assistant) => assistant.triggers.contains(trigger));

  Future<void> setEnabled(AssistantDefinition assistant, bool enabled) async {
    if (isEnabled(assistant) == enabled) return;
    await switches.write(assistant.id, enabled);
    _reconcile();
    notifyListeners();
  }

  /// The assistant's settings were edited: each operation hears of it at once,
  /// as `config`, since nothing else would wake an assistant without triggers.
  void configChanged(AssistantDefinition assistant) {
    if (!isEnabled(assistant)) return;
    for (final feed in _feeds) {
      _fire(assistant, feed, 'config');
    }
  }

  void _onRuntimeReplaced() => unawaited(refresh());

  /// Re-reads what the extensions offer.
  Future<void> refresh() async {
    final seq = ++_refreshSeq;
    final entries = await extensions.getExtensionAssistants();
    if (seq != _refreshSeq || _disposed) return;
    // Could not ask: the assistants already known keep running.
    if (entries == null) return;
    final assistants = <AssistantDefinition>[];
    final seen = <String>{};
    for (final entry in entries) {
      final assistant = AssistantDefinition.fromEntry(entry);
      if (assistant == null) {
        debugPrint('[assistants] ignoring an entry from "${entry['hookKey']}": needs a key and a title');
        continue;
      }
      if (!seen.add(assistant.id)) {
        debugPrint('[assistants] "${assistant.id}" is already claimed; ignoring the duplicate');
        continue;
      }
      if (assistant.triggers.contains('radio') && !extensions.canReadRadio(assistant.hookKey)) {
        debugPrint('[assistants] "${assistant.id}" declares "radio", which never fires: its extension does not declare requiresRadioRead');
      }
      assistants.add(assistant);
    }
    _catalog = assistants;
    _reconcile();
    notifyListeners();
  }

  final List<AssistantFeed> _feeds = [];
  final Map<(String, AssistantFeed), _Slot> _slots = {};

  AssistantFeed openFeed() {
    final feed = AssistantFeed._(this);
    _feeds.add(feed);
    return feed;
  }

  void _openFeed(AssistantFeed feed) {
    for (final assistant in _enabled) {
      _fire(assistant, feed, 'open');
    }
  }

  void _feedChanged(AssistantFeed feed, Set<String> changes) {
    for (final assistant in _enabled) {
      final fired = changes.intersection(assistant.triggers.toSet());
      for (final reason in fired) {
        _fire(assistant, feed, reason);
      }
    }
  }

  void _closeFeed(AssistantFeed feed) {
    _feeds.remove(feed);
    _slots.removeWhere((key, slot) {
      if (key.$2 != feed) return false;
      slot.cancel();
      return true;
    });
  }

  /// Brings the slots and tickers in line with what is on: an assistant
  /// switched on, or newly offered, hears `open` for every operation already
  /// open; one switched off, or gone, loses whatever it was owed.
  void _reconcile() {
    final enabled = {for (final assistant in _enabled) assistant.id: assistant};
    final reopen = <(String, AssistantFeed)>{};
    _slots.removeWhere((key, slot) {
      final current = enabled[key.$1];
      if (current == null) {
        slot.cancel();
        slot.retired = true;
        return !slot.running;
      }
      // Re-offered by a new runtime, or switched back on: it hears `open`
      // again, through the same slot, after any call still out.
      if (slot.retired || !identical(current, slot.assistant)) reopen.add(key);
      slot.assistant = current;
      slot.retired = false;
      return false;
    });
    for (final assistant in enabled.values) {
      for (final feed in _feeds) {
        final key = (assistant.id, feed);
        if (feed._opened && (!_slots.containsKey(key) || reopen.contains(key))) _fire(assistant, feed, 'open');
      }
    }
    _restartTicks();
    _dialSeen = radio?.state();
    extensions.releaseSpotMarks(
      offered: {for (final assistant in _catalog) assistant.hookKey},
      on: {for (final assistant in enabled.values) assistant.hookKey},
    );
  }

  void _fire(AssistantDefinition assistant, AssistantFeed feed, String reason) {
    if (_disposed || feed._closed || !feed._opened) return;
    final slot = _slots.putIfAbsent((assistant.id, feed), () => _Slot(assistant, feed));
    slot.pending.add(reason);
    _schedule(slot);
  }

  void _schedule(_Slot slot) {
    if (slot.running || slot.wait != null || slot.pending.isEmpty) return;
    final delay = panelRenderDelay(lastEndedAt: slot.lastEndedAt, now: realNowUtc());
    if (delay == Duration.zero) {
      unawaited(_run(slot));
      return;
    }
    slot.wait = Timer(delay, () {
      slot.wait = null;
      unawaited(_run(slot));
    });
  }

  Future<void> _run(_Slot slot) async {
    if (_disposed || slot.feed._closed || slot.pending.isEmpty) return;
    final reasons = slot.pending.toList();
    slot.pending.clear();
    slot.running = true;
    final assistant = slot.assistant;
    final context = slot.feed.context;
    final failureKey = 'assistant:${assistant.id}';
    try {
      final config = await extensions.readPanelConfig(panelKey: assistant.id, fields: assistant.formFields);
      final operation = context.operation;
      if (operation == null) return;
      final called = await extensions.observe(
        hookKey: assistant.hookKey,
        assistantKey: assistant.key,
        args: {
          'assistantKey': assistant.key,
          'operation': operationHookArgs(operation),
          // Only to one that declared it: the draft is the operator's
          // keystrokes, and other features produce it too.
          if (context.qso != null && (assistant.triggers.contains('qso') || assistant.triggers.contains('lookup'))) 'qso': context.qso,
          'qsoCount': context.qsoCount,
          'config': config,
          'reasons': reasons,
          'clock': {'nowMillis': nowMillis(), 'realNowMillis': realNowMillis()},
        },
      );
      // No runtime is no call: it says nothing about whether the assistant works.
      if (called) ErrorReportingService.recordSuccess(failureKey);
    } catch (e, stack) {
      // An assistant has no pane to show its failure in. The console line is
      // the author's; a streak is the operator's, through the policy.
      debugPrint('[assistants] ${assistant.id} failed on ${reasons.join(', ')}: $e');
      ErrorReportingService.reportIfRepeated(failureKey, e, stack, context: failureKey);
    } finally {
      slot.running = false;
      slot.lastEndedAt = realNowUtc();
      final key = (slot.assistant.id, slot.feed);
      if (!_disposed && identical(_slots[key], slot)) {
        if (slot.retired) {
          _slots.remove(key);
        } else {
          _schedule(slot);
        }
      }
    }
  }

  // Ticks: one chain per assistant, aimed at wall-clock boundaries as a
  // panel's are, delivered to every open operation.

  final Map<String, Timer> _ticks = {};

  void _restartTicks() {
    for (final timer in _ticks.values) {
      timer.cancel();
    }
    _ticks.clear();
    for (final assistant in _enabled) {
      _armTick(assistant);
    }
  }

  void _armTick(AssistantDefinition assistant) {
    final period = panelTickPeriod(assistant.triggers);
    if (period == null || _disposed) return;
    final delay = panelTickDelayMillis(periodMs: period.inMilliseconds, nowMillis: nowMillis(), speed: AppClock.instance.speed);
    _ticks[assistant.id] = Timer(Duration(milliseconds: delay), () {
      _ticks.remove(assistant.id);
      // Re-armed whatever happens: nothing else restarts a chain that broke.
      try {
        for (final feed in List.of(_feeds)) {
          _fire(assistant, feed, 'tick');
        }
      } finally {
        if (!_disposed && isEnabled(assistant) && _catalog.contains(assistant)) _armTick(assistant);
      }
    });
  }

  /// Travel moves the boundaries the pending ticks were aimed at.
  void _onClockTravel() {
    if (_disposed) return;
    _restartTicks();
  }

  List<Object?>? _dialSeen;

  /// Runs on every meter reading, several a second: nothing is read unless an
  /// assistant that is on asked for the radio.
  void _onRadio() {
    if (!wants('radio')) return;
    final dial = radio?.state();
    if (_disposed || dial == null || listEquals(dial, _dialSeen)) return;
    _dialSeen = dial;
    for (final assistant in _enabled) {
      if (!assistant.triggers.contains('radio') || !extensions.canReadRadio(assistant.hookKey)) continue;
      for (final feed in _feeds) {
        _fire(assistant, feed, 'radio');
      }
    }
  }
}

/// An assistant's on/off switch, kept in the app's prefs beside its settings.
class _PrefsAssistantSwitches implements AssistantSwitches {
  final SettingsService settings;
  _PrefsAssistantSwitches(this.settings);

  @override
  bool? read(String id) => settings.prefs.getBool('$id.enabled');

  @override
  Future<void> write(String id, bool enabled) => settings.prefs.setBool('$id.enabled', enabled);
}
