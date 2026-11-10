#!/usr/bin/env bash
# NebulaOS · atualiza o repositório e reaplica dotfiles e pós-instalação
set -euo pipefail

NEBULA_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
export NEBULA_ROOT
# shellcheck source=scripts/lib.sh
source "$NEBULA_ROOT/scripts/lib.sh"

step "git pull"
git -C "$NEBULA_ROOT" pull --ff-only
bash "$NEBULA_ROOT/scripts/20-stow.sh"
bash "$NEBULA_ROOT/scripts/30-post.sh"
step "Atualizado ✦"
