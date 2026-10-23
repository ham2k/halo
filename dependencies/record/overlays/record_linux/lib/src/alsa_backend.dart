// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'package:record_platform_interface/record_platform_interface.dart';

/// Only named hardware PCMs: numeric card indexes can change at reboot, and
/// plug/default/pulse devices can resample or manufacture a second channel.
bool isAlsaHardwareId(String id) => RegExp(
  r'^hw:CARD=[A-Za-z_][A-Za-z0-9_-]*,DEV=\d+(?:,SUBDEV=\d+)?$',
).hasMatch(id);

class AlsaSourceFormat {
  final bool hardware;
  final int channels;
  final int sampleRate;
  const AlsaSourceFormat({
    required this.hardware,
    required this.channels,
    required this.sampleRate,
  });
}

abstract interface class AlsaBackend {
  List<InputDevice> inputs();
  AlsaPcm open(String deviceId);
}

abstract interface class AlsaPcm {
  AlsaSourceFormat configure(int sampleRate);
  Uint8List? read();
  void close();
}

PlatformException alsaFailure(String reason, [String? details]) =>
    PlatformException(code: 'record', message: reason, details: details);

/// Opens once and closes every rejected source, including a driver returning
/// a format different from the exact hardware configuration requested.
AlsaPcm openAlsaIq(AlsaBackend backend, String deviceId, int sampleRate) {
  if (!isAlsaHardwareId(deviceId) ||
      !backend.inputs().any((input) => input.id == deviceId)) {
    throw alsaFailure('iq_audio_device_unavailable');
  }
  final pcm = backend.open(deviceId);
  try {
    final format = pcm.configure(sampleRate);
    if (!format.hardware || format.channels != 2) {
      throw alsaFailure('iq_audio_invalid_format');
    }
    if (format.sampleRate != sampleRate) {
      throw alsaFailure('iq_audio_sample_rate_mismatch');
    }
    return pcm;
  } catch (_) {
    pcm.close();
    rethrow;
  }
}

/// One bounded read per poll. Discontinuities stop the source rather than
/// joining samples across an overrun, unplug or driver reset in one FFT.
class AlsaIqSession {
  AlsaPcm? _pcm;
  final AlsaBackend backend;
  AlsaIqSession(this.backend);

  void start(String deviceId, int sampleRate) {
    if (_pcm != null) throw StateError('ALSA capture is already open');
    _pcm = openAlsaIq(backend, deviceId, sampleRate);
  }

  Uint8List? read() {
    try {
      return _pcm?.read();
    } catch (_) {
      stop();
      rethrow;
    }
  }

  void stop() {
    final pcm = _pcm;
    _pcm = null;
    pcm?.close();
  }
}

/// ALSA signed little-endian formats from include/pcm.h. Conversion discards
/// only low significance bits; channel order and the sampling clock survive.
Uint8List alsaPcm16(Uint8List source, int format) {
  if (format == 2) {
    // S16_LE
    if (source.length % 4 != 0) throw alsaFailure('iq_audio_invalid_format');
    return Uint8List.fromList(source);
  }
  final width = format == 32 ? 3 : 4; // S24_3LE, S24_LE, S32_LE
  final high = format == 10 ? 2 : 1;
  if (!const [6, 10, 32].contains(format) || source.length % (width * 2) != 0) {
    throw alsaFailure('iq_audio_invalid_format');
  }
  final output = Uint8List(source.length ~/ width * 2);
  for (var sample = 0; sample < output.length ~/ 2; sample++) {
    output[sample * 2] = source[sample * width + high];
    output[sample * 2 + 1] = source[sample * width + high + 1];
  }
  return output;
}

class NativeAlsaBackend implements AlsaBackend {
  final _Alsa _api;
  NativeAlsaBackend() : _api = _Alsa.open();

  @override
  List<InputDevice> inputs() {
    final result = <InputDevice>[];
    final card = calloc<Int32>()..value = -1;
    try {
      while (true) {
        _api.check(_api.nextCard(card));
        if (card.value < 0) break;
        final handle = calloc<Pointer<Void>>();
        final cardInfo = calloc<Pointer<Void>>();
        final pcmInfo = calloc<Pointer<Void>>();
        final device = calloc<Int32>()..value = -1;
        final name = 'hw:${card.value}'.toNativeUtf8();
        try {
          // Control inspection is read-only: it never starts microphone capture.
          _api.check(_api.openControl(handle, name, 5));
          _api.check(_api.allocCardInfo(cardInfo));
          _api.check(_api.cardInfo(handle.value, cardInfo.value));
          final cardId = _api.cardId(cardInfo.value).toDartString();
          final cardName = _api.cardName(cardInfo.value).toDartString();
          _api.check(_api.allocPcmInfo(pcmInfo));
          while (true) {
            _api.check(_api.nextDevice(handle.value, device));
            if (device.value < 0) break;
            _api.infoDevice(pcmInfo.value, device.value);
            _api.infoSubdevice(pcmInfo.value, 0);
            _api.infoStream(pcmInfo.value, 1); // Capture only.
            final status = _api.pcmInfo(handle.value, pcmInfo.value);
            if (status == -2) continue; // ENOENT: playback-only PCM.
            _api.check(status);
            final count = _api.subdeviceCount(pcmInfo.value);
            final pcmName = _api.pcmName(pcmInfo.value).toDartString();
            for (var sub = 0; sub < count; sub++) {
              final id = 'hw:CARD=$cardId,DEV=${device.value},SUBDEV=$sub';
              if (!isAlsaHardwareId(id)) continue;
              result.add(
                InputDevice(id: id, label: '$cardName — $pcmName ($id)'),
              );
            }
          }
        } finally {
          if (handle.value != nullptr) _api.closeControl(handle.value);
          if (cardInfo.value != nullptr) _api.freeCardInfo(cardInfo.value);
          if (pcmInfo.value != nullptr) _api.freePcmInfo(pcmInfo.value);
          calloc.free(handle);
          calloc.free(cardInfo);
          calloc.free(pcmInfo);
          calloc.free(device);
          calloc.free(name);
        }
      }
    } finally {
      calloc.free(card);
    }
    return result;
  }

  @override
  AlsaPcm open(String deviceId) {
    final result = calloc<Pointer<Void>>();
    final name = deviceId.toNativeUtf8();
    try {
      // Capture + nonblocking + no automatic rate/channel/format conversion.
      _api.check(_api.openPcm(result, name, 1, 0x00070001));
      return _NativeAlsaPcm(_api, result.value);
    } finally {
      calloc.free(result);
      calloc.free(name);
    }
  }
}

class _NativeAlsaPcm implements AlsaPcm {
  final _Alsa api;
  Pointer<Void> pcm;
  Pointer<Uint8> _buffer = nullptr;
  int _format = 2;
  static const framesPerRead = 4096;
  _NativeAlsaPcm(this.api, this.pcm);

  @override
  AlsaSourceFormat configure(int sampleRate) {
    if (api.pcmType(pcm) != 0) {
      throw alsaFailure(
        'iq_audio_invalid_format',
        'The selected PCM is not a hardware source',
      );
    }
    final params = calloc<Pointer<Void>>();
    final channels = calloc<Uint32>();
    final rate = calloc<Uint32>();
    final direction = calloc<Int32>();
    final bufferMicros = calloc<Uint32>()..value = 100000;
    try {
      api.check(api.allocParams(params));
      api.check(api.anyParams(pcm, params.value), 'iq_audio_invalid_format');
      api.check(api.setAccess(pcm, params.value, 3), 'iq_audio_invalid_format');
      api.check(
        api.setChannels(pcm, params.value, 2),
        'iq_audio_invalid_format',
      );
      api.check(
        api.setRate(pcm, params.value, sampleRate, 0),
        'iq_audio_sample_rate_mismatch',
      );
      final supported = [
        2,
        10,
        6,
        32,
      ].where((format) => api.testFormat(pcm, params.value, format) == 0);
      if (supported.isEmpty) {
        throw alsaFailure(
          'iq_audio_invalid_format',
          'The input has no supported signed PCM format',
        );
      }
      _format = supported.first;
      api.check(
        api.setFormat(pcm, params.value, _format),
        'iq_audio_invalid_format',
      );
      api.check(api.setBufferTime(pcm, params.value, bufferMicros, direction));
      api.check(api.applyParams(pcm, params.value));
      api.check(api.currentParams(pcm, params.value));
      api.check(
        api.getChannels(params.value, channels),
        'iq_audio_invalid_format',
      );
      api.check(
        api.getRate(params.value, rate, direction),
        'iq_audio_invalid_format',
      );
      if (direction.value != 0) {
        throw alsaFailure('iq_audio_sample_rate_mismatch');
      }
      api.check(api.prepare(pcm));
      _buffer = calloc<Uint8>(framesPerRead * 2 * 4);
      return AlsaSourceFormat(
        hardware: true,
        channels: channels.value,
        sampleRate: rate.value,
      );
    } finally {
      if (params.value != nullptr) api.freeParams(params.value);
      calloc.free(params);
      calloc.free(channels);
      calloc.free(rate);
      calloc.free(direction);
      calloc.free(bufferMicros);
    }
  }

  @override
  Uint8List? read() {
    final count = api.read(pcm, _buffer.cast(), framesPerRead);
    if (count == -11 || count == 0) return null; // EAGAIN: no samples yet.
    api.check(count);
    final width = _format == 2
        ? 2
        : _format == 32
        ? 3
        : 4;
    return alsaPcm16(_buffer.asTypedList(count * 2 * width), _format);
  }

  @override
  void close() {
    if (pcm == nullptr) return;
    api.closePcm(pcm);
    pcm = nullptr;
    if (_buffer != nullptr) calloc.free(_buffer);
    _buffer = nullptr;
  }
}

// ABI declarations only; libasound is loaded lazily on the capture isolate.
// No development headers, PulseAudio utilities or child executables are used.
class _Alsa {
  final DynamicLibrary library;
  _Alsa(this.library);
  factory _Alsa.open() {
    try {
      return _Alsa(DynamicLibrary.open('libasound.so.2'));
    } on ArgumentError catch (error) {
      throw alsaFailure(
        'iq_audio_unsupported',
        'Install the ALSA runtime library (libasound2): $error',
      );
    }
  }

  late final nextCard = library
      .lookupFunction<
        Int32 Function(Pointer<Int32>),
        int Function(Pointer<Int32>)
      >('snd_card_next');
  late final openControl = library
      .lookupFunction<
        Int32 Function(Pointer<Pointer<Void>>, Pointer<Utf8>, Int32),
        int Function(Pointer<Pointer<Void>>, Pointer<Utf8>, int)
      >('snd_ctl_open');
  late final closeControl = library
      .lookupFunction<
        Int32 Function(Pointer<Void>),
        int Function(Pointer<Void>)
      >('snd_ctl_close');
  late final allocCardInfo = library
      .lookupFunction<
        Int32 Function(Pointer<Pointer<Void>>),
        int Function(Pointer<Pointer<Void>>)
      >('snd_ctl_card_info_malloc');
  late final freeCardInfo = library
      .lookupFunction<
        Void Function(Pointer<Void>),
        void Function(Pointer<Void>)
      >('snd_ctl_card_info_free');
  late final cardInfo = library
      .lookupFunction<
        Int32 Function(Pointer<Void>, Pointer<Void>),
        int Function(Pointer<Void>, Pointer<Void>)
      >('snd_ctl_card_info');
  late final cardId = library
      .lookupFunction<
        Pointer<Utf8> Function(Pointer<Void>),
        Pointer<Utf8> Function(Pointer<Void>)
      >('snd_ctl_card_info_get_id');
  late final cardName = library
      .lookupFunction<
        Pointer<Utf8> Function(Pointer<Void>),
        Pointer<Utf8> Function(Pointer<Void>)
      >('snd_ctl_card_info_get_name');
  late final nextDevice = library
      .lookupFunction<
        Int32 Function(Pointer<Void>, Pointer<Int32>),
        int Function(Pointer<Void>, Pointer<Int32>)
      >('snd_ctl_pcm_next_device');
  late final allocPcmInfo = library
      .lookupFunction<
        Int32 Function(Pointer<Pointer<Void>>),
        int Function(Pointer<Pointer<Void>>)
      >('snd_pcm_info_malloc');
  late final freePcmInfo = library
      .lookupFunction<
        Void Function(Pointer<Void>),
        void Function(Pointer<Void>)
      >('snd_pcm_info_free');
  late final infoDevice = library
      .lookupFunction<
        Void Function(Pointer<Void>, Uint32),
        void Function(Pointer<Void>, int)
      >('snd_pcm_info_set_device');
  late final infoSubdevice = library
      .lookupFunction<
        Void Function(Pointer<Void>, Uint32),
        void Function(Pointer<Void>, int)
      >('snd_pcm_info_set_subdevice');
  late final infoStream = library
      .lookupFunction<
        Void Function(Pointer<Void>, Int32),
        void Function(Pointer<Void>, int)
      >('snd_pcm_info_set_stream');
  late final pcmInfo = library
      .lookupFunction<
        Int32 Function(Pointer<Void>, Pointer<Void>),
        int Function(Pointer<Void>, Pointer<Void>)
      >('snd_ctl_pcm_info');
  late final pcmName = library
      .lookupFunction<
        Pointer<Utf8> Function(Pointer<Void>),
        Pointer<Utf8> Function(Pointer<Void>)
      >('snd_pcm_info_get_name');
  late final subdeviceCount = library
      .lookupFunction<
        Uint32 Function(Pointer<Void>),
        int Function(Pointer<Void>)
      >('snd_pcm_info_get_subdevices_count');
  late final openPcm = library
      .lookupFunction<
        Int32 Function(Pointer<Pointer<Void>>, Pointer<Utf8>, Int32, Int32),
        int Function(Pointer<Pointer<Void>>, Pointer<Utf8>, int, int)
      >('snd_pcm_open');
  late final closePcm = library
      .lookupFunction<
        Int32 Function(Pointer<Void>),
        int Function(Pointer<Void>)
      >('snd_pcm_close');
  late final pcmType = library
      .lookupFunction<
        Int32 Function(Pointer<Void>),
        int Function(Pointer<Void>)
      >('snd_pcm_type');
  late final prepare = library
      .lookupFunction<
        Int32 Function(Pointer<Void>),
        int Function(Pointer<Void>)
      >('snd_pcm_prepare');
  late final allocParams = library
      .lookupFunction<
        Int32 Function(Pointer<Pointer<Void>>),
        int Function(Pointer<Pointer<Void>>)
      >('snd_pcm_hw_params_malloc');
  late final freeParams = library
      .lookupFunction<
        Void Function(Pointer<Void>),
        void Function(Pointer<Void>)
      >('snd_pcm_hw_params_free');
  late final anyParams = library
      .lookupFunction<
        Int32 Function(Pointer<Void>, Pointer<Void>),
        int Function(Pointer<Void>, Pointer<Void>)
      >('snd_pcm_hw_params_any');
  late final applyParams = library
      .lookupFunction<
        Int32 Function(Pointer<Void>, Pointer<Void>),
        int Function(Pointer<Void>, Pointer<Void>)
      >('snd_pcm_hw_params');
  late final currentParams = library
      .lookupFunction<
        Int32 Function(Pointer<Void>, Pointer<Void>),
        int Function(Pointer<Void>, Pointer<Void>)
      >('snd_pcm_hw_params_current');
  late final setAccess = library
      .lookupFunction<
        Int32 Function(Pointer<Void>, Pointer<Void>, Int32),
        int Function(Pointer<Void>, Pointer<Void>, int)
      >('snd_pcm_hw_params_set_access');
  late final setChannels = library
      .lookupFunction<
        Int32 Function(Pointer<Void>, Pointer<Void>, Uint32),
        int Function(Pointer<Void>, Pointer<Void>, int)
      >('snd_pcm_hw_params_set_channels');
  late final setFormat = library
      .lookupFunction<
        Int32 Function(Pointer<Void>, Pointer<Void>, Int32),
        int Function(Pointer<Void>, Pointer<Void>, int)
      >('snd_pcm_hw_params_set_format');
  late final testFormat = library
      .lookupFunction<
        Int32 Function(Pointer<Void>, Pointer<Void>, Int32),
        int Function(Pointer<Void>, Pointer<Void>, int)
      >('snd_pcm_hw_params_test_format');
  late final setRate = library
      .lookupFunction<
        Int32 Function(Pointer<Void>, Pointer<Void>, Uint32, Int32),
        int Function(Pointer<Void>, Pointer<Void>, int, int)
      >('snd_pcm_hw_params_set_rate');
  late final getChannels = library
      .lookupFunction<
        Int32 Function(Pointer<Void>, Pointer<Uint32>),
        int Function(Pointer<Void>, Pointer<Uint32>)
      >('snd_pcm_hw_params_get_channels');
  late final getRate = library
      .lookupFunction<
        Int32 Function(Pointer<Void>, Pointer<Uint32>, Pointer<Int32>),
        int Function(Pointer<Void>, Pointer<Uint32>, Pointer<Int32>)
      >('snd_pcm_hw_params_get_rate');
  late final setBufferTime = library
      .lookupFunction<
        Int32 Function(
          Pointer<Void>,
          Pointer<Void>,
          Pointer<Uint32>,
          Pointer<Int32>,
        ),
        int Function(
          Pointer<Void>,
          Pointer<Void>,
          Pointer<Uint32>,
          Pointer<Int32>,
        )
      >('snd_pcm_hw_params_set_buffer_time_near');
  late final read = library
      .lookupFunction<
        Long Function(Pointer<Void>, Pointer<Void>, UnsignedLong),
        int Function(Pointer<Void>, Pointer<Void>, int)
      >('snd_pcm_readi');
  late final strerror = library
      .lookupFunction<
        Pointer<Utf8> Function(Int32),
        Pointer<Utf8> Function(int)
      >('snd_strerror');

  void check(int status, [String reason = 'iq_audio_device_unavailable']) {
    if (status >= 0) return;
    if (status == -13 || status == -1) reason = 'iq_audio_permission_denied';
    throw alsaFailure(reason, strerror(status).toDartString());
  }
}
