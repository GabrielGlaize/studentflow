#!/usr/bin/env bash
set -euo pipefail

# Runs StudyFlow on a physical iPhone from /Users/gab/Developer/studentflow.
#
# Why this script exists:
# - iOS code signing can fail when the project lives in Documents/iCloud-like
#   locations because macOS adds resource forks or Finder metadata.
# - The script copies the project to ~/Developer without extended attributes,
#   then launches Flutter from that clean location.

SOURCE_ROOT="${STUDYFLOW_SOURCE_ROOT:-/Users/gab/Documents/studentflow}"
DEV_ROOT="${STUDYFLOW_DEV_ROOT:-/Users/gab/Developer/studentflow}"
DEVICE_ID="${STUDYFLOW_IOS_DEVICE_ID:-00008120-0009098822A2201E}"
SHOULD_SYNC=true
SHOULD_CLEAN=false

for argument in "$@"; do
  case "$argument" in
    --no-sync)
      SHOULD_SYNC=false
      ;;
    --clean)
      SHOULD_CLEAN=true
      ;;
    --device=*)
      DEVICE_ID="${argument#--device=}"
      ;;
    *)
      echo "Unknown argument: $argument"
      echo "Usage: scripts/run_iphone_developer.sh [--clean] [--no-sync] [--device=DEVICE_ID]"
      exit 1
      ;;
  esac
done

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

echo "Removing possible macOS signing metadata..."
xattr -cr "$APP_ROOT" 2>/dev/null || true

if [ -d "$HOME/development/flutter" ]; then
  xattr -cr "$HOME/development/flutter" 2>/dev/null || true
fi

if [ "$SHOULD_CLEAN" = true ]; then
  echo "Cleaning Flutter/iOS generated files..."
  flutter clean
  rm -rf build .dart_tool ios/Pods ios/Podfile.lock
fi

MAC_IP="$(ipconfig getifaddr en0 2>/dev/null || true)"
if [ -z "$MAC_IP" ]; then
  MAC_IP="$(ifconfig en0 | awk '/inet / {print $2; exit}')"
fi

if [ -z "$MAC_IP" ]; then
  echo "Could not detect Mac IP. Check Wi-Fi, then retry."
  exit 1
fi

echo "Mac IP: $MAC_IP"
echo "iPhone device: $DEVICE_ID"

flutter pub get

if [ ! -d "ios/Pods" ]; then
  echo "Installing iOS pods..."
  (cd ios && pod install)
fi

flutter run -d "$DEVICE_ID" \
  --dart-define=STUDYFLOW_API_URL="http://$MAC_IP:5028"
