// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// An extension's `html` panel is refused on the web build, where a web view
// exists but is an iframe whose sandbox grants `allow-top-navigation` and
// `allow-popups` — so the no-navigation half of the panel sandbox, the half
// `_SandboxedHtmlView` leans on hardest, is not enforceable there. The full
// per-platform table and the reasoning are in docs/quirks.md.
//
// This reads the SOURCE rather than pumping a widget, the way
// no_hover_tooltips_test and links_leave_the_app_test enforce their own
// conventions, and it does so because the branch cannot be reached any other
// way. `kIsWeb` is a compile-time constant: on the host VM the guard is
// compiled away, so a widget test asserting the refusal would silently be
// asserting the NATIVE branch instead — green while enforcing nothing. A
// browser is the only place it is true at runtime, and a `--platform chrome`
// test cannot import panel_content_view.dart at all (it hangs at load; see
// docs/quirks.md).
//
// So the risk this exists for is not "the check computes the wrong answer" —
// it is one line, and it either reads `kIsWeb` or it does not. It is that a
// later edit REMOVES it: refactor the `switch` into per-kind widgets, drop
// the guard on the way past, and nothing on any platform goes red. That is
// exactly the mutation a source scan catches and a runtime test here cannot.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

File _panelContentView() {
  final file = File('lib/views/operation/panel_content_view.dart');
  // Loudly, not vacuously: a suite run from an unexpected cwd would otherwise
  // scan nothing and pass while enforcing nothing at all.
  if (!file.existsSync()) {
    fail('expected ${file.path} to exist — run this suite from the app package (cwd: ${Directory.current.path})');
  }
  return file;
}

/// The file's lines, with comments AND imports dropped.
///
/// Both exclusions are load-bearing, and both were found by mutation rather
/// than foresight. The gate is explained in a long comment naming `kIsWeb`
/// several times, so counting those stays green after the code is deleted.
/// And `import ... show kIsWeb, listEquals` matches just as well as the guard
/// does — with it left in, deleting the guard outright still left the
/// placement check below comparing the IMPORT's line number against
/// `_HtmlPanelView`'s and passing.
List<String> _codeLines() => _panelContentView()
    .readAsLinesSync()
    .where((l) => !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('import '))
    .toList();

void main() {
  test('the html panel kind is guarded by kIsWeb', () {
    final guards = _codeLines().where((l) => l.contains('kIsWeb')).toList();

    expect(
      guards,
      isNotEmpty,
      reason: 'panel_content_view.dart must refuse `html` panels on the web — an iframe cannot hold an\n'
          "extension's document to the no-navigation rule. See docs/quirks.md.",
    );
    // The guard has to RETURN, not merely mention kIsWeb — a condition whose
    // body fell away in a refactor reads identically to a scan looking only
    // for the identifier.
    expect(
      guards.any((l) => l.contains('return')),
      isTrue,
      reason: 'the kIsWeb check must return the unsupported message, not just test the flag:\n${guards.join('\n')}',
    );
  });

  test('the web refusal uses its own message, not the missing-web-view one', () {
    // Reusing `htmlPanelUnsupported` would be the tempting simplification and
    // it would be a lie: that string tells the operator this platform provides
    // no web view, and the web provides one. The distinct key is the only
    // thing keeping the refusal honest, and swapping it back is a silent
    // change no other test would notice.
    final guards = _codeLines().where((l) => l.contains('kIsWeb')).join('\n');

    expect(
      guards.contains('htmlPanelUnsupportedOnWeb'),
      isTrue,
      reason: 'the web refusal must use htmlPanelUnsupportedOnWeb:\n$guards',
    );
  });

  test('the guard sits ahead of the web view widget, not inside it', () {
    // Placement is the half a "does it mention kIsWeb" scan would miss. The
    // check belongs at the `case 'html'` branch, BEFORE _HtmlPanelView is
    // constructed: that widget's own probe answers a different question (does
    // a web view exist), and `probeWebviewSupport` deliberately answers yes on
    // the web because the Web Site pane shares it and legitimately runs there.
    // A guard that drifted inside _HtmlPanelView would either be dead or would
    // take the Web Site pane down with it.
    final lines = _codeLines();
    final guard = lines.indexWhere((l) => l.contains('kIsWeb'));
    final htmlPanelView = lines.indexWhere((l) => l.contains('_HtmlPanelView(html:'));

    expect(guard, isNonNegative);
    expect(htmlPanelView, isNonNegative);
    expect(
      guard,
      lessThan(htmlPanelView),
      reason: 'the kIsWeb refusal must come before _HtmlPanelView is built, at the `case \'html\'` branch',
    );
  });
}
