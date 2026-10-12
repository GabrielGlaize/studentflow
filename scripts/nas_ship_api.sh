#!/usr/bin/env bash
set -euo pipefail

# Déploie l'API sur le NAS SANS compiler sur le NAS (1,8 Go de RAM partagés).
#
# Sur le Mac : publication .NET, image Docker linux/amd64 « runtime seul »,
# archive copiée dans le dossier personnel du NAS avec un script d'installation.
# Sur le NAS (une commande, mot de passe sudo demandé) : sauvegarde de la base,
# chargement de l'image, redémarrage du seul conteneur api. Les migrations
# s'appliquent au démarrage de l'API.
#
# Usage :
#   ./scripts/nas_ship_api.sh
#   STUDYFLOW_NAS_HOST=Gabriel@192.168.1.14 ./scripts/nas_ship_api.sh
#
# Variables :
#   STUDYFLOW_NAS_HOST     utilisateur@hôte SSH (défaut : Gabriel@192.168.1.14)
#   STUDYFLOW_NAS_SSH_KEY  clé SSH (défaut : ~/.ssh/id_ed25519_gabriel_nas)
#   STUDYFLOW_NAS_DIR      dossier du projet sur le NAS (défaut : /volume1/docker/studyflow)

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NAS_HOST="${STUDYFLOW_NAS_HOST:-Gabriel@192.168.1.14}"
NAS_KEY="${STUDYFLOW_NAS_SSH_KEY:-$HOME/.ssh/id_ed25519_gabriel_nas}"
NAS_DIR="${STUDYFLOW_NAS_DIR:-/volume1/docker/studyflow}"
BUILD_DIR="$PROJECT_ROOT/build/nas-api"
IMAGE="studyflow-api:nas"
ARCHIVE="studyflow-api.tar.gz"
INSTALLER="studyflow_install_api.sh"
SSH_OPTS=(-i "$NAS_KEY" -o ConnectTimeout=8)

step() { printf '\n\033[1m==> %s\033[0m\n' "$1"; }

command -v docker >/dev/null || { echo "Docker est introuvable : lance Docker Desktop."; exit 1; }
docker info >/dev/null 2>&1 || { echo "Docker ne répond pas : ouvre Docker Desktop puis relance."; exit 1; }

step "Connexion au NAS ($NAS_HOST)"
if ! ssh "${SSH_OPTS[@]}" -o BatchMode=yes "$NAS_HOST" true 2>/dev/null; then
  echo "NAS injoignable. Le Mac doit être sur le Wi-Fi de la maison (192.168.1.x)."
  exit 1
fi

step "Publication de l'API (.NET, Release)"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
dotnet publish "$PROJECT_ROOT/src/backend/StudyFlow.Api/StudyFlow.Api.csproj" \
  --configuration Release \
  --output "$BUILD_DIR/publish" \
  /p:UseAppHost=false \
  --nologo -v quiet

cat > "$BUILD_DIR/Dockerfile" <<'DOCKERFILE'
FROM mcr.microsoft.com/dotnet/aspnet:8.0-alpine
WORKDIR /app
# Fuseaux horaires : l'API calcule les cours et rappels en heure de Paris.
RUN apk add --no-cache tzdata
ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080
COPY publish/ .
ENTRYPOINT ["dotnet", "StudyFlow.Api.dll"]
DOCKERFILE

step "Image Docker linux/amd64 ($IMAGE)"
docker buildx build --platform linux/amd64 --tag "$IMAGE" --load "$BUILD_DIR"
docker save "$IMAGE" | gzip > "$BUILD_DIR/$ARCHIVE"
echo "Archive : $(du -h "$BUILD_DIR/$ARCHIVE" | cut -f1)"

cat > "$BUILD_DIR/$INSTALLER" <<INSTALL
#!/bin/sh
# Installé par scripts/nas_ship_api.sh : à lancer avec sudo sur le NAS.
set -eu
cd "$NAS_DIR"
mkdir -p backups
STAMP=\$(date +%Y%m%d-%H%M%S)
echo "==> Sauvegarde de la base (backups/studyflow-\$STAMP.sql.gz)"
docker exec studyflow-nas-postgres sh -c 'pg_dump -U "\$POSTGRES_USER" "\$POSTGRES_DB"' | gzip > "backups/studyflow-\$STAMP.sql.gz"
echo "==> Chargement de l'image"
gunzip -c "\$HOME_DIR/$ARCHIVE" | docker load
echo "==> Redémarrage de l'API (migrations appliquées au démarrage)"
docker compose --env-file .env.nas -f compose.nas.yaml up -d --no-build api
sleep 8
docker compose --env-file .env.nas -f compose.nas.yaml ps api
PORT=\$(awk -F= '\$1 == "STUDYFLOW_API_PORT" {print \$2}' .env.nas | tail -n 1)
curl -fsS "http://localhost:\${PORT:-5028}/api/status" && echo && echo "API à jour."
rm -f "\$HOME_DIR/$ARCHIVE"
INSTALL
# Le dossier personnel de l'utilisateur SSH, figé ici : sous sudo, \$HOME devient celui de root.
NAS_HOME="$(ssh "${SSH_OPTS[@]}" "$NAS_HOST" 'printf %s "$HOME"')"
sed -i '' "s#\\\$HOME_DIR#$NAS_HOME#g" "$BUILD_DIR/$INSTALLER"

step "Copie vers le NAS"
# rsync est refusé par Synology pour cet utilisateur : on passe par cat sur SSH.
ssh "${SSH_OPTS[@]}" "$NAS_HOST" "cat > '$NAS_HOME/$ARCHIVE'" < "$BUILD_DIR/$ARCHIVE"
ssh "${SSH_OPTS[@]}" "$NAS_HOST" "cat > '$NAS_HOME/$INSTALLER'" < "$BUILD_DIR/$INSTALLER"

step "Dernière étape, sur le NAS"
echo "Lance cette commande (mot de passe sudo du NAS demandé) :"
echo
echo "  ssh -t -i $NAS_KEY $NAS_HOST 'sudo sh $NAS_HOME/$INSTALLER'"
echo
echo "Depuis Claude Code : tape ! devant la commande."
