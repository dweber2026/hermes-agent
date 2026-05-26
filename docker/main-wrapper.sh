#!/bin/sh
# /opt/hermes/docker/main-wrapper.sh
# Runs as Docker CMD main program (AFTER volume mounts in Railway).
set -e

# Resolve HERMES_HOME from s6 container environment (Railway env vars are here).
_hermes_home="/opt/data"
if [ -f /run/s6/container_environment/HERMES_HOME ]; then
    _hermes_home=$(cat /run/s6/container_environment/HERMES_HOME)
elif [ -n "${HERMES_HOME:-}" ]; then
    _hermes_home="$HERMES_HOME"
fi
export HERMES_HOME="$_hermes_home"

# If Railway injects OPENROUTER_API_KEY, remove stale .env from prior crashes.
# (dotenv loads .env with override=True which would clobber Railway's env vars)
_or_key_env="/run/s6/container_environment/OPENROUTER_API_KEY"
if [ -f "$_or_key_env" ] && [ -f "$HERMES_HOME/.env" ]; then
    echo "[main-wrapper] Railway env vars present — removing stale volume .env"
    rm -f "$HERMES_HOME/.env"
fi

# Chown HERMES_HOME after volume mount so hermes user can write to it.
if [ -d "$_hermes_home" ]; then
    chown -R hermes:hermes "$_hermes_home" 2>/dev/null || true
    echo "[main-wrapper] chowned $_hermes_home to hermes"
fi

cd "$_hermes_home"
# shellcheck disable=SC1091
. /opt/hermes/.venv/bin/activate

# Route args:
# no args → run hermes gateway (daemon mode for containers)
# executable arg → pass through directly
# other arg → hermes subcommand passthrough
if [ $# -eq 0 ]; then
    exec /command/with-contenv s6-setuidgid hermes hermes gateway
fi

if command -v "$1" >/dev/null 2>&1; then
    exec /command/with-contenv s6-setuidgid hermes "$@"
fi

exec /command/with-contenv s6-setuidgid hermes hermes "$@"
