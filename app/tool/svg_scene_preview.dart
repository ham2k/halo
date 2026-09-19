// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
// Run after `npm run build` in extensions, with the sample served from there:
// npm run dev -- --only k2hrc-svg-scenes
// flutter run -t tool/svg_scene_preview.dart -d macos --profile
//
// The sample is a fixture, so it is not among the app's assets, and a
// sandboxed macOS build cannot read it off the disk: it comes from the
// extension dev server (`--dart-define=SCENE_FIXTURE_URL=…` for another address).
// This deliberately uses ExtensionPanel and the real extension service routing.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:http/http.dart' as http;
import 'package:ham2k_logger/services/extension_service.dart';
import 'package:ham2k_logger/services/panel_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/operation/weather/weather_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ham2k_logger/views/operation/extension_panel.dart';

class PrototypeExtensionService extends ExtensionService {
  final ExtensionHost prototypeHost;
  int renders = 0, events = 0;
  PrototypeExtensionService(this.prototypeHost);
  @override
  ExtensionHost get host => prototypeHost;
  @override
  Future<Map<String, dynamic>> readPanelConfig({
    required String panelKey,
    required List<Map<String, dynamic>> fields,
  }) async => {};
  @override
  Future<Map<String, dynamic>?> renderPanel({
    required String hookKey,
    required String panelKey,
    required Map<String, dynamic> args,
  }) {
    renders++;
    return super.renderPanel(hookKey: hookKey, panelKey: panelKey, args: args);
  }

  @override
  Future<Map<String, dynamic>?> panelEvent({
    required String hookKey,
    required String panelKey,
    required Map<String, dynamic> args,
  }) {
    events++;
    return super.panelEvent(hookKey: hookKey, panelKey: panelKey, args: args);
  }
}

const _fixtureUrl = String.fromEnvironment(
  'SCENE_FIXTURE_URL',
  defaultValue: 'http://127.0.0.1:8787/k2hrc-svg-scenes.js',
);

Future<String> _fixtureSource() async {
  final response = await http.get(Uri.parse(_fixtureUrl));
  if (response.statusCode != 200) {
    throw StateError(
      'No sample bundle at $_fixtureUrl (HTTP ${response.statusCode}). '
      'From extensions/, run: npm run dev -- --only k2hrc-svg-scenes',
    );
  }
  return response.body;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final host = await ExtensionHost.start(
    kernelSource: await rootBundle.loadString('assets/extensions/kernel.js'),
    extensions: [
      ExtensionBundle(
        key: 'k2hrc-svg-scenes',
        source: await _fixtureSource(),
      ),
    ],
    onHostCall: (method, args) async =>
        method == 'getSettings' ? {'appName': 'SVG Scene Preview'} : null,
  );
  final service = PrototypeExtensionService(host);
  final panels = PanelService(service);
  await panels.refreshExtensionPanels();
  panels.registerNative(
    const PanelDefinition(
      id: weatherPanelId,
      title: 'Weather',
      source: PanelSource.native,
    ),
  );
  final settings = SettingsService(await SharedPreferences.getInstance());
  runApp(
    TranslationProvider(
      child: MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: ScenePreview(
          panels: panels,
          service: service,
          settings: settings,
        ),
      ),
    ),
  );
}

class ScenePreview extends StatefulWidget {
  final PanelService panels;
  final PrototypeExtensionService service;
  final SettingsService settings;
  const ScenePreview({
    super.key,
    required this.panels,
    required this.service,
    required this.settings,
  });
  @override
  State<ScenePreview> createState() => _ScenePreviewState();
}

class _ScenePreviewState extends State<ScenePreview> {
  bool _visible = true, _stress = false, _reduced = false;
  bool _productionWeather = !const bool.fromEnvironment('SVG_SCENE_BENCHMARK');
  final _buildTimes = <int>[];
  final _rasterTimes = <int>[];
  int _startRenders = 0, _startEvents = 0;
  Timer? _measurement;
  String _report = 'Measure in profile mode; simulated data only.';

  @override
  void initState() {
    super.initState();
    if (const bool.fromEnvironment('SVG_SCENE_BENCHMARK')) {
      unawaited(_benchmark());
    }
  }

  Future<void> _benchmark() async {
    for (final mode in ['two', 'eight', 'hidden']) {
      if (!mounted) return;
      setState(() {
        _stress = mode != 'two';
        _visible = mode != 'hidden';
      });
      await Future<void>.delayed(const Duration(seconds: 3));
      if (!mounted) return;
      debugPrint('[svg-scene-profile] mode=$mode');
      _measure();
      await Future<void>.delayed(const Duration(seconds: 11));
    }
    if (mounted) {
      setState(() {
        _visible = true;
        _stress = false;
      });
    }
  }

  void _timings(List<FrameTiming> frames) {
    for (final frame in frames) {
      _buildTimes.add(frame.buildDuration.inMicroseconds);
      _rasterTimes.add(frame.rasterDuration.inMicroseconds);
    }
  }

  void _measure() {
    _buildTimes.clear();
    _rasterTimes.clear();
    _startRenders = widget.service.renders;
    _startEvents = widget.service.events;
    SchedulerBinding.instance.addTimingsCallback(_timings);
    setState(() => _report = 'Measuring 10 seconds…');
    _measurement = Timer(const Duration(seconds: 10), () {
      SchedulerBinding.instance.removeTimingsCallback(_timings);
      _buildTimes.sort();
      _rasterTimes.sort();
      String p95(List<int> values) => values.isEmpty
          ? 'n/a'
          : (values[((values.length - 1) * .95).round()] / 1000)
                .toStringAsFixed(2);
      setState(() {
        _report =
            '${_buildTimes.length} frames · p95 build ${p95(_buildTimes)} ms · raster ${p95(_rasterTimes)} ms · '
            '${widget.service.renders - _startRenders} renders · ${widget.service.events - _startEvents} events';
        _measurement = null;
      });
      debugPrint('[svg-scene-profile] $_report');
    });
  }

  @override
  void dispose() {
    _measurement?.cancel();
    SchedulerBinding.instance.removeTimingsCallback(_timings);
    widget.panels.dispose();
    unawaited(widget.service.prototypeHost.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('SVG Scene Prototypes'),
      actions: [
        TextButton(
          onPressed: () =>
              setState(() => _productionWeather = !_productionWeather),
          child: Text(
            _productionWeather ? 'Sample weather' : 'Production weather',
          ),
        ),
        TextButton(
          onPressed: () => setState(() => _visible = !_visible),
          child: Text(_visible ? 'Hide panels' : 'Show panels'),
        ),
        TextButton(
          onPressed: () => setState(() => _stress = !_stress),
          child: Text(_stress ? 'Two panels' : 'Eight panels'),
        ),
        TextButton(
          onPressed: () => setState(() => _reduced = !_reduced),
          child: Text(_reduced ? 'Enable motion' : 'Reduce motion'),
        ),
        TextButton(
          onPressed: _measurement == null ? _measure : null,
          child: const Text('Measure'),
        ),
      ],
    ),
    body: Column(
      children: [
        Padding(padding: const EdgeInsets.all(8), child: Text(_report)),
        Expanded(
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: _reduced),
            child: DockPaneVisibility(
              visible: _visible,
              child: Offstage(
                offstage: !_visible,
                child: LayoutBuilder(
                  builder: (context, constraints) => GridView.count(
                    crossAxisCount: _stress
                        ? (constraints.maxWidth > 850 ? 4 : 2)
                        : (constraints.maxWidth > 850 ? 2 : 1),
                    childAspectRatio: 640 / 360,
                    children: [
                      for (var i = 0; i < (_stress ? 8 : 2); i++)
                        if (i.isOdd && _productionWeather)
                          WeatherPanel(
                            key: ValueKey('weather-$i'),
                            panelId: weatherPanelId,
                            panels: widget.panels,
                            settings: widget.settings,
                            operationGrid: 'FN42',
                            fetch: _forecastFixture,
                          )
                        else
                          ExtensionPanel(
                            key: ValueKey(i),
                            panels: widget.panels,
                            panel: widget
                                .panels['ext:k2hrc-svg-scenes:${i.isEven ? 'radio' : 'weather'}#${i + 1}']!,
                            renderContext: const PanelRenderContext(),
                          ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

// Use the production controller/parser/layout with a repeatable injected feed.
// This preview never claims fixture data is the current weather.
Future<({int status, String body})> _forecastFixture(Uri url) async {
  final now = DateTime.now().toUtc();
  final hour =
      DateTime.utc(
        now.year,
        now.month,
        now.day,
        now.hour,
      ).millisecondsSinceEpoch ~/
      1000;
  return (
    status: 200,
    body: jsonEncode({
      'utc_offset_seconds': 0,
      'timezone_abbreviation': 'UTC',
      'current_units': {'temperature_2m': '°C', 'wind_speed_10m': 'km/h'},
      'current': {
        'temperature_2m': 22,
        'weather_code': 2,
        'is_day': 1,
        'relative_humidity_2m': 64,
        'wind_speed_10m': 12,
        'wind_gusts_10m': 18,
        'wind_direction_10m': 240,
      },
      'hourly': {
        'time': [for (var i = 0; i < 8; i++) hour + i * 3600],
        'temperature_2m': [22, 23, 24, 23, 21, 20, 19, 18],
        'weather_code': [2, 2, 3, 3, 61, 61, 3, 3],
        'precipitation_probability': [5, 10, 15, 30, 65, 75, 40, 20],
        'is_day': [1, 1, 1, 1, 1, 1, 0, 0],
      },
    }),
  );
}
