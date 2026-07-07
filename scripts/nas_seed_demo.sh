#!/usr/bin/env bash
set -euo pipefail

# Runs the StudyFlow demo seeder once against the NAS PostgreSQL database.
# Use --reset only when you want a fresh demo database.

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

if [ ! -f ".env.nas" ]; then
  echo "Missing .env.nas."
  echo "Create one with:"
  echo "  ./scripts/nas_generate_env.sh"
  exit 1
fi

RESET_ON_STARTUP=false
if [ "${1:-}" = "--reset" ]; then
  RESET_ON_STARTUP=true
elif [ "${1:-}" != "" ]; then
  echo "Usage: ./scripts/nas_seed_demo.sh [--reset]"
  exit 1
fi

docker compose --env-file .env.nas -f compose.nas.yaml run --rm \
  -e DevelopmentSeed__ResetOnStartup="$RESET_ON_STARTUP" \
  api \
  --seed-development-data

echo
echo "Demo seed complete."
echo "Accounts:"
echo "  gabriel@studyflow.dev / Password1234!"
echo "  garance@studyflow.dev / Password1234!"
echo "  liam@studyflow.dev / Password1234!"
echo "  nina@studyflow.dev / Password1234! (pending class request)"
