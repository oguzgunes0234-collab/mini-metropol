#!/usr/bin/env bash
# Bölüm doğrulaması: her bölümü rastgele, "akıllı" ve planlayıcı botlarla oynar.
# Kullanım: tools/validate_levels.sh [ek argümanlar, ör. --levels=1-01,1-02 --attempts=10]
# Rapor: reports/levels.json ve reports/levels.md
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
mkdir -p reports && touch reports/.gdignore  # Godot bu klasörü içe aktarmasın
"$GODOT" --headless --path . --import >/dev/null 2>&1
"$GODOT" --headless --path . --fixed-fps 60 -s res://tools/validate_levels.gd -- "$@" 2>&1 | tee reports/levels.log
status=${PIPESTATUS[0]}
if grep -qE "SCRIPT ERROR|^ERROR:" reports/levels.log; then
  echo "!!! Betik hatası bulundu"; grep -nE "SCRIPT ERROR|^ERROR:" reports/levels.log | head; status=1
fi
exit $status
