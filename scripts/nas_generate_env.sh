#!/usr/bin/env bash
set -euo pipefail

# Creates a local .env.nas file with random development/NAS secrets.
# The generated file is intentionally ignored by Git.

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_FILE="$PROJECT_ROOT/.env.nas"

if [ -f "$TARGET_FILE" ]; then
  echo ".env.nas already exists:"
  echo "$TARGET_FILE"
  echo "Delete it manually first if you really want to regenerate secrets."
  exit 1
fi

random_secret() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -base64 48 | tr -d '\n'
  else
    od -An -tx1 -N48 /dev/urandom | tr -d ' \n'
  fi
}

POSTGRES_PASSWORD="$(random_secret)"
JWT_SIGNING_KEY="$(random_secret)"
LOOKUP_KEY="$(random_secret)"

cat >"$TARGET_FILE" <<EOF
STUDYFLOW_POSTGRES_DB=studyflow
STUDYFLOW_POSTGRES_USER=studyflow
STUDYFLOW_POSTGRES_PASSWORD=$POSTGRES_PASSWORD

STUDYFLOW_JWT_SIGNING_KEY=$JWT_SIGNING_KEY
STUDYFLOW_SECURITY_LOOKUP_KEY=$LOOKUP_KEY

# Port exposed by the NAS on the local network.
STUDYFLOW_API_PORT=5028

# Replace with your final HTTPS origin if you expose the API through a reverse proxy.
# For a first local NAS test, you can keep this value.
STUDYFLOW_CORS_ORIGIN=http://localhost:8080

# Optional alternance providers. Leave empty to keep demo fallback where supported.
ADZUNA_APP_ID=
ADZUNA_APP_KEY=
FRANCE_TRAVAIL_CLIENT_ID=
FRANCE_TRAVAIL_CLIENT_SECRET=
# Notifications push Firebase. Copier la clé du compte de service dans ./secrets/
# (jamais dans Git) puis indiquer son chemin vu depuis le conteneur.
# Laisser vide pour désactiver l'envoi réel.
STUDYFLOW_FIREBASE_CREDENTIALS_PATH=/run/secrets/studyflow/firebase-adminsdk.json
STUDYFLOW_NOTIFICATIONS_ENABLED=true
EOF

chmod 600 "$TARGET_FILE"

echo "Created $TARGET_FILE"
echo "Keep this file private. It contains passwords and signing keys."
