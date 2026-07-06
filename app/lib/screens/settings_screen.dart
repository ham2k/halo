// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// App-wide settings: appearance, QRZ.com credentials, and about/version —
// a small, single-screen start (no app-polo-style nested settings stack;
// there's nowhere near enough settings yet to need one).

import 'package:flutter/material.dart';
import 'package:polo_widgets/polo_widgets.dart';

import '../main.dart';

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
    final usernameController = TextEditingController(text: settings.qrzUsername);
    final passwordController = TextEditingController(text: settings.qrzPassword);

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('QRZ.com credentials'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: usernameController,
              autofocus: true,
              decoration: poloFieldDecoration(context, 'Username'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: poloFieldDecoration(context, 'Password'),
              onSubmitted: (_) => Navigator.of(context).pop(true),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Save')),
        ],
      ),
    );

    if (saved != true) return;
    await settings.setQrzCredentials(username: usernameController.text.trim(), password: passwordController.text);
    await widget.services.extensions.setQrzCredentials(
      username: usernameController.text.trim(),
      password: passwordController.text,
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.services.settings;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: isMacOSChromelessWindow ? 56 + macOSTrafficLightInset : null,
        leading: isMacOSChromelessWindow
            ? const Padding(
                padding: EdgeInsets.only(left: macOSTrafficLightInset),
                child: BackButton(),
              )
            : null,
        title: const Text('Settings'),
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
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('PoLo Next'),
            subtitle: Text('Version $_appVersion (dev build)'),
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
