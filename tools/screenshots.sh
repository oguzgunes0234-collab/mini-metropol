#!/usr/bin/env bash
# Farklı ekran oranlarında oyun ekranı görüntüleri üretir (reports/shots/).
# Ekransız sunucuda sanal ekran (xvfb-run) ve yazılımsal OpenGL (Mesa) gerekir.
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
OUT=reports/shots
mkdir -p "$OUT" && touch reports/.gdignore  # Godot bu klasörü içe aktarmasın

if [ -d "$HOME/.nix-profile/lib/dri" ]; then
  export LD_LIBRARY_PATH="$HOME/.nix-profile/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  export LIBGL_DRIVERS_PATH="$HOME/.nix-profile/lib/dri"
  export __EGL_VENDOR_LIBRARY_DIRS="$HOME/.nix-profile/share/glvnd/egl_vendor.d"
fi

"$GODOT" --headless --path . --import >/dev/null 2>&1

shot() { # ad çözünürlük [ek argümanlar]
  local name=$1 res=$2; shift 2
  xvfb-run -a -s "-screen 0 1600x2600x24" "$GODOT" --path . --rendering-driver opengl3 \
    --resolution "$res" -s res://tools/screenshot.gd -- "--out=$OUT/$name.png" "$@" 2>&1 \
    | grep -E "Kaydedildi|SCRIPT ERROR|^ERROR: [^C]" || true
}

shot phone_9x16      540x960  --drops=45 --seed=3
shot phone_19_5x9    540x1170 --drops=45 --seed=3
shot tablet_3x4      720x960  --drops=45 --seed=3
shot game_over       540x1170 --drops=60 --seed=8 --bot=random --game-over
shot english_debug   540x960  --drops=30 --seed=4 --locale=en --debug
