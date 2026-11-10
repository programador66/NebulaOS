# NebulaOS · PATH e ferramentas (migrado do .bashrc)

export PATH="$HOME/.local/bin:$PATH"
export EDITOR="${EDITOR:-nano}"

# nvm (é de onde vem o codex)
export NVM_DIR="$HOME/.nvm"
[[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"

# sdkman
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]] && source "$SDKMAN_DIR/bin/sdkman-init.sh"
