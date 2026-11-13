#!/usr/bin/env bash
# Renders preview/banner.png (1440x340) for the README from the theme assets.
# Usage: tools/make-banner.sh [GLYPHS]      (default: "1 . 0 4 8 5 9 6")
# Requires: ImageMagick 7
set -euo pipefail
cd "$(dirname "$0")/../divergence-meter"

read -ra GLYPHS <<< "${1:-1 . 0 4 8 5 9 6}"
TW=100; TH=190; GAP=9; Y0=40
X0=$(( (1440 - (8*TW + 7*GAP)) / 2 ))

args=(); i=0
for c in "${GLYPHS[@]}"; do
  x=$(( X0 + i * (TW + GAP) ))
  [[ $c == . ]] && lit=dot || lit=d$c
  args+=( \( tube.png -resize 50% \) -geometry "+$x+$Y0" -composite \( "$lit.png" -resize 50% \) -geometry "+$x+$Y0" -composite )
  i=$((i + 1))
done

magick \( bg.png -resize 1440x900! -gravity center -crop 1440x340+0+0 +repage \) -gravity northwest "${args[@]}" \
  \( tagline-boot.png -resize 50% \) -geometry "+0+$((Y0 + TH + 25))" -composite -depth 8 ../preview/banner.png
echo "preview/banner.png"
