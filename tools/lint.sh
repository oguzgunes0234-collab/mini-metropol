#!/usr/bin/env bash
# GDScript dosyalarını Godot'nun kendi ayrıştırıcısıyla denetler (sözdizimi ve tür hataları).
# Kullanım: tools/lint.sh [dosya.gd ...]   (dosya verilmezse tüm proje)
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"

"$GODOT" --headless --path . --import >/dev/null 2>&1

if [ $# -gt 0 ]; then
  files=("$@")
else
  mapfile -t files < <(find . -name '*.gd' -not -path './.godot/*' | sort)
fi

failed=0
for f in "${files[@]}"; do
  out=$("$GODOT" --headless --path . --check-only -s "res://${f#./}" 2>&1)
  if echo "$out" | grep -qE "SCRIPT ERROR|Parse Error"; then
    echo "HATA: $f"
    echo "$out" | grep -E "SCRIPT ERROR|Parse Error|at:" | head -6
    failed=1
  fi
done
[ $failed -eq 0 ] && echo "lint: ${#files[@]} dosya temiz"
exit $failed
