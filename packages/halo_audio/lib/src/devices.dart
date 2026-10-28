// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

/// A sound device as the system lists it. [id] is miniaudio's per-backend
/// identifier written as hex; it survives a reboot on CoreAudio and WASAPI
/// but not on every Linux backend, which is why [matchAudioDevice] falls
/// back to [name].
class AudioDevice {
  const AudioDevice({required this.id, required this.name, this.isDefault = false});

  final String id;
  final String name;
  final bool isDefault;

  @override
  bool operator ==(Object other) => other is AudioDevice && other.id == id && other.name == name && other.isDefault == isDefault;

  @override
  int get hashCode => Object.hash(id, name, isDefault);

  @override
  String toString() => 'AudioDevice($name${isDefault ? ', default' : ''})';
}

/// The device among [devices] that a stored [id] and [name] name: the id
/// when it is still listed, otherwise the one device with that name. Null
/// when neither finds it, or when the name alone is ambiguous — two
/// identical sound cards on one station are the one case a name cannot
/// settle, and guessing between them could key audio into the wrong radio.
AudioDevice? matchAudioDevice(List<AudioDevice> devices, {String? id, String? name}) {
  if (id != null && id.isNotEmpty) {
    for (final d in devices) {
      if (d.id == id) return d;
    }
  }
  if (name == null || name.isEmpty) return null;
  final named = devices.where((d) => d.name == name).toList();
  return named.length == 1 ? named.single : null;
}

class HaloAudioException implements Exception {
  HaloAudioException(this.message);
  final String message;

  @override
  String toString() => 'HaloAudioException: $message';
}

/// How [HaloAudio.normalize] finds the sound in a recording to trim it to:
/// the 10 ms stretches whose RMS is [aboveFloorDb] above the recording's
/// noise floor (its quietest tenth) — or within [belowLoudestDb] of its
/// loudest stretch, when that is the lower bar, so a recording with little
/// room in it keeps its soft speech — in runs of at least [minSound], so a
/// click is not sound — with [lead] kept before the first and [tail] after
/// the last, faded in and out. The last [cutEnd] goes first, unmeasured.
class AudioTrim {
  final double aboveFloorDb;
  final double belowLoudestDb;
  final Duration minSound;
  final Duration lead;
  final Duration tail;
  final Duration cutEnd;

  const AudioTrim({
    required this.aboveFloorDb,
    required this.belowLoudestDb,
    required this.minSound,
    required this.lead,
    required this.tail,
    this.cutEnd = Duration.zero,
  });
}
