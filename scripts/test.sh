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

benchmark_output="$($GODOT --headless --path . -- --benchmark)"
printf '%s\n' "$benchmark_output"
grep -q "BENCHMARK_RESULT" <<<"$benchmark_output"

# The stock benchmark never fires the four newer weapons, so their cost is
# unmeasured. This variant swaps the loadout and leaves the headline number
# above comparable across commits.
expanded_output="$($GODOT --headless --path . -- --benchmark-expanded)"
printf '%s\n' "$expanded_output"
grep -q "BENCHMARK_RESULT" <<<"$expanded_output"
grep -q '"owned_weapons":\["chain","flak","orbital","detonator"\]' <<<"$expanded_output"

echo "All Overrun checks passed."
