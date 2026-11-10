#!/usr/bin/env bash
# NebulaOS · 30 — pós-instalação: Oh My Zsh e Deepin Terminal
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

DBUS_NAME="${NEBULA_DEEPIN_DBUS_NAME:-com.deepin.terminal.reborn}"
DBUS_PATH=/window
DBUS_IFACE=com.deepin.terminal.reborn

# ── Oh My Zsh ────────────────────────────────────────────────
if [[ "${NEBULA_SKIP_NET:-}" != 1 ]]; then
  step "Oh My Zsh"
  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    ok "Oh My Zsh já presente"
  else
    info "instalando Oh My Zsh (sem trocar o shell de login)…"
    url="${NEBULA_OMZ_URL:-https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh}"
    if ! installer="$(curl -fsSL "$url")"; then
      err "falha ao baixar o instalador do Oh My Zsh ($url)"
      exit 1
    fi
    RUNZSH=no KEEP_ZSHRC=yes CHSH=no sh -c "$installer"
    ok "Oh My Zsh instalado"
  fi
  custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"
  for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
    if [[ -d "$custom/$plugin" ]]; then
      ok "$plugin já presente"
    else
      git clone --depth 1 "https://github.com/zsh-users/$plugin" "$custom/$plugin"
      ok "$plugin instalado"
    fi
  done
fi

# ── Deepin Terminal: tema ────────────────────────────────────
step "Deepin Terminal · tema Theme8"
CONF="${NEBULA_DEEPIN_CONF:-$HOME/.config/deepin/deepin-terminal/config.conf}"
if [[ -f "$CONF" ]]; then
  [[ -e "$CONF.nebula-bak" ]] || cp "$CONF" "$CONF.nebula-bak"
else
  # Deepin nunca aberto: cria a config já com o tema
  mkdir -p "$(dirname "$CONF")"
fi
ini_set "$CONF" basic.interface.expand_theme value Theme8
ok "tema Theme8 definido em $CONF"
if pgrep -x deepin-terminal >/dev/null 2>&1; then
  warn "o Deepin Terminal está aberto: se o tema não mudar, feche todas as janelas e reabra"
fi

# ── Deepin Terminal: shell zsh ───────────────────────────────
if [[ "${NEBULA_SKIP_DBUS:-}" != 1 ]]; then
  step "Deepin Terminal · shell zsh"
  zsh_path="$(command -v zsh || true)"
  if [[ -z "$zsh_path" ]]; then
    warn "zsh não encontrado; rode ./install.sh completo"
  elif busctl --user call "$DBUS_NAME" "$DBUS_PATH" "$DBUS_IFACE" setConsoleShell s "$zsh_path" >/dev/null 2>&1; then
    current="$(busctl --user call "$DBUS_NAME" "$DBUS_PATH" "$DBUS_IFACE" consoleShell 2>/dev/null || true)"
    ok "shell do Deepin: ${current#s }"
  else
    warn "o Deepin Terminal não está aberto, então o shell zsh ainda não foi definido nele."
    warn "Para terminar: abra o Deepin Terminal e rode: nebula update"
    warn "(ou defina manualmente: Configurações → Avançado → Shell → zsh)"
  fi
fi
