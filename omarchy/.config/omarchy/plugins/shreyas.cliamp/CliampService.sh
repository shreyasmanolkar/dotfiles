#!/usr/bin/env bash
# Starts a Cliamp daemon for the bar controller without ever touching a
# separately launched Cliamp TUI. The PID file is written only for daemons we
# launch, and it is verified before a source switch is allowed to stop it.
set -euo pipefail

action=${1:-start}
provider=${2:-}
playlist=${3:-}
state_home=${XDG_STATE_HOME:-"$HOME/.local/state"}
state_dir="$state_home/omarchy"
pid_file="$state_dir/cliamp-controller.pid"
log_file="$state_dir/cliamp-controller.log"
lock_file="$state_dir/cliamp-controller.lock"

mkdir -p "$state_dir"
exec 9>"$lock_file"
if ! flock -w 5 9; then
  printf 'Cliamp controller is busy; please try again.\n'
  exit 1
fi

case "$provider" in
  ""|radio|navidrome|plex|jellyfin|emby|spotify|qobuz|soundcloud|netease|yt|youtube|ytmusic) ;;
  *)
    printf 'Unsupported Cliamp source: %s\n' "$provider"
    exit 2
    ;;
esac

player_is_available() {
  timeout 2s cliamp status --json >/dev/null 2>&1
}

owned_pid() {
  [ -r "$pid_file" ] || return 1
  local pid command_line
  pid=$(tr -d '[:space:]' < "$pid_file")
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null || return 1
  command_line=$(ps -p "$pid" -o args= 2>/dev/null || true)
  [[ "$command_line" == *cliamp* && "$command_line" == *--daemon* ]] || return 1
  printf '%s\n' "$pid"
}

stop_owned_daemon() {
  local pid
  if ! pid=$(owned_pid); then
    rm -f "$pid_file"
    return 0
  fi

  kill "$pid"
  for _ in $(seq 1 30); do
    kill -0 "$pid" 2>/dev/null || {
      rm -f "$pid_file"
      return 0
    }
    sleep 0.1
  done

  printf 'The controller-owned Cliamp daemon did not stop.\n'
  return 1
}

start_daemon() {
  if ! command -v cliamp >/dev/null 2>&1; then
    printf 'Cliamp is not installed or is not on PATH.\n'
    exit 127
  fi

  if player_is_available; then
    # A previous version could race when the bar was created on more than one
    # display and leave a PID from the losing launch. Never claim another
    # player's process as ours; discard only the stale ownership record.
    if ! owned_pid >/dev/null 2>&1; then
      rm -f "$pid_file"
    fi
    printf 'Cliamp is already running.\n'
    return 0
  fi

  local args=(--daemon)
  [ -n "$provider" ] && args+=(--provider "$provider")
  if [ -n "$playlist" ]; then
    args+=(--playlist "$playlist" --auto-play)
  fi

  nohup cliamp "${args[@]}" >>"$log_file" 2>&1 &
  local launched_pid=$!
  for _ in $(seq 1 30); do
    if player_is_available; then
      # Cliamp publishes the real owner of its IPC socket. Recording it only
      # after the socket is live prevents a failed concurrent launch from
      # overwriting the controller's ownership record.
      if [ -r "$HOME/.config/cliamp/cliamp.sock.pid" ]; then
        tr -d '[:space:]' < "$HOME/.config/cliamp/cliamp.sock.pid" > "$pid_file"
      else
        printf '%s\n' "$launched_pid" > "$pid_file"
      fi
      break
    fi
    if ! kill -0 "$launched_pid" 2>/dev/null; then
      printf 'Cliamp background service exited before it became ready.\n'
      return 1
    fi
    sleep 0.1
  done
  if ! player_is_available; then
    printf 'Cliamp background service did not become ready.\n'
    return 1
  fi
  if [ -n "$provider" ]; then
    printf 'Started Cliamp in the background using %s.\n' "$provider"
  else
    printf 'Started Cliamp in the background using the default source.\n'
  fi
}

case "$action" in
  start)
    start_daemon
    ;;
  restart)
    if player_is_available && ! owned_pid >/dev/null; then
      printf 'A separately launched Cliamp player is already active; it was left unchanged.\n'
      exit 0
    fi
    stop_owned_daemon
    start_daemon
    ;;
  stop)
    stop_owned_daemon
    printf 'Stopped the controller-owned Cliamp daemon.\n'
    ;;
  *)
    printf 'Unknown Cliamp controller action: %s\n' "$action"
    exit 2
    ;;
esac
