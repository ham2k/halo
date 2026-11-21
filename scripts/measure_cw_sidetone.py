#!/usr/bin/env python3
# SPDX-License-Identifier: MPL-2.0
"""Measure paddle-to-sidetone latency from a common-clock stereo PCM WAV.

Record isolated paddle presses spaced farther apart than --window-ms. Start
with both channels quiet. Feed an isolated, audio-safe contact reference to the
left channel and the headphone signal or a microphone at the listening
position to the right. Record both through the same interface. Disable
automatic gain, noise suppression and other per-channel processing. Calibrate
channel skew with a shared reference signal before measuring, and save the
capture settings and thresholds with the result.

A contact onset is the selected-polarity threshold crossing after 3 ms below
half threshold. A tone onset is the first threshold crossing of a burst that
alternates polarity at roughly --pitch-hz for at least one period.
The measured onset includes the effect of the tone ramp, phase and threshold.
"""

import argparse
import io
import math
import struct
import sys
import unittest
import wave


def pcm_frames(recording):
    width = recording.getsampwidth()
    remaining = recording.getnframes()
    while remaining:
        count = min(remaining, 8192)
        data = recording.readframes(count)
        if len(data) != count * width * 2:
            raise ValueError("truncated WAV sample data")
        remaining -= count
        if width == 3:
            for offset in range(0, len(data), 6):
                yield (
                    int.from_bytes(data[offset : offset + 3], "little", signed=True),
                    int.from_bytes(data[offset + 3 : offset + 6], "little", signed=True),
                )
        else:
            yield from struct.iter_unpack({1: "BB", 2: "<hh", 4: "<ii"}[width], data)


def detect_onsets(recording, pitch_hz, contact_threshold, tone_threshold, polarity):
    if recording.getnchannels() != 2 or recording.getcomptype() != "NONE":
        raise ValueError("expected a two-channel uncompressed PCM WAV")
    width = recording.getsampwidth()
    if width not in (1, 2, 3, 4):
        raise ValueError("expected 8-, 16-, 24- or 32-bit integer PCM samples")

    rate = recording.getframerate()
    full_scale = 1 << (width * 8 - 1)
    center = 128 if width == 1 else 0
    contact_level = contact_threshold * full_scale
    tone_level = tone_threshold * full_scale
    contact_rearm = math.ceil(0.003 * rate)
    tone_period = math.ceil(rate / pitch_hz)
    if tone_period < 4:
        raise ValueError("sample rate must be at least four times the sidetone pitch")

    contacts, tones = [], []
    below_contact = 0
    contact_armed = False
    start = last_peak = -2 * tone_period - 1
    last_crossing = start
    last_sign = alternations = 0
    tone_confirmed = False

    for frame, (left, right) in enumerate(pcm_frames(recording)):
        ref = (left - center) * polarity
        if ref < contact_level / 2:
            below_contact += 1
            if below_contact >= contact_rearm:
                contact_armed = True
        else:
            below_contact = 0
            if contact_armed and ref >= contact_level:
                contacts.append(frame)
                contact_armed = False

        sample = right - center
        if abs(sample) < tone_level:
            continue
        if frame - last_peak > 2 * tone_period:
            last_sign = alternations = 0
            tone_confirmed = False
        last_peak = frame
        if tone_confirmed:
            continue
        sign = 1 if sample > 0 else -1
        if sign != last_sign:
            gap = frame - last_crossing
            if last_sign and 0.25 * tone_period <= gap <= 0.90 * tone_period:
                alternations += 1
            else:
                start = frame
                alternations = 0
            last_crossing = frame
            last_sign = sign
        if alternations >= 2 and frame - start >= tone_period:
            tones.append(start)
            tone_confirmed = True

    return contacts, tones


def match_trials(contacts, tones, window_frames):
    """Pair one tone per contact window. Preserve misses and unexpected tones."""
    latencies = []
    missing = extra = ambiguous = tone_index = 0
    for index, contact in enumerate(contacts):
        while tone_index < len(tones) and tones[tone_index] < contact:
            extra += 1
            tone_index += 1

        next_contact = contacts[index + 1] if index + 1 < len(contacts) else math.inf
        end = contact + window_frames
        first = tone_index
        while tone_index < len(tones) and tones[tone_index] <= end and tones[tone_index] < next_contact:
            tone_index += 1

        candidates = tone_index - first
        if next_contact <= end or candidates > 1:
            ambiguous += 1
            extra += candidates
        elif candidates == 0:
            missing += 1
        else:
            latencies.append(tones[first] - contact)

    return latencies, missing, extra + len(tones) - tone_index, ambiguous


def percentile(ordered, quantile):
    return ordered[math.ceil(quantile * len(ordered)) - 1]


def positive(value):
    number = float(value)
    if not math.isfinite(number) or number <= 0:
        raise argparse.ArgumentTypeError("must be a finite positive number")
    return number


def threshold(value):
    number = positive(value)
    if number > 1:
        raise argparse.ArgumentTypeError("must be at most 1.0 (full scale)")
    return number


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("wav", nargs="?", help="stereo PCM WAV to analyze")
    parser.add_argument("--pitch-hz", type=positive, default=600, help="approximate recorded sidetone pitch (default 600)")
    parser.add_argument("--contact-threshold", type=threshold, default=0.15, help="left-channel fraction of full scale (default 0.15)")
    parser.add_argument("--tone-threshold", type=threshold, default=0.02, help="right-channel fraction of full scale (default 0.02)")
    parser.add_argument("--contact-polarity", choices=("positive", "negative"), default="positive", help="direction from zero of the contact edge")
    parser.add_argument("--window-ms", type=positive, default=80, help="maximum contact-to-tone pairing window in ms (default 80)")
    parser.add_argument("--min-trials", type=int, default=100, help="minimum number of isolated presses (default 100)")
    parser.add_argument("--p95-ms", type=positive, default=10, help="maximum p95 latency in ms (default 10)")
    parser.add_argument("--p99-ms", type=positive, default=15, help="maximum p99 latency in ms (default 15)")
    parser.add_argument("--self-test", action="store_true", help="run synthetic PCM capture checks and exit")
    args = parser.parse_args()

    if args.self_test:
        return 0 if unittest.TextTestRunner().run(unittest.defaultTestLoader.loadTestsFromTestCase(SyntheticCaptures)).wasSuccessful() else 1
    if args.wav is None:
        parser.error("provide a stereo WAV or --self-test")
    if args.min_trials < 1:
        parser.error("--min-trials must be positive")
    if args.window_ms < max(args.p95_ms, args.p99_ms):
        parser.error("--window-ms must cover both percentile limits")

    try:
        with wave.open(args.wav, "rb") as recording:
            rate = recording.getframerate()
            polarity = 1 if args.contact_polarity == "positive" else -1
            contacts, tones = detect_onsets(recording, args.pitch_hz, args.contact_threshold, args.tone_threshold, polarity)
    except (OSError, EOFError, ValueError, wave.Error) as error:
        parser.error(str(error))

    frames, missing, extra, ambiguous = match_trials(contacts, tones, round(args.window_ms * rate / 1000))
    ordered = sorted(frame * 1000 / rate for frame in frames)
    print(f"{rate} Hz capture, {args.pitch_hz:g} Hz tone, {args.contact_polarity} contact, {args.window_ms:g} ms pairing window")
    print(f"Thresholds (full scale): contact {args.contact_threshold:g}, tone {args.tone_threshold:g}")
    print(f"Trials {len(contacts)}, matched {len(ordered)}, missing {missing}, extra tones {extra}, ambiguous {ambiguous}")
    within_budget = False
    if ordered:
        p50, p95, p99 = (percentile(ordered, quantile) for quantile in (0.50, 0.95, 0.99))
        print(f"Paddle to tone (ms): p50 {p50:.3f}, p95 {p95:.3f}, p99 {p99:.3f}, worst {ordered[-1]:.3f}")
        within_budget = p95 <= args.p95_ms and p99 <= args.p99_ms
    passed = len(contacts) >= args.min_trials and not (missing or extra or ambiguous) and within_budget
    print(f"{'PASS' if passed else 'FAIL'} (requires ≥{args.min_trials} trials, p95 ≤ {args.p95_ms:g} ms, p99 ≤ {args.p99_ms:g} ms, and unique matches)")
    return 0 if passed else 1


class SyntheticCaptures(unittest.TestCase):
    rate = 48000
    pitch = 600

    def measure(self, contacts_ms, tones_ms, click_ms=None, polarity=1):
        buffer = io.BytesIO()
        end_ms = max(contacts_ms + tones_ms) + 60
        frames = bytearray(end_ms * 48 * 4)
        for start in contacts_ms:
            for frame in range(start * 48, (start + 8) * 48):
                struct.pack_into("<h", frames, frame * 4, polarity * 12000)
        for start in tones_ms:
            for frame in range(30 * 48):
                sample = int(6000 * math.sin(2 * math.pi * self.pitch * frame / self.rate))
                struct.pack_into("<h", frames, (start * 48 + frame) * 4 + 2, sample)
        if click_ms is not None:
            struct.pack_into("<h", frames, click_ms * 48 * 4 + 2, 18000)
        with wave.open(buffer, "wb") as writer:
            writer.setparams((2, 2, self.rate, 0, "NONE", "not compressed"))
            writer.writeframes(frames)
        buffer.seek(0)
        with wave.open(buffer, "rb") as recording:
            contacts, tones = detect_onsets(recording, self.pitch, 0.15, 0.02, polarity)
        return match_trials(contacts, tones, 80 * 48)

    def test_matches_8_and_12_ms_onsets_with_inverted_contact(self):
        frames, missing, extra, ambiguous = self.measure([20, 200], [28, 212], click_ms=23, polarity=-1)
        self.assertEqual((missing, extra, ambiguous), (0, 0, 0))
        self.assertEqual(len(frames), 2)
        for actual, expected in zip(frames, (8, 12)):
            self.assertAlmostEqual(actual * 1000 / self.rate, expected, delta=0.1)

    def test_late_and_unrelated_tones_do_not_hide_missing_trials(self):
        frames, missing, extra, ambiguous = self.measure([60, 200], [10, 68, 300])
        self.assertEqual(len(frames), 1)
        self.assertEqual((missing, extra, ambiguous), (1, 2, 0))

    def test_multiple_tones_inside_one_window_are_ambiguous(self):
        frames, missing, extra, ambiguous = self.measure([30], [38, 75])
        self.assertEqual(frames, [])
        self.assertEqual((missing, extra, ambiguous), (0, 2, 1))


if __name__ == "__main__":
    sys.exit(main())
