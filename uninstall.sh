#!/usr/bin/env bash
# Removes the Divergence Meter theme and switches back to another theme.
#
# Usage: sudo ./uninstall.sh [THEME]      (default: bgrt, falling back to spinner)
set -euo pipefail

NAME=divergence-meter
DEST=/usr/share/plymouth/themes/$NAME
die() { echo "error: $*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "run as root: sudo ./uninstall.sh"

FALLBACK=${1:-bgrt}
[[ -d /usr/share/plymouth/themes/$FALLBACK ]] || FALLBACK=spinner
[[ -d /usr/share/plymouth/themes/$FALLBACK ]] || die "theme '$FALLBACK' is not installed; pass one: sudo ./uninstall.sh <theme>"

echo ":: Switching to $FALLBACK"
if command -v plymouth-set-default-theme >/dev/null; then
  plymouth-set-default-theme -R "$FALLBACK"
elif command -v update-alternatives >/dev/null; then
  update-alternatives --remove default.plymouth "$DEST/$NAME.plymouth" || true
  update-alternatives --set default.plymouth "/usr/share/plymouth/themes/$FALLBACK/$FALLBACK.plymouth"
  update-initramfs -u
fi

echo ":: Removing $DEST"
rm -rf "$DEST"
echo ":: Done."
