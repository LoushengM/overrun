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

"$GODOT" --headless --editor --path . --quit
"$GODOT" --headless --path . --script tests/formula_test.gd
"$GODOT" --headless --path . --script tests/regression_test.gd

benchmark_output="$($GODOT --headless --path . -- --benchmark)"
printf '%s\n' "$benchmark_output"
grep -q "BENCHMARK_RESULT" <<<"$benchmark_output"

echo "All Overrun checks passed."
