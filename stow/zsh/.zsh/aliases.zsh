# NebulaOS · aliases

# notificação ao fim de um comando longo:  sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(fc -ln -1 | sed -e '\''s/[;&|]\s*alert$//'\'')"'
