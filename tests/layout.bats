#!/usr/bin/env bats
load helpers

setup() { setup_nebula_env; NEBULA="$NEBULA_ROOT/bin/nebula"; }
teardown() { teardown_nebula_env; }

# imprime "top left height width" de cada painel, ordenado
panes() { t list-panes -t "=$1:" -F '#{pane_top} #{pane_left} #{pane_height} #{pane_width}' | sort -n -k1,1 -k2,2; }
win_height() { t display-message -p -t "=$1:" '#{window_height}'; }

# simula o Claude abrindo um painel de sub-agente
external_split() { t split-window -t "=$1:" 'sleep 600'; }

@test "two external splits: leader on top, two side by side below" {
  "$NEBULA" claude L "$BATS_TEST_TMPDIR"
  external_split L
  external_split L
  mapfile -t P < <(panes L)
  [ "${#P[@]}" -eq 3 ]
  read -r top0 left0 h0 _ <<<"${P[0]}"
  read -r top1 left1 _ _ <<<"${P[1]}"
  read -r top2 left2 _ _ <<<"${P[2]}"
  [ "$top0" -eq 0 ] && [ "$left0" -eq 0 ]
  H=$(win_height L)
  # líder com ~55% da altura (tolerância 50–60%)
  [ $((h0 * 100 / H)) -ge 50 ] && [ $((h0 * 100 / H)) -le 60 ]
  # os dois de baixo na mesma faixa, lado a lado
  [ "$top1" -gt 0 ] && [ "$top1" -eq "$top2" ]
  [ "$left1" -ne "$left2" ]
}

@test "three splits keep leader on top, three below" {
  "$NEBULA" claude L "$BATS_TEST_TMPDIR"
  external_split L; external_split L; external_split L
  mapfile -t P < <(panes L)
  [ "${#P[@]}" -eq 4 ]
  read -r top0 _ _ _ <<<"${P[0]}"
  [ "$top0" -eq 0 ]
  bottoms=$(printf '%s\n' "${P[@]:1}" | awk '{print $1}' | sort -u | wc -l)
  [ "$bottoms" -eq 1 ]
}

@test "non-nebula session keeps its own layout" {
  t new-session -d -s plain 'sleep 600'
  t split-window -h -t =plain: 'sleep 600'
  t split-window -h -t =plain: 'sleep 600'
  # nenhum painel ocupa a largura toda: continua em colunas
  W=$(t display-message -p -t =plain: '#{window_width}')
  run bash -c "tmux -L '$NEBULA_TMUX_SOCKET' list-panes -t =plain: -F '#{pane_width}' | grep -cx '$W'"
  [ "$output" -eq 0 ]
}

@test "layout holds with NebulaOS tmux.conf loaded" {
  cp "$NEBULA_ROOT/stow/tmux/.tmux.conf" "$HOME/.tmux.conf"
  "$NEBULA" claude L "$BATS_TEST_TMPDIR"
  [ "$(t show-options -gv status)" = off ]
  external_split L
  external_split L
  mapfile -t P < <(panes L)
  [ "${#P[@]}" -eq 3 ]
  read -r top1 left1 _ _ <<<"${P[1]}"
  read -r top2 left2 _ _ <<<"${P[2]}"
  [ "$top1" -eq "$top2" ] && [ "$left1" -ne "$left2" ]
  [ "$(t display-message -p -t =L:.1 '#{pane_title}')" = "líder · L" ]
}

# reproduz a sequência real do backend tmux do Claude Code (2.1.x):
# 1º sub-agente: split -h -l 70%; demais: split + select-layout main-vertical + resize-pane -x 30%
claude_spawn() {
  local leader; leader=$(t list-panes -t "=$1:" -F '#{pane_id}' | head -1)
  if [ "$(t list-panes -t "=$1:" | wc -l)" -eq 1 ]; then
    t split-window -d -t "$leader" -h -l 70% 'sleep 600'
  else
    t split-window -d -t "$(t list-panes -t "=$1:" -F '#{pane_id}' | tail -1)" 'sleep 600'
    t select-layout -t "=$1:" main-vertical
    t resize-pane -t "$leader" -x 30%
  fi
}

@test "Claude's real spawn sequence still ends with leader on top" {
  "$NEBULA" claude L "$BATS_TEST_TMPDIR"
  claude_spawn L
  claude_spawn L
  mapfile -t P < <(panes L)
  [ "${#P[@]}" -eq 3 ]
  read -r top0 left0 _ w0 <<<"${P[0]}"
  read -r top1 left1 _ _ <<<"${P[1]}"
  read -r top2 left2 _ _ <<<"${P[2]}"
  W=$(t display-message -p -t =L: '#{window_width}')
  [ "$top0" -eq 0 ] && [ "$left0" -eq 0 ] && [ "$w0" -eq "$W" ]
  [ "$top1" -gt 0 ] && [ "$top1" -eq "$top2" ] && [ "$left1" -ne "$left2" ]
}

@test "hook lays out the split window, not the current one" {
  "$NEBULA" claude L "$BATS_TEST_TMPDIR"
  leader=$(t list-panes -t =L: -F '#{pane_id}' | head -1)
  t new-window -t =L: 'sleep 600'
  t split-window -h -t "$leader" 'sleep 600'
  t split-window -h -t "$leader" 'sleep 600'
  W=$(t display-message -p -t "$leader" '#{window_width}')
  [ "$(t display-message -p -t "$leader" '#{pane_width}')" -eq "$W" ]
}
