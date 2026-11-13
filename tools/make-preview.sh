#!/usr/bin/env bash
# Renders preview animations of the theme WITHOUT running Plymouth.
# (Running plymouthd on a live desktop takes over the display — use this instead.)
#
# Usage: tools/make-preview.sh [boot|shutdown|both]      (default: both)
# Output: preview/boot.gif, preview/shutdown.gif   (+ build/preview-<mode>.mp4)
#
# The frame logic mirrors divergence-meter/divergence-meter.script exactly:
# same 50 fps clock, same per-mode timings, same flicker/lock/fade rules.
# Keep the TIMINGS below in sync with the script when you change it.
#
# Requires: ImageMagick 7, ffmpeg
set -euo pipefail
cd "$(dirname "$0")/.."

THEME=divergence-meter
WORK=build/preview
SCALE=25                      # % of the 2880x1800 design size -> 720x450
HOLD=60                       # extra frames to keep the final state visible (1.2 s)

declare -A TIMINGS=(
  # mode       DARK LOCK_START LOCK_STEP TAG_START TAG_FADE
  [boot]="     0    20         4         36        12"
  [shutdown]=" 5    35         5         70        10"
)
declare -A TARGETS=( [boot]="1 . 0 4 8 5 9 6" [shutdown]="0 . 5 7 1 0 2 4" )
FLICKER=2

SW=$((2880*SCALE/100)); SH=$((1800*SCALE/100))
TW=$((200*SCALE/100)); TH=$((380*SCALE/100)); GAP=$((18*SCALE/100))
X0=$(( (SW - (8*TW + 7*GAP)) / 2 ))
Y0=$(( (SH - TH) / 2 - 60*SCALE/100 ))
TY=$(( Y0 + TH + 50*SCALE/100 ))

mkdir -p "$WORK/img" preview
for f in "$THEME"/*.png; do magick "$f" -resize "$SCALE%" "$WORK/img/$(basename "$f")"; done
magick "$THEME/bg.png" -resize "${SW}x${SH}!" "$WORK/img/bg.png"

render() {  # $1 = mode
  local mode=$1
  read -r DARK LOCK_START LOCK_STEP TAG_START TAG_FADE <<< "${TIMINGS[$mode]}"
  read -ra target <<< "${TARGETS[$mode]}"
  local frames=$((TAG_START + TAG_FADE + HOLD))
  local dir="$WORK/frames-$mode"; rm -rf "$dir"; mkdir -p "$dir"
  local shown=(- - - - - - - -) f i order locked op args x

  for ((f = 1; f <= frames; f++)); do
    if (( f >= DARK )); then
      shown[1]=.
      locked=0; (( f >= LOCK_START )) && locked=$(( (f - LOCK_START) / LOCK_STEP + 1 ))
      for ((i = 0; i < 8; i++)); do
        (( i == 1 )) && continue
        order=$i; (( i > 1 )) && order=$((i - 1))
        if (( order < locked )); then shown[$i]=${target[$i]}
        elif (( f % FLICKER == 0 )); then shown[$i]=$((RANDOM % 10)); fi
      done
    fi
    op=0; (( f > TAG_START )) && op=$(( (f - TAG_START) * 100 / TAG_FADE )); (( op > 100 )) && op=100

    args=()
    for ((i = 0; i < 8; i++)); do
      x=$(( X0 + i * (TW + GAP) ))
      args+=("$WORK/img/tube.png" -geometry "+$x+$Y0" -composite)
      if [[ ${shown[$i]} == . ]]; then args+=("$WORK/img/dot.png" -geometry "+$x+$Y0" -composite)
      elif [[ ${shown[$i]} != - ]]; then args+=("$WORK/img/d${shown[$i]}.png" -geometry "+$x+$Y0" -composite); fi
    done
    if (( op > 0 )); then
      args+=(\( "$WORK/img/tagline-$mode.png" -channel A -evaluate multiply "$(awk "BEGIN{print $op/100}")" +channel \) -geometry "+0+$TY" -composite)
    fi
    magick "$WORK/img/bg.png" "${args[@]}" "$dir/$(printf %04d "$f").png"
  done

  ffmpeg -loglevel error -y -framerate 50 -i "$dir/%04d.png" -c:v libx264 -pix_fmt yuv420p "build/preview-$mode.mp4"
  ffmpeg -loglevel error -y -framerate 50 -i "$dir/%04d.png" \
    -vf "fps=25,split[a][b];[a]palettegen=max_colors=96[p];[b][p]paletteuse=dither=bayer:bayer_scale=4" \
    -loop 0 "preview/$mode.gif"
  echo "preview/$mode.gif  ($frames frames, $(du -h "preview/$mode.gif" | cut -f1))"
}

case ${1:-both} in
  boot|shutdown) render "$1" ;;
  both) render boot; render shutdown ;;
  *) echo "usage: $0 [boot|shutdown|both]" >&2; exit 1 ;;
esac
