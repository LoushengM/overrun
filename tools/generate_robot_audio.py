#!/usr/bin/env python3
"""Generate Overrun's cohesive robot-themed sound pack.

The generator uses only Python's standard library and produces deterministic
44.1 kHz mono 16-bit PCM WAV files. The palette is intentionally synthetic:
short servo ticks and clean digital tones for UI, cyan-energy sweeps for player
weapons, red/noisy oscillators for enemy fire, and low metallic impacts for
bosses. Regenerate with:

    python3 tools/generate_robot_audio.py
"""
from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path
from typing import Iterable

SR = 44_100
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "audio"
TAU = math.tau


def seconds(value: float) -> int:
    return max(1, int(round(value * SR)))


def silence(duration: float) -> list[float]:
    return [0.0] * seconds(duration)


def osc(
    duration: float,
    f0: float,
    f1: float | None = None,
    *,
    wave_shape: str = "sine",
    phase: float = 0.0,
    vibrato_hz: float = 0.0,
    vibrato_depth: float = 0.0,
) -> list[float]:
    count = seconds(duration)
    f1 = f0 if f1 is None else f1
    result: list[float] = [0.0] * count
    current_phase = phase
    for i in range(count):
        t = i / max(1, count - 1)
        frequency = f0 + (f1 - f0) * t
        if vibrato_hz > 0.0 and vibrato_depth > 0.0:
            frequency *= 1.0 + math.sin(TAU * vibrato_hz * i / SR) * vibrato_depth
        current_phase += TAU * frequency / SR
        wrapped = (current_phase / TAU) % 1.0
        if wave_shape == "triangle":
            value = 1.0 - 4.0 * abs(wrapped - 0.5)
        elif wave_shape == "square":
            value = 1.0 if wrapped < 0.5 else -1.0
        elif wave_shape == "saw":
            value = 2.0 * wrapped - 1.0
        else:
            value = math.sin(current_phase)
        result[i] = value
    return result


def noise(duration: float, seed: int, *, smooth: float = 0.0) -> list[float]:
    rng = random.Random(seed)
    result: list[float] = [0.0] * seconds(duration)
    previous = 0.0
    smooth = max(0.0, min(0.999, smooth))
    for i in range(len(result)):
        raw = rng.uniform(-1.0, 1.0)
        previous = previous * smooth + raw * (1.0 - smooth)
        result[i] = previous
    return result


def shaped(
    signal: list[float],
    *,
    attack: float = 0.005,
    release: float = 0.04,
    decay: float = 2.0,
    sustain: float = 0.0,
) -> list[float]:
    count = len(signal)
    attack_samples = max(1, seconds(attack))
    release_samples = max(1, seconds(release))
    output = [0.0] * count
    for i, sample in enumerate(signal):
        progress = i / max(1, count - 1)
        attack_gain = min(1.0, i / attack_samples)
        release_gain = min(1.0, (count - 1 - i) / release_samples)
        decay_gain = sustain + (1.0 - sustain) * math.exp(-decay * progress)
        output[i] = sample * attack_gain * release_gain * decay_gain
    return output


def gain(signal: list[float], amount: float) -> list[float]:
    return [sample * amount for sample in signal]


def lowpass(signal: list[float], cutoff: float) -> list[float]:
    alpha = 1.0 - math.exp(-TAU * cutoff / SR)
    previous = 0.0
    output: list[float] = [0.0] * len(signal)
    for i, sample in enumerate(signal):
        previous += alpha * (sample - previous)
        output[i] = previous
    return output


def highpass(signal: list[float], cutoff: float) -> list[float]:
    low = lowpass(signal, cutoff)
    return [sample - low_sample for sample, low_sample in zip(signal, low)]


def distort(signal: list[float], drive: float = 2.0) -> list[float]:
    normalizer = math.tanh(drive)
    return [math.tanh(sample * drive) / normalizer for sample in signal]


def echo(signal: list[float], delay: float, amount: float, repeats: int = 2) -> list[float]:
    delay_samples = seconds(delay)
    output = signal[:] + [0.0] * (delay_samples * repeats)
    for repeat in range(1, repeats + 1):
        offset = delay_samples * repeat
        repeat_gain = amount**repeat
        for i, sample in enumerate(signal):
            output[i + offset] += sample * repeat_gain
    return output


def mix(duration: float, tracks: Iterable[tuple[list[float], float, float]]) -> list[float]:
    output = silence(duration)
    for signal, amount, offset_seconds in tracks:
        offset = max(0, seconds(offset_seconds))
        for i, sample in enumerate(signal):
            target = i + offset
            if target >= len(output):
                break
            output[target] += sample * amount
    return output


def normalize(signal: list[float], peak: float = 0.88) -> list[float]:
    maximum = max((abs(sample) for sample in signal), default=0.0)
    if maximum <= 1e-9:
        return signal
    scale = peak / maximum
    return [max(-1.0, min(1.0, sample * scale)) for sample in signal]


def tone(
    duration: float,
    f0: float,
    f1: float | None = None,
    *,
    wave_shape: str = "sine",
    attack: float = 0.004,
    release: float = 0.04,
    decay: float = 3.0,
    sustain: float = 0.0,
    vibrato_hz: float = 0.0,
    vibrato_depth: float = 0.0,
) -> list[float]:
    return shaped(
        osc(
            duration,
            f0,
            f1,
            wave_shape=wave_shape,
            vibrato_hz=vibrato_hz,
            vibrato_depth=vibrato_depth,
        ),
        attack=attack,
        release=release,
        decay=decay,
        sustain=sustain,
    )


def burst(duration: float, seed: int, *, cutoff: float = 2800.0, decay: float = 5.0) -> list[float]:
    return shaped(lowpass(noise(duration, seed), cutoff), attack=0.001, release=0.04, decay=decay)


def write(
    name: str,
    signal: list[float],
    *,
    dark_cutoff: float | None = None,
    dark_passes: int = 0,
) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / f"{name}.wav"
    final = signal
    if dark_cutoff is not None:
        for _ in range(max(1, dark_passes)):
            final = lowpass(final, dark_cutoff)
    final = normalize(final)
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(SR)
        frames = bytearray()
        for sample in final:
            frames.extend(struct.pack("<h", int(round(sample * 32767.0))))
        handle.writeframes(frames)
    print(f"{name:<22} {len(final) / SR:5.2f}s  {path.relative_to(ROOT)}")


def chord(notes: list[float], duration: float, *, decay: float = 2.5) -> list[float]:
    return mix(duration, [(tone(duration, note, note * 1.01, wave_shape="triangle", decay=decay), 1.0 / len(notes), 0.0) for note in notes])


def arpeggio(notes: list[float], step: float, tail: float = 0.12) -> list[float]:
    duration = step * len(notes) + tail
    tracks = []
    for index, note in enumerate(notes):
        tracks.append((tone(step + tail, note, note * 1.025, wave_shape="triangle", decay=3.0), 0.72, index * step))
    return echo(mix(duration, tracks), 0.07, 0.22, 1)[: seconds(duration)]


def generate() -> None:
    # Player weapons: clean cyan-energy sweeps with a shared metallic transient.
    write("needle_fire", mix(0.18, [
        (tone(0.15, 1900, 520, wave_shape="saw", decay=5.5), 0.54, 0.0),
        (tone(0.11, 980, 420, wave_shape="triangle", decay=5.0), 0.42, 0.0),
        (highpass(burst(0.055, 11, cutoff=5200, decay=8.0), 900), 0.38, 0.0),
    ]), dark_cutoff=1450.0, dark_passes=3)
    write("longshot_fire", mix(0.58, [
        (tone(0.52, 620, 95, wave_shape="saw", decay=2.8), 0.58, 0.0),
        (tone(0.38, 2100, 440, wave_shape="triangle", decay=3.5), 0.38, 0.015),
        (lowpass(burst(0.18, 12, cutoff=1100, decay=4.0), 900), 0.50, 0.0),
    ]), dark_cutoff=1700.0, dark_passes=2)
    write("aura_pulse", echo(mix(0.52, [
        (tone(0.48, 115, 58, wave_shape="sine", decay=1.8), 0.72, 0.0),
        (tone(0.34, 420, 1020, wave_shape="triangle", decay=2.0), 0.36, 0.025),
        (burst(0.20, 13, cutoff=1700, decay=3.0), 0.20, 0.0),
    ]), 0.095, 0.18, 1)[: seconds(0.62)])
    write("mire_deploy", mix(0.46, [
        (tone(0.38, 210, 72, wave_shape="triangle", decay=4.0), 0.62, 0.0),
        (tone(0.25, 720, 290, wave_shape="square", decay=5.0), 0.18, 0.03),
        (lowpass(burst(0.31, 14, cutoff=850, decay=4.5), 700), 0.46, 0.0),
    ]))
    write("chain_arc", mix(0.32, [
        (distort(tone(0.28, 1450, 430, wave_shape="square", decay=4.0, vibrato_hz=31, vibrato_depth=0.12), 1.6), 0.48, 0.0),
        (highpass(burst(0.24, 15, cutoff=6400, decay=3.0), 1200), 0.62, 0.0),
        (tone(0.20, 340, 125, wave_shape="triangle", decay=5.0), 0.30, 0.02),
    ]), dark_cutoff=1550.0, dark_passes=3)
    write("flak_fire", mix(0.28, [
        (lowpass(burst(0.24, 16, cutoff=1800, decay=5.5), 1300), 0.78, 0.0),
        (tone(0.19, 240, 78, wave_shape="triangle", decay=5.0), 0.56, 0.0),
        (highpass(burst(0.06, 17, cutoff=7000, decay=8.0), 1800), 0.24, 0.0),
    ]))
    write("orbital_contact", mix(0.18, [
        (tone(0.15, 840, 310, wave_shape="triangle", decay=6.0), 0.56, 0.0),
        (tone(0.10, 1680, 620, wave_shape="sine", decay=7.0), 0.25, 0.0),
        (burst(0.075, 18, cutoff=2200, decay=8.0), 0.28, 0.0),
    ]))
    write("detonator_launch", mix(0.38, [
        (tone(0.32, 165, 58, wave_shape="triangle", decay=4.0), 0.72, 0.0),
        (lowpass(burst(0.28, 19, cutoff=800, decay=5.0), 600), 0.62, 0.0),
        (tone(0.18, 540, 250, wave_shape="square", decay=6.0), 0.16, 0.025),
    ]))
    write("detonator_blast", mix(0.82, [
        (tone(0.72, 96, 38, wave_shape="sine", decay=2.6), 0.92, 0.0),
        (lowpass(burst(0.78, 20, cutoff=1050, decay=2.7), 920), 0.82, 0.0),
        (highpass(burst(0.18, 21, cutoff=5400, decay=7.0), 1100), 0.24, 0.0),
        (tone(0.42, 430, 110, wave_shape="saw", decay=4.5), 0.20, 0.015),
    ]))

    # Enemy and impact language: rougher red-spectrum oscillators and metal noise.
    write("enemy_ranged_fire", mix(0.27, [
        (distort(tone(0.23, 760, 230, wave_shape="square", decay=4.5), 1.8), 0.48, 0.0),
        (highpass(burst(0.12, 30, cutoff=4800, decay=6.0), 800), 0.38, 0.0),
        (tone(0.18, 190, 105, wave_shape="triangle", decay=5.0), 0.30, 0.02),
    ]), dark_cutoff=1500.0, dark_passes=3)
    write("enemy_hit", mix(0.15, [
        (highpass(burst(0.12, 31, cutoff=3600, decay=7.0), 650), 0.60, 0.0),
        (tone(0.12, 520, 210, wave_shape="triangle", decay=7.0), 0.40, 0.0),
    ]), dark_cutoff=1350.0, dark_passes=3)
    write("enemy_destroy", mix(0.34, [
        (lowpass(burst(0.30, 32, cutoff=1400, decay=4.5), 1100), 0.70, 0.0),
        (tone(0.28, 390, 78, wave_shape="saw", decay=4.5), 0.44, 0.0),
        (tone(0.19, 960, 210, wave_shape="triangle", decay=7.0), 0.22, 0.025),
    ]), dark_cutoff=1500.0, dark_passes=2)
    write("boss_hit", mix(0.28, [
        (lowpass(burst(0.24, 33, cutoff=1500, decay=5.0), 1150), 0.74, 0.0),
        (tone(0.22, 245, 72, wave_shape="triangle", decay=5.5), 0.66, 0.0),
        (highpass(burst(0.07, 34, cutoff=6000, decay=8.0), 1300), 0.22, 0.0),
    ]))
    write("player_hit", mix(0.43, [
        (lowpass(burst(0.34, 35, cutoff=1700, decay=4.0), 1300), 0.70, 0.0),
        (tone(0.34, 310, 92, wave_shape="saw", decay=4.0), 0.50, 0.0),
        (tone(0.22, 1120, 640, wave_shape="square", decay=5.5), 0.18, 0.015),
    ]))
    write("last_stand", mix(0.78, [
        (arpeggio([220, 330, 440, 660], 0.11, 0.18), 0.75, 0.0),
        (tone(0.72, 74, 150, wave_shape="sine", decay=1.6, sustain=0.22), 0.54, 0.0),
        (burst(0.26, 36, cutoff=2200, decay=3.0), 0.18, 0.04),
    ]))

    # Boss events: long low-frequency machinery, alarms, and core-collapse tails.
    write("boss_spawn", mix(1.22, [
        (tone(1.16, 46, 84, wave_shape="sine", decay=1.0, sustain=0.35, vibrato_hz=4.0, vibrato_depth=0.035), 0.82, 0.0),
        (lowpass(burst(1.05, 40, cutoff=520, decay=1.4), 430), 0.68, 0.0),
        (tone(0.72, 170, 410, wave_shape="saw", decay=1.6), 0.22, 0.30),
        (tone(0.18, 840, 420, wave_shape="triangle", decay=6.0), 0.18, 0.86),
    ]))
    write("boss_telegraph", mix(0.78, [
        (tone(0.24, 330, 330, wave_shape="square", decay=2.2), 0.34, 0.0),
        (tone(0.24, 247, 247, wave_shape="square", decay=2.2), 0.34, 0.27),
        (tone(0.62, 62, 72, wave_shape="sine", decay=1.4, sustain=0.20), 0.50, 0.0),
        (burst(0.16, 41, cutoff=1800, decay=5.0), 0.22, 0.52),
    ]))
    write("boss_slam", mix(0.86, [
        (tone(0.78, 78, 30, wave_shape="sine", decay=2.2), 0.98, 0.0),
        (lowpass(burst(0.82, 42, cutoff=900, decay=2.4), 760), 0.82, 0.0),
        (highpass(burst(0.22, 43, cutoff=5200, decay=6.0), 1000), 0.24, 0.0),
        (tone(0.50, 270, 66, wave_shape="saw", decay=4.0), 0.23, 0.02),
    ]))
    write("boss_defeat", mix(1.28, [
        (tone(1.18, 92, 28, wave_shape="sine", decay=1.7), 0.84, 0.0),
        (lowpass(burst(1.15, 44, cutoff=980, decay=1.8), 850), 0.78, 0.0),
        (tone(0.84, 520, 55, wave_shape="saw", decay=2.3), 0.32, 0.05),
        (highpass(burst(0.42, 45, cutoff=4800, decay=4.0), 900), 0.24, 0.12),
    ]))
    write("surge_start", mix(0.68, [
        (tone(0.62, 110, 220, wave_shape="saw", decay=1.2, sustain=0.18), 0.48, 0.0),
        (tone(0.17, 660, 660, wave_shape="square", decay=3.0), 0.24, 0.08),
        (tone(0.17, 880, 880, wave_shape="square", decay=3.0), 0.24, 0.34),
        (lowpass(burst(0.55, 46, cutoff=720, decay=2.0), 620), 0.34, 0.0),
    ]))

    # UI and progression: concise digital/servo grammar with no combat rumble.
    write("menu_move", mix(0.075, [
        (tone(0.065, 1050, 1240, wave_shape="triangle", decay=8.0, release=0.012), 0.72, 0.0),
        (highpass(burst(0.032, 50, cutoff=6500, decay=10.0), 1600), 0.22, 0.0),
    ]))
    write("upgrade_select", mix(0.14, [
        (tone(0.12, 740, 980, wave_shape="triangle", decay=5.0, release=0.02), 0.62, 0.0),
        (tone(0.10, 370, 490, wave_shape="sine", decay=5.0), 0.26, 0.0),
        (burst(0.04, 51, cutoff=4200, decay=9.0), 0.16, 0.0),
    ]))
    write("character_select", mix(0.30, [
        (tone(0.24, 310, 620, wave_shape="triangle", decay=3.2), 0.56, 0.0),
        (tone(0.18, 920, 730, wave_shape="sine", decay=4.8), 0.24, 0.03),
        (burst(0.10, 52, cutoff=1600, decay=7.0), 0.20, 0.0),
    ]))
    write("menu_back", mix(0.20, [
        (tone(0.17, 880, 390, wave_shape="triangle", decay=4.5), 0.66, 0.0),
        (burst(0.06, 53, cutoff=2500, decay=8.0), 0.20, 0.0),
    ]))
    write("restart", mix(0.48, [
        (tone(0.42, 84, 168, wave_shape="sine", decay=1.7, sustain=0.16), 0.58, 0.0),
        (arpeggio([330, 440, 660], 0.085, 0.10), 0.55, 0.11),
        (burst(0.09, 54, cutoff=1700, decay=6.0), 0.18, 0.0),
    ]))
    write("target_toggle", mix(0.15, [
        (tone(0.12, 520, 780, wave_shape="square", decay=5.5), 0.34, 0.0),
        (tone(0.11, 260, 390, wave_shape="triangle", decay=6.0), 0.38, 0.0),
    ]))
    write("health_pickup", arpeggio([523.25, 659.25, 783.99], 0.085, 0.16))
    write("level_up", mix(0.84, [
        (arpeggio([261.63, 329.63, 392.00, 523.25], 0.12, 0.22), 0.74, 0.0),
        (tone(0.68, 98, 196, wave_shape="sine", decay=1.8), 0.30, 0.0),
    ]))
    write("boss_reward", mix(0.92, [
        (arpeggio([196.00, 293.66, 392.00, 587.33], 0.12, 0.25), 0.70, 0.0),
        (chord([98.00, 146.83, 196.00], 0.82, decay=1.8), 0.38, 0.0),
    ]))
    write("weapon_unlock", mix(0.76, [
        (tone(0.70, 120, 960, wave_shape="triangle", decay=1.8), 0.52, 0.0),
        (arpeggio([392.00, 523.25, 783.99], 0.11, 0.20), 0.58, 0.24),
        (burst(0.18, 55, cutoff=2600, decay=3.5), 0.15, 0.28),
    ]))
    write("run_over", mix(0.92, [
        (tone(0.86, 180, 42, wave_shape="saw", decay=1.7), 0.48, 0.0),
        (tone(0.78, 72, 34, wave_shape="sine", decay=1.5), 0.62, 0.0),
        (lowpass(burst(0.70, 56, cutoff=650, decay=2.0), 560), 0.36, 0.0),
    ]))


if __name__ == "__main__":
    generate()
