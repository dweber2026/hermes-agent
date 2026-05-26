#!/usr/bin/env python3
"""
Seed ~/.hermes/.env from Railway environment variables.
Runs as root during s6-overlay init (cont-init.d/01-hermes-setup).
"""
import os, sys, pathlib, stat

HERMES_HOME = os.environ.get('HERMES_HOME', '/opt/data')
env_path = pathlib.Path(HERMES_HOME) / '.env'

KEYS = [
    'OPENROUTER_API_KEY',
    'OPENAI_API_KEY',
    'ANTHROPIC_API_KEY',
    'TELEGRAM_BOT_TOKEN',
    'TELEGRAM_ALLOWED_USERS',
    'TELEGRAM_HOME_CHANNEL',
    'LLM_MODEL',
]

lines = []
for key in KEYS:
    val = os.environ.get(key, '')
    if val:
        lines.append(f'{key}={val}')

if not lines:
    print('[seed-env] No Railway env vars found — skipping .env seed', flush=True)
    sys.exit(0)

env_path.parent.mkdir(parents=True, exist_ok=True)
content = '\n'.join(lines) + '\n'
env_path.write_text(content)
env_path.chmod(0o600)

try:
    import pwd, grp
    uid = pwd.getpwnam('hermes').pw_uid
    gid = grp.getgrnam('hermes').gr_gid
    os.chown(str(env_path), uid, gid)
except Exception:
    pass  # rootless container — skip chown

print(f'[seed-env] Wrote {len(lines)} keys to {env_path}', flush=True)
