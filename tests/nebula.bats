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
  for v in 0 6 9 12 ""; do
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
  wait_log "claude args=--teammate-mode tmux --session-id "
  wait_log "teams=1 pwd=$BATS_TEST_TMPDIR"
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

# ── rename ───────────────────────────────────────────────────
@test "rename moves the session to the new name" {
  "$NEBULA" claude velho "$BATS_TEST_TMPDIR"
  run "$NEBULA" rename velho novo
  [ "$status" -eq 0 ]
  ! t has-session -t =velho 2>/dev/null
  t has-session -t =novo
  run "$NEBULA" ls
  [[ "$output" == *"novo"*"claude"* ]]
  [[ "$output" != *"velho"* ]]
}

@test "rename updates leader title, window name and NEBULA_SESSION" {
  "$NEBULA" claude velho "$BATS_TEST_TMPDIR"
  t split-window -t =velho: 'sleep 600'   # sub-agente: o líder não é o painel ativo
  "$NEBULA" rename velho novo
  leader=$(t show-options -t =novo: -v @nebula_leader)
  [ "$(t display-message -p -t "$leader" '#{pane_title}')" = "líder · novo" ]
  [ "$(t display-message -p -t "$leader" '#{window_name}')" = novo ]
  [ "$(t show-environment -t =novo: NEBULA_SESSION)" = "NEBULA_SESSION=novo" ]
}

@test "rename keeps the layout hook working" {
  "$NEBULA" claude velho "$BATS_TEST_TMPDIR"
  "$NEBULA" rename velho novo
  t split-window -h -t =novo: 'sleep 600'
  t split-window -h -t =novo: 'sleep 600'
  W=$(t display-message -p -t =novo: '#{window_width}')
  run bash -c "tmux -L '$NEBULA_TMUX_SOCKET' list-panes -t =novo: -F '#{pane_top} #{pane_width}' | grep -c '^0 $W\$'"
  [ "$output" -eq 1 ]
}

@test "rename normalizes the new name" {
  "$NEBULA" claude velho "$BATS_TEST_TMPDIR"
  run "$NEBULA" rename velho "novo nome"
  [ "$status" -eq 0 ]
  t has-session -t =novo-nome
}

@test "rename to an invalid name exits 2" {
  "$NEBULA" claude velho "$BATS_TEST_TMPDIR"
  run "$NEBULA" rename velho "..."
  [ "$status" -eq 2 ]
  t has-session -t =velho
}

@test "rename to an existing name exits 1" {
  "$NEBULA" claude a "$BATS_TEST_TMPDIR"
  "$NEBULA" claude b "$BATS_TEST_TMPDIR"
  run "$NEBULA" rename a b
  [ "$status" -eq 1 ]
  [[ "$output" == *"sessão 'b' já existe"* ]]
  t has-session -t =a
}

@test "rename unknown session exits 1" {
  run "$NEBULA" rename nada novo
  [ "$status" -eq 1 ]
  [[ "$output" == *"sessão 'nada' não existe"* ]]
}

@test "rename without both names exits 2" {
  run "$NEBULA" rename velho
  [ "$status" -eq 2 ]
}

@test "help lists rename" {
  run "$NEBULA" help
  [[ "$output" == *"nebula rename <atual> <novo>"* ]]
}

@test "rename finds leader by title in sessions created before @nebula_leader" {
  "$NEBULA" claude velho "$BATS_TEST_TMPDIR"
  t set-option -u -t =velho: @nebula_leader
  t split-window -t =velho: 'sleep 600'
  "$NEBULA" rename velho novo
  run bash -c "tmux -L '$NEBULA_TMUX_SOCKET' list-panes -t =novo: -F '#{pane_title}'"
  [[ "$output" == *"líder · novo"* ]]
  [[ "$output" != *"líder · velho"* ]]
}


# ── retomar a conversa depois do reboot ──────────────────────
state() { echo "$HOME/.local/state/nebula/$1"; }
state_get() { sed -n "s/^$2=//p" "$(state "$1")"; }
reboot() { t kill-server 2>/dev/null || true; : > "$FAKE_LOG"; }

@test "creating a claude session saves state with a session id" {
  "$NEBULA" claude s1 "$BATS_TEST_TMPDIR"
  [ -f "$(state s1)" ]
  [ "$(state_get s1 agent)" = claude ]
  [ "$(state_get s1 dir)" = "$BATS_TEST_TMPDIR" ]
  id=$(state_get s1 claude_session)
  [[ "$id" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]
  wait_log "--session-id $id"
}

@test "after reboot, nebula claude resumes the conversation in the original dir" {
  mkdir -p "$BATS_TEST_TMPDIR/outro"
  "$NEBULA" claude s1 "$BATS_TEST_TMPDIR"
  id=$(state_get s1 claude_session)
  reboot
  cd "$BATS_TEST_TMPDIR/outro"
  run "$NEBULA" claude s1
  [ "$status" -eq 0 ]
  [[ "$output" == *"retomando a conversa anterior de 's1'"* ]]
  wait_log "claude args=--teammate-mode tmux --resume $id teams=1 pwd=$BATS_TEST_TMPDIR "
  [ "$(t show-options -t =s1: -v @nebula_dir)" = "$BATS_TEST_TMPDIR" ]
}

@test "after reboot, attach also resumes" {
  "$NEBULA" claude s1 "$BATS_TEST_TMPDIR"
  id=$(state_get s1 claude_session)
  reboot
  run "$NEBULA" attach s1
  [ "$status" -eq 0 ]
  [[ "$output" == *"would-attach s1"* ]]
  wait_log "--resume $id"
}

@test "resume with --team sends the team prompt too" {
  "$NEBULA" claude s1 "$BATS_TEST_TMPDIR"
  reboot
  "$NEBULA" claude s1 --team 2
  wait_log "--resume "
  wait_log "Crie um time de agentes com 2 sub-agentes"
}

@test "resume that fails falls back to a new conversation" {
  "$NEBULA" claude s1 "$BATS_TEST_TMPDIR"
  old=$(state_get s1 claude_session)
  reboot
  FAKE_RESUME_FAIL=1 run "$NEBULA" claude s1
  [ "$status" -eq 0 ]
  [[ "$output" == *"começando uma nova"* ]]
  new=$(state_get s1 claude_session)
  [ -n "$new" ] && [ "$new" != "$old" ]
  t has-session -t =s1
  wait_log "--session-id $new"
}

@test "codex session does not save state" {
  "$NEBULA" codex c1 "$BATS_TEST_TMPDIR"
  [ ! -e "$(state c1)" ]
}

@test "ls shows stopped sessions as resumable" {
  "$NEBULA" claude s1 "$BATS_TEST_TMPDIR"
  reboot
  run "$NEBULA" ls
  [ "$status" -eq 0 ]
  [[ "$output" == *"s1"*"claude"*"parada (retomável)"* ]]
}

@test "ls does not mark running sessions as stopped" {
  "$NEBULA" claude s1 "$BATS_TEST_TMPDIR"
  run "$NEBULA" ls
  [[ "$output" != *"parada"* ]]
}

@test "kill removes the state" {
  "$NEBULA" claude s1 "$BATS_TEST_TMPDIR"
  "$NEBULA" kill s1
  [ ! -e "$(state s1)" ]
}

@test "kill of a stopped session removes the state" {
  "$NEBULA" claude s1 "$BATS_TEST_TMPDIR"
  reboot
  run "$NEBULA" kill s1
  [ "$status" -eq 0 ]
  [ ! -e "$(state s1)" ]
  run "$NEBULA" ls
  [[ "$output" == *"nenhuma sessão nebula"* ]]
}

@test "rename moves the state" {
  "$NEBULA" claude velho "$BATS_TEST_TMPDIR"
  id=$(state_get velho claude_session)
  "$NEBULA" rename velho novo
  [ ! -e "$(state velho)" ]
  [ "$(state_get novo claude_session)" = "$id" ]
}

# ── recriar os sub-agentes na retomada ───────────────────────
# histórico falso do Claude: um arquivo por sub-agente do time do líder
fake_teammate() {   # fake_teammate <sessão-nebula> <nome> [time]
  local id team proj
  id=$(state_get "$1" claude_session)
  team="${3:-session-${id:0:8}}"
  proj="$HOME/.claude/projects/$(printf '%s' "$BATS_TEST_TMPDIR" | sed 's/[^A-Za-z0-9]/-/g')"
  mkdir -p "$proj"
  printf '{"type":"user","teamName":"%s","agentName":"%s"}\n{"teamName":"%s","agentName":"%s"}\n' \
    "$team" "$2" "$team" "$2" > "$proj/$RANDOM$RANDOM.jsonl"
}

@test "resume asks the leader to recreate previous teammates by name" {
  "$NEBULA" claude p1 "$BATS_TEST_TMPDIR"
  fake_teammate p1 Zeus
  fake_teammate p1 Arthemis
  fake_teammate p1 Hermes session-outrotim   # de outro time: não entra
  reboot
  run "$NEBULA" attach p1
  [ "$status" -eq 0 ]
  [[ "$output" == *"pedindo ao líder para recriar os sub-agentes ativos"* ]]
  wait_log "--resume "
  wait_log "Esta sessão foi retomada. Na sessão anterior você teve os sub-agentes "
  wait_log "Recrie, com os mesmos nomes e papéis, apenas os que ainda estavam ativos no fim da sessão"
  grep -q "Zeus" "$FAKE_LOG"
  grep -q "Arthemis" "$FAKE_LOG"
  ! grep -q "Hermes" "$FAKE_LOG"
}

@test "resume without previous teammates sends no message" {
  "$NEBULA" claude p1 "$BATS_TEST_TMPDIR"
  id=$(state_get p1 claude_session)
  reboot
  "$NEBULA" claude p1
  wait_log "--resume $id teams=1"
}

@test "resume with --team sends the generic prompt instead" {
  "$NEBULA" claude p1 "$BATS_TEST_TMPDIR"
  fake_teammate p1 Zeus
  reboot
  "$NEBULA" claude p1 --team 3
  wait_log "Crie um time de agentes com 3 sub-agentes"
  ! grep -q "Esta sessão foi retomada" "$FAKE_LOG"
}

@test "resume with --sem-time sends no message" {
  "$NEBULA" claude p1 "$BATS_TEST_TMPDIR"
  id=$(state_get p1 claude_session)
  fake_teammate p1 Zeus
  reboot
  "$NEBULA" attach p1 --sem-time
  wait_log "--resume $id teams=1"
}

@test "--team and --sem-time together exit 2" {
  run "$NEBULA" claude p1 "$BATS_TEST_TMPDIR" --team 2 --sem-time
  [ "$status" -eq 2 ]
}

# ── attach aceita --team ─────────────────────────────────────
@test "attach --team N after reboot sends the generic team prompt" {
  "$NEBULA" claude p1 "$BATS_TEST_TMPDIR"
  fake_teammate p1 Zeus
  reboot
  run "$NEBULA" attach p1 --team 2
  [ "$status" -eq 0 ]
  wait_log "--resume "
  wait_log "Crie um time de agentes com 2 sub-agentes"
  ! grep -q "Esta sessão foi retomada" "$FAKE_LOG"
}

@test "attach --team on a running session warns it is ignored" {
  "$NEBULA" claude p1 "$BATS_TEST_TMPDIR"
  run "$NEBULA" attach p1 --team 2
  [ "$status" -eq 0 ]
  [[ "$output" == *"--team ignorado"* ]]
  [[ "$output" == *"would-attach p1"* ]]
}

@test "attach --team validates the value" {
  run "$NEBULA" attach p1 --team 9
  [ "$status" -eq 2 ]
  [[ "$output" == *"--team aceita 1 a 5"* ]]
}

@test "attach with --team and --sem-time exits 2" {
  run "$NEBULA" attach p1 --team 2 --sem-time
  [ "$status" -eq 2 ]
}

# ── sub-agentes com nome ─────────────────────────────────────
@test "--team with names asks for named teammates" {
  "$NEBULA" claude p1 "$BATS_TEST_TMPDIR" --team Zeus,Arthemis
  wait_log "Crie um time de agentes com 2 sub-agentes (teammates) para esta sessão, chamados Zeus e Arthemis."
}

@test "--team with names saves them in the session state" {
  "$NEBULA" claude p1 "$BATS_TEST_TMPDIR" --team Zeus,Arthemis
  [ "$(state_get p1 team_names)" = "Zeus,Arthemis" ]
}

@test "--team N does not save names" {
  "$NEBULA" claude p1 "$BATS_TEST_TMPDIR" --team 2
  [ -z "$(state_get p1 team_names)" ]
}

@test "after reboot, attach recreates the saved names without searching history" {
  "$NEBULA" claude p1 "$BATS_TEST_TMPDIR" --team Zeus,Arthemis
  fake_teammate p1 teammate-9          # histórico diferente: não deve ser usado
  reboot
  run "$NEBULA" attach p1
  [ "$status" -eq 0 ]
  wait_log "Esta sessão foi retomada. Recrie os sub-agentes Zeus e Arthemis com os mesmos nomes e papéis que tinham antes"
  ! grep -q "teammate-9" "$FAKE_LOG"
}

@test "resume with new names replaces the saved ones" {
  "$NEBULA" claude p1 "$BATS_TEST_TMPDIR" --team Zeus,Arthemis
  reboot
  "$NEBULA" attach p1 --team Apolo,Hera,Atena
  wait_log "com 3 sub-agentes (teammates) para esta sessão, chamados Apolo, Hera e Atena."
  [ "$(state_get p1 team_names)" = "Apolo,Hera,Atena" ]
}

@test "--team names are validated" {
  for v in "Zeus,,Hera" "Ze us" "a,b,c,d,e,f" "Zeus;rm" ","; do
    run "$NEBULA" claude p1 "$BATS_TEST_TMPDIR" --team "$v"
    [ "$status" -eq 2 ]
    [[ "$output" == *"--team aceita 1 a 5"* ]]
  done
}

@test "attach --team names is validated too" {
  run "$NEBULA" attach p1 --team "Ze us"
  [ "$status" -eq 2 ]
}

@test "rename keeps saved team names" {
  "$NEBULA" claude velho "$BATS_TEST_TMPDIR" --team Zeus
  "$NEBULA" rename velho novo
  [ "$(state_get novo team_names)" = "Zeus" ]
}
