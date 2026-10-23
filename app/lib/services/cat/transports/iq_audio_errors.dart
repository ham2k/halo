// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:halo_i18n/halo_i18n.dart';

import 'iq_audio_types.dart';

String iqAudioProblemFor(Object error) => switch (error) {
  IqAudioException(reason: IqAudioFailure.permissionDenied) => t.settings.station.kx3IqPermissionDenied,
  IqAudioException(reason: IqAudioFailure.deviceUnavailable) => t.settings.station.kx3IqDeviceUnavailable,
  IqAudioException(reason: IqAudioFailure.unsupported) => t.settings.station.kx3IqUnsupported,
  IqAudioException(reason: IqAudioFailure.invalidFormat) => t.settings.station.kx3IqInvalidFormat,
  IqAudioException(reason: IqAudioFailure.sampleRateMismatch) => t.settings.station.kx3IqSampleRateMismatch,
  _ => t.settings.station.kx3IqFailed,
};
