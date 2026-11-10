#!/usr/bin/env bash
# NebulaOS · 20 — dotfiles via GNU Stow (com backup do que já existir)
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

NEBULA_ROOT="${NEBULA_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
STOW_DIR="$NEBULA_ROOT/stow"
PACKAGES=(zsh starship tmux)

# symlink que não aponta para dentro do NebulaOS também sai do caminho
backup_foreign() {
  local target="$1"
  # caminho real já dentro do repo (link nosso ou pasta dobrada): nunca mover
  [[ "$(readlink -f "$target")" == "$STOW_DIR/"* ]] && return 0
  if [[ -L "$target" ]]; then
    local bak="$target.nebula-bak"
    [[ -e "$bak" || -L "$bak" ]] && bak="$bak.$(date +%s)"
    mv "$target" "$bak"
    info "backup: $target → $bak"
  else
    backup_conflict "$target"
  fi
}

step "Dotfiles (stow)"
for pkg in "${PACKAGES[@]}"; do
  while IFS= read -r -d '' file; do
    backup_foreign "$HOME/${file#"$STOW_DIR/$pkg/"}"
  done < <(find "$STOW_DIR/$pkg" -type f -print0)
  stow --restow --no-folding --dir="$STOW_DIR" --target="$HOME" "$pkg"
  ok "$pkg"
done

step "Comando nebula"
mkdir -p "$HOME/.local/bin"
backup_foreign "$HOME/.local/bin/nebula"
ln -sfn "$NEBULA_ROOT/bin/nebula" "$HOME/.local/bin/nebula"
ok "$HOME/.local/bin/nebula → bin/nebula"
