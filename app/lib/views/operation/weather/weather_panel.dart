// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// One weather pane: the current reading, large, over a curve of the next
// eight hours.
//
// Location either follows the OPERATION's own grid, so the pane works the
// moment it's placed inside one, or is a typed override — a grid square or
// lat/lon, handy for checking a summit before driving to it, and the only
// option outside an operation (Home, the Logs view). Deliberately not the
// device's GPS: that is a permission prompt for a panel that only wants a
// rough position.
//
// The forecast is a public SVG scene. Native code retains the location,
// fetching, stale-data handling and responsive header shared with older layouts.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:http/http.dart' as http;

import '../../../config/user_agent.dart';
import 'package:halo_i18n/halo_i18n.dart';
import '../../../services/panel_service.dart';
import '../../../services/settings_service.dart';
import '../svg_scene/scene_view.dart';
import 'weather_scene.dart';
import 'weather_codes.dart';
import 'weather_reading.dart';

/// The panel id the view registers this pane under. Shared rather than
/// spelled twice: the dock matches placements against it, and a rename that
/// reached only the registration would route the pane to the missing-panel
/// fallback.
const String weatherPanelId = 'weather';

const String weatherLocationKey = 'location';

/// Whether the pane follows the operation's own grid rather than
/// [weatherLocationKey]'s typed override. Absent from an older saved config,
/// which is why [_WeatherPanelState._useOperationLocation] falls back to
/// "was there a typed override" rather than treating a missing key as false.
const String weatherUseOperationLocationKey = 'useOperationLocation';

/// How long a reading stands before it is refetched.
const Duration weatherMaxAge = Duration(minutes: 15);

/// Capped well under the pane's own patience: a forecast that arrives late is
/// worth nothing, and the periodic refresh will be along shortly.
const Duration _fetchTimeout = Duration(seconds: 8);

/// The fetch, injectable so a widget test never opens a socket. Answers with
/// the status and the body; a transport failure throws, which is the
/// distinction [_Failure.transport] is drawn from.
typedef WeatherFetch = Future<({int status, String body})> Function(Uri url);

Future<({int status, String body})> _httpFetch(Uri url) async {
  final response = await http.get(url, headers: {'User-Agent': await ham2kUserAgentOrFallback()}).timeout(_fetchTimeout);
  return (status: response.statusCode, body: response.body);
}

/// Whether the panel should ask the service again.
///
/// A free function, not a method, because it is the panel's whole refresh
/// policy and the `State` around it cannot be driven far enough to test one:
/// `fakeAsync` does not move the app clock, so a widget test that pumps
/// fifteen minutes fires the timer against a `now` that never moved, and
/// every branch below reads as "not due".
///
/// [realNow] and [now] are deliberately different clocks. [now] is the app
/// clock, so a forecast stops covering the hours the rest of the app is
/// showing the moment DEVTT moves them. [realNow] paces requests to a third
/// party and must not travel — docs/design/time.md.
bool weatherFetchIsDue({
  required String? key,
  required String? attemptKey,
  required DateTime? attemptedAtReal,
  required DateTime realNow,
  required String? readingKey,
  required WeatherReading? reading,
  required DateTime now,
}) {
  if (key == null) return false;
  // A different place or unit system is a different question, and worth
  // asking the moment the operator asks it — the floor below is about
  // repeating a question, not about answering a new one.
  if (attemptKey != key) return true;
  // However many times something invites a retry. `SettingsService` notifies
  // on background sync writes, and each one reaches this: without the floor,
  // an operator with no signal sends a request per sync tick.
  if (attemptedAtReal != null && realNow.difference(attemptedAtReal) < _retryFloor) return false;
  if (readingKey != key || reading == null) return true;
  if (now.difference(reading.fetchedAtUtc) >= weatherMaxAge) return true;
  // The app clock can be moved out from under a forecast (DEVTT), and it is
  // moved in hours. A response that no longer covers the hours being asked
  // about is stale however recently it arrived.
  return reading.hoursFrom(now).length < 2;
}

/// How long the same question waits before being asked again.
const Duration _retryFloor = Duration(minutes: 1);

/// Why the last fetch failed. Kept apart from the reading so a failure never
/// erases a good one — and so the pane can say whether the service answered
/// badly or never answered at all, which are different problems with
/// different remedies. An operator told "no network" goes looking for signal,
/// which is wasted effort when the truth is a 503 or a reshaped feed.
class _Failure {
  final bool transport;

  const _Failure({required this.transport});
}

class WeatherPanel extends StatefulWidget {
  /// The placement's id — the key this pane's config is stored under.
  final String panelId;

  final PanelService panels;
  final SettingsService settings;

  /// The operation's own grid, used when the pane's settings name no
  /// location of their own.
  final String? operationGrid;

  final ValueChanged<String?>? onTitle;

  /// Null outside tests, where [_httpFetch] is used.
  final WeatherFetch? fetch;

  const WeatherPanel({super.key, required this.panelId, required this.panels, required this.settings, this.operationGrid, this.onTitle, this.fetch});

  @override
  State<WeatherPanel> createState() => _WeatherPanelState();
}

class _WeatherPanelState extends State<WeatherPanel> with WidgetsBindingObserver {
  Map<String, dynamic> _config = const {};
  int _configRevision = 0;
  bool _configLoaded = false;

  WeatherReading? _reading;

  /// What [_reading] is OF — place and units. A reading whose key no longer
  /// matches what the pane is being asked for is not shown: relabelling last
  /// summit's forecast with this one's name is the one failure an operator
  /// cannot detect.
  String? _readingKey;

  _Failure? _failure;

  /// What [_failure] is ABOUT, for the same reason [_readingKey] exists. An
  /// unkeyed failure outlives the question that produced it: fail on a bad
  /// connection, then edit the location, and the pane asserts "no network"
  /// about a place it has not yet asked about — and does it in preference to
  /// the spinner, so it shows its worst information while better is in hand.
  String? _failureKey;

  bool _fetching = false;

  /// The last question asked of the service, and when it was really asked.
  ///
  /// REAL time, not the app clock: this paces requests to a third party, and
  /// docs/design/time.md puts anything protecting a protocol on `realNowUtc`.
  /// A developer time-travelling a day forward must not turn into a burst.
  String? _attemptKey;
  DateTime? _attemptedAtReal;

  /// Keyed by WHAT is in flight, not merely that something is. A location
  /// edit landing mid-flight starts a second request; without the key the
  /// older one's answer would install itself over the newer one's.
  String? _inFlightKey;

  Timer? _refresh;

  /// False while nobody can see this pane — behind another dock tab, or the
  /// whole app minimized/backgrounded. A pane in a dock group stays MOUNTED
  /// behind its neighbour, so without this every weather pane in a saved
  /// layout keeps a 15-minute fetch running for a view nobody is looking at.
  bool _dockVisible = true;
  bool _appVisible = true;

  @override
  void initState() {
    super.initState();
    // Null before the first platform message, which is not evidence of being
    // hidden.
    final state = WidgetsBinding.instance.lifecycleState;
    _appVisible = state == null || _visibleIn(state);
    WidgetsBinding.instance.addObserver(this);
    widget.panels.addListener(_onCatalogChanged);
    widget.settings.addListener(_onSettingsChanged);
    _configRevision = widget.panels.configRevision(widget.panelId);
    unawaited(_loadConfig());
  }

  static bool _visibleIn(AppLifecycleState state) => state == AppLifecycleState.resumed || state == AppLifecycleState.inactive;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final visible = _visibleIn(state);
    if (visible == _appVisible) return;
    _appVisible = visible;
    _syncRefresh();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _dockVisible = DockPaneVisibility.of(context);
    _syncRefresh();
  }

  @override
  void didUpdateWidget(WeatherPanel old) {
    super.didUpdateWidget(old);
    if (old.panels != widget.panels) {
      old.panels.removeListener(_onCatalogChanged);
      widget.panels.addListener(_onCatalogChanged);
    }
    if (old.settings != widget.settings) {
      old.settings.removeListener(_onSettingsChanged);
      widget.settings.addListener(_onSettingsChanged);
    }
    if (old.panelId != widget.panelId) {
      _configRevision = widget.panels.configRevision(widget.panelId);
      // Back to unread, so nothing acts on the PREVIOUS placement's override
      // in the frames before the new one's arrives.
      _configLoaded = false;
      unawaited(_loadConfig());
    } else if (old.operationGrid != widget.operationGrid) {
      // Costs nothing when an override is set: the grid is not in `_key`
      // then, so `_due` finds nothing to do.
      _syncRefresh();
    }
  }

  @override
  void dispose() {
    _refresh?.cancel();
    widget.panels.removeListener(_onCatalogChanged);
    widget.settings.removeListener(_onSettingsChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// This pane's own config was edited. Nothing else would tell it — the form
  /// is host-persisted and the catalog is the only thing that notices.
  void _onCatalogChanged() {
    final revision = widget.panels.configRevision(widget.panelId);
    if (revision == _configRevision) return;
    _configRevision = revision;
    unawaited(_loadConfig());
  }

  /// The distance preference stands in for a unit SYSTEM here, so switching
  /// it has to refetch: Open-Meteo is asked for °F or °C, and relabelling the
  /// number already on screen would be a lie rather than a conversion.
  void _onSettingsChanged() {
    if (!mounted) return;
    _syncRefresh();
  }

  Future<void> _loadConfig() async {
    final panel = widget.panels[widget.panelId];
    // A panel the catalog cannot explain has no form, so there is nothing to
    // wait for — as opposed to a form not yet read, which [_syncRefresh]
    // refuses to act on.
    final config = panel == null ? const <String, dynamic>{} : await widget.panels.configFor(panel);
    if (!mounted) return;
    setState(() {
      _config = config;
      _configLoaded = true;
    });
    // From here, not only from a successful fetch: the tab is named after the
    // override, which this just read, and a name that waited for the network
    // would keep the previous place's while the body says the new one cannot
    // be read.
    _announceTitle();
    _syncRefresh();
  }

  bool get _fahrenheit => widget.settings.distanceUnits == DistanceUnits.miles;

  String get _override => (_config[weatherLocationKey] as String? ?? '').trim();

  /// Whether the pane follows the operation's grid rather than [_override].
  /// A config that never wrote this key is read as "follow the operation"
  /// exactly when [_override] is blank — an empty override defers to the
  /// operation, and a typed one wins outright — so an older placement's
  /// behavior stays identical without a migration step.
  bool get _useOperationLocation => _config[weatherUseOperationLocationKey] as bool? ?? _override.isEmpty;

  /// Null when the pane has nowhere to look — following the operation
  /// outside one, or with no grid set, or a blank override — and also when
  /// the override is there but unreadable, which [_overrideIsBad] tells
  /// apart.
  WeatherPlace? get _place => _useOperationLocation ? parseWeatherPlace(widget.operationGrid) : parseWeatherPlace(_override);

  bool get _overrideIsBad => !_useOperationLocation && _override.isNotEmpty && parseWeatherPlace(_override) == null;

  /// What a reading is OF. Rounded to two places so a grid square's centre
  /// and the same square typed as lat/lon are one reading, not two.
  String? get _key {
    final place = _place;
    if (place == null) return null;
    return '${place.latitude.toStringAsFixed(2)},${place.longitude.toStringAsFixed(2)}'
        '/${_fahrenheit ? 'F' : 'C'}';
  }

  bool get _visible => _dockVisible && _appVisible;

  /// The single place that decides whether the timer runs and whether a fetch
  /// is due. Called from every edge that could change either answer — config,
  /// settings, visibility, the operation's grid — rather than each of them
  /// reasoning about timers on its own.
  void _syncRefresh() {
    // Ahead of everything: this runs from `didChangeDependencies`, which is
    // long before the pane's own config has been read. Acting there would
    // send a request for the OPERATION's location on every mount — wasted for
    // an operator who set an override, and briefly drawn as if it were theirs.
    if (!_configLoaded) return;
    if (!_visible || _key == null) {
      _refresh?.cancel();
      _refresh = null;
      return;
    }
    _refresh ??= Timer.periodic(weatherMaxAge, (_) => unawaited(_fetchIfDue()));
    unawaited(_fetchIfDue());
  }

  bool get _due => weatherFetchIsDue(
    key: _key,
    attemptKey: _attemptKey,
    attemptedAtReal: _attemptedAtReal,
    realNow: realNowUtc(),
    readingKey: _readingKey,
    reading: _reading,
    now: nowUtc(),
  );

  Future<void> _fetchIfDue() async {
    if (!_due) return;
    final key = _key;
    final place = _place;
    if (key == null || place == null || _inFlightKey == key) return;

    _inFlightKey = key;
    _attemptKey = key;
    _attemptedAtReal = realNowUtc();
    if (mounted) setState(() => _fetching = true);

    WeatherReading? reading;
    _Failure? failure;
    // Only the fetch and the parse. The state update and the title callback
    // are deliberately outside: `_announceTitle` reaches the VIEW's state,
    // which setStates in turn, so a fault there would be caught here, told to
    // the operator as "no network", and logged against the wrong subsystem —
    // for a fetch that succeeded.
    try {
      final fetch = widget.fetch ?? _httpFetch;
      final response = await fetch(weatherRequestUrl(place, fahrenheit: _fahrenheit));
      // The body, not just the status: Open-Meteo answers a bad request with
      // `{"reason":"Latitude must be in range …"}`, which is the single most
      // useful string in the whole failure and is otherwise thrown away.
      if (response.status != 200) throw _BadAnswer('status ${response.status}: ${_excerpt(response.body)}');
      reading = parseWeatherReading(response.body, fetchedAtUtc: nowUtc(), fahrenheit: _fahrenheit);
      // Declined, not failed — and the parse does not say which of its
      // reasons applied, so the body is what a developer has to go on.
      if (reading == null) throw _BadAnswer('unreadable forecast: ${_excerpt(response.body)}');
    } catch (e, stack) {
      // `parseWeatherReading` is total, so what reaches here is the fetch —
      // which makes "not a bad answer" a sound reading of "no network".
      failure = _Failure(transport: e is! _BadAnswer);
      // For the author, never the operator — the same shape every other
      // network path in the app uses, stack included, because a reshaped feed
      // is otherwise undebuggable.
      debugPrint('[weather] fetch failed: $e\n$stack');
    } finally {
      // Only if it is still OURS: a location edit landing mid-flight took the
      // slot, and clearing unconditionally would let this older request open
      // a third for a place two have already been sent for.
      if (_inFlightKey == key) _inFlightKey = null;
    }

    // Superseded while this was on the wire. A location edit starts a second
    // request without cancelling this one, so the older answer arrives last
    // and would otherwise install itself — leaving `_readingKey` naming a
    // place the pane is no longer showing, which `build` resolves to no
    // reading, no failure and no spinner: a blank pane until the 15-minute
    // timer comes round. `_inFlightKey` cannot answer this, because the
    // `finally` above has already cleared it for the request that won.
    if (!mounted || _attemptKey != key) return;
    setState(() {
      _fetching = false;
      if (reading != null) {
        _reading = reading;
        _readingKey = key;
        _failure = null;
        _failureKey = null;
      } else {
        _failure = failure;
        _failureKey = key;
      }
    });
    if (reading != null) _announceTitle();
  }

  /// Enough of a response body to name what went wrong, and no more — this
  /// goes to the console, and a forecast body is 40 KB of numbers.
  static String _excerpt(String body) {
    final trimmed = body.trim();
    return trimmed.length <= 200 ? trimmed : '${trimmed.substring(0, 200)}…';
  }

  /// Names the tab after the place, so a pane following a summit is told
  /// apart from the operation's own weather. After the setState, never from
  /// build: this reaches the VIEW's state, which setStates in turn.
  void _announceTitle() {
    final onTitle = widget.onTitle;
    if (onTitle == null) return;
    final override = _override;
    onTitle(override.isEmpty ? null : override.toUpperCase());
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.operation.layout.panels;
    if (_overrideIsBad) return _message(t.weatherBadLocation(location: _override));
    if (_place == null) {
      // Not while the config is still being read: a pane that flashed "no
      // location" on every mount would accuse the operator of not having set
      // one they had.
      return _configLoaded ? _message(t.weatherNoLocation) : const SizedBox.shrink();
    }

    final reading = _readingKey == _key ? _reading : null;
    if (reading == null) {
      // Keyed, like the reading: a failure about somewhere else is not news
      // about here, and saying it would pre-empt the spinner for a fetch
      // already in flight.
      final failure = _failureKey == _key ? _failure : null;
      if (failure != null) {
        return _message(failure.transport ? t.weatherUnreachable : t.weatherUnreadable);
      }
      return Center(child: SizedBox.square(dimension: 24, child: _fetching ? const CircularProgressIndicator(strokeWidth: 2) : null));
    }
    return _WeatherReadout(reading: reading, staleFetch: _failure != null);
  }

  Widget _message(String text) => Padding(
    padding: EdgeInsets.all(Space.xl).add(PaneSafeArea.paddingOf(context)),
    child: Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ),
  );
}

/// A response that ARRIVED and was not usable, as opposed to one that never
/// arrived — the two the operator is told apart.
class _BadAnswer implements Exception {
  final String message;

  const _BadAnswer(this.message);

  @override
  String toString() => message;
}

/// What the pane draws once it has something to draw. Split from the fetching
/// State so the layout can be pumped from a test with a reading in hand,
/// without a socket, a timer or a config store.
class _WeatherReadout extends StatelessWidget {
  final WeatherReading reading;

  /// A good reading with a failed refresh behind it. Worth saying: weather is
  /// the one thing here an operator acts on physically, and a failing fetch
  /// would otherwise leave a reading on screen indefinitely looking current.
  final bool staleFetch;

  const _WeatherReadout({required this.reading, required this.staleFetch});

  /// What the READING is inset by. The chart and the hour strip deliberately
  /// ignore this and run to the pane's edges: the curve is the pane's
  /// background, and an inset one reads as a chart that was dropped into a
  /// box rather than as weather behind the numbers.
  ///
  /// The bottom is the gap the curve may not close: a warm first hour puts
  /// the peak at the very top of the chart's band, and without this it
  /// arrives against the underside of the detail chips.
  static const EdgeInsets _inset = EdgeInsets.fromLTRB(Space.xl, Space.lg, Space.xl, Space.lg);

  /// The temperature's line height. Named because the layout divides by it —
  /// the row's height IS this times the font size (the glyph beside it is
  /// smaller), so a change here that did not reach [build] would let the
  /// reading overflow the Column in a short pane.
  static const double _tempLineHeight = 1.05;

  /// The hour strip's own height, including the [_stripBottom] under it.
  ///
  /// Scaled by the OS text scaler at use, never used raw: the glyph is a
  /// fixed 16pt but the label under it is not, so an accessibility text size
  /// overflows a fixed band at about 1.13x. Same treatment as the activities
  /// search band (docs/design/ui-scaling.md §3 — the OS preference composes
  /// on top of the app's own Font Scale).
  static const double _stripHeight = 44;
  static const double _stripBottom = Space.md;

  /// The narrowest an hour column may be — its own glyph, which is a fixed
  /// 16pt and does not shrink with the column.
  static const double _stripColumnFloor = 16;

  /// One line of the smallest type the panel draws (`labelSmall`, which the
  /// corner stamp uses). The pane's own lower bound is built from it.
  static const double _smallestLine = 16;

  /// The pane heights below which each layer stops earning its space, and the
  /// width below which the detail chips do. The width floor is measured on
  /// the CONTENT box — what the chips are actually handed — because they are
  /// inside [_inset] while the layers around them are not.
  static const double _stripFloor = 150;

  /// Tuned against the one thing that made it knowable: the chips are a
  /// single run ([_details]), so the reading's height is the temperature row
  /// plus two fixed lines. Below this the chip run would take the band the
  /// curve needs, and the panel would show the operator everything about the
  /// weather except the forecast.
  static const double _detailFloor = 205;
  static const double _detailContentWidthFloor = 120;

  /// Below this the pane is a sliver, and the temperature plus its inset is
  /// all that fits. The glyph beside it still names the sky, so what goes is
  /// the naming of it in words — and it goes rather than overflowing, which
  /// is what a fixed inset around a fixed line does in a pane this short.
  static const double _conditionFloor = 76;

  /// The chart's OWN minimum height, not the pane's. It takes whatever the
  /// reading and the strip leave, so how much that is depends on the type
  /// they were laid out at — which only the chart's own constraints know.
  /// Below this a curve is a smear rather than a shape. Deliberately low: in
  /// a wide, short pane a 20pt band still reads as a trend across eight
  /// hours, and the alternative there is a wide band of nothing.
  static const double _chartFloor = 20;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = HaLoColors.of(context).onSurfaceAccent;
    final safe = PaneSafeArea.paddingOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final box = Size(constraints.maxWidth - safe.horizontal, constraints.maxHeight - safe.vertical);
        // Nothing at all below one line of the smallest text plus the inset.
        // A Column cannot shrink a Text, so what happens instead of this is a
        // RenderFlex overflow on every frame — in a pane far too small to
        // read. Derived rather than a constant, because the scaler moves it.
        final smallestLine = MediaQuery.textScalerOf(context).scale(_smallestLine);
        if (box.width <= 0 || box.height < _inset.vertical + smallestLine) {
          return const SizedBox.shrink();
        }

        final now = nowUtc();
        final hours = reading.hoursFrom(now);
        final condition = weatherConditionFor(reading.code, isDay: reading.isDay);

        // What the reading gets, as opposed to what the curve behind it does.
        // Floored at zero: the inset is a fixed 32pt, so any pane narrower
        // than that makes this negative — and a negative upper bound inverts
        // `clamp`'s limits, which THROWS out of build. The dock floors a pane
        // extent at 0 and only enforces its 120pt minimum while dragging, so
        // a layout saved in a wide window and reopened in a narrow one
        // arrives here well under 32.
        final contentWidth = math.max(0.0, box.width - _inset.horizontal);

        final hasForecast = hours.length >= 2;
        final stripHeight = MediaQuery.textScalerOf(context).scale(_stripHeight);
        // The floor rises by exactly what the scaler added, so a larger strip
        // does not start taking the curve's band instead of standing down.
        // Width matters too: a column narrower than the glyph it holds is not
        // a strip, it is eight clipped icons.
        final showStrip = hasForecast && box.height >= _stripFloor - _stripHeight + stripHeight && box.width / hours.length >= _stripColumnFloor;
        final showDetails = box.height >= _detailFloor && contentWidth >= _detailContentWidthFloor;

        // The size the pane would like, then what it can actually pay for in
        // both directions.
        //
        // The 22pt floor gives way before the LAYOUT does. The reading is the
        // Column's one non-flexible child, so a floor the pane's height
        // cannot cover does not shrink the curve — it overflows the Column,
        // on every frame. 22pt of numeral plus the 24pt inset already needs
        // 47pt of pane, which a dock pane can go under.
        final roomForTemp = math.max(0.0, box.height - _inset.vertical);
        final tempSize = math.min(math.min(math.max(box.height * 0.26, 22.0), 60.0), math.min(roomForTemp / _tempLineHeight, contentWidth * 0.30));
        final tempStyle = theme.textTheme.displaySmall?.copyWith(
          fontSize: tempSize,
          height: _tempLineHeight,
          fontWeight: FontWeight.w300,
          color: scheme.onSurface,
          fontFeatures: const [FontFeature.tabularFigures()],
        );

        final readout = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Scaled down to fit rather than clipped or ellipsised: the
            // temperature is the one thing on this panel that must survive
            // every pane size, and a unit label the API renames longer ("°F"
            // becoming "degF") must not be able to cut the number off.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(condition.icon, size: tempSize * 0.86, color: accent),
                  SizedBox(width: Space.sm),
                  Text('${reading.temperature.round()}${reading.units.temperature}', style: tempStyle),
                ],
              ),
            ),
            if (box.height >= _conditionFloor)
              Text(
                _conditionText(context, condition.key),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
          ],
        );

        // A Column, not a Stack: the curve takes whatever the reading and the
        // strip leave, rather than starting at a fraction of the pane. A
        // fraction is wrong at both ends — the temperature stops growing at
        // its cap, so a tall pane would open a dead band under the reading,
        // and a short one would have the curve climbing toward text it has to
        // stay clear of.
        //
        // Only the reading is inset. The chart and the strip are full-bleed
        // children of the same Column, which is what puts the curve against
        // the pane's edges while the numbers keep their margin.
        return Padding(
          padding: safe,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: _inset,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: readout),
                        // A narrow pane shrinks the temperature to fit rather
                        // than wrapping, so without this gap the reading
                        // arrives hard against the stamp and the two read as
                        // one string.
                        SizedBox(width: Space.md),
                        // The zone label exists to explain hours that are not
                        // UTC, so it earns its line only where hours are
                        // shown.
                        _stamp(context, showZone: showStrip || showDetails),
                      ],
                    ),
                    // Below that row rather than inside it: the chips are
                    // measured against the width they get, and inside the row
                    // that width is whatever the stamp leaves — which
                    // `contentWidth` does not know.
                    if (showDetails) ...[SizedBox(height: Space.md), _details(context, now, contentWidth)],
                  ],
                ),
              ),
              if (hasForecast)
                Expanded(
                  child: LayoutBuilder(
                    // Its OWN height, which is the only place that knows what
                    // the reading actually took: a pane that clears every
                    // floor can still leave nothing here once the type is
                    // laid out.
                    builder: (context, chartBox) => chartBox.maxHeight < _chartFloor
                        ? const SizedBox.shrink()
                        : SvgSceneView(
                            // A changed location/hour window must not retain an
                            // inspection index that referred to another forecast.
                            key: ValueKey('${hours.first.utc}:${reading.units.temperature}'),
                            scene: weatherScene(
                              size: Size(chartBox.maxWidth, chartBox.maxHeight),
                              hours: hours,
                              unit: reading.units.temperature,
                              zone: reading.timezoneAbbreviation ?? '',
                              label: context.t.operation.tabs.weather,
                              line: accent,
                              rain: scheme.secondary,
                              baseline: scheme.outlineVariant,
                              surface: scheme.surface,
                              foreground: scheme.onSurface,
                              labelSize: theme.textTheme.labelSmall?.fontSize ?? 12,
                              labelHeight: MediaQuery.textScalerOf(context).scale(theme.textTheme.labelSmall?.fontSize ?? 12) * 1.6,
                            ),
                          ),
                  ),
                )
              else
                const Spacer(),
              if (showStrip)
                SizedBox(
                  height: stripHeight,
                  child: _HourStrip(hours: hours, accent: accent),
                ),
            ],
          ),
        );
      },
    );
  }

  String _conditionText(BuildContext context, String key) => context.t['operation.layout.panels.weatherConditions.$key'] as String;

  /// Wind, humidity, and whichever of sunrise/sunset comes next. Only the
  /// next one: both, in a pane this size, costs the row that carries the wind
  /// — and the one already behind you is not a forecast.
  ///
  /// **Exactly one run, or fewer chips.** These sit directly above the curve
  /// in a Column, so a run that wraps takes the band the curve was going to
  /// get — at a middling pane size that is the whole forecast gone to make
  /// room for a humidity reading. [_chipsFor] measures instead, and drops in
  /// a fixed order rather than letting the layout decide.
  Widget _details(BuildContext context, DateTime now, double available) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return DefaultTextStyle.merge(
      style: TextStyle(color: muted),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (index, chip) in _chipsFor(context, now, available).indexed) ...[
            if (index > 0) SizedBox(width: Space.lg),
            _chip(context, chip.icon, chip.text),
          ],
        ],
      ),
    );
  }

  /// The chips that fit [available] on one run.
  ///
  /// Humidity is dropped before the sun event and the sun event before the
  /// wind: an operator with a mast up cares about wind, then about how long
  /// the light lasts, and humidity is the one that only ever confirms what
  /// the sky already said.
  List<({IconData icon, String text})> _chipsFor(BuildContext context, DateTime now, double available) {
    final t = context.t.operation.layout.panels;
    final units = reading.units;

    final sunrise = reading.nextSunrise(now);
    final sunset = reading.nextSunset(now);
    final sunIsRise = sunrise != null && (sunset == null || sunrise.isBefore(sunset));
    final sun = sunIsRise ? sunrise : sunset;

    final wind = reading.windSpeed == null
        ? null
        : (
            icon: MdiIcons.weatherWindy,
            text: [
              // Spaced, unlike the temperature: Open-Meteo's speed labels are
              // words ("mp/h", "km/h"), and "11mp/h" reads as one token.
              '${reading.windSpeed!.round()} ${units.windSpeed}'.trim(),
              if (reading.windDirection case final degrees?) compassPoint(degrees),
              if (reading.windGusts case final gusts? when gusts > reading.windSpeed!) t.weatherGusts(speed: '${gusts.round()}'),
            ].join(' '),
          );
    final humidity = reading.humidity == null ? null : (icon: MdiIcons.waterPercent, text: '${reading.humidity}%');
    final sunChip = sun == null ? null : (icon: sunIsRise ? MdiIcons.weatherSunsetUp : MdiIcons.weatherSunsetDown, text: _hhmm(reading.atLocation(sun)));

    // Widest first, so the first candidate that fits is the most it can show.
    for (final candidate in [
      [wind, humidity, sunChip],
      [wind, sunChip],
      [wind],
      [sunChip],
    ]) {
      final chips = candidate.nonNulls.toList();
      if (chips.isNotEmpty && _runWidth(context, chips) <= available) return chips;
    }
    return const [];
  }

  double _runWidth(BuildContext context, List<({IconData icon, String text})> chips) {
    final style = Theme.of(context).textTheme.labelMedium ?? const TextStyle();
    var width = Space.lg * (chips.length - 1);
    for (final chip in chips) {
      // The glyph and the gap it sits in, then the label measured the way a
      // Text actually lays it out — `textWidth` folds in the ambient style and
      // the text scaler, so this does not under-measure at OS text sizes.
      width += _chipIcon + Space.xs + textWidth(context, chip.text, style);
    }
    return width;
  }

  static const double _chipIcon = 15;

  Widget _chip(BuildContext context, IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: _chipIcon, color: Theme.of(context).colorScheme.onSurfaceVariant),
      SizedBox(width: Space.xs),
      Text(text, style: Theme.of(context).textTheme.labelMedium, maxLines: 1),
    ],
  );

  /// Where and how long ago, in the corner. The age is not decoration: a
  /// failing fetch leaves a good reading on screen indefinitely, and this is
  /// the only thing that says so.
  Widget _stamp(BuildContext context, {required bool showZone}) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(color: staleFetch ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        // A leaf, so the per-second rebuild the shared heartbeat drives stops
        // here rather than re-running the pane's whole subtree.
        OncePerSecond(builder: (context, now) => Text(_ageText(context, now.difference(reading.fetchedAtUtc)), style: style)),
        if (showZone)
          if (reading.timezoneAbbreviation case final zone?) Text(zone, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
      ],
    );
  }

  String _ageText(BuildContext context, Duration age) {
    final t = context.t.operation.layout.panels;
    if (age.inMinutes < 1) return t.panelAgeNow;
    if (age.inHours < 1) return t.panelAgeMinutes(count: age.inMinutes);
    return t.panelAgeHours(count: age.inHours);
  }
}

String _hhmm(DateTime wall) => '${wall.hour.toString().padLeft(2, '0')}:${wall.minute.toString().padLeft(2, '0')}';

class _HourStrip extends StatelessWidget {
  final List<WeatherHour> hours;
  final Color accent;

  const _HourStrip({required this.hours, required this.accent});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Only at the bottom. Left and right stay flush, because a column's
    // centre has to land on its own point of the curve — the x mapping
    // weather_chart.dart calls a contract — and an inset strip slides every
    // label off the shape it describes.
    return Padding(
      padding: const EdgeInsets.only(bottom: _WeatherReadout._stripBottom),
      child: Row(
        children: [
          for (final (index, hour) in hours.indexed)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    weatherConditionFor(hour.code, isDay: hour.isDay).icon,
                    size: 16,
                    // The first column is the hour happening NOW, which is
                    // what the big reading above is describing; leaving it
                    // the same weight as the rest makes the two read as
                    // unrelated.
                    color: index == 0 ? accent : theme.colorScheme.onSurfaceVariant,
                  ),
                  SizedBox(height: Space.xxs),
                  Text(
                    hour.localHour.toString().padLeft(2, '0'),
                    // A column narrower than two digits would otherwise wrap
                    // the label onto a second line and burst the strip's
                    // fixed height.
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.clip,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: index == 0 ? accent : theme.colorScheme.onSurfaceVariant,
                      fontWeight: index == 0 ? FontWeight.w700 : null,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
