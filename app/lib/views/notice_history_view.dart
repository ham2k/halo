// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// About → Notices & Messages: every notice ever shown (active or
// dismissed), most-recent-first, as read-only post-it cards — the history
// view app-polo's NoticesSettingsScreen inspired. Status messages/progress
// bars aren't included; only notices are persisted (StatusBarService). This
// is a panel body (not its own Scaffold) — settings_view.dart's About panel
// opens it in a Modal Pane, which supplies the surrounding title/chrome.

import 'package:flutter/material.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../i18n/strings.g.dart';
import '../main.dart';

class NoticeHistoryView extends StatelessWidget {
  final HaLoServices services;

  const NoticeHistoryView({super.key, required this.services});

  @override
  Widget build(BuildContext context) {
    final history = services.statusBar.history;

    return history.isEmpty
        ? Center(child: Text(context.t.notices.emptyHistory))
        : ListView.separated(
            padding: const EdgeInsets.all(Space.lg),
            itemCount: history.length,
            separatorBuilder: (context, index) => const SizedBox(height: Space.md),
            itemBuilder: (context, index) {
              final notice = history[index];
              return NoticeCard(
                notice: StatusBarNoticeData(
                  key: notice.key,
                  icon: notice.icon,
                  title: notice.title,
                  text: notice.text,
                  createdAt: notice.createdAt,
                ),
              );
            },
          );
  }
}
