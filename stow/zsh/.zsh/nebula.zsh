# NebulaOS · completion do comando nebula

_nebula() {
  local -a subcmds sessions
  subcmds=(
    'claude:Claude como líder, sub-agentes em painéis'
    'codex:Codex num painel'
    'ls:lista as sessões'
    'attach:volta para uma sessão'
    'kill:encerra uma sessão'
    'rename:renomeia uma sessão'
    'update:atualiza o NebulaOS'
    'help:ajuda'
  )
  if (( CURRENT == 2 )); then
    _describe 'comando' subcmds
    return
  fi
  case "${words[2]}" in
    attach|kill|rename)
      (( CURRENT == 3 )) || return
      sessions=(${(f)"$(tmux list-sessions -F '#S' 2>/dev/null)"})
      _describe 'sessão' sessions ;;
    claude|codex)
      if (( CURRENT == 4 )); then _directories; fi
      [[ "${words[2]}" == claude ]] && _arguments '--team[sub-agentes iniciais]:N:(1 2 3 4 5)' ;;
  esac
}

if (( $+functions[compdef] )); then
  compdef _nebula nebula
fi
