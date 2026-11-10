#!/usr/bin/env bash
#
#   NebulaOS — ambiente de agentes de IA para Ubuntu + Deepin Terminal
#
#   Uso:  ./install.sh             (completo)
#         ./install.sh --dotfiles  (só os links dos dotfiles)
#
set -euo pipefail

NEBULA_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export NEBULA_ROOT
# shellcheck source=scripts/lib.sh
source "$NEBULA_ROOT/scripts/lib.sh"

run_step() {
  local script="$NEBULA_ROOT/scripts/$1"
  [[ -f "$script" ]] || return 0
  bash "$script"
}

MODE="${1:-full}"
case "$MODE" in
  --dotfiles)
    info "modo: só dotfiles"
    run_step 20-stow.sh
    ;;
  full)
    run_step 00-apt.sh
    run_step 10-binaries.sh
    run_step 20-stow.sh
    run_step 30-post.sh
    ;;
  *)
    err "modo desconhecido: $MODE  (use: ./install.sh ou ./install.sh --dotfiles)"
    exit 2
    ;;
esac

step "Done ✦"
cat <<EOF
  O NebulaOS está pronto. Próximos passos:
    1. Abra uma nova janela do Deepin Terminal.
    2. Rode ${C_GREEN}nebula claude meu-projeto${C_RESET} dentro de um projeto.
  Atualizar depois:  ${C_GREEN}nebula update${C_RESET}
EOF
