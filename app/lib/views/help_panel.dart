// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Where to go when the app itself can't answer — ported from the tail of
// app-polo's settings screen, so an operator who knows one app finds the
// same places in the other.

import 'package:flutter/material.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../i18n/strings.g.dart';
import '../services/link_opener.dart' show openExternalUrl;

/// One destination: an icon, what it is, and where it goes. `mailto:` here as
/// readily as `https:` — [openExternalUrl] hands either to the platform.
typedef HelpLink = ({IconData icon, String title, String description, String url});

List<HelpLink> helpLinks(BuildContext context) {
  final t = context.t.settings.help;
  return [
    (icon: MdiIcons.forumOutline, title: t.forums, description: t.forumsDescription, url: 'https://forums.ham2k.com/'),
    (icon: MdiIcons.chatOutline, title: t.chat, description: t.chatDescription, url: 'https://discord.gg/c4Th9QkByJ'),
    (icon: MdiIcons.youtube, title: t.youtube, description: t.youtubeDescription, url: 'https://www.youtube.com/@Ham2KApps'),
    (icon: MdiIcons.instagram, title: t.instagram, description: t.instagramDescription, url: 'https://www.instagram.com/ham2kapps/'),
    (icon: MdiIcons.butterflyOutline, title: t.bluesky, description: t.blueskyDescription, url: 'https://bsky.app/profile/ham2k.com'),
    (icon: MdiIcons.emailAlertOutline, title: t.contact, description: t.contactDescription, url: 'mailto:help@ham2k.com'),
  ];
}

class HelpPanel extends StatelessWidget {
  const HelpPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: Space.md),
      children: [
        for (final link in helpLinks(context))
          ListTile(
            leading: Icon(link.icon),
            title: Text(link.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(link.description),
            trailing: const Icon(MdiIcons.openInNew),
            onTap: () => openExternalUrl(link.url),
            mouseCursor: SystemMouseCursors.click,
          ),
      ],
    );
  }
}
