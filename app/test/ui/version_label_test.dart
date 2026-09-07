// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_build_tools/halo_build_tools.dart' show MainVersion;
import 'package:ham2k_logger/config/version.dart';
import 'package:ham2k_logger/services/update_service.dart' show currentCodePush;
import 'package:ham2k_logger/i18n/strings.g.dart';
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
    // The LOCALIZED name with the edition qualifier — the row the operator
    // reads. kEditionVersionName is the canonical spelling that goes to the
    // clipboard and to notice matching, and asserting it here would pass in
    // English while the row silently stopped translating.
    expect(lines[0], withEdition(localizedVersionName()));
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

  group('the UI name and the canonical name describe the same version', () {
    const august = MainVersion(year: 26, month: 8);
    const versions = [
      PublicVersion(main: august, patch: 0),
      PublicVersion(main: august, patch: 3),
      PublicVersion(main: august, patch: 3, preRelease: 1),
      PublicVersion(main: august, patch: 0, preRelease: 2, preReleasePatch: 4, preReleaseLabel: 'rc'),
    ];

    test('localizedVersionName spells the same version displayName does', () {
      // Asserted through the FUNCTION the About row calls, not a hand-rolled
      // reconstruction of it: a parallel spelling here would pin the parts
      // while leaving the row free to drop one.
      //
      // Case-folded because the UI capitalizes (`Patch 1` opens a line of its
      // own) and upper-cases the pre-release token. This holds under `en`,
      // where the translation is word-for-word the canonical spelling; under
      // any other locale the two differ on purpose, which is the point of the
      // split — so this compares spellings, not languages.
      for (final version in versions) {
        expect(
          localizedVersionName(version: version, stageLabel: 'ALPHA').toLowerCase(),
          version.displayName(stageLabel: 'ALPHA').toLowerCase(),
        );
      }
    });

    test('the splash lines together spell it too', () {
      // The other rendering of the same name: the header's first line plus the
      // qualifiers that open its second.
      for (final version in versions) {
        final parts = version.displayParts(stageLabel: 'ALPHA');
        final lines = [
          parts.mainName,
          parts.stageLabel,
          versionQualifiers(version: version, stageLabel: 'ALPHA'),
        ].where((part) => part.isNotEmpty).join(' ');
        expect(lines.toLowerCase(), version.displayName(stageLabel: 'ALPHA').toLowerCase());
      }
    });

    test('this build spells its own name the same way on both surfaces', () {
      // The compiled-in constants. Weaker than the fixtures above by nature —
      // for most of a cycle the shipping version is a patch-0 release with no
      // qualifiers, and then this asserts only the release line and the stage
      // marker. It is here for the cells the fixtures cannot reach: the real
      // kStageLabel and the real MainVersion.
      expect(localizedVersionName().toLowerCase(), kVersionName.toLowerCase());
      expect(kVersionMainName, startsWith(kVersionParts.mainName));
    });

    test('a translation renders the patch NUMBER, not just the word', () async {
      // Slang builds the method signature from the base locale, so a
      // translation that drops `${patch}` still compiles — and then a Spanish
      // operator reads `Parche (build 131)`, a patch marker naming no patch.
      await LocaleSettings.setLocale(AppLocale.es);
      addTearDown(() => LocaleSettings.setLocale(AppLocale.en));

      final qualifiers = versionQualifiers(
        version: const PublicVersion(main: august, patch: 7),
        stageLabel: 'ALPHA',
      );
      expect(qualifiers, contains('7'));
      expect(qualifiers, isNot(equals('Patch 7')), reason: 'the es string should not be the en one');
    });
  });

  group('versionBuildLine', () {
    const august26 = MainVersion(year: 26, month: 8);

    test('a patch release names the patch, then the build', () {
      expect(
        versionBuildLine(
          version: const PublicVersion(main: august26, patch: 1),
          edition: Edition.next,
          build: 130,
          sha: '',
        ),
        'Patch 1 (build 130)',
      );
    });

    test('patch 0 is not spelled out — the line is the build alone', () {
      // "Patch 0" would name a thing that doesn't exist: the first release of a
      // version has no patch, which is why displayName omits it too.
      expect(
        versionBuildLine(
          version: const PublicVersion(main: august26, patch: 0),
          edition: Edition.next,
          build: 130,
          sha: '',
        ),
        '(build 130)',
      );
    });

    test('a pre-release rides between the patch and the build, upper-cased', () {
      // Upper-cased to read as a stage marker next to ALPHA on the line above,
      // whatever case the version string's own token carries.
      expect(
        versionBuildLine(
          version: const PublicVersion(main: august26, patch: 1, preRelease: 1),
          edition: Edition.next,
          build: 130,
          sha: '',
        ),
        'Patch 1 PRE 1 (build 130)',
      );
      expect(
        versionBuildLine(
          version: const PublicVersion(main: august26, patch: 1, preRelease: 1, preReleasePatch: 2),
          edition: Edition.next,
          build: 130,
          sha: '',
        ),
        'Patch 1 PRE 1.2 (build 130)',
      );
    });

    test('a Dev build keeps its rule: no build number, so the line can be the patch alone', () {
      // The whole reason buildDetails exists — Dev's kBuildNumber names the
      // last RELEASE, not the build in hand. Splitting the name across two
      // lines must not smuggle it back in.
      expect(
        versionBuildLine(
          version: const PublicVersion(main: august26, patch: 1),
          edition: Edition.dev,
          build: 130,
          sha: '',
        ),
        'Patch 1',
      );
    });

    test('a patch-0 Dev build with no SHA has nothing to say, so the line is empty', () {
      // The state every local `flutter run` lands in the day `halo-ops release`
      // cuts a new month version — asserted directly rather than through the
      // compiled-in constants, which only reach this case for one release at a
      // time. VersionLabel drops the whole second line on this, so an empty
      // string here is a contract, not an accident.
      expect(
        versionBuildLine(
          version: const PublicVersion(main: august26, patch: 0),
          edition: Edition.dev,
          build: 130,
          sha: '',
        ),
        isEmpty,
      );
    });

    test('a pre-release label that matches the stage marker stays lower-case', () {
      // `September '26 ALPHA` over `Patch 1 ALPHA 1` puts the same token on both
      // lines, and a tester can no longer tell the product's stage from this
      // build's pre-release counter. Case is what keeps them apart.
      //
      // stageLabel is passed rather than leaning on kStageLabel: pinned to the
      // constant, this case would stop being the collision case — and the one
      // below would start being it — the day a release cut edits that token,
      // reddening the suite for a reason unrelated to the edit.
      expect(
        versionBuildLine(
          version: const PublicVersion(main: august26, patch: 1, preRelease: 1, preReleaseLabel: 'alpha'),
          edition: Edition.next,
          build: 130,
          sha: '',
          stageLabel: 'ALPHA',
        ),
        'Patch 1 alpha 1 (build 130)',
      );
    });

    test('a pre-release label that differs from the stage marker is upper-cased', () {
      expect(
        versionBuildLine(
          version: const PublicVersion(main: august26, patch: 1, preRelease: 1, preReleaseLabel: 'alpha'),
          edition: Edition.next,
          build: 130,
          sha: '',
          stageLabel: 'BETA',
        ),
        'Patch 1 ALPHA 1 (build 130)',
      );
    });

    test('a code push extends the build number, and the SHA rides along', () {
      expect(
        versionBuildLine(
          version: const PublicVersion(main: august26, patch: 1),
          edition: Edition.next,
          build: 130,
          sha: '04e3d1',
          codePush: 2,
        ),
        'Patch 1 (build 130.2 - 04e3d1)',
      );
    });

    test('bareBuildNumber names the binary alone — no code push, no SHA, Dev or not', () {
      // The tester overlay's line is a notes KEY. Its notes are indexed by the
      // binary's number, so `build 130.2 - 04e3d1` over notes headed "What's new
      // in build 130" would name a build the index doesn't contain — and on Dev,
      // where every other display suppresses the number, it must still appear.
      expect(
        versionBuildLine(
          version: const PublicVersion(main: august26, patch: 1),
          edition: Edition.dev,
          build: 130,
          sha: '04e3d1',
          codePush: 2,
          bareBuildNumber: true,
        ),
        'Patch 1 (build 130)',
      );
    });
  });

  testWidgets('nameAndBuild splits the version across two lines', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: VersionLabel(nameAndBuild: true, detailStyle: TextStyle(fontSize: 12))));

    // The release LINE and stage marker on top (`August '26 ALPHA`), never the
    // whole kVersionName and never the edition-qualified name — the edition is
    // shown separately by the badge SVG (docs/releases.md §2.6).
    expect(find.text(kVersionMainName), findsOneWidget);
    expect(find.text(kEditionVersionName), findsNothing);
    expect(find.textContaining('Version '), findsNothing);
    // The build line is a SEPARATE line, not appended to the name above — and
    // when this build has nothing to identify it by (a patch-0 Dev build with
    // no SHA), no empty line is rendered in its place. Written against
    // versionBuildLine's emptiness rather than today's `Patch 1`, which becomes
    // '' the next time `halo-ops release` resets the patch to 0.
    final buildLine = versionBuildLine();
    expect(find.text(buildLine), buildLine.isEmpty ? findsNothing : findsOneWidget);
    if (kVersionName != kVersionMainName) expect(find.text(kVersionName), findsNothing);
  });

  group('nameAndBuild lines never wrap', () {
    // Fitting is the CALLER's job now (the overlays' shared header and the home
    // branding pane each scale their whole block), so what this label owes them
    // is lines that stay single — a wrapped line inside a scaled block would
    // shrink the brand mark to make room for a break that shouldn't be there.
    const style = TextStyle(fontSize: 32);
    const detail = TextStyle(fontSize: 20);

    testWidgets('both lines are unwrappable, whatever the pane does with them', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: SizedBox(width: 60, child: VersionLabel(nameAndBuild: true, style: style, detailStyle: detail)),
          ),
        ),
      );

      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        expect(text.maxLines, 1, reason: 'wrapped line: "${text.data}"');
        expect(text.softWrap, isFalse, reason: 'wrappable line: "${text.data}"');
      }
    });

    testWidgets('one fit box around BOTH lines, never one each', (tester) async {
      // Two boxes scale by different factors: a short build line never needs
      // shrinking, so it would come out BIGGER than the version name it sits
      // under. One box keeps the hierarchy on the way down.
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: SizedBox(width: 60, child: VersionLabel(nameAndBuild: true, style: style, detailStyle: detail)),
          ),
        ),
      );

      // ONE box, scaling the whole column. The box COUNT is the assertion that
      // catches a per-line regression: `getSize` reports each Text's NATURAL
      // size (a FittedBox applies its fit as a paint transform), so comparing
      // the two lines' sizes passes under per-line boxes too — and comparing
      // the box's own width and height ratios is tautological, since scaleDown
      // is uniform by definition.
      expect(find.byType(FittedBox), findsOneWidget);
      final box = tester.getSize(find.byType(FittedBox));
      final column = tester.getSize(find.byType(Column).last);
      expect(box.width, lessThan(column.width), reason: 'the block should scale down into the 60px pane');
    });
  });
}
