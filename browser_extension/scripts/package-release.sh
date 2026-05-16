#!/usr/bin/env bash
# Build and zip only files required for Chrome Web Store upload.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "Building extension..."
npm run build

OUT="$ROOT/release"
ZIP="$ROOT/simpletodo-extension.zip"
rm -rf "$OUT" "$ZIP"
mkdir -p "$OUT/icons"

cp manifest.json popup.html popup.js background.js styles.css "$OUT/"
cp icons/*.png "$OUT/icons/"

echo "Creating $ZIP ..."
(cd "$OUT" && zip -r -q "$ZIP" .)

SIZE="$(du -sh "$ZIP" | cut -f1)"
echo "Done: $ZIP ($SIZE)"
echo ""
echo "Upload this zip in Chrome Web Store Developer Dashboard."
echo "Do NOT zip node_modules/, webapp/, or src/."
