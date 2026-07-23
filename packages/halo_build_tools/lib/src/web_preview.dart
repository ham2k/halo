// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

// Web-preview deploy/prune support for halo-ops (ham2k/app-halo-dist#244).
//
// Previews are cut by tagging a commit `web-preview-<name>` and pushing it;
// `.github/workflows/deploy-web-preview.yml` deploys it to the
// `halo-dev-ham2k-net` Cloudflare Pages project under the branch alias
// `<name>`, served at `https://<name>-halo-dev.ham2k.net`.

/// Cloudflare Pages branch-alias length cap this project sanitizes names to
/// (mirrors deploy-web-preview.yml's `cut -c1-28`).
const int kPreviewNameMaxLength = 28;

/// The Cloudflare Pages project the previews live on.
const String kPreviewPagesProject = 'halo-dev-ham2k-net';

/// The zone previews' placeholder DNS records live in.
const String kPreviewZone = 'ham2k.net';

/// Sanitizes [raw] to the branch alias Cloudflare Pages will actually use —
/// exactly as `deploy-web-preview.yml` does, so the URL we print/target matches
/// what Cloudflare serves: strip an optional `web-preview-` prefix, lowercase,
/// map every non-`[a-z0-9-]` char to `-`, trim leading/trailing `-`, then cap at
/// [kPreviewNameMaxLength]. Returns null when the result is empty or a reserved
/// name (`dist` / `main`), both of which the workflow rejects.
String? sanitizePreviewName(String raw) {
  var name = raw.trim();
  if (name.startsWith('web-preview-')) name = name.substring('web-preview-'.length);
  name = name.toLowerCase().replaceAll(RegExp('[^a-z0-9-]'), '-');
  name = name.replaceAll(RegExp('^-+'), '').replaceAll(RegExp(r'-+$'), '');
  if (name.length > kPreviewNameMaxLength) name = name.substring(0, kPreviewNameMaxLength);
  if (name.isEmpty || name == 'dist' || name == 'main') return null;
  return name;
}

/// The `web-preview-<name>` git tag for a (sanitized) preview [name].
String previewTagName(String name) => 'web-preview-$name';

/// The public URL a preview [name] is served at.
String previewUrl(String name) => 'https://$name-halo-dev.ham2k.net';

/// The `<name>-halo-dev.ham2k.net` hostname of a preview's placeholder DNS
/// record.
String previewDnsHost(String name) => '$name-halo-dev.ham2k.net';

/// One Cloudflare Pages deployment, reduced to what pruning needs.
class PreviewDeployment {
  final String id;

  /// The branch alias — the preview name. The production deployment's is `main`.
  final String branch;
  final DateTime createdOn;

  const PreviewDeployment({required this.id, required this.branch, required this.createdOn});
}

/// Groups [deployments] by preview name, newest-first within each group,
/// dropping the production branch [productionBranch]. So each key is a live
/// preview and its value is every deployment under that alias (all of which a
/// prune must delete).
Map<String, List<PreviewDeployment>> groupPreviews(
  Iterable<PreviewDeployment> deployments, {
  String productionBranch = 'main',
}) {
  final byName = <String, List<PreviewDeployment>>{};
  for (final d in deployments) {
    if (d.branch == productionBranch || d.branch.isEmpty) continue;
    (byName[d.branch] ??= <PreviewDeployment>[]).add(d);
  }
  for (final list in byName.values) {
    list.sort((a, b) => b.createdOn.compareTo(a.createdOn));
  }
  return byName;
}

/// The preview names whose newest deployment is older than [maxAge] as of
/// [now] — the selection for `prune-previews --older-than`.
Set<String> previewsOlderThan(
  Map<String, List<PreviewDeployment>> groups, {
  required Duration maxAge,
  required DateTime now,
}) {
  final selected = <String>{};
  groups.forEach((name, deployments) {
    final newest = deployments.first.createdOn; // groups are newest-first
    if (now.difference(newest) > maxAge) selected.add(name);
  });
  return selected;
}
