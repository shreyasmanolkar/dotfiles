# If not running interactively, don't do anything (leave this at the top of this file)
[[ $- != *i* ]] && return

# All the default Omarchy aliases and functions
# (don't mess with these directly, just overwrite them here!)
source ~/.local/share/omarchy/default/bash/rc

# Add your own exports, aliases, and functions here.
#
# Make an alias for invoking commands you use constantly
# alias p='python'

#function cursor() {
#    { exec setsid cursor "$@" > /dev/null 2>&1 & } 2>/dev/null
#    disown
#}

cursor() {
  ~/Applications/cursor.AppImage "$@" &
}

# ============================================
# Copy current directory path to clipboard
# ============================================
copy_path() {
    local path
    path=$(pwd)
    
    if command -v wl-copy >/dev/null 2>&1; then
        printf '%s' "$path" | wl-copy
        printf '✓ Copied to clipboard (Wayland): %s\n' "$path"
    elif command -v xclip >/dev/null 2>&1; then
        printf '%s' "$path" | xclip -selection clipboard
        printf '✓ Copied to clipboard (X11): %s\n' "$path"
    elif command -v pbcopy >/dev/null 2>&1; then
        printf '%s' "$path" | pbcopy
        printf '✓ Copied to clipboard (macOS): %s\n' "$path"
    else
        printf '⚠ No clipboard utility found.\n'
        printf 'Install with:\n'
        printf '  sudo apt install xclip          # for X11\n'
        printf '  sudo apt install wl-clipboard   # for Wayland\n\n'
        printf 'Current path: %s\n' "$path"
    fi
}

alias c='clear'
alias code='cursor'
alias ls='eza -a --icons'
alias ll='eza -al --icons'
alias lt='eza -a --tree --level=1 --icons'
alias nrd='npm run dev'
alias nrs='npm run start'
alias nrb='npm run build'
alias cpwd='copy_path'

# if command -v tmux &> /dev/null && [ -n "$PS1" ] && [[ ! "$TERM" =~ screen ]] && [[ ! "$TERM" =~ tmux ]] && [ -z "$TMUX" ]; then
#   exec tmux
# fi

# Auto-start/attach tmux for interactive shells
# Set TMUX_AUTO=1 to enable (exported by default below)
# if command -v tmux &> /dev/null && [ -n "$PS1" ] && [[ ! "$TERM" =~ screen ]] && [[ ! "$TERM" =~ tmux ]] && [ -z "$TMUX" ] && [ -n "$TMUX_AUTO" ]; then
#   # Reuse a session if it exists; otherwise create one named "main"
#   if tmux has-session -t main 2>/dev/null; then
#     exec tmux attach -t main
#   else
#     exec tmux new -s main
#   fi
# fi

# export TMUX_AUTO=1

# Enable auto-attach by default; comment this out if you don’t want it
# Set the history file location
HISTFILE=~/.bash_history

# Number of commands to keep in memory for the current session
HISTSIZE=10000

# Maximum number of lines in the history file
HISTFILESIZE=10000

# Append to the history file instead of overwriting it on shell exit
shopt -s histappend

set -h
export NVM_DIR="$HOME/.config/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

export PATH="$HOME/.local/bin:$PATH"

. "$HOME/.local/share/../bin/env"
