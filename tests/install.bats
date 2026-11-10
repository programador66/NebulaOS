#!/usr/bin/env bats
load helpers

setup() {
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
  export NEBULA_APT=true
}

points_into_stow() { [ -L "$1" ] && [[ "$(readlink -f "$1")" == "$NEBULA_ROOT/stow/"* ]]; }

@test "dotfiles mode links files" {
  run "$NEBULA_ROOT/install.sh" --dotfiles
  [ "$status" -eq 0 ]
  points_into_stow "$HOME/.zshrc"
  points_into_stow "$HOME/.tmux.conf"
  points_into_stow "$HOME/.config/starship.toml"
  [ -f "$HOME/.zsh/exports.zsh" ]
}

@test "directories are real, never folded into the repo" {
  run "$NEBULA_ROOT/install.sh" --dotfiles
  [ "$status" -eq 0 ]
  [ -d "$HOME/.config" ] && [ ! -L "$HOME/.config" ]
  [ -d "$HOME/.zsh" ] && [ ! -L "$HOME/.zsh" ]
}

@test "never moves files inside the repo (previously folded dir)" {
  # simula uma instalação antiga em que o stow dobrou ~/.config no repo
  stow --dir="$NEBULA_ROOT/stow" --target="$HOME" starship
  [ -L "$HOME/.config" ]
  run "$NEBULA_ROOT/install.sh" --dotfiles
  [ "$status" -eq 0 ]
  [ -f "$NEBULA_ROOT/stow/starship/.config/starship.toml" ]
  [ ! -L "$NEBULA_ROOT/stow/starship/.config/starship.toml" ]
  [ -z "$(find "$NEBULA_ROOT/stow" -name '*.nebula-bak*')" ]
}

@test "existing real zshrc is backed up" {
  echo "meu zshrc antigo" > "$HOME/.zshrc"
  run "$NEBULA_ROOT/install.sh" --dotfiles
  [ "$status" -eq 0 ]
  [ "$(cat "$HOME/.zshrc.nebula-bak")" = "meu zshrc antigo" ]
  points_into_stow "$HOME/.zshrc"
}

@test "foreign symlink is backed up" {
  echo outro > "$BATS_TEST_TMPDIR/outro.conf"
  ln -s "$BATS_TEST_TMPDIR/outro.conf" "$HOME/.tmux.conf"
  run "$NEBULA_ROOT/install.sh" --dotfiles
  [ "$status" -eq 0 ]
  points_into_stow "$HOME/.tmux.conf"
  [ -L "$HOME/.tmux.conf.nebula-bak" ]
}

@test "existing .config dir with other files is preserved" {
  mkdir -p "$HOME/.config/outro"
  echo x > "$HOME/.config/outro/a"
  run "$NEBULA_ROOT/install.sh" --dotfiles
  [ "$status" -eq 0 ]
  [ "$(cat "$HOME/.config/outro/a")" = x ]
  points_into_stow "$HOME/.config/starship.toml"
}

@test "idempotent: twice is fine, single backup" {
  echo antigo > "$HOME/.zshrc"
  "$NEBULA_ROOT/install.sh" --dotfiles
  run "$NEBULA_ROOT/install.sh" --dotfiles
  [ "$status" -eq 0 ]
  [ "$(ls -a "$HOME" | grep -c '^\.zshrc\.nebula-bak')" -eq 1 ]
  points_into_stow "$HOME/.zshrc"
}

@test "nebula linked into local bin" {
  "$NEBULA_ROOT/install.sh" --dotfiles
  [ -L "$HOME/.local/bin/nebula" ]
  [ "$(readlink -f "$HOME/.local/bin/nebula")" = "$NEBULA_ROOT/bin/nebula" ]
  run "$HOME/.local/bin/nebula" help
  [ "$status" -eq 0 ]
}

@test "unknown mode exits 2" {
  run "$NEBULA_ROOT/install.sh" --foo
  [ "$status" -eq 2 ]
}

@test "apt skipped when nothing missing" {
  NEBULA_APT='echo APT' NEBULA_APT_PACKAGES='bash coreutils' run "$NEBULA_ROOT/scripts/00-apt.sh"
  [ "$status" -eq 0 ]
  [[ "$output" != *"APT"* ]]
}

@test "apt installs only missing packages, warning about sudo" {
  NEBULA_APT='echo APT' NEBULA_APT_PACKAGES='git pacote-nebula-inexistente' \
    run "$NEBULA_ROOT/scripts/00-apt.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"vou usar sudo para instalar: pacote-nebula-inexistente"* ]]
  [[ "$output" == *"APT pacote-nebula-inexistente"* ]]
  [[ "$output" != *"APT git"* ]]
}

# ── 30-post (sem rede e sem D-Bus nos testes) ────────────────
post() { NEBULA_SKIP_NET=1 NEBULA_SKIP_DBUS=1 NEBULA_DEEPIN_CONF="$CONF" run "$NEBULA_ROOT/scripts/30-post.sh"; }

@test "deepin theme set to Theme8 with backup" {
  CONF="$BATS_TEST_TMPDIR/config.conf"
  printf '[basic.interface.expand_theme]\nvalue=Theme3\n\n[basic.interface.theme]\nvalue=Dark\n' > "$CONF"
  post
  [ "$status" -eq 0 ]
  run awk '/^\[basic\.interface\.expand_theme\]/{f=1;next} /^\[/{f=0} f&&/^value=/' "$CONF"
  [ "$output" = "value=Theme8" ]
  grep -qx 'value=Dark' "$CONF"
  grep -qx 'value=Theme3' "$CONF.nebula-bak"
}

@test "deepin conf missing is created with Theme8" {
  CONF="$BATS_TEST_TMPDIR/deepin/deepin-terminal/config.conf"
  post
  [ "$status" -eq 0 ]
  [ -f "$CONF" ]
  run awk '/^\[basic\.interface\.expand_theme\]/{f=1;next} /^\[/{f=0} f&&/^value=/' "$CONF"
  [ "$output" = "value=Theme8" ]
  [ ! -e "$CONF.nebula-bak" ]
}

@test "30-post is idempotent and keeps first backup" {
  CONF="$BATS_TEST_TMPDIR/config.conf"
  printf '[basic.interface.expand_theme]\nvalue=Theme3\n' > "$CONF"
  post; [ "$status" -eq 0 ]
  post; [ "$status" -eq 0 ]
  grep -qx 'value=Theme3' "$CONF.nebula-bak"
  [ "$(ls "$BATS_TEST_TMPDIR" | grep -c 'config.conf.nebula-bak')" -eq 1 ]
}

# ── downloads que falham não podem dizer "instalado" ─────────
@test "starship download failure is reported" {
  PATH=/usr/bin:/bin NEBULA_STARSHIP_URL=file:///nao/existe/install.sh \
    run "$NEBULA_ROOT/scripts/10-binaries.sh"
  [ "$status" -ne 0 ]
  [[ "$output" != *"starship instalado"* ]]
  [ ! -e "$HOME/.local/bin/starship" ]
}

@test "oh-my-zsh download failure is reported" {
  NEBULA_SKIP_DBUS=1 NEBULA_DEEPIN_CONF="$BATS_TEST_TMPDIR/x.conf" \
    NEBULA_OMZ_URL=file:///nao/existe/install.sh run "$NEBULA_ROOT/scripts/30-post.sh"
  [ "$status" -ne 0 ]
  [[ "$output" != *"Oh My Zsh instalado"* ]]
}


# ── Deepin Terminal instalado e configurado pelo NebulaOS ────
@test "apt list includes deepin-terminal by default" {
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  printf '#!/bin/sh\nexit 1\n' > "$BATS_TEST_TMPDIR/bin/dpkg-query"   # nada instalado
  chmod +x "$BATS_TEST_TMPDIR/bin/dpkg-query"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH" NEBULA_APT='echo APT' run "$NEBULA_ROOT/scripts/00-apt.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"APT zsh tmux stow git curl deepin-terminal"* ]]
}

@test "deepin not running: final notice tells how to finish" {
  CONF="$BATS_TEST_TMPDIR/config.conf"
  NEBULA_SKIP_NET=1 NEBULA_DEEPIN_CONF="$CONF" NEBULA_DEEPIN_DBUS_NAME=com.nebula.inexistente \
    run "$NEBULA_ROOT/scripts/30-post.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"abra o Deepin Terminal e rode: nebula update"* ]]
}
