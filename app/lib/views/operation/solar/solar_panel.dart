// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// One solar pane: today's indices, large, over a month of flux, three days of
// planetary Kp, and the band-conditions grid.
//
// Native rather than an extension `panel` hook, for the reason
// docs/design/layouts.md gives for the clock and the weather panel: an
// extension contributes a DOCUMENT, and its SVG is compiled to a static
// instruction list, so a curve fitted to thirty fetched numbers is not
// something it can return.
//
// No settings, and nothing to configure: solar conditions are the same
// everywhere, so unlike Weather there is no location to ask about. What a
// small pane shows is decided by the pane's own size instead — see
// [_SolarReadout]'s floors.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:http/http.dart' as http;

import '../../../config/user_agent.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'solar_charts.dart';
import 'solar_reading.dart';

/// The panel id the view registers this pane under. Shared rather than
/// spelled twice: the dock matches placements against it, and a rename that
/// reached only the registration would route the pane to the missing-panel
/// fallback.
const String solarPanelId = 'solar';

/// How long a reading stands before it is refetched. hamqsl recomputes a few
/// times an hour and SWPC's Kp arrives every three, so anything shorter is a
/// request nobody reads a new answer from.
const Duration solarMaxAge = Duration(minutes: 15);

/// How long the same question waits before being asked again, whatever
/// invites a retry.
const Duration _retryFloor = Duration(minutes: 1);

/// Capped well under the pane's own patience: a reading that arrives late is
/// worth nothing, and the periodic refresh will be along shortly.
const Duration _fetchTimeout = Duration(seconds: 8);

/// The seven-day wind file's own, because it is 1.13MB and the eight seconds
/// above are sized for a 5KB one. A megabyte inside eight seconds needs a
/// sustained 1.2 Mbit/s, which a summit's cellular link routinely does not
/// have — and `Future.timeout` does not abort the request underneath it, so a
/// timeout that always fires costs the whole download and returns nothing.
const Duration _historyFetchTimeout = Duration(seconds: 45);

/// The fetch, injectable so a widget test never opens a socket. Answers with
/// the status and the body; a transport failure throws, which is the
/// distinction [_Failure.transport] is drawn from.
typedef SolarFetch = Future<({int status, String body})> Function(Uri url);

Future<({int status, String body})> _httpFetch(Uri url) => _request(url).timeout(
  url == solarWindHistoryUrl() ? _historyFetchTimeout : _fetchTimeout,
);

/// The timeout wraps THIS, resolving the User-Agent included. Left outside,
/// a UA resolution that never completes (it is a platform channel, and on web
/// it fetches `version.json` with no timeout of its own) strands the panel:
/// nothing clears the in-flight flag, so every later refresh returns at the
/// door and the pane spins forever with no message and no log.
Future<({int status, String body})> _request(Uri url) async {
  final response = await http.get(url, headers: {'User-Agent': await ham2kUserAgentOrFallback()});
  final String body;
  try {
    body = response.body;
  } on FormatException catch (e) {
    // `Response.body` decodes through the charset the response NAMES, and
    // throws on one Dart does not know as well as on malformed UTF-8. Left to
    // escape, it is not a `_BadAnswer` — so the elimination below reads it as
    // the network being down, and an operator whose proxy truncated a body
    // goes looking for signal.
    throw _BadAnswer('undecodable body (${response.headers['content-type']}): $e');
  }
  return (status: response.statusCode, body: body);
}

/// Whether the panel should ask the services again.
///
/// A free function, not a method, because it is the panel's whole refresh
/// policy and the `State` around it cannot be driven far enough to test one:
/// `fakeAsync` does not move the app clock, so a widget test that pumps
/// fifteen minutes fires the timer against a `now` that never moved, and
/// every branch below reads as "not due".
///
/// [realNow] and [now] are deliberately different clocks. [now] is the app
/// clock, so a reading goes stale in step with the rest of the app when DEVTT
/// moves it. [realNow] paces requests to third parties and must not travel —
/// docs/design/time.md.
bool solarFetchIsDue({
  required DateTime? attemptedAtReal,
  required DateTime realNow,
  required SolarReading? reading,
  required DateTime now,
}) {
  // However many times something invites a retry. Every visibility change
  // reaches this, and without the floor an operator switching between two
  // dock tabs sends a request per switch.
  if (attemptedAtReal != null && realNow.difference(attemptedAtReal) < _retryFloor) return false;
  if (reading == null) return true;
  return now.difference(reading.fetchedAtUtc) >= solarMaxAge;
}

/// Whether the 1.13MB seven-day wind file is worth asking for again.
///
/// Its own predicate, and a pure one, for the reason [solarFetchIsDue] is:
/// this is the panel's one expensive request, the rule is a clock comparison,
/// and a rule buried in a `State` method is one no test can reach without
/// moving real time.
///
/// REAL time only. There is no app-clock branch here because nothing about
/// this is about staleness of the DATA — the hourly feed keeps the recent end
/// current on its own. This paces a megabyte to a third party, and
/// docs/design/time.md puts anything protecting a protocol on the real clock.
bool solarWindHistoryIsDue({required DateTime? fetchedAtReal, required DateTime realNow}) {
  if (fetchedAtReal == null) return true;
  return realNow.difference(fetchedAtReal) >= solarWindHistoryInterval;
}

/// Why the last fetch failed. Kept apart from the reading so a failure never
/// erases a good one — and so the pane can say whether the service answered
/// badly or never answered at all, which are different problems with
/// different remedies. An operator told "no network" goes looking for signal,
/// which is wasted effort when the truth is a 503 or a reshaped feed.
class _Failure {
  final bool transport;

  const _Failure({required this.transport});
}

class SolarPanel extends StatefulWidget {
  /// Null outside tests, where [_httpFetch] is used.
  final SolarFetch? fetch;

  const SolarPanel({super.key, this.fetch});

  @override
  State<SolarPanel> createState() => _SolarPanelState();
}

class _SolarPanelState extends State<SolarPanel> with WidgetsBindingObserver {
  /// The week's wind, already averaged into three-hour buckets — what the
  /// chart draws, and all that is kept of the megabyte it came from.
  List<SolarPoint> _windHistory = const [];

  /// Raw one-minute readings gathered since that big fetch, from the hourly
  /// feed. Kept RAW rather than bucketed: the newest bucket is still filling,
  /// and averaging an average as each round adds to it would weight the first
  /// readings of the period far above the last. Bounded by
  /// [solarWindHistoryInterval] — the next big fetch clears it.
  List<SolarPoint> _windRecent = const [];

  SolarReading? _reading;
  _Failure? _failure;
  bool _fetching = false;

  /// The last good SWPC series, held across refreshes so one service's bad
  /// afternoon does not blank a chart that has a perfectly good month in it.
  /// Neither is part of the reading until it is built, which is what lets a
  /// hamqsl-only round keep both charts on screen.
  List<SolarPoint> _flux = const [];
  List<SolarPoint> _kp = const [];
  List<SolarPoint> _wind = const [];

  bool _inFlight = false;

  /// When the services were last really asked.
  ///
  /// REAL time, not the app clock: this paces requests to third parties, and
  /// docs/design/time.md puts anything protecting a protocol on `realNowUtc`.
  /// A developer time-travelling a day forward must not turn into a burst.
  DateTime? _attemptedAtReal;

  /// When the big seven-day wind file was last really fetched. REAL time, for
  /// the same reason [_attemptedAtReal] is: this paces a megabyte-sized
  /// request to a third party, and a developer time-travelling must not turn
  /// it into a burst.
  DateTime? _windHistoryAtReal;

  Timer? _refresh;

  /// False while nobody can see this pane — behind another dock tab, or the
  /// whole app minimized/backgrounded. A pane in a dock group stays MOUNTED
  /// behind its neighbour, so without this every solar pane in a saved layout
  /// keeps three fetches running for a view nobody is looking at.
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
  }

  static bool _visibleIn(AppLifecycleState state) =>
      state == AppLifecycleState.resumed || state == AppLifecycleState.inactive;

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
  void dispose() {
    _refresh?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool get _visible => _dockVisible && _appVisible;

  /// The single place that decides whether the timer runs and whether a fetch
  /// is due, so no caller has to reason about timers on its own.
  void _syncRefresh() {
    if (!_visible) {
      _refresh?.cancel();
      _refresh = null;
      return;
    }
    // HALF the age, deliberately. A tick at exactly `solarMaxAge` lands a
    // round-trip's worth BEFORE the reading turns stale — `fetchedAtUtc` is
    // stamped when the answer arrived, not when it was asked for — so the
    // due check says no and the pane actually refreshes on the following
    // tick, at twice the interval it advertises. The retry floor is what
    // keeps the extra ticks from becoming extra requests.
    _refresh ??= Timer.periodic(solarMaxAge ~/ 2, (_) => unawaited(_fetchIfDue()));
    unawaited(_fetchIfDue());
  }

  Future<void> _fetchIfDue() async {
    if (_inFlight) return;
    if (!solarFetchIsDue(
      attemptedAtReal: _attemptedAtReal,
      realNow: realNowUtc(),
      reading: _reading,
      now: nowUtc(),
    )) {
      return;
    }

    // Inside the try, with nothing between: this flag is the panel's only
    // guard, and it has no key to rotate the way the weather pane's does. A
    // throw before the `finally` is armed — `setState` during build reaches
    // here through `didChangeDependencies` — would strand it true, and every
    // later refresh returns at the door for the life of the pane.
    SolarReading? reading;
    _Failure? failure;
    List<Object?>? answers;
    try {
      _inFlight = true;
      _attemptedAtReal = realNowUtc();
      if (mounted) setState(() => _fetching = true);
      final fetch = widget.fetch ?? _httpFetch;
      // All four at once. The three series are additive — [_series] answers
      // with the previous one rather than throwing — so only hamqsl can fail
      // this round, and the charts survive a SWPC outage.
      // The big wind file only when it is due — everything else every round.
      final historyDue = solarWindHistoryIsDue(
        fetchedAtReal: _windHistoryAtReal,
        realNow: realNowUtc(),
      );
      // Stamped on the ATTEMPT and BEFORE the await, which is the whole
      // pacing guarantee. Stamped on the result instead, every way this round
      // can fail asks for the megabyte again on the next one: hamqsl throwing
      // takes `Future.wait` down before any result is read, and a history
      // fetch that times out on a slow link answers with the previous series
      // rather than an error. Either way the bytes were already pulled — a
      // timeout does not abort the request underneath it — so the retry is
      // pure cost, every 15 minutes, on the metered link that caused it.
      if (historyDue) _windHistoryAtReal = realNowUtc();
      final results = await Future.wait([
        _conditions(fetch),
        _series(fetch, solarFluxSeriesUrl(), parseFluxSeries, _flux),
        _series(fetch, solarKpSeriesUrl(), parseKpSeries, _kp),
        _series(fetch, solarWindSeriesUrl(), parseSolarWindSeries, const []),
        if (historyDue)
          _series(fetch, solarWindHistoryUrl(), parseSolarWindSeries, const [])
        else
          Future.value(const <SolarPoint>[]),
      ]);
      answers = results;
    } catch (e, stack) {
      // `parseSolarReading` is total, so what reaches here that is not a
      // [_BadAnswer] is the fetch — which makes "not a bad answer" a sound
      // reading of "no network".
      failure = _Failure(transport: e is! _BadAnswer);
      // For the author, never the operator — the same shape every other
      // network path in the app uses, stack included, because a reshaped feed
      // is otherwise undebuggable.
      debugPrint('[solar] fetch failed: $e\n$stack');
    } finally {
      _inFlight = false;
    }

    // Outside the try, deliberately, the way `weather_panel.dart` puts its own
    // state update outside its: none of this touches the network, so a fault
    // here caught by that `catch` would be told to the operator as "no
    // network" and logged against the wrong subsystem — for five fetches that
    // all succeeded. It also has to be all-or-nothing, which inside the try it
    // was not: a throw halfway left `_windRecent` cleared and `_windHistory`
    // stamped fresh against a `_wind` that had not been rebuilt, and nothing
    // repaired that for six hours.
    if (answers != null) {
      _flux = answers[1] as List<SolarPoint>;
      _kp = answers[2] as List<SolarPoint>;

      // The week, bucketed on arrival: nine thousand one-minute readings is a
      // megabyte held for a chart a few hundred marks wide, and the buckets
      // are what gets drawn anyway.
      final windHistory = answers[4] as List<SolarPoint>;
      if (windHistory.isNotEmpty) {
        _windHistory = averageIntoBuckets(windHistory);
        _windRecent = const [];
      }
      // The hourly feed accumulates raw between big fetches, so the bucket
      // still filling is the mean of every reading seen for it rather than of
      // the last hour's alone.
      _windRecent = mergeSeries(_windRecent, answers[3] as List<SolarPoint>);
      _wind = mergeSeries(_windHistory, _windBeyondHistory());
      reading = (answers[0] as SolarReading).withSeries(flux: _flux, kp: _kp, wind: _wind);
    }

    if (!mounted) return;
    setState(() {
      _fetching = false;
      if (reading != null) {
        _reading = reading;
        _failure = null;
      } else {
        _failure = failure;
      }
    });
  }

  /// hamqsl's document, or a throw. The one fetch that decides the round.
  Future<SolarReading> _conditions(SolarFetch fetch) async {
    final response = await fetch(solarConditionsUrl());
    if (response.status != 200) throw _BadAnswer('status ${response.status}: ${_excerpt(response.body)}');
    final reading = parseSolarReading(response.body, fetchedAtUtc: nowUtc());
    // Declined, not failed — and the parse does not say which of its reasons
    // applied, so the body is what a developer has to go on.
    if (reading == null) throw _BadAnswer('unreadable solar data: ${_excerpt(response.body)}');
    return reading;
  }

  /// One SWPC series, falling back to [previous] for anything at all —
  /// including a transport failure, which is why this catches where
  /// [_conditions] throws. A chart is worth keeping through an outage; it is
  /// not worth failing the pane over.
  Future<List<SolarPoint>> _series(
    SolarFetch fetch,
    Uri url,
    List<SolarPoint> Function(String) parse,
    List<SolarPoint> previous,
  ) async {
    try {
      final response = await fetch(url);
      if (response.status != 200) {
        // With the body, like [_conditions]: SWPC answers a rate limit or a
        // moved product with a page saying which, and that sentence is the
        // whole diagnosis.
        throw _BadAnswer('status ${response.status}: ${_excerpt(response.body)}');
      }
      final points = parse(response.body);
      if (points.isEmpty) {
        // A 200 whose every row was rejected — SWPC renaming a field, or
        // moving this feed to the array-of-arrays shape its other products
        // use. Silent, this is indistinguishable from "same data as last
        // time": the chart quietly stops appearing on every install and the
        // first sign is a user report months later.
        debugPrint('[solar] series $url: 200 with no usable rows: ${_excerpt(response.body)}');
        return previous;
      }
      return points;
    } catch (e, stack) {
      // With the stack, because this catches EVERYTHING — a `_TypeError`
      // raised inside `parse` lands here too, and without a line of ours in
      // it there is nothing to go on.
      debugPrint('[solar] series $url failed: $e\n$stack');
      return previous;
    }
  }

  /// The recent buckets the week's own does not already cover, better.
  ///
  /// A bucket the history file already averaged over three hours is not
  /// improved by the same period recomputed from the one hour of readings
  /// held since — and right after a big fetch that is exactly what
  /// [_windRecent] holds, because the fetch clears it. Letting that win drew
  /// a one-hour mean under a label naming three, which is the plausible curve
  /// of the wrong quantity this panel keeps having to avoid.
  List<SolarPoint> _windBeyondHistory() {
    final buckets = averageIntoBuckets(_windRecent);
    if (_windHistory.isEmpty) return buckets;
    final covered = _windHistory.last.utc;
    return [
      for (final bucket in buckets)
        if (bucket.utc.isAfter(covered)) bucket,
    ];
  }

  /// Enough of a response body to name what went wrong, and no more — this
  /// goes to the console, and a series body is tens of KB of numbers.
  static String _excerpt(String body) {
    final trimmed = body.trim();
    return trimmed.length <= 200 ? trimmed : '${trimmed.substring(0, 200)}…';
  }

  @override
  Widget build(BuildContext context) {
    // A pane nobody is looking at draws nothing AND lays out nothing. The
    // dock keeps a group's panes in an `IndexedStack`, which paints only the
    // selected one but LAYS OUT every one of them — so the three tabs behind
    // the front one were each rebuilding a numbers block, a band grid and
    // three charts on every frame of a pane being dragged. The refresh timer
    // is already gated on the same flag; this is the other half of it.
    //
    // `SizedBox.expand`, not `shrink`: the IndexedStack sizes itself to its
    // largest child, and a pane that collapsed to nothing while hidden would
    // resize the group as tabs changed.
    if (!_dockVisible) return const SizedBox.expand();

    final t = context.t.operation.layout.panels;
    final reading = _reading;
    if (reading == null) {
      final failure = _failure;
      if (failure != null) {
        return _message(failure.transport ? t.solarUnreachable : t.solarUnreadable);
      }
      return Center(
        child: SizedBox.square(
          dimension: 24,
          child: _fetching ? const CircularProgressIndicator(strokeWidth: 2) : null,
        ),
      );
    }
    return _SolarReadout(reading: reading, staleFetch: _failure != null);
  }

  Widget _message(String text) => Padding(
    padding: EdgeInsets.all(Space.xl).add(PaneSafeArea.paddingOf(context)),
    child: Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ),
  );
}

/// The readout alone, with a reading already in hand.
///
/// The seam exists because the pane's own refresh CANNOT be driven from a
/// widget test: the retry floor is paced on `realNowUtc` and staleness on the
/// app clock, and `fakeAsync` moves neither — pumping twenty minutes fires the
/// timer against a `now` that never moved. So the one state that needs two
/// rounds to reach, a good reading with a failed refresh behind it, is
/// reachable only by building the readout directly.
@visibleForTesting
Widget solarReadoutForTest({required SolarReading reading, required bool staleFetch}) =>
    _SolarReadout(reading: reading, staleFetch: staleFetch);

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
/// without a socket or a timer.
///
/// **Nothing here is configurable, and the pane's SIZE is what decides what
/// it shows.** In priority order the sections are: the flux headline, the
/// index chips, the band grid, the Kp bars, the flux curve — so a shrinking
/// pane sheds them in exactly the opposite order. The numbers outlive the
/// graphics on purpose: a chart nobody can read the axis of is decoration,
/// where "K 6" in a 90pt pane is still the reason the band went quiet.
class _SolarReadout extends StatefulWidget {
  final SolarReading reading;

  /// A good reading with a failed refresh behind it. Worth saying: without
  /// it, a failing fetch leaves a month-old flux number on screen looking
  /// current.
  final bool staleFetch;

  const _SolarReadout({required this.reading, required this.staleFetch});

  @override
  State<_SolarReadout> createState() => _SolarReadoutState();
}

class _SolarReadoutState extends State<_SolarReadout> {
  /// The instant the pointer is over, shared by all three charts.
  ///
  /// A TIME rather than an index, because the three do not share a cadence:
  /// the flux is read three times a day and the other two are three-hourly
  /// buckets. An index would put the pointer on a different moment in each.
  ///
  /// A [ValueNotifier] rather than `setState`, so a pointer moving across a
  /// chart rebuilds the three chart bands and nothing else — the band grid
  /// and the numbers above them do not change while hovering, and rebuilding
  /// them at pointer rate would be the panel's most expensive frame for the
  /// least reason.
  final _hoveredAt = ValueNotifier<DateTime?>(null);

  @override
  void dispose() {
    _hoveredAt.dispose();
    super.dispose();
  }

  SolarReading get reading => widget.reading;
  bool get staleFetch => widget.staleFetch;

  /// What the READINGS are inset by. The charts deliberately ignore this and
  /// run to the pane's edges: they are the pane's background, and an inset
  /// curve reads as a chart dropped into a box rather than as a month behind
  /// the numbers.
  static const EdgeInsets _inset = EdgeInsets.fromLTRB(Space.xl, Space.lg, Space.xl, Space.lg);

  /// The flux number's line height. Named because the layout divides by it —
  /// the row's height IS this times the font size — so a change here that did
  /// not reach [build] would let the reading overflow the Column in a short
  /// pane.
  static const double _fluxLineHeight = 1.05;

  /// One line of the smallest type the panel draws. The pane's own lower
  /// bound is built from it.
  static const double _smallestLine = 16;

  /// The pane heights below which each layer stops earning its space, and the
  /// content widths below which three of them do. Heights are measured on the
  /// PANE; widths on the content box, because those layers sit inside
  /// [_inset] while the charts around them do not.
  ///
  /// **Every one of these is written at a text scale of 1.0 and must be read
  /// back through [_scaled].** What they gate is type — a line of chips, four
  /// rows of band names, two chart captions — and type grows with the OS text
  /// size (docs/design/ui-scaling.md §3: the OS preference composes on top of
  /// the app's own Font Scale, and unlike Font Scale it does not come out of
  /// the MediaQuery size). Compared raw, a section keeps its place in the
  /// Column while taking half again the height it was budgeted, and a Column
  /// cannot shrink a Text: what happens instead is a RenderFlex overflow on
  /// every frame.
  /// Below these the block drops to the sun and the flux alone. The pairs
  /// are the first thing the pane sheds, and the only part of the block it
  /// can: [_numbers] scales rather than drops, so without a floor a 120pt
  /// pane would shrink all four columns to fit and answer nothing legibly
  /// instead of one thing clearly.
  static const double _pairsFloor = 108;
  static const double _pairsContentWidthFloor = 210;

  /// The credit line is a line of its own at the pane's foot, so it cannot
  /// overflow anything — it ellipsizes. This floor is editorial rather than
  /// structural: "Source hamqsl.com, 12 min ago" clipped to "Source ham…"
  /// credits nobody and dates nothing, and the pane is better off spending
  /// the line on the reading.
  static const double _stampContentWidthFloor = 190;

  /// And the pane height below which it goes too. Under this the pane is
  /// showing the headline and little else, and the line the credit would take
  /// is a sixth of the pane.
  static const double _stampFloor = 72;

  /// What the credit line costs the sections above it: one line of the
  /// smallest type (16), the gap that keeps it off the chart above (6), and
  /// the inset below it that matches the readings' own (12). Every floor
  /// below is measured against what is left AFTER this, which is the whole
  /// reason it is a named number — a footer that took its height without
  /// telling them would leave the sections above choosing against room they
  /// do not have.
  ///
  /// Scaled as a whole even though only the 16 is type: the two gaps are
  /// fixed, so passing them through the scaler over-budgets the footer at
  /// large text sizes. That is the safe direction — it costs a chart band
  /// early rather than crowding one late.
  static const double _footerLine = 34;

  /// The stale-reading glyph, in a pane too small for the stamp that would
  /// otherwise carry the news.
  static const double _staleGlyph = 14;
  /// The grid's floor answers to the HEADLINE as much as to the grid: the
  /// flux number is sized at `height * 0.22`, so every point of pane height
  /// this floor is lowered by buys the grid only about three quarters of a
  /// point — the headline takes the rest. Set to what the grid actually costs
  /// (196) the two overflowed the Column together anywhere in 196..208.
  static const double _gridFloor = 210;
  static const double _gridContentWidthFloor = 148;
  static const double _kpFloor = 262;
  static const double _fluxFloor = 320;

  /// The wind curve is the first chart to GO, though it is drawn second. Not
  /// because it matters least — it is the earliest warning of the three — but
  /// because it is a WEEK wide where the others are a month, and a quiet week
  /// of wind is a flat line that costs a band the Kp bars would have used.
  ///
  /// So a shrinking pane empties from the MIDDLE rather than the bottom.
  /// Deliberate: the order the three are drawn in is about reading them,
  /// and the order they are dropped in is about which one an operator can
  /// least afford to lose. Those are different questions.
  static const double _windFloor = 392;

  /// The window all three charts share. ONE WEEK, and the same week for each,
  /// so a disturbance in the Kp bars sits directly under the wind that
  /// brought it and the flux of the days around it — the whole reason to
  /// stack three charts rather than show them apart.
  ///
  /// The feeds carry more than this. The slack is for a device that has been
  /// asleep, not for the pane.
  static const int _chartDays = 7;

  /// A floor at the text size actually in force. Every floor above gates a
  /// band of type, so each one moves with the scaler by the same amount the
  /// thing it is protecting does.
  static double _scaled(BuildContext context, double floor) =>
      MediaQuery.textScalerOf(context).scale(floor);

  /// How much bigger the scaler makes a given font size. Taken as a ratio off
  /// a real size rather than assumed linear — `TextScaler` need not be, and
  /// the platform's is not above the accessibility sizes.
  static double _scaleRatio(BuildContext context) => _scaled(context, _smallestLine) / _smallestLine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final safe = PaneSafeArea.paddingOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final box = Size(
          constraints.maxWidth - safe.horizontal,
          constraints.maxHeight - safe.vertical,
        );
        // Nothing at all below one line of the smallest text plus the inset.
        // A Column cannot shrink a Text, so what happens instead of this is a
        // RenderFlex overflow on every frame — in a pane far too small to
        // read. Derived rather than a constant, because the scaler moves it.
        final smallestLine = MediaQuery.textScalerOf(context).scale(_smallestLine);
        if (box.width <= 0 || box.height < _inset.vertical + smallestLine) {
          return const SizedBox.shrink();
        }

        // Floored at zero: the inset is a fixed 32pt, so any pane narrower
        // than that makes this negative — and a negative upper bound inverts
        // `clamp`'s limits, which THROWS out of build. The dock floors a pane
        // extent at 0 and only enforces its 120pt minimum while dragging, so
        // a layout saved in a wide window and reopened in a narrow one
        // arrives here well under 32.
        final contentWidth = math.max(0.0, box.width - _inset.horizontal);

        final now = nowUtc();
        final flux = SolarReading.lastDays(reading.flux, now, _chartDays);
        final kp = SolarReading.lastDays(reading.kp, now, _chartDays);
        // Already averaged into the same three-hour buckets the Kp bars sit
        // on, so a mark here and a bar below it cover the same period.
        final wind = SolarReading.lastDays(reading.wind, now, _chartDays);

        final showStamp = contentWidth >= _scaled(context, _stampContentWidthFloor) &&
            box.height >= _scaled(context, _stampFloor);
        // The credit line is the FIRST claim on the pane, not the last: it
        // sits at the foot, below the charts, so every section above it is
        // choosing from what it leaves rather than from the pane. Read the
        // pane's own height into any floor below this and the sections come
        // back to a Column one line shorter than they were told.
        final room = box.height - (showStamp ? _scaled(context, _footerLine) : 0.0);

        final showPairs =
            room >= _scaled(context, _pairsFloor) &&
            contentWidth >= _scaled(context, _pairsContentWidthFloor);
        final showGrid = reading.bands.isNotEmpty &&
            room >= _scaled(context, _gridFloor) &&
            contentWidth >= _scaled(context, _gridContentWidthFloor);
        final showKp = kp.length >= 2 && room >= _scaled(context, _kpFloor);
        final showFlux = flux.length >= 2 && room >= _scaled(context, _fluxFloor);
        final showWind = wind.length >= 2 && room >= _scaled(context, _windFloor);

        // The size the headline would like, then what it can actually pay for
        // in both directions. The 20pt floor gives way before the LAYOUT
        // does: the headline is the Column's one non-flexible child, so a
        // floor the pane cannot cover does not shrink a chart — it overflows
        // the Column, on every frame.
        final roomForFlux = math.max(0.0, room - _inset.vertical);
        // The caps are in UNSCALED font sizes, because that is what a
        // TextStyle takes: the room a size actually occupies is
        // `scaler.scale(size) * lineHeight`, so the room available has to be
        // divided back through the ratio before it can be read as a size. The
        // FittedBox around the headline does not save this — it is given
        // unbounded height by the Column, so it shrinks for width and never
        // for height.
        final ratio = _scaleRatio(context);
        final fluxSize = math.min(
          math.min(math.max(room * 0.22, 20.0), 52.0),
          math.min(roomForFlux / (_fluxLineHeight * ratio), contentWidth * 0.34 / ratio),
        );

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
                        Expanded(child: _numbers(context, fluxSize, showPairs: showPairs)),
                        if (!showStamp && staleFetch) ...[
                          // The credit line at the foot is where a stale
                          // reading is normally confessed, and a pane too
                          // small for one is exactly where a month-old number
                          // looks most current. This is the whole confession
                          // in one glyph, kept beside the headline because
                          // that is all such a pane has.
                          SizedBox(width: Space.sm),
                          Icon(MdiIcons.alertOutline, size: _staleGlyph, color: scheme.error),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (showGrid)
                Padding(
                  padding: EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.md),
                  child: _BandGrid(bands: reading.bands),
                ),
              if (showFlux || showKp || showWind)
                Expanded(
                  // ONE pointer watcher for every band, not one each. A
                  // `MouseRegion` re-runs its hit test whenever the layout
                  // changes, and a pane being dragged changes it every frame
                  // — three of them measured at about 2ms a frame between
                  // them, against 0.3ms for all the painting they wrapped.
                  // The Builder is what makes `context.size` below the size of
                  // the BANDS. Read from the enclosing LayoutBuilder's context
                  // it is the whole readout's, against a local position
                  // measured from the bands — so the pointer lands in the
                  // wrong band, or in none.
                  child: Builder(
                    builder: (context) => MouseRegion(
                    // `opaque: false` so the pane behind still sees the
                    // pointer — this sits over the pane's background, and
                    // swallowing enter/exit here would strand any hover state
                    // above it.
                    opaque: false,
                    onHover: (event) => _hoverCharts(
                      context,
                      event.localPosition,
                      [if (showFlux) flux, if (showWind) wind, if (showKp) kp],
                    ),
                    onExit: (_) => _hoveredAt.value = null,
                    child: Column(
                    children: [
                      if (showFlux)
                        Expanded(
                          child: _HoverChart(
                            key: const ValueKey('solar-chart-flux'),
                            points: flux,
                            hoveredAt: _hoveredAt,
                            // With the hour, now that the curve carries all
                            // three of the day's observations: a date alone
                            // would name three different marks.
                            hoverLabel: (point) => (
                              metric: 'SFI ${point.value.round()}',
                              detail: '${_chartDate(context, point.utc)} ${_chartTime(point.utc)}',
                            ),
                            painterFor: (hovered, labels) => SolarLineChartPainter(
                              values: [for (final point in flux) point.value],
                              line: HaLoColors.of(context).onSurfaceAccent,
                              fill: HaLoColors.of(context).onSurfaceAccent.withValues(alpha: 0.20),
                              labelStyle: _chartLabelStyle(context),
                              labelPlate: _chartLabelPlate(context),
                              labels: labels,
                              hovered: hovered,
                            ),
                          ),
                        ),
                      if (showWind)
                        Expanded(
                          child: _HoverChart(
                            key: const ValueKey('solar-chart-wind'),
                            points: wind,
                            hoveredAt: _hoveredAt,
                            // The bucket's START, which is what the Kp bars
                            // name too — "Aug 24 03:00z" is the three hours
                            // from 03:00, on both charts.
                            hoverLabel: (point) => (
                              metric: 'SW ${point.value.round()}',
                              detail: '${_chartDate(context, point.utc)} ${_chartTime(point.utc)}',
                            ),
                            painterFor: (hovered, labels) => SolarLineChartPainter(
                              values: [for (final point in wind) point.value],
                              // Neutral rather than accented: the flux curve
                              // above already owns the accent, and two
                              // accented lines in one pane read as one series
                              // split in half.
                              line: scheme.onSurfaceVariant,
                              fill: scheme.onSurfaceVariant.withValues(alpha: 0.16),
                              minSpan: solarMinWindSpan,
                              labelStyle: _chartLabelStyle(context),
                              labelPlate: _chartLabelPlate(context),
                              labels: labels,
                              hovered: hovered,
                            ),
                          ),
                        ),
                      if (showKp)
                        Expanded(
                          child: _HoverChart(
                            key: const ValueKey('solar-chart-kp'),
                            points: kp,
                            hoveredAt: _hoveredAt,
                            // Date AND time: a bar is one three-hour period,
                            // and three days of them means a date alone names
                            // eight different bars.
                            hoverLabel: (point) => (
                              metric:
                                  '${context.t.operation.layout.panels.solarKIndex} ${_plain(point.value)}',
                              detail: '${_chartDate(context, point.utc)} ${_chartTime(point.utc)}',
                            ),
                            painterFor: (hovered, labels) => SolarKpChartPainter(
                              values: [for (final point in kp) point.value],
                              storm: scheme.outlineVariant,
                              highlight: scheme.onSurface,
                              labelStyle: _chartLabelStyle(context),
                              labelPlate: _chartLabelPlate(context),
                              labels: labels,
                              hovered: hovered,
                            ),
                          ),
                        ),
                    ],
                    ),
                    ),
                  ),
                )
              else
                const Spacer(),
              // Last, and below the charts: the credit dates the whole pane,
              // not the section above it. Inset like the readings rather than
              // run to the edge like the charts — it is type, and type that
              // starts where the band names start reads as belonging to the
              // reading.
              if (showStamp)
                Padding(
                  // A gap above: the Kp bars run to the pane's edges, so
                  // without it the tallest bar and the credit line sit flush
                  // against each other and the text reads as an axis label.
                  padding: EdgeInsets.fromLTRB(Space.xl, Space.sm, Space.xl, Space.lg),
                  child: _stamp(context),
                ),
            ],
          ),
        );
      },
    );
  }

  /// The numbers, in four columns: the sun, the flux, then two stacked pairs.
  ///
  /// ```
  /// [sun] | SFI 132 |   SN 83    |  A 4
  ///       |         | 304A 120.4 | Kp 0
  /// ```
  ///
  /// The flux is the one number drawn large, and the pairs beside it are
  /// sized off it rather than off the theme, so the block scales as one thing
  /// — a fixed small size beside a 52pt flux reads as two separate headers.
  ///
  /// [FittedBox] rather than a measured drop: the whole block is one shape and
  /// shrinking it keeps every number, where dropping a column loses one. The
  /// pairs still have a floor of their own below, because scaling all the way
  /// down would make the flux illegible to save two indices that a pane that
  /// narrow was never going to fit.
  Widget _numbers(BuildContext context, double size, {required bool showPairs}) {
    final theme = Theme.of(context);
    final sfi = reading.solarFlux;
    final style = theme.textTheme.displaySmall?.copyWith(
      fontSize: size,
      height: _fluxLineHeight,
      fontWeight: FontWeight.w300,
      color: theme.colorScheme.onSurface,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    // Scaled down to fit rather than clipped: these numbers are what must
    // survive every pane size.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            MdiIcons.whiteBalanceSunny,
            size: size * 0.80,
            color: sfi == null ? theme.colorScheme.onSurfaceVariant : solarFluxColor(sfi),
          ),
          SizedBox(width: Space.sm),
          Text('SFI ${sfi ?? '—'}', style: style),
          if (showPairs) ...[
            SizedBox(width: Space.lg),
            // Sunspots over the wind speed, then the two field indices
            // beside them. Not a tidy pairing — SN counts the disc and the
            // wind is what reaches us — but the column an operator reads
            // first is the one with the flux, and these are the two numbers
            // that qualify it.
            _pair(context, size, [
              if (reading.sunspots case final sunspots?) (label: 'SN', value: '$sunspots', color: null),
              if (reading.solarWind case final wind?) (label: 'SW', value: wind, color: null),
            ]),
            SizedBox(width: Space.lg),
            _pair(context, size, [
              if (reading.aIndex case final a?)
                (label: context.t.operation.layout.panels.solarAIndex, value: '$a', color: solarAColor(a)),
              if (reading.kIndex case final k?)
                (
                  label: context.t.operation.layout.panels.solarKIndex,
                  value: '$k',
                  color: solarKColor(k.toDouble()),
                ),
            ]),
          ],
        ],
      ),
    );
  }

  /// One column of the block: up to two labelled numbers, stacked.
  ///
  /// Right-aligned on the VALUE side would line the digits up, but the labels
  /// are what an operator scans for — "A" and "Kp" one under the other — so
  /// the labels align and the values follow them.
  Widget _pair(BuildContext context, double size, List<({String label, String value, Color? color})> rows) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final row in rows)
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                row.label,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: size * 0.24,
                  color: theme.colorScheme.outline,
                ),
              ),
              SizedBox(width: Space.xs),
              Text(
                row.value,
                maxLines: 1,
                style: _valueStyle(theme, row.color)?.copyWith(
                  fontSize: size * 0.30,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
      ],
    );
  }

  /// The value's style. Shared so anything measuring this block measures what
  /// it draws — a bold value lays out wider than a plain one, and the panel's
  /// other tests cannot see the difference because their harness loads no
  /// real font. `panel_solar_overflow_test.dart` loads the app's own and
  /// sweeps the block across pane widths, where an under-measure surfaces as
  /// the horizontal overflow it is.
  static TextStyle? _valueStyle(ThemeData theme, Color? color) => theme.textTheme.labelMedium?.copyWith(
    color: color ?? theme.colorScheme.onSurfaceVariant,
    fontWeight: FontWeight.w600,
  );

  /// What the labels on both charts are drawn in. Resolved here rather than
  /// inside the painters: a `TextPainter` needs a size and a colour, and a
  /// painter that reached for a theme would be a painter that has to be given
  /// a BuildContext.
  static TextStyle _chartLabelStyle(BuildContext context) {
    final theme = Theme.of(context);
    return (theme.textTheme.labelSmall ?? const TextStyle()).copyWith(
      fontSize: MediaQuery.textScalerOf(context).scale(theme.textTheme.labelSmall?.fontSize ?? 11),
      color: theme.colorScheme.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    // Scaled by hand because a painter draws outside the widget tree: nothing
    // below applies the text scaler for it, so an OS text size would have no
    // effect on these labels at all.
  }

  /// Who the pane's numbers belong to, centred at its foot.
  ///
  /// No age. The charts date themselves — hovering any mark says which day it
  /// was — so a line under them repeating it would be a fourth copy.
  ///
  /// The stale glyph stays. A refresh that has stopped landing is not
  /// something the chart labels can say: they date the DATA, which is exactly
  /// as old as it always was, where this is about the fetch behind it.
  Widget _stamp(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (staleFetch) ...[
          // A SHAPE, not only the error colour on the text: a red-green
          // deficiency, a screen in sunlight, or simply not knowing this text
          // is ever red, and a colour-only signal is no signal.
          Icon(MdiIcons.alertOutline, size: _staleGlyph, color: theme.colorScheme.error),
          SizedBox(width: Space.xxs),
        ],
        Flexible(
          child: Text(
            context.t.operation.layout.panels.solarSources(
              primary: solarSourceHost,
              secondary: solarSeriesSource,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: staleFetch ? theme.colorScheme.error : theme.colorScheme.outline,
            ),
          ),
        ),
      ],
    );
  }

  /// Which mark the pointer is over, across all the bands at once.
  ///
  /// The bands are equal-height `Expanded` children of one Column, so which
  /// one the pointer is in is its share of the height — and the mark within
  /// it is an even division of the width, the same division the charts are
  /// laid out by. That cannot drift from what is drawn the way a hit test
  /// against the bar rectangles would: the bars are inset within their
  /// columns, and the gaps between them are not nothing.
  ///
  /// It resolves against the band under the pointer and publishes a TIME, so
  /// the other bands answer the same instant through their own marks — the
  /// flux is read three times a day where the other two are three-hourly, and
  /// an equal index would be a different moment in each.
  void _hoverCharts(BuildContext context, Offset local, List<List<SolarPoint>> bands) {
    final size = context.size;
    if (bands.isEmpty || size == null || size.height <= 0 || size.width <= 0) {
      _hoveredAt.value = null;
      return;
    }
    final band = (local.dy / size.height * bands.length).floor().clamp(0, bands.length - 1);
    final points = bands[band];
    if (points.isEmpty) {
      _hoveredAt.value = null;
      return;
    }
    final index = (local.dx / size.width * points.length).floor().clamp(0, points.length - 1);
    _hoveredAt.value = points[index].utc;
  }

  /// What a label is drawn over: the pane's own surface, so the mark beneath
  /// it does not run through the type. Nearly opaque rather than opaque — the
  /// plate is a hole in the chart, and one you can still faintly see the
  /// curve through reads as a label lying ON the chart rather than as a gap
  /// cut out of it.
  static Color _chartLabelPlate(BuildContext context) =>
      Theme.of(context).colorScheme.surface.withValues(alpha: 0.88);

  /// The day a mark belongs to, in the operator's locale. Month names are
  /// localized (`DateFormat.MMMd`) rather than assembled here, the same way
  /// the call-info panel and the logging panel do it.
  ///
  /// The DateTime is UTC and stays that way: these are UTC observations shown
  /// beside a UTC clock, and a date silently converted to local time would
  /// disagree with the [_chartTime] next to it by a day for half the world.
  String _chartDate(BuildContext context, DateTime utc) =>
      DateFormat.MMMd(Localizations.localeOf(context).toLanguageTag()).format(utc);

  /// The hour a Kp bar covers, on the app's UTC clock — the `z` is what says
  /// so, and it is the same suffix every other time in the app carries.
  String _chartTime(DateTime utc) => '${DateFormat('HH:mm').format(utc)}z';

}

/// A whole number without its trailing zero: Kp arrives from SWPC as 1.33 or
/// 2.0, and "Kp 2.0" beside a column of integers reads as a different kind of
/// number rather than the same one.
String _plain(double value) =>
    value == value.roundToDouble() ? '${value.round()}' : value.toStringAsFixed(2);

/// One chart band, drawn for whatever instant the readout is pointing at.
///
/// No caption and no standing labels. A caption cost two lines of type above
/// a chart band that was already short, and labels left on the marks crowded
/// each other in a real pane while the curve ran straight through them. The
/// chart is the shape; the reading is what you ask it for.
///
/// It does NOT watch the pointer itself. One [MouseRegion] over all the
/// bands does that — see [_SolarReadoutState._hoverCharts] — because every
/// one of them re-runs its hit test on every layout change, and a pane being
/// dragged changes the layout on every frame. Three of them measured at
/// about 2ms a frame between them, against 0.3ms for all the painting they
/// wrap.
class _HoverChart extends StatelessWidget {
  final List<SolarPoint> points;

  /// The instant every chart in the pane is answering, owned by the readout.
  final ValueNotifier<DateTime?> hoveredAt;

  /// What the mark nearest that instant says: its reading, and the period it
  /// belongs to.
  final ({String metric, String detail}) Function(SolarPoint point) hoverLabel;

  final CustomPainter Function(int? hovered, List<SolarChartLabel> labels) painterFor;

  const _HoverChart({
    super.key,
    required this.points,
    required this.hoveredAt,
    required this.hoverLabel,
    required this.painterFor,
  });

  /// This chart's mark nearest [instant], or null when it has none.
  ///
  /// NEAREST, with no tolerance. The bands cover the same week at different
  /// cadences, so an exact match would mean the flux — three marks a day
  /// against the others' eight — answered almost never. What "nearest" costs
  /// is that a gap in one series answers with the reading on its far side,
  /// which is still the closest thing that series has to say.
  int? _nearest(DateTime instant) {
    if (points.isEmpty) return null;
    var best = 0;
    var bestGap = (points.first.utc.difference(instant)).abs();
    for (final (index, point) in points.indexed) {
      final gap = point.utc.difference(instant).abs();
      if (gap < bestGap) {
        best = index;
        bestGap = gap;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DateTime?>(
      valueListenable: hoveredAt,
      builder: (context, instant, _) {
        final hovered = instant == null ? null : _nearest(instant);
        final labels = <SolarChartLabel>[
          if (hovered != null)
            (
              index: hovered,
              metric: hoverLabel(points[hovered]).metric,
              detail: hoverLabel(points[hovered]).detail,
            ),
        ];
        // A boundary of its own: hovering repaints ONE chart band rather than
        // the pane it sits in, and the pointer moves as often as a drag does.
        //
        // `SizedBox.expand` explicitly. A `CustomPaint` with no CHILD takes
        // its size from `preferredSize` — zero — wherever the constraints are
        // loose, and the Column above hands out loose widths.
        return RepaintBoundary(
          child: SizedBox.expand(
            child: CustomPaint(painter: painterFor(hovered, labels)),
          ),
        );
      },
    );
  }
}

/// The band-conditions grid: one row per band group, a cell for day and one
/// for night.
///
/// Day and night are both shown rather than only the one in force: this panel
/// has no location — solar conditions are global, which is the whole reason
/// it needs no settings — so which of the two applies is not something it can
/// know, and picking one would be a guess an operator cannot see through.
class _BandGrid extends StatelessWidget {
  final List<BandConditions> bands;

  const _BandGrid({required this.bands});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.t.operation.layout.panels;
    final headerStyle = theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Spacer(),
            Expanded(flex: 2, child: Text(t.solarBandDay, textAlign: TextAlign.center, style: headerStyle)),
            Expanded(flex: 2, child: Text(t.solarBandNight, textAlign: TextAlign.center, style: headerStyle)),
          ],
        ),
        for (final band in bands)
          Padding(
            padding: EdgeInsets.only(top: Space.xxs),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    band.band,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
                Expanded(flex: 2, child: _cell(context, band.day)),
                Expanded(flex: 2, child: _cell(context, band.night)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _cell(BuildContext context, BandRating rating) {
    final theme = Theme.of(context);
    final t = context.t.operation.layout.panels;
    final (color, label) = switch (rating) {
      BandRating.good => (SolarPalette.good, t.solarBandGood),
      BandRating.fair => (SolarPalette.fair, t.solarBandFair),
      BandRating.poor => (SolarPalette.poor, t.solarBandPoor),
      // A dash, not an empty cell: a blank row reads as a layout fault, where
      // this reads as the feed not having said.
      BandRating.unknown => (theme.colorScheme.outline, '—'),
    };
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Space.xxs),
      child: Container(
        // Height, never width: the cell is inside an Expanded and a
        // Container with an alignment would stretch to fill the row.
        padding: EdgeInsets.symmetric(vertical: Space.xxs),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
