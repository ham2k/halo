// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Spike stub UI: boots the extension host, runs a self-test on launch (bridge
// benchmark, HamDB lookup, POTA spots fetch), and exposes interactive
// controls for lookups, spots, and latency measurement.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:polo_extension_host/polo_extension_host.dart';
import 'package:polo_widgets/polo_widgets.dart';

class SpikeScreen extends StatefulWidget {
  const SpikeScreen({super.key});

  @override
  State<SpikeScreen> createState() => _SpikeScreenState();
}

class _SpikeScreenState extends State<SpikeScreen> {
  ExtensionHost? _host;
  String _status = 'Booting extension host…';
  String? _selfTestReport;
  String? _lookupResult;
  String? _benchResult;
  List<dynamic> _spots = [];
  final List<String> _logs = [];

  final _callsignController = TextEditingController(text: 'W1AW');
  final _qrzUserController = TextEditingController();
  final _qrzPassController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _host?.dispose();
    _callsignController.dispose();
    _qrzUserController.dispose();
    _qrzPassController.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    try {
      final bootWatch = Stopwatch()..start();
      final index = jsonDecode(await rootBundle.loadString('assets/extensions/index.json')) as Map<String, dynamic>;
      final kernelSource = await rootBundle.loadString('assets/extensions/${index['kernel']}');
      final bundles = <ExtensionBundle>[];
      for (final entry in (index['extensions'] as List).cast<Map<String, dynamic>>()) {
        bundles.add(ExtensionBundle(
          key: entry['key'] as String,
          source: await rootBundle.loadString('assets/extensions/${entry['file']}'),
        ));
      }

      final host = await ExtensionHost.start(kernelSource: kernelSource, extensions: bundles);
      bootWatch.stop();
      if (!mounted) {
        host.dispose();
        return;
      }

      setState(() {
        _host = host;
        _logs.addAll(host.logLines);
        _status = 'Ready — engine: ${host.engine}'
            '${host.runningInIsolate ? " on background isolate" : " IN-PROCESS (isolate failed)"}'
            ' — kernel+${bundles.length} extensions loaded in ${host.loadMillis}ms'
            ' (${bootWatch.elapsedMilliseconds}ms total boot)';
      });
      host.logs.listen((line) {
        if (mounted) setState(() => _logs.add(line));
      });

      await _selfTest(host);
    } catch (e) {
      if (mounted) setState(() => _status = 'BOOT FAILED: $e');
    }
  }

  Future<void> _selfTest(ExtensionHost host) async {
    final report = StringBuffer();
    try {
      final echo = await host.invokeHook('bench', key: 'kernel', method: 'echo', args: {'ping': true});
      report.writeln('echo: ok (${jsonEncode(echo)})');

      await _runBench(host, warmup: true);
      final benchLine = await _runBench(host);
      report.writeln('bridge: $benchLine');

      final lookup = await host.invokeHook('lookup', key: 'hamdb', method: 'lookupCall',
          args: {'callInfo': {'call': 'W1AW'}});
      report.writeln('hamdb W1AW: ${jsonEncode(lookup)}');

      final spots = await host.invokeHook('spots', key: 'pota', method: 'fetchSpots',
          timeout: const Duration(seconds: 20)) as List;
      final sample = spots.isEmpty ? 'none' : jsonEncode(spots.first);
      report.writeln('pota spots: ${spots.length} fetched, first: $sample');

      if (mounted) {
        setState(() {
          _selfTestReport = report.toString();
          _spots = spots;
        });
      }
    } catch (e) {
      report.writeln('FAILED: $e');
      if (mounted) setState(() => _selfTestReport = report.toString());
    }
    debugPrint('=== SPIKE SELF-TEST ===\n$_status\n$report=== END SELF-TEST ===');
  }

  Future<String> _runBench(ExtensionHost host, {bool warmup = false}) async {
    const rounds = 100;
    final times = <int>[];
    final watch = Stopwatch();
    for (var i = 0; i < (warmup ? 10 : rounds); i++) {
      watch
        ..reset()
        ..start();
      await host.invokeHook('bench', key: 'kernel', method: 'echo', args: {'i': i});
      watch.stop();
      times.add(watch.elapsedMicroseconds);
    }
    if (warmup) return '';
    times.sort();
    final mean = times.reduce((a, b) => a + b) / times.length;
    String us(num v) => '${(v / 1000).toStringAsFixed(2)}ms';
    final line = '$rounds round-trips — mean ${us(mean)}, '
        'p50 ${us(times[times.length ~/ 2])}, '
        'p95 ${us(times[(times.length * 95) ~/ 100])}, '
        'max ${us(times.last)}';
    if (mounted) setState(() => _benchResult = line);
    return line;
  }

  Future<void> _lookup(String hookKey) async {
    final host = _host;
    if (host == null) return;
    setState(() => _lookupResult = 'Looking up…');
    try {
      if (hookKey == 'qrz') {
        host.setKV('qrz', 'username', _qrzUserController.text.trim());
        host.setKV('qrz', 'password', _qrzPassController.text);
      }
      final result = await host.invokeHook('lookup', key: hookKey, method: 'lookupCall',
          args: {'callInfo': {'call': _callsignController.text.trim()}});
      if (mounted) setState(() => _lookupResult = const JsonEncoder.withIndent('  ').convert(result));
    } catch (e) {
      if (mounted) setState(() => _lookupResult = '$e');
    }
  }

  Future<void> _fetchSpots() async {
    final host = _host;
    if (host == null) return;
    try {
      final spots = await host.invokeHook('spots', key: 'pota', method: 'fetchSpots',
          timeout: const Duration(seconds: 20)) as List;
      if (mounted) setState(() => _spots = spots);
    } catch (e) {
      if (mounted) setState(() => _spots = ['ERROR: $e']);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PoLo Next — Extension Bridge Spike')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _card('Runtime', Text(_status)),
          if (_selfTestReport != null) _card('Self-test', _mono(_selfTestReport!)),
          _card(
            'Bridge benchmark',
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (_benchResult != null) _mono(_benchResult!),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _host == null ? null : () => _runBench(_host!),
                child: const Text('Run 100 echo round-trips'),
              ),
            ]),
          ),
          _card(
            'Callsign lookup',
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(
                controller: _callsignController,
                decoration: poloFieldDecoration(context, 'Callsign'),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _qrzUserController,
                    decoration: poloFieldDecoration(context, 'QRZ username (optional)'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _qrzPassController,
                    obscureText: true,
                    decoration: poloFieldDecoration(context, 'QRZ password'),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                FilledButton(onPressed: _host == null ? null : () => _lookup('hamdb'), child: const Text('HamDB')),
                FilledButton.tonal(onPressed: _host == null ? null : () => _lookup('qrz'), child: const Text('QRZ')),
              ]),
              if (_lookupResult != null) Padding(padding: const EdgeInsets.only(top: 8), child: _mono(_lookupResult!)),
            ]),
          ),
          _card(
            'POTA spots (${_spots.length})',
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              FilledButton(onPressed: _host == null ? null : _fetchSpots, child: const Text('Fetch spots')),
              const SizedBox(height: 8),
              for (final spot in _spots.take(15))
                spot is Map
                    ? ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('${spot['their']?['call'] ?? '?'}'
                            '  ${spot['freq'] ?? '?'} kHz'
                            '  ${spot['band'] ?? ''}  ${spot['mode'] ?? ''}'),
                        subtitle: Text('${spot['spot']?['label'] ?? ''}'),
                      )
                    : Text('$spot'),
            ]),
          ),
          _card(
            'Hook call stats',
            _mono(_statsTable()),
          ),
          _card('Extension log', _mono(_logs.reversed.take(40).toList().reversed.join('\n'))),
        ],
      ),
    );
  }

  String _statsTable() {
    final host = _host;
    if (host == null || host.samples.isEmpty) return 'no calls yet';
    final groups = <String, List<HookCallSample>>{};
    for (final sample in host.samples) {
      groups.putIfAbsent(sample.label, () => []).add(sample);
    }
    final buffer = StringBuffer('call                      n     mean    max   (js mean)\n');
    for (final entry in groups.entries) {
      final totals = entry.value.map((s) => s.totalMillis).toList()..sort();
      final jsMean = entry.value.map((s) => s.jsMillis).reduce((a, b) => a + b) / entry.value.length;
      final mean = totals.reduce((a, b) => a + b) / totals.length;
      buffer.writeln('${entry.key.padRight(24)} ${totals.length.toString().padLeft(4)} '
          '${mean.toStringAsFixed(1).padLeft(7)}ms ${totals.last.toString().padLeft(5)}ms '
          '${jsMean.toStringAsFixed(1).padLeft(8)}ms');
    }
    return buffer.toString();
  }

  Widget _card(String title, Widget child) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          child,
        ]),
      ),
    );
  }

  Widget _mono(String text) {
    return Text(text, style: const TextStyle(fontFamily: 'Menlo', fontSize: 12));
  }
}
