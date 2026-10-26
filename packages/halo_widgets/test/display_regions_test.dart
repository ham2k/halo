// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// DisplayRegionInsets corrects the MediaQuery at the app root from what iOS
// reports about a foldable's display over `ham2k/display_regions`. The
// reports below are the iPhone Duo's, recorded off the iOS 27.1 simulator.
// These tests pin what the correction must never do: lay content under the
// drawn keyboard or the status bar, jump as the keyboard animates, act on a
// report the display has rotated away from, or remount the app on a fold.

import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

const _channel = MethodChannel('ham2k/display_regions');

/// The inner display, as the reporter describes it.
Map<String, Object?> _portrait({bool halfFolded = false}) => {
  'width': 669.0,
  'height': 951.0,
  'headerBar': {'top': 24.0, 'left': 16.0, 'bottom': 869.0, 'right': 144.0},
  'cornerSafeArea': {'top': 82.0, 'left': 16.0, 'bottom': 34.0, 'right': 16.0},
  'fold': {'left': 0.0, 'top': 455.5, 'width': 669.0, 'height': 40.0, 'active': halfFolded},
};

Map<String, Object?> _landscape() => {
  'width': 951.0,
  'height': 669.0,
  'headerBar': {'top': 24.0, 'left': 16.0, 'bottom': 587.0, 'right': 84.0},
  'cornerSafeArea': {'top': 0.0, 'left': 16.0, 'bottom': 34.0, 'right': 84.0},
  'fold': {'left': 455.5, 'top': 0.0, 'width': 40.0, 'height': 669.0, 'active': false},
};

/// What iOS reports as the keyboard, half-folded: everything from the fold's
/// upper margin down.
const _halfFoldReport = 951 - 455.5;
const _fold = 951 / 2;

Future<void> _onIOS(Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

void _portraitView(WidgetTester tester, {double keyboard = 0}) {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = const Size(669, 951) * 3;
  tester.view.padding = const FakeViewPadding(top: 82 * 3, bottom: 34 * 3);
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard * 3);
  addTearDown(tester.view.reset);
}

void _landscapeView(WidgetTester tester) {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = const Size(951, 669) * 3;
  tester.view.padding = const FakeViewPadding(right: 84 * 3, bottom: 34 * 3);
  tester.view.viewInsets = FakeViewPadding.zero;
  addTearDown(tester.view.reset);
}

/// The reporter's answer to the startup pull; null answers nothing at all.
void _reporter(WidgetTester tester, Map<String, Object?>? Function() answer, {List<MethodCall>? calls}) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) async {
    calls?.add(call);
    return answer();
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null));
}

Future<void> _push(WidgetTester tester, Map<String, Object?> report) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    _channel.name,
    const StandardMethodCodec().encodeMethodCall(MethodCall('changed', report)),
    (_) {},
  );
  await tester.pump();
}

class _Mounts extends StatefulWidget {
  final ValueChanged<BuildContext> onBuild;
  static int count = 0;

  const _Mounts({required this.onBuild});

  @override
  State<_Mounts> createState() => _MountsState();
}

class _MountsState extends State<_Mounts> {
  @override
  void initState() {
    super.initState();
    _Mounts.count++;
  }

  @override
  Widget build(BuildContext context) {
    widget.onBuild(context);
    return const SizedBox.expand();
  }
}

void main() {
  late MediaQueryData seen;
  late double strip;
  late StatusBandHeader? header;
  late EdgeInsets bottomBar;

  Widget app({Widget? field}) => MaterialApp(
    builder: (context, child) => DisplayRegionInsets(child: child!),
    home: Scaffold(
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          ?field,
          Expanded(
            child: _Mounts(
              onBuild: (context) {
                seen = MediaQuery.of(context);
                strip = stripBelowFoldOf(context);
                header = statusBandHeaderOf(context);
                bottomBar = bottomBarPaddingOf(context);
              },
            ),
          ),
        ],
      ),
    ),
  );

  setUp(() => _Mounts.count = 0);

  testWidgets("held portrait, the header rises into the status bar's band, clear of the bar and the corner", (tester) async {
    await _onIOS(() async {
      _portraitView(tester);
      _reporter(tester, _portrait);
      await tester.pumpWidget(app());
      await tester.pump();

      expect(seen.padding.top, 24, reason: "where iOS starts a header bar, not the 82pt band the clock's corner holds across the whole width");
      expect(header, (height: 46.0, trailing: 144.0));
      // The corner's clearance is the whole left edge's, not the header's
      // alone: the rail runs down that edge under the app's mark, and a mark
      // nudged off the corner by itself sits off the rail's column.
      expect(seen.padding.left, 16);

      // iOS centres a bar the footer's height exactly at the 34pt safe area,
      // spending the band on space the home indicator does not need. Lower
      // without the corner clearance at its sides, the footer's ends would
      // run into the rounded corners.
      expect(bottomBar, const EdgeInsets.fromLTRB(16, 24, 16, 12));
    });
  });

  testWidgets('held landscape, the leading edge clears the rounded corner iOS leaves out of the safe area', (tester) async {
    await _onIOS(() async {
      _landscapeView(tester);
      _reporter(tester, _landscape);
      await tester.pumpWidget(app());
      await tester.pump();

      expect(header, isNull, reason: 'the status bar is a column at the side; there is no band to rise into');
      expect(seen.padding.left, 16, reason: "iOS reports no left inset, and the corner cuts into the header's leading edge");
      expect(seen.padding.right, 84);
      expect(bottomBar, const EdgeInsets.fromLTRB(16, 0, 84, 12));
    });
  });

  testWidgets('a display with no fold is laid out as Flutter reports it', (tester) async {
    await _onIOS(() async {
      // The outer display, or any other iPhone: the same calls answer there,
      // but what their answers would do to its layout is unverified.
      _portraitView(tester);
      _reporter(tester, () => {..._portrait(), 'fold': null});
      await tester.pumpWidget(app());
      await tester.pump();

      expect(seen.padding.top, 82);
      expect(header, isNull);
      expect(bottomBar, seen.padding);
    });
  });

  testWidgets('half-folded, the inset is the keyboard drawn for the focused field, and the strip reaches the fold', (tester) async {
    await _onIOS(() async {
      _portraitView(tester, keyboard: _halfFoldReport);
      _reporter(tester, () => _portrait(halfFolded: true));

      // The callsign field: no suggestion bar, the shorter keyboard.
      await tester.pumpWidget(app(field: const TextField(autofocus: true, autocorrect: false)));
      await tester.pump();
      expect(seen.viewInsets.bottom, 396);
      expect(seen.viewInsets.bottom + strip, moreOrLessEquals(_fold), reason: 'a row filling the strip ends at the fold');

      // A password field turns autocorrect off too, but iOS still raises its
      // Passwords bar over it. Taken for the shorter keyboard, the fields
      // above would sit under the keys by the bar's height.
      await tester.pumpWidget(app(field: const TextField(key: ValueKey('password'), autofocus: true, autocorrect: false, obscureText: true)));
      await tester.pump();
      expect(seen.viewInsets.bottom, 445);
    });
  });

  testWidgets('opened flat, the same keyboard report is left alone', (tester) async {
    await _onIOS(() async {
      // Whether the display is half-folded is the fold's own report, not a
      // guess from the keyboard's height.
      _portraitView(tester, keyboard: _halfFoldReport);
      _reporter(tester, _portrait);
      await tester.pumpWidget(app(field: const TextField(autofocus: true, autocorrect: false)));
      await tester.pump();
      expect(seen.viewInsets.bottom, _halfFoldReport);
      expect(strip, 0);

      await _push(tester, _portrait(halfFolded: true));
      expect(seen.viewInsets.bottom, 396, reason: 'folding changes no inset; the push alone has to carry it');
    });
  });

  testWidgets('the correction follows focus between fields, with no inset change to prompt it', (tester) async {
    await _onIOS(() async {
      _portraitView(tester, keyboard: _halfFoldReport);
      _reporter(tester, () => _portrait(halfFolded: true));
      final plain = FocusNode();
      final suggesting = FocusNode();
      addTearDown(plain.dispose);
      addTearDown(suggesting.dispose);

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => DisplayRegionInsets(child: child!),
          home: Scaffold(
            resizeToAvoidBottomInset: false,
            body: Column(
              children: [
                TextField(focusNode: plain, autocorrect: false),
                TextField(focusNode: suggesting),
                Expanded(child: _Mounts(onBuild: (context) => seen = MediaQuery.of(context))),
              ],
            ),
          ),
        ),
      );
      plain.requestFocus();
      await tester.pump();
      expect(seen.viewInsets.bottom, 396);

      suggesting.requestFocus();
      await tester.pump();
      expect(seen.viewInsets.bottom, 445, reason: 'still the shorter keyboard here is content under the suggestion bar');
    });
  });

  testWidgets('as the keyboard animates in, the corrected inset never jumps and never sits below the keys', (tester) async {
    await _onIOS(() async {
      _portraitView(tester);
      _reporter(tester, () => _portrait(halfFolded: true));
      await tester.pumpWidget(app(field: const TextField(autofocus: true, autocorrect: false)));
      await tester.pump();

      // Applied only once the report settles, the layout drops by the whole
      // correction on the last frame of the keyboard's arrival, and leaps by
      // it on the first of its departure.
      const frames = 90;
      var previous = 0.0;
      for (var frame = 0; frame <= frames; frame++) {
        final report = _halfFoldReport * frame / frames;
        tester.view.viewInsets = FakeViewPadding(bottom: report * 3);
        await tester.pump();
        final inset = seen.viewInsets.bottom;
        expect((inset - previous).abs(), lessThanOrEqualTo(_halfFoldReport / frames + 0.01), reason: 'at a report of $report');
        // iOS slides the drawn keyboard up in step with its report.
        expect(inset, greaterThanOrEqualTo(report * 396 / _halfFoldReport - 0.01), reason: 'content under the keys at a report of $report');
        previous = inset;
      }
      expect(previous, 396);
    });
  });

  testWidgets('a rotation re-answers every clearance, acts on no stale report, and remounts nothing', (tester) async {
    await _onIOS(() async {
      _landscapeView(tester);
      _reporter(tester, _landscape);
      late double clearance;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => DisplayRegionInsets(child: child!),
          home: _Mounts(onBuild: (context) => clearance = windowsCaptionClearance(context)),
        ),
      );
      await tester.pump();
      MediaQueryData mq() => tester.element(find.byType(_Mounts)).getInheritedWidgetOfExactType<MediaQuery>()!.data;
      expect(mq().padding.left, 16);
      expect(clearance, 0);

      // The view turns before the reporter's push lands. Its landscape
      // report laid over the portrait view would raise the header with the
      // landscape status column's clearance, 84pt, and its last actions
      // under the portrait clock.
      _portraitView(tester);
      await tester.pump();
      expect(mq().padding.top, 82);
      expect(clearance, 0);

      await _push(tester, _portrait());
      expect(mq().padding.top, 24);
      expect(clearance, 144, reason: "the header's actions clear the status bar");
      expect(_Mounts.count, 1, reason: 'a correction switching on or off must not unmount the app below it');
    });
  });

  testWidgets('a reporter that never answers corrects nothing', (tester) async {
    await _onIOS(() async {
      _portraitView(tester);
      _reporter(tester, () => null);
      await tester.pumpWidget(app());
      await tester.pump();
      expect(seen.padding.top, 82);
      expect(header, isNull);
    });
  });

  testWidgets('a malformed report corrects nothing, and drops the one before it', (tester) async {
    await _onIOS(() async {
      // A cast that threw here would be turned by the channel into a reply
      // the reporter never reads: the push gone, and nothing said about it.
      _portraitView(tester);
      _reporter(tester, _portrait);
      await tester.pumpWidget(app());
      await tester.pump();
      expect(seen.padding.top, 24);

      await _push(tester, {..._portrait(), 'width': '669'});
      expect(tester.takeException(), isNull);
      expect(seen.padding.top, 82);
    });
  });

  testWidgets('off iOS the channel is never asked', (tester) async {
    final calls = <MethodCall>[];
    _portraitView(tester);
    _reporter(tester, _portrait, calls: calls);
    await tester.pumpWidget(app());
    await tester.pump();
    expect(calls, isEmpty);
    expect(seen.padding.top, 82);
  });
}
