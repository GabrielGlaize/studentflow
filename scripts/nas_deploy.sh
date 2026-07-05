#!/usr/bin/env bash
set -euo pipefail

# Builds and starts the NAS stack from the project root.
# Requires Docker Compose and a local .env.nas file.

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

if [ ! -f ".env.nas" ]; then
  echo "Missing .env.nas."
  echo "Create one with:"
  echo "  ./scripts/nas_generate_env.sh"
  echo "Then edit STUDYFLOW_CORS_ORIGIN if you expose the API with HTTPS."
  exit 1
fi

docker compose --env-file .env.nas -f compose.nas.yaml up -d --build
docker compose --env-file .env.nas -f compose.nas.yaml ps

API_PORT="$(awk -F= '$1 == "STUDYFLOW_API_PORT" {print $2}' .env.nas | tail -n 1)"
API_PORT="${API_PORT:-5028}"

echo
echo "API status check from this machine:"
echo "  curl http://localhost:$API_PORT/api/status"

if command -v curl >/dev/null 2>&1; then
  curl -fsS "http://localhost:$API_PORT/api/status" || true
  echo
fi
