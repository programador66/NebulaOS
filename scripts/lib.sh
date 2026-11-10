#!/usr/bin/env bash
# NebulaOS · funções compartilhadas (usar com `source`)

if [[ -t 1 ]]; then
  C_GREEN=$'\e[38;2;0;205;0m'; C_DIM=$'\e[2m'; C_YELLOW=$'\e[33m'
  C_RED=$'\e[31m'; C_BOLD=$'\e[1m'; C_RESET=$'\e[0m'
else
  C_GREEN=''; C_DIM=''; C_YELLOW=''; C_RED=''; C_BOLD=''; C_RESET=''
fi
export C_GREEN C_DIM C_YELLOW C_RED C_BOLD C_RESET

step() { printf '\n%s%s▸ %s%s\n' "$C_BOLD" "$C_GREEN" "$*" "$C_RESET"; }
info() { printf '  %s·%s %s\n' "$C_DIM" "$C_RESET" "$*"; }
ok()   { printf '  %s✓%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn() { printf '  %s!%s %s\n' "$C_YELLOW" "$C_RESET" "$*"; }
err()  { printf '  %s✗%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; }

have() { command -v "$1" >/dev/null 2>&1; }

# Move um arquivo/diretório real (não symlink) para PATH.nebula-bak.
backup_conflict() {
  local path="$1" bak
  [[ -e "$path" && ! -L "$path" ]] || return 0
  bak="$path.nebula-bak"
  [[ -e "$bak" ]] && bak="$bak.$(date +%s)"
  mv "$path" "$bak"
  info "backup: $path → $bak"
}

# Define KEY=VALUE dentro de [SECTION] num arquivo INI (estilo Deepin).
ini_set() {
  local file="$1" section="$2" key="$3" value="$4" tmp
  [[ -e "$file" ]] || : > "$file"
  tmp="$(mktemp "${file}.XXXXXX")"
  awk -v sec="[$section]" -v key="$key" -v val="$value" '
    function flush() { if (insec && !done) { print key "=" val; done = 1 } }
    $0 == sec { insec = 1; seen = 1; print; next }
    /^\[/ { if (insec) { flush(); insec = 0 } print; next }
    insec && index($0, key "=") == 1 { if (!done) { print key "=" val; done = 1 } next }
    { print }
    END {
      if (insec) flush()
      if (!seen) { print sec; print key "=" val }
    }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
}
