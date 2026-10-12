#!/usr/bin/env bash
set -euo pipefail

# Lance Swikko sur n'importe quelle cible Flutter :
# - Android emulator / Android device
# - physical iPhone
# - Chrome
# - macOS desktop
#
# Examples:
#   ./scripts/run_app.sh --list
#   ./scripts/run_app.sh --device=emulator-5554
#   ./scripts/run_app.sh --device=chrome
#   ./scripts/run_app.sh --device=macos
#   ./scripts/run_app.sh --device=chrome --env=dev
#   ./scripts/run_app.sh --device=00008120-0009098822A2201E --env=prod --release --sync --clean
#
# Environnements (src/app/config/<env>.json) : dev par défaut (API du Mac,
# make dev), prod (API du NAS), demo (sans serveur).

SOURCE_ROOT="${STUDYFLOW_SOURCE_ROOT:-/Users/gab/Documents/studentflow}"
DEV_ROOT="${STUDYFLOW_DEV_ROOT:-/Users/gab/Developer/studentflow}"
NAS_API_URL="${STUDYFLOW_NAS_API_URL:-https://studyflow-dev.duckdns.org}"

DEVICE_ID=""
BUILD_MODE="debug"
API_URL=""
ENV_NAME="dev"
SHOULD_CLEAN=false
SHOULD_SYNC=false
SHOULD_LIST=false
USE_LOCAL_MAC=false

usage() {
  cat <<'EOF'
Usage:
  scripts/run_app.sh [options]

Options:
  --list                  Affiche les appareils Flutter disponibles.
  --device=ID             Lance sur un appareil précis: chrome, macos, emulator-5554, ID iPhone...
  --debug                 Build debug. Par défaut.
  --profile               Build profile.
  --release               Build release.
  --env=dev|prod|demo     Environnement (défaut : dev). Voir src/app/config.
  --api-url=URL           URL exacte du backend (remplace celle de l'environnement).
  --nas, --prod           Raccourcis de --env=prod.
  --local-mac             --env=dev avec l'IP du Mac (téléphone sur le même Wi-Fi).
  --clean                 Nettoie Flutter avant lancement.
  --sync                  Copie vers ~/Developer/studentflow avant lancement, utile pour iPhone.
  --no-sync               Désactive explicitement la copie.

Exemples:
  ./scripts/run_app.sh --list
  ./scripts/run_app.sh --device=emulator-5554
  ./scripts/run_app.sh --device=chrome
  ./scripts/run_app.sh --device=macos
  ./scripts/run_app.sh --device=00008120-0009098822A2201E --nas --release --sync --clean
EOF
}

detect_mac_ip() {
  local mac_ip
  mac_ip="$(ipconfig getifaddr en0 2>/dev/null || true)"
  if [ -z "$mac_ip" ]; then
    mac_ip="$(ifconfig en0 2>/dev/null | awk '/inet / {print $2; exit}')"
  fi

  if [ -z "$mac_ip" ]; then
    echo "Could not detect Mac IP. Check Wi-Fi or pass --api-url manually." >&2
    exit 1
  fi

  echo "$mac_ip"
}

looks_like_android_target() {
  case "$DEVICE_ID" in
    emulator-*|android*|*gphone*|*Android*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

looks_like_desktop_or_web_target() {
  case "$DEVICE_ID" in
    chrome|macos|linux|windows|web-server|edge)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

looks_like_ios_target() {
  if [ -z "$DEVICE_ID" ]; then
    return 1
  fi

  looks_like_android_target && return 1
  looks_like_desktop_or_web_target && return 1
  return 0
}

for argument in "$@"; do
  case "$argument" in
    --help|-h)
      usage
      exit 0
      ;;
    --list)
      SHOULD_LIST=true
      ;;
    --device=*)
      DEVICE_ID="${argument#--device=}"
      ;;
    --debug)
      BUILD_MODE="debug"
      ;;
    --profile)
      BUILD_MODE="profile"
      ;;
    --release)
      BUILD_MODE="release"
      ;;
    --api-url=*)
      API_URL="${argument#--api-url=}"
      ;;
    --env=*)
      ENV_NAME="${argument#--env=}"
      ;;
    --nas|--prod)
      ENV_NAME="prod"
      ;;
    --local-mac)
      ENV_NAME="dev"
      USE_LOCAL_MAC=true
      ;;
    --clean)
      SHOULD_CLEAN=true
      ;;
    --sync)
      SHOULD_SYNC=true
      ;;
    --no-sync)
      SHOULD_SYNC=false
      ;;
    *)
      echo "Unknown argument: $argument" >&2
      usage
      exit 1
      ;;
  esac
done

if [ "$SHOULD_LIST" = true ]; then
  (cd "$SOURCE_ROOT/src/app" && flutter devices)
  exit 0
fi

case "$ENV_NAME" in
  dev|prod|demo) ;;
  *)
    echo "Environnement inconnu : $ENV_NAME (dev, prod ou demo)." >&2
    exit 1
    ;;
esac

if [ -n "$API_URL" ] || [ "$ENV_NAME" = "demo" ]; then
  :
elif [ "$ENV_NAME" = "prod" ]; then
  API_URL="$NAS_API_URL"
elif [ "$USE_LOCAL_MAC" = true ]; then
  API_URL="http://$(detect_mac_ip):5028"
elif [ -z "$API_URL" ] && [ -n "$DEVICE_ID" ]; then
  if looks_like_android_target; then
    API_URL="http://10.0.2.2:5028"
  elif looks_like_desktop_or_web_target; then
    API_URL="http://localhost:5028"
  elif looks_like_ios_target; then
    API_URL="http://$(detect_mac_ip):5028"
  fi
fi

RUN_ROOT="$SOURCE_ROOT"

if [ "$SHOULD_SYNC" = true ]; then
  echo "Syncing project to $DEV_ROOT without macOS extended attributes..."
  mkdir -p "$(dirname "$DEV_ROOT")"

  rsync -a --delete \
    --exclude ".git/" \
    --exclude ".dart_tool/" \
    --exclude ".dotnet-home/" \
    --exclude ".dotnet-sdk/" \
    --exclude ".data-protection-keys/" \
    --exclude "src/app/.dart_tool/" \
    --exclude "src/app/build/" \
    --exclude "src/app/ios/Pods/" \
    --exclude "src/app/ios/.symlinks/" \
    "$SOURCE_ROOT/" \
    "$DEV_ROOT/"

  RUN_ROOT="$DEV_ROOT"
fi

APP_ROOT="$RUN_ROOT/src/app"
cd "$APP_ROOT"

if command -v xattr >/dev/null 2>&1; then
  echo "Removing possible macOS signing metadata..."
  xattr -cr "$APP_ROOT" 2>/dev/null || true

  if [ -d "$HOME/development/flutter" ]; then
    xattr -cr "$HOME/development/flutter" 2>/dev/null || true
  fi
fi

if [ "$SHOULD_CLEAN" = true ]; then
  echo "Cleaning Flutter generated files..."
  flutter clean
  rm -rf build .dart_tool ios/Pods ios/Podfile.lock
fi

echo "Flutter target: ${DEVICE_ID:-interactive selection}"
echo "Build mode: $BUILD_MODE"
echo "Environnement: $ENV_NAME"
echo "API URL: ${API_URL:-Flutter default}"
echo "Project root: $RUN_ROOT"

flutter pub get

if looks_like_ios_target && [ ! -d "ios/Pods" ]; then
  echo "Installing iOS pods..."
  (cd ios && pod install)
fi

COMMAND=(flutter run "--$BUILD_MODE" "--dart-define-from-file=config/$ENV_NAME.json")

# Port fixe pour le web : l'API n'autorise que des origines connues (CORS).
if [ "$DEVICE_ID" = "chrome" ] || [ "$DEVICE_ID" = "web-server" ]; then
  COMMAND+=(--web-port=8080)
fi

if [ -n "$DEVICE_ID" ]; then
  COMMAND+=(-d "$DEVICE_ID")
fi

# Identifiants Firebase (notifications push), fichier local ignoré par Git.
if [ -f "firebase_config.json" ]; then
  COMMAND+=(--dart-define-from-file=firebase_config.json)
fi

if [ -n "$API_URL" ]; then
  COMMAND+=(--dart-define=STUDYFLOW_API_URL="$API_URL")
fi

echo "Running: ${COMMAND[*]}"
"${COMMAND[@]}"
