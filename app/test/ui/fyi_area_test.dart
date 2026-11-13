// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The FYI area's one line (docs/design/logging-fields.md § The FYI area):
// how the room goes to the messages in order, how they come and go, what a
// tap does, and which set each message reaches. The keyer line it hosts is
// tested in keying/keyer_area_test.dart.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart' show DraftSuggestion, DraftSuggestionList, DraftSuggestions, HaLoColors, MdiIcons;
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/fyi_service.dart';
import 'package:ham2k_logger/views/fyi_area.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoServices services;
  late FyiService fyi;

  setUp(() async {
    final harness = await makeHaLoServices();
    services = harness.services;
    fyi = services.fyi;
  });

  // Wide enough for the messages below in the test font, a 14 px box per glyph.
  const width = 640.0;

  /// The area at a known width, as a set's info frame gives it one.
  Widget host({String radio = 'A', bool keyer = false, bool suppressed = false, DraftSuggestions? suggestions}) => TranslationProvider(
    child: MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: Column(
              children: [FyiArea(services: services, radio: radio, keyer: keyer, suppressed: suppressed, suggestions: suggestions)],
            ),
          ),
        ),
      ),
    ),
  );

  FyiMessage message(String key, FyiCategory category, String text, {IconData icon = MdiIcons.antenna, String? radio, VoidCallback? onTap}) =>
      FyiMessage(key: key, category: category, icon: icon, text: text, radio: radio, onTap: onTap);

  double areaHeight(WidgetTester tester) => tester.getSize(find.byType(FyiArea)).height;

  /// Pumps the slide in or out, and a resize.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('the line', () {
    testWidgets('takes no room with nothing to say, slides in with the first message and away after the last', (tester) async {
      await tester.pumpWidget(host());
      expect(areaHeight(tester), 0);
      fyi.post(message('storm', FyiCategory.warning, 'Thunderstorm 12 mi NW'));
      await tester.pump();
      final atStart = areaHeight(tester);
      await tester.pump(const Duration(milliseconds: 100));
      // The trap: the line at full size at once — what is under it moves
      // down rather than jumps.
      expect(areaHeight(tester), greaterThan(atStart));
      await tester.pump(const Duration(milliseconds: 200));
      final full = areaHeight(tester);
      expect(full, greaterThan(0));
      fyi.clear('storm');
      await settle(tester);
      expect(areaHeight(tester), 0);
    });

    testWidgets('rises out of the fields\' edge: mid-slide its top is the content\'s top, not its bottom', (tester) async {
      // The trap: the slide from the top, which pins the content's BOTTOM to
      // the growing edge and reads as dropping out of the info area.
      await tester.pumpWidget(host());
      fyi.post(message('storm', FyiCategory.warning, 'Thunderstorm 12 mi NW'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final area = tester.getRect(find.byType(FyiArea));
      final text = tester.getRect(find.text('Thunderstorm 12 mi NW'));
      expect(area.height, lessThan(text.height), reason: 'still sliding');
      // Three pixels of gap above the line and one of inset above its text.
      expect(text.top - area.top, closeTo(4, 1), reason: 'the content is pinned to the rising edge');
      await settle(tester);
    });

    testWidgets('has one height whatever it shows, and every text sits on the pill\'s baseline', (tester) async {
      // Without the fixed height, a pill replacing a plain alert moves the
      // entry row by a few pixels.
      await tester.pumpWidget(host());
      fyi.post(message('swr', FyiCategory.alert, 'SWR 2.4'));
      await settle(tester);
      final plain = areaHeight(tester);
      expect(plain, greaterThan(0));

      fyi.post(FyiMessage(key: 'band', category: FyiCategory.alert, priority: FyiPriority.high, icon: MdiIcons.radio, text: 'No Band'));
      fyi.post(message('storm', FyiCategory.warning, 'Storm', icon: MdiIcons.weatherLightning));
      fyi.post(message('kp', FyiCategory.info, 'Kp 4', icon: MdiIcons.sunWireless));
      await settle(tester);
      expect(areaHeight(tester), plain, reason: 'a pill and three texts share the height a text alone had');

      final pill = tester.getRect(find.text('No Band'));
      final text = tester.getRect(find.text('SWR 2.4'));
      expect(text.top, pill.top, reason: 'the same style at the same inset is the same baseline');
      expect(tester.getRect(find.text('Kp 4')).top, pill.top);
      expect(tester.getRect(find.byIcon(MdiIcons.antenna)).center.dy, closeTo(text.center.dy, 1), reason: 'an icon beside a text is centred on it');
      expect(tester.getRect(find.byIcon(MdiIcons.sunWireless)).center.dy, closeTo(text.center.dy, 1));

      fyi.clear('band');
      fyi.clear('storm');
      fyi.clear('kp');
      await settle(tester);
      expect(areaHeight(tester), plain);
    });

    testWidgets('every message shows its text, from the left: high alerts, what is under way, the other alerts, warnings, info', (tester) async {
      await tester.pumpWidget(host());
      fyi.post(message('kp', FyiCategory.info, 'Kp 4', icon: MdiIcons.sunWireless));
      fyi.post(message('storm', FyiCategory.warning, 'Storm', icon: MdiIcons.weatherLightning));
      fyi.post(message('swr', FyiCategory.alert, 'SWR 2.3'));
      fyi.post(message('tuning', FyiCategory.operational, 'Tuning', icon: MdiIcons.tune));
      fyi.post(FyiMessage(key: 'band', category: FyiCategory.alert, priority: FyiPriority.high, icon: MdiIcons.radio, text: 'No Band'));
      await settle(tester);
      // The traps: a message sharing the line folded to its icon; the info
      // pushed to the trailing edge, away from the rest; and what is under
      // way queued behind a reading.
      final area = tester.getRect(find.byType(FyiArea));
      final band = tester.getRect(find.text('No Band'));
      final tuning = tester.getRect(find.text('Tuning'));
      final swr = tester.getRect(find.text('SWR 2.3'));
      final storm = tester.getRect(find.text('Storm'));
      final kp = tester.getRect(find.text('Kp 4'));
      expect(tester.getRect(find.byIcon(MdiIcons.radio)).left, closeTo(area.left + 6, 1), reason: 'the high alert leads, inside its pill');
      expect(tuning.left, greaterThan(band.right), reason: 'then what is under way');
      expect(swr.left, greaterThan(tuning.right), reason: 'then the plain alert');
      expect(storm.left, greaterThan(swr.right), reason: 'then the warning');
      expect(kp.left, greaterThan(storm.right), reason: 'then the info');
      expect(kp.left - storm.right, lessThan(40), reason: 'right after the warning, not against the trailing edge');
    });

    testWidgets('the room goes to the messages in order: the first takes what it needs, the last what is left', (tester) async {
      await tester.pumpWidget(host());
      fyi.post(message('tuning', FyiCategory.operational, 'Tuning the amplifier', icon: MdiIcons.tune));
      await settle(tester);
      final alone = tester.getRect(find.text('Tuning the amplifier'));

      fyi.post(message('swr', FyiCategory.alert, 'SWR 2.3 on the dipole, check the feedline'));
      await settle(tester);
      final area = tester.getRect(find.byType(FyiArea));
      final tuning = tester.getRect(find.text('Tuning the amplifier'));
      // The trap: the line shared by flex, which squeezes what is under way
      // for a message that ranks under it.
      expect(tuning.width, alone.width, reason: 'the operational message keeps every pixel it had alone');
      final alert = tester.getRect(find.text('SWR 2.3 on the dipole, check the feedline'));
      expect(alert.left, greaterThan(tuning.right));
      expect(alert.right, lessThanOrEqualTo(area.right + 1), reason: 'the alert is cut to what is left');
      expect(alert.width, greaterThan(60), reason: 'and shows that much of itself');
    });

    testWidgets('a message arriving grows into its room and one leaving shrinks out of it, the rest following', (tester) async {
      await tester.pumpWidget(host());
      fyi.post(message('swr', FyiCategory.alert, 'High SWR 2.3'));
      fyi.post(message('kp', FyiCategory.info, 'Kp 4', icon: MdiIcons.sunWireless));
      await settle(tester);
      final kpBefore = tester.getRect(find.text('Kp 4')).left;

      fyi.post(message('storm', FyiCategory.warning, 'Storm 12 mi NW', icon: MdiIcons.weatherLightning));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      // The trap: the warning at its full width at once, the info jumping
      // right by the whole of it.
      final kpMidway = tester.getRect(find.text('Kp 4')).left;
      expect(kpMidway, greaterThan(kpBefore));
      await settle(tester);
      final kpAfter = tester.getRect(find.text('Kp 4')).left;
      expect(kpAfter, greaterThan(kpMidway), reason: 'still making room midway');

      fyi.clear('storm');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.text('Storm 12 mi NW'), findsOneWidget, reason: 'on its way out, still on the line');
      final kpLeaving = tester.getRect(find.text('Kp 4')).left;
      expect(kpLeaving, lessThan(kpAfter));
      expect(kpLeaving, greaterThan(kpBefore), reason: 'following the warning out, not jumping back');
      await settle(tester);
      expect(find.text('Storm 12 mi NW'), findsNothing);
      expect(tester.getRect(find.text('Kp 4')).left, kpBefore);
    });

    testWidgets('a message leaving shrinks where it was, not at one end of the line', (tester) async {
      await tester.pumpWidget(host());
      fyi.post(message('swr', FyiCategory.alert, 'High SWR 2.3'));
      fyi.post(message('storm', FyiCategory.warning, 'Storm 12 mi NW', icon: MdiIcons.weatherLightning));
      fyi.post(message('kp', FyiCategory.info, 'Kp 4', icon: MdiIcons.sunWireless));
      await settle(tester);
      fyi.clear('storm');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final storm = tester.getRect(find.text('Storm 12 mi NW'));
      expect(storm.left, greaterThan(tester.getRect(find.text('High SWR 2.3')).right));
      expect(storm.left, lessThan(tester.getRect(find.text('Kp 4')).left));
      await settle(tester);
    });
  });

  group('taps', () {
    testWidgets('a tap runs the message\'s action and dismisses it', (tester) async {
      var acted = 0;
      await tester.pumpWidget(host());
      fyi.post(message('storm', FyiCategory.warning, 'Storm 12 mi NW', icon: MdiIcons.weatherLightning, onTap: () => acted++));
      fyi.post(message('swr', FyiCategory.alert, 'High SWR 2.3'));
      await settle(tester);

      await tester.tap(find.text('Storm 12 mi NW'));
      await tester.pump();
      expect(acted, 1);
      expect(fyi.messageFor('storm'), isNull, reason: 'one tap puts it away');
      expect(fyi.messageFor('swr'), isNotNull);
      await settle(tester);
      expect(find.text('Storm 12 mi NW'), findsNothing);
    });

    testWidgets('a tap runs the action the message was last posted with', (tester) async {
      var first = 0, second = 0;
      await tester.pumpWidget(host());
      fyi.post(message('kp', FyiCategory.info, 'Kp 7', onTap: () => first++));
      await settle(tester);
      // Reads the same, so the line is not told of the re-post: the trap is
      // a slot running the action it was built with.
      fyi.post(message('kp', FyiCategory.info, 'Kp 7', onTap: () => second++));
      await tester.tap(find.text('Kp 7'));
      await settle(tester);
      expect((first, second), (0, 1));
    });

    testWidgets('a message on its way out takes no tap', (tester) async {
      var acted = 0;
      await tester.pumpWidget(host());
      fyi.post(message('storm', FyiCategory.warning, 'Storm 12 mi NW', icon: MdiIcons.weatherLightning, onTap: () => acted++));
      fyi.post(message('swr', FyiCategory.alert, 'High SWR 2.3'));
      await settle(tester);
      fyi.clear('storm');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      // The trap: a tap landing on a message as it shrinks, read as a
      // dismissal that holds a re-post down for three minutes.
      await tester.tap(find.text('Storm 12 mi NW'), warnIfMissed: false);
      await settle(tester);
      expect(acted, 0);
      fyi.post(message('storm', FyiCategory.warning, 'Storm 12 mi NW', icon: MdiIcons.weatherLightning));
      expect(fyi.messageFor('storm'), isNotNull, reason: 'cleared by its poster, not dismissed: it posts again at once');
      await settle(tester);
    });
  });

  group('tapped open', () {
    const long = 'SWR 2.3 on the dipole, check the feedline';
    Finder slotOf(String text) => find.ancestor(of: find.text(text), matching: find.byType(Align)).first;

    testWidgets('a message cut short opens on a tap, the rest making way, and the second tap dismisses it', (tester) async {
      var acted = 0;
      await tester.pumpWidget(host());
      fyi.post(message('tuning', FyiCategory.operational, 'Tuning the amplifier', icon: MdiIcons.tune));
      fyi.post(message('swr', FyiCategory.alert, long, onTap: () => acted++));
      await settle(tester);
      final cut = tester.getRect(find.text(long)).width;

      await tester.tap(find.text(long));
      await settle(tester);
      // The trap: dismissing a message the operator could not read in full.
      expect(acted, 0, reason: 'the first tap is to read it');
      expect(fyi.messageFor('swr'), isNotNull);
      expect(tester.getRect(find.text(long)).width, greaterThan(cut), reason: 'in full');
      expect(tester.getSize(slotOf('Tuning the amplifier')).width, 0, reason: 'the operational message made way');

      await tester.tap(find.text(long));
      await settle(tester);
      expect(acted, 1);
      expect(fyi.messageFor('swr'), isNull, reason: 'the second tap puts it away');
      expect(tester.getSize(slotOf('Tuning the amplifier')).width, greaterThan(0), reason: 'and the operational message is back');
    });

    testWidgets('a message opened folds back by itself after five seconds', (tester) async {
      await tester.pumpWidget(host());
      fyi.post(message('tuning', FyiCategory.operational, 'Tuning the amplifier', icon: MdiIcons.tune));
      fyi.post(message('swr', FyiCategory.alert, long));
      await settle(tester);
      final cut = tester.getRect(find.text(long)).width;
      await tester.tap(find.text(long));
      await settle(tester);
      await tester.pump(const Duration(seconds: 4));
      expect(tester.getRect(find.text(long)).width, greaterThan(cut), reason: 'still open');
      await tester.pump(const Duration(seconds: 2));
      await settle(tester);
      expect(tester.getRect(find.text(long)).width, cut, reason: 'folded back');
      expect(fyi.messageFor('swr'), isNotNull, reason: 'folding back is not a dismissal');
    });

    testWidgets('a message that leaves behind one tapped open is gone once that one folds back', (tester) async {
      await tester.pumpWidget(host());
      fyi.post(message('tuning', FyiCategory.operational, 'Tuning the amplifier', icon: MdiIcons.tune));
      fyi.post(message('swr', FyiCategory.alert, long));
      await settle(tester);
      await tester.tap(find.text(long));
      await settle(tester);
      fyi.clear('tuning');
      await settle(tester);
      await tester.pump(const Duration(seconds: 6));
      await settle(tester);
      // The trap: a slot already shrunk away has no shrink left to end on,
      // and a ghost of it keeps its place on the line.
      expect(find.text('Tuning the amplifier'), findsNothing);
      expect(find.text(long), findsOneWidget);
    });

    testWidgets('a message cleared by the action of the one tapped open is gone with it', (tester) async {
      await tester.pumpWidget(host());
      fyi.post(message('tuning', FyiCategory.operational, 'Tuning the amplifier', icon: MdiIcons.tune));
      fyi.post(message('swr', FyiCategory.alert, long, onTap: () => fyi.clear('tuning')));
      fyi.post(message('kp', FyiCategory.info, 'Kp 7'));
      await settle(tester);
      await tester.tap(find.text(long));
      await settle(tester);
      // The second tap clears the open message before its action runs: the
      // trap is reading the line as if nothing were open while the
      // operational slot is still at nothing.
      await tester.tap(find.text(long));
      await settle(tester);
      expect(find.text(long), findsNothing);
      expect(find.text('Tuning the amplifier'), findsNothing);
      expect(find.text('Kp 7'), findsOneWidget, reason: 'the line stays up for what is left');
    });

    testWidgets('a message that opted out of dismissal stays through its taps', (tester) async {
      var acted = 0;
      await tester.pumpWidget(host());
      fyi.post(
        FyiMessage(
          key: 'band',
          category: FyiCategory.alert,
          priority: FyiPriority.high,
          icon: MdiIcons.radio,
          text: 'No Band',
          dismissible: false,
          onTap: () => acted++,
        ),
      );
      await settle(tester);
      await tester.tap(find.text('No Band'));
      await settle(tester);
      expect(acted, 1, reason: 'its action still runs');
      expect(fyi.messageFor('band'), isNotNull, reason: 'a condition only the band pick answers');
      expect(find.text('No Band'), findsOneWidget);
    });
  });

  group('which set', () {
    testWidgets("a radio's message reaches its set alone; the station's reaches both", (tester) async {
      await tester.pumpWidget(host(radio: 'B'));
      fyi.post(message('swr:A', FyiCategory.alert, 'High SWR 2.3', radio: 'A'));
      await settle(tester);
      expect(areaHeight(tester), 0, reason: "radio A's trouble is not set B's");
      fyi.post(message('storm', FyiCategory.warning, 'Thunderstorm 12 mi NW', icon: MdiIcons.weatherLightning));
      fyi.post(message('swr:B', FyiCategory.alert, 'High SWR 1.9', radio: 'B'));
      await settle(tester);
      expect(find.text('High SWR 2.3'), findsNothing);
      expect(find.text('High SWR 1.9'), findsOneWidget);
      expect(find.text('Thunderstorm 12 mi NW'), findsOneWidget);
    });

    testWidgets('the keyer line comes before every message but a high alert', (tester) async {
      await services.settings.setExperimentEnabled('keyer', true);
      final node = await services.cat.addNode(typeKey: 'placeholder-radio', name: 'Bench Rig', config: placeholderRadioModel.variants.single.defaultConfig);
      await tester.runAsync(() => services.cat.connect(node.uuid));
      addTearDown(() => services.cat.disconnect(node.uuid));
      await tester.pumpWidget(host(keyer: true));
      fyi.post(message('swr', FyiCategory.alert, 'SWR 2.3'));
      fyi.post(FyiMessage(key: 'band', category: FyiCategory.alert, priority: FyiPriority.high, icon: MdiIcons.radio, text: 'No Band'));
      services.cat.sendCw('CQ DE N0DEV');
      await settle(tester);
      // The trap: the message keying queued behind an SWR reading — read
      // while it keys, it needs the room first.
      final key = tester.getRect(find.byIcon(MdiIcons.key));
      expect(key.left, greaterThan(tester.getRect(find.text('No Band')).right), reason: 'the pill still leads');
      expect(key.right, lessThan(tester.getRect(find.text('SWR 2.3')).left), reason: 'the keyer line before the reading');
      services.cat.stopCw();
      await tester.pump(const Duration(seconds: 62));
    });

    // The operating style's pill (StyleWatch): how the operator is working,
    // read before the keying it explains — and the keyer line still before
    // what is under way at the ordinary priority.
    testWidgets('a high operational message comes before the keyer line, the others after it', (tester) async {
      await services.settings.setExperimentEnabled('keyer', true);
      final node = await services.cat.addNode(typeKey: 'placeholder-radio', name: 'Bench Rig', config: placeholderRadioModel.variants.single.defaultConfig);
      await tester.runAsync(() => services.cat.connect(node.uuid));
      addTearDown(() => services.cat.disconnect(node.uuid));
      await tester.pumpWidget(host(keyer: true));
      fyi.post(message('tuning', FyiCategory.operational, 'Tuning', icon: MdiIcons.tune));
      fyi.post(FyiMessage(key: 'style', category: FyiCategory.operational, priority: FyiPriority.high, icon: MdiIcons.run, text: 'Run'));
      services.cat.sendCw('CQ DE N0DEV');
      await settle(tester);
      final key = tester.getRect(find.byIcon(MdiIcons.key));
      expect(key.left, greaterThan(tester.getRect(find.text('Run')).right));
      expect(key.right, lessThan(tester.getRect(find.text('Tuning')).left));
      services.cat.stopCw();
      await tester.pump(const Duration(seconds: 62));
    });

    testWidgets('editing a logged QSO hides the keyer line alone; the other messages stay', (tester) async {
      await services.settings.setExperimentEnabled('keyer', true);
      final node = await services.cat.addNode(typeKey: 'placeholder-radio', name: 'Bench Rig', config: placeholderRadioModel.variants.single.defaultConfig);
      await tester.runAsync(() => services.cat.connect(node.uuid));
      addTearDown(() => services.cat.disconnect(node.uuid));
      await tester.pumpWidget(host(keyer: true, suppressed: true));
      fyi.post(message('swr', FyiCategory.alert, 'High SWR 2.3'));
      services.cat.sendCw('CQ CQ CQ DE N0DEV N0DEV N0DEV K');
      await settle(tester);
      expect(find.text('High SWR 2.3'), findsOneWidget, reason: 'the antenna is as mismatched while a contact is corrected');
      expect(find.byIcon(MdiIcons.key), findsNothing, reason: 'the message keying is for the contact in progress, not the one being edited');
      services.cat.stopCw();
      await tester.pump(const Duration(seconds: 62));
    });
  });

  testWidgets('a high-priority alert draws as a filled pill, a plain one as text', (tester) async {
    // The pill is what tells "No Band" apart from an SWR reading at a glance:
    // the error colour BEHIND the text rather than on the icon alone.
    fyi.post(FyiMessage(key: 'band', category: FyiCategory.alert, priority: FyiPriority.high, icon: MdiIcons.radio, text: 'No Band'));
    fyi.post(message('swr', FyiCategory.alert, 'SWR 2.4'));
    await tester.pumpWidget(host());
    await settle(tester);

    // The app's alert red, not the scheme's error: in dark mode that is a
    // pale pink, and a pill in it reads as decoration.
    final red = HaLoColors.of(tester.element(find.byType(FyiArea))).alert;
    Finder filled(String text) =>
        find.ancestor(of: find.text(text), matching: find.byWidgetPredicate((w) => w is Container && (w.decoration as BoxDecoration?)?.color == red));
    expect(filled('No Band'), findsOneWidget);
    expect(filled('SWR 2.4'), findsNothing);
  });

  // Run's pill (StyleWatch): a low alert, filled all the same, in a colour
  // that is not the alert's.
  testWidgets('a message with a background colour draws as a pill in it, whatever its priority', (tester) async {
    const green = Color(0xFF5E7D63);
    fyi.post(FyiMessage(key: 'style', category: FyiCategory.alert, priority: FyiPriority.low, icon: MdiIcons.run, text: 'Run', backgroundColor: green));
    await tester.pumpWidget(host());
    await settle(tester);
    expect(
      find.ancestor(of: find.text('Run'), matching: find.byWidgetPredicate((w) => w is Container && (w.decoration as BoxDecoration?)?.color == green)),
      findsOneWidget,
    );
    final onAlert = HaLoColors.of(tester.element(find.byType(FyiArea))).onAlert;
    expect(tester.widget<Icon>(find.byIcon(MdiIcons.run)).color, onAlert, reason: 'the icon in the colour that reads on a pill');
  });

  // logging-fields.md § Draft suggestions. The trap is a list shown for text
  // the operator has typed past: its calls are what K1A could be, not what
  // K1AB could, and a tap on one would replace the call they are typing.
  group('the suggestions line', () {
    const list = DraftSuggestionList(
      forCall: 'K1A',
      drafts: [
        DraftSuggestion(
          call: 'K1AB',
          qso: {
            'their': {'call': 'K1AB'},
          },
          notices: {'duplicate'},
        ),
        DraftSuggestion(
          call: 'K1AC',
          qso: {
            'their': {'call': 'K1AC'},
          },
        ),
      ],
    );

    testWidgets('shows the calls while the set reads the text they were offered for, a duplicate struck through', (tester) async {
      final suggestions = DraftSuggestions()
        ..list = list
        ..call = 'k1a';
      addTearDown(suggestions.dispose);
      await tester.pumpWidget(host(suggestions: suggestions));
      await settle(tester);
      expect(find.text('K1AC'), findsOneWidget);
      expect(tester.widget<Text>(find.text('K1AB')).style!.decoration, TextDecoration.lineThrough);

      // Typed past: held a moment for the next list, but out of reach.
      final tapped = <int>[];
      suggestions
        ..onTap = tapped.add
        ..call = 'K1AX';
      await settle(tester);
      await tester.tap(find.text('K1AC'), warnIfMissed: false);
      expect(tapped, isEmpty, reason: 'its calls are what K1A could be, not K1AX');

      await tester.pump(const Duration(seconds: 1));
      await settle(tester);
      await settle(tester);
      expect(find.text('K1AC'), findsNothing);
      expect(areaHeight(tester), 0);
    });

    testWidgets('shows only the calls that fit whole, and tells the set how many', (tester) async {
      final suggestions = DraftSuggestions()
        ..list = DraftSuggestionList(
          forCall: 'K1A',
          drafts: [
            for (var i = 0; i < 10; i++)
              DraftSuggestion(
                call: 'K1A$i',
                qso: {
                  'their': {'call': 'K1A$i'},
                },
              ),
          ],
        )
        ..call = 'K1A';
      addTearDown(suggestions.dispose);
      await tester.pumpWidget(host(suggestions: suggestions));
      await settle(tester);
      final shown = suggestions.shownCount!;
      expect(shown, inInclusiveRange(1, 9), reason: 'ten calls of four 14 px glyphs do not fit in $width px');
      expect(find.text('K1A${shown - 1}'), findsOneWidget);
      expect(find.text('K1A$shown'), findsNothing, reason: 'a call that does not fit whole is not drawn at all');
    });

    testWidgets('the next list fades in over the one typed past, the area staying up', (tester) async {
      final suggestions = DraftSuggestions()
        ..list = list
        ..call = 'K1A';
      addTearDown(suggestions.dispose);
      await tester.pumpWidget(host(suggestions: suggestions));
      await settle(tester);
      final up = areaHeight(tester);

      suggestions.call = 'K1AB';
      await tester.pump(const Duration(milliseconds: 300));
      suggestions.list = const DraftSuggestionList(
        forCall: 'K1AB',
        drafts: [
          DraftSuggestion(
            call: 'WK1AB',
            qso: {
              'their': {'call': 'WK1AB'},
            },
          ),
        ],
      );
      await tester.pump();
      expect(areaHeight(tester), up, reason: 'the line never went away between the two lists');
      await settle(tester);
      expect(find.text('WK1AB'), findsOneWidget);
      expect(find.text('K1AC'), findsNothing);
    });

    testWidgets("a tap on a call is the set's to act on, and the line hides while a logged contact is open", (tester) async {
      final tapped = <int>[];
      final suggestions = DraftSuggestions()
        ..list = list
        ..call = 'K1A'
        ..onTap = tapped.add;
      addTearDown(suggestions.dispose);
      await tester.pumpWidget(host(suggestions: suggestions));
      await settle(tester);
      await tester.tap(find.text('K1AC'));
      expect(tapped, [1]);

      await tester.pumpWidget(host(suggestions: suggestions, suppressed: true));
      await settle(tester);
      await settle(tester);
      expect(find.text('K1AC'), findsNothing);
    });
  });
}
