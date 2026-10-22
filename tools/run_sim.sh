#!/usr/bin/env bash
# Uzun stres simülasyonu: iki farklı otomatik oyuncuyla paralel çalışır.
# Kullanım: tools/run_sim.sh [bırakma_sayısı_her_oyuncu_için]   (varsayılan 5000)
# Raporlar: reports/sim_random.json, reports/sim_greedy.json
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
DROPS="${1:-5000}"
mkdir -p reports && touch reports/.gdignore  # Godot bu klasörü içe aktarmasın

"$GODOT" --headless --path . --import >/dev/null 2>&1

run() {
  "$GODOT" --headless --path . --fixed-fps 120 -s res://tools/simulate.gd -- \
    "--drops=$DROPS" "--seed=$2" "--bot=$1" "--out=reports/sim_$1.json" \
    > "reports/sim_$1.log" 2>&1
}

run random 1 & p1=$!
run greedy 2 & p2=$!
wait $p1; s1=$?
wait $p2; s2=$?

status=0
for b in random greedy; do
  echo "== $b =="
  if grep -qE "SCRIPT ERROR|^ERROR:" "reports/sim_$b.log"; then
    echo "!!! Betik hatası:"; grep -nE "SCRIPT ERROR|^ERROR:" "reports/sim_$b.log" | head -10
    status=1
  fi
  cat "reports/sim_$b.json" 2>/dev/null || { echo "rapor yok"; status=1; }
done
[ $s1 -ne 0 ] || [ $s2 -ne 0 ] && status=1
exit $status
