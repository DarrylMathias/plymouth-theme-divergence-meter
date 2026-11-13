#!/usr/bin/env bash
# Installs the Divergence Meter Plymouth theme and makes it the default.
#
# Usage: sudo ./install.sh [--no-rebuild]
#   --no-rebuild   only copy the files and set the theme; rebuild the initramfs yourself
set -euo pipefail
cd "$(dirname "$0")"

NAME=divergence-meter
DEST=/usr/share/plymouth/themes/$NAME
REBUILD=1
[[ ${1:-} == --no-rebuild ]] && REBUILD=0

die() { echo "error: $*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "run as root: sudo ./install.sh"
command -v plymouth >/dev/null || die "plymouth is not installed"
compgen -G "/usr/lib*/plymouth/script.so" >/dev/null || compgen -G "/usr/lib/*/plymouth/script.so" >/dev/null \
  || die "the plymouth 'script' module is missing (Fedora: plymouth-plugin-script, Debian/Ubuntu: plymouth plymouth-themes)"
[[ -f $NAME/$NAME.script && -f $NAME/$NAME.plymouth ]] || die "theme files not found in ./$NAME"

echo ":: Copying theme to $DEST"
rm -rf "$DEST"
install -d "$DEST"
install -m 644 "$NAME"/* "$DEST"/

echo ":: Setting $NAME as the default theme"
if command -v plymouth-set-default-theme >/dev/null; then
  # Arch, Fedora and most others. -R also rebuilds the initramfs (mkinitcpio / dracut).
  if (( REBUILD )); then
    plymouth-set-default-theme -R "$NAME"
  else
    plymouth-set-default-theme "$NAME"
  fi
elif command -v update-alternatives >/dev/null && [[ -e /usr/share/plymouth/themes/default.plymouth ]]; then
  # Debian / Ubuntu
  update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth "$DEST/$NAME.plymouth" 100
  update-alternatives --set default.plymouth "$DEST/$NAME.plymouth"
  (( REBUILD )) && update-initramfs -u
else
  die "could not find plymouth-set-default-theme or update-alternatives; set the theme manually"
fi

echo
echo ":: Done. Reboot to see it."
echo "   Make sure your kernel command line contains: quiet splash"
(( REBUILD )) || echo "   Remember to rebuild your initramfs (mkinitcpio -P / dracut -f / update-initramfs -u)."
