#!/usr/bin/env bash
# Otomatik testleri çalıştırır. Godot 4.7.x gerekir (PATH'te "godot" ya da GODOT değişkeni).
# Kullanım: tools/run_tests.sh [filtre]
# Çıkış kodu: 0 = tüm testler başarılı, 1 = başarısız test veya betik hatası.
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
mkdir -p reports && touch reports/.gdignore  # Godot bu klasörü içe aktarmasın

"$GODOT" --headless --path . --import >/dev/null 2>&1

ARGS=()
if [ $# -gt 0 ]; then ARGS=(-- "--filter=$1"); fi

"$GODOT" --headless --path . --fixed-fps 120 -s res://tests/run_tests.gd "${ARGS[@]}" 2>&1 | tee reports/test_output.txt
status=${PIPESTATUS[0]}

# GDScript çalışma hataları testi durdurmaz; çıktıda arayıp başarısız sayıyoruz.
# (Testlerin bilerek ürettiği uyarılar "WARNING" olarak geçer ve sayılmaz.)
if grep -qE "SCRIPT ERROR|^ERROR:|Parse Error" reports/test_output.txt; then
  echo ""
  echo "!!! Çıktıda betik hatası bulundu — testler başarısız sayılıyor."
  grep -nE "SCRIPT ERROR|^ERROR:|Parse Error" reports/test_output.txt | head -20
  status=1
fi
exit $status
