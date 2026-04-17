# ~/.bashrc — ruOS defaults

# If not interactive, skip
case $- in
    *i*) ;;
    *) return;;
esac

# First-login setup
if [ -f "$HOME/.ruos-first-login.sh" ] && [ ! -f "$HOME/.ruos-initialized" ]; then
    bash "$HOME/.ruos-first-login.sh"
fi

# Cargo/Rust
[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"

# Path
export PATH="$HOME/.local/bin:$PATH"

# Prompt
PS1='\[\033[1;36m\]ruOS\[\033[0m\]:\[\033[1;34m\]\w\[\033[0m\]\$ '

# Aliases
alias ll='ls -alF'
alias la='ls -A'
alias brain='mcp-brain'
alias dj='mixxx'

# History
HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoreboth
shopt -s histappend
