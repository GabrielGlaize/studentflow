#!/usr/bin/env bash
set -euo pipefail

# Environnement de développement Swikko sur le Mac (voir compose.yaml).
#
#   ./scripts/dev.sh setup    vérifie les outils, crée .env avec des clés aléatoires
#   ./scripts/dev.sh up       base + API dans Docker (seedée) + Mailpit
#   ./scripts/dev.sh api      base + Mailpit dans Docker, API sur le Mac (dotnet watch)
#   ./scripts/dev.sh reset    efface la base de dev et la reseed
#   ./scripts/dev.sh down     arrête tout (les données restent)
#   ./scripts/dev.sh logs     journaux de l'API Docker
#   ./scripts/dev.sh psql     console SQL sur la base de dev
#   ./scripts/dev.sh status   état des services
#
# Le Makefile appelle ce script : `make dev`, `make dev-api`, `make dev-reset`…

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

API_URL="http://localhost:5028"
COMPOSE=(docker compose -f compose.yaml)

bold() { printf '\033[1m%s\033[0m\n' "$1"; }
step() { printf '\n\033[1m==> %s\033[0m\n' "$1"; }
fail() { printf '\033[31m%s\033[0m\n' "$1" >&2; exit 1; }

require_docker() {
  command -v docker >/dev/null || fail "Docker est introuvable : installe Docker Desktop."
  docker info >/dev/null 2>&1 || fail "Docker ne répond pas : ouvre Docker Desktop puis relance."
}

random_key() { openssl rand -base64 48 | tr -d '\n/+=' | cut -c1-64; }

ensure_env() {
  if [ ! -f .env ]; then
    step "Création de .env (clés locales aléatoires, jamais dans Git)"
    cat > .env <<EOF
# Clés de DÉVELOPPEMENT, créées par scripts/dev.sh. Fichier ignoré par Git.
Jwt__SigningKey=$(random_key)
Security__LookupKey=$(random_key)
Security__DataProtectionKeysPath=.data-protection-keys

# Facultatif : vraies offres d'alternance (voir .env.example).
# LaBonneAlternance__AccessToken=
# Adzuna__AppId=
# Adzuna__AppKey=
# FranceTravail__ClientId=
# FranceTravail__ClientSecret=
EOF
    chmod 600 .env
    return
  fi

  # .env existe. .NET ignore la casse des clés, Docker Compose non : on aligne
  # l'écriture (JWT__SigningKey → Jwt__SigningKey) sans toucher aux valeurs.
  for key in Jwt__SigningKey Security__LookupKey; do
    if ! grep -q "^$key=" .env && grep -qi "^$key=" .env; then
      sed -i '' "s/^$(grep -io "^$key" .env | head -1)=/$key=/" .env
    fi
  done

  # Puis on complète seulement les clés obligatoires manquantes.
  for key in Jwt__SigningKey Security__LookupKey; do
    if ! grep -q "^$key=." .env; then
      echo "$key=$(random_key)" >> .env
      echo "Clé $key ajoutée à .env."
    fi
  done
}

wait_for_api() {
  printf 'Attente de l’API'
  for _ in $(seq 1 90); do
    if curl -fsS -m 2 "$API_URL/api/status" >/dev/null 2>&1; then
      printf ' prête.\n'
      return 0
    fi
    printf '.'
    sleep 2
  done
  printf '\n'
  fail "L’API ne répond pas. Regarde les journaux : make dev-logs"
}

mac_ip() {
  ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true
}

summary() {
  local ip
  ip="$(mac_ip)"
  echo
  bold "Swikko · développement"
  echo "  API        $API_URL   (Swagger : $API_URL/swagger)"
  [ -n "$ip" ] && echo "  Téléphone  http://$ip:5028   (même Wi-Fi que le Mac)"
  echo "  E-mails    http://localhost:8025   (Mailpit)"
  echo "  Base       localhost:5433 · studyflow / studyflow   (make dev-psql)"
  echo
  echo "  Comptes (mot de passe Password1234!) :"
  echo "    gabriel@studyflow.dev   délégué, en entreprise, dans un groupe de projet"
  echo "    garance@ liam@ ines@ yanis@ chloe@ hugo@ sarah@studyflow.dev"
  echo "    nina@studyflow.dev      demande d’adhésion en attente"
  echo
  echo "  App : make app-dev   (appareil branché)  ·  make app-web (navigateur)"
}

setup() {
  step "Outils"
  local missing=0
  for tool in docker dotnet flutter jq curl openssl; do
    if command -v "$tool" >/dev/null; then
      printf '  ✓ %s\n' "$tool"
    else
      printf '  ✗ %s manquant\n' "$tool"
      missing=1
    fi
  done
  [ "$missing" -eq 0 ] || fail "Installe les outils manquants puis relance make setup."
  ensure_env
  mkdir -p src/backend/StudyFlow.Api/.data-protection-keys
  step "Dépendances"
  dotnet restore StudyFlow.sln --nologo -v quiet
  (cd src/app && flutter pub get >/dev/null)
  echo "Prêt. Lance : make dev"
}

up() {
  require_docker
  ensure_env
  mkdir -p src/backend/StudyFlow.Api/.data-protection-keys
  step "Base, Mailpit et API (Docker)"
  "${COMPOSE[@]}" --profile api up -d --build
  wait_for_api
  summary
}

api_on_mac() {
  require_docker
  ensure_env
  if docker ps --format '{{.Names}}' | grep -qx swikko-dev-api; then
    step "Arrêt de l’API Docker (le port 5028 passe à l’API du Mac)"
    "${COMPOSE[@]}" --profile api stop api >/dev/null
  fi
  step "Base et Mailpit (Docker)"
  "${COMPOSE[@]}" up -d --wait postgres mailpit
  summary
  step "API sur le Mac, rechargement à chaud (Ctrl+C pour arrêter)"
  exec dotnet watch --project src/backend/StudyFlow.Api run --urls http://0.0.0.0:5028
}

reset() {
  require_docker
  local api_running=false
  if docker ps --format '{{.Names}}' | grep -qx swikko-dev-api; then api_running=true; fi
  step "Effacement de la base de développement"
  "${COMPOSE[@]}" --profile api down --volumes --remove-orphans
  if [ "$api_running" = true ]; then
    up
  else
    "${COMPOSE[@]}" up -d --wait postgres mailpit
    echo "Base vide. Elle sera seedée au prochain démarrage de l’API (make dev ou make dev-api)."
  fi
}

case "${1:-}" in
  setup) setup ;;
  up) up ;;
  api) api_on_mac ;;
  reset) reset ;;
  down)
    require_docker
    "${COMPOSE[@]}" --profile api down
    ;;
  logs)
    require_docker
    "${COMPOSE[@]}" --profile api logs -f --tail 100 api
    ;;
  psql)
    require_docker
    docker exec -it swikko-dev-postgres psql -U studyflow studyflow
    ;;
  status)
    require_docker
    "${COMPOSE[@]}" --profile api ps
    if curl -fsS -m 3 "$API_URL/api/status" >/dev/null 2>&1; then
      echo "API : en ligne sur $API_URL"
    else
      echo "API : arrêtée"
    fi
    ;;
  *)
    sed -n '4,15p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
    ;;
esac
