#!/usr/bin/env bash
# Rebuild the five expanded-roster audio cues from their CC0 Kenney sources.
#
# The source packs are not vendored (14 MB of upstream zips for 170 KB of
# output). Fetch them from kenney.nl -- "Sci-Fi Sounds" and "Impact Sounds" --
# extract, and point SRC_ROOT at the parent directory holding scifi/ and
# impact/. Per-clip provenance is recorded in
# assets/audio/LICENSE_KENNEY_CC0.txt.
#
#   SRC_ROOT=~/kenney tools/build_audio_cues.sh
#
# Every clip is pitched down with asetrate (which lowers pitch AND lengthens the
# clip), then resampled back to 44.1 kHz so Godot sees the project's standard
# format. atrim runs AFTER the pitch shift so the stated duration is the final
# duration, not the pre-stretch one. Output matches the existing stock assets:
# 44.1 kHz mono 16-bit PCM WAV.
#
# Verify results with tools/measure_audio_band.py -- all five should read
# hi_2k <= -37 dB, which is the bar for a cue that repeats this often.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${ROOT_DIR}/assets/audio"
SRC_ROOT="${SRC_ROOT:?Set SRC_ROOT to the directory containing scifi/ and impact/}"
SCIFI="${SRC_ROOT}/scifi/Audio"
IMPACT="${SRC_ROOT}/impact/Audio"

for dir in "$SCIFI" "$IMPACT"; do
  [[ -d "$dir" ]] || { echo "Missing source directory: $dir" >&2; exit 1; }
done

# src, dest, pitch_ratio, final_duration, fade_out_start
build() {
  local src="$1" dest="$2" ratio="$3" dur="$4" fade="$5"
  local rate
  rate=$(python3 -c "print(int(44100*$ratio))")
  ffmpeg -hide_banner -v error -y -i "$src" \
    -af "asetrate=${rate},aresample=44100,atrim=0:${dur},highpass=f=35,afade=t=out:st=${fade}:d=$(python3 -c "print(round($dur-$fade,3))"),loudnorm=I=-20:TP=-1.5:LRA=11" \
    -ar 44100 -ac 1 -c:a pcm_s16le "${OUT}/${dest}"
  printf '%-26s <- %-34s ratio=%s dur=%s\n' "$dest" "$(basename "$src")" "$ratio" "$dur"
}

# Arc Chain: fires every ~0.2-0.5s. Force-field hum, pitched down and cut short
# so it reads as a zap rather than a sustained drone.
build "${SCIFI}/forceField_000.ogg"             chain_arc.wav        0.80 0.34 0.20

# Flak Burst: one cue per volley, frequent. Short dark punch.
build "${IMPACT}/impactPunch_heavy_001.ogg"     flak_fire.wav        0.85 0.28 0.16

# Orbital: the highest-repetition cue in the game -- eight satellites can each
# contact on every interval. Softest and darkest source, heavily shortened.
build "${IMPACT}/impactSoft_heavy_000.ogg"      orbital_contact.wav  0.80 0.24 0.12

# Detonator launch: mortar thump.
build "${IMPACT}/impactPunch_heavy_000.ogg"     detonator_launch.wav 0.78 0.36 0.22

# Detonator blast: darkest source in either pack.
build "${SCIFI}/lowFrequency_explosion_001.ogg" detonator_blast.wav  0.90 0.75 0.40
