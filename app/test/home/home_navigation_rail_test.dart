// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The rail is the ONLY route to Settings from Home — the header's cog moved
// into it — so "the rail is on screen at this width" and "its Settings entry
// is a live control" are not cosmetic assertions: either one failing strands
// the operator on the home screen with no way into Settings at all.
//
// The width rule has no crash signal either. `homeNavExpanded` is honoured
// only where there is width to spend on labels, and a regression that honours
// it everywhere costs a 360px phone a third of its width silently — the labels
// simply appear, and nothing throws.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/views/home_navigation_rail.dart';
import 'package:ham2k_logger/views/header_profile_label.dart';
import 'package:ham2k_logger/views/home_view.dart';
import 'package:ham2k_logger/views/settings_view.dart';

import '../support/halo_test_support.dart';

Future<HaLoServices> _services(WidgetTester tester) async {
  return (await makeHaLoServices()).services;
}

Future<void> _pumpHome(WidgetTester tester, HaLoServices services, {required Size size, ThemeData? theme}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  // Through the shell the ROOT uses, not HomeView bare: the rail is a sibling
  // of the window's chrome now, so a test that pumped the view alone would be
  // exercising a composition that does not ship.
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        theme: theme,
        home: HomeRailShell(
          services: services,
          routes: HomeView(services: services),
        ),
      ),
    ),
  );

  // Home is `MaterialApp.home` and arms two timers on mount — the FAB's
  // settle deadline and the first-run nudge's wait. A test that simply ends
  // leaves them pending, and the binding asserts "a Timer is still pending
  // even after the widget tree was disposed", which reads as the test hanging
  // rather than as the teardown it actually is. Unmount, then let their
  // wall-clock run out.
  addTearDown(() async {
    await _endOfTest(tester);
  });
  await _settle(tester);
}

/// A BOUNDED pump. Never `pumpAndSettle`: pushing Settings puts a view that
/// loads extensions and accounts asynchronously on screen, and it has no
/// settled state to wait for — the default 10-minute timeout is what a test
/// that asks for one actually gets.
Future<void> _settle(WidgetTester tester) => settleFrames(tester);

/// The width the rail actually OCCUPIES — its clip, not the widget inside it.
///
/// The rail is laid out at its full contents width and clipped down to the
/// visible one (that is how it opens and closes without squeezing its glyphs),
/// so measuring the widget reports the same number in every state, including
/// the state where the rail is not on screen at all.
double _railWidth(WidgetTester tester) => tester.getSize(find.ancestor(of: find.byType(HomeNavigationRail), matching: find.byType(ClipRect)).first).width;

/// Unmounts the tree and lets Home's timers run out.
///
/// Called at the END OF EACH TEST BODY, never from `addTearDown`: flutter_test
/// asserts "a Timer is still pending even after the widget tree was disposed"
/// as part of running the body, which is BEFORE any tearDown callback gets a
/// turn — so a drain registered there is too late to prevent the very thing it
/// is for.
///
/// Stepped, because the timers CHAIN: Home's nudge wait fires at 5s and only
/// then mounts the widget that arms its own ~9.7s settle, so one long advance
/// past the first deadline still leaves the second pending.
Future<void> _endOfTest(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(seconds: 6));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a wide window always has the rail, and its header carries no settings cog', (tester) async {
    final services = await _services(tester);
    await _pumpHome(tester, services, size: const Size(1000, 800));

    expect(_railWidth(tester), HomeNavigationRail.collapsedWidth, reason: 'a permanent fixture at this width');
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.byIcon(MdiIcons.cogOutline)),
      findsNothing,
      reason: 'the cog belongs to the rail here; two routes to Settings is what removing it from the header settles',
    );
    await _endOfTest(tester);
  });

  testWidgets('a phone starts with no rail, and gets one from the logo', (tester) async {
    final services = await _services(tester);
    await _pumpHome(tester, services, size: const Size(400, 800));

    // Not merely narrow — ABSENT. A 360px window cannot spare a permanent
    // column, so the mark and a settings button sit in the header instead, and
    // the operator asks for the rail when they want it.
    expect(_railWidth(tester), 0, reason: 'a phone starts without the rail');
    final cog = find.descendant(of: find.byType(AppBar), matching: find.byIcon(MdiIcons.cogOutline));
    expect(cog, findsOneWidget, reason: 'with no rail to hold it, Settings needs a way in from the header');

    await tester.tap(find.bySemanticsLabel('Show or hide the navigation labels'));
    await _settle(tester);

    expect(_railWidth(tester), HomeNavigationRail.collapsedWidth, reason: 'the logo brings in the narrow rail — never the labelled one at this width');
    expect(find.text('Operations'), findsNothing, reason: 'labels would take a third of a 400px window');
    expect(cog, findsNothing, reason: 'the header button goes as the rail arrives; the rail carries Settings now');
    await _endOfTest(tester);
  });

  testWidgets('the railless header holds only the cog; the profile name and layout button come with the rail', (tester) async {
    final services = await _services(tester);
    await _pumpHome(tester, services, size: const Size(400, 800));

    final profile = find.descendant(of: find.byType(AppBar), matching: find.byType(HeaderProfileLabel));
    final layoutButton = find.descendant(of: find.byType(AppBar), matching: find.byIcon(MdiIcons.viewDashboard));
    expect(_railWidth(tester), 0);
    expect(profile, findsNothing, reason: 'a phone header already holds the product name and the cog');
    expect(layoutButton, findsNothing);

    await tester.tap(find.bySemanticsLabel('Show or hide the navigation labels'));
    await _settle(tester);
    expect(profile, findsOneWidget);
    expect(layoutButton, findsOneWidget);
    await _endOfTest(tester);
  });

  testWidgets('a rail toggled away mid-edit leaves the way out of the edit in the header', (tester) async {
    // The trap in hiding the layout controls by the rail alone: once editing
    // they are Save and Discard, and the rail going would take the only way
    // out of the edit with it.
    final services = await _services(tester);
    await _pumpHome(tester, services, size: const Size(600, 800));
    final logo = find.bySemanticsLabel('Show or hide the navigation labels');

    await tester.tap(logo);
    await _settle(tester);
    await tester.tap(find.descendant(of: find.byType(AppBar), matching: find.byIcon(MdiIcons.viewDashboard)));
    await _settle(tester);
    await tester.tap(logo);
    await _settle(tester);

    expect(_railWidth(tester), 0);
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.byIcon(MdiIcons.contentSave)),
      findsOneWidget,
      reason: 'the edit controls outlive the rail',
    );
    await _endOfTest(tester);
  });

  testWidgets('the logo toggles the labels, and the choice survives a remount', (tester) async {
    final services = await _services(tester);
    await _pumpHome(tester, services, size: const Size(1000, 800));

    expect(_railWidth(tester), HomeNavigationRail.collapsedWidth, reason: 'collapsed by default');
    expect(find.text(services.settings.homeNavExpanded ? '' : 'Operations'), findsNothing);

    // By its accessible name, not its position: the logo lives at the top of
    // the RAIL now rather than in the header, and a finder anchored to either
    // one would be re-pointed by the next layout change. The name is what the
    // control promises and is the same wherever it is drawn.
    await tester.tap(find.bySemanticsLabel('Show or hide the navigation labels'));
    await _settle(tester);

    expect(_railWidth(tester), HomeNavigationRail.expandedWidth, reason: 'the logo is the toggle');
    expect(find.text('Operations'), findsOneWidget, reason: 'expanded means the labels are readable');
    expect(services.settings.homeNavExpanded, isTrue, reason: 'and the choice is stored, not just held in the State');

    // A fresh HomeView over the same settings — what a relaunch amounts to.
    await _pumpHome(tester, services, size: const Size(1000, 800));
    expect(_railWidth(tester), HomeNavigationRail.expandedWidth, reason: 'the stored choice is read back');
    await _endOfTest(tester);
  });

  testWidgets('with no rail, Settings gets the corner and its own way out', (tester) async {
    final services = await _services(tester);
    await _pumpHome(tester, services, size: const Size(400, 800));

    await tester.tap(find.descendant(of: find.byType(AppBar), matching: find.byIcon(MdiIcons.cogOutline)));
    await _settle(tester);

    // The mark is drawn OVER the top-left corner by the window, and is never
    // taken down for a view that does not cover it. With no rail under it,
    // that corner is also where Settings puts its back button — so Settings
    // holds the mark's column and the button lands BESIDE it. Overlapping,
    // the mark would sit on top of the only way out.
    expect(find.byType(BackButton), findsOneWidget, reason: 'embedded Settings pops itself, so it needs the button');
    final logo = find.bySemanticsLabel('Show or hide the navigation labels');
    expect(logo, findsOneWidget, reason: 'the mark stays; nothing here covers it');
    expect(
      tester.getTopLeft(find.byType(BackButton)).dx,
      greaterThanOrEqualTo(tester.getBottomRight(logo.first).dx),
      reason: 'the button must clear the mark, not share its corner',
    );

    await _endOfTest(tester);
  });

  testWidgets('a landscape cutout widens the rail instead of squeezing it', (tester) async {
    final services = await _services(tester);
    // Physical pixels, and `_pumpHome` pins the ratio at 1 — so this is 59
    // logical points of cutout, roughly what a notched phone reports on its
    // leading edge in landscape.
    tester.view.padding = const FakeViewPadding(left: 59, top: 0, right: 0, bottom: 0);
    addTearDown(tester.view.resetPadding);
    await _pumpHome(tester, services, size: const Size(1000, 800));

    // A notch in landscape falls on the RAIL — it is what touches that edge.
    // Taken as padding INSIDE a fixed 64pt column it would leave 5pt for a
    // 35pt glyph, so the rail grows by it instead. Every width the shell
    // computes has to carry the cutout too: the rail is laid out at a TIGHT
    // width, and one that left the cutout out would clamp the widening away
    // and overflow the glyph out of its own column — on device only, where a
    // cutout exists at all.
    expect(_railWidth(tester), HomeNavigationRail.collapsedWidth + 59, reason: 'the rail holds its own column PLUS the cutout');
    expect(tester.takeException(), isNull, reason: 'nothing may overflow');

    // And it is still the ICON-ONLY rail. The cutout makes it wider than a
    // bare 64, so a width test written against that number reads it as
    // already expanded and builds the labels — under a clip that is 64 wide
    // plus a notch, which shows a sliver of the first letter at the rail's
    // edge and nothing else. Only ever visible on a device with a cutout,
    // which is why no desktop or browser check would catch it.
    expect(find.text('Operations'), findsNothing, reason: 'a notch is not the operator asking for labels');
    expect(find.text('Settings'), findsNothing, reason: 'and the cap follows the same state as the rail above it');

    await _endOfTest(tester);
  });

  testWidgets('a cutout keeps off Quick Lookup, where there is no rail to take it', (tester) async {
    final services = await _services(tester);
    // A landscape phone with the toggle off — the shipped default there, and
    // the one arrangement where this view really does touch the leading edge.
    tester.view.padding = const FakeViewPadding(left: 59, top: 0, right: 0, bottom: 0);
    addTearDown(tester.view.resetPadding);
    await _pumpHome(tester, services, size: const Size(600, 400));

    expect(_railWidth(tester), 0, reason: 'no rail here, so nothing else is taking the cutout');
    // The FIELD's leading edge, not the bar's: the bar is edge-to-edge teal on
    // purpose, and it is the magnifier and the first characters typed that a
    // notch would land on.
    expect(
      tester.getTopLeft(find.byType(TextField)).dx,
      greaterThanOrEqualTo(59),
      reason: 'the lookup field must clear the cutout itself when no rail is doing it',
    );
    await _endOfTest(tester);
  });

  testWidgets('the keyboard does not bury the Settings destination', (tester) async {
    final services = await _services(tester);
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // The rail runs the full height of the window and pins Settings to the
    // bottom of ITSELF, so a keyboard over that corner takes the app's only
    // route to Settings with it — and the shell cannot see the keyboard on its
    // own (it is built inside `removeViewInsets`), which is why the inset is
    // handed to it.
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: HomeRailShell(
            services: services,
            routes: HomeView(services: services),
            // What the root reserves for the keyboard: a spacer below the whole
            // band, so nothing above it can reach into the keyboard's space.
            keyboard: const [SizedBox(height: 300, width: double.infinity)],
          ),
        ),
      ),
    );
    await _settle(tester);

    expect(
      tester.getBottomLeft(find.byType(HomeNavigationRail)).dy,
      lessThanOrEqualTo(800 - 300),
      reason: 'the rail must stop above the band and the keyboard below it',
    );

    await _endOfTest(tester);
  });

  testWidgets('the home indicator does not sit on the Settings destination', (tester) async {
    final services = await _services(tester);
    tester.view.padding = const FakeViewPadding(left: 0, top: 47, right: 0, bottom: 34);
    addTearDown(tester.view.resetPadding);
    await _pumpHome(tester, services, size: const Size(1000, 800));

    // Settings is pinned to the BOTTOM of the rail, which runs the full height
    // of the window — so it is the one destination a home indicator lands on.
    // The rail runs outside any Scaffold, so nothing above it has taken that
    // inset on its behalf.
    final cog = find.descendant(of: find.byType(HomeNavigationRail), matching: find.byIcon(MdiIcons.cogOutline));
    expect(tester.getBottomLeft(cog).dy, lessThanOrEqualTo(800 - 34), reason: 'the glyph must clear the home indicator, not sit under it');

    await _endOfTest(tester);
  });

  testWidgets('the selected destination is not marked with the teal that vanishes on the rail', (tester) async {
    final theme = buildHaLoTheme(Brightness.dark);
    final services = await _services(tester);
    await _pumpHome(tester, services, size: const Size(1200, 800), theme: theme);

    // Operations is where Home opens, so it is the selected one. It has no MDI
    // outline variant, which is why this matters: with no solid/outline
    // contrast to fall back on, colour is the ONLY thing separating the
    // selected destination from the rest.
    final icon = tester.widget<Icon>(find.descendant(of: find.byType(HomeNavigationRail), matching: find.byIcon(MdiIcons.notebookMultiple)));

    // The rail paints on `surfaceContainerHighest`, a band off `surface`, and
    // `colorScheme.primary` is the SAME teal in both brightnesses — 1.45:1
    // there, dimmer than the unselected destinations it has to stand out
    // from. Reaching for the scheme role is the natural mistake, and it looks
    // right in light mode, so this pins the value rather than the branch.
    expect(icon.color, isNot(theme.colorScheme.primary));
    expect(icon.color, const Color(0xFF6FC7E0));

    await _endOfTest(tester);
  });

  testWidgets('one stored preference, read differently at each width', (tester) async {
    final services = await _services(tester);
    await services.settings.setHomeNavExpanded(true);

    // The SAME stored value means "labels" where there is room for them and
    // "show the rail at all" where there is not, so a phone must never read it
    // as labels — and must not rewrite it either, or widening the window would
    // come back collapsed.
    await _pumpHome(tester, services, size: const Size(400, 800));
    expect(_railWidth(tester), HomeNavigationRail.collapsedWidth, reason: 'on, but icon-only');
    expect(find.text('Operations'), findsNothing);
    expect(services.settings.homeNavExpanded, isTrue);

    await _pumpHome(tester, services, size: const Size(1000, 800));
    expect(_railWidth(tester), HomeNavigationRail.expandedWidth, reason: 'the same value, read as labels');
    await _endOfTest(tester);
  });

  testWidgets('Settings opens from the rail; Operations names where we already are and does not navigate', (tester) async {
    final services = await _services(tester);
    await _pumpHome(tester, services, size: const Size(1000, 800));

    await tester.tap(find.descendant(of: find.byType(HomeNavigationRail), matching: find.byIcon(MdiIcons.notebookMultiple)));
    await _settle(tester);
    expect(find.byType(SettingsView), findsNothing, reason: 'Operations is the screen we are on — it must not push anything');
    expect(find.byType(HomeView), findsOneWidget);

    await tester.tap(find.descendant(of: find.byType(HomeNavigationRail), matching: find.byIcon(MdiIcons.cog)));
    await _settle(tester);
    expect(find.byType(SettingsView), findsOneWidget, reason: 'the rail is the only way into Settings from Home');

    await tester.tap(find.descendant(of: find.byType(HomeNavigationRail), matching: find.byIcon(MdiIcons.notebookMultiple)));
    await _settle(tester);
    // Settings rides over Home on an AnimationController, and the slide OUT
    // ends with no rebuild of its own. Left mounted, it goes on laying itself
    // out against a pane it no longer occupies — which is a negative padding
    // and a caught assertion, not merely a wasted subtree.
    expect(find.byType(SettingsView), findsNothing, reason: 'going back must UNMOUNT Settings, not park it off-screen');

    // The cog is a TOGGLE, where Operations is inert on its own screen: the
    // operator who opened Settings from here reaches for the same control to
    // put it away, and an inert one leaves them hunting for the back button.
    final cog = find.descendant(of: find.byType(HomeNavigationRail), matching: find.byIcon(MdiIcons.cog));
    await tester.tap(cog);
    await _settle(tester);
    expect(find.byType(SettingsView), findsOneWidget);
    await tester.tap(cog);
    await _settle(tester);
    expect(find.byType(SettingsView), findsNothing, reason: 'a second press on the cog closes Settings again');

    await _endOfTest(tester);
  });

  testWidgets("the rail's Settings cap is exactly as tall as Quick Lookup beside it", (tester) async {
    final services = await _services(tester);
    await _pumpHome(tester, services, size: const Size(1000, 800));

    // The two make up one row across the foot of the window, and they are
    // built by different widgets in different subtrees — nothing forces them
    // to agree except both being [HomeQuickLookup.heightOf]. A field left to
    // measure itself (a dense decoration, a prefix icon) lands a few pixels
    // off that, and the cap beside it then reads as misaligned rather than as
    // the bar being an odd height.
    final cap = find.ancestor(of: find.byIcon(MdiIcons.cog), matching: find.byType(ColoredBox)).first;
    final context = tester.element(find.byType(HomeQuickLookup));
    expect(tester.getSize(find.byType(HomeQuickLookup)).height, HomeQuickLookup.heightOf(context));
    expect(tester.getSize(cap).height, tester.getSize(find.byType(HomeQuickLookup)).height);
    // Level, not merely equal: the same height at different offsets is still
    // two rows.
    expect(tester.getBottomLeft(cap).dy, moreOrLessEquals(tester.getBottomLeft(find.byType(HomeQuickLookup)).dy, epsilon: 0.01));
    await _endOfTest(tester);
  });

  testWidgets('anything over the home layer covers the rail, whatever pushed it', (tester) async {
    final services = await _services(tester);
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(() => homeRail.destination = HomeDestination.operations);

    // Through the app's own observer, which is what decides this. Declared by
    // the route instead, every route that does not opt in — ⌘K's jump to an
    // operation, a dialog, a deep link — leaves a live rail pasted over the
    // top of it: pressable, undimmed, and driving the Home underneath, which
    // the operator only discovers when they pop back into Settings.
    // Mounted the way the ROOT mounts it — `builder`, wrapping the Navigator —
    // not as a route itself. As `home:` the shell is inside the stack, so
    // anything pushed covers it whatever the flag says, and this test would
    // pass against the very bug it exists for.
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          navigatorObservers: [homeRailRouteObserver],
          builder: (context, child) => HomeRailShell(services: services, routes: child!),
          home: const _RouteHost(),
        ),
      ),
    );
    await _settle(tester);

    // Pressed by POSITION rather than by finder, because what is under test is
    // exactly whether a press there reaches the rail — a finder-driven tap
    // would answer a question about the widget tree instead.
    final cog = find.descendant(of: find.byType(HomeNavigationRail), matching: find.byIcon(MdiIcons.cog));
    final onTheCog = tester.getCenter(cog);
    homeRail.destination = HomeDestination.operations;
    await tester.tapAt(onTheCog);
    await _settle(tester);
    expect(homeRail.destination, HomeDestination.settings, reason: 'beside Home the rail is a fixture and must be pressable');

    homeRail.destination = HomeDestination.operations;
    await tester.tap(find.text('push a page'));
    await _settle(tester);
    await tester.tapAt(onTheCog);
    await _settle(tester);
    expect(homeRail.destination, HomeDestination.operations, reason: 'a view that owns the window covers the rail; a press there must not reach it');

    // Mid-pop, with the outgoing view still filling the window. `didPop` fires
    // when the pop is ASKED for, so a count released there paints the rail
    // over a screen on its way off and hands it the taps meant for it.
    await tester.tap(find.text('back'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    await tester.tapAt(onTheCog);
    await tester.pump();
    expect(homeRail.destination, HomeDestination.operations, reason: 'the rail stays under a route for the whole way out, not just until the pop is asked for');

    await _settle(tester);
    await tester.tapAt(onTheCog);
    await _settle(tester);
    expect(homeRail.destination, HomeDestination.settings, reason: 'and comes back once the route is gone');

    homeRail.destination = HomeDestination.operations;
    await tester.tap(find.text('open a dialog'));
    await _settle(tester);
    await tester.tapAt(onTheCog);
    await _settle(tester);
    expect(
      homeRail.destination,
      HomeDestination.operations,
      reason: 'a dialog dims the window; the rail must not float over it taking taps meant for the barrier',
    );
  });

  testWidgets('chrome handed to the shell after the first build reaches the screen', (tester) async {
    final services = await _services(tester);
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // The shell builds everything inside ONE OverlayEntry, and an entry rebuilds
    // only when it is told to. A notice raised while the app is running arrives
    // as a new `chrome` list on a new shell widget: nothing about that reaches
    // the entry on its own, so unfixed the notice appears only after a hot
    // restart and its dismiss button never takes.
    Future<void> pumpWith(List<Widget> chrome) => tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: HomeRailShell(services: services, routes: const SizedBox.expand(), chrome: chrome),
        ),
      ),
    );

    await pumpWith(const [Text('nothing to report')]);
    await _settle(tester);
    expect(find.text('nothing to report'), findsOneWidget);

    await pumpWith(const [Text('sync failed')]);
    await _settle(tester);
    expect(find.text('sync failed'), findsOneWidget, reason: 'a notice raised while the app runs must appear now');
    expect(find.text('nothing to report'), findsNothing, reason: 'and a dismissed one must go away');
  });
}

/// A stand-in for the app's routes: two controls that put something over the
/// home layer the way the app really does — a plain `MaterialPageRoute`, which
/// is what ⌘K and the deep-link path use, and a dialog.
class _RouteHost extends StatelessWidget {
  const _RouteHost();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => Scaffold(
                body: TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('back')),
              ),
            ),
          ),
          child: const Text('push a page'),
        ),
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const AlertDialog(title: Text('hi')),
            ),
            child: const Text('open a dialog'),
          ),
        ),
      ],
    ),
  );
}
