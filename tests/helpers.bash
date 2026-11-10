# Infra de teste compartilhada pelos arquivos .bats
NEBULA_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
export NEBULA_ROOT

setup_nebula_env() {
  export NEBULA_TMUX_SOCKET="nebula-test-$$-${BATS_TEST_NUMBER:-0}"
  export NEBULA_NO_ATTACH=1
  export FAKE_LOG="$BATS_TEST_TMPDIR/fake.log"
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
  unset TMUX
  export PATH="$NEBULA_ROOT/tests/fakes:$PATH"
}

teardown_nebula_env() {
  tmux -L "$NEBULA_TMUX_SOCKET" kill-server 2>/dev/null || true
}

t() { tmux -L "$NEBULA_TMUX_SOCKET" "$@"; }

# espera até o arquivo de log conter a substring (até ~2s)
wait_log() {
  for _ in $(seq 1 40); do
    grep -qF -- "$1" "$FAKE_LOG" 2>/dev/null && return 0
    sleep 0.05
  done
  echo "log não contém: $1"; cat "$FAKE_LOG" 2>/dev/null; return 1
}
