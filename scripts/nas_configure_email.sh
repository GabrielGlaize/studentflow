#!/usr/bin/env bash
set -euo pipefail

# Configure l'envoi des e-mails de réinitialisation de mot de passe (SMTP).
# À lancer SUR LE NAS, à la racine du projet :
#   ./scripts/nas_configure_email.sh
#
# Par défaut : Gmail avec un « mot de passe d'application » (16 lettres),
# créé sur https://myaccount.google.com/apppasswords (la validation en deux
# étapes doit être activée sur le compte Google).
# Le mot de passe est saisi en masqué et écrit seulement dans .env.nas
# (ignoré par Git), puis l'API est relancée.

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

ENV_FILE=".env.nas"
if [ ! -f "$ENV_FILE" ]; then
  echo "Fichier $ENV_FILE introuvable : lance d'abord ./scripts/nas_generate_env.sh"
  exit 1
fi

read -r -p "Adresse Gmail qui enverra les e-mails : " EMAIL_ADDRESS
if [[ "$EMAIL_ADDRESS" != *@* ]]; then
  echo "Adresse invalide."
  exit 1
fi

read -r -s -p "Mot de passe d'application Google (16 lettres, espaces acceptés) : " APP_PASSWORD
echo
APP_PASSWORD="${APP_PASSWORD// /}"
if [ ${#APP_PASSWORD} -lt 16 ]; then
  echo "Ce mot de passe semble trop court : utilise un mot de passe d'application, pas celui du compte."
  exit 1
fi

read -r -p "Serveur SMTP [smtp.gmail.com] : " SMTP_HOST
SMTP_HOST="${SMTP_HOST:-smtp.gmail.com}"
read -r -p "Port SMTP [587] : " SMTP_PORT
SMTP_PORT="${SMTP_PORT:-587}"

# Sauvegarde, puis remplacement des anciennes valeurs e-mail éventuelles.
cp "$ENV_FILE" "$ENV_FILE.backup-$(date +%Y%m%d-%H%M%S)"
TMP_FILE="$(mktemp)"
grep -v '^STUDYFLOW_EMAIL_' "$ENV_FILE" > "$TMP_FILE" || true
{
  echo
  echo "# E-mails de réinitialisation de mot de passe (configurés le $(date +%d/%m/%Y))."
  echo "STUDYFLOW_EMAIL_FROM=StudyFlow <$EMAIL_ADDRESS>"
  echo "STUDYFLOW_EMAIL_HOST=$SMTP_HOST"
  echo "STUDYFLOW_EMAIL_PORT=$SMTP_PORT"
  echo "STUDYFLOW_EMAIL_USE_SSL=true"
  echo "STUDYFLOW_EMAIL_USERNAME=$EMAIL_ADDRESS"
  echo "STUDYFLOW_EMAIL_PASSWORD=$APP_PASSWORD"
} >> "$TMP_FILE"
mv "$TMP_FILE" "$ENV_FILE"
chmod 600 "$ENV_FILE"
echo "Configuration e-mail enregistrée dans $ENV_FILE."

echo "Relance de l'API..."
docker compose --env-file "$ENV_FILE" -f compose.nas.yaml up -d --build api

API_PORT="$(awk -F= '$1 == "STUDYFLOW_API_PORT" {print $2}' "$ENV_FILE" | tail -n 1)"
API_PORT="${API_PORT:-5028}"
for _ in $(seq 1 30); do
  if curl -fsS "http://localhost:$API_PORT/api/status" > /dev/null 2>&1; then break; fi
  sleep 2
done

echo
read -r -p "Adresse d'un compte StudyFlow pour un e-mail de test (vide pour passer) : " TEST_EMAIL
if [ -n "$TEST_EMAIL" ]; then
  if curl -fsS -X POST "http://localhost:$API_PORT/api/v1/auth/forgot-password" \
    -H 'Content-Type: application/json' \
    -d "{\"email\":\"$TEST_EMAIL\"}" > /dev/null; then
    echo "E-mail envoyé. Regarde la boîte de $TEST_EMAIL (et les spams)."
  else
    echo "L'envoi a échoué : mot de passe d'application ou adresse sans doute incorrects."
    echo "Relance ce script pour corriger. Détail de l'erreur :"
    docker compose --env-file "$ENV_FILE" -f compose.nas.yaml logs --tail 30 api | grep -i -A3 "smtp\|mail" || true
  fi
fi
