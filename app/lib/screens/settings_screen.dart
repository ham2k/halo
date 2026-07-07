// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// App-wide settings: appearance, QRZ.com credentials, and about/version —
// a small, single-screen start (no app-polo-style nested settings stack;
// there's nowhere near enough settings yet to need one).

import 'package:flutter/material.dart';
import 'package:polo_widgets/polo_widgets.dart';

import '../main.dart';
import 'operation_dialogs.dart';

const _appVersion = '0.1.0'; // keep in sync with app/pubspec.yaml

class SettingsScreen extends StatefulWidget {
  final PoloServices services;

  const SettingsScreen({super.key, required this.services});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<void> _editQrzCredentials() async {
    final settings = widget.services.settings;
    final result = await editTwoFieldDialog(
      context,
      title: 'QRZ.com credentials',
      field1Label: 'Username',
      field1Initial: settings.qrzUsername,
      field2Label: 'Password',
      field2Initial: settings.qrzPassword,
      field2Obscure: true,
    );
    if (result == null) return;

    await widget.services.setQrzCredentials(username: result.$1.trim(), password: result.$2);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.services.settings;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: isMacOSChromelessWindow ? 56 + macOSTrafficLightInset + macOSTrafficLightGap : null,
        leading: isMacOSChromelessWindow
            ? const Padding(
                padding: EdgeInsets.only(left: macOSTrafficLightInset + macOSTrafficLightGap),
                child: BackButton(),
              )
            : null,
        title: const Text('Settings'),
        actions: const [SizedBox(width: 16)],
      ),
      body: ListView(
        children: [
          const _SectionHeader('Appearance'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto_outlined),
                  label: Text('System'),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_outlined),
                  label: Text('Light'),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_outlined),
                  label: Text('Dark'),
                ),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (selection) => settings.setThemeMode(selection.first),
            ),
          ),
          const _SectionHeader('Accounts & services'),
          ListTile(
            leading: Icon(MdiIcons.keyChain),
            title: const Text('QRZ.com credentials'),
            subtitle: Text(settings.hasQrzCredentials ? settings.qrzUsername : 'Not configured'),
            onTap: _editQrzCredentials,
          ),
          const _SectionHeader('About'),
          ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset('assets/images/ham2k-icon.png', width: 40, height: 40),
            ),
            title: const Text('PoLo Next'),
            subtitle: const Text('Version $_appVersion (dev build)'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
    );
  }
}
