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
mkdir -p dist
"$GODOT" --headless --editor --path . --quit
"$GODOT" --headless --path . --export-release "Windows Desktop" dist/Overrun.exe

if [[ ! -s dist/Overrun.exe ]]; then
  echo "Export failed: dist/Overrun.exe was not created." >&2
  exit 1
fi

sha256sum dist/Overrun.exe > dist/Overrun.exe.sha256
ls -lh dist/Overrun.exe dist/Overrun.exe.sha256
