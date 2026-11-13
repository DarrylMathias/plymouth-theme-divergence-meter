#!/usr/bin/env bash
# Renders every image used by the Divergence Meter Plymouth theme.
#
# Usage: tools/make-assets.sh [OUTPUT_DIR]      (default: build/assets)
#
# Requires: ImageMagick 7 (`magick`), DejaVu fonts (ttf-dejavu / fonts-dejavu-core)
# All sizes are drawn for a 2880 px wide screen; the script scales them at runtime.
set -euo pipefail
cd "$(dirname "$0")/.."

OUT=${1:-build/assets}
mkdir -p "$OUT"

FONT_THIN=${FONT_THIN:-$(fc-match -f '%{file}' 'DejaVu Sans:extralight')}
FONT_REG=${FONT_REG:-$(fc-match -f '%{file}' 'DejaVu Sans')}
GLOW=${GLOW:-'#ff5a00'}        # outer glow
MID=${MID:-'#ff8a2a'}          # inner glow
CORE=${CORE:-'#ffe4c2'}        # hot filament
TAG=${TAG:-'#e0a26a'}          # tagline text

W=200; H=380                   # one tube
PT=250                         # digit size

# --- glass: dark amber-tinted tube with rounded top and a metal base
magick -size ${W}x${H} xc:none \
  \( -size $((W-16))x$((H-46)) gradient:'#1a0d06'-'#070302' -alpha set -channel A -evaluate set 92% +channel \
     \( +clone -alpha extract -fill black -colorize 100 -fill white -draw "roundrectangle 0,0 $((W-17)),$((H-47)) 80,80" \) \
     -alpha off -compose CopyOpacity -composite \) -geometry +8+6 -compose over -composite \
  -fill none -stroke '#5a3a24' -strokewidth 2 -draw "roundrectangle 8,6 $((W-9)),$((H-41)) 80,80" \
  -stroke '#ffffff22' -strokewidth 3 -draw "line 30,70 30,$((H-90))" \
  -stroke none -fill '#2b2622' -draw "rectangle 4,$((H-40)) $((W-5)),$((H-1))" \
  -fill '#4a423b' -draw "rectangle 4,$((H-40)) $((W-5)),$((H-34))" \
  -fill '#191512' -draw "rectangle 4,$((H-12)) $((W-5)),$((H-1))" \
  "$OUT/.glass.png"

# --- anode mesh: faint grid inside the glass
MESH=()
for x in $(seq 24 14 $((W-24))); do MESH+=(-draw "line $x,40 $x,$((H-60))"); done
for y in $(seq 40 14 $((H-60))); do MESH+=(-draw "line 24,$y $((W-24)),$y"); done
magick -size ${W}x${H} xc:none -stroke '#3a2414' -strokewidth 1 "${MESH[@]}" \
  -channel A -evaluate multiply 0.55 +channel "$OUT/.mesh.png"

# --- unlit cathodes: all ten digits stacked, very dim
GHOST=()
for d in 0 1 2 3 4 5 6 7 8 9; do GHOST+=(-annotate "+0-12" "$d"); done
magick -size ${W}x${H} xc:none -font "$FONT_THIN" -pointsize $PT -gravity center \
  -fill '#2a180c' -stroke '#3a2414' -strokewidth 0.8 "${GHOST[@]}" \
  -channel A -evaluate multiply 0.55 +channel "$OUT/.ghost.png"

magick "$OUT/.glass.png" "$OUT/.mesh.png" -compose over -composite "$OUT/.ghost.png" -compose over -composite "$OUT/tube.png"
rm -f "$OUT/.glass.png" "$OUT/.mesh.png" "$OUT/.ghost.png"

# --- lit digits: outer glow + inner glow + hot core
lit() {  # $1 = digit, $2 = output file
  magick -size ${W}x${H} xc:none -font "$FONT_THIN" -pointsize $PT -gravity center \
    -fill "$GLOW" -stroke "$GLOW" -strokewidth 16 -annotate "+0-12" "$1" -blur 0x18 \
    \( -size ${W}x${H} xc:none -font "$FONT_THIN" -pointsize $PT -gravity center -fill "$MID" -stroke "$MID" -strokewidth 6 -annotate "+0-12" "$1" -blur 0x5 \) -compose screen -composite \
    \( -size ${W}x${H} xc:none -font "$FONT_THIN" -pointsize $PT -gravity center -fill "$CORE" -stroke '#fff3e0' -strokewidth 0.6 -annotate "+0-12" "$1" \) -compose over -composite \
    "$2"
}
for d in 0 1 2 3 4 5 6 7 8 9; do lit "$d" "$OUT/d$d.png"; done

# --- decimal point: a glowing dot level with the digits' baseline
magick -size ${W}x${H} xc:none -fill "$GLOW" -draw "circle 100,262 100,284" -blur 0x16 \
  \( -size ${W}x${H} xc:none -fill "$MID" -draw "circle 100,262 100,276" -blur 0x5 \) -compose screen -composite \
  \( -size ${W}x${H} xc:none -fill "$CORE" -draw "circle 100,262 100,272" \) -compose over -composite "$OUT/dot.png"

# --- background: small radial gradient, scaled to the screen by the script
magick -size 720x450 radial-gradient:'#120804'-'#000000' "$OUT/bg.png"

# --- taglines (2880x110, text centred, soft orange glow)
glowify() { magick "$1" \( +clone -channel RGB -fill '#ff7a1a' -colorize 100 +channel -blur 0x7 \) +swap -compose over -composite "$1"; }

magick -size 2880x110 xc:none -font "$FONT_THIN" -pointsize 44 -gravity center -fill "$TAG" \
  -annotate +0+0 'E L   P S Y   K O N G R O O' "$OUT/tagline-boot.png"
glowify "$OUT/tagline-boot.png"

magick -background none -fill "$TAG" \
  \( -font "$FONT_REG" -pointsize 76 label:'α' -trim +repage -gravity north -splice 0x6 \) \
  \( -size 44x10 xc:none \) +size \
  \( -font "$FONT_THIN" -pointsize 44 label:'W O R L D L I N E' -trim +repage \) \
  -gravity center +append +repage -gravity center -background none -extent 2880x110 +repage \
  "$OUT/tagline-shutdown.png"
glowify "$OUT/tagline-shutdown.png"

# --- small, 8-bit PNGs (the whole theme ends up inside the initramfs)
for f in "$OUT"/*.png; do magick "$f" -depth 8 -define png:compression-level=9 "$f"; done

echo "Assets written to $OUT:"
ls "$OUT"
