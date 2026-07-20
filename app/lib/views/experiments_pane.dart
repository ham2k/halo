// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Experiments list (Settings → Developer → Experiments), shown as a
// Modal Pane: every non-hidden experiment from experiments.yaml with an
// on/off switch. Hidden experiments still toggle via the EXP command;
// they're just not listed here. Loads the catalog itself (rather than
// taking it from the opener) so a pane opened before the catalog finished
// loading still fills in.

import 'package:flutter/material.dart';

import '../config/experiments.dart';
import '../services/settings_service.dart';

class ExperimentsPane extends StatelessWidget {
  final SettingsService settings;

  const ExperimentsPane({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ExperimentDefinition>>(
      future: loadExperiments(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final visible = [for (final d in snapshot.data!) if (!d.hidden) d];
        return ListenableBuilder(
          listenable: settings,
          builder: (context, _) {
            if (visible.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('No experiments available in this build.'),
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final definition in visible)
                  SwitchListTile(
                    title: Text(definition.name),
                    subtitle: definition.description == null ? null : Text(definition.description!),
                    value: settings.experimentEnabled(definition.key),
                    onChanged: (enabled) => settings.setExperimentEnabled(definition.key, enabled),
                    contentPadding: EdgeInsets.zero,
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
