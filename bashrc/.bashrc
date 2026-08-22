# Omarchy environment (OMARCHY_PATH + PATH), needed for login and non-interactive shells.
[[ -r /usr/share/omarchy/default/bash/env-bootstrap ]] && source /usr/share/omarchy/default/bash/env-bootstrap

# Leave non-interactive shells with the Omarchy environment only.
[[ $- != *i* ]] && return

# All the default Omarchy aliases and functions.
source "$OMARCHY_PATH/default/bash/rc"

# Open Cursor using the local AppImage when present, otherwise use the installed command.
cursor() {
  if [[ -x "$HOME/Applications/cursor.AppImage" ]]; then
    "$HOME/Applications/cursor.AppImage" "$@" &
  else
    command cursor "$@"
  fi
}

# Copy the current directory path to the clipboard.
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

# Keep tmux opt-in; enable the old auto-attach behavior by setting TMUX_AUTO yourself.
# if command -v tmux >/dev/null && [[ -n "$TMUX_AUTO" ]] && [[ -z "$TMUX" ]]; then
#   tmux has-session -t main 2>/dev/null && exec tmux attach -t main || exec tmux new -s main
# fi

HISTFILE="$HOME/.bash_history"
HISTSIZE=10000
HISTFILESIZE=10000
shopt -s histappend
set -h

export NVM_DIR="$HOME/.config/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"

export PATH="$HOME/.local/bin:$PATH"

. "$HOME/.local/share/../bin/env"
