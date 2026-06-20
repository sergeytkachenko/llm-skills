#!/usr/bin/env sh
# Preflight for the code-review skill's deterministic analyzer layer.
#
# Validates that Docker is installed AND running AND that Compose v2 is usable,
# then confirms the compose file resolves. One command, one exit code, one
# diagnostic line — so the gather step doesn't have to chain the checks by hand.
#
# Usage:   sh preflight.sh [path-to-compose.yml]
# Exit 0 → Docker layer available (prints "ok").
# Exit !0 → Docker layer unavailable; stdout is the on-the-record skip reason, and
#           the exit code says which check failed (so callers can branch if needed):
#   1 unsupported OS (only Linux and macOS)
#   2 docker CLI missing      3 compose v2 missing (maybe legacy v1 present)
#   4 daemon not running      5 daemon not accessible (permissions)
#   6 compose file not found
#
# On ANY non-zero exit, stdout also carries a second line, `fallback: <…>`, naming
# which host binaries (or ephemeral `uvx`/`npx` runners) are present so the skill can
# degrade to the host-binary path (rubrics/tool-registry.md "Host-binary fallback")
# instead of dropping the whole layer. `fallback: none` means no host tool is usable
# either — only then is the deterministic layer fully skipped.
#
# The script only DIAGNOSES — it never starts the daemon, installs anything, or runs
# a scanner. The skill decides what to do with the result.

set -eu

# Emit the on-the-record skip reason, then probe the host for usable fallback tools
# and print a `fallback:` line, then exit with the given code. Called on every
# Docker-unavailable path so the skill never has to re-probe.
fail_with_fallback() {
  _code="$1"; _reason="$2"
  echo "$_reason"
  _have=""
  for _t in semgrep gitleaks trivy osv-scanner; do
    command -v "$_t" >/dev/null 2>&1 && _have="$_have $_t"
  done
  # Ephemeral runners can stand in for Semgrep (uvx) and osv-scanner/Trivy is Go-only,
  # so only note uvx for semgrep when the binary itself is absent.
  if ! command -v semgrep >/dev/null 2>&1 && command -v uvx >/dev/null 2>&1; then
    _have="$_have semgrep(uvx)"
  fi
  if [ -n "$_have" ]; then
    echo "fallback:$_have"
  else
    echo "fallback: none"
  fi
  exit "$_code"
}

COMPOSE="${1:-${CLAUDE_PLUGIN_ROOT:-}/skills/code-review/tools/compose.yml}"

# 0. Supported OS? Only Linux and macOS — the toolchain relies on a POSIX shell
#    and Unix bind-mount/socket semantics. Windows (outside a Linux/WSL shell,
#    which reports as Linux) is not supported.
OS="$(uname -s 2>/dev/null || echo unknown)"
case "$OS" in
  Linux|Darwin) : ;;  # supported
  *)
    # No usable host path on a non-POSIX OS either — hard skip, no fallback probe.
    echo "deterministic scan skipped — unsupported OS '$OS' (only Linux and macOS)"
    exit 1
    ;;
esac

# 1. Docker CLI installed?
if ! command -v docker >/dev/null 2>&1; then
  fail_with_fallback 2 "deterministic scan skipped — Docker not installed"
fi

# 2. Compose v2 (the `docker compose` subcommand, not legacy `docker-compose`)?
if ! docker compose version >/dev/null 2>&1; then
  if command -v docker-compose >/dev/null 2>&1; then
    fail_with_fallback 3 "deterministic scan skipped — Docker Compose v2 required (found legacy docker-compose v1)"
  else
    fail_with_fallback 3 "deterministic scan skipped — Docker Compose not available"
  fi
fi

# 3. Daemon running and reachable? `docker info` is the real "is it running" probe.
if ! info_err="$(docker info 2>&1 >/dev/null)"; then
  case "$info_err" in
    *"permission denied"*|*"Got permission"*)
      fail_with_fallback 5 "deterministic scan skipped — Docker daemon running but not accessible to this user (add user to the 'docker' group, or run rootless)"
      ;;
    *)
      fail_with_fallback 4 "deterministic scan skipped — Docker installed but the daemon isn't running (start Docker Desktop or 'sudo systemctl start docker')"
      ;;
  esac
fi

# 4. Compose file resolves? (skill-install problem, not a Docker one)
if [ ! -f "$COMPOSE" ]; then
  fail_with_fallback 6 "deterministic scan skipped — compose file not found at ${COMPOSE:-<unset>}"
fi

echo "ok"
