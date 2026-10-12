#!/usr/bin/env bash
set -euo pipefail

# Installe Swikko sur un appareil iOS ou Android branché au Mac.
#
# - Without --device, the script lists the iPhone, iPad and Android devices
#   seen by Flutter and asks which one to use. If only one is connected, it is
#   picked automatically.
# - iOS code signing can fail when the project lives in Documents/iCloud-like
#   locations because macOS adds resource forks or Finder metadata. The script
#   copies the project to ~/Developer without extended attributes, then
#   launches Flutter from that clean location.
# - --env choisit l'environnement (src/app/config/<env>.json) :
#     prod (défaut) : API du NAS ;
#     dev           : API du Mac (make dev) : IP du Mac pour un appareil physique,
#                     10.0.2.2 pour l'émulateur Android, localhost pour le simulateur iOS ;
#     demo          : sans serveur, données fictives.

SOURCE_ROOT="${STUDYFLOW_SOURCE_ROOT:-/Users/gab/Documents/studentflow}"
DEV_ROOT="${STUDYFLOW_DEV_ROOT:-/Users/gab/Developer/studentflow}"
NAS_API_URL="${STUDYFLOW_NAS_API_URL:-https://studyflow-dev.duckdns.org}"
DEVICE_QUERY="${STUDYFLOW_DEVICE_ID:-}"
SHOULD_SYNC=true
SHOULD_CLEAN=false
SHOULD_LIST=false
ENV_NAME="prod"
BUILD_MODE="debug"
API_URL=""

usage() {
  cat <<'EOF'
Usage:
  scripts/install_app.sh [options]

Options:
  --list                  Affiche les appareils iOS/Android connectés.
  --device=ID|NOM         Appareil cible : ID exact ou partie du nom (ex. ipad,
                          pixel). Sans cette option, un menu demande lequel.
  --debug                 Build debug. Par défaut.
  --profile               Build profile.
  --release               Build release (app autonome, débranchable ensuite).
  --env=dev|prod|demo     Environnement (défaut : prod). Voir src/app/config.
  --api-url=URL           URL exacte du backend (remplace celle de l'environnement).
  --local-mac             Raccourci de --env=dev.
  --clean                Nettoie Flutter avant lancement.
  --no-sync               Lance depuis ~/Developer/studentflow sans recopier.

Exemples:
  ./scripts/install_app.sh
  ./scripts/install_app.sh --env=dev
  ./scripts/install_app.sh --list
  ./scripts/install_app.sh --device=ipad --release
  ./scripts/install_app.sh --device=00008120-0009098822A2201E --clean --release
EOF
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
    --no-sync)
      SHOULD_SYNC=false
      ;;
    --clean)
      SHOULD_CLEAN=true
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
    --local-mac)
      ENV_NAME="dev"
      ;;
    --env=*)
      ENV_NAME="${argument#--env=}"
      ;;
    --device=*)
      DEVICE_QUERY="${argument#--device=}"
      ;;
    *)
      echo "Unknown argument: $argument" >&2
      usage
      exit 1
      ;;
  esac
done

case "$ENV_NAME" in
  dev|prod|demo) ;;
  *)
    echo "Environnement inconnu : $ENV_NAME (dev, prod ou demo)." >&2
    exit 1
    ;;
esac

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

to_lower() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

# One line per supported iOS/Android device: id, platform, kind, name, sdk.
list_mobile_devices() {
  flutter devices --machine 2>/dev/null | jq -r '
    .[]
    | select(.isSupported and (.targetPlatform | test("^(ios|android)")))
    | [
        .id,
        (if (.targetPlatform | startswith("ios")) then "ios" else "android" end),
        (if .emulator then "emulator" else "physical" end),
        .name,
        (.sdk // "")
      ]
    | @tsv'
}

device_label() {
  local index="$1"
  local platform="iOS"
  local kind=""

  if [ "${DEVICE_PLATFORMS[$index]}" = "android" ]; then
    platform="Android"
  fi

  if [ "${DEVICE_KINDS[$index]}" = "emulator" ]; then
    if [ "$platform" = "iOS" ]; then
      kind=" (simulateur)"
    else
      kind=" (émulateur)"
    fi
  fi

  echo "[$platform] ${DEVICE_NAMES[$index]}$kind · ${DEVICE_SDKS[$index]} · ${DEVICE_IDS[$index]}"
}

echo "Recherche des appareils iOS/Android connectés..."

if ! DEVICES_TSV="$(list_mobile_devices)"; then
  echo "Impossible de lister les appareils avec 'flutter devices'." >&2
  exit 1
fi

DEVICE_IDS=()
DEVICE_PLATFORMS=()
DEVICE_KINDS=()
DEVICE_NAMES=()
DEVICE_SDKS=()

while IFS=$'\t' read -r id platform kind name sdk; do
  [ -n "$id" ] || continue
  DEVICE_IDS+=("$id")
  DEVICE_PLATFORMS+=("$platform")
  DEVICE_KINDS+=("$kind")
  DEVICE_NAMES+=("$name")
  DEVICE_SDKS+=("$sdk")
done <<EOF
$DEVICES_TSV
EOF

if [ "$SHOULD_LIST" = true ]; then
  if [ "${#DEVICE_IDS[@]}" -eq 0 ]; then
    echo "Aucun appareil iOS/Android détecté."
  fi

  index=0
  while [ "$index" -lt "${#DEVICE_IDS[@]}" ]; do
    echo "  $(device_label "$index")"
    index=$((index + 1))
  done
  exit 0
fi

# Indexes of the devices the user can choose from.
CANDIDATES=()
index=0
while [ "$index" -lt "${#DEVICE_IDS[@]}" ]; do
  if [ -z "$DEVICE_QUERY" ]; then
    CANDIDATES+=("$index")
  elif [ "${DEVICE_IDS[$index]}" = "$DEVICE_QUERY" ]; then
    CANDIDATES=("$index")
    break
  else
    case "$(to_lower "${DEVICE_NAMES[$index]}")" in
      *"$(to_lower "$DEVICE_QUERY")"*)
        CANDIDATES+=("$index")
        ;;
    esac
  fi
  index=$((index + 1))
done

if [ "${#CANDIDATES[@]}" -eq 0 ]; then
  if [ -n "$DEVICE_QUERY" ]; then
    echo "Aucun appareil iOS/Android ne correspond à '$DEVICE_QUERY'." >&2
    echo "Liste les appareils avec: ./scripts/install_app.sh --list" >&2
  else
    echo "Aucun appareil iOS/Android détecté." >&2
    echo "- iPhone/iPad : branche-le, déverrouille-le, fais 'Se fier à cet ordinateur' et active le mode développeur." >&2
    echo "- Android : active le débogage USB et accepte l'empreinte du Mac sur le téléphone." >&2
    echo "Diagnostic complet: flutter doctor" >&2
  fi
  exit 1
fi

if [ "${#CANDIDATES[@]}" -eq 1 ]; then
  SELECTED="${CANDIDATES[0]}"
else
  if [ ! -t 0 ]; then
    echo "Plusieurs appareils correspondent ; précise-le avec --device=ID." >&2
    exit 1
  fi

  echo "Appareils disponibles :"
  position=1
  for candidate in "${CANDIDATES[@]}"; do
    echo "  $position) $(device_label "$candidate")"
    position=$((position + 1))
  done

  while true; do
    if ! read -r -p "Sur quel appareil installer Swikko ? [1-${#CANDIDATES[@]}, q pour quitter] " choice; then
      echo
      exit 1
    fi
    case "$choice" in
      q|Q)
        exit 0
        ;;
      ''|*[!0-9]*)
        ;;
      *)
        if [ "$choice" -ge 1 ] && [ "$choice" -le "${#CANDIDATES[@]}" ]; then
          SELECTED="${CANDIDATES[$((choice - 1))]}"
          break
        fi
        ;;
    esac
    echo "Choix invalide."
  done
fi

DEVICE_ID="${DEVICE_IDS[$SELECTED]}"
DEVICE_PLATFORM="${DEVICE_PLATFORMS[$SELECTED]}"
DEVICE_KIND="${DEVICE_KINDS[$SELECTED]}"

if [ -n "$API_URL" ] || [ "$ENV_NAME" = "demo" ]; then
  :
elif [ "$ENV_NAME" = "prod" ]; then
  API_URL="$NAS_API_URL"
else
  case "$DEVICE_PLATFORM:$DEVICE_KIND" in
    android:emulator)
      API_URL="http://10.0.2.2:5028"
      ;;
    ios:emulator)
      API_URL="http://localhost:5028"
      ;;
    *)
      API_URL="http://$(detect_mac_ip):5028"
      ;;
  esac
fi

# Checks the API from the Mac before the long build. 10.0.2.2 is the Mac seen
# from the Android emulator, so it is checked through localhost.
STATUS_URL="${API_URL%/}/api/status"
STATUS_URL="${STATUS_URL/10.0.2.2/localhost}"
if [ -n "$API_URL" ] && ! curl -fsS -m 5 "$STATUS_URL" >/dev/null 2>&1; then
  echo "Attention : l'API ne répond pas sur $STATUS_URL." >&2
  echo "L'app affichera 'impossible de joindre le serveur'." >&2
  if [ "$ENV_NAME" = "dev" ]; then
    echo "Lance l'environnement de dev : make dev" >&2
  else
    echo "Vérifie que l'API du NAS tourne, ou utilise --env=dev / --api-url=URL." >&2
  fi

  if [ -t 0 ]; then
    if ! read -r -p "Installer quand même ? [o/N] " answer; then
      echo
      exit 1
    fi
    case "$answer" in
      o|O|oui|y|Y)
        ;;
      *)
        exit 1
        ;;
    esac
  fi
fi

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
fi

APP_ROOT="$DEV_ROOT/src/app"
cd "$APP_ROOT"

if [ "$DEVICE_PLATFORM" = "ios" ]; then
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

echo "Device: $(device_label "$SELECTED")"
echo "Environnement: $ENV_NAME"
echo "Build mode: $BUILD_MODE"
echo "API URL: ${API_URL:-aucune (démo)}"

flutter pub get

if [ "$DEVICE_PLATFORM" = "ios" ] && [ ! -d "ios/Pods" ]; then
  echo "Installing iOS pods..."
  (cd ios && pod install)
fi

COMMAND=(flutter run "--$BUILD_MODE" -d "$DEVICE_ID" "--dart-define-from-file=config/$ENV_NAME.json")

# Identifiants Firebase (notifications push Android), fichier local ignoré par Git.
if [ -f "firebase_config.json" ]; then
  COMMAND+=(--dart-define-from-file=firebase_config.json)
fi

if [ -n "$API_URL" ]; then
  COMMAND+=(--dart-define=STUDYFLOW_API_URL="$API_URL")
fi

echo "Running: ${COMMAND[*]}"
"${COMMAND[@]}"
