#!/bin/sh
# /opt/hermes/docker/main-wrapper.sh — wraps the container's CMD with
# the same argument-routing logic the pre-s6 entrypoint.sh used. Runs
# as /init's "main program" (Docker CMD) so it inherits stdin/stdout/
# stderr from the container.
#
# Routing:
#   no args                       → exec `hermes` (the default)
#   first arg is an executable    → exec it directly (sleep, bash, sh, …)
#   first arg is anything else    → exec `hermes <args>` (subcommand passthrough)
#
# We drop to the hermes user via `s6-setuidgid` so the supervised
# workload runs unprivileged (UID 10000 by default).
set -e

# Resolve HERMES_HOME from s6 container environment (Railway env vars live here)
# s6-overlay stores Railway-injected env vars in /run/s6/container_environment/
_hermes_home="/opt/data"
if [ -f /run/s6/container_environment/HERMES_HOME ]; then
    _hermes_home=$(cat /run/s6/container_environment/HERMES_HOME)
elif [ -n "${HERMES_HOME:-}" ]; then
    _hermes_home="$HERMES_HOME"
fi
export HERMES_HOME="$_hermes_home"

# If .env exists but has no real API keys (stale blank seed from .env.example),
# remove it so Hermes falls back to reading keys from os.environ (Railway vars).
if [ -f "$HERMES_HOME/.env" ]; then
    if ! grep -q "OPENROUTER_API_KEY=sk\|OPENAI_API_KEY=sk\|ANTHROPIC_API_KEY=sk\|OPENROUTER_API_KEY=[a-zA-Z0-9_-]" "$HERMES_HOME/.env" 2>/dev/null; then
        echo "[main-wrapper] Removing stale blank .env (no API keys found)"
        rm -f "$HERMES_HOME/.env"
    fi
fi

cd "$_hermes_home"
# shellcheck disable=SC1091
. /opt/hermes/.venv/bin/activate

# Chown HERMES_HOME to hermes user — runs AFTER volume mount (CMD runs post-volume).
# Fixes stale root-owned dirs/files left by previous crash writes on the volume.
if [ -d "$_hermes_home" ]; then
    chown -R hermes:hermes "$_hermes_home" 2>/dev/null || true
    echo "[main-wrapper] chowned $_hermes_home to hermes"
fi

if [ $# -eq 0 ]; then
    exec s6-setuidgid hermes hermes
fi

if command -v "$1" >/dev/null 2>&1; then
    # Bare executable — pass through directly.
    exec s6-setuidgid hermes "$@"
fi

# Hermes subcommand pass-through.
exec s6-setuidgid hermes hermes "$@"
