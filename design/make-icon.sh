#!/bin/sh
# Renders design/icon.svg into the app icon set. Needs Google Chrome (the only SVG rasteriser here that draws filters).
set -eu
cd "$(dirname "$0")/.."
out=apps/macos/Locked/Assets.xcassets/AppIcon.appiconset
mkdir -p "$out"
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless --hide-scrollbars \
  --default-background-color=00000000 --window-size=1024,1024 \
  --screenshot="$PWD/$out/icon_1024.png" "file://$PWD/design/icon.svg" 2>/dev/null
for s in 16 32 64 128 256 512; do
  sips -z $s $s "$out/icon_1024.png" --out "$out/icon_$s.png" >/dev/null
done
cat > "$out/Contents.json" <<'EOF'
{"images":[
{"idiom":"mac","size":"16x16","scale":"1x","filename":"icon_16.png"},
{"idiom":"mac","size":"16x16","scale":"2x","filename":"icon_32.png"},
{"idiom":"mac","size":"32x32","scale":"1x","filename":"icon_32.png"},
{"idiom":"mac","size":"32x32","scale":"2x","filename":"icon_64.png"},
{"idiom":"mac","size":"128x128","scale":"1x","filename":"icon_128.png"},
{"idiom":"mac","size":"128x128","scale":"2x","filename":"icon_256.png"},
{"idiom":"mac","size":"256x256","scale":"1x","filename":"icon_256.png"},
{"idiom":"mac","size":"256x256","scale":"2x","filename":"icon_512.png"},
{"idiom":"mac","size":"512x512","scale":"1x","filename":"icon_512.png"},
{"idiom":"mac","size":"512x512","scale":"2x","filename":"icon_1024.png"}
],"info":{"author":"xcode","version":1}}
EOF
printf '{"info":{"author":"xcode","version":1}}\n' > apps/macos/Locked/Assets.xcassets/Contents.json
