#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
root="$PWD"
out="${1:-$root/dist}"
cache="${SPEAK_LOW_MODEL_CACHE:-${OPTIONVOICE_MODEL_CACHE:-$root/.model-cache}}"
mkdir -p "$out"
out="$(cd "$out" && pwd)"
stage="$(mktemp -d "$out/.speak-low-build.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
app="$stage/speak-low.app"
resources="$app/Contents/Resources"
mkdir -p "$app/Contents/MacOS" "$resources" "$stage/Icon.iconset"
swift build -c release --product speak-low
python3 scripts/fetch-model.py "$cache"
cp "$root/.build/release/speak-low" "$app/Contents/MacOS/"
cp Resources/Info.plist "$app/Contents/"
ditto "$cache" "$resources/Whisper"
ditto Resources/Licenses "$resources/Licenses"
swift scripts/make-icon.swift "$stage/Icon.iconset"
iconutil -c icns "$stage/Icon.iconset" -o "$resources/speak-low.icns"
codesign --force --sign "${SPEAK_LOW_SIGN_IDENTITY:-${OPTIONVOICE_SIGN_IDENTITY:--}}" "$app"
codesign --verify --strict --deep "$app"
if [[ -e "$out/speak-low.app" ]]; then
    mv "$out/speak-low.app" "$stage/previous.app"
fi
if ! mv "$app" "$out/speak-low.app"; then
    if [[ -d "$stage/previous.app" ]]; then mv "$stage/previous.app" "$out/speak-low.app"; fi
    exit 1
fi
echo "$out/speak-low.app"
