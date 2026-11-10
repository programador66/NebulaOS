# NebulaOS · zsh

# Oh My Zsh (tema vazio: o prompt é do starship)
export ZSH="$HOME/.oh-my-zsh"
if [[ -d "$ZSH" ]]; then
  ZSH_THEME=""
  plugins=(git zsh-autosuggestions zsh-syntax-highlighting)
  source "$ZSH/oh-my-zsh.sh"
fi

# histórico
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt HIST_IGNORE_DUPS SHARE_HISTORY

# módulos do NebulaOS (ordem alfabética)
for f in "$HOME"/.zsh/*.zsh(N); do
  source "$f"
done
unset f

command -v starship >/dev/null && eval "$(starship init zsh)"
