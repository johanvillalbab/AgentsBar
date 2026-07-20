#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GROUP_SIZE="${AGENTSBAR_TEST_GROUP_SIZE:-12}"
SUITE_TIMEOUT="${AGENTSBAR_TEST_SUITE_TIMEOUT:-180}"
RETRY_NON_TIMEOUT_FAILURES="${AGENTSBAR_TEST_RETRY_NON_TIMEOUT_FAILURES:-1}"

cd "${ROOT_DIR}"

# Defense in depth: test processes also self-detect, but keep this explicit so runner changes cannot
# expose the user's login Keychain. Deliberate isolated Keychain tests must opt in by setting the allow flag.
if [[ "${AGENTSBAR_ALLOW_TEST_KEYCHAIN_ACCESS:-}" != "1" ]]; then
  export AGENTSBAR_SUPPRESS_TEST_KEYCHAIN_ACCESS=1
fi

ARGS=(
  --group-size "${GROUP_SIZE}"
  --timeout "${SUITE_TIMEOUT}"
)

case "${RETRY_NON_TIMEOUT_FAILURES}" in
  0) ARGS+=(--no-retry-non-timeout-failures) ;;
  1) ;;
  *)
    echo "AGENTSBAR_TEST_RETRY_NON_TIMEOUT_FAILURES must be 0 or 1" >&2
    exit 2
    ;;
esac

if [[ -n "${AGENTSBAR_TEST_SHARD_INDEX:-}" || -n "${AGENTSBAR_TEST_SHARD_COUNT:-}" ]]; then
  ARGS+=(
    --shard-index "${AGENTSBAR_TEST_SHARD_INDEX:?AGENTSBAR_TEST_SHARD_COUNT requires AGENTSBAR_TEST_SHARD_INDEX}"
    --shard-count "${AGENTSBAR_TEST_SHARD_COUNT:?AGENTSBAR_TEST_SHARD_INDEX requires AGENTSBAR_TEST_SHARD_COUNT}"
  )
fi

exec python3 "${ROOT_DIR}/Scripts/ci_swift_test_by_suite.py" "${ARGS[@]}" "$@"
