#!/usr/bin/env bash
# Linux geliştirme/test ortamı kurulumu (Claude Code bulut oturumu için).
# Godot 4.7.2'yi ve ekran görüntüsü araçlarını (Xvfb + Mesa) Nix ile,
# sabitlenmiş bir nixpkgs sürümünden kurar. Sistem dosyalarına dokunmaz;
# her şey /nix/store altına gider. Tekrar çalıştırmak güvenlidir.
#
# Mac'te bu betik gerekmez: Godot 4.7.2'yi godotengine.org'dan indirmek yeterli.
set -euo pipefail

NIXPKGS="https://releases.nixos.org/nixos/unstable/nixos-26.11pre1097682.02c087f3fe67/nixexprs.tar.xz"
GODOT_VERSION_PREFIX="4.7.2"
export PATH="$HOME/.nix-profile/bin:/nix/var/nix/profiles/default/bin:$PATH"

if ! command -v nix-env >/dev/null 2>&1; then
  echo "setup_env: Nix bulunamadı; Godot otomatik kurulamadı." >&2
  exit 1
fi

if ! godot --version 2>/dev/null | grep -q "^${GODOT_VERSION_PREFIX}"; then
  echo "setup_env: Godot ${GODOT_VERSION_PREFIX} kuruluyor..."
  nix-env -f "$NIXPKGS" -iA godot
fi

if ! command -v xvfb-run >/dev/null 2>&1 || [ ! -d "$HOME/.nix-profile/lib/dri" ]; then
  echo "setup_env: ekran görüntüsü araçları (xvfb-run, mesa) kuruluyor..."
  nix-env -f "$NIXPKGS" -iA xvfb-run mesa libglvnd
fi

godot --version
