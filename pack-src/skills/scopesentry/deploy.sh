#!/usr/bin/env bash
# deploy.sh — optional, agent-assisted single-host deployment of ScopeSentry
# on macOS / Linux (the Windows twin is deploy.ps1).
#
# Run ONLY when the operator explicitly asks to deploy ScopeSentry. Starts
# Docker if it can, clones the official repository, writes local credentials,
# brings up the four containers, and waits for the Web UI. Writes files only
# inside its own install directory and never installs Docker itself — but it
# may start the Docker engine (Docker.app on macOS) to bring it up.
#
# Usage:
#   ./deploy.sh
#   ./deploy.sh -i ~/scopesentry -t 300
#   ./deploy.sh -r <tag-or-commit>   # pinned upstream version

set -euo pipefail

INSTALL_DIR="$HOME/scopesentry"
HEALTH_TIMEOUT=300
REF=""

while getopts "i:t:r:" opt; do
  case "$opt" in
    i) INSTALL_DIR="$OPTARG" ;;
    t) HEALTH_TIMEOUT="$OPTARG" ;;
    r) REF="$OPTARG" ;;
    *) echo "usage: $0 [-i install-dir] [-t health-timeout-sec] [-r ref]"; exit 2 ;;
  esac
done

say() { printf '[scopesentry-deploy] %s\n' "$*"; }

# 1. Docker engine: check; on macOS try to open Docker Desktop, on Linux just
#    report. We do not install Docker.
if ! command -v docker >/dev/null 2>&1; then
  echo "docker CLI not found. Install Docker Desktop / Docker Engine first, then rerun." >&2
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  case "$(uname -s)" in
    Darwin)
      say "Docker engine stopped; opening Docker.app, waiting up to 90s..."
      open -a Docker || true
      deadline=$(( $(date +%s) + 90 ))
      until docker info >/dev/null 2>&1 || [ "$(date +%s)" -ge "$deadline" ]; do
        sleep 5
      done
      ;;
    *)
      echo "Docker engine is not reachable. Start the Docker daemon (systemctl start docker / Docker Desktop) and rerun." >&2
      exit 1
      ;;
  esac
fi

if ! docker info >/dev/null 2>&1; then
  echo "Docker engine still unreachable; start it manually and rerun." >&2
  exit 1
fi
say "Docker engine OK."

# 2. Repository: clone once, pull afterwards. With -r the upstream version is
#    pinned (tag or commit); without it we clone the default branch and say so.
#    Either way the exact deployed revision is recorded for reproducibility.
REPO="$INSTALL_DIR/ScopeSentry"
if [ ! -d "$REPO" ]; then
  mkdir -p "$INSTALL_DIR"
  if [ -n "$REF" ]; then
    say "Cloning https://github.com/Autumn-27/ScopeSentry into $REPO (pinned ref: $REF) ..."
    git clone --branch "$REF" https://github.com/Autumn-27/ScopeSentry.git "$REPO"
  else
    say "Cloning https://github.com/Autumn-27/ScopeSentry into $REPO (no -r: default branch, NOT version-pinned) ..."
    git clone https://github.com/Autumn-27/ScopeSentry.git "$REPO"
  fi
else
  say "Reusing existing checkout at $REPO (git pull)."
  (cd "$REPO" && git pull)
fi
git -C "$REPO" rev-parse HEAD > "$INSTALL_DIR/clone-revision.txt"
say "Recorded deployed revision $(cat "$INSTALL_DIR/clone-revision.txt")"

# 3. Local credentials: write .env once, never overwrite an existing one.
ENV_FILE="$REPO/.env"
if [ ! -f "$ENV_FILE" ]; then
  gen_pw() {
    if command -v openssl >/dev/null 2>&1; then openssl rand -base64 24 | tr -d '/+=' ; else head -c 24 /dev/urandom | od -An -tx1 | tr -d ' \n'; fi
  }
  MONGO_PASS="$(gen_pw)"
  REDIS_PASS="$(gen_pw)"
  {
    echo "MONGO_INITDB_ROOT_USERNAME=root"
    echo "MONGO_INITDB_ROOT_PASSWORD=$MONGO_PASS"
    echo "REDIS_PASSWORD=$REDIS_PASS"
  } > "$ENV_FILE"
  say "Wrote $ENV_FILE with generated passwords (existing values are never overwritten)."
else
  say "$ENV_FILE exists; keeping it."
fi

# 4. Bring up the four containers (web, scan, mongo, redis).
COMPOSE="$REPO/single-host-deployment.yml"
[ -f "$COMPOSE" ] || { echo "Missing $COMPOSE" >&2; exit 1; }
say "Starting containers (first pull downloads ~1.15 GB; this can take a while)..."
if docker compose version >/dev/null 2>&1; then
  docker compose -f "$COMPOSE" up -d
else
  docker-compose -f "$COMPOSE" up -d
fi

# 5. Wait for the Web UI; MongoDB initialization with bundled data is slow.
say "Waiting for http://127.0.0.1:8082 (MongoDB init may take minutes)..."
deadline=$(( $(date +%s) + HEALTH_TIMEOUT ))
ready=0
while [ "$(date +%s)" -lt "$deadline" ]; do
  if curl -sf -o /dev/null --max-time 5 http://127.0.0.1:8082; then ready=1; break; fi
  sleep 10
done

if [ "$ready" -ne 1 ]; then
  echo "Web UI did not answer within ${HEALTH_TIMEOUT}s. Check: docker compose -f \"$COMPOSE\" logs." >&2
  exit 1
fi

say "Web UI reachable at http://127.0.0.1:8082 (default login ScopeSentry/ScopeSentry; change it)."
say "NEXT: sign in, open the API Key page, create an ssk_... key, then set:"
say "  export SS_BASE_URL='http://127.0.0.1:8082'"
say "  export SS_API_KEY='ssk_...'"
say "Verify with: node <skill-dir>/ssclient.js health"
