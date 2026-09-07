// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Experiments list (Settings → Developer → Experiments), shown as a
// Modal Pane: every non-private experiment from experiments.yaml with an
// on/off switch. Private experiments still toggle via the EXP command and
// join the list once that has enabled them. Loads the catalog itself
// (rather than taking it from the opener) so a pane opened before the
// catalog finished loading still fills in.

import 'package:flutter/material.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../config/experiments.dart';
import '../services/halo_services.dart';
class ExperimentsPane extends StatelessWidget {
  final HaLoServices services;

  const ExperimentsPane({super.key, required this.services});

  @override
  Widget build(BuildContext context) {
    final settings = services.settings;
    return FutureBuilder<List<ExperimentDefinition>>(
      future: loadExperiments(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: Space.xxl),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return ListenableBuilder(
          listenable: settings,
          builder: (context, _) {
            // Inside the listenable: an EXP flip of a private one adds it.
            final visible = [
              for (final d in snapshot.data!)
                if (!d.private || settings.experimentEverEnabled(d.key)) d,
            ];
            if (visible.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: Space.xxl),
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
                    // The availability pass may restart the extension
                    // runtime (an experiment revealing or hiding gated
                    // extensions); the switch itself flips immediately via
                    // the settings listenable.
                    onChanged: (enabled) async {
                      await settings.setExperimentEnabled(definition.key, enabled);
                      await services.extensions.applyExtensionAvailability();
                    },
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
