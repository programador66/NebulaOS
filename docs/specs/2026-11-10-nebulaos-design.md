# NebulaOS — Design

- **Data:** 2026-11-10
- **Status:** aguardando revisão
- **Inspiração:** [AntaresOS](https://github.com/HenriqueMachine/AntaresOS) (dotfiles macOS com Stow + scripts numerados)

## 1. Objetivo

Um ambiente de desenvolvimento pessoal para **Ubuntu 24.04 (X11)**, versionado e
reprovisionável com um comando, cujo foco principal é **abrir sessões de agentes de IA
(Claude Code ou Codex) com um único comando**, num layout em que um agente líder fica
em cima e seus sub-agentes ficam lado a lado embaixo.

### Critérios de sucesso

1. `./install.sh` numa máquina Ubuntu limpa deixa o ambiente pronto, e é idempotente.
2. `nebula claude <nome>` abre, no Deepin Terminal, uma sessão em que o Claude é o líder
   e, ao pedir sub-agentes, eles surgem em painéis lado a lado abaixo do líder.
3. Fechar a janela não mata a sessão; `nebula attach <nome>` retoma.
4. Nada fora do NebulaOS muda de comportamento: o `~/.claude/settings.json`, o shell de
   login (bash) e as configurações de git/SSH ficam intactos.

### Fora de escopo (v1)

- Flutter, Neovim/LazyVim, ferramentas CLI extras (fzf, eza, bat…), library/notas.
- Sub-agentes do Codex em painéis separados (o Codex não oferece isso; ficaria para uma v2
  com ponte própria).
- macOS, Wayland, outros terminais.

## 2. Decisões

| Decisão | Escolha | Motivo |
|---|---|---|
| Terminal | **Deepin Terminal** (5.9.x) com o tema embutido **Theme8** (fundo `#000000`, texto `#00cd00`) | Terminal e tema que o usuário já usa |
| Painéis | **tmux "invisível"** dentro do Deepin | O Deepin não pode ser dividido por script (CLI só tem `-e/-w/-C`; D-Bus só expõe cor/fonte/opacidade). O agent teams do Claude Code só faz painéis com tmux ou iTerm2. |
| Multi-agente | **Claude Code agent teams** (experimental), `--teammate-mode tmux` | O líder delega para os sub-agentes e o usuário fala com o líder (podendo falar com cada sub-agente clicando no painel) |
| Codex | Painel único, com os sub-agentes internos dele (`/subagents`) | Sem suporte a painéis no Codex |
| Shell | **zsh + Oh My Zsh + starship**, só dentro do Deepin | Sem `chsh`; o bash continua como shell de login |
| Dotfiles | **GNU Stow**, como no AntaresOS | Links simbólicos simples e reversíveis |
| Nome do comando | `nebula` | — |

## 3. Estrutura do repositório

```
NebulaOS/
├── install.sh              # full | --dotfiles
├── update.sh               # git pull + stow + pós-instalação
├── bin/nebula              # a CLI (bash)
├── scripts/
│   ├── lib.sh              # cores, step/info/ok/warn/err, have(), backup()
│   ├── 00-apt.sh           # zsh tmux stow git curl (com sudo, avisando antes)
│   ├── 10-binaries.sh      # starship (instalador oficial, em ~/.local/bin)
│   ├── 20-stow.sh          # backup *.nebula-bak + stow dos pacotes + link ~/.local/bin/nebula
│   └── 30-post.sh          # Oh My Zsh + plugins, Deepin (Theme8 + zsh)
├── stow/
│   ├── zsh/                # .zshrc, .zsh/{exports,aliases,nebula}.zsh
│   ├── starship/           # .config/starship.toml
│   └── tmux/               # .tmux.conf
├── tests/                  # bats: nebula.bats, install.bats, fakes/{claude,codex}
└── docs/specs/
```

## 4. CLI `nebula`

| Comando | Comportamento |
|---|---|
| `nebula claude <nome> [dir] [--team N]` | Cria ou retoma a sessão tmux `<nome>` em `dir` (padrão: `$PWD`). O painel líder roda `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 claude --teammate-mode tmux`. Com `--team N`, o Claude recebe como prompt inicial uma instrução para criar N sub-agentes e aguardar a tarefa. |
| `nebula codex <nome> [dir]` | Igual, com `codex` num painel único |
| `nebula ls` | Lista as sessões |
| `nebula attach <nome>` | Retoma uma sessão |
| `nebula kill <nome>` | Encerra a sessão (e os painéis dos sub-agentes) |
| `nebula update` | Roda `update.sh` |
| `nebula` / `nebula help` | Ajuda |

- A variável do agent teams é definida **apenas no processo do líder** dessa sessão; o
  `~/.claude/settings.json` não é tocado.
- A sessão guarda o agente e o diretório como opções do tmux (`@nebula_agent`,
  `@nebula_dir`), usadas para avisos ao retomar.

### Layout

- Um hook do tmux (`after-split-window`), restrito às sessões do nebula, reaplica
  `select-layout main-horizontal` com `main-pane-height 55%`.
- Resultado: o líder ocupa a faixa de cima e os N sub-agentes dividem a faixa de baixo lado a lado.
- O título de cada painel aparece na borda (`líder · <nome>` / nome do sub-agente).

### Tratamento de erros

| Situação | Comportamento |
|---|---|
| Sessão já existe | Retoma; avisa se o `dir` pedido difere de `@nebula_dir` |
| Rodado de dentro do tmux | `switch-client` para a sessão em vez de aninhar |
| `claude`/`codex`/`tmux` ausente | Mensagem dizendo como instalar; exit ≠ 0 |
| `dir` inexistente | Erro, nada é criado |
| Nome com espaço, `.` ou `:` | Normaliza para `-` e avisa |
| Subcomando ou argumento desconhecido | Ajuda; exit 2 |

## 5. Visual

**tmux** (`.tmux.conf`):
- `status off`
- Bordas finas: inativa em cinza escuro, ativa em `#00cd00`
- `pane-border-status top` com o título do painel
- `mouse on`
- Prefixo padrão `Ctrl+b`
- `default-terminal tmux-256color` com truecolor

**Deepin Terminal:**
- O `30-post.sh` garante `[basic.interface.expand_theme] value=Theme8` e define o shell
  do Deepin como `zsh`, editando só essas chaves no `config.conf` (com backup).
- O arquivo inteiro **não** é versionado, porque o Deepin o reescreve.

**starship:**
- Prompt verde e mínimo: diretório, branch git, status do último comando e, dentro do
  tmux, o nome da sessão nebula.

## 6. zsh

- Oh My Zsh com `zsh-autosuggestions` e `zsh-syntax-highlighting`.
- O `.zshrc` migra o que o `.bashrc` atual faz: `nvm` (de onde vem o `codex`), `sdkman`,
  `~/.local/bin` no `PATH` (de onde vem o `claude`) e o alias `alert`.
- Completion do `nebula` (subcomandos e nomes de sessões).

## 7. Instalação

- Os modos e a ordem de execução estão na seção 3.
- **Sem sobrescrever:** antes do stow, todo arquivo real que conflite vira `<arquivo>.nebula-bak`.
- **Idempotente:** cada passo checa se já foi feito.
- O `sudo` é usado só para o `apt`, com aviso antes.

## 8. Testes

- **bats** para `bin/nebula`:
  - Usa `claude`/`codex` falsos que registram argumentos e ambiente.
  - Roda num servidor tmux isolado (`tmux -L nebula-test`).
  - Cobre:
    - criação no diretório certo
    - variável do agent teams e `--teammate-mode tmux`
    - `--team N`
    - retomada de sessão
    - layout: líder em cima e 2 painéis lado a lado embaixo, com splits simulados
    - todos os casos da tabela de erros
- **bats** para a instalação:
  - Roda com `$HOME` temporário e `apt` simulado.
  - Verifica os links, os backups `*.nebula-bak` e a idempotência (duas execuções).
- **shellcheck** em todos os scripts.
- **Validação manual:** no Deepin, `nebula claude teste --team 2` e verificar os dois
  sub-agentes nos painéis de baixo.

## 9. Publicação

- Repositório público: `https://github.com/programador66/NebulaOS`.
- Antes de cada push, conferir que o histórico não contém dados de outras identidades
  git da máquina.

## 10. Riscos

- **Agent teams é experimental:** flags e comportamento podem mudar. A CLI isola o
  uso num ponto só (a função que monta o comando do líder).
- **O tmux no Linux é "menos testado" segundo a documentação do Claude Code:** validação
  manual obrigatória antes de considerar pronto.
- **Custo:** cada sub-agente é uma instância completa do Claude.
- **Atalhos do Deepin vs. tmux:** o prefixo `Ctrl+b` não conflita com os atalhos
  padrão do Deepin. Se surgir conflito, ajustar no `.tmux.conf`.
