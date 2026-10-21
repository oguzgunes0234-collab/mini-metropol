#!/bin/bash
# Claude Code bulut oturumu başlarken Godot'yu kurar ve projeyi içe aktarır,
# böylece testler (tools/run_tests.sh) ve lint (tools/lint.sh) hemen çalışır.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

cd "$CLAUDE_PROJECT_DIR"
tools/setup_env.sh

if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo 'export PATH="$HOME/.nix-profile/bin:$PATH"' >> "$CLAUDE_ENV_FILE"
fi

# .godot/ önbelleği Git'te yok; sınıf adlarının çözülmesi için içe aktarma gerekir.
"$HOME/.nix-profile/bin/godot" --headless --path . --import >/dev/null 2>&1 || true
