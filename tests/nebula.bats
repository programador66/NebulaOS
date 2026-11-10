#!/usr/bin/env bats
load helpers

setup() { setup_nebula_env; NEBULA="$NEBULA_ROOT/bin/nebula"; }
teardown() { teardown_nebula_env; }

# ── ajuda e uso ──────────────────────────────────────────────
@test "no args prints help" {
  run "$NEBULA"
  [ "$status" -eq 0 ]
  [[ "$output" == *"nebula claude <nome>"* ]]
}

@test "help prints help" {
  run "$NEBULA" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"nebula codex <nome>"* ]]
}

@test "unknown subcommand exits 2 with help" {
  run "$NEBULA" foo
  [ "$status" -eq 2 ]
  [[ "$output" == *"nebula claude <nome>"* ]]
}

@test "claude without name exits 2" {
  run "$NEBULA" claude
  [ "$status" -eq 2 ]
}

@test "unknown flag exits 2" {
  run "$NEBULA" claude x --banana
  [ "$status" -eq 2 ]
}

# ── validações ───────────────────────────────────────────────
@test "missing dir exits 1" {
  run "$NEBULA" claude x /nao/existe
  [ "$status" -eq 1 ]
  [[ "$output" == *"diretório não existe"* ]]
}

@test "missing claude binary exits 1 with hint" {
  [ -x /usr/bin/claude ] && skip "claude instalado em /usr/bin"
  PATH=/usr/bin:/bin run "$NEBULA" claude x
  [ "$status" -eq 1 ]
  [[ "$output" == *"claude não encontrado"* ]]
  [[ "$output" == *"claude.ai/install.sh"* ]]
}

@test "missing codex binary exits 1 with hint" {
  [ -x /usr/bin/codex ] && skip "codex instalado em /usr/bin"
  PATH=/usr/bin:/bin run "$NEBULA" codex x
  [ "$status" -eq 1 ]
  [[ "$output" == *"codex não encontrado"* ]]
}

@test "--team on codex exits 2" {
  run "$NEBULA" codex x --team 2
  [ "$status" -eq 2 ]
  [[ "$output" == *"--team só vale para claude"* ]]
}

@test "--team out of range exits 2" {
  for v in 0 6 9 abc ""; do
    run "$NEBULA" claude x --team "$v"
    [ "$status" -eq 2 ]
    [[ "$output" == *"--team aceita 1 a 5"* ]]
  done
}

@test "--team without value exits 2" {
  run "$NEBULA" claude x --team
  [ "$status" -eq 2 ]
}

# ── abrir e retomar sessões ──────────────────────────────────
@test "claude creates session in dir with agent teams" {
  run "$NEBULA" claude s1 "$BATS_TEST_TMPDIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"would-attach s1"* ]]
  t has-session -t =s1
  wait_log "claude args=--teammate-mode tmux teams=1 pwd=$BATS_TEST_TMPDIR"
}

@test "claude --team 2 passes team prompt" {
  run "$NEBULA" claude s1 "$BATS_TEST_TMPDIR" --team 2
  [ "$status" -eq 0 ]
  wait_log "Crie um time de agentes com 2 sub-agentes (teammates) para esta sessão. Não comece nenhuma tarefa: apenas crie o time e aguarde minhas instruções."
}

@test "codex creates session without agent teams" {
  run "$NEBULA" codex c1 "$BATS_TEST_TMPDIR"
  [ "$status" -eq 0 ]
  wait_log "codex args= teams= pwd=$BATS_TEST_TMPDIR"
}

@test "session options record agent and dir" {
  "$NEBULA" claude s1 "$BATS_TEST_TMPDIR"
  [ "$(t show-options -t =s1: -v @nebula_agent)" = claude ]
  [ "$(t show-options -t =s1: -v @nebula_dir)" = "$BATS_TEST_TMPDIR" ]
}

@test "leader pane has title" {
  "$NEBULA" claude s1 "$BATS_TEST_TMPDIR"
  [ "$(t display-message -p -t =s1: '#{pane_title}')" = "líder · s1" ]
}

@test "existing session is resumed, not recreated" {
  "$NEBULA" claude s1 "$BATS_TEST_TMPDIR"
  wait_log "claude args="
  run "$NEBULA" claude s1 "$BATS_TEST_TMPDIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"would-attach s1"* ]]
  [ "$(t list-sessions -F '#S' | grep -c '^s1$')" -eq 1 ]
  [ "$(t list-panes -t =s1: | wc -l)" -eq 1 ]
  sleep 0.3
  [ "$(grep -c '^claude ' "$FAKE_LOG")" -eq 1 ]
}

@test "resume with different dir warns" {
  mkdir -p "$BATS_TEST_TMPDIR/outro"
  "$NEBULA" claude s1 "$BATS_TEST_TMPDIR"
  run "$NEBULA" claude s1 "$BATS_TEST_TMPDIR/outro"
  [ "$status" -eq 0 ]
  [[ "$output" == *"aviso"* ]]
  [[ "$output" == *"$BATS_TEST_TMPDIR"* ]]
}

@test "inside tmux switches instead of nesting" {
  TMUX=/tmp/fake,1,0 run "$NEBULA" claude s1 "$BATS_TEST_TMPDIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"would-switch s1"* ]]
}

@test "name with spaces is normalized" {
  run "$NEBULA" claude "minha feature" "$BATS_TEST_TMPDIR"
  [ "$status" -eq 0 ]
  t has-session -t =minha-feature
  [[ "$output" == *"nome ajustado para 'minha-feature'"* ]]
}

@test "dir defaults to PWD" {
  cd "$BATS_TEST_TMPDIR"
  "$NEBULA" claude s1
  [ "$(t show-options -t =s1: -v @nebula_dir)" = "$BATS_TEST_TMPDIR" ]
}

# ── ls / attach / kill ───────────────────────────────────────
@test "ls lists nebula sessions with agent and dir" {
  "$NEBULA" claude s1 "$BATS_TEST_TMPDIR"
  "$NEBULA" codex c1 "$BATS_TEST_TMPDIR"
  run "$NEBULA" ls
  [ "$status" -eq 0 ]
  [[ "$output" == *"s1"*"claude"*"$BATS_TEST_TMPDIR"* ]]
  [[ "$output" == *"c1"*"codex"* ]]
}

@test "ls ignores plain tmux sessions" {
  "$NEBULA" claude s1 "$BATS_TEST_TMPDIR"
  t new-session -d -s plain 'sleep 600'
  run "$NEBULA" ls
  [[ "$output" != *"plain"* ]]
}

@test "ls with no sessions" {
  run "$NEBULA" ls
  [ "$status" -eq 0 ]
  [[ "$output" == *"nenhuma sessão nebula"* ]]
}

@test "attach existing session" {
  "$NEBULA" claude s1 "$BATS_TEST_TMPDIR"
  run "$NEBULA" attach s1
  [ "$status" -eq 0 ]
  [[ "$output" == *"would-attach s1"* ]]
}

@test "attach unknown session exits 1" {
  run "$NEBULA" attach nada
  [ "$status" -eq 1 ]
  [[ "$output" == *"sessão 'nada' não existe"* ]]
}

@test "kill removes session" {
  "$NEBULA" claude s1 "$BATS_TEST_TMPDIR"
  run "$NEBULA" kill s1
  [ "$status" -eq 0 ]
  ! t has-session -t =s1 2>/dev/null
}

@test "kill unknown session exits 1" {
  run "$NEBULA" kill nada
  [ "$status" -eq 1 ]
  [[ "$output" == *"sessão 'nada' não existe"* ]]
}

@test "attach without name exits 2" {
  run "$NEBULA" attach
  [ "$status" -eq 2 ]
}

@test "leader exports NEBULA_SESSION" {
  "$NEBULA" claude s1 "$BATS_TEST_TMPDIR"
  wait_log "session=s1"
}

@test "codex leader exports NEBULA_SESSION" {
  "$NEBULA" codex c1 "$BATS_TEST_TMPDIR"
  wait_log "codex args= teams= pwd=$BATS_TEST_TMPDIR session=c1"
}

@test "name with quote and format chars is whitelisted" {
  run "$NEBULA" claude "it's #{x}" "$BATS_TEST_TMPDIR"
  [ "$status" -eq 0 ]
  t has-session -t =it-s-x-
  [ "$(t show-options -t =it-s-x-: -v @nebula_agent)" = claude ]
  t split-window -t =it-s-x-: 'sleep 600'
}

@test "name with only invalid chars is rejected" {
  run "$NEBULA" claude "..." "$BATS_TEST_TMPDIR"
  [ "$status" -eq 2 ]
}

@test "agent that exits on startup gives a clear error" {
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  printf '#!/bin/sh\nexit 3\n' > "$BATS_TEST_TMPDIR/bin/claude"
  chmod +x "$BATS_TEST_TMPDIR/bin/claude"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH" run "$NEBULA" claude s1 "$BATS_TEST_TMPDIR"
  [ "$status" -eq 1 ]
  [[ "$output" == *"o agente encerrou ao iniciar"* ]]
}
