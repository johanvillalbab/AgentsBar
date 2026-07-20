#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/agentsbar-repository-size.XXXXXX")
trap 'rm -rf "$TEMP_DIR"' EXIT

mkdir -p "$TEMP_DIR/Scripts"
cp "$ROOT_DIR/Scripts/check_repository_size.sh" "$TEMP_DIR/Scripts/"
git -C "$TEMP_DIR" init --quiet
empty_output=$("$TEMP_DIR/Scripts/check_repository_size.sh")
grep -Fq 'repository size OK: 0 tracked files' <<<"$empty_output"

printf 'small source file\n' > "$TEMP_DIR/source.txt"
git -C "$TEMP_DIR" add source.txt Scripts/check_repository_size.sh

"$TEMP_DIR/Scripts/check_repository_size.sh" >/dev/null

dd if=/dev/zero of="$TEMP_DIR/untracked.bin" bs=1024 count=2049 2>/dev/null
"$TEMP_DIR/Scripts/check_repository_size.sh" >/dev/null

dd if=/dev/zero of="$TEMP_DIR/boundary.bin" bs=1024 count=2048 2>/dev/null
git -C "$TEMP_DIR" add boundary.bin
"$TEMP_DIR/Scripts/check_repository_size.sh" >/dev/null
printf 'x' >> "$TEMP_DIR/boundary.bin"
git -C "$TEMP_DIR" add boundary.bin
if "$TEMP_DIR/Scripts/check_repository_size.sh" >"$TEMP_DIR/large.log" 2>&1; then
  printf 'ERROR: staged blob one byte above the limit was accepted.\n' >&2
  exit 1
fi
grep -Fq 'tracked file exceeds 2097152 bytes: boundary.bin (2097153 bytes)' "$TEMP_DIR/large.log"

git -C "$TEMP_DIR" rm --cached --force --quiet boundary.bin
git -C "$TEMP_DIR" add untracked.bin
printf 'working tree is now small\n' > "$TEMP_DIR/untracked.bin"
if "$TEMP_DIR/Scripts/check_repository_size.sh" >"$TEMP_DIR/staged-large.log" 2>&1; then
  printf 'ERROR: oversized staged blob was accepted after its working-tree file changed.\n' >&2
  exit 1
fi
grep -Fq 'tracked file exceeds 2097152 bytes: untracked.bin (2098176 bytes)' "$TEMP_DIR/staged-large.log"

git -C "$TEMP_DIR" rm --cached --force --quiet untracked.bin
printf 'small staged blob\n' > "$TEMP_DIR/index-is-authoritative.bin"
git -C "$TEMP_DIR" add index-is-authoritative.bin
dd if=/dev/zero of="$TEMP_DIR/index-is-authoritative.bin" bs=1024 count=2049 2>/dev/null
"$TEMP_DIR/Scripts/check_repository_size.sh" >/dev/null

odd_path=$'odd\nname.txt'
printf 'small source file\n' > "$TEMP_DIR/$odd_path"
git -C "$TEMP_DIR" add "$odd_path"
"$TEMP_DIR/Scripts/check_repository_size.sh" >/dev/null

artifacts=(
  "AgentsBar 2.app/Contents/MacOS/AgentsBar"
  "AgentsBar.dSYM/Contents/Info.plist"
  "AgentsBar.xcarchive/Products/Applications/AgentsBar.app/Contents/Info.plist"
  "AgentsBar.xcresult/Data/data"
  "AgentsBar.ipa"
  "AgentsBar.zip"
  "AgentsBar.delta"
  "AgentsBar.dmg"
  "AgentsBar.pkg"
  "AgentsBar.tar.gz"
  "AgentsBar.tgz"
)
for artifact in "${artifacts[@]}"; do
  mkdir -p "$TEMP_DIR/$(dirname "$artifact")"
  printf 'release artifact\n' > "$TEMP_DIR/$artifact"
  git -C "$TEMP_DIR" add -f "$artifact"
done
ln -s source.txt "$TEMP_DIR/AgentsBar-latest.dmg"
git -C "$TEMP_DIR" add -f AgentsBar-latest.dmg
rm "$TEMP_DIR/AgentsBar.zip"
if "$TEMP_DIR/Scripts/check_repository_size.sh" >"$TEMP_DIR/artifact.log" 2>&1; then
  printf 'ERROR: tracked release artifacts were accepted.\n' >&2
  exit 1
fi
for artifact in "${artifacts[@]}" AgentsBar-latest.dmg; do
  grep -Fq "generated artifact is tracked: $artifact" "$TEMP_DIR/artifact.log"
done

printf 'Repository size tests passed.\n'
