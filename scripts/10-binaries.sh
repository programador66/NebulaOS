#!/usr/bin/env bash
# NebulaOS · 10 — binários fora do apt (starship)
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

step "starship"
if have starship || [[ -x "$HOME/.local/bin/starship" ]]; then
  ok "starship já instalado"
  exit 0
fi
mkdir -p "$HOME/.local/bin"
info "instalando starship em ~/.local/bin…"
url="${NEBULA_STARSHIP_URL:-https://starship.rs/install.sh}"
if ! installer="$(curl -fsSL "$url")"; then
  err "falha ao baixar o instalador do starship ($url)"
  exit 1
fi
sh -c "$installer" -- -y -b "$HOME/.local/bin"
ok "starship instalado"
