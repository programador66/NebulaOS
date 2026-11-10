#!/usr/bin/env bash
# NebulaOS · 00 — pacotes do apt
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

step "Pacotes (apt)"
read -r -a wanted <<<"${NEBULA_APT_PACKAGES:-zsh tmux stow git curl}"
read -r -a apt_cmd <<<"${NEBULA_APT:-sudo apt-get install -y}"

missing=()
for pkg in "${wanted[@]}"; do
  if ! dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q 'install ok installed'; then
    missing+=("$pkg")
  fi
done

if ((${#missing[@]} == 0)); then
  ok "todos instalados: ${wanted[*]}"
  exit 0
fi

warn "vou usar sudo para instalar: ${missing[*]}"
"${apt_cmd[@]}" "${missing[@]}"
ok "instalados: ${missing[*]}"
