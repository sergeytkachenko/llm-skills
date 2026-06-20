#!/usr/bin/env sh
# Self-check for the code-review skill's deterministic analyzer layer.
#
# Validates the toolchain is internally consistent WITHOUT pulling images or running
# a scan — so it's safe in CI and on a laptop. Checks:
#   1. preflight.sh is valid POSIX sh and its fallback probe parses.
#   2. compose.yml is valid and FAILS LOUDLY when OUTPUT_DIR is unset (the invariant
#      that a report never lands inside the reviewed tree).
#   3. compose.yml is valid when the three mount env vars are set.
#   4. every service image is pinned to an explicit tag (never `latest`/untagged) —
#      a bump can change findings, so it must be deliberate.
#   5. no service mounts an in-tree `./.review` default for /out.
#
# Usage:  sh verify.sh            (run from the tools/ dir, or pass its path)
# Exit 0 → all checks pass.  Exit 1 → a check failed (message on stderr).

set -eu

# preflight.sh always lives next to THIS script. The optional arg points at the
# directory holding the compose.yml to validate (defaults to the script's own dir),
# so a test can validate a throwaway compose copy without also copying preflight.
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
DIR="${1:-$SELF_DIR}"
COMPOSE="$DIR/compose.yml"
PREFLIGHT="$SELF_DIR/preflight.sh"
fail() { echo "verify: FAIL — $1" >&2; exit 1; }
ok()   { echo "verify: ok — $1"; }

# 1. preflight parses.
[ -f "$PREFLIGHT" ] || fail "preflight.sh not found at $PREFLIGHT"
sh -n "$PREFLIGHT" || fail "preflight.sh is not valid POSIX sh"
ok "preflight.sh parses"

[ -f "$COMPOSE" ] || fail "compose.yml not found at $COMPOSE"

# Need docker compose to validate the file; if absent, do a structural check only.
if docker compose version >/dev/null 2>&1; then
  # 2. Unset OUTPUT_DIR must make `config` fail (the :? guard).
  if OUTPUT_DIR= REVIEW_DIR=/tmp/rev GIT_COMMON_DIR=/tmp/rev/.git \
       docker compose -f "$COMPOSE" config >/dev/null 2>&1; then
    fail "compose.yml accepted an UNSET OUTPUT_DIR — the :? guard is missing (report could leak into the reviewed tree)"
  fi
  ok "unset OUTPUT_DIR is rejected (no in-tree report leak)"

  # 3. With env set, the file is valid.
  OUTPUT_DIR=/tmp/out REVIEW_DIR=/tmp/rev GIT_COMMON_DIR=/tmp/rev/.git \
    docker compose -f "$COMPOSE" config >/dev/null 2>&1 \
    || fail "compose.yml is invalid when the mount env vars are set"
  ok "compose.yml is valid with env set"
else
  echo "verify: note — docker compose not available; skipping config validation (structural checks only)"
fi

# 4. Every `image:` is pinned (has a `:tag`, and the tag isn't `latest`).
grep -E '^\s*image:' "$COMPOSE" | while IFS= read -r line; do
  ref="$(printf '%s\n' "$line" | sed -E 's/^\s*image:\s*//; s/\s*$//')"
  case "$ref" in
    *:latest) fail "image '$ref' is pinned to :latest — pin a specific version" ;;
    *:*)      : ;;  # has an explicit tag — good
    *)        fail "image '$ref' is unpinned (no tag) — pin a specific version" ;;
  esac
done
ok "all service images are pinned to explicit version tags"

# 5. No in-tree `./.review` default survives for /out.
if grep -q '\.review:/out' "$COMPOSE"; then
  fail "a service still defaults OUTPUT_DIR to ./.review:/out — reports must never land inside the reviewed tree"
fi
ok "no in-tree ./.review report mount"

echo "verify: ALL CHECKS PASSED"
