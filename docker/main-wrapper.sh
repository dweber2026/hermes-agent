#!/bin/sh
# /opt/hermes/docker/main-wrapper.sh
# Runs as Docker CMD (main program) — executes AFTER volume mounts.
set -e

# Resolve HERMES_HOME from s6 container environment.
_hermes_home="/opt/data"
if [ -f /run/s6/container_environment/HERMES_HOME ]; then
    _hermes_home=$(cat /run/s6/container_environment/HERMES_HOME)
elif [ -n "${HERMES_HOME:-}" ]; then
    _hermes_home="$HERMES_HOME"
fi
export HERMES_HOME="$_hermes_home"

# If Railway injects OPENROUTER_API_KEY via s6 container env, remove any stale .env.
# (Volume mounts before this script runs as CMD main program.)
_or_key_env="/run/s6/container_environment/OPENROUTER_API_KEY"
if [ -f "$_or_key_env" ] && [ -f "$HERMES_HOME/.env" ]; then
    echo "[main-wrapper] Railway env detected — removing stale volume .env"
    rm -f "$HERMES_HOME/.env"
fi

# Chown HERMES_HOME — volume is already mounted at this point.
if [ -d "$_hermes_home" ]; then
    chown -R hermes:hermes "$_hermes_home" 2>/dev/null || true
    echo "[main-wrapper] chowned $_hermes_home to hermes"
fi

cd "$_hermes_home"
# shellcheck disable=SC1091
. /opt/hermes/.venv/bin/activate

# Use with-contenv to pass Railway env vars (from /run/s6/container_environment/)
# into the hermes process via os.environ. Without this, s6-setuidgid drops them.
if [ $# -eq 0 ]; then
    exec /command/with-contenv s6-setuidgid hermes hermes
fi

if command -v "$1" >/dev/null 2>&1; then
    exec /command/with-contenv s6-setuidgid hermes "$@"
fi

exec /command/with-contenv s6-setuidgid hermes hermes "$@"
