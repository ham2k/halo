// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Settings → About → Recent Notices: every notice ever shown (active or
// dismissed), most-recent-first, as read-only post-it cards — the history
// view app-polo's NoticesSettingsScreen inspired. Status messages/progress
// bars aren't included; only notices are persisted (StatusBarService).

import 'package:flutter/material.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../main.dart';

class NoticeHistoryView extends StatelessWidget {
  final HaLoServices services;

  const NoticeHistoryView({super.key, required this.services});

  @override
  Widget build(BuildContext context) {
    final history = services.statusBar.history;

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: windowHeaderGestureArea(),
        leadingWidth: macOSAwareLeadingWidth(context),
        leading: macOSAwareBackButton(context),
        title: const Text('Recent Notices'),
        actions: [windowsCaptionSpacer(context)],
      ),
      body: history.isEmpty
          ? const Center(child: Text('No notices yet'))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: history.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
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
            ),
    );
  }
}
