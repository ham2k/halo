// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/config/version.dart';
import 'package:ham2k_logger/services/update_service.dart' show currentCodePush;
import 'package:ham2k_logger/views/version_label.dart';

void main() {
  test('the default (unset HALO_EDITION) build is the Dev edition, and its name says "Edition"', () {
    // `flutter test` runs with no --dart-define, so the tree resolves to the
    // safe, non-distributed edition — and its qualifier is what makes a dev
    // build visibly distinct from a Regular one in the UI (docs/releases.md §2.6).
    expect(kEdition, Edition.dev);
    expect(kEditionVersionName, '$kVersionName (Dev Edition)');
  });

  test('the stage label rides the version name but never the version number', () {
    // The label qualifies the product, not the version, so it must not reach
    // kPublicVersion — which is what tags, plists and store fields project
    // from. Asserted as a shape rather than as `isNot(contains(kStageLabel))`:
    // `contains('')` is true of every string, so that form would fail the day
    // someone retires the label by setting it to '', for a reason unrelated to
    // what this guards.
    expect(kVersionName, contains(kStageLabel));
    expect(kPublicVersion, matches(RegExp(r'^\d+\.\d+\.\d+(-[a-z]+\d+(\.\d+)?)?$')));
  });

  group('buildDetails', () {
    test('a Dev build names only the SHA', () {
      // kBuildNumber in a Dev build is the last RELEASE's number, not this
      // build's — printing it would name a build that isn't running.
      expect(buildDetails(edition: Edition.dev, build: 125, sha: '04e3d1'), '(04e3d1)');
    });

    test('a Dev build with no SHA has nothing to say, so it says nothing', () {
      // Every local `flutter run` — only CI sets --dart-define=HALO_GIT_SHA.
      // The empty string is what lets callers drop the line entirely rather
      // than render a bare "()".
      expect(buildDetails(edition: Edition.dev, build: 125, sha: ''), isEmpty);
    });

    test('an official build names the build number and the SHA', () {
      expect(buildDetails(edition: Edition.next, build: 125, sha: '04e3d1'), '(build 125 - 04e3d1)');
      expect(buildDetails(edition: Edition.prod, build: 125, sha: '04e3d1'), '(build 125 - 04e3d1)');
    });

    test('an official build with no SHA still names the build number', () {
      expect(buildDetails(edition: Edition.next, build: 125, sha: ''), '(build 125)');
    });

    test('a running code push extends the build number rather than taking a field of its own', () {
      // `125.2`, not `125 - patch 2`: Shorebird's counter restarts at 1 for
      // every release, so the push number names nothing without the build it
      // sits on, and separating them invites a bug report quoting only the ".2".
      expect(buildDetails(edition: Edition.next, build: 125, sha: '04e3d1', codePush: 2), '(build 125.2 - 04e3d1)');
    });

    test('a Dev build DOES name the build number once a code push is running', () {
      // The reason Dev hides kBuildNumber — that it names the last release
      // rather than the build in hand — stops holding here: only a
      // `shorebird release` binary can carry a code push, so this IS that
      // release. Hiding it would leave a Dev tester with no way to say which
      // of several same-version pushes they are running, the whole point of
      // showing the number.
      expect(buildDetails(edition: Edition.dev, build: 125, sha: '04e3d1', codePush: 2), '(build 125.2 - 04e3d1)');
    });

    test('buildDetails reads the boot-cached code-push number when none is passed', () {
      // The seam that makes this work at all: every call site is a widget with
      // no services in reach, so it passes no codePush and the global is the
      // only path from the updater to the screen. Pass explicit values in every
      // other test and this wiring can rot silently.
      addTearDown(() => currentCodePush = null);
      currentCodePush = 3;
      expect(buildDetails(edition: Edition.next, build: 125, sha: ''), '(build 125.3)');
    });

    test('an empty parenthetical leaves no trailing space on the detail line', () {
      // The About row and the clipboard text both render this verbatim, so a
      // dangling space would ship into pasted bug reports. This is the case
      // `flutter test` actually runs (Dev, no SHA); the populated forms are
      // covered by the matrix above, which the compiled-in constants keep out
      // of reach of a widget test.
      expect(buildDetails(), isEmpty);
      expect(versionDetailLine(), 'Version $kPublicVersion');
      expect(versionDetailsText(), '$kEditionVersionName\nVersion $kPublicVersion');
    });
  });

  testWidgets('shows the version name and public version', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: VersionLabel()));

    // No FutureBuilder: the build number is a compiled-in constant, so the
    // full text is right on the first frame with no pumpAndSettle.
    expect(find.text('$kEditionVersionName · $kPublicVersion'), findsOneWidget);
  });

  testWidgets('prefix is prepended to the version text', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: VersionLabel(prefix: 'Version ')));

    expect(find.text('Version $kEditionVersionName · $kPublicVersion'), findsOneWidget);
  });

  testWidgets('renders as selectable text', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: VersionLabel()));

    expect(find.byType(SelectableText), findsOneWidget);
  });

  testWidgets('detailed mode splits into two lines — version name, then the version detail line', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: VersionLabel(detailed: true)));

    final lines = tester.widgetList<SelectableText>(find.byType(SelectableText)).map((w) => w.data).toList();
    expect(lines, hasLength(2));
    expect(lines[0], kEditionVersionName);
    // The shape, not `versionDetailLine()` — asserting the widget against the
    // function it calls would survive that function regressing.
    expect(lines[1], startsWith('Version $kPublicVersion'));
  });

  testWidgets('detailed mode\'s second line is smaller than the first', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: VersionLabel(detailed: true, style: TextStyle(fontSize: 15))),
    );

    final lines = tester.widgetList<SelectableText>(find.byType(SelectableText)).toList();
    expect(lines, hasLength(2));
    expect(lines[0].style?.fontSize, 15);
    expect(lines[1].style?.fontSize, lessThan(lines[0].style!.fontSize!));
  });

  testWidgets('detailed + boldFirstLine: name is bold, detail is normal weight and exactly two points smaller',
      (tester) async {
    // The About row's intent: the version name reads as the heading, the
    // "Version … (build …)" detail as secondary — normal weight, two points
    // smaller than the name.
    await tester.pumpWidget(
      const MaterialApp(
        home: VersionLabel(
          detailed: true,
          boldFirstLine: true,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
        ),
      ),
    );

    final lines = tester.widgetList<SelectableText>(find.byType(SelectableText)).toList();
    expect(lines[0].style?.fontWeight, FontWeight.bold);
    expect(lines[0].style?.fontSize, 16);
    expect(lines[1].style?.fontWeight, FontWeight.normal);
    expect(lines[1].style?.fontSize, 14);
  });

  testWidgets('nameOnly shows just the release name — no edition qualifier, no detail line', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: VersionLabel(nameOnly: true)));

    // The bare release name (kVersionName), NOT the edition-qualified name —
    // the edition is shown separately by the badge SVG (docs/releases.md §2.6) —
    // and none of the detailed mode's "Version …" line.
    expect(find.text(kVersionName), findsOneWidget);
    expect(find.text(kEditionVersionName), findsNothing);
    expect(find.textContaining('Version '), findsNothing);
  });
}
