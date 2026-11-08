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
revision="${SPEAK_LOW_BUILD_REVISION:-}"
if [[ -z "$revision" && "$(git rev-parse --show-toplevel 2>/dev/null || true)" == "$root" ]]; then
    revision="$(git rev-parse HEAD)"
    if [[ -n "$(git status --porcelain --untracked-files=normal)" ]]; then revision="$revision-dirty"; fi
fi
if [[ -n "$revision" ]]; then
    /usr/bin/plutil -insert SpeakLowRevision -string "$revision" "$app/Contents/Info.plist"
fi
identity="${SPEAK_LOW_SIGN_IDENTITY:-${OPTIONVOICE_SIGN_IDENTITY:--}}"
if [[ "$identity" != "-" ]]; then
    /usr/bin/plutil -insert SpeakLowSigningIdentity -string "$identity" "$app/Contents/Info.plist"
fi
cp scripts/update.py "$resources/"
ditto "$cache" "$resources/Whisper"
ditto Resources/Licenses "$resources/Licenses"
ditto Resources/Sounds "$resources/Sounds"
mkdir -p "$resources/Brand"
cp Resources/Brand/speak-low.svg "$resources/Brand/"
swift scripts/make-icon.swift "$stage/Icon.iconset" "$resources/Brand"
iconutil -c icns "$stage/Icon.iconset" -o "$resources/speak-low.icns"
codesign --force --sign "$identity" "$app"
codesign --verify --strict --deep "$app"
# Staging in the target directory keeps both bundles on the same volume.
# An exchange leaves the current app intact if the update is interrupted.
swift - "$app" "$out/speak-low.app" <<'SWIFT'
import Darwin

let staged = CommandLine.arguments[1]
let destination = CommandLine.arguments[2]
if renamex_np(staged, destination, UInt32(RENAME_EXCL)) != 0 {
    guard errno == EEXIST, renamex_np(staged, destination, UInt32(RENAME_SWAP)) == 0 else {
        perror("Could not install speak-low")
        exit(1)
    }
}
SWIFT
echo "$out/speak-low.app"
