// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What the Web Site pane will load.
//
// This is the ONLY gate between what the operator types and what the web view
// is handed: a panel form's `pattern` is inert, because `showPanelSettings`
// passes no validator to `FormRenderer`. So a hole here is a hole in the
// feature, not a missing nicety — and the two that matter (`javascript:` and
// `data:`) are script execution in whatever origin the pane last held, since
// this pane runs scripts.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/views/operation/website/website_url.dart';

void main() {
  ({Uri? uri, WebsiteUrlProblem? problem}) parse(String raw) {
    WebsiteUrlProblem? seen;
    final uri = parseWebsiteUrl(raw, problem: (p) => seen = p);
    return (uri: uri, problem: seen);
  }

  group('what loads', () {
    test('an https URL, with its path and query intact', () {
      final r = parse('https://dxheat.com/dxc/?band=20');
      expect(r.problem, isNull);
      expect(r.uri.toString(), 'https://dxheat.com/dxc/?band=20');
    });

    test('surrounding whitespace is forgiven', () {
      // Pasting a URL brings a trailing newline more often than not.
      expect(parse('  https://qrz.com \n').uri?.host, 'qrz.com');
    });
  });

  group('what does not load', () {
    test('a script URL, in either case', () {
      // The one that matters most: scripts are ON in this pane, so a
      // `javascript:` URL executes against whatever origin the pane last
      // held. The mixed-case rows pin the fact that `Uri` normalizes a
      // scheme while parsing — the gate does no case-folding of its own, and
      // this is what says that is safe rather than lucky.
      for (final bad in ['javascript:alert(1)', 'JavaScript:alert(1)', 'JAVASCRIPT:alert(1)']) {
        expect(parse(bad).problem, WebsiteUrlProblem.notHttps, reason: bad);
        expect(parse(bad).uri, isNull, reason: bad);
      }
    });

    test('a data URL, even though the sandboxed panel view relies on them', () {
      // `data:` is how the HTML panel kind inlines its assets, and it is safe
      // THERE because that view has scripts off. Copying the allowance here
      // would import the transport without the condition that made it safe.
      expect(parse('data:text/html,<script>alert(1)</script>').problem, WebsiteUrlProblem.notHttps);
    });

    test('a file URL', () {
      expect(parse('file:///etc/passwd').problem, WebsiteUrlProblem.notHttps);
    });

    test('plain http, which would work on Windows and fail everywhere else', () {
      // Not a taste call: there are no ATS exemptions in either Info.plist and
      // no Android cleartext config, so http is already blocked on Apple and
      // Android. Accepting it here would ship a URL that loads on one platform
      // and silently blanks on the others.
      expect(parse('http://192.168.1.50/').problem, WebsiteUrlProblem.notHttps);
    });

    test('a bare host, rather than guessing a scheme for it', () {
      // `Uri.tryParse('qrz.com')` SUCCEEDS — it parses as a relative path — so
      // a null check is not the test. And silently prefixing `https://` would
      // load somewhere the operator did not name.
      expect(parse('qrz.com').problem, WebsiteUrlProblem.notAUrl);
      expect(parse('www.qrz.com/db').problem, WebsiteUrlProblem.notAUrl);
    });

    test('a scheme with no host', () {
      expect(parse('https://').problem, WebsiteUrlProblem.notAUrl);
    });

    test('nothing typed is not an error', () {
      // A fresh pane has no URL yet. Reporting that as malformed would put a
      // red message in front of an operator who has done nothing wrong.
      expect(parse('').problem, WebsiteUrlProblem.empty);
      expect(parse('   ').problem, WebsiteUrlProblem.empty);
    });
  });

  group('websiteShortName', () {
    test('names the tab after the host, without www', () {
      // Two panes must be tellable apart on their tabs, and the full URL does
      // not fit.
      expect(websiteShortName('https://www.qrz.com/db/W1AW'), 'qrz.com');
      expect(websiteShortName('https://dxheat.com/dxc/'), 'dxheat.com');
      expect(websiteShortName('https://sub.example.co.uk/x'), 'sub.example.co.uk');
    });

    test('is empty when there is no host to name', () {
      expect(websiteShortName(''), '');
      expect(websiteShortName('qrz.com'), '');
    });
  });

  group('websiteRefreshInterval', () {
    test('maps the offered choices', () {
      expect(websiteRefreshInterval(1), const Duration(minutes: 1));
      expect(websiteRefreshInterval(5), const Duration(minutes: 5));
      expect(websiteRefreshInterval(15), const Duration(minutes: 15));
    });

    test('never is never', () {
      expect(websiteRefreshInterval(0), isNull);
      expect(websiteRefreshInterval(null), isNull);
    });

    test('a value this build does not offer does not become a refresh', () {
      // A layout outlives the build that wrote it. A stored `2` from some
      // other set of choices must not start a two-minute reload the operator
      // cannot see configured anywhere — and a negative must not become a
      // timer that fires continuously.
      expect(websiteRefreshInterval(2), isNull);
      expect(websiteRefreshInterval(-5), isNull);
      expect(websiteRefreshInterval('5'), isNull);
    });
  });
}
