#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
swiftc Sources/SpeakLow/VoiceError.swift Sources/SpeakLow/Hotkey.swift Sources/SpeakLow/Claude.swift \
    Tests/SpeakLowTests/SpeakLowTests.swift -o "$tmp/check"
"$tmp/check"
