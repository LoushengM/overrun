#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

RELEASE_TAG="${RELEASE_TAG:-dev}"
RELEASE_TITLE="${RELEASE_TITLE:-Overrun development build}"
ALLOW_DIRTY="${ALLOW_DIRTY:-0}"
ASSETS=(
  "dist/Overrun.exe"
  "dist/Overrun.exe.sha256"
)

for command_name in git gh sha256sum file; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Required command not found: $command_name" >&2
    exit 1
  fi
done

gh auth status >/dev/null

if [[ "$ALLOW_DIRTY" != "1" ]] && [[ -n "$(git status --porcelain)" ]]; then
  echo "Refusing to publish from a dirty worktree." >&2
  echo "Commit or stash local changes, or set ALLOW_DIRTY=1 intentionally." >&2
  git status --short >&2
  exit 1
fi

repository="$(gh repo view --json nameWithOwner --jq '.nameWithOwner')"
commit_sha="$(git rev-parse HEAD)"
commit_short="$(git rev-parse --short HEAD)"

verify_build() {
  local directory="$1"

  if [[ ! -s "$directory/Overrun.exe" ]]; then
    echo "Missing or empty executable: $directory/Overrun.exe" >&2
    return 1
  fi
  if [[ ! -s "$directory/Overrun.exe.sha256" ]]; then
    echo "Missing or empty checksum: $directory/Overrun.exe.sha256" >&2
    return 1
  fi

  (
    cd "$directory"
    sha256sum -c Overrun.exe.sha256
  )

  if ! file "$directory/Overrun.exe" | grep -Eq 'PE32\+ executable.*x86-64'; then
    echo "Packaged file is not a 64-bit Windows PE executable." >&2
    file "$directory/Overrun.exe" >&2
    return 1
  fi
}

"$ROOT_DIR/scripts/package.sh"
verify_build "$ROOT_DIR/dist"

checksum="$(cut -d' ' -f1 dist/Overrun.exe.sha256)"
built_at="$(date -u '+%Y-%m-%d %H:%M UTC')"
notes="Rolling Windows test build.

Built: $built_at
Source: $commit_sha
SHA-256: $checksum

The Overrun.exe asset at this release is replaced on each publish."

if gh release view "$RELEASE_TAG" --repo "$repository" >/dev/null 2>&1; then
  gh release upload "$RELEASE_TAG" "${ASSETS[@]}" --clobber --repo "$repository"
  gh release edit "$RELEASE_TAG" \
    --repo "$repository" \
    --title "$RELEASE_TITLE" \
    --notes "$notes" \
    --prerelease

  gh api --method PATCH \
    "repos/$repository/git/refs/tags/$RELEASE_TAG" \
    -f sha="$commit_sha" \
    -F force=true >/dev/null
else
  gh release create "$RELEASE_TAG" "${ASSETS[@]}" \
    --repo "$repository" \
    --target "$commit_sha" \
    --title "$RELEASE_TITLE" \
    --notes "$notes" \
    --prerelease
fi

remote_tag_sha="$(gh api "repos/$repository/git/ref/tags/$RELEASE_TAG" --jq '.object.sha')"
if [[ "$remote_tag_sha" != "$commit_sha" ]]; then
  echo "Published tag points to $remote_tag_sha instead of $commit_sha." >&2
  exit 1
fi

verification_dir="$(mktemp -d)"
trap 'rm -rf "$verification_dir"' EXIT

gh release download "$RELEASE_TAG" \
  --repo "$repository" \
  --pattern 'Overrun.exe' \
  --pattern 'Overrun.exe.sha256' \
  --dir "$verification_dir" \
  --clobber
verify_build "$verification_dir"

printf '\nPublished %s (%s)\n' "$RELEASE_TITLE" "$commit_short"
printf 'Release:  https://github.com/%s/releases/tag/%s\n' "$repository" "$RELEASE_TAG"
printf 'Download: https://github.com/%s/releases/download/%s/Overrun.exe\n' "$repository" "$RELEASE_TAG"
printf 'Checksum: https://github.com/%s/releases/download/%s/Overrun.exe.sha256\n' "$repository" "$RELEASE_TAG"
printf 'SHA-256: %s\n' "$checksum"
