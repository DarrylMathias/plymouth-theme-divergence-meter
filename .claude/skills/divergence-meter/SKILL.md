---
name: divergence-meter
description: Work on the Divergence Meter Plymouth boot-splash theme in this repo — change its timings, worldline numbers, colours, taglines or tube layout, regenerate assets and preview GIFs, and install/test it safely. Use for any task touching divergence-meter/, tools/, install.sh or the README previews.
---

# Divergence Meter — agent guide

A Steins;Gate–style Plymouth **script** theme: 8 Nixie tubes flicker, then lock onto
`1.048596` on boot ("EL PSY KONGROO") and `0.571024` on shutdown/reboot ("α WORLDLINE").

## Golden rules (read first)

1. **Never run Plymouth on the user's live session.** `plymouthd`, `plymouth --show-splash`,
   `plymouth-set-default-theme`, `mkinitcpio`, `dracut`, `update-initramfs` take over the display,
   need root, or change what boots. Hand these commands to the user to run; don't run them yourself.
   Ask them to paste the output back.
2. **Preview with `tools/make-preview.sh`**, never with Plymouth. It renders the real assets with the same
   frame logic and writes `preview/*.gif` + `build/preview-*.mp4`. View a frame by extracting it:
   `magick 'preview/boot.gif[-1]' -coalesce /tmp/last.png`.
3. **Keep `TIMINGS` in `tools/make-preview.sh` identical to the per-mode constants in the script.**
   The preview is only trustworthy if they match.
4. **Assets are generated, not hand-edited.** Change `tools/make-assets.sh`, then regenerate into
   `divergence-meter/`. Check the result visually (extract/crop a PNG and look at it).
5. Changes reach the real splash only after the user reinstalls (`sudo ./install.sh`), because the theme
   is copied **into the initramfs**. Tell the user to reboot to see it.

## Layout

| Path | What |
| --- | --- |
| `divergence-meter/divergence-meter.plymouth` | descriptor (`ModuleName=script`, absolute `ImageDir`/`ScriptFile`) |
| `divergence-meter/divergence-meter.script` | all behaviour: mode switch, layout, `refresh_callback` |
| `divergence-meter/*.png` | `tube.png` (glass+mesh+unlit cathodes), `d0-9.png`, `dot.png` (lit glow), `tagline-{boot,shutdown}.png`, `bg.png` |
| `tools/make-assets.sh [OUT]` | renders every PNG (ImageMagick 7 + DejaVu). Default OUT is `build/assets` |
| `tools/make-preview.sh [boot\|shutdown\|both]` | preview GIF/MP4 at 720×450 |
| `tools/make-banner.sh` | README banner `preview/banner.png` |
| `install.sh` / `uninstall.sh` | distro-aware install (plymouth-set-default-theme -R, or update-alternatives + update-initramfs on Debian/Ubuntu) |

## How the script works

- Design size is **2880 px wide**. `S = Window.GetWidth() / 2880` scales everything.
  Tube = 200×380 design px, gap 18, row centred, `Y0 = (H - TH)/2 - 60*S`. Tagline is a full-width
  2880×110 image placed `50*S` below the tubes.
- `Plymouth.GetMode()`: `"shutdown"`/`"reboot"` → α worldline, anything else → boot.
- Each mode sets `target[0]`, `target[2..7]` (index 1 is always the decimal point) and its timings.
- `refresh_callback` runs at **50 fps** with a global `frame` counter:
  - `frame >= DARK`: dot lit; tubes not yet locked get a random digit every `FLICKER` frames.
  - Lock order is tube 0 then 2..7; `locked = (frame - LOCK_START) / LOCK_STEP + 1`.
  - Tagline opacity ramps from 0→1 over `TAG_FADE` frames after `TAG_START`.
- Current defaults: boot `DARK 0, LOCK_START 20, LOCK_STEP 4, TAG_START 36, TAG_FADE 12` (fully shown ≈ 1 s);
  shutdown `5, 35, 5, 70, 10` (≈ 1.6 s). They are tuned for a machine whose splash is visible ~3 s, so the user
  sees the end. Don't lengthen them without being asked.

## Plymouth script: safe subset

There is no linter, and a script error only shows up as a **black splash at boot**. Stay within constructs
used by Plymouth's own example theme (`/usr/share/plymouth/themes/script/script.script`):

- ✅ `fun name () { ... }`, `if (...) { } else { }`, `for (local.i = 0; i < n; i++)`, `++`, `+=`, `return x;`
- ✅ `global.x = ...` to assign a global from inside a function; `local.x` for temporaries
- ✅ `Image("f.png")`, `.Scale(w, h)`, `Sprite(img)`, `.SetImage`, `.SetPosition(x, y, z)`, `.SetOpacity`,
  `Window.GetWidth/GetHeight`, `Math.Int`, `Math.Random`, `Plymouth.GetMode`, `Plymouth.SetRefreshFunction`
- ❌ avoid `%` (use `a - Math.Int(a / b) * b`), `else if` chains (nest instead), bare `return;`,
  string indexing. They are either unsupported or unverified here.
- After editing, at least check that `{`/`}` and `(`/`)` counts balance, and re-read the changed function.

## Recipes

**Change timings**: edit the constants in both mode branches at the top of the script → mirror them in
`TIMINGS` in `tools/make-preview.sh` → `tools/make-preview.sh both` → inspect the last frames → update the
timing table in `README.md`.

**Change worldline numbers**: edit `target[...]` in the script and `TARGETS` in `make-preview.sh`.
Keep 8 glyphs with `.` at index 1.

**Change colours / taglines / tube size**:
```bash
GLOW='#ff5a00' MID='#ff8a2a' CORE='#ffe4c2' TAG='#e0a26a' tools/make-assets.sh divergence-meter
tools/make-preview.sh both
```
Taglines are near the end of `make-assets.sh`. ImageMagick gotcha: `-size` sticks to later `label:`
operators; reset with `+size` (see the α tagline). Always `+repage` after `-extent`/`-trim`.
If you change tube `W`/`H`, update `TW`/`TH`/`GAP` maths in the script **and** in `make-preview.sh`.

**Regenerate the README banner**: `tools/make-banner.sh` (after any asset change).

**Verify assets didn't change by accident**:
```bash
tools/make-assets.sh /tmp/da && for f in divergence-meter/*.png; do
  printf '%s ' "$(basename "$f")"; magick compare -metric RMSE "$f" "/tmp/da/$(basename "$f")" null: 2>&1; echo; done
```
All zeros = identical.

## Install / test commands to give the user

```bash
sudo ./install.sh                                   # copy + set default + rebuild initramfs
plymouth-set-default-theme                          # confirm it's active
sudo ./uninstall.sh                                 # back to bgrt/spinner
```
Kernel cmdline needs `quiet splash`. With a UKI the cmdline is in `/etc/kernel/cmdline` (rebuild with
`mkinitcpio -P`), not `/etc/default/grub`.

A live Plymouth test is only acceptable **from a text console (TTY), run by the user**:
`sudo plymouthd --debug --tty=$(tty); sudo plymouth --show-splash; sleep 8; sudo plymouth --quit`.

## Debugging a black splash (user runs these)

```bash
journalctl -b | grep -i plymouth
ls /usr/share/plymouth/themes/divergence-meter
```
Boot once with `plymouth.debug` and read `/var/log/plymouth-debug.log` for the script error line.
