#!/bin/sh
# /opt/hermes/docker/main-wrapper.sh
set -e

# Resolve HERMES_HOME from s6 container environment (Railway env vars live here).
# s6-overlay stores Railway-injected env vars in /run/s6/container_environment/
_hermes_home="/opt/data"
if [ -f /run/s6/container_environment/HERMES_HOME ]; then
    _hermes_home=$(cat /run/s6/container_environment/HERMES_HOME)
elif [ -n "${HERMES_HOME:-}" ]; then
    _hermes_home="$HERMES_HOME"
fi
export HERMES_HOME="$_hermes_home"

# If Railway injects OPENROUTER_API_KEY, remove any stale .env on the volume.
# A blank .env seeded from .env.example overrides Railway env vars via dotenv override=True.
_or_key_env="/run/s6/container_environment/OPENROUTER_API_KEY"
if [ -f "$_or_key_env" ] && [ -f "$HERMES_HOME/.env" ]; then
    echo "[main-wrapper] Railway env vars detected — removing stale .env"
    rm -f "$HERMES_HOME/.env"
fi

# Chown HERMES_HOME to hermes user. This script runs as the CMD main program,
# which executes AFTER the volume mounts — so chown sees the real volume contents.
if [ -d "$_hermes_home" ]; then
    chown -R hermes:hermes "$_hermes_home" 2>/dev/null || true
    echo "[main-wrapper] chowned $_hermes_home to hermes"
fi

cd "$_hermes_home"
# shellcheck disable=SC1091
. /opt/hermes/.venv/bin/activate

if [ $# -eq 0 ]; then
    exec s6-setuidgid hermes hermes
fi

if command -v "$1" >/dev/null 2>&1; then
    exec s6-setuidgid hermes "$@"
fi

exec s6-setuidgid hermes hermes "$@"
