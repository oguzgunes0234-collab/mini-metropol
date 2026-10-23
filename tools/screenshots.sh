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

shot levels          540x960  --screen=levels
shot intro_1-04      540x960  --screen=intro --level=1-04
shot play_1-07       540x960  --screen=play  --level=1-07 --drops=10
shot play_1-10_tall  540x1170 --screen=play  --level=1-10 --drops=14
shot won_1-01        540x960  --screen=won   --level=1-01
shot lost_1-06       540x960  --screen=lost  --level=1-06 --drops=8
shot pause_tablet    720x960  --screen=pause --level=1-09 --drops=6
shot free_en_debug   540x960  --screen=free  --drops=30 --locale=en --debug
# Güçlendiriciler (Aşama 5): ilk 9 bölüm tamamlanmış oyuncu.
shot boosters_1-10   540x960  --screen=play  --level=1-10 --drops=12 --completed=9
shot intro_new_1-03  540x960  --screen=intro --level=1-03 --completed=2
shot shop_1-10       540x960  --screen=shop  --level=1-10 --drops=6 --completed=9 --booster=extra_moves
shot shop_poor_1-10  540x960  --screen=shop  --level=1-10 --drops=6 --completed=9 --booster=relieve --coins=40
shot pick_1-10       540x960  --screen=pick  --level=1-10 --drops=12 --completed=9
shot won_rewards     540x960  --screen=won   --level=1-02 --completed=1
shot levels_diamonds 540x960  --screen=levels --completed=20
