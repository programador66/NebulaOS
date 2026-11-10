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

- Ubuntu 24.04 (X11)
- [Deepin Terminal](https://github.com/linuxdeepin/deepin-terminal) 5.9+
- [Claude Code](https://claude.com/claude-code) e/ou [Codex CLI](https://github.com/openai/codex)

## Instalação

```bash
git clone https://github.com/programador66/NebulaOS.git
cd NebulaOS
./install.sh
```

`install.sh` é idempotente e roda, em ordem:

| Passo | O que faz |
|---|---|
| `00-apt` | instala o que falta entre `zsh tmux stow git curl` (avisa antes de usar `sudo`) |
| `10-binaries` | instala o [starship](https://starship.rs) em `~/.local/bin` |
| `20-stow` | linka os dotfiles (zsh, starship, tmux) no `$HOME` e o comando `nebula` em `~/.local/bin` |
| `30-post` | Oh My Zsh + plugins, tema **Theme8** e shell **zsh** no Deepin Terminal |

- Arquivos que já existirem viram `<arquivo>.nebula-bak`. Nada é sobrescrito.
- O shell de login continua o mesmo: o zsh vale só dentro do Deepin Terminal.
- Para aplicar só os dotfiles: `./install.sh --dotfiles`.

## Uso

| Comando | O que faz |
|---|---|
| `nebula claude <nome> [dir] [--team N]` | abre (ou retoma) a sessão `<nome>` em `dir` (padrão: o diretório atual) com o Claude como líder |
| `nebula codex <nome> [dir]` | igual, com o Codex num painel |
| `nebula ls` | lista as sessões |
| `nebula attach <nome>` | volta para uma sessão (depois de fechar a janela, por exemplo) |
| `nebula kill <nome>` | encerra a sessão e os sub-agentes |
| `nebula update` | `git pull` + reaplica dotfiles e pós-instalação |

### Trabalhando com sub-agentes (Claude)

O `nebula claude` liga o recurso experimental
[agent teams](https://code.claude.com/docs/en/agent-teams) **só nessa sessão**. Seu
`~/.claude/settings.json` não é alterado.

1. Fale com o líder, no painel de cima. Peça o time, por exemplo: *"crie 2 sub-agentes: um
   implementa, outro escreve testes"*. Ou já abra com `--team 2`.
2. O Claude abre cada sub-agente num painel novo, e o NebulaOS os organiza lado a lado embaixo.
3. Para falar direto com um sub-agente, clique no painel dele.

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
