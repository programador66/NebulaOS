# NebulaOS

**Sessões de agentes de IA (Claude Code / Codex) com um comando, no Ubuntu + Deepin Terminal.**

Um agente líder em cima, os sub-agentes dele lado a lado embaixo, tudo no tema verde
do Deepin Terminal, e as sessões continuam vivas quando você fecha a janela.

```
┌──────────────────────────────────────────────┐
│  líder · minha-feature   (você fala aqui)     │
├───────────────────────┬──────────────────────┤
│  sub-agente 1          │  sub-agente 2         │
└───────────────────────┴──────────────────────┘
```

Inspirado no [AntaresOS](https://github.com/HenriqueMachine/AntaresOS).

## Requisitos

- Ubuntu 24.04 (X11) ou derivado
- [Claude Code](https://claude.com/claude-code) e/ou [Codex CLI](https://github.com/openai/codex)

O [Deepin Terminal](https://github.com/linuxdeepin/deepin-terminal) é instalado
automaticamente (pacote `deepin-terminal` do Ubuntu).

## Instalação

```bash
git clone https://github.com/programador66/NebulaOS.git
cd NebulaOS
./install.sh
```

`install.sh` é idempotente e roda, em ordem:

| Passo | O que faz |
|---|---|
| `00-apt` | instala o que falta entre `zsh tmux stow git curl deepin-terminal` (avisa antes de usar `sudo`) |
| `10-binaries` | instala o [starship](https://starship.rs) em `~/.local/bin` |
| `20-stow` | linka os dotfiles (zsh, starship, tmux) no `$HOME` e o comando `nebula` em `~/.local/bin` |
| `30-post` | Oh My Zsh + plugins, tema **Theme8** e shell **zsh** no Deepin Terminal |

- Arquivos que já existirem viram `<arquivo>.nebula-bak`. Nada é sobrescrito.
- O shell de login continua o mesmo: o zsh vale só dentro do Deepin Terminal.
- Para aplicar só os dotfiles: `./install.sh --dotfiles`.
- O shell zsh do Deepin é definido com o Deepin aberto. Se ele estava fechado durante a
  instalação, o instalador avisa: abra o Deepin Terminal e rode `nebula update`.

## Uso

| Comando | O que faz |
|---|---|
| `nebula claude <nome> [dir] [--team N\|nomes]` | abre (ou retoma) a sessão `<nome>` em `dir` (padrão: o diretório atual) com o Claude como líder |
| `nebula codex <nome> [dir]` | igual, com o Codex num painel |
| `nebula ls` | lista as sessões (inclusive as paradas depois de um reboot) |
| `nebula attach <nome> [--team N\|nomes] [--sem-time]` | volta para uma sessão (depois de fechar a janela, por exemplo); depois de um reboot, as opções valem como no `nebula claude` |
| `nebula kill <nome>` | encerra a sessão e os sub-agentes |
| `nebula rename <atual> <novo>` | renomeia uma sessão (inclusive o título do líder e o nome da janela) |
| `nebula update` | `git pull` + reaplica dotfiles e pós-instalação |

### Trabalhando com sub-agentes (Claude)

O `nebula claude` liga o recurso experimental
[agent teams](https://code.claude.com/docs/en/agent-teams) **só nessa sessão**. Seu
`~/.claude/settings.json` não é alterado.

1. Fale com o líder, no painel de cima. Peça o time, por exemplo: *"crie 2 sub-agentes: um
   implementa, outro escreve testes"*. Ou já abra com `--team 2`, ou com nomes:
   `--team Zeus,Arthemis`. A sessão lembra os nomes para as próximas retomadas.
2. O Claude abre cada sub-agente num painel novo, e o NebulaOS os organiza lado a lado embaixo.
3. Para falar direto com um sub-agente, clique no painel dele.

### Depois de reiniciar o computador

O tmux não sobrevive a um reboot, mas a conversa com o Claude sim. Cada sessão criada com
`nebula claude` guarda o ID exato da conversa em `~/.local/state/nebula/<nome>`.

- `nebula ls` mostra essas sessões como `parada (retomável)`.
- `nebula claude <nome>` ou `nebula attach <nome>` recria a sessão **na pasta original**
  e retoma a mesma conversa (`claude --resume <id>`).
- Os sub-agentes são recriados automaticamente. Se a sessão foi criada com nomes
  (`--team Zeus,Arthemis`), o líder recria exatamente esses. Senão, o nebula encontra no
  histórico do Claude os nomes dos sub-agentes daquele líder e pede a ele para recriar, com os
  mesmos nomes e papéis, os que estavam ativos no fim. Eles voltam com o contexto que o líder passa, não com a
  memória completa da conversa antiga.
- `--sem-time` retoma só o líder; `--team N` pede N sub-agentes novos e genéricos;
  `--team A,B` usa esses nomes e passa a lembrá-los.
- Se a conversa não existir mais (por exemplo, a sessão foi criada mas nunca usada), o
  nebula avisa e começa uma nova.
- `nebula kill <nome>` apaga esse registro. A conversa continua no histórico do Claude
  (`claude --resume`).

### Atalhos úteis

- **Mouse:** clique para escolher o painel; a roda rola o histórico.
- `Ctrl+b` `d`: sai da sessão sem encerrá-la (volte com `nebula attach <nome>`).
- `Ctrl+b` `z`: amplia/restaura o painel atual.

## Limitações

- O agent teams do Claude Code é **experimental** e pode mudar.
- Cada sub-agente é uma instância completa do Claude, então o consumo de tokens cresce
  com o tamanho do time.
- O Codex não abre sub-agentes em painéis: eles ficam dentro do painel dele (`/subagents`).
- Os painéis usam tmux por baixo, configurado para ficar invisível (sem barra de status e
  com bordas finas), porque o Deepin Terminal não pode ser dividido por script.

## Desenvolvimento

```bash
sudo apt install bats shellcheck
bats tests/
shellcheck bin/nebula install.sh update.sh scripts/*.sh
```

Os testes usam `claude`/`codex` falsos e um servidor tmux isolado, sem tocar nas suas sessões.

## Licença

MIT
