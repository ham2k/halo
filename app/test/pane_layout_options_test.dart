// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A pane's layout options, as they travel to storage and back
// (docs/design/layouts.md). Every rule here is about what a saved layout may
// contain and what it must survive: these are written by one build and read
// by the next, and a layout that will not parse is a view that will not open.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/operation/pane_layout_options.dart';

void main() {
  test('round-trips through JSON', () {
    const options = PaneLayoutOptions(
      title: 'Sked list',
      showHeader: false,
      fontScale: 'smaller',
      density: 'dense',
    );
    final revived = PaneLayoutOptions.fromJson(options.toJson());
    expect(revived.title, 'Sked list');
    expect(revived.showHeader, isFalse);
    expect(revived.fontScaleValue, FontScale.smaller);
    expect(revived.densityValue, DensityPreference.dense);
  });

  test('says nothing when it has nothing to say', () {
    expect(PaneLayoutOptions.none.isEmpty, isTrue);
    expect(const PaneLayoutOptions(title: '').isEmpty, isTrue, reason: 'a blank title is not a title');
    expect(const PaneLayoutOptions(showHeader: false).isEmpty, isFalse);

    // Empties are dropped in BOTH directions, so a layout nobody has
    // configured stores nothing at all rather than one inert entry per pane.
    expect(PaneLayoutOptions.mapToJson({'logging': PaneLayoutOptions.none}), isEmpty);
    expect(PaneLayoutOptions.mapFromJson({'logging': <String, dynamic>{}}), isEmpty);
  });

  test('an unrecognized override inherits rather than throwing', () {
    // A layout written by a newer build, or hand-edited. A pane at the app's
    // own size is a far better failure than a view that will not open — and
    // this is read during the first build of the Operation View.
    const options = PaneLayoutOptions(fontScale: 'gigantic', density: 'roomier-than-roomy', themeMode: 'system');
    expect(options.fontScaleValue, isNull);
    expect(options.densityValue, isNull);
    expect(options.themeBrightness, isNull, reason: 'only light/dark are real overrides — system is inherit');
    expect(options.isEmpty, isFalse, reason: 'unreadable is not absent — it round-trips back out untouched');
    expect(options.toJson()['fontScale'], 'gigantic');
  });

  test('themeMode round-trips to a Brightness', () {
    final revived = PaneLayoutOptions.fromJson(const PaneLayoutOptions(themeMode: 'dark').toJson());
    expect(revived.themeMode, 'dark');
    expect(revived.themeBrightness, Brightness.dark);
  });

  test('copyWith keeps a field by default and clears it only when told', () {
    const options = PaneLayoutOptions(title: 'Sked list', fontScale: 'smaller');
    // No args: every field survives untouched.
    final unchanged = options.copyWith();
    expect(unchanged.title, 'Sked list');
    expect(unchanged.fontScale, 'smaller');
    // Explicit null clears — the `_unset` sentinel is what tells "not passed"
    // apart from "passed null" here, since every field is itself nullable.
    final titleCleared = options.copyWith(title: null);
    expect(titleCleared.title, isNull);
    expect(titleCleared.fontScale, 'smaller', reason: 'clearing one field must not touch the others');
  });

  test('showHeader is tri-state: absent means the VIEW decides', () {
    // Absent is "no opinion", not "off" and not "on". The view supplies the
    // default — Operation's panes are headed, Home's are not — and a bool
    // could not tell "never asked" from "asked for a header", which on a
    // headerless-by-default view are opposite outcomes.
    expect(PaneLayoutOptions.fromJson(<String, dynamic>{}).showHeader, isNull);
    expect(PaneLayoutOptions.fromJson({'title': 'Notes'}).showHeader, isNull);
    expect(const PaneLayoutOptions(title: 'Notes').toJson().containsKey('showHeader'), isFalse);

    // Resolution against each view's default.
    const noOpinion = PaneLayoutOptions();
    expect(noOpinion.showsHeader(byDefault: true), isTrue);
    expect(noOpinion.showsHeader(byDefault: false), isFalse);

    // An opinion overrides the default in BOTH directions — the second is the
    // one a bool could not express: a header asked for on a view that hides
    // them by default.
    expect(const PaneLayoutOptions(showHeader: false).showsHeader(byDefault: true), isFalse);
    expect(const PaneLayoutOptions(showHeader: true).showsHeader(byDefault: false), isTrue);

    // And it survives a round trip, which is what makes it stick: `true` is
    // now a value worth storing, where before it was the default and dropped.
    expect(PaneLayoutOptions.fromJson(const PaneLayoutOptions(showHeader: true).toJson()).showHeader, isTrue);
    expect(const PaneLayoutOptions(showHeader: true).isEmpty, isFalse);
  });

  test('the map it hands back is always mutable', () {
    // The view owns it and edits it in place. A `const {}` on the
    // nothing-saved path — the commonest of all — would throw on the first
    // pane configured.
    final fresh = PaneLayoutOptions.mapFromJson(null);
    expect(() => fresh['logging'] = PaneLayoutOptions.none, returnsNormally);
  });

  test('a stored value of the wrong TYPE inherits, rather than throwing', () {
    // The one case that actually throws. `fontScaleValue` handles an unknown
    // NAME, but a plain cast on a number or a bool blows up inside a `late`
    // field read during build — an Operation View that shows an error tile on
    // every launch, with the dialog that would repair it behind the view that
    // will not open.
    final options = PaneLayoutOptions.fromJson({'fontScale': 3, 'density': true, 'title': 42});
    expect(options.isEmpty, isTrue);
    expect(options.fontScaleValue, isNull);
    expect(options.densityValue, isNull);
  });
}
