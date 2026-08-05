#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

resolve_godot() {
  if [[ -n "${GODOT_BIN:-}" ]]; then
    printf '%s\n' "$GODOT_BIN"
  elif [[ -x ".tools/godot/Godot_v4.7.1-stable_linux.x86_64" ]]; then
    printf '%s\n' ".tools/godot/Godot_v4.7.1-stable_linux.x86_64"
  elif command -v godot4 >/dev/null 2>&1; then
    command -v godot4
  elif command -v godot >/dev/null 2>&1; then
    command -v godot
  else
    echo "Godot not found. Set GODOT_BIN." >&2
    exit 1
  fi
}

GODOT="$(resolve_godot)"

# Godot asserts print to stderr without setting a non-zero exit code, so a failed
# assertion would otherwise slip past `set -e`. Scan the output instead.
run_script() {
  local script_path="$1"
  local output
  output="$("$GODOT" --headless --path . --script "$script_path" 2>&1)"
  printf '%s\n' "$output"
  if grep -qE "SCRIPT ERROR|Assertion failed" <<<"$output"; then
    echo "Failure in $script_path" >&2
    exit 1
  fi
}

"$GODOT" --headless --editor --path . --quit
run_script tests/formula_test.gd
run_script tests/regression_test.gd

# The roster overlay check and the 1200-enemy crowd benchmark both lived in the
# repo without ever being gated on, so a character stat regression or an FPS
# collapse could land green. Each prints a terminal marker; grep for it so a
# silent early quit cannot pass either.
character_output="$(run_script tests/character_check.gd)"
printf '%s\n' "$character_output"
grep -q "CHARACTER_CHECK_OK" <<<"$character_output"

crowd_output="$(run_script tests/crowd_benchmark.gd)"
printf '%s\n' "$crowd_output"
grep -q "CROWD_BENCHMARK_RESULT" <<<"$crowd_output"
# The headline performance promise is 1200 enemies at >= 60 fps. Assert it here
# rather than eyeballing the JSON.
printf '%s' "$crowd_output" | python3 -c '
import json, re, sys
blob = sys.stdin.read()
match = re.search(r"CROWD_BENCHMARK_RESULT\s+(\{.*\})", blob)
if not match:
    sys.exit("crowd benchmark produced no result line")
data = json.loads(match.group(1))
if data["fps"] < 60.0:
    sys.exit("crowd benchmark below 60 fps: %s" % data)
print("CROWD_BENCHMARK_OK %s enemies at %s fps" % (data["enemies"], data["fps"]))
'

# The dummy renderer cannot detect a CanvasItem draw-call explosion. On Linux,
# exercise the visual caps through a real OpenGL context under Xvfb and gate on
# both sustained frame rate and draw-call count. Other platforms still run the
# deterministic batching assertions in regression_test.gd.
if command -v xvfb-run >/dev/null 2>&1; then
  render_output="$(xvfb-run -a -s '-screen 0 1280x720x24' \
    "$GODOT" --path . --audio-driver Dummy --disable-vsync \
    --script tests/render_benchmark.gd 2>&1)"
  printf '%s\n' "$render_output"
  if grep -qE "SCRIPT ERROR|Assertion failed" <<<"$render_output"; then
    echo "Failure in tests/render_benchmark.gd" >&2
    exit 1
  fi
  printf '%s' "$render_output" | python3 -c '
import json, re, sys
blob = sys.stdin.read()
match = re.search(r"RENDER_BENCHMARK_RESULT\s+(\{.*\})", blob)
if not match:
    sys.exit("render benchmark produced no result line")
data = json.loads(match.group(1))
if data["fps"] < 60.0:
    sys.exit("render benchmark below 60 fps: %s" % data)
if data["draw_calls"] > 100:
    sys.exit("render benchmark exceeded 100 draw calls: %s" % data)
print("RENDER_BENCHMARK_OK %.1f fps at %d draw calls" % (data["fps"], data["draw_calls"]))
'
else
  echo "RENDER_BENCHMARK_SKIPPED xvfb-run not available"
fi

if command -v xvfb-run >/dev/null 2>&1; then
  motion_output="$(xvfb-run -a -s '-screen 0 1280x720x24' \
    "$GODOT" --path . --audio-driver Dummy --disable-vsync \
    --script tests/motion_render_test.gd 2>&1)"
  printf '%s\n' "$motion_output"
  if grep -qE "SCRIPT ERROR|Assertion failed" <<<"$motion_output"; then
    echo "Failure in tests/motion_render_test.gd" >&2
    exit 1
  fi
  grep -q "MOTION_RENDER_TEST_OK" <<<"$motion_output"
else
  echo "MOTION_RENDER_TEST_SKIPPED xvfb-run not available"
fi

if command -v xvfb-run >/dev/null 2>&1; then
  gameplay_stress_output="$(xvfb-run -a -s '-screen 0 1280x720x24' \
    "$GODOT" --path . --audio-driver Dummy --disable-vsync \
    --script tests/gameplay_stress_benchmark.gd 2>&1)"
  printf '%s\n' "$gameplay_stress_output"
  if grep -qE "SCRIPT ERROR|Assertion failed" <<<"$gameplay_stress_output"; then
    echo "Failure in tests/gameplay_stress_benchmark.gd" >&2
    exit 1
  fi
  printf '%s' "$gameplay_stress_output" | python3 -c '
import json, re, sys
blob = sys.stdin.read()
match = re.search(r"GAMEPLAY_STRESS_RESULT\s+(\{.*\})", blob)
if not match:
    sys.exit("gameplay stress benchmark produced no result line")
data = json.loads(match.group(1))
if data["fps"] < 60.0:
    sys.exit("gameplay stress benchmark below 60 fps: %s" % data)
if data["frame_ms_p99"] > 33.4:
    sys.exit("gameplay stress p99 frame exceeded 33.4 ms: %s" % data)
print("GAMEPLAY_STRESS_OK %.1f fps, p99 %.2f ms" % (data["fps"], data["frame_ms_p99"]))
'
else
  echo "GAMEPLAY_STRESS_SKIPPED xvfb-run not available"
fi

benchmark_output="$($GODOT --headless --path . -- --benchmark 2>&1)"
printf '%s\n' "$benchmark_output"
if grep -qE "SCRIPT ERROR|Assertion failed" <<<"$benchmark_output"; then
  echo "Failure in stock gameplay benchmark" >&2
  exit 1
fi
grep -q "BENCHMARK_RESULT" <<<"$benchmark_output"

# The stock benchmark never fires the four newer weapons, so their cost is
# unmeasured. This variant swaps the loadout and leaves the headline number
# above comparable across commits.
expanded_output="$($GODOT --headless --path . -- --benchmark-expanded 2>&1)"
printf '%s\n' "$expanded_output"
if grep -qE "SCRIPT ERROR|Assertion failed" <<<"$expanded_output"; then
  echo "Failure in expanded gameplay benchmark" >&2
  exit 1
fi
grep -q "BENCHMARK_RESULT" <<<"$expanded_output"
grep -q '"owned_weapons":\["chain","flak","orbital","detonator"\]' <<<"$expanded_output"

echo "All Overrun checks passed."
