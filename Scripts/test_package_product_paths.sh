#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
source "$ROOT/Scripts/package_product_paths.sh"

TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/agentsbar-package-paths.XXXXXX")
trap 'rm -rf "$TEMP_DIR"' EXIT

NATIVE_DIR="$TEMP_DIR/.build/arm64-apple-macosx/release"
SWIFTBUILD_DIR="$TEMP_DIR/.build/out/Products/Release"
STAGE_ROOT="$TEMP_DIR/.build/package-products/release"
mkdir -p "$NATIVE_DIR/AgentsBar.dSYM" "$SWIFTBUILD_DIR/Sparkle.framework" "$SWIFTBUILD_DIR/AgentsBar.dSYM"
touch "$NATIVE_DIR/AgentsBar" "$SWIFTBUILD_DIR/AgentsBar"

native=$(agentsbar_require_product_file "$NATIVE_DIR" AgentsBar arm64)
[[ "$native" == "$NATIVE_DIR/AgentsBar" ]]

swiftbuild=$(agentsbar_require_product_file "$SWIFTBUILD_DIR" AgentsBar arm64)
[[ "$swiftbuild" == "$SWIFTBUILD_DIR/AgentsBar" ]]

framework=$(agentsbar_require_product_directory "$SWIFTBUILD_DIR" Sparkle.framework packaging)
[[ "$framework" == "$SWIFTBUILD_DIR/Sparkle.framework" ]]

dsym=$(agentsbar_require_product_directory "$SWIFTBUILD_DIR" AgentsBar.dSYM release)
[[ "$dsym" == "$SWIFTBUILD_DIR/AgentsBar.dSYM" ]]

resolved=$(agentsbar_resolve_staged_or_reported_file "$STAGE_ROOT" "$SWIFTBUILD_DIR" AgentsBar arm64)
[[ "$resolved" == "$SWIFTBUILD_DIR/AgentsBar" ]]

resolved_dsym=$(agentsbar_resolve_dsym_path "$STAGE_ROOT" "$SWIFTBUILD_DIR" AgentsBar arm64)
[[ "$resolved_dsym" == "$SWIFTBUILD_DIR/AgentsBar.dSYM" ]]

mkdir -p "$STAGE_ROOT/arm64/AgentsBar.dSYM"
touch "$STAGE_ROOT/arm64/AgentsBar"
staged=$(agentsbar_resolve_staged_or_reported_file "$STAGE_ROOT" "$SWIFTBUILD_DIR" AgentsBar arm64)
[[ "$staged" == "$STAGE_ROOT/arm64/AgentsBar" ]]
staged_dsym=$(agentsbar_resolve_dsym_path "$STAGE_ROOT" "$SWIFTBUILD_DIR" AgentsBar arm64)
[[ "$staged_dsym" == "$STAGE_ROOT/arm64/AgentsBar.dSYM" ]]

rm -rf "$STAGE_ROOT"
rm "$SWIFTBUILD_DIR/AgentsBar"
if agentsbar_resolve_staged_or_reported_file "$STAGE_ROOT" "$SWIFTBUILD_DIR" AgentsBar arm64 \
  2>"$TEMP_DIR/missing-file.log"; then
  echo "ERROR: Missing reported product unexpectedly fell back to legacy output." >&2
  exit 1
fi
grep -Fq "$SWIFTBUILD_DIR/AgentsBar" "$TEMP_DIR/missing-file.log"

rm -rf "$SWIFTBUILD_DIR/Sparkle.framework"
if agentsbar_require_product_directory "$SWIFTBUILD_DIR" Sparkle.framework packaging \
  2>"$TEMP_DIR/missing-directory.log"; then
  echo "ERROR: Missing reported framework was accepted." >&2
  exit 1
fi
grep -Fq "$SWIFTBUILD_DIR/Sparkle.framework" "$TEMP_DIR/missing-directory.log"

rm -rf "$SWIFTBUILD_DIR/AgentsBar.dSYM"
if agentsbar_resolve_dsym_path "$STAGE_ROOT" "$SWIFTBUILD_DIR" AgentsBar arm64 \
  2>"$TEMP_DIR/missing-dsym.log"; then
  echo "ERROR: Missing reported dSYM unexpectedly fell back to legacy output." >&2
  exit 1
fi
grep -Fq "$SWIFTBUILD_DIR/AgentsBar.dSYM" "$TEMP_DIR/missing-dsym.log"

swift() {
  [[ "$*" == "build --show-bin-path -c release --arch arm64" ]]
  printf '%s\n' "$SWIFTBUILD_DIR"
}
reported=$(agentsbar_swiftpm_bin_path release arm64)
[[ "$reported" == "$SWIFTBUILD_DIR" ]]

swift() {
  return 23
}
if agentsbar_swiftpm_bin_path release arm64 2>"$TEMP_DIR/query.log"; then
  echo "ERROR: SwiftPM bin-path query failure was ignored." >&2
  exit 1
fi
grep -Fq "SwiftPM failed to report" "$TEMP_DIR/query.log"

swift() {
  return 0
}
if agentsbar_swiftpm_bin_path release arm64 2>"$TEMP_DIR/empty.log"; then
  echo "ERROR: Empty SwiftPM bin path was accepted." >&2
  exit 1
fi
grep -Fq "SwiftPM reported an empty" "$TEMP_DIR/empty.log"

echo "Package product path tests passed."
