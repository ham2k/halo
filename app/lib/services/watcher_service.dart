// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What assistants (docs/extensions/assistants.md) and integrations
// (docs/extensions/integrations.md) share: extension hooks that watch the
// operations open in a view and are called about one at a time, on the panel
// triggers, from the same [PanelRenderContext] a view hands its panes — but
// with nothing depending on a pane being placed, visible or on a selected
// tab. That dependence is exactly what a panel cannot shed, and what these
// exist without.
//
// The two differ in where they are switched on and in what a call carries:
// an assistant app-wide, handed the draft; an integration per operation,
// handed the contacts that changed. Each subclass decides those; this file
// decides when a call happens.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:halo_core/halo_core.dart';

import 'error_reporting_service.dart';
import 'panel_service.dart';

/// One assistant or integration an extension offers, as its `getAssistants`
/// or `getIntegrations` described it.
@immutable
class WatcherDefinition {
  /// The hook category it was offered under — `assistant` or `integration` —
  /// and the first part of its [id].
  final String kind;
  final String hookKey;
  final String key;
  final String title;
  final String? description;
  final String? icon;
  final List<String> triggers;
  final List<Map<String, dynamic>> formFields;
  final bool enabledByDefault;

  const WatcherDefinition({
    required this.kind,
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
  /// the key loses both, as renaming a panel loses its placements.
  String get id => '$kind:$hookKey:$key';

  /// One entry an extension offered, tagged with its `hookKey`. Null for an
  /// entry without a key or a title — the caller says so in the console.
  /// Unknown trigger names are dropped here, with a line, as a panel's are,
  /// and so are the [refused] ones, which this kind is never woken by. A field
  /// of the wrong type reads as absent: a cast that threw here would cost
  /// every other extension's entries their place in the catalog.
  static WatcherDefinition? fromEntry(Map<String, dynamic> entry, {required String kind, Set<String> refused = const {}}) {
    final hookKey = entry['hookKey'], key = entry['key'], title = entry['title'];
    if (hookKey is! String || key is! String || key.isEmpty || title is! String || title.isEmpty) return null;
    final on = entry['on'], form = entry['form'], description = entry['description'], icon = entry['icon'];
    if ((on != null && on is! List) || (form != null && form is! List)) {
      debugPrint('[${kind}s] "$hookKey:$key": `on` and `form` are lists; ignoring what is not one');
    }
    final declared = on is List ? on.whereType<String>() : const <String>[];
    final triggers = <String>[];
    for (final trigger in declared) {
      if (refused.contains(trigger)) {
        debugPrint('[${kind}s] "$hookKey:$key" declares "$trigger", which never wakes an $kind; it will never fire');
      } else if (isKnownPanelTrigger(trigger)) {
        triggers.add(trigger);
      } else {
        debugPrint('[${kind}s] "$hookKey:$key" declares an unrecognized trigger ($trigger); it will never fire');
      }
    }
    return WatcherDefinition(
      kind: kind,
      hookKey: hookKey,
      key: key,
      title: title,
      description: description is String ? description : null,
      icon: icon is String ? icon : null,
      triggers: triggers,
      formFields: [
        if (form is List)
          for (final field in form)
            if (field is Map) field.cast<String, dynamic>(),
      ],
      enabledByDefault: entry['enabledByDefault'] != false,
    );
  }
}

/// What the `radio` trigger compares: the dial of every radio, never a meter.
/// The same reading a panel's `radio` trigger takes.
typedef WatcherRadioDial = ({Listenable changes, List<Object?> Function() state});

/// One open operation, as a view feeds it to the watchers. A view opens one
/// from each service on mount, hands it every [PanelRenderContext] it builds,
/// and closes it on dispose.
class WatcherFeed {
  final WatcherService _service;
  PanelRenderContext _context = const PanelRenderContext();

  /// Whether the watchers have been told about this feed's operation yet.
  /// The first context carrying one is `open` rather than a change.
  bool _opened = false;
  bool _closed = false;

  WatcherFeed._(this._service);

  PanelRenderContext get context => _context;

  void update(PanelRenderContext next) {
    if (_closed) return;
    final previous = _context;
    _context = next;
    _service.contextMoved(this, previous);
    if (next.operation == null) return;
    if (!_opened || previous.operation?.uuid != next.operation?.uuid) {
      _opened = true;
      _service._openFeed(this);
      return;
    }
    if (_service.switchesMoved(previous, next)) _service.reconcile();
    final changes = next.changesFrom(previous);
    if (changes.isNotEmpty) _service._feedChanged(this, changes);
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _service._closeFeed(this);
  }
}

/// One watcher's calls about one feed: at most one in flight, the triggers
/// that arrived meanwhile folded into the next, and [panelRenderThrottle]
/// of idle between them.
class _Slot {
  /// Replaced in place when the runtime re-offers it, so a call still out
  /// keeps pacing the next one.
  WatcherDefinition watcher;
  final WatcherFeed feed;
  final Set<String> pending = {};
  bool running = false;

  /// Switched off while a call was out: kept until that call ends, so one
  /// switched back on meanwhile waits for it rather than running beside it.
  bool retired = false;
  DateTime? lastEndedAt;
  Timer? wait;

  _Slot(this.watcher, this.feed);

  void cancel() {
    wait?.cancel();
    wait = null;
    pending.clear();
  }
}

abstract class WatcherService extends ChangeNotifier {
  /// Ticks after every runtime (re)start: what a runtime offers is only
  /// knowable by asking it.
  final Listenable runtimeGeneration;
  final WatcherRadioDial? radio;

  WatcherService({required this.runtimeGeneration, this.radio}) {
    runtimeGeneration.addListener(_onRuntimeReplaced);
    AppClock.instance.addListener(_onClockTravel);
    radio?.changes.addListener(_onRadio);
  }

  /// The hook category, as [WatcherDefinition.kind] spells it.
  @protected
  String get kind;

  /// Every entry the extensions offer, each tagged with its `hookKey`; null
  /// when the runtime could not be asked.
  @protected
  Future<List<Map<String, dynamic>>?> fetchCatalog();

  /// The triggers this kind is never woken by.
  @protected
  Set<String> get refusedTriggers => const {};

  /// Whether [hookKey]'s extension may read the radio (`requiresRadioRead`):
  /// the `radio` and `equipment` triggers fire for no one else.
  @protected
  bool canReadRadio(String hookKey);

  /// Whether [watcher] is on for [feed]'s operation.
  bool isOnFor(WatcherDefinition watcher, WatcherFeed feed);

  /// Whether [watcher] is on for any open operation: what keeps its ticks
  /// running and its triggers produced.
  bool isOnAnywhere(WatcherDefinition watcher) => _feeds.any((feed) => feed._opened && isOnFor(watcher, feed));

  /// Whether the switches [isOnFor] reads moved between two contexts of one
  /// feed, which nothing in [PanelRenderContext.changesFrom] says.
  @protected
  bool switchesMoved(PanelRenderContext previous, PanelRenderContext next) => false;

  @protected
  Future<Map<String, dynamic>> readConfig(WatcherDefinition watcher);

  /// Calls [watcher]'s `observe` about [feed]'s operation with [args] — the
  /// `operation`, `qsoCount`, `config`, `reasons` and `clock` every call
  /// carries — plus what this kind adds. Throws when the hook does; false
  /// when there was no runtime to call.
  @protected
  Future<bool> observe(WatcherDefinition watcher, WatcherFeed feed, Map<String, dynamic> args);

  /// After every [reconcile]: what is on may have changed.
  @protected
  void reconciled() {}

  /// [feed]'s view closed.
  @protected
  void feedClosed(WatcherFeed feed) {}

  /// [feed] was handed a context, [previous] the one it held before. Before
  /// anything is fired for it.
  @protected
  void contextMoved(WatcherFeed feed, PanelRenderContext previous) {}

  /// [reason] was just queued for [watcher]'s call about [feed]: the moment
  /// it fired, which may be a pacing gap before the call it folds into.
  @protected
  void fired(WatcherDefinition watcher, WatcherFeed feed, String reason) {}

  /// The views open on an operation, oldest first.
  @protected
  Iterable<WatcherFeed> get openedFeeds => _feeds.where((feed) => feed._opened && !feed._closed);

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    runtimeGeneration.removeListener(_onRuntimeReplaced);
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

  List<WatcherDefinition> _catalog = const [];
  int _refreshSeq = 0;

  /// Every watcher the extensions offer, on or off.
  List<WatcherDefinition> get catalog => _catalog;

  /// Whether a watcher that is on declared [trigger]. A view producing a
  /// signal only for those who asked (the draft per keystroke, the spots
  /// revision) asks this beside its panes.
  bool wants(String trigger) => _catalog.any((watcher) => watcher.triggers.contains(trigger) && isOnAnywhere(watcher));

  /// The watcher's settings were edited: each operation it is on for hears
  /// of it at once, as `config`, since nothing else would wake one without
  /// triggers.
  void configChanged(WatcherDefinition watcher) {
    for (final feed in _feeds) {
      if (isOnFor(watcher, feed)) _fire(watcher, feed, 'config');
    }
  }

  void _onRuntimeReplaced() => unawaited(refresh());

  /// Re-reads what the extensions offer.
  Future<void> refresh() async {
    final seq = ++_refreshSeq;
    final entries = await fetchCatalog();
    if (seq != _refreshSeq || _disposed) return;
    // Could not ask: the watchers already known keep running.
    if (entries == null) return;
    final watchers = <WatcherDefinition>[];
    final seen = <String>{};
    for (final entry in entries) {
      final watcher = WatcherDefinition.fromEntry(entry, kind: kind, refused: refusedTriggers);
      if (watcher == null) {
        debugPrint('[${kind}s] ignoring an entry from "${entry['hookKey']}": needs a key and a title');
        continue;
      }
      if (!seen.add(watcher.id)) {
        debugPrint('[${kind}s] "${watcher.id}" is already claimed; ignoring the duplicate');
        continue;
      }
      for (final trigger in const ['radio', 'equipment']) {
        if (watcher.triggers.contains(trigger) && !canReadRadio(watcher.hookKey)) {
          debugPrint('[${kind}s] "${watcher.id}" declares "$trigger", which never fires: its extension does not declare requiresRadioRead');
        }
      }
      watchers.add(watcher);
    }
    _catalog = watchers;
    reconcile();
    notifyListeners();
  }

  final List<WatcherFeed> _feeds = [];
  final Map<(String, WatcherFeed), _Slot> _slots = {};

  WatcherFeed openFeed() {
    final feed = WatcherFeed._(this);
    _feeds.add(feed);
    return feed;
  }

  void _openFeed(WatcherFeed feed) {
    for (final watcher in _catalog) {
      if (isOnFor(watcher, feed)) _fire(watcher, feed, 'open');
    }
    // A watcher on only for this operation has had no ticks running.
    _armMissingTicks();
  }

  void _feedChanged(WatcherFeed feed, Set<String> changes) {
    for (final watcher in _catalog) {
      if (!isOnFor(watcher, feed)) continue;
      final fired = changes.intersection(watcher.triggers.toSet());
      // The switches and rotators are the radio's to read, as the `radio`
      // trigger is.
      if (!canReadRadio(watcher.hookKey)) fired.remove('equipment');
      for (final reason in fired) {
        _fire(watcher, feed, reason);
      }
    }
  }

  void _closeFeed(WatcherFeed feed) {
    _feeds.remove(feed);
    _slots.removeWhere((key, slot) {
      if (key.$2 != feed) return false;
      slot.cancel();
      return true;
    });
    feedClosed(feed);
  }

  /// Brings the slots and tickers in line with what is on: a watcher switched
  /// on, or newly offered, hears `open` for every operation already open that
  /// it is on for; one switched off, or gone, loses whatever it was owed.
  @protected
  void reconcile() {
    final offered = {for (final watcher in _catalog) watcher.id: watcher};
    final reopen = <(String, WatcherFeed)>{};
    _slots.removeWhere((key, slot) {
      final current = offered[key.$1];
      if (current == null || !isOnFor(current, key.$2)) {
        slot.cancel();
        slot.retired = true;
        return !slot.running;
      }
      // Re-offered by a new runtime, or switched back on: it hears `open`
      // again, through the same slot, after any call still out.
      if (slot.retired || !identical(current, slot.watcher)) reopen.add(key);
      slot.watcher = current;
      slot.retired = false;
      return false;
    });
    for (final watcher in _catalog) {
      for (final feed in _feeds) {
        if (!feed._opened || !isOnFor(watcher, feed)) continue;
        final key = (watcher.id, feed);
        if (!_slots.containsKey(key) || reopen.contains(key)) _fire(watcher, feed, 'open');
      }
    }
    _restartTicks();
    _dialSeen = radio?.state();
    reconciled();
  }

  void _fire(WatcherDefinition watcher, WatcherFeed feed, String reason) {
    if (_disposed || feed._closed || !feed._opened) return;
    final slot = _slots.putIfAbsent((watcher.id, feed), () => _Slot(watcher, feed));
    slot.pending.add(reason);
    fired(watcher, feed, reason);
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
    final watcher = slot.watcher;
    final failureKey = '$kind:${watcher.id}';
    // Only a call that went out paces the next: one that stopped short
    // would hold an `open` a whole gap for nothing.
    var called = false;
    try {
      final config = await readConfig(watcher);
      // Owed from before its operation stopped having it on (which only a
      // feed whose operation was replaced can be), or its view closed while
      // the settings were read: a call now would be about an operation no
      // longer open.
      if (_disposed || slot.feed._closed || !isOnFor(watcher, slot.feed)) return;
      final context = slot.feed.context;
      final operation = context.operation;
      if (operation == null) return;
      called = true;
      final answered = await observe(watcher, slot.feed, {
        'operation': operationHookArgs(operation),
        'qsoCount': context.qsoCount,
        'config': config,
        'reasons': reasons,
        'clock': {'nowMillis': nowMillis(), 'realNowMillis': realNowMillis()},
      });
      // No runtime is no call: it says nothing about whether the watcher works.
      if (answered) ErrorReportingService.recordSuccess(failureKey);
    } catch (e, stack) {
      // A watcher has no pane to show its failure in. The console line is
      // the author's; a streak is the operator's, through the policy.
      debugPrint('[${kind}s] ${watcher.id} failed on ${reasons.join(', ')}: $e');
      ErrorReportingService.reportIfRepeated(failureKey, e, stack, context: failureKey);
    } finally {
      slot.running = false;
      if (called) slot.lastEndedAt = realNowUtc();
      final key = (slot.watcher.id, slot.feed);
      if (!_disposed && identical(_slots[key], slot)) {
        if (slot.retired) {
          _slots.remove(key);
        } else {
          _schedule(slot);
        }
      }
    }
  }

  // Ticks: one chain per watcher that is on anywhere, aimed at wall-clock
  // boundaries as a panel's are, delivered to every open operation it is on
  // for.

  final Map<String, Timer> _ticks = {};

  void _restartTicks() {
    for (final timer in _ticks.values) {
      timer.cancel();
    }
    _ticks.clear();
    _armMissingTicks();
  }

  void _armMissingTicks() {
    for (final watcher in _catalog) {
      if (!_ticks.containsKey(watcher.id) && isOnAnywhere(watcher)) _armTick(watcher);
    }
  }

  void _armTick(WatcherDefinition watcher) {
    final period = panelTickPeriod(watcher.triggers);
    if (period == null || _disposed) return;
    final delay = panelTickDelayMillis(periodMs: period.inMilliseconds, nowMillis: nowMillis(), speed: AppClock.instance.speed);
    _ticks[watcher.id] = Timer(Duration(milliseconds: delay), () {
      _ticks.remove(watcher.id);
      // Re-armed whatever happens: nothing else restarts a chain that broke.
      try {
        for (final feed in List.of(_feeds)) {
          if (isOnFor(watcher, feed)) _fire(watcher, feed, 'tick');
        }
      } finally {
        if (!_disposed && _catalog.contains(watcher) && isOnAnywhere(watcher)) _armTick(watcher);
      }
    });
  }

  /// Travel moves the boundaries the pending ticks were aimed at.
  void _onClockTravel() {
    if (_disposed) return;
    _restartTicks();
  }

  List<Object?>? _dialSeen;

  /// Runs on every meter reading, several a second: nothing is read unless a
  /// watcher that is on asked for the radio.
  void _onRadio() {
    if (!wants('radio')) return;
    final dial = radio?.state();
    if (_disposed || dial == null || listEquals(dial, _dialSeen)) return;
    _dialSeen = dial;
    for (final watcher in _catalog) {
      if (!watcher.triggers.contains('radio') || !canReadRadio(watcher.hookKey)) continue;
      for (final feed in _feeds) {
        if (isOnFor(watcher, feed)) _fire(watcher, feed, 'radio');
      }
    }
  }
}
