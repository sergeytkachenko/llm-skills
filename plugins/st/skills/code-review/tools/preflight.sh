#!/usr/bin/env sh
# Preflight for the code-review skill's deterministic analyzer layer.
#
# Validates that Docker is installed AND running AND that Compose v2 is usable,
# then confirms the compose file resolves. One command, one exit code, one
# diagnostic line — so the gather step doesn't have to chain the checks by hand.
#
# Usage:   sh preflight.sh [path-to-compose.yml]
# Exit 0 → layer available (prints "ok").
# Exit !0 → layer unavailable; stdout is the on-the-record skip reason, and the
#           exit code says which check failed (so callers can branch if needed):
#   1 unsupported OS (only Linux and macOS)
#   2 docker CLI missing      3 compose v2 missing (maybe legacy v1 present)
#   4 daemon not running      5 daemon not accessible (permissions)
#   6 compose file not found
#
# The script only DIAGNOSES — it never starts the daemon, installs anything, or
# falls back to a host binary. The skill decides what to do with the result.

set -eu

COMPOSE="${1:-${CLAUDE_PLUGIN_ROOT:-}/skills/code-review/tools/compose.yml}"

# 0. Supported OS? Only Linux and macOS — the toolchain relies on a POSIX shell
#    and Unix bind-mount/socket semantics. Windows (outside a Linux/WSL shell,
#    which reports as Linux) is not supported.
OS="$(uname -s 2>/dev/null || echo unknown)"
case "$OS" in
  Linux|Darwin) : ;;  # supported
  *)
    echo "deterministic scan skipped — unsupported OS '$OS' (only Linux and macOS)"
    exit 1
    ;;
esac

# 1. Docker CLI installed?
if ! command -v docker >/dev/null 2>&1; then
  echo "deterministic scan skipped — Docker not installed"
  exit 2
fi

# 2. Compose v2 (the `docker compose` subcommand, not legacy `docker-compose`)?
if ! docker compose version >/dev/null 2>&1; then
  if command -v docker-compose >/dev/null 2>&1; then
    echo "deterministic scan skipped — Docker Compose v2 required (found legacy docker-compose v1)"
  else
    echo "deterministic scan skipped — Docker Compose not available"
  fi
  exit 3
fi

# 3. Daemon running and reachable? `docker info` is the real "is it running" probe.
if ! info_err="$(docker info 2>&1 >/dev/null)"; then
  case "$info_err" in
    *"permission denied"*|*"Got permission"*)
      echo "deterministic scan skipped — Docker daemon running but not accessible to this user (add user to the 'docker' group, or run rootless)"
      exit 5
      ;;
    *)
      echo "deterministic scan skipped — Docker installed but the daemon isn't running (start Docker Desktop or 'sudo systemctl start docker')"
      exit 4
      ;;
  esac
fi

# 4. Compose file resolves? (skill-install problem, not a Docker one)
if [ ! -f "$COMPOSE" ]; then
  echo "deterministic scan skipped — compose file not found at ${COMPOSE:-<unset>}"
  exit 6
fi

echo "ok"
