// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Pure parsing for the web-preview DEV_LABEL: given a
// hostname, decide which preview name to show — or none. Deliberately free of
// any web/dart:html import so it stays unit-testable on the Dart VM.

/// Suffixes of a HaLo web-preview host. Each includes the separator (`.` or
/// `-`) that joins the preview name to it, so the bare PRODUCTION hosts
/// (`halo-dev-ham2k-net.pages.dev`, `halo-dev.ham2k.net`) can't match — they
/// have no name in front of the separator:
///   - Cloudflare Pages default domain: `<name>.halo-dev-ham2k-net.pages.dev`
///     (see `.github/workflows/deploy-web-preview.yml`)
///   - custom domain: `<name>-halo-dev.ham2k.net`
const List<String> _previewHostSuffixes = <String>[
  '.halo-dev-ham2k-net.pages.dev',
  '-halo-dev.ham2k.net',
];

/// The preview name encoded in [host], or `''` when [host] is a production
/// deployment, localhost, a custom domain, or otherwise not a single-label
/// preview alias.
///
/// Used as the automatic DEV_LABEL for web preview builds: those are release
/// builds (so the compile-time DEV_LABEL is stripped, see [debugEnvFlag]) yet
/// still want to show which preview they are.
String previewLabelForHost(String host) {
  for (final suffix in _previewHostSuffixes) {
    if (!host.endsWith(suffix)) continue;
    final name = host.substring(0, host.length - suffix.length);
    // Branch aliases (and per-deploy hashes) sit in a single DNS label;
    // anything containing a dot is an unexpected nested host — don't guess a
    // label from it.
    if (name.isEmpty || name.contains('.')) return '';
    return name;
  }
  return '';
}
